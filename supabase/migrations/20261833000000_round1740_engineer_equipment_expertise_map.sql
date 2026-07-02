BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_equipment_expertise_r1740 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_category text NOT NULL,
  expertise_level int NOT NULL CHECK (expertise_level BETWEEN 1 AND 10),
  years_of_experience int NOT NULL DEFAULT 0 CHECK (years_of_experience >= 0),
  certifications_count int NOT NULL DEFAULT 0 CHECK (certifications_count >= 0),
  last_repair_at timestamptz,
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, equipment_category)
);

CREATE INDEX IF NOT EXISTS idx_eeer1740_engineer ON public.engineer_equipment_expertise_r1740(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eeer1740_category ON public.engineer_equipment_expertise_r1740(equipment_category);

CREATE TABLE IF NOT EXISTS public.engineer_expertise_gap_actions_r1740 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expertise_id uuid NOT NULL REFERENCES public.engineer_equipment_expertise_r1740(id) ON DELETE CASCADE,
  gap_description text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('training','shadowing','cert_sponsor','hire','refer_out')),
  target_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eegar1740_expertise ON public.engineer_expertise_gap_actions_r1740(expertise_id);
CREATE INDEX IF NOT EXISTS idx_eegar1740_status ON public.engineer_expertise_gap_actions_r1740(status);

ALTER TABLE public.engineer_equipment_expertise_r1740 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_expertise_gap_actions_r1740 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eeer1740 ON public.engineer_equipment_expertise_r1740;
CREATE POLICY founder_all_eeer1740 ON public.engineer_equipment_expertise_r1740
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eegar1740 ON public.engineer_expertise_gap_actions_r1740;
CREATE POLICY founder_all_eegar1740 ON public.engineer_expertise_gap_actions_r1740
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_expertise
CREATE OR REPLACE FUNCTION public.list_expertise_r1740()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_category text,
  expertise_level int,
  years_of_experience int,
  certifications_count int,
  last_repair_at timestamptz,
  last_updated_at timestamptz,
  open_gaps int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.engineer_user_id,
    p.email::text AS engineer_email,
    e.equipment_category,
    e.expertise_level,
    e.years_of_experience,
    e.certifications_count,
    e.last_repair_at,
    e.last_updated_at,
    (SELECT COUNT(*) FILTER (WHERE g.status <> 'closed') FROM public.engineer_expertise_gap_actions_r1740 g WHERE g.expertise_id = e.id)::int AS open_gaps
  FROM public.engineer_equipment_expertise_r1740 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  ORDER BY e.expertise_level DESC, e.last_updated_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: set_expertise (upsert)
