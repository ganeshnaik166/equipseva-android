BEGIN;

-- =====================================================================
-- r2383 — Hospital chain regulatory-audit readiness
-- Per-chain compliance docs ready for their audits, gap log, readiness score
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.hospital_chain_audit_docs_r2383 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL,
  chain_name text NOT NULL,
  regulator text NOT NULL CHECK (regulator IN ('nabh','cdsco','aerb','pcb','fire','bmw','dpdp','gst','other')),
  audit_window_start date,
  audit_window_end date,
  doc_kind text NOT NULL CHECK (doc_kind IN ('calibration_cert','amc_contract','engineer_license','preventive_log','incident_log','training_record','spare_provenance','biomed_register','dpdp_register','other')),
  doc_title text NOT NULL,
  doc_url text,
  ready boolean NOT NULL DEFAULT false,
  last_refreshed_at timestamptz,
  expires_on date,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id)
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_audit_gaps_r2383 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL,
  chain_name text NOT NULL,
  regulator text NOT NULL CHECK (regulator IN ('nabh','cdsco','aerb','pcb','fire','bmw','dpdp','gst','other')),
  gap_kind text NOT NULL CHECK (gap_kind IN ('missing_doc','expired_doc','stale_data','signature_missing','training_overdue','license_lapsed','calibration_overdue','other')),
  gap_title text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('blocker','high','medium','low')),
  detected_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  remediation text,
  owner_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id)
);

ALTER TABLE public.hospital_chain_audit_docs_r2383 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_audit_gaps_r2383 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_audit_docs_r2383;
CREATE POLICY founder_all ON public.hospital_chain_audit_docs_r2383
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_audit_gaps_r2383;
CREATE POLICY founder_all ON public.hospital_chain_audit_gaps_r2383
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_audit_docs_r2383_chain ON public.hospital_chain_audit_docs_r2383(chain_id, regulator);
CREATE INDEX IF NOT EXISTS idx_audit_docs_r2383_ready ON public.hospital_chain_audit_docs_r2383(ready, expires_on);
CREATE INDEX IF NOT EXISTS idx_audit_gaps_r2383_chain ON public.hospital_chain_audit_gaps_r2383(chain_id, severity);
CREATE INDEX IF NOT EXISTS idx_audit_gaps_r2383_open ON public.hospital_chain_audit_gaps_r2383(resolved_at) WHERE resolved_at IS NULL;

-- =====================================================================
-- RPC 1 — list all docs across chains
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_audit_docs_r2383();
CREATE OR REPLACE FUNCTION public.list_audit_docs_r2383()
RETURNS TABLE (
  id uuid,
  chain_id uuid,
  chain_name text,
  regulator text,
  doc_kind text,
  doc_title text,
  ready boolean,
  last_refreshed_at timestamptz,
  expires_on date,
  owner_email text,
  audit_window_start date,
  audit_window_end date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT d.id, d.chain_id, d.chain_name, d.regulator, d.doc_kind, d.doc_title,
         d.ready, d.last_refreshed_at, d.expires_on, d.owner_email,
         d.audit_window_start, d.audit_window_end
  FROM public.hospital_chain_audit_docs_r2383 d
  ORDER BY d.chain_name ASC, d.regulator ASC, d.doc_kind ASC;
END;
$$;

-- =====================================================================
-- RPC 2 — list open gaps
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_audit_gaps_r2383();
CREATE OR REPLACE FUNCTION public.list_audit_gaps_r2383()
RETURNS TABLE (
  id uuid,
  chain_id uuid,
  chain_name text,
  regulator text,
  gap_kind text,
  gap_title text,
  severity text,
  detected_at timestamptz,
  remediation text,
  owner_email text,
  days_open integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT g.id, g.chain_id, g.chain_name, g.regulator, g.gap_kind, g.gap_title,
         g.severity, g.detected_at, g.remediation, g.owner_email,
         GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (now() - g.detected_at)) / 86400))::integer AS days_open
  FROM public.hospital_chain_audit_gaps_r2383 g
  WHERE g.resolved_at IS NULL
  ORDER BY
    CASE g.severity WHEN 'blocker' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    g.detected_at ASC;
END;
$$;

