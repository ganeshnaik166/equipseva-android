BEGIN;

-- Table 1: customer discovery interviews
CREATE TABLE IF NOT EXISTS public.founder_customer_discovery_interviews_r2006 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  interview_with_name text NOT NULL,
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  interview_date date NOT NULL DEFAULT CURRENT_DATE,
  key_insights_md text,
  pain_points_md text,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed','follow_up_needed','closed_won','closed_lost')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcdi_r2006_date ON public.founder_customer_discovery_interviews_r2006(interview_date DESC);
CREATE INDEX IF NOT EXISTS idx_fcdi_r2006_status ON public.founder_customer_discovery_interviews_r2006(status);
CREATE INDEX IF NOT EXISTS idx_fcdi_r2006_hospital ON public.founder_customer_discovery_interviews_r2006(hospital_id);

ALTER TABLE public.founder_customer_discovery_interviews_r2006 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fcdi_r2006 ON public.founder_customer_discovery_interviews_r2006;
CREATE POLICY founder_all_fcdi_r2006 ON public.founder_customer_discovery_interviews_r2006
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: discovery insight log
CREATE TABLE IF NOT EXISTS public.founder_discovery_insight_log_r2006 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  interview_id uuid NOT NULL REFERENCES public.founder_customer_discovery_interviews_r2006(id) ON DELETE CASCADE,
  insight_category text NOT NULL CHECK (insight_category IN ('pricing','feature','competitive','relationship','process','customer_problem')),
  insight_md text NOT NULL,
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fdil_r2006_interview ON public.founder_discovery_insight_log_r2006(interview_id);
CREATE INDEX IF NOT EXISTS idx_fdil_r2006_category ON public.founder_discovery_insight_log_r2006(insight_category);
CREATE INDEX IF NOT EXISTS idx_fdil_r2006_taken ON public.founder_discovery_insight_log_r2006(taken_at DESC);

ALTER TABLE public.founder_discovery_insight_log_r2006 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fdil_r2006 ON public.founder_discovery_insight_log_r2006;
CREATE POLICY founder_all_fdil_r2006 ON public.founder_discovery_insight_log_r2006
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_interviews
CREATE OR REPLACE FUNCTION public.list_interviews_r2006()
RETURNS TABLE (
  id uuid,
  interview_with_name text,
  hospital_id uuid,
  hospital_name text,
  interview_date date,
  key_insights_md text,
  pain_points_md text,
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
    SELECT i.id, i.interview_with_name, i.hospital_id, o.name AS hospital_name,
           i.interview_date, i.key_insights_md, i.pain_points_md, i.status, i.created_at
    FROM public.founder_customer_discovery_interviews_r2006 i
    LEFT JOIN public.organizations o ON o.id = i.hospital_id
    ORDER BY i.interview_date DESC, i.created_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: log_interview
CREATE OR REPLACE FUNCTION public.log_interview_r2006(
  p_interview_with_name text,
  p_hospital_id uuid,
  p_interview_date date,
  p_key_insights_md text,
  p_pain_points_md text,
  p_status text
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
  INSERT INTO public.founder_customer_discovery_interviews_r2006(
    interview_with_name, hospital_id, interview_date, key_insights_md, pain_points_md, status
  ) VALUES (
    p_interview_with_name, p_hospital_id, COALESCE(p_interview_date, CURRENT_DATE),
    p_key_insights_md, p_pain_points_md, COALESCE(p_status, 'completed')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(id, actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (gen_random_uuid(), auth.uid(), (auth.jwt()->>'email'), 'log_interview_r2006',
          jsonb_build_object('interview_id', v_id, 'name', p_interview_with_name, 'status', p_status), now());

  RETURN v_id;
END;
$$;

-- RPC 3: list_insights
CREATE OR REPLACE FUNCTION public.list_insights_r2006(p_interview_id uuid)
RETURNS TABLE (
  id uuid,
  interview_id uuid,
  insight_category text,
  insight_md text,
  taken_at timestamptz,
  by_email text
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
    SELECT l.id, l.interview_id, l.insight_category, l.insight_md, l.taken_at, l.by_email
    FROM public.founder_discovery_insight_log_r2006 l
    WHERE l.interview_id = p_interview_id
    ORDER BY l.taken_at DESC
    LIMIT 200;
END;
$$;

-- RPC 4: log_insight
CREATE OR REPLACE FUNCTION public.log_insight_r2006(
  p_interview_id uuid,
  p_insight_category text,
  p_insight_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_discovery_insight_log_r2006(
    interview_id, insight_category, insight_md, by_email
  ) VALUES (
    p_interview_id, p_insight_category, p_insight_md, v_email
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(id, actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (gen_random_uuid(), auth.uid(), v_email, 'log_insight_r2006',
          jsonb_build_object('insight_id', v_id, 'interview_id', p_interview_id, 'category', p_insight_category), now());

  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2006(
  p_interview_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_customer_discovery_interviews_r2006
  SET status = p_status, updated_at = now()
  WHERE id = p_interview_id;

  INSERT INTO public.founder_action_log(id, actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (gen_random_uuid(), auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2006',
          jsonb_build_object('interview_id', p_interview_id, 'status', p_status), now());
END;
$$;

-- RPC 6: top_insights (counts by category)
CREATE OR REPLACE FUNCTION public.top_insights_r2006()
RETURNS TABLE (
  insight_category text,
  insight_count bigint,
  latest_taken_at timestamptz
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
    SELECT l.insight_category, COUNT(*)::bigint AS insight_count, MAX(l.taken_at) AS latest_taken_at
    FROM public.founder_discovery_insight_log_r2006 l
    GROUP BY l.insight_category
    ORDER BY insight_count DESC;
END;
$$;

-- RPC 7: recent_insights
CREATE OR REPLACE FUNCTION public.recent_insights_r2006()
RETURNS TABLE (
  id uuid,
  interview_id uuid,
  interview_with_name text,
  insight_category text,
  insight_md text,
  taken_at timestamptz,
  by_email text
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
    SELECT l.id, l.interview_id, i.interview_with_name, l.insight_category, l.insight_md, l.taken_at, l.by_email
    FROM public.founder_discovery_insight_log_r2006 l
    JOIN public.founder_customer_discovery_interviews_r2006 i ON i.id = l.interview_id
    ORDER BY l.taken_at DESC
    LIMIT 50;
END;
$$;

-- REVOKE + GRANT
REVOKE EXECUTE ON FUNCTION public.list_interviews_r2006() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_interview_r2006(text, uuid, date, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_insights_r2006(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_insight_r2006(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2006(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_insights_r2006() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_insights_r2006() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_interviews_r2006() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_interview_r2006(text, uuid, date, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_insights_r2006(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_insight_r2006(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2006(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_insights_r2006() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_insights_r2006() TO authenticated;

COMMIT;
