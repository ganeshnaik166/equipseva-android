BEGIN;

-- Inner circle people
CREATE TABLE IF NOT EXISTS public.founder_inner_circle_r1822 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_name text NOT NULL,
  person_role text NOT NULL CHECK (person_role IN ('spouse','family','cofounder_old','best_friend','mentor','therapist','coach')),
  trust_level int NOT NULL DEFAULT 5 CHECK (trust_level BETWEEN 1 AND 10),
  share_what_with text[] NOT NULL DEFAULT '{}',
  last_consulted_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','distant','lost_touch','family_priority_check_in')),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_inner_circle_r1822 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_inner_circle_r1822_founder_all ON public.founder_inner_circle_r1822;
CREATE POLICY founder_inner_circle_r1822_founder_all ON public.founder_inner_circle_r1822
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Check-ins
CREATE TABLE IF NOT EXISTS public.founder_inner_circle_check_ins_r1822 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id uuid NOT NULL REFERENCES public.founder_inner_circle_r1822(id) ON DELETE CASCADE,
  check_in_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  was_helpful boolean NOT NULL DEFAULT true,
  topic_discussed text,
  takeaway_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_inner_circle_check_ins_r1822 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_inner_circle_check_ins_r1822_founder_all ON public.founder_inner_circle_check_ins_r1822;
CREATE POLICY founder_inner_circle_check_ins_r1822_founder_all ON public.founder_inner_circle_check_ins_r1822
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_fic_check_ins_r1822_circle ON public.founder_inner_circle_check_ins_r1822(circle_id, check_in_date DESC);

