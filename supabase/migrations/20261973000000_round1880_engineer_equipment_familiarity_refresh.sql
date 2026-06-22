BEGIN;

-- Tables ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.engineer_familiarity_refresh_r1880 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_category text NOT NULL,
  last_serviced_at timestamptz,
  days_since_service int NOT NULL DEFAULT 0,
  refresh_recommended boolean NOT NULL DEFAULT false,
  refresh_completed_at timestamptz,
  status text NOT NULL DEFAULT 'current'
    CHECK (status IN ('current','refresh_recommended','refresh_done','lost')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efr_r1880_engineer
  ON public.engineer_familiarity_refresh_r1880 (engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_efr_r1880_status
  ON public.engineer_familiarity_refresh_r1880 (status);

CREATE TABLE IF NOT EXISTS public.engineer_refresh_actions_r1880 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  familiarity_id uuid NOT NULL REFERENCES public.engineer_familiarity_refresh_r1880(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('shadow_session','training','mentor_call','practical_test')),
  completed_at timestamptz,
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_era_r1880_fam
  ON public.engineer_refresh_actions_r1880 (familiarity_id);

-- RLS ------------------------------------------------------------------------

ALTER TABLE public.engineer_familiarity_refresh_r1880 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_refresh_actions_r1880 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_efr_r1880_founder ON public.engineer_familiarity_refresh_r1880;
CREATE POLICY p_efr_r1880_founder ON public.engineer_familiarity_refresh_r1880
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_era_r1880_founder ON public.engineer_refresh_actions_r1880;
CREATE POLICY p_era_r1880_founder ON public.engineer_refresh_actions_r1880
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC: list_familiarity ------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_familiarity_r1880()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_category text,
  last_serviced_at timestamptz,
  days_since_service int,
  refresh_recommended boolean,
  refresh_completed_at timestamptz,
  status text,
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
  SELECT f.id, f.engineer_user_id, p.email, f.equipment_category,
         f.last_serviced_at, f.days_since_service, f.refresh_recommended,
         f.refresh_completed_at, f.status, f.created_at
  FROM public.engineer_familiarity_refresh_r1880 f
  LEFT JOIN public.profiles p ON p.id = f.engineer_user_id
  ORDER BY f.days_since_service DESC, f.created_at DESC
  LIMIT 500;
END;
$$;

-- RPC: refresh_familiarity ---------------------------------------------------

CREATE OR REPLACE FUNCTION public.refresh_familiarity_r1880(
  p_engineer_user_id uuid,
  p_equipment_category text,
  p_last_serviced_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_days int;
  v_rec boolean;
  v_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_days := COALESCE(EXTRACT(EPOCH FROM (now() - p_last_serviced_at)) / 86400, 0)::int;
  v_rec := v_days >= 180;
  v_status := CASE
    WHEN v_days >= 365 THEN 'lost'
    WHEN v_days >= 180 THEN 'refresh_recommended'
    ELSE 'current'
  END;

  INSERT INTO public.engineer_familiarity_refresh_r1880 (
    engineer_user_id, equipment_category, last_serviced_at,
    days_since_service, refresh_recommended, status
  )
  VALUES (p_engineer_user_id, p_equipment_category, p_last_serviced_at,
          v_days, v_rec, v_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'refresh_familiarity_r1880',
    jsonb_build_object(
      'id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'equipment_category', p_equipment_category,
      'days_since_service', v_days,
      'status', v_status
    )
  );
  RETURN v_id;
END;
$$;

-- RPC: list_actions ----------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_actions_r1880(p_familiarity_id uuid)
RETURNS TABLE (
  id uuid,
  familiarity_id uuid,
  action_type text,
  completed_at timestamptz,
  by_email text,
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
  SELECT a.id, a.familiarity_id, a.action_type, a.completed_at, a.by_email, a.created_at
  FROM public.engineer_refresh_actions_r1880 a
  WHERE a.familiarity_id = p_familiarity_id
  ORDER BY a.created_at DESC
  LIMIT 500;
END;
$$;

-- RPC: log_action ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.log_action_r1880(
  p_familiarity_id uuid,
  p_action_type text,
  p_completed_at timestamptz,
  p_by_email text
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

  INSERT INTO public.engineer_refresh_actions_r1880 (
    familiarity_id, action_type, completed_at, by_email
  )
  VALUES (p_familiarity_id, p_action_type, p_completed_at, p_by_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_action_r1880',
    jsonb_build_object(
      'id', v_id,
      'familiarity_id', p_familiarity_id,
      'action_type', p_action_type,
      'by_email', p_by_email
    )
  );
  RETURN v_id;
END;
$$;

-- RPC: mark_refreshed --------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_refreshed_r1880(p_familiarity_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_familiarity_refresh_r1880
  SET status = 'refresh_done',
      refresh_completed_at = now(),
      updated_at = now()
  WHERE id = p_familiarity_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_refreshed_r1880',
    jsonb_build_object('familiarity_id', p_familiarity_id)
  );
END;
$$;

-- RPC: refresh_recommended_queue ---------------------------------------------

CREATE OR REPLACE FUNCTION public.refresh_recommended_queue_r1880()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_category text,
  days_since_service int,
  status text,
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
  SELECT f.id, f.engineer_user_id, p.email, f.equipment_category,
         f.days_since_service, f.status, f.created_at
  FROM public.engineer_familiarity_refresh_r1880 f
  LEFT JOIN public.profiles p ON p.id = f.engineer_user_id
  WHERE f.status = 'refresh_recommended'
  ORDER BY f.days_since_service DESC
  LIMIT 500;
END;
$$;

-- RPC: recently_refreshed ----------------------------------------------------

CREATE OR REPLACE FUNCTION public.recently_refreshed_r1880()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_category text,
  refresh_completed_at timestamptz,
  status text
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
  SELECT f.id, f.engineer_user_id, p.email, f.equipment_category,
         f.refresh_completed_at, f.status
  FROM public.engineer_familiarity_refresh_r1880 f
  LEFT JOIN public.profiles p ON p.id = f.engineer_user_id
  WHERE f.status = 'refresh_done'
    AND f.refresh_completed_at >= (now() - interval '30 days')
  ORDER BY f.refresh_completed_at DESC
  LIMIT 500;
END;
$$;

-- Grants ---------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.list_familiarity_r1880() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_familiarity_r1880() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.refresh_familiarity_r1880(uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.refresh_familiarity_r1880(uuid, text, timestamptz) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_actions_r1880(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_actions_r1880(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_action_r1880(uuid, text, timestamptz, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_action_r1880(uuid, text, timestamptz, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_refreshed_r1880(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_refreshed_r1880(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.refresh_recommended_queue_r1880() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.refresh_recommended_queue_r1880() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recently_refreshed_r1880() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.recently_refreshed_r1880() TO authenticated;

COMMIT;