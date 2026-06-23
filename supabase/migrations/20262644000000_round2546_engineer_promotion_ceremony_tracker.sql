-- Round 2546: engineer-promotion-ceremony-tracker
-- Tracks engineer promotion ceremonies + followup retention/performance outcomes.

CREATE TABLE IF NOT EXISTS public.engineer_promotion_ceremonies_r2546 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  promoted_at timestamptz,
  from_tier text NOT NULL CHECK (from_tier IN ('t1','t2','t3','t4','t5')),
  to_tier text NOT NULL CHECK (to_tier IN ('t1','t2','t3','t4','t5')),
  ceremony_kind text NOT NULL CHECK (ceremony_kind IN ('internal_huddle','all_hands','team_lunch','founder_dinner','anniversary_event')),
  bonus_rupees int NOT NULL DEFAULT 0,
  team_celebration boolean NOT NULL DEFAULT false,
  engineer_pride_score int NOT NULL DEFAULT 5 CHECK (engineer_pride_score BETWEEN 0 AND 10),
  retention_boost_expected_months int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.promotion_followup_outcomes_r2546 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ceremony_id uuid NOT NULL REFERENCES public.engineer_promotion_ceremonies_r2546(id) ON DELETE CASCADE,
  observed_at timestamptz,
  retention_status text NOT NULL CHECK (retention_status IN ('retained','exited','at_risk')),
  nps_lift_delta int NOT NULL DEFAULT 0,
  performance_lift_pct numeric(6,2) NOT NULL DEFAULT 0,
  lessons_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_promotion_ceremonies_r2546 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotion_followup_outcomes_r2546 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_promotion_ceremonies_r2546;
CREATE POLICY founder_all ON public.engineer_promotion_ceremonies_r2546
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.promotion_followup_outcomes_r2546;
CREATE POLICY founder_all ON public.promotion_followup_outcomes_r2546
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed ceremonies
INSERT INTO public.engineer_promotion_ceremonies_r2546
  (id, engineer_user_id, promoted_at, from_tier, to_tier, ceremony_kind, bonus_rupees, team_celebration, engineer_pride_score, retention_boost_expected_months, owner_email, status, notes)
VALUES
  ('aaaaaaa1-0000-0000-0000-000000000001'::uuid, NULL, '2026-01-20 16:00:00'::timestamptz, 't2', 't3', 'team_lunch', 15000, true, 9, 12, 'founder@equipseva.in', 'done', 'Team lunch + bonus, high pride'),
  ('aaaaaaa2-0000-0000-0000-000000000002'::uuid, NULL, '2026-02-14 18:30:00'::timestamptz, 't3', 't4', 'founder_dinner', 25000, true, 10, 18, 'founder@equipseva.in', 'done', 'Founder dinner, top performer'),
  ('aaaaaaa3-0000-0000-0000-000000000003'::uuid, NULL, '2026-03-05 10:00:00'::timestamptz, 't1', 't2', 'internal_huddle', 5000, false, 6, 6, 'founder@equipseva.in', 'done', 'Quick internal huddle only'),
  ('aaaaaaa4-0000-0000-0000-000000000004'::uuid, NULL, '2026-04-12 14:00:00'::timestamptz, 't4', 't5', 'all_hands', 50000, true, 10, 24, 'founder@equipseva.in', 'done', 'All-hands recognition, marquee promo'),
  ('aaaaaaa5-0000-0000-0000-000000000005'::uuid, NULL, '2026-06-30 17:00:00'::timestamptz, 't2', 't3', 'anniversary_event', 18000, true, 8, 12, 'founder@equipseva.in', 'planned', 'Tied to 2yr work anniversary');

-- Seed followup outcomes
INSERT INTO public.promotion_followup_outcomes_r2546
  (ceremony_id, observed_at, retention_status, nps_lift_delta, performance_lift_pct, lessons_md, owner_email, notes)
VALUES
  ('aaaaaaa1-0000-0000-0000-000000000001'::uuid, '2026-04-20 12:00:00'::timestamptz, 'retained', 12, 18.50, '- Team lunch creates lasting bond\n- Bonus appreciated', 'founder@equipseva.in', '90d followup positive'),
  ('aaaaaaa2-0000-0000-0000-000000000002'::uuid, '2026-05-14 11:00:00'::timestamptz, 'retained', 18, 24.00, '- Founder dinner = highest leverage signal\n- Repeat for top quartile', 'founder@equipseva.in', 'Big perf lift'),
  ('aaaaaaa3-0000-0000-0000-000000000003'::uuid, '2026-06-05 09:30:00'::timestamptz, 'at_risk', 2, 5.20, '- Skipping team celebration kills pride\n- Always do at least team_lunch', 'founder@equipseva.in', 'Engineer disengaged, low ceremony'),
  ('aaaaaaa4-0000-0000-0000-000000000004'::uuid, '2026-06-12 15:00:00'::timestamptz, 'retained', 22, 30.00, '- All-hands moment compounds culture\n- Bonus + visibility = retention lock', 'founder@equipseva.in', 'Marquee outcome');

