BEGIN;

-- ============================================================
-- r1611 — Engineer Retention Bonus Log
-- Pay retention bonuses to high-performers at risk of leaving
-- Per-engineer amount + reason + duration + founder approval ladder
-- ============================================================

-- Tables ----------------------------------------------------

CREATE TABLE IF NOT EXISTS engineer_retention_bonuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  amount_rupees integer NOT NULL CHECK (amount_rupees > 0 AND amount_rupees <= 500000),
  reason text NOT NULL CHECK (length(reason) BETWEEN 12 AND 800),
  risk_signal text NOT NULL CHECK (risk_signal IN ('competitor_offer','burnout','pay_complaint','relocation','tier_drop','silent_quit','other')),
  duration_months integer NOT NULL CHECK (duration_months BETWEEN 1 AND 24),
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','l1_approved','l2_approved','paid','rejected','cancelled')),
  proposed_by uuid REFERENCES auth.users(id),
  l1_approver uuid REFERENCES auth.users(id),
  l1_approved_at timestamptz,
  l2_approver uuid REFERENCES auth.users(id),
  l2_approved_at timestamptz,
  paid_at timestamptz,
  rejected_reason text,
  effective_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_retention_bonuses_engineer_idx ON engineer_retention_bonuses(engineer_id);
CREATE INDEX IF NOT EXISTS engineer_retention_bonuses_status_idx ON engineer_retention_bonuses(status);
CREATE INDEX IF NOT EXISTS engineer_retention_bonuses_created_idx ON engineer_retention_bonuses(created_at DESC);

CREATE TABLE IF NOT EXISTS engineer_retention_bonus_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bonus_id uuid NOT NULL REFERENCES engineer_retention_bonuses(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('proposed','l1_approved','l2_approved','paid','rejected','cancelled','note')),
  actor_user_id uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_retention_bonus_events_bonus_idx ON engineer_retention_bonus_events(bonus_id, created_at DESC);

ALTER TABLE engineer_retention_bonuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_retention_bonus_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_retention_bonuses ON engineer_retention_bonuses;
CREATE POLICY founder_only_retention_bonuses ON engineer_retention_bonuses
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_retention_bonus_events ON engineer_retention_bonus_events;
CREATE POLICY founder_only_retention_bonus_events ON engineer_retention_bonus_events
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Log helpers (VOLATILE SECDEF) -----------------------------

