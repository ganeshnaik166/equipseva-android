BEGIN;

-- ============================================================================
-- Round 1970 — Founder External Counsel Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_external_counsel_r1970 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  counsel_name text NOT NULL,
  counsel_type text NOT NULL CHECK (counsel_type IN ('legal','tax','regulatory','m_and_a','employment','ip','compliance')),
  monthly_retainer_rupees bigint NOT NULL DEFAULT 0,
  engagement_start_date date,
  engagement_end_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','concluded','replaced')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_counsel_engagement_log_r1970 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  counsel_id uuid NOT NULL REFERENCES public.founder_external_counsel_r1970(id) ON DELETE CASCADE,
  engagement_type text NOT NULL CHECK (engagement_type IN ('matter_opened','advice_given','billing_received','scope_extended','escalation')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  billable_hours int NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_counsel_r1970_status ON public.founder_external_counsel_r1970(status);
CREATE INDEX IF NOT EXISTS idx_counsel_r1970_type ON public.founder_external_counsel_r1970(counsel_type);
CREATE INDEX IF NOT EXISTS idx_counsel_log_r1970_counsel ON public.founder_counsel_engagement_log_r1970(counsel_id);
CREATE INDEX IF NOT EXISTS idx_counsel_log_r1970_taken ON public.founder_counsel_engagement_log_r1970(taken_at DESC);

ALTER TABLE public.founder_external_counsel_r1970 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_counsel_engagement_log_r1970 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_counsel_r1970_all ON public.founder_external_counsel_r1970;
CREATE POLICY founder_counsel_r1970_all ON public.founder_external_counsel_r1970
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_counsel_log_r1970_all ON public.founder_counsel_engagement_log_r1970;
CREATE POLICY founder_counsel_log_r1970_all ON public.founder_counsel_engagement_log_r1970
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1. list_counsel
CREATE OR REPLACE FUNCTION public.list_counsel_r1970()
RETURNS TABLE (
  id uuid,
  counsel_name text,
  counsel_type text,
  monthly_retainer_rupees bigint,
  engagement_start_date date,
  engagement_end_date date,
  status text,
  captured_at timestamptz
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
  SELECT c.id, c.counsel_name, c.counsel_type, c.monthly_retainer_rupees,
         c.engagement_start_date, c.engagement_end_date, c.status, c.captured_at
  FROM public.founder_external_counsel_r1970 c
  ORDER BY c.captured_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_counsel
CREATE OR REPLACE FUNCTION public.log_counsel_r1970(
  p_counsel_name text,
  p_counsel_type text,
  p_monthly_retainer_rupees bigint,
  p_engagement_start_date date,
  p_engagement_end_date date,
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

  INSERT INTO public.founder_external_counsel_r1970(
    counsel_name, counsel_type, monthly_retainer_rupees,
    engagement_start_date, engagement_end_date, status
  ) VALUES (
    p_counsel_name, p_counsel_type, COALESCE(p_monthly_retainer_rupees, 0),
    p_engagement_start_date, p_engagement_end_date, COALESCE(p_status, 'active')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_counsel_r1970',
          jsonb_build_object('id', v_id, 'counsel_name', p_counsel_name, 'counsel_type', p_counsel_type));

  RETURN v_id;
END;
$$;

-- 3. list_engagements
CREATE OR REPLACE FUNCTION public.list_engagements_r1970()
RETURNS TABLE (
  id uuid,
  counsel_id uuid,
  counsel_name text,
  engagement_type text,
  taken_at timestamptz,
  by_email text,
  billable_hours int,
  notes_md text
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
  SELECT l.id, l.counsel_id, c.counsel_name, l.engagement_type,
         l.taken_at, l.by_email, l.billable_hours, l.notes_md
  FROM public.founder_counsel_engagement_log_r1970 l
  JOIN public.founder_external_counsel_r1970 c ON c.id = l.counsel_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

-- 4. log_engagement
CREATE OR REPLACE FUNCTION public.log_engagement_r1970(
  p_counsel_id uuid,
  p_engagement_type text,
  p_by_email text,
  p_billable_hours int,
  p_notes_md text
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

  INSERT INTO public.founder_counsel_engagement_log_r1970(
    counsel_id, engagement_type, by_email, billable_hours, notes_md
  ) VALUES (
    p_counsel_id, p_engagement_type, p_by_email,
    COALESCE(p_billable_hours, 0), p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_engagement_r1970',
          jsonb_build_object('id', v_id, 'counsel_id', p_counsel_id, 'engagement_type', p_engagement_type));

  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_counsel_status_r1970(
  p_counsel_id uuid,
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

  UPDATE public.founder_external_counsel_r1970
     SET status = p_status, updated_at = now()
   WHERE id = p_counsel_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_counsel_status_r1970',
          jsonb_build_object('counsel_id', p_counsel_id, 'status', p_status));
END;
$$;

-- 6. by_type
CREATE OR REPLACE FUNCTION public.counsel_by_type_r1970()
RETURNS TABLE (
  counsel_type text,
  total_count bigint,
  active_count bigint,
  total_monthly_retainer_rupees bigint
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
  SELECT c.counsel_type,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE c.status = 'active')::bigint AS active_count,
         COALESCE(SUM(c.monthly_retainer_rupees) FILTER (WHERE c.status = 'active'), 0)::bigint AS total_monthly_retainer_rupees
  FROM public.founder_external_counsel_r1970 c
  GROUP BY c.counsel_type
  ORDER BY total_count DESC;
END;
$$;

-- 7. recent_engagements
CREATE OR REPLACE FUNCTION public.recent_engagements_r1970(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  counsel_id uuid,
  counsel_name text,
  counsel_type text,
  engagement_type text,
  taken_at timestamptz,
  billable_hours int,
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
  SELECT l.id, l.counsel_id, c.counsel_name, c.counsel_type,
         l.engagement_type, l.taken_at, l.billable_hours, l.by_email
  FROM public.founder_counsel_engagement_log_r1970 l
  JOIN public.founder_external_counsel_r1970 c ON c.id = l.counsel_id
  WHERE l.taken_at >= now() - (COALESCE(p_days, 30) || ' days')::interval
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_counsel_r1970() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_counsel_r1970(text, text, bigint, date, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_engagements_r1970() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_engagement_r1970(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_counsel_status_r1970(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.counsel_by_type_r1970() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_engagements_r1970(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_counsel_r1970() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_counsel_r1970(text, text, bigint, date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_engagements_r1970() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_engagement_r1970(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_counsel_status_r1970(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.counsel_by_type_r1970() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_engagements_r1970(int) TO authenticated;

COMMIT;
