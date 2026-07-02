-- Round 2592: customer multi-quarter trend comparison
-- hospital × quarter trend × NPS × CSAT × ARR × engineer × scoreboard × tier movement

CREATE TABLE IF NOT EXISTS public.customer_quarterly_trend_r2592 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  nps int,
  csat numeric(4,2),
  arr_rupees bigint,
  top_engineer_email text,
  scoreboard_position int,
  tier_kind text NOT NULL CHECK (tier_kind IN ('bronze','silver','gold','platinum','diamond')),
  tier_movement_kind text NOT NULL CHECK (tier_movement_kind IN ('promoted','maintained','downgraded','lapsed')),
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','final','published')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trend_alert_actions_r2592 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trend_id uuid NOT NULL REFERENCES public.customer_quarterly_trend_r2592(id) ON DELETE CASCADE,
  alert_at timestamptz NOT NULL DEFAULT now(),
  alert_kind text NOT NULL CHECK (alert_kind IN ('declining_nps','declining_arr','tier_downgrade','scoreboard_drop')),
  action_summary_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_quarterly_trend_r2592 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trend_alert_actions_r2592 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_quarterly_trend_r2592;
CREATE POLICY founder_all ON public.customer_quarterly_trend_r2592
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.trend_alert_actions_r2592;
CREATE POLICY founder_all ON public.trend_alert_actions_r2592
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_hospital uuid;
  v_t1 uuid;
  v_t2 uuid;
  v_t3 uuid;
  v_t4 uuid;
BEGIN
  SELECT id INTO v_hospital FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  IF v_hospital IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.customer_quarterly_trend_r2592 (hospital_user_id, quarter_label, nps, csat, arr_rupees, top_engineer_email, scoreboard_position, tier_kind, tier_movement_kind, owner_email, status, notes)
  VALUES (v_hospital, 'FY26Q1', 62, 4.30, 1800000, 'eng1@equipseva.in', 3, 'gold', 'maintained', 'founder@equipseva.in', 'published', 'baseline quarter')
  RETURNING id INTO v_t1;

  INSERT INTO public.customer_quarterly_trend_r2592 (hospital_user_id, quarter_label, nps, csat, arr_rupees, top_engineer_email, scoreboard_position, tier_kind, tier_movement_kind, owner_email, status, notes)
  VALUES (v_hospital, 'FY26Q2', 68, 4.50, 2100000, 'eng2@equipseva.in', 2, 'platinum', 'promoted', 'founder@equipseva.in', 'published', 'tier up after AMC renewal')
  RETURNING id INTO v_t2;

  INSERT INTO public.customer_quarterly_trend_r2592 (hospital_user_id, quarter_label, nps, csat, arr_rupees, top_engineer_email, scoreboard_position, tier_kind, tier_movement_kind, owner_email, status, notes)
  VALUES (v_hospital, 'FY26Q3', 54, 4.10, 1950000, 'eng2@equipseva.in', 5, 'platinum', 'maintained', 'founder@equipseva.in', 'final', 'NPS dip flagged')
  RETURNING id INTO v_t3;

  INSERT INTO public.customer_quarterly_trend_r2592 (hospital_user_id, quarter_label, nps, csat, arr_rupees, top_engineer_email, scoreboard_position, tier_kind, tier_movement_kind, owner_email, status, notes)
  VALUES (v_hospital, 'FY26Q4', 48, 3.90, 1750000, 'eng3@equipseva.in', 8, 'gold', 'downgraded', 'founder@equipseva.in', 'draft', 'churn risk rising')
  RETURNING id INTO v_t4;

  INSERT INTO public.trend_alert_actions_r2592 (trend_id, alert_kind, action_summary_md, owner_email, status, notes) VALUES
    (v_t3, 'declining_nps', '## NPS dropped 14pts\nCalled hospital admin, scheduled QBR.', 'founder@equipseva.in', 'in_progress', 'QBR booked Jul 5'),
    (v_t4, 'tier_downgrade', '## Tier downgrade\nLost platinum status due to missed SLA.', 'founder@equipseva.in', 'open', 'recovery plan needed'),
    (v_t4, 'scoreboard_drop', '## Scoreboard slipped\nFell from rank 5 to rank 8.', 'founder@equipseva.in', 'open', 'investigate causes'),
    (v_t4, 'declining_arr', '## ARR contracted', 'founder@equipseva.in', 'open', 'price-pressure suspected');
