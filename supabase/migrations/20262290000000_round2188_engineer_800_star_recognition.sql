BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_800_star_recognition_r2188 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recognition_type text NOT NULL CHECK (recognition_type IN ('800_milestone','peer_recognized','customer_recognized','founder_recognized','special_award')),
  recognition_md text NOT NULL DEFAULT '',
  awarded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','celebrated','archived')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_recognition_action_log_r2188 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recognition_id uuid NOT NULL REFERENCES public.engineer_800_star_recognition_r2188(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('awarded','announced','bonused','promoted','marketing_used')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_800_recog_r2188_eng ON public.engineer_800_star_recognition_r2188(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_800_recog_r2188_awarded ON public.engineer_800_star_recognition_r2188(awarded_at DESC);
CREATE INDEX IF NOT EXISTS idx_eng_recog_action_r2188_rec ON public.engineer_recognition_action_log_r2188(recognition_id);
CREATE INDEX IF NOT EXISTS idx_eng_recog_action_r2188_taken ON public.engineer_recognition_action_log_r2188(taken_at DESC);

-- RLS
ALTER TABLE public.engineer_800_star_recognition_r2188 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_recognition_action_log_r2188 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eng_800_recog_r2188 ON public.engineer_800_star_recognition_r2188;
CREATE POLICY founder_all_eng_800_recog_r2188 ON public.engineer_800_star_recognition_r2188
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eng_recog_action_r2188 ON public.engineer_recognition_action_log_r2188;
CREATE POLICY founder_all_eng_recog_action_r2188 ON public.engineer_recognition_action_log_r2188
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC: list_recognitions
DROP FUNCTION IF EXISTS public.list_recognitions_r2188(int);
CREATE OR REPLACE FUNCTION public.list_recognitions_r2188(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  recognition_type text,
  recognition_md text,
  awarded_at timestamptz,
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
  SELECT r.id, r.engineer_user_id, r.recognition_type, r.recognition_md, r.awarded_at, r.status, r.captured_at
  FROM public.engineer_800_star_recognition_r2188 r
  ORDER BY r.awarded_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recognitions_r2188(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recognitions_r2188(int) TO authenticated;

-- RPC: log_recognition
DROP FUNCTION IF EXISTS public.log_recognition_r2188(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_recognition_r2188(
  p_engineer_user_id uuid,
  p_recognition_type text,
  p_recognition_md text,
  p_status text DEFAULT 'active'
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
  INSERT INTO public.engineer_800_star_recognition_r2188 (engineer_user_id, recognition_type, recognition_md, status)
  VALUES (p_engineer_user_id, p_recognition_type, COALESCE(p_recognition_md, ''), COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_recognition_r2188',
          jsonb_build_object('recognition_id', v_id, 'engineer_user_id', p_engineer_user_id, 'type', p_recognition_type),
          now());

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_recognition_r2188(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_recognition_r2188(uuid, text, text, text) TO authenticated;

-- RPC: list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2188(uuid, int);
CREATE OR REPLACE FUNCTION public.list_actions_r2188(p_recognition_id uuid DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  recognition_id uuid,
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
  SELECT a.id, a.recognition_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_recognition_action_log_r2188 a
  WHERE p_recognition_id IS NULL OR a.recognition_id = p_recognition_id
  ORDER BY a.taken_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2188(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2188(uuid, int) TO authenticated;

-- RPC: log_action
DROP FUNCTION IF EXISTS public.log_action_r2188(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2188(
  p_recognition_id uuid,
  p_action_type text,
  p_by_email text,
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
  INSERT INTO public.engineer_recognition_action_log_r2188 (recognition_id, action_type, by_email, notes_md)
  VALUES (p_recognition_id, p_action_type, p_by_email, COALESCE(p_notes_md, ''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2188',
          jsonb_build_object('action_id', v_id, 'recognition_id', p_recognition_id, 'type', p_action_type),
          now());

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2188(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2188(uuid, text, text, text) TO authenticated;

-- RPC: mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2188(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2188(p_recognition_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_800_star_recognition_r2188
  SET status = p_status, updated_at = now()
  WHERE id = p_recognition_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2188',
          jsonb_build_object('recognition_id', p_recognition_id, 'status', p_status),
          now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2188(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2188(uuid, text) TO authenticated;

-- RPC: recent_recognitions
DROP FUNCTION IF EXISTS public.recent_recognitions_r2188(int);
CREATE OR REPLACE FUNCTION public.recent_recognitions_r2188(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  recognition_type text,
  recognition_md text,
  awarded_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, r.recognition_type, r.recognition_md, r.awarded_at, r.status
  FROM public.engineer_800_star_recognition_r2188 r
  WHERE r.awarded_at >= now() - (p_days || ' days')::interval
  ORDER BY r.awarded_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_recognitions_r2188(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_recognitions_r2188(int) TO authenticated;

-- RPC: recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2188(int);
CREATE OR REPLACE FUNCTION public.recent_actions_r2188(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  recognition_id uuid,
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
  SELECT a.id, a.recognition_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_recognition_action_log_r2188 a
  WHERE a.taken_at >= now() - (p_days || ' days')::interval
  ORDER BY a.taken_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2188(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2188(int) TO authenticated;

COMMIT;
