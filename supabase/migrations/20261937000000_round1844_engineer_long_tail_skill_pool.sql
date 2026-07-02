BEGIN;

-- ============================================================================
-- Round 1844: Engineer Long-Tail Skill Pool
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_long_tail_skills_r1844 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  skill_name text NOT NULL,
  skill_category text NOT NULL CHECK (skill_category IN ('legacy_equipment','vendor_specific','regulatory','language','region_specific')),
  mastery_level int NOT NULL CHECK (mastery_level BETWEEN 1 AND 5),
  acquired_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','aging','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eltsk_r1844_engineer ON public.engineer_long_tail_skills_r1844(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eltsk_r1844_category ON public.engineer_long_tail_skills_r1844(skill_category);
CREATE INDEX IF NOT EXISTS idx_eltsk_r1844_status ON public.engineer_long_tail_skills_r1844(status);

CREATE TABLE IF NOT EXISTS public.engineer_skill_demand_signals_r1844 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_id uuid NOT NULL REFERENCES public.engineer_long_tail_skills_r1844(id) ON DELETE CASCADE,
  demand_event_at timestamptz NOT NULL DEFAULT now(),
  demand_source text NOT NULL CHECK (demand_source IN ('repair_job','hospital_request','competitive_threat')),
  value_realized_md numeric(14,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esds_r1844_skill ON public.engineer_skill_demand_signals_r1844(skill_id);
CREATE INDEX IF NOT EXISTS idx_esds_r1844_event_at ON public.engineer_skill_demand_signals_r1844(demand_event_at DESC);

ALTER TABLE public.engineer_long_tail_skills_r1844 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_skill_demand_signals_r1844 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eltsk_r1844 ON public.engineer_long_tail_skills_r1844;
CREATE POLICY founder_all_eltsk_r1844 ON public.engineer_long_tail_skills_r1844
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_esds_r1844 ON public.engineer_skill_demand_signals_r1844;
CREATE POLICY founder_all_esds_r1844 ON public.engineer_skill_demand_signals_r1844
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_long_tail_skills_r1844()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  skill_name text,
  skill_category text,
  mastery_level int,
  acquired_at timestamptz,
  status text,
  notes text
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
  SELECT s.id, s.engineer_user_id, p.email, s.skill_name, s.skill_category,
         s.mastery_level, s.acquired_at, s.status, s.notes
  FROM public.engineer_long_tail_skills_r1844 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.mastery_level DESC, s.acquired_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_long_tail_skill_r1844(
  p_engineer_user_id uuid,
  p_skill_name text,
  p_skill_category text,
  p_mastery_level int,
  p_notes text DEFAULT NULL
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
  INSERT INTO public.engineer_long_tail_skills_r1844(engineer_user_id, skill_name, skill_category, mastery_level, notes)
  VALUES (p_engineer_user_id, p_skill_name, p_skill_category, p_mastery_level, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1844_add_long_tail_skill',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'skill_name', p_skill_name, 'category', p_skill_category, 'mastery', p_mastery_level));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_skill_demand_r1844(p_skill_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  skill_id uuid,
  skill_name text,
  demand_event_at timestamptz,
  demand_source text,
  value_realized_md numeric,
  notes text
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
  SELECT d.id, d.skill_id, s.skill_name, d.demand_event_at, d.demand_source, d.value_realized_md, d.notes
  FROM public.engineer_skill_demand_signals_r1844 d
  JOIN public.engineer_long_tail_skills_r1844 s ON s.id = d.skill_id
  WHERE p_skill_id IS NULL OR d.skill_id = p_skill_id
  ORDER BY d.demand_event_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_skill_demand_r1844(
  p_skill_id uuid,
  p_demand_source text,
  p_value_realized_md numeric,
  p_notes text DEFAULT NULL
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
  INSERT INTO public.engineer_skill_demand_signals_r1844(skill_id, demand_source, value_realized_md, notes)
  VALUES (p_skill_id, p_demand_source, p_value_realized_md, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1844_log_skill_demand',
          jsonb_build_object('id', v_id, 'skill_id', p_skill_id, 'source', p_demand_source, 'value_md', p_value_realized_md));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.high_value_skills_r1844()
RETURNS TABLE (
  skill_id uuid,
  skill_name text,
  skill_category text,
  engineer_user_id uuid,
  engineer_email text,
  mastery_level int,
  total_value_md numeric,
  demand_events int
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
  SELECT s.id, s.skill_name, s.skill_category, s.engineer_user_id, p.email, s.mastery_level,
         COALESCE(SUM(d.value_realized_md), 0)::numeric AS total_value,
         (COUNT(d.id))::int AS events
  FROM public.engineer_long_tail_skills_r1844 s
  LEFT JOIN public.engineer_skill_demand_signals_r1844 d ON d.skill_id = s.id
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  GROUP BY s.id, p.email
  HAVING COALESCE(SUM(d.value_realized_md), 0) > 0
  ORDER BY total_value DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.fading_skills_r1844()
RETURNS TABLE (
  skill_id uuid,
  skill_name text,
  skill_category text,
  engineer_user_id uuid,
  engineer_email text,
  status text,
  last_demand_at timestamptz,
  days_since_demand int
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
  SELECT s.id, s.skill_name, s.skill_category, s.engineer_user_id, p.email, s.status,
         MAX(d.demand_event_at) AS last_demand,
         CASE WHEN MAX(d.demand_event_at) IS NULL THEN NULL
              ELSE EXTRACT(DAY FROM (now() - MAX(d.demand_event_at)))::int
         END AS days_since
  FROM public.engineer_long_tail_skills_r1844 s
  LEFT JOIN public.engineer_skill_demand_signals_r1844 d ON d.skill_id = s.id
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.status IN ('aging','lost')
     OR (MAX(d.demand_event_at) IS NULL)
     OR (MAX(d.demand_event_at) < now() - INTERVAL '180 days')
  GROUP BY s.id, p.email
  ORDER BY last_demand NULLS FIRST
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.skill_demand_summary_r1844()
RETURNS TABLE (
  total_skills int,
  active_skills int,
  aging_skills int,
  lost_skills int,
  total_demand_events int,
  total_value_md numeric,
  unique_engineers int
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
  SELECT
    (SELECT COUNT(*) FROM public.engineer_long_tail_skills_r1844)::int,
    (SELECT (COUNT(*) FILTER (WHERE status='active'))::int FROM public.engineer_long_tail_skills_r1844),
    (SELECT (COUNT(*) FILTER (WHERE status='aging'))::int FROM public.engineer_long_tail_skills_r1844),
    (SELECT (COUNT(*) FILTER (WHERE status='lost'))::int FROM public.engineer_long_tail_skills_r1844),
    (SELECT COUNT(*) FROM public.engineer_skill_demand_signals_r1844)::int,
    (SELECT COALESCE(SUM(value_realized_md),0)::numeric FROM public.engineer_skill_demand_signals_r1844),
    (SELECT COUNT(DISTINCT engineer_user_id) FROM public.engineer_long_tail_skills_r1844)::int;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_long_tail_skills_r1844() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_long_tail_skill_r1844(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_skill_demand_r1844(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_skill_demand_r1844(uuid, text, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_value_skills_r1844() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fading_skills_r1844() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.skill_demand_summary_r1844() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_long_tail_skills_r1844() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_long_tail_skill_r1844(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_skill_demand_r1844(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_skill_demand_r1844(uuid, text, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_value_skills_r1844() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fading_skills_r1844() TO authenticated;
GRANT EXECUTE ON FUNCTION public.skill_demand_summary_r1844() TO authenticated;

COMMIT;