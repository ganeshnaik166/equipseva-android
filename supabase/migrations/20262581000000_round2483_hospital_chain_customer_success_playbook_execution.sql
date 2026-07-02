-- Round 2483: hospital-chain-customer-success-playbook-execution
-- Tables: chain_cs_playbook_runs_r2483, playbook_deviations_r2483

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_cs_playbook_runs_r2483 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  playbook_kind text NOT NULL CHECK (playbook_kind IN ('onboarding','expansion','retention','recovery','qbr','escalation')),
  execution_stage text NOT NULL DEFAULT 'planning' CHECK (execution_stage IN ('planning','in_progress','in_review','completed','dropped')),
  adherence_pct int NOT NULL DEFAULT 0 CHECK (adherence_pct BETWEEN 0 AND 100),
  outcome_kind text NOT NULL DEFAULT 'partial' CHECK (outcome_kind IN ('success','partial','missed','dropped')),
  owner_email text,
  started_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.playbook_deviations_r2483 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL REFERENCES public.chain_cs_playbook_runs_r2483(id) ON DELETE CASCADE,
  deviation_at timestamptz NOT NULL DEFAULT now(),
  step_skipped text NOT NULL,
  deviation_reason text,
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  kill_action_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_cs_playbook_runs_r2483 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playbook_deviations_r2483 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_cs_playbook_runs_r2483;
CREATE POLICY founder_all ON public.chain_cs_playbook_runs_r2483
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.playbook_deviations_r2483;
CREATE POLICY founder_all ON public.playbook_deviations_r2483
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed runs
INSERT INTO public.chain_cs_playbook_runs_r2483 (chain_name, playbook_kind, execution_stage, adherence_pct, outcome_kind, owner_email, started_at, completed_at, notes)
VALUES
  ('Apollo Hospitals', 'onboarding', 'completed', 92, 'success', 'cs1@equipseva.com', '2026-05-01'::timestamptz, '2026-05-20'::timestamptz, '5 sites onboarded clean'),
  ('Fortis Healthcare', 'expansion', 'in_progress', 68, 'partial', 'cs2@equipseva.com', '2026-05-15'::timestamptz, NULL, 'Stuck at procurement signoff'),
  ('Manipal Hospitals', 'retention', 'in_review', 78, 'partial', 'cs1@equipseva.com', '2026-04-10'::timestamptz, NULL, 'QBR slipped 2 weeks'),
  ('Max Healthcare', 'recovery', 'in_progress', 45, 'missed', 'cs3@equipseva.com', '2026-05-25'::timestamptz, NULL, 'P0 outage recovery underway'),
  ('Narayana Health', 'qbr', 'completed', 88, 'success', 'cs2@equipseva.com', '2026-04-01'::timestamptz, '2026-04-15'::timestamptz, 'Clean QBR + expansion commit');

-- Seed deviations
DO $$
DECLARE
  v_run_fortis uuid;
  v_run_max uuid;
  v_run_manipal uuid;
BEGIN
  SELECT id INTO v_run_fortis FROM public.chain_cs_playbook_runs_r2483 WHERE chain_name='Fortis Healthcare' LIMIT 1;
  SELECT id INTO v_run_max FROM public.chain_cs_playbook_runs_r2483 WHERE chain_name='Max Healthcare' LIMIT 1;
  SELECT id INTO v_run_manipal FROM public.chain_cs_playbook_runs_r2483 WHERE chain_name='Manipal Hospitals' LIMIT 1;

  INSERT INTO public.playbook_deviations_r2483 (run_id, step_skipped, deviation_reason, severity, kill_action_md, owner_email, status, notes)
  VALUES (v_run_fortis, 'procurement_signoff_demo', 'Buyer on leave 10 days', 'high', 'Escalate to procurement head + offer remote demo', 'cs2@equipseva.com', 'in_progress', 'Demo rescheduled');

  INSERT INTO public.playbook_deviations_r2483 (run_id, step_skipped, deviation_reason, severity, kill_action_md, owner_email, status, notes)
  VALUES (v_run_max, 'p0_postmortem_within_24h', 'Founder unavailable', 'critical', 'Founder must own postmortem in 24h or auto-credit', 'cs3@equipseva.com', 'open', 'P0 dispute open');

  INSERT INTO public.playbook_deviations_r2483 (run_id, step_skipped, deviation_reason, severity, kill_action_md, owner_email, status, notes)
  VALUES (v_run_manipal, 'qbr_data_pack_t-7', 'Data pack assembled t-2', 'medium', 'Lock t-7 deadline in cron + auto-nag owner', 'cs1@equipseva.com', 'closed', 'Process fix shipped');
END $$;

