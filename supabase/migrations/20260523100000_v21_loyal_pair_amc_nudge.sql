-- v2.1 PR-D8: server-side AMC upsell on loyal hospital-engineer pairs
-- (T2.7 in the strategy memo, adapted).
--
-- Strategy memo originally said: "same hospital + same engineer in 3+
-- direct bookings → flag. Send hospital a 2% discount coupon to nudge
-- retention." Two adaptations for v1:
--   1. Our system has no direct-booking path; every job goes through
--      the bid auction. So "loyal pair" = 3+ completed jobs same pair.
--   2. v1 monetization is FREE (no take rate) so no coupon to give.
--      Instead nudge the hospital toward an AMC contract — the natural
--      product for "we keep choosing the same engineer" — which is
--      itself a structural moat (#262–#268).
--
-- Idempotency:
--   * No re-fire if the hospital already has an active AMC contract
--     with the engineer (they're locked in).
--   * No re-fire if a 'amc_loyal_pair_nudge' notification was sent to
--     the same hospital→engineer pair in the last 90 days.
--
-- Fires from the same status='completed' transition as the rate prompt
-- (notify_on_repair_job_completed_for_rating from #250) and the cash
-- survey enqueue (#271). Three triggers stacked on the same UPDATE OF
-- status — Postgres fires them in trigger-name alpha order; ordering
-- doesn't matter here since they don't read each other's writes.

CREATE OR REPLACE FUNCTION public.notify_loyal_pair_amc_upsell()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hospital uuid := NEW.hospital_user_id;
  v_engineer uuid := NEW.engineer_id;
  v_engineer_name text;
  v_engineer_user uuid;
  v_pair_count int;
  v_amc_already boolean;
  v_recent_nudge boolean;
  v_job_number text;
BEGIN
  IF NEW.status::text <> 'completed' THEN RETURN NEW; END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
  IF v_hospital IS NULL OR v_engineer IS NULL THEN RETURN NEW; END IF;

  -- Pair count (incl. this newly-completed row).
  SELECT count(*) INTO v_pair_count
    FROM public.repair_jobs rj
   WHERE rj.hospital_user_id = v_hospital
     AND rj.engineer_id      = v_engineer
     AND rj.status::text     = 'completed';
  IF v_pair_count < 3 THEN RETURN NEW; END IF;

  -- Already on an AMC together → no upsell.
  SELECT EXISTS (
    SELECT 1
      FROM public.amc_contracts c
     WHERE c.hospital_user_id   = v_hospital
       AND c.primary_engineer_id = v_engineer
       AND c.status IN ('active','paused','pending_payment')
  ) INTO v_amc_already;
  IF v_amc_already THEN RETURN NEW; END IF;

  -- Cooldown — don't carpet-bomb the hospital with the same prompt.
  SELECT EXISTS (
    SELECT 1
      FROM public.notifications n
     WHERE n.user_id = v_hospital
       AND n.kind    = 'amc_loyal_pair_nudge'
       AND (n.data ->> 'engineer_id')::uuid = v_engineer
       AND n.sent_at >= now() - interval '90 days'
  ) INTO v_recent_nudge;
  IF v_recent_nudge THEN RETURN NEW; END IF;

  -- Resolve engineer display name (best-effort).
  SELECT e.user_id INTO v_engineer_user
    FROM public.engineers e WHERE e.id = v_engineer;
  IF v_engineer_user IS NOT NULL THEN
    SELECT coalesce(p.full_name, 'this engineer')
      INTO v_engineer_name
      FROM public.profiles p WHERE p.id = v_engineer_user;
  END IF;
  v_engineer_name := coalesce(v_engineer_name, 'this engineer');
  v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      v_hospital,
      'amc_loyal_pair_nudge',
      concat(v_pair_count::text, ' jobs with ', v_engineer_name, ' — set up monthly maintenance?'),
      concat(
        'You''ve completed ', v_pair_count::text,
        ' jobs with ', v_engineer_name,
        '. Lock in monthly maintenance so they''re always on call.'
      ),
      jsonb_build_object(
        'engineer_id',  v_engineer,
        'pair_count',   v_pair_count,
        'last_job_id',  NEW.id,
        'last_job_number', v_job_number
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'amc_loyal_pair_nudge insert failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_loyal_pair_amc_upsell() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_loyal_pair_amc_upsell() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_loyal_pair_amc_upsell_trg ON public.repair_jobs;
CREATE TRIGGER notify_loyal_pair_amc_upsell_trg
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.status::text = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_loyal_pair_amc_upsell();
