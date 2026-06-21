BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_multi_year_plans_r1723 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan_label text NOT NULL,
  plan_years int NOT NULL CHECK (plan_years > 0 AND plan_years <= 20),
  total_committed_rupees bigint NOT NULL DEFAULT 0 CHECK (total_committed_rupees >= 0),
  plan_start date NOT NULL,
  plan_end date NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','completed','cancelled')),
  key_milestones_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hmyp_r1723_hosp ON public.hospital_multi_year_plans_r1723(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hmyp_r1723_status ON public.hospital_multi_year_plans_r1723(status);

CREATE TABLE IF NOT EXISTS public.hospital_plan_quarterly_reviews_r1723 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.hospital_multi_year_plans_r1723(id) ON DELETE CASCADE,
  quarter text NOT NULL,
  review_date date NOT NULL DEFAULT CURRENT_DATE,
  on_track boolean NOT NULL DEFAULT true,
  expected_revenue_rupees bigint NOT NULL DEFAULT 0,
  actual_revenue_rupees bigint NOT NULL DEFAULT 0,
  variance_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpqr_r1723_plan ON public.hospital_plan_quarterly_reviews_r1723(plan_id);
CREATE INDEX IF NOT EXISTS idx_hpqr_r1723_date ON public.hospital_plan_quarterly_reviews_r1723(review_date DESC);

-- RLS
ALTER TABLE public.hospital_multi_year_plans_r1723 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_plan_quarterly_reviews_r1723 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hmyp_r1723_founder_all ON public.hospital_multi_year_plans_r1723;
CREATE POLICY hmyp_r1723_founder_all ON public.hospital_multi_year_plans_r1723
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hpqr_r1723_founder_all ON public.hospital_plan_quarterly_reviews_r1723;
CREATE POLICY hpqr_r1723_founder_all ON public.hospital_plan_quarterly_reviews_r1723
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_plans
CREATE OR REPLACE FUNCTION public.list_plans_r1723(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  plan_label text,
  plan_years int,
  total_committed_rupees bigint,
  plan_start date,
  plan_end date,
  status text,
  review_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_user_id, pr.email::text, p.plan_label, p.plan_years,
         p.total_committed_rupees, p.plan_start, p.plan_end, p.status,
         (SELECT COUNT(*) FROM public.hospital_plan_quarterly_reviews_r1723 r WHERE r.plan_id = p.id)::int,
         p.created_at
  FROM public.hospital_multi_year_plans_r1723 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  WHERE (p_status IS NULL OR p.status = p_status)
  ORDER BY p.created_at DESC;
END;
$$;

-- RPC 2: add_plan
CREATE OR REPLACE FUNCTION public.add_plan_r1723(
  p_hospital_user_id uuid,
  p_plan_label text,
  p_plan_years int,
  p_total_committed_rupees bigint,
  p_plan_start date,
  p_plan_end date,
  p_key_milestones_md text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_multi_year_plans_r1723(
    hospital_user_id, plan_label, plan_years, total_committed_rupees,
    plan_start, plan_end, key_milestones_md
  ) VALUES (
    p_hospital_user_id, p_plan_label, p_plan_years, p_total_committed_rupees,
    p_plan_start, p_plan_end, p_key_milestones_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_plan_r1723',
    jsonb_build_object('plan_id', v_id, 'hospital_user_id', p_hospital_user_id, 'label', p_plan_label));
  RETURN v_id;
END;
$$;

-- RPC 3: list_reviews
CREATE OR REPLACE FUNCTION public.list_reviews_r1723(p_plan_id uuid)
RETURNS TABLE (
  id uuid,
  plan_id uuid,
  quarter text,
  review_date date,
  on_track boolean,
  expected_revenue_rupees bigint,
  actual_revenue_rupees bigint,
  variance_rupees bigint,
  variance_note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.plan_id, r.quarter, r.review_date, r.on_track,
         r.expected_revenue_rupees, r.actual_revenue_rupees,
         (r.actual_revenue_rupees - r.expected_revenue_rupees) AS variance_rupees,
         r.variance_note, r.created_at
  FROM public.hospital_plan_quarterly_reviews_r1723 r
  WHERE r.plan_id = p_plan_id
  ORDER BY r.review_date DESC;
END;
$$;

-- RPC 4: record_review
CREATE OR REPLACE FUNCTION public.record_review_r1723(
  p_plan_id uuid,
  p_quarter text,
  p_on_track boolean,
  p_expected_revenue_rupees bigint,
  p_actual_revenue_rupees bigint,
  p_variance_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_plan_quarterly_reviews_r1723(
    plan_id, quarter, on_track, expected_revenue_rupees, actual_revenue_rupees, variance_note
  ) VALUES (
    p_plan_id, p_quarter, p_on_track, p_expected_revenue_rupees, p_actual_revenue_rupees, p_variance_note
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_review_r1723',
    jsonb_build_object('review_id', v_id, 'plan_id', p_plan_id, 'quarter', p_quarter, 'on_track', p_on_track));
  RETURN v_id;
END;
$$;

-- RPC 5: complete_plan
CREATE OR REPLACE FUNCTION public.complete_plan_r1723(p_plan_id uuid, p_status text DEFAULT 'completed')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('completed','cancelled','active','draft') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.hospital_multi_year_plans_r1723
  SET status = p_status, updated_at = now()
  WHERE id = p_plan_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_plan_r1723',
    jsonb_build_object('plan_id', p_plan_id, 'status', p_status));
END;
$$;

-- RPC 6: plan_revenue_summary
CREATE OR REPLACE FUNCTION public.plan_revenue_summary_r1723()
RETURNS TABLE (
  total_plans int,
  active_plans int,
  completed_plans int,
  draft_plans int,
  cancelled_plans int,
  total_committed_rupees bigint,
  total_expected_rupees bigint,
  total_actual_rupees bigint,
  overall_variance_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.hospital_multi_year_plans_r1723)::int,
    (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.hospital_multi_year_plans_r1723),
    (SELECT (COUNT(*) FILTER (WHERE status = 'completed'))::int FROM public.hospital_multi_year_plans_r1723),
    (SELECT (COUNT(*) FILTER (WHERE status = 'draft'))::int FROM public.hospital_multi_year_plans_r1723),
    (SELECT (COUNT(*) FILTER (WHERE status = 'cancelled'))::int FROM public.hospital_multi_year_plans_r1723),
    COALESCE((SELECT SUM(total_committed_rupees) FROM public.hospital_multi_year_plans_r1723), 0)::bigint,
    COALESCE((SELECT SUM(expected_revenue_rupees) FROM public.hospital_plan_quarterly_reviews_r1723), 0)::bigint,
    COALESCE((SELECT SUM(actual_revenue_rupees) FROM public.hospital_plan_quarterly_reviews_r1723), 0)::bigint,
    COALESCE((SELECT SUM(actual_revenue_rupees - expected_revenue_rupees) FROM public.hospital_plan_quarterly_reviews_r1723), 0)::bigint;
END;
$$;

-- RPC 7: off_track_plans
CREATE OR REPLACE FUNCTION public.off_track_plans_r1723()
RETURNS TABLE (
  plan_id uuid,
  hospital_user_id uuid,
  hospital_email text,
  plan_label text,
  status text,
  off_track_reviews int,
  last_review_date date,
  total_variance_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_user_id, pr.email::text, p.plan_label, p.status,
         (COUNT(*) FILTER (WHERE r.on_track = false))::int,
         MAX(r.review_date),
         COALESCE(SUM(r.actual_revenue_rupees - r.expected_revenue_rupees), 0)::bigint
  FROM public.hospital_multi_year_plans_r1723 p
  JOIN public.hospital_plan_quarterly_reviews_r1723 r ON r.plan_id = p.id
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  WHERE p.status = 'active'
  GROUP BY p.id, p.hospital_user_id, pr.email, p.plan_label, p.status
  HAVING (COUNT(*) FILTER (WHERE r.on_track = false)) > 0
  ORDER BY (COUNT(*) FILTER (WHERE r.on_track = false)) DESC;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_plans_r1723(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_plan_r1723(uuid, text, int, bigint, date, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r1723(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_review_r1723(uuid, text, boolean, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_plan_r1723(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.plan_revenue_summary_r1723() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.off_track_plans_r1723() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_plans_r1723(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_plan_r1723(uuid, text, int, bigint, date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1723(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_review_r1723(uuid, text, boolean, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_plan_r1723(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plan_revenue_summary_r1723() TO authenticated;
GRANT EXECUTE ON FUNCTION public.off_track_plans_r1723() TO authenticated;

COMMIT;