-- Round 2460: Customer AMC Onboarding Checklist
-- Hospital × onboarding step × status × days × auto reminders × handover signoff

-- =====================================================================
-- TABLE 1: amc_onboarding_steps_r2460
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.amc_onboarding_steps_r2460 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  step_kind text NOT NULL CHECK (step_kind IN ('kyc','po_signed','equipment_inventory','first_pm','handover_signoff','satisfaction_survey')),
  planned_at timestamptz NOT NULL,
  completed_at timestamptz,
  days_elapsed int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','blocked','dropped')),
  reminder_count int NOT NULL DEFAULT 0,
  last_reminder_at timestamptz,
  blocker_notes text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.amc_onboarding_steps_r2460 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.amc_onboarding_steps_r2460;
CREATE POLICY founder_all ON public.amc_onboarding_steps_r2460
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: amc_onboarding_handover_signoffs_r2460
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.amc_onboarding_handover_signoffs_r2460 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  signoff_at timestamptz NOT NULL,
  signoff_by_email text NOT NULL,
  equipment_count int NOT NULL DEFAULT 0,
  gst_invoice_issued boolean NOT NULL DEFAULT false,
  satisfaction_score numeric(3,2),
  status text NOT NULL CHECK (status IN ('pending','complete','escalated')),
  founder_review_required boolean NOT NULL DEFAULT false,
  founder_review_notes text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.amc_onboarding_handover_signoffs_r2460 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.amc_onboarding_handover_signoffs_r2460;
CREATE POLICY founder_all ON public.amc_onboarding_handover_signoffs_r2460
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
DO $seed$
DECLARE
  v_hospital1 uuid;
  v_hospital2 uuid;
  v_hospital3 uuid;
BEGIN
  SELECT id INTO v_hospital1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hospital2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_hospital1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hospital3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_hospital1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_hospital2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;

  IF v_hospital1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.amc_onboarding_steps_r2460 (hospital_user_id, step_kind, planned_at, completed_at, days_elapsed, status, reminder_count, last_reminder_at, blocker_notes, owner_email, notes)
  VALUES
    (v_hospital1, 'kyc', (now() - interval '12 days')::timestamptz, (now() - interval '10 days')::timestamptz, 2, 'done', 1, (now() - interval '11 days')::timestamptz, NULL, 'ops@equipseva.com', 'KYC clean'),
    (v_hospital1, 'po_signed', (now() - interval '9 days')::timestamptz, (now() - interval '7 days')::timestamptz, 2, 'done', 0, NULL, NULL, 'ops@equipseva.com', 'PO countersigned'),
    (v_hospital1, 'equipment_inventory', (now() - interval '6 days')::timestamptz, NULL, 6, 'in_progress', 2, (now() - interval '1 day')::timestamptz, 'Awaiting nurse manager confirm', 'ops@equipseva.com', 'Partial 12 of 18 done'),
    (COALESCE(v_hospital2, v_hospital1), 'first_pm', (now() - interval '4 days')::timestamptz, NULL, 4, 'blocked', 3, (now() - interval '6 hours')::timestamptz, 'Biomed engineer on leave', 'pm@equipseva.com', 'Rescheduled twice'),
    (COALESCE(v_hospital3, v_hospital1), 'handover_signoff', (now() - interval '2 days')::timestamptz, NULL, 2, 'open', 1, (now() - interval '1 day')::timestamptz, NULL, 'founder@equipseva.com', 'Awaiting admin signature');

  INSERT INTO public.amc_onboarding_handover_signoffs_r2460 (hospital_user_id, signoff_at, signoff_by_email, equipment_count, gst_invoice_issued, satisfaction_score, status, founder_review_required, founder_review_notes, notes)
  VALUES
    (v_hospital1, (now() - interval '15 days')::timestamptz, 'admin@hosp1.com', 18, true, 4.6, 'complete', false, NULL, 'Smooth handover'),
    (COALESCE(v_hospital2, v_hospital1), (now() - interval '8 days')::timestamptz, 'admin@hosp2.com', 24, true, 3.8, 'escalated', true, 'Score below 4.0 — schedule QBR', 'Founder follow-up'),
    (COALESCE(v_hospital3, v_hospital1), (now() - interval '3 days')::timestamptz, 'admin@hosp3.com', 12, false, NULL, 'pending', false, NULL, 'GST invoice pending');
END
$seed$;

-- =====================================================================
-- RPC 1: list_steps_r2460
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_steps_r2460()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  step_kind text,
  planned_at timestamptz,
  completed_at timestamptz,
  days_elapsed int,
  status text,
  reminder_count int,
  last_reminder_at timestamptz,
  blocker_notes text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.step_kind, s.planned_at, s.completed_at, s.days_elapsed, s.status, s.reminder_count, s.last_reminder_at, s.blocker_notes, s.owner_email, s.notes
  FROM public.amc_onboarding_steps_r2460 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.planned_at DESC
  LIMIT 200;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_steps_r2460() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_steps_r2460() TO authenticated;

