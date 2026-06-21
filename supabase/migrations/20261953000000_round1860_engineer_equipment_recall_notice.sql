BEGIN;

-- ============================================================================
-- Round 1860 — Engineer Equipment Recall Notice
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_equipment_recalls_r1860 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_name text NOT NULL,
  manufacturer text NOT NULL,
  recall_notice_at timestamptz NOT NULL DEFAULT now(),
  recall_severity text NOT NULL CHECK (recall_severity IN ('critical','serious','moderate','minor')),
  affected_units_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','cleared','superseded')),
  deadline date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eer_r1860_status ON public.engineer_equipment_recalls_r1860(status);
CREATE INDEX IF NOT EXISTS idx_eer_r1860_severity ON public.engineer_equipment_recalls_r1860(recall_severity);
CREATE INDEX IF NOT EXISTS idx_eer_r1860_notice_at ON public.engineer_equipment_recalls_r1860(recall_notice_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_recall_response_log_r1860 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recall_id uuid NOT NULL REFERENCES public.engineer_equipment_recalls_r1860(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action_taken_at timestamptz NOT NULL DEFAULT now(),
  response_status text NOT NULL CHECK (response_status IN ('identified','secured','replaced','documented')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_errl_r1860_recall ON public.engineer_recall_response_log_r1860(recall_id);
CREATE INDEX IF NOT EXISTS idx_errl_r1860_engineer ON public.engineer_recall_response_log_r1860(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_errl_r1860_status ON public.engineer_recall_response_log_r1860(response_status);

ALTER TABLE public.engineer_equipment_recalls_r1860 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_recall_response_log_r1860 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eer_r1860_founder_all ON public.engineer_equipment_recalls_r1860;
CREATE POLICY eer_r1860_founder_all ON public.engineer_equipment_recalls_r1860
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS errl_r1860_founder_all ON public.engineer_recall_response_log_r1860;
CREATE POLICY errl_r1860_founder_all ON public.engineer_recall_response_log_r1860
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_recalls_r1860()
RETURNS TABLE (
  id uuid,
  equipment_name text,
  manufacturer text,
  recall_notice_at timestamptz,
  recall_severity text,
  affected_units_count int,
  status text,
  deadline date,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT r.id, r.equipment_name, r.manufacturer, r.recall_notice_at,
           r.recall_severity, r.affected_units_count, r.status, r.deadline,
           r.notes, r.created_at
    FROM public.engineer_equipment_recalls_r1860 r
    ORDER BY r.recall_notice_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_recall_r1860(
  p_equipment_name text,
  p_manufacturer text,
  p_recall_severity text,
  p_affected_units_count int,
  p_deadline date,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_equipment_recalls_r1860(
    equipment_name, manufacturer, recall_severity,
    affected_units_count, deadline, notes
  ) VALUES (
    p_equipment_name, p_manufacturer, p_recall_severity,
    COALESCE(p_affected_units_count, 0), p_deadline, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_recall_r1860',
    jsonb_build_object(
      'recall_id', v_id,
      'equipment_name', p_equipment_name,
      'manufacturer', p_manufacturer,
      'severity', p_recall_severity
    )
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_responses_r1860(p_recall_id uuid)
RETURNS TABLE (
  id uuid,
  recall_id uuid,
  engineer_user_id uuid,
  hospital_id uuid,
  action_taken_at timestamptz,
  response_status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT l.id, l.recall_id, l.engineer_user_id, l.hospital_id,
           l.action_taken_at, l.response_status, l.notes, l.created_at
    FROM public.engineer_recall_response_log_r1860 l
    WHERE p_recall_id IS NULL OR l.recall_id = p_recall_id
    ORDER BY l.action_taken_at DESC
    LIMIT 300;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_response_r1860(
  p_recall_id uuid,
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_response_status text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_recall_response_log_r1860(
    recall_id, engineer_user_id, hospital_id, response_status, notes
  ) VALUES (
    p_recall_id, p_engineer_user_id, p_hospital_id, p_response_status, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_response_r1860',
    jsonb_build_object(
      'response_id', v_id,
      'recall_id', p_recall_id,
      'engineer_user_id', p_engineer_user_id,
      'response_status', p_response_status
    )
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_cleared_r1860(p_recall_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_equipment_recalls_r1860
     SET status = 'cleared', updated_at = now()
   WHERE id = p_recall_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_cleared_r1860',
    jsonb_build_object('recall_id', p_recall_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.active_recalls_r1860()
RETURNS TABLE (
  id uuid,
  equipment_name text,
  manufacturer text,
  recall_severity text,
  affected_units_count int,
  deadline date,
  days_to_deadline int,
  recall_notice_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT r.id, r.equipment_name, r.manufacturer, r.recall_severity,
           r.affected_units_count, r.deadline,
           CASE WHEN r.deadline IS NULL THEN NULL
                ELSE (r.deadline - CURRENT_DATE)::int END AS days_to_deadline,
           r.recall_notice_at
    FROM public.engineer_equipment_recalls_r1860 r
    WHERE r.status = 'active'
    ORDER BY
      CASE r.recall_severity
        WHEN 'critical' THEN 1
        WHEN 'serious' THEN 2
        WHEN 'moderate' THEN 3
        WHEN 'minor' THEN 4
        ELSE 5
      END,
      r.deadline NULLS LAST,
      r.recall_notice_at DESC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.response_summary_r1860()
RETURNS TABLE (
  total_recalls int,
  active_recalls int,
  cleared_recalls int,
  critical_active int,
  total_responses int,
  identified_count int,
  secured_count int,
  replaced_count int,
  documented_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*) FROM public.engineer_equipment_recalls_r1860)::int,
      (SELECT (COUNT(*) FILTER (WHERE status = 'active')) FROM public.engineer_equipment_recalls_r1860)::int,
      (SELECT (COUNT(*) FILTER (WHERE status = 'cleared')) FROM public.engineer_equipment_recalls_r1860)::int,
      (SELECT (COUNT(*) FILTER (WHERE status = 'active' AND recall_severity = 'critical')) FROM public.engineer_equipment_recalls_r1860)::int,
      (SELECT COUNT(*) FROM public.engineer_recall_response_log_r1860)::int,
      (SELECT (COUNT(*) FILTER (WHERE response_status = 'identified')) FROM public.engineer_recall_response_log_r1860)::int,
      (SELECT (COUNT(*) FILTER (WHERE response_status = 'secured')) FROM public.engineer_recall_response_log_r1860)::int,
      (SELECT (COUNT(*) FILTER (WHERE response_status = 'replaced')) FROM public.engineer_recall_response_log_r1860)::int,
      (SELECT (COUNT(*) FILTER (WHERE response_status = 'documented')) FROM public.engineer_recall_response_log_r1860)::int;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_recalls_r1860() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_recall_r1860(text, text, text, int, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_responses_r1860(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_response_r1860(uuid, uuid, uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_cleared_r1860(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_recalls_r1860() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.response_summary_r1860() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_recalls_r1860() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_recall_r1860(text, text, text, int, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_responses_r1860(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_response_r1860(uuid, uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_cleared_r1860(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_recalls_r1860() TO authenticated;
GRANT EXECUTE ON FUNCTION public.response_summary_r1860() TO authenticated;

COMMIT;