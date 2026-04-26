-- Engineer-side push event triggers (Phase C of v1 polish loop).
-- Closes notification gaps for the engineer worker journey:
--   1. repair_job_bids UPDATE → status flips to 'accepted'  → kind=repair_bid_accepted
--   2. repair_job_bids UPDATE → status flips to 'rejected'  → kind=repair_bid_rejected
--   3. repair_jobs     UPDATE → status flips to 'cancelled' → kind=repair_job_cancelled
--   4. engineers       UPDATE → verification_status changes → kind=kyc_status_changed
--
-- All recipients are the engineer (user_id), so each function resolves the
-- engineer user from the relevant join. Same defensive pattern as the existing
-- triggers: SECURITY DEFINER, fixed search_path, never roll back the parent
-- write on a fan-out failure, skip self-notifications.

-- ---------------------------------------------------------------------------
-- 1+2. repair_job_bids → repair_bid_accepted / repair_bid_rejected
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_on_repair_bid_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_job_number text;
    v_kind       text;
    v_title      text;
    v_body       text;
BEGIN
    -- Only on durable transition into accepted/rejected. Other status moves
    -- (withdrawn, back to pending) don't emit a push.
    IF NEW.status NOT IN ('accepted', 'rejected') THEN
        RETURN NEW;
    END IF;
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;
    IF NEW.engineer_user_id IS NULL THEN
        RAISE NOTICE 'notify_on_repair_bid_status_change: missing engineer_user_id on bid %', NEW.id;
        RETURN NEW;
    END IF;

    SELECT job_number INTO v_job_number
    FROM public.repair_jobs
    WHERE id = NEW.repair_job_id;

    IF NEW.status = 'accepted' THEN
        v_kind  := 'repair_bid_accepted';
        v_title := 'Your bid was accepted';
        v_body  := concat(
            'You won the job ',
            coalesce(v_job_number, substring(NEW.repair_job_id::text, 1, 8)),
            '. Tap to view details.'
        );
    ELSE
        v_kind  := 'repair_bid_rejected';
        v_title := 'Bid not selected';
        v_body  := concat(
            'Hospital chose another engineer for ',
            coalesce(v_job_number, substring(NEW.repair_job_id::text, 1, 8)),
            '.'
        );
    END IF;

    BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
            NEW.engineer_user_id,
            v_kind,
            v_title,
            v_body,
            jsonb_build_object(
                'repair_job_id', NEW.repair_job_id,
                'bid_id',        NEW.id,
                'amount_rupees', NEW.amount_rupees
            )
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'notify_on_repair_bid_status_change: insert failed: % / %', SQLSTATE, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_on_repair_bid_status_change() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_repair_bid_status_change ON public.repair_job_bids;
CREATE TRIGGER notify_on_repair_bid_status_change
    AFTER UPDATE OF status ON public.repair_job_bids
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_repair_bid_status_change();

-- ---------------------------------------------------------------------------
-- 3. repair_jobs → repair_job_cancelled
-- ---------------------------------------------------------------------------
-- Hospital cancels an assigned job. Resolve engineer user via engineers.id.

CREATE OR REPLACE FUNCTION public.notify_on_repair_job_cancelled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_engineer_user uuid;
    v_body          text;
BEGIN
    IF NEW.status IS DISTINCT FROM 'cancelled'::job_status THEN
        RETURN NEW;
    END IF;
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;
    -- No engineer assigned yet → nobody to notify, exit cleanly.
    IF NEW.engineer_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT user_id INTO v_engineer_user
    FROM public.engineers
    WHERE id = NEW.engineer_id;

    IF v_engineer_user IS NULL THEN
        RAISE NOTICE 'notify_on_repair_job_cancelled: no user for engineer %', NEW.engineer_id;
        RETURN NEW;
    END IF;

    -- Self-cancel guard: if the engineer somehow cancelled their own job,
    -- skip the push.
    IF v_engineer_user = NEW.hospital_user_id THEN
        RETURN NEW;
    END IF;

    v_body := concat(
        'Job ',
        coalesce(NEW.job_number, substring(NEW.id::text, 1, 8)),
        ' was cancelled by the hospital.'
    );

    BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
            v_engineer_user,
            'repair_job_cancelled',
            'Job cancelled',
            v_body,
            jsonb_build_object(
                'repair_job_id', NEW.id,
                'job_number',    NEW.job_number
            )
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'notify_on_repair_job_cancelled: insert failed: % / %', SQLSTATE, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_on_repair_job_cancelled() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_repair_job_cancelled ON public.repair_jobs;
CREATE TRIGGER notify_on_repair_job_cancelled
    AFTER UPDATE OF status ON public.repair_jobs
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_repair_job_cancelled();

-- ---------------------------------------------------------------------------
-- 4. engineers → kyc_status_changed
-- ---------------------------------------------------------------------------
-- Founder admin RPC flips verification_status; engineer needs a push so they
-- can come back into the app and either start bidding (verified) or fix the
-- flagged docs (rejected).

CREATE OR REPLACE FUNCTION public.notify_on_engineer_kyc_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_title text;
    v_body  text;
BEGIN
    -- Only fire on transitions to verified/rejected. We don't push for
    -- pending → pending or rejected → pending (engineer initiated reupload).
    IF NEW.verification_status NOT IN ('verified'::verification_status, 'rejected'::verification_status) THEN
        RETURN NEW;
    END IF;
    IF OLD.verification_status IS NOT DISTINCT FROM NEW.verification_status THEN
        RETURN NEW;
    END IF;
    IF NEW.user_id IS NULL THEN
        RAISE NOTICE 'notify_on_engineer_kyc_status_change: missing user_id on engineer %', NEW.id;
        RETURN NEW;
    END IF;

    IF NEW.verification_status = 'verified'::verification_status THEN
        v_title := 'You''re verified';
        v_body  := 'Hospitals can now find you in the directory and request jobs.';
    ELSE
        v_title := 'KYC needs another look';
        v_body  := 'Tap to see what to re-upload.';
    END IF;

    BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
            NEW.user_id,
            'kyc_status_changed',
            v_title,
            v_body,
            jsonb_build_object(
                'verification_status', NEW.verification_status::text,
                'engineer_id',         NEW.id
            )
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'notify_on_engineer_kyc_status_change: insert failed: % / %', SQLSTATE, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_on_engineer_kyc_status_change() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_engineer_kyc_status_change ON public.engineers;
CREATE TRIGGER notify_on_engineer_kyc_status_change
    AFTER UPDATE OF verification_status ON public.engineers
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_engineer_kyc_status_change();
