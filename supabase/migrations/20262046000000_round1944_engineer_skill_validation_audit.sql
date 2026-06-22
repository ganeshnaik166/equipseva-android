BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_skill_validation_audits_r1944 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  skill_name text NOT NULL,
  validation_method text NOT NULL CHECK (validation_method IN ('assessment','practical','peer_review','customer_feedback','incident_response')),
  validated_at timestamptz NOT NULL DEFAULT now(),
  validity_period_days int NOT NULL DEFAULT 365,
  status text NOT NULL DEFAULT 'valid' CHECK (status IN ('valid','expiring_soon','expired','revoked')),
  validator_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_skill_revalidation_log_r1944 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  validation_id uuid NOT NULL REFERENCES public.engineer_skill_validation_audits_r1944(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('revalidated','scheduled_revalidation','skill_retired','upgraded_to_expert','revoked')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_skill_validation_audits_r1944 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_skill_revalidation_log_r1944 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_validations_r1944 ON public.engineer_skill_validation_audits_r1944;
CREATE POLICY founder_all_validations_r1944 ON public.engineer_skill_validation_audits_r1944
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_revalidation_log_r1944 ON public.engineer_skill_revalidation_log_r1944;
CREATE POLICY founder_all_revalidation_log_r1944 ON public.engineer_skill_revalidation_log_r1944
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_skill_validations_r1944()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  skill_name text,
  validation_method text,
  validated_at timestamptz,
  validity_period_days int,
  expires_at timestamptz,
  status text,
  validator_email text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.engineer_user_id, p.email::text, v.skill_name, v.validation_method,
         v.validated_at, v.validity_period_days,
         (v.validated_at + (v.validity_period_days || ' days')::interval) AS expires_at,
         v.status, v.validator_email
  FROM public.engineer_skill_validation_audits_r1944 v
  LEFT JOIN public.profiles p ON p.id = v.engineer_user_id
  ORDER BY v.validated_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_skill_validation_r1944(
  p_engineer_user_id uuid,
  p_skill_name text,
  p_validation_method text,
  p_validity_period_days int,
  p_validator_email text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_skill_validation_audits_r1944(
    engineer_user_id, skill_name, validation_method, validity_period_days, validator_email
  ) VALUES (
    p_engineer_user_id, p_skill_name, p_validation_method, p_validity_period_days, p_validator_email
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_skill_validation_r1944',
          jsonb_build_object('id', v_id, 'skill', p_skill_name, 'engineer', p_engineer_user_id));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_skill_actions_r1944()
RETURNS TABLE (
  id uuid,
  validation_id uuid,
  skill_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.validation_id, v.skill_name, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.engineer_skill_revalidation_log_r1944 l
  LEFT JOIN public.engineer_skill_validation_audits_r1944 v ON v.id = l.validation_id
  ORDER BY l.taken_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_skill_action_r1944(
  p_validation_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_skill_revalidation_log_r1944(
    validation_id, action_type, by_email, notes_md
  ) VALUES (
    p_validation_id, p_action_type, p_by_email, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_skill_action_r1944',
          jsonb_build_object('id', v_id, 'validation_id', p_validation_id, 'action', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_skill_status_r1944(
  p_validation_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_skill_validation_audits_r1944
  SET status = p_status, updated_at = now()
  WHERE id = p_validation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_skill_status_r1944',
          jsonb_build_object('id', p_validation_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.expiring_skill_validations_r1944()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  skill_name text,
  validated_at timestamptz,
  expires_at timestamptz,
  days_left int,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.engineer_user_id, p.email::text, v.skill_name, v.validated_at,
         (v.validated_at + (v.validity_period_days || ' days')::interval) AS expires_at,
         GREATEST(0, EXTRACT(DAY FROM (v.validated_at + (v.validity_period_days || ' days')::interval - now()))::int) AS days_left,
         v.status
  FROM public.engineer_skill_validation_audits_r1944 v
  LEFT JOIN public.profiles p ON p.id = v.engineer_user_id
  WHERE v.status IN ('valid','expiring_soon')
    AND (v.validated_at + (v.validity_period_days || ' days')::interval) <= (now() + interval '60 days')
  ORDER BY expires_at ASC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_skill_actions_r1944()
RETURNS TABLE (
  id uuid,
  skill_name text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, v.skill_name, l.action_type, l.taken_at, l.by_email
  FROM public.engineer_skill_revalidation_log_r1944 l
  LEFT JOIN public.engineer_skill_validation_audits_r1944 v ON v.id = l.validation_id
  WHERE l.taken_at >= now() - interval '30 days'
  ORDER BY l.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_skill_validations_r1944() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_skill_validation_r1944(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_skill_actions_r1944() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_skill_action_r1944(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_skill_status_r1944(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_skill_validations_r1944() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_skill_actions_r1944() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_skill_validations_r1944() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_skill_validation_r1944(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_skill_actions_r1944() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_skill_action_r1944(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_skill_status_r1944(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_skill_validations_r1944() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_skill_actions_r1944() TO authenticated;

COMMIT;
