BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_switching_signals_r1679 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  integration_count int NOT NULL DEFAULT 0 CHECK (integration_count >= 0),
  custom_contract_clauses int NOT NULL DEFAULT 0 CHECK (custom_contract_clauses >= 0),
  staff_trained_count int NOT NULL DEFAULT 0 CHECK (staff_trained_count >= 0),
  lockin_score int NOT NULL DEFAULT 0 CHECK (lockin_score BETWEEN 0 AND 100),
  assessed_at timestamptz NOT NULL DEFAULT now(),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hosp_sw_sig_r1679_hosp_idx
  ON public.hospital_switching_signals_r1679(hospital_user_id, assessed_at DESC);
CREATE INDEX IF NOT EXISTS hosp_sw_sig_r1679_score_idx
  ON public.hospital_switching_signals_r1679(lockin_score DESC);

CREATE TABLE IF NOT EXISTS public.hospital_switching_actions_r1679 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN (
    'integration_added','contract_clause_added','staff_trained',
    'process_embedded','data_migrated','workflow_customized','other'
  )),
  completed_at timestamptz NOT NULL DEFAULT now(),
  weight int NOT NULL DEFAULT 5 CHECK (weight BETWEEN 1 AND 20),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hosp_sw_act_r1679_hosp_idx
  ON public.hospital_switching_actions_r1679(hospital_user_id, completed_at DESC);
CREATE INDEX IF NOT EXISTS hosp_sw_act_r1679_type_idx
  ON public.hospital_switching_actions_r1679(action_type);

