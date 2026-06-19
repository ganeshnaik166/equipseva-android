BEGIN;
-- round1344 — Founder customer success playbook tracker
-- Per-AMC-tier playbook step ledger + per-contract runs + completion telemetry.
-- All RPCs founder-gated. No authenticated grants. STABLE SECURITY DEFINER plpgsql.

BEGIN;

-- 1. Steps catalog (template rows, per amc_tier)
CREATE TABLE IF NOT EXISTS public.founder_cs_playbook_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_tier text NOT NULL CHECK (amc_tier IN ('starter','growth','enterprise')),
  step_kind text NOT NULL CHECK (step_kind IN ('onboarding','first_visit_qa','monthly_checkin','quarterly_review','renewal_prep','churn_risk_save')),
  step_order int NOT NULL,
  step_title text NOT NULL,
  step_description text,
  default_due_days_after_activation int,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (amc_tier, step_order)
);

CREATE INDEX IF NOT EXISTS founder_cs_playbook_steps_tier_idx
  ON public.founder_cs_playbook_steps (amc_tier, step_order)
  WHERE is_active = true;

ALTER TABLE public.founder_cs_playbook_steps ENABLE ROW LEVEL SECURITY;

-- 2. Runs ledger (per-contract per-step instance)
CREATE TABLE IF NOT EXISTS public.founder_cs_playbook_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  step_id uuid NOT NULL REFERENCES public.founder_cs_playbook_steps(id) ON DELETE CASCADE,
  due_at date,
  completed_at timestamptz,
  completed_by uuid REFERENCES auth.users(id),
  outcome_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (amc_contract_id, step_id)
);

CREATE INDEX IF NOT EXISTS founder_cs_playbook_runs_due_idx
  ON public.founder_cs_playbook_runs (due_at)
  WHERE completed_at IS NULL;

CREATE INDEX IF NOT EXISTS founder_cs_playbook_runs_contract_idx
  ON public.founder_cs_playbook_runs (amc_contract_id);

ALTER TABLE public.founder_cs_playbook_runs ENABLE ROW LEVEL SECURITY;

-- 3. Seed default steps (15 across 3 tiers) — idempotent via UNIQUE(amc_tier, step_order)
INSERT INTO public.founder_cs_playbook_steps (amc_tier, step_kind, step_order, step_title, step_description, default_due_days_after_activation)
VALUES
  -- starter (5)
  ('starter',    'onboarding',        1, 'Welcome onboarding call',            'Founder/CS call: confirm equipment list, primary engineer, billing contact.', 1),
  ('starter',    'first_visit_qa',    2, 'First visit QA check',                'Verify first scheduled visit was completed; rating captured.',                14),
  ('starter',    'monthly_checkin',   3, 'Month-1 checkin',                     'SMS+call: any open issues, satisfaction pulse.',                              30),
  ('starter',    'monthly_checkin',   4, 'Month-2 checkin',                     'SMS+call: usage rhythm + escalations.',                                       60),
  ('starter',    'quarterly_review',  5, 'Quarter-1 review',                    'Share visit summary + NPS pulse + renewal nudge.',                            90),
  -- growth (6)
  ('growth',     'onboarding',        1, 'Welcome onboarding call',             'Founder/CS call + success-manager intro.',                                    1),
  ('growth',     'first_visit_qa',    2, 'First visit QA check',                'Verify first visit + photos uploaded.',                                       10),
  ('growth',     'monthly_checkin',   3, 'Monthly success-manager checkin',     'Dedicated SM walks hospital through visit log.',                              30),
  ('growth',     'monthly_checkin',   4, 'Month-2 checkin',                     'SM call + escalation review.',                                                60),
  ('growth',     'quarterly_review',  5, 'Quarterly review',                    'On-call review with SLA stats.',                                              90),
  ('growth',     'renewal_prep',      6, 'Semi-annual deep-dive',               'Renewal pre-brief + tier-fit assessment.',                                    180),
  -- enterprise (8)
  ('enterprise', 'onboarding',        1, 'Welcome onboarding call',             'Founder + SM + account exec joint kickoff.',                                  1),
  ('enterprise', 'first_visit_qa',    2, 'First visit onsite QA',               'SM onsite during first visit; signoff captured.',                             7),
  ('enterprise', 'monthly_checkin',   3, 'Monthly checkin',                     'SM monthly call + bespoke report.',                                           30),
  ('enterprise', 'quarterly_review',  4, 'Quarterly onsite review',             'SM travels onsite; biometric SLA & uptime walkthrough.',                      90),
  ('enterprise', 'quarterly_review',  5, 'Custom SLA report',                   'Bespoke SLA + downtime report shared with hospital ops head.',                100),
  ('enterprise', 'renewal_prep',      6, 'Renewal prep brief',                  'Founder briefs hospital admin on renewal terms 60d before end_date.',         300),
  ('enterprise', 'churn_risk_save',   7, 'Churn-risk save play',                'Triggered when complaint count or downtime breaches threshold.',              365),
  ('enterprise', 'monthly_checkin',   8, 'Quarter-4 deep checkin',              'Final-quarter health assessment before renewal.',                             330)
