BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_pick_errors_r2382 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  warehouse_code text NOT NULL,
  picked_at timestamptz NOT NULL DEFAULT now(),
  requested_part_sku text NOT NULL,
  picked_part_sku text NOT NULL,
  error_type text NOT NULL CHECK (error_type IN ('wrong_sku','wrong_quantity','wrong_variant','expired_stock','damaged','mislabeled_bin')),
  quantity_requested integer NOT NULL DEFAULT 1 CHECK (quantity_requested >= 0),
  quantity_picked integer NOT NULL DEFAULT 1 CHECK (quantity_picked >= 0),
  error_cost_rupees integer NOT NULL DEFAULT 0 CHECK (error_cost_rupees >= 0),
  detected_at timestamptz,
  detected_by text NOT NULL DEFAULT 'self' CHECK (detected_by IN ('self','engineer_at_site','hospital','qa_audit','customer')),
  caused_revisit boolean NOT NULL DEFAULT false,
  caused_delay_hours integer NOT NULL DEFAULT 0 CHECK (caused_delay_hours >= 0),
  root_cause text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_pick_errors_r2382_engineer ON public.engineer_pick_errors_r2382(engineer_profile_id);
CREATE INDEX IF NOT EXISTS idx_engineer_pick_errors_r2382_picked_at ON public.engineer_pick_errors_r2382(picked_at DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_pick_errors_r2382_type ON public.engineer_pick_errors_r2382(error_type);

ALTER TABLE public.engineer_pick_errors_r2382 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_pick_errors_r2382;
CREATE POLICY founder_all ON public.engineer_pick_errors_r2382
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_pick_error_training_r2382 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  training_module text NOT NULL,
  triggered_by_error_type text NOT NULL CHECK (triggered_by_error_type IN ('wrong_sku','wrong_quantity','wrong_variant','expired_stock','damaged','mislabeled_bin')),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  due_at timestamptz,
  completed_at timestamptz,
  quiz_score integer CHECK (quiz_score IS NULL OR (quiz_score BETWEEN 0 AND 100)),
  status text NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned','in_progress','completed','overdue','waived')),
  assigned_by_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pick_error_training_r2382_engineer ON public.engineer_pick_error_training_r2382(engineer_profile_id);
CREATE INDEX IF NOT EXISTS idx_pick_error_training_r2382_status ON public.engineer_pick_error_training_r2382(status);

ALTER TABLE public.engineer_pick_error_training_r2382 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_pick_error_training_r2382;
CREATE POLICY founder_all ON public.engineer_pick_error_training_r2382
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.founder_pick_error_summary_r2382()
RETURNS TABLE (
  total_errors bigint,
  errors_30d bigint,
  total_cost_rupees bigint,
  cost_30d_rupees bigint,
  revisits_caused bigint,
  avg_delay_hours numeric,
  distinct_engineers bigint,
  open_training bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.engineer_pick_errors_r2382),
    (SELECT count(*) FROM public.engineer_pick_errors_r2382 WHERE picked_at > now() - interval '30 days'),
    COALESCE((SELECT sum(error_cost_rupees) FROM public.engineer_pick_errors_r2382), 0),
    COALESCE((SELECT sum(error_cost_rupees) FROM public.engineer_pick_errors_r2382 WHERE picked_at > now() - interval '30 days'), 0),
    (SELECT count(*) FROM public.engineer_pick_errors_r2382 WHERE caused_revisit = true),
    COALESCE((SELECT avg(caused_delay_hours)::numeric(10,2) FROM public.engineer_pick_errors_r2382 WHERE caused_delay_hours > 0), 0),
    (SELECT count(DISTINCT engineer_profile_id) FROM public.engineer_pick_errors_r2382),
    (SELECT count(*) FROM public.engineer_pick_error_training_r2382 WHERE status IN ('assigned','in_progress','overdue'));
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_pick_error_recent_r2382()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  warehouse_code text,
  picked_at timestamptz,
  requested_part_sku text,
  picked_part_sku text,
  error_type text,
  error_cost_rupees integer,
  caused_revisit boolean,
  caused_delay_hours integer,
  detected_by text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, p.email, e.warehouse_code, e.picked_at, e.requested_part_sku, e.picked_part_sku,
         e.error_type, e.error_cost_rupees, e.caused_revisit, e.caused_delay_hours, e.detected_by
  FROM public.engineer_pick_errors_r2382 e
  JOIN public.profiles p ON p.id = e.engineer_profile_id
  ORDER BY e.picked_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_pick_error_by_type_r2382()
RETURNS TABLE (
  error_type text,
  occurrences bigint,
  total_cost_rupees bigint,
  revisits bigint,
  avg_delay_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.error_type,
         count(*),
         COALESCE(sum(e.error_cost_rupees), 0),
         count(*) FILTER (WHERE e.caused_revisit = true),
         COALESCE(avg(e.caused_delay_hours)::numeric(10,2), 0)
  FROM public.engineer_pick_errors_r2382 e
  GROUP BY e.error_type
  ORDER BY count(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_pick_error_top_engineers_r2382()
RETURNS TABLE (
  engineer_email text,
  errors_count bigint,
  total_cost_rupees bigint,
  revisits bigint,
  open_training bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email,
         count(e.*),
         COALESCE(sum(e.error_cost_rupees), 0),
         count(e.*) FILTER (WHERE e.caused_revisit = true),
         (SELECT count(*) FROM public.engineer_pick_error_training_r2382 t
            WHERE t.engineer_profile_id = e.engineer_profile_id
              AND t.status IN ('assigned','in_progress','overdue'))
  FROM public.engineer_pick_errors_r2382 e
  JOIN public.profiles p ON p.id = e.engineer_profile_id
  GROUP BY p.email, e.engineer_profile_id
  ORDER BY count(e.*) DESC
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_pick_error_by_warehouse_r2382()
RETURNS TABLE (
  warehouse_code text,
  errors_count bigint,
  total_cost_rupees bigint,
  distinct_engineers bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.warehouse_code,
         count(*),
         COALESCE(sum(e.error_cost_rupees), 0),
         count(DISTINCT e.engineer_profile_id)
  FROM public.engineer_pick_errors_r2382 e
  GROUP BY e.warehouse_code
  ORDER BY count(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_pick_error_training_recent_r2382()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  training_module text,
  triggered_by_error_type text,
  assigned_at timestamptz,
  due_at timestamptz,
  completed_at timestamptz,
  quiz_score integer,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, p.email, t.training_module, t.triggered_by_error_type,
         t.assigned_at, t.due_at, t.completed_at, t.quiz_score, t.status
  FROM public.engineer_pick_error_training_r2382 t
  JOIN public.profiles p ON p.id = t.engineer_profile_id
  ORDER BY t.assigned_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_pick_error_training_effectiveness_r2382()
RETURNS TABLE (
  triggered_by_error_type text,
  assigned_count bigint,
  completed_count bigint,
  avg_quiz_score numeric,
  completion_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.triggered_by_error_type,
         count(*),
         count(*) FILTER (WHERE t.status = 'completed'),
         COALESCE(avg(t.quiz_score)::numeric(10,2), 0),
         CASE WHEN count(*) > 0
           THEN (count(*) FILTER (WHERE t.status = 'completed')::numeric / count(*)::numeric * 100)::numeric(10,2)
           ELSE 0 END
  FROM public.engineer_pick_error_training_r2382 t
  GROUP BY t.triggered_by_error_type
  ORDER BY count(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_pick_error_summary_r2382() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_pick_error_recent_r2382() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_pick_error_by_type_r2382() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_pick_error_top_engineers_r2382() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_pick_error_by_warehouse_r2382() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_pick_error_training_recent_r2382() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_pick_error_training_effectiveness_r2382() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_pick_error_summary_r2382() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pick_error_recent_r2382() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pick_error_by_type_r2382() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pick_error_top_engineers_r2382() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pick_error_by_warehouse_r2382() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pick_error_training_recent_r2382() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pick_error_training_effectiveness_r2382() TO authenticated;

COMMIT;
