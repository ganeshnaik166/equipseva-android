-- Round 2463: Hospital chain recurring issue tracker
-- Chains x recurring issues x hit count x root cause x kill actions x ARR risk

CREATE TABLE IF NOT EXISTS public.chain_recurring_issues_r2463 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  issue_signature text NOT NULL,
  issue_kind text NOT NULL CHECK (issue_kind IN ('uptime','billing','communication','sla_breach','training_gap','parts')),
  hit_count int NOT NULL DEFAULT 1 CHECK (hit_count >= 0),
  last_hit_at timestamptz,
  root_cause_kind text CHECK (root_cause_kind IN ('process','people','product','policy','external')),
  root_cause_md text,
  arr_risk_rupees bigint NOT NULL DEFAULT 0 CHECK (arr_risk_rupees >= 0),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dropped')),
  notes text
);

ALTER TABLE public.chain_recurring_issues_r2463 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_recurring_issues_r2463;
CREATE POLICY founder_all ON public.chain_recurring_issues_r2463
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.recurring_issue_kill_actions_r2463 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  issue_id uuid NOT NULL REFERENCES public.chain_recurring_issues_r2463(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('process_change','training','escalation','refund','policy_change')),
  action_summary text NOT NULL,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.recurring_issue_kill_actions_r2463 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.recurring_issue_kill_actions_r2463;
CREATE POLICY founder_all ON public.recurring_issue_kill_actions_r2463
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data (5 issues + 5 kill actions)
DO $seed$
DECLARE
  v_issue1 uuid;
  v_issue2 uuid;
  v_issue3 uuid;
  v_issue4 uuid;
  v_issue5 uuid;
