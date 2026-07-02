-- Round 2524 — Customer loyalty points redemption
-- Tables:
--   customer_loyalty_redemptions_r2524
--   loyalty_repeat_redeem_metrics_r2524
-- RPCs:
--   list_redemptions_r2524
--   list_repeat_metrics_r2524
--   top_redeeming_hospitals_r2524
--   kind_breakdown_r2524
--   satisfaction_distribution_r2524
--   monthly_redemption_trend_r2524
--   champion_focus_r2524

BEGIN;

-- =====================================================================
-- TABLE: customer_loyalty_redemptions_r2524
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.customer_loyalty_redemptions_r2524 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  redemption_at timestamptz NOT NULL DEFAULT now(),
  points_redeemed integer NOT NULL DEFAULT 0,
  redemption_kind text NOT NULL CHECK (redemption_kind IN ('amc_discount','spare_credit','training_pass','conference_invite','branded_swag','exec_dinner')),
  satisfaction_score integer NOT NULL DEFAULT 0 CHECK (satisfaction_score BETWEEN 0 AND 10),
  owner_email text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','fulfilled','cancelled','expired')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_loyalty_redemptions_r2524 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_loyalty_redemptions_r2524;
CREATE POLICY founder_all ON public.customer_loyalty_redemptions_r2524
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE: loyalty_repeat_redeem_metrics_r2524
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.loyalty_repeat_redeem_metrics_r2524 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_redemptions integer NOT NULL DEFAULT 0,
  total_points_redeemed integer NOT NULL DEFAULT 0,
  avg_satisfaction numeric(4,2) NOT NULL DEFAULT 0,
  repeat_redeem_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','at_risk','champion')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.loyalty_repeat_redeem_metrics_r2524 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.loyalty_repeat_redeem_metrics_r2524;
CREATE POLICY founder_all ON public.loyalty_repeat_redeem_metrics_r2524
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
DO $seed$
DECLARE
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
BEGIN
  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_hosp3 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC OFFSET 2 LIMIT 1;

  IF v_hosp1 IS NULL THEN
    RETURN;
  END IF;
  IF v_hosp2 IS NULL THEN v_hosp2 := v_hosp1; END IF;
  IF v_hosp3 IS NULL THEN v_hosp3 := v_hosp1; END IF;

  INSERT INTO public.customer_loyalty_redemptions_r2524
    (hospital_user_id, redemption_at, points_redeemed, redemption_kind, satisfaction_score, owner_email, status, notes)
  VALUES
    (v_hosp1, '2026-05-12'::timestamptz, 2500, 'amc_discount', 9, 'cs-lead@equipseva.in', 'fulfilled', 'Applied to next AMC renewal');

  INSERT INTO public.customer_loyalty_redemptions_r2524
    (hospital_user_id, redemption_at, points_redeemed, redemption_kind, satisfaction_score, owner_email, status, notes)
  VALUES
    (v_hosp1, '2026-06-02'::timestamptz, 800, 'spare_credit', 8, 'cs-lead@equipseva.in', 'fulfilled', 'Probe replacement credit');

  INSERT INTO public.customer_loyalty_redemptions_r2524
    (hospital_user_id, redemption_at, points_redeemed, redemption_kind, satisfaction_score, owner_email, status, notes)
  VALUES
    (v_hosp2, '2026-05-30'::timestamptz, 1500, 'training_pass', 7, 'cs-lead@equipseva.in', 'fulfilled', 'Biomed engineer training cohort-7');

  INSERT INTO public.customer_loyalty_redemptions_r2524
    (hospital_user_id, redemption_at, points_redeemed, redemption_kind, satisfaction_score, owner_email, status, notes)
  VALUES
    (v_hosp3, '2026-06-08'::timestamptz, 5000, 'conference_invite', 10, 'founder@equipseva.in', 'fulfilled', 'AHPI conference Mumbai sponsor pass');

  INSERT INTO public.customer_loyalty_redemptions_r2524
    (hospital_user_id, redemption_at, points_redeemed, redemption_kind, satisfaction_score, owner_email, status, notes)
  VALUES
    (v_hosp2, '2026-06-15'::timestamptz, 300, 'branded_swag', 6, 'cs-lead@equipseva.in', 'pending', 'Mug + tote awaiting shipment');

  INSERT INTO public.loyalty_repeat_redeem_metrics_r2524
    (hospital_user_id, period_start, period_end, total_redemptions, total_points_redeemed, avg_satisfaction, repeat_redeem_rate_pct, status, notes)
  VALUES
    (v_hosp1, '2026-04-01'::date, '2026-06-30'::date, 4, 4100, 8.50, 75.00, 'champion', 'Steady multi-kind redeemer');

  INSERT INTO public.loyalty_repeat_redeem_metrics_r2524
    (hospital_user_id, period_start, period_end, total_redemptions, total_points_redeemed, avg_satisfaction, repeat_redeem_rate_pct, status, notes)
  VALUES
    (v_hosp2, '2026-04-01'::date, '2026-06-30'::date, 2, 1800, 6.50, 40.00, 'monitoring', 'Mid satisfaction; nudge with exec dinner');

  INSERT INTO public.loyalty_repeat_redeem_metrics_r2524
    (hospital_user_id, period_start, period_end, total_redemptions, total_points_redeemed, avg_satisfaction, repeat_redeem_rate_pct, status, notes)
  VALUES
    (v_hosp3, '2026-04-01'::date, '2026-06-30'::date, 1, 5000, 10.00, 20.00, 'at_risk', 'One large redemption then silent — re-engage');
END
$seed$;

