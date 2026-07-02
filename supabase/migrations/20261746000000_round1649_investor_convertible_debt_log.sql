BEGIN;

-- ============================================================================
-- r1649 — Investor Convertible Debt Log
-- Tracks convertible notes (debt instruments with interest accrual + maturity
-- + conversion triggers), distinct from SAFEs. Founder-only watch list.
-- ============================================================================

CREATE TABLE IF NOT EXISTS investor_convertible_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_email text,
  principal_rupees bigint NOT NULL CHECK (principal_rupees > 0),
  interest_rate_pct numeric(5,2) NOT NULL DEFAULT 8.00 CHECK (interest_rate_pct >= 0 AND interest_rate_pct <= 30),
  issue_date date NOT NULL,
  maturity_date date NOT NULL,
  conversion_discount_pct numeric(5,2) DEFAULT 20.00 CHECK (conversion_discount_pct >= 0 AND conversion_discount_pct <= 50),
  valuation_cap_rupees bigint CHECK (valuation_cap_rupees IS NULL OR valuation_cap_rupees > 0),
  conversion_trigger text NOT NULL DEFAULT 'qualified_round' CHECK (conversion_trigger IN ('qualified_round','maturity','optional','acquisition')),
  qualified_round_min_rupees bigint,
  status text NOT NULL DEFAULT 'outstanding' CHECK (status IN ('outstanding','converted','repaid','defaulted','extended')),
  converted_at timestamptz,
  conversion_price_rupees bigint,
  watch_flag boolean NOT NULL DEFAULT false,
  watch_reason text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (maturity_date > issue_date)
);

CREATE INDEX IF NOT EXISTS idx_icn_status ON investor_convertible_notes(status);
CREATE INDEX IF NOT EXISTS idx_icn_maturity ON investor_convertible_notes(maturity_date);
CREATE INDEX IF NOT EXISTS idx_icn_watch ON investor_convertible_notes(watch_flag) WHERE watch_flag = true;

ALTER TABLE investor_convertible_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_icn ON investor_convertible_notes;
CREATE POLICY founder_only_icn ON investor_convertible_notes
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS investor_convertible_note_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES investor_convertible_notes(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('issued','interest_accrued','watch_added','watch_cleared','converted','repaid','extended','defaulted','note_updated')),
  event_amount_rupees bigint,
  event_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icne_note ON investor_convertible_note_events(note_id, created_at DESC);

