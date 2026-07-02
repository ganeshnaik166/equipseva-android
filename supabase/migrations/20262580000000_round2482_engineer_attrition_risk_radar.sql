-- Round 2482: Engineer Attrition Risk Radar
-- Tracks flight risk signals + retention plan execution per engineer.

CREATE TABLE IF NOT EXISTS public.engineer_attrition_signals_r2482 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  tenure_months int NOT NULL CHECK (tenure_months >= 0),
  current_comp_rupees bigint NOT NULL CHECK (current_comp_rupees >= 0),
  market_comp_gap_pct numeric(6,2) NOT NULL,
  satisfaction_score int NOT NULL CHECK (satisfaction_score BETWEEN 0 AND 10),
  side_opportunity_kind text NOT NULL CHECK (side_opportunity_kind IN ('none','recruiter_calls','internal_inquiry','exit_signal','peer_resignation')),
  flight_risk_score int NOT NULL CHECK (flight_risk_score BETWEEN 0 AND 100),
  top_risk text NOT NULL,
  last_assessed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','in_intervention','saved','exited')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_attrition_signals_r2482 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON public.engineer_attrition_signals_r2482
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.attrition_retention_plans_r2482 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  opened_at timestamptz NOT NULL DEFAULT now(),
  plan_kind text NOT NULL CHECK (plan_kind IN ('comp_bump','role_change','coaching','sabbatical','transfer')),
  recommended_action_md text NOT NULL,
  owner_email text NOT NULL,
  action_due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('retained','exited','dropped','pending')),
  closed_at timestamptz,
  closed_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.attrition_retention_plans_r2482 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON public.attrition_retention_plans_r2482
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_eng4 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at OFFSET 2 LIMIT 1;
  SELECT id INTO v_eng4 FROM public.engineers ORDER BY created_at OFFSET 3 LIMIT 1;

  IF v_eng1 IS NOT NULL THEN
    INSERT INTO public.engineer_attrition_signals_r2482 (engineer_user_id, tenure_months, current_comp_rupees, market_comp_gap_pct, satisfaction_score, side_opportunity_kind, flight_risk_score, top_risk, last_assessed_at, status, notes)
    VALUES (v_eng1, 28, 4800000, 22.50, 4, 'recruiter_calls', 82, 'Comp gap + active recruiter pings', now() - interval '2 days', 'in_intervention', 'Top performer; need comp adjustment fast');

    INSERT INTO public.attrition_retention_plans_r2482 (engineer_user_id, opened_at, plan_kind, recommended_action_md, owner_email, action_due_at, status, outcome, notes)
    VALUES (v_eng1, now() - interval '2 days', 'comp_bump', '- Approve 18% hike\n- Stock refresh grant', 'founder@equipseva.in', now() + interval '5 days', 'in_progress', 'pending', 'CFO sign-off pending');
  END IF;

  IF v_eng2 IS NOT NULL THEN
    INSERT INTO public.engineer_attrition_signals_r2482 (engineer_user_id, tenure_months, current_comp_rupees, market_comp_gap_pct, satisfaction_score, side_opportunity_kind, flight_risk_score, top_risk, last_assessed_at, status, notes)
    VALUES (v_eng2, 14, 3200000, 8.00, 7, 'none', 28, 'Healthy engagement; monitor', now() - interval '5 days', 'monitoring', 'Stable; check in quarterly');
  END IF;

  IF v_eng3 IS NOT NULL THEN
    INSERT INTO public.engineer_attrition_signals_r2482 (engineer_user_id, tenure_months, current_comp_rupees, market_comp_gap_pct, satisfaction_score, side_opportunity_kind, flight_risk_score, top_risk, last_assessed_at, status, notes)
    VALUES (v_eng3, 36, 5200000, 15.00, 5, 'peer_resignation', 67, 'Peer just resigned; contagion risk', now() - interval '1 day', 'in_intervention', 'Pair with new mentor');

    INSERT INTO public.attrition_retention_plans_r2482 (engineer_user_id, opened_at, plan_kind, recommended_action_md, owner_email, action_due_at, status, outcome, closed_at, closed_by_email, notes)
    VALUES (v_eng3, now() - interval '20 days', 'role_change', '- Move to senior architect track\n- New project assignment', 'founder@equipseva.in', now() - interval '5 days', 'done', 'retained', now() - interval '3 days', 'founder@equipseva.in', 'Accepted; energized by new scope');
  END IF;

  IF v_eng4 IS NOT NULL THEN
    INSERT INTO public.engineer_attrition_signals_r2482 (engineer_user_id, tenure_months, current_comp_rupees, market_comp_gap_pct, satisfaction_score, side_opportunity_kind, flight_risk_score, top_risk, last_assessed_at, status, notes)
    VALUES (v_eng4, 8, 2800000, 5.00, 8, 'internal_inquiry', 35, 'Asking for vertical move; healthy', now() - interval '7 days', 'monitoring', 'Discuss internal transfer in 1:1');

    INSERT INTO public.attrition_retention_plans_r2482 (engineer_user_id, opened_at, plan_kind, recommended_action_md, owner_email, action_due_at, status, outcome, notes)
    VALUES (v_eng4, now() - interval '10 days', 'transfer', '- Move to platform team\n- 2-week shadowing first', 'founder@equipseva.in', now() + interval '14 days', 'open', 'pending', 'Awaiting target team capacity');
  END IF;
