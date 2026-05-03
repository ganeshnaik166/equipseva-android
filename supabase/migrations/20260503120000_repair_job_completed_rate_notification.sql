-- Push the user toward the rating flow once a job lands in `completed`.
-- Today the Rate CTA only appears as a passive button on the detail
-- screen — users who close the app right after a job ends never come
-- back to rate, and the directory ranking signal stays empty.
--
-- Mirrors the existing `notify_on_repair_bid_status_change` pattern from
-- 20260428020000_engineer_side_push_event_triggers — SECURITY DEFINER,
-- fixed search_path, defensive RAISE NOTICE on inner failures so a
-- fan-out hiccup never rolls back the status flip.

CREATE OR REPLACE FUNCTION public.notify_on_repair_job_completed_for_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_engineer_user_id uuid;
    v_job_number       text;
    v_payload          jsonb;
BEGIN
    -- Only on durable transition into completed. Other status moves
    -- (assigned → cancelled, etc.) don't trigger the rating prompt.
    IF NEW.status::text <> 'completed' THEN
        RETURN NEW;
    END IF;
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;

    SELECT user_id INTO v_engineer_user_id
      FROM public.engineers
     WHERE id = NEW.engineer_id;

    v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));
    v_payload := jsonb_build_object(
        'repair_job_id', NEW.id,
        'job_number',    v_job_number
    );

    -- Hospital → "rate the engineer"
    IF NEW.hospital_user_id IS NOT NULL THEN
        BEGIN
            INSERT INTO public.notifications (user_id, kind, title, body, data)
            VALUES (
                NEW.hospital_user_id,
                'rate_engineer',
                'Rate the engineer',
                concat('Job ', v_job_number, ' is done. How was the engineer?'),
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'rate_engineer notify failed: % / %', SQLSTATE, SQLERRM;
        END;
    END IF;

    -- Engineer → "rate the hospital"
    IF v_engineer_user_id IS NOT NULL THEN
        BEGIN
            INSERT INTO public.notifications (user_id, kind, title, body, data)
            VALUES (
                v_engineer_user_id,
                'rate_hospital',
                'Rate the hospital',
                concat('You wrapped ', v_job_number, '. Rate the hospital so others know what to expect.'),
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'rate_hospital notify failed: % / %', SQLSTATE, SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_on_repair_job_completed_for_rating() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_on_repair_job_completed_for_rating() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_repair_job_completed_for_rating_trg ON public.repair_jobs;
CREATE TRIGGER notify_on_repair_job_completed_for_rating_trg
    AFTER UPDATE OF status ON public.repair_jobs
    FOR EACH ROW
    WHEN (NEW.status::text = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.notify_on_repair_job_completed_for_rating();
