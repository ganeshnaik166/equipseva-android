BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_2000_milestone_recognition_r2000 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('100_jobs','500_jobs','1000_jobs','gold_tier','master_skill','5_year_tenure','customer_champion')),
  achieved_at timestamptz NOT NULL DEFAULT now(),
  recognition_status text NOT NULL DEFAULT 'pending' CHECK (recognition_status IN ('pending','recognized','celebrated','promoted','elevated')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_milestone_r2000_engineer ON public.engineer_2000_milestone_recognition_r2000(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_milestone_r2000_status ON public.engineer_2000_milestone_recognition_r2000(recognition_status);
CREATE INDEX IF NOT EXISTS idx_eng_milestone_r2000_achieved ON public.engineer_2000_milestone_recognition_r2000(achieved_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_milestone_celebration_log_r2000 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id uuid NOT NULL REFERENCES public.engineer_2000_milestone_recognition_r2000(id) ON DELETE CASCADE,
  celebration_type text NOT NULL CHECK (celebration_type IN ('public_announcement','bonus_paid','promotion','founder_visit','customer_share')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_celebration_r2000_milestone ON public.engineer_milestone_celebration_log_r2000(milestone_id);
CREATE INDEX IF NOT EXISTS idx_eng_celebration_r2000_taken ON public.engineer_milestone_celebration_log_r2000(taken_at DESC);

ALTER TABLE public.engineer_2000_milestone_recognition_r2000 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_milestone_celebration_log_r2000 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eng_milestone_r2000 ON public.engineer_2000_milestone_recognition_r2000;
CREATE POLICY founder_all_eng_milestone_r2000 ON public.engineer_2000_milestone_recognition_r2000
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eng_celebration_r2000 ON public.engineer_milestone_celebration_log_r2000;
CREATE POLICY founder_all_eng_celebration_r2000 ON public.engineer_milestone_celebration_log_r2000
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_milestones_r2000()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  milestone_type text,
  achieved_at timestamptz,
  recognition_status text,
  status text,
  notes_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.engineer_user_id, m.milestone_type, m.achieved_at, m.recognition_status, m.status, m.notes_md, m.created_at
    FROM public.engineer_2000_milestone_recognition_r2000 m
    ORDER BY m.achieved_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_milestone_r2000(
  p_engineer_user_id uuid,
  p_milestone_type text,
  p_notes_md text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_2000_milestone_recognition_r2000(engineer_user_id, milestone_type, notes_md)
  VALUES (p_engineer_user_id, p_milestone_type, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_milestone_r2000',
    jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'milestone_type', p_milestone_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_celebrations_r2000(p_milestone_id uuid)
RETURNS TABLE (
  id uuid,
  milestone_id uuid,
  celebration_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.milestone_id, c.celebration_type, c.taken_at, c.by_email, c.notes_md, c.created_at
    FROM public.engineer_milestone_celebration_log_r2000 c
    WHERE c.milestone_id = p_milestone_id
    ORDER BY c.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_celebration_r2000(
  p_milestone_id uuid,
  p_celebration_type text,
  p_notes_md text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_milestone_celebration_log_r2000(milestone_id, celebration_type, by_email, notes_md)
  VALUES (p_milestone_id, p_celebration_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_celebration_r2000',
    jsonb_build_object('id', v_id, 'milestone_id', p_milestone_id, 'celebration_type', p_celebration_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2000(
  p_id uuid,
  p_recognition_status text,
  p_status text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_2000_milestone_recognition_r2000
  SET recognition_status = COALESCE(p_recognition_status, recognition_status),
      status = COALESCE(p_status, status),
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2000',
    jsonb_build_object('id', p_id, 'recognition_status', p_recognition_status, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.pending_recognition_r2000()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  milestone_type text,
  achieved_at timestamptz,
  recognition_status text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.engineer_user_id, m.milestone_type, m.achieved_at, m.recognition_status, m.notes_md
    FROM public.engineer_2000_milestone_recognition_r2000 m
    WHERE m.recognition_status = 'pending' AND m.status = 'active'
    ORDER BY m.achieved_at ASC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_celebrations_r2000()
RETURNS TABLE (
  id uuid,
  milestone_id uuid,
  celebration_type text,
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
    SELECT c.id, c.milestone_id, c.celebration_type, c.taken_at, c.by_email, c.notes_md
    FROM public.engineer_milestone_celebration_log_r2000 c
    ORDER BY c.taken_at DESC
    LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_milestones_r2000() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_milestone_r2000(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_celebrations_r2000(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_celebration_r2000(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2000(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pending_recognition_r2000() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_celebrations_r2000() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_milestones_r2000() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_milestone_r2000(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_celebrations_r2000(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_celebration_r2000(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2000(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pending_recognition_r2000() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_celebrations_r2000() TO authenticated;

COMMIT;
