-- Round r2578: Engineer customer retention attribution
-- Tables: engineer_retention_attribution_r2578, retention_attribution_events_r2578
-- 7 RPCs guarded by public.is_founder()

CREATE TABLE IF NOT EXISTS public.engineer_retention_attribution_r2578 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  attribution_kind text NOT NULL CHECK (attribution_kind IN ('retention_save','retention_loss','no_impact')),
  observed_at timestamptz NOT NULL DEFAULT now(),
  retention_impact_rupees bigint NOT NULL DEFAULT 0,
  top_factor_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','saved','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.retention_attribution_events_r2578 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attribution_id uuid NOT NULL REFERENCES public.engineer_retention_attribution_r2578(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_kind text NOT NULL CHECK (event_kind IN ('escalation_resolved','proactive_visit','relationship_repair','missed_signal','competitor_save')),
  impact_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_retention_attribution_r2578 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retention_attribution_events_r2578 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_retention_attribution_r2578;
CREATE POLICY founder_all ON public.engineer_retention_attribution_r2578
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.retention_attribution_events_r2578;
CREATE POLICY founder_all ON public.retention_attribution_events_r2578
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed attribution rows
INSERT INTO public.engineer_retention_attribution_r2578
  (id, engineer_user_id, hospital_user_id, attribution_kind, observed_at, retention_impact_rupees, top_factor_md, owner_email, status, notes)
VALUES
  ('33333333-3333-3333-3333-333333333301', NULL, NULL, 'retention_save', '2026-05-12 10:00:00+05:30', 4800000, '- Engineer Rakesh resolved Apollo Hyd CT scanner escalation in 6 hrs\n- Hospital CFO was already evaluating competitor', 'csm@equipseva.in', 'saved', 'Saved Apollo chain ₹48L AMC renewal'),
  ('33333333-3333-3333-3333-333333333302', NULL, NULL, 'retention_loss', '2026-05-20 14:00:00+05:30', -2200000, '- Engineer missed 2 SLA windows on Care Hospital MRI\n- No proactive visit despite warning signals', 'csm@equipseva.in', 'lost', 'Care Hospital churned to GE Healthcare'),
  ('33333333-3333-3333-3333-333333333303', NULL, NULL, 'retention_save', '2026-06-02 11:00:00+05:30', 3100000, '- Engineer Priya did 4 proactive visits in Q1\n- Relationship repair after dispute over spare part delay', 'csm@equipseva.in', 'saved', 'Yashoda Group ₹31L expansion AMC'),
  ('33333333-3333-3333-3333-333333333304', NULL, NULL, 'no_impact', '2026-06-10 09:00:00+05:30', 0, '- Routine maintenance only\n- No churn risk detected', 'csm@equipseva.in', 'monitoring', 'KIMS — stable account'),
  ('33333333-3333-3333-3333-333333333305', NULL, NULL, 'retention_save', '2026-06-18 16:00:00+05:30', 1800000, '- Engineer Suresh competitor-save: matched Philips service quote\n- Trust built over 2 years on Continental Hospitals', 'csm@equipseva.in', 'saved', 'Continental retained ₹18L')
ON CONFLICT (id) DO NOTHING;

-- Seed events
INSERT INTO public.retention_attribution_events_r2578
  (attribution_id, event_at, event_kind, impact_rupees, owner_email, status, notes)
VALUES
  ('33333333-3333-3333-3333-333333333301', '2026-05-10 14:00:00+05:30', 'escalation_resolved', 4800000, 'csm@equipseva.in', 'done', 'CT scanner uptime restored same-day'),
  ('33333333-3333-3333-3333-333333333301', '2026-05-15 11:00:00+05:30', 'relationship_repair', 0, 'csm@equipseva.in', 'done', 'CFO 1:1 lunch'),
  ('33333333-3333-3333-3333-333333333302', '2026-05-18 09:00:00+05:30', 'missed_signal', -2200000, 'csm@equipseva.in', 'done', 'NPS drop ignored 3 weeks'),
  ('33333333-3333-3333-3333-333333333303', '2026-05-25 10:00:00+05:30', 'proactive_visit', 1500000, 'csm@equipseva.in', 'done', 'Quarterly health review'),
  ('33333333-3333-3333-3333-333333333303', '2026-06-01 13:00:00+05:30', 'relationship_repair', 1600000, 'csm@equipseva.in', 'done', 'Apologized for spare part SLA'),
  ('33333333-3333-3333-3333-333333333305', '2026-06-17 11:00:00+05:30', 'competitor_save', 1800000, 'csm@equipseva.in', 'done', 'Matched Philips quote on AMC')
ON CONFLICT (id) DO NOTHING;

-- RPC 1: list_attribution_r2578
CREATE OR REPLACE FUNCTION public.list_attribution_r2578()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  attribution_kind text,
  observed_at timestamptz,
  retention_impact_rupees bigint,
  top_factor_md text,
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
  SELECT a.id, a.engineer_user_id, a.hospital_user_id, a.attribution_kind, a.observed_at,
         a.retention_impact_rupees, a.top_factor_md, a.owner_email, a.status, a.notes, a.created_at
  FROM public.engineer_retention_attribution_r2578 a
  ORDER BY a.observed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_attribution_r2578() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attribution_r2578() TO authenticated;

-- RPC 2: list_events_r2578
CREATE OR REPLACE FUNCTION public.list_events_r2578()
RETURNS TABLE (
  id uuid,
  attribution_id uuid,
  event_at timestamptz,
  event_kind text,
  impact_rupees bigint,
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
  SELECT e.id, e.attribution_id, e.event_at, e.event_kind, e.impact_rupees,
         e.owner_email, e.status, e.notes, e.created_at
  FROM public.retention_attribution_events_r2578 e
  ORDER BY e.event_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_events_r2578() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_events_r2578() TO authenticated;

-- RPC 3: top_save_engineers_r2578
CREATE OR REPLACE FUNCTION public.top_save_engineers_r2578()
RETURNS TABLE (
  engineer_user_id uuid,
  saves int,
  total_saved_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_user_id,
         COUNT(*)::int AS saves,
         COALESCE(SUM(a.retention_impact_rupees), 0)::bigint AS total_saved_rupees
  FROM public.engineer_retention_attribution_r2578 a
  WHERE a.attribution_kind = 'retention_save'
  GROUP BY a.engineer_user_id
  ORDER BY total_saved_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_save_engineers_r2578() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_save_engineers_r2578() TO authenticated;

-- RPC 4: attribution_kind_breakdown_r2578
CREATE OR REPLACE FUNCTION public.attribution_kind_breakdown_r2578()
RETURNS TABLE (
  attribution_kind text,
  total int,
  total_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.attribution_kind,
         COUNT(*)::int AS total,
         COALESCE(SUM(a.retention_impact_rupees), 0)::bigint AS total_impact_rupees
  FROM public.engineer_retention_attribution_r2578 a
  GROUP BY a.attribution_kind
  ORDER BY total DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.attribution_kind_breakdown_r2578() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.attribution_kind_breakdown_r2578() TO authenticated;

-- RPC 5: total_retention_impact_summary_r2578
CREATE OR REPLACE FUNCTION public.total_retention_impact_summary_r2578()
RETURNS TABLE (
  total_attributions int,
  total_saves int,
  total_losses int,
  total_save_rupees bigint,
  total_loss_rupees bigint,
  net_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::int AS total_attributions,
         COUNT(*) FILTER (WHERE a.attribution_kind = 'retention_save')::int AS total_saves,
         COUNT(*) FILTER (WHERE a.attribution_kind = 'retention_loss')::int AS total_losses,
         COALESCE(SUM(a.retention_impact_rupees) FILTER (WHERE a.attribution_kind = 'retention_save'), 0)::bigint AS total_save_rupees,
         COALESCE(SUM(a.retention_impact_rupees) FILTER (WHERE a.attribution_kind = 'retention_loss'), 0)::bigint AS total_loss_rupees,
         COALESCE(SUM(a.retention_impact_rupees), 0)::bigint AS net_impact_rupees
  FROM public.engineer_retention_attribution_r2578 a;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.total_retention_impact_summary_r2578() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_retention_impact_summary_r2578() TO authenticated;

-- RPC 6: monthly_attribution_trend_r2578
CREATE OR REPLACE FUNCTION public.monthly_attribution_trend_r2578()
RETURNS TABLE (
  month_start date,
  total int,
  net_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', a.observed_at)::date AS month_start,
         COUNT(*)::int AS total,
         COALESCE(SUM(a.retention_impact_rupees), 0)::bigint AS net_impact_rupees
  FROM public.engineer_retention_attribution_r2578 a
  GROUP BY date_trunc('month', a.observed_at)
  ORDER BY month_start DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_attribution_trend_r2578() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_attribution_trend_r2578() TO authenticated;

-- RPC 7: owner_load_r2578
CREATE OR REPLACE FUNCTION public.owner_load_r2578()
RETURNS TABLE (
  owner_email text,
  open_attributions int,
  open_events int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(a.owner_email, e.owner_email) AS owner_email,
         COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'monitoring')::int AS open_attributions,
         COUNT(DISTINCT e.id) FILTER (WHERE e.status = 'open')::int AS open_events
  FROM public.engineer_retention_attribution_r2578 a
  FULL OUTER JOIN public.retention_attribution_events_r2578 e
    ON e.owner_email = a.owner_email
  GROUP BY COALESCE(a.owner_email, e.owner_email)
  ORDER BY open_attributions DESC NULLS LAST, open_events DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2578() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2578() TO authenticated;
