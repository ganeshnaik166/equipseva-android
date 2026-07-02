-- Round 2491: Hospital chain finance team counterpart map
-- Tables: chain_finance_counterparts_r2491, finance_counterpart_touchpoints_r2491

CREATE TABLE IF NOT EXISTS public.chain_finance_counterparts_r2491 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  counterpart_role text NOT NULL CHECK (counterpart_role IN ('cfo','ar_head','ap_head','treasury','controller')),
  counterpart_name text NOT NULL,
  counterpart_email text NOT NULL,
  cycle_preference text NOT NULL CHECK (cycle_preference IN ('weekly','biweekly','monthly','quarterly')),
  dispute_resolution_speed_hours numeric NOT NULL DEFAULT 0,
  payment_terms_days int NOT NULL DEFAULT 30,
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('weak','developing','strong','champion')),
  last_touch_at timestamptz,
  notes text
);

CREATE TABLE IF NOT EXISTS public.finance_counterpart_touchpoints_r2491 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  counterpart_id uuid NOT NULL REFERENCES public.chain_finance_counterparts_r2491(id) ON DELETE CASCADE,
  touch_at timestamptz NOT NULL DEFAULT now(),
  touch_kind text NOT NULL CHECK (touch_kind IN ('call','email','meeting','event','dispute_resolve')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  owner_email text NOT NULL,
  notes text
);

ALTER TABLE public.chain_finance_counterparts_r2491 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_counterpart_touchpoints_r2491 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_finance_counterparts_r2491;
CREATE POLICY founder_all ON public.chain_finance_counterparts_r2491 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.finance_counterpart_touchpoints_r2491;
CREATE POLICY founder_all ON public.finance_counterpart_touchpoints_r2491 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed counterparts
INSERT INTO public.chain_finance_counterparts_r2491 (chain_name, counterpart_role, counterpart_name, counterpart_email, cycle_preference, dispute_resolution_speed_hours, payment_terms_days, relationship_strength, last_touch_at, notes) VALUES
  ('Apollo Hospitals', 'cfo', 'Krishnan Akileswaran', 'cfo@apollo.example.com', 'monthly', 18.5, 45, 'champion', now() - interval '2 days', 'Quarterly board reviews, very responsive'),
  ('Fortis Healthcare', 'ar_head', 'Priya Subramanian', 'ar.head@fortis.example.com', 'biweekly', 36.0, 60, 'strong', now() - interval '5 days', 'AR cycle locked, escalates fast'),
  ('Manipal Hospitals', 'ap_head', 'Rajesh Iyer', 'ap@manipal.example.com', 'monthly', 72.0, 75, 'developing', now() - interval '14 days', 'Slow on dispute resolution, growing trust'),
  ('Max Healthcare', 'treasury', 'Anita Verma', 'treasury@max.example.com', 'weekly', 12.0, 30, 'champion', now() - interval '1 day', 'Treasury auto-debits weekly, gold standard'),
  ('Narayana Health', 'controller', 'Sunil Reddy', 'controller@narayana.example.com', 'quarterly', 96.0, 90, 'weak', now() - interval '45 days', 'No response in 6 weeks, escalate to CEO');

-- Seed touchpoints (one INSERT per row)
DO $seed$
DECLARE
  v_apollo uuid;
  v_fortis uuid;
  v_manipal uuid;
  v_max uuid;
  v_narayana uuid;