-- RPC 1: list_runs_r2483
CREATE OR REPLACE FUNCTION public.list_runs_r2483()
RETURNS TABLE (
  id uuid,
  chain_name text,
  playbook_kind text,
  execution_stage text,
  adherence_pct int,
  outcome_kind text,
  owner_email text,
  started_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.playbook_kind, r.execution_stage, r.adherence_pct, r.outcome_kind,
         r.owner_email, r.started_at, r.completed_at, r.notes, r.created_at
  FROM public.chain_cs_playbook_runs_r2483 r
  ORDER BY r.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_runs_r2483() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_runs_r2483() TO authenticated;

-- RPC 2: list_deviations_r2483
CREATE OR REPLACE FUNCTION public.list_deviations_r2483()
RETURNS TABLE (
  id uuid,
  run_id uuid,
  chain_name text,
  step_skipped text,
  deviation_reason text,
  severity text,
  kill_action_md text,
  owner_email text,
  status text,
  deviation_at timestamptz,
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
  SELECT d.id, d.run_id, r.chain_name, d.step_skipped, d.deviation_reason, d.severity,
         d.kill_action_md, d.owner_email, d.status, d.deviation_at, d.notes
  FROM public.playbook_deviations_r2483 d
  JOIN public.chain_cs_playbook_runs_r2483 r ON r.id = d.run_id
  ORDER BY d.deviation_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_deviations_r2483() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_deviations_r2483() TO authenticated;

-- RPC 3: low_adherence_focus_r2483
CREATE OR REPLACE FUNCTION public.low_adherence_focus_r2483()
RETURNS TABLE (
  id uuid,
  chain_name text,
  playbook_kind text,
  execution_stage text,
  adherence_pct int,
  outcome_kind text,
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
  SELECT r.id, r.chain_name, r.playbook_kind, r.execution_stage, r.adherence_pct, r.outcome_kind, r.owner_email
  FROM public.chain_cs_playbook_runs_r2483 r
  WHERE r.adherence_pct < 75
    AND r.execution_stage NOT IN ('completed','dropped')
  ORDER BY r.adherence_pct ASC, r.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.low_adherence_focus_r2483() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.low_adherence_focus_r2483() TO authenticated;

-- RPC 4: top_deviation_severity_r2483
CREATE OR REPLACE FUNCTION public.top_deviation_severity_r2483()
RETURNS TABLE (
  severity text,
  total_deviations bigint,
  open_count bigint,
  closed_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.severity,
         COUNT(*)::bigint AS total_deviations,
         COUNT(*) FILTER (WHERE d.status IN ('open','in_progress'))::bigint AS open_count,
         COUNT(*) FILTER (WHERE d.status = 'closed')::bigint AS closed_count
  FROM public.playbook_deviations_r2483 d
  GROUP BY d.severity
  ORDER BY CASE d.severity
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
    ELSE 5
  END;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_deviation_severity_r2483() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_deviation_severity_r2483() TO authenticated;

-- RPC 5: playbook_kind_summary_r2483
CREATE OR REPLACE FUNCTION public.playbook_kind_summary_r2483()
RETURNS TABLE (
  playbook_kind text,
  run_count bigint,
  avg_adherence numeric,
  success_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.playbook_kind,
         COUNT(*)::bigint AS run_count,
         ROUND(AVG(r.adherence_pct)::numeric, 1) AS avg_adherence,
         COUNT(*) FILTER (WHERE r.outcome_kind = 'success')::bigint AS success_count
  FROM public.chain_cs_playbook_runs_r2483 r
  GROUP BY r.playbook_kind
  ORDER BY run_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.playbook_kind_summary_r2483() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.playbook_kind_summary_r2483() TO authenticated;

-- RPC 6: outcome_distribution_r2483
CREATE OR REPLACE FUNCTION public.outcome_distribution_r2483()
RETURNS TABLE (
  outcome_kind text,
  run_count bigint,
  avg_adherence numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.outcome_kind,
         COUNT(*)::bigint AS run_count,
         ROUND(AVG(r.adherence_pct)::numeric, 1) AS avg_adherence
  FROM public.chain_cs_playbook_runs_r2483 r
  GROUP BY r.outcome_kind
  ORDER BY run_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.outcome_distribution_r2483() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.outcome_distribution_r2483() TO authenticated;

-- RPC 7: owner_load_r2483
CREATE OR REPLACE FUNCTION public.owner_load_r2483()
RETURNS TABLE (
  owner_email text,
  active_runs bigint,
  total_runs bigint,
  avg_adherence numeric,
  open_deviations bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.owner_email,
         COUNT(*) FILTER (WHERE r.execution_stage NOT IN ('completed','dropped'))::bigint AS active_runs,
         COUNT(*)::bigint AS total_runs,
         ROUND(AVG(r.adherence_pct)::numeric, 1) AS avg_adherence,
         COALESCE((
           SELECT COUNT(*)::bigint
           FROM public.playbook_deviations_r2483 d
           JOIN public.chain_cs_playbook_runs_r2483 r2 ON r2.id = d.run_id
           WHERE r2.owner_email = r.owner_email
             AND d.status IN ('open','in_progress')
         ), 0) AS open_deviations
  FROM public.chain_cs_playbook_runs_r2483 r
  WHERE r.owner_email IS NOT NULL
  GROUP BY r.owner_email
  ORDER BY active_runs DESC, avg_adherence ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2483() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2483() TO authenticated;

