BEGIN;

-- ============================================================================
-- Round 1710: Founder Weekly Customer Calls Log
-- Founder mandatory 5 customer calls/week tracker with sentiment + actions
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_customer_calls_r1710 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  call_date timestamptz NOT NULL DEFAULT now(),
  duration_minutes int NOT NULL DEFAULT 0,
  key_quotes_md text,
  action_items_md text,
  sentiment text NOT NULL CHECK (sentiment IN ('very_positive','positive','neutral','negative','concerned')),
  follow_up_needed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcc_r1710_week ON public.founder_customer_calls_r1710(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_fcc_r1710_hospital ON public.founder_customer_calls_r1710(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_fcc_r1710_sentiment ON public.founder_customer_calls_r1710(sentiment);

CREATE TABLE IF NOT EXISTS public.founder_customer_call_action_items_r1710 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id uuid NOT NULL REFERENCES public.founder_customer_calls_r1710(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  done_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fccai_r1710_call ON public.founder_customer_call_action_items_r1710(call_id);
CREATE INDEX IF NOT EXISTS idx_fccai_r1710_status ON public.founder_customer_call_action_items_r1710(status);
CREATE INDEX IF NOT EXISTS idx_fccai_r1710_due ON public.founder_customer_call_action_items_r1710(due_date);

ALTER TABLE public.founder_customer_calls_r1710 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_customer_call_action_items_r1710 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcc_r1710_founder_all ON public.founder_customer_calls_r1710;
CREATE POLICY fcc_r1710_founder_all ON public.founder_customer_calls_r1710
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fccai_r1710_founder_all ON public.founder_customer_call_action_items_r1710;
CREATE POLICY fccai_r1710_founder_all ON public.founder_customer_call_action_items_r1710
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs (7)
-- ============================================================================

-- 1) list_calls
CREATE OR REPLACE FUNCTION public.fcc_r1710_list_calls(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  week_start date,
  hospital_user_id uuid,
  hospital_name text,
  hospital_city text,
  call_date timestamptz,
  duration_minutes int,
  sentiment text,
  follow_up_needed boolean,
  key_quotes_md text,
  action_items_md text,
  open_actions int,
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
    c.id,
    c.week_start,
    c.hospital_user_id,
    COALESCE(o.name, p.full_name, p.email, 'Unknown')::text AS hospital_name,
    COALESCE(o.city, '')::text AS hospital_city,
    c.call_date,
    c.duration_minutes,
    c.sentiment,
    c.follow_up_needed,
    c.key_quotes_md,
    c.action_items_md,
    (SELECT (COUNT(*))::int FROM public.founder_customer_call_action_items_r1710 a WHERE a.call_id = c.id AND a.status = 'open') AS open_actions,
    c.created_at
  FROM public.founder_customer_calls_r1710 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY c.call_date DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- 2) log_call
CREATE OR REPLACE FUNCTION public.fcc_r1710_log_call(
  p_hospital_user_id uuid,
  p_call_date timestamptz,
  p_duration_minutes int,
  p_key_quotes_md text,
  p_action_items_md text,
  p_sentiment text,
  p_follow_up_needed boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_week date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_week := date_trunc('week', COALESCE(p_call_date, now()))::date;
  INSERT INTO public.founder_customer_calls_r1710(
    week_start, hospital_user_id, call_date, duration_minutes,
    key_quotes_md, action_items_md, sentiment, follow_up_needed
  ) VALUES (
    v_week, p_hospital_user_id, COALESCE(p_call_date, now()), COALESCE(p_duration_minutes, 0),
    p_key_quotes_md, p_action_items_md, p_sentiment, COALESCE(p_follow_up_needed, false)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fcc_r1710_log_call',
    jsonb_build_object('call_id', v_id, 'hospital_user_id', p_hospital_user_id, 'sentiment', p_sentiment));
  RETURN v_id;
END;
$$;

-- 3) list_actions
CREATE OR REPLACE FUNCTION public.fcc_r1710_list_actions(p_status text DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  call_id uuid,
  hospital_name text,
  action_text text,
  owner_email text,
  due_date date,
  status text,
  done_at timestamptz,
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
    a.id,
    a.call_id,
    COALESCE(o.name, p.full_name, p.email, 'Unknown')::text AS hospital_name,
    a.action_text,
    a.owner_email,
    a.due_date,
    a.status,
    a.done_at,
    a.created_at
  FROM public.founder_customer_call_action_items_r1710 a
  JOIN public.founder_customer_calls_r1710 c ON c.id = a.call_id
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE (p_status IS NULL OR a.status = p_status)
  ORDER BY (a.status = 'open') DESC, a.due_date ASC NULLS LAST, a.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- 4) add_action
CREATE OR REPLACE FUNCTION public.fcc_r1710_add_action(
  p_call_id uuid,
  p_action_text text,
  p_owner_email text,
  p_due_date date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_customer_call_action_items_r1710(call_id, action_text, owner_email, due_date, status)
  VALUES (p_call_id, p_action_text, p_owner_email, p_due_date, 'open')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fcc_r1710_add_action',
    jsonb_build_object('action_id', v_id, 'call_id', p_call_id, 'owner_email', p_owner_email));
  RETURN v_id;
END;
$$;

-- 5) complete_action
CREATE OR REPLACE FUNCTION public.fcc_r1710_complete_action(p_action_id uuid, p_status text DEFAULT 'done')
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('done','dropped') THEN RAISE EXCEPTION 'invalid status'; END IF;
  UPDATE public.founder_customer_call_action_items_r1710
     SET status = p_status,
         done_at = CASE WHEN p_status = 'done' THEN now() ELSE done_at END,
         updated_at = now()
   WHERE id = p_action_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fcc_r1710_complete_action',
    jsonb_build_object('action_id', p_action_id, 'status', p_status));
  RETURN true;
