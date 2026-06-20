BEGIN;
-- r1427 founder_customer_lifetime_value_calculator

CREATE TABLE IF NOT EXISTS public.founder_customer_lifetime_value_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  total_lifetime_revenue_rupees numeric NOT NULL DEFAULT 0,
  total_lifetime_payouts_rupees numeric NOT NULL DEFAULT 0,
  total_lifetime_gross_profit_rupees numeric NOT NULL DEFAULT 0,
  days_active int NOT NULL DEFAULT 0,
  projected_remaining_months int NOT NULL DEFAULT 60,
  projected_remaining_revenue_rupees numeric NOT NULL DEFAULT 0,
  total_projected_clv_rupees numeric NOT NULL DEFAULT 0,
  churn_risk_band text NOT NULL DEFAULT 'low' CHECK (churn_risk_band IN ('low','medium','high','critical')),
  value_segment text NOT NULL DEFAULT 'bronze' CHECK (value_segment IN ('platinum','gold','silver','bronze')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fclv_hospital ON public.founder_customer_lifetime_value_snapshots(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_fclv_snapshot_at ON public.founder_customer_lifetime_value_snapshots(snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_fclv_segment ON public.founder_customer_lifetime_value_snapshots(value_segment);
CREATE INDEX IF NOT EXISTS idx_fclv_band ON public.founder_customer_lifetime_value_snapshots(churn_risk_band);

ALTER TABLE public.founder_customer_lifetime_value_snapshots ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.founder_clv_calculator_summary()
RETURNS TABLE (
  total_snapshots int,
  unique_hospitals int,
  snapshots_last_7d int,
  snapshots_last_30d int,
  avg_clv_rupees numeric,
  top_clv_rupees numeric,
  bottom_clv_rupees numeric,
  median_clv_rupees numeric,
  p90_clv_threshold_rupees numeric,
  total_clv_book_rupees numeric,
  platinum_count int,
  gold_count int,
  silver_count int,
  bronze_count int,
  critical_band_count int,
  gold_to_bronze_ratio numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_user_id) *
    FROM public.founder_customer_lifetime_value_snapshots
    ORDER BY hospital_user_id, snapshot_at DESC
  ),
  s AS (SELECT * FROM public.founder_customer_lifetime_value_snapshots)
  SELECT
    (SELECT count(*)::int FROM s),
    (SELECT count(DISTINCT hospital_user_id)::int FROM s),
    (SELECT count(*)::int FROM s WHERE snapshot_at >= now() - interval '7 days'),
    (SELECT count(*)::int FROM s WHERE snapshot_at >= now() - interval '30 days'),
    (SELECT round(avg(total_projected_clv_rupees)::numeric, 2) FROM latest),
    (SELECT max(total_projected_clv_rupees) FROM latest),
    (SELECT min(total_projected_clv_rupees) FROM latest),
    (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY total_projected_clv_rupees) FROM latest),
    (SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY total_projected_clv_rupees) FROM latest),
    (SELECT coalesce(sum(total_projected_clv_rupees), 0) FROM latest),
    (SELECT count(*)::int FROM latest WHERE value_segment = 'platinum'),
    (SELECT count(*)::int FROM latest WHERE value_segment = 'gold'),
    (SELECT count(*)::int FROM latest WHERE value_segment = 'silver'),
    (SELECT count(*)::int FROM latest WHERE value_segment = 'bronze'),
    (SELECT count(*)::int FROM latest WHERE churn_risk_band = 'critical'),
    (SELECT CASE WHEN nullif(count(*) FILTER (WHERE value_segment='bronze'),0) IS NULL THEN NULL
                 ELSE round((count(*) FILTER (WHERE value_segment='gold'))::numeric
                          / nullif(count(*) FILTER (WHERE value_segment='bronze'),0)::numeric, 3) END
     FROM latest);
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_clv_recent_snapshots(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  snapshot_at timestamptz,
  total_lifetime_revenue_rupees numeric,
  total_lifetime_gross_profit_rupees numeric,
  total_projected_clv_rupees numeric,
  days_active int,
  churn_risk_band text,
  value_segment text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id,
         coalesce(o.name, p.full_name, s.hospital_user_id::text) AS hospital_name,
         s.snapshot_at, s.total_lifetime_revenue_rupees, s.total_lifetime_gross_profit_rupees,
         s.total_projected_clv_rupees, s.days_active, s.churn_risk_band, s.value_segment
  FROM public.founder_customer_lifetime_value_snapshots s
  LEFT JOIN public.profiles p ON p.user_id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.snapshot_at DESC
  LIMIT greatest(1, least(p_limit, 200));
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_clv_top_customers(p_limit int DEFAULT 50)
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_name text,
  city text,
  snapshot_at timestamptz,
  total_lifetime_revenue_rupees numeric,
  total_lifetime_gross_profit_rupees numeric,
  total_projected_clv_rupees numeric,
  days_active int,
  value_segment text,
  churn_risk_band text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_user_id) *
    FROM public.founder_customer_lifetime_value_snapshots
    ORDER BY hospital_user_id, snapshot_at DESC
  )
  SELECT l.hospital_user_id,
         coalesce(o.name, p.full_name, l.hospital_user_id::text) AS hospital_name,
         o.city,
         l.snapshot_at, l.total_lifetime_revenue_rupees, l.total_lifetime_gross_profit_rupees,
         l.total_projected_clv_rupees, l.days_active, l.value_segment, l.churn_risk_band
  FROM latest l
  LEFT JOIN public.profiles p ON p.user_id = l.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY l.total_projected_clv_rupees DESC NULLS LAST
  LIMIT greatest(1, least(p_limit, 200));
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_clv_by_segment()
RETURNS TABLE (
  value_segment text,
  hospital_count int,
  avg_clv_rupees numeric,
  total_clv_rupees numeric,
  avg_days_active numeric,
  critical_risk_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_user_id) *
    FROM public.founder_customer_lifetime_value_snapshots
    ORDER BY hospital_user_id, snapshot_at DESC
  )
  SELECT l.value_segment,
         count(*)::int,
         round(avg(l.total_projected_clv_rupees)::numeric, 2),
         coalesce(sum(l.total_projected_clv_rupees), 0),
         round(avg(l.days_active)::numeric, 1),
         count(*) FILTER (WHERE l.churn_risk_band = 'critical')::int
  FROM latest l
  GROUP BY l.value_segment
  ORDER BY CASE l.value_segment WHEN 'platinum' THEN 1 WHEN 'gold' THEN 2 WHEN 'silver' THEN 3 ELSE 4 END;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_clv_calculate_for_hospital(p_hospital_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_revenue numeric := 0;
  v_payouts numeric := 0;
  v_profit numeric := 0;
  v_days_active int := 0;
  v_remaining_months int := 60;
  v_projected_remaining numeric := 0;
  v_total_clv numeric := 0;
  v_avg_monthly numeric := 0;
  v_segment text := 'bronze';
  v_band text := 'low';
  v_last_activity timestamptz;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT coalesce(sum(monthly_fee_rupees), 0) * 12
    INTO v_revenue
  FROM public.amc_contracts
  WHERE hospital_user_id = p_hospital_user_id AND status IN ('active','expired','cancelled');

  SELECT coalesce(sum(amount_rupees), 0)
    INTO v_payouts
  FROM public.engineer_payouts ep
  JOIN public.repair_jobs rj ON rj.id = ep.repair_job_id
  WHERE rj.hospital_user_id = p_hospital_user_id;

  v_profit := v_revenue - v_payouts;

  SELECT extract(day FROM (now() - min(created_at)))::int
    INTO v_days_active
  FROM public.amc_contracts WHERE hospital_user_id = p_hospital_user_id;
  IF v_days_active IS NULL THEN v_days_active := 0; END IF;

  SELECT max(created_at) INTO v_last_activity
  FROM public.repair_jobs WHERE hospital_user_id = p_hospital_user_id;

  IF v_days_active > 0 THEN
    v_avg_monthly := v_revenue / greatest(v_days_active / 30.0, 1);
  END IF;
  v_projected_remaining := v_avg_monthly * v_remaining_months;
  v_total_clv := v_revenue + v_projected_remaining;

  v_segment := CASE
    WHEN v_total_clv >= 5000000 THEN 'platinum'
    WHEN v_total_clv >= 1500000 THEN 'gold'
    WHEN v_total_clv >= 500000 THEN 'silver'
    ELSE 'bronze' END;

  v_band := CASE
    WHEN v_last_activity IS NULL OR v_last_activity < now() - interval '180 days' THEN 'critical'
    WHEN v_last_activity < now() - interval '90 days' THEN 'high'
    WHEN v_last_activity < now() - interval '45 days' THEN 'medium'
    ELSE 'low' END;

  INSERT INTO public.founder_customer_lifetime_value_snapshots (
    hospital_user_id, total_lifetime_revenue_rupees, total_lifetime_payouts_rupees,
    total_lifetime_gross_profit_rupees, days_active, projected_remaining_months,
    projected_remaining_revenue_rupees, total_projected_clv_rupees,
    churn_risk_band, value_segment, notes
  ) VALUES (
    p_hospital_user_id, v_revenue, v_payouts, v_profit, v_days_active, v_remaining_months,
    v_projected_remaining, v_total_clv, v_band, v_segment, 'auto-computed via founder_clv_calculate_for_hospital'
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_clv_snapshot_all_hospitals()
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_count int := 0;
  r record;
BEGIN
  FOR r IN
    SELECT DISTINCT hospital_user_id
    FROM public.amc_contracts
    WHERE hospital_user_id IS NOT NULL
  LOOP
    BEGIN
      INSERT INTO public.founder_customer_lifetime_value_snapshots (
        hospital_user_id, total_lifetime_revenue_rupees, total_lifetime_payouts_rupees,
        total_lifetime_gross_profit_rupees, days_active, projected_remaining_revenue_rupees,
        total_projected_clv_rupees, churn_risk_band, value_segment, notes
      )
      SELECT r.hospital_user_id, 0, 0, 0, 0, 0, 0, 'low', 'bronze', 'cron-stub';
      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      CONTINUE;
    END;
  END LOOP;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_clv_record_snapshot(
  p_hospital_user_id uuid,
  p_total_revenue numeric,
  p_total_payouts numeric,
  p_days_active int,
  p_segment text,
  p_band text,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_profit numeric;
  v_projected numeric;
  v_clv numeric;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  v_profit := coalesce(p_total_revenue,0) - coalesce(p_total_payouts,0);
  v_projected := CASE WHEN coalesce(p_days_active,0) > 0
                      THEN (coalesce(p_total_revenue,0) / greatest(p_days_active/30.0,1)) * 60
                      ELSE 0 END;
  v_clv := coalesce(p_total_revenue,0) + v_projected;

  INSERT INTO public.founder_customer_lifetime_value_snapshots (
    hospital_user_id, total_lifetime_revenue_rupees, total_lifetime_payouts_rupees,
    total_lifetime_gross_profit_rupees, days_active, projected_remaining_revenue_rupees,
    total_projected_clv_rupees, churn_risk_band, value_segment, notes
  ) VALUES (
    p_hospital_user_id, coalesce(p_total_revenue,0), coalesce(p_total_payouts,0),
    v_profit, coalesce(p_days_active,0), v_projected, v_clv,
    coalesce(p_band,'low'), coalesce(p_segment,'bronze'), p_notes
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_clv_calculator_summary() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_clv_recent_snapshots(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_clv_top_customers(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_clv_by_segment() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_clv_calculate_for_hospital(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.founder_clv_snapshot_all_hospitals() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.log_founder_clv_record_snapshot(uuid, numeric, numeric, int, text, text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.founder_clv_calculator_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_clv_recent_snapshots(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_clv_top_customers(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_clv_by_segment() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_clv_calculate_for_hospital(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_clv_snapshot_all_hospitals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_clv_record_snapshot(uuid, numeric, numeric, int, text, text, text) TO authenticated;

COMMIT;