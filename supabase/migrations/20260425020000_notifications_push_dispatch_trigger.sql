-- Server-side push send rules (PENDING.md #36).
--
-- Fan-out FCM delivery for every row inserted into `public.notifications`.
-- The actual HTTP call to FCM happens inside the `send_push_notification`
-- Edge Function; this migration wires the DB trigger that posts the new row
-- (in Supabase DB-webhook payload shape) to that function via `pg_net`.
--
-- Why a SQL trigger and not a Supabase Dashboard webhook:
--   1. Reproducible across environments (preview / staging / prod) under
--      `supabase db push` — no out-of-band UI step that drifts.
--   2. Survives a project re-link or restore.
--   3. Lets us version-control the auth header alongside the payload shape.
--
-- Configuration:
--   Two GUCs must be set on the Postgres role (run from the SQL editor or a
--   one-off psql session, not committed to git):
--
--     ALTER DATABASE postgres SET app.push_webhook_url =
--       'https://<project-ref>.supabase.co/functions/v1/send_push_notification';
--     ALTER DATABASE postgres SET app.push_webhook_secret =
--       '<long-random-string>';
--
--   The same secret value must be passed to the Edge Function as the
--   `PUSH_WEBHOOK_SECRET` env var via `supabase secrets set`. If either GUC
--   is unset, the trigger no-ops (notification still inserts cleanly — we
--   never want a missing webhook config to break the inbox write path).
--
-- Required extension: `pg_net` (Supabase-managed). It creates and owns the
-- `net` schema where `net.http_post` lives.

-- ---------------------------------------------------------------------------
-- Extension
-- ---------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_net;

-- ---------------------------------------------------------------------------
-- Trigger function
-- ---------------------------------------------------------------------------
--
-- Posts a Supabase-DB-webhook-shaped payload to the configured edge function.
-- We deliberately do NOT block the INSERT on the HTTP call: `net.http_post`
-- is async (returns a request id immediately; the response lands in
-- `net._http_response`). If the edge function is down the original
-- `INSERT INTO notifications` still commits — the inbox write is sacred.

CREATE OR REPLACE FUNCTION public.notifications_dispatch_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net, pg_temp
AS $$
DECLARE
    v_url text;
    v_secret text;
    v_payload jsonb;
BEGIN
    v_url := current_setting('app.push_webhook_url', true);
    v_secret := current_setting('app.push_webhook_secret', true);

    -- No-op if the deploy hasn't wired the GUCs yet. We still want the inbox
    -- INSERT to succeed; pushes can be back-filled by a manual replay later.
    IF v_url IS NULL OR v_url = '' OR v_secret IS NULL OR v_secret = '' THEN
        RETURN NEW;
    END IF;

    v_payload := jsonb_build_object(
        'type',   'INSERT',
        'table',  TG_TABLE_NAME,
        'schema', TG_TABLE_SCHEMA,
        'record', to_jsonb(NEW),
        'old_record', NULL
    );

    PERFORM net.http_post(
        url      := v_url,
        body     := v_payload,
        headers  := jsonb_build_object(
            'Content-Type',     'application/json',
            'x-webhook-secret', v_secret
        ),
        timeout_milliseconds := 5000
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Defensive: never let a webhook problem rollback the notifications row.
    -- Surface the error in Postgres logs and return.
    RAISE WARNING 'notifications_dispatch_push failed: % / %', SQLSTATE, SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notifications_dispatch_push() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Trigger
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS notifications_dispatch_push ON public.notifications;
CREATE TRIGGER notifications_dispatch_push
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.notifications_dispatch_push();