-- =====================================================================
-- RPC 2: list_signoffs_r2460
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_signoffs_r2460()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  signoff_at timestamptz,
  signoff_by_email text,
  equipment_count int,
  gst_invoice_issued boolean,
  satisfaction_score numeric,
  status text,
  founder_review_required boolean,
  founder_review_notes text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, p.email, h.signoff_at, h.signoff_by_email, h.equipment_count, h.gst_invoice_issued, h.satisfaction_score, h.status, h.founder_review_required, h.founder_review_notes, h.notes
  FROM public.amc_onboarding_handover_signoffs_r2460 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  ORDER BY h.signoff_at DESC
  LIMIT 200;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_signoffs_r2460() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_signoffs_r2460() TO authenticated;

-- =====================================================================
-- RPC 3: stuck_steps_r2460
-- =====================================================================
CREATE OR REPLACE FUNCTION public.stuck_steps_r2460()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  step_kind text,
  status text,
  days_elapsed int,
  reminder_count int,
  blocker_notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.step_kind, s.status, s.days_elapsed, s.reminder_count, s.blocker_notes
  FROM public.amc_onboarding_steps_r2460 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.status IN ('blocked','in_progress','open') AND s.days_elapsed >= 3
  ORDER BY s.days_elapsed DESC
  LIMIT 100;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.stuck_steps_r2460() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stuck_steps_r2460() TO authenticated;

-- =====================================================================
-- RPC 4: step_kind_summary_r2460
-- =====================================================================
CREATE OR REPLACE FUNCTION public.step_kind_summary_r2460()
RETURNS TABLE (
  step_kind text,
  total_steps bigint,
  done_steps bigint,
  blocked_steps bigint,
  avg_days_elapsed numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.step_kind,
    count(*)::bigint,
    count(*) FILTER (WHERE s.status = 'done')::bigint,
    count(*) FILTER (WHERE s.status = 'blocked')::bigint,
    round(avg(s.days_elapsed)::numeric, 2)
  FROM public.amc_onboarding_steps_r2460 s
  GROUP BY s.step_kind
  ORDER BY s.step_kind;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.step_kind_summary_r2460() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.step_kind_summary_r2460() TO authenticated;

-- =====================================================================
-- RPC 5: top_hospitals_by_handover_r2460
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_hospitals_by_handover_r2460()
RETURNS TABLE (
  hospital_email text,
  handover_count bigint,
  avg_satisfaction numeric,
  total_equipment bigint,
  escalated_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.email,
    count(*)::bigint,
    round(avg(h.satisfaction_score)::numeric, 2),
    sum(h.equipment_count)::bigint,
    count(*) FILTER (WHERE h.status = 'escalated')::bigint
  FROM public.amc_onboarding_handover_signoffs_r2460 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  GROUP BY p.email
  ORDER BY count(*) DESC
  LIMIT 25;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_handover_r2460() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_handover_r2460() TO authenticated;

-- =====================================================================
-- RPC 6: this_week_due_steps_r2460
-- =====================================================================
CREATE OR REPLACE FUNCTION public.this_week_due_steps_r2460()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  step_kind text,
  planned_at timestamptz,
  status text,
  days_elapsed int,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.step_kind, s.planned_at, s.status, s.days_elapsed, s.owner_email
  FROM public.amc_onboarding_steps_r2460 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.planned_at BETWEEN (now() - interval '7 days')::timestamptz AND (now() + interval '7 days')::timestamptz
    AND s.status NOT IN ('done','dropped')
  ORDER BY s.planned_at ASC
  LIMIT 100;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.this_week_due_steps_r2460() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.this_week_due_steps_r2460() TO authenticated;

-- =====================================================================
-- RPC 7: monthly_onboarding_trend_r2460
-- =====================================================================
CREATE OR REPLACE FUNCTION public.monthly_onboarding_trend_r2460()
RETURNS TABLE (
  month_label text,
  steps_planned bigint,
  steps_done bigint,
  steps_blocked bigint,
  handovers_complete bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT to_char(date_trunc('month', s.planned_at), 'YYYY-MM') AS m,
           count(*)::bigint AS planned,
           count(*) FILTER (WHERE s.status = 'done')::bigint AS done,
           count(*) FILTER (WHERE s.status = 'blocked')::bigint AS blocked
    FROM public.amc_onboarding_steps_r2460 s
    GROUP BY 1
  ),
  handovers AS (
    SELECT to_char(date_trunc('month', h.signoff_at), 'YYYY-MM') AS m,
           count(*) FILTER (WHERE h.status = 'complete')::bigint AS done_count
    FROM public.amc_onboarding_handover_signoffs_r2460 h
    GROUP BY 1
  )
  SELECT
    m.m,
    m.planned,
    m.done,
    m.blocked,
    COALESCE(hh.done_count, 0::bigint)
  FROM months m
  LEFT JOIN handovers hh ON hh.m = m.m
  ORDER BY m.m DESC
  LIMIT 12;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.monthly_onboarding_trend_r2460() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_onboarding_trend_r2460() TO authenticated;
