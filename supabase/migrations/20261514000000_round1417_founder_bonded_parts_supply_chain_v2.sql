BEGIN;
-- Round 1416 — /founder-bonded-parts-supply-chain-v2
-- Unified bonded-parts supplier rollup across dental + lab_diagnostics verticals
-- plus supply-chain health derived from spare_part_orders. NO new tables.



-- =====================================================================
-- 1) SUMMARY (18 KPIs)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_bonded_parts_supply_chain_v2_summary();
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_supply_chain_v2_summary()
RETURNS TABLE (
  total_bonded_suppliers           bigint,
  dental_supplier_count            bigint,
  lab_supplier_count               bigint,
  cross_vertical_supplier_count    bigint,
  signed_count                     bigint,
  pending_count                    bigint,
  active_count                     bigint,
  revoked_count                    bigint,
  total_bond_value_rupees          numeric,
  avg_bond_amount_rupees           numeric,
  top_supplier_name                text,
  top_supplier_orders_count        bigint,
  total_orders_via_bonded_30d      bigint,
  avg_delivery_days                numeric,
  on_time_pct                      numeric,
  supplier_dependency_top3_pct     numeric,
  single_source_risk_count         bigint,
  avg_parts_per_supplier           numeric,
  longest_relationship_days        integer,
  total_spare_part_volume_30d_rupees numeric,
  expiring_bonds_60d_count         bigint,
  generated_at                     timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_unioned_count   bigint := 0;
  v_dental          bigint := 0;
  v_lab             bigint := 0;
  v_cross           bigint := 0;
  v_signed          bigint := 0;
  v_pending         bigint := 0;
  v_active          bigint := 0;
  v_revoked         bigint := 0;
  v_total_bond      numeric := 0;
  v_avg_bond        numeric := 0;
  v_top_name        text := NULL;
  v_top_orders      bigint := 0;
  v_orders_30d      bigint := 0;
  v_avg_delivery    numeric := 0;
  v_on_time_pct     numeric := 0;
  v_top3_pct        numeric := 0;
  v_single_source   bigint := 0;
  v_avg_parts       numeric := 0;
  v_longest_days    integer := 0;
  v_vol_30d         numeric := 0;
  v_expiring        bigint := 0;
  v_total_paid_30d  numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  -- Unified supplier counts (DISTINCT supplier_org_id across both verticals)
  WITH unioned AS (
    SELECT supplier_org_id, supplier_name, bonded_status, bond_amount_rupees,
           bond_signed_at, bond_expires_at, created_at, 'dental'::text AS v
      FROM public.dental_bonded_parts_suppliers
    UNION ALL
    SELECT supplier_org_id, supplier_name, bonded_status, bond_amount_rupees,
           bond_signed_at, bond_expires_at, created_at, 'lab'::text AS v
      FROM public.lab_diagnostics_bonded_parts_suppliers
  )
  SELECT
    COUNT(DISTINCT supplier_org_id),
    COUNT(*) FILTER (WHERE v='dental'),
    COUNT(*) FILTER (WHERE v='lab'),
    COALESCE(SUM(bond_amount_rupees),0),
    COALESCE(AVG(bond_amount_rupees) FILTER (WHERE bond_amount_rupees > 0), 0),
    COUNT(*) FILTER (WHERE bonded_status='signed'),
    COUNT(*) FILTER (WHERE bonded_status='pending'),
    COUNT(*) FILTER (WHERE bonded_status='active'),
    COUNT(*) FILTER (WHERE bonded_status='revoked'),
    COUNT(*) FILTER (WHERE bond_expires_at IS NOT NULL
                     AND bond_expires_at <= now() + interval '60 days'
                     AND bond_expires_at >= now())
  INTO v_unioned_count, v_dental, v_lab, v_total_bond, v_avg_bond,
       v_signed, v_pending, v_active, v_revoked, v_expiring
  FROM unioned;

  -- Cross-vertical supplier_org_id present in BOTH verticals
  SELECT COUNT(*) INTO v_cross
    FROM (
      SELECT supplier_org_id
        FROM public.dental_bonded_parts_suppliers
      INTERSECT
      SELECT supplier_org_id
        FROM public.lab_diagnostics_bonded_parts_suppliers
    ) x;

  -- Orders 30d via bonded supplier_org_id
  WITH bonded_orgs AS (
    SELECT supplier_org_id FROM public.dental_bonded_parts_suppliers
    UNION
    SELECT supplier_org_id FROM public.lab_diagnostics_bonded_parts_suppliers
  )
  SELECT COUNT(*)
    INTO v_orders_30d
    FROM public.spare_part_orders o
    JOIN bonded_orgs b ON b.supplier_org_id = o.supplier_org_id
   WHERE o.created_at >= now() - interval '30 days';

  -- Top supplier by orders 30d
  WITH bonded_names AS (
    SELECT supplier_org_id, supplier_name FROM public.dental_bonded_parts_suppliers
    UNION
    SELECT supplier_org_id, supplier_name FROM public.lab_diagnostics_bonded_parts_suppliers
  ),
  ranked AS (
    SELECT bn.supplier_name, COUNT(o.*) AS oc
      FROM public.spare_part_orders o
      JOIN bonded_names bn ON bn.supplier_org_id = o.supplier_org_id
     WHERE o.created_at >= now() - interval '30 days'
     GROUP BY bn.supplier_name
     ORDER BY oc DESC NULLS LAST
     LIMIT 1
  )
  SELECT supplier_name, oc INTO v_top_name, v_top_orders FROM ranked;

  -- Average delivery days (delivered orders 90d)
  SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 86400.0), 0)
    INTO v_avg_delivery
    FROM public.spare_part_orders
   WHERE order_status = 'delivered'
     AND created_at >= now() - interval '90 days';

  -- On-time % (delivered ≤ 7d / total delivered)
  SELECT CASE WHEN COUNT(*) = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(*) FILTER (
                WHERE EXTRACT(EPOCH FROM (updated_at - created_at)) / 86400.0 <= 7
              ) / COUNT(*), 2) END
    INTO v_on_time_pct
    FROM public.spare_part_orders
   WHERE order_status = 'delivered'
     AND created_at >= now() - interval '90 days';

  -- Top-3 supplier dependency % (30d)
  WITH per_supp AS (
    SELECT supplier_org_id, COALESCE(SUM(total_amount),0) AS vol
      FROM public.spare_part_orders
     WHERE payment_status = 'paid'
       AND created_at >= now() - interval '30 days'
     GROUP BY supplier_org_id
  ),
  totals AS ( SELECT COALESCE(SUM(vol),0) AS grand FROM per_supp ),
  top3 AS (
    SELECT COALESCE(SUM(vol),0) AS t3 FROM (
      SELECT vol FROM per_supp ORDER BY vol DESC LIMIT 3
    ) z
  )
  SELECT CASE WHEN (SELECT grand FROM totals) = 0 THEN 0
              ELSE ROUND(100.0 * (SELECT t3 FROM top3) / (SELECT grand FROM totals), 2) END
    INTO v_top3_pct;

  -- Single-source risk: parts categories supplied by only 1 bonded supplier (cross-vertical)
  WITH cats AS (
    SELECT UNNEST(supported_categories) AS cat, supplier_org_id
      FROM public.dental_bonded_parts_suppliers
    UNION
    SELECT UNNEST(supported_categories) AS cat, supplier_org_id
      FROM public.lab_diagnostics_bonded_parts_suppliers
  )
  SELECT COUNT(*) INTO v_single_source FROM (
    SELECT cat FROM cats GROUP BY cat HAVING COUNT(DISTINCT supplier_org_id) = 1
  ) s;

  -- Avg parts (categories) per supplier
  WITH cats AS (
    SELECT supplier_org_id, COALESCE(cardinality(supported_categories),0) AS n
      FROM public.dental_bonded_parts_suppliers
    UNION ALL
    SELECT supplier_org_id, COALESCE(cardinality(supported_categories),0)
      FROM public.lab_diagnostics_bonded_parts_suppliers
  )
  SELECT COALESCE(ROUND(AVG(n)::numeric, 2), 0) INTO v_avg_parts FROM cats;

  -- Longest relationship days
  WITH oldest AS (
    SELECT MIN(created_at) AS first_at FROM (
      SELECT created_at FROM public.dental_bonded_parts_suppliers
      UNION ALL
      SELECT created_at FROM public.lab_diagnostics_bonded_parts_suppliers
    ) u
  )
  SELECT COALESCE(EXTRACT(DAY FROM (now() - first_at))::int, 0)
    INTO v_longest_days FROM oldest;

  -- Total paid spare_part_orders volume 30d (bonded suppliers only)
  WITH bonded_orgs AS (
    SELECT supplier_org_id FROM public.dental_bonded_parts_suppliers
    UNION
    SELECT supplier_org_id FROM public.lab_diagnostics_bonded_parts_suppliers
  )
  SELECT COALESCE(SUM(o.total_amount),0)
    INTO v_vol_30d
    FROM public.spare_part_orders o
    JOIN bonded_orgs b ON b.supplier_org_id = o.supplier_org_id
   WHERE o.payment_status = 'paid'
     AND o.created_at >= now() - interval '30 days';

  RETURN QUERY SELECT
    v_unioned_count,
    v_dental,
    v_lab,
    v_cross,
    v_signed,
    v_pending,
    v_active,
    v_revoked,
    v_total_bond,
    ROUND(v_avg_bond, 2),
    v_top_name,
    v_top_orders,
    v_orders_30d,
    ROUND(v_avg_delivery, 2),
    v_on_time_pct,
    v_top3_pct,
    v_single_source,
    v_avg_parts,
    v_longest_days,
    v_vol_30d,
    v_expiring,
    now();
