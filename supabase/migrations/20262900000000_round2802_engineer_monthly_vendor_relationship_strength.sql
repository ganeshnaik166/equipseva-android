BEGIN;

-- ============================================================================
-- Round 2802 — Engineer Monthly Vendor Relationship Strength
-- HEAVY ★★★★ founder console
-- engineer × vendor × interactions × response time × strength × tier action
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: engineer_vendor_relationship_strength_r2802
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_vendor_relationship_strength_r2802 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month                 date NOT NULL,
  engineer_name               text NOT NULL,
  engineer_tier               text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  vendor_name                 text NOT NULL,
  vendor_category             text NOT NULL CHECK (vendor_category IN ('spare_parts','consumables','calibration','tools','logistics')),
  interactions_count          integer NOT NULL CHECK (interactions_count >= 0),
  orders_placed               integer NOT NULL CHECK (orders_placed >= 0),
  orders_fulfilled            integer NOT NULL CHECK (orders_fulfilled >= 0),
  avg_response_minutes        numeric(10,2) NOT NULL CHECK (avg_response_minutes >= 0),
  median_response_minutes     numeric(10,2) NOT NULL CHECK (median_response_minutes >= 0),
  on_time_delivery_pct        numeric(5,2) NOT NULL CHECK (on_time_delivery_pct >= 0 AND on_time_delivery_pct <= 100),
  strength_score              numeric(5,2) NOT NULL CHECK (strength_score >= 0 AND strength_score <= 100),
  relationship_tier           text NOT NULL CHECK (relationship_tier IN ('cold','warm','strong','strategic')),
  trend_direction             text NOT NULL CHECK (trend_direction IN ('up','flat','down')),
  recommended_action          text NOT NULL CHECK (recommended_action IN ('escalate','deepen','maintain','rotate','sunset')),
  last_interaction_at         timestamptz NOT NULL DEFAULT now(),
  notes                       text,
  created_at                  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_vendor_relationship_strength_r2802 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_vendor_relationship_strength_r2802;
CREATE POLICY founder_all ON engineer_vendor_relationship_strength_r2802
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_vendor_relationship_strength_r2802
  (cycle_month, engineer_name, engineer_tier, vendor_name, vendor_category,
   interactions_count, orders_placed, orders_fulfilled,
   avg_response_minutes, median_response_minutes, on_time_delivery_pct,
   strength_score, relationship_tier, trend_direction, recommended_action, notes)
VALUES
  ('2026-06-01'::date, 'Ravi Kumar',    'platinum', 'Medikart Spares',    'spare_parts',  48, 22, 21, 18.50, 14.00, 95.45, 92.30, 'strategic', 'up',   'deepen',   'Top vendor, expand SLA tier'),
  ('2026-06-01'::date, 'Priya Sharma',  'gold',     'Calibrate Co',       'calibration',  31, 14, 12, 42.10, 35.00, 85.71, 78.40, 'strong',    'flat', 'maintain', 'Steady performer'),
  ('2026-06-01'::date, 'Anil Reddy',    'silver',   'BulkConsumables.in', 'consumables',  19,  9,  7, 88.75, 72.00, 77.77, 61.20, 'warm',      'down', 'rotate',   'Slipping on lead time'),
  ('2026-06-01'::date, 'Sunita Desai',  'bronze',   'ToolNexus',          'tools',         8,  3,  2, 145.20, 120.00, 66.66, 38.50, 'cold',      'down', 'sunset',   'Unresponsive, replace next cycle'),
  ('2026-06-01'::date, 'Vikram Joshi',  'gold',     'FastLogix',          'logistics',    36, 18, 18, 12.30, 10.00, 100.00, 95.10, 'strategic', 'up',   'escalate', 'Promote to tier-1 logistics partner'),
  ('2026-06-01'::date, 'Meena Iyer',    'platinum', 'Medikart Spares',    'spare_parts',  44, 20, 19, 21.40, 17.50, 95.00, 89.70, 'strategic', 'up',   'deepen',   'Second engineer with high vendor trust'),
  ('2026-06-01'::date, 'Karthik Nair',  'silver',   'Calibrate Co',       'calibration',  22, 11,  9, 55.60, 48.00, 81.81, 70.30, 'strong',    'flat', 'maintain', 'Solid mid-tier');

-- ---------------------------------------------------------------------------
-- Table 2: engineer_vendor_action_log_r2802
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_vendor_action_log_r2802 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id     uuid REFERENCES engineer_vendor_relationship_strength_r2802(id) ON DELETE CASCADE,
  action_type         text NOT NULL CHECK (action_type IN ('escalate','deepen','maintain','rotate','sunset','review','contract_renewal')),
  taken_by            text NOT NULL,
  taken_at            timestamptz NOT NULL DEFAULT now(),
  outcome             text NOT NULL CHECK (outcome IN ('pending','in_progress','succeeded','failed','cancelled')),
  impact_score_delta  numeric(5,2) NOT NULL DEFAULT 0,
  rupees_value        bigint NOT NULL DEFAULT 0 CHECK (rupees_value >= 0),
  notes               text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_vendor_action_log_r2802 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_vendor_action_log_r2802;
