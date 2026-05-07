-- v2.1 PR-D43: random spot-audit framework (strategy memo T2.10).
--
-- The cash-flag survey (PR-D1) is targeted: it asks ONE specific
-- question on EVERY completed job. Spot-audits are the complementary
-- random sweep: 1-in-20 completed jobs sampled for a richer quality
-- check (rating 1..5 + free-text feedback). Caught patterns the
-- targeted question misses (slow service, parts not actually
-- replaced, hospital satisfaction nuance).
--
-- Schema:
--   * spot_audit_invitations — sampled jobs queued for the hospital
--   * spot_audit_responses   — submitted responses (1:1 to invitation)
-- Trigger:
--   * sample_for_spot_audit_on_completion — 1-in-20 random pick on
--     status flip to 'completed'. Hospital can only have 1 OPEN
--     invitation at a time (rate-limit on hospital fatigue).
-- RPCs:
--   * get_pending_spot_audit() — caller-scoped: returns the open
--     invitation if any, else NULL
--   * submit_spot_audit(invitation_id, rating, feedback)
--   * admin_list_recent_spot_audits(window_days) — queue read

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.spot_audit_invitations (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id     uuid NOT NULL UNIQUE
                      REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  hospital_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  engineer_id       uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  expires_at        timestamptz NOT NULL DEFAULT (now() + interval '7 days')
);
-- Plain index (Postgres rejects now() in a partial predicate because
-- now() is STABLE not IMMUTABLE). The predicate filter happens at
-- query time in get_pending_spot_audit().
CREATE INDEX IF NOT EXISTS spot_audit_invitations_lookup_idx
  ON public.spot_audit_invitations (hospital_user_id, expires_at);

CREATE TABLE IF NOT EXISTS public.spot_audit_responses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id   uuid NOT NULL UNIQUE
                    REFERENCES public.spot_audit_invitations(id) ON DELETE CASCADE,
  rating          int  NOT NULL CHECK (rating BETWEEN 1 AND 5),
  feedback        text,
  responded_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS spot_audit_responses_recent_idx
  ON public.spot_audit_responses (responded_at DESC);

-- RLS — invitations readable by their hospital + admin/founder. Direct
-- INSERT/UPDATE blocked; flow goes through SECDEF RPCs.
ALTER TABLE public.spot_audit_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spot_audit_responses   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS spot_audit_invitations_select ON public.spot_audit_invitations;
CREATE POLICY spot_audit_invitations_select ON public.spot_audit_invitations
  FOR SELECT TO authenticated
  USING (
    auth.uid() = hospital_user_id
    OR public.is_admin(auth.uid())
    OR public.is_founder()
  );

DROP POLICY IF EXISTS spot_audit_responses_select ON public.spot_audit_responses;
CREATE POLICY spot_audit_responses_select ON public.spot_audit_responses
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.spot_audit_invitations i
       WHERE i.id = invitation_id
         AND (
           i.hospital_user_id = auth.uid()
           OR public.is_admin(auth.uid())
           OR public.is_founder()
         )
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.spot_audit_invitations FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.spot_audit_responses   FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. Sampling trigger — 1-in-20 on completion
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sample_for_spot_audit_on_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_existing int;
  v_invitation_id uuid;