END
$$;
REVOKE ALL ON FUNCTION public.founder_bonded_parts_supply_chain_v2_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bonded_parts_supply_chain_v2_summary() TO authenticated;

-- =====================================================================
-- 2) BY VERTICAL
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_bonded_parts_v2_by_vertical();
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_v2_by_vertical()
RETURNS TABLE (
  vertical          text,
  supplier_count    bigint,
  signed_count      bigint,
  total_bond_rupees numeric,
  recent_order_count bigint,
  avg_order_amount  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  WITH per_vert AS (
    SELECT 'dental'::text AS vertical, supplier_org_id, bonded_status, bond_amount_rupees
      FROM public.dental_bonded_parts_suppliers
    UNION ALL
    SELECT 'lab'::text, supplier_org_id, bonded_status, bond_amount_rupees
      FROM public.lab_diagnostics_bonded_parts_suppliers
  ),
  cross_v AS (
    SELECT supplier_org_id
      FROM public.dental_bonded_parts_suppliers
    INTERSECT
    SELECT supplier_org_id
      FROM public.lab_diagnostics_bonded_parts_suppliers
  ),
  base AS (
    SELECT pv.vertical, pv.supplier_org_id, pv.bonded_status, pv.bond_amount_rupees
      FROM per_vert pv
    UNION ALL
    SELECT 'cross_vertical', cv.supplier_org_id, NULL::text, 0::numeric
      FROM cross_v cv
  ),
  orders AS (
    SELECT supplier_org_id,
           COUNT(*) AS oc,
           COALESCE(AVG(total_amount),0) AS avg_amt
      FROM public.spare_part_orders
     WHERE created_at >= now() - interval '30 days'
     GROUP BY supplier_org_id
  )
  SELECT
    b.vertical,
    COUNT(DISTINCT b.supplier_org_id),
    COUNT(*) FILTER (WHERE b.bonded_status='signed'),
    COALESCE(SUM(b.bond_amount_rupees),0),
    COALESCE(SUM(o.oc),0)::bigint,
    COALESCE(ROUND(AVG(o.avg_amt)::numeric, 2), 0)
  FROM base b
  LEFT JOIN orders o ON o.supplier_org_id = b.supplier_org_id
  GROUP BY b.vertical
  ORDER BY b.vertical;
END
$$;
REVOKE ALL ON FUNCTION public.founder_bonded_parts_v2_by_vertical() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bonded_parts_v2_by_vertical() TO authenticated;

-- =====================================================================
-- 3) TOP SUPPLIERS (cross-vertical merged)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_bonded_parts_v2_top_suppliers(int);
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_v2_top_suppliers(p_limit int DEFAULT 30)
RETURNS TABLE (
  supplier_org_id  uuid,
  supplier_name    text,
  vertical         text,
  bonded_status    text,
  total_bond       numeric,
  orders_count     bigint,
  total_amount     numeric,
  last_order_at    timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  WITH all_bonded AS (
    SELECT supplier_org_id, supplier_name, bonded_status, bond_amount_rupees,
           'dental'::text AS v
      FROM public.dental_bonded_parts_suppliers
    UNION ALL
    SELECT supplier_org_id, supplier_name, bonded_status, bond_amount_rupees, 'lab'
      FROM public.lab_diagnostics_bonded_parts_suppliers
  ),
  merged AS (
    SELECT
      supplier_org_id,
      MAX(supplier_name) AS supplier_name,
      CASE WHEN COUNT(DISTINCT v) > 1 THEN 'cross_vertical'
           ELSE MAX(v) END AS vertical,
      MAX(bonded_status) AS bonded_status,
      SUM(bond_amount_rupees) AS total_bond
    FROM all_bonded
    GROUP BY supplier_org_id
  ),
  ord AS (
    SELECT supplier_org_id,
           COUNT(*) AS oc,
           COALESCE(SUM(total_amount),0) AS ta,
           MAX(created_at) AS last_at
      FROM public.spare_part_orders
     GROUP BY supplier_org_id
  )
  SELECT m.supplier_org_id, m.supplier_name, m.vertical, m.bonded_status,
         m.total_bond,
         COALESCE(o.oc,0)::bigint,
         COALESCE(o.ta,0)::numeric,
         o.last_at
    FROM merged m
    LEFT JOIN ord o ON o.supplier_org_id = m.supplier_org_id
   ORDER BY COALESCE(o.ta,0) DESC, m.total_bond DESC
   LIMIT GREATEST(p_limit, 1);
END
$$;
REVOKE ALL ON FUNCTION public.founder_bonded_parts_v2_top_suppliers(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bonded_parts_v2_top_suppliers(int) TO authenticated;

-- =====================================================================
-- 4) CONCENTRATION RISK (top-10 + cumulative %)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_bonded_parts_v2_concentration_risk();
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_v2_concentration_risk()
RETURNS TABLE (
  rank_no          int,
  supplier_org_id  uuid,
  supplier_name    text,
  volume_rupees    numeric,
  pct_of_total     numeric,
  cumulative_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  WITH bonded_names AS (
    SELECT supplier_org_id, supplier_name FROM public.dental_bonded_parts_suppliers
    UNION
    SELECT supplier_org_id, supplier_name FROM public.lab_diagnostics_bonded_parts_suppliers
  ),
  per_supp AS (
    SELECT bn.supplier_org_id, MAX(bn.supplier_name) AS supplier_name,
           COALESCE(SUM(o.total_amount),0) AS vol
      FROM bonded_names bn
      LEFT JOIN public.spare_part_orders o
             ON o.supplier_org_id = bn.supplier_org_id
            AND o.payment_status = 'paid'
            AND o.created_at >= now() - interval '90 days'
     GROUP BY bn.supplier_org_id
  ),
  ranked AS (
    SELECT supplier_org_id, supplier_name, vol,
           ROW_NUMBER() OVER (ORDER BY vol DESC) AS rk,
           SUM(vol) OVER () AS grand
      FROM per_supp
  ),
  scored AS (
    SELECT rk::int AS rank_no, supplier_org_id, supplier_name, vol,
           CASE WHEN grand = 0 THEN 0 ELSE ROUND(100.0 * vol / grand, 2) END AS pct,
           CASE WHEN grand = 0 THEN 0
                ELSE ROUND(100.0 * SUM(vol) OVER (ORDER BY vol DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / grand, 2)
           END AS cum_pct
      FROM ranked
  )
  SELECT rank_no, supplier_org_id, supplier_name, vol, pct, cum_pct
    FROM scored
   WHERE rank_no <= 10
   ORDER BY rank_no;
END
$$;
REVOKE ALL ON FUNCTION public.founder_bonded_parts_v2_concentration_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bonded_parts_v2_concentration_risk() TO authenticated;

-- =====================================================================
-- 5) ORDER TREND (monthly)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_bonded_parts_v2_order_trend(int);
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_v2_order_trend(p_months int DEFAULT 12)
RETURNS TABLE (
  month_label       text,
  order_count       bigint,
  total_amount      numeric,
  distinct_suppliers bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_months int := GREATEST(LEAST(p_months, 24), 1);
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  WITH bonded_orgs AS (
    SELECT supplier_org_id FROM public.dental_bonded_parts_suppliers
    UNION
    SELECT supplier_org_id FROM public.lab_diagnostics_bonded_parts_suppliers
  ),
  scoped AS (
    SELECT o.created_at, o.total_amount, o.supplier_org_id
      FROM public.spare_part_orders o
      JOIN bonded_orgs b ON b.supplier_org_id = o.supplier_org_id
     WHERE o.created_at >= date_trunc('month', now()) - make_interval(months => v_months - 1)
  ),
  bucketed AS (
    SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS m,
           COUNT(*) AS oc,
           COALESCE(SUM(total_amount),0) AS ta,
           COUNT(DISTINCT supplier_org_id) AS ds
      FROM scoped
     GROUP BY 1
  )
  SELECT m, oc, ta, ds
    FROM bucketed
   ORDER BY m;
END
$$;
REVOKE ALL ON FUNCTION public.founder_bonded_parts_v2_order_trend(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bonded_parts_v2_order_trend(int) TO authenticated;

-- =====================================================================
-- 6) AT-RISK SUPPLIERS (expiring bond ≤ 60d OR stuck pending >30d)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_bonded_parts_v2_at_risk_suppliers();
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_v2_at_risk_suppliers()
RETURNS TABLE (
  supplier_org_id   uuid,
  supplier_name     text,
  vertical          text,
  bonded_status     text,
  bond_expires_at   timestamptz,
  days_to_expiry    integer,
  pending_days      integer,
  risk_reason       text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  WITH all_bonded AS (
    SELECT supplier_org_id, supplier_name, bonded_status, bond_expires_at, created_at,
           'dental'::text AS v
      FROM public.dental_bonded_parts_suppliers
    UNION ALL
    SELECT supplier_org_id, supplier_name, bonded_status, bond_expires_at, created_at, 'lab'
      FROM public.lab_diagnostics_bonded_parts_suppliers
  )
  SELECT
    supplier_org_id,
    supplier_name,
    v AS vertical,
    bonded_status,
    bond_expires_at,
    CASE WHEN bond_expires_at IS NOT NULL
         THEN EXTRACT(DAY FROM (bond_expires_at - now()))::int
         ELSE NULL END AS days_to_expiry,
    CASE WHEN bonded_status='pending'
         THEN EXTRACT(DAY FROM (now() - created_at))::int
         ELSE NULL END AS pending_days,
    CASE
      WHEN bond_expires_at IS NOT NULL
           AND bond_expires_at <= now() + interval '60 days'
           AND bond_expires_at >= now()
        THEN 'bond_expiring_60d'
      WHEN bonded_status = 'pending'
           AND created_at < now() - interval '30 days'
        THEN 'pending_over_30d'
      ELSE 'other'
    END AS risk_reason
  FROM all_bonded
  WHERE
    (bond_expires_at IS NOT NULL
     AND bond_expires_at <= now() + interval '60 days'
     AND bond_expires_at >= now())
    OR (bonded_status = 'pending'
        AND created_at < now() - interval '30 days')
  ORDER BY
    COALESCE(bond_expires_at, now() + interval '999 days') ASC,
    created_at ASC
  LIMIT 100;
END
$$;
REVOKE ALL ON FUNCTION public.founder_bonded_parts_v2_at_risk_suppliers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_bonded_parts_v2_at_risk_suppliers() TO authenticated;

COMMIT;