BEGIN;

-- ============================================================
-- r1484 — Engineer Second-Life Equipment Intel
-- Log hospital end-of-life equipment that engineers find
-- redeployable to smaller hospitals; broker-fee ladder;
-- refurb cost; resale tracking.
-- ============================================================

-- ---------- Table 1: source listings -----------------------
CREATE TABLE IF NOT EXISTS second_life_equipment_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  logged_by_engineer_id uuid NOT NULL REFERENCES engineers(id),
  source_hospital_org_id uuid REFERENCES organizations(id),
  equipment_category text NOT NULL,
  equipment_model text NOT NULL,
  manufacturer text,
  age_years int CHECK (age_years >= 0 AND age_years <= 40),
  condition_grade text NOT NULL CHECK (condition_grade IN ('a','b','c','d')),
  redeployable boolean NOT NULL DEFAULT true,
  est_resale_rupees int NOT NULL DEFAULT 0,
  est_refurb_cost_rupees int NOT NULL DEFAULT 0,
  broker_fee_tier text NOT NULL DEFAULT 't1' CHECK (broker_fee_tier IN ('t1','t2','t3','t4')),
  broker_fee_pct numeric(5,2) NOT NULL DEFAULT 5.00,
  status text NOT NULL DEFAULT 'logged' CHECK (status IN ('logged','listed','negotiating','sold','withdrawn','scrapped')),
  notes text,
  logged_at timestamptz NOT NULL DEFAULT now(),
  listed_at timestamptz,
  sold_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_sle_listings_status ON second_life_equipment_listings(status);
CREATE INDEX IF NOT EXISTS idx_sle_listings_logged_at ON second_life_equipment_listings(logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_sle_listings_engineer ON second_life_equipment_listings(logged_by_engineer_id);
CREATE INDEX IF NOT EXISTS idx_sle_listings_category ON second_life_equipment_listings(equipment_category);

ALTER TABLE second_life_equipment_listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sle_listings_founder_all ON second_life_equipment_listings;
CREATE POLICY sle_listings_founder_all ON second_life_equipment_listings
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- Table 2: resale transactions -------------------
CREATE TABLE IF NOT EXISTS second_life_equipment_resales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES second_life_equipment_listings(id) ON DELETE CASCADE,
  buyer_hospital_org_id uuid REFERENCES organizations(id),
  buyer_hospital_label text,
  sale_price_rupees int NOT NULL,
  refurb_cost_actual_rupees int NOT NULL DEFAULT 0,
  broker_fee_rupees int NOT NULL DEFAULT 0,
  engineer_commission_rupees int NOT NULL DEFAULT 0,
  net_margin_rupees int NOT NULL DEFAULT 0,
  sold_at timestamptz NOT NULL DEFAULT now(),
  warranty_months int DEFAULT 3,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_sle_resales_listing ON second_life_equipment_resales(listing_id);
CREATE INDEX IF NOT EXISTS idx_sle_resales_sold_at ON second_life_equipment_resales(sold_at DESC);

ALTER TABLE second_life_equipment_resales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sle_resales_founder_all ON second_life_equipment_resales;
CREATE POLICY sle_resales_founder_all ON second_life_equipment_resales
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

-- 1) summary KPIs
CREATE OR REPLACE FUNCTION founder_sle_summary()
RETURNS TABLE (
  total_listings bigint,
  active_listings bigint,
  sold_listings bigint,
  total_resale_rupees bigint,
  total_net_margin_rupees bigint,
  avg_broker_fee_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM second_life_equipment_listings),
    (SELECT count(*) FROM second_life_equipment_listings WHERE status IN ('logged','listed','negotiating')),
    (SELECT count(*) FROM second_life_equipment_listings WHERE status = 'sold'),
    COALESCE((SELECT sum(sale_price_rupees) FROM second_life_equipment_resales), 0)::bigint,
    COALESCE((SELECT sum(net_margin_rupees) FROM second_life_equipment_resales), 0)::bigint,
    COALESCE((SELECT avg(broker_fee_pct) FROM second_life_equipment_listings), 0)::numeric;