CREATE OR REPLACE FUNCTION log_founder_retention_bonus_proposed(p_bonus_id uuid, p_amount integer, p_engineer uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'retention_bonus_proposed',
          jsonb_build_object('bonus_id', p_bonus_id, 'amount_rupees', p_amount, 'engineer_id', p_engineer), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_retention_bonus_proposed(uuid, integer, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_retention_bonus_proposed(uuid, integer, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_retention_bonus_approved(p_bonus_id uuid, p_level text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'retention_bonus_approved',
          jsonb_build_object('bonus_id', p_bonus_id, 'level', p_level), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_retention_bonus_approved(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_retention_bonus_approved(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_retention_bonus_paid(p_bonus_id uuid, p_amount integer)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'retention_bonus_paid',
          jsonb_build_object('bonus_id', p_bonus_id, 'amount_rupees', p_amount), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_retention_bonus_paid(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_retention_bonus_paid(uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_retention_bonus_rejected(p_bonus_id uuid, p_reason text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'retention_bonus_rejected',
          jsonb_build_object('bonus_id', p_bonus_id, 'reason', p_reason), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_retention_bonus_rejected(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_retention_bonus_rejected(uuid, text) TO authenticated;

-- Read RPCs (STABLE SECDEF) ---------------------------------

CREATE OR REPLACE FUNCTION founder_retention_bonus_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH agg AS (
    SELECT
      count(*) AS total,
      count(*) FILTER (WHERE status='proposed') AS proposed,
      count(*) FILTER (WHERE status='l1_approved') AS l1_approved,
      count(*) FILTER (WHERE status='l2_approved') AS l2_approved,
      count(*) FILTER (WHERE status='paid') AS paid,
      count(*) FILTER (WHERE status='rejected') AS rejected,
      count(*) FILTER (WHERE status='cancelled') AS cancelled,
      coalesce(sum(amount_rupees) FILTER (WHERE status='paid'),0) AS paid_total,
      coalesce(sum(amount_rupees) FILTER (WHERE status IN ('proposed','l1_approved','l2_approved')),0) AS pipeline_total,
      coalesce(avg(amount_rupees) FILTER (WHERE status='paid'),0)::numeric(12,2) AS avg_paid,
      coalesce(max(amount_rupees) FILTER (WHERE status='paid'),0) AS max_paid,
      count(*) FILTER (WHERE created_at >= now() - interval '30 days') AS last_30d,
      count(*) FILTER (WHERE created_at >= now() - interval '7 days') AS last_7d,
      count(DISTINCT engineer_id) AS unique_engineers,
      count(*) FILTER (WHERE effective_until > now() AND status='paid') AS active_now,
      coalesce(avg(duration_months) FILTER (WHERE status='paid'),0)::numeric(8,2) AS avg_duration_months
  FROM engineer_retention_bonuses )
  SELECT to_jsonb(agg.*) INTO result FROM agg;
  RETURN coalesce(result, '{}'::jsonb);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_retention_bonus_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_retention_bonus_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_retention_bonus_list(p_limit integer DEFAULT 100)
RETURNS TABLE(id uuid, engineer_id uuid, engineer_name text, amount_rupees integer, status text, risk_signal text, duration_months integer, reason text, created_at timestamptz, effective_until timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.engineer_id, coalesce(p.full_name,'(unknown)')::text, b.amount_rupees, b.status, b.risk_signal, b.duration_months, b.reason, b.created_at, b.effective_until
  FROM engineer_retention_bonuses b
  LEFT JOIN engineers e ON e.id = b.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY b.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit,100), 500));
END; $$;
REVOKE EXECUTE ON FUNCTION founder_retention_bonus_list(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_retention_bonus_list(integer) TO authenticated;

CREATE OR REPLACE FUNCTION founder_retention_bonus_pending()
RETURNS TABLE(id uuid, engineer_id uuid, engineer_name text, amount_rupees integer, status text, risk_signal text, created_at timestamptz, awaiting text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.engineer_id, coalesce(p.full_name,'(unknown)')::text, b.amount_rupees, b.status, b.risk_signal, b.created_at,
    CASE WHEN b.status='proposed' THEN 'L1 review'
         WHEN b.status='l1_approved' THEN 'L2 (founder) approval'
         WHEN b.status='l2_approved' THEN 'Payout disbursal'
         ELSE '—' END::text
  FROM engineer_retention_bonuses b
  LEFT JOIN engineers e ON e.id = b.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE b.status IN ('proposed','l1_approved','l2_approved')
  ORDER BY b.created_at ASC
  LIMIT 200;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_retention_bonus_pending() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_retention_bonus_pending() TO authenticated;

CREATE OR REPLACE FUNCTION founder_retention_bonus_by_risk()
RETURNS TABLE(risk_signal text, bonus_count bigint, paid_count bigint, total_rupees bigint, avg_amount numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.risk_signal::text,
         count(*)::bigint,
         count(*) FILTER (WHERE b.status='paid')::bigint,
         coalesce(sum(b.amount_rupees) FILTER (WHERE b.status='paid'),0)::bigint,
         coalesce(avg(b.amount_rupees),0)::numeric(12,2)
  FROM engineer_retention_bonuses b
  GROUP BY b.risk_signal
  ORDER BY count(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_retention_bonus_by_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_retention_bonus_by_risk() TO authenticated;

CREATE OR REPLACE FUNCTION founder_retention_bonus_top_recipients(p_limit integer DEFAULT 20)
RETURNS TABLE(engineer_id uuid, engineer_name text, tier text, bonus_count bigint, paid_total bigint, last_paid_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.engineer_id,
         coalesce(p.full_name,'(unknown)')::text,
         coalesce(e.cached_highest_tier,'none')::text,
         count(*)::bigint,
         coalesce(sum(b.amount_rupees) FILTER (WHERE b.status='paid'),0)::bigint,
         max(b.paid_at)
  FROM engineer_retention_bonuses b
  LEFT JOIN engineers e ON e.id = b.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  GROUP BY b.engineer_id, p.full_name, e.cached_highest_tier
  ORDER BY coalesce(sum(b.amount_rupees) FILTER (WHERE b.status='paid'),0) DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit,20), 100));
END; $$;
REVOKE EXECUTE ON FUNCTION founder_retention_bonus_top_recipients(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_retention_bonus_top_recipients(integer) TO authenticated;

CREATE OR REPLACE FUNCTION founder_retention_bonus_event_log(p_limit integer DEFAULT 100)
RETURNS TABLE(id uuid, bonus_id uuid, event_type text, notes text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ev.id, ev.bonus_id, ev.event_type, ev.notes, ev.created_at
  FROM engineer_retention_bonus_events ev
  ORDER BY ev.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit,100), 500));
END; $$;
REVOKE EXECUTE ON FUNCTION founder_retention_bonus_event_log(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_retention_bonus_event_log(integer) TO authenticated;

-- Write RPC (VOLATILE SECDEF) -------------------------------

CREATE OR REPLACE FUNCTION founder_retention_bonus_propose(p_engineer_id uuid, p_amount integer, p_reason text, p_risk text, p_duration integer)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_retention_bonuses(engineer_id, amount_rupees, reason, risk_signal, duration_months, proposed_by, effective_until)
  VALUES (p_engineer_id, p_amount, p_reason, p_risk, p_duration, auth.uid(), now() + (p_duration || ' months')::interval)
  RETURNING id INTO v_id;
  INSERT INTO engineer_retention_bonus_events(bonus_id, event_type, actor_user_id, notes)
  VALUES (v_id, 'proposed', auth.uid(), p_reason);
  PERFORM log_founder_retention_bonus_proposed(v_id, p_amount, p_engineer_id);
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_retention_bonus_propose(uuid, integer, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_retention_bonus_propose(uuid, integer, text, text, integer) TO authenticated;

COMMIT;