ON CONFLICT (amc_tier, step_order) DO NOTHING;

-- 4. Summary RPC — 12 KPIs
DROP FUNCTION IF EXISTS public.founder_cs_playbook_summary();
CREATE OR REPLACE FUNCTION public.founder_cs_playbook_summary()
RETURNS TABLE (
  total_active_contracts        bigint,
  total_active_steps            bigint,
  runs_due_this_week            bigint,
  runs_due_today                bigint,
  runs_completed_this_month     bigint,
  runs_overdue                  bigint,
  runs_overdue_30d              bigint,
  runs_overdue_90d              bigint,
  contracts_with_zero_runs      bigint,
  completion_pct_30d            numeric,
  completion_pct_90d            numeric,
  top_overdue_tier              text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := current_date;
  v_total_30d bigint;
  v_done_30d bigint;
  v_total_90d bigint;
  v_done_90d bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*) INTO total_active_contracts
    FROM public.amc_contracts WHERE status = 'active';

  SELECT COUNT(*) INTO total_active_steps
    FROM public.founder_cs_playbook_steps WHERE is_active = true;

  SELECT COUNT(*) INTO runs_due_this_week
    FROM public.founder_cs_playbook_runs
   WHERE completed_at IS NULL
     AND due_at IS NOT NULL
     AND due_at BETWEEN v_today AND v_today + INTERVAL '7 days';

  SELECT COUNT(*) INTO runs_due_today
    FROM public.founder_cs_playbook_runs
   WHERE completed_at IS NULL AND due_at = v_today;

  SELECT COUNT(*) INTO runs_completed_this_month
    FROM public.founder_cs_playbook_runs
   WHERE completed_at IS NOT NULL
     AND completed_at >= date_trunc('month', now());

  SELECT COUNT(*) INTO runs_overdue
    FROM public.founder_cs_playbook_runs
   WHERE completed_at IS NULL AND due_at IS NOT NULL AND due_at < v_today;

  SELECT COUNT(*) INTO runs_overdue_30d
    FROM public.founder_cs_playbook_runs
   WHERE completed_at IS NULL AND due_at IS NOT NULL
     AND due_at < v_today - INTERVAL '30 days';

  SELECT COUNT(*) INTO runs_overdue_90d
    FROM public.founder_cs_playbook_runs
   WHERE completed_at IS NULL AND due_at IS NOT NULL
     AND due_at < v_today - INTERVAL '90 days';

  SELECT COUNT(*) INTO contracts_with_zero_runs
    FROM public.amc_contracts c
   WHERE c.status = 'active'
     AND NOT EXISTS (
       SELECT 1 FROM public.founder_cs_playbook_runs r
        WHERE r.amc_contract_id = c.id
     );

  SELECT COUNT(*) FILTER (WHERE r.due_at >= v_today - INTERVAL '30 days'),
         COUNT(*) FILTER (WHERE r.due_at >= v_today - INTERVAL '30 days' AND r.completed_at IS NOT NULL)
    INTO v_total_30d, v_done_30d
    FROM public.founder_cs_playbook_runs r;

  SELECT COUNT(*) FILTER (WHERE r.due_at >= v_today - INTERVAL '90 days'),
         COUNT(*) FILTER (WHERE r.due_at >= v_today - INTERVAL '90 days' AND r.completed_at IS NOT NULL)
    INTO v_total_90d, v_done_90d
    FROM public.founder_cs_playbook_runs r;

  completion_pct_30d := CASE WHEN v_total_30d > 0 THEN round((v_done_30d::numeric * 100.0) / v_total_30d, 1) ELSE NULL END;
  completion_pct_90d := CASE WHEN v_total_90d > 0 THEN round((v_done_90d::numeric * 100.0) / v_total_90d, 1) ELSE NULL END;

  SELECT s.amc_tier INTO top_overdue_tier
    FROM public.founder_cs_playbook_runs r
    JOIN public.founder_cs_playbook_steps s ON s.id = r.step_id
   WHERE r.completed_at IS NULL AND r.due_at IS NOT NULL AND r.due_at < v_today
   GROUP BY s.amc_tier
   ORDER BY COUNT(*) DESC
   LIMIT 1;

  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cs_playbook_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_playbook_summary() TO authenticated;