BEGIN
  INSERT INTO public.chain_recurring_issues_r2463
    (chain_name, issue_signature, issue_kind, hit_count, last_hit_at, root_cause_kind, root_cause_md, arr_risk_rupees, owner_email, status, notes)
  VALUES
    ('Apollo Hospitals', 'ventilator-uptime-drop-after-monsoon', 'uptime', 7, now() - interval '2 days',
     'product', 'humidity ingress into PCB on ICU vents', 4800000, 'ops@equipseva.in', 'in_progress',
     'replicates across 3 Apollo units in Hyderabad')
  RETURNING id INTO v_issue1;

  INSERT INTO public.chain_recurring_issues_r2463
    (chain_name, issue_signature, issue_kind, hit_count, last_hit_at, root_cause_kind, root_cause_md, arr_risk_rupees, owner_email, status, notes)
  VALUES
    ('Yashoda Group', 'gst-invoice-mismatch-recurring', 'billing', 5, now() - interval '5 days',
     'process', 'wrong recipient GSTIN auto-pulled from stale CRM record', 1200000, 'finance@equipseva.in', 'open',
     'finance team flagged 3rd time this quarter')
  RETURNING id INTO v_issue2;

  INSERT INTO public.chain_recurring_issues_r2463
    (chain_name, issue_signature, issue_kind, hit_count, last_hit_at, root_cause_kind, root_cause_md, arr_risk_rupees, owner_email, status, notes)
  VALUES
    ('KIMS', 'engineer-eta-no-update-after-90min', 'communication', 9, now() - interval '1 day',
     'people', 'field engineers skip SLA acknowledge step', 2200000, 'cx@equipseva.in', 'in_progress',
     'KIMS escalation manager threatened churn')
  RETURNING id INTO v_issue3;

  INSERT INTO public.chain_recurring_issues_r2463
    (chain_name, issue_signature, issue_kind, hit_count, last_hit_at, root_cause_kind, root_cause_md, arr_risk_rupees, owner_email, status, notes)
  VALUES
    ('Care Hospitals', 'sla-breach-4hr-cardiac-cath', 'sla_breach', 4, now() - interval '8 days',
     'policy', 'no priority lane for cardiac cath lab in current AMC tier', 3500000, 'ops@equipseva.in', 'open',
     'needs P3 tier carveout in AMC contract')
  RETURNING id INTO v_issue4;

  INSERT INTO public.chain_recurring_issues_r2463
    (chain_name, issue_signature, issue_kind, hit_count, last_hit_at, root_cause_kind, root_cause_md, arr_risk_rupees, owner_email, status, notes)
  VALUES
    ('Continental Hospitals', 'wrong-spare-part-shipped', 'parts', 3, now() - interval '11 days',
     'process', 'supplier picks part by description not SKU', 900000, 'parts@equipseva.in', 'resolved',
     'fixed by mandatory SKU scan at supplier dock')
  RETURNING id INTO v_issue5;

  INSERT INTO public.recurring_issue_kill_actions_r2463
    (issue_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_issue1, now() - interval '1 day', 'process_change',
     'added humidity gasket replacement to monsoon prep checklist', 'positive',
     now() + interval '14 days', 'ops@equipseva.in', 'done',
     'rolling out to all coastal units');

  INSERT INTO public.recurring_issue_kill_actions_r2463
    (issue_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_issue2, now() - interval '3 days', 'policy_change',
     'forced GSTIN re-verification on every invoice over 5L', 'pending',
     now() + interval '7 days', 'finance@equipseva.in', 'open',
     'engineering ticket EQS-4412');

  INSERT INTO public.recurring_issue_kill_actions_r2463
    (issue_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_issue3, now() - interval '2 days', 'training',
     'mandatory SLA-ack training for all engineers tier-3 and above', 'neutral',
     now() + interval '21 days', 'cx@equipseva.in', 'open',
     'awaiting compliance audit pass');

  INSERT INTO public.recurring_issue_kill_actions_r2463
    (issue_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_issue4, now() - interval '4 days', 'escalation',
     'escalated to founder; proposing dedicated cardiac SLA tier', 'pending',
     now() + interval '5 days', 'ops@equipseva.in', 'open',
     'Care CMO meeting Friday');

  INSERT INTO public.recurring_issue_kill_actions_r2463
    (issue_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_issue5, now() - interval '10 days', 'process_change',
     'SKU barcode scan mandatory at supplier dock + receiving dock', 'positive',
     now() + interval '30 days', 'parts@equipseva.in', 'done',
     '0 mis-ships since rollout');
END
$seed$;

