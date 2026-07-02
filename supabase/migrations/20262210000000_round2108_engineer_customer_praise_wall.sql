BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_praise_wall_r2108 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  praise_text_md text NOT NULL,
  source text NOT NULL CHECK (source IN ('survey','visit','email','phone','written_review')),
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','displayed','featured','marketing_used')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_praise_action_log_r2108 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  praise_id uuid NOT NULL REFERENCES public.engineer_customer_praise_wall_r2108(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('displayed','featured','marketing_published','awards','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_praise_wall_r2108 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_praise_action_log_r2108 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_praise_wall_r2108 ON public.engineer_customer_praise_wall_r2108;
CREATE POLICY founder_all_praise_wall_r2108 ON public.engineer_customer_praise_wall_r2108
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_praise_actions_r2108 ON public.engineer_praise_action_log_r2108;
CREATE POLICY founder_all_praise_actions_r2108 ON public.engineer_praise_action_log_r2108
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.list_praise_r2108(int);
CREATE OR REPLACE FUNCTION public.list_praise_r2108(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  praise_text_md text,
  source text,
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
  SELECT p.id, p.engineer_user_id, pr.email::text, p.hospital_id, o.name::text,
         p.praise_text_md, p.source, p.status, p.captured_at
  FROM public.engineer_customer_praise_wall_r2108 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = p.hospital_id
  ORDER BY p.captured_at DESC
  LIMIT p_limit;
END;
$$;

DROP FUNCTION IF EXISTS public.log_praise_r2108(uuid, uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_praise_r2108(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_praise_text_md text,
  p_source text
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
  INSERT INTO public.engineer_customer_praise_wall_r2108
    (engineer_user_id, hospital_id, praise_text_md, source)
  VALUES (p_engineer_user_id, p_hospital_id, p_praise_text_md, p_source)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_praise_r2108',
    jsonb_build_object('praise_id', v_id, 'engineer_user_id', p_engineer_user_id, 'source', p_source));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_praise_actions_r2108(uuid);
CREATE OR REPLACE FUNCTION public.list_praise_actions_r2108(p_praise_id uuid)
RETURNS TABLE (
  id uuid,
  praise_id uuid,
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
  SELECT a.id, a.praise_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_praise_action_log_r2108 a
  WHERE a.praise_id = p_praise_id
  ORDER BY a.taken_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.log_praise_action_r2108(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_praise_action_r2108(
  p_praise_id uuid,
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
  INSERT INTO public.engineer_praise_action_log_r2108
    (praise_id, action_type, by_email, notes_md)
  VALUES (p_praise_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_praise_action_r2108',
    jsonb_build_object('praise_id', p_praise_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_praise_status_r2108(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_praise_status_r2108(p_praise_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_customer_praise_wall_r2108
  SET status = p_status, updated_at = now()
  WHERE id = p_praise_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_praise_status_r2108',
    jsonb_build_object('praise_id', p_praise_id, 'status', p_status));
END;
$$;

DROP FUNCTION IF EXISTS public.list_featured_praise_r2108(int);
CREATE OR REPLACE FUNCTION public.list_featured_praise_r2108(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_name text,
  praise_text_md text,
  source text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, pr.email::text, o.name::text,
         p.praise_text_md, p.source, p.captured_at
  FROM public.engineer_customer_praise_wall_r2108 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = p.hospital_id
  WHERE p.status IN ('featured','marketing_used')
  ORDER BY p.captured_at DESC
  LIMIT p_limit;
END;
$$;

DROP FUNCTION IF EXISTS public.recent_praise_actions_r2108(int);
CREATE OR REPLACE FUNCTION public.recent_praise_actions_r2108(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  praise_id uuid,
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
  SELECT a.id, a.praise_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_praise_action_log_r2108 a
  ORDER BY a.taken_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_praise_r2108(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_praise_r2108(uuid, uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_praise_actions_r2108(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_praise_action_r2108(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_praise_status_r2108(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_featured_praise_r2108(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_praise_actions_r2108(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_praise_r2108(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_praise_r2108(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_praise_actions_r2108(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_praise_action_r2108(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_praise_status_r2108(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_featured_praise_r2108(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_praise_actions_r2108(int) TO authenticated;

COMMIT;
