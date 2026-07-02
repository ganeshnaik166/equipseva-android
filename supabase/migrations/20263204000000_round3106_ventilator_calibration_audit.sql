-- Round 3106 — Customer Hospital Critical Care Ventilator Calibration & Tidal-Volume Accuracy Audit
-- Monthly ICU ventilator calibration: set vs delivered tidal volume, PEEP accuracy, FiO2 mix, alarm test, leak test, CAPA queue.

BEGIN;

-- =========================================================================
-- TABLE 1: ventilator_calibration_runs_r3106
-- One row per monthly calibration session per ICU ventilator unit.
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.ventilator_calibration_runs_r3106 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id             uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  engineer_id                 uuid NOT NULL REFERENCES public.engineers(id) ON DELETE RESTRICT,
  asset_tag                   text NOT NULL,
  ventilator_model            text NOT NULL,
  icu_bay                     text NOT NULL,
  calibration_month           date NOT NULL,
  calibration_kind            text NOT NULL CHECK (calibration_kind IN ('monthly_routine','quarterly_deep','post_repair','post_install','recall_response')),
  set_tidal_volume_ml         integer NOT NULL CHECK (set_tidal_volume_ml BETWEEN 100 AND 1000),
  delivered_tidal_volume_ml   numeric(6,2) NOT NULL CHECK (delivered_tidal_volume_ml BETWEEN 0 AND 1200),
  tidal_deviation_pct         numeric(5,2) NOT NULL,
  set_peep_cmh2o              numeric(4,1) NOT NULL CHECK (set_peep_cmh2o BETWEEN 0 AND 25),
  delivered_peep_cmh2o        numeric(4,1) NOT NULL CHECK (delivered_peep_cmh2o BETWEEN 0 AND 30),
  peep_deviation_cmh2o        numeric(4,2) NOT NULL,
  set_fio2_pct                integer NOT NULL CHECK (set_fio2_pct BETWEEN 21 AND 100),
  delivered_fio2_pct          numeric(5,2) NOT NULL CHECK (delivered_fio2_pct BETWEEN 0 AND 100),
  fio2_deviation_pct          numeric(5,2) NOT NULL,
  alarm_test_result           text NOT NULL CHECK (alarm_test_result IN ('pass','fail_high_pressure','fail_low_pressure','fail_apnea','fail_disconnect','fail_power')),
  leak_test_ml_per_min        numeric(6,2) NOT NULL CHECK (leak_test_ml_per_min >= 0),
  leak_verdict                text NOT NULL CHECK (leak_verdict IN ('within_spec','marginal','out_of_spec','catastrophic')),
  overall_verdict             text NOT NULL CHECK (overall_verdict IN ('pass','pass_with_observation','conditional_pass','fail_take_out_of_service','fail_capa_required')),
  capa_required               boolean NOT NULL DEFAULT false,
  next_due_date               date NOT NULL,
  notes                       text,
  created_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vcal_r3106_hospital ON public.ventilator_calibration_runs_r3106(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_vcal_r3106_month    ON public.ventilator_calibration_runs_r3106(calibration_month);
CREATE INDEX IF NOT EXISTS idx_vcal_r3106_verdict  ON public.ventilator_calibration_runs_r3106(overall_verdict);

-- =========================================================================
-- TABLE 2: ventilator_capa_actions_r3106
-- CAPA (Corrective And Preventive Action) queue items raised against a run.
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.ventilator_capa_actions_r3106 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  calibration_run_id       uuid NOT NULL REFERENCES public.ventilator_calibration_runs_r3106(id) ON DELETE CASCADE,
  hospital_org_id          uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  capa_category            text NOT NULL CHECK (capa_category IN ('tidal_volume_drift','peep_drift','fio2_mix_drift','alarm_failure','leak_failure','flow_sensor_replace','oxygen_sensor_replace','expiratory_valve_service','calibration_recall','firmware_update','training_gap','sop_violation')),
  severity                 text NOT NULL CHECK (severity IN ('p0_critical','p1_high','p2_medium','p3_low','observation')),
  raised_against           text NOT NULL CHECK (raised_against IN ('vendor','biomed_team','icu_staff','manufacturer','procurement','engineer')),
  capa_status              text NOT NULL CHECK (capa_status IN ('open','in_progress','awaiting_part','awaiting_oem','blocked','closed_verified','closed_no_action','escalated_founder')),
  due_within_hours         integer NOT NULL CHECK (due_within_hours BETWEEN 1 AND 720),
  hours_to_close           numeric(6,2),
  cost_to_close_rupees     integer NOT NULL DEFAULT 0 CHECK (cost_to_close_rupees >= 0),
  part_replaced_sku        text,
  patient_safety_event     boolean NOT NULL DEFAULT false,
  reported_to_cdsco        boolean NOT NULL DEFAULT false,
  closed_at                timestamptz,
  closure_evidence_url     text,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vcapa_r3106_run      ON public.ventilator_capa_actions_r3106(calibration_run_id);
CREATE INDEX IF NOT EXISTS idx_vcapa_r3106_status   ON public.ventilator_capa_actions_r3106(capa_status);
CREATE INDEX IF NOT EXISTS idx_vcapa_r3106_severity ON public.ventilator_capa_actions_r3106(severity);

-- RLS
ALTER TABLE public.ventilator_calibration_runs_r3106 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventilator_capa_actions_r3106     ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vcal_r3106_founder_all ON public.ventilator_calibration_runs_r3106;
CREATE POLICY vcal_r3106_founder_all ON public.ventilator_calibration_runs_r3106
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS vcapa_r3106_founder_all ON public.ventilator_capa_actions_r3106;
CREATE POLICY vcapa_r3106_founder_all ON public.ventilator_capa_actions_r3106
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================================
-- SEED DATA — 12 calibration runs + 12 CAPA actions
-- =========================================================================
DO $seed$
DECLARE
  v_org uuid;
  v_eng uuid;
  v_run1 uuid; v_run2 uuid; v_run3 uuid; v_run4 uuid; v_run5 uuid; v_run6 uuid;
  v_run7 uuid; v_run8 uuid; v_run9 uuid; v_run10 uuid; v_run11 uuid; v_run12 uuid;
BEGIN
  SELECT id INTO v_org FROM public.organizations ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng FROM public.engineers     ORDER BY created_at LIMIT 1;

  IF v_org IS NULL OR v_eng IS NULL THEN
    RAISE NOTICE 'r3106 seed skipped — no org or engineer row available';
    RETURN;
  END IF;

  v_run1  := gen_random_uuid();
  v_run2  := gen_random_uuid();
  v_run3  := gen_random_uuid();
  v_run4  := gen_random_uuid();
  v_run5  := gen_random_uuid();
  v_run6  := gen_random_uuid();
  v_run7  := gen_random_uuid();
  v_run8  := gen_random_uuid();
  v_run9  := gen_random_uuid();
  v_run10 := gen_random_uuid();
  v_run11 := gen_random_uuid();
  v_run12 := gen_random_uuid();

  INSERT INTO public.ventilator_calibration_runs_r3106
    (id, hospital_org_id, engineer_id, asset_tag, ventilator_model, icu_bay, calibration_month,
     calibration_kind, set_tidal_volume_ml, delivered_tidal_volume_ml, tidal_deviation_pct,
     set_peep_cmh2o, delivered_peep_cmh2o, peep_deviation_cmh2o,
     set_fio2_pct, delivered_fio2_pct, fio2_deviation_pct,
     alarm_test_result, leak_test_ml_per_min, leak_verdict,
     overall_verdict, capa_required, next_due_date, notes)
  VALUES
    (v_run1,  v_org, v_eng, 'AIIMS-DEL-VENT-014', 'Draeger Evita V500',     'MICU-Bay-2',  '2026-06-01', 'monthly_routine',   500, 498.40,  -0.32, 5.0, 5.1, 0.10, 40, 40.10, 0.25, 'pass',               42.10, 'within_spec',  'pass',                       false, '2026-07-01', 'AIIMS Delhi — flagship unit'),
    (v_run2,  v_org, v_eng, 'APOLLO-HYD-VENT-007', 'Hamilton C6',           'SICU-Bay-4',  '2026-06-01', 'monthly_routine',   450, 437.20,  -2.84, 8.0, 7.6, -0.40, 60, 58.20, -3.00, 'pass',               68.30, 'marginal',     'pass_with_observation',      true,  '2026-07-01', 'Apollo Hyderabad — flow sensor drift trending'),
    (v_run3,  v_org, v_eng, 'FORTIS-MUM-VENT-022', 'Medtronic Puritan PB980','CTICU-Bay-1', '2026-06-02', 'quarterly_deep',    400, 388.00,  -3.00, 10.0, 9.5, -0.50, 50, 47.80, -4.40, 'fail_high_pressure', 110.50,'out_of_spec',  'fail_capa_required',         true,  '2026-06-09', 'Fortis Mumbai — high-pressure alarm failed at 40 cmH2O'),
    (v_run4,  v_org, v_eng, 'MANIPAL-BLR-VENT-031','GE Carescape R860',      'NICU-Bay-3',  '2026-06-03', 'post_repair',       350, 351.20,   0.34, 4.0, 4.0, 0.00, 35, 35.05, 0.14, 'pass',               18.40, 'within_spec',  'pass',                       false, '2026-07-03', 'Manipal Bangalore — post repair re-verify clean'),
    (v_run5,  v_org, v_eng, 'KIMS-HYD-VENT-019',   'Mindray SV800',          'MICU-Bay-6',  '2026-06-04', 'monthly_routine',   500, 472.50,  -5.50, 6.0, 5.4, -0.60, 45, 41.30, -8.22, 'fail_low_pressure',  145.20,'out_of_spec',  'fail_take_out_of_service',   true,  '2026-06-11', 'KIMS Hyderabad — taken out of ICU service, replacement deployed'),
    (v_run6,  v_org, v_eng, 'NARAYANA-BLR-VENT-008','Hamilton C3',           'PICU-Bay-2',  '2026-06-05', 'monthly_routine',   300, 297.60,  -0.80, 5.0, 5.0, 0.00, 40, 40.20, 0.50, 'pass',               24.10, 'within_spec',  'pass',                       false, '2026-07-05', 'Narayana — pediatric unit, all within spec'),
    (v_run7,  v_org, v_eng, 'CMC-VEL-VENT-041',    'Draeger Evita Infinity', 'MICU-Bay-1',  '2026-06-06', 'recall_response',   500, 461.00,  -7.80, 8.0, 7.2, -0.80, 55, 49.80, -9.45, 'fail_apnea',         165.80,'out_of_spec',  'fail_capa_required',         true,  '2026-06-13', 'CMC Vellore — Draeger recall notice followup'),
    (v_run8,  v_org, v_eng, 'TATA-MEM-VENT-016',   'Hamilton G5',            'CTICU-Bay-3', '2026-06-07', 'quarterly_deep',    600, 594.60,  -0.90, 12.0, 12.1, 0.10, 70, 70.15, 0.21, 'pass',               31.20, 'within_spec',  'pass',                       false, '2026-07-07', 'Tata Memorial — cardiac unit, flagship'),
    (v_run9,  v_org, v_eng, 'MAX-DEL-VENT-027',    'GE Carescape R860',      'SICU-Bay-2',  '2026-06-08', 'monthly_routine',   480, 462.72,  -3.60, 7.0, 6.5, -0.50, 50, 46.00, -8.00, 'fail_disconnect',    98.50, 'marginal',     'conditional_pass',           true,  '2026-06-22', 'Max Delhi — disconnect alarm intermittent, SOP retraining'),
    (v_run10, v_org, v_eng, 'STJOHN-BLR-VENT-012', 'Mindray SV600',          'MICU-Bay-5',  '2026-06-09', 'post_install',      500, 500.50,   0.10, 5.0, 5.0, 0.00, 40, 40.00, 0.00, 'pass',               12.80, 'within_spec',  'pass',                       false, '2026-07-09', 'St Johns Bangalore — new install commissioning'),
    (v_run11, v_org, v_eng, 'GLENEAGLES-CHN-VENT-005','Puritan Bennett 840', 'MICU-Bay-7',  '2026-06-10', 'monthly_routine',   500, 470.00,  -6.00, 8.0, 7.0, -1.00, 60, 53.40, -11.00, 'fail_power',        210.40,'catastrophic', 'fail_take_out_of_service',   true,  '2026-06-17', 'Gleneagles Chennai — power supply failed during alarm test'),
    (v_run12, v_org, v_eng, 'KOKILABEN-MUM-VENT-033','Hamilton C6',          'NICU-Bay-1',  '2026-06-11', 'monthly_routine',   320, 318.40,  -0.50, 4.0, 4.1, 0.10, 35, 35.20, 0.57, 'pass',               16.50, 'within_spec',  'pass',                       false, '2026-07-11', 'Kokilaben Mumbai — neonatal, within spec');

  -- CAPA actions linked to the failing/flagged runs
  INSERT INTO public.ventilator_capa_actions_r3106
    (calibration_run_id, hospital_org_id, capa_category, severity, raised_against, capa_status,
     due_within_hours, hours_to_close, cost_to_close_rupees, part_replaced_sku,
     patient_safety_event, reported_to_cdsco, closed_at, closure_evidence_url, notes)
  VALUES
    (v_run2,  v_org, 'flow_sensor_replace',     'p2_medium',   'biomed_team',  'in_progress',      72,  NULL,    8500,  'HAM-FS-C6-450',  false, false, NULL,                              NULL,                                              'Apollo Hyderabad — flow sensor swap scheduled'),
    (v_run3,  v_org, 'alarm_failure',           'p0_critical', 'manufacturer', 'awaiting_oem',     24,  NULL,   45000,  NULL,             true,  true,  NULL,                              NULL,                                              'Fortis Mumbai — Medtronic OEM dispatched field engineer'),
    (v_run3,  v_org, 'tidal_volume_drift',      'p1_high',     'vendor',       'open',             48,  NULL,   12000,  'MED-TV-PB980',   false, false, NULL,                              NULL,                                              'Fortis Mumbai — tidal drift 3% on quarterly'),
    (v_run5,  v_org, 'fio2_mix_drift',          'p0_critical', 'manufacturer', 'escalated_founder',12,  NULL,   62000,  'MIN-O2-SV800',   true,  true,  NULL,                              NULL,                                              'KIMS Hyderabad — taken out of service, founder escalation'),
    (v_run5,  v_org, 'leak_failure',            'p1_high',     'biomed_team',  'in_progress',      48,  NULL,    9500,  'MIN-EXV-SV800',  false, false, NULL,                              NULL,                                              'KIMS Hyderabad — expiratory valve cracked'),
    (v_run7,  v_org, 'calibration_recall',      'p0_critical', 'manufacturer', 'awaiting_oem',     24,  NULL,    0,     NULL,             true,  true,  NULL,                              NULL,                                              'CMC Vellore — Draeger global recall acknowledged'),
    (v_run7,  v_org, 'oxygen_sensor_replace',   'p1_high',     'procurement',  'awaiting_part',    72,  NULL,    7800,  'DRA-O2-EVI-INF', false, false, NULL,                              NULL,                                              'CMC Vellore — O2 cell on order'),
    (v_run9,  v_org, 'training_gap',            'p2_medium',   'icu_staff',    'in_progress',     168,  NULL,    0,     NULL,             false, false, NULL,                              NULL,                                              'Max Delhi — SOP retraining on disconnect alarm'),
    (v_run9,  v_org, 'sop_violation',           'p3_low',      'engineer',     'closed_verified', 168,   96.50,   0,    NULL,             false, false, '2026-06-12 09:15:00+05:30',       'https://docs.equipseva.app/capa/r3106-run9-sop.pdf','Max Delhi — engineer signed updated SOP'),
    (v_run11, v_org, 'expiratory_valve_service','p0_critical', 'vendor',       'blocked',          24,   NULL,   18500,  'PB840-EXP-VLV',  true,  true,  NULL,                              NULL,                                              'Gleneagles Chennai — vendor SLA breach, founder notified'),
    (v_run11, v_org, 'firmware_update',         'p2_medium',   'manufacturer', 'awaiting_oem',    240,   NULL,    0,    NULL,             false, false, NULL,                              NULL,                                              'Gleneagles Chennai — PB840 firmware patch pending OEM'),
    (v_run4,  v_org, 'training_gap',            'observation', 'biomed_team',  'closed_no_action',168,   24.00,   0,    NULL,             false, false, '2026-06-04 11:00:00+05:30',       'https://docs.equipseva.app/capa/r3106-run4-obs.pdf','Manipal Bangalore — post repair observation, no further action');

  RAISE NOTICE 'r3106 seed inserted: 12 calibration runs + 12 CAPA actions';
END
$seed$;

-- =========================================================================
-- RPC 1 — Monthly verdict rollup
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_monthly_verdict_rollup()
RETURNS TABLE (
  calibration_month date,
  total_runs        bigint,
  passed            bigint,
  with_observation  bigint,
  conditional       bigint,
  out_of_service    bigint,
  capa_required     bigint,
  pass_rate_pct     numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.calibration_month,
    count(*)::bigint AS total_runs,
    count(*) FILTER (WHERE v.overall_verdict = 'pass')::bigint,
    count(*) FILTER (WHERE v.overall_verdict = 'pass_with_observation')::bigint,
    count(*) FILTER (WHERE v.overall_verdict = 'conditional_pass')::bigint,
    count(*) FILTER (WHERE v.overall_verdict = 'fail_take_out_of_service')::bigint,
    count(*) FILTER (WHERE v.overall_verdict = 'fail_capa_required')::bigint,
    round(100.0 * count(*) FILTER (WHERE v.overall_verdict = 'pass') / NULLIF(count(*),0), 2) AS pass_rate_pct
  FROM public.ventilator_calibration_runs_r3106 v
  GROUP BY v.calibration_month
  ORDER BY v.calibration_month DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_monthly_verdict_rollup() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_monthly_verdict_rollup() TO authenticated;

-- =========================================================================
-- RPC 2 — Tidal volume deviation hotlist
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_tidal_deviation_hotlist()
RETURNS TABLE (
  asset_tag                 text,
  ventilator_model          text,
  icu_bay                   text,
  set_tidal_volume_ml       integer,
  delivered_tidal_volume_ml numeric,
  tidal_deviation_pct       numeric,
  overall_verdict           text,
  next_due_date             date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.asset_tag, v.ventilator_model, v.icu_bay,
         v.set_tidal_volume_ml, v.delivered_tidal_volume_ml, v.tidal_deviation_pct,
         v.overall_verdict, v.next_due_date
  FROM public.ventilator_calibration_runs_r3106 v
  WHERE abs(v.tidal_deviation_pct) >= 2.0
  ORDER BY abs(v.tidal_deviation_pct) DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_tidal_deviation_hotlist() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_tidal_deviation_hotlist() TO authenticated;

-- =========================================================================
-- RPC 3 — PEEP accuracy distribution
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_peep_accuracy_distribution()
RETURNS TABLE (
  band             text,
  unit_count       bigint,
  avg_deviation    numeric,
  worst_deviation  numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN abs(v.peep_deviation_cmh2o) < 0.25 THEN 'A. within 0.25 cmH2O'
      WHEN abs(v.peep_deviation_cmh2o) < 0.50 THEN 'B. 0.25 - 0.50 cmH2O'
      WHEN abs(v.peep_deviation_cmh2o) < 1.00 THEN 'C. 0.50 - 1.00 cmH2O'
      ELSE                                          'D. over 1.00 cmH2O'
    END AS band,
    count(*)::bigint AS unit_count,
    round(avg(abs(v.peep_deviation_cmh2o))::numeric, 3) AS avg_deviation,
    round(max(abs(v.peep_deviation_cmh2o))::numeric, 3) AS worst_deviation
  FROM public.ventilator_calibration_runs_r3106 v
  GROUP BY 1
  ORDER BY 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_peep_accuracy_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_peep_accuracy_distribution() TO authenticated;

-- =========================================================================
-- RPC 4 — FiO2 mix accuracy by model
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_fio2_accuracy_by_model()
RETURNS TABLE (
  ventilator_model    text,
  units_tested        bigint,
  avg_fio2_deviation  numeric,
  worst_fio2_dev      numeric,
  failing_units       bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.ventilator_model,
    count(*)::bigint,
    round(avg(abs(v.fio2_deviation_pct))::numeric, 2),
    round(max(abs(v.fio2_deviation_pct))::numeric, 2),
    count(*) FILTER (WHERE abs(v.fio2_deviation_pct) > 5.0)::bigint
  FROM public.ventilator_calibration_runs_r3106 v
  GROUP BY v.ventilator_model
  ORDER BY worst_fio2_dev DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_fio2_accuracy_by_model() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_fio2_accuracy_by_model() TO authenticated;

-- =========================================================================
-- RPC 5 — Alarm + leak failure breakdown
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_alarm_leak_failure_breakdown()
RETURNS TABLE (
  alarm_test_result text,
  leak_verdict      text,
  unit_count        bigint,
  avg_leak_ml_min   numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.alarm_test_result, v.leak_verdict,
         count(*)::bigint,
         round(avg(v.leak_test_ml_per_min)::numeric, 2)
  FROM public.ventilator_calibration_runs_r3106 v
  GROUP BY v.alarm_test_result, v.leak_verdict
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_alarm_leak_failure_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_alarm_leak_failure_breakdown() TO authenticated;

-- =========================================================================
-- RPC 6 — Open CAPA queue
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_open_capa_queue()
RETURNS TABLE (
  capa_id              uuid,
  asset_tag            text,
  capa_category        text,
  severity             text,
  raised_against       text,
  capa_status          text,
  due_within_hours     integer,
  patient_safety_event boolean,
  cost_to_close_rupees integer,
  notes                text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, v.asset_tag, c.capa_category, c.severity, c.raised_against,
         c.capa_status, c.due_within_hours, c.patient_safety_event,
         c.cost_to_close_rupees, c.notes
  FROM public.ventilator_capa_actions_r3106 c
  JOIN public.ventilator_calibration_runs_r3106 v ON v.id = c.calibration_run_id
  WHERE c.capa_status NOT IN ('closed_verified','closed_no_action')
  ORDER BY
    CASE c.severity
      WHEN 'p0_critical' THEN 0
      WHEN 'p1_high'     THEN 1
      WHEN 'p2_medium'   THEN 2
      WHEN 'p3_low'      THEN 3
      ELSE 4
    END,
    c.due_within_hours ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_open_capa_queue() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_open_capa_queue() TO authenticated;

-- =========================================================================
-- RPC 7 — CAPA category leaderboard
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_capa_category_leaderboard()
RETURNS TABLE (
  capa_category        text,
  total_capas          bigint,
  open_capas           bigint,
  patient_safety_evts  bigint,
  total_cost_rupees    bigint,
  avg_hours_to_close   numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.capa_category,
    count(*)::bigint,
    count(*) FILTER (WHERE c.capa_status NOT IN ('closed_verified','closed_no_action'))::bigint,
    count(*) FILTER (WHERE c.patient_safety_event)::bigint,
    coalesce(sum(c.cost_to_close_rupees),0)::bigint,
    round(avg(c.hours_to_close)::numeric, 2)
  FROM public.ventilator_capa_actions_r3106 c
  GROUP BY c.capa_category
  ORDER BY count(*) DESC, total_cost_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_capa_category_leaderboard() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_capa_category_leaderboard() TO authenticated;

-- =========================================================================
-- RPC 8 — CDSCO reportable events
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_cdsco_reportable_events()
RETURNS TABLE (
  asset_tag             text,
  ventilator_model      text,
  capa_category         text,
  severity              text,
  reported_to_cdsco     boolean,
  patient_safety_event  boolean,
  capa_status           text,
  notes                 text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.asset_tag, v.ventilator_model, c.capa_category, c.severity,
         c.reported_to_cdsco, c.patient_safety_event, c.capa_status, c.notes
  FROM public.ventilator_capa_actions_r3106 c
  JOIN public.ventilator_calibration_runs_r3106 v ON v.id = c.calibration_run_id
  WHERE c.patient_safety_event OR c.reported_to_cdsco
  ORDER BY c.severity, v.asset_tag;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_cdsco_reportable_events() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_cdsco_reportable_events() TO authenticated;

-- =========================================================================
-- RPC 9 — Next-due calibration schedule
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r3106_next_due_calibration_schedule()
RETURNS TABLE (
  asset_tag         text,
  ventilator_model  text,
  icu_bay           text,
  overall_verdict   text,
  next_due_date     date,
  days_until_due    integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.asset_tag, v.ventilator_model, v.icu_bay, v.overall_verdict, v.next_due_date,
         (v.next_due_date - current_date)::integer AS days_until_due
  FROM public.ventilator_calibration_runs_r3106 v
  ORDER BY v.next_due_date ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r3106_next_due_calibration_schedule() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r3106_next_due_calibration_schedule() TO authenticated;

COMMIT;