-- RPC 1: list_issues_r2463
CREATE OR REPLACE FUNCTION public.list_issues_r2463()
RETURNS TABLE (
  id uuid,
  chain_name text,
  issue_signature text,
  issue_kind text,
  hit_count int,
  last_hit_at timestamptz,
  root_cause_kind text,
  arr_risk_rupees bigint,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.chain_name, i.issue_signature, i.issue_kind, i.hit_count,
           i.last_hit_at, i.root_cause_kind, i.arr_risk_rupees, i.owner_email, i.status
    FROM public.chain_recurring_issues_r2463 i
    ORDER BY i.hit_count DESC, i.last_hit_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_issues_r2463() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_issues_r2463() TO authenticated;

-- RPC 2: list_kill_actions_r2463
CREATE OR REPLACE FUNCTION public.list_kill_actions_r2463()
RETURNS TABLE (
  id uuid,
  issue_id uuid,
  chain_name text,
  action_at timestamptz,
  action_kind text,
  action_summary text,
  outcome text,
  follow_up_at timestamptz,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.issue_id, i.chain_name, a.action_at, a.action_kind, a.action_summary,
           a.outcome, a.follow_up_at, a.owner_email, a.status
    FROM public.recurring_issue_kill_actions_r2463 a
    JOIN public.chain_recurring_issues_r2463 i ON i.id = a.issue_id
    ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_kill_actions_r2463() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_kill_actions_r2463() TO authenticated;

-- RPC 3: top_recurring_by_chain_r2463
CREATE OR REPLACE FUNCTION public.top_recurring_by_chain_r2463()
RETURNS TABLE (
  chain_name text,
  open_issues bigint,
  total_hits bigint,
  total_arr_risk_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.chain_name,
           count(*) FILTER (WHERE i.status IN ('open','in_progress'))::bigint AS open_issues,
           sum(i.hit_count)::bigint AS total_hits,
           sum(i.arr_risk_rupees)::bigint AS total_arr_risk_rupees
    FROM public.chain_recurring_issues_r2463 i
    GROUP BY i.chain_name
    ORDER BY total_arr_risk_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_recurring_by_chain_r2463() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_recurring_by_chain_r2463() TO authenticated;

-- RPC 4: root_cause_breakdown_r2463
CREATE OR REPLACE FUNCTION public.root_cause_breakdown_r2463()
RETURNS TABLE (
  root_cause_kind text,
  issue_count bigint,
  total_hits bigint,
  arr_risk_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT coalesce(i.root_cause_kind, 'unknown') AS root_cause_kind,
           count(*)::bigint AS issue_count,
           sum(i.hit_count)::bigint AS total_hits,
           sum(i.arr_risk_rupees)::bigint AS arr_risk_rupees
    FROM public.chain_recurring_issues_r2463 i
    GROUP BY coalesce(i.root_cause_kind, 'unknown')
    ORDER BY arr_risk_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.root_cause_breakdown_r2463() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_cause_breakdown_r2463() TO authenticated;

-- RPC 5: top_arr_at_risk_r2463
CREATE OR REPLACE FUNCTION public.top_arr_at_risk_r2463()
RETURNS TABLE (
  id uuid,
  chain_name text,
  issue_signature text,
  hit_count int,
  arr_risk_rupees bigint,
  status text,
  last_hit_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.chain_name, i.issue_signature, i.hit_count,
           i.arr_risk_rupees, i.status, i.last_hit_at
    FROM public.chain_recurring_issues_r2463 i
    WHERE i.status IN ('open','in_progress')
    ORDER BY i.arr_risk_rupees DESC NULLS LAST
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_arr_at_risk_r2463() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_at_risk_r2463() TO authenticated;

-- RPC 6: monthly_hit_trend_r2463
CREATE OR REPLACE FUNCTION public.monthly_hit_trend_r2463()
RETURNS TABLE (
  month_start timestamptz,
  issues_opened bigint,
  total_hits bigint,
  arr_risk_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', i.created_at)::timestamptz AS month_start,
           count(*)::bigint AS issues_opened,
           sum(i.hit_count)::bigint AS total_hits,
           sum(i.arr_risk_rupees)::bigint AS arr_risk_rupees
    FROM public.chain_recurring_issues_r2463 i
    WHERE i.created_at >= now() - interval '12 months'
    GROUP BY date_trunc('month', i.created_at)
    ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_hit_trend_r2463() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_hit_trend_r2463() TO authenticated;

-- RPC 7: this_week_action_calendar_r2463
CREATE OR REPLACE FUNCTION public.this_week_action_calendar_r2463()
RETURNS TABLE (
  id uuid,
  chain_name text,
  action_kind text,
  action_summary text,
  follow_up_at timestamptz,
  owner_email text,
  status text,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, i.chain_name, a.action_kind, a.action_summary,
           a.follow_up_at, a.owner_email, a.status, a.outcome
    FROM public.recurring_issue_kill_actions_r2463 a
    JOIN public.chain_recurring_issues_r2463 i ON i.id = a.issue_id
    WHERE a.follow_up_at IS NOT NULL
      AND a.follow_up_at >= date_trunc('week', now())
      AND a.follow_up_at < date_trunc('week', now()) + interval '7 days'
      AND a.status = 'open'
    ORDER BY a.follow_up_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.this_week_action_calendar_r2463() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.this_week_action_calendar_r2463() TO authenticated;