CREATE POLICY founder_all ON engineer_vendor_action_log_r2802
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_vendor_action_log_r2802
  (relationship_id, action_type, taken_by, outcome, impact_score_delta, rupees_value, notes)
SELECT id, 'deepen', 'founder', 'in_progress', 3.50, 250000, 'Onboarded to priority lane'
  FROM engineer_vendor_relationship_strength_r2802 WHERE engineer_name = 'Ravi Kumar' LIMIT 1;
INSERT INTO engineer_vendor_action_log_r2802
  (relationship_id, action_type, taken_by, outcome, impact_score_delta, rupees_value, notes)
SELECT id, 'maintain', 'ops_lead', 'succeeded', 0.20, 80000, 'Quarterly check-in done'
  FROM engineer_vendor_relationship_strength_r2802 WHERE engineer_name = 'Priya Sharma' LIMIT 1;
INSERT INTO engineer_vendor_action_log_r2802
  (relationship_id, action_type, taken_by, outcome, impact_score_delta, rupees_value, notes)
SELECT id, 'rotate', 'founder', 'pending', -2.10, 0, 'Backup vendor sourced'
  FROM engineer_vendor_relationship_strength_r2802 WHERE engineer_name = 'Anil Reddy' LIMIT 1;
INSERT INTO engineer_vendor_action_log_r2802
  (relationship_id, action_type, taken_by, outcome, impact_score_delta, rupees_value, notes)
SELECT id, 'sunset', 'founder', 'in_progress', -5.50, 0, 'Wind-down contract by next month'
  FROM engineer_vendor_relationship_strength_r2802 WHERE engineer_name = 'Sunita Desai' LIMIT 1;
INSERT INTO engineer_vendor_action_log_r2802
  (relationship_id, action_type, taken_by, outcome, impact_score_delta, rupees_value, notes)
SELECT id, 'escalate', 'founder', 'succeeded', 4.80, 500000, 'Signed tier-1 logistics MoU'
  FROM engineer_vendor_relationship_strength_r2802 WHERE engineer_name = 'Vikram Joshi' LIMIT 1;
INSERT INTO engineer_vendor_action_log_r2802
  (relationship_id, action_type, taken_by, outcome, impact_score_delta, rupees_value, notes)
SELECT id, 'contract_renewal', 'legal', 'pending', 1.10, 350000, 'Annual renewal in queue'
  FROM engineer_vendor_relationship_strength_r2802 WHERE engineer_name = 'Meena Iyer' LIMIT 1;
INSERT INTO engineer_vendor_action_log_r2802
  (relationship_id, action_type, taken_by, outcome, impact_score_delta, rupees_value, notes)
SELECT id, 'review', 'ops_lead', 'succeeded', 0.40, 60000, 'Post-cycle review filed'
  FROM engineer_vendor_relationship_strength_r2802 WHERE engineer_name = 'Karthik Nair' LIMIT 1;

