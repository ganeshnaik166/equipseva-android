BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_voice_of_operations_r2127 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  voice_text_md text NOT NULL,
  voice_source text NOT NULL CHECK (voice_source IN ('daily_huddle','incident_review','quarterly_check_in','audit','staff_meeting')),
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','actioned','closed','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_voice_action_log_r2127 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_id uuid NOT NULL REFERENCES public.hospital_customer_voice_of_operations_r2127(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('actioned','escalated','closed','feature_requested')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_voice_of_operations_r2127 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_voice_action_log_r2127 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_voice_r2127 ON public.hospital_customer_voice_of_operations_r2127;
CREATE POLICY founder_all_voice_r2127 ON public.hospital_customer_voice_of_operations_r2127
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_voice_action_r2127 ON public.hospital_voice_action_log_r2127;
CREATE POLICY founder_all_voice_action_r2127 ON public.hospital_voice_action_log_r2127
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_voices_r2127()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  voice_text_md text,
  voice_source text,
  status text,
  captured_at timestamptz
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
    SELECT v.id, v.hospital_id, COALESCE(o.name, p.full_name, 'unknown') AS hospital_name,
           v.voice_text_md, v.voice_source, v.status, v.captured_at
    FROM public.hospital_customer_voice_of_operations_r2127 v
    LEFT JOIN public.profiles p ON p.id = v.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY v.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_voice_r2127(
  p_hospital_id uuid,
  p_voice_text_md text,
  p_voice_source text
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
  INSERT INTO public.hospital_customer_voice_of_operations_r2127(hospital_id, voice_text_md, voice_source)
  VALUES (p_hospital_id, p_voice_text_md, p_voice_source)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_voice_r2127',
          jsonb_build_object('voice_id', v_id, 'hospital_id', p_hospital_id, 'voice_source', p_voice_source));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2127(p_voice_id uuid)
RETURNS TABLE (
  id uuid,
  voice_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT a.id, a.voice_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_voice_action_log_r2127 a
    WHERE a.voice_id = p_voice_id
    ORDER BY a.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2127(
  p_voice_id uuid,
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
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_voice_action_log_r2127(voice_id, action_type, by_email, notes_md)
  VALUES (p_voice_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r2127',
          jsonb_build_object('action_id', v_id, 'voice_id', p_voice_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2127(
  p_voice_id uuid,
  p_status text
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
  UPDATE public.hospital_customer_voice_of_operations_r2127
     SET status = p_status, updated_at = now()
   WHERE id = p_voice_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2127',
          jsonb_build_object('voice_id', p_voice_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.by_source_r2127()
RETURNS TABLE (
  voice_source text,
  voice_count bigint,
  open_count bigint
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
    SELECT v.voice_source,
           count(*)::bigint AS voice_count,
           count(*) FILTER (WHERE v.status IN ('captured','escalated'))::bigint AS open_count
    FROM public.hospital_customer_voice_of_operations_r2127 v
    GROUP BY v.voice_source
    ORDER BY voice_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2127()
RETURNS TABLE (
  id uuid,
  voice_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  voice_source text
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
    SELECT a.id, a.voice_id, a.action_type, a.taken_at, a.by_email, v.voice_source
    FROM public.hospital_voice_action_log_r2127 a
    JOIN public.hospital_customer_voice_of_operations_r2127 v ON v.id = a.voice_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_voices_r2127() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_voice_r2127(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2127(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2127(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2127(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.by_source_r2127() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2127() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_voices_r2127() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_voice_r2127(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2127(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2127(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2127(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.by_source_r2127() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2127() TO authenticated;

COMMIT;
