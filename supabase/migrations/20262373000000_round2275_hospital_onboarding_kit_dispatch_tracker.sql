BEGIN;

-- ============================================================
-- r2275: Hospital onboarding kit dispatch tracker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_onboarding_kits_r2275 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  city text NOT NULL,
  signed_at timestamptz NOT NULL DEFAULT now(),
  kit_tier text NOT NULL CHECK (kit_tier IN ('starter','pro','enterprise')),
  kit_components jsonb NOT NULL DEFAULT '[]'::jsonb,
  total_components_count int NOT NULL DEFAULT 0,
  dispatch_status text NOT NULL DEFAULT 'pending'
    CHECK (dispatch_status IN ('pending','packed','dispatched','in_transit','delivered','received_confirmed','delayed','lost')),
  courier_partner text,
  tracking_number text,
  dispatched_at timestamptz,
  estimated_delivery_at timestamptz,
  delivered_at timestamptz,
  receipt_confirmed_at timestamptz,
  receipt_confirmed_by_email text,
  delay_reason text,
  delay_hours int NOT NULL DEFAULT 0,
  kit_value_rupees int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kits_r2275_status ON public.hospital_onboarding_kits_r2275(dispatch_status);
CREATE INDEX IF NOT EXISTS idx_kits_r2275_signed ON public.hospital_onboarding_kits_r2275(signed_at DESC);
CREATE INDEX IF NOT EXISTS idx_kits_r2275_hospital ON public.hospital_onboarding_kits_r2275(hospital_user_id);

ALTER TABLE public.hospital_onboarding_kits_r2275 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_onboarding_kits_r2275;
CREATE POLICY founder_all ON public.hospital_onboarding_kits_r2275
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_onboarding_kit_events_r2275 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kit_id uuid NOT NULL REFERENCES public.hospital_onboarding_kits_r2275(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('packed','dispatched','scan','delay','delivered','receipt_confirmed','lost','reassigned')),
  event_at timestamptz NOT NULL DEFAULT now(),
  location text,
  actor_email text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kit_events_r2275_kit ON public.hospital_onboarding_kit_events_r2275(kit_id, event_at DESC);

ALTER TABLE public.hospital_onboarding_kit_events_r2275 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_onboarding_kit_events_r2275;
CREATE POLICY founder_all ON public.hospital_onboarding_kit_events_r2275
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seed data
-- ============================================================

DO $$
DECLARE
  h1 uuid;
  h2 uuid;
  h3 uuid;
  h4 uuid;
  h5 uuid;
  h6 uuid;
  k1 uuid;
  k2 uuid;
  k3 uuid;
  k4 uuid;
  k5 uuid;
  k6 uuid;
