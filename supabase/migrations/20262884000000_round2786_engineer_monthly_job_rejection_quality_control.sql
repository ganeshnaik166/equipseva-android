BEGIN;

-- =============================================================================
-- Round 2786 — Engineer Monthly Job Rejection Quality Control
-- =============================================================================

CREATE TABLE IF NOT EXISTS engineer_monthly_job_rejections_r2786 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_key       text NOT NULL,
  engineer_code   text NOT NULL,
  engineer_name   text NOT NULL,
  job_code        text NOT NULL,
  rejection_reason text NOT NULL CHECK (rejection_reason IN ('distance_too_far','part_unavailable','skill_mismatch','schedule_conflict','customer_blacklist','safety_concern','duplicate_request')),
  reason_valid    boolean NOT NULL DEFAULT false,
  override_applied boolean NOT NULL DEFAULT false,
  override_actor  text,
  outcome         text NOT NULL CHECK (outcome IN ('reassigned','cancelled','completed_after_override','escalated','pending_review')),
  policy_adjust_flag boolean NOT NULL DEFAULT false,
  policy_adjust_note text,
  rejected_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_job_rejections_r2786 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_job_rejections_r2786;
CREATE POLICY founder_all ON engineer_monthly_job_rejections_r2786 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_monthly_rejection_policy_log_r2786 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_key       text NOT NULL,
  policy_area     text NOT NULL CHECK (policy_area IN ('distance_radius','part_inventory','skill_routing','schedule_buffer','customer_screening','safety_protocol','dedup_window')),
  prior_threshold text NOT NULL,
  new_threshold   text NOT NULL,
  trigger_reason  text NOT NULL,
  rejections_avoided_est integer NOT NULL DEFAULT 0,
  approved_by     text NOT NULL,
  effective_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_rejection_policy_log_r2786 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_rejection_policy_log_r2786;
CREATE POLICY founder_all ON engineer_monthly_rejection_policy_log_r2786 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed: rejections
INSERT INTO engineer_monthly_job_rejections_r2786 (month_key, engineer_code, engineer_name, job_code, rejection_reason, reason_valid, override_applied, override_actor, outcome, policy_adjust_flag, policy_adjust_note, rejected_at) VALUES
('2026-06','ENG-HYD-014','Ravi Kumar','JOB-88421','distance_too_far',true,false,NULL,'reassigned',false,NULL,'2026-06-03 10:14:00+05:30'),
('2026-06','ENG-BLR-022','Priya Nair','JOB-88455','part_unavailable',true,true,'ops_lead','completed_after_override',true,'expedite spare-part SLA to 24h','2026-06-05 12:22:00+05:30'),
('2026-06','ENG-CHN-007','Suresh M','JOB-88512','skill_mismatch',false,true,'founder','completed_after_override',true,'tighten skill-tag taxonomy','2026-06-07 09:05:00+05:30'),
('2026-06','ENG-MUM-031','Anita Shah','JOB-88577','schedule_conflict',true,false,NULL,'reassigned',false,NULL,'2026-06-09 14:40:00+05:30'),
('2026-06','ENG-HYD-014','Ravi Kumar','JOB-88641','customer_blacklist',true,false,NULL,'cancelled',false,NULL,'2026-06-11 11:00:00+05:30'),
('2026-06','ENG-DEL-009','Manoj Verma','JOB-88702','safety_concern',true,false,NULL,'escalated',true,'mandate biohazard PPE for dental ops','2026-06-13 16:18:00+05:30'),
('2026-06','ENG-BLR-022','Priya Nair','JOB-88755','duplicate_request',true,false,NULL,'cancelled',false,NULL,'2026-06-15 08:50:00+05:30'),
('2026-06','ENG-CHN-007','Suresh M','JOB-88811','distance_too_far',false,true,'ops_lead','completed_after_override',true,'review 25km radius cap','2026-06-17 13:30:00+05:30');

-- Seed: policy log
INSERT INTO engineer_monthly_rejection_policy_log_r2786 (month_key, policy_area, prior_threshold, new_threshold, trigger_reason, rejections_avoided_est, approved_by, effective_at) VALUES
('2026-06','distance_radius','25km','30km flex','12 valid rejections in zone',9,'founder','2026-06-08 10:00:00+05:30'),
('2026-06','part_inventory','72h SLA','24h SLA tier-A','part_unavailable spike',14,'ops_lead','2026-06-10 11:30:00+05:30'),
('2026-06','skill_routing','tag-v1','tag-v2 dental sub-tags','false-positive skill_mismatch',6,'founder','2026-06-12 09:15:00+05:30'),
('2026-06','schedule_buffer','30min','45min','schedule_conflict cluster',8,'ops_lead','2026-06-14 14:00:00+05:30'),
('2026-06','dedup_window','15min','30min','duplicate_request false rejects',5,'founder','2026-06-16 10:45:00+05:30'),
('2026-06','safety_protocol','optional PPE','mandatory PPE dental','engineer-flagged biohazard',3,'founder','2026-06-17 12:00:00+05:30');

