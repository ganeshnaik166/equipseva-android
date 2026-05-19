-- Round 391 — dedupe rating-prompt notification on repair_jobs completion.
--
-- The trigger fires on every status→completed transition. Structural
-- guard (WHEN NEW.status='completed' AND OLD.status IS DISTINCT) blocks
-- no-op re-stamps, but a real status cycle (completed → in_progress →
-- completed, e.g. dispute-reopen + re-complete) sends a second
-- rate_engineer + rate_hospital push. Hospital/engineer see the same
-- "Rate the engineer / hospital" prompt twice, reads as spam.
--
-- Sibling fix to r370 (AMC notifier debounce) + r384 (cash-flag race).
-- Skip the INSERT if we already paged the same recipient about the same
-- repair_job_id in the last 7 days.

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
    v_recent_hospital  boolean;
    v_recent_engineer  boolean;
BEGIN
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
        -- Round 391 — dedupe within the trailing 7 days.
        SELECT EXISTS (
          SELECT 1 FROM public.notifications n
           WHERE n.user_id = NEW.hospital_user_id
             AND n.kind    = 'rate_engineer'
             AND n.data->>'repair_job_id' = NEW.id::text
             AND n.created_at >= now() - interval '7 days'
        ) INTO v_recent_hospital;
        IF NOT v_recent_hospital THEN
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
    END IF;

    -- Engineer → "rate the hospital"
    IF v_engineer_user_id IS NOT NULL THEN
        SELECT EXISTS (
          SELECT 1 FROM public.notifications n
           WHERE n.user_id = v_engineer_user_id
             AND n.kind    = 'rate_hospital'
             AND n.data->>'repair_job_id' = NEW.id::text
             AND n.created_at >= now() - interval '7 days'
        ) INTO v_recent_engineer;
        IF NOT v_recent_engineer THEN
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
    END IF;

    RETURN NEW;
END;
$$;