BEGIN
  SELECT id INTO v_apollo FROM public.chain_finance_counterparts_r2491 WHERE chain_name='Apollo Hospitals' LIMIT 1;
  SELECT id INTO v_fortis FROM public.chain_finance_counterparts_r2491 WHERE chain_name='Fortis Healthcare' LIMIT 1;
  SELECT id INTO v_manipal FROM public.chain_finance_counterparts_r2491 WHERE chain_name='Manipal Hospitals' LIMIT 1;
  SELECT id INTO v_max FROM public.chain_finance_counterparts_r2491 WHERE chain_name='Max Healthcare' LIMIT 1;
  SELECT id INTO v_narayana FROM public.chain_finance_counterparts_r2491 WHERE chain_name='Narayana Health' LIMIT 1;

  INSERT INTO public.finance_counterpart_touchpoints_r2491 (counterpart_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, notes)
    VALUES (v_apollo, now() - interval '2 days', 'meeting', 'positive', now() + interval '14 days', 'founder@equipseva.com', 'Q4 contract renewal verbal commit');
  INSERT INTO public.finance_counterpart_touchpoints_r2491 (counterpart_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, notes)
    VALUES (v_fortis, now() - interval '5 days', 'call', 'neutral', now() + interval '7 days', 'founder@equipseva.com', 'AR cycle question, expecting written response');
  INSERT INTO public.finance_counterpart_touchpoints_r2491 (counterpart_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, notes)
    VALUES (v_manipal, now() - interval '14 days', 'dispute_resolve', 'positive', NULL, 'ops@equipseva.com', 'Resolved invoice mismatch in 72h');
  INSERT INTO public.finance_counterpart_touchpoints_r2491 (counterpart_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, notes)
    VALUES (v_max, now() - interval '1 day', 'email', 'positive', now() + interval '3 days', 'founder@equipseva.com', 'Weekly autodebit confirmation');
  INSERT INTO public.finance_counterpart_touchpoints_r2491 (counterpart_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, notes)
    VALUES (v_narayana, now() - interval '45 days', 'email', 'negative', now() + interval '2 days', 'founder@equipseva.com', 'No reply on 3 nudges, escalating');
  INSERT INTO public.finance_counterpart_touchpoints_r2491 (counterpart_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, notes)
    VALUES (v_apollo, now() - interval '20 days', 'event', 'positive', NULL, 'founder@equipseva.com', 'CFO conference, deepened relationship');
  INSERT INTO public.finance_counterpart_touchpoints_r2491 (counterpart_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, notes)
    VALUES (v_fortis, now() - interval '30 days', 'dispute_resolve', 'positive', NULL, 'ops@equipseva.com', 'Resolved 3-invoice dispute in 36h');
END
$seed$;

-- RPC 1: list_counterparts_r2491
CREATE OR REPLACE FUNCTION public.list_counterparts_r2491()
RETURNS TABLE (
  id uuid,
  chain_name text,
  counterpart_role text,
  counterpart_name text,
  counterpart_email text,
  cycle_preference text,
  dispute_resolution_speed_hours numeric,
  payment_terms_days int,
  relationship_strength text,
  last_touch_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.counterpart_role, c.counterpart_name, c.counterpart_email,
         c.cycle_preference, c.dispute_resolution_speed_hours, c.payment_terms_days,
         c.relationship_strength, c.last_touch_at, c.notes, c.created_at
  FROM public.chain_finance_counterparts_r2491 c
  ORDER BY c.chain_name ASC, c.counterpart_role ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_counterparts_r2491() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_counterparts_r2491() TO authenticated;

-- RPC 2: list_touchpoints_r2491
CREATE OR REPLACE FUNCTION public.list_touchpoints_r2491()
RETURNS TABLE (
  id uuid,
  counterpart_id uuid,
  chain_name text,
  counterpart_name text,
  touch_at timestamptz,
  touch_kind text,
  outcome text,
  follow_up_at timestamptz,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.counterpart_id, c.chain_name, c.counterpart_name,
         t.touch_at, t.touch_kind, t.outcome, t.follow_up_at, t.owner_email, t.notes
  FROM public.finance_counterpart_touchpoints_r2491 t
  JOIN public.chain_finance_counterparts_r2491 c ON c.id = t.counterpart_id
  ORDER BY t.touch_at DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_touchpoints_r2491() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_touchpoints_r2491() TO authenticated;

-- RPC 3: weak_relationship_focus_r2491
CREATE OR REPLACE FUNCTION public.weak_relationship_focus_r2491()
RETURNS TABLE (
  chain_name text,
  counterpart_role text,
  counterpart_name text,
  relationship_strength text,
  days_since_last_touch numeric,
  payment_terms_days int,
  recommended_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, c.counterpart_role, c.counterpart_name, c.relationship_strength,
         ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(c.last_touch_at, c.created_at))) / 86400.0, 1) AS days_since_last_touch,
         c.payment_terms_days,
         CASE
           WHEN c.relationship_strength = 'weak' THEN 'Escalate to CEO/CXO call this week'
           WHEN c.relationship_strength = 'developing' THEN 'Schedule a coffee + dispute review'
           ELSE 'Maintain cadence'
         END AS recommended_action
  FROM public.chain_finance_counterparts_r2491 c
  WHERE c.relationship_strength IN ('weak','developing')
  ORDER BY
    CASE c.relationship_strength WHEN 'weak' THEN 0 WHEN 'developing' THEN 1 ELSE 2 END,
    c.last_touch_at ASC NULLS FIRST;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.weak_relationship_focus_r2491() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weak_relationship_focus_r2491() TO authenticated;

