BEGIN;

-- =============================================================
-- r1574 — Founder Engineer Suspension Audit Trail
-- Tables: engineer_suspension_audit, engineer_suspension_reviews
-- =============================================================

CREATE TABLE IF NOT EXISTS engineer_suspension_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  suspended_by uuid REFERENCES auth.users(id),
  reason text NOT NULL,
  reason_category text NOT NULL CHECK (reason_category IN ('fraud','quality','safety','no_show','complaint','documentation','other')),
  evidence_urls text[] DEFAULT '{}'::text[],
  evidence_summary text,
  founder_approved boolean NOT NULL DEFAULT false,
  founder_approved_by uuid REFERENCES auth.users(id),
  founder_approved_at timestamptz,
  reinstatement_path text,
  sla_review_due_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','reinstated','permanent','archived')),
  reinstated_at timestamptz,
  reinstated_by uuid REFERENCES auth.users(id),
  reinstatement_notes text,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esa_engineer ON engineer_suspension_audit(engineer_id);
CREATE INDEX IF NOT EXISTS idx_esa_status ON engineer_suspension_audit(status);
CREATE INDEX IF NOT EXISTS idx_esa_sla ON engineer_suspension_audit(sla_review_due_at) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS idx_esa_created ON engineer_suspension_audit(created_at DESC);

ALTER TABLE engineer_suspension_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS esa_founder_all ON engineer_suspension_audit;
CREATE POLICY esa_founder_all ON engineer_suspension_audit
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_suspension_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES engineer_suspension_audit(id) ON DELETE CASCADE,
  reviewer_id uuid REFERENCES auth.users(id),
  reviewer_email text,
  decision text NOT NULL CHECK (decision IN ('uphold','reinstate','extend','escalate')),
  decision_notes text,
  reviewed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esr_audit ON engineer_suspension_reviews(audit_id);
CREATE INDEX IF NOT EXISTS idx_esr_reviewed ON engineer_suspension_reviews(reviewed_at DESC);

ALTER TABLE engineer_suspension_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS esr_founder_all ON engineer_suspension_reviews;
CREATE POLICY esr_founder_all ON engineer_suspension_reviews
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =============================================================
-- Logging helpers (VOLATILE SECDEF, founder-gated)
-- =============================================================