-- RPCs

CREATE OR REPLACE FUNCTION public.list_ceremonies_r2546()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  promoted_at timestamptz,
  from_tier text,
  to_tier text,
  ceremony_kind text,
  bonus_rupees int,
  team_celebration boolean,
  engineer_pride_score int,
  retention_boost_expected_months int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_user_id, c.promoted_at, c.from_tier, c.to_tier, c.ceremony_kind,
         c.bonus_rupees, c.team_celebration, c.engineer_pride_score, c.retention_boost_expected_months,
         c.owner_email, c.status, c.notes, c.created_at
    FROM public.engineer_promotion_ceremonies_r2546 c
   ORDER BY c.promoted_at DESC NULLS LAST, c.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_ceremonies_r2546() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ceremonies_r2546() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_followup_outcomes_r2546()
RETURNS TABLE (
  id uuid,
  ceremony_id uuid,
  observed_at timestamptz,
  retention_status text,
  nps_lift_delta int,
  performance_lift_pct numeric,
  lessons_md text,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.ceremony_id, o.observed_at, o.retention_status, o.nps_lift_delta,
         o.performance_lift_pct, o.lessons_md, o.owner_email, o.notes, o.created_at
    FROM public.promotion_followup_outcomes_r2546 o
   ORDER BY o.observed_at DESC NULLS LAST, o.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_followup_outcomes_r2546() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followup_outcomes_r2546() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_celebration_count_r2546()
RETURNS TABLE (
  team_celebration boolean,
  ceremonies_count bigint,
  avg_pride numeric,
  avg_retention_boost numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.team_celebration,
         COUNT(*)::bigint,
         ROUND(AVG(c.engineer_pride_score)::numeric, 2),
         ROUND(AVG(c.retention_boost_expected_months)::numeric, 2)
    FROM public.engineer_promotion_ceremonies_r2546 c
   GROUP BY c.team_celebration
   ORDER BY c.team_celebration DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_celebration_count_r2546() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_celebration_count_r2546() TO authenticated;

CREATE OR REPLACE FUNCTION public.ceremony_kind_breakdown_r2546()
RETURNS TABLE (
  ceremony_kind text,
  ceremonies_count bigint,
  avg_bonus_rupees numeric,
  avg_pride numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.ceremony_kind,
         COUNT(*)::bigint,
         ROUND(AVG(c.bonus_rupees)::numeric, 2),
         ROUND(AVG(c.engineer_pride_score)::numeric, 2)
    FROM public.engineer_promotion_ceremonies_r2546 c
   GROUP BY c.ceremony_kind
   ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.ceremony_kind_breakdown_r2546() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ceremony_kind_breakdown_r2546() TO authenticated;

CREATE OR REPLACE FUNCTION public.retention_correlation_r2546()
RETURNS TABLE (
  retention_status text,
  outcomes_count bigint,
  avg_nps_lift numeric,
  avg_perf_lift_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.retention_status,
         COUNT(*)::bigint,
         ROUND(AVG(o.nps_lift_delta)::numeric, 2),
         ROUND(AVG(o.performance_lift_pct)::numeric, 2)
    FROM public.promotion_followup_outcomes_r2546 o
   GROUP BY o.retention_status
   ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.retention_correlation_r2546() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retention_correlation_r2546() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_ceremony_trend_r2546()
RETURNS TABLE (
  month_bucket text,
  ceremonies_count bigint,
  total_bonus_rupees bigint,
  avg_pride numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', c.promoted_at), 'YYYY-MM') AS month_bucket,
         COUNT(*)::bigint,
         COALESCE(SUM(c.bonus_rupees),0)::bigint,
         ROUND(AVG(c.engineer_pride_score)::numeric, 2)
    FROM public.engineer_promotion_ceremonies_r2546 c
   WHERE c.promoted_at IS NOT NULL
   GROUP BY date_trunc('month', c.promoted_at)
   ORDER BY date_trunc('month', c.promoted_at) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_ceremony_trend_r2546() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_ceremony_trend_r2546() TO authenticated;

CREATE OR REPLACE FUNCTION public.total_bonus_summary_r2546()
RETURNS TABLE (
  status text,
  ceremonies_count bigint,
  total_bonus_rupees bigint,
  avg_retention_boost numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status,
         COUNT(*)::bigint,
         COALESCE(SUM(c.bonus_rupees),0)::bigint,
         ROUND(AVG(c.retention_boost_expected_months)::numeric, 2)
    FROM public.engineer_promotion_ceremonies_r2546 c
   GROUP BY c.status
   ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.total_bonus_summary_r2546() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_bonus_summary_r2546() TO authenticated;