END
$seed$;

-- list_trend_r2592
CREATE OR REPLACE FUNCTION public.list_trend_r2592()
RETURNS TABLE(id uuid, hospital_user_id uuid, quarter_label text, nps int, csat numeric, arr_rupees bigint, top_engineer_email text, scoreboard_position int, tier_kind text, tier_movement_kind text, owner_email text, status text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_user_id, t.quarter_label, t.nps, t.csat, t.arr_rupees, t.top_engineer_email,
         t.scoreboard_position, t.tier_kind, t.tier_movement_kind, t.owner_email, t.status, t.notes, t.created_at
  FROM public.customer_quarterly_trend_r2592 t
  ORDER BY t.created_at DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_trend_r2592() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_trend_r2592() TO authenticated;

-- list_alert_actions_r2592
CREATE OR REPLACE FUNCTION public.list_alert_actions_r2592()
RETURNS TABLE(id uuid, trend_id uuid, alert_at timestamptz, alert_kind text, action_summary_md text, owner_email text, status text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.trend_id, a.alert_at, a.alert_kind, a.action_summary_md, a.owner_email, a.status, a.notes, a.created_at
  FROM public.trend_alert_actions_r2592 a
  ORDER BY a.alert_at DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_alert_actions_r2592() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_alert_actions_r2592() TO authenticated;

-- top_arr_quarters_r2592
CREATE OR REPLACE FUNCTION public.top_arr_quarters_r2592()
RETURNS TABLE(quarter_label text, total_arr_rupees bigint, hospital_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.quarter_label, COALESCE(SUM(t.arr_rupees), 0)::bigint, COUNT(DISTINCT t.hospital_user_id)::bigint
  FROM public.customer_quarterly_trend_r2592 t
  GROUP BY t.quarter_label
  ORDER BY 2 DESC NULLS LAST
  LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_arr_quarters_r2592() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_quarters_r2592() TO authenticated;

-- tier_movement_distribution_r2592
CREATE OR REPLACE FUNCTION public.tier_movement_distribution_r2592()
RETURNS TABLE(tier_movement_kind text, n bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.tier_movement_kind, COUNT(*)::bigint
  FROM public.customer_quarterly_trend_r2592 t
  GROUP BY t.tier_movement_kind
  ORDER BY 2 DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.tier_movement_distribution_r2592() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tier_movement_distribution_r2592() TO authenticated;

-- scoreboard_top_summary_r2592
CREATE OR REPLACE FUNCTION public.scoreboard_top_summary_r2592()
RETURNS TABLE(quarter_label text, best_position int, worst_position int, avg_position numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.quarter_label, MIN(t.scoreboard_position)::int, MAX(t.scoreboard_position)::int, ROUND(AVG(t.scoreboard_position)::numeric, 2)
  FROM public.customer_quarterly_trend_r2592 t
  WHERE t.scoreboard_position IS NOT NULL
  GROUP BY t.quarter_label
  ORDER BY 1 ASC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.scoreboard_top_summary_r2592() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.scoreboard_top_summary_r2592() TO authenticated;

-- monthly_alert_trend_r2592
CREATE OR REPLACE FUNCTION public.monthly_alert_trend_r2592()
RETURNS TABLE(month_label text, n bigint, open_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', a.alert_at), 'YYYY-MM'),
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE a.status = 'open')::bigint
  FROM public.trend_alert_actions_r2592 a
  GROUP BY 1
  ORDER BY 1 DESC NULLS LAST
  LIMIT 24;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_alert_trend_r2592() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_alert_trend_r2592() TO authenticated;

-- quarterly_summary_r2592
CREATE OR REPLACE FUNCTION public.quarterly_summary_r2592()
RETURNS TABLE(quarter_label text, avg_nps numeric, avg_csat numeric, total_arr_rupees bigint, hospitals bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.quarter_label,
         ROUND(AVG(t.nps)::numeric, 2),
         ROUND(AVG(t.csat)::numeric, 2),
         COALESCE(SUM(t.arr_rupees), 0)::bigint,
         COUNT(DISTINCT t.hospital_user_id)::bigint
  FROM public.customer_quarterly_trend_r2592 t
  GROUP BY t.quarter_label
  ORDER BY 1 ASC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_summary_r2592() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_summary_r2592() TO authenticated;
