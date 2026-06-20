BEGIN;

-- ============================================================================
-- r1480 — Engineer payouts disputes ledger
-- 2 tables (disputes + events), 7 SECDEF RPCs, 4 log helpers, RLS founder-only
-- ============================================================================

-- ---- Tables ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineer_payout_disputes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payout_id uuid REFERENCES engineer_payouts(id) ON DELETE SET NULL,
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  repair_job_id uuid REFERENCES repair_jobs(id) ON DELETE SET NULL,
  dispute_type text NOT NULL CHECK (dispute_type IN ('amount_mismatch','missing_payout','late_payout','wrong_job','other')),
  claimed_amount_rupees integer,
  current_amount_rupees integer,
  delta_rupees integer,
  engineer_notes text,
  status text NOT NULL DEFAULT 'raised' CHECK (status IN ('raised','investigating','resolved','escalated','closed')),
  resolution_notes text,
  resolved_amount_rupees integer,
  raised_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  closed_at timestamptz,
  sla_target_at timestamptz NOT NULL DEFAULT (now() + interval '48 hours'),
  assigned_founder_email text,
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_epd_status ON engineer_payout_disputes(status);
CREATE INDEX IF NOT EXISTS idx_epd_engineer ON engineer_payout_disputes(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_epd_payout ON engineer_payout_disputes(payout_id);
CREATE INDEX IF NOT EXISTS idx_epd_raised_at ON engineer_payout_disputes(raised_at DESC);
CREATE INDEX IF NOT EXISTS idx_epd_sla ON engineer_payout_disputes(sla_target_at) WHERE status IN ('raised','investigating');

CREATE TABLE IF NOT EXISTS engineer_payout_dispute_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id uuid NOT NULL REFERENCES engineer_payout_disputes(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  actor_email text,
  note text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_epde_dispute ON engineer_payout_dispute_events(dispute_id, created_at DESC);

ALTER TABLE engineer_payout_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_payout_dispute_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS epd_founder_all ON engineer_payout_disputes;
CREATE POLICY epd_founder_all ON engineer_payout_disputes
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS epde_founder_all ON engineer_payout_dispute_events;
CREATE POLICY epde_founder_all ON engineer_payout_dispute_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---- Log helpers (VOLATILE SECDEF) -----------------------------------------

CREATE OR REPLACE FUNCTION log_founder_dispute_raised(p_dispute_id uuid, p_note text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.email(), 'dispute_raised',
    jsonb_build_object('dispute_id', p_dispute_id, 'note', p_note));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_dispute_raised(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_dispute_raised(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_dispute_transition(p_dispute_id uuid, p_from text, p_to text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.email(), 'dispute_transition',
    jsonb_build_object('dispute_id', p_dispute_id, 'from', p_from, 'to', p_to));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_dispute_transition(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_dispute_transition(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_dispute_resolved(p_dispute_id uuid, p_amount integer, p_note text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.email(), 'dispute_resolved',
    jsonb_build_object('dispute_id', p_dispute_id, 'amount_rupees', p_amount, 'note', p_note));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_dispute_resolved(uuid,integer,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_dispute_resolved(uuid,integer,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_dispute_escalated(p_dispute_id uuid, p_reason text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.email(), 'dispute_escalated',
    jsonb_build_object('dispute_id', p_dispute_id, 'reason', p_reason));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_dispute_escalated(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_dispute_escalated(uuid,text) TO authenticated;

-- ---- 7 SECDEF RPCs ---------------------------------------------------------

-- 1) read: open disputes feed
CREATE OR REPLACE FUNCTION founder_dispute_open_feed()
RETURNS TABLE (
  id uuid, engineer_user_id uuid, engineer_email text, payout_id uuid,
  dispute_type text, status text, priority text,
  claimed_amount_rupees integer, current_amount_rupees integer, delta_rupees integer,
  raised_at timestamptz, sla_target_at timestamptz, hours_to_sla numeric,
  engineer_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_user_id, p.email, d.payout_id,
         d.dispute_type, d.status, d.priority,
         d.claimed_amount_rupees, d.current_amount_rupees, d.delta_rupees,
         d.raised_at, d.sla_target_at,
         EXTRACT(EPOCH FROM (d.sla_target_at - now()))/3600.0,
         d.engineer_notes
  FROM engineer_payout_disputes d
  LEFT JOIN profiles p ON p.id = d.engineer_user_id
  WHERE d.status IN ('raised','investigating','escalated')
  ORDER BY
    CASE d.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END,
    d.sla_target_at ASC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_dispute_open_feed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dispute_open_feed() TO authenticated;

-- 2) read: KPIs
CREATE OR REPLACE FUNCTION founder_dispute_kpis()
RETURNS TABLE (
  total_disputes integer, open_count integer, raised_count integer,
  investigating_count integer, resolved_count integer, escalated_count integer,
  closed_count integer, sla_breached integer, sla_within_4h integer,
  median_resolution_hours numeric, total_delta_rupees integer,
  paid_back_rupees integer, urgent_count integer, last_24h_raised integer,
  amount_disputes integer, missing_disputes integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status IN ('raised','investigating','escalated'))::int,
    COUNT(*) FILTER (WHERE status='raised')::int,
    COUNT(*) FILTER (WHERE status='investigating')::int,
    COUNT(*) FILTER (WHERE status='resolved')::int,
    COUNT(*) FILTER (WHERE status='escalated')::int,
    COUNT(*) FILTER (WHERE status='closed')::int,
    COUNT(*) FILTER (WHERE sla_target_at < now() AND status IN ('raised','investigating'))::int,
    COUNT(*) FILTER (WHERE sla_target_at < now() + interval '4 hours' AND sla_target_at >= now() AND status IN ('raised','investigating'))::int,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_at - raised_at))/3600.0) FILTER (WHERE resolved_at IS NOT NULL),
    COALESCE(SUM(delta_rupees),0)::int,
    COALESCE(SUM(resolved_amount_rupees) FILTER (WHERE status IN ('resolved','closed')),0)::int,
    COUNT(*) FILTER (WHERE priority='urgent' AND status IN ('raised','investigating','escalated'))::int,
    COUNT(*) FILTER (WHERE raised_at > now() - interval '24 hours')::int,
    COUNT(*) FILTER (WHERE dispute_type='amount_mismatch')::int,
    COUNT(*) FILTER (WHERE dispute_type='missing_payout')::int
  FROM engineer_payout_disputes;
END $$;
REVOKE EXECUTE ON FUNCTION founder_dispute_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dispute_kpis() TO authenticated;

-- 3) read: by type breakdown
CREATE OR REPLACE FUNCTION founder_dispute_by_type()
RETURNS TABLE (
  dispute_type text, total integer, open_count integer,
  resolved_count integer, avg_resolution_hours numeric, total_delta_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.dispute_type,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE d.status IN ('raised','investigating','escalated'))::int,
         COUNT(*) FILTER (WHERE d.status='resolved')::int,
         AVG(EXTRACT(EPOCH FROM (d.resolved_at - d.raised_at))/3600.0) FILTER (WHERE d.resolved_at IS NOT NULL),
         COALESCE(SUM(d.delta_rupees),0)::int
  FROM engineer_payout_disputes d
  GROUP BY d.dispute_type
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_dispute_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dispute_by_type() TO authenticated;

-- 4) read: top complaining engineers
CREATE OR REPLACE FUNCTION founder_dispute_top_engineers()
RETURNS TABLE (
  engineer_user_id uuid, engineer_email text, dispute_count integer,
  open_count integer, total_delta_rupees integer, last_raised_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.engineer_user_id, p.email,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE d.status IN ('raised','investigating','escalated'))::int,
         COALESCE(SUM(d.delta_rupees),0)::int,
         MAX(d.raised_at)
  FROM engineer_payout_disputes d
  LEFT JOIN profiles p ON p.id = d.engineer_user_id
  GROUP BY d.engineer_user_id, p.email
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_dispute_top_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dispute_top_engineers() TO authenticated;

-- 5) read: recent transitions
CREATE OR REPLACE FUNCTION founder_dispute_recent_events()
RETURNS TABLE (
  id uuid, dispute_id uuid, from_status text, to_status text,
  actor_email text, note text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.dispute_id, e.from_status, e.to_status,
         e.actor_email, e.note, e.created_at
  FROM engineer_payout_dispute_events e
  ORDER BY e.created_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_dispute_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dispute_recent_events() TO authenticated;

-- 6) write: transition dispute status (VOLATILE)
CREATE OR REPLACE FUNCTION founder_dispute_transition(
  p_dispute_id uuid, p_to_status text, p_note text DEFAULT NULL,
  p_resolved_amount integer DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_from text; v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_to_status NOT IN ('raised','investigating','resolved','escalated','closed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  SELECT status INTO v_from FROM engineer_payout_disputes WHERE id = p_dispute_id;
  IF v_from IS NULL THEN RAISE EXCEPTION 'not_found'; END IF;
  v_email := auth.email();
  UPDATE engineer_payout_disputes
     SET status = p_to_status,
         resolution_notes = COALESCE(p_note, resolution_notes),
         resolved_amount_rupees = COALESCE(p_resolved_amount, resolved_amount_rupees),
         acknowledged_at = CASE WHEN p_to_status='investigating' AND acknowledged_at IS NULL THEN now() ELSE acknowledged_at END,
         resolved_at = CASE WHEN p_to_status='resolved' AND resolved_at IS NULL THEN now() ELSE resolved_at END,
         closed_at = CASE WHEN p_to_status='closed' AND closed_at IS NULL THEN now() ELSE closed_at END,
         assigned_founder_email = COALESCE(assigned_founder_email, v_email),
         updated_at = now()
   WHERE id = p_dispute_id;
  INSERT INTO engineer_payout_dispute_events(dispute_id, from_status, to_status, actor_email, note)
  VALUES (p_dispute_id, v_from, p_to_status, v_email, p_note);
  PERFORM log_founder_dispute_transition(p_dispute_id, v_from, p_to_status);
  IF p_to_status = 'resolved' THEN
    PERFORM log_founder_dispute_resolved(p_dispute_id, p_resolved_amount, p_note);
  ELSIF p_to_status = 'escalated' THEN
    PERFORM log_founder_dispute_escalated(p_dispute_id, p_note);
  END IF;
  RETURN p_dispute_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_dispute_transition(uuid,text,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dispute_transition(uuid,text,text,integer) TO authenticated;

-- 7) write: raise dispute on behalf of engineer (VOLATILE)
CREATE OR REPLACE FUNCTION founder_dispute_raise(
  p_engineer_user_id uuid, p_payout_id uuid, p_dispute_type text,
  p_claimed_amount integer, p_current_amount integer, p_notes text,
  p_priority text DEFAULT 'normal'
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_dispute_type NOT IN ('amount_mismatch','missing_payout','late_payout','wrong_job','other') THEN
    RAISE EXCEPTION 'invalid_type';
  END IF;
  v_email := auth.email();
  INSERT INTO engineer_payout_disputes(
    engineer_user_id, payout_id, dispute_type,
    claimed_amount_rupees, current_amount_rupees,
    delta_rupees, engineer_notes, priority, assigned_founder_email
  ) VALUES (
    p_engineer_user_id, p_payout_id, p_dispute_type,
    p_claimed_amount, p_current_amount,
    COALESCE(p_claimed_amount,0) - COALESCE(p_current_amount,0),
    p_notes, p_priority, v_email
  ) RETURNING id INTO v_id;
  INSERT INTO engineer_payout_dispute_events(dispute_id, from_status, to_status, actor_email, note)
  VALUES (v_id, NULL, 'raised', v_email, p_notes);
  PERFORM log_founder_dispute_raised(v_id, p_notes);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_dispute_raise(uuid,uuid,text,integer,integer,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_dispute_raise(uuid,uuid,text,integer,integer,text,text) TO authenticated;

COMMIT;