BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_handovers_r2408 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_model text NOT NULL,
  serial_no text,
  site_label text,
  shift_label text NOT NULL CHECK (shift_label IN ('morning','afternoon','night','custom')),
  handover_started_at timestamptz NOT NULL DEFAULT now(),
  handover_completed_at timestamptz,
  exterior_clean boolean NOT NULL DEFAULT false,
  interior_clean boolean NOT NULL DEFAULT false,
  consumables_restocked boolean NOT NULL DEFAULT false,
  cables_organized boolean NOT NULL DEFAULT false,
  calibration_verified boolean NOT NULL DEFAULT false,
  logs_signed boolean NOT NULL DEFAULT false,
  hazards_cleared boolean NOT NULL DEFAULT false,
  total_checks int NOT NULL DEFAULT 7,
  passed_checks int NOT NULL DEFAULT 0,
  overall_status text NOT NULL DEFAULT 'pending' CHECK (overall_status IN ('pending','passed','failed','disputed')),
  customer_signoff_at timestamptz,
  customer_satisfaction int CHECK (customer_satisfaction BETWEEN 1 AND 5 OR customer_satisfaction IS NULL),
  customer_comment text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_handover_events_r2408 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handover_id uuid NOT NULL REFERENCES public.founder_handovers_r2408(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('started','checklist_updated','completed','signoff','satisfaction_logged','disputed','note')),
  event_at timestamptz NOT NULL DEFAULT now(),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_handovers_r2408 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_handover_events_r2408 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_handovers_r2408 ON public.founder_handovers_r2408;
