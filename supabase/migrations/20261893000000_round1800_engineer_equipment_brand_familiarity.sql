BEGIN;

-- =========================================================================
-- Round 1800 — Engineer Equipment Brand Familiarity
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_brand_familiarity_r1800 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  brand_name text NOT NULL,
  familiarity_level text NOT NULL CHECK (familiarity_level IN ('expert','proficient','intermediate','beginner','no_exposure')),
  last_serviced_at timestamptz,
  total_repairs_count int NOT NULL DEFAULT 0,
  cert_obtained boolean NOT NULL DEFAULT false,
  cert_date date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, brand_name)
);

CREATE INDEX IF NOT EXISTS idx_ebf_r1800_engineer ON public.engineer_brand_familiarity_r1800(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ebf_r1800_brand ON public.engineer_brand_familiarity_r1800(brand_name);
CREATE INDEX IF NOT EXISTS idx_ebf_r1800_level ON public.engineer_brand_familiarity_r1800(familiarity_level);

CREATE TABLE IF NOT EXISTS public.engineer_brand_certification_attempts_r1800 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  familiarity_id uuid NOT NULL REFERENCES public.engineer_brand_familiarity_r1800(id) ON DELETE CASCADE,
  attempt_at timestamptz NOT NULL DEFAULT now(),
  passed boolean NOT NULL DEFAULT false,
  score int,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ebca_r1800_familiarity ON public.engineer_brand_certification_attempts_r1800(familiarity_id);
CREATE INDEX IF NOT EXISTS idx_ebca_r1800_attempt_at ON public.engineer_brand_certification_attempts_r1800(attempt_at DESC);

ALTER TABLE public.engineer_brand_familiarity_r1800 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_brand_certification_attempts_r1800 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ebf_r1800_founder ON public.engineer_brand_familiarity_r1800;
CREATE POLICY p_ebf_r1800_founder ON public.engineer_brand_familiarity_r1800
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_ebca_r1800_founder ON public.engineer_brand_certification_attempts_r1800;
CREATE POLICY p_ebca_r1800_founder ON public.engineer_brand_certification_attempts_r1800
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1 — list_familiarity
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_familiarity_r1800();
CREATE OR REPLACE FUNCTION public.list_familiarity_r1800()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  brand_name text,
  familiarity_level text,
  last_serviced_at timestamptz,
  total_repairs_count int,
  cert_obtained boolean,
  cert_date date,
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
  SELECT
    f.id,
    f.engineer_user_id,
    p.email AS engineer_email,
    f.brand_name,
    f.familiarity_level,
    f.last_serviced_at,
    f.total_repairs_count,
    f.cert_obtained,
    f.cert_date,
    f.created_at
  FROM public.engineer_brand_familiarity_r1800 f
  LEFT JOIN public.profiles p ON p.id = f.engineer_user_id
  ORDER BY f.brand_name ASC, f.familiarity_level ASC, f.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_familiarity_r1800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_familiarity_r1800() TO authenticated;

-- =========================================================================
-- RPC 2 — set_familiarity
-- =========================================================================
DROP FUNCTION IF EXISTS public.set_familiarity_r1800(uuid, text, text, boolean, date);
CREATE OR REPLACE FUNCTION public.set_familiarity_r1800(
  p_engineer_user_id uuid,
  p_brand_name text,
  p_level text,
  p_cert_obtained boolean DEFAULT false,
  p_cert_date date DEFAULT NULL
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

  INSERT INTO public.engineer_brand_familiarity_r1800
    (engineer_user_id, brand_name, familiarity_level, cert_obtained, cert_date)
  VALUES
    (p_engineer_user_id, p_brand_name, p_level, p_cert_obtained, p_cert_date)
  ON CONFLICT (engineer_user_id, brand_name) DO UPDATE
    SET familiarity_level = EXCLUDED.familiarity_level,
        cert_obtained = EXCLUDED.cert_obtained,
        cert_date = EXCLUDED.cert_date,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1800.set_familiarity',
    jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'brand_name', p_brand_name, 'level', p_level)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_familiarity_r1800(uuid, text, text, boolean, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_familiarity_r1800(uuid, text, text, boolean, date) TO authenticated;

-- =========================================================================
-- RPC 3 — list_attempts
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_attempts_r1800(uuid);
CREATE OR REPLACE FUNCTION public.list_attempts_r1800(p_familiarity_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  familiarity_id uuid,
  brand_name text,
  engineer_email text,
  attempt_at timestamptz,
  passed boolean,
  score int,
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
  SELECT
    a.id,
    a.familiarity_id,
    f.brand_name,
    p.email AS engineer_email,
    a.attempt_at,
    a.passed,
    a.score,
    a.notes
  FROM public.engineer_brand_certification_attempts_r1800 a
  JOIN public.engineer_brand_familiarity_r1800 f ON f.id = a.familiarity_id
  LEFT JOIN public.profiles p ON p.id = f.engineer_user_id
  WHERE (p_familiarity_id IS NULL OR a.familiarity_id = p_familiarity_id)
  ORDER BY a.attempt_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_attempts_r1800(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attempts_r1800(uuid) TO authenticated;

-- =========================================================================
-- RPC 4 — log_attempt
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_attempt_r1800(uuid, boolean, int, text);
CREATE OR REPLACE FUNCTION public.log_attempt_r1800(
  p_familiarity_id uuid,
  p_passed boolean,
  p_score int DEFAULT NULL,
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

  INSERT INTO public.engineer_brand_certification_attempts_r1800
    (familiarity_id, passed, score, notes)
  VALUES (p_familiarity_id, p_passed, p_score, p_notes)
  RETURNING id INTO v_id;

  IF p_passed THEN
    UPDATE public.engineer_brand_familiarity_r1800
      SET cert_obtained = true,
          cert_date = COALESCE(cert_date, current_date),
          updated_at = now()
      WHERE id = p_familiarity_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1800.log_attempt',
    jsonb_build_object('id', v_id, 'familiarity_id', p_familiarity_id, 'passed', p_passed, 'score', p_score)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_attempt_r1800(uuid, boolean, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_attempt_r1800(uuid, boolean, int, text) TO authenticated;

-- =========================================================================
-- RPC 5 — top_brand_experts
-- =========================================================================
DROP FUNCTION IF EXISTS public.top_brand_experts_r1800();
CREATE OR REPLACE FUNCTION public.top_brand_experts_r1800()
RETURNS TABLE (
  brand_name text,
  expert_count int,
  proficient_count int,
  certified_count int,
  sample_emails text
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
    f.brand_name,
    (COUNT(*) FILTER (WHERE f.familiarity_level = 'expert'))::int AS expert_count,
    (COUNT(*) FILTER (WHERE f.familiarity_level = 'proficient'))::int AS proficient_count,
    (COUNT(*) FILTER (WHERE f.cert_obtained = true))::int AS certified_count,
    string_agg(DISTINCT p.email, ', ') FILTER (WHERE f.familiarity_level = 'expert') AS sample_emails
  FROM public.engineer_brand_familiarity_r1800 f
  LEFT JOIN public.profiles p ON p.id = f.engineer_user_id
  GROUP BY f.brand_name
  ORDER BY expert_count DESC, certified_count DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_brand_experts_r1800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_brand_experts_r1800() TO authenticated;

-- =========================================================================
-- RPC 6 — no_coverage_brands
-- =========================================================================
DROP FUNCTION IF EXISTS public.no_coverage_brands_r1800();
CREATE OR REPLACE FUNCTION public.no_coverage_brands_r1800()
RETURNS TABLE (
  brand_name text,
  total_engineers int,
  experts_or_proficient int,
  coverage_gap_flag text
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
    f.brand_name,
    (COUNT(*))::int AS total_engineers,
    (COUNT(*) FILTER (WHERE f.familiarity_level IN ('expert','proficient')))::int AS experts_or_proficient,
    CASE
      WHEN (COUNT(*) FILTER (WHERE f.familiarity_level IN ('expert','proficient'))) = 0 THEN 'NO_COVERAGE'
      WHEN (COUNT(*) FILTER (WHERE f.familiarity_level IN ('expert','proficient'))) < 2 THEN 'THIN_COVERAGE'
      ELSE 'OK'
    END AS coverage_gap_flag
  FROM public.engineer_brand_familiarity_r1800 f
  GROUP BY f.brand_name
  HAVING (COUNT(*) FILTER (WHERE f.familiarity_level IN ('expert','proficient'))) < 2
  ORDER BY experts_or_proficient ASC, total_engineers DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.no_coverage_brands_r1800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.no_coverage_brands_r1800() TO authenticated;

-- =========================================================================
-- RPC 7 — certification_summary
-- =========================================================================
DROP FUNCTION IF EXISTS public.certification_summary_r1800();
CREATE OR REPLACE FUNCTION public.certification_summary_r1800()
RETURNS TABLE (
  total_rows int,
  certified_rows int,
  experts int,
  proficient int,
  intermediate int,
  beginner int,
  no_exposure int,
  total_attempts int,
  attempts_passed int,
  attempts_failed int
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
    (SELECT COUNT(*) FROM public.engineer_brand_familiarity_r1800)::int AS total_rows,
    (SELECT COUNT(*) FROM public.engineer_brand_familiarity_r1800 WHERE cert_obtained = true)::int AS certified_rows,
    (SELECT COUNT(*) FROM public.engineer_brand_familiarity_r1800 WHERE familiarity_level = 'expert')::int AS experts,
    (SELECT COUNT(*) FROM public.engineer_brand_familiarity_r1800 WHERE familiarity_level = 'proficient')::int AS proficient,
    (SELECT COUNT(*) FROM public.engineer_brand_familiarity_r1800 WHERE familiarity_level = 'intermediate')::int AS intermediate,
    (SELECT COUNT(*) FROM public.engineer_brand_familiarity_r1800 WHERE familiarity_level = 'beginner')::int AS beginner,
    (SELECT COUNT(*) FROM public.engineer_brand_familiarity_r1800 WHERE familiarity_level = 'no_exposure')::int AS no_exposure,
    (SELECT COUNT(*) FROM public.engineer_brand_certification_attempts_r1800)::int AS total_attempts,
    (SELECT COUNT(*) FROM public.engineer_brand_certification_attempts_r1800 WHERE passed = true)::int AS attempts_passed,
    (SELECT COUNT(*) FROM public.engineer_brand_certification_attempts_r1800 WHERE passed = false)::int AS attempts_failed;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.certification_summary_r1800() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.certification_summary_r1800() TO authenticated;

COMMIT;