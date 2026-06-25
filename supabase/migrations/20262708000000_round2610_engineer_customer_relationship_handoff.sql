-- r2610 engineer-customer-relationship-handoff

CREATE TABLE IF NOT EXISTS public.engineer_customer_handoffs_r2610 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outgoing_engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  incoming_engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  handoff_at timestamptz NOT NULL DEFAULT now(),
  relationship_notes_md text,
  intro_meeting_done boolean NOT NULL DEFAULT false,
  csat_after numeric(4,2),
  retention_status text NOT NULL DEFAULT 'retained' CHECK (retention_status IN ('retained','at_risk','lost')),
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.handoff_retention_outcomes_r2610 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handoff_id uuid REFERENCES public.engineer_customer_handoffs_r2610(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('retained','lost','at_risk','improved')),
  revenue_impact_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_handoffs_r2610 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.handoff_retention_outcomes_r2610 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_customer_handoffs_r2610;
CREATE POLICY founder_all ON public.engineer_customer_handoffs_r2610 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.handoff_retention_outcomes_r2610;
CREATE POLICY founder_all ON public.handoff_retention_outcomes_r2610 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.engineer_customer_handoffs_r2610 (handoff_at, relationship_notes_md, intro_meeting_done, csat_after, retention_status, owner_email, status, notes)
VALUES
  ('2026-06-01T10:00:00+05:30'::timestamptz, 'Outgoing eng moved to Bengaluru. Strong rapport with bio-med team.', true, 4.6, 'retained', 'founder@equipseva.in', 'done', 'Smooth transition'),
  ('2026-06-05T09:30:00+05:30'::timestamptz, 'Long-tenured account. Incoming eng needs 2 site visits.', true, 4.2, 'at_risk', 'ops@equipseva.in', 'done', 'Watch closely'),
  ('2026-06-10T11:00:00+05:30'::timestamptz, 'Hospital chain switching procurement lead. Sensitive handoff.', false, NULL, 'at_risk', 'founder@equipseva.in', 'planned', 'Intro pending'),
  ('2026-06-15T14:00:00+05:30'::timestamptz, 'Quick handoff. Junior eng covering during paternity leave.', true, 4.8, 'retained', 'ops@equipseva.in', 'done', 'Short-term'),
  ('2026-06-18T16:00:00+05:30'::timestamptz, 'Lost account during transition. Need post-mortem.', false, 2.5, 'lost', 'founder@equipseva.in', 'done', 'Run debrief');

INSERT INTO public.handoff_retention_outcomes_r2610 (handoff_id, observed_at, outcome_kind, revenue_impact_rupees, owner_email, status, notes)
SELECT id, '2026-06-20T10:00:00+05:30'::timestamptz, 'retained', 180000, 'ops@equipseva.in', 'done', 'AMC renewed'
FROM public.engineer_customer_handoffs_r2610 WHERE retention_status = 'retained' AND status = 'done' LIMIT 1;

INSERT INTO public.handoff_retention_outcomes_r2610 (handoff_id, observed_at, outcome_kind, revenue_impact_rupees, owner_email, status, notes)
SELECT id, '2026-06-22T10:00:00+05:30'::timestamptz, 'improved', 95000, 'founder@equipseva.in', 'open', 'CSAT rising'
FROM public.engineer_customer_handoffs_r2610 WHERE retention_status = 'at_risk' LIMIT 1;