-- =====================================================================
-- RPC 3 — readiness score per chain
-- =====================================================================
DROP FUNCTION IF EXISTS public.chain_readiness_score_r2383();
CREATE OR REPLACE FUNCTION public.chain_readiness_score_r2383()
RETURNS TABLE (
  chain_id uuid,
  chain_name text,
  total_docs integer,
  ready_docs integer,
  expired_docs integer,
  blocker_gaps integer,
  high_gaps integer,
  medium_gaps integer,
  low_gaps integer,
  readiness_pct integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH docs AS (
    SELECT d.chain_id, d.chain_name,
           COUNT(*)::int AS total_docs,
           COUNT(*) FILTER (WHERE d.ready AND (d.expires_on IS NULL OR d.expires_on >= CURRENT_DATE))::int AS ready_docs,
           COUNT(*) FILTER (WHERE d.expires_on IS NOT NULL AND d.expires_on < CURRENT_DATE)::int AS expired_docs
    FROM public.hospital_chain_audit_docs_r2383 d
    GROUP BY d.chain_id, d.chain_name
  ),
  gaps AS (
    SELECT g.chain_id,
           COUNT(*) FILTER (WHERE g.severity = 'blocker' AND g.resolved_at IS NULL)::int AS blocker_gaps,
           COUNT(*) FILTER (WHERE g.severity = 'high'    AND g.resolved_at IS NULL)::int AS high_gaps,
           COUNT(*) FILTER (WHERE g.severity = 'medium'  AND g.resolved_at IS NULL)::int AS medium_gaps,
           COUNT(*) FILTER (WHERE g.severity = 'low'     AND g.resolved_at IS NULL)::int AS low_gaps
    FROM public.hospital_chain_audit_gaps_r2383 g
    GROUP BY g.chain_id
  )
  SELECT d.chain_id, d.chain_name,
         d.total_docs,
         d.ready_docs,
         d.expired_docs,
         COALESCE(g.blocker_gaps, 0),
         COALESCE(g.high_gaps, 0),
         COALESCE(g.medium_gaps, 0),
         COALESCE(g.low_gaps, 0),
         CASE WHEN d.total_docs = 0 THEN 0
              ELSE GREATEST(0, LEAST(100,
                ((d.ready_docs * 100 / d.total_docs)
                 - COALESCE(g.blocker_gaps, 0) * 20
                 - COALESCE(g.high_gaps, 0) * 10
                 - COALESCE(g.medium_gaps, 0) * 4
                 - COALESCE(g.low_gaps, 0) * 1)::int
              ))
         END AS readiness_pct
  FROM docs d
  LEFT JOIN gaps g ON g.chain_id = d.chain_id
  ORDER BY readiness_pct ASC, d.chain_name ASC;
END;
$$;

-- =====================================================================
-- RPC 4 — docs expiring or stale within N days
-- =====================================================================
DROP FUNCTION IF EXISTS public.expiring_audit_docs_r2383(integer);
CREATE OR REPLACE FUNCTION public.expiring_audit_docs_r2383(p_days integer DEFAULT 30)
RETURNS TABLE (
  id uuid,
  chain_id uuid,
  chain_name text,
  regulator text,
  doc_kind text,
  doc_title text,
  expires_on date,
  days_until_expiry integer,
  owner_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT d.id, d.chain_id, d.chain_name, d.regulator, d.doc_kind, d.doc_title,
         d.expires_on,
         (d.expires_on - CURRENT_DATE)::int AS days_until_expiry,
         d.owner_email
  FROM public.hospital_chain_audit_docs_r2383 d
  WHERE d.expires_on IS NOT NULL
    AND d.expires_on <= CURRENT_DATE + (p_days || ' days')::interval
  ORDER BY d.expires_on ASC;
END;
$$;

-- =====================================================================
-- RPC 5 — upcoming audit windows
-- =====================================================================
DROP FUNCTION IF EXISTS public.upcoming_audit_windows_r2383();
CREATE OR REPLACE FUNCTION public.upcoming_audit_windows_r2383()
RETURNS TABLE (
  chain_id uuid,
  chain_name text,
  regulator text,
  audit_window_start date,
  audit_window_end date,
  days_until_audit integer,
  ready_docs integer,
  total_docs integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT d.chain_id, d.chain_name, d.regulator,
         MIN(d.audit_window_start) AS audit_window_start,
         MAX(d.audit_window_end)   AS audit_window_end,
         (MIN(d.audit_window_start) - CURRENT_DATE)::int AS days_until_audit,
         COUNT(*) FILTER (WHERE d.ready AND (d.expires_on IS NULL OR d.expires_on >= CURRENT_DATE))::int AS ready_docs,
         COUNT(*)::int AS total_docs
  FROM public.hospital_chain_audit_docs_r2383 d
  WHERE d.audit_window_start IS NOT NULL
    AND d.audit_window_start >= CURRENT_DATE
  GROUP BY d.chain_id, d.chain_name, d.regulator
  ORDER BY audit_window_start ASC;
END;
$$;

-- =====================================================================
-- RPC 6 — gap breakdown by regulator
-- =====================================================================
DROP FUNCTION IF EXISTS public.gaps_by_regulator_r2383();
CREATE OR REPLACE FUNCTION public.gaps_by_regulator_r2383()
RETURNS TABLE (
  regulator text,
  blocker_gaps integer,
  high_gaps integer,
  medium_gaps integer,
  low_gaps integer,
  total_open integer,
  chains_affected integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT g.regulator,
         COUNT(*) FILTER (WHERE g.severity = 'blocker')::int,
         COUNT(*) FILTER (WHERE g.severity = 'high')::int,
         COUNT(*) FILTER (WHERE g.severity = 'medium')::int,
         COUNT(*) FILTER (WHERE g.severity = 'low')::int,
         COUNT(*)::int,
         COUNT(DISTINCT g.chain_id)::int
  FROM public.hospital_chain_audit_gaps_r2383 g
  WHERE g.resolved_at IS NULL
  GROUP BY g.regulator
  ORDER BY COUNT(*) DESC;
END;
$$;

-- =====================================================================
-- RPC 7 — portfolio-wide audit readiness summary
-- =====================================================================
DROP FUNCTION IF EXISTS public.portfolio_audit_summary_r2383();
CREATE OR REPLACE FUNCTION public.portfolio_audit_summary_r2383()
RETURNS TABLE (
  total_chains integer,
  total_docs integer,
  ready_docs integer,
  expired_docs integer,
  open_gaps integer,
  blocker_gaps integer,
  upcoming_audits_30d integer,
  avg_readiness_pct integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_avg_pct integer;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(AVG(s.readiness_pct), 0)::int INTO v_avg_pct
  FROM public.chain_readiness_score_r2383() s;

  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT d.chain_id)::int FROM public.hospital_chain_audit_docs_r2383 d),
    (SELECT COUNT(*)::int FROM public.hospital_chain_audit_docs_r2383),
    (SELECT COUNT(*)::int FROM public.hospital_chain_audit_docs_r2383
       WHERE ready AND (expires_on IS NULL OR expires_on >= CURRENT_DATE)),
    (SELECT COUNT(*)::int FROM public.hospital_chain_audit_docs_r2383
       WHERE expires_on IS NOT NULL AND expires_on < CURRENT_DATE),
    (SELECT COUNT(*)::int FROM public.hospital_chain_audit_gaps_r2383 WHERE resolved_at IS NULL),
    (SELECT COUNT(*)::int FROM public.hospital_chain_audit_gaps_r2383
       WHERE resolved_at IS NULL AND severity = 'blocker'),
    (SELECT COUNT(DISTINCT (d.chain_id, d.regulator))::int FROM public.hospital_chain_audit_docs_r2383 d
       WHERE d.audit_window_start IS NOT NULL
         AND d.audit_window_start BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'),
    v_avg_pct;
END;
$$;

-- =====================================================================
-- Grants
-- =====================================================================
REVOKE ALL ON FUNCTION public.list_audit_docs_r2383()           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_audit_gaps_r2383()           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.chain_readiness_score_r2383()     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.expiring_audit_docs_r2383(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.upcoming_audit_windows_r2383()    FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gaps_by_regulator_r2383()         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.portfolio_audit_summary_r2383()   FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_audit_docs_r2383()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_audit_gaps_r2383()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.chain_readiness_score_r2383()     TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_audit_docs_r2383(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_audit_windows_r2383()    TO authenticated;
GRANT EXECUTE ON FUNCTION public.gaps_by_regulator_r2383()         TO authenticated;
GRANT EXECUTE ON FUNCTION public.portfolio_audit_summary_r2383()   TO authenticated;

COMMIT;
