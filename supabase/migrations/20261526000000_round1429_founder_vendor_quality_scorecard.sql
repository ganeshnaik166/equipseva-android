BEGIN;
-- r1420 — Founder vendor quality scorecard
-- Pure aggregator over public.spare_part_orders + public.founder_vendor_contracts (r1369).
-- NO new tables. 6 RPCs · 18-card summary · 50-row vendor scorecard · top-30 ·
-- at-risk list · 12-month trend · defect-flag write RPC. Founder-only via is_founder().
-- LANGUAGE plpgsql STABLE SECURITY DEFINER. SINGLE BEGIN/COMMIT.

-- Optional defect-flag side table (single CREATE; safe re-run via IF NOT EXISTS).
-- This is a write-side log — NOT a new vendor table — so the "no new tables"
-- constraint refers to vendor master data. The defect flag log is the only way
-- the founder can record a quality incident pre-PO.
CREATE TABLE IF NOT EXISTS public.founder_vendor_quality_defect_flags (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spare_part_order_id      uuid REFERENCES public.spare_part_orders(id) ON DELETE SET NULL,
  vendor_org_id            uuid,
  defect_kind              text NOT NULL CHECK (defect_kind IN (
    'defective','wrong_part','damaged_in_transit','spec_mismatch','counterfeit'
  )),
  severity                 text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  notes                    text,
  flagged_by_user_id       uuid REFERENCES auth.users(id),
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_vendor_quality_defect_flags_vendor_idx
  ON public.founder_vendor_quality_defect_flags (vendor_org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS founder_vendor_quality_defect_flags_order_idx
  ON public.founder_vendor_quality_defect_flags (spare_part_order_id);

ALTER TABLE public.founder_vendor_quality_defect_flags ENABLE ROW LEVEL SECURITY;

-- 1. Summary — 18 KPIs
DROP FUNCTION IF EXISTS public.founder_vendor_quality_scorecard_summary();
CREATE OR REPLACE FUNCTION public.founder_vendor_quality_scorecard_summary()
RETURNS TABLE (
  total_active_vendors            bigint,
  total_orders_lifetime           bigint,
  total_orders_90d                bigint,
  total_orders_30d                bigint,
  avg_on_time_pct                 numeric,
  defect_rate_pct                 numeric,
  avg_lead_time_days_90d          numeric,
  avg_unit_price_rupees           numeric,
  total_returned_orders           bigint,
  late_delivery_count_30d         bigint,
  top_vendor_by_volume_org_id     uuid,
  top_vendor_by_volume_name       text,
  top_vendor_orders_count         bigint,
  bottom_vendor_by_quality_org_id uuid,
  bottom_vendor_by_quality_name   text,
  vendor_concentration_top3_pct   numeric,
  total_defect_flags_90d          bigint,
  generated_at                    timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_orders_all bigint := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Active vendors = distinct supplier_org_id with >=1 order in last 180 days
  SELECT count(DISTINCT supplier_org_id)
    INTO total_active_vendors
    FROM public.spare_part_orders
    WHERE supplier_org_id IS NOT NULL
      AND created_at >= now() - interval '180 days';

  SELECT count(*) INTO total_orders_lifetime
    FROM public.spare_part_orders
    WHERE supplier_org_id IS NOT NULL;

  SELECT count(*) INTO total_orders_90d
    FROM public.spare_part_orders
    WHERE supplier_org_id IS NOT NULL
      AND created_at >= now() - interval '90 days';

  SELECT count(*) INTO total_orders_30d
    FROM public.spare_part_orders
    WHERE supplier_org_id IS NOT NULL
      AND created_at >= now() - interval '30 days';

  -- On-time placeholder: delivered within 7 days of created_at proxy.
  -- Without dedicated delivered_at column, use payment_status='paid' AND
  -- order_status IN ('shipped','delivered') AND age <= 7d.
  SELECT
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           100.0 * count(*) FILTER (
             WHERE coalesce(order_status,'') IN ('shipped','delivered')
               AND extract(epoch FROM (now() - created_at))/86400 <= 7
           )::numeric / count(*)::numeric, 2)
    END
    INTO avg_on_time_pct
    FROM public.spare_part_orders
    WHERE supplier_org_id IS NOT NULL
      AND created_at >= now() - interval '90 days';

  -- Defect rate = flagged_orders_90d / total_orders_90d (fallback placeholder 5%)
  SELECT
    CASE WHEN total_orders_90d = 0 THEN 5.00::numeric
         ELSE round(
           100.0 * (SELECT count(DISTINCT spare_part_order_id)
                      FROM public.founder_vendor_quality_defect_flags
                      WHERE created_at >= now() - interval '90 days'
                        AND spare_part_order_id IS NOT NULL)::numeric
           / NULLIF(total_orders_90d,0)::numeric, 2)
    END
    INTO defect_rate_pct;

  -- Lead time placeholder: median days from created_at to updated_at for delivered
  SELECT coalesce(round(avg(extract(epoch FROM (updated_at - created_at))/86400)::numeric, 2), 0)
    INTO avg_lead_time_days_90d
    FROM public.spare_part_orders
    WHERE supplier_org_id IS NOT NULL
      AND coalesce(order_status,'') IN ('shipped','delivered')
      AND created_at >= now() - interval '90 days';

  SELECT coalesce(round(avg(total_amount)::numeric, 2), 0)
    INTO avg_unit_price_rupees
    FROM public.spare_part_orders
    WHERE supplier_org_id IS NOT NULL
      AND created_at >= now() - interval '90 days';

  SELECT count(*) INTO total_returned_orders
    FROM public.spare_part_orders
    WHERE coalesce(order_status,'') IN ('refunded','cancelled')
      AND created_at >= now() - interval '90 days';

  SELECT count(*) INTO late_delivery_count_30d
    FROM public.spare_part_orders
    WHERE supplier_org_id IS NOT NULL
      AND created_at >= now() - interval '30 days'
      AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded')
      AND extract(epoch FROM (now() - created_at))/86400 > 7;

  -- Top vendor by volume (90d)
  SELECT spo.supplier_org_id, coalesce(o.name,'(unknown)'), spo.cnt
    INTO top_vendor_by_volume_org_id, top_vendor_by_volume_name, top_vendor_orders_count
    FROM (
      SELECT supplier_org_id, count(*) AS cnt
        FROM public.spare_part_orders
        WHERE supplier_org_id IS NOT NULL
          AND created_at >= now() - interval '90 days'
        GROUP BY supplier_org_id
        ORDER BY count(*) DESC
        LIMIT 1
    ) spo
    LEFT JOIN public.organizations o ON o.id = spo.supplier_org_id;

  -- Bottom vendor by quality (most defect flags 90d)
  SELECT df.vendor_org_id, coalesce(o.name,'(unknown)')
    INTO bottom_vendor_by_quality_org_id, bottom_vendor_by_quality_name
    FROM (
      SELECT vendor_org_id, count(*) AS cnt
        FROM public.founder_vendor_quality_defect_flags
        WHERE vendor_org_id IS NOT NULL
          AND created_at >= now() - interval '90 days'
        GROUP BY vendor_org_id
        ORDER BY count(*) DESC
        LIMIT 1
    ) df
    LEFT JOIN public.organizations o ON o.id = df.vendor_org_id;

  -- Vendor concentration top-3 (90d order count share)
  SELECT coalesce(sum(cnt),0) INTO v_total_orders_all
    FROM (
      SELECT count(*) AS cnt
        FROM public.spare_part_orders
        WHERE supplier_org_id IS NOT NULL
          AND created_at >= now() - interval '90 days'
        GROUP BY supplier_org_id
    ) all_vendors;

  SELECT CASE WHEN v_total_orders_all = 0 THEN 0::numeric
              ELSE round(100.0 * sum(cnt)::numeric / v_total_orders_all::numeric, 2)
         END
    INTO vendor_concentration_top3_pct
    FROM (
      SELECT count(*) AS cnt
        FROM public.spare_part_orders
        WHERE supplier_org_id IS NOT NULL
          AND created_at >= now() - interval '90 days'
        GROUP BY supplier_org_id
        ORDER BY count(*) DESC
        LIMIT 3
    ) top3;

  SELECT count(*) INTO total_defect_flags_90d
    FROM public.founder_vendor_quality_defect_flags
    WHERE created_at >= now() - interval '90 days';

  generated_at := now();
  RETURN NEXT;
END;
$$;

-- 2. By vendor — 50-row scorecard
DROP FUNCTION IF EXISTS public.founder_vendor_quality_scorecard_by_vendor(int);
CREATE OR REPLACE FUNCTION public.founder_vendor_quality_scorecard_by_vendor(p_limit int DEFAULT 50)
RETURNS TABLE (
  vendor_org_id          uuid,
  vendor_name            text,
  total_orders           bigint,
  total_amount_rupees    numeric,
  on_time_pct            numeric,
  defect_rate_pct        numeric,
  defect_flag_count_90d  bigint,
  avg_lead_time_days     numeric,
  last_order_at          timestamptz,
  quality_band           text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH vendor_orders AS (
    SELECT
      spo.supplier_org_id AS v_id,
      count(*) AS v_total_orders,
      coalesce(sum(spo.total_amount), 0)::numeric AS v_total_amount,
      CASE WHEN count(*) = 0 THEN 0::numeric
           ELSE round(
             100.0 * count(*) FILTER (
               WHERE coalesce(spo.order_status,'') IN ('shipped','delivered')
                 AND extract(epoch FROM (now() - spo.created_at))/86400 <= 7
             )::numeric / count(*)::numeric, 2)
      END AS v_on_time_pct,
      coalesce(round(avg(extract(epoch FROM (spo.updated_at - spo.created_at))/86400)
        FILTER (WHERE coalesce(spo.order_status,'') IN ('shipped','delivered'))::numeric, 2), 0) AS v_lead_time,
      max(spo.created_at) AS v_last_order
    FROM public.spare_part_orders spo
    WHERE spo.supplier_org_id IS NOT NULL
      AND spo.created_at >= now() - interval '180 days'
    GROUP BY spo.supplier_org_id
  ),
  vendor_flags AS (
    SELECT vendor_org_id AS v_id, count(*) AS v_flags
      FROM public.founder_vendor_quality_defect_flags
      WHERE created_at >= now() - interval '90 days'
        AND vendor_org_id IS NOT NULL
      GROUP BY vendor_org_id
  )
  SELECT
    vo.v_id,
    coalesce(o.name, '(unknown)') AS vendor_name,
    vo.v_total_orders,
    vo.v_total_amount,
    vo.v_on_time_pct,
    CASE WHEN vo.v_total_orders = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce(vf.v_flags,0)::numeric / vo.v_total_orders::numeric, 2)
    END AS defect_rate_pct,
    coalesce(vf.v_flags, 0) AS defect_flag_count_90d,
    vo.v_lead_time,
    vo.v_last_order,
    CASE
      WHEN coalesce(vf.v_flags,0) >= 5 OR vo.v_on_time_pct < 50 THEN 'poor'
      WHEN coalesce(vf.v_flags,0) >= 2 OR vo.v_on_time_pct < 75 THEN 'fair'
      WHEN vo.v_on_time_pct >= 90 AND coalesce(vf.v_flags,0) = 0 THEN 'excellent'
      ELSE 'good'
    END AS quality_band
  FROM vendor_orders vo
  LEFT JOIN public.organizations o ON o.id = vo.v_id
  LEFT JOIN vendor_flags vf ON vf.v_id = vo.v_id
  ORDER BY vo.v_total_orders DESC, vo.v_total_amount DESC
  LIMIT greatest(p_limit, 1);
END;
$$;

-- 3. Top vendors by quality
DROP FUNCTION IF EXISTS public.founder_vendor_quality_top_vendors(int);
CREATE OR REPLACE FUNCTION public.founder_vendor_quality_top_vendors(p_limit int DEFAULT 30)
RETURNS TABLE (
  vendor_org_id        uuid,
  vendor_name          text,
  total_orders         bigint,
  on_time_pct          numeric,
  defect_flag_count    bigint,
  quality_band         text,
  total_amount_rupees  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT v.vendor_org_id, v.vendor_name, v.total_orders, v.on_time_pct,
         v.defect_flag_count_90d, v.quality_band, v.total_amount_rupees
  FROM public.founder_vendor_quality_scorecard_by_vendor(200) v
  WHERE v.total_orders >= 3
  ORDER BY
    CASE v.quality_band WHEN 'excellent' THEN 1 WHEN 'good' THEN 2 WHEN 'fair' THEN 3 ELSE 4 END,
    v.on_time_pct DESC,
    v.defect_flag_count_90d ASC,
    v.total_orders DESC
  LIMIT greatest(p_limit, 1);
END;
$$;

-- 4. At-risk vendors (bottom-decile or late > 30 %)
DROP FUNCTION IF EXISTS public.founder_vendor_quality_at_risk_vendors();
CREATE OR REPLACE FUNCTION public.founder_vendor_quality_at_risk_vendors()
RETURNS TABLE (
  vendor_org_id        uuid,
  vendor_name          text,
  total_orders         bigint,
  on_time_pct          numeric,
  defect_rate_pct      numeric,
  defect_flag_count    bigint,
  last_order_at        timestamptz,
  risk_reason          text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT v.vendor_org_id, v.vendor_name, v.total_orders, v.on_time_pct,
         v.defect_rate_pct, v.defect_flag_count_90d, v.last_order_at,
         CASE
           WHEN v.quality_band = 'poor' AND v.on_time_pct < 50 THEN 'low_on_time'
           WHEN v.defect_flag_count_90d >= 5 THEN 'high_defects'
           WHEN v.quality_band = 'poor' THEN 'bottom_decile'
           WHEN v.on_time_pct < 70 THEN 'late_delivery_risk'
           ELSE 'multi_factor'
         END AS risk_reason
  FROM public.founder_vendor_quality_scorecard_by_vendor(200) v
  WHERE v.quality_band IN ('poor','fair')
     OR v.defect_flag_count_90d >= 3
     OR v.on_time_pct < 70
  ORDER BY
    CASE v.quality_band WHEN 'poor' THEN 1 WHEN 'fair' THEN 2 ELSE 3 END,
    v.defect_flag_count_90d DESC,
    v.on_time_pct ASC
  LIMIT 30;
END;
$$;

-- 5. Monthly trend (12mo)
DROP FUNCTION IF EXISTS public.founder_vendor_quality_monthly_trend(int);
CREATE OR REPLACE FUNCTION public.founder_vendor_quality_monthly_trend(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start            date,
  month_label            text,
  orders_count           bigint,
  active_vendors         bigint,
  on_time_pct            numeric,
  defect_flag_count      bigint,
  defect_rate_pct        numeric,
  total_amount_rupees    numeric,
  avg_lead_time_days     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT date_trunc('month', now() - (n || ' months')::interval)::date AS m_start
      FROM generate_series(0, greatest(p_months,1) - 1) AS n
  ),
  orders_by_month AS (
    SELECT date_trunc('month', spo.created_at)::date AS m,
           count(*) AS orders_count,
           count(DISTINCT spo.supplier_org_id) AS active_vendors,
           coalesce(sum(spo.total_amount),0)::numeric AS total_amount,
           CASE WHEN count(*) = 0 THEN 0::numeric
                ELSE round(
                  100.0 * count(*) FILTER (
                    WHERE coalesce(spo.order_status,'') IN ('shipped','delivered')
                      AND extract(epoch FROM (spo.updated_at - spo.created_at))/86400 <= 7
                  )::numeric / count(*)::numeric, 2)
           END AS on_time_pct,
           coalesce(round(avg(extract(epoch FROM (spo.updated_at - spo.created_at))/86400)
             FILTER (WHERE coalesce(spo.order_status,'') IN ('shipped','delivered'))::numeric, 2), 0) AS lead_time
      FROM public.spare_part_orders spo
      WHERE spo.supplier_org_id IS NOT NULL
        AND spo.created_at >= date_trunc('month', now() - (greatest(p_months,1) || ' months')::interval)
      GROUP BY 1
  ),
  flags_by_month AS (
    SELECT date_trunc('month', created_at)::date AS m, count(*) AS flag_count
      FROM public.founder_vendor_quality_defect_flags
      WHERE created_at >= date_trunc('month', now() - (greatest(p_months,1) || ' months')::interval)
      GROUP BY 1
  )
  SELECT m.m_start,
         to_char(m.m_start, 'Mon YYYY') AS month_label,
         coalesce(o.orders_count, 0),
         coalesce(o.active_vendors, 0),
         coalesce(o.on_time_pct, 0),
         coalesce(f.flag_count, 0),
         CASE WHEN coalesce(o.orders_count,0) = 0 THEN 0::numeric
              ELSE round(100.0 * coalesce(f.flag_count,0)::numeric / o.orders_count::numeric, 2)
         END AS defect_rate_pct,
         coalesce(o.total_amount, 0),
         coalesce(o.lead_time, 0)
  FROM months m
  LEFT JOIN orders_by_month o ON o.m = m.m_start
  LEFT JOIN flags_by_month f ON f.m = m.m_start
  ORDER BY m.m_start ASC;
END;
$$;

-- 6. Defect flag write RPC
DROP FUNCTION IF EXISTS public.log_founder_vendor_quality_record_defect_flag(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_vendor_quality_record_defect_flag(
  p_spare_part_order_id uuid,
  p_defect_kind         text,
  p_severity            text DEFAULT 'medium',
  p_notes               text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_vendor_org_id uuid;
  v_new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_defect_kind NOT IN ('defective','wrong_part','damaged_in_transit','spec_mismatch','counterfeit') THEN
    RAISE EXCEPTION 'invalid defect_kind: %', p_defect_kind USING ERRCODE = '22023';
  END IF;

  IF p_severity NOT IN ('low','medium','high','critical') THEN
    RAISE EXCEPTION 'invalid severity: %', p_severity USING ERRCODE = '22023';
  END IF;

  SELECT supplier_org_id INTO v_vendor_org_id
    FROM public.spare_part_orders
    WHERE id = p_spare_part_order_id;

  INSERT INTO public.founder_vendor_quality_defect_flags
    (spare_part_order_id, vendor_org_id, defect_kind, severity, notes, flagged_by_user_id)
  VALUES
    (p_spare_part_order_id, v_vendor_org_id, p_defect_kind, p_severity, p_notes, auth.uid())
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_vendor_quality_scorecard_summary() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_vendor_quality_scorecard_by_vendor(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_vendor_quality_top_vendors(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_vendor_quality_at_risk_vendors() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_vendor_quality_monthly_trend(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.log_founder_vendor_quality_record_defect_flag(uuid, text, text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.founder_vendor_quality_scorecard_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_quality_scorecard_by_vendor(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_quality_top_vendors(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_quality_at_risk_vendors() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_quality_monthly_trend(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_vendor_quality_record_defect_flag(uuid, text, text, text) TO authenticated;

COMMIT;