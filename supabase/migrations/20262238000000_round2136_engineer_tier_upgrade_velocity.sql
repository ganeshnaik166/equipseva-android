BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_tier_upgrade_velocity_r2136 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_label text NOT NULL,
  period_label text NOT NULL,
  upgrades_to_bronze int NOT NULL DEFAULT 0,
  upgrades_to_silver int NOT NULL DEFAULT 0,
  upgrades_to_gold int NOT NULL DEFAULT 0,
  upgrades_to_platinum int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('accelerating','stable','decelerating','blocked')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_upgrade_action_log_r2136 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  velocity_id uuid NOT NULL REFERENCES public.engineer_tier_upgrade_velocity_r2136(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('upgraded','celebrated','coached','escalated','blocked_review')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_tier_upgrade_velocity_r2136 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_upgrade_action_log_r2136 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_velocity_r2136 ON public.engineer_tier_upgrade_velocity_r2136;
CREATE POLICY founder_all_velocity_r2136 ON public.engineer_tier_upgrade_velocity_r2136
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2136 ON public.engineer_upgrade_action_log_r2136;
CREATE POLICY founder_all_action_log_r2136 ON public.engineer_upgrade_action_log_r2136
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_tier_velocities_r2136()
RETURNS SETOF public.engineer_tier_upgrade_velocity_r2136
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_tier_upgrade_velocity_r2136 ORDER BY captured_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_tier_velocity_r2136(
  p_region_label text,
  p_period_label text,
  p_upgrades_to_bronze int,
  p_upgrades_to_silver int,
  p_upgrades_to_gold int,
  p_upgrades_to_platinum int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_tier_upgrade_velocity_r2136(
    region_label, period_label, upgrades_to_bronze, upgrades_to_silver,
    upgrades_to_gold, upgrades_to_platinum, status
  ) VALUES (
    p_region_label, p_period_label, p_upgrades_to_bronze, p_upgrades_to_silver,
    p_upgrades_to_gold, p_upgrades_to_platinum, p_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tier_velocity_r2136',
          jsonb_build_object('id', v_id, 'region', p_region_label, 'period', p_period_label, 'status', p_status));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_tier_upgrade_actions_r2136(p_velocity_id uuid)
RETURNS SETOF public.engineer_upgrade_action_log_r2136
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_upgrade_action_log_r2136
    WHERE velocity_id = p_velocity_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_tier_upgrade_action_r2136(
  p_velocity_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_upgrade_action_log_r2136(velocity_id, action_type, by_email, notes_md)
  VALUES (p_velocity_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tier_upgrade_action_r2136',
          jsonb_build_object('id', v_id, 'velocity_id', p_velocity_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_tier_velocity_status_r2136(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_tier_upgrade_velocity_r2136
    SET status = p_status, updated_at = now()
    WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_tier_velocity_status_r2136',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.accelerating_tier_velocities_r2136()
RETURNS SETOF public.engineer_tier_upgrade_velocity_r2136
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_tier_upgrade_velocity_r2136
    WHERE status = 'accelerating' ORDER BY captured_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_tier_upgrade_actions_r2136()
RETURNS SETOF public.engineer_upgrade_action_log_r2136
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_upgrade_action_log_r2136
    ORDER BY taken_at DESC LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_tier_velocities_r2136() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tier_velocity_r2136(text, text, int, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_tier_upgrade_actions_r2136(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tier_upgrade_action_r2136(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_tier_velocity_status_r2136(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.accelerating_tier_velocities_r2136() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_tier_upgrade_actions_r2136() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tier_velocities_r2136() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tier_velocity_r2136(text, text, int, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_tier_upgrade_actions_r2136(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tier_upgrade_action_r2136(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_tier_velocity_status_r2136(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accelerating_tier_velocities_r2136() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_tier_upgrade_actions_r2136() TO authenticated;

COMMIT;
