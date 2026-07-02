BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_tech_stack_compatibility_r1919 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  system_name text NOT NULL,
  system_category text NOT NULL CHECK (system_category IN ('his','lis','pacs','emr','billing','inventory')),
  integration_status text NOT NULL DEFAULT 'not_started' CHECK (integration_status IN ('not_started','scoped','in_progress','live','blocked')),
  compatibility_score int NOT NULL DEFAULT 0,
  last_assessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_tech_integration_log_r1919 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compat_id uuid NOT NULL REFERENCES public.hospital_tech_stack_compatibility_r1919(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('kickoff','scoped','api_test','go_live','blocker_resolved')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_tech_stack_compatibility_r1919 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_tech_integration_log_r1919 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_compat_r1919 ON public.hospital_tech_stack_compatibility_r1919;
CREATE POLICY founder_all_compat_r1919 ON public.hospital_tech_stack_compatibility_r1919
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_intlog_r1919 ON public.hospital_tech_integration_log_r1919;
CREATE POLICY founder_all_intlog_r1919 ON public.hospital_tech_integration_log_r1919
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_compat_r1919_hospital ON public.hospital_tech_stack_compatibility_r1919(hospital_id);
CREATE INDEX IF NOT EXISTS idx_compat_r1919_status ON public.hospital_tech_stack_compatibility_r1919(integration_status);
CREATE INDEX IF NOT EXISTS idx_intlog_r1919_compat ON public.hospital_tech_integration_log_r1919(compat_id);

CREATE OR REPLACE FUNCTION public.list_systems_r1919()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  system_name text,
  system_category text,
  integration_status text,
  compatibility_score int,
  last_assessed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_id, p.full_name, c.system_name, c.system_category,
         c.integration_status, c.compatibility_score, c.last_assessed_at, c.created_at
  FROM public.hospital_tech_stack_compatibility_r1919 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_id
  ORDER BY c.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_system_r1919(
  p_hospital_id uuid,
  p_system_name text,
  p_system_category text,
  p_compatibility_score int
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
  INSERT INTO public.hospital_tech_stack_compatibility_r1919(
    hospital_id, system_name, system_category, compatibility_score, last_assessed_at
  ) VALUES (
    p_hospital_id, p_system_name, p_system_category, COALESCE(p_compatibility_score, 0), now()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_system_r1919',
          jsonb_build_object('compat_id', v_id, 'hospital_id', p_hospital_id, 'system_name', p_system_name),
          now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_integrations_r1919(p_compat_id uuid)
RETURNS TABLE (
  id uuid,
  compat_id uuid,
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
  SELECT l.id, l.compat_id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.hospital_tech_integration_log_r1919 l
  WHERE l.compat_id = p_compat_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_integration_r1919(
  p_compat_id uuid,
  p_action_type text,
  p_notes_md text
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
  INSERT INTO public.hospital_tech_integration_log_r1919(
    compat_id, action_type, by_email, notes_md, taken_at
  ) VALUES (
    p_compat_id, p_action_type, (auth.jwt()->>'email'), p_notes_md, now()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_integration_r1919',
          jsonb_build_object('log_id', v_id, 'compat_id', p_compat_id, 'action_type', p_action_type),
          now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_live_r1919(p_compat_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_tech_stack_compatibility_r1919
  SET integration_status = 'live', last_assessed_at = now(), updated_at = now()
  WHERE id = p_compat_id;

  INSERT INTO public.hospital_tech_integration_log_r1919(compat_id, action_type, by_email, notes_md, taken_at)
  VALUES (p_compat_id, 'go_live', (auth.jwt()->>'email'), 'marked live', now());

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_live_r1919',
          jsonb_build_object('compat_id', p_compat_id), now());
END;
$$;

CREATE OR REPLACE FUNCTION public.blocked_integrations_r1919()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  system_name text,
  system_category text,
  compatibility_score int,
  last_assessed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_id, p.full_name, c.system_name, c.system_category,
         c.compatibility_score, c.last_assessed_at
  FROM public.hospital_tech_stack_compatibility_r1919 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_id
  WHERE c.integration_status = 'blocked'
  ORDER BY c.last_assessed_at DESC NULLS LAST
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_integrations_r1919()
RETURNS TABLE (
  id uuid,
  compat_id uuid,
  system_name text,
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
  SELECT l.id, l.compat_id, c.system_name, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.hospital_tech_integration_log_r1919 l
  LEFT JOIN public.hospital_tech_stack_compatibility_r1919 c ON c.id = l.compat_id
  ORDER BY l.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_systems_r1919() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_system_r1919(uuid, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_integrations_r1919(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_integration_r1919(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_live_r1919(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.blocked_integrations_r1919() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_integrations_r1919() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_systems_r1919() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_system_r1919(uuid, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_integrations_r1919(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_integration_r1919(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_live_r1919(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.blocked_integrations_r1919() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_integrations_r1919() TO authenticated;

COMMIT;