ALTER TABLE investor_convertible_note_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_icne ON investor_convertible_note_events;
CREATE POLICY founder_only_icne ON investor_convertible_note_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1) Summary: aggregate principal/accrued/converted/at-risk
DROP FUNCTION IF EXISTS founder_convertible_debt_summary();
CREATE OR REPLACE FUNCTION founder_convertible_debt_summary()
RETURNS TABLE (
  total_notes int,
  outstanding_notes int,
  converted_notes int,
  repaid_notes int,
  defaulted_notes int,
  watch_listed int,
  total_principal_rupees bigint,
  outstanding_principal_rupees bigint,
  accrued_interest_rupees bigint,
  maturing_within_90d int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_notes,
    (COUNT(*) FILTER (WHERE status = 'outstanding'))::int AS outstanding_notes,
    (COUNT(*) FILTER (WHERE status = 'converted'))::int AS converted_notes,
    (COUNT(*) FILTER (WHERE status = 'repaid'))::int AS repaid_notes,
    (COUNT(*) FILTER (WHERE status = 'defaulted'))::int AS defaulted_notes,
    (COUNT(*) FILTER (WHERE watch_flag = true))::int AS watch_listed,
    COALESCE(SUM(principal_rupees), 0)::bigint AS total_principal_rupees,
    COALESCE(SUM(principal_rupees) FILTER (WHERE status = 'outstanding'), 0)::bigint AS outstanding_principal_rupees,
    COALESCE(SUM(
      CASE WHEN status = 'outstanding' THEN
        (principal_rupees * interest_rate_pct / 100.0 *
          GREATEST(0, EXTRACT(EPOCH FROM (now() - issue_date::timestamptz)) / (365.25 * 86400)))::bigint
      ELSE 0 END
    ), 0)::bigint AS accrued_interest_rupees,
    (COUNT(*) FILTER (WHERE status = 'outstanding' AND maturity_date <= (current_date + INTERVAL '90 days')))::int AS maturing_within_90d
  FROM investor_convertible_notes;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_convertible_debt_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_convertible_debt_summary() TO authenticated;

-- 2) List all notes with computed accrued interest
DROP FUNCTION IF EXISTS founder_convertible_debt_list();
CREATE OR REPLACE FUNCTION founder_convertible_debt_list()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_email text,
  principal_rupees bigint,
  interest_rate_pct numeric,
  issue_date date,
  maturity_date date,
  days_to_maturity int,
  accrued_interest_rupees bigint,
  total_owed_rupees bigint,
  conversion_trigger text,
  conversion_discount_pct numeric,
  valuation_cap_rupees bigint,
  status text,
  watch_flag boolean,
  watch_reason text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.id,
    n.investor_name,
    n.investor_email,
    n.principal_rupees,
    n.interest_rate_pct,
    n.issue_date,
    n.maturity_date,
    (n.maturity_date - current_date)::int AS days_to_maturity,
    CASE WHEN n.status = 'outstanding' THEN
      (n.principal_rupees * n.interest_rate_pct / 100.0 *
        GREATEST(0, EXTRACT(EPOCH FROM (now() - n.issue_date::timestamptz)) / (365.25 * 86400)))::bigint
    ELSE 0 END AS accrued_interest_rupees,
    CASE WHEN n.status = 'outstanding' THEN
      n.principal_rupees +
      (n.principal_rupees * n.interest_rate_pct / 100.0 *
        GREATEST(0, EXTRACT(EPOCH FROM (now() - n.issue_date::timestamptz)) / (365.25 * 86400)))::bigint
    ELSE n.principal_rupees END AS total_owed_rupees,
    n.conversion_trigger,
    n.conversion_discount_pct,
    n.valuation_cap_rupees,
    n.status,
    n.watch_flag,
    n.watch_reason
  FROM investor_convertible_notes n
  ORDER BY
    (n.watch_flag) DESC,
    CASE n.status WHEN 'outstanding' THEN 0 WHEN 'extended' THEN 1 WHEN 'defaulted' THEN 2 ELSE 3 END,
    n.maturity_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_convertible_debt_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_convertible_debt_list() TO authenticated;

