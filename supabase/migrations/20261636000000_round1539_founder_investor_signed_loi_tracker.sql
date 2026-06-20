BEGIN;

-- ============================================================
-- r1539 — Founder investor signed-LOI tracker
-- Tracks every signed LOI / term-sheet (binding + non-binding)
-- separately from cap_table. Surfaces stale signed docs.
-- ============================================================

CREATE TABLE IF NOT EXISTS investor_signed_loi_tracker_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_firm text,
  doc_kind text NOT NULL CHECK (doc_kind IN ('loi','term_sheet','sidecar','convertible_safe')),
  is_binding boolean NOT NULL DEFAULT false,
  signed_at timestamptz NOT NULL DEFAULT now(),
  close_by_date date,
  commit_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (commit_amount_rupees >= 0),
  valuation_pre_money_rupees bigint CHECK (valuation_pre_money_rupees IS NULL OR valuation_pre_money_rupees >= 0),
  status text NOT NULL DEFAULT 'signed' CHECK (status IN ('signed','in_diligence','funds_wired','closed','withdrawn','expired')),
  doc_url text,
  notes text,
  created_by_user uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isloitv2_status ON investor_signed_loi_tracker_v2(status);
CREATE INDEX IF NOT EXISTS idx_isloitv2_close_by ON investor_signed_loi_tracker_v2(close_by_date);
CREATE INDEX IF NOT EXISTS idx_isloitv2_signed_at ON investor_signed_loi_tracker_v2(signed_at DESC);

