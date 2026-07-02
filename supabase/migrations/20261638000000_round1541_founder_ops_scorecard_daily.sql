BEGIN;

-- ============================================================================
-- r1541 — Founder Ops Scorecard Daily
-- Daily ops health card: open jobs queue, unassigned escalations, payout
-- backlog, spare-part shortages, all P0/P1 incidents, founder action queue
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Daily scorecard snapshot table — one row per IST day
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_ops_scorecard_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date NOT NULL UNIQUE,
  open_jobs_count int NOT NULL DEFAULT 0,
  unassigned_jobs_count int NOT NULL DEFAULT 0,
  stuck_jobs_count int NOT NULL DEFAULT 0,
  payout_backlog_count int NOT NULL DEFAULT 0,
  payout_backlog_rupees bigint NOT NULL DEFAULT 0,
  spare_shortage_count int NOT NULL DEFAULT 0,
  p0_incidents_open int NOT NULL DEFAULT 0,
  p1_incidents_open int NOT NULL DEFAULT 0,
  amc_overdue_count int NOT NULL DEFAULT 0,
  health_score int NOT NULL DEFAULT 100,
  notes text,
  built_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_ops_scorecard_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_scorecard_snapshots" ON founder_ops_scorecard_snapshots;
CREATE POLICY "founder_only_scorecard_snapshots" ON founder_ops_scorecard_snapshots
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_scorecard_snapshots_date ON founder_ops_scorecard_snapshots(snapshot_date DESC);

-- ---------------------------------------------------------------------------
-- 2. Founder action queue (items founder must touch today)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_ops_action_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  queued_at timestamptz NOT NULL DEFAULT now(),
  category text NOT NULL CHECK (category IN ('incident','payout','escalation','amc','spare','review')),
  severity text NOT NULL DEFAULT 'p2' CHECK (severity IN ('p0','p1','p2','p3')),
  subject text NOT NULL,
  detail text,
  ref_table text,
  ref_id uuid,
  action_taken text,
  resolved_at timestamptz
);

ALTER TABLE founder_ops_action_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_action_queue" ON founder_ops_action_queue;
CREATE POLICY "founder_only_action_queue" ON founder_ops_action_queue
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_action_queue_open ON founder_ops_action_queue(queued_at DESC) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_action_queue_severity ON founder_ops_action_queue(severity, queued_at DESC);

-- ---------------------------------------------------------------------------
-- 3. READ RPCs (STABLE SECDEF, founder-gated)
-- ---------------------------------------------------------------------------

-- 3.1 Today snapshot summary
CREATE OR REPLACE FUNCTION rpc_founder_ops_scorecard_today()
RETURNS TABLE (
  snapshot_date date,
  open_jobs_count int,
  unassigned_jobs_count int,
  stuck_jobs_count int,
  payout_backlog_count int,
  payout_backlog_rupees bigint,
  spare_shortage_count int,
  p0_incidents_open int,
  p1_incidents_open int,
  amc_overdue_count int,
  health_score int,
  built_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.snapshot_date, s.open_jobs_count, s.unassigned_jobs_count, s.stuck_jobs_count,
         s.payout_backlog_count, s.payout_backlog_rupees, s.spare_shortage_count,
         s.p0_incidents_open, s.p1_incidents_open, s.amc_overdue_count, s.health_score, s.built_at
  FROM founder_ops_scorecard_snapshots s
  ORDER BY s.snapshot_date DESC
  LIMIT 1;
END $$;

-- 3.2 Open jobs queue
CREATE OR REPLACE FUNCTION rpc_founder_ops_open_jobs(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  status text,
  kind text,
  hospital_org_id uuid,
  contracted_amount_rupees bigint,
  created_at timestamptz,
  age_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.id, j.status::text, j.kind::text, j.hospital_org_id,
         j.contracted_amount_rupees, j.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - j.created_at))/86400.0, 1)::numeric AS age_days
  FROM repair_jobs j
  WHERE j.status IN ('open','assigned','in_progress','awaiting_parts')
  ORDER BY j.created_at ASC
  LIMIT GREATEST(p_limit, 1);
END $$;