CREATE OR REPLACE FUNCTION public.set_expertise_r1740(
  p_engineer_user_id uuid,
  p_equipment_category text,
  p_expertise_level int,
  p_years_of_experience int,
  p_certifications_count int
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
  IF p_expertise_level < 1 OR p_expertise_level > 10 THEN RAISE EXCEPTION 'bad_level'; END IF;

  INSERT INTO public.engineer_equipment_expertise_r1740 (
    engineer_user_id, equipment_category, expertise_level, years_of_experience, certifications_count, last_updated_at, updated_at
  )
  VALUES (p_engineer_user_id, p_equipment_category, p_expertise_level, COALESCE(p_years_of_experience, 0), COALESCE(p_certifications_count, 0), now(), now())
  ON CONFLICT (engineer_user_id, equipment_category)
  DO UPDATE SET
    expertise_level = EXCLUDED.expertise_level,
    years_of_experience = EXCLUDED.years_of_experience,
    certifications_count = EXCLUDED.certifications_count,
    last_updated_at = now(),
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_expertise_r1740',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'category', p_equipment_category, 'level', p_expertise_level));
  RETURN v_id;
END;
$$;

-- RPC 3: list_gap_actions
CREATE OR REPLACE FUNCTION public.list_gap_actions_r1740()
RETURNS TABLE (
  id uuid,
  expertise_id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_category text,
  expertise_level int,
  gap_description text,
  action_type text,
  target_date date,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    g.id,
    g.expertise_id,
    e.engineer_user_id,
    p.email::text AS engineer_email,
    e.equipment_category,
    e.expertise_level,
    g.gap_description,
    g.action_type,
    g.target_date,
    g.status,
    g.created_at
  FROM public.engineer_expertise_gap_actions_r1740 g
  JOIN public.engineer_equipment_expertise_r1740 e ON e.id = g.expertise_id
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  ORDER BY
    CASE g.status WHEN 'open' THEN 0 WHEN 'in_progress' THEN 1 ELSE 2 END,
    g.target_date NULLS LAST,
    g.created_at DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log_gap_action
CREATE OR REPLACE FUNCTION public.log_gap_action_r1740(
  p_expertise_id uuid,
  p_gap_description text,
  p_action_type text,
  p_target_date date
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
  IF p_action_type NOT IN ('training','shadowing','cert_sponsor','hire','refer_out') THEN RAISE EXCEPTION 'bad_action_type'; END IF;

  INSERT INTO public.engineer_expertise_gap_actions_r1740 (expertise_id, gap_description, action_type, target_date, status)
  VALUES (p_expertise_id, p_gap_description, p_action_type, p_target_date, 'open')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_gap_action_r1740',
          jsonb_build_object('id', v_id, 'expertise_id', p_expertise_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: close_gap_action
CREATE OR REPLACE FUNCTION public.close_gap_action_r1740(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_expertise_gap_actions_r1740
  SET status = 'closed', updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_gap_action_r1740',
          jsonb_build_object('id', p_id));
END;
$$;

-- RPC 6: top_experts_per_category
CREATE OR REPLACE FUNCTION public.top_experts_per_category_r1740()
RETURNS TABLE (
  equipment_category text,
  engineer_user_id uuid,
  engineer_email text,
  expertise_level int,
  years_of_experience int,
  certifications_count int,
  last_repair_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ranked AS (
    SELECT
      e.equipment_category,
      e.engineer_user_id,
      p.email::text AS engineer_email,
      e.expertise_level,
      e.years_of_experience,
      e.certifications_count,
      e.last_repair_at,
      ROW_NUMBER() OVER (PARTITION BY e.equipment_category ORDER BY e.expertise_level DESC, e.years_of_experience DESC) AS rn
    FROM public.engineer_equipment_expertise_r1740 e
    LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  )
  SELECT r.equipment_category, r.engineer_user_id, r.engineer_email, r.expertise_level, r.years_of_experience, r.certifications_count, r.last_repair_at
  FROM ranked r
  WHERE r.rn <= 3
  ORDER BY r.equipment_category, r.expertise_level DESC
  LIMIT 200;
END;
$$;

-- RPC 7: expertise_gaps (categories with no/low expertise)
CREATE OR REPLACE FUNCTION public.expertise_gaps_r1740()
RETURNS TABLE (
  equipment_category text,
  engineer_count int,
  max_level int,
  avg_level numeric,
  experts_count int,
  open_gap_actions int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.equipment_category,
    (COUNT(*))::int AS engineer_count,
    (MAX(e.expertise_level))::int AS max_level,
    ROUND(AVG(e.expertise_level)::numeric, 2) AS avg_level,
    (COUNT(*) FILTER (WHERE e.expertise_level >= 8))::int AS experts_count,
    (SELECT COUNT(*) FILTER (WHERE g.status <> 'closed') FROM public.engineer_expertise_gap_actions_r1740 g
       JOIN public.engineer_equipment_expertise_r1740 e2 ON e2.id = g.expertise_id
       WHERE e2.equipment_category = e.equipment_category)::int AS open_gap_actions
  FROM public.engineer_equipment_expertise_r1740 e
  GROUP BY e.equipment_category
  ORDER BY (COUNT(*) FILTER (WHERE e.expertise_level >= 8))::int ASC, AVG(e.expertise_level) ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_expertise_r1740() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_expertise_r1740(uuid, text, int, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_gap_actions_r1740() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_gap_action_r1740(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_gap_action_r1740(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_experts_per_category_r1740() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expertise_gaps_r1740() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_expertise_r1740() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_expertise_r1740(uuid, text, int, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_gap_actions_r1740() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_gap_action_r1740(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_gap_action_r1740(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_experts_per_category_r1740() TO authenticated;
GRANT EXECUTE ON FUNCTION public.expertise_gaps_r1740() TO authenticated;

COMMIT;