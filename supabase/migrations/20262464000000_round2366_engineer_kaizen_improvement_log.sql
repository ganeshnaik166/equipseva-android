-- Round 2366: Engineer Continuous-Improvement Kaizen Log
-- Engineers post small improvements they made; founder reviews and scales good ones across team
BEGIN;

-- =====================================================================
-- TABLE 1: kaizen submissions (one per engineer improvement idea)
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_kaizen_log_r2366 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  title text NOT NULL,
  problem_statement text NOT NULL,
  improvement_made text NOT NULL,
  category text NOT NULL CHECK (category IN ('tool_hack','process_shortcut','safety_fix','parts_workaround','customer_handling','documentation','training_tip','other')),
  time_saved_minutes_per_job integer NOT NULL DEFAULT 0 CHECK (time_saved_minutes_per_job >= 0),
  jobs_applied_count integer NOT NULL DEFAULT 1 CHECK (jobs_applied_count >= 0),
  photo_url text,
  video_url text,
  status text NOT NULL DEFAULT 'pending_review' CHECK (status IN ('pending_review','approved_local','approved_scaled','rejected','needs_more_info','duplicate')),
  founder_reviewed_at timestamptz,
  founder_reviewer_email text,
  founder_notes text,
  scale_decision text CHECK (scale_decision IN ('keep_local','share_pod','share_region','share_all_india','build_into_sop','build_into_tool','reject')),
  estimated_annual_savings_rupees numeric(12,2) DEFAULT 0,
  reward_paid_rupees numeric(10,2) DEFAULT 0,
  reward_paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kaizen_r2366_engineer ON public.engineer_kaizen_log_r2366(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_kaizen_r2366_status ON public.engineer_kaizen_log_r2366(status);
CREATE INDEX IF NOT EXISTS idx_kaizen_r2366_submitted ON public.engineer_kaizen_log_r2366(submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_kaizen_r2366_category ON public.engineer_kaizen_log_r2366(category);

ALTER TABLE public.engineer_kaizen_log_r2366 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kaizen_log_r2366_founder_all ON public.engineer_kaizen_log_r2366;
CREATE POLICY kaizen_log_r2366_founder_all ON public.engineer_kaizen_log_r2366
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: scale-out tracking (when founder rolls a kaizen to other engineers)
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.kaizen_scale_rollouts_r2366 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kaizen_id uuid NOT NULL REFERENCES public.engineer_kaizen_log_r2366(id) ON DELETE CASCADE,
  rolled_out_at timestamptz NOT NULL DEFAULT now(),
  rolled_out_by_email text NOT NULL,
  target_audience text NOT NULL CHECK (target_audience IN ('single_pod','region','all_engineers','sop_doc','tool_update')),
  engineers_notified_count integer NOT NULL DEFAULT 0 CHECK (engineers_notified_count >= 0),
  engineers_adopted_count integer NOT NULL DEFAULT 0 CHECK (engineers_adopted_count >= 0),
  adoption_rate_pct numeric(5,2) GENERATED ALWAYS AS (
    CASE WHEN engineers_notified_count > 0
         THEN (engineers_adopted_count::numeric * 100.0 / engineers_notified_count)
         ELSE 0 END
  ) STORED,
  rollout_notes text,
  measured_impact_rupees numeric(12,2) DEFAULT 0,
  measurement_window_days integer DEFAULT 30,
  rollout_status text NOT NULL DEFAULT 'in_progress' CHECK (rollout_status IN ('in_progress','measuring','completed','reverted')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scale_r2366_kaizen ON public.kaizen_scale_rollouts_r2366(kaizen_id);
CREATE INDEX IF NOT EXISTS idx_scale_r2366_status ON public.kaizen_scale_rollouts_r2366(rollout_status);
CREATE INDEX IF NOT EXISTS idx_scale_r2366_rolled_out ON public.kaizen_scale_rollouts_r2366(rolled_out_at DESC);

ALTER TABLE public.kaizen_scale_rollouts_r2366 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS scale_rollouts_r2366_founder_all ON public.kaizen_scale_rollouts_r2366;
CREATE POLICY scale_rollouts_r2366_founder_all ON public.kaizen_scale_rollouts_r2366
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list kaizen submissions (with engineer info)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kaizen_list_submissions_r2366(p_status_filter text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  submitted_at timestamptz,
  title text,
  category text,
  time_saved_minutes_per_job integer,
  jobs_applied_count integer,
  status text,
  scale_decision text,
  estimated_annual_savings_rupees numeric,
  reward_paid_rupees numeric,
  founder_reviewed_at timestamptz
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
    k.id,
    k.engineer_user_id,
    p.email::text,
    k.submitted_at,
    k.title,
    k.category,
    k.time_saved_minutes_per_job,
    k.jobs_applied_count,
    k.status,
    k.scale_decision,
    k.estimated_annual_savings_rupees,
    k.reward_paid_rupees,
    k.founder_reviewed_at
  FROM public.engineer_kaizen_log_r2366 k
  LEFT JOIN public.profiles p ON p.id = k.engineer_user_id
  WHERE (p_status_filter IS NULL OR k.status = p_status_filter)
  ORDER BY k.submitted_at DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.kaizen_list_submissions_r2366(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kaizen_list_submissions_r2366(text) TO authenticated;

-- =====================================================================
-- RPC 2: summary stats
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kaizen_summary_r2366()
RETURNS TABLE (
  total_submissions bigint,
  pending_review_count bigint,
  approved_scaled_count bigint,
  rejected_count bigint,
  total_estimated_savings_rupees numeric,
  total_rewards_paid_rupees numeric,
  unique_contributors bigint,
  avg_time_saved_minutes numeric
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
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status = 'pending_review')::bigint,
    COUNT(*) FILTER (WHERE status = 'approved_scaled')::bigint,
    COUNT(*) FILTER (WHERE status = 'rejected')::bigint,
    COALESCE(SUM(estimated_annual_savings_rupees), 0)::numeric,
    COALESCE(SUM(reward_paid_rupees), 0)::numeric,
    COUNT(DISTINCT engineer_user_id)::bigint,
    COALESCE(AVG(time_saved_minutes_per_job), 0)::numeric
  FROM public.engineer_kaizen_log_r2366;
END;
$$;

REVOKE ALL ON FUNCTION public.kaizen_summary_r2366() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kaizen_summary_r2366() TO authenticated;

-- =====================================================================
-- RPC 3: top contributing engineers
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kaizen_top_contributors_r2366()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  submissions_count bigint,
  approved_count bigint,
  total_savings_rupees numeric,
  total_rewards_rupees numeric
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
    k.engineer_user_id,
    p.email::text,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE k.status IN ('approved_local','approved_scaled'))::bigint,
    COALESCE(SUM(k.estimated_annual_savings_rupees), 0)::numeric,
    COALESCE(SUM(k.reward_paid_rupees), 0)::numeric
  FROM public.engineer_kaizen_log_r2366 k
  LEFT JOIN public.profiles p ON p.id = k.engineer_user_id
  GROUP BY k.engineer_user_id, p.email
  ORDER BY COUNT(*) FILTER (WHERE k.status IN ('approved_local','approved_scaled')) DESC, COUNT(*) DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.kaizen_top_contributors_r2366() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kaizen_top_contributors_r2366() TO authenticated;

-- =====================================================================
-- RPC 4: category breakdown
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kaizen_category_breakdown_r2366()
RETURNS TABLE (
  category text,
  submissions_count bigint,
  approved_count bigint,
  avg_time_saved_minutes numeric,
  total_estimated_savings_rupees numeric
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
    k.category,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE k.status IN ('approved_local','approved_scaled'))::bigint,
    COALESCE(AVG(k.time_saved_minutes_per_job), 0)::numeric,
    COALESCE(SUM(k.estimated_annual_savings_rupees), 0)::numeric
  FROM public.engineer_kaizen_log_r2366 k
  GROUP BY k.category
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.kaizen_category_breakdown_r2366() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kaizen_category_breakdown_r2366() TO authenticated;

-- =====================================================================
-- RPC 5: list scale rollouts
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kaizen_list_rollouts_r2366()
RETURNS TABLE (
  id uuid,
  kaizen_id uuid,
  kaizen_title text,
  rolled_out_at timestamptz,
  rolled_out_by_email text,
  target_audience text,
  engineers_notified_count integer,
  engineers_adopted_count integer,
  adoption_rate_pct numeric,
  measured_impact_rupees numeric,
  rollout_status text
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
    r.id,
    r.kaizen_id,
    k.title,
    r.rolled_out_at,
    r.rolled_out_by_email,
    r.target_audience,
    r.engineers_notified_count,
    r.engineers_adopted_count,
    r.adoption_rate_pct,
    r.measured_impact_rupees,
    r.rollout_status
  FROM public.kaizen_scale_rollouts_r2366 r
  LEFT JOIN public.engineer_kaizen_log_r2366 k ON k.id = r.kaizen_id
  ORDER BY r.rolled_out_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.kaizen_list_rollouts_r2366() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kaizen_list_rollouts_r2366() TO authenticated;

-- =====================================================================
-- RPC 6: approve / reject kaizen submission
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kaizen_review_submission_r2366(
  p_kaizen_id uuid,
  p_new_status text,
  p_scale_decision text,
  p_estimated_savings numeric,
  p_founder_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_caller := auth.jwt()->>'email';

  UPDATE public.engineer_kaizen_log_r2366
  SET
    status = p_new_status,
    scale_decision = p_scale_decision,
    estimated_annual_savings_rupees = COALESCE(p_estimated_savings, estimated_annual_savings_rupees),
    founder_notes = p_founder_notes,
    founder_reviewed_at = now(),
    founder_reviewer_email = v_caller,
    updated_at = now()
  WHERE id = p_kaizen_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'kaizen submission not found';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.kaizen_review_submission_r2366(uuid, text, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kaizen_review_submission_r2366(uuid, text, text, numeric, text) TO authenticated;

-- =====================================================================
-- RPC 7: create a scale rollout for an approved kaizen
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kaizen_create_rollout_r2366(
  p_kaizen_id uuid,
  p_target_audience text,
  p_engineers_notified integer,
  p_rollout_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_caller := auth.jwt()->>'email';

  INSERT INTO public.kaizen_scale_rollouts_r2366 (
    kaizen_id,
    rolled_out_by_email,
    target_audience,
    engineers_notified_count,
    rollout_notes
  ) VALUES (
    p_kaizen_id,
    v_caller,
    p_target_audience,
    COALESCE(p_engineers_notified, 0),
    p_rollout_notes
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.kaizen_create_rollout_r2366(uuid, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kaizen_create_rollout_r2366(uuid, text, integer, text) TO authenticated;

COMMIT;