-- =====================================================================
-- RPC: list_redemptions_r2524
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_redemptions_r2524()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  redemption_at timestamptz,
  points_redeemed integer,
  redemption_kind text,
  satisfaction_score integer,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.hospital_user_id, p.email,
           r.redemption_at, r.points_redeemed, r.redemption_kind,
           r.satisfaction_score, r.owner_email, r.status, r.notes
    FROM public.customer_loyalty_redemptions_r2524 r
    LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
    ORDER BY r.redemption_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_redemptions_r2524() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_redemptions_r2524() TO authenticated;

-- =====================================================================
-- RPC: list_repeat_metrics_r2524
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_repeat_metrics_r2524()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  period_start date,
  period_end date,
  total_redemptions integer,
  total_points_redeemed integer,
  avg_satisfaction numeric,
  repeat_redeem_rate_pct numeric,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.hospital_user_id, p.email,
           m.period_start, m.period_end, m.total_redemptions, m.total_points_redeemed,
           m.avg_satisfaction, m.repeat_redeem_rate_pct, m.status, m.notes
    FROM public.loyalty_repeat_redeem_metrics_r2524 m
    LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
    ORDER BY m.repeat_redeem_rate_pct DESC, m.total_points_redeemed DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_repeat_metrics_r2524() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_repeat_metrics_r2524() TO authenticated;

-- =====================================================================
-- RPC: top_redeeming_hospitals_r2524
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_redeeming_hospitals_r2524()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  redemption_count bigint,
  total_points bigint,
  avg_satisfaction numeric,
  last_redemption_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.hospital_user_id,
           p.email,
           COUNT(*)::bigint AS redemption_count,
           COALESCE(SUM(r.points_redeemed),0)::bigint AS total_points,
           ROUND(AVG(r.satisfaction_score)::numeric, 2) AS avg_satisfaction,
           MAX(r.redemption_at) AS last_redemption_at
    FROM public.customer_loyalty_redemptions_r2524 r
    LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
    WHERE r.status IN ('fulfilled','pending')
    GROUP BY r.hospital_user_id, p.email
    ORDER BY total_points DESC, redemption_count DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_redeeming_hospitals_r2524() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_redeeming_hospitals_r2524() TO authenticated;

-- =====================================================================
-- RPC: kind_breakdown_r2524
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kind_breakdown_r2524()
RETURNS TABLE (
  redemption_kind text,
  redemption_count bigint,
  total_points bigint,
  avg_satisfaction numeric,
  fulfilled_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.redemption_kind,
           COUNT(*)::bigint AS redemption_count,
           COALESCE(SUM(r.points_redeemed),0)::bigint AS total_points,
           ROUND(AVG(r.satisfaction_score)::numeric, 2) AS avg_satisfaction,
           SUM(CASE WHEN r.status = 'fulfilled' THEN 1 ELSE 0 END)::bigint AS fulfilled_count
    FROM public.customer_loyalty_redemptions_r2524 r
    GROUP BY r.redemption_kind
    ORDER BY total_points DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kind_breakdown_r2524() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_breakdown_r2524() TO authenticated;

-- =====================================================================
-- RPC: satisfaction_distribution_r2524
-- =====================================================================
CREATE OR REPLACE FUNCTION public.satisfaction_distribution_r2524()
RETURNS TABLE (
  bucket text,
  redemption_count bigint,
  total_points bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN r.satisfaction_score >= 9 THEN 'promoter (9-10)'
        WHEN r.satisfaction_score >= 7 THEN 'passive (7-8)'
        WHEN r.satisfaction_score >= 4 THEN 'detractor-mid (4-6)'
        ELSE 'detractor-low (0-3)'
      END AS bucket,
      COUNT(*)::bigint AS redemption_count,
      COALESCE(SUM(r.points_redeemed),0)::bigint AS total_points
    FROM public.customer_loyalty_redemptions_r2524 r
    GROUP BY 1
    ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.satisfaction_distribution_r2524() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satisfaction_distribution_r2524() TO authenticated;

-- =====================================================================
-- RPC: monthly_redemption_trend_r2524
-- =====================================================================
CREATE OR REPLACE FUNCTION public.monthly_redemption_trend_r2524()
RETURNS TABLE (
  month_start date,
  redemption_count bigint,
  total_points bigint,
  avg_satisfaction numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', r.redemption_at)::date AS month_start,
           COUNT(*)::bigint AS redemption_count,
           COALESCE(SUM(r.points_redeemed),0)::bigint AS total_points,
           ROUND(AVG(r.satisfaction_score)::numeric, 2) AS avg_satisfaction
    FROM public.customer_loyalty_redemptions_r2524 r
    GROUP BY 1
    ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_redemption_trend_r2524() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_redemption_trend_r2524() TO authenticated;

-- =====================================================================
-- RPC: champion_focus_r2524
-- =====================================================================
CREATE OR REPLACE FUNCTION public.champion_focus_r2524()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  status text,
  total_redemptions integer,
  total_points_redeemed integer,
  avg_satisfaction numeric,
  repeat_redeem_rate_pct numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.hospital_user_id, p.email, m.status,
           m.total_redemptions, m.total_points_redeemed,
           m.avg_satisfaction, m.repeat_redeem_rate_pct, m.notes
    FROM public.loyalty_repeat_redeem_metrics_r2524 m
    LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
    WHERE m.status IN ('champion','at_risk')
    ORDER BY
      CASE m.status WHEN 'at_risk' THEN 0 WHEN 'champion' THEN 1 ELSE 2 END ASC,
      m.repeat_redeem_rate_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.champion_focus_r2524() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.champion_focus_r2524() TO authenticated;

