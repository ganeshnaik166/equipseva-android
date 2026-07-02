-- Round 2539: hospital-chain-procurement-policy-evolution
-- Tables: chain_procurement_policy_versions_r2539, policy_evolution_events_r2539
-- RPCs: list_policy_versions_r2539, list_evolution_events_r2539, critical_threat_focus_r2539,
--       adoption_status_summary_r2539, our_impact_distribution_r2539, monthly_event_trend_r2539,
--       owner_load_r2539

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_procurement_policy_versions_r2539 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  version_label text NOT NULL,
  effective_at timestamptz NOT NULL DEFAULT now(),
  prior_version_label text,
  key_changes_md text,
  our_impact_kind text NOT NULL DEFAULT 'neutral' CHECK (our_impact_kind IN ('positive','neutral','negative','critical_threat')),
  adoption_status text NOT NULL DEFAULT 'considering' CHECK (adoption_status IN ('adopted','considering','blocked','abandoned')),
  our_counter_strategy_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.policy_evolution_events_r2539 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id uuid NOT NULL REFERENCES public.chain_procurement_policy_versions_r2539(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_kind text NOT NULL CHECK (event_kind IN ('rfi_added','clause_change','vendor_audit','payment_cycle','exception_granted')),
  summary text,
  action_taken_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_procurement_policy_versions_r2539 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_evolution_events_r2539 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_procurement_policy_versions_r2539;
CREATE POLICY founder_all ON public.chain_procurement_policy_versions_r2539
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.policy_evolution_events_r2539;
CREATE POLICY founder_all ON public.policy_evolution_events_r2539
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed policy versions
INSERT INTO public.chain_procurement_policy_versions_r2539
  (chain_name, version_label, effective_at, prior_version_label, key_changes_md, our_impact_kind,
   adoption_status, our_counter_strategy_md, owner_email, notes)
VALUES
  ('Apollo Hospitals', 'v2026.Q2', '2026-04-01'::timestamptz, 'v2026.Q1',
   '## Key Changes\n- AMC partner must have 50+ engineers\n- 90-day payment cycle becomes 120-day\n- ISO 13485 mandatory',
   'critical_threat', 'considering',
   '## Counter\n- Apply for ISO 13485 within 6 months\n- Push back on 120-day via QBR\n- Showcase 35 engineers + Q3 hiring plan',
   'founder@equipseva.in', 'biggest revenue chain'),
  ('Manipal Hospitals', 'v2026.06', '2026-06-10'::timestamptz, 'v2026.03',
   '## Key Changes\n- Single vendor for >100 units\n- Exception process for niche equipment\n- Quarterly vendor scorecard',
   'negative', 'adopted',
   '## Counter\n- Position as niche-equipment exception vendor\n- Build vendor scorecard dashboard for them',
   'founder@equipseva.in', 'mid-priority chain'),
  ('Fortis Healthcare', 'v2026.Q1', '2026-01-15'::timestamptz, 'v2025.Q4',
   '## Key Changes\n- Local supplier preference (within 50km)\n- Annual rate contract for AMC\n- E-invoice mandatory',
   'positive', 'adopted',
   '## Counter\n- Highlight our Hyderabad presence\n- E-invoice ready since v0.3',
   'founder@equipseva.in', 'we benefit from local preference'),
  ('Max Healthcare', 'v2026.Q2', '2026-05-01'::timestamptz, 'v2026.Q1',
   '## Key Changes\n- Centralized procurement (was per-hospital)\n- Pan-India rate negotiation\n- 6-month performance review',
   'negative', 'blocked',
   '## Counter\n- Build pan-India offer\n- Currently Hyderabad-only',
   'founder@equipseva.in', 'pan-India gap is blocker'),
  ('Care Hospitals', 'v2026.04', '2026-04-15'::timestamptz, NULL,
   '## Key Changes\n- First formal AMC policy\n- Open RFI process\n- Founder-friendly',
   'positive', 'adopted',
   '## Counter\n- Aggressive pricing for first contract\n- Use as case study',
   'founder@equipseva.in', 'green-field opportunity');

-- Seed evolution events tied to versions
INSERT INTO public.policy_evolution_events_r2539
  (version_id, event_at, event_kind, summary, action_taken_md, owner_email, status, notes)
SELECT v.id, '2026-04-05'::timestamptz, 'rfi_added',
       'Apollo added RFI for ISO 13485 cert',
       '## Action\n- Filed RFI response\n- Attached ISO roadmap',
       'founder@equipseva.in', 'done', 'turnaround in 48 hours'
FROM public.chain_procurement_policy_versions_r2539 v
WHERE v.chain_name = 'Apollo Hospitals' AND v.version_label = 'v2026.Q2'
LIMIT 1;

INSERT INTO public.policy_evolution_events_r2539
  (version_id, event_at, event_kind, summary, action_taken_md, owner_email, status, notes)
SELECT v.id, '2026-05-20'::timestamptz, 'payment_cycle',
       'Apollo moved 90d to 120d',
       '## Action\n- Escalated to CFO meeting\n- Asked for 100d compromise',
       'founder@equipseva.in', 'in_progress', 'cash flow hit'
FROM public.chain_procurement_policy_versions_r2539 v
WHERE v.chain_name = 'Apollo Hospitals' AND v.version_label = 'v2026.Q2'
LIMIT 1;

INSERT INTO public.policy_evolution_events_r2539
  (version_id, event_at, event_kind, summary, action_taken_md, owner_email, status, notes)
SELECT v.id, '2026-06-12'::timestamptz, 'vendor_audit',
       'Manipal vendor scorecard Q2',
       '## Action\n- Scored 87/100\n- Top quartile',
       'founder@equipseva.in', 'done', 'good positioning'
FROM public.chain_procurement_policy_versions_r2539 v
WHERE v.chain_name = 'Manipal Hospitals'
LIMIT 1;

INSERT INTO public.policy_evolution_events_r2539
  (version_id, event_at, event_kind, summary, action_taken_md, owner_email, status, notes)
SELECT v.id, '2026-05-10'::timestamptz, 'exception_granted',
       'Manipal granted niche equipment exception',
       '## Action\n- Won 12-unit niche contract',
       'founder@equipseva.in', 'done', 'first exception of year'
FROM public.chain_procurement_policy_versions_r2539 v
WHERE v.chain_name = 'Manipal Hospitals'
LIMIT 1;

INSERT INTO public.policy_evolution_events_r2539
  (version_id, event_at, event_kind, summary, action_taken_md, owner_email, status, notes)
SELECT v.id, '2026-06-18'::timestamptz, 'clause_change',
       'Max Healthcare draft amendment for pan-India clause',
       '## Action\n- Joined feedback call\n- Lobbied for state-level pilots',
       'founder@equipseva.in', 'open', 'tracking weekly'
FROM public.chain_procurement_policy_versions_r2539 v
WHERE v.chain_name = 'Max Healthcare'
LIMIT 1;

CREATE OR REPLACE FUNCTION public.list_policy_versions_r2539()
RETURNS TABLE (id uuid, chain_name text, version_label text, effective_at timestamptz,
               prior_version_label text, our_impact_kind text, adoption_status text,
               owner_email text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.chain_name, v.version_label, v.effective_at,
           v.prior_version_label, v.our_impact_kind, v.adoption_status,
           v.owner_email, v.notes
    FROM public.chain_procurement_policy_versions_r2539 v
    ORDER BY v.effective_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_policy_versions_r2539() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_policy_versions_r2539() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_evolution_events_r2539()
RETURNS TABLE (id uuid, chain_name text, version_label text, event_at timestamptz,
               event_kind text, summary text, status text, owner_email text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, v.chain_name, v.version_label, e.event_at,
           e.event_kind, e.summary, e.status, e.owner_email, e.notes
    FROM public.policy_evolution_events_r2539 e
    JOIN public.chain_procurement_policy_versions_r2539 v ON v.id = e.version_id
    ORDER BY e.event_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_evolution_events_r2539() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_evolution_events_r2539() TO authenticated;

CREATE OR REPLACE FUNCTION public.critical_threat_focus_r2539()
RETURNS TABLE (id uuid, chain_name text, version_label text, effective_at timestamptz,
               adoption_status text, owner_email text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.chain_name, v.version_label, v.effective_at,
           v.adoption_status, v.owner_email, v.notes
    FROM public.chain_procurement_policy_versions_r2539 v
    WHERE v.our_impact_kind = 'critical_threat'
    ORDER BY v.effective_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.critical_threat_focus_r2539() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.critical_threat_focus_r2539() TO authenticated;

CREATE OR REPLACE FUNCTION public.adoption_status_summary_r2539()
RETURNS TABLE (adoption_status text, versions_count bigint, critical_threat_count bigint,
               negative_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.adoption_status,
           count(*)::bigint,
           count(*) FILTER (WHERE v.our_impact_kind = 'critical_threat')::bigint,
           count(*) FILTER (WHERE v.our_impact_kind = 'negative')::bigint
    FROM public.chain_procurement_policy_versions_r2539 v
    GROUP BY v.adoption_status
    ORDER BY count(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.adoption_status_summary_r2539() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.adoption_status_summary_r2539() TO authenticated;

CREATE OR REPLACE FUNCTION public.our_impact_distribution_r2539()
RETURNS TABLE (our_impact_kind text, versions_count bigint, adopted_count bigint,
               blocked_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.our_impact_kind,
           count(*)::bigint,
           count(*) FILTER (WHERE v.adoption_status = 'adopted')::bigint,
           count(*) FILTER (WHERE v.adoption_status = 'blocked')::bigint
    FROM public.chain_procurement_policy_versions_r2539 v
    GROUP BY v.our_impact_kind
    ORDER BY count(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.our_impact_distribution_r2539() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.our_impact_distribution_r2539() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_event_trend_r2539()
RETURNS TABLE (month_start date, events_count bigint, open_count bigint,
               done_count bigint, distinct_chains bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT (date_trunc('month', e.event_at)::date) AS month_start,
           count(*)::bigint,
           count(*) FILTER (WHERE e.status = 'open')::bigint,
           count(*) FILTER (WHERE e.status = 'done')::bigint,
           count(DISTINCT v.chain_name)::bigint
    FROM public.policy_evolution_events_r2539 e
    JOIN public.chain_procurement_policy_versions_r2539 v ON v.id = e.version_id
    GROUP BY date_trunc('month', e.event_at)
    ORDER BY month_start DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_event_trend_r2539() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_event_trend_r2539() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2539()
RETURNS TABLE (owner_email text, versions_count bigint, events_count bigint,
               open_events bigint, critical_threats bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(v.owner_email, 'unassigned') AS owner_email,
           count(DISTINCT v.id)::bigint,
           count(e.id)::bigint,
           count(e.id) FILTER (WHERE e.status = 'open')::bigint,
           count(DISTINCT v.id) FILTER (WHERE v.our_impact_kind = 'critical_threat')::bigint
    FROM public.chain_procurement_policy_versions_r2539 v
    LEFT JOIN public.policy_evolution_events_r2539 e ON e.version_id = v.id
    GROUP BY COALESCE(v.owner_email, 'unassigned')
    ORDER BY count(DISTINCT v.id) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2539() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2539() TO authenticated;

