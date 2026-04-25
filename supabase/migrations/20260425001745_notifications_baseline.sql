-- Notifications inbox baseline.
--
-- Goal: turn the existing `public.notifications` table into a proper
-- read-side feed for the Android app's Notifications inbox.
--   - Add a free-form `data jsonb` column carrying deep-link metadata
--     (kind, route, ids), so the client can navigate without us hard-coding
--     a column per future surface.
--   - Add a `kind` text column so the server-side push code can tag rows
--     consistently (order_status, bid_received, message_received, ...).
--     Older rows already use `notification_type`; we keep both during the
--     transition and the client falls back to either.
--   - Make the table realtime-publishable so the inbox can stream inserts
--     and read-state changes without polling.
--   - Tighten the UPDATE policy so users can only mark their own rows read
--     (i.e. flip `read_at` / `is_read` from null/false to a value); they
--     must not be able to edit title/body/user_id/etc. Insert is server-
--     controlled (admin or self-targeted only); we leave the existing
--     policy alone since it's already (auth.uid() = user_id OR is_admin).
--
-- Idempotent: every change uses IF NOT EXISTS / DO blocks so the migration
-- can be re-run safely on a partially-applied environment.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS data jsonb;

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS kind text;

-- ---------------------------------------------------------------------------
-- Indexes (cheap; SELECT path is `user_id` + ordering by sent_at desc)
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_notifications_user_sent_at
    ON public.notifications (user_id, sent_at DESC);

-- ---------------------------------------------------------------------------
-- UPDATE guard: only `read_at` and `is_read` may change from a client UPDATE.
-- The RLS policy alone can't enforce per-column immutability, so we layer a
-- trigger on top. Server-side code (SECURITY DEFINER) bypasses RLS but still
-- runs triggers; if needed we can carve an exception by checking session_user.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notifications_guard_user_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Allow the elevated postgres / service_role to update freely (this is
    -- how the server-side send path will set sent_at / kind / data, etc).
    IF current_setting('request.jwt.claims', true) IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.id              IS DISTINCT FROM OLD.id              THEN
        RAISE EXCEPTION 'notifications.id is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.user_id         IS DISTINCT FROM OLD.user_id         THEN
        RAISE EXCEPTION 'notifications.user_id is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.title           IS DISTINCT FROM OLD.title           THEN
        RAISE EXCEPTION 'notifications.title is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.body            IS DISTINCT FROM OLD.body            THEN
        RAISE EXCEPTION 'notifications.body is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.kind            IS DISTINCT FROM OLD.kind            THEN
        RAISE EXCEPTION 'notifications.kind is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.notification_type IS DISTINCT FROM OLD.notification_type THEN
        RAISE EXCEPTION 'notifications.notification_type is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.channel         IS DISTINCT FROM OLD.channel         THEN
        RAISE EXCEPTION 'notifications.channel is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.related_entity_type IS DISTINCT FROM OLD.related_entity_type THEN
        RAISE EXCEPTION 'notifications.related_entity_type is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.related_entity_id   IS DISTINCT FROM OLD.related_entity_id   THEN
        RAISE EXCEPTION 'notifications.related_entity_id is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.action_url      IS DISTINCT FROM OLD.action_url      THEN
        RAISE EXCEPTION 'notifications.action_url is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.data            IS DISTINCT FROM OLD.data            THEN
        RAISE EXCEPTION 'notifications.data is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.sent_at         IS DISTINCT FROM OLD.sent_at         THEN
        RAISE EXCEPTION 'notifications.sent_at is immutable' USING ERRCODE = '42501';
    END IF;

    -- read_at: clients may only set it forward (null -> timestamp). Don't
    -- let them clear it back to null or stamp it in the future.
    IF NEW.read_at IS NULL AND OLD.read_at IS NOT NULL THEN
        RAISE EXCEPTION 'notifications.read_at cannot be cleared' USING ERRCODE = '42501';
    END IF;
    IF NEW.read_at IS NOT NULL AND NEW.read_at > now() + interval '1 minute' THEN
        RAISE EXCEPTION 'notifications.read_at cannot be in the future' USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_guard_user_update ON public.notifications;
CREATE TRIGGER notifications_guard_user_update
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.notifications_guard_user_update();

-- ---------------------------------------------------------------------------
-- Realtime: include the table in the supabase_realtime publication so the
-- Android client can subscribe to inserts + read-state updates. REPLICA
-- IDENTITY FULL gives the client the OLD row on UPDATE / DELETE so the
-- realtime payload includes user_id and read_at for filtering.
-- ---------------------------------------------------------------------------

ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'notifications'
    ) THEN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications';
    END IF;
END;
$$;
