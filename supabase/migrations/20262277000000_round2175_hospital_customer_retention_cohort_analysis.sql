BEGIN;

-- ============================================================================
-- Round 2175 — Hospital Customer Retention Cohort Analysis
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_customer_retention_cohort_r2175 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cohort_label text NOT NULL,
  cohort_start_month text NOT NULL,
  customers_started int NOT NULL DEFAULT 0,
  customers_remaining_30d int NOT NULL DEFAULT 0,
  customers_remaining_90d int NOT NULL DEFAULT 0,
  customers_remaining_365d int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'tracking' CHECK (status IN ('tracking','closed','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_cohort_action_log_r2175 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cohort_id uuid NOT NULL REFERENCES public.hospital_customer_retention_cohort_r2175(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('tracked','intervention','celebrated','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_retention_cohort_r2175 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_cohort_action_log_r2175 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hospital_customer_retention_cohort_r2175 ON public.hospital_customer_retention_cohort_r2175;
CREATE POLICY founder_all_hospital_customer_retention_cohort_r2175
  ON public.hospital_customer_retention_cohort_r2175
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hospital_cohort_action_log_r2175 ON public.hospital_cohort_action_log_r2175;
CREATE POLICY founder_all_hospital_cohort_action_log_r2175
  ON public.hospital_cohort_action_log_r2175
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_cohorts
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_cohorts_r2175();
CREATE OR REPLACE FUNCTION public.list_cohorts_r2175()
RETURNS TABLE (
  id uuid,
  cohort_label text,
  cohort_start_month text,
  customers_started int,
  customers_remaining_30d int,
  customers_remaining_90d int,
  customers_remaining_365d int,
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
  SELECT c.id, c.cohort_label, c.cohort_start_month, c.customers_started,
         c.customers_remaining_30d, c.customers_remaining_90d, c.customers_remaining_365d,
         c.status, c.captured_at
  FROM public.hospital_customer_retention_cohort_r2175 c
  ORDER BY c.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_cohorts_r2175() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cohorts_r2175() TO authenticated;

-- ============================================================================
-- RPC 2: log_cohort
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_cohort_r2175(text, text, int, int, int, int);
CREATE OR REPLACE FUNCTION public.log_cohort_r2175(
  p_cohort_label text,
  p_cohort_start_month text,
  p_customers_started int,
  p_customers_remaining_30d int,
  p_customers_remaining_90d int,
  p_customers_remaining_365d int
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
  INSERT INTO public.hospital_customer_retention_cohort_r2175
    (cohort_label, cohort_start_month, customers_started, customers_remaining_30d,
     customers_remaining_90d, customers_remaining_365d)
  VALUES (p_cohort_label, p_cohort_start_month, p_customers_started,
          p_customers_remaining_30d, p_customers_remaining_90d, p_customers_remaining_365d)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cohort_r2175',
          jsonb_build_object('cohort_id', v_id, 'cohort_label', p_cohort_label));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_cohort_r2175(text, text, int, int, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_cohort_r2175(text, text, int, int, int, int) TO authenticated;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_actions_r2175(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2175(p_cohort_id uuid)
RETURNS TABLE (
  id uuid,
  cohort_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
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
  SELECT a.id, a.cohort_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_cohort_action_log_r2175 a
  WHERE a.cohort_id = p_cohort_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2175(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2175(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_action_r2175(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2175(
  p_cohort_id uuid,
  p_action_type text,
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
  INSERT INTO public.hospital_cohort_action_log_r2175 (cohort_id, action_type, by_email, notes_md)
  VALUES (p_cohort_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2175',
          jsonb_build_object('action_id', v_id, 'cohort_id', p_cohort_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2175(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2175(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_status_r2175(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2175(
  p_cohort_id uuid,
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
  IF p_status NOT IN ('tracking','closed','superseded') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.hospital_customer_retention_cohort_r2175
  SET status = p_status, updated_at = now()
  WHERE id = p_cohort_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2175',
          jsonb_build_object('cohort_id', p_cohort_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2175(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2175(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: declining_cohorts
-- ============================================================================
DROP FUNCTION IF EXISTS public.declining_cohorts_r2175();
CREATE OR REPLACE FUNCTION public.declining_cohorts_r2175()
RETURNS TABLE (
  id uuid,
  cohort_label text,
  cohort_start_month text,
  customers_started int,
  customers_remaining_30d int,
  customers_remaining_90d int,
  customers_remaining_365d int,
  retention_365_pct numeric,
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
  SELECT c.id, c.cohort_label, c.cohort_start_month, c.customers_started,
         c.customers_remaining_30d, c.customers_remaining_90d, c.customers_remaining_365d,
         CASE WHEN c.customers_started = 0 THEN 0
              ELSE round((c.customers_remaining_365d::numeric / c.customers_started::numeric) * 100, 2)
         END AS retention_365_pct,
         c.status
  FROM public.hospital_customer_retention_cohort_r2175 c
  WHERE c.status = 'tracking'
    AND c.customers_started > 0
    AND (c.customers_remaining_365d::numeric / c.customers_started::numeric) < 0.5
  ORDER BY retention_365_pct ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.declining_cohorts_r2175() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.declining_cohorts_r2175() TO authenticated;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_actions_r2175();
CREATE OR REPLACE FUNCTION public.recent_actions_r2175()
RETURNS TABLE (
  id uuid,
  cohort_id uuid,
  cohort_label text,
  action_type text,
  taken_at timestamptz,
  by_email text,
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
  SELECT a.id, a.cohort_id, c.cohort_label, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_cohort_action_log_r2175 a
  JOIN public.hospital_customer_retention_cohort_r2175 c ON c.id = a.cohort_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2175() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2175() TO authenticated;

COMMIT;
