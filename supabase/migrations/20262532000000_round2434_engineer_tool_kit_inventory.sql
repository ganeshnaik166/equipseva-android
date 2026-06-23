-- Round 2434: Engineer Tool Kit Inventory
-- Per-engineer tool kit x condition x last calibrated x next calibration due x missing items x replacement cost

BEGIN;

-- ============================================================================
-- TABLE 1: engineer_tool_inventory_r2434
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_tool_inventory_r2434 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  tool_name text NOT NULL,
  tool_kind text NOT NULL CHECK (tool_kind IN ('multimeter','calibration','scope','hand_tool','safety_gear','specialty_imaging','specialty_anesthesia')),
  serial_no text,
  condition text NOT NULL CHECK (condition IN ('new','good','fair','worn','broken','missing')),
  last_used_at timestamptz,
  last_calibrated_at timestamptz,
  next_calibration_due_at timestamptz,
  calibration_authority text,
  replacement_cost_rupees int NOT NULL DEFAULT 0 CHECK (replacement_cost_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_tool_inv_r2434_eng ON public.engineer_tool_inventory_r2434(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_tool_inv_r2434_kind ON public.engineer_tool_inventory_r2434(tool_kind);
CREATE INDEX IF NOT EXISTS idx_eng_tool_inv_r2434_cond ON public.engineer_tool_inventory_r2434(condition);
CREATE INDEX IF NOT EXISTS idx_eng_tool_inv_r2434_due ON public.engineer_tool_inventory_r2434(next_calibration_due_at);

ALTER TABLE public.engineer_tool_inventory_r2434 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_tool_inventory_r2434;
CREATE POLICY founder_all ON public.engineer_tool_inventory_r2434
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: tool_kit_audits_r2434
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.tool_kit_audits_r2434 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  audit_date date NOT NULL,
  total_tools int NOT NULL DEFAULT 0 CHECK (total_tools >= 0),
  missing_tools int NOT NULL DEFAULT 0 CHECK (missing_tools >= 0),
  broken_tools int NOT NULL DEFAULT 0 CHECK (broken_tools >= 0),
  expired_calibration int NOT NULL DEFAULT 0 CHECK (expired_calibration >= 0),
  audit_status text NOT NULL CHECK (audit_status IN ('pending','in_progress','complete','escalated')),
  corrective_action text,
  owner_email text,
  closed_at timestamptz,
  closed_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tool_audits_r2434_eng ON public.tool_kit_audits_r2434(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_tool_audits_r2434_date ON public.tool_kit_audits_r2434(audit_date);
CREATE INDEX IF NOT EXISTS idx_tool_audits_r2434_status ON public.tool_kit_audits_r2434(audit_status);

ALTER TABLE public.tool_kit_audits_r2434 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.tool_kit_audits_r2434;
CREATE POLICY founder_all ON public.tool_kit_audits_r2434
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_eng4 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at OFFSET 2 LIMIT 1;
  SELECT id INTO v_eng4 FROM public.engineers ORDER BY created_at OFFSET 3 LIMIT 1;

  IF v_eng1 IS NULL THEN RETURN; END IF;
  IF v_eng2 IS NULL THEN v_eng2 := v_eng1; END IF;
  IF v_eng3 IS NULL THEN v_eng3 := v_eng1; END IF;
  IF v_eng4 IS NULL THEN v_eng4 := v_eng1; END IF;

  INSERT INTO public.engineer_tool_inventory_r2434
    (engineer_user_id, tool_name, tool_kind, serial_no, condition, last_used_at, last_calibrated_at, next_calibration_due_at, calibration_authority, replacement_cost_rupees, notes)
  VALUES
    (v_eng1, 'Fluke 87V Multimeter', 'multimeter', 'FK87V-1029', 'good', now() - interval '2 days', now() - interval '180 days', now() + interval '180 days', 'NABL Hyderabad', 45000, 'Primary diagnostic tool'),
    (v_eng1, 'Tektronix TBS1052B Scope', 'scope', 'TBS-9911', 'fair', now() - interval '14 days', now() - interval '400 days', now() - interval '35 days', 'NABL Bangalore', 120000, 'Calibration expired — flag'),
    (v_eng2, 'Pressure Calibrator Beamex', 'calibration', 'BMX-77G', 'good', now() - interval '5 days', now() - interval '90 days', now() + interval '270 days', 'NABL Pune', 380000, NULL),
    (v_eng2, 'X-Ray kVp Meter', 'specialty_imaging', 'XKV-441', 'worn', now() - interval '21 days', now() - interval '200 days', now() + interval '160 days', 'AERB Mumbai', 250000, 'Battery worn, schedule replacement'),
    (v_eng3, 'Anesthesia Flow Analyzer', 'specialty_anesthesia', 'AFA-2202', 'broken', now() - interval '60 days', now() - interval '500 days', now() - interval '135 days', 'Fluke Biomedical', 410000, 'Sensor failure, sent for repair'),
    (v_eng3, 'Insulated Screwdriver Set', 'hand_tool', NULL, 'good', now() - interval '1 day', NULL, NULL, NULL, 4500, NULL),
    (v_eng4, 'Arc Flash PPE Kit', 'safety_gear', 'PPE-AF-09', 'missing', now() - interval '90 days', NULL, NULL, NULL, 32000, 'Lost at site — replace urgently'),
    (v_eng4, 'Defibrillator Analyzer', 'specialty_anesthesia', 'DA-8810', 'new', now() - interval '7 days', now() - interval '30 days', now() + interval '335 days', 'NABL Hyderabad', 290000, 'New unit, just deployed');

  INSERT INTO public.tool_kit_audits_r2434
    (engineer_user_id, audit_date, total_tools, missing_tools, broken_tools, expired_calibration, audit_status, corrective_action, owner_email, closed_at, closed_by_email, notes)
  VALUES
    (v_eng1, current_date - 3, 12, 0, 0, 1, 'in_progress', 'Renew scope calibration this week', 'ops@equipseva.in', NULL, NULL, 'Scope calibration overdue'),
    (v_eng2, current_date - 14, 9, 0, 0, 0, 'complete', 'No action — all green', 'ops@equipseva.in', now() - interval '13 days', 'ops@equipseva.in', NULL),
    (v_eng3, current_date - 7, 11, 0, 1, 1, 'escalated', 'Anesthesia analyzer at vendor; loaner requested', 'founder@equipseva.in', NULL, NULL, 'Specialty tool down — revenue risk'),
    (v_eng4, current_date - 1, 14, 1, 0, 0, 'pending', 'Missing PPE kit reorder + serial verification', 'ops@equipseva.in', NULL, NULL, 'Audit just opened'),
    (v_eng1, current_date - 30, 12, 0, 0, 0, 'complete', 'All clear', 'ops@equipseva.in', now() - interval '29 days', 'ops@equipseva.in', NULL);
END
$seed$;

-- ============================================================================
-- RPC 1: list_inventory_r2434
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_inventory_r2434()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_label text,
  tool_name text,
  tool_kind text,
  serial_no text,
  condition text,
  last_used_at timestamptz,
  last_calibrated_at timestamptz,
  next_calibration_due_at timestamptz,
  calibration_authority text,
  replacement_cost_rupees int,
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
  SELECT
    t.id,
    t.engineer_user_id,
    COALESCE(left(t.engineer_user_id::text, 8), 'eng') AS engineer_label,
    t.tool_name,
    t.tool_kind,
    t.serial_no,
    t.condition,
    t.last_used_at,
    t.last_calibrated_at,
    t.next_calibration_due_at,
    t.calibration_authority,
    t.replacement_cost_rupees,
    t.notes,
    t.created_at
  FROM public.engineer_tool_inventory_r2434 t
  ORDER BY
    CASE t.condition WHEN 'missing' THEN 0 WHEN 'broken' THEN 1 WHEN 'worn' THEN 2 WHEN 'fair' THEN 3 ELSE 4 END,
    t.next_calibration_due_at NULLS LAST,
    t.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_inventory_r2434() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_inventory_r2434() TO authenticated;

-- ============================================================================
-- RPC 2: list_audits_r2434
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_audits_r2434()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_label text,
  audit_date date,
  total_tools int,
  missing_tools int,
  broken_tools int,
  expired_calibration int,
  audit_status text,
  corrective_action text,
  owner_email text,
  closed_at timestamptz,
  closed_by_email text,
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
  SELECT
    a.id,
    a.engineer_user_id,
    COALESCE(left(a.engineer_user_id::text, 8), 'eng') AS engineer_label,
    a.audit_date,
    a.total_tools,
    a.missing_tools,
    a.broken_tools,
    a.expired_calibration,
    a.audit_status,
    a.corrective_action,
    a.owner_email,
    a.closed_at,
    a.closed_by_email,
    a.notes,
    a.created_at
  FROM public.tool_kit_audits_r2434 a
  ORDER BY a.audit_date DESC, a.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_audits_r2434() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_audits_r2434() TO authenticated;

-- ============================================================================
-- RPC 3: top_replacement_cost_engineers_r2434
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_replacement_cost_engineers_r2434()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_label text,
  tool_count bigint,
  total_replacement_cost_rupees bigint,
  broken_or_missing bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.engineer_user_id,
    COALESCE(left(t.engineer_user_id::text, 8), 'eng') AS engineer_label,
    COUNT(*)::bigint AS tool_count,
    SUM(t.replacement_cost_rupees)::bigint AS total_replacement_cost_rupees,
    SUM(CASE WHEN t.condition IN ('broken','missing') THEN 1 ELSE 0 END)::bigint AS broken_or_missing
  FROM public.engineer_tool_inventory_r2434 t
  GROUP BY t.engineer_user_id
  ORDER BY total_replacement_cost_rupees DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_replacement_cost_engineers_r2434() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_replacement_cost_engineers_r2434() TO authenticated;

-- ============================================================================
-- RPC 4: expired_calibration_focus_r2434
-- ============================================================================
CREATE OR REPLACE FUNCTION public.expired_calibration_focus_r2434()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_label text,
  tool_name text,
  tool_kind text,
  next_calibration_due_at timestamptz,
  days_overdue int,
  calibration_authority text,
  replacement_cost_rupees int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.engineer_user_id,
    COALESCE(left(t.engineer_user_id::text, 8), 'eng') AS engineer_label,
    t.tool_name,
    t.tool_kind,
    t.next_calibration_due_at,
    GREATEST(0, EXTRACT(day FROM (now() - t.next_calibration_due_at))::int) AS days_overdue,
    t.calibration_authority,
    t.replacement_cost_rupees
  FROM public.engineer_tool_inventory_r2434 t
  WHERE t.next_calibration_due_at IS NOT NULL
    AND t.next_calibration_due_at < now()
  ORDER BY t.next_calibration_due_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.expired_calibration_focus_r2434() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expired_calibration_focus_r2434() TO authenticated;

-- ============================================================================
-- RPC 5: missing_breakdown_r2434
-- ============================================================================
CREATE OR REPLACE FUNCTION public.missing_breakdown_r2434()
RETURNS TABLE (
  tool_kind text,
  total_tools bigint,
  missing_count bigint,
  broken_count bigint,
  worn_count bigint,
  total_replacement_cost_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.tool_kind,
    COUNT(*)::bigint AS total_tools,
    SUM(CASE WHEN t.condition = 'missing' THEN 1 ELSE 0 END)::bigint AS missing_count,
    SUM(CASE WHEN t.condition = 'broken' THEN 1 ELSE 0 END)::bigint AS broken_count,
    SUM(CASE WHEN t.condition = 'worn' THEN 1 ELSE 0 END)::bigint AS worn_count,
    SUM(CASE WHEN t.condition IN ('missing','broken') THEN t.replacement_cost_rupees ELSE 0 END)::bigint AS total_replacement_cost_rupees
  FROM public.engineer_tool_inventory_r2434 t
  GROUP BY t.tool_kind
  ORDER BY missing_count DESC, broken_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.missing_breakdown_r2434() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.missing_breakdown_r2434() TO authenticated;

-- ============================================================================
-- RPC 6: audit_status_summary_r2434
-- ============================================================================
CREATE OR REPLACE FUNCTION public.audit_status_summary_r2434()
RETURNS TABLE (
  audit_status text,
  audit_count bigint,
  total_missing bigint,
  total_broken bigint,
  total_expired_calibration bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.audit_status,
    COUNT(*)::bigint AS audit_count,
    SUM(a.missing_tools)::bigint AS total_missing,
    SUM(a.broken_tools)::bigint AS total_broken,
    SUM(a.expired_calibration)::bigint AS total_expired_calibration
  FROM public.tool_kit_audits_r2434 a
  GROUP BY a.audit_status
  ORDER BY audit_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.audit_status_summary_r2434() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audit_status_summary_r2434() TO authenticated;

-- ============================================================================
-- RPC 7: weekly_audit_trend_r2434
-- ============================================================================
CREATE OR REPLACE FUNCTION public.weekly_audit_trend_r2434()
RETURNS TABLE (
  week_start date,
  audit_count bigint,
  closed_count bigint,
  escalated_count bigint,
  total_missing bigint,
  total_broken bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', a.audit_date)::date AS week_start,
    COUNT(*)::bigint AS audit_count,
    SUM(CASE WHEN a.audit_status = 'complete' THEN 1 ELSE 0 END)::bigint AS closed_count,
    SUM(CASE WHEN a.audit_status = 'escalated' THEN 1 ELSE 0 END)::bigint AS escalated_count,
    SUM(a.missing_tools)::bigint AS total_missing,
    SUM(a.broken_tools)::bigint AS total_broken
  FROM public.tool_kit_audits_r2434 a
  WHERE a.audit_date >= current_date - interval '90 days'
  GROUP BY date_trunc('week', a.audit_date)
  ORDER BY week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_audit_trend_r2434() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_audit_trend_r2434() TO authenticated;