-- 3.3 Unassigned escalations (open >48h, no engineer)
CREATE OR REPLACE FUNCTION rpc_founder_ops_unassigned_escalations()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  kind text,
  created_at timestamptz,
  hours_open numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.id, j.hospital_org_id, j.kind::text, j.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - j.created_at))/3600.0, 1)::numeric AS hours_open
  FROM repair_jobs j
  WHERE j.status = 'open'
    AND j.engineer_id IS NULL
    AND j.created_at < now() - interval '48 hours'
  ORDER BY j.created_at ASC
  LIMIT 200;
END $$;

-- 3.4 Payout backlog
CREATE OR REPLACE FUNCTION rpc_founder_ops_payout_backlog()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  amount_rupees bigint,
  created_at timestamptz,
  age_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.amount_rupees, p.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - p.created_at))/86400.0, 1)::numeric AS age_days
  FROM engineer_payouts p
  WHERE p.paid_at IS NULL
  ORDER BY p.created_at ASC
  LIMIT 200;
END $$;

-- 3.5 Spare part shortages (orders pending / not delivered)
CREATE OR REPLACE FUNCTION rpc_founder_ops_spare_shortages()
RETURNS TABLE (
  id uuid,
  supplier_org_id uuid,
  repair_job_id uuid,
  created_at timestamptz,
  age_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.supplier_org_id, o.repair_job_id, o.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - o.created_at))/86400.0, 1)::numeric AS age_days
  FROM spare_part_orders o
  WHERE o.delivered_at IS NULL
    AND o.created_at < now() - interval '24 hours'
  ORDER BY o.created_at ASC
  LIMIT 200;
END $$;

