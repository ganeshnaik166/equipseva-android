BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_equipment_failure_modes_r2055 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','lab','monitor','ventilator','anesthesia','other')),
  failure_mode_label text NOT NULL,
  root_cause_category text NOT NULL CHECK (root_cause_category IN ('operator_error','maintenance_missed','material_defect','environmental','age','firmware')),
  frequency_score int NOT NULL CHECK (frequency_score BETWEEN 1 AND 10),
  severity_score int NOT NULL CHECK (severity_score BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_failure_response_protocol_r2055 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  failure_id uuid NOT NULL REFERENCES public.hospital_equipment_failure_modes_r2055(id) ON DELETE CASCADE,
  protocol_md text NOT NULL,
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_equipment_failure_modes_r2055 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_failure_response_protocol_r2055 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_failures_r2055 ON public.hospital_equipment_failure_modes_r2055;
CREATE POLICY founder_all_failures_r2055 ON public.hospital_equipment_failure_modes_r2055
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_protocols_r2055 ON public.hospital_failure_response_protocol_r2055;
CREATE POLICY founder_all_protocols_r2055 ON public.hospital_failure_response_protocol_r2055
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_failures_r2055()
RETURNS TABLE(id uuid, equipment_category text, failure_mode_label text, root_cause_category text, frequency_score int, severity_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.equipment_category, f.failure_mode_label, f.root_cause_category, f.frequency_score, f.severity_score, f.status, f.captured_at
    FROM public.hospital_equipment_failure_modes_r2055 f
    ORDER BY f.captured_at DESC
    LIMIT 200;
END;$$;

CREATE OR REPLACE FUNCTION public.log_failure_r2055(p_category text, p_label text, p_root_cause text, p_freq int, p_sev int)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_equipment_failure_modes_r2055(equipment_category, failure_mode_label, root_cause_category, frequency_score, severity_score)
    VALUES (p_category, p_label, p_root_cause, p_freq, p_sev)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_failure_r2055', jsonb_build_object('id', v_id, 'category', p_category, 'label', p_label));
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.list_protocols_r2055()
RETURNS TABLE(id uuid, failure_id uuid, failure_mode_label text, protocol_md text, last_updated_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.failure_id, f.failure_mode_label, p.protocol_md, p.last_updated_at, p.by_email
    FROM public.hospital_failure_response_protocol_r2055 p
    LEFT JOIN public.hospital_equipment_failure_modes_r2055 f ON f.id = p.failure_id
    ORDER BY p.last_updated_at DESC
    LIMIT 200;
END;$$;

CREATE OR REPLACE FUNCTION public.log_protocol_r2055(p_failure_id uuid, p_protocol_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := COALESCE((auth.jwt()->>'email'), 'system');
  INSERT INTO public.hospital_failure_response_protocol_r2055(failure_id, protocol_md, by_email)
    VALUES (p_failure_id, p_protocol_md, v_email)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'log_protocol_r2055', jsonb_build_object('id', v_id, 'failure_id', p_failure_id));
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2055(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_equipment_failure_modes_r2055
     SET status = p_status, updated_at = now()
   WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2055', jsonb_build_object('id', p_id, 'status', p_status));
END;$$;

CREATE OR REPLACE FUNCTION public.top_failure_modes_r2055()
RETURNS TABLE(equipment_category text, failure_count bigint, avg_frequency numeric, avg_severity numeric, max_risk numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.equipment_category,
           COUNT(*)::bigint AS failure_count,
           ROUND(AVG(f.frequency_score)::numeric, 2) AS avg_frequency,
           ROUND(AVG(f.severity_score)::numeric, 2) AS avg_severity,
           MAX(f.frequency_score * f.severity_score)::numeric AS max_risk
    FROM public.hospital_equipment_failure_modes_r2055 f
    WHERE f.status = 'active'
    GROUP BY f.equipment_category
    ORDER BY failure_count DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.recent_protocols_r2055()
RETURNS TABLE(id uuid, failure_mode_label text, by_email text, last_updated_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, f.failure_mode_label, p.by_email, p.last_updated_at
    FROM public.hospital_failure_response_protocol_r2055 p
    LEFT JOIN public.hospital_equipment_failure_modes_r2055 f ON f.id = p.failure_id
    ORDER BY p.last_updated_at DESC
    LIMIT 50;
END;$$;

REVOKE EXECUTE ON FUNCTION public.list_failures_r2055() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_failure_r2055(text, text, text, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_protocols_r2055() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_protocol_r2055(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2055(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_failure_modes_r2055() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_protocols_r2055() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_failures_r2055() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_failure_r2055(text, text, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_protocols_r2055() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_protocol_r2055(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2055(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_failure_modes_r2055() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_protocols_r2055() TO authenticated;

COMMIT;
