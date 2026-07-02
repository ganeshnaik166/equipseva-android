BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_hospital_affinity_r1896 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repeat_assignment_count int NOT NULL DEFAULT 0,
  avg_hospital_rating numeric(4,2),
  avg_engineer_rating numeric(4,2),
  total_jobs int NOT NULL DEFAULT 0,
  affinity_score int NOT NULL DEFAULT 0 CHECK (affinity_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'moderate' CHECK (status IN ('strong','moderate','weak','blocked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, hospital_user_id)
);

CREATE TABLE IF NOT EXISTS public.engineer_hospital_affinity_actions_r1896 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  affinity_id uuid NOT NULL REFERENCES public.engineer_hospital_affinity_r1896(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('lock_pairing','avoid_pairing','cross_train','founder_review')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_hospital_affinity_r1896 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_hospital_affinity_actions_r1896 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS affinity_founder_all ON public.engineer_hospital_affinity_r1896;
CREATE POLICY affinity_founder_all ON public.engineer_hospital_affinity_r1896
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS affinity_actions_founder_all ON public.engineer_hospital_affinity_actions_r1896;
CREATE POLICY affinity_actions_founder_all ON public.engineer_hospital_affinity_actions_r1896
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_affinities
DROP FUNCTION IF EXISTS public.list_affinities_r1896();
CREATE OR REPLACE FUNCTION public.list_affinities_r1896()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  repeat_assignment_count int,
  avg_hospital_rating numeric,
  avg_engineer_rating numeric,
  total_jobs int,
  affinity_score int,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.engineer_user_id, a.hospital_user_id, a.repeat_assignment_count,
           a.avg_hospital_rating, a.avg_engineer_rating, a.total_jobs, a.affinity_score,
           a.status, a.created_at, a.updated_at
    FROM public.engineer_hospital_affinity_r1896 a
    ORDER BY a.affinity_score DESC, a.total_jobs DESC
    LIMIT 200;
END;
$$;

-- RPC 2: refresh_affinity
DROP FUNCTION IF EXISTS public.refresh_affinity_r1896(uuid, uuid);
CREATE OR REPLACE FUNCTION public.refresh_affinity_r1896(p_engineer_user_id uuid, p_hospital_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_jobs int;
  v_repeat int;
  v_avg_hosp numeric;
  v_score int;
  v_status text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*)::int,
         (COUNT(*) FILTER (WHERE rj.completed_at IS NOT NULL))::int,
         AVG(rj.hospital_rating)
    INTO v_total_jobs, v_repeat, v_avg_hosp
    FROM public.repair_jobs rj
    JOIN public.engineers e ON e.id = rj.engineer_id
   WHERE e.user_id = p_engineer_user_id
     AND rj.hospital_id = p_hospital_user_id;

  v_score := LEAST(100, GREATEST(0, COALESCE(v_repeat,0)*10 + COALESCE(ROUND(v_avg_hosp*10)::int,0)));
  v_status := CASE
    WHEN v_score >= 70 THEN 'strong'
    WHEN v_score >= 40 THEN 'moderate'
    ELSE 'weak'
  END;

  INSERT INTO public.engineer_hospital_affinity_r1896
    (engineer_user_id, hospital_user_id, repeat_assignment_count, avg_hospital_rating, total_jobs, affinity_score, status, updated_at)
  VALUES (p_engineer_user_id, p_hospital_user_id, COALESCE(v_repeat,0), v_avg_hosp, COALESCE(v_total_jobs,0), v_score, v_status, now())
  ON CONFLICT (engineer_user_id, hospital_user_id) DO UPDATE
    SET repeat_assignment_count = EXCLUDED.repeat_assignment_count,
        avg_hospital_rating = EXCLUDED.avg_hospital_rating,
        total_jobs = EXCLUDED.total_jobs,
        affinity_score = EXCLUDED.affinity_score,
        status = CASE WHEN public.engineer_hospital_affinity_r1896.status = 'blocked' THEN 'blocked' ELSE EXCLUDED.status END,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_affinity_r1896',
          jsonb_build_object('engineer_user_id', p_engineer_user_id, 'hospital_user_id', p_hospital_user_id, 'score', v_score));

  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
DROP FUNCTION IF EXISTS public.list_actions_r1896(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r1896(p_affinity_id uuid)
RETURNS TABLE (
  id uuid,
  affinity_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.affinity_id, a.action_type, a.taken_at, a.by_email
    FROM public.engineer_hospital_affinity_actions_r1896 a
    WHERE a.affinity_id = p_affinity_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

-- RPC 4: log_action
DROP FUNCTION IF EXISTS public.log_action_r1896(uuid, text);
CREATE OR REPLACE FUNCTION public.log_action_r1896(p_affinity_id uuid, p_action_type text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';

  INSERT INTO public.engineer_hospital_affinity_actions_r1896 (affinity_id, action_type, by_email)
  VALUES (p_affinity_id, p_action_type, v_email)
  RETURNING id INTO v_id;

  IF p_action_type = 'avoid_pairing' THEN
    UPDATE public.engineer_hospital_affinity_r1896 SET status = 'blocked', updated_at = now() WHERE id = p_affinity_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r1896',
          jsonb_build_object('affinity_id', p_affinity_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- RPC 5: top_pairs
DROP FUNCTION IF EXISTS public.top_pairs_r1896();
CREATE OR REPLACE FUNCTION public.top_pairs_r1896()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  affinity_score int,
  total_jobs int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.engineer_user_id, a.hospital_user_id, a.affinity_score, a.total_jobs, a.status
    FROM public.engineer_hospital_affinity_r1896 a
    WHERE a.status = 'strong'
    ORDER BY a.affinity_score DESC, a.total_jobs DESC
    LIMIT 25;
END;
$$;

-- RPC 6: blocked_pairs
DROP FUNCTION IF EXISTS public.blocked_pairs_r1896();
CREATE OR REPLACE FUNCTION public.blocked_pairs_r1896()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  affinity_score int,
  total_jobs int,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.engineer_user_id, a.hospital_user_id, a.affinity_score, a.total_jobs, a.updated_at
    FROM public.engineer_hospital_affinity_r1896 a
    WHERE a.status = 'blocked'
    ORDER BY a.updated_at DESC
    LIMIT 50;
END;
$$;

-- RPC 7: recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r1896();
CREATE OR REPLACE FUNCTION public.recent_actions_r1896()
RETURNS TABLE (
  id uuid,
  affinity_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.affinity_id, a.action_type, a.taken_at, a.by_email
    FROM public.engineer_hospital_affinity_actions_r1896 a
    ORDER BY a.taken_at DESC
    LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_affinities_r1896() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_affinity_r1896(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1896(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1896(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_pairs_r1896() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.blocked_pairs_r1896() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1896() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_affinities_r1896() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_affinity_r1896(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1896(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1896(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_pairs_r1896() TO authenticated;
GRANT EXECUTE ON FUNCTION public.blocked_pairs_r1896() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1896() TO authenticated;

COMMIT;