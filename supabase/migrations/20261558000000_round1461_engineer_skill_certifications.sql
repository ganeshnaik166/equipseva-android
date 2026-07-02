BEGIN;

-- ============================================================================
-- r1461 — Engineer Skill Certifications (external OEM certs + expiry + cost)
-- Extends r888-style internal cert ladder with Siemens / GE / Philips / etc.
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_external_certifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id     uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  oem_vendor      text NOT NULL CHECK (oem_vendor IN ('siemens','ge','philips','mindray','drager','fresenius','roche','abbott','other')),
  cert_name       text NOT NULL,
  cert_level      text NOT NULL CHECK (cert_level IN ('basic','intermediate','advanced','expert')),
  modality        text NOT NULL CHECK (modality IN ('ct','mri','xray','ultrasound','dialysis','ventilator','anesthesia','lab','patient_monitor','other')),
  cert_number     text,
  issued_on       date NOT NULL,
  expires_on      date NOT NULL,
  cost_rupees     bigint NOT NULL DEFAULT 0 CHECK (cost_rupees >= 0),
  funded_by       text NOT NULL DEFAULT 'company' CHECK (funded_by IN ('company','engineer','split','vendor_sponsored')),
  company_share_rupees bigint NOT NULL DEFAULT 0 CHECK (company_share_rupees >= 0),
  status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','revoked','renewal_pending')),
  proof_url       text,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eec_engineer ON engineer_external_certifications(engineer_id);
CREATE INDEX IF NOT EXISTS idx_eec_expires  ON engineer_external_certifications(expires_on);
CREATE INDEX IF NOT EXISTS idx_eec_vendor   ON engineer_external_certifications(oem_vendor);
CREATE INDEX IF NOT EXISTS idx_eec_status   ON engineer_external_certifications(status);

ALTER TABLE engineer_external_certifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eec_founder_all ON engineer_external_certifications;
CREATE POLICY eec_founder_all ON engineer_external_certifications
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_cert_renewal_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cert_id         uuid NOT NULL REFERENCES engineer_external_certifications(id) ON DELETE CASCADE,
  event_type      text NOT NULL CHECK (event_type IN ('scheduled','reminded','renewed','lapsed','escalated')),
  due_on          date,
  sla_days        int,
  actor_id        uuid REFERENCES profiles(id),
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecrl_cert ON engineer_cert_renewal_log(cert_id);
CREATE INDEX IF NOT EXISTS idx_ecrl_due  ON engineer_cert_renewal_log(due_on);

