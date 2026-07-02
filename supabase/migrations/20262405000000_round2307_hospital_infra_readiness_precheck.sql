BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_infra_precheck_r2307 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  hospital_name text NOT NULL,
  amc_contract_id uuid,
  assessor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  assessor_email text,
  power_score int NOT NULL DEFAULT 0 CHECK (power_score BETWEEN 0 AND 100),
  network_score int NOT NULL DEFAULT 0 CHECK (network_score BETWEEN 0 AND 100),
  ac_score int NOT NULL DEFAULT 0 CHECK (ac_score BETWEEN 0 AND 100),
  calibration_score int NOT NULL DEFAULT 0 CHECK (calibration_score BETWEEN 0 AND 100),
  overall_score int NOT NULL DEFAULT 0 CHECK (overall_score BETWEEN 0 AND 100),
  readiness_status text NOT NULL DEFAULT 'pending' CHECK (readiness_status IN ('pending','assessing','ready','blocked','remediated')),
  power_notes text,
  network_notes text,
  ac_notes text,
  calibration_notes text,
  scheduled_amc_start_date date,
  assessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_infra_gap_log_r2307 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  precheck_id uuid NOT NULL REFERENCES public.hospital_infra_precheck_r2307(id) ON DELETE CASCADE,
  gap_category text NOT NULL CHECK (gap_category IN ('power','network','ac','calibration','safety','space','other')),
  severity text NOT NULL CHECK (severity IN ('blocker','major','minor','info')),
  description text NOT NULL,
  remediation_owner text,
  due_date date,
  resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  resolved_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

