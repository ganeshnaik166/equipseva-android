-- Round 420 — hotfix for Round 391 (20260709800000_round391_rating_prompt_dedup.sql).
--
-- The rating-prompt dedupe trigger introduced in r391 references
-- public.notifications.created_at, but that column does NOT exist on
-- this schema (the table has sent_at + read_at — see migrations 20260427030000+).
-- Result: EVERY repair_jobs status→completed transition since r391
-- raises `column n.created_at does not exist` and the entire UPDATE
-- (including the BEFORE-UPDATE commission split + AFTER-UPDATE escrow
-- release schedule) rolls back. Engineers literally cannot complete
-- jobs in prod.
--
-- Discovered while running an end-to-end ₹10 demo job:
--   ERROR:  42703: column n.created_at does not exist
--   HINT:   Perhaps you meant to reference the column "n.read_at".
--   CONTEXT: PL/pgSQL function notify_on_repair_job_completed_for_rating() line 29
--
-- Fix: swap `n.created_at` → `n.sent_at` (the canonical insertion
-- timestamp on public.notifications). Dedupe semantics are unchanged:
-- a duplicate row is still defined as "same recipient + same kind +
-- same repair_job_id within 7 days", we just use the column that
-- actually exists.
--
-- This patch was applied live to prod via the Management API SQL
-- endpoint on 2026-06-01 to unblock job completion; this migration
-- captures the same fix in source so a future `supabase db reset`
-- doesn't reintroduce the bug.

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

    IF NEW.hospital_user_id IS NOT NULL THEN
        SELECT EXISTS (
          SELECT 1 FROM public.notifications n
           WHERE n.user_id = NEW.hospital_user_id
             AND n.kind    = 'rate_engineer'
             AND n.data->>'repair_job_id' = NEW.id::text
             AND n.sent_at >= now() - interval '7 days'
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

    IF v_engineer_user_id IS NOT NULL THEN
        SELECT EXISTS (
          SELECT 1 FROM public.notifications n
           WHERE n.user_id = v_engineer_user_id
             AND n.kind    = 'rate_hospital'
             AND n.data->>'repair_job_id' = NEW.id::text
             AND n.sent_at >= now() - interval '7 days'
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
