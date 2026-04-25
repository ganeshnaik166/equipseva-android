-- Invoices + Seller verification + listing-type bundle.
--
-- Adds:
--   1. organizations.verification_status + GST/licence columns
--   2. seller_verification_requests table (founder-approved)
--   3. spare_parts.listing_type enum (spare_part | equipment)
--   4. spare_part_orders.invoice_url (already nullable; ensure column)
--   5. Trigger on payment_status='completed' that POSTs to send_invoice edge
--      function via pg_net, mirroring notifications_dispatch_push pattern.
--   6. SECURITY DEFINER RPCs: seller_can_list(uuid),
--      admin_set_org_verification(uuid, text, text).

CREATE EXTENSION IF NOT EXISTS pg_net;

-- ---------------------------------------------------------------------------
-- 0. is_founder() — email-pinned founder check for SECURITY DEFINER RPCs.
-- Mirrors Profile.isFounder() on the client; server-side enforcement uses
-- auth.email() so a client cannot spoof founder identity.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_founder()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT lower(coalesce(nullif(auth.jwt() ->> 'email', ''), '')) = 'ganesh1431.dhanavath@gmail.com';
$$;

GRANT EXECUTE ON FUNCTION public.is_founder() TO authenticated;

-- ---------------------------------------------------------------------------
-- 1. organizations columns
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='organizations'
      AND column_name='verification_status'
  ) THEN
    ALTER TABLE public.organizations
      ADD COLUMN verification_status text NOT NULL DEFAULT 'pending'
        CHECK (verification_status IN ('pending','verified','rejected')),
      ADD COLUMN gst_number text,
      ADD COLUMN gst_certificate_url text,
      ADD COLUMN trade_licence_url text,
      ADD COLUMN licence_expires_at date,
      ADD COLUMN verified_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
      ADD COLUMN verified_at timestamptz,
      ADD COLUMN rejection_reason text;
  END IF;
END$$;

-- Backfill: any organization that has shipped at least one delivered order
-- in the past 90 days is auto-verified so live sellers don't get gated.
UPDATE public.organizations o
SET verification_status='verified', verified_at=now()
WHERE o.verification_status='pending'
  AND EXISTS (
    SELECT 1 FROM public.spare_part_orders s
    WHERE s.supplier_org_id = o.id
      AND s.order_status = 'delivered'
      AND s.created_at >= now() - interval '90 days'
  );

-- ---------------------------------------------------------------------------
-- 2. seller_verification_requests
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.seller_verification_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  submitted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  gst_number text NOT NULL,
  gst_certificate_url text,
  trade_licence_url text NOT NULL,
  licence_expires_at date,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  rejection_reason text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_seller_verification_requests_status
  ON public.seller_verification_requests(status, submitted_at DESC);

ALTER TABLE public.seller_verification_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owners read own verification" ON public.seller_verification_requests;
CREATE POLICY "owners read own verification"
  ON public.seller_verification_requests
  FOR SELECT
  TO authenticated
  USING (
    submitted_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id=auth.uid() AND p.organization_id=seller_verification_requests.organization_id
    )
  );

DROP POLICY IF EXISTS "owners insert own verification" ON public.seller_verification_requests;
CREATE POLICY "owners insert own verification"
  ON public.seller_verification_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    submitted_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id=auth.uid() AND p.organization_id=organization_id
    )
  );

-- ---------------------------------------------------------------------------
-- 3. spare_parts.listing_type
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='spare_parts'
      AND column_name='listing_type'
  ) THEN
    ALTER TABLE public.spare_parts
      ADD COLUMN listing_type text NOT NULL DEFAULT 'spare_part'
        CHECK (listing_type IN ('spare_part','equipment'));
    CREATE INDEX idx_spare_parts_listing_type
      ON public.spare_parts(listing_type);
  END IF;
END$$;

-- Re-tighten INSERT policy: org must be verified.
DROP POLICY IF EXISTS "Suppliers can manage parts" ON public.spare_parts;
DROP POLICY IF EXISTS "verified suppliers can insert parts" ON public.spare_parts;
CREATE POLICY "verified suppliers can insert parts"
  ON public.spare_parts
  FOR INSERT
  TO authenticated
  WITH CHECK (
    supplier_org_id IN (
      SELECT p.organization_id
      FROM public.profiles p
      JOIN public.organizations o ON o.id=p.organization_id
      WHERE p.id=auth.uid()
        AND p.organization_id IS NOT NULL
        AND o.verification_status='verified'
    )
  );

DROP POLICY IF EXISTS "verified suppliers can update own parts" ON public.spare_parts;
CREATE POLICY "verified suppliers can update own parts"
  ON public.spare_parts
  FOR UPDATE
  TO authenticated
  USING (
    supplier_org_id IN (
      SELECT p.organization_id FROM public.profiles p
      WHERE p.id=auth.uid() AND p.organization_id IS NOT NULL
    )
  )
  WITH CHECK (
    supplier_org_id IN (
      SELECT p.organization_id
      FROM public.profiles p
      JOIN public.organizations o ON o.id=p.organization_id
      WHERE p.id=auth.uid()
        AND p.organization_id IS NOT NULL
        AND o.verification_status='verified'
    )
  );

-- ---------------------------------------------------------------------------
-- 4. spare_part_orders.invoice_url (idempotent)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='spare_part_orders'
      AND column_name='invoice_url'
  ) THEN
    ALTER TABLE public.spare_part_orders ADD COLUMN invoice_url text;
  END IF;
END$$;

-- ---------------------------------------------------------------------------
-- 5. Invoice dispatch trigger
-- ---------------------------------------------------------------------------

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
    -- Only fire when payment_status flips TO 'completed'.
    IF NEW.payment_status IS DISTINCT FROM 'completed' THEN
        RETURN NEW;
    END IF;
    IF OLD.payment_status = 'completed' THEN
        RETURN NEW;
    END IF;

    v_url := current_setting('app.invoice_webhook_url', true);
    v_secret := current_setting('app.invoice_webhook_secret', true);

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

DROP TRIGGER IF EXISTS dispatch_invoice ON public.spare_part_orders;
CREATE TRIGGER dispatch_invoice
  AFTER UPDATE OF payment_status ON public.spare_part_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.spare_part_orders_dispatch_invoice();

-- ---------------------------------------------------------------------------
-- 6. RPCs
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.seller_can_list(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.organizations o ON o.id=p.organization_id
    WHERE p.id=p_user_id
      AND p.organization_id IS NOT NULL
      AND o.verification_status='verified'
  );
$$;

GRANT EXECUTE ON FUNCTION public.seller_can_list(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_org_verification(
    p_org_id uuid,
    p_status text,
    p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  IF p_status NOT IN ('pending','verified','rejected') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023';
  END IF;
  UPDATE public.organizations
  SET verification_status=p_status,
      verified_by=auth.uid(),
      verified_at=CASE WHEN p_status='verified' THEN now() ELSE verified_at END,
      rejection_reason=CASE WHEN p_status='rejected' THEN p_reason ELSE NULL END
  WHERE id=p_org_id;

  UPDATE public.seller_verification_requests
  SET status=CASE p_status WHEN 'verified' THEN 'approved' ELSE p_status END,
      rejection_reason=CASE WHEN p_status='rejected' THEN p_reason ELSE NULL END,
      reviewed_at=now(),
      reviewed_by=auth.uid()
  WHERE organization_id=p_org_id AND status='pending';
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_org_verification(uuid, text, text) TO authenticated;