-- 5. Runs-due RPC
DROP FUNCTION IF EXISTS public.founder_cs_playbook_runs_due(int);
CREATE OR REPLACE FUNCTION public.founder_cs_playbook_runs_due(p_limit int DEFAULT 50)
RETURNS TABLE (
  run_id            uuid,
  amc_contract_id   uuid,
  hospital_name     text,
  amc_tier          text,
  step_kind         text,
  step_title        text,
  due_at            date,
  overdue_days      int,
  monthly_fee_rupees numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.amc_contract_id,
    COALESCE(o.name, p.full_name, 'Unknown hospital')::text,
    s.amc_tier::text,
    s.step_kind::text,
    s.step_title::text,
    r.due_at,
    GREATEST((current_date - r.due_at)::int, 0),
    c.monthly_fee_rupees
  FROM public.founder_cs_playbook_runs r
  JOIN public.founder_cs_playbook_steps s ON s.id = r.step_id
  JOIN public.amc_contracts c              ON c.id = r.amc_contract_id
  LEFT JOIN public.profiles p              ON p.user_id = c.hospital_user_id
  LEFT JOIN public.organizations o         ON o.id = p.organization_id
  WHERE r.completed_at IS NULL
    AND r.due_at IS NOT NULL
    AND r.due_at <= current_date
  ORDER BY (current_date - r.due_at) DESC, r.due_at ASC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cs_playbook_runs_due(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_playbook_runs_due(int) TO authenticated;

-- 6. Runs by contract
DROP FUNCTION IF EXISTS public.founder_cs_playbook_runs_by_contract(uuid);
CREATE OR REPLACE FUNCTION public.founder_cs_playbook_runs_by_contract(p_contract_id uuid)
RETURNS TABLE (
  run_id        uuid,
  step_kind     text,
  step_title    text,
  step_order    int,
  due_at        date,
  completed_at  timestamptz,
  outcome_note  text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT r.id, s.step_kind::text, s.step_title::text, s.step_order, r.due_at, r.completed_at, r.outcome_note
  FROM public.founder_cs_playbook_runs r
  JOIN public.founder_cs_playbook_steps s ON s.id = r.step_id
  WHERE r.amc_contract_id = p_contract_id
  ORDER BY s.step_order ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cs_playbook_runs_by_contract(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cs_playbook_runs_by_contract(uuid) TO authenticated;

-- 7. Seed runs for a contract
DROP FUNCTION IF EXISTS public.log_founder_cs_playbook_seed_for_contract(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_cs_playbook_seed_for_contract(p_contract_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tier text;
  v_activated timestamptz;
  v_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT amc_tier, COALESCE(activated_at, created_at)
    INTO v_tier, v_activated
    FROM public.amc_contracts
   WHERE id = p_contract_id;

  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'contract not found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.founder_cs_playbook_runs (amc_contract_id, step_id, due_at)
  SELECT p_contract_id,
         s.id,
         (v_activated::date + COALESCE(s.default_due_days_after_activation, 0))
    FROM public.founder_cs_playbook_steps s
   WHERE s.amc_tier = v_tier AND s.is_active = true
  ON CONFLICT (amc_contract_id, step_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_cs_playbook_seed_for_contract(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cs_playbook_seed_for_contract(uuid) TO authenticated;

-- 8. Complete a run
DROP FUNCTION IF EXISTS public.log_founder_cs_playbook_complete_run(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_cs_playbook_complete_run(p_run_id uuid, p_outcome_note text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_cs_playbook_runs
     SET completed_at  = COALESCE(completed_at, now()),
         completed_by  = COALESCE(completed_by, auth.uid()),
         outcome_note  = p_outcome_note
   WHERE id = p_run_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_cs_playbook_complete_run(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cs_playbook_complete_run(uuid, text) TO authenticated;

COMMIT;