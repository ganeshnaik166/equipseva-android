-- Round 2603: hospital-chain-quarterly-strategic-account-plan
-- chain × annual plan × initiatives × revenue target × execution scorecard × QBR

CREATE TABLE IF NOT EXISTS public.chain_quarterly_account_plans_r2603 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  initiatives_md text,
  revenue_target_rupees bigint NOT NULL DEFAULT 0,
  execution_scorecard_pct int NOT NULL DEFAULT 0 CHECK (execution_scorecard_pct BETWEEN 0 AND 100),
  qbr_held boolean NOT NULL DEFAULT false,
  qbr_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','aligned','executing','reviewed','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.account_plan_initiative_progress_r2603 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.chain_quarterly_account_plans_r2603(id) ON DELETE CASCADE,
  initiative_label text NOT NULL,
  target_pct int NOT NULL DEFAULT 0 CHECK (target_pct BETWEEN 0 AND 100),
  actual_pct int NOT NULL DEFAULT 0 CHECK (actual_pct BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_quarterly_account_plans_r2603 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_plan_initiative_progress_r2603 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_quarterly_account_plans_r2603;
CREATE POLICY founder_all ON public.chain_quarterly_account_plans_r2603
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.account_plan_initiative_progress_r2603;
CREATE POLICY founder_all ON public.account_plan_initiative_progress_r2603
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_quarterly_account_plans_r2603
  (chain_name, quarter_label, initiatives_md, revenue_target_rupees, execution_scorecard_pct, qbr_held, qbr_at, owner_email, status, notes)
VALUES
  ('Apollo Group','Q3 2026','- Expand AMC coverage to 12 sites; onboard 4 new dental clinics', 4500000, 72, true,  now() - interval '6 days',  'founder@equipseva.in', 'executing', 'On track; AMC renewal cycle Q4'),
  ('Yashoda Hospitals','Q3 2026','- Cardiology HVAC retrofit; spare parts SLA tightening', 2800000, 55, false, NULL,                         'founder@equipseva.in', 'aligned',   'Pending CFO sign-off on retrofit'),
  ('Care Hospitals','Q3 2026','- Pilot dental sterilizer line; quarterly invoice consolidation', 1900000, 40, false, NULL,                  'ops@equipseva.in',     'draft',     'Awaiting procurement intro'),
  ('KIMS','Q2 2026','- AMC tier upgrade; founder QBR done',                                       3200000, 88, true,  now() - interval '38 days', 'founder@equipseva.in', 'reviewed',  'Strong delivery; renew at gold tier'),
  ('Rainbow Children','Q2 2026','- Closeout pediatric warranty audit',                            1100000, 95, true,  now() - interval '52 days', 'founder@equipseva.in', 'closed',    'Closed clean; expansion next FY');

INSERT INTO public.account_plan_initiative_progress_r2603 (plan_id, initiative_label, target_pct, actual_pct, owner_email, status, notes)
SELECT id, 'Expand AMC coverage', 100, 65, 'founder@equipseva.in','in_progress','7/12 sites signed' FROM public.chain_quarterly_account_plans_r2603 WHERE chain_name='Apollo Group' AND quarter_label='Q3 2026';
INSERT INTO public.account_plan_initiative_progress_r2603 (plan_id, initiative_label, target_pct, actual_pct, owner_email, status, notes)
SELECT id, 'Onboard new dental clinics', 100, 50, 'ops@equipseva.in','in_progress','2 of 4 onboarded' FROM public.chain_quarterly_account_plans_r2603 WHERE chain_name='Apollo Group' AND quarter_label='Q3 2026';
INSERT INTO public.account_plan_initiative_progress_r2603 (plan_id, initiative_label, target_pct, actual_pct, owner_email, status, notes)
SELECT id, 'HVAC retrofit', 100, 30, 'founder@equipseva.in','in_progress','CFO meeting scheduled' FROM public.chain_quarterly_account_plans_r2603 WHERE chain_name='Yashoda Hospitals';
INSERT INTO public.account_plan_initiative_progress_r2603 (plan_id, initiative_label, target_pct, actual_pct, owner_email, status, notes)
SELECT id, 'Spare parts SLA tightening', 100, 80, 'ops@equipseva.in','in_progress','SLA doc circulated' FROM public.chain_quarterly_account_plans_r2603 WHERE chain_name='Yashoda Hospitals';
INSERT INTO public.account_plan_initiative_progress_r2603 (plan_id, initiative_label, target_pct, actual_pct, owner_email, status, notes)
SELECT id, 'AMC tier upgrade', 100, 100, 'founder@equipseva.in','done','Closed; gold tier active' FROM public.chain_quarterly_account_plans_r2603 WHERE chain_name='KIMS';

-- RPCs

CREATE OR REPLACE FUNCTION public.list_account_plans_r2603()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  revenue_target_rupees bigint,
  execution_scorecard_pct int,
  qbr_held boolean,
  qbr_at timestamptz,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.chain_name, p.quarter_label, p.revenue_target_rupees, p.execution_scorecard_pct,
           p.qbr_held, p.qbr_at, p.owner_email, p.status, p.notes, p.created_at
    FROM public.chain_quarterly_account_plans_r2603 p
    ORDER BY p.created_at DESC NULLS LAST
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_account_plans_r2603() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_account_plans_r2603() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_initiative_progress_r2603()
RETURNS TABLE (
  id uuid,
  plan_id uuid,
  chain_name text,
  initiative_label text,
  target_pct int,
  actual_pct int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.plan_id, p.chain_name, i.initiative_label, i.target_pct, i.actual_pct,
           i.owner_email, i.status, i.notes, i.created_at
    FROM public.account_plan_initiative_progress_r2603 i
    JOIN public.chain_quarterly_account_plans_r2603 p ON p.id = i.plan_id
    ORDER BY i.created_at DESC NULLS LAST
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_initiative_progress_r2603() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_initiative_progress_r2603() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_revenue_target_r2603()
RETURNS TABLE (
  chain_name text,
  total_target_rupees bigint,
  plans_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.chain_name, SUM(p.revenue_target_rupees)::bigint, COUNT(*)::bigint
    FROM public.chain_quarterly_account_plans_r2603 p
    GROUP BY p.chain_name
    ORDER BY SUM(p.revenue_target_rupees) DESC NULLS LAST
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_revenue_target_r2603() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_revenue_target_r2603() TO authenticated;

CREATE OR REPLACE FUNCTION public.execution_score_summary_r2603()
RETURNS TABLE (
  bucket text,
  plans_count bigint,
  avg_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN p.execution_scorecard_pct >= 80 THEN 'on_track'
        WHEN p.execution_scorecard_pct >= 50 THEN 'watch'
        ELSE 'at_risk'
      END::text AS bucket,
      COUNT(*)::bigint,
      ROUND(AVG(p.execution_scorecard_pct)::numeric, 1)
    FROM public.chain_quarterly_account_plans_r2603 p
    GROUP BY 1
    ORDER BY 1 ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.execution_score_summary_r2603() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.execution_score_summary_r2603() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2603()
RETURNS TABLE (status text, plans_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.status, COUNT(*)::bigint
    FROM public.chain_quarterly_account_plans_r2603 p
    GROUP BY p.status
    ORDER BY COUNT(*) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2603() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2603() TO authenticated;

CREATE OR REPLACE FUNCTION public.qbr_completion_rate_r2603()
RETURNS TABLE (
  total_plans bigint,
  qbr_done bigint,
  qbr_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::bigint,
      COUNT(*) FILTER (WHERE p.qbr_held)::bigint,
      CASE WHEN COUNT(*) = 0 THEN 0
           ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE p.qbr_held) / COUNT(*), 1)
      END
    FROM public.chain_quarterly_account_plans_r2603 p;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.qbr_completion_rate_r2603() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.qbr_completion_rate_r2603() TO authenticated;

CREATE OR REPLACE FUNCTION public.quarterly_plan_trend_r2603()
RETURNS TABLE (
  quarter_label text,
  plans_count bigint,
  total_target_rupees bigint,
  avg_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.quarter_label,
           COUNT(*)::bigint,
           SUM(p.revenue_target_rupees)::bigint,
           ROUND(AVG(p.execution_scorecard_pct)::numeric, 1)
    FROM public.chain_quarterly_account_plans_r2603 p
    GROUP BY p.quarter_label
    ORDER BY p.quarter_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_plan_trend_r2603() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_plan_trend_r2603() TO authenticated;
