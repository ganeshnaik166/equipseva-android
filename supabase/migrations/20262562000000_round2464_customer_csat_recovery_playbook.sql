-- Round 2464: customer-csat-recovery-playbook
-- Customer CSAT drop detection + recovery action playbook (call/visit/refund/replace/training/discount)

CREATE TABLE IF NOT EXISTS public.customer_csat_drops_r2464 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  drop_detected_at timestamptz NOT NULL DEFAULT now(),
  prior_csat numeric NOT NULL CHECK (prior_csat >= 0 AND prior_csat <= 10),
  current_csat numeric NOT NULL CHECK (current_csat >= 0 AND current_csat <= 10),
  csat_delta numeric NOT NULL,
  drop_kind text NOT NULL CHECK (drop_kind IN ('workflow','equipment','billing','communication','engineer_change','unknown')),
  root_cause_md text,
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dropped')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.csat_recovery_actions_r2464 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drop_id uuid NOT NULL REFERENCES public.customer_csat_drops_r2464(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('call','visit','refund','equipment_replace','training','discount')),
  action_summary text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  nps_recovery_score numeric CHECK (nps_recovery_score IS NULL OR (nps_recovery_score >= -100 AND nps_recovery_score <= 100)),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_csat_drops_r2464 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.csat_recovery_actions_r2464 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_csat_drops_r2464;
CREATE POLICY founder_all ON public.customer_csat_drops_r2464
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.csat_recovery_actions_r2464;
CREATE POLICY founder_all ON public.csat_recovery_actions_r2464
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed CSAT drops
WITH seed_users AS (
  SELECT id FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 4
), inserted_drops AS (
  INSERT INTO public.customer_csat_drops_r2464
    (hospital_user_id, drop_detected_at, prior_csat, current_csat, csat_delta, drop_kind, root_cause_md, severity, status, owner_email, notes)
  SELECT
    su.id,
    now() - (idx || ' days')::interval,
    prior,
    cur,
    cur - prior,
    kind,
    root,
    sev,
    stat,
    email,
    note
  FROM seed_users su
  CROSS JOIN LATERAL (
    VALUES
      (1, 9.2::numeric, 6.1::numeric, 'equipment'::text, '# Root cause\n\nVentilator downtime exceeded 6h SLA twice in same week.', 'high'::text, 'in_progress'::text, 'founder@equipseva.in'::text, 'Escalated to manufacturer rep.'::text),
      (2, 8.8::numeric, 7.4::numeric, 'communication'::text, '# Root cause\n\nEngineer rotation not announced to hospital ops.', 'medium'::text, 'resolved'::text, 'ops@equipseva.in'::text, 'Comms playbook updated.'::text),
      (3, 9.5::numeric, 5.2::numeric, 'billing'::text, '# Root cause\n\nGST line items doubled on quarterly invoice.', 'critical'::text, 'open'::text, 'finance@equipseva.in'::text, 'Refund + credit note in flight.'::text),
      (4, 7.9::numeric, 6.8::numeric, 'engineer_change'::text, '# Root cause\n\nLead engineer transferred without warm handover.'::text, 'medium'::text, 'in_progress'::text, 'founder@equipseva.in'::text, 'Reassigned senior engineer.'::text),
      (5, 8.5::numeric, 4.9::numeric, 'workflow'::text, '# Root cause\n\nAMC tier downgrade triggered SLA confusion.'::text, 'high'::text, 'open'::text, 'founder@equipseva.in'::text, 'Tier guide being rewritten.'::text)
  ) AS v(idx, prior, cur, kind, root, sev, stat, email, note)
  WHERE su.id IS NOT NULL
  RETURNING id, drop_kind
)
INSERT INTO public.csat_recovery_actions_r2464
  (drop_id, action_at, action_kind, action_summary, outcome, follow_up_at, nps_recovery_score, owner_email, notes)
SELECT
  d.id,
  now() - '1 day'::interval,
  CASE d.drop_kind
    WHEN 'equipment' THEN 'equipment_replace'
    WHEN 'billing' THEN 'refund'
    WHEN 'communication' THEN 'call'
    WHEN 'engineer_change' THEN 'visit'
    WHEN 'workflow' THEN 'training'
    ELSE 'call'
  END,
  'Recovery action logged for drop kind ' || d.drop_kind,
  'pending',
  now() + '7 days'::interval,
  CASE d.drop_kind WHEN 'billing' THEN -20 WHEN 'equipment' THEN 10 ELSE 5 END,
  'founder@equipseva.in',
  'First-touch recovery attempt.'