ALTER TABLE engineer_cert_renewal_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ecrl_founder_all ON engineer_cert_renewal_log;
CREATE POLICY ecrl_founder_all ON engineer_cert_renewal_log
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- log helpers (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_cert_added(p_cert_id uuid, p_note text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_cert_renewal_log(cert_id, event_type, actor_id, note)
  VALUES (p_cert_id, 'scheduled', auth.uid(), p_note);
END; $$;
GRANT EXECUTE ON FUNCTION log_founder_cert_added(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cert_reminder(p_cert_id uuid, p_due_on date, p_sla_days int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_cert_renewal_log(cert_id, event_type, due_on, sla_days, actor_id)
  VALUES (p_cert_id, 'reminded', p_due_on, p_sla_days, auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION log_founder_cert_reminder(uuid, date, int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cert_renewed(p_cert_id uuid, p_new_expiry date, p_cost_rupees bigint)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_cert_renewal_log(cert_id, event_type, due_on, actor_id, note)
  VALUES (p_cert_id, 'renewed', p_new_expiry, auth.uid(), 'cost=' || p_cost_rupees::text);
END; $$;
GRANT EXECUTE ON FUNCTION log_founder_cert_renewed(uuid, date, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cert_lapsed(p_cert_id uuid, p_note text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_cert_renewal_log(cert_id, event_type, actor_id, note)
  VALUES (p_cert_id, 'lapsed', auth.uid(), p_note);
END; $$;
GRANT EXECUTE ON FUNCTION log_founder_cert_lapsed(uuid, text) TO authenticated;

-- ============================================================================
-- 7 STABLE SECDEF RPCs
-- ============================================================================

-- 1) KPIs
CREATE OR REPLACE FUNCTION founder_cert_kpis()
RETURNS TABLE (
  total_certs bigint,
  active_certs bigint,
  expired_certs bigint,
  revoked_certs bigint,
  renewal_pending bigint,
  expiring_30d bigint,
  expiring_60d bigint,
  expiring_90d bigint,
  unique_engineers bigint,
  unique_vendors bigint,
  avg_cost_rupees bigint,
  total_cost_rupees bigint,
  company_funded_rupees bigint,
  engineer_funded_rupees bigint,
  expert_level_count bigint,
  vendor_sponsored_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status = 'active')::bigint,
    COUNT(*) FILTER (WHERE status = 'expired')::bigint,
    COUNT(*) FILTER (WHERE status = 'revoked')::bigint,
    COUNT(*) FILTER (WHERE status = 'renewal_pending')::bigint,
    COUNT(*) FILTER (WHERE status = 'active' AND expires_on <= CURRENT_DATE + 30)::bigint,
    COUNT(*) FILTER (WHERE status = 'active' AND expires_on <= CURRENT_DATE + 60)::bigint,
    COUNT(*) FILTER (WHERE status = 'active' AND expires_on <= CURRENT_DATE + 90)::bigint,
    COUNT(DISTINCT engineer_id)::bigint,
    COUNT(DISTINCT oem_vendor)::bigint,
    COALESCE(AVG(cost_rupees), 0)::bigint,
    COALESCE(SUM(cost_rupees), 0)::bigint,
    COALESCE(SUM(company_share_rupees), 0)::bigint,
    COALESCE(SUM(cost_rupees - company_share_rupees), 0)::bigint,
    COUNT(*) FILTER (WHERE cert_level = 'expert')::bigint,
    COUNT(*) FILTER (WHERE funded_by = 'vendor_sponsored')::bigint
  FROM engineer_external_certifications;
END; $$;
GRANT EXECUTE ON FUNCTION founder_cert_kpis() TO authenticated;

-- 2) Expiring soon (next 90 days)
CREATE OR REPLACE FUNCTION founder_cert_expiring_soon()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  oem_vendor text,
  cert_name text,
  cert_level text,
  modality text,
  expires_on date,
  days_remaining int,
  cost_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    COALESCE(p.full_name, 'Unknown')::text,
    c.oem_vendor,
    c.cert_name,
    c.cert_level,
    c.modality,
    c.expires_on,
    (c.expires_on - CURRENT_DATE)::int,
    c.cost_rupees,
    c.status
  FROM engineer_external_certifications c
  JOIN engineers e ON e.id = c.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  WHERE c.status IN ('active','renewal_pending')
    AND c.expires_on <= CURRENT_DATE + 90
  ORDER BY c.expires_on ASC
  LIMIT 200;
END; $$;
GRANT EXECUTE ON FUNCTION founder_cert_expiring_soon() TO authenticated;

-- 3) By vendor
CREATE OR REPLACE FUNCTION founder_cert_by_vendor()
RETURNS TABLE (
  id text,
  oem_vendor text,
  cert_count bigint,
  engineer_count bigint,
  expert_count bigint,
  total_cost_rupees bigint,
  expiring_60d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.oem_vendor::text AS id,
    c.oem_vendor,
    COUNT(*)::bigint,
    COUNT(DISTINCT c.engineer_id)::bigint,
    COUNT(*) FILTER (WHERE c.cert_level = 'expert')::bigint,
    COALESCE(SUM(c.cost_rupees), 0)::bigint,
    COUNT(*) FILTER (WHERE c.status = 'active' AND c.expires_on <= CURRENT_DATE + 60)::bigint
  FROM engineer_external_certifications c
  GROUP BY c.oem_vendor
  ORDER BY cert_count DESC;
END; $$;
GRANT EXECUTE ON FUNCTION founder_cert_by_vendor() TO authenticated;

-- 4) Engineer leaderboard by certs
CREATE OR REPLACE FUNCTION founder_cert_engineer_leaderboard()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  total_certs bigint,
  active_certs bigint,
  expert_certs bigint,
  unique_vendors bigint,
  total_cost_rupees bigint,
  next_expiry date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, 'Unknown')::text,
    COUNT(c.id)::bigint,
    COUNT(c.id) FILTER (WHERE c.status = 'active')::bigint,
    COUNT(c.id) FILTER (WHERE c.cert_level = 'expert')::bigint,
    COUNT(DISTINCT c.oem_vendor)::bigint,
    COALESCE(SUM(c.cost_rupees), 0)::bigint,
    MIN(c.expires_on) FILTER (WHERE c.status = 'active')
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.profile_id
  JOIN engineer_external_certifications c ON c.engineer_id = e.id
  GROUP BY e.id, p.full_name
  ORDER BY total_certs DESC, expert_certs DESC
  LIMIT 100;
END; $$;
GRANT EXECUTE ON FUNCTION founder_cert_engineer_leaderboard() TO authenticated;

-- 5) Cost trend by month (last 12 months)
CREATE OR REPLACE FUNCTION founder_cert_cost_trend()
RETURNS TABLE (
  id text,
  month_label text,
  cert_count bigint,
  total_cost_rupees bigint,
  company_share_rupees bigint,
  vendor_sponsored bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('month', c.issued_on), 'YYYY-MM') AS id,
    to_char(date_trunc('month', c.issued_on), 'Mon YYYY') AS month_label,
    COUNT(*)::bigint,
    COALESCE(SUM(c.cost_rupees), 0)::bigint,
    COALESCE(SUM(c.company_share_rupees), 0)::bigint,
    COUNT(*) FILTER (WHERE c.funded_by = 'vendor_sponsored')::bigint
  FROM engineer_external_certifications c
  WHERE c.issued_on >= (CURRENT_DATE - INTERVAL '12 months')
  GROUP BY 1, 2
  ORDER BY 1 DESC;
END; $$;
GRANT EXECUTE ON FUNCTION founder_cert_cost_trend() TO authenticated;

-- 6) Renewal SLA breaches
CREATE OR REPLACE FUNCTION founder_cert_renewal_sla_breaches()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  oem_vendor text,
  cert_name text,
  expires_on date,
  days_overdue int,
  status text,
  last_reminder timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    COALESCE(p.full_name, 'Unknown')::text,
    c.oem_vendor,
    c.cert_name,
    c.expires_on,
    (CURRENT_DATE - c.expires_on)::int,
    c.status,
    (SELECT MAX(l.created_at) FROM engineer_cert_renewal_log l WHERE l.cert_id = c.id AND l.event_type = 'reminded')
  FROM engineer_external_certifications c
  JOIN engineers e ON e.id = c.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  WHERE c.expires_on < CURRENT_DATE
    AND c.status IN ('active','renewal_pending','expired')
  ORDER BY c.expires_on ASC
  LIMIT 100;
END; $$;
GRANT EXECUTE ON FUNCTION founder_cert_renewal_sla_breaches() TO authenticated;

-- 7) Recent renewal log
CREATE OR REPLACE FUNCTION founder_cert_recent_renewal_log()
RETURNS TABLE (
  id uuid,
  cert_name text,
  engineer_name text,
  event_type text,
  due_on date,
  sla_days int,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    c.cert_name,
    COALESCE(p.full_name, 'Unknown')::text,
    l.event_type,
    l.due_on,
    l.sla_days,
    l.note,
    l.created_at
  FROM engineer_cert_renewal_log l
  JOIN engineer_external_certifications c ON c.id = l.cert_id
  JOIN engineers e ON e.id = c.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  ORDER BY l.created_at DESC
  LIMIT 100;
END; $$;
GRANT EXECUTE ON FUNCTION founder_cert_recent_renewal_log() TO authenticated;

COMMIT;