BEGIN;

-- ============================================================================
-- Round 1712 — Engineer Skill Endorsements
-- Hospital + peer endorsements per engineer skill
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_skill_endorsements_r1712 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  skill text NOT NULL,
  endorser_email text NOT NULL,
  endorser_role text NOT NULL CHECK (endorser_role IN ('hospital','peer','founder')),
  endorsement_text text,
  endorsed_at timestamptz NOT NULL DEFAULT now(),
  weight int NOT NULL DEFAULT 1 CHECK (weight BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eskl_end_r1712_eng ON public.engineer_skill_endorsements_r1712(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eskl_end_r1712_skill ON public.engineer_skill_endorsements_r1712(skill);
CREATE INDEX IF NOT EXISTS idx_eskl_end_r1712_at ON public.engineer_skill_endorsements_r1712(endorsed_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_skill_summaries_r1712 (
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  skill text NOT NULL,
  total_endorsements int NOT NULL DEFAULT 0,
  weighted_score int NOT NULL DEFAULT 0,
  last_endorsed_at timestamptz,
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (engineer_user_id, skill)
);

CREATE INDEX IF NOT EXISTS idx_eskl_sum_r1712_score ON public.engineer_skill_summaries_r1712(weighted_score DESC);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.engineer_skill_endorsements_r1712 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_skill_summaries_r1712 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eskl_end_r1712 ON public.engineer_skill_endorsements_r1712;
CREATE POLICY founder_all_eskl_end_r1712 ON public.engineer_skill_endorsements_r1712
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eskl_sum_r1712 ON public.engineer_skill_summaries_r1712;
CREATE POLICY founder_all_eskl_sum_r1712 ON public.engineer_skill_summaries_r1712
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- 1. list_endorsements
CREATE OR REPLACE FUNCTION public.list_endorsements_r1712()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  skill text,
  endorser_email text,
  endorser_role text,
  endorsement_text text,
  weight int,
  endorsed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.engineer_user_id, p.email, e.skill,
         e.endorser_email, e.endorser_role, e.endorsement_text,
         e.weight, e.endorsed_at
  FROM public.engineer_skill_endorsements_r1712 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  ORDER BY e.endorsed_at DESC
  LIMIT 200;
END;
$$;

-- 2. add_endorsement
CREATE OR REPLACE FUNCTION public.add_endorsement_r1712(
  p_engineer_user_id uuid,
  p_skill text,
  p_endorser_email text,
  p_endorser_role text,
  p_endorsement_text text,
  p_weight int
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
  INSERT INTO public.engineer_skill_endorsements_r1712
    (engineer_user_id, skill, endorser_email, endorser_role, endorsement_text, weight)
  VALUES (p_engineer_user_id, p_skill, p_endorser_email, p_endorser_role, p_endorsement_text, p_weight)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_endorsement_r1712',
    jsonb_build_object('id', v_id, 'engineer', p_engineer_user_id, 'skill', p_skill, 'weight', p_weight)
  );

  RETURN v_id;
END;
$$;

-- 3. list_summaries
CREATE OR REPLACE FUNCTION public.list_summaries_r1712()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  skill text,
  total_endorsements int,
  weighted_score int,
  last_endorsed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_user_id, p.email, s.skill,
         s.total_endorsements, s.weighted_score, s.last_endorsed_at
  FROM public.engineer_skill_summaries_r1712 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.weighted_score DESC
  LIMIT 200;
END;
$$;

-- 4. recompute_summary
CREATE OR REPLACE FUNCTION public.recompute_summary_r1712(
  p_engineer_user_id uuid,
  p_skill text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_score int;
  v_last timestamptz;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT (COUNT(*))::int, (COALESCE(SUM(weight),0))::int, MAX(endorsed_at)
    INTO v_total, v_score, v_last
  FROM public.engineer_skill_endorsements_r1712
  WHERE engineer_user_id = p_engineer_user_id AND skill = p_skill;

  INSERT INTO public.engineer_skill_summaries_r1712
    (engineer_user_id, skill, total_endorsements, weighted_score, last_endorsed_at)
  VALUES (p_engineer_user_id, p_skill, v_total, v_score, v_last)
  ON CONFLICT (engineer_user_id, skill) DO UPDATE
    SET total_endorsements = EXCLUDED.total_endorsements,
        weighted_score = EXCLUDED.weighted_score,
        last_endorsed_at = EXCLUDED.last_endorsed_at,
        updated_at = now();

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'recompute_summary_r1712',
    jsonb_build_object('engineer', p_engineer_user_id, 'skill', p_skill, 'score', v_score)
  );
END;
$$;

-- 5. top_endorsed_skills
CREATE OR REPLACE FUNCTION public.top_endorsed_skills_r1712()
RETURNS TABLE (
  skill text,
  total_endorsements int,
  weighted_score int,
  engineer_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.skill,
         (COUNT(*))::int AS total_endorsements,
         (COALESCE(SUM(e.weight),0))::int AS weighted_score,
         (COUNT(DISTINCT e.engineer_user_id))::int AS engineer_count
  FROM public.engineer_skill_endorsements_r1712 e
  GROUP BY e.skill
  ORDER BY weighted_score DESC
  LIMIT 50;
END;
$$;

-- 6. top_endorsers
CREATE OR REPLACE FUNCTION public.top_endorsers_r1712()
RETURNS TABLE (
  endorser_email text,
  endorser_role text,
  total_endorsements int,
  total_weight int,
  last_endorsed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.endorser_email, e.endorser_role,
         (COUNT(*))::int AS total_endorsements,
         (COALESCE(SUM(e.weight),0))::int AS total_weight,
         MAX(e.endorsed_at) AS last_endorsed_at
  FROM public.engineer_skill_endorsements_r1712 e
  GROUP BY e.endorser_email, e.endorser_role
  ORDER BY total_weight DESC
  LIMIT 50;
END;
$$;

-- 7. hospital_endorsed_engineers
CREATE OR REPLACE FUNCTION public.hospital_endorsed_engineers_r1712()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  hospital_endorsements int,
  hospital_weight int,
  distinct_skills int,
  last_endorsed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_user_id,
         p.email,
         (COUNT(*))::int AS hospital_endorsements,
         (COALESCE(SUM(e.weight),0))::int AS hospital_weight,
         (COUNT(DISTINCT e.skill))::int AS distinct_skills,
         MAX(e.endorsed_at) AS last_endorsed_at
  FROM public.engineer_skill_endorsements_r1712 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  WHERE e.endorser_role = 'hospital'
  GROUP BY e.engineer_user_id, p.email
  ORDER BY hospital_weight DESC
  LIMIT 100;
END;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.list_endorsements_r1712() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_endorsements_r1712() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.add_endorsement_r1712(uuid, text, text, text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_endorsement_r1712(uuid, text, text, text, text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_summaries_r1712() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_summaries_r1712() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recompute_summary_r1712(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recompute_summary_r1712(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_endorsed_skills_r1712() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_endorsed_skills_r1712() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_endorsers_r1712() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_endorsers_r1712() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.hospital_endorsed_engineers_r1712() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hospital_endorsed_engineers_r1712() TO authenticated;

COMMIT;