ALTER TABLE investor_signed_loi_tracker_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS isloitv2_founder_all ON investor_signed_loi_tracker_v2;
CREATE POLICY isloitv2_founder_all ON investor_signed_loi_tracker_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS investor_signed_loi_events_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loi_id uuid NOT NULL REFERENCES investor_signed_loi_tracker_v2(id) ON DELETE CASCADE,
  event_kind text NOT NULL CHECK (event_kind IN ('status_change','reminder','note','close_by_extended')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isloiev2_loi ON investor_signed_loi_events_v2(loi_id, created_at DESC);

ALTER TABLE investor_signed_loi_events_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS isloiev2_founder_all ON investor_signed_loi_events_v2;
CREATE POLICY isloiev2_founder_all ON investor_signed_loi_events_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- ============================================================
-- log_founder_* helpers
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_loi_create(p_loi_id uuid, p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'loi_create', jsonb_build_object('loi_id', p_loi_id, 'after', p_after));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_loi_create(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_loi_create(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_loi_status_change(p_loi_id uuid, p_new_status text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'loi_status_change', jsonb_build_object('loi_id', p_loi_id, 'new_status', p_new_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_loi_status_change(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_loi_status_change(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_loi_reminder(p_loi_id uuid, p_note text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'loi_reminder', jsonb_build_object('loi_id', p_loi_id, 'note', p_note));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_loi_reminder(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_loi_reminder(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_loi_withdraw(p_loi_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'loi_withdraw', jsonb_build_object('loi_id', p_loi_id, 'reason', p_reason));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_loi_withdraw(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_loi_withdraw(uuid, text) TO authenticated;


-- ============================================================
-- 7 SECDEF RPCs
-- ============================================================

-- 1. KPI summary
CREATE OR REPLACE FUNCTION founder_loi_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_count', COUNT(*),
    'signed_count', COUNT(*) FILTER (WHERE status='signed'),
    'in_diligence_count', COUNT(*) FILTER (WHERE status='in_diligence'),
    'funds_wired_count', COUNT(*) FILTER (WHERE status='funds_wired'),
    'closed_count', COUNT(*) FILTER (WHERE status='closed'),
    'withdrawn_count', COUNT(*) FILTER (WHERE status='withdrawn'),
    'expired_count', COUNT(*) FILTER (WHERE status='expired'),
    'binding_count', COUNT(*) FILTER (WHERE is_binding),
    'non_binding_count', COUNT(*) FILTER (WHERE NOT is_binding),
    'total_commit_rupees', COALESCE(SUM(commit_amount_rupees) FILTER (WHERE status IN ('signed','in_diligence','funds_wired','closed')),0),
    'open_commit_rupees', COALESCE(SUM(commit_amount_rupees) FILTER (WHERE status IN ('signed','in_diligence')),0),
    'wired_rupees', COALESCE(SUM(commit_amount_rupees) FILTER (WHERE status='funds_wired'),0),
    'closed_rupees', COALESCE(SUM(commit_amount_rupees) FILTER (WHERE status='closed'),0),
    'stale_open_count', COUNT(*) FILTER (WHERE status IN ('signed','in_diligence') AND signed_at < now() - interval '30 days'),
    'overdue_close_by_count', COUNT(*) FILTER (WHERE status IN ('signed','in_diligence') AND close_by_date IS NOT NULL AND close_by_date < CURRENT_DATE),
    'closing_this_week_count', COUNT(*) FILTER (WHERE status IN ('signed','in_diligence') AND close_by_date IS NOT NULL AND close_by_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7)
  ) INTO r
  FROM investor_signed_loi_tracker_v2;
  RETURN r;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_loi_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loi_kpis() TO authenticated;

-- 2. All LOIs (recent)
CREATE OR REPLACE FUNCTION founder_loi_list_recent()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  doc_kind text,
  is_binding boolean,
  signed_at timestamptz,
  close_by_date date,
  commit_amount_rupees bigint,
  valuation_pre_money_rupees bigint,
  status text,
  age_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.investor_name, l.investor_firm, l.doc_kind, l.is_binding, l.signed_at, l.close_by_date,
         l.commit_amount_rupees, l.valuation_pre_money_rupees, l.status,
         ROUND(EXTRACT(EPOCH FROM (now() - l.signed_at))/86400.0, 1) AS age_days
  FROM investor_signed_loi_tracker_v2 l
  ORDER BY l.signed_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_loi_list_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loi_list_recent() TO authenticated;

-- 3. Stale signed (>30d open)
CREATE OR REPLACE FUNCTION founder_loi_stale_signed()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  doc_kind text,
  is_binding boolean,
  status text,
  commit_amount_rupees bigint,
  signed_at timestamptz,
  days_stale numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.investor_name, l.investor_firm, l.doc_kind, l.is_binding, l.status, l.commit_amount_rupees, l.signed_at,
         ROUND(EXTRACT(EPOCH FROM (now() - l.signed_at))/86400.0, 1) AS days_stale
  FROM investor_signed_loi_tracker_v2 l
  WHERE l.status IN ('signed','in_diligence')
    AND l.signed_at < now() - interval '30 days'
  ORDER BY l.signed_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_loi_stale_signed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loi_stale_signed() TO authenticated;

-- 4. Overdue close-by
CREATE OR REPLACE FUNCTION founder_loi_overdue_close_by()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  status text,
  is_binding boolean,
  commit_amount_rupees bigint,
  close_by_date date,
  days_overdue integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.investor_name, l.investor_firm, l.status, l.is_binding, l.commit_amount_rupees, l.close_by_date,
         (CURRENT_DATE - l.close_by_date)::integer AS days_overdue
  FROM investor_signed_loi_tracker_v2 l
  WHERE l.status IN ('signed','in_diligence')
    AND l.close_by_date IS NOT NULL
    AND l.close_by_date < CURRENT_DATE
  ORDER BY l.close_by_date ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_loi_overdue_close_by() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loi_overdue_close_by() TO authenticated;

-- 5. Closing this week
CREATE OR REPLACE FUNCTION founder_loi_closing_this_week()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  is_binding boolean,
  status text,
  commit_amount_rupees bigint,
  close_by_date date,
  days_until integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.investor_name, l.investor_firm, l.is_binding, l.status, l.commit_amount_rupees, l.close_by_date,
         (l.close_by_date - CURRENT_DATE)::integer AS days_until
  FROM investor_signed_loi_tracker_v2 l
  WHERE l.status IN ('signed','in_diligence')
    AND l.close_by_date IS NOT NULL
    AND l.close_by_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
  ORDER BY l.close_by_date ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_loi_closing_this_week() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loi_closing_this_week() TO authenticated;

-- 6. By status breakdown
CREATE OR REPLACE FUNCTION founder_loi_by_status()
RETURNS TABLE(
  status text,
  cnt bigint,
  binding_cnt bigint,
  total_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.status,
         COUNT(*)::bigint AS cnt,
         COUNT(*) FILTER (WHERE l.is_binding)::bigint AS binding_cnt,
         COALESCE(SUM(l.commit_amount_rupees),0)::bigint AS total_rupees
  FROM investor_signed_loi_tracker_v2 l
  GROUP BY l.status
  ORDER BY total_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_loi_by_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loi_by_status() TO authenticated;

-- 7. Recent events log
CREATE OR REPLACE FUNCTION founder_loi_recent_events()
RETURNS TABLE(
  id uuid,
  loi_id uuid,
  investor_name text,
  event_kind text,
  payload jsonb,
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
  SELECT e.id, e.loi_id, l.investor_name, e.event_kind, e.payload, e.created_at
  FROM investor_signed_loi_events_v2 e
  LEFT JOIN investor_signed_loi_tracker_v2 l ON l.id = e.loi_id
  ORDER BY e.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_loi_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_loi_recent_events() TO authenticated;

COMMIT;