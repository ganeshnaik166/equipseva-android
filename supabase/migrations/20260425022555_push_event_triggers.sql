-- Server-side push send rules for high-value events (PENDING.md #36 expansion).
--
-- Today, FCM only fires when something INSERTs into public.notifications
-- (the dispatch trigger from migration 20260425020000). This migration adds
-- AFTER triggers on four key business events that auto-INSERT a row into
-- public.notifications, which then auto-pushes via the existing dispatcher.
--
-- Events wired here:
--   1. chat_messages   AFTER INSERT  -> notify the *other* participant(s)
--                                       (kind='chat_message_new').
--   2. repair_job_bids AFTER INSERT  -> notify the hospital owner of the job
--                                       (kind='repair_bid_new').
--   3. spare_part_orders AFTER UPDATE WHEN order_status transitions
--                       'placed' / 'confirmed' -> 'shipped'
--                                     -> notify buyer (kind='order_shipped').
--   4. rfq_bids        AFTER UPDATE  WHEN status transitions to 'accepted'
--                                     -> notify the supplier (kind='rfq_bid_accepted').
--
-- Design notes:
--   - All trigger functions are SECURITY DEFINER with `set search_path` to a
--     fixed list, so they can INSERT into public.notifications regardless of
--     the writer's RLS context, and so search_path injection is impossible.
--   - We never notify the actor themselves (sender == recipient is skipped).
--   - We RAISE NOTICE and RETURN NEW cleanly when the recipient cannot be
--     resolved (e.g. cascade-deleted user, mis-shaped row); the underlying
--     INSERT/UPDATE must never roll back due to a notification fan-out issue.
--   - Body strings are length-capped (substring(..., 1, 80)) so they fit a
--     push notification preview without sending the full message.
--   - Per-category mute (#173) and quiet hours (#182) are client-side; the
--     server still inserts the row, the device decides whether to surface a
--     system pop. That is the intended split.
--   - Idempotent: each function is OR REPLACE; each trigger is DROP IF
--     EXISTS + CREATE.
--
-- This migration introduces no new tables or columns.

-- ---------------------------------------------------------------------------
-- 1. chat_messages -> chat_message_new
-- ---------------------------------------------------------------------------
--
-- chat_conversations.participant_user_ids is a uuid[]. Fan out to every
-- participant that is NOT the sender. (1:1 chats today, but the array shape
-- means we are forward-compatible with group chats without a schema change.)

CREATE OR REPLACE FUNCTION public.notify_on_chat_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_participants uuid[];
    v_recipient    uuid;
    v_preview      text;
BEGIN
    -- Look up participants. If the conversation row vanished (cascade delete
    -- race), bail without raising.
    SELECT participant_user_ids INTO v_participants
    FROM public.chat_conversations
    WHERE id = NEW.conversation_id;

    IF v_participants IS NULL OR array_length(v_participants, 1) IS NULL THEN
        RAISE NOTICE 'notify_on_chat_message: no participants for conversation %', NEW.conversation_id;
        RETURN NEW;
    END IF;

    -- Skip soft-deleted/edited replays just in case (deleted_at is set on
    -- delete, but a brand-new INSERT shouldn't have it; defensive).
    IF NEW.deleted_at IS NOT NULL THEN
        RETURN NEW;
    END IF;

    v_preview := substring(coalesce(NEW.message, ''), 1, 80);

    FOR v_recipient IN
        SELECT u
        FROM unnest(v_participants) AS u
        WHERE u IS DISTINCT FROM NEW.sender_user_id
    LOOP
        BEGIN
            INSERT INTO public.notifications (user_id, kind, title, body, data)
            VALUES (
                v_recipient,
                'chat_message_new',
                'New message',
                v_preview,
                jsonb_build_object(
                    'conversation_id', NEW.conversation_id,
                    'sender_user_id',  NEW.sender_user_id,
                    'message_id',      NEW.id
                )
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'notify_on_chat_message: insert failed for %: % / %',
                v_recipient, SQLSTATE, SQLERRM;
        END;
    END LOOP;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_on_chat_message() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_chat_message ON public.chat_messages;
CREATE TRIGGER notify_on_chat_message
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_chat_message();

-- ---------------------------------------------------------------------------
-- 2. repair_job_bids -> repair_bid_new
-- ---------------------------------------------------------------------------
--
-- The repair_jobs row carries hospital_user_id (the owner who posted the
-- job). The bidding engineer is NEW.engineer_user_id. We notify the hospital
-- owner — never the bidder themselves.

CREATE OR REPLACE FUNCTION public.notify_on_repair_bid()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_recipient uuid;
    v_body      text;
BEGIN
    SELECT hospital_user_id INTO v_recipient
    FROM public.repair_jobs
    WHERE id = NEW.repair_job_id;

    IF v_recipient IS NULL THEN
        RAISE NOTICE 'notify_on_repair_bid: no hospital_user_id for job %', NEW.repair_job_id;
        RETURN NEW;
    END IF;

    -- Bidder is the hospital owner? Skip (shouldn't happen but defensive).
    IF v_recipient = NEW.engineer_user_id THEN
        RETURN NEW;
    END IF;

    v_body := concat('Rs ', to_char(NEW.amount_rupees, 'FM999G999G999D00'));

    BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
            v_recipient,
            'repair_bid_new',
            'New bid on your repair',
            v_body,
            jsonb_build_object(
                'repair_job_id',     NEW.repair_job_id,
                'bid_id',            NEW.id,
                'engineer_user_id',  NEW.engineer_user_id,
                'amount_rupees',     NEW.amount_rupees
            )
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'notify_on_repair_bid: insert failed: % / %', SQLSTATE, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_on_repair_bid() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_repair_bid ON public.repair_job_bids;
CREATE TRIGGER notify_on_repair_bid
    AFTER INSERT ON public.repair_job_bids
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_repair_bid();

-- ---------------------------------------------------------------------------
-- 3. spare_part_orders -> order_shipped
-- ---------------------------------------------------------------------------
--
-- Fires only on the durable transition placed/confirmed -> shipped. We do
-- not fire on confirmed -> confirmed, draft state changes, or backwards
-- transitions. Buyer (NEW.buyer_user_id) is the recipient.

CREATE OR REPLACE FUNCTION public.notify_on_order_shipped()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_body text;
BEGIN
    -- Guard: only the placed/confirmed -> shipped edge.
    IF NEW.order_status IS DISTINCT FROM 'shipped'::order_status THEN
        RETURN NEW;
    END IF;
    IF OLD.order_status IS NOT DISTINCT FROM NEW.order_status THEN
        RETURN NEW;
    END IF;
    IF OLD.order_status NOT IN ('placed'::order_status, 'confirmed'::order_status) THEN
        RETURN NEW;
    END IF;
    IF NEW.buyer_user_id IS NULL THEN
        RAISE NOTICE 'notify_on_order_shipped: missing buyer_user_id on order %', NEW.id;
        RETURN NEW;
    END IF;

    v_body := concat(
        'Order ',
        coalesce(NEW.order_number, substring(NEW.id::text, 1, 8)),
        ' is on the way.'
    );

    BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
            NEW.buyer_user_id,
            'order_shipped',
            'Your order has shipped',
            v_body,
            jsonb_build_object(
                'order_id',         NEW.id,
                'order_number',     NEW.order_number,
                'tracking_number',  NEW.tracking_number
            )
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'notify_on_order_shipped: insert failed: % / %', SQLSTATE, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_on_order_shipped() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_order_shipped ON public.spare_part_orders;
CREATE TRIGGER notify_on_order_shipped
    AFTER UPDATE OF order_status ON public.spare_part_orders
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_order_shipped();

-- ---------------------------------------------------------------------------
-- 4. rfq_bids -> rfq_bid_accepted
-- ---------------------------------------------------------------------------
--
-- Resolve the supplier user from manufacturers.organization_id ->
-- profiles.organization_id (any active profile in that org). Pick the
-- organization's `created_by` first if it has a profile (most accurate
-- "owner"); else fall back to the first active profile. If neither
-- resolves, RAISE NOTICE and bail.

CREATE OR REPLACE FUNCTION public.notify_on_rfq_bid_accepted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_org_id     uuid;
    v_recipient  uuid;
    v_rfq_number text;
    v_body       text;
BEGIN
    -- Only on durable transition to 'accepted'.
    IF NEW.status IS DISTINCT FROM 'accepted' THEN
        RETURN NEW;
    END IF;
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;

    SELECT organization_id INTO v_org_id
    FROM public.manufacturers
    WHERE id = NEW.manufacturer_id;

    IF v_org_id IS NULL THEN
        RAISE NOTICE 'notify_on_rfq_bid_accepted: manufacturer % has no organization_id', NEW.manufacturer_id;
        RETURN NEW;
    END IF;

    -- Prefer the organization's creator if they still own a profile in that org.
    SELECT p.id INTO v_recipient
    FROM public.organizations o
    JOIN public.profiles p
      ON p.id = o.created_by
     AND p.organization_id = o.id
     AND coalesce(p.is_active, true) = true
    WHERE o.id = v_org_id
    LIMIT 1;

    -- Fallback: any active profile attached to this org.
    IF v_recipient IS NULL THEN
        SELECT p.id INTO v_recipient
        FROM public.profiles p
        WHERE p.organization_id = v_org_id
          AND coalesce(p.is_active, true) = true
        ORDER BY p.created_at ASC
        LIMIT 1;
    END IF;

    IF v_recipient IS NULL THEN
        RAISE NOTICE 'notify_on_rfq_bid_accepted: no active user for org %', v_org_id;
        RETURN NEW;
    END IF;

    SELECT rfq_number INTO v_rfq_number
    FROM public.rfqs
    WHERE id = NEW.rfq_id;

    v_body := concat(
        'Your bid on RFQ ',
        coalesce(v_rfq_number, substring(NEW.rfq_id::text, 1, 8)),
        ' was accepted.'
    );

    BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
            v_recipient,
            'rfq_bid_accepted',
            'Your bid was accepted',
            v_body,
            jsonb_build_object(
                'rfq_id',          NEW.rfq_id,
                'rfq_bid_id',      NEW.id,
                'manufacturer_id', NEW.manufacturer_id,
                'total_price',     NEW.total_price
            )
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'notify_on_rfq_bid_accepted: insert failed: % / %', SQLSTATE, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_on_rfq_bid_accepted() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_rfq_bid_accepted ON public.rfq_bids;
CREATE TRIGGER notify_on_rfq_bid_accepted
    AFTER UPDATE OF status ON public.rfq_bids
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_on_rfq_bid_accepted();