-- =============================================================================
-- RPCs
-- =============================================================================

DROP FUNCTION IF EXISTS founder_r2786_rejection_kpis();
CREATE OR REPLACE FUNCTION founder_r2786_rejection_kpis()
RETURNS TABLE(total_rejections int, valid_rejections int, override_count int, policy_adjusts int, avoided_est int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM engineer_monthly_job_rejections_r2786),
    (SELECT count(*)::int FROM engineer_monthly_job_rejections_r2786 WHERE reason_valid),
    (SELECT count(*)::int FROM engineer_monthly_job_rejections_r2786 WHERE override_applied),
    (SELECT count(*)::int FROM engineer_monthly_rejection_policy_log_r2786),
    (SELECT coalesce(sum(rejections_avoided_est),0)::int FROM engineer_monthly_rejection_policy_log_r2786);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2786_rejection_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2786_rejection_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2786_rejections_by_reason();
CREATE OR REPLACE FUNCTION founder_r2786_rejections_by_reason()
RETURNS TABLE(rejection_reason text, total int, valid_count int, invalid_count int, override_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.rejection_reason,
         count(*)::int,
         count(*) FILTER (WHERE r.reason_valid)::int,
         count(*) FILTER (WHERE NOT r.reason_valid)::int,
         count(*) FILTER (WHERE r.override_applied)::int
  FROM engineer_monthly_job_rejections_r2786 r
  GROUP BY r.rejection_reason
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2786_rejections_by_reason() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2786_rejections_by_reason() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2786_rejections_by_engineer();
CREATE OR REPLACE FUNCTION founder_r2786_rejections_by_engineer()
RETURNS TABLE(engineer_code text, engineer_name text, total int, valid_pct numeric, override_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.engineer_name,
         count(*)::int,
         round(100.0 * count(*) FILTER (WHERE r.reason_valid) / nullif(count(*),0), 1),
         round(100.0 * count(*) FILTER (WHERE r.override_applied) / nullif(count(*),0), 1)
  FROM engineer_monthly_job_rejections_r2786 r
  GROUP BY r.engineer_code, r.engineer_name
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2786_rejections_by_engineer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2786_rejections_by_engineer() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2786_invalid_rejection_list();
CREATE OR REPLACE FUNCTION founder_r2786_invalid_rejection_list()
RETURNS TABLE(job_code text, engineer_name text, rejection_reason text, outcome text, override_actor text, rejected_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.job_code, r.engineer_name, r.rejection_reason, r.outcome, r.override_actor, r.rejected_at
  FROM engineer_monthly_job_rejections_r2786 r
  WHERE NOT r.reason_valid
  ORDER BY r.rejected_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2786_invalid_rejection_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2786_invalid_rejection_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2786_override_outcomes();
CREATE OR REPLACE FUNCTION founder_r2786_override_outcomes()
RETURNS TABLE(outcome text, total int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.outcome, count(*)::int
  FROM engineer_monthly_job_rejections_r2786 r
  WHERE r.override_applied
  GROUP BY r.outcome
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2786_override_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2786_override_outcomes() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2786_policy_adjusts();
CREATE OR REPLACE FUNCTION founder_r2786_policy_adjusts()
RETURNS TABLE(policy_area text, prior_threshold text, new_threshold text, trigger_reason text, rejections_avoided_est int, approved_by text, effective_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.policy_area, p.prior_threshold, p.new_threshold, p.trigger_reason, p.rejections_avoided_est, p.approved_by, p.effective_at
  FROM engineer_monthly_rejection_policy_log_r2786 p
  ORDER BY p.effective_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2786_policy_adjusts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2786_policy_adjusts() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2786_flagged_for_review();
CREATE OR REPLACE FUNCTION founder_r2786_flagged_for_review()
RETURNS TABLE(job_code text, engineer_name text, rejection_reason text, policy_adjust_note text, rejected_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.job_code, r.engineer_name, r.rejection_reason, r.policy_adjust_note, r.rejected_at
  FROM engineer_monthly_job_rejections_r2786 r
  WHERE r.policy_adjust_flag
  ORDER BY r.rejected_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2786_flagged_for_review() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2786_flagged_for_review() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2786_recent_rejections();
CREATE OR REPLACE FUNCTION founder_r2786_recent_rejections()
RETURNS TABLE(job_code text, engineer_name text, rejection_reason text, reason_valid boolean, override_applied boolean, outcome text, rejected_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.job_code, r.engineer_name, r.rejection_reason, r.reason_valid, r.override_applied, r.outcome, r.rejected_at
  FROM engineer_monthly_job_rejections_r2786 r
  ORDER BY r.rejected_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2786_recent_rejections() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2786_recent_rejections() TO authenticated;

COMMIT;