BEGIN
  IF TG_OP <> 'UPDATE' THEN RETURN NEW; END IF;
  IF NEW.status::text <> 'completed' THEN RETURN NEW; END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
  IF NEW.hospital_user_id IS NULL THEN RETURN NEW; END IF;

  -- Skip AMC visits — pool charges, not direct hospital pay; the
  -- targeted cash-flag survey already covers contracted_amount jobs.
  IF NEW.kind::text = 'maintenance' THEN RETURN NEW; END IF;

  -- Rate-limit: skip when hospital already has an open invitation.
  -- Avoids fatigue from multiple completions in quick succession.
  SELECT count(*) INTO v_existing
    FROM public.spot_audit_invitations
   WHERE hospital_user_id = NEW.hospital_user_id
     AND expires_at > now();
  IF v_existing > 0 THEN RETURN NEW; END IF;

  -- 1-in-20 sample.
  IF random() >= 0.05 THEN RETURN NEW; END IF;

  INSERT INTO public.spot_audit_invitations (
    repair_job_id, hospital_user_id, engineer_id
  ) VALUES (NEW.id, NEW.hospital_user_id, NEW.engineer_id)
  RETURNING id INTO v_invitation_id;

  -- Push to hospital. Best-effort.
  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.hospital_user_id,
      'spot_audit_invited',
      'Quick quality check (under a minute)',
      'Help EquipSeva keep service quality high — rate the work and (optionally) leave a note.',
      jsonb_build_object(
        'invitation_id', v_invitation_id,
        'repair_job_id', NEW.id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'spot_audit_invited notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;
ALTER FUNCTION public.sample_for_spot_audit_on_completion() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.sample_for_spot_audit_on_completion() FROM PUBLIC;

DROP TRIGGER IF EXISTS sample_for_spot_audit_on_completion_trg ON public.repair_jobs;
CREATE TRIGGER sample_for_spot_audit_on_completion_trg
  AFTER UPDATE ON public.repair_jobs
  FOR EACH ROW
  WHEN (
    NEW.status::text = 'completed'
    AND OLD.status IS DISTINCT FROM NEW.status
  )
  EXECUTE FUNCTION public.sample_for_spot_audit_on_completion();

-- ---------------------------------------------------------------------
-- 3. get_pending_spot_audit() — hospital-side single open invitation
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_pending_spot_audit()
RETURNS TABLE (
  invitation_id   uuid,
  repair_job_id   uuid,
  job_number      text,
  engineer_id     uuid,
  engineer_name   text,
  expires_at      timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    i.id                              AS invitation_id,
    i.repair_job_id,
    rj.job_number,
    i.engineer_id,
    coalesce(p_eng.full_name, '(unnamed)') AS engineer_name,
    i.expires_at
    FROM public.spot_audit_invitations i
    LEFT JOIN public.repair_jobs rj  ON rj.id = i.repair_job_id
    LEFT JOIN public.engineers e     ON e.id  = i.engineer_id
    LEFT JOIN public.profiles p_eng  ON p_eng.id = e.user_id
   WHERE i.hospital_user_id = v_caller
     AND i.expires_at > now()
     AND NOT EXISTS (
       SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = i.id
     )
   ORDER BY i.created_at DESC
   LIMIT 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_pending_spot_audit() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_pending_spot_audit() TO authenticated;

-- ---------------------------------------------------------------------
-- 4. submit_spot_audit(invitation_id, rating, feedback)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_spot_audit(
  p_invitation_id uuid,
  p_rating        int,
  p_feedback      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_inv    record;
  v_resp_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'rating must be 1..5' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_inv FROM public.spot_audit_invitations
   WHERE id = p_invitation_id
   FOR UPDATE;
  IF v_inv IS NULL THEN
    RAISE EXCEPTION 'invitation not found' USING ERRCODE = '02000';
  END IF;
  IF v_inv.hospital_user_id <> v_caller THEN
    RAISE EXCEPTION 'caller is not the invited hospital' USING ERRCODE = '42501';
  END IF;
  IF v_inv.expires_at <= now() THEN
    RAISE EXCEPTION 'invitation expired at %', v_inv.expires_at USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.spot_audit_responses (invitation_id, rating, feedback)
  VALUES (
    p_invitation_id,
    p_rating,
    nullif(trim(coalesce(p_feedback, '')), '')
  )
  RETURNING id INTO v_resp_id;

  RETURN v_resp_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.submit_spot_audit(uuid, int, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.submit_spot_audit(uuid, int, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 5. admin_list_recent_spot_audits(window_days)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_recent_spot_audits(
  p_window_days int DEFAULT 30,
  p_limit       int DEFAULT 100
)
RETURNS TABLE (
  response_id     uuid,
  invitation_id   uuid,
  repair_job_id   uuid,
  job_number      text,
  hospital_user_id uuid,
  hospital_name   text,
  engineer_id     uuid,
  engineer_name   text,
  rating          int,
  feedback        text,
  responded_at    timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_window_days <= 0 OR p_window_days > 365 OR p_limit <= 0 OR p_limit > 500 THEN
    RAISE EXCEPTION 'window_days 1..365 / limit 1..500' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    r.id                                AS response_id,
    r.invitation_id,
    i.repair_job_id,
    rj.job_number,
    i.hospital_user_id,
    coalesce(p_hosp.full_name, '(unnamed)') AS hospital_name,
    i.engineer_id,
    coalesce(p_eng.full_name, '(unnamed)')  AS engineer_name,
    r.rating,
    r.feedback,
    r.responded_at
    FROM public.spot_audit_responses r
    JOIN public.spot_audit_invitations i ON i.id = r.invitation_id
    LEFT JOIN public.repair_jobs rj ON rj.id = i.repair_job_id
    LEFT JOIN public.profiles p_hosp ON p_hosp.id = i.hospital_user_id
    LEFT JOIN public.engineers e     ON e.id = i.engineer_id
    LEFT JOIN public.profiles p_eng  ON p_eng.id = e.user_id
   WHERE r.responded_at >= now() - make_interval(days => p_window_days)
   ORDER BY r.responded_at DESC
   LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_list_recent_spot_audits(int, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_list_recent_spot_audits(int, int) TO authenticated;
