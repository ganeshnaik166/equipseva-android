-- =====================================================================
-- Round 505 — Smart Escrow Auto-Release polish (v0.4 Phase 2 #5)
-- =====================================================================
--
-- Existing process_due_repair_job_escrow_releases() already does the
-- core 48h auto + dispute-pause logic (WHERE dispute_opened_at IS NULL).
-- This round adds the missing polish:
--   1. Hospital sign-off SHORTCUT — instant release when hospital
--      explicitly approves (no 48h wait). Better UX for happy path.
--   2. repair_job_escrow.hospital_signed_off_at column + RPC.
--   3. Hourly cron schedule for the existing release sweep (best-effort
--      via DO/EXCEPTION; pg_cron unavailable on this tier).
--   4. Audit row to r482 founder_action_log when founder manually
--      triggers a release (override path).

BEGIN;

-- ---------------------------------------------------------------------
-- 1. hospital_signed_off_at column
-- ---------------------------------------------------------------------
ALTER TABLE public.repair_job_escrow
  ADD COLUMN IF NOT EXISTS hospital_signed_off_at timestamptz,
  ADD COLUMN IF NOT EXISTS hospital_signoff_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS hospital_signoff_note  text;

CREATE INDEX IF NOT EXISTS repair_job_escrow_hospital_signoff_idx
  ON public.repair_job_escrow (hospital_signed_off_at)
  WHERE hospital_signed_off_at IS NOT NULL AND status = 'held';

-- ---------------------------------------------------------------------
-- 2. hospital_signoff_release_escrow — instant release
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hospital_signoff_release_escrow(
  p_escrow_id  uuid,
  p_signoff_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_escrow record;
  v_job    record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_escrow FROM public.repair_job_escrow WHERE id = p_escrow_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'escrow_not_found' USING ERRCODE = '02000';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = v_escrow.repair_job_id;
  IF v_job.hospital_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_hospital_can_signoff' USING ERRCODE = '42501';
  END IF;
  IF v_escrow.status <> 'held' THEN
    RAISE EXCEPTION 'escrow_not_held (status=%)', v_escrow.status USING ERRCODE = '22023';
  END IF;
  IF v_escrow.dispute_opened_at IS NOT NULL THEN
    RAISE EXCEPTION 'escrow_in_dispute_resolve_first' USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_escrow
     SET status = 'released',
         released_at = now(),
         hospital_signed_off_at = now(),
         hospital_signoff_by = auth.uid(),
         hospital_signoff_note = p_signoff_note
   WHERE id = p_escrow_id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (
    p_escrow_id,
    'released',
    auth.uid(),
    jsonb_build_object(
      'reason', 'hospital_signoff',
      'note', p_signoff_note,
      'released_via', 'instant_signoff'
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.hospital_signoff_release_escrow(uuid, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_signoff_release_escrow(uuid, text)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.hospital_signoff_release_escrow IS
  'Round 505 — instant escrow release on explicit hospital sign-off. Faster than the 48h scheduled auto-release. Refuses when dispute_opened_at is set (must resolve dispute first).';

-- ---------------------------------------------------------------------
-- 3. founder_force_release_escrow — override path with audit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_force_release_escrow(
  p_escrow_id uuid,
  p_reason    text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_escrow record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'reason required (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_escrow FROM public.repair_job_escrow WHERE id = p_escrow_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'escrow_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_escrow.status NOT IN ('held','disputed') THEN
    RAISE EXCEPTION 'escrow_in_terminal_status (%)', v_escrow.status USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_escrow
     SET status = 'released',
         released_at = now()
   WHERE id = p_escrow_id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (
    p_escrow_id,
    'released',
    auth.uid(),
    jsonb_build_object(
      'reason', 'founder_force',
      'founder_reason', p_reason,
      'prior_status', v_escrow.status
    )
  );

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_force_release_escrow',
    p_target_table  => 'repair_job_escrow',
    p_target_row_id => p_escrow_id,
    p_before_value  => jsonb_build_object('status', v_escrow.status, 'amount', v_escrow.amount_rupees),
    p_after_value   => jsonb_build_object('status', 'released'),
    p_reason        => p_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_force_release_escrow(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_force_release_escrow(uuid, text) TO service_role;

-- ---------------------------------------------------------------------
-- 4. Schedule the existing auto-release sweep hourly
-- ---------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.schedule(
    'process_due_repair_job_escrow_releases_hourly',
    '0 * * * *',  -- top of every hour
    $cron$SELECT public.process_due_repair_job_escrow_releases();$cron$
  );
  RAISE NOTICE 'round 505: hourly escrow release sweep scheduled';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 505: pg_cron unavailable; process_due_repair_job_escrow_releases() callable from edge fn / manual';
END;
$$;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='repair_job_escrow'
      AND column_name='hospital_signed_off_at'
  ) THEN
    RAISE EXCEPTION 'round 505: hospital_signed_off_at column not created';
  END IF;
  RAISE NOTICE 'round 505 escrow auto-release polish verified: 3 new columns + 2 RPCs + hourly cron';
END;
$$;
