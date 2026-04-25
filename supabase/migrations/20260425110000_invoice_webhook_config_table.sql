-- Replaces GUC-based invoice webhook config with a tiny internal config table.
--
-- Why: ALTER DATABASE postgres SET requires superuser, which neither the
-- Supabase MCP nor `supabase db push` get. An RLS-locked table that only
-- SECURITY DEFINER functions can read is a safe substitute.

CREATE TABLE IF NOT EXISTS public._app_invoice_config (
  id text PRIMARY KEY DEFAULT 'singleton',
  webhook_url text NOT NULL,
  webhook_secret text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (id = 'singleton')
);

ALTER TABLE public._app_invoice_config ENABLE ROW LEVEL SECURITY;
-- Deliberately no policies; RLS denies every caller. Only SECURITY DEFINER
-- functions (running as the table owner) read this table.

REVOKE ALL ON TABLE public._app_invoice_config FROM PUBLIC, authenticated, anon;

-- Trigger reads url + secret from the config table instead of GUCs.
CREATE OR REPLACE FUNCTION public.spare_part_orders_dispatch_invoice()
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
    IF NEW.payment_status IS DISTINCT FROM 'completed' THEN
        RETURN NEW;
    END IF;
    IF OLD.payment_status = 'completed' THEN
        RETURN NEW;
    END IF;

    SELECT webhook_url, webhook_secret
      INTO v_url, v_secret
      FROM public._app_invoice_config
     WHERE id='singleton'
     LIMIT 1;

    IF v_url IS NULL OR v_url='' OR v_secret IS NULL OR v_secret='' THEN
        RETURN NEW;
    END IF;

    v_payload := jsonb_build_object(
        'type','UPDATE',
        'table',TG_TABLE_NAME,
        'schema',TG_TABLE_SCHEMA,
        'record', to_jsonb(NEW),
        'old_record', to_jsonb(OLD)
    );

    PERFORM net.http_post(
        url := v_url,
        body := v_payload,
        headers := jsonb_build_object(
            'Content-Type','application/json',
            'x-webhook-secret', v_secret
        ),
        timeout_milliseconds := 8000
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'spare_part_orders_dispatch_invoice failed: % / %', SQLSTATE, SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.spare_part_orders_dispatch_invoice() FROM PUBLIC;

-- Note: webhook_url + webhook_secret rows are seeded out-of-band (NOT in this
-- migration) so the secret never lands in version control. To rotate, run:
--   INSERT INTO public._app_invoice_config (id, webhook_url, webhook_secret)
--   VALUES ('singleton', '<edge-fn-url>', '<32-byte-hex-secret>')
--   ON CONFLICT (id) DO UPDATE
--   SET webhook_url=EXCLUDED.webhook_url,
--       webhook_secret=EXCLUDED.webhook_secret,
--       updated_at=now();
-- Then set the same value as INVOICE_WEBHOOK_SECRET on the edge function env.
