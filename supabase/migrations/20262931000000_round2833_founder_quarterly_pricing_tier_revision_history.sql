BEGIN;

-- ============================================================================
-- Round 2833 — Founder Quarterly Pricing Tier Revision History
-- HEAVY ★★★★ founder console
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: pricing_tier_revisions_r2833
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pricing_tier_revisions_r2833 (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter          text NOT NULL,
  tier_name        text NOT NULL,
  old_price_rupees integer NOT NULL,
  new_price_rupees integer NOT NULL,
  pct_change       numeric(6,2) NOT NULL,
  rationale        text NOT NULL,
  effective_date   date NOT NULL,
  approved_by      text NOT NULL,
  status           text NOT NULL CHECK (status IN ('proposed','approved','rolled_back','live')),
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE pricing_tier_revisions_r2833 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON pricing_tier_revisions_r2833;
CREATE POLICY founder_all ON pricing_tier_revisions_r2833
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO pricing_tier_revisions_r2833
  (quarter, tier_name, old_price_rupees, new_price_rupees, pct_change, rationale, effective_date, approved_by, status)
VALUES
  ('Q1-2026','AMC Basic',     11999, 12999,  8.34, 'Spare-part CPI up 7.2%, absorb 1.1pt margin',  '2026-01-01'::date, 'founder', 'live'),
  ('Q2-2026','AMC Pro',       24999, 26499,  6.00, 'Add 2 preventive visits + cert renewal',       '2026-04-01'::date, 'founder', 'live'),
  ('Q2-2026','AMC Enterprise',74999, 79999,  6.67, 'Hospital-chain SLA tightened 6h -> 4h',         '2026-04-01'::date, 'founder', 'live'),
  ('Q3-2026','AMC Basic',     12999, 12499, -3.85, 'Promo to defend churn vs Siemens Service',     '2026-07-01'::date, 'founder', 'approved'),
  ('Q3-2026','AMC Pro',       26499, 27999,  5.66, 'Bundle remote-monitoring add-on',              '2026-07-01'::date, 'founder', 'approved'),
  ('Q4-2026','AMC Enterprise',79999, 84999,  6.25, 'NABH cert workflow, GST e-invoice automation', '2026-10-01'::date, 'founder', 'proposed'),
  ('Q1-2026','Spot Repair',    1999,  1899, -5.00, 'Win-back vs grey-market freelancers',          '2026-01-15'::date, 'founder', 'rolled_back');

-- ---------------------------------------------------------------------------
-- Table 2: pricing_tier_revision_outcomes_r2833
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pricing_tier_revision_outcomes_r2833 (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  revision_quarter     text NOT NULL,
  tier_name            text NOT NULL,
  customers_impacted   integer NOT NULL,
  churn_pct            numeric(6,2) NOT NULL,
  upsell_pct           numeric(6,2) NOT NULL,
  revenue_delta_rupees bigint NOT NULL,
  nps_delta            numeric(5,2) NOT NULL,
  outcome_label        text NOT NULL CHECK (outcome_label IN ('win','neutral','loss','too_early')),
  notes                text NOT NULL,
  measured_at          date NOT NULL,
  created_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE pricing_tier_revision_outcomes_r2833 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON pricing_tier_revision_outcomes_r2833;
CREATE POLICY founder_all ON pricing_tier_revision_outcomes_r2833
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO pricing_tier_revision_outcomes_r2833
  (revision_quarter, tier_name, customers_impacted, churn_pct, upsell_pct, revenue_delta_rupees, nps_delta, outcome_label, notes, measured_at)
VALUES
  ('Q1-2026','AMC Basic',     412, 2.40, 11.30,   389000,  3.20, 'win',      'Churn within budget, upsell on Pro strong',     '2026-03-31'::date),
  ('Q2-2026','AMC Pro',       186, 1.10, 17.80,   612000,  4.10, 'win',      'Remote monitoring add-on stickier than modelled','2026-06-30'::date),
  ('Q2-2026','AMC Enterprise', 38, 0.00,  9.20,  1180000,  2.40, 'win',      '4h SLA closed 2 Tata-1mg deals',                '2026-06-30'::date),
  ('Q3-2026','AMC Basic',     420, 0.50,  4.10,  -210000,  1.80, 'too_early','Promo just launched, measure end-of-Q3',        '2026-07-10'::date),
  ('Q1-2026','Spot Repair',  1247, 8.40,  2.30,  -480000, -2.10, 'loss',     'Price-elastic segment, rolled back at +30 days','2026-02-15'::date),
  ('Q3-2026','AMC Pro',       198, 1.40,  6.70,    72000,  0.40, 'neutral',  'Bundle uptake below 12% target',                '2026-07-15'::date);

-- ============================================================================
-- RPCs (7+)
-- ============================================================================

-- 1. List revisions
DROP FUNCTION IF EXISTS founder_pricing_revisions_list_r2833();
CREATE OR REPLACE FUNCTION founder_pricing_revisions_list_r2833()
RETURNS SETOF pricing_tier_revisions_r2833
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM pricing_tier_revisions_r2833 ORDER BY effective_date DESC, tier_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_pricing_revisions_list_r2833() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pricing_revisions_list_r2833() TO authenticated;

-- 2. List outcomes
DROP FUNCTION IF EXISTS founder_pricing_outcomes_list_r2833();
CREATE OR REPLACE FUNCTION founder_pricing_outcomes_list_r2833()
RETURNS SETOF pricing_tier_revision_outcomes_r2833
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM pricing_tier_revision_outcomes_r2833 ORDER BY measured_at DESC, tier_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_pricing_outcomes_list_r2833() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pricing_outcomes_list_r2833() TO authenticated;

-- 3. KPI summary
DROP FUNCTION IF EXISTS founder_pricing_kpi_summary_r2833();
CREATE OR REPLACE FUNCTION founder_pricing_kpi_summary_r2833()
RETURNS TABLE (
  total_revisions     bigint,
  live_revisions      bigint,
  proposed_revisions  bigint,
  rolled_back         bigint,
  total_revenue_delta bigint,
  avg_pct_change      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM pricing_tier_revisions_r2833),
    (SELECT count(*) FROM pricing_tier_revisions_r2833 WHERE status = 'live'),
    (SELECT count(*) FROM pricing_tier_revisions_r2833 WHERE status = 'proposed'),
    (SELECT count(*) FROM pricing_tier_revisions_r2833 WHERE status = 'rolled_back'),
    (SELECT COALESCE(sum(revenue_delta_rupees),0) FROM pricing_tier_revision_outcomes_r2833),
    (SELECT ROUND(AVG(pct_change)::numeric, 2) FROM pricing_tier_revisions_r2833);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_pricing_kpi_summary_r2833() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pricing_kpi_summary_r2833() TO authenticated;

-- 4. By tier rollup
DROP FUNCTION IF EXISTS founder_pricing_by_tier_r2833();
CREATE OR REPLACE FUNCTION founder_pricing_by_tier_r2833()
RETURNS TABLE (
  tier_name      text,
  revision_count bigint,
  latest_price   integer,
  total_delta    bigint,
  avg_churn      numeric,
  avg_upsell     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.tier_name,
    count(*)::bigint,
    (SELECT new_price_rupees FROM pricing_tier_revisions_r2833 r2
       WHERE r2.tier_name = r.tier_name ORDER BY effective_date DESC LIMIT 1),
    COALESCE((SELECT sum(revenue_delta_rupees) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.tier_name = r.tier_name), 0),
    COALESCE((SELECT ROUND(AVG(churn_pct)::numeric, 2) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.tier_name = r.tier_name), 0),
    COALESCE((SELECT ROUND(AVG(upsell_pct)::numeric, 2) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.tier_name = r.tier_name), 0)
  FROM pricing_tier_revisions_r2833 r
  GROUP BY r.tier_name
  ORDER BY r.tier_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_pricing_by_tier_r2833() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pricing_by_tier_r2833() TO authenticated;

-- 5. By quarter rollup
DROP FUNCTION IF EXISTS founder_pricing_by_quarter_r2833();
CREATE OR REPLACE FUNCTION founder_pricing_by_quarter_r2833()
RETURNS TABLE (
  quarter        text,
  revision_count bigint,
  avg_pct_change numeric,
  total_delta    bigint,
  wins           bigint,
  losses         bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.quarter,
    count(*)::bigint,
    ROUND(AVG(r.pct_change)::numeric, 2),
    COALESCE((SELECT sum(revenue_delta_rupees) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.revision_quarter = r.quarter), 0),
    COALESCE((SELECT count(*) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.revision_quarter = r.quarter AND o.outcome_label = 'win'), 0),
    COALESCE((SELECT count(*) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.revision_quarter = r.quarter AND o.outcome_label = 'loss'), 0)
  FROM pricing_tier_revisions_r2833 r
  GROUP BY r.quarter
  ORDER BY r.quarter DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_pricing_by_quarter_r2833() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pricing_by_quarter_r2833() TO authenticated;

-- 6. Outcome wins (top movers)
DROP FUNCTION IF EXISTS founder_pricing_top_wins_r2833();
CREATE OR REPLACE FUNCTION founder_pricing_top_wins_r2833()
RETURNS TABLE (
  tier_name            text,
  revision_quarter     text,
  revenue_delta_rupees bigint,
  upsell_pct           numeric,
  nps_delta            numeric,
  notes                text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.tier_name, o.revision_quarter, o.revenue_delta_rupees, o.upsell_pct, o.nps_delta, o.notes
  FROM pricing_tier_revision_outcomes_r2833 o
  WHERE o.outcome_label = 'win'
  ORDER BY o.revenue_delta_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_pricing_top_wins_r2833() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pricing_top_wins_r2833() TO authenticated;

-- 7. Rolled-back retro
DROP FUNCTION IF EXISTS founder_pricing_rollbacks_r2833();
CREATE OR REPLACE FUNCTION founder_pricing_rollbacks_r2833()
RETURNS TABLE (
  tier_name        text,
  quarter          text,
  old_price_rupees integer,
  new_price_rupees integer,
  pct_change       numeric,
  rationale        text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.tier_name, r.quarter, r.old_price_rupees, r.new_price_rupees, r.pct_change, r.rationale
  FROM pricing_tier_revisions_r2833 r
  WHERE r.status = 'rolled_back'
  ORDER BY r.effective_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_pricing_rollbacks_r2833() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pricing_rollbacks_r2833() TO authenticated;

-- 8. Approve proposed revision
DROP FUNCTION IF EXISTS founder_pricing_approve_revision_r2833(uuid);
CREATE OR REPLACE FUNCTION founder_pricing_approve_revision_r2833(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE pricing_tier_revisions_r2833
     SET status = 'approved'
   WHERE id = p_id AND status = 'proposed';
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_pricing_approve_revision_r2833(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_pricing_approve_revision_r2833(uuid) TO authenticated;

COMMIT;
