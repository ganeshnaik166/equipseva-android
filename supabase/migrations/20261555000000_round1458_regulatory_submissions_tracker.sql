BEGIN;

-- ============================================================
-- r1458 — Regulatory submissions tracker
-- CDSCO + state drug control + Udyam + GST + MSME license/filing log
-- ============================================================

CREATE TABLE IF NOT EXISTS regulatory_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  authority text NOT NULL CHECK (authority IN ('cdsco','state_drug_control','udyam','gst','msme','dpdp','fssai','bis','other')),
  submission_type text NOT NULL,
  reference_number text,
  title text NOT NULL,
  description text,
  submitted_at timestamptz,
  due_at timestamptz,
  expires_at timestamptz,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','submitted','under_review','approved','rejected','expired','renewed')),
  approval_stage text,
  approval_stages_total int DEFAULT 1,
  approval_stages_done int DEFAULT 0,
  filing_fee_rupees int DEFAULT 0,
  state_code text,
  responsible_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  external_url text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_regsub_authority ON regulatory_submissions(authority);
CREATE INDEX IF NOT EXISTS idx_regsub_status ON regulatory_submissions(status);
CREATE INDEX IF NOT EXISTS idx_regsub_due ON regulatory_submissions(due_at);
CREATE INDEX IF NOT EXISTS idx_regsub_expires ON regulatory_submissions(expires_at);

ALTER TABLE regulatory_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS regsub_founder_all ON regulatory_submissions;
CREATE POLICY regsub_founder_all ON regulatory_submissions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS regulatory_submission_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES regulatory_submissions(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','submitted','stage_advanced','approved','rejected','expired','renewed','note_added','reminder_set')),
  actor_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  payload jsonb DEFAULT '{}'::jsonb,
  note text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_regsub_events_sub ON regulatory_submission_events(submission_id);
CREATE INDEX IF NOT EXISTS idx_regsub_events_time ON regulatory_submission_events(occurred_at DESC);

ALTER TABLE regulatory_submission_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS regsub_events_founder_all ON regulatory_submission_events;
CREATE POLICY regsub_events_founder_all ON regulatory_submission_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- SECDEF read RPCs (7)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_regsub_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_submissions', (SELECT count(*) FROM regulatory_submissions),
    'active_licenses', (SELECT count(*) FROM regulatory_submissions WHERE status IN ('approved','renewed')),
    'pending_review', (SELECT count(*) FROM regulatory_submissions WHERE status IN ('submitted','under_review')),
    'draft', (SELECT count(*) FROM regulatory_submissions WHERE status = 'draft'),
    'rejected', (SELECT count(*) FROM regulatory_submissions WHERE status = 'rejected'),
    'expired', (SELECT count(*) FROM regulatory_submissions WHERE status = 'expired'),
    'expiring_30d', (SELECT count(*) FROM regulatory_submissions WHERE expires_at IS NOT NULL AND expires_at <= now() + interval '30 days' AND expires_at > now()),
    'expiring_90d', (SELECT count(*) FROM regulatory_submissions WHERE expires_at IS NOT NULL AND expires_at <= now() + interval '90 days' AND expires_at > now()),
    'overdue', (SELECT count(*) FROM regulatory_submissions WHERE due_at IS NOT NULL AND due_at < now() AND status NOT IN ('approved','renewed','expired','rejected')),
    'due_7d', (SELECT count(*) FROM regulatory_submissions WHERE due_at IS NOT NULL AND due_at <= now() + interval '7 days' AND due_at > now()),
    'cdsco_count', (SELECT count(*) FROM regulatory_submissions WHERE authority = 'cdsco'),
    'state_dc_count', (SELECT count(*) FROM regulatory_submissions WHERE authority = 'state_drug_control'),
    'udyam_count', (SELECT count(*) FROM regulatory_submissions WHERE authority = 'udyam'),
    'gst_count', (SELECT count(*) FROM regulatory_submissions WHERE authority = 'gst'),
    'msme_count', (SELECT count(*) FROM regulatory_submissions WHERE authority = 'msme'),
    'total_filing_fee_rupees', COALESCE((SELECT sum(filing_fee_rupees) FROM regulatory_submissions),0)
  ) INTO v;
  RETURN v;
END $$;