ALTER TABLE public.hospital_infra_precheck_r2307 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_infra_gap_log_r2307 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_infra_precheck_r2307;
CREATE POLICY founder_all ON public.hospital_infra_precheck_r2307 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_infra_gap_log_r2307;
CREATE POLICY founder_all ON public.hospital_infra_gap_log_r2307 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_precheck_status_r2307 ON public.hospital_infra_precheck_r2307(readiness_status, scheduled_amc_start_date);
CREATE INDEX IF NOT EXISTS idx_precheck_hospital_r2307 ON public.hospital_infra_precheck_r2307(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_gap_precheck_r2307 ON public.hospital_infra_gap_log_r2307(precheck_id, resolved);
CREATE INDEX IF NOT EXISTS idx_gap_severity_r2307 ON public.hospital_infra_gap_log_r2307(severity, resolved);

-- RPC 1: Summary stats
CREATE OR REPLACE FUNCTION public.fn_r2307_precheck_summary()
RETURNS TABLE(total int, pending int, assessing int, ready int, blocked int, remediated int, avg_overall_score numeric, open_blockers int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE readiness_status='pending')::int,
    COUNT(*) FILTER (WHERE readiness_status='assessing')::int,
    COUNT(*) FILTER (WHERE readiness_status='ready')::int,
    COUNT(*) FILTER (WHERE readiness_status='blocked')::int,
    COUNT(*) FILTER (WHERE readiness_status='remediated')::int,
    COALESCE(ROUND(AVG(overall_score)::numeric, 1), 0),
    (SELECT COUNT(*)::int FROM public.hospital_infra_gap_log_r2307 WHERE severity='blocker' AND resolved=false)
  FROM public.hospital_infra_precheck_r2307;
END $$;

-- RPC 2: List prechecks
CREATE OR REPLACE FUNCTION public.fn_r2307_list_prechecks(p_status text DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, hospital_name text, readiness_status text, overall_score int, power_score int, network_score int, ac_score int, calibration_score int, scheduled_amc_start_date date, assessor_email text, open_gaps int, blocker_gaps int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.hospital_name, p.readiness_status, p.overall_score,
    p.power_score, p.network_score, p.ac_score, p.calibration_score,
    p.scheduled_amc_start_date, p.assessor_email,
    (SELECT COUNT(*)::int FROM public.hospital_infra_gap_log_r2307 g WHERE g.precheck_id=p.id AND g.resolved=false),
    (SELECT COUNT(*)::int FROM public.hospital_infra_gap_log_r2307 g WHERE g.precheck_id=p.id AND g.resolved=false AND g.severity='blocker')
  FROM public.hospital_infra_precheck_r2307 p
  WHERE (p_status IS NULL OR p.readiness_status = p_status)
  ORDER BY
    CASE p.readiness_status WHEN 'blocked' THEN 1 WHEN 'assessing' THEN 2 WHEN 'pending' THEN 3 WHEN 'remediated' THEN 4 WHEN 'ready' THEN 5 END,
    p.scheduled_amc_start_date NULLS LAST
  LIMIT p_limit;
END $$;

-- RPC 3: Gaps for precheck
CREATE OR REPLACE FUNCTION public.fn_r2307_list_gaps(p_precheck_id uuid)
RETURNS TABLE(id uuid, gap_category text, severity text, description text, remediation_owner text, due_date date, resolved boolean, resolved_at timestamptz, days_open int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.gap_category, g.severity, g.description, g.remediation_owner, g.due_date, g.resolved, g.resolved_at,
    EXTRACT(DAY FROM (COALESCE(g.resolved_at, now()) - g.created_at))::int
  FROM public.hospital_infra_gap_log_r2307 g
  WHERE g.precheck_id = p_precheck_id
  ORDER BY g.resolved ASC,
    CASE g.severity WHEN 'blocker' THEN 1 WHEN 'major' THEN 2 WHEN 'minor' THEN 3 WHEN 'info' THEN 4 END,
    g.created_at DESC;
END $$;

-- RPC 4: Create precheck
CREATE OR REPLACE FUNCTION public.fn_r2307_create_precheck(p_hospital_org_id uuid, p_hospital_name text, p_amc_contract_id uuid, p_scheduled_start date)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_assessor uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  SELECT id INTO v_assessor FROM public.profiles WHERE email = v_email LIMIT 1;
  INSERT INTO public.hospital_infra_precheck_r2307(hospital_org_id, hospital_name, amc_contract_id, assessor_id, assessor_email, scheduled_amc_start_date, readiness_status)
  VALUES (p_hospital_org_id, p_hospital_name, p_amc_contract_id, v_assessor, v_email, p_scheduled_start, 'pending')
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- RPC 5: Score precheck
CREATE OR REPLACE FUNCTION public.fn_r2307_score_precheck(p_id uuid, p_power int, p_network int, p_ac int, p_calibration int, p_power_notes text, p_network_notes text, p_ac_notes text, p_calibration_notes text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_overall int; v_status text; v_blockers int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_overall := ROUND((p_power + p_network + p_ac + p_calibration) / 4.0)::int;
  SELECT COUNT(*)::int INTO v_blockers FROM public.hospital_infra_gap_log_r2307 WHERE precheck_id = p_id AND severity = 'blocker' AND resolved = false;
  IF v_blockers > 0 THEN v_status := 'blocked';
  ELSIF v_overall >= 80 THEN v_status := 'ready';
  ELSE v_status := 'assessing';
  END IF;
  UPDATE public.hospital_infra_precheck_r2307
  SET power_score = p_power, network_score = p_network, ac_score = p_ac, calibration_score = p_calibration,
      power_notes = p_power_notes, network_notes = p_network_notes, ac_notes = p_ac_notes, calibration_notes = p_calibration_notes,
      overall_score = v_overall, readiness_status = v_status, assessed_at = now(), updated_at = now()
  WHERE id = p_id;
END $$;

-- RPC 6: Log gap
CREATE OR REPLACE FUNCTION public.fn_r2307_log_gap(p_precheck_id uuid, p_category text, p_severity text, p_description text, p_owner text, p_due_date date)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_creator uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_creator FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.hospital_infra_gap_log_r2307(precheck_id, gap_category, severity, description, remediation_owner, due_date, created_by)
  VALUES (p_precheck_id, p_category, p_severity, p_description, p_owner, p_due_date, v_creator)
  RETURNING id INTO v_id;
  IF p_severity = 'blocker' THEN
    UPDATE public.hospital_infra_precheck_r2307 SET readiness_status = 'blocked', updated_at = now() WHERE id = p_precheck_id;
  END IF;
  RETURN v_id;
END $$;

-- RPC 7: Resolve gap
CREATE OR REPLACE FUNCTION public.fn_r2307_resolve_gap(p_gap_id uuid, p_note text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_precheck uuid; v_remaining_blockers int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_infra_gap_log_r2307
  SET resolved = true, resolved_at = now(), resolved_note = p_note
  WHERE id = p_gap_id
  RETURNING precheck_id INTO v_precheck;
  SELECT COUNT(*)::int INTO v_remaining_blockers FROM public.hospital_infra_gap_log_r2307 WHERE precheck_id = v_precheck AND severity = 'blocker' AND resolved = false;
  IF v_remaining_blockers = 0 THEN
    UPDATE public.hospital_infra_precheck_r2307 SET readiness_status = 'remediated', updated_at = now() WHERE id = v_precheck AND readiness_status = 'blocked';
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.fn_r2307_precheck_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2307_list_prechecks(text, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2307_list_gaps(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2307_create_precheck(uuid, text, uuid, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2307_score_precheck(uuid, int, int, int, int, text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2307_log_gap(uuid, text, text, text, text, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_r2307_resolve_gap(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fn_r2307_precheck_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2307_list_prechecks(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2307_list_gaps(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2307_create_precheck(uuid, text, uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2307_score_precheck(uuid, int, int, int, int, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2307_log_gap(uuid, text, text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_r2307_resolve_gap(uuid, text) TO authenticated;

COMMIT;