-- 1. list_circle
CREATE OR REPLACE FUNCTION public.fic_list_circle_r1822()
RETURNS TABLE (
  id uuid,
  person_name text,
  person_role text,
  trust_level int,
  share_what_with text[],
  last_consulted_at timestamptz,
  status text,
  notes_md text,
  days_since_consult int,
  check_in_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id, c.person_name, c.person_role, c.trust_level, c.share_what_with,
    c.last_consulted_at, c.status, c.notes_md,
    CASE WHEN c.last_consulted_at IS NULL THEN NULL
         ELSE EXTRACT(DAY FROM (now() - c.last_consulted_at))::int END AS days_since_consult,
    (SELECT COUNT(*) FROM public.founder_inner_circle_check_ins_r1822 ci WHERE ci.circle_id = c.id)::int AS check_in_count
  FROM public.founder_inner_circle_r1822 c
  ORDER BY c.trust_level DESC, c.person_name ASC;
END;
$$;

-- 2. add_person
CREATE OR REPLACE FUNCTION public.fic_add_person_r1822(
  p_person_name text,
  p_person_role text,
  p_trust_level int,
  p_share_what_with text[],
  p_status text DEFAULT 'active',
  p_notes_md text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_inner_circle_r1822 (person_name, person_role, trust_level, share_what_with, status, notes_md)
  VALUES (p_person_name, p_person_role, p_trust_level, COALESCE(p_share_what_with,'{}'), p_status, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fic_add_person_r1822',
    jsonb_build_object('id', v_id, 'person_name', p_person_name, 'role', p_person_role, 'trust', p_trust_level));

  RETURN v_id;
END;
$$;

-- 3. list_check_ins
CREATE OR REPLACE FUNCTION public.fic_list_check_ins_r1822(p_circle_id uuid DEFAULT NULL, p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  circle_id uuid,
  person_name text,
  check_in_date date,
  was_helpful boolean,
  topic_discussed text,
  takeaway_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ci.id, ci.circle_id, c.person_name, ci.check_in_date, ci.was_helpful, ci.topic_discussed, ci.takeaway_md
  FROM public.founder_inner_circle_check_ins_r1822 ci
  JOIN public.founder_inner_circle_r1822 c ON c.id = ci.circle_id
  WHERE (p_circle_id IS NULL OR ci.circle_id = p_circle_id)
  ORDER BY ci.check_in_date DESC, ci.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;

-- 4. log_check_in
CREATE OR REPLACE FUNCTION public.fic_log_check_in_r1822(
  p_circle_id uuid,
  p_check_in_date date,
  p_was_helpful boolean,
  p_topic_discussed text,
  p_takeaway_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_inner_circle_check_ins_r1822 (circle_id, check_in_date, was_helpful, topic_discussed, takeaway_md)
  VALUES (p_circle_id, COALESCE(p_check_in_date, (now() AT TIME ZONE 'Asia/Kolkata')::date), COALESCE(p_was_helpful, true), p_topic_discussed, p_takeaway_md)
  RETURNING id INTO v_id;

  UPDATE public.founder_inner_circle_r1822
     SET last_consulted_at = now(), updated_at = now()
   WHERE id = p_circle_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fic_log_check_in_r1822',
    jsonb_build_object('check_in_id', v_id, 'circle_id', p_circle_id, 'helpful', p_was_helpful, 'topic', p_topic_discussed));

  RETURN v_id;
END;
$$;

-- 5. update_trust
CREATE OR REPLACE FUNCTION public.fic_update_trust_r1822(p_circle_id uuid, p_trust_level int, p_status text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_trust_level IS NULL OR p_trust_level < 1 OR p_trust_level > 10 THEN
    RAISE EXCEPTION 'trust_level must be 1..10';
  END IF;
  UPDATE public.founder_inner_circle_r1822
     SET trust_level = p_trust_level,
         status = COALESCE(p_status, status),
         updated_at = now()
   WHERE id = p_circle_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fic_update_trust_r1822',
    jsonb_build_object('circle_id', p_circle_id, 'trust', p_trust_level, 'status', p_status));
END;
$$;

-- 6. recently_consulted
CREATE OR REPLACE FUNCTION public.fic_recently_consulted_r1822(p_days int DEFAULT 14)
RETURNS TABLE (
  id uuid,
  person_name text,
  person_role text,
  trust_level int,
  last_consulted_at timestamptz,
  days_ago int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.person_name, c.person_role, c.trust_level, c.last_consulted_at,
         EXTRACT(DAY FROM (now() - c.last_consulted_at))::int AS days_ago
  FROM public.founder_inner_circle_r1822 c
  WHERE c.last_consulted_at IS NOT NULL
    AND c.last_consulted_at >= now() - (COALESCE(p_days,14) || ' days')::interval
  ORDER BY c.last_consulted_at DESC;
END;
$$;

-- 7. stale_relationships
CREATE OR REPLACE FUNCTION public.fic_stale_relationships_r1822(p_threshold_days int DEFAULT 60)
RETURNS TABLE (
  id uuid,
  person_name text,
  person_role text,
  trust_level int,
  status text,
  last_consulted_at timestamptz,
  days_since int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.person_name, c.person_role, c.trust_level, c.status, c.last_consulted_at,
         CASE WHEN c.last_consulted_at IS NULL THEN 9999
              ELSE EXTRACT(DAY FROM (now() - c.last_consulted_at))::int END AS days_since
  FROM public.founder_inner_circle_r1822 c
  WHERE c.status IN ('active','family_priority_check_in')
    AND (c.last_consulted_at IS NULL OR c.last_consulted_at < now() - (COALESCE(p_threshold_days,60) || ' days')::interval)
  ORDER BY c.trust_level DESC, days_since DESC;
END;
$$;

-- Lockdown
REVOKE EXECUTE ON FUNCTION public.fic_list_circle_r1822() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fic_add_person_r1822(text, text, int, text[], text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fic_list_check_ins_r1822(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fic_log_check_in_r1822(uuid, date, boolean, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fic_update_trust_r1822(uuid, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fic_recently_consulted_r1822(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fic_stale_relationships_r1822(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fic_list_circle_r1822() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fic_add_person_r1822(text, text, int, text[], text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fic_list_check_ins_r1822(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fic_log_check_in_r1822(uuid, date, boolean, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fic_update_trust_r1822(uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fic_recently_consulted_r1822(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fic_stale_relationships_r1822(int) TO authenticated;

COMMIT;