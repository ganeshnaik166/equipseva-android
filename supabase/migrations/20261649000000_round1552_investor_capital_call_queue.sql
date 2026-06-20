BEGIN;

-- =====================================================================
-- Round 1552: Investor Capital Call Queue
-- HEAVY founder console feature: queue of upcoming capital calls
-- (drawdowns from committed funds), per-investor commitments,
-- called amount, remaining, founder send list.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLE 1: investor_capital_commitments
-- Per-investor committed capital amount + running called/remaining.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS investor_capital_commitments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_email text NOT NULL,
  investor_entity_type text NOT NULL CHECK (investor_entity_type IN ('individual','llp','company','fund','family_office')),
  committed_amount_rupees bigint NOT NULL CHECK (committed_amount_rupees > 0),
  called_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (called_amount_rupees >= 0),
  currency text NOT NULL DEFAULT 'INR',
  commitment_signed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','closed','defaulted')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icc_status ON investor_capital_commitments(status);
CREATE INDEX IF NOT EXISTS idx_icc_email ON investor_capital_commitments(investor_email);

ALTER TABLE investor_capital_commitments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS icc_founder_only ON investor_capital_commitments;
CREATE POLICY icc_founder_only ON investor_capital_commitments
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------------------------------------------------------------------
-- TABLE 2: investor_capital_calls
-- Each row = one upcoming/sent capital call (drawdown event) against
-- one commitment.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS investor_capital_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commitment_id uuid NOT NULL REFERENCES investor_capital_commitments(id) ON DELETE CASCADE,
  call_number int NOT NULL,
  call_amount_rupees bigint NOT NULL CHECK (call_amount_rupees > 0),
  due_date date NOT NULL,
  purpose text NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','acknowledged','funded','overdue','cancelled')),
  sent_at timestamptz,
  acknowledged_at timestamptz,
  funded_at timestamptz,
  funded_amount_rupees bigint NOT NULL DEFAULT 0,
  reminder_count int NOT NULL DEFAULT 0,
  last_reminder_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icc_calls_commitment ON investor_capital_calls(commitment_id);
CREATE INDEX IF NOT EXISTS idx_icc_calls_status ON investor_capital_calls(status);
CREATE INDEX IF NOT EXISTS idx_icc_calls_due_date ON investor_capital_calls(due_date);

