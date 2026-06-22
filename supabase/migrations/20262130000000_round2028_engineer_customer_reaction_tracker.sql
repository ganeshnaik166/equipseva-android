BEGIN;

-- ============================================================================
-- Round 2028 — Engineer Customer Reaction Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_customer_reaction_tracker_r2028 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  repair_job_id uuid,
  reaction_type text NOT NULL CHECK (reaction_type IN ('thank_you','concern','upset','escalation','repeat_request')),
  reaction_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','follow_up_needed','resolved','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecrt_r2028_engineer ON public.engineer_customer_reaction_tracker_r2028(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecrt_r2028_status ON public.engineer_customer_reaction_tracker_r2028(status);
CREATE INDEX IF NOT EXISTS idx_ecrt_r2028_captured ON public.engineer_customer_reaction_tracker_r2028(captured_at DESC);

ALTER TABLE public.engineer_customer_reaction_tracker_r2028 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ecrt_r2028 ON public.engineer_customer_reaction_tracker_r2028;
CREATE POLICY founder_all_ecrt_r2028 ON public.engineer_customer_reaction_tracker_r2028
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_reaction_action_log_r2028 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reaction_id uuid NOT NULL REFERENCES public.engineer_customer_reaction_tracker_r2028(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('thanked','concern_addressed','coached','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL DEFAULT '',
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eral_r2028_reaction ON public.engineer_reaction_action_log_r2028(reaction_id);
CREATE INDEX IF NOT EXISTS idx_eral_r2028_taken ON public.engineer_reaction_action_log_r2028(taken_at DESC);

ALTER TABLE public.engineer_reaction_action_log_r2028 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eral_r2028 ON public.engineer_reaction_action_log_r2028;
CREATE POLICY founder_all_eral_r2028 ON public.engineer_reaction_action_log_r2028
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_reactions_r2028()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_email text,
  repair_job_id uuid,
  reaction_type text,
  reaction_md text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, ep.email, r.hospital_id, hp.email,
         r.repair_job_id, r.reaction_type, r.reaction_md, r.status, r.captured_at
  FROM public.engineer_customer_reaction_tracker_r2028 r
  LEFT JOIN public.profiles ep ON ep.id = r.engineer_user_id
  LEFT JOIN public.profiles hp ON hp.id = r.hospital_id
  ORDER BY r.captured_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reactions_r2028() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reactions_r2028() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_reaction_r2028(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_repair_job_id uuid,
  p_reaction_type text,
  p_reaction_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_customer_reaction_tracker_r2028(engineer_user_id, hospital_id, repair_job_id, reaction_type, reaction_md)
  VALUES (p_engineer_user_id, p_hospital_id, p_repair_job_id, p_reaction_type, COALESCE(p_reaction_md,''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reaction_r2028',
          jsonb_build_object('reaction_id', v_id, 'engineer_user_id', p_engineer_user_id, 'reaction_type', p_reaction_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_reaction_r2028(uuid, uuid, uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_reaction_r2028(uuid, uuid, uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2028(p_reaction_id uuid)
RETURNS TABLE (
  id uuid,
  reaction_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.reaction_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_reaction_action_log_r2028 a
  WHERE a.reaction_id = p_reaction_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2028(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2028(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2028(
  p_reaction_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_reaction_action_log_r2028(reaction_id, action_type, by_email, notes_md)
  VALUES (p_reaction_id, p_action_type, COALESCE(p_by_email,''), COALESCE(p_notes_md,''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2028',
          jsonb_build_object('action_id', v_id, 'reaction_id', p_reaction_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_action_r2028(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2028(uuid, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2028(
  p_reaction_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_customer_reaction_tracker_r2028
  SET status = p_status, updated_at = now()
  WHERE id = p_reaction_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2028',
          jsonb_build_object('reaction_id', p_reaction_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2028(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2028(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.escalations_r2028()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  reaction_type text,
  status text,
  captured_at timestamptz,
  reaction_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, ep.email, r.reaction_type, r.status, r.captured_at, r.reaction_md
  FROM public.engineer_customer_reaction_tracker_r2028 r
  LEFT JOIN public.profiles ep ON ep.id = r.engineer_user_id
  WHERE r.status = 'escalated' OR r.reaction_type = 'escalation'
  ORDER BY r.captured_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.escalations_r2028() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escalations_r2028() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2028()
RETURNS TABLE (
  id uuid,
  reaction_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.reaction_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_reaction_action_log_r2028 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2028() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2028() TO authenticated;

COMMIT;