CREATE POLICY founder_all_handovers_r2408 ON public.founder_handovers_r2408
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_handover_events_r2408 ON public.founder_handover_events_r2408;
CREATE POLICY founder_all_handover_events_r2408 ON public.founder_handover_events_r2408
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_handovers_r2408_status ON public.founder_handovers_r2408(overall_status);
CREATE INDEX IF NOT EXISTS idx_handovers_r2408_customer ON public.founder_handovers_r2408(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_handovers_r2408_engineer ON public.founder_handovers_r2408(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_handovers_r2408_started ON public.founder_handovers_r2408(handover_started_at);
CREATE INDEX IF NOT EXISTS idx_handovers_r2408_shift ON public.founder_handovers_r2408(shift_label);
CREATE INDEX IF NOT EXISTS idx_handover_events_r2408_handover ON public.founder_handover_events_r2408(handover_id);
CREATE INDEX IF NOT EXISTS idx_handover_events_r2408_type ON public.founder_handover_events_r2408(event_type);

DROP FUNCTION IF EXISTS public.list_handovers_r2408();
CREATE OR REPLACE FUNCTION public.list_handovers_r2408()
RETURNS TABLE (
  id uuid,
  customer_user_id uuid,
  engineer_user_id uuid,
  equipment_model text,
  serial_no text,
  site_label text,
  shift_label text,
  handover_started_at timestamptz,
  handover_completed_at timestamptz,
  exterior_clean boolean,
  interior_clean boolean,
  consumables_restocked boolean,
  cables_organized boolean,
  calibration_verified boolean,
  logs_signed boolean,
  hazards_cleared boolean,
  total_checks int,
  passed_checks int,
  overall_status text,
  customer_signoff_at timestamptz,
  customer_satisfaction int,
  customer_comment text,
  notes text,
  pass_pct numeric,
  minutes_elapsed int,
  is_open boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.customer_user_id, h.engineer_user_id, h.equipment_model, h.serial_no,
         h.site_label, h.shift_label, h.handover_started_at, h.handover_completed_at,
         h.exterior_clean, h.interior_clean, h.consumables_restocked, h.cables_organized,
         h.calibration_verified, h.logs_signed, h.hazards_cleared,
         h.total_checks, h.passed_checks, h.overall_status,
         h.customer_signoff_at, h.customer_satisfaction, h.customer_comment, h.notes,
         ROUND((h.passed_checks::numeric / NULLIF(h.total_checks,0)::numeric) * 100.0, 1) AS pass_pct,
         (EXTRACT(EPOCH FROM (COALESCE(h.handover_completed_at, now()) - h.handover_started_at)) / 60.0)::int AS minutes_elapsed,
         (h.handover_completed_at IS NULL) AS is_open
  FROM public.founder_handovers_r2408 h
  ORDER BY (h.handover_completed_at IS NULL) DESC, h.handover_started_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.open_handover_r2408(uuid, uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.open_handover_r2408(
  p_customer_user_id uuid,
  p_engineer_user_id uuid,
  p_equipment_model text,
  p_serial_no text,
  p_site_label text,
  p_shift_label text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_shift_label NOT IN ('morning','afternoon','night','custom') THEN
    RAISE EXCEPTION 'invalid shift_label %', p_shift_label;
  END IF;

  INSERT INTO public.founder_handovers_r2408(
    customer_user_id, engineer_user_id, equipment_model, serial_no, site_label, shift_label
  ) VALUES (
    p_customer_user_id, p_engineer_user_id, p_equipment_model, p_serial_no, p_site_label, p_shift_label
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_handover_events_r2408(handover_id, event_type, note)
  VALUES (v_id, 'started', 'shift=' || p_shift_label);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'open_handover_r2408',
    jsonb_build_object('id', v_id, 'customer_user_id', p_customer_user_id, 'shift', p_shift_label));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.update_handover_checklist_r2408(uuid, boolean, boolean, boolean, boolean, boolean, boolean, boolean);
CREATE OR REPLACE FUNCTION public.update_handover_checklist_r2408(
  p_handover_id uuid,
  p_exterior_clean boolean,
  p_interior_clean boolean,
  p_consumables_restocked boolean,
  p_cables_organized boolean,
  p_calibration_verified boolean,
  p_logs_signed boolean,
  p_hazards_cleared boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_passed int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_passed := (CASE WHEN p_exterior_clean THEN 1 ELSE 0 END)
            + (CASE WHEN p_interior_clean THEN 1 ELSE 0 END)
            + (CASE WHEN p_consumables_restocked THEN 1 ELSE 0 END)
            + (CASE WHEN p_cables_organized THEN 1 ELSE 0 END)
            + (CASE WHEN p_calibration_verified THEN 1 ELSE 0 END)
            + (CASE WHEN p_logs_signed THEN 1 ELSE 0 END)
            + (CASE WHEN p_hazards_cleared THEN 1 ELSE 0 END);

  UPDATE public.founder_handovers_r2408
     SET exterior_clean = p_exterior_clean,
         interior_clean = p_interior_clean,
         consumables_restocked = p_consumables_restocked,
         cables_organized = p_cables_organized,
         calibration_verified = p_calibration_verified,
         logs_signed = p_logs_signed,
         hazards_cleared = p_hazards_cleared,
         passed_checks = v_passed,
         updated_at = now()
   WHERE id = p_handover_id;

  INSERT INTO public.founder_handover_events_r2408(handover_id, event_type, note)
  VALUES (p_handover_id, 'checklist_updated', 'passed=' || v_passed::text || '/7');

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_handover_checklist_r2408',
    jsonb_build_object('id', p_handover_id, 'passed', v_passed));

  RETURN p_handover_id;
END;
$$;

DROP FUNCTION IF EXISTS public.complete_handover_r2408(uuid, text);
CREATE OR REPLACE FUNCTION public.complete_handover_r2408(
  p_handover_id uuid,
  p_outcome text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_outcome NOT IN ('passed','failed','disputed') THEN
    RAISE EXCEPTION 'invalid outcome %', p_outcome;
  END IF;

  UPDATE public.founder_handovers_r2408
     SET handover_completed_at = now(),
         overall_status = p_outcome,
         updated_at = now()
   WHERE id = p_handover_id
     AND handover_completed_at IS NULL;

  INSERT INTO public.founder_handover_events_r2408(handover_id, event_type, note)
  VALUES (p_handover_id, CASE WHEN p_outcome = 'disputed' THEN 'disputed' ELSE 'completed' END,
          'outcome=' || p_outcome);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_handover_r2408',
    jsonb_build_object('id', p_handover_id, 'outcome', p_outcome));

  RETURN p_handover_id;
END;
$$;

DROP FUNCTION IF EXISTS public.log_handover_satisfaction_r2408(uuid, int, text);
CREATE OR REPLACE FUNCTION public.log_handover_satisfaction_r2408(
  p_handover_id uuid,
  p_score int,
  p_comment text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_score IS NULL OR p_score < 1 OR p_score > 5 THEN
    RAISE EXCEPTION 'score must be 1..5';
  END IF;

  UPDATE public.founder_handovers_r2408
     SET customer_satisfaction = p_score,
         customer_comment = p_comment,
         customer_signoff_at = COALESCE(customer_signoff_at, now()),
         updated_at = now()
   WHERE id = p_handover_id;

  INSERT INTO public.founder_handover_events_r2408(handover_id, event_type, note)
  VALUES (p_handover_id, 'satisfaction_logged', 'score=' || p_score::text);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_handover_satisfaction_r2408',
    jsonb_build_object('id', p_handover_id, 'score', p_score));

  RETURN p_handover_id;
END;
$$;

DROP FUNCTION IF EXISTS public.shift_handover_summary_r2408();
CREATE OR REPLACE FUNCTION public.shift_handover_summary_r2408()
RETURNS TABLE (
  shift_label text,
  total_handovers int,
  open_handovers int,
  passed_handovers int,
  failed_handovers int,
  disputed_handovers int,
  avg_pass_pct numeric,
  avg_minutes numeric,
  avg_satisfaction numeric,
  last_handover_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.shift_label,
         COUNT(*)::int AS total_handovers,
         COUNT(*) FILTER (WHERE h.handover_completed_at IS NULL)::int AS open_handovers,
         COUNT(*) FILTER (WHERE h.overall_status = 'passed')::int AS passed_handovers,
         COUNT(*) FILTER (WHERE h.overall_status = 'failed')::int AS failed_handovers,
         COUNT(*) FILTER (WHERE h.overall_status = 'disputed')::int AS disputed_handovers,
         ROUND(AVG((h.passed_checks::numeric / NULLIF(h.total_checks,0)::numeric) * 100.0)::numeric, 1) AS avg_pass_pct,
         ROUND(AVG(EXTRACT(EPOCH FROM (h.handover_completed_at - h.handover_started_at)) / 60.0)
               FILTER (WHERE h.handover_completed_at IS NOT NULL)::numeric, 1) AS avg_minutes,
         ROUND(AVG(h.customer_satisfaction)::numeric, 2) AS avg_satisfaction,
         MAX(h.handover_started_at) AS last_handover_at
  FROM public.founder_handovers_r2408 h
  GROUP BY h.shift_label
  ORDER BY total_handovers DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.list_handover_events_r2408(uuid);
CREATE OR REPLACE FUNCTION public.list_handover_events_r2408(p_handover_id uuid)
RETURNS TABLE (
  id uuid,
  handover_id uuid,
  event_type text,
  event_at timestamptz,
  note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.handover_id, e.event_type, e.event_at, e.note
  FROM public.founder_handover_events_r2408 e
  WHERE e.handover_id = p_handover_id
  ORDER BY e.event_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_handovers_r2408() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_handover_r2408(uuid, uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_handover_checklist_r2408(uuid, boolean, boolean, boolean, boolean, boolean, boolean, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_handover_r2408(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_handover_satisfaction_r2408(uuid, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.shift_handover_summary_r2408() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_handover_events_r2408(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_handovers_r2408() TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_handover_r2408(uuid, uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_handover_checklist_r2408(uuid, boolean, boolean, boolean, boolean, boolean, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_handover_r2408(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_handover_satisfaction_r2408(uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shift_handover_summary_r2408() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_handover_events_r2408(uuid) TO authenticated;

COMMIT;
