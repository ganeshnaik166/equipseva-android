-- v1 ships with marketplace gated off behind AppFeatureFlags. Server still
-- has the order_shipped + rfq_bid_accepted push triggers wired (PR #36),
-- which would push v1 users into routes the v1 nav graph doesn't register.
-- Add a server-side gate via a config flag so the trigger functions no-op
-- until v2 flips marketplace_enabled = true.

ALTER TABLE public._app_admin_config
    ADD COLUMN IF NOT EXISTS marketplace_enabled boolean NOT NULL DEFAULT false;

-- Lightweight reader. SECURITY DEFINER so trigger functions (which run with
-- definer rights themselves) can call it; STABLE so Postgres can cache the
-- read inside the same statement.
CREATE OR REPLACE FUNCTION public.marketplace_enabled()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(
    (SELECT marketplace_enabled FROM public._app_admin_config WHERE id = 'singleton'),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.marketplace_enabled() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.marketplace_enabled() TO authenticated;

-- ---------------------------------------------------------------------------
-- Re-define the two marketplace push trigger functions with an early-return
-- when marketplace is disabled. The notification row is NEVER inserted, so
-- the dispatch trigger doesn't fan out to FCM either — clean kill at the
-- source. Engineer + KYC + chat triggers stay unchanged (always fire).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_on_order_shipped()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_body text;
BEGIN
    -- v1 gate: skip the whole fan-out while marketplace is disabled. Once
    -- the admin flips marketplace_enabled = true, push resumes naturally.
    IF NOT public.marketplace_enabled() THEN
        RETURN NEW;
    END IF;
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
    -- v1 gate: same kill-switch as notify_on_order_shipped.
    IF NOT public.marketplace_enabled() THEN
        RETURN NEW;
    END IF;
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

    SELECT p.id INTO v_recipient
    FROM public.organizations o
    JOIN public.profiles p
      ON p.id = o.created_by
     AND p.organization_id = o.id
     AND coalesce(p.is_active, true) = true
    WHERE o.id = v_org_id
    LIMIT 1;

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
