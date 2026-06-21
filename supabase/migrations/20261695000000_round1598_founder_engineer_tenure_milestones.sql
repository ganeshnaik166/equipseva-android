BEGIN;

-- ============================================================================
-- Round 1598 — Founder Engineer Tenure Milestone Awards
-- Celebrate engineer tenure milestones (90d, 1yr, 2yr, 5yr) with auto-bonus,
-- recognition email, and founder personal note.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: tenure milestone awards
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_tenure_milestone_awards_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  milestone_kind text NOT NULL CHECK (milestone_kind IN ('day_90','year_1','year_2','year_5')),
  tenure_days integer NOT NULL,
  bonus_amount_rupees integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','paid','skipped')),
  approved_at timestamptz,
  approved_by uuid REFERENCES profiles(id),
  paid_at timestamptz,
  email_sent_at timestamptz,
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id, milestone_kind)
);

CREATE INDEX IF NOT EXISTS idx_etma_v2_status ON engineer_tenure_milestone_awards_v2(status);
CREATE INDEX IF NOT EXISTS idx_etma_v2_engineer ON engineer_tenure_milestone_awards_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_etma_v2_kind ON engineer_tenure_milestone_awards_v2(milestone_kind);

ALTER TABLE engineer_tenure_milestone_awards_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS etma_v2_founder_all ON engineer_tenure_milestone_awards_v2;
CREATE POLICY etma_v2_founder_all ON engineer_tenure_milestone_awards_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ----------------------------------------------------------------------------
-- Table 2: bonus payout queue
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_tenure_bonus_queue_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  award_id uuid NOT NULL REFERENCES engineer_tenure_milestone_awards_v2(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  amount_rupees integer NOT NULL,
  queued_at timestamptz NOT NULL DEFAULT now(),
  dispatched_at timestamptz,
  payout_status text NOT NULL DEFAULT 'queued' CHECK (payout_status IN ('queued','dispatched','failed'))
);

CREATE INDEX IF NOT EXISTS idx_etbq_v2_status ON engineer_tenure_bonus_queue_v2(payout_status);
CREATE INDEX IF NOT EXISTS idx_etbq_v2_engineer ON engineer_tenure_bonus_queue_v2(engineer_id);

ALTER TABLE engineer_tenure_bonus_queue_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS etbq_v2_founder_all ON engineer_tenure_bonus_queue_v2;
CREATE POLICY etbq_v2_founder_all ON engineer_tenure_bonus_queue_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_tenure_milestone_create(p_award_id uuid, p_kind text, p_bonus integer)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'tenure_milestone_create',
          jsonb_build_object('award_id', p_award_id, 'kind', p_kind, 'bonus', p_bonus));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_tenure_milestone_create(uuid, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tenure_milestone_create(uuid, text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_tenure_milestone_approve(p_award_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'tenure_milestone_approve',
          jsonb_build_object('award_id', p_award_id));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_tenure_milestone_approve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tenure_milestone_approve(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_tenure_milestone_note(p_award_id uuid, p_note_len integer)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'tenure_milestone_note',
          jsonb_build_object('award_id', p_award_id, 'note_len', p_note_len));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_tenure_milestone_note(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tenure_milestone_note(uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_tenure_milestone_dispatch(p_award_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'tenure_milestone_dispatch',
          jsonb_build_object('award_id', p_award_id));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_tenure_milestone_dispatch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_tenure_milestone_dispatch(uuid) TO authenticated;

-- ============================================================================
-- READ RPCs (STABLE SECDEF, founder-gated)
-- ============================================================================

-- 1. KPI overview
CREATE OR REPLACE FUNCTION founder_tenure_milestone_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_awards', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2),
    'pending', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE status='pending'),
    'approved', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE status='approved'),
    'paid', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE status='paid'),
    'skipped', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE status='skipped'),
    'day_90_count', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE milestone_kind='day_90'),
    'year_1_count', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE milestone_kind='year_1'),
    'year_2_count', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE milestone_kind='year_2'),
    'year_5_count', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE milestone_kind='year_5'),
    'total_bonus_rupees', COALESCE((SELECT sum(bonus_amount_rupees) FROM engineer_tenure_milestone_awards_v2),0),
    'paid_bonus_rupees', COALESCE((SELECT sum(bonus_amount_rupees) FROM engineer_tenure_milestone_awards_v2 WHERE status='paid'),0),
    'pending_bonus_rupees', COALESCE((SELECT sum(bonus_amount_rupees) FROM engineer_tenure_milestone_awards_v2 WHERE status IN ('pending','approved')),0),
    'emails_sent', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE email_sent_at IS NOT NULL),
    'notes_written', (SELECT count(*) FROM engineer_tenure_milestone_awards_v2 WHERE founder_note IS NOT NULL AND length(founder_note) > 0),
    'queue_size', (SELECT count(*) FROM engineer_tenure_bonus_queue_v2 WHERE payout_status='queued'),
    'queue_dispatched', (SELECT count(*) FROM engineer_tenure_bonus_queue_v2 WHERE payout_status='dispatched')
  ) INTO v;
  RETURN v;