FROM inserted_drops d;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_drops_r2464()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  drop_detected_at timestamptz,
  prior_csat numeric,
  current_csat numeric,
  csat_delta numeric,
  drop_kind text,
  severity text,
  status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.hospital_user_id, p.email, d.drop_detected_at,
         d.prior_csat, d.current_csat, d.csat_delta,
         d.drop_kind, d.severity, d.status, d.owner_email, d.notes
  FROM public.customer_csat_drops_r2464 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  ORDER BY d.drop_detected_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_drops_r2464() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_drops_r2464() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_recovery_actions_r2464()
RETURNS TABLE (
  id uuid,
  drop_id uuid,
  hospital_email text,
  action_at timestamptz,
  action_kind text,
  action_summary text,
  outcome text,
  follow_up_at timestamptz,
  nps_recovery_score numeric,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.drop_id, p.email, a.action_at,
         a.action_kind, a.action_summary, a.outcome,
         a.follow_up_at, a.nps_recovery_score, a.owner_email
  FROM public.csat_recovery_actions_r2464 a
  JOIN public.customer_csat_drops_r2464 d ON d.id = a.drop_id
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  ORDER BY a.action_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_actions_r2464() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_actions_r2464() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_drops_focus_r2464()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  csat_delta numeric,
  drop_kind text,
  severity text,
  status text,
  detected_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, p.email, d.csat_delta, d.drop_kind, d.severity, d.status, d.drop_detected_at
  FROM public.customer_csat_drops_r2464 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  WHERE d.status IN ('open','in_progress')
  ORDER BY
    CASE d.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    d.csat_delta ASC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_drops_focus_r2464() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_drops_focus_r2464() TO authenticated;

CREATE OR REPLACE FUNCTION public.action_kind_summary_r2464()
RETURNS TABLE (
  action_kind text,
  action_count bigint,
  positive_count bigint,
  negative_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'negative')::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'pending')::bigint
  FROM public.csat_recovery_actions_r2464 a
  GROUP BY a.action_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_summary_r2464() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_summary_r2464() TO authenticated;

CREATE OR REPLACE FUNCTION public.nps_recovery_summary_r2464()
RETURNS TABLE (
  avg_nps_recovery numeric,
  positive_actions bigint,
  neutral_actions bigint,
  negative_actions bigint,
  pending_actions bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ROUND(AVG(a.nps_recovery_score)::numeric, 2),
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'neutral')::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'negative')::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'pending')::bigint
  FROM public.csat_recovery_actions_r2464 a;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.nps_recovery_summary_r2464() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_recovery_summary_r2464() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_hospitals_in_recovery_r2464()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  drop_count bigint,
  avg_delta numeric,
  worst_severity text,
  open_drops bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.hospital_user_id,
         p.email,
         COUNT(*)::bigint,
         ROUND(AVG(d.csat_delta)::numeric, 2),
         (ARRAY_AGG(d.severity ORDER BY
            CASE d.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END))[1],
         COUNT(*) FILTER (WHERE d.status IN ('open','in_progress'))::bigint
  FROM public.customer_csat_drops_r2464 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  GROUP BY d.hospital_user_id, p.email
  ORDER BY COUNT(*) DESC, AVG(d.csat_delta) ASC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_in_recovery_r2464() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_in_recovery_r2464() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_drop_trend_r2464()
RETURNS TABLE (
  month_start timestamptz,
  drops_detected bigint,
  avg_delta numeric,
  critical_count bigint,
  resolved_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', d.drop_detected_at)::timestamptz,
         COUNT(*)::bigint,
         ROUND(AVG(d.csat_delta)::numeric, 2),
         COUNT(*) FILTER (WHERE d.severity = 'critical')::bigint,
         COUNT(*) FILTER (WHERE d.status = 'resolved')::bigint
  FROM public.customer_csat_drops_r2464 d
  GROUP BY date_trunc('month', d.drop_detected_at)
  ORDER BY date_trunc('month', d.drop_detected_at) DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_drop_trend_r2464() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_drop_trend_r2464() TO authenticated;
