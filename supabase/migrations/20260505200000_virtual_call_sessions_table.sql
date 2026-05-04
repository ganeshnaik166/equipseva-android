-- Anti-disintermediation moat (Feature 3 of the v2 plan): hospital
-- and engineer never see each other's real phone number. Calls bridge
-- through Exotel — server allocates a click-to-call session, dials
-- both legs, neither party gets the other's MSISDN in their call log.
-- This row tracks each bridge attempt for audit + abuse detection.
--
-- Click-to-call mode (vs. number pool): a single ExoPhone fronts every
-- call. We don't hold a long-lived virtual number per (hospital,
-- engineer) pair; instead Exotel's /Calls/connect bridges the two
-- legs from its own number. The session row exists for analytics
-- (call_count, abuse signals like "20 calls + every duration < 10s")
-- and for the post-job tombstone trigger.
--
-- RLS: SELECT to participants only. INSERT/UPDATE blocked at the
-- policy level → only SECURITY DEFINER edge functions running under
-- service-role write here. Mirrors the repair_job_cost_revisions /
-- payments table patterns.

CREATE TABLE IF NOT EXISTS public.virtual_call_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id uuid NOT NULL REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'exotel',
  exotel_call_sid text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'ringing', 'answered', 'completed', 'failed', 'released')),
  expires_at timestamptz,
  last_called_at timestamptz,
  call_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Hot lookup by job + still-fresh window (the edge function reuses an
-- in-flight session if one exists for the same job + caller-callee
-- pair within the last 30 min; saves an Exotel API roundtrip).
CREATE INDEX IF NOT EXISTS virtual_call_sessions_job_expires_idx
  ON public.virtual_call_sessions (repair_job_id, expires_at);

-- Abuse-detection lookup: high call_count with short durations =
-- likely circumvention attempt where one side is using the bridge to
-- read out their real number aloud. Founder dashboard surfaces this.
CREATE INDEX IF NOT EXISTS virtual_call_sessions_call_count_idx
  ON public.virtual_call_sessions (call_count DESC, created_at DESC);

-- Per-user lookups (founder forensics + the user's own call history,
-- if we expose it in v3).
CREATE INDEX IF NOT EXISTS virtual_call_sessions_hospital_idx
  ON public.virtual_call_sessions (hospital_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS virtual_call_sessions_engineer_idx
  ON public.virtual_call_sessions (engineer_user_id, created_at DESC);

ALTER TABLE public.virtual_call_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY virtual_call_sessions_select_participant
  ON public.virtual_call_sessions
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = hospital_user_id
    OR auth.uid() = engineer_user_id
  );

-- INSERT/UPDATE/DELETE: no policy → only SECURITY DEFINER edge fns
-- (service_role) write. Same shape as repair_job_cost_revisions.

REVOKE ALL ON public.virtual_call_sessions FROM anon;
GRANT SELECT ON public.virtual_call_sessions TO authenticated;

ALTER TABLE public.virtual_call_sessions OWNER TO postgres;

-- Tombstone session rows when the parent repair_job lands in a
-- terminal state. Click-to-call is stateless per call (Exotel doesn't
-- hold a number reserved for this pair), so "release" really just
-- marks the session ineligible for reuse. 30-day grace before sweep
-- via TTL helper below.
CREATE OR REPLACE FUNCTION public.release_virtual_call_sessions_on_job_terminal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status::text NOT IN ('completed', 'cancelled') THEN
    RETURN NEW;
  END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  UPDATE public.virtual_call_sessions
     SET status = 'released',
         expires_at = now() + interval '30 days'
   WHERE repair_job_id = NEW.id
     AND status NOT IN ('released', 'failed');

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.release_virtual_call_sessions_on_job_terminal() OWNER TO postgres;

DROP TRIGGER IF EXISTS release_virtual_call_sessions_trg ON public.repair_jobs;
CREATE TRIGGER release_virtual_call_sessions_trg
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.status::text IN ('completed', 'cancelled'))
  EXECUTE FUNCTION public.release_virtual_call_sessions_on_job_terminal();

REVOKE ALL ON FUNCTION public.release_virtual_call_sessions_on_job_terminal() FROM PUBLIC;

-- TTL: tombstoned sessions older than 30 days get fully purged.
-- Same standalone-helper pattern as the v2 scaling pass; ops wires it
-- to pg_cron OR a Supabase scheduled edge function.
CREATE OR REPLACE FUNCTION public.purge_old_virtual_call_sessions()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  WITH gone AS (
    DELETE FROM public.virtual_call_sessions
     WHERE status = 'released'
       AND expires_at IS NOT NULL
       AND expires_at < now()
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM gone;
  RETURN v_count;
END;
$$;

ALTER FUNCTION public.purge_old_virtual_call_sessions() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_old_virtual_call_sessions() FROM PUBLIC, anon, authenticated;
