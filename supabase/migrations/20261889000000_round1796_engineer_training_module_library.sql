BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_training_modules_r1796 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_name text NOT NULL,
  module_category text NOT NULL CHECK (module_category IN ('safety','equipment_specific','customer_service','business_skills','compliance')),
  duration_minutes int NOT NULL CHECK (duration_minutes >= 0),
  mandatory boolean NOT NULL DEFAULT false,
  refresh_interval_months int CHECK (refresh_interval_months IS NULL OR refresh_interval_months > 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','under_review')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etm_r1796_category ON public.engineer_training_modules_r1796(module_category);
CREATE INDEX IF NOT EXISTS idx_etm_r1796_status ON public.engineer_training_modules_r1796(status);
CREATE INDEX IF NOT EXISTS idx_etm_r1796_mandatory ON public.engineer_training_modules_r1796(mandatory);

CREATE TABLE IF NOT EXISTS public.engineer_module_completions_r1796 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id uuid NOT NULL REFERENCES public.engineer_training_modules_r1796(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  started_at timestamptz,
  completed_at timestamptz,
  score int CHECK (score IS NULL OR (score >= 0 AND score <= 100)),
  next_due_at timestamptz,
  status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','completed','expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emc_r1796_module ON public.engineer_module_completions_r1796(module_id);
CREATE INDEX IF NOT EXISTS idx_emc_r1796_engineer ON public.engineer_module_completions_r1796(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_emc_r1796_status ON public.engineer_module_completions_r1796(status);
CREATE INDEX IF NOT EXISTS idx_emc_r1796_due ON public.engineer_module_completions_r1796(next_due_at);

ALTER TABLE public.engineer_training_modules_r1796 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_module_completions_r1796 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS etm_r1796_founder ON public.engineer_training_modules_r1796;
CREATE POLICY etm_r1796_founder ON public.engineer_training_modules_r1796
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS emc_r1796_founder ON public.engineer_module_completions_r1796;
CREATE POLICY emc_r1796_founder ON public.engineer_module_completions_r1796
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_modules
CREATE OR REPLACE FUNCTION public.list_modules_r1796()
RETURNS TABLE (
  id uuid,
  module_name text,
  module_category text,
  duration_minutes int,
  mandatory boolean,
  refresh_interval_months int,
  status text,
  created_at timestamptz
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
    SELECT m.id, m.module_name, m.module_category, m.duration_minutes, m.mandatory,
           m.refresh_interval_months, m.status, m.created_at
    FROM public.engineer_training_modules_r1796 m
    ORDER BY m.created_at DESC
    LIMIT 500;
END;
$$;

-- 2. add_module
CREATE OR REPLACE FUNCTION public.add_module_r1796(
  p_module_name text,
  p_module_category text,
  p_duration_minutes int,
  p_mandatory boolean,
  p_refresh_interval_months int
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
  INSERT INTO public.engineer_training_modules_r1796(module_name, module_category, duration_minutes, mandatory, refresh_interval_months)
  VALUES (p_module_name, p_module_category, p_duration_minutes, COALESCE(p_mandatory, false), p_refresh_interval_months)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_module_r1796',
    jsonb_build_object('module_id', v_id, 'module_name', p_module_name, 'category', p_module_category));

  RETURN v_id;
END;
$$;

-- 3. list_completions
CREATE OR REPLACE FUNCTION public.list_completions_r1796(p_module_id uuid DEFAULT NULL, p_engineer_user_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  module_id uuid,
  module_name text,
  engineer_user_id uuid,
  engineer_email text,
  started_at timestamptz,
  completed_at timestamptz,
  score int,
  next_due_at timestamptz,
  status text
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
    SELECT c.id, c.module_id, m.module_name, c.engineer_user_id, p.email,
           c.started_at, c.completed_at, c.score, c.next_due_at, c.status
    FROM public.engineer_module_completions_r1796 c
    LEFT JOIN public.engineer_training_modules_r1796 m ON m.id = c.module_id
    LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
    WHERE (p_module_id IS NULL OR c.module_id = p_module_id)
      AND (p_engineer_user_id IS NULL OR c.engineer_user_id = p_engineer_user_id)
    ORDER BY c.created_at DESC
    LIMIT 500;
END;
$$;

-- 4. record_completion
CREATE OR REPLACE FUNCTION public.record_completion_r1796(
  p_module_id uuid,
  p_engineer_user_id uuid,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_score int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_refresh int;
  v_next_due timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT refresh_interval_months INTO v_refresh
  FROM public.engineer_training_modules_r1796
  WHERE id = p_module_id;

  IF p_status = 'completed' AND v_refresh IS NOT NULL AND p_completed_at IS NOT NULL THEN
    v_next_due := p_completed_at + (v_refresh || ' months')::interval;
  ELSE
    v_next_due := NULL;
  END IF;

  INSERT INTO public.engineer_module_completions_r1796(
    module_id, engineer_user_id, started_at, completed_at, score, next_due_at, status
  )
  VALUES (
    p_module_id, p_engineer_user_id, p_started_at, p_completed_at, p_score, v_next_due, COALESCE(p_status, 'in_progress')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_completion_r1796',
    jsonb_build_object('completion_id', v_id, 'module_id', p_module_id, 'engineer_user_id', p_engineer_user_id, 'status', p_status));

  RETURN v_id;
END;
$$;

-- 5. expiring_completions
CREATE OR REPLACE FUNCTION public.expiring_completions_r1796(p_days_ahead int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  module_id uuid,
  module_name text,
  engineer_user_id uuid,
  engineer_email text,
  completed_at timestamptz,
  next_due_at timestamptz,
  days_until_due int
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
    SELECT c.id, c.module_id, m.module_name, c.engineer_user_id, p.email,
           c.completed_at, c.next_due_at,
           GREATEST(0, EXTRACT(DAY FROM (c.next_due_at - now()))::int) AS days_until_due
    FROM public.engineer_module_completions_r1796 c
    LEFT JOIN public.engineer_training_modules_r1796 m ON m.id = c.module_id
    LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
    WHERE c.status = 'completed'
      AND c.next_due_at IS NOT NULL
      AND c.next_due_at BETWEEN now() AND now() + (p_days_ahead || ' days')::interval
    ORDER BY c.next_due_at ASC
    LIMIT 500;
END;
$$;

-- 6. module_completion_summary
CREATE OR REPLACE FUNCTION public.module_completion_summary_r1796()
RETURNS TABLE (
  module_id uuid,
  module_name text,
  module_category text,
  mandatory boolean,
  in_progress_count int,
  completed_count int,
  expired_count int,
  avg_score numeric
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
    SELECT m.id, m.module_name, m.module_category, m.mandatory,
           (COUNT(*) FILTER (WHERE c.status = 'in_progress'))::int,
           (COUNT(*) FILTER (WHERE c.status = 'completed'))::int,
           (COUNT(*) FILTER (WHERE c.status = 'expired'))::int,
           ROUND(AVG(c.score) FILTER (WHERE c.status = 'completed'), 2)
    FROM public.engineer_training_modules_r1796 m
    LEFT JOIN public.engineer_module_completions_r1796 c ON c.module_id = m.id
    GROUP BY m.id, m.module_name, m.module_category, m.mandatory
    ORDER BY m.module_name ASC;
END;
$$;

-- 7. overdue_engineers
CREATE OR REPLACE FUNCTION public.overdue_engineers_r1796()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  overdue_count int,
  oldest_overdue_at timestamptz,
  module_names text
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
    SELECT c.engineer_user_id,
           p.email,
           (COUNT(*))::int,
           MIN(c.next_due_at),
           STRING_AGG(DISTINCT m.module_name, ', ')
    FROM public.engineer_module_completions_r1796 c
    LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
    LEFT JOIN public.engineer_training_modules_r1796 m ON m.id = c.module_id
    WHERE (c.status = 'expired')
       OR (c.status = 'completed' AND c.next_due_at IS NOT NULL AND c.next_due_at < now())
    GROUP BY c.engineer_user_id, p.email
    ORDER BY MIN(c.next_due_at) ASC
    LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_modules_r1796() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_module_r1796(text, text, int, boolean, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_completions_r1796(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_completion_r1796(uuid, uuid, timestamptz, timestamptz, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_completions_r1796(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.module_completion_summary_r1796() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_engineers_r1796() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_modules_r1796() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_module_r1796(text, text, int, boolean, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_completions_r1796(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_completion_r1796(uuid, uuid, timestamptz, timestamptz, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_completions_r1796(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.module_completion_summary_r1796() TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_engineers_r1796() TO authenticated;

COMMIT;