BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_equipment_loss_events_r1828 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  equipment_name text NOT NULL,
  lost_at timestamptz NOT NULL DEFAULT now(),
  location_lost text,
  replacement_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (replacement_cost_rupees >= 0),
  status text NOT NULL DEFAULT 'reported' CHECK (status IN ('reported','recovered','written_off','disputed')),
  recovered_at timestamptz,
  recovered_location text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_equipment_loss_prevention_actions_r1828 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.engineer_equipment_loss_events_r1828(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('policy_update','training','insurance','tagging_system','spot_audit')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  expected_impact text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_equipment_loss_events_r1828 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_equipment_loss_prevention_actions_r1828 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_events_r1828 ON public.engineer_equipment_loss_events_r1828;
CREATE POLICY founder_all_events_r1828 ON public.engineer_equipment_loss_events_r1828
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r1828 ON public.engineer_equipment_loss_prevention_actions_r1828;
CREATE POLICY founder_all_actions_r1828 ON public.engineer_equipment_loss_prevention_actions_r1828
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_eelp_events_r1828_engineer ON public.engineer_equipment_loss_events_r1828(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eelp_events_r1828_status ON public.engineer_equipment_loss_events_r1828(status);
CREATE INDEX IF NOT EXISTS idx_eelp_events_r1828_lost_at ON public.engineer_equipment_loss_events_r1828(lost_at DESC);
CREATE INDEX IF NOT EXISTS idx_eelp_actions_r1828_event ON public.engineer_equipment_loss_prevention_actions_r1828(event_id);
CREATE INDEX IF NOT EXISTS idx_eelp_actions_r1828_taken ON public.engineer_equipment_loss_prevention_actions_r1828(taken_at DESC);

-- 1) list_events
CREATE OR REPLACE FUNCTION public.list_loss_events_r1828()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_name text,
  lost_at timestamptz,
  location_lost text,
  replacement_cost_rupees bigint,
  status text,
  recovered_at timestamptz,
  recovered_location text
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
  SELECT e.id, e.engineer_user_id, p.email, e.equipment_name, e.lost_at, e.location_lost,
         e.replacement_cost_rupees, e.status, e.recovered_at, e.recovered_location
  FROM public.engineer_equipment_loss_events_r1828 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  ORDER BY e.lost_at DESC
  LIMIT 200;
END;
$$;

-- 2) log_event
CREATE OR REPLACE FUNCTION public.log_loss_event_r1828(
  p_engineer_user_id uuid,
  p_equipment_name text,
  p_location_lost text,
  p_replacement_cost_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_equipment_loss_events_r1828(engineer_user_id, equipment_name, location_lost, replacement_cost_rupees)
  VALUES (p_engineer_user_id, p_equipment_name, p_location_lost, COALESCE(p_replacement_cost_rupees, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_loss_event_r1828',
    jsonb_build_object('event_id', v_id, 'engineer_user_id', p_engineer_user_id, 'equipment_name', p_equipment_name, 'cost', p_replacement_cost_rupees));
  RETURN v_id;
END;
$$;

-- 3) list_actions
CREATE OR REPLACE FUNCTION public.list_loss_prevention_actions_r1828(p_event_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  event_id uuid,
  equipment_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  expected_impact text
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
  SELECT a.id, a.event_id, e.equipment_name, a.action_type, a.taken_at, a.by_email, a.expected_impact
  FROM public.engineer_equipment_loss_prevention_actions_r1828 a
  JOIN public.engineer_equipment_loss_events_r1828 e ON e.id = a.event_id
  WHERE p_event_id IS NULL OR a.event_id = p_event_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- 4) log_action
CREATE OR REPLACE FUNCTION public.log_loss_prevention_action_r1828(
  p_event_id uuid,
  p_action_type text,
  p_expected_impact text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_equipment_loss_prevention_actions_r1828(event_id, action_type, by_email, expected_impact)
  VALUES (p_event_id, p_action_type, (auth.jwt()->>'email'), p_expected_impact)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_loss_prevention_action_r1828',
    jsonb_build_object('action_id', v_id, 'event_id', p_event_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- 5) mark_recovered
CREATE OR REPLACE FUNCTION public.mark_loss_recovered_r1828(
  p_event_id uuid,
  p_recovered_location text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_equipment_loss_events_r1828
  SET status = 'recovered',
      recovered_at = now(),
      recovered_location = p_recovered_location,
      updated_at = now()
  WHERE id = p_event_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_loss_recovered_r1828',
    jsonb_build_object('event_id', p_event_id, 'recovered_location', p_recovered_location));
END;
$$;

-- 6) loss_summary_per_engineer
CREATE OR REPLACE FUNCTION public.loss_summary_per_engineer_r1828()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_events int,
  reported_count int,
  recovered_count int,
  written_off_count int,
  disputed_count int,
  total_replacement_cost_rupees bigint
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
  SELECT e.engineer_user_id,
         p.email,
         COUNT(*)::int AS total_events,
         (COUNT(*) FILTER (WHERE e.status = 'reported'))::int,
         (COUNT(*) FILTER (WHERE e.status = 'recovered'))::int,
         (COUNT(*) FILTER (WHERE e.status = 'written_off'))::int,
         (COUNT(*) FILTER (WHERE e.status = 'disputed'))::int,
         COALESCE(SUM(e.replacement_cost_rupees), 0)::bigint
  FROM public.engineer_equipment_loss_events_r1828 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  GROUP BY e.engineer_user_id, p.email
  ORDER BY total_events DESC
  LIMIT 200;
END;
$$;

-- 7) recent_recoveries
CREATE OR REPLACE FUNCTION public.recent_recoveries_r1828()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  equipment_name text,
  lost_at timestamptz,
  recovered_at timestamptz,
  recovered_location text,
  replacement_cost_rupees bigint
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
  SELECT e.id, p.email, e.equipment_name, e.lost_at, e.recovered_at, e.recovered_location, e.replacement_cost_rupees
  FROM public.engineer_equipment_loss_events_r1828 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  WHERE e.status = 'recovered' AND e.recovered_at IS NOT NULL
  ORDER BY e.recovered_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_loss_events_r1828() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_loss_event_r1828(uuid, text, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_loss_prevention_actions_r1828(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_loss_prevention_action_r1828(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_loss_recovered_r1828(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.loss_summary_per_engineer_r1828() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_recoveries_r1828() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_loss_events_r1828() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_loss_event_r1828(uuid, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_loss_prevention_actions_r1828(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_loss_prevention_action_r1828(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_loss_recovered_r1828(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.loss_summary_per_engineer_r1828() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_recoveries_r1828() TO authenticated;

COMMIT;