END;
$$;

-- 6) weekly_target_progress
CREATE OR REPLACE FUNCTION public.fcc_r1710_weekly_target_progress(p_weeks int DEFAULT 12)
RETURNS TABLE (
  week_start date,
  calls_logged int,
  target int,
  on_target boolean,
  unique_hospitals int,
  avg_duration_minutes int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.week_start,
    (COUNT(*))::int AS calls_logged,
    5 AS target,
    (COUNT(*) >= 5) AS on_target,
    (COUNT(DISTINCT c.hospital_user_id))::int AS unique_hospitals,
    COALESCE(AVG(c.duration_minutes), 0)::int AS avg_duration_minutes
  FROM public.founder_customer_calls_r1710 c
  WHERE c.week_start >= (date_trunc('week', now()) - (GREATEST(p_weeks, 1) || ' weeks')::interval)::date
  GROUP BY c.week_start
  ORDER BY c.week_start DESC;
END;
$$;

-- 7) sentiment_summary
CREATE OR REPLACE FUNCTION public.fcc_r1710_sentiment_summary(p_weeks int DEFAULT 4)
RETURNS TABLE (
  sentiment text,
  call_count int,
  pct_of_total numeric,
  hospitals_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT (COUNT(*))::int INTO v_total
  FROM public.founder_customer_calls_r1710 c
  WHERE c.week_start >= (date_trunc('week', now()) - (GREATEST(p_weeks, 1) || ' weeks')::interval)::date;

  RETURN QUERY
  SELECT
    c.sentiment,
    (COUNT(*))::int AS call_count,
    CASE WHEN v_total > 0 THEN ROUND((COUNT(*)::numeric * 100.0) / v_total, 1) ELSE 0 END AS pct_of_total,
    (COUNT(DISTINCT c.hospital_user_id))::int AS hospitals_count
  FROM public.founder_customer_calls_r1710 c
  WHERE c.week_start >= (date_trunc('week', now()) - (GREATEST(p_weeks, 1) || ' weeks')::interval)::date
  GROUP BY c.sentiment
  ORDER BY call_count DESC;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.fcc_r1710_list_calls(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fcc_r1710_log_call(uuid, timestamptz, int, text, text, text, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fcc_r1710_list_actions(text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fcc_r1710_add_action(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fcc_r1710_complete_action(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fcc_r1710_weekly_target_progress(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fcc_r1710_sentiment_summary(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fcc_r1710_list_calls(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fcc_r1710_log_call(uuid, timestamptz, int, text, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fcc_r1710_list_actions(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fcc_r1710_add_action(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fcc_r1710_complete_action(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fcc_r1710_weekly_target_progress(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fcc_r1710_sentiment_summary(int) TO authenticated;

COMMIT;