-- RPC 4: top_resolution_speed_r2491
CREATE OR REPLACE FUNCTION public.top_resolution_speed_r2491()
RETURNS TABLE (
  chain_name text,
  counterpart_role text,
  counterpart_name text,
  dispute_resolution_speed_hours numeric,
  relationship_strength text,
  rank_position bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, c.counterpart_role, c.counterpart_name,
         c.dispute_resolution_speed_hours, c.relationship_strength,
         ROW_NUMBER() OVER (ORDER BY c.dispute_resolution_speed_hours ASC) AS rank_position
  FROM public.chain_finance_counterparts_r2491 c
  ORDER BY c.dispute_resolution_speed_hours ASC
  LIMIT 10;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.top_resolution_speed_r2491() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_resolution_speed_r2491() TO authenticated;

-- RPC 5: role_breakdown_r2491
CREATE OR REPLACE FUNCTION public.role_breakdown_r2491()
RETURNS TABLE (
  counterpart_role text,
  counterpart_count bigint,
  avg_resolution_hours numeric,
  avg_payment_terms_days numeric,
  champion_count bigint,
  weak_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.counterpart_role,
         COUNT(*)::bigint AS counterpart_count,
         ROUND(AVG(c.dispute_resolution_speed_hours)::numeric, 1) AS avg_resolution_hours,
         ROUND(AVG(c.payment_terms_days)::numeric, 1) AS avg_payment_terms_days,
         COUNT(*) FILTER (WHERE c.relationship_strength = 'champion')::bigint AS champion_count,
         COUNT(*) FILTER (WHERE c.relationship_strength = 'weak')::bigint AS weak_count
  FROM public.chain_finance_counterparts_r2491 c
  GROUP BY c.counterpart_role
  ORDER BY c.counterpart_role ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.role_breakdown_r2491() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_breakdown_r2491() TO authenticated;

-- RPC 6: cycle_preference_summary_r2491
CREATE OR REPLACE FUNCTION public.cycle_preference_summary_r2491()
RETURNS TABLE (
  cycle_preference text,
  counterpart_count bigint,
  avg_payment_terms_days numeric,
  avg_resolution_hours numeric,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.chain_finance_counterparts_r2491;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT c.cycle_preference,
         COUNT(*)::bigint AS counterpart_count,
         ROUND(AVG(c.payment_terms_days)::numeric, 1) AS avg_payment_terms_days,
         ROUND(AVG(c.dispute_resolution_speed_hours)::numeric, 1) AS avg_resolution_hours,
         ROUND((COUNT(*)::numeric * 100.0) / v_total::numeric, 1) AS share_pct
  FROM public.chain_finance_counterparts_r2491 c
  GROUP BY c.cycle_preference
  ORDER BY counterpart_count DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.cycle_preference_summary_r2491() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cycle_preference_summary_r2491() TO authenticated;

-- RPC 7: recent_touchpoint_calendar_r2491
CREATE OR REPLACE FUNCTION public.recent_touchpoint_calendar_r2491()
RETURNS TABLE (
  touch_day date,
  touch_count bigint,
  positive_count bigint,
  negative_count bigint,
  dispute_resolve_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (t.touch_at AT TIME ZONE 'UTC')::date AS touch_day,
         COUNT(*)::bigint AS touch_count,
         COUNT(*) FILTER (WHERE t.outcome = 'positive')::bigint AS positive_count,
         COUNT(*) FILTER (WHERE t.outcome = 'negative')::bigint AS negative_count,
         COUNT(*) FILTER (WHERE t.touch_kind = 'dispute_resolve')::bigint AS dispute_resolve_count
  FROM public.finance_counterpart_touchpoints_r2491 t
  WHERE t.touch_at >= now() - interval '60 days'
  GROUP BY touch_day
  ORDER BY touch_day DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.recent_touchpoint_calendar_r2491() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_touchpoint_calendar_r2491() TO authenticated;