END
$seed$;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_signals_r2482()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  tenure_months int,
  current_comp_rupees bigint,
  market_comp_gap_pct numeric,
  satisfaction_score int,
  side_opportunity_kind text,
  flight_risk_score int,
  top_risk text,
  last_assessed_at timestamptz,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, p.email, s.tenure_months, s.current_comp_rupees,
         s.market_comp_gap_pct, s.satisfaction_score, s.side_opportunity_kind,
         s.flight_risk_score, s.top_risk, s.last_assessed_at, s.status, s.notes
  FROM public.engineer_attrition_signals_r2482 s
  LEFT JOIN public.engineers e ON e.id = s.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY s.flight_risk_score DESC, s.last_assessed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_signals_r2482() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_signals_r2482() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_retention_plans_r2482()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  opened_at timestamptz,
  plan_kind text,
  recommended_action_md text,
  owner_email text,
  action_due_at timestamptz,
  status text,
  outcome text,
  closed_at timestamptz,
  closed_by_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT rp.id, rp.engineer_user_id, p.email, rp.opened_at, rp.plan_kind,
         rp.recommended_action_md, rp.owner_email, rp.action_due_at, rp.status,
         rp.outcome, rp.closed_at, rp.closed_by_email, rp.notes
  FROM public.attrition_retention_plans_r2482 rp
  LEFT JOIN public.engineers e ON e.id = rp.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY rp.opened_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_retention_plans_r2482() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_retention_plans_r2482() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_risk_engineers_r2482()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  flight_risk_score int,
  top_risk text,
  tenure_months int,
  market_comp_gap_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_user_id, p.email, s.flight_risk_score, s.top_risk,
         s.tenure_months, s.market_comp_gap_pct, s.status
  FROM public.engineer_attrition_signals_r2482 s
  LEFT JOIN public.engineers e ON e.id = s.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE s.flight_risk_score >= 60
  ORDER BY s.flight_risk_score DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_risk_engineers_r2482() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_risk_engineers_r2482() TO authenticated;

CREATE OR REPLACE FUNCTION public.risk_distribution_r2482()
RETURNS TABLE (
  bucket text,
  engineer_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.bucket, COUNT(s.id)::bigint
  FROM (VALUES ('low_0_29'), ('mid_30_59'), ('high_60_79'), ('critical_80_100')) b(bucket)
  LEFT JOIN public.engineer_attrition_signals_r2482 s ON
    (b.bucket = 'low_0_29' AND s.flight_risk_score BETWEEN 0 AND 29) OR
    (b.bucket = 'mid_30_59' AND s.flight_risk_score BETWEEN 30 AND 59) OR
    (b.bucket = 'high_60_79' AND s.flight_risk_score BETWEEN 60 AND 79) OR
    (b.bucket = 'critical_80_100' AND s.flight_risk_score BETWEEN 80 AND 100)
  GROUP BY b.bucket
  ORDER BY b.bucket;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.risk_distribution_r2482() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.risk_distribution_r2482() TO authenticated;

CREATE OR REPLACE FUNCTION public.side_opportunity_breakdown_r2482()
RETURNS TABLE (
  side_opportunity_kind text,
  engineer_count bigint,
  avg_flight_risk numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.side_opportunity_kind, COUNT(*)::bigint,
         ROUND(AVG(s.flight_risk_score)::numeric, 1)
  FROM public.engineer_attrition_signals_r2482 s
  GROUP BY s.side_opportunity_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.side_opportunity_breakdown_r2482() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.side_opportunity_breakdown_r2482() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_flight_risk_trend_r2482()
RETURNS TABLE (
  month_start timestamptz,
  assessments bigint,
  avg_risk numeric,
  high_risk_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', s.last_assessed_at)::timestamptz,
         COUNT(*)::bigint,
         ROUND(AVG(s.flight_risk_score)::numeric, 1),
         COUNT(*) FILTER (WHERE s.flight_risk_score >= 60)::bigint
  FROM public.engineer_attrition_signals_r2482 s
  WHERE s.last_assessed_at >= (now() - interval '12 months')
  GROUP BY date_trunc('month', s.last_assessed_at)
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_flight_risk_trend_r2482() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_flight_risk_trend_r2482() TO authenticated;

CREATE OR REPLACE FUNCTION public.plan_outcome_summary_r2482()
RETURNS TABLE (
  outcome text,
  plan_count bigint,
  avg_days_to_close numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT rp.outcome, COUNT(*)::bigint,
         ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(rp.closed_at, now()) - rp.opened_at)) / 86400.0)::numeric, 1)
  FROM public.attrition_retention_plans_r2482 rp
  GROUP BY rp.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.plan_outcome_summary_r2482() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plan_outcome_summary_r2482() TO authenticated;