-- ============================================================================
-- RPCs
-- ============================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_engineer_vendor_strength_kpis_r2802();
CREATE OR REPLACE FUNCTION founder_engineer_vendor_strength_kpis_r2802()
RETURNS TABLE(
  total_relationships         integer,
  strategic_count             integer,
  strong_count                integer,
  warm_count                  integer,
  cold_count                  integer,
  avg_strength_score          numeric,
  avg_response_minutes        numeric,
  avg_on_time_delivery_pct    numeric,
  total_interactions          integer,
  total_orders_fulfilled      integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    COUNT(*) FILTER (WHERE relationship_tier = 'strategic')::integer,
    COUNT(*) FILTER (WHERE relationship_tier = 'strong')::integer,
    COUNT(*) FILTER (WHERE relationship_tier = 'warm')::integer,
    COUNT(*) FILTER (WHERE relationship_tier = 'cold')::integer,
    ROUND(AVG(strength_score)::numeric, 2),
    ROUND(AVG(avg_response_minutes)::numeric, 2),
    ROUND(AVG(on_time_delivery_pct)::numeric, 2),
    COALESCE(SUM(interactions_count), 0)::integer,
    COALESCE(SUM(orders_fulfilled), 0)::integer
  FROM engineer_vendor_relationship_strength_r2802;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_vendor_strength_kpis_r2802() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_engineer_vendor_strength_kpis_r2802() TO authenticated;

-- RPC 2: list all relationships
DROP FUNCTION IF EXISTS founder_engineer_vendor_relationships_r2802();
CREATE OR REPLACE FUNCTION founder_engineer_vendor_relationships_r2802()
RETURNS SETOF engineer_vendor_relationship_strength_r2802
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM engineer_vendor_relationship_strength_r2802
    ORDER BY strength_score DESC, engineer_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_vendor_relationships_r2802() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_engineer_vendor_relationships_r2802() TO authenticated;

-- RPC 3: strategic relationships
DROP FUNCTION IF EXISTS founder_engineer_vendor_strategic_r2802();
CREATE OR REPLACE FUNCTION founder_engineer_vendor_strategic_r2802()
RETURNS TABLE(
  engineer_name    text,
  vendor_name      text,
  strength_score   numeric,
  on_time_delivery_pct numeric,
  recommended_action text,
  trend_direction  text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.engineer_name, r.vendor_name, r.strength_score,
           r.on_time_delivery_pct, r.recommended_action, r.trend_direction
    FROM engineer_vendor_relationship_strength_r2802 r
    WHERE r.relationship_tier = 'strategic'
    ORDER BY r.strength_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_vendor_strategic_r2802() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_engineer_vendor_strategic_r2802() TO authenticated;

-- RPC 4: cold / sunset candidates
DROP FUNCTION IF EXISTS founder_engineer_vendor_at_risk_r2802();
CREATE OR REPLACE FUNCTION founder_engineer_vendor_at_risk_r2802()
RETURNS TABLE(
  engineer_name        text,
  vendor_name          text,
  strength_score       numeric,
  avg_response_minutes numeric,
  on_time_delivery_pct numeric,
  recommended_action   text,
  notes                text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.engineer_name, r.vendor_name, r.strength_score,
           r.avg_response_minutes, r.on_time_delivery_pct,
           r.recommended_action, r.notes
    FROM engineer_vendor_relationship_strength_r2802 r
    WHERE r.relationship_tier IN ('cold','warm')
       OR r.recommended_action IN ('rotate','sunset')
    ORDER BY r.strength_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_vendor_at_risk_r2802() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_engineer_vendor_at_risk_r2802() TO authenticated;

-- RPC 5: rollup by engineer tier
DROP FUNCTION IF EXISTS founder_engineer_vendor_by_tier_r2802();
CREATE OR REPLACE FUNCTION founder_engineer_vendor_by_tier_r2802()
RETURNS TABLE(
  engineer_tier          text,
  relationship_count     integer,
  avg_strength           numeric,
  avg_response_minutes   numeric,
  avg_on_time_delivery   numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.engineer_tier,
           COUNT(*)::integer,
           ROUND(AVG(r.strength_score)::numeric, 2),
           ROUND(AVG(r.avg_response_minutes)::numeric, 2),
           ROUND(AVG(r.on_time_delivery_pct)::numeric, 2)
    FROM engineer_vendor_relationship_strength_r2802 r
    GROUP BY r.engineer_tier
    ORDER BY avg_strength DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_vendor_by_tier_r2802() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_engineer_vendor_by_tier_r2802() TO authenticated;

-- RPC 6: rollup by vendor category
DROP FUNCTION IF EXISTS founder_engineer_vendor_by_category_r2802();
CREATE OR REPLACE FUNCTION founder_engineer_vendor_by_category_r2802()
RETURNS TABLE(
  vendor_category    text,
  relationship_count integer,
  avg_strength       numeric,
  total_interactions integer,
  total_orders       integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.vendor_category,
           COUNT(*)::integer,
           ROUND(AVG(r.strength_score)::numeric, 2),
           COALESCE(SUM(r.interactions_count), 0)::integer,
           COALESCE(SUM(r.orders_fulfilled), 0)::integer
    FROM engineer_vendor_relationship_strength_r2802 r
    GROUP BY r.vendor_category
    ORDER BY avg_strength DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_vendor_by_category_r2802() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_engineer_vendor_by_category_r2802() TO authenticated;

-- RPC 7: action log
DROP FUNCTION IF EXISTS founder_engineer_vendor_action_log_r2802();
CREATE OR REPLACE FUNCTION founder_engineer_vendor_action_log_r2802()
RETURNS TABLE(
  engineer_name      text,
  vendor_name        text,
  action_type        text,
  taken_by           text,
  taken_at           timestamptz,
  outcome            text,
  impact_score_delta numeric,
  rupees_value       bigint,
  notes              text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.engineer_name, r.vendor_name,
           a.action_type, a.taken_by, a.taken_at, a.outcome,
           a.impact_score_delta, a.rupees_value, a.notes
    FROM engineer_vendor_action_log_r2802 a
    JOIN engineer_vendor_relationship_strength_r2802 r ON r.id = a.relationship_id
    ORDER BY a.taken_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_vendor_action_log_r2802() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_engineer_vendor_action_log_r2802() TO authenticated;

-- RPC 8: response time leaders (fastest)
DROP FUNCTION IF EXISTS founder_engineer_vendor_response_leaders_r2802();
CREATE OR REPLACE FUNCTION founder_engineer_vendor_response_leaders_r2802()
RETURNS TABLE(
  engineer_name        text,
  vendor_name          text,
  avg_response_minutes numeric,
  median_response_minutes numeric,
  interactions_count   integer,
  strength_score       numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.engineer_name, r.vendor_name,
           r.avg_response_minutes, r.median_response_minutes,
           r.interactions_count, r.strength_score
    FROM engineer_vendor_relationship_strength_r2802 r
    ORDER BY r.avg_response_minutes ASC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_vendor_response_leaders_r2802() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_engineer_vendor_response_leaders_r2802() TO authenticated;

COMMIT;