CREATE OR REPLACE FUNCTION log_founder_suspension_open(p_audit_id uuid, p_engineer_id uuid, p_reason_category text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'suspension_open', jsonb_build_object('audit_id', p_audit_id, 'engineer_id', p_engineer_id, 'category', p_reason_category));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_suspension_open(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_suspension_open(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_suspension_approve(p_audit_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'suspension_approve', jsonb_build_object('audit_id', p_audit_id));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_suspension_approve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_suspension_approve(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_suspension_reinstate(p_audit_id uuid, p_engineer_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'suspension_reinstate', jsonb_build_object('audit_id', p_audit_id, 'engineer_id', p_engineer_id));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_suspension_reinstate(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_suspension_reinstate(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_suspension_archive(p_archived_count int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'suspension_archive', jsonb_build_object('archived_count', p_archived_count));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_suspension_archive(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_suspension_archive(int) TO authenticated;

-- =============================================================
-- Read RPCs (STABLE SECDEF, founder-gated)
-- =============================================================

CREATE OR REPLACE FUNCTION founder_suspension_audit_kpis()
RETURNS TABLE (
  total_suspensions int,
  open_count int,
  approved_count int,
  reinstated_count int,
  permanent_count int,
  archived_count int,
  sla_breached_count int,
  avg_review_hours numeric,
  fraud_count int,
  quality_count int,
  safety_count int,
  no_show_count int,
  complaint_count int,
  documentation_count int,
  other_count int,
  evidence_attached_count int,
  l30d_new int,
  l30d_reinstated int,
  pending_founder_approval int,
  median_days_open numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status = 'open')::int,
    COUNT(*) FILTER (WHERE founder_approved)::int,
    COUNT(*) FILTER (WHERE status = 'reinstated')::int,
    COUNT(*) FILTER (WHERE status = 'permanent')::int,
    COUNT(*) FILTER (WHERE status = 'archived')::int,
    COUNT(*) FILTER (WHERE status = 'open' AND sla_review_due_at < now())::int,
    ROUND(AVG(EXTRACT(EPOCH FROM (founder_approved_at - created_at))/3600.0) FILTER (WHERE founder_approved_at IS NOT NULL), 2),
    COUNT(*) FILTER (WHERE reason_category = 'fraud')::int,
    COUNT(*) FILTER (WHERE reason_category = 'quality')::int,
    COUNT(*) FILTER (WHERE reason_category = 'safety')::int,
    COUNT(*) FILTER (WHERE reason_category = 'no_show')::int,
    COUNT(*) FILTER (WHERE reason_category = 'complaint')::int,
    COUNT(*) FILTER (WHERE reason_category = 'documentation')::int,
    COUNT(*) FILTER (WHERE reason_category = 'other')::int,
    COUNT(*) FILTER (WHERE array_length(evidence_urls, 1) > 0)::int,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::int,
    COUNT(*) FILTER (WHERE reinstated_at >= now() - interval '30 days')::int,
    COUNT(*) FILTER (WHERE status = 'open' AND NOT founder_approved)::int,
    ROUND((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (COALESCE(reinstated_at, archived_at, now()) - created_at))/86400.0) FROM engineer_suspension_audit)::numeric, 2)
  FROM engineer_suspension_audit;
END; $$;

REVOKE EXECUTE ON FUNCTION founder_suspension_audit_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_suspension_audit_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_suspension_audit_recent()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  reason_category text,
  reason text,
  status text,
  founder_approved boolean,
  sla_review_due_at timestamptz,
  evidence_count int,
  days_open numeric,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.engineer_id,
    p.email,
    a.reason_category,
    a.reason,
    a.status,
    a.founder_approved,
    a.sla_review_due_at,
    COALESCE(array_length(a.evidence_urls, 1), 0),
    ROUND(EXTRACT(EPOCH FROM (COALESCE(a.reinstated_at, a.archived_at, now()) - a.created_at))/86400.0, 1),
    a.created_at
  FROM engineer_suspension_audit a
  LEFT JOIN engineers e ON e.id = a.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY a.created_at DESC
  LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION founder_suspension_audit_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_suspension_audit_recent() TO authenticated;

CREATE OR REPLACE FUNCTION founder_suspension_audit_sla_breaches()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  reason_category text,
  hours_overdue numeric,
  sla_review_due_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.engineer_id,
    p.email,
    a.reason_category,
    ROUND(EXTRACT(EPOCH FROM (now() - a.sla_review_due_at))/3600.0, 1),
    a.sla_review_due_at
  FROM engineer_suspension_audit a
  LEFT JOIN engineers e ON e.id = a.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE a.status = 'open' AND a.sla_review_due_at < now()
  ORDER BY a.sla_review_due_at ASC
  LIMIT 50;
END; $$;

REVOKE EXECUTE ON FUNCTION founder_suspension_audit_sla_breaches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_suspension_audit_sla_breaches() TO authenticated;

CREATE OR REPLACE FUNCTION founder_suspension_audit_category_mix()
RETURNS TABLE (
  reason_category text,
  cnt int,
  reinstated int,
  permanent int,
  avg_days_open numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.reason_category,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE a.status = 'reinstated')::int,
    COUNT(*) FILTER (WHERE a.status = 'permanent')::int,
    ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(a.reinstated_at, a.archived_at, now()) - a.created_at))/86400.0), 1)
  FROM engineer_suspension_audit a
  GROUP BY a.reason_category
  ORDER BY COUNT(*) DESC;
END; $$;

REVOKE EXECUTE ON FUNCTION founder_suspension_audit_category_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_suspension_audit_category_mix() TO authenticated;

CREATE OR REPLACE FUNCTION founder_suspension_audit_reviews_recent()
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  reviewer_email text,
  decision text,
  decision_notes text,
  reviewed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.audit_id, r.reviewer_email, r.decision, r.decision_notes, r.reviewed_at
  FROM engineer_suspension_reviews r
  ORDER BY r.reviewed_at DESC
  LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION founder_suspension_audit_reviews_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_suspension_audit_reviews_recent() TO authenticated;

-- =============================================================
-- Write RPCs (VOLATILE SECDEF, founder-gated)
-- =============================================================

CREATE OR REPLACE FUNCTION founder_suspension_open(
  p_engineer_id uuid,
  p_reason text,
  p_reason_category text,
  p_evidence_urls text[],
  p_evidence_summary text,
  p_reinstatement_path text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_suspension_audit(engineer_id, suspended_by, reason, reason_category, evidence_urls, evidence_summary, reinstatement_path)
  VALUES (p_engineer_id, auth.uid(), p_reason, p_reason_category, COALESCE(p_evidence_urls, '{}'::text[]), p_evidence_summary, p_reinstatement_path)
  RETURNING id INTO v_id;
  PERFORM log_founder_suspension_open(v_id, p_engineer_id, p_reason_category);
  RETURN v_id;
END; $$;

REVOKE EXECUTE ON FUNCTION founder_suspension_open(uuid, text, text, text[], text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_suspension_open(uuid, text, text, text[], text, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_suspension_approve(p_audit_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_suspension_audit
  SET founder_approved = true,
      founder_approved_by = auth.uid(),
      founder_approved_at = now(),
      updated_at = now()
  WHERE id = p_audit_id;
  PERFORM log_founder_suspension_approve(p_audit_id);
END; $$;

REVOKE EXECUTE ON FUNCTION founder_suspension_approve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_suspension_approve(uuid) TO authenticated;

COMMIT;