ALTER TABLE public.hospital_switching_signals_r1679 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_switching_actions_r1679 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hosp_sw_sig_r1679_founder_all ON public.hospital_switching_signals_r1679;
CREATE POLICY hosp_sw_sig_r1679_founder_all
  ON public.hospital_switching_signals_r1679
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hosp_sw_act_r1679_founder_all ON public.hospital_switching_actions_r1679;
CREATE POLICY hosp_sw_act_r1679_founder_all
  ON public.hospital_switching_actions_r1679
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_signals
CREATE OR REPLACE FUNCTION public.list_signals_r1679(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  city text,
  integration_count int,
  custom_contract_clauses int,
  staff_trained_count int,
  lockin_score int,
  assessed_at timestamptz,
  note text
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
  SELECT s.id,
         s.hospital_user_id,
         COALESCE(o.name, p.full_name, 'Hospital ' || left(s.hospital_user_id::text, 8)) AS hospital_name,
         o.city,
         s.integration_count,
         s.custom_contract_clauses,
         s.staff_trained_count,
         s.lockin_score,
         s.assessed_at,
         s.note
  FROM public.hospital_switching_signals_r1679 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.assessed_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- 2. record_signal
CREATE OR REPLACE FUNCTION public.record_signal_r1679(
  p_hospital_user_id uuid,
  p_integration_count int,
  p_custom_contract_clauses int,
  p_staff_trained_count int,
  p_lockin_score int,
  p_note text DEFAULT NULL
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

  INSERT INTO public.hospital_switching_signals_r1679(
    hospital_user_id, integration_count, custom_contract_clauses,
    staff_trained_count, lockin_score, note
  ) VALUES (
    p_hospital_user_id,
    GREATEST(0, COALESCE(p_integration_count, 0)),
    GREATEST(0, COALESCE(p_custom_contract_clauses, 0)),
    GREATEST(0, COALESCE(p_staff_trained_count, 0)),
    GREATEST(0, LEAST(100, COALESCE(p_lockin_score, 0))),
    p_note
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1679_record_signal',
    jsonb_build_object(
      'signal_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'lockin_score', p_lockin_score
    )
  );

  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1679(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  action_type text,
  completed_at timestamptz,
  weight int,
  note text
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
  SELECT a.id,
         a.hospital_user_id,
         COALESCE(o.name, p.full_name, 'Hospital ' || left(a.hospital_user_id::text, 8)) AS hospital_name,
         a.action_type,
         a.completed_at,
         a.weight,
         a.note
  FROM public.hospital_switching_actions_r1679 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY a.completed_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r1679(
  p_hospital_user_id uuid,
  p_action_type text,
  p_weight int DEFAULT 5,
  p_note text DEFAULT NULL
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

  IF p_action_type NOT IN (
    'integration_added','contract_clause_added','staff_trained',
    'process_embedded','data_migrated','workflow_customized','other'
  ) THEN
    RAISE EXCEPTION 'invalid action_type';
  END IF;

  INSERT INTO public.hospital_switching_actions_r1679(
    hospital_user_id, action_type, weight, note
  ) VALUES (
    p_hospital_user_id,
    p_action_type,
    GREATEST(1, LEAST(20, COALESCE(p_weight, 5))),
    p_note
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1679_log_action',
    jsonb_build_object(
      'action_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'action_type', p_action_type,
      'weight', p_weight
    )
  );

  RETURN v_id;
END;
$$;

-- 5. top_locked_in_hospitals
CREATE OR REPLACE FUNCTION public.top_locked_in_hospitals_r1679(p_limit int DEFAULT 20)
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_name text,
  city text,
  latest_lockin_score int,
  latest_assessed_at timestamptz,
  total_actions int,
  total_action_weight int
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
  WITH latest AS (
    SELECT DISTINCT ON (s.hospital_user_id)
      s.hospital_user_id, s.lockin_score, s.assessed_at
    FROM public.hospital_switching_signals_r1679 s
    ORDER BY s.hospital_user_id, s.assessed_at DESC
  ),
  acts AS (
    SELECT a.hospital_user_id,
           (COUNT(*))::int AS total_actions,
           (COALESCE(SUM(a.weight), 0))::int AS total_action_weight
    FROM public.hospital_switching_actions_r1679 a
    GROUP BY a.hospital_user_id
  )
  SELECT l.hospital_user_id,
         COALESCE(o.name, p.full_name, 'Hospital ' || left(l.hospital_user_id::text, 8)) AS hospital_name,
         o.city,
         l.lockin_score AS latest_lockin_score,
         l.assessed_at AS latest_assessed_at,
         COALESCE(acts.total_actions, 0) AS total_actions,
         COALESCE(acts.total_action_weight, 0) AS total_action_weight
  FROM latest l
  LEFT JOIN public.profiles p ON p.id = l.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  LEFT JOIN acts ON acts.hospital_user_id = l.hospital_user_id
  ORDER BY l.lockin_score DESC, COALESCE(acts.total_action_weight, 0) DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

-- 6. switching_cost_summary
CREATE OR REPLACE FUNCTION public.switching_cost_summary_r1679()
RETURNS TABLE (
  hospitals_assessed int,
  avg_lockin_score numeric,
  high_lockin_count int,
  medium_lockin_count int,
  low_lockin_count int,
  total_actions int,
  total_weight int,
  signals_last_30d int
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
  WITH latest AS (
    SELECT DISTINCT ON (s.hospital_user_id)
      s.hospital_user_id, s.lockin_score, s.assessed_at
    FROM public.hospital_switching_signals_r1679 s
    ORDER BY s.hospital_user_id, s.assessed_at DESC
  )
  SELECT
    (COUNT(*))::int AS hospitals_assessed,
    ROUND(AVG(latest.lockin_score)::numeric, 1) AS avg_lockin_score,
    (COUNT(*) FILTER (WHERE latest.lockin_score >= 70))::int AS high_lockin_count,
    (COUNT(*) FILTER (WHERE latest.lockin_score BETWEEN 40 AND 69))::int AS medium_lockin_count,
    (COUNT(*) FILTER (WHERE latest.lockin_score < 40))::int AS low_lockin_count,
    (SELECT (COUNT(*))::int FROM public.hospital_switching_actions_r1679) AS total_actions,
    (SELECT (COALESCE(SUM(weight), 0))::int FROM public.hospital_switching_actions_r1679) AS total_weight,
    (SELECT (COUNT(*))::int FROM public.hospital_switching_signals_r1679
       WHERE assessed_at >= now() - interval '30 days') AS signals_last_30d
  FROM latest;
END;
$$;

-- 7. low_lockin_at_risk
CREATE OR REPLACE FUNCTION public.low_lockin_at_risk_r1679(
  p_threshold int DEFAULT 40,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_name text,
  city text,
  latest_lockin_score int,
  latest_assessed_at timestamptz,
  days_since_assessment int,
  risk_band text
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
  WITH latest AS (
    SELECT DISTINCT ON (s.hospital_user_id)
      s.hospital_user_id, s.lockin_score, s.assessed_at
    FROM public.hospital_switching_signals_r1679 s
    ORDER BY s.hospital_user_id, s.assessed_at DESC
  )
  SELECT l.hospital_user_id,
         COALESCE(o.name, p.full_name, 'Hospital ' || left(l.hospital_user_id::text, 8)) AS hospital_name,
         o.city,
         l.lockin_score AS latest_lockin_score,
         l.assessed_at AS latest_assessed_at,
         GREATEST(0, EXTRACT(day FROM (now() - l.assessed_at))::int) AS days_since_assessment,
         CASE
           WHEN l.lockin_score < 20 THEN 'critical'
           WHEN l.lockin_score < 30 THEN 'high'
           WHEN l.lockin_score < p_threshold THEN 'medium'
           ELSE 'low'
         END AS risk_band
  FROM latest l
  LEFT JOIN public.profiles p ON p.id = l.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE l.lockin_score < GREATEST(1, LEAST(100, COALESCE(p_threshold, 40)))
  ORDER BY l.lockin_score ASC, l.assessed_at ASC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_signals_r1679(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_signal_r1679(uuid, int, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1679(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1679(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_locked_in_hospitals_r1679(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.switching_cost_summary_r1679() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.low_lockin_at_risk_r1679(int, int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_signals_r1679(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_signal_r1679(uuid, int, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1679(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1679(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_locked_in_hospitals_r1679(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.switching_cost_summary_r1679() TO authenticated;
GRANT EXECUTE ON FUNCTION public.low_lockin_at_risk_r1679(int, int) TO authenticated;

COMMIT;