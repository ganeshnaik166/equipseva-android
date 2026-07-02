-- Round 2554: engineer-on-the-job-coaching-hours
-- Senior on-job coaching x junior x hours x topics x outcome x certification credit

CREATE TABLE IF NOT EXISTS public.engineer_on_job_coaching_r2554 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  senior_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  junior_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  coached_at timestamptz NOT NULL DEFAULT now(),
  hours numeric NOT NULL DEFAULT 0,
  topic_kind text NOT NULL CHECK (topic_kind IN ('equipment_specific','safety','process','customer_skills','troubleshooting')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  certification_credit_hours numeric NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.on_job_coaching_credits_r2554 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  junior_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_hours numeric NOT NULL DEFAULT 0,
  certified_hours numeric NOT NULL DEFAULT 0,
  certification_target_hours numeric NOT NULL DEFAULT 0,
  certification_status text NOT NULL DEFAULT 'not_started' CHECK (certification_status IN ('not_started','in_progress','eligible','certified','dropped')),
  owner_email text,
  notes text
);

ALTER TABLE public.engineer_on_job_coaching_r2554 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.on_job_coaching_credits_r2554 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_on_job_coaching_r2554;
CREATE POLICY founder_all ON public.engineer_on_job_coaching_r2554
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.on_job_coaching_credits_r2554;
CREATE POLICY founder_all ON public.on_job_coaching_credits_r2554
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed coaching sessions
INSERT INTO public.engineer_on_job_coaching_r2554
  (coached_at, hours, topic_kind, outcome, certification_credit_hours, owner_email, status, notes)
VALUES
  ('2026-05-12 10:00:00'::timestamptz, 2.5, 'equipment_specific', 'positive', 2.5, 'ops@equipseva.in', 'done', 'Ventilator field calibration walkthrough'),
  ('2026-05-21 14:00:00'::timestamptz, 1.5, 'safety', 'positive', 1.5, 'ops@equipseva.in', 'done', 'Electrical isolation drill at hospital site'),
  ('2026-06-03 09:30:00'::timestamptz, 2.0, 'troubleshooting', 'neutral', 1.0, 'ops@equipseva.in', 'done', 'CT scan intermittent fault diagnosis'),
  ('2026-06-12 11:00:00'::timestamptz, 1.0, 'customer_skills', 'negative', 0.0, 'ops@equipseva.in', 'done', 'Junior froze on hospital admin escalation'),
  ('2026-06-25 15:00:00'::timestamptz, 3.0, 'process', 'pending', 0.0, 'ops@equipseva.in', 'planned', 'SOP runthrough for new AMC onboarding');

-- Seed certification credits
INSERT INTO public.on_job_coaching_credits_r2554
  (period_start, period_end, total_hours, certified_hours, certification_target_hours, certification_status, owner_email, notes)
VALUES
  ('2026-04-01', '2026-06-30', 18.5, 14.0, 20.0, 'in_progress', 'ops@equipseva.in', 'On track for Q2 Tier-2 promotion'),
  ('2026-01-01', '2026-03-31', 22.0, 20.0, 20.0, 'certified', 'ops@equipseva.in', 'Promoted to Tier-2 in April'),
  ('2026-04-01', '2026-06-30', 8.0, 5.0, 20.0, 'in_progress', 'ops@equipseva.in', 'Behind schedule, needs senior re-pairing'),
  ('2026-04-01', '2026-06-30', 0.0, 0.0, 20.0, 'not_started', 'ops@equipseva.in', 'New hire onboarded last week');

