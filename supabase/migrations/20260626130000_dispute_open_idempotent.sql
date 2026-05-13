-- dispute_repair_job_escrow throws "escrow not in held state" when the
-- caller taps Open dispute on a row that's already 'in_dispute'. That
-- happens any time the client's retry layer fires a second call after
-- the first succeeded — same hospital, same escrow, second tap. The
-- caller already got what they wanted; raising looks like a failure
-- and surfaces a confusing toast.
--
-- Make the RPC idempotent: when the row is already 'in_dispute' AND the
-- caller is the same hospital that opened the original dispute, return
-- the escrow id without changes. Any other mismatch (different status,
-- different caller) still throws so we don't accept conflicting writes.

CREATE OR REPLACE FUNCTION public.dispute_repair_job_escrow(
  p_repair_job_id uuid,
  p_reason        text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow record;
  v_completed_at timestamptz;
  v_prior_release_resolutions int;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF coalesce(length(trim(p_reason)),0) < 10 THEN
    RAISE EXCEPTION 'dispute reason too short (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_escrow
    FROM public.repair_job_escrow
   WHERE repair_job_id = p_repair_job_id
   FOR UPDATE;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_escrow.hospital_user_id THEN
    RAISE EXCEPTION 'only hospital can open dispute' USING ERRCODE = '42501';
  END IF;

  -- Idempotent re-open: already-in-dispute by the same hospital is a
  -- no-op return, not an error. dispute_reason stays whatever was set
  -- on the first call — second call's reason is silently dropped
  -- because the original was already accepted into the queue.
  IF v_escrow.status = 'in_dispute' THEN
    RETURN v_escrow.id;
  END IF;

  IF v_escrow.status <> 'held' THEN
    RAISE EXCEPTION 'escrow not in held state (got %)', v_escrow.status USING ERRCODE = '22023';
  END IF;

  SELECT completed_at INTO v_completed_at
    FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF v_completed_at IS NULL THEN
    RAISE EXCEPTION 'job not completed' USING ERRCODE = '22023';
  END IF;
  IF now() > v_completed_at + interval '48 hours' THEN
    RAISE EXCEPTION 'dispute window closed' USING ERRCODE = '22023';
  END IF;

  -- Weaponization cap: a hospital that's had >=3 disputes ruled in the
  -- engineer's favor (release outcome) in the past 90 days has shown a
  -- pattern of false-flag disputes. Block further dispute filing — they
  -- can still raise the issue with admin via support, but can't trigger
  -- the automatic 'in_dispute' freeze on escrow.
  SELECT count(*) INTO v_prior_release_resolutions
    FROM public.repair_job_escrow
   WHERE hospital_user_id = v_caller
     AND dispute_resolution = 'release'
     AND dispute_resolved_at IS NOT NULL
     AND dispute_resolved_at >= now() - interval '90 days';

  IF v_prior_release_resolutions >= 3 THEN
    RAISE EXCEPTION
      'dispute filing temporarily blocked: too many prior disputes ruled in engineer favor in the last 90 days. Contact support.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.repair_job_escrow
     SET status = 'in_dispute',
         dispute_opened_at = now(),
         dispute_reason = p_reason
   WHERE id = v_escrow.id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (v_escrow.id, 'disputed', v_caller,
          jsonb_build_object('reason', p_reason));

  RETURN v_escrow.id;
END;
$$;
