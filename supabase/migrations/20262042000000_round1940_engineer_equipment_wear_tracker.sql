BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_equipment_wear_tracker_r1940 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('ppe','diagnostic','tools','test_meters','comms','transport')),
  condition_score int NOT NULL CHECK (condition_score BETWEEN 1 AND 10),
  last_inspected_at timestamptz,
  status text NOT NULL CHECK (status IN ('serviceable','needs_repair','needs_replacement','decommissioned')),
  issued_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_equipment_action_log_r1940 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL REFERENCES public.engineer_equipment_wear_tracker_r1940(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('inspected','repaired','replaced','decommissioned','issued')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  cost_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_equipment_wear_tracker_r1940 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_equipment_action_log_r1940 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eqwear_r1940 ON public.engineer_equipment_wear_tracker_r1940;
CREATE POLICY founder_all_eqwear_r1940 ON public.engineer_equipment_wear_tracker_r1940
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eqact_r1940 ON public.engineer_equipment_action_log_r1940;
CREATE POLICY founder_all_eqact_r1940 ON public.engineer_equipment_action_log_r1940
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. list_equipment
CREATE OR REPLACE FUNCTION public.list_equipment_r1940()
RETURNS TABLE(id uuid, engineer_user_id uuid, equipment_label text, equipment_category text, condition_score int, last_inspected_at timestamptz, status text, issued_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.engineer_user_id, t.equipment_label, t.equipment_category, t.condition_score, t.last_inspected_at, t.status, t.issued_at, t.created_at
    FROM public.engineer_equipment_wear_tracker_r1940 t
    ORDER BY t.condition_score ASC, t.issued_at DESC
    LIMIT 200;
END; $$;

-- 2. log_equipment
CREATE OR REPLACE FUNCTION public.log_equipment_r1940(
  p_engineer_user_id uuid,
  p_equipment_label text,
  p_equipment_category text,
  p_condition_score int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_equipment_wear_tracker_r1940(engineer_user_id, equipment_label, equipment_category, condition_score, status)
    VALUES (p_engineer_user_id, p_equipment_label, p_equipment_category, p_condition_score, p_status)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_equipment_r1940', jsonb_build_object('id', v_id, 'label', p_equipment_label));
  RETURN v_id;
END; $$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1940(p_equipment_id uuid)
RETURNS TABLE(id uuid, equipment_id uuid, action_type text, taken_at timestamptz, by_email text, cost_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.equipment_id, a.action_type, a.taken_at, a.by_email, a.cost_rupees
    FROM public.engineer_equipment_action_log_r1940 a
    WHERE a.equipment_id = p_equipment_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END; $$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r1940(
  p_equipment_id uuid,
  p_action_type text,
  p_by_email text,
  p_cost_rupees bigint
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_equipment_action_log_r1940(equipment_id, action_type, by_email, cost_rupees)
    VALUES (p_equipment_id, p_action_type, p_by_email, COALESCE(p_cost_rupees, 0))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1940', jsonb_build_object('id', v_id, 'equipment_id', p_equipment_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1940(p_equipment_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_equipment_wear_tracker_r1940
    SET status = p_status, updated_at = now()
    WHERE id = p_equipment_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1940', jsonb_build_object('id', p_equipment_id, 'status', p_status));
END; $$;

-- 6. equipment_needing_attention
CREATE OR REPLACE FUNCTION public.equipment_needing_attention_r1940()
RETURNS TABLE(id uuid, engineer_user_id uuid, equipment_label text, equipment_category text, condition_score int, status text, last_inspected_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.engineer_user_id, t.equipment_label, t.equipment_category, t.condition_score, t.status, t.last_inspected_at
    FROM public.engineer_equipment_wear_tracker_r1940 t
    WHERE t.status IN ('needs_repair','needs_replacement') OR t.condition_score <= 4
    ORDER BY t.condition_score ASC
    LIMIT 200;
END; $$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r1940()
RETURNS TABLE(id uuid, equipment_id uuid, equipment_label text, action_type text, taken_at timestamptz, by_email text, cost_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.equipment_id, t.equipment_label, a.action_type, a.taken_at, a.by_email, a.cost_rupees
    FROM public.engineer_equipment_action_log_r1940 a
    LEFT JOIN public.engineer_equipment_wear_tracker_r1940 t ON t.id = a.equipment_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_equipment_r1940() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_equipment_r1940(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1940(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1940(uuid, text, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1940(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.equipment_needing_attention_r1940() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1940() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_equipment_r1940() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_equipment_r1940(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1940(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1940(uuid, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1940(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.equipment_needing_attention_r1940() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1940() TO authenticated;

COMMIT;