-- RPC 1: list_coaching_r2554
CREATE OR REPLACE FUNCTION public.list_coaching_r2554()
RETURNS TABLE (
  id uuid,
  senior_engineer_user_id uuid,
  junior_engineer_user_id uuid,
  coached_at timestamptz,
  hours numeric,
  topic_kind text,
  outcome text,
  certification_credit_hours numeric,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.senior_engineer_user_id, c.junior_engineer_user_id, c.coached_at,
         c.hours, c.topic_kind, c.outcome, c.certification_credit_hours,
         c.owner_email, c.status, c.notes, c.created_at
  FROM public.engineer_on_job_coaching_r2554 c
  ORDER BY c.coached_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_coaching_r2554() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coaching_r2554() TO authenticated;

-- RPC 2: list_credits_r2554
CREATE OR REPLACE FUNCTION public.list_credits_r2554()
RETURNS TABLE (
  id uuid,
  junior_engineer_user_id uuid,
  period_start date,
  period_end date,
  total_hours numeric,
  certified_hours numeric,
  certification_target_hours numeric,
  certification_status text,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.junior_engineer_user_id, k.period_start, k.period_end,
         k.total_hours, k.certified_hours, k.certification_target_hours,
         k.certification_status, k.owner_email, k.notes, k.created_at
  FROM public.on_job_coaching_credits_r2554 k
  ORDER BY k.period_end DESC NULLS LAST, k.created_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_credits_r2554() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_credits_r2554() TO authenticated;

-- RPC 3: top_coached_juniors_r2554
CREATE OR REPLACE FUNCTION public.top_coached_juniors_r2554()
RETURNS TABLE (
  junior_engineer_user_id uuid,
  session_count bigint,
  total_hours numeric,
  certification_credit_total numeric,
  positive_outcomes bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.junior_engineer_user_id,
         COUNT(*)::bigint AS session_count,
         COALESCE(SUM(c.hours),0)::numeric AS total_hours,
         COALESCE(SUM(c.certification_credit_hours),0)::numeric AS certification_credit_total,
         COUNT(*) FILTER (WHERE c.outcome = 'positive')::bigint AS positive_outcomes
  FROM public.engineer_on_job_coaching_r2554 c
  GROUP BY c.junior_engineer_user_id
  ORDER BY total_hours DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_coached_juniors_r2554() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_coached_juniors_r2554() TO authenticated;

-- RPC 4: topic_kind_breakdown_r2554
CREATE OR REPLACE FUNCTION public.topic_kind_breakdown_r2554()
RETURNS TABLE (
  topic_kind text,
  session_count bigint,
  total_hours numeric,
  avg_credit_hours numeric,
  positive_count bigint,
  negative_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.topic_kind,
         COUNT(*)::bigint AS session_count,
         COALESCE(SUM(c.hours),0)::numeric AS total_hours,
         ROUND(AVG(c.certification_credit_hours)::numeric, 2) AS avg_credit_hours,
         COUNT(*) FILTER (WHERE c.outcome = 'positive')::bigint AS positive_count,
         COUNT(*) FILTER (WHERE c.outcome = 'negative')::bigint AS negative_count
  FROM public.engineer_on_job_coaching_r2554 c
  GROUP BY c.topic_kind
  ORDER BY total_hours DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.topic_kind_breakdown_r2554() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.topic_kind_breakdown_r2554() TO authenticated;

-- RPC 5: certification_status_summary_r2554
CREATE OR REPLACE FUNCTION public.certification_status_summary_r2554()
RETURNS TABLE (
  certification_status text,
  junior_count bigint,
  total_hours_sum numeric,
  certified_hours_sum numeric,
  target_hours_sum numeric,
  pct_to_target numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.certification_status,
         COUNT(*)::bigint AS junior_count,
         COALESCE(SUM(k.total_hours),0)::numeric AS total_hours_sum,
         COALESCE(SUM(k.certified_hours),0)::numeric AS certified_hours_sum,
         COALESCE(SUM(k.certification_target_hours),0)::numeric AS target_hours_sum,
         CASE WHEN COALESCE(SUM(k.certification_target_hours),0) = 0 THEN 0
              ELSE ROUND((SUM(k.certified_hours) / SUM(k.certification_target_hours) * 100)::numeric, 1)
         END AS pct_to_target
  FROM public.on_job_coaching_credits_r2554 k
  GROUP BY k.certification_status
  ORDER BY junior_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.certification_status_summary_r2554() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.certification_status_summary_r2554() TO authenticated;

-- RPC 6: monthly_hours_trend_r2554
CREATE OR REPLACE FUNCTION public.monthly_hours_trend_r2554()
RETURNS TABLE (
  month_label text,
  session_count bigint,
  total_hours numeric,
  certification_credit_total numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', c.coached_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS session_count,
         COALESCE(SUM(c.hours),0)::numeric AS total_hours,
         COALESCE(SUM(c.certification_credit_hours),0)::numeric AS certification_credit_total
  FROM public.engineer_on_job_coaching_r2554 c
  GROUP BY 1
  ORDER BY 1 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_hours_trend_r2554() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_hours_trend_r2554() TO authenticated;

-- RPC 7: owner_load_r2554
CREATE OR REPLACE FUNCTION public.owner_load_r2554()
RETURNS TABLE (
  owner_email text,
  session_count bigint,
  total_hours numeric,
  certification_credit_total numeric,
  juniors_tracked bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(c.owner_email, 'unassigned') AS owner_email,
         COUNT(*)::bigint AS session_count,
         COALESCE(SUM(c.hours),0)::numeric AS total_hours,
         COALESCE(SUM(c.certification_credit_hours),0)::numeric AS certification_credit_total,
         COUNT(DISTINCT c.junior_engineer_user_id)::bigint AS juniors_tracked
  FROM public.engineer_on_job_coaching_r2554 c
  GROUP BY 1
  ORDER BY total_hours DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2554() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2554() TO authenticated;