INSERT INTO public.handoff_retention_outcomes_r2610 (handoff_id, observed_at, outcome_kind, revenue_impact_rupees, owner_email, status, notes)
SELECT id, '2026-06-23T10:00:00+05:30'::timestamptz, 'lost', -240000, 'founder@equipseva.in', 'done', 'Churned'
FROM public.engineer_customer_handoffs_r2610 WHERE retention_status = 'lost' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_handoffs_r2610()
RETURNS TABLE (
  id uuid,
  handoff_at timestamptz,
  intro_meeting_done boolean,
  csat_after numeric,
  retention_status text,
  owner_email text,
  status text,
  notes text,
  relationship_notes_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.handoff_at, h.intro_meeting_done, h.csat_after,
         h.retention_status, h.owner_email, h.status, h.notes, h.relationship_notes_md
  FROM public.engineer_customer_handoffs_r2610 h
  ORDER BY h.handoff_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_handoffs_r2610() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_handoffs_r2610() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_outcomes_r2610()
RETURNS TABLE (
  id uuid,
  handoff_id uuid,
  observed_at timestamptz,
  outcome_kind text,
  revenue_impact_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.handoff_id, o.observed_at, o.outcome_kind,
         o.revenue_impact_rupees, o.owner_email, o.status, o.notes
  FROM public.handoff_retention_outcomes_r2610 o
  ORDER BY o.observed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2610() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2610() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_retention_engineers_r2610()
RETURNS TABLE (
  engineer_label text,
  total_handoffs bigint,
  retained_count bigint,
  lost_count bigint,
  retention_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(h.incoming_engineer_user_id::text, 'unassigned') AS engineer_label,
    COUNT(*)::bigint AS total_handoffs,
    COUNT(*) FILTER (WHERE h.retention_status = 'retained')::bigint AS retained_count,
    COUNT(*) FILTER (WHERE h.retention_status = 'lost')::bigint AS lost_count,
    ROUND((COUNT(*) FILTER (WHERE h.retention_status = 'retained')::numeric * 100.0)
          / NULLIF(COUNT(*), 0), 2) AS retention_pct
  FROM public.engineer_customer_handoffs_r2610 h
  GROUP BY engineer_label
  ORDER BY total_handoffs DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_retention_engineers_r2610() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_retention_engineers_r2610() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2610()
RETURNS TABLE (status_label text, handoff_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.status::text AS status_label, COUNT(*)::bigint AS handoff_count
  FROM public.engineer_customer_handoffs_r2610 h
  GROUP BY h.status
  ORDER BY handoff_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2610() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2610() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_handoff_trend_r2610()
RETURNS TABLE (
  month_label text,
  total_handoffs bigint,
  done_handoffs bigint,
  retained_handoffs bigint,
  lost_handoffs bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('month', h.handoff_at), 'YYYY-MM') AS month_label,
    COUNT(*)::bigint AS total_handoffs,
    COUNT(*) FILTER (WHERE h.status = 'done')::bigint AS done_handoffs,
    COUNT(*) FILTER (WHERE h.retention_status = 'retained')::bigint AS retained_handoffs,
    COUNT(*) FILTER (WHERE h.retention_status = 'lost')::bigint AS lost_handoffs
  FROM public.engineer_customer_handoffs_r2610 h
  GROUP BY month_label
  ORDER BY month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_handoff_trend_r2610() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_handoff_trend_r2610() TO authenticated;

CREATE OR REPLACE FUNCTION public.intro_done_rate_r2610()
RETURNS TABLE (metric_label text, metric_value numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'total_handoffs'::text, COUNT(*)::numeric FROM public.engineer_customer_handoffs_r2610
  UNION ALL
  SELECT 'intro_done'::text, COUNT(*)::numeric FROM public.engineer_customer_handoffs_r2610 WHERE intro_meeting_done = true
  UNION ALL
  SELECT 'intro_pending'::text, COUNT(*)::numeric FROM public.engineer_customer_handoffs_r2610 WHERE intro_meeting_done = false
  UNION ALL
  SELECT 'intro_done_pct'::text,
         ROUND((COUNT(*) FILTER (WHERE intro_meeting_done = true)::numeric * 100.0)
               / NULLIF(COUNT(*), 0), 2)
  FROM public.engineer_customer_handoffs_r2610
  UNION ALL
  SELECT 'avg_csat_after'::text, ROUND(AVG(csat_after)::numeric, 2)
  FROM public.engineer_customer_handoffs_r2610 WHERE csat_after IS NOT NULL;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.intro_done_rate_r2610() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.intro_done_rate_r2610() TO authenticated;

CREATE OR REPLACE FUNCTION public.revenue_impact_summary_r2610()
RETURNS TABLE (
  outcome_kind text,
  outcome_count bigint,
  total_revenue_impact_rupees bigint,
  avg_revenue_impact_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.outcome_kind::text,
    COUNT(*)::bigint AS outcome_count,
    COALESCE(SUM(o.revenue_impact_rupees), 0)::bigint AS total_revenue_impact_rupees,
    ROUND(AVG(o.revenue_impact_rupees)::numeric, 2) AS avg_revenue_impact_rupees
  FROM public.handoff_retention_outcomes_r2610 o
  GROUP BY o.outcome_kind
  ORDER BY total_revenue_impact_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.revenue_impact_summary_r2610() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revenue_impact_summary_r2610() TO authenticated;
