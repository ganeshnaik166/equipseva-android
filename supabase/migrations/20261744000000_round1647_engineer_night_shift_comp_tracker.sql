BEGIN;

-- r1647: Engineer night-shift comp tracker
-- Per-engineer night-shift earnings + premium pay, reconciliation vs base pay, founder approval queue.

CREATE TABLE IF NOT EXISTS engineer_night_shift_shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL,
  shift_started_at timestamptz NOT NULL,
  shift_ended_at timestamptz NOT NULL,
  hours_worked numeric(6,2) NOT NULL DEFAULT 0,
  base_pay_rupees integer NOT NULL DEFAULT 0,
  night_premium_rupees integer NOT NULL DEFAULT 0,
  total_pay_rupees integer NOT NULL DEFAULT 0,
  jobs_count integer NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_night_shift_shifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_night_shift_shifts_founder ON engineer_night_shift_shifts;
CREATE POLICY engineer_night_shift_shifts_founder ON engineer_night_shift_shifts
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_ens_shifts_engineer ON engineer_night_shift_shifts(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ens_shifts_started ON engineer_night_shift_shifts(shift_started_at DESC);

CREATE TABLE IF NOT EXISTS engineer_night_shift_approval_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL,
  period_label text NOT NULL,
  total_premium_rupees integer NOT NULL DEFAULT 0,
  shifts_count integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  submitted_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by_email text,
  decision_note text
);

ALTER TABLE engineer_night_shift_approval_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_night_shift_approval_queue_founder ON engineer_night_shift_approval_queue;
CREATE POLICY engineer_night_shift_approval_queue_founder ON engineer_night_shift_approval_queue
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_ens_queue_status ON engineer_night_shift_approval_queue(status);
CREATE INDEX IF NOT EXISTS idx_ens_queue_submitted ON engineer_night_shift_approval_queue(submitted_at DESC);

-- Seed a few demo rows so console isn't empty
INSERT INTO engineer_night_shift_shifts (engineer_user_id, shift_started_at, shift_ended_at, hours_worked, base_pay_rupees, night_premium_rupees, total_pay_rupees, jobs_count)
SELECT e.user_id,
       now() - (interval '1 day' * (random()*14)::int) - interval '10 hours',
       now() - (interval '1 day' * (random()*14)::int) - interval '2 hours',
       8.0,
       2400,
       (1200 + (random()*1800)::int),
       (2400 + 1200 + (random()*1800)::int),
       (1 + (random()*4)::int)
FROM engineers e
LIMIT 24
ON CONFLICT DO NOTHING;

INSERT INTO engineer_night_shift_approval_queue (engineer_user_id, period_label, total_premium_rupees, shifts_count, status)
SELECT engineer_user_id,
       to_char(date_trunc('week', now()), 'YYYY-"W"IW'),
       SUM(night_premium_rupees)::int,
       COUNT(*)::int,
       'pending'
FROM engineer_night_shift_shifts
GROUP BY engineer_user_id
ON CONFLICT DO NOTHING;

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_night_shift_kpis();
CREATE OR REPLACE FUNCTION founder_night_shift_kpis()
RETURNS TABLE (
  total_shifts integer,
  total_engineers integer,
  total_premium_rupees bigint,
  total_base_rupees bigint,
  pending_approvals integer,
  approved_this_month integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM engineer_night_shift_shifts WHERE shift_started_at >= now() - interval '30 days'),
    (SELECT COUNT(DISTINCT engineer_user_id)::int FROM engineer_night_shift_shifts WHERE shift_started_at >= now() - interval '30 days'),
    COALESCE((SELECT SUM(night_premium_rupees)::bigint FROM engineer_night_shift_shifts WHERE shift_started_at >= now() - interval '30 days'), 0::bigint),
    COALESCE((SELECT SUM(base_pay_rupees)::bigint FROM engineer_night_shift_shifts WHERE shift_started_at >= now() - interval '30 days'), 0::bigint),
    (SELECT COUNT(*)::int FROM engineer_night_shift_approval_queue WHERE status = 'pending'),
    (SELECT COUNT(*)::int FROM engineer_night_shift_approval_queue WHERE status = 'approved' AND decided_at >= date_trunc('month', now()));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_kpis() TO authenticated;

-- RPC 2: Per-engineer comp rollup
DROP FUNCTION IF EXISTS founder_night_shift_per_engineer();
CREATE OR REPLACE FUNCTION founder_night_shift_per_engineer()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  tier text,
  shifts_count integer,
  total_hours numeric,
  base_pay_rupees bigint,
  premium_pay_rupees bigint,
  total_pay_rupees bigint,
  premium_ratio_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_user_id AS id,
    s.engineer_user_id,
    p.email AS engineer_email,
    e.cached_highest_tier AS tier,
    COUNT(*)::int AS shifts_count,
    COALESCE(SUM(s.hours_worked), 0)::numeric AS total_hours,
    COALESCE(SUM(s.base_pay_rupees), 0)::bigint AS base_pay_rupees,
    COALESCE(SUM(s.night_premium_rupees), 0)::bigint AS premium_pay_rupees,
    COALESCE(SUM(s.total_pay_rupees), 0)::bigint AS total_pay_rupees,
    CASE WHEN COALESCE(SUM(s.base_pay_rupees), 0) > 0
         THEN ROUND((COALESCE(SUM(s.night_premium_rupees), 0)::numeric / SUM(s.base_pay_rupees)::numeric) * 100, 1)
         ELSE 0 END AS premium_ratio_pct
  FROM engineer_night_shift_shifts s
  LEFT JOIN profiles p ON p.id = s.engineer_user_id
  LEFT JOIN engineers e ON e.user_id = s.engineer_user_id
  WHERE s.shift_started_at >= now() - interval '30 days'
  GROUP BY s.engineer_user_id, p.email, e.cached_highest_tier
  ORDER BY premium_pay_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_per_engineer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_per_engineer() TO authenticated;

