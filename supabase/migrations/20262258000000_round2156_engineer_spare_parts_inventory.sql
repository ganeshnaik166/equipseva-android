BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_spare_parts_inventory_r2156 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  part_label text NOT NULL,
  part_category text NOT NULL CHECK (part_category IN ('imaging','ventilator','general','consumables','safety')),
  quantity_on_hand int NOT NULL DEFAULT 0,
  par_level int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'stocked' CHECK (status IN ('stocked','low','critical','needs_reorder')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_parts_action_log_r2156 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL REFERENCES public.engineer_spare_parts_inventory_r2156(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('stocked','reordered','critical_used','replaced','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  quantity_change int NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_spare_parts_inventory_r2156 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_parts_action_log_r2156 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_inv_r2156 ON public.engineer_spare_parts_inventory_r2156;
CREATE POLICY founder_all_inv_r2156 ON public.engineer_spare_parts_inventory_r2156
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_log_r2156 ON public.engineer_parts_action_log_r2156;
CREATE POLICY founder_all_log_r2156 ON public.engineer_parts_action_log_r2156
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_inventory_r2156()
RETURNS SETOF public.engineer_spare_parts_inventory_r2156
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_spare_parts_inventory_r2156 ORDER BY captured_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_inventory_r2156(
  p_engineer_user_id uuid,
  p_part_label text,
  p_part_category text,
  p_quantity_on_hand int,
  p_par_level int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_spare_parts_inventory_r2156(engineer_user_id, part_label, part_category, quantity_on_hand, par_level, status)
  VALUES (p_engineer_user_id, p_part_label, p_part_category, p_quantity_on_hand, p_par_level, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_inventory_r2156', jsonb_build_object('id', v_id, 'part_label', p_part_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2156(p_inventory_id uuid)
RETURNS SETOF public.engineer_parts_action_log_r2156
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_parts_action_log_r2156 WHERE inventory_id = p_inventory_id ORDER BY taken_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2156(
  p_inventory_id uuid,
  p_action_type text,
  p_quantity_change int,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_parts_action_log_r2156(inventory_id, action_type, by_email, quantity_change, notes_md)
  VALUES (p_inventory_id, p_action_type, (auth.jwt()->>'email'), p_quantity_change, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2156', jsonb_build_object('id', v_id, 'inventory_id', p_inventory_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2156(p_inventory_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_spare_parts_inventory_r2156 SET status = p_status, updated_at = now() WHERE id = p_inventory_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2156', jsonb_build_object('id', p_inventory_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.critical_low_r2156()
RETURNS SETOF public.engineer_spare_parts_inventory_r2156
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_spare_parts_inventory_r2156
  WHERE status IN ('low','critical','needs_reorder') ORDER BY captured_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2156()
RETURNS SETOF public.engineer_parts_action_log_r2156
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_parts_action_log_r2156 ORDER BY taken_at DESC LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_inventory_r2156() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_inventory_r2156(uuid, text, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2156(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2156(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2156(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_low_r2156() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2156() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_inventory_r2156() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_inventory_r2156(uuid, text, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2156(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2156(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2156(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_low_r2156() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2156() TO authenticated;

COMMIT;
