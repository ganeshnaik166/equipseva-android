-- v2.1 PR-D31: hospital commission-tier upgrade celebration push.
--
-- PR-D2 ships the silent tier flip — commission_rate_for_hospital()
-- recomputes rate at every job completion (10+ jobs/12mo -> 5%; 50+
-- jobs/12mo -> 3%). The hospital sees the change only via the
-- existing CommissionTierPill on Home, and only if they happen to
-- look. Crossing the 10-job and 50-job lines deserves an active push:
--   * Positive reinforcement that the loyalty program is real
--   * Reduces "off-platform" pressure right at the moment hospitals
--     are most engaged with us (just completed a job)
--
-- AFTER UPDATE trigger on repair_jobs. Fires when status flips to
-- 'completed'. Counts hospital's completed_at >= now() - 12 months.
-- When count is exactly 10 OR exactly 50, push kind=
-- 'commission_tier_upgraded' with payload encoding old_rate +
-- new_rate + threshold so the client can render rich copy.
--
-- Tier downgrades (12 months pass without a new job) intentionally
-- silent — surfacing "you lost your tier" would be punitive and we
-- want loyalty to feel like a perk, not a stick.

CREATE OR REPLACE FUNCTION public.notify_commission_tier_upgrade()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count       int;
  v_threshold   int;
  v_new_rate    numeric;
  v_old_rate    numeric;
  v_title       text;
  v_body        text;
BEGIN
  -- Only on the status flip into 'completed'.
  IF TG_OP <> 'UPDATE' THEN RETURN NEW; END IF;
  IF NEW.status::text <> 'completed' THEN RETURN NEW; END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
  IF NEW.hospital_user_id IS NULL THEN RETURN NEW; END IF;

  -- Count hospital's completed jobs in the trailing 12mo window.
  -- AFTER UPDATE so this completion is already visible in the count.
  SELECT count(*) INTO v_count
    FROM public.repair_jobs
   WHERE hospital_user_id = NEW.hospital_user_id
     AND status::text = 'completed'
     AND completed_at IS NOT NULL
     AND completed_at >= now() - interval '12 months';

  -- Crossing exactly the threshold counts as the upgrade event.
  -- 10 -> 7% to 5%; 50 -> 5% to 3%.
  IF v_count = 10 THEN
    v_threshold := 10;
    v_old_rate  := 0.07;
    v_new_rate  := 0.05;
    v_title     := 'Welcome to Loyal — 5% commission';
    v_body      := '10 completed jobs in the last 12 months unlocked the loyal tier. EquipSeva''s cut on future jobs drops from 7% to 5%.';
  ELSIF v_count = 50 THEN
    v_threshold := 50;
    v_old_rate  := 0.05;
    v_new_rate  := 0.03;
    v_title     := 'Welcome to Anchor — 3% commission';
    v_body      := '50 completed jobs in the last 12 months unlocked the anchor tier. Commission drops from 5% to 3% on future jobs.';
  ELSE
    RETURN NEW;
  END IF;

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.hospital_user_id,
      'commission_tier_upgraded',
      v_title,
      v_body,
      jsonb_build_object(
        'threshold',     v_threshold,
        'old_rate',      v_old_rate,
        'new_rate',      v_new_rate,
        'completed_12m', v_count
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'commission_tier_upgraded notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;
ALTER FUNCTION public.notify_commission_tier_upgrade() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_commission_tier_upgrade() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_commission_tier_upgrade_trg ON public.repair_jobs;
CREATE TRIGGER notify_commission_tier_upgrade_trg
  AFTER UPDATE ON public.repair_jobs
  FOR EACH ROW
  WHEN (
    NEW.status::text = 'completed'
    AND OLD.status IS DISTINCT FROM NEW.status
  )
  EXECUTE FUNCTION public.notify_commission_tier_upgrade();