-- 3.6 Open P0/P1 incidents
CREATE OR REPLACE FUNCTION rpc_founder_ops_open_incidents()
RETURNS TABLE (
  id uuid,
  severity text,
  title text,
  opened_at timestamptz,
  hours_open numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.severity::text, i.title, i.opened_at,
         ROUND(EXTRACT(EPOCH FROM (now() - i.opened_at))/3600.0, 1)::numeric AS hours_open
  FROM founder_incidents i
  WHERE i.severity IN ('p0','p1')
    AND i.resolved_at IS NULL
  ORDER BY (CASE i.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 ELSE 2 END), i.opened_at ASC
  LIMIT 200;
END $$;

-- 3.7 Founder action queue (open items)
CREATE OR REPLACE FUNCTION rpc_founder_ops_action_queue()
RETURNS TABLE (
  id uuid,
  queued_at timestamptz,
  category text,
  severity text,
  subject text,
  detail text,
  age_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.queued_at, q.category, q.severity, q.subject, q.detail,
         ROUND(EXTRACT(EPOCH FROM (now() - q.queued_at))/3600.0, 1)::numeric AS age_hours
  FROM founder_ops_action_queue q
  WHERE q.resolved_at IS NULL
  ORDER BY (CASE q.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END),
           q.queued_at ASC
  LIMIT 200;
END $$;

-- ---------------------------------------------------------------------------
-- 4. WRITE RPCs (VOLATILE SECDEF, founder-gated)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION rpc_founder_ops_scorecard_build()
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_open int := 0; v_unassigned int := 0; v_stuck int := 0;
  v_payout_count int := 0; v_payout_rupees bigint := 0;
  v_spare int := 0; v_p0 int := 0; v_p1 int := 0;
  v_amc_overdue int := 0; v_score int := 100; v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) INTO v_open FROM repair_jobs
    WHERE status IN ('open','assigned','in_progress','awaiting_parts');

  SELECT COUNT(*) INTO v_unassigned FROM repair_jobs
    WHERE status='open' AND engineer_id IS NULL
      AND created_at < now() - interval '48 hours';

  SELECT COUNT(*) INTO v_stuck FROM repair_jobs
    WHERE status IN ('in_progress','awaiting_parts')
      AND created_at < now() - interval '7 days';

  SELECT COUNT(*), COALESCE(SUM(amount_rupees),0) INTO v_payout_count, v_payout_rupees
  FROM engineer_payouts WHERE paid_at IS NULL;

  SELECT COUNT(*) INTO v_spare FROM spare_part_orders
    WHERE delivered_at IS NULL AND created_at < now() - interval '24 hours';

  SELECT COUNT(*) INTO v_p0 FROM founder_incidents WHERE severity='p0' AND resolved_at IS NULL;
  SELECT COUNT(*) INTO v_p1 FROM founder_incidents WHERE severity='p1' AND resolved_at IS NULL;

  SELECT COUNT(*) INTO v_amc_overdue FROM amc_contracts
    WHERE status='active' AND end_date < CURRENT_DATE;

  v_score := GREATEST(0, 100 - (v_p0*25) - (v_p1*10) - LEAST(v_unassigned*2, 20) - LEAST(v_stuck, 15) - LEAST(v_spare, 10));

  INSERT INTO founder_ops_scorecard_snapshots (
    snapshot_date, open_jobs_count, unassigned_jobs_count, stuck_jobs_count,
    payout_backlog_count, payout_backlog_rupees, spare_shortage_count,
    p0_incidents_open, p1_incidents_open, amc_overdue_count, health_score, built_at
  ) VALUES (
    CURRENT_DATE, v_open, v_unassigned, v_stuck,
    v_payout_count, v_payout_rupees, v_spare,
    v_p0, v_p1, v_amc_overdue, v_score, now()
  )
  ON CONFLICT (snapshot_date) DO UPDATE SET
    open_jobs_count = EXCLUDED.open_jobs_count,
    unassigned_jobs_count = EXCLUDED.unassigned_jobs_count,
    stuck_jobs_count = EXCLUDED.stuck_jobs_count,
    payout_backlog_count = EXCLUDED.payout_backlog_count,
    payout_backlog_rupees = EXCLUDED.payout_backlog_rupees,
    spare_shortage_count = EXCLUDED.spare_shortage_count,
    p0_incidents_open = EXCLUDED.p0_incidents_open,
    p1_incidents_open = EXCLUDED.p1_incidents_open,
    amc_overdue_count = EXCLUDED.amc_overdue_count,
    health_score = EXCLUDED.health_score,
    built_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION rpc_founder_ops_action_enqueue(
  p_category text, p_severity text, p_subject text, p_detail text,
  p_ref_table text DEFAULT NULL, p_ref_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_ops_action_queue (category, severity, subject, detail, ref_table, ref_id)
  VALUES (p_category, p_severity, p_subject, p_detail, p_ref_table, p_ref_id)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION rpc_founder_ops_action_resolve(p_id uuid, p_action_taken text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_ops_action_queue
  SET action_taken = p_action_taken, resolved_at = now()
  WHERE id = p_id;
END $$;

-- ---------------------------------------------------------------------------
-- 5. log_founder_* helpers (VOLATILE SECDEF, founder-gated)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_ops_scorecard_view()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ops_scorecard_view',
          jsonb_build_object('viewed_at', now()));
END $$;

CREATE OR REPLACE FUNCTION log_founder_ops_scorecard_build(p_snapshot_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ops_scorecard_build',
          jsonb_build_object('snapshot_id', p_snapshot_id, 'at', now()));
END $$;

CREATE OR REPLACE FUNCTION log_founder_ops_action_enqueue(p_action_id uuid, p_category text, p_severity text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ops_action_enqueue',
          jsonb_build_object('action_id', p_action_id, 'category', p_category, 'severity', p_severity));
END $$;

CREATE OR REPLACE FUNCTION log_founder_ops_action_resolve(p_action_id uuid, p_action_taken text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ops_action_resolve',
          jsonb_build_object('action_id', p_action_id, 'action_taken', p_action_taken));
END $$;

-- ---------------------------------------------------------------------------
-- 6. GRANTS — revoke PUBLIC/anon, grant authenticated (founder gate enforced inside)
-- ---------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION rpc_founder_ops_scorecard_today() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_open_jobs(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_unassigned_escalations() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_payout_backlog() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_spare_shortages() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_open_incidents() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_action_queue() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_scorecard_build() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_action_enqueue(text,text,text,text,text,uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_ops_action_resolve(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_ops_scorecard_view() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_ops_scorecard_build(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_ops_action_enqueue(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_ops_action_resolve(uuid,text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_founder_ops_scorecard_today() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_open_jobs(int) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_unassigned_escalations() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_payout_backlog() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_spare_shortages() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_open_incidents() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_action_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_scorecard_build() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_action_enqueue(text,text,text,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_ops_action_resolve(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_ops_scorecard_view() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_ops_scorecard_build(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_ops_action_enqueue(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_ops_action_resolve(uuid,text) TO authenticated;

COMMIT;