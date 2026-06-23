BEGIN;

-- =========================================================================
-- r2306: Engineer first-call-fix-rate tracker
-- Tables:
--   founder_first_call_fix_visits_r2306    — one row per repair-job site visit
--   founder_first_call_fix_root_causes_r2306 — root-cause log for revisits
-- Purpose: measure % of jobs resolved on first visit vs needing 2nd/3rd
-- visit; surface root cause for revisits and aggregate by engineer.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_first_call_fix_visits_r2306 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id               uuid,
  job_label                   text NOT NULL,
  engineer_user_id            uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  engineer_email              text NOT NULL,
  engineer_tier               text NOT NULL DEFAULT 'silver'
    CHECK (engineer_tier IN ('bronze','silver','gold','platinum','diamond','master')),
  hospital_org_id             uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  hospital_label              text NOT NULL,
  region                      text NOT NULL DEFAULT 'south'
    CHECK (region IN ('north','south','east','west','central','northeast','metro_blr','metro_hyd','metro_chn','metro_mum','metro_del','other')),
  equipment_category          text NOT NULL DEFAULT 'imaging'
    CHECK (equipment_category IN ('imaging','dialysis','ventilator','monitor','surgical','dental','lab','sterilizer','ot_table','anesthesia','infusion','ecg','ultrasound','xray','ct','mri','other')),
  visit_number                int  NOT NULL DEFAULT 1 CHECK (visit_number BETWEEN 1 AND 10),
  visit_date                  date NOT NULL DEFAULT CURRENT_DATE,
  arrival_at                  timestamptz,
  departure_at                timestamptz,
  on_site_minutes             int  CHECK (on_site_minutes IS NULL OR on_site_minutes >= 0),
  outcome                     text NOT NULL DEFAULT 'resolved_on_site'
    CHECK (outcome IN ('resolved_on_site','partial_fix','needs_part','needs_specialist','customer_unavailable','wrong_diagnosis','deferred','escalated','unresolved')),
  fixed_on_first_call         boolean NOT NULL DEFAULT false,
  needs_revisit               boolean NOT NULL DEFAULT false,
  revisit_scheduled_on        date,
  diagnosis_confidence        text NOT NULL DEFAULT 'medium'
    CHECK (diagnosis_confidence IN ('low','medium','high','certain')),
  customer_satisfaction       int  CHECK (customer_satisfaction IS NULL OR customer_satisfaction BETWEEN 1 AND 5),
  parts_carried_count         int  NOT NULL DEFAULT 0 CHECK (parts_carried_count >= 0),
  parts_used_count            int  NOT NULL DEFAULT 0 CHECK (parts_used_count >= 0),
  notes                       text,
  created_by                  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcfv_r2306_engineer ON public.founder_first_call_fix_visits_r2306(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_fcfv_r2306_email    ON public.founder_first_call_fix_visits_r2306(engineer_email);
CREATE INDEX IF NOT EXISTS idx_fcfv_r2306_job      ON public.founder_first_call_fix_visits_r2306(repair_job_id);
CREATE INDEX IF NOT EXISTS idx_fcfv_r2306_visit    ON public.founder_first_call_fix_visits_r2306(visit_date);
CREATE INDEX IF NOT EXISTS idx_fcfv_r2306_outcome  ON public.founder_first_call_fix_visits_r2306(outcome);
CREATE INDEX IF NOT EXISTS idx_fcfv_r2306_cat      ON public.founder_first_call_fix_visits_r2306(equipment_category);
CREATE INDEX IF NOT EXISTS idx_fcfv_r2306_region   ON public.founder_first_call_fix_visits_r2306(region);
CREATE INDEX IF NOT EXISTS idx_fcfv_r2306_fcf      ON public.founder_first_call_fix_visits_r2306(fixed_on_first_call);

CREATE TABLE IF NOT EXISTS public.founder_first_call_fix_root_causes_r2306 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id                    uuid NOT NULL REFERENCES public.founder_first_call_fix_visits_r2306(id) ON DELETE CASCADE,
  root_cause_category         text NOT NULL DEFAULT 'missing_part'
    CHECK (root_cause_category IN ('missing_part','wrong_part','wrong_diagnosis','insufficient_tools','training_gap','equipment_complexity','customer_blocker','remote_dependency','vendor_dependency','time_constraint','sla_breach','documentation_gap','firmware_issue','other')),
  severity                    text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  detected_on                 date NOT NULL DEFAULT CURRENT_DATE,
  responsible_party           text NOT NULL DEFAULT 'engineer'
    CHECK (responsible_party IN ('engineer','supplier','manufacturer','logistics','hospital_admin','customer','founder','ops')),
  responsible_user_id         uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  cost_of_revisit_rupees      bigint NOT NULL DEFAULT 0 CHECK (cost_of_revisit_rupees >= 0),
  preventive_action           text,
  coaching_assigned           boolean NOT NULL DEFAULT false,
  coaching_completed_on       date,
  resolved_on                 date,
  prevented_future_count      int  NOT NULL DEFAULT 0 CHECK (prevented_future_count >= 0),
  notes                       text,
  created_by                  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcfrc_r2306_visit    ON public.founder_first_call_fix_root_causes_r2306(visit_id);
CREATE INDEX IF NOT EXISTS idx_fcfrc_r2306_cat      ON public.founder_first_call_fix_root_causes_r2306(root_cause_category);
CREATE INDEX IF NOT EXISTS idx_fcfrc_r2306_sev      ON public.founder_first_call_fix_root_causes_r2306(severity);
CREATE INDEX IF NOT EXISTS idx_fcfrc_r2306_party    ON public.founder_first_call_fix_root_causes_r2306(responsible_party);
CREATE INDEX IF NOT EXISTS idx_fcfrc_r2306_detected ON public.founder_first_call_fix_root_causes_r2306(detected_on);

-- =========================================================================
-- RLS — founder_all
-- =========================================================================
ALTER TABLE public.founder_first_call_fix_visits_r2306      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_first_call_fix_root_causes_r2306 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fcfv_r2306 ON public.founder_first_call_fix_visits_r2306;
CREATE POLICY founder_all_fcfv_r2306 ON public.founder_first_call_fix_visits_r2306
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fcfrc_r2306 ON public.founder_first_call_fix_root_causes_r2306;
CREATE POLICY founder_all_fcfrc_r2306 ON public.founder_first_call_fix_root_causes_r2306
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs (7) — all is_founder gated, plpgsql SECURITY DEFINER
-- =========================================================================

-- 1. list_first_call_fix_visits_r2306
CREATE OR REPLACE FUNCTION public.list_first_call_fix_visits_r2306()
RETURNS TABLE (
  id uuid,
  job_label text,
  engineer_email text,
  engineer_tier text,
  hospital_label text,
  region text,
  equipment_category text,
  visit_number int,
  visit_date date,
  on_site_minutes int,
  outcome text,
  fixed_on_first_call boolean,
  needs_revisit boolean,
  revisit_scheduled_on date,
  diagnosis_confidence text,
  customer_satisfaction int,
  parts_carried_count int,
  parts_used_count int,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.job_label, v.engineer_email, v.engineer_tier,
         v.hospital_label, v.region, v.equipment_category,
         v.visit_number, v.visit_date, v.on_site_minutes,
         v.outcome, v.fixed_on_first_call, v.needs_revisit,
         v.revisit_scheduled_on, v.diagnosis_confidence,
         v.customer_satisfaction, v.parts_carried_count, v.parts_used_count,
         v.notes, v.created_at
    FROM public.founder_first_call_fix_visits_r2306 v
   ORDER BY v.visit_date DESC, v.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_first_call_fix_visits_r2306() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_first_call_fix_visits_r2306() TO authenticated;

-- 2. log_first_call_fix_visit_r2306
CREATE OR REPLACE FUNCTION public.log_first_call_fix_visit_r2306(
  p_job_label text,
  p_engineer_email text,
  p_engineer_tier text,
  p_hospital_label text,
  p_region text,
  p_equipment_category text,
  p_visit_number int,
  p_visit_date date,
  p_outcome text,
  p_fixed_on_first_call boolean,
  p_needs_revisit boolean,
  p_diagnosis_confidence text,
  p_customer_satisfaction int,
  p_on_site_minutes int,
  p_parts_carried_count int,
  p_parts_used_count int,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_actor uuid;
  v_engineer_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_actor FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;
  SELECT id INTO v_engineer_id FROM public.profiles WHERE email = p_engineer_email LIMIT 1;

  INSERT INTO public.founder_first_call_fix_visits_r2306 (
    job_label, engineer_user_id, engineer_email, engineer_tier,
    hospital_label, region, equipment_category,
    visit_number, visit_date, on_site_minutes,
    outcome, fixed_on_first_call, needs_revisit,
    diagnosis_confidence, customer_satisfaction,
    parts_carried_count, parts_used_count, notes, created_by
  )
  VALUES (
    p_job_label, v_engineer_id, p_engineer_email,
    COALESCE(p_engineer_tier,'silver'),
    p_hospital_label,
    COALESCE(p_region,'south'),
    COALESCE(p_equipment_category,'imaging'),
    COALESCE(p_visit_number, 1),
    COALESCE(p_visit_date, CURRENT_DATE),
    p_on_site_minutes,
    COALESCE(p_outcome,'resolved_on_site'),
    COALESCE(p_fixed_on_first_call, false),
    COALESCE(p_needs_revisit, false),
    COALESCE(p_diagnosis_confidence,'medium'),
    p_customer_satisfaction,
    COALESCE(p_parts_carried_count, 0),
    COALESCE(p_parts_used_count, 0),
    p_notes, v_actor
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_first_call_fix_visit_r2306(text,text,text,text,text,text,int,date,text,boolean,boolean,text,int,int,int,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_first_call_fix_visit_r2306(text,text,text,text,text,text,int,date,text,boolean,boolean,text,int,int,int,int,text) TO authenticated;

-- 3. update_first_call_fix_outcome_r2306
CREATE OR REPLACE FUNCTION public.update_first_call_fix_outcome_r2306(
  p_visit_id uuid,
  p_outcome text,
  p_fixed_on_first_call boolean,
  p_needs_revisit boolean,
  p_revisit_scheduled_on date,
  p_customer_satisfaction int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_first_call_fix_visits_r2306
     SET outcome                = COALESCE(p_outcome, outcome),
         fixed_on_first_call    = COALESCE(p_fixed_on_first_call, fixed_on_first_call),
         needs_revisit          = COALESCE(p_needs_revisit, needs_revisit),
         revisit_scheduled_on   = COALESCE(p_revisit_scheduled_on, revisit_scheduled_on),
         customer_satisfaction  = COALESCE(p_customer_satisfaction, customer_satisfaction),
         updated_at             = now()
   WHERE id = p_visit_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_first_call_fix_outcome_r2306(uuid,text,boolean,boolean,date,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_first_call_fix_outcome_r2306(uuid,text,boolean,boolean,date,int) TO authenticated;

-- 4. log_first_call_fix_root_cause_r2306
CREATE OR REPLACE FUNCTION public.log_first_call_fix_root_cause_r2306(
  p_visit_id uuid,
  p_root_cause_category text,
  p_severity text,
  p_responsible_party text,
  p_cost_of_revisit_rupees bigint,
  p_preventive_action text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_actor uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_actor FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;

  INSERT INTO public.founder_first_call_fix_root_causes_r2306 (
    visit_id, root_cause_category, severity, responsible_party,
    cost_of_revisit_rupees, preventive_action, notes, responsible_user_id, created_by
  )
  VALUES (
    p_visit_id,
    COALESCE(p_root_cause_category,'missing_part'),
    COALESCE(p_severity,'medium'),
    COALESCE(p_responsible_party,'engineer'),
    COALESCE(p_cost_of_revisit_rupees, 0),
    p_preventive_action, p_notes, v_actor, v_actor
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_first_call_fix_root_cause_r2306(uuid,text,text,text,bigint,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_first_call_fix_root_cause_r2306(uuid,text,text,text,bigint,text,text) TO authenticated;

-- 5. resolve_first_call_fix_root_cause_r2306
CREATE OR REPLACE FUNCTION public.resolve_first_call_fix_root_cause_r2306(
  p_root_cause_id uuid,
  p_coaching_completed_on date,
  p_prevented_future_count int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_first_call_fix_root_causes_r2306
     SET resolved_on            = CURRENT_DATE,
         coaching_assigned      = true,
         coaching_completed_on  = COALESCE(p_coaching_completed_on, coaching_completed_on),
         prevented_future_count = GREATEST(COALESCE(p_prevented_future_count, 0), 0)
   WHERE id = p_root_cause_id;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_first_call_fix_root_cause_r2306(uuid,date,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_first_call_fix_root_cause_r2306(uuid,date,int) TO authenticated;

-- 6. list_first_call_fix_root_causes_r2306
CREATE OR REPLACE FUNCTION public.list_first_call_fix_root_causes_r2306(p_visit_id uuid)
RETURNS TABLE (
  id uuid,
  visit_id uuid,
  job_label text,
  engineer_email text,
  root_cause_category text,
  severity text,
  responsible_party text,
  detected_on date,
  resolved_on date,
  cost_of_revisit_rupees bigint,
  preventive_action text,
  coaching_assigned boolean,
  coaching_completed_on date,
  prevented_future_count int,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT rc.id, rc.visit_id, v.job_label, v.engineer_email,
         rc.root_cause_category, rc.severity, rc.responsible_party,
         rc.detected_on, rc.resolved_on, rc.cost_of_revisit_rupees,
         rc.preventive_action, rc.coaching_assigned, rc.coaching_completed_on,
         rc.prevented_future_count, rc.notes, rc.created_at
    FROM public.founder_first_call_fix_root_causes_r2306 rc
    JOIN public.founder_first_call_fix_visits_r2306 v ON v.id = rc.visit_id
   WHERE p_visit_id IS NULL OR rc.visit_id = p_visit_id
   ORDER BY rc.detected_on DESC, rc.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_first_call_fix_root_causes_r2306(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_first_call_fix_root_causes_r2306(uuid) TO authenticated;

-- 7. first_call_fix_rate_summary_r2306 — KPI roll-up by engineer + global
CREATE OR REPLACE FUNCTION public.first_call_fix_rate_summary_r2306()
RETURNS TABLE (
  total_visits int,
  unique_jobs int,
  first_visit_count int,
  second_visit_count int,
  third_plus_visit_count int,
  fcf_count int,
  fcf_rate_pct numeric,
  revisit_required_count int,
  revisit_rate_pct numeric,
  avg_on_site_minutes numeric,
  avg_customer_satisfaction numeric,
  total_root_causes int,
  open_root_causes int,
  critical_root_causes int,
  total_revisit_cost_rupees bigint,
  avg_revisit_cost_rupees numeric,
  top_root_cause_category text,
  worst_engineer_email text,
  best_engineer_email text,
  worst_equipment_category text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_cause text;
  v_worst_eng text;
  v_best_eng text;
  v_worst_cat text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT rc.root_cause_category
    INTO v_top_cause
    FROM public.founder_first_call_fix_root_causes_r2306 rc
   GROUP BY rc.root_cause_category
   ORDER BY count(*) DESC
   LIMIT 1;

  SELECT v.engineer_email
    INTO v_worst_eng
    FROM public.founder_first_call_fix_visits_r2306 v
   GROUP BY v.engineer_email
  HAVING count(*) >= 3
   ORDER BY (sum(CASE WHEN v.fixed_on_first_call THEN 1 ELSE 0 END)::numeric / GREATEST(count(*),1)) ASC
   LIMIT 1;

  SELECT v.engineer_email
    INTO v_best_eng
    FROM public.founder_first_call_fix_visits_r2306 v
   GROUP BY v.engineer_email
  HAVING count(*) >= 3
   ORDER BY (sum(CASE WHEN v.fixed_on_first_call THEN 1 ELSE 0 END)::numeric / GREATEST(count(*),1)) DESC
   LIMIT 1;

  SELECT v.equipment_category
    INTO v_worst_cat
    FROM public.founder_first_call_fix_visits_r2306 v
   GROUP BY v.equipment_category
  HAVING count(*) >= 3
   ORDER BY (sum(CASE WHEN v.fixed_on_first_call THEN 1 ELSE 0 END)::numeric / GREATEST(count(*),1)) ASC
   LIMIT 1;

  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM public.founder_first_call_fix_visits_r2306),
    (SELECT count(DISTINCT job_label)::int FROM public.founder_first_call_fix_visits_r2306),
    (SELECT count(*)::int FROM public.founder_first_call_fix_visits_r2306 WHERE visit_number = 1),
    (SELECT count(*)::int FROM public.founder_first_call_fix_visits_r2306 WHERE visit_number = 2),
    (SELECT count(*)::int FROM public.founder_first_call_fix_visits_r2306 WHERE visit_number >= 3),
    (SELECT count(*)::int FROM public.founder_first_call_fix_visits_r2306 WHERE fixed_on_first_call AND visit_number = 1),
    COALESCE((SELECT (sum(CASE WHEN fixed_on_first_call AND visit_number = 1 THEN 1 ELSE 0 END)::numeric * 100
                   / GREATEST(count(*) FILTER (WHERE visit_number = 1), 1))
                 FROM public.founder_first_call_fix_visits_r2306), 0)::numeric,
    (SELECT count(*)::int FROM public.founder_first_call_fix_visits_r2306 WHERE needs_revisit),
    COALESCE((SELECT (sum(CASE WHEN needs_revisit THEN 1 ELSE 0 END)::numeric * 100
                   / GREATEST(count(*),1))
                 FROM public.founder_first_call_fix_visits_r2306), 0)::numeric,
    COALESCE((SELECT avg(on_site_minutes) FROM public.founder_first_call_fix_visits_r2306 WHERE on_site_minutes IS NOT NULL), 0)::numeric,
    COALESCE((SELECT avg(customer_satisfaction) FROM public.founder_first_call_fix_visits_r2306 WHERE customer_satisfaction IS NOT NULL), 0)::numeric,
    (SELECT count(*)::int FROM public.founder_first_call_fix_root_causes_r2306),
    (SELECT count(*)::int FROM public.founder_first_call_fix_root_causes_r2306 WHERE resolved_on IS NULL),
    (SELECT count(*)::int FROM public.founder_first_call_fix_root_causes_r2306 WHERE severity = 'critical'),
    COALESCE((SELECT sum(cost_of_revisit_rupees) FROM public.founder_first_call_fix_root_causes_r2306), 0)::bigint,
    COALESCE((SELECT avg(cost_of_revisit_rupees) FROM public.founder_first_call_fix_root_causes_r2306), 0)::numeric,
    COALESCE(v_top_cause, '—'),
    COALESCE(v_worst_eng, '—'),
    COALESCE(v_best_eng, '—'),
    COALESCE(v_worst_cat, '—');
END;
$$;

REVOKE ALL ON FUNCTION public.first_call_fix_rate_summary_r2306() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.first_call_fix_rate_summary_r2306() TO authenticated;

COMMIT;
