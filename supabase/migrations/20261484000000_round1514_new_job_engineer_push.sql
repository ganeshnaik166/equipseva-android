-- Round 1514 — page nearby engineers when a new marketplace job is posted.
--
-- THE GAP (found via the client's notification-kind census): engineers had
-- NO push for new jobs — discovery was app-open-only, while the feed itself
-- tells them "bids in the first 10 min get accepted 3× more often". This
-- trigger closes the loop: a hospital posts, nearby engineers' phones buzz,
-- bid latency drops, match rate rises.
--
-- CONSERVATIVE v1 targeting (spam control):
--   * only OPEN marketplace jobs: status='requested' AND engineer_id IS NULL
--     (AMC visits are pre-assigned and must not page the market);
--   * only jobs WITH site coords (no-pin jobs are still discoverable in the
--     feed; without coords we cannot target honestly, so we stay silent);
--   * only VERIFIED engineers with a registered base, within THEIR OWN
--     service_radius_km (fallback 25 km) of the site — the engineer already
--     declared how far they'll travel, so we respect it;
--   * never the posting hospital's own user; capped at the 50 nearest.
--
-- SAFETY: the entire body is wrapped — any failure logs a NOTICE and the
-- job INSERT still commits (the posting flow is sacred, same rule as every
-- other notify trigger in this schema). Uses the existing
-- public.haversine_km helper + the notifications table drained by the FCM
-- pipeline. Client mapping ships in the same round (KIND_REPAIR_JOB_NEW_NEARBY
-- → repair job detail); the client's NotificationKindDriftGuardTest enforces
-- the pairing.

CREATE OR REPLACE FUNCTION public.notify_nearby_engineers_on_job_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_target record;
  v_title  text;
  v_body   text;
BEGIN
  BEGIN
    IF NEW.status IS DISTINCT FROM 'requested' THEN RETURN NEW; END IF;
    IF NEW.engineer_id IS NOT NULL THEN RETURN NEW; END IF;
    IF NEW.site_latitude IS NULL OR NEW.site_longitude IS NULL THEN RETURN NEW; END IF;

    v_title := 'New ' || replace(coalesce(NEW.equipment_type::text, 'repair'), '_', ' ')
      || ' job near you';
    v_body := left(coalesce(NEW.issue_description, 'Open repair job'), 140)
      || coalesce(' · ' || nullif(left(NEW.site_location, 60), ''), '');

    FOR v_target IN
      SELECT e.user_id
        FROM public.engineers e
       WHERE coalesce(e.verification_status::text, 'pending') = 'verified'
         AND e.latitude IS NOT NULL
         AND e.longitude IS NOT NULL
         AND e.user_id IS DISTINCT FROM NEW.hospital_user_id
         AND public.haversine_km(
               e.latitude, e.longitude,
               NEW.site_latitude, NEW.site_longitude
             ) <= coalesce(nullif(e.service_radius_km, 0), 25)
       ORDER BY public.haversine_km(
                  e.latitude, e.longitude,
                  NEW.site_latitude, NEW.site_longitude
                ) ASC
       LIMIT 50
    LOOP
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_target.user_id,
          'repair_job_new_nearby',
          v_title,
          v_body,
          jsonb_build_object(
            'repair_job_id', NEW.id,
            'job_number',    NEW.job_number
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'repair_job_new_nearby notify failed for %: % / %',
          v_target.user_id, SQLSTATE, SQLERRM;
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    -- Never let the paging fan-out block the job posting itself.
    RAISE NOTICE 'notify_nearby_engineers_on_job_insert failed: % / %', SQLSTATE, SQLERRM;
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS repair_jobs_notify_nearby_engineers_trg ON public.repair_jobs;
CREATE TRIGGER repair_jobs_notify_nearby_engineers_trg
  AFTER INSERT ON public.repair_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_nearby_engineers_on_job_insert();

COMMENT ON FUNCTION public.notify_nearby_engineers_on_job_insert() IS
  'Round 1514: pages up to 50 verified engineers (within their own service radius of the job site) when an open marketplace job is inserted. Best-effort — never blocks the insert.';