END $$;
REVOKE EXECUTE ON FUNCTION founder_tenure_milestone_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_tenure_milestone_kpis() TO authenticated;

-- 2. Eligible engineers (compute who has crossed milestones not yet awarded)
CREATE OR REPLACE FUNCTION founder_tenure_milestone_eligible()
RETURNS TABLE (
  engineer_id uuid,
  engineer_name text,
  tenure_days integer,
  next_milestone text,
  already_awarded_kinds text
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
    e.id AS engineer_id,
    COALESCE(p.full_name, p.email, '(unknown)') AS engineer_name,
    (EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0)::integer AS tenure_days,
    CASE
      WHEN (EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0) >= 1825 THEN 'year_5'
      WHEN (EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0) >= 730 THEN 'year_2'
      WHEN (EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0) >= 365 THEN 'year_1'
      WHEN (EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0) >= 90 THEN 'day_90'
      ELSE 'none'
    END AS next_milestone,
    COALESCE((SELECT string_agg(a.milestone_kind, ',') FROM engineer_tenure_milestone_awards_v2 a WHERE a.engineer_id = e.id), '') AS already_awarded_kinds
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE (EXTRACT(EPOCH FROM (now() - e.created_at)) / 86400.0) >= 90
  ORDER BY e.created_at ASC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_tenure_milestone_eligible() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_tenure_milestone_eligible() TO authenticated;

-- 3. Recent awards
CREATE OR REPLACE FUNCTION founder_tenure_milestone_recent()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  milestone_kind text,
  tenure_days integer,
  bonus_amount_rupees integer,
  status text,
  email_sent boolean,
  has_note boolean,
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
    COALESCE(p.full_name, p.email, '(unknown)') AS engineer_name,
    a.milestone_kind,
    a.tenure_days,
    a.bonus_amount_rupees,
    a.status,
    (a.email_sent_at IS NOT NULL) AS email_sent,
    (a.founder_note IS NOT NULL AND length(a.founder_note) > 0) AS has_note,
    a.created_at
  FROM engineer_tenure_milestone_awards_v2 a
  JOIN engineers e ON e.id = a.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY a.created_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_tenure_milestone_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_tenure_milestone_recent() TO authenticated;

-- 4. Pending approvals
CREATE OR REPLACE FUNCTION founder_tenure_milestone_pending()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  milestone_kind text,
  tenure_days integer,
  bonus_amount_rupees integer,
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
    COALESCE(p.full_name, p.email, '(unknown)') AS engineer_name,
    a.milestone_kind,
    a.tenure_days,
    a.bonus_amount_rupees,
    a.created_at
  FROM engineer_tenure_milestone_awards_v2 a
  JOIN engineers e ON e.id = a.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE a.status = 'pending'
  ORDER BY a.created_at ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_tenure_milestone_pending() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_tenure_milestone_pending() TO authenticated;

-- 5. Bonus queue
CREATE OR REPLACE FUNCTION founder_tenure_milestone_queue()
RETURNS TABLE (
  id uuid,
  award_id uuid,
  engineer_name text,
  amount_rupees integer,
  payout_status text,
  queued_at timestamptz,
  dispatched_at timestamptz
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
    q.id,
    q.award_id,
    COALESCE(p.full_name, p.email, '(unknown)') AS engineer_name,
    q.amount_rupees,
    q.payout_status,
    q.queued_at,
    q.dispatched_at
  FROM engineer_tenure_bonus_queue_v2 q
  JOIN engineers e ON e.id = q.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY q.queued_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_tenure_milestone_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_tenure_milestone_queue() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE SECDEF, founder-gated)
-- ============================================================================

-- 6. Auto-create awards for eligible engineers
CREATE OR REPLACE FUNCTION founder_tenure_milestone_auto_award()
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
  r record;
  v_days integer;
  v_kind text;
  v_bonus integer;
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  FOR r IN SELECT e.id, e.created_at FROM engineers e LOOP
    v_days := (EXTRACT(EPOCH FROM (now() - r.created_at)) / 86400.0)::integer;
    FOR v_kind, v_bonus IN SELECT * FROM (VALUES
      ('day_90', 2000),
      ('year_1', 5000),
      ('year_2', 10000),
      ('year_5', 25000)
    ) AS m(k, b) LOOP
      IF (v_kind = 'day_90' AND v_days >= 90)
         OR (v_kind = 'year_1' AND v_days >= 365)
         OR (v_kind = 'year_2' AND v_days >= 730)
         OR (v_kind = 'year_5' AND v_days >= 1825) THEN
        IF NOT EXISTS (SELECT 1 FROM engineer_tenure_milestone_awards_v2 a WHERE a.engineer_id = r.id AND a.milestone_kind = v_kind) THEN
          INSERT INTO engineer_tenure_milestone_awards_v2 (engineer_id, milestone_kind, tenure_days, bonus_amount_rupees)
          VALUES (r.id, v_kind, v_days, v_bonus)
          RETURNING id INTO v_id;
          PERFORM log_founder_tenure_milestone_create(v_id, v_kind, v_bonus);
          v_count := v_count + 1;
        END IF;
      END IF;
    END LOOP;
  END LOOP;
  RETURN v_count;
END $$;
REVOKE EXECUTE ON FUNCTION founder_tenure_milestone_auto_award() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_tenure_milestone_auto_award() TO authenticated;

-- 7. Approve award + queue bonus + mark email sent
CREATE OR REPLACE FUNCTION founder_tenure_milestone_approve(p_award_id uuid, p_note text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_engineer_id uuid;
  v_amount integer;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_tenure_milestone_awards_v2
     SET status = 'approved',
         approved_at = now(),
         approved_by = auth.uid(),
         email_sent_at = now(),
         founder_note = COALESCE(p_note, founder_note)
   WHERE id = p_award_id
   RETURNING engineer_id, bonus_amount_rupees INTO v_engineer_id, v_amount;
  IF v_engineer_id IS NULL THEN RAISE EXCEPTION 'award_not_found'; END IF;
  INSERT INTO engineer_tenure_bonus_queue_v2 (award_id, engineer_id, amount_rupees)
  VALUES (p_award_id, v_engineer_id, v_amount);
  PERFORM log_founder_tenure_milestone_approve(p_award_id);
  IF p_note IS NOT NULL AND length(p_note) > 0 THEN
    PERFORM log_founder_tenure_milestone_note(p_award_id, length(p_note));
  END IF;
END $$;
REVOKE EXECUTE ON FUNCTION founder_tenure_milestone_approve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_tenure_milestone_approve(uuid, text) TO authenticated;

COMMIT;