END;
$$;

-- 2) listings list
CREATE OR REPLACE FUNCTION founder_sle_list_listings(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  equipment_category text,
  equipment_model text,
  condition_grade text,
  status text,
  est_resale_rupees int,
  est_refurb_cost_rupees int,
  broker_fee_tier text,
  broker_fee_pct numeric,
  logged_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.equipment_category, l.equipment_model, l.condition_grade,
         l.status, l.est_resale_rupees, l.est_refurb_cost_rupees,
         l.broker_fee_tier, l.broker_fee_pct, l.logged_at
  FROM second_life_equipment_listings l
  ORDER BY l.logged_at DESC
  LIMIT p_limit;
END;
$$;

-- 3) resales list
CREATE OR REPLACE FUNCTION founder_sle_list_resales(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  listing_id uuid,
  equipment_model text,
  buyer_hospital_label text,
  sale_price_rupees int,
  refurb_cost_actual_rupees int,
  broker_fee_rupees int,
  engineer_commission_rupees int,
  net_margin_rupees int,
  sold_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.listing_id, l.equipment_model, r.buyer_hospital_label,
         r.sale_price_rupees, r.refurb_cost_actual_rupees,
         r.broker_fee_rupees, r.engineer_commission_rupees,
         r.net_margin_rupees, r.sold_at
  FROM second_life_equipment_resales r
  JOIN second_life_equipment_listings l ON l.id = r.listing_id
  ORDER BY r.sold_at DESC
  LIMIT p_limit;
END;
$$;

-- 4) by category
CREATE OR REPLACE FUNCTION founder_sle_by_category()
RETURNS TABLE (
  equipment_category text,
  listings_count bigint,
  sold_count bigint,
  total_resale_rupees bigint,
  total_net_margin_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.equipment_category,
         count(*)::bigint,
         count(*) FILTER (WHERE l.status='sold')::bigint,
         COALESCE(sum(r.sale_price_rupees),0)::bigint,
         COALESCE(sum(r.net_margin_rupees),0)::bigint
  FROM second_life_equipment_listings l
  LEFT JOIN second_life_equipment_resales r ON r.listing_id = l.id
  GROUP BY l.equipment_category
  ORDER BY count(*) DESC;
END;
$$;

-- 5) broker fee ladder
CREATE OR REPLACE FUNCTION founder_sle_broker_ladder()
RETURNS TABLE (
  broker_fee_tier text,
  listings_count bigint,
  avg_broker_fee_pct numeric,
  total_broker_fee_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.broker_fee_tier,
         count(*)::bigint,
         COALESCE(avg(l.broker_fee_pct),0)::numeric,
         COALESCE(sum(r.broker_fee_rupees),0)::bigint
  FROM second_life_equipment_listings l
  LEFT JOIN second_life_equipment_resales r ON r.listing_id = l.id
  GROUP BY l.broker_fee_tier
  ORDER BY l.broker_fee_tier;
END;
$$;

-- 6) top engineers
CREATE OR REPLACE FUNCTION founder_sle_top_engineers(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_id uuid,
  engineer_name text,
  listings_count bigint,
  sold_count bigint,
  total_commission_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id,
         COALESCE(p.full_name, 'unknown') AS engineer_name,
         count(l.id)::bigint,
         count(l.id) FILTER (WHERE l.status='sold')::bigint,
         COALESCE(sum(r.engineer_commission_rupees),0)::bigint
  FROM second_life_equipment_listings l
  JOIN engineers e ON e.id = l.logged_by_engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN second_life_equipment_resales r ON r.listing_id = l.id
  GROUP BY e.id, p.full_name
  ORDER BY count(l.id) DESC
  LIMIT p_limit;
END;
$$;

-- 7) monthly trend
CREATE OR REPLACE FUNCTION founder_sle_monthly_trend()
RETURNS TABLE (
  month_start date,
  listings_count bigint,
  sold_count bigint,
  total_resale_rupees bigint,
  total_net_margin_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', l.logged_at)::date,
         count(*)::bigint,
         count(*) FILTER (WHERE l.status='sold')::bigint,
         COALESCE(sum(r.sale_price_rupees),0)::bigint,
         COALESCE(sum(r.net_margin_rupees),0)::bigint
  FROM second_life_equipment_listings l
  LEFT JOIN second_life_equipment_resales r ON r.listing_id = l.id
  GROUP BY date_trunc('month', l.logged_at)
  ORDER BY date_trunc('month', l.logged_at) DESC
  LIMIT 12;
END;
$$;

-- ============================================================
-- WRITE helpers (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_sle_listing(
  p_engineer_id uuid,
  p_equipment_category text,
  p_equipment_model text,
  p_condition_grade text,
  p_est_resale_rupees int,
  p_est_refurb_cost_rupees int,
  p_broker_fee_tier text,
  p_broker_fee_pct numeric
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO second_life_equipment_listings(
    logged_by_engineer_id, equipment_category, equipment_model,
    condition_grade, est_resale_rupees, est_refurb_cost_rupees,
    broker_fee_tier, broker_fee_pct
  ) VALUES (
    p_engineer_id, p_equipment_category, p_equipment_model,
    p_condition_grade, p_est_resale_rupees, p_est_refurb_cost_rupees,
    p_broker_fee_tier, p_broker_fee_pct
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_sle_status_change(
  p_listing_id uuid,
  p_new_status text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE second_life_equipment_listings
     SET status = p_new_status,
         listed_at = CASE WHEN p_new_status='listed' AND listed_at IS NULL THEN now() ELSE listed_at END,
         sold_at   = CASE WHEN p_new_status='sold'   AND sold_at   IS NULL THEN now() ELSE sold_at   END
   WHERE id = p_listing_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_sle_resale(
  p_listing_id uuid,
  p_buyer_label text,
  p_sale_price_rupees int,
  p_refurb_cost_actual_rupees int,
  p_broker_fee_rupees int,
  p_engineer_commission_rupees int
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid; v_net int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_net := p_sale_price_rupees - p_refurb_cost_actual_rupees - p_broker_fee_rupees - p_engineer_commission_rupees;
  INSERT INTO second_life_equipment_resales(
    listing_id, buyer_hospital_label, sale_price_rupees,
    refurb_cost_actual_rupees, broker_fee_rupees,
    engineer_commission_rupees, net_margin_rupees
  ) VALUES (
    p_listing_id, p_buyer_label, p_sale_price_rupees,
    p_refurb_cost_actual_rupees, p_broker_fee_rupees,
    p_engineer_commission_rupees, v_net
  ) RETURNING id INTO v_id;
  UPDATE second_life_equipment_listings SET status='sold', sold_at=now() WHERE id = p_listing_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_sle_withdraw(p_listing_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE second_life_equipment_listings SET status='withdrawn' WHERE id = p_listing_id;
END;
$$;

-- ============================================================
-- GRANTs — REVOKE all then GRANT to authenticated only
-- ============================================================

REVOKE EXECUTE ON FUNCTION founder_sle_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_sle_summary() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_sle_list_listings(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_sle_list_listings(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_sle_list_resales(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_sle_list_resales(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_sle_by_category() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_sle_by_category() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_sle_broker_ladder() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_sle_broker_ladder() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_sle_top_engineers(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_sle_top_engineers(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_sle_monthly_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_sle_monthly_trend() TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_sle_listing(uuid,text,text,text,int,int,text,numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_sle_listing(uuid,text,text,text,int,int,text,numeric) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_sle_status_change(uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_sle_status_change(uuid,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_sle_resale(uuid,text,int,int,int,int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_sle_resale(uuid,text,int,int,int,int) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_sle_withdraw(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_sle_withdraw(uuid) TO authenticated;

COMMIT;