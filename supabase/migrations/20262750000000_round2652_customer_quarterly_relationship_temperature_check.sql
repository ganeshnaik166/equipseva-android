-- Round 2652 — customer-quarterly-relationship-temperature-check
-- Tables: customer_relationship_temperature_r2652 + temperature_intervention_actions_r2652
-- 7 founder-only RPCs

CREATE TABLE IF NOT EXISTS public.customer_relationship_temperature_r2652 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  temperature_kind text NOT NULL CHECK (temperature_kind IN ('cold','cool','warm','hot','burning')),
  top_signals_md text,
  action_required boolean NOT NULL DEFAULT false,
  action_owner_email text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','intervening','recovered','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.temperature_intervention_actions_r2652 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  temp_id uuid NOT NULL REFERENCES public.customer_relationship_temperature_r2652(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('call','visit','discount','founder_intro','case_study_offer')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_relationship_temperature_r2652 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temperature_intervention_actions_r2652 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_relationship_temperature_r2652;
CREATE POLICY founder_all ON public.customer_relationship_temperature_r2652 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.temperature_intervention_actions_r2652;
CREATE POLICY founder_all ON public.temperature_intervention_actions_r2652 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds (no apostrophes)
INSERT INTO public.customer_relationship_temperature_r2652 (quarter_label, temperature_kind, top_signals_md, action_required, action_owner_email, owner_email, status, notes) VALUES
  ('Q1-2026', 'burning', 'Two missed AMC renewals; CFO escalation; 3 open P1 tickets', true, 'founder@equipseva.in', 'cs@equipseva.in', 'intervening', 'Need founder call this week'),
  ('Q1-2026', 'cold', 'No usage logs for 45 days; last ticket 90 days ago', true, 'cs@equipseva.in', 'cs@equipseva.in', 'monitoring', 'Possible churn; try case study offer'),
  ('Q1-2026', 'warm', 'AMC renewed on time; 2 positive NPS responses', false, NULL, 'cs@equipseva.in', 'monitoring', 'Healthy; quarterly touchpoint only'),
  ('Q4-2025', 'hot', 'Referred new hospital; agreed to logo permission', false, NULL, 'founder@equipseva.in', 'recovered', 'Convert to case study'),
  ('Q4-2025', 'cool', 'Two complaints about engineer rotation', true, 'cs@equipseva.in', 'cs@equipseva.in', 'intervening', 'Stabilize assigned engineer');

INSERT INTO public.temperature_intervention_actions_r2652 (temp_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'founder_intro', 'positive', 'founder@equipseva.in', 'done', 'Founder call scheduled and completed'
FROM public.customer_relationship_temperature_r2652 WHERE temperature_kind = 'burning' LIMIT 1;

INSERT INTO public.temperature_intervention_actions_r2652 (temp_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'case_study_offer', 'pending', 'cs@equipseva.in', 'open', 'Offered free case study in exchange for renewal'
FROM public.customer_relationship_temperature_r2652 WHERE temperature_kind = 'cold' LIMIT 1;

INSERT INTO public.temperature_intervention_actions_r2652 (temp_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'visit', 'neutral', 'cs@equipseva.in', 'open', 'On-site visit planned for next sprint'
FROM public.customer_relationship_temperature_r2652 WHERE temperature_kind = 'cool' LIMIT 1;

-- ============================================================
-- RPC 1: list_temperature_r2652
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_temperature_r2652()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  temperature_kind text,
  top_signals_md text,
  action_required boolean,
  action_owner_email text,
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
  SELECT t.id, t.quarter_label, t.temperature_kind, t.top_signals_md,
         t.action_required, t.action_owner_email, t.owner_email, t.status, t.notes, t.created_at
  FROM public.customer_relationship_temperature_r2652 t
  ORDER BY t.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_temperature_r2652() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_temperature_r2652() TO authenticated;

-- ============================================================
-- RPC 2: list_intervention_actions_r2652
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_intervention_actions_r2652()
RETURNS TABLE (
  id uuid,
  temp_id uuid,
  quarter_label text,
  temperature_kind text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.temp_id, t.quarter_label, t.temperature_kind,
         a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
  FROM public.temperature_intervention_actions_r2652 a
  LEFT JOIN public.customer_relationship_temperature_r2652 t ON t.id = a.temp_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_intervention_actions_r2652() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_intervention_actions_r2652() TO authenticated;

-- ============================================================
-- RPC 3: top_cold_focus_r2652
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_cold_focus_r2652()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  temperature_kind text,
  top_signals_md text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.quarter_label, t.temperature_kind, t.top_signals_md, t.owner_email, t.status
  FROM public.customer_relationship_temperature_r2652 t
  WHERE t.temperature_kind IN ('cold','cool')
    AND t.status IN ('monitoring','intervening')
  ORDER BY
    CASE t.temperature_kind WHEN 'cold' THEN 0 ELSE 1 END,
    t.created_at DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_cold_focus_r2652() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_cold_focus_r2652() TO authenticated;

-- ============================================================
-- RPC 4: temperature_distribution_r2652
-- ============================================================
CREATE OR REPLACE FUNCTION public.temperature_distribution_r2652()
RETURNS TABLE (
  temperature_kind text,
  total bigint,
  action_required_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.temperature_kind,
         count(*)::bigint AS total,
         count(*) FILTER (WHERE t.action_required)::bigint AS action_required_count
  FROM public.customer_relationship_temperature_r2652 t
  GROUP BY t.temperature_kind
  ORDER BY t.temperature_kind;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.temperature_distribution_r2652() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.temperature_distribution_r2652() TO authenticated;

-- ============================================================
-- RPC 5: status_funnel_r2652
-- ============================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2652()
RETURNS TABLE (
  status text,
  total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.status, count(*)::bigint AS total
  FROM public.customer_relationship_temperature_r2652 t
  GROUP BY t.status
  ORDER BY t.status;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2652() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2652() TO authenticated;

-- ============================================================
-- RPC 6: quarterly_temperature_trend_r2652
-- ============================================================
CREATE OR REPLACE FUNCTION public.quarterly_temperature_trend_r2652()
RETURNS TABLE (
  quarter_label text,
  temperature_kind text,
  total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.quarter_label, t.temperature_kind, count(*)::bigint AS total
  FROM public.customer_relationship_temperature_r2652 t
  GROUP BY t.quarter_label, t.temperature_kind
  ORDER BY t.quarter_label DESC, t.temperature_kind;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_temperature_trend_r2652() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_temperature_trend_r2652() TO authenticated;

-- ============================================================
-- RPC 7: owner_load_r2652
-- ============================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2652()
RETURNS TABLE (
  owner_email text,
  total bigint,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(t.owner_email, 'unassigned') AS owner_email,
         count(*)::bigint AS total,
         count(*) FILTER (WHERE t.action_required AND t.status IN ('monitoring','intervening'))::bigint AS open_actions
  FROM public.customer_relationship_temperature_r2652 t
  GROUP BY coalesce(t.owner_email, 'unassigned')
  ORDER BY open_actions DESC, total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2652() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2652() TO authenticated;