-- 3) Watch list (urgent attention)
DROP FUNCTION IF EXISTS founder_convertible_debt_watch_list();
CREATE OR REPLACE FUNCTION founder_convertible_debt_watch_list()
RETURNS TABLE (
  id uuid,
  investor_name text,
  principal_rupees bigint,
  maturity_date date,
  days_to_maturity int,
  status text,
  watch_reason text,
  urgency text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.id,
    n.investor_name,
    n.principal_rupees,
    n.maturity_date,
    (n.maturity_date - current_date)::int AS days_to_maturity,
    n.status,
    n.watch_reason,
    CASE
      WHEN n.status = 'defaulted' THEN 'critical'
      WHEN n.maturity_date < current_date THEN 'critical'
      WHEN n.maturity_date <= current_date + INTERVAL '30 days' THEN 'high'
      WHEN n.maturity_date <= current_date + INTERVAL '90 days' THEN 'medium'
      ELSE 'low'
    END AS urgency
  FROM investor_convertible_notes n
  WHERE n.watch_flag = true
     OR n.status = 'defaulted'
     OR (n.status = 'outstanding' AND n.maturity_date <= current_date + INTERVAL '90 days')
  ORDER BY
    CASE
      WHEN n.status = 'defaulted' THEN 0
      WHEN n.maturity_date < current_date THEN 1
      WHEN n.maturity_date <= current_date + INTERVAL '30 days' THEN 2
      WHEN n.maturity_date <= current_date + INTERVAL '90 days' THEN 3
      ELSE 4
    END,
    n.maturity_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_convertible_debt_watch_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_convertible_debt_watch_list() TO authenticated;

-- 4) Recent events feed
DROP FUNCTION IF EXISTS founder_convertible_debt_events(int);
CREATE OR REPLACE FUNCTION founder_convertible_debt_events(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  note_id uuid,
  investor_name text,
  event_type text,
  event_amount_rupees bigint,
  event_note text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.note_id, n.investor_name, e.event_type, e.event_amount_rupees, e.event_note, e.created_at
  FROM investor_convertible_note_events e
  JOIN investor_convertible_notes n ON n.id = e.note_id
  ORDER BY e.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_convertible_debt_events(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_convertible_debt_events(int) TO authenticated;

-- 5) Trigger conversion: WRITE — VOLATILE
DROP FUNCTION IF EXISTS founder_convertible_debt_record_conversion(uuid, bigint, text);
CREATE OR REPLACE FUNCTION founder_convertible_debt_record_conversion(
  p_note_id uuid,
  p_conversion_price_rupees bigint,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_note_id IS NULL OR p_conversion_price_rupees IS NULL OR p_conversion_price_rupees <= 0 THEN
    RAISE EXCEPTION 'invalid input';
  END IF;
  UPDATE investor_convertible_notes
  SET status = 'converted',
      converted_at = now(),
      conversion_price_rupees = p_conversion_price_rupees,
      updated_at = now()
  WHERE id = p_note_id
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'note not found'; END IF;
  INSERT INTO investor_convertible_note_events(note_id, event_type, event_amount_rupees, event_note)
  VALUES (p_note_id, 'converted', p_conversion_price_rupees, p_note);
  PERFORM log_founder_action('icn.converted', p_note_id::text, jsonb_build_object('price', p_conversion_price_rupees));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_convertible_debt_record_conversion(uuid, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_convertible_debt_record_conversion(uuid, bigint, text) TO authenticated;

-- 6) Set watch flag: WRITE — VOLATILE
DROP FUNCTION IF EXISTS founder_convertible_debt_set_watch(uuid, boolean, text);
CREATE OR REPLACE FUNCTION founder_convertible_debt_set_watch(
  p_note_id uuid,
  p_watch boolean,
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_convertible_notes
  SET watch_flag = COALESCE(p_watch, false),
      watch_reason = CASE WHEN p_watch THEN p_reason ELSE NULL END,
      updated_at = now()
  WHERE id = p_note_id
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'note not found'; END IF;
  INSERT INTO investor_convertible_note_events(note_id, event_type, event_note)
  VALUES (p_note_id, CASE WHEN p_watch THEN 'watch_added' ELSE 'watch_cleared' END, p_reason);
  PERFORM log_founder_action('icn.watch', p_note_id::text, jsonb_build_object('watch', p_watch, 'reason', p_reason));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_convertible_debt_set_watch(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_convertible_debt_set_watch(uuid, boolean, text) TO authenticated;

-- 7) Insert new note: WRITE — VOLATILE
DROP FUNCTION IF EXISTS founder_convertible_debt_log_note(text, text, bigint, numeric, date, date, text, numeric, bigint, text);
CREATE OR REPLACE FUNCTION founder_convertible_debt_log_note(
  p_investor_name text,
  p_investor_email text,
  p_principal_rupees bigint,
  p_interest_rate_pct numeric,
  p_issue_date date,
  p_maturity_date date,
  p_conversion_trigger text DEFAULT 'qualified_round',
  p_conversion_discount_pct numeric DEFAULT 20.00,
  p_valuation_cap_rupees bigint DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_investor_name IS NULL OR length(trim(p_investor_name)) = 0 THEN RAISE EXCEPTION 'investor_name required'; END IF;
  IF p_principal_rupees IS NULL OR p_principal_rupees <= 0 THEN RAISE EXCEPTION 'principal must be > 0'; END IF;
  IF p_maturity_date <= p_issue_date THEN RAISE EXCEPTION 'maturity must be after issue'; END IF;
  INSERT INTO investor_convertible_notes(
    investor_name, investor_email, principal_rupees, interest_rate_pct,
    issue_date, maturity_date, conversion_trigger, conversion_discount_pct,
    valuation_cap_rupees, notes
  ) VALUES (
    p_investor_name, p_investor_email, p_principal_rupees, p_interest_rate_pct,
    p_issue_date, p_maturity_date, p_conversion_trigger, p_conversion_discount_pct,
    p_valuation_cap_rupees, p_notes
  )
  RETURNING id INTO v_id;
  INSERT INTO investor_convertible_note_events(note_id, event_type, event_amount_rupees, event_note)
  VALUES (v_id, 'issued', p_principal_rupees, p_notes);
  PERFORM log_founder_action('icn.logged', v_id::text, jsonb_build_object('investor', p_investor_name, 'principal', p_principal_rupees));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_convertible_debt_log_note(text, text, bigint, numeric, date, date, text, numeric, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_convertible_debt_log_note(text, text, bigint, numeric, date, date, text, numeric, bigint, text) TO authenticated;

COMMIT;