BEGIN
  SELECT id INTO h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(h1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(h2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO h4 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(h2, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(h3, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO h5 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO h6 FROM public.profiles WHERE role = 'engineer' ORDER BY created_at LIMIT 1;

  h1 := COALESCE(h1, h6);
  h2 := COALESCE(h2, h6);
  h3 := COALESCE(h3, h6);
  h4 := COALESCE(h4, h6);
  h5 := COALESCE(h5, h6);

  IF h1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.hospital_onboarding_kits_r2275 (hospital_user_id, hospital_name, city, signed_at, kit_tier, kit_components, total_components_count, dispatch_status, courier_partner, tracking_number, dispatched_at, estimated_delivery_at, delivered_at, receipt_confirmed_at, receipt_confirmed_by_email, kit_value_rupees, notes)
  VALUES (h1, 'Apollo Hyderabad', 'Hyderabad', now() - interval '14 days', 'enterprise',
    '[{"item":"Welcome pack","qty":1},{"item":"Service tags","qty":50},{"item":"Tablet kiosk","qty":1},{"item":"QR stickers","qty":100}]'::jsonb,
    4, 'received_confirmed', 'Bluedart', 'BD7234561289', now() - interval '10 days', now() - interval '7 days', now() - interval '7 days', now() - interval '6 days', 'admin@apollo-hyd.example', 24500, 'Smooth dispatch')
  RETURNING id INTO k1;

  INSERT INTO public.hospital_onboarding_kits_r2275 (hospital_user_id, hospital_name, city, signed_at, kit_tier, kit_components, total_components_count, dispatch_status, courier_partner, tracking_number, dispatched_at, estimated_delivery_at, delivered_at, kit_value_rupees, notes)
  VALUES (h2, 'KIMS Secunderabad', 'Secunderabad', now() - interval '10 days', 'pro',
    '[{"item":"Welcome pack","qty":1},{"item":"Service tags","qty":30},{"item":"QR stickers","qty":50}]'::jsonb,
    3, 'delivered', 'DTDC', 'DT9988776655', now() - interval '6 days', now() - interval '4 days', now() - interval '3 days', 14200, 'Awaiting receipt confirmation')
  RETURNING id INTO k2;

  INSERT INTO public.hospital_onboarding_kits_r2275 (hospital_user_id, hospital_name, city, signed_at, kit_tier, kit_components, total_components_count, dispatch_status, courier_partner, tracking_number, dispatched_at, estimated_delivery_at, delay_reason, delay_hours, kit_value_rupees, notes)
  VALUES (h3, 'Yashoda Somajiguda', 'Hyderabad', now() - interval '8 days', 'pro',
    '[{"item":"Welcome pack","qty":1},{"item":"Service tags","qty":30}]'::jsonb,
    2, 'delayed', 'Bluedart', 'BD8765432198', now() - interval '5 days', now() - interval '2 days', 'Courier hub congestion in Hyderabad', 36, 12000, 'Escalated to courier')
  RETURNING id INTO k3;

  INSERT INTO public.hospital_onboarding_kits_r2275 (hospital_user_id, hospital_name, city, signed_at, kit_tier, kit_components, total_components_count, dispatch_status, courier_partner, tracking_number, dispatched_at, estimated_delivery_at, kit_value_rupees, notes)
  VALUES (h4, 'Continental Gachibowli', 'Hyderabad', now() - interval '4 days', 'starter',
    '[{"item":"Welcome pack","qty":1},{"item":"Service tags","qty":15}]'::jsonb,
    2, 'in_transit', 'DTDC', 'DT2233445566', now() - interval '2 days', now() + interval '1 day', 7800, NULL)
  RETURNING id INTO k4;

  INSERT INTO public.hospital_onboarding_kits_r2275 (hospital_user_id, hospital_name, city, signed_at, kit_tier, kit_components, total_components_count, dispatch_status, kit_value_rupees, notes)
  VALUES (h5, 'Sunshine Begumpet', 'Hyderabad', now() - interval '2 days', 'starter',
    '[{"item":"Welcome pack","qty":1},{"item":"Service tags","qty":15}]'::jsonb,
    2, 'pending', 7800, 'Packing scheduled tomorrow')
  RETURNING id INTO k5;

  INSERT INTO public.hospital_onboarding_kits_r2275 (hospital_user_id, hospital_name, city, signed_at, kit_tier, kit_components, total_components_count, dispatch_status, courier_partner, tracking_number, dispatched_at, kit_value_rupees, notes)
  VALUES (h1, 'AIG Mindspace', 'Hyderabad', now() - interval '1 day', 'enterprise',
    '[{"item":"Welcome pack","qty":1},{"item":"Tablet kiosk","qty":1},{"item":"Service tags","qty":50},{"item":"QR stickers","qty":100}]'::jsonb,
    4, 'packed', NULL, NULL, NULL, 24500, 'Packed, awaiting courier pickup')
  RETURNING id INTO k6;

  -- Event log
  INSERT INTO public.hospital_onboarding_kit_events_r2275 (kit_id, event_type, event_at, location, actor_email, notes) VALUES
    (k1, 'packed', now() - interval '11 days', 'Hyderabad warehouse', 'ops@equipseva.com', 'Packed enterprise kit'),
    (k1, 'dispatched', now() - interval '10 days', 'Hyderabad warehouse', 'ops@equipseva.com', 'Handed to Bluedart'),
    (k1, 'delivered', now() - interval '7 days', 'Apollo Hyderabad', 'courier@bluedart.example', 'Signed at reception'),
    (k1, 'receipt_confirmed', now() - interval '6 days', 'Apollo Hyderabad', 'admin@apollo-hyd.example', 'Hospital admin confirmed receipt');

  INSERT INTO public.hospital_onboarding_kit_events_r2275 (kit_id, event_type, event_at, location, actor_email, notes) VALUES
    (k2, 'packed', now() - interval '7 days', 'Hyderabad warehouse', 'ops@equipseva.com', NULL),
    (k2, 'dispatched', now() - interval '6 days', 'Hyderabad warehouse', 'ops@equipseva.com', NULL),
    (k2, 'delivered', now() - interval '3 days', 'KIMS Secunderabad', 'courier@dtdc.example', 'Reception accepted');

  INSERT INTO public.hospital_onboarding_kit_events_r2275 (kit_id, event_type, event_at, location, actor_email, notes) VALUES
    (k3, 'packed', now() - interval '6 days', 'Hyderabad warehouse', 'ops@equipseva.com', NULL),
    (k3, 'dispatched', now() - interval '5 days', 'Hyderabad warehouse', 'ops@equipseva.com', NULL),
    (k3, 'delay', now() - interval '2 days', 'Bluedart hub Hyderabad', 'support@bluedart.example', 'Hub congestion');

  INSERT INTO public.hospital_onboarding_kit_events_r2275 (kit_id, event_type, event_at, location, actor_email, notes) VALUES
    (k4, 'packed', now() - interval '3 days', 'Hyderabad warehouse', 'ops@equipseva.com', NULL),
    (k4, 'dispatched', now() - interval '2 days', 'Hyderabad warehouse', 'ops@equipseva.com', NULL),
    (k4, 'scan', now() - interval '1 day', 'DTDC Hyderabad sort', 'system@dtdc.example', 'In transit');

  INSERT INTO public.hospital_onboarding_kit_events_r2275 (kit_id, event_type, event_at, actor_email, notes) VALUES
    (k6, 'packed', now() - interval '1 day', 'ops@equipseva.com', 'Packed, awaiting pickup');
END $$;

-- ============================================================
-- RPCs (7) — all is_founder gated, plpgsql, SECURITY DEFINER
-- ============================================================

-- 1. Summary KPIs
CREATE OR REPLACE FUNCTION public.r2275_kit_dispatch_summary()
RETURNS TABLE (
  total_kits int,
  pending_count int,
  in_transit_count int,
  delivered_count int,
  receipt_confirmed_count int,
  delayed_count int,
  lost_count int,
  total_kit_value_rupees bigint,
  avg_delay_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_kits,
    (COUNT(*) FILTER (WHERE dispatch_status = 'pending'))::int,
    (COUNT(*) FILTER (WHERE dispatch_status IN ('dispatched','in_transit')))::int,
    (COUNT(*) FILTER (WHERE dispatch_status = 'delivered'))::int,
    (COUNT(*) FILTER (WHERE dispatch_status = 'received_confirmed'))::int,
    (COUNT(*) FILTER (WHERE dispatch_status = 'delayed'))::int,
    (COUNT(*) FILTER (WHERE dispatch_status = 'lost'))::int,
    COALESCE(SUM(kit_value_rupees), 0)::bigint,
    COALESCE(AVG(delay_hours) FILTER (WHERE delay_hours > 0), 0)::numeric
  FROM public.hospital_onboarding_kits_r2275;
END;
$$;

-- 2. Kit list
CREATE OR REPLACE FUNCTION public.r2275_kit_list()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  city text,
  signed_at timestamptz,
  kit_tier text,
  total_components_count int,
  dispatch_status text,
  courier_partner text,
  tracking_number text,
  dispatched_at timestamptz,
  estimated_delivery_at timestamptz,
  delivered_at timestamptz,
  delay_hours int,
  kit_value_rupees int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.hospital_name, k.city, k.signed_at, k.kit_tier,
         k.total_components_count, k.dispatch_status, k.courier_partner,
         k.tracking_number, k.dispatched_at, k.estimated_delivery_at,
         k.delivered_at, k.delay_hours, k.kit_value_rupees
  FROM public.hospital_onboarding_kits_r2275 k
  ORDER BY k.signed_at DESC;
END;
$$;

-- 3. Delayed kits
CREATE OR REPLACE FUNCTION public.r2275_delayed_kits()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  city text,
  courier_partner text,
  tracking_number text,
  estimated_delivery_at timestamptz,
  delay_hours int,
  delay_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.hospital_name, k.city, k.courier_partner, k.tracking_number,
         k.estimated_delivery_at, k.delay_hours, k.delay_reason
  FROM public.hospital_onboarding_kits_r2275 k
  WHERE k.dispatch_status = 'delayed' OR k.delay_hours > 0
  ORDER BY k.delay_hours DESC;
END;
$$;

-- 4. Receipt pending (delivered but not confirmed)
CREATE OR REPLACE FUNCTION public.r2275_receipt_pending()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  city text,
  delivered_at timestamptz,
  days_since_delivery int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.hospital_name, k.city, k.delivered_at,
         (EXTRACT(epoch FROM (now() - k.delivered_at)) / 86400)::int AS days_since_delivery
  FROM public.hospital_onboarding_kits_r2275 k
  WHERE k.dispatch_status = 'delivered'
    AND k.receipt_confirmed_at IS NULL
  ORDER BY k.delivered_at ASC;
END;
$$;

-- 5. By courier breakdown
CREATE OR REPLACE FUNCTION public.r2275_courier_breakdown()
RETURNS TABLE (
  courier_partner text,
  kit_count int,
  delivered_count int,
  delayed_count int,
  avg_delay_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(k.courier_partner, 'unassigned') AS courier_partner,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE k.dispatch_status IN ('delivered','received_confirmed')))::int,
    (COUNT(*) FILTER (WHERE k.dispatch_status = 'delayed'))::int,
    COALESCE(AVG(k.delay_hours) FILTER (WHERE k.delay_hours > 0), 0)::numeric
  FROM public.hospital_onboarding_kits_r2275 k
  GROUP BY COALESCE(k.courier_partner, 'unassigned')
  ORDER BY (COUNT(*)) DESC;
END;
$$;

-- 6. Component coverage
CREATE OR REPLACE FUNCTION public.r2275_component_coverage()
RETURNS TABLE (
  kit_tier text,
  kit_count int,
  total_components int,
  total_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.kit_tier,
         (COUNT(*))::int,
         COALESCE(SUM(k.total_components_count), 0)::int,
         COALESCE(SUM(k.kit_value_rupees), 0)::bigint
  FROM public.hospital_onboarding_kits_r2275 k
  GROUP BY k.kit_tier
  ORDER BY k.kit_tier;
END;
$$;

-- 7. Recent events
CREATE OR REPLACE FUNCTION public.r2275_recent_events()
RETURNS TABLE (
  id uuid,
  kit_id uuid,
  hospital_name text,
  event_type text,
  event_at timestamptz,
  location text,
  actor_email text,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.kit_id, k.hospital_name, e.event_type, e.event_at,
         e.location, e.actor_email, e.notes
  FROM public.hospital_onboarding_kit_events_r2275 e
  JOIN public.hospital_onboarding_kits_r2275 k ON k.id = e.kit_id
  ORDER BY e.event_at DESC
  LIMIT 50;
END;
$$;

-- Grants
REVOKE ALL ON FUNCTION public.r2275_kit_dispatch_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2275_kit_list() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2275_delayed_kits() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2275_receipt_pending() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2275_courier_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2275_component_coverage() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2275_recent_events() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2275_kit_dispatch_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2275_kit_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2275_delayed_kits() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2275_receipt_pending() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2275_courier_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2275_component_coverage() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2275_recent_events() TO authenticated;

COMMIT;