-- RPC 3: Recent shifts
DROP FUNCTION IF EXISTS founder_night_shift_recent_shifts();
CREATE OR REPLACE FUNCTION founder_night_shift_recent_shifts()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  shift_started_at timestamptz,
  hours_worked numeric,
  jobs_count integer,
  base_pay_rupees integer,
  night_premium_rupees integer,
  total_pay_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.shift_started_at, s.hours_worked, s.jobs_count,
         s.base_pay_rupees, s.night_premium_rupees, s.total_pay_rupees
  FROM engineer_night_shift_shifts s
  LEFT JOIN profiles p ON p.id = s.engineer_user_id
  ORDER BY s.shift_started_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_recent_shifts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_recent_shifts() TO authenticated;

-- RPC 4: Approval queue
DROP FUNCTION IF EXISTS founder_night_shift_pending_queue();
CREATE OR REPLACE FUNCTION founder_night_shift_pending_queue()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  period_label text,
  shifts_count integer,
  total_premium_rupees integer,
  status text,
  submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, p.email, q.period_label, q.shifts_count, q.total_premium_rupees, q.status, q.submitted_at
  FROM engineer_night_shift_approval_queue q
  LEFT JOIN profiles p ON p.id = q.engineer_user_id
  WHERE q.status = 'pending'
  ORDER BY q.submitted_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_pending_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_pending_queue() TO authenticated;

-- RPC 5: Reconciliation vs base pay (payouts)
DROP FUNCTION IF EXISTS founder_night_shift_reconciliation();
CREATE OR REPLACE FUNCTION founder_night_shift_reconciliation()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  shifts_premium_rupees bigint,
  payouts_total_rupees bigint,
  delta_rupees bigint,
  payouts_paid_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_user_id AS id,
    p.email AS engineer_email,
    COALESCE(SUM(s.night_premium_rupees), 0)::bigint AS shifts_premium_rupees,
    COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts ep WHERE ep.engineer_user_id = s.engineer_user_id AND ep.paid_at IS NOT NULL AND ep.paid_at >= now() - interval '30 days'), 0)::bigint AS payouts_total_rupees,
    COALESCE(SUM(s.night_premium_rupees), 0)::bigint - COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts ep WHERE ep.engineer_user_id = s.engineer_user_id AND ep.paid_at IS NOT NULL AND ep.paid_at >= now() - interval '30 days'), 0)::bigint AS delta_rupees,
    COALESCE((SELECT COUNT(*) FILTER (WHERE ep.paid_at IS NOT NULL) FROM engineer_payouts ep WHERE ep.engineer_user_id = s.engineer_user_id AND ep.paid_at >= now() - interval '30 days'), 0)::int AS payouts_paid_count
  FROM engineer_night_shift_shifts s
  LEFT JOIN profiles p ON p.id = s.engineer_user_id
  WHERE s.shift_started_at >= now() - interval '30 days'
  GROUP BY s.engineer_user_id, p.email
  ORDER BY delta_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_reconciliation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_reconciliation() TO authenticated;

-- RPC 6: Approve queue row (VOLATILE)
DROP FUNCTION IF EXISTS founder_night_shift_approve(uuid, text);
CREATE OR REPLACE FUNCTION founder_night_shift_approve(p_id uuid, p_note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_night_shift_approval_queue
     SET status = 'approved',
         decided_at = now(),
         decided_by_email = (auth.jwt()->>'email'),
         decision_note = p_note
   WHERE id = p_id AND status = 'pending';
  INSERT INTO founder_action_log(action_type, actor_email, target_kind, target_id, note)
  VALUES ('night_shift_approve', (auth.jwt()->>'email'), 'night_shift_queue', p_id::text, p_note);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_approve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_approve(uuid, text) TO authenticated;

-- RPC 7: Reject queue row (VOLATILE)
DROP FUNCTION IF EXISTS founder_night_shift_reject(uuid, text);
CREATE OR REPLACE FUNCTION founder_night_shift_reject(p_id uuid, p_note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_night_shift_approval_queue
     SET status = 'rejected',
         decided_at = now(),
         decided_by_email = (auth.jwt()->>'email'),
         decision_note = p_note
   WHERE id = p_id AND status = 'pending';
  INSERT INTO founder_action_log(action_type, actor_email, target_kind, target_id, note)
  VALUES ('night_shift_reject', (auth.jwt()->>'email'), 'night_shift_queue', p_id::text, p_note);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_reject(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_reject(uuid, text) TO authenticated;

COMMIT;