ALTER TABLE investor_capital_calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS icc_calls_founder_only ON investor_capital_calls;
CREATE POLICY icc_calls_founder_only ON investor_capital_calls
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =====================================================================
-- LOG HELPERS (VOLATILE SECDEF) — 4 helpers
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_capital_call_queued(
  p_call_id uuid,
  p_commitment_id uuid,
  p_amount_rupees bigint,
  p_due_date date
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'capital_call_queued',
    jsonb_build_object(
      'call_id', p_call_id,
      'commitment_id', p_commitment_id,
      'amount_rupees', p_amount_rupees,
      'due_date', p_due_date
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_capital_call_queued(uuid, uuid, bigint, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_capital_call_queued(uuid, uuid, bigint, date) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_capital_call_sent(
  p_call_id uuid,
  p_recipient_email text
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'capital_call_sent',
    jsonb_build_object(
      'call_id', p_call_id,
      'recipient_email', p_recipient_email,
      'sent_at', now()
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_capital_call_sent(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_capital_call_sent(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_capital_call_funded(
  p_call_id uuid,
  p_funded_amount_rupees bigint
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'capital_call_funded',
    jsonb_build_object(
      'call_id', p_call_id,
      'funded_amount_rupees', p_funded_amount_rupees,
      'funded_at', now()
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_capital_call_funded(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_capital_call_funded(uuid, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_capital_call_cancelled(
  p_call_id uuid,
  p_reason text
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'capital_call_cancelled',
    jsonb_build_object(
      'call_id', p_call_id,
      'reason', p_reason
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_capital_call_cancelled(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_capital_call_cancelled(uuid, text) TO authenticated;

-- =====================================================================
-- READ RPCs (STABLE SECDEF) — 4 read fns
-- =====================================================================

-- 1) Top-line KPIs across all commitments + calls
CREATE OR REPLACE FUNCTION founder_capital_call_kpis()
RETURNS TABLE(
  total_commitments bigint,
  active_commitments bigint,
  paused_commitments bigint,
  closed_commitments bigint,
  defaulted_commitments bigint,
  total_committed_rupees bigint,
  total_called_rupees bigint,
  total_remaining_rupees bigint,
  total_funded_rupees bigint,
  calls_queued bigint,
  calls_sent bigint,
  calls_acknowledged bigint,
  calls_funded bigint,
  calls_overdue bigint,
  next_due_date date,
  next_due_amount_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH c AS (
    SELECT * FROM investor_capital_commitments
  ), k AS (
    SELECT * FROM investor_capital_calls
  ), nxt AS (
    SELECT due_date, call_amount_rupees
    FROM investor_capital_calls
    WHERE status IN ('queued','sent','acknowledged')
    ORDER BY due_date ASC
    LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM c)::bigint,
    (SELECT count(*) FROM c WHERE status='active')::bigint,
    (SELECT count(*) FROM c WHERE status='paused')::bigint,
    (SELECT count(*) FROM c WHERE status='closed')::bigint,
    (SELECT count(*) FROM c WHERE status='defaulted')::bigint,
    (SELECT COALESCE(sum(committed_amount_rupees),0) FROM c)::bigint,
    (SELECT COALESCE(sum(called_amount_rupees),0) FROM c)::bigint,
    (SELECT COALESCE(sum(committed_amount_rupees - called_amount_rupees),0) FROM c)::bigint,
    (SELECT COALESCE(sum(funded_amount_rupees),0) FROM k)::bigint,
    (SELECT count(*) FROM k WHERE status='queued')::bigint,
    (SELECT count(*) FROM k WHERE status='sent')::bigint,
    (SELECT count(*) FROM k WHERE status='acknowledged')::bigint,
    (SELECT count(*) FROM k WHERE status='funded')::bigint,
    (SELECT count(*) FROM k WHERE status='overdue' OR (status IN ('queued','sent','acknowledged') AND due_date < CURRENT_DATE))::bigint,
    (SELECT due_date FROM nxt),
    (SELECT call_amount_rupees FROM nxt);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_capital_call_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_call_kpis() TO authenticated;

-- 2) Per-investor commitment roster
CREATE OR REPLACE FUNCTION founder_capital_commitments_roster()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_email text,
  investor_entity_type text,
  committed_amount_rupees bigint,
  called_amount_rupees bigint,
  remaining_amount_rupees bigint,
  pct_called numeric,
  status text,
  open_calls bigint,
  commitment_signed_at timestamptz
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
    c.id,
    c.investor_name,
    c.investor_email,
    c.investor_entity_type,
    c.committed_amount_rupees,
    c.called_amount_rupees,
    (c.committed_amount_rupees - c.called_amount_rupees)::bigint AS remaining_amount_rupees,
    CASE WHEN c.committed_amount_rupees > 0
      THEN ROUND((c.called_amount_rupees::numeric / c.committed_amount_rupees::numeric) * 100.0, 2)
      ELSE 0
    END AS pct_called,
    c.status,
    (SELECT count(*) FROM investor_capital_calls k
      WHERE k.commitment_id = c.id
        AND k.status IN ('queued','sent','acknowledged')
    )::bigint AS open_calls,
    c.commitment_signed_at
  FROM investor_capital_commitments c
  ORDER BY c.committed_amount_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_capital_commitments_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_commitments_roster() TO authenticated;

-- 3) Upcoming capital-call queue (next 90 days, ordered by due date)
CREATE OR REPLACE FUNCTION founder_capital_call_queue_upcoming()
RETURNS TABLE(
  id uuid,
  commitment_id uuid,
  investor_name text,
  investor_email text,
  call_number int,
  call_amount_rupees bigint,
  due_date date,
  days_until_due int,
  purpose text,
  status text,
  reminder_count int
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
    k.id,
    k.commitment_id,
    c.investor_name,
    c.investor_email,
    k.call_number,
    k.call_amount_rupees,
    k.due_date,
    (k.due_date - CURRENT_DATE)::int AS days_until_due,
    k.purpose,
    k.status,
    k.reminder_count
  FROM investor_capital_calls k
  JOIN investor_capital_commitments c ON c.id = k.commitment_id
  WHERE k.status IN ('queued','sent','acknowledged')
  ORDER BY k.due_date ASC, k.call_amount_rupees DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_capital_call_queue_upcoming() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_call_queue_upcoming() TO authenticated;

-- 4) Send list — investors with queued calls ready to dispatch
CREATE OR REPLACE FUNCTION founder_capital_call_send_list()
RETURNS TABLE(
  call_id uuid,
  commitment_id uuid,
  investor_name text,
  investor_email text,
  call_number int,
  call_amount_rupees bigint,
  due_date date,
  purpose text,
  remaining_commitment_rupees bigint
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
    k.id AS call_id,
    k.commitment_id,
    c.investor_name,
    c.investor_email,
    k.call_number,
    k.call_amount_rupees,
    k.due_date,
    k.purpose,
    (c.committed_amount_rupees - c.called_amount_rupees)::bigint AS remaining_commitment_rupees
  FROM investor_capital_calls k
  JOIN investor_capital_commitments c ON c.id = k.commitment_id
  WHERE k.status = 'queued'
    AND c.status = 'active'
  ORDER BY k.due_date ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_capital_call_send_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_call_send_list() TO authenticated;

-- =====================================================================
-- WRITE RPCs (VOLATILE SECDEF) — 3 write fns
-- =====================================================================

-- 5) Queue a new capital call
CREATE OR REPLACE FUNCTION founder_queue_capital_call(
  p_commitment_id uuid,
  p_call_amount_rupees bigint,
  p_due_date date,
  p_purpose text
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_call_id uuid;
  v_next_num int;
  v_remaining bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT (committed_amount_rupees - called_amount_rupees)
    INTO v_remaining
  FROM investor_capital_commitments
  WHERE id = p_commitment_id AND status = 'active';

  IF v_remaining IS NULL THEN RAISE EXCEPTION 'commitment_not_found_or_inactive'; END IF;
  IF p_call_amount_rupees > v_remaining THEN RAISE EXCEPTION 'call_exceeds_remaining'; END IF;

  SELECT COALESCE(max(call_number),0) + 1 INTO v_next_num
  FROM investor_capital_calls WHERE commitment_id = p_commitment_id;

  INSERT INTO investor_capital_calls(
    commitment_id, call_number, call_amount_rupees, due_date, purpose, status
  ) VALUES (
    p_commitment_id, v_next_num, p_call_amount_rupees, p_due_date, p_purpose, 'queued'
  ) RETURNING id INTO v_call_id;

  PERFORM log_founder_capital_call_queued(v_call_id, p_commitment_id, p_call_amount_rupees, p_due_date);
  RETURN v_call_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_queue_capital_call(uuid, bigint, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_queue_capital_call(uuid, bigint, date, text) TO authenticated;

-- 6) Mark capital call as sent
CREATE OR REPLACE FUNCTION founder_mark_capital_call_sent(
  p_call_id uuid
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE investor_capital_calls
  SET status = 'sent', sent_at = now(), updated_at = now()
  WHERE id = p_call_id AND status = 'queued';

  IF NOT FOUND THEN RAISE EXCEPTION 'call_not_queued'; END IF;

  SELECT c.investor_email INTO v_email
  FROM investor_capital_calls k
  JOIN investor_capital_commitments c ON c.id = k.commitment_id
  WHERE k.id = p_call_id;

  PERFORM log_founder_capital_call_sent(p_call_id, v_email);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_mark_capital_call_sent(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mark_capital_call_sent(uuid) TO authenticated;

-- 7) Record funding receipt — updates call + bumps called_amount on commitment
CREATE OR REPLACE FUNCTION founder_record_capital_call_funded(
  p_call_id uuid,
  p_funded_amount_rupees bigint
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_commitment_id uuid;
  v_call_amount bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT commitment_id, call_amount_rupees
    INTO v_commitment_id, v_call_amount
  FROM investor_capital_calls
  WHERE id = p_call_id;

  IF v_commitment_id IS NULL THEN RAISE EXCEPTION 'call_not_found'; END IF;
  IF p_funded_amount_rupees <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;

  UPDATE investor_capital_calls
  SET status = 'funded',
      funded_at = now(),
      funded_amount_rupees = p_funded_amount_rupees,
      updated_at = now()
  WHERE id = p_call_id;

  UPDATE investor_capital_commitments
  SET called_amount_rupees = called_amount_rupees + p_funded_amount_rupees,
      updated_at = now()
  WHERE id = v_commitment_id;

  PERFORM log_founder_capital_call_funded(p_call_id, p_funded_amount_rupees);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_record_capital_call_funded(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_record_capital_call_funded(uuid, bigint) TO authenticated;

COMMIT;