GRANT EXECUTE ON FUNCTION founder_regsub_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_regsub_expiring_soon()
RETURNS TABLE(id uuid, authority text, title text, reference_number text, expires_at timestamptz, days_until int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.authority, r.title, r.reference_number, r.expires_at,
         EXTRACT(DAY FROM (r.expires_at - now()))::int AS days_until,
         r.status
  FROM regulatory_submissions r
  WHERE r.expires_at IS NOT NULL
    AND r.expires_at <= now() + interval '120 days'
    AND r.status IN ('approved','renewed','submitted','under_review')
  ORDER BY r.expires_at ASC
  LIMIT 50;
END $$;

GRANT EXECUTE ON FUNCTION founder_regsub_expiring_soon() TO authenticated;

CREATE OR REPLACE FUNCTION founder_regsub_overdue_filings()
RETURNS TABLE(id uuid, authority text, title text, reference_number text, due_at timestamptz, days_overdue int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.authority, r.title, r.reference_number, r.due_at,
         EXTRACT(DAY FROM (now() - r.due_at))::int AS days_overdue,
         r.status
  FROM regulatory_submissions r
  WHERE r.due_at IS NOT NULL
    AND r.due_at < now()
    AND r.status NOT IN ('approved','renewed','expired','rejected')
  ORDER BY r.due_at ASC
  LIMIT 50;
END $$;

GRANT EXECUTE ON FUNCTION founder_regsub_overdue_filings() TO authenticated;

CREATE OR REPLACE FUNCTION founder_regsub_approval_ladder()
RETURNS TABLE(id uuid, authority text, title text, approval_stage text, approval_stages_done int, approval_stages_total int, status text, submitted_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.authority, r.title, r.approval_stage, r.approval_stages_done, r.approval_stages_total, r.status, r.submitted_at
  FROM regulatory_submissions r
  WHERE r.status IN ('submitted','under_review')
  ORDER BY r.submitted_at ASC NULLS LAST
  LIMIT 50;
END $$;

GRANT EXECUTE ON FUNCTION founder_regsub_approval_ladder() TO authenticated;

CREATE OR REPLACE FUNCTION founder_regsub_by_authority()
RETURNS TABLE(authority text, total int, approved int, pending int, rejected int, total_fee_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.authority,
         count(*)::int AS total,
         count(*) FILTER (WHERE r.status IN ('approved','renewed'))::int AS approved,
         count(*) FILTER (WHERE r.status IN ('submitted','under_review','draft'))::int AS pending,
         count(*) FILTER (WHERE r.status = 'rejected')::int AS rejected,
         COALESCE(sum(r.filing_fee_rupees),0)::bigint AS total_fee_rupees
  FROM regulatory_submissions r
  GROUP BY r.authority
  ORDER BY total DESC;
END $$;

GRANT EXECUTE ON FUNCTION founder_regsub_by_authority() TO authenticated;

CREATE OR REPLACE FUNCTION founder_regsub_recent_events(p_limit int DEFAULT 30)
RETURNS TABLE(id uuid, submission_id uuid, authority text, title text, event_type text, note text, occurred_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.submission_id, r.authority, r.title, e.event_type, e.note, e.occurred_at
  FROM regulatory_submission_events e
  JOIN regulatory_submissions r ON r.id = e.submission_id
  ORDER BY e.occurred_at DESC
  LIMIT p_limit;
END $$;

GRANT EXECUTE ON FUNCTION founder_regsub_recent_events(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_regsub_active_licenses()
RETURNS TABLE(id uuid, authority text, title text, reference_number text, expires_at timestamptz, state_code text, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.authority, r.title, r.reference_number, r.expires_at, r.state_code, r.status
  FROM regulatory_submissions r
  WHERE r.status IN ('approved','renewed')
  ORDER BY r.expires_at ASC NULLS LAST
  LIMIT 100;
END $$;

GRANT EXECUTE ON FUNCTION founder_regsub_active_licenses() TO authenticated;

-- ============================================================
-- VOLATILE log_founder_* helpers (4)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_regsub_create(
  p_authority text,
  p_submission_type text,
  p_title text,
  p_due_at timestamptz,
  p_state_code text DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO regulatory_submissions(authority, submission_type, title, due_at, state_code, notes, status)
  VALUES (p_authority, p_submission_type, p_title, p_due_at, p_state_code, p_notes, 'draft')
  RETURNING id INTO v_id;

  INSERT INTO regulatory_submission_events(submission_id, event_type, actor_user_id, note)
  VALUES (v_id, 'created', auth.uid(), p_notes);
  RETURN v_id;
END $$;

GRANT EXECUTE ON FUNCTION log_founder_regsub_create(text,text,text,timestamptz,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_regsub_submit(
  p_submission_id uuid,
  p_reference_number text,
  p_filing_fee_rupees int DEFAULT 0
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE regulatory_submissions
     SET status = 'submitted',
         reference_number = COALESCE(p_reference_number, reference_number),
         filing_fee_rupees = COALESCE(p_filing_fee_rupees, filing_fee_rupees),
         submitted_at = now(),
         updated_at = now()
   WHERE id = p_submission_id;

  INSERT INTO regulatory_submission_events(submission_id, event_type, actor_user_id, payload)
  VALUES (p_submission_id, 'submitted', auth.uid(), jsonb_build_object('reference_number', p_reference_number, 'filing_fee_rupees', p_filing_fee_rupees));
END $$;

GRANT EXECUTE ON FUNCTION log_founder_regsub_submit(uuid,text,int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_regsub_advance_stage(
  p_submission_id uuid,
  p_stage_label text,
  p_note text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE regulatory_submissions
     SET approval_stage = p_stage_label,
         approval_stages_done = LEAST(approval_stages_done + 1, COALESCE(approval_stages_total, 1)),
         status = 'under_review',
         updated_at = now()
   WHERE id = p_submission_id;

  INSERT INTO regulatory_submission_events(submission_id, event_type, actor_user_id, note, payload)
  VALUES (p_submission_id, 'stage_advanced', auth.uid(), p_note, jsonb_build_object('stage', p_stage_label));
END $$;

GRANT EXECUTE ON FUNCTION log_founder_regsub_advance_stage(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_regsub_decide(
  p_submission_id uuid,
  p_outcome text,
  p_expires_at timestamptz DEFAULT NULL,
  p_note text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_outcome NOT IN ('approved','rejected','renewed','expired') THEN
    RAISE EXCEPTION 'invalid_outcome';
  END IF;
  UPDATE regulatory_submissions
     SET status = p_outcome,
         expires_at = COALESCE(p_expires_at, expires_at),
         updated_at = now()
   WHERE id = p_submission_id;

  INSERT INTO regulatory_submission_events(submission_id, event_type, actor_user_id, note, payload)
  VALUES (p_submission_id, p_outcome, auth.uid(), p_note, jsonb_build_object('expires_at', p_expires_at));
END $$;

GRANT EXECUTE ON FUNCTION log_founder_regsub_decide(uuid,text,timestamptz,text) TO authenticated;

COMMIT;