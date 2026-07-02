BEGIN;

-- ============================================================================
-- r1488 — Engineer Training Cost ROI
-- Per-program: cost, attendees, post-training NPS/efficiency lift,
-- certification yield, payback period; ranked.
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_training_programs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_code text NOT NULL UNIQUE,
  program_name text NOT NULL,
  category text NOT NULL CHECK (category IN ('clinical','safety','soft_skills','vendor_oem','compliance','leadership')),
  delivery_mode text NOT NULL CHECK (delivery_mode IN ('in_person','virtual','hybrid','self_paced')),
  duration_hours numeric(6,2) NOT NULL DEFAULT 0,
  cost_per_attendee_rupees bigint NOT NULL DEFAULT 0,
  fixed_cost_rupees bigint NOT NULL DEFAULT 0,
  target_tier text CHECK (target_tier IN ('pro','bgc','gst','pan','aadhaar','none','any')),
  certification_awarded boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_training_programs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS etp_founder_all ON engineer_training_programs;
CREATE POLICY etp_founder_all ON engineer_training_programs
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_training_attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id uuid NOT NULL REFERENCES engineer_training_programs(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  attended_at timestamptz NOT NULL DEFAULT now(),
  cost_actual_rupees bigint NOT NULL DEFAULT 0,
  completed boolean NOT NULL DEFAULT false,
  certified boolean NOT NULL DEFAULT false,
  pre_nps numeric(5,2),
  post_nps numeric(5,2),
  pre_jobs_per_week numeric(6,2),
  post_jobs_per_week numeric(6,2),
  pre_avg_rating numeric(3,2),
  post_avg_rating numeric(3,2),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_training_attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eta_founder_all ON engineer_training_attendance;
CREATE POLICY eta_founder_all ON engineer_training_attendance
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_eta_program ON engineer_training_attendance(program_id);
CREATE INDEX IF NOT EXISTS idx_eta_engineer ON engineer_training_attendance(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eta_attended_at ON engineer_training_attendance(attended_at DESC);

-- ============================================================================
-- READ RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_training_kpis()
RETURNS TABLE(
  total_programs bigint,
  total_attendees bigint,
  total_spend_rupees bigint,
  avg_cost_per_attendee numeric,
  cert_yield_pct numeric,
  completion_pct numeric,
  avg_nps_lift numeric,
  avg_efficiency_lift_pct numeric,
  avg_rating_lift numeric,
  payback_days_avg numeric,
  programs_positive_roi bigint,
  programs_negative_roi bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH att AS (
    SELECT a.*, p.cost_per_attendee_rupees, p.fixed_cost_rupees
    FROM engineer_training_attendance a
    JOIN engineer_training_programs p ON p.id = a.program_id
  )
  SELECT
    (SELECT count(*) FROM engineer_training_programs)::bigint,
    (SELECT count(*) FROM engineer_training_attendance)::bigint,
    COALESCE(SUM(a.cost_actual_rupees),0)::bigint,
    COALESCE(AVG(NULLIF(a.cost_actual_rupees,0)),0)::numeric,
    ROUND(100.0 * COALESCE(SUM(CASE WHEN a.certified THEN 1 ELSE 0 END),0)::numeric / NULLIF(count(a.*),0),2),
    ROUND(100.0 * COALESCE(SUM(CASE WHEN a.completed THEN 1 ELSE 0 END),0)::numeric / NULLIF(count(a.*),0),2),
    ROUND(AVG(a.post_nps - a.pre_nps)::numeric,2),
    ROUND(AVG(CASE WHEN a.pre_jobs_per_week > 0 THEN 100.0*(a.post_jobs_per_week - a.pre_jobs_per_week)/a.pre_jobs_per_week END)::numeric,2),
    ROUND(AVG(a.post_avg_rating - a.pre_avg_rating)::numeric,2),
    ROUND(AVG(CASE WHEN (a.post_jobs_per_week - a.pre_jobs_per_week) > 0
              THEN a.cost_actual_rupees::numeric / NULLIF((a.post_jobs_per_week - a.pre_jobs_per_week)*1000,0) * 7
              END)::numeric,1),
    (SELECT count(*) FROM (
      SELECT a2.program_id, AVG(a2.post_jobs_per_week - a2.pre_jobs_per_week) lift
      FROM engineer_training_attendance a2 GROUP BY a2.program_id HAVING AVG(a2.post_jobs_per_week - a2.pre_jobs_per_week) > 0
    ) z)::bigint,
    (SELECT count(*) FROM (
      SELECT a2.program_id, AVG(a2.post_jobs_per_week - a2.pre_jobs_per_week) lift
      FROM engineer_training_attendance a2 GROUP BY a2.program_id HAVING AVG(a2.post_jobs_per_week - a2.pre_jobs_per_week) <= 0
    ) z)::bigint
  FROM att a;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_training_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_program_ranking()
RETURNS TABLE(
  id uuid,
  program_code text,
  program_name text,
  category text,
  attendees bigint,
  total_spend_rupees bigint,
  cost_per_attendee numeric,
  cert_yield_pct numeric,
  avg_nps_lift numeric,
  avg_efficiency_lift_pct numeric,
  payback_days numeric,
  roi_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.program_code, p.program_name, p.category,
    count(a.*)::bigint,
    COALESCE(SUM(a.cost_actual_rupees),0)::bigint,
    ROUND(AVG(NULLIF(a.cost_actual_rupees,0))::numeric,2),
    ROUND(100.0*COALESCE(SUM(CASE WHEN a.certified THEN 1 ELSE 0 END),0)::numeric/NULLIF(count(a.*),0),2),
    ROUND(AVG(a.post_nps - a.pre_nps)::numeric,2),
    ROUND(AVG(CASE WHEN a.pre_jobs_per_week > 0 THEN 100.0*(a.post_jobs_per_week - a.pre_jobs_per_week)/a.pre_jobs_per_week END)::numeric,2),
    ROUND(AVG(CASE WHEN (a.post_jobs_per_week - a.pre_jobs_per_week) > 0
            THEN a.cost_actual_rupees::numeric / NULLIF((a.post_jobs_per_week - a.pre_jobs_per_week)*1000,0) * 7
            END)::numeric,1),
    ROUND((
      COALESCE(AVG(a.post_nps - a.pre_nps),0)*5
      + COALESCE(AVG(CASE WHEN a.pre_jobs_per_week>0 THEN 100.0*(a.post_jobs_per_week - a.pre_jobs_per_week)/a.pre_jobs_per_week END),0)
      + COALESCE(100.0*SUM(CASE WHEN a.certified THEN 1 ELSE 0 END)/NULLIF(count(a.*),0),0)*0.3
    )::numeric,2) AS roi_score
  FROM engineer_training_programs p
  LEFT JOIN engineer_training_attendance a ON a.program_id = p.id
  GROUP BY p.id
  ORDER BY roi_score DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_training_program_ranking() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_program_ranking() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_by_category()
RETURNS TABLE(
  category text,
  programs bigint,
  attendees bigint,
  total_spend_rupees bigint,
  avg_nps_lift numeric,
  avg_efficiency_lift_pct numeric,
  cert_yield_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.category,
    count(DISTINCT p.id)::bigint,
    count(a.*)::bigint,
    COALESCE(SUM(a.cost_actual_rupees),0)::bigint,
    ROUND(AVG(a.post_nps - a.pre_nps)::numeric,2),
    ROUND(AVG(CASE WHEN a.pre_jobs_per_week>0 THEN 100.0*(a.post_jobs_per_week - a.pre_jobs_per_week)/a.pre_jobs_per_week END)::numeric,2),
    ROUND(100.0*COALESCE(SUM(CASE WHEN a.certified THEN 1 ELSE 0 END),0)::numeric/NULLIF(count(a.*),0),2)
  FROM engineer_training_programs p
  LEFT JOIN engineer_training_attendance a ON a.program_id = p.id
  GROUP BY p.category
  ORDER BY count(a.*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_training_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_by_category() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_top_attendees()
RETURNS TABLE(
  engineer_user_id uuid,
  programs_attended bigint,
  total_invested_rupees bigint,
  certs_earned bigint,
  avg_nps_lift numeric,
  avg_efficiency_lift_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_user_id,
    count(*)::bigint,
    COALESCE(SUM(a.cost_actual_rupees),0)::bigint,
    COALESCE(SUM(CASE WHEN a.certified THEN 1 ELSE 0 END),0)::bigint,
    ROUND(AVG(a.post_nps - a.pre_nps)::numeric,2),
    ROUND(AVG(CASE WHEN a.pre_jobs_per_week>0 THEN 100.0*(a.post_jobs_per_week - a.pre_jobs_per_week)/a.pre_jobs_per_week END)::numeric,2)
  FROM engineer_training_attendance a
  GROUP BY a.engineer_user_id
  ORDER BY count(*) DESC, COALESCE(SUM(a.cost_actual_rupees),0) DESC
  LIMIT 50;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_training_top_attendees() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_top_attendees() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_monthly_spend()
RETURNS TABLE(
  month_start date,
  attendees bigint,
  total_spend_rupees bigint,
  certs bigint,
  avg_nps_lift numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', a.attended_at)::date,
    count(*)::bigint,
    COALESCE(SUM(a.cost_actual_rupees),0)::bigint,
    COALESCE(SUM(CASE WHEN a.certified THEN 1 ELSE 0 END),0)::bigint,
    ROUND(AVG(a.post_nps - a.pre_nps)::numeric,2)
  FROM engineer_training_attendance a
  WHERE a.attended_at > now() - interval '12 months'
  GROUP BY 1 ORDER BY 1 DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_training_monthly_spend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_monthly_spend() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_payback_curve()
RETURNS TABLE(
  bucket text,
  programs bigint,
  attendees bigint,
  avg_payback_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT p.id pid,
      AVG(CASE WHEN (a.post_jobs_per_week - a.pre_jobs_per_week) > 0
           THEN a.cost_actual_rupees::numeric / NULLIF((a.post_jobs_per_week - a.pre_jobs_per_week)*1000,0)*7 END) pd,
      count(a.*) att
    FROM engineer_training_programs p
    LEFT JOIN engineer_training_attendance a ON a.program_id = p.id
    GROUP BY p.id
  )
  SELECT
    CASE
      WHEN pd IS NULL THEN 'no_lift'
      WHEN pd < 30 THEN '<30d'
      WHEN pd < 90 THEN '30-90d'
      WHEN pd < 180 THEN '90-180d'
      WHEN pd < 365 THEN '180-365d'
      ELSE '>365d'
    END,
    count(*)::bigint,
    COALESCE(SUM(att),0)::bigint,
    ROUND(AVG(pd)::numeric,1)
  FROM base
  GROUP BY 1
  ORDER BY 1;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_training_payback_curve() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_payback_curve() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_recent_attendance()
RETURNS TABLE(
  id uuid,
  program_id uuid,
  program_name text,
  engineer_user_id uuid,
  attended_at timestamptz,
  cost_actual_rupees bigint,
  completed boolean,
  certified boolean,
  nps_lift numeric,
  efficiency_lift_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.program_id, p.program_name, a.engineer_user_id, a.attended_at,
    a.cost_actual_rupees, a.completed, a.certified,
    ROUND((a.post_nps - a.pre_nps)::numeric,2),
    ROUND(CASE WHEN a.pre_jobs_per_week>0 THEN 100.0*(a.post_jobs_per_week - a.pre_jobs_per_week)/a.pre_jobs_per_week END::numeric,2)
  FROM engineer_training_attendance a
  JOIN engineer_training_programs p ON p.id = a.program_id
  ORDER BY a.attended_at DESC
  LIMIT 100;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_training_recent_attendance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_recent_attendance() TO authenticated;

-- ============================================================================
-- WRITE / LOG helpers (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_training_program_upsert(
  p_code text, p_name text, p_category text, p_delivery text,
  p_duration numeric, p_cost_per bigint, p_fixed bigint,
  p_target_tier text, p_cert boolean, p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_training_programs(
    program_code, program_name, category, delivery_mode, duration_hours,
    cost_per_attendee_rupees, fixed_cost_rupees, target_tier, certification_awarded, notes
  ) VALUES (
    p_code, p_name, p_category, p_delivery, COALESCE(p_duration,0),
    COALESCE(p_cost_per,0), COALESCE(p_fixed,0), p_target_tier, COALESCE(p_cert,false), p_notes
  )
  ON CONFLICT (program_code) DO UPDATE
    SET program_name = EXCLUDED.program_name,
        category = EXCLUDED.category,
        delivery_mode = EXCLUDED.delivery_mode,
        duration_hours = EXCLUDED.duration_hours,
        cost_per_attendee_rupees = EXCLUDED.cost_per_attendee_rupees,
        fixed_cost_rupees = EXCLUDED.fixed_cost_rupees,
        target_tier = EXCLUDED.target_tier,
        certification_awarded = EXCLUDED.certification_awarded,
        notes = EXCLUDED.notes,
        updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_training_program_upsert(text,text,text,text,numeric,bigint,bigint,text,boolean,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_training_program_upsert(text,text,text,text,numeric,bigint,bigint,text,boolean,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_training_attendance(
  p_program uuid, p_engineer uuid, p_cost bigint,
  p_completed boolean, p_certified boolean,
  p_pre_nps numeric, p_post_nps numeric,
  p_pre_jpw numeric, p_post_jpw numeric,
  p_pre_rating numeric, p_post_rating numeric,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_training_attendance(
    program_id, engineer_user_id, cost_actual_rupees, completed, certified,
    pre_nps, post_nps, pre_jobs_per_week, post_jobs_per_week,
    pre_avg_rating, post_avg_rating, notes
  ) VALUES (
    p_program, p_engineer, COALESCE(p_cost,0),
    COALESCE(p_completed,false), COALESCE(p_certified,false),
    p_pre_nps, p_post_nps, p_pre_jpw, p_post_jpw,
    p_pre_rating, p_post_rating, p_notes
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_training_attendance(uuid,uuid,bigint,boolean,boolean,numeric,numeric,numeric,numeric,numeric,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_training_attendance(uuid,uuid,bigint,boolean,boolean,numeric,numeric,numeric,numeric,numeric,numeric,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_training_attendance_outcome(
  p_attendance uuid, p_post_nps numeric, p_post_jpw numeric,
  p_post_rating numeric, p_certified boolean, p_completed boolean
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_training_attendance
     SET post_nps = COALESCE(p_post_nps, post_nps),
         post_jobs_per_week = COALESCE(p_post_jpw, post_jobs_per_week),
         post_avg_rating = COALESCE(p_post_rating, post_avg_rating),
         certified = COALESCE(p_certified, certified),
         completed = COALESCE(p_completed, completed)
   WHERE id = p_attendance;
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_training_attendance_outcome(uuid,numeric,numeric,numeric,boolean,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_training_attendance_outcome(uuid,numeric,numeric,numeric,boolean,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_training_program_archive(p_program uuid, p_note text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_training_programs
     SET notes = COALESCE(notes,'') || E'\n[ARCHIVED ' || now()::text || '] ' || COALESCE(p_note,''),
         updated_at = now()
   WHERE id = p_program;
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_training_program_archive(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_training_program_archive(uuid,text) TO authenticated;

COMMIT;