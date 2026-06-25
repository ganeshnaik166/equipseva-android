-- Round 2646: Engineer Team Celebration Recognition Program
-- Tracks personal milestones celebrated with engineers and downstream engagement outcomes.

CREATE TABLE IF NOT EXISTS public.engineer_celebrations_r2646 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  celebrated_at timestamptz NOT NULL DEFAULT now(),
  celebration_kind text NOT NULL CHECK (celebration_kind IN ('birthday','anniversary','promotion','marriage','baby','personal_milestone')),
  value_rupees int NOT NULL DEFAULT 0,
  team_present_count int NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.celebration_engagement_outcomes_r2646 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  celebration_id uuid NOT NULL REFERENCES public.engineer_celebrations_r2646(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  engagement_kind text NOT NULL CHECK (engagement_kind IN ('boost','neutral','mixed')),
  retention_signal text NOT NULL CHECK (retention_signal IN ('positive','neutral','negative')),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_celebrations_r2646 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.celebration_engagement_outcomes_r2646 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_celebrations_r2646;
CREATE POLICY founder_all ON public.engineer_celebrations_r2646
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.celebration_engagement_outcomes_r2646;
CREATE POLICY founder_all ON public.celebration_engagement_outcomes_r2646
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed: pick 3 engineers
WITH eng AS (
  SELECT id FROM public.engineers ORDER BY created_at LIMIT 3
), inserted AS (
  INSERT INTO public.engineer_celebrations_r2646 (engineer_user_id, celebrated_at, celebration_kind, value_rupees, team_present_count, owner_email, status, notes)
  SELECT
    e.id,
    (now() - (interval '7 days' * (row_number() OVER ()))),
    (ARRAY['birthday','anniversary','promotion','marriage','baby'])[((row_number() OVER ())::int % 5) + 1],
    1500 + ((row_number() OVER ())::int * 500),
    6 + ((row_number() OVER ())::int * 2),
    'people@equipseva.in',
    (ARRAY['planned','done','done'])[((row_number() OVER ())::int % 3) + 1],
    'Celebration logged by people ops'
  FROM eng e
  RETURNING id
)
INSERT INTO public.celebration_engagement_outcomes_r2646 (celebration_id, observed_at, engagement_kind, retention_signal, owner_email, status, notes)
SELECT
  i.id,
  now() - interval '2 days',
  (ARRAY['boost','neutral','mixed'])[((row_number() OVER ())::int % 3) + 1],
  (ARRAY['positive','neutral','positive'])[((row_number() OVER ())::int % 3) + 1],
  'people@equipseva.in',
  'open',
  'Engagement signal recorded post celebration'
FROM inserted i;

-- RPC 1: list_celebrations
CREATE OR REPLACE FUNCTION public.list_celebrations_r2646()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  celebrated_at timestamptz,
  celebration_kind text,
  value_rupees int,
  team_present_count int,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_user_id, c.celebrated_at, c.celebration_kind,
         c.value_rupees, c.team_present_count, c.owner_email, c.status, c.notes
  FROM public.engineer_celebrations_r2646 c
  ORDER BY c.celebrated_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_celebrations_r2646() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_celebrations_r2646() TO authenticated;

-- RPC 2: list_engagement_outcomes
CREATE OR REPLACE FUNCTION public.list_engagement_outcomes_r2646()
RETURNS TABLE (
  id uuid,
  celebration_id uuid,
  observed_at timestamptz,
  engagement_kind text,
  retention_signal text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.celebration_id, o.observed_at, o.engagement_kind,
         o.retention_signal, o.owner_email, o.status, o.notes
  FROM public.celebration_engagement_outcomes_r2646 o
  ORDER BY o.observed_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_engagement_outcomes_r2646() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engagement_outcomes_r2646() TO authenticated;

-- RPC 3: top_value_focus
CREATE OR REPLACE FUNCTION public.top_value_focus_r2646()
RETURNS TABLE (
  celebration_kind text,
  celebration_count bigint,
  total_value_rupees bigint,
  avg_team_present numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.celebration_kind,
         COUNT(*)::bigint,
         SUM(c.value_rupees)::bigint,
         ROUND(AVG(c.team_present_count)::numeric, 2)
  FROM public.engineer_celebrations_r2646 c
  GROUP BY c.celebration_kind
  ORDER BY SUM(c.value_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_value_focus_r2646() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_focus_r2646() TO authenticated;

-- RPC 4: celebration_kind_distribution
CREATE OR REPLACE FUNCTION public.celebration_kind_distribution_r2646()
RETURNS TABLE (
  celebration_kind text,
  celebration_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.celebration_kind, COUNT(*)::bigint
  FROM public.engineer_celebrations_r2646 c
  GROUP BY c.celebration_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.celebration_kind_distribution_r2646() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.celebration_kind_distribution_r2646() TO authenticated;

-- RPC 5: status_funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2646()
RETURNS TABLE (
  status text,
  celebration_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status, COUNT(*)::bigint
  FROM public.engineer_celebrations_r2646 c
  GROUP BY c.status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2646() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2646() TO authenticated;

-- RPC 6: monthly_celebration_trend
CREATE OR REPLACE FUNCTION public.monthly_celebration_trend_r2646()
RETURNS TABLE (
  month_bucket timestamptz,
  celebration_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', c.celebrated_at) AS month_bucket,
         COUNT(*)::bigint,
         SUM(c.value_rupees)::bigint
  FROM public.engineer_celebrations_r2646 c
  GROUP BY date_trunc('month', c.celebrated_at)
  ORDER BY date_trunc('month', c.celebrated_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_celebration_trend_r2646() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_celebration_trend_r2646() TO authenticated;

-- RPC 7: owner_load
CREATE OR REPLACE FUNCTION public.owner_load_r2646()
RETURNS TABLE (
  owner_email text,
  celebration_count bigint,
  outcome_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.owner_email,
         COUNT(DISTINCT c.id)::bigint,
         COUNT(DISTINCT o.id)::bigint
  FROM public.engineer_celebrations_r2646 c
  LEFT JOIN public.celebration_engagement_outcomes_r2646 o ON o.celebration_id = c.id
  GROUP BY c.owner_email
  ORDER BY COUNT(DISTINCT c.id) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2646() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2646() TO authenticated;
