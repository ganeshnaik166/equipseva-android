BEGIN;

-- ============================================================================
-- r2339: Hospital chain procurement-portal integration status tracker
-- ============================================================================
-- Tracks which hospital chains require Equipseva to upload invoices/POs to
-- their procurement portals (GHX, Hospaccx, custom SAP Ariba instances, etc),
-- the current integration state, compliance gaps, and SLA risk.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_chain_portal_integrations_r2339 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  portal_name text NOT NULL,
  portal_vendor text NOT NULL CHECK (portal_vendor IN ('ghx','hospaccx','sap_ariba','coupa','medusind','custom','manual_email')),
  portal_url text,
  upload_required boolean NOT NULL DEFAULT true,
  document_types text[] NOT NULL DEFAULT ARRAY['invoice','po_ack','delivery_note']::text[],
  integration_status text NOT NULL DEFAULT 'not_started'
    CHECK (integration_status IN ('not_started','requirements_gathering','dev_in_progress','uat','live','degraded','suspended')),
  auth_method text CHECK (auth_method IN ('api_key','oauth2','saml_sso','sftp_key','manual_login',NULL)),
  api_credentials_vault_ref text,
  monthly_volume_invoices int NOT NULL DEFAULT 0,
  monthly_gmv_rupees bigint NOT NULL DEFAULT 0,
  last_successful_upload_at timestamptz,
  last_failed_upload_at timestamptz,
  consecutive_failure_count int NOT NULL DEFAULT 0,
  contract_clause_ref text,
  penalty_per_miss_rupees bigint NOT NULL DEFAULT 0,
  go_live_target_date date,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcpi_r2339_status ON public.hospital_chain_portal_integrations_r2339(integration_status);
CREATE INDEX IF NOT EXISTS idx_hcpi_r2339_chain ON public.hospital_chain_portal_integrations_r2339(chain_name);
CREATE INDEX IF NOT EXISTS idx_hcpi_r2339_vendor ON public.hospital_chain_portal_integrations_r2339(portal_vendor);

ALTER TABLE public.hospital_chain_portal_integrations_r2339 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcpi_r2339_founder_all ON public.hospital_chain_portal_integrations_r2339;
CREATE POLICY hcpi_r2339_founder_all ON public.hospital_chain_portal_integrations_r2339
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_chain_portal_upload_events_r2339 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id uuid NOT NULL REFERENCES public.hospital_chain_portal_integrations_r2339(id) ON DELETE CASCADE,
  document_type text NOT NULL,
  document_ref text NOT NULL,
  invoice_amount_rupees bigint NOT NULL DEFAULT 0,
  upload_outcome text NOT NULL CHECK (upload_outcome IN ('success','failed','retry_pending','manual_fallback')),
  failure_reason text,
  attempted_at timestamptz NOT NULL DEFAULT now(),
  uploaded_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  retry_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcpue_r2339_integration ON public.hospital_chain_portal_upload_events_r2339(integration_id);
CREATE INDEX IF NOT EXISTS idx_hcpue_r2339_outcome ON public.hospital_chain_portal_upload_events_r2339(upload_outcome);
CREATE INDEX IF NOT EXISTS idx_hcpue_r2339_attempted ON public.hospital_chain_portal_upload_events_r2339(attempted_at DESC);

ALTER TABLE public.hospital_chain_portal_upload_events_r2339 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcpue_r2339_founder_all ON public.hospital_chain_portal_upload_events_r2339;
CREATE POLICY hcpue_r2339_founder_all ON public.hospital_chain_portal_upload_events_r2339
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: Portfolio summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2339_portal_portfolio_summary()
RETURNS TABLE(
  total_chains bigint,
  live_count bigint,
  in_progress_count bigint,
  not_started_count bigint,
  degraded_count bigint,
  total_monthly_invoices bigint,
  total_monthly_gmv_rupees bigint,
  total_penalty_exposure_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE integration_status = 'live')::bigint,
    count(*) FILTER (WHERE integration_status IN ('requirements_gathering','dev_in_progress','uat'))::bigint,
    count(*) FILTER (WHERE integration_status = 'not_started')::bigint,
    count(*) FILTER (WHERE integration_status IN ('degraded','suspended'))::bigint,
    coalesce(sum(monthly_volume_invoices),0)::bigint,
    coalesce(sum(monthly_gmv_rupees),0)::bigint,
    coalesce(sum(penalty_per_miss_rupees * consecutive_failure_count),0)::bigint
  FROM public.hospital_chain_portal_integrations_r2339;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2339_portal_portfolio_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2339_portal_portfolio_summary() TO authenticated;

-- ============================================================================
-- RPC 2: Status breakdown by vendor
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2339_portal_vendor_breakdown()
RETURNS TABLE(
  portal_vendor text,
  chain_count bigint,
  live_count bigint,
  monthly_gmv_rupees bigint,
  avg_failure_count numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.portal_vendor,
    count(*)::bigint,
    count(*) FILTER (WHERE i.integration_status = 'live')::bigint,
    coalesce(sum(i.monthly_gmv_rupees),0)::bigint,
    round(avg(i.consecutive_failure_count)::numeric, 2)
  FROM public.hospital_chain_portal_integrations_r2339 i
  GROUP BY i.portal_vendor
  ORDER BY count(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2339_portal_vendor_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2339_portal_vendor_breakdown() TO authenticated;

-- ============================================================================
-- RPC 3: All integrations list
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2339_portal_list_all()
RETURNS TABLE(
  id uuid,
  chain_name text,
  portal_name text,
  portal_vendor text,
  integration_status text,
  monthly_volume_invoices int,
  monthly_gmv_rupees bigint,
  consecutive_failure_count int,
  last_successful_upload_at timestamptz,
  go_live_target_date date,
  owner_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id, i.chain_name, i.portal_name, i.portal_vendor,
    i.integration_status, i.monthly_volume_invoices, i.monthly_gmv_rupees,
    i.consecutive_failure_count, i.last_successful_upload_at,
    i.go_live_target_date, p.email
  FROM public.hospital_chain_portal_integrations_r2339 i
  LEFT JOIN public.profiles p ON p.id = i.owner_user_id
  ORDER BY i.monthly_gmv_rupees DESC, i.chain_name ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2339_portal_list_all() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2339_portal_list_all() TO authenticated;

-- ============================================================================
-- RPC 4: At-risk integrations (failures or overdue go-live)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2339_portal_at_risk()
RETURNS TABLE(
  id uuid,
  chain_name text,
  portal_name text,
  integration_status text,
  consecutive_failure_count int,
  go_live_target_date date,
  days_overdue int,
  penalty_exposure_rupees bigint,
  risk_reason text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id, i.chain_name, i.portal_name, i.integration_status,
    i.consecutive_failure_count, i.go_live_target_date,
    CASE WHEN i.go_live_target_date IS NOT NULL AND i.go_live_target_date < current_date AND i.integration_status != 'live'
         THEN (current_date - i.go_live_target_date) ELSE 0 END,
    (i.penalty_per_miss_rupees * i.consecutive_failure_count)::bigint,
    CASE
      WHEN i.consecutive_failure_count >= 3 THEN 'upload_failing'
      WHEN i.integration_status = 'degraded' THEN 'degraded_status'
      WHEN i.integration_status = 'suspended' THEN 'suspended'
      WHEN i.go_live_target_date IS NOT NULL AND i.go_live_target_date < current_date AND i.integration_status != 'live' THEN 'go_live_overdue'
      ELSE 'other'
    END
  FROM public.hospital_chain_portal_integrations_r2339 i
  WHERE i.consecutive_failure_count >= 3
     OR i.integration_status IN ('degraded','suspended')
     OR (i.go_live_target_date IS NOT NULL AND i.go_live_target_date < current_date AND i.integration_status != 'live')
  ORDER BY (i.penalty_per_miss_rupees * i.consecutive_failure_count) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2339_portal_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2339_portal_at_risk() TO authenticated;

-- ============================================================================
-- RPC 5: Recent upload events
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2339_portal_recent_uploads(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  chain_name text,
  portal_name text,
  document_type text,
  document_ref text,
  invoice_amount_rupees bigint,
  upload_outcome text,
  failure_reason text,
  attempted_at timestamptz,
  retry_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id, i.chain_name, i.portal_name, e.document_type, e.document_ref,
    e.invoice_amount_rupees, e.upload_outcome, e.failure_reason,
    e.attempted_at, e.retry_count
  FROM public.hospital_chain_portal_upload_events_r2339 e
  JOIN public.hospital_chain_portal_integrations_r2339 i ON i.id = e.integration_id
  ORDER BY e.attempted_at DESC
  LIMIT greatest(1, least(coalesce(p_limit,50), 500));
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2339_portal_recent_uploads(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2339_portal_recent_uploads(int) TO authenticated;

-- ============================================================================
-- RPC 6: Compliance gaps — chains where upload is required but not live
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2339_portal_compliance_gaps()
RETURNS TABLE(
  id uuid,
  chain_name text,
  portal_name text,
  portal_vendor text,
  integration_status text,
  contract_clause_ref text,
  monthly_gmv_at_risk_rupees bigint,
  days_until_go_live int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id, i.chain_name, i.portal_name, i.portal_vendor, i.integration_status,
    i.contract_clause_ref, i.monthly_gmv_rupees,
    CASE WHEN i.go_live_target_date IS NOT NULL THEN (i.go_live_target_date - current_date) ELSE NULL END
  FROM public.hospital_chain_portal_integrations_r2339 i
  WHERE i.upload_required = true
    AND i.integration_status != 'live'
  ORDER BY i.monthly_gmv_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2339_portal_compliance_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2339_portal_compliance_gaps() TO authenticated;

-- ============================================================================
-- RPC 7: 30-day upload success rate by chain
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2339_portal_success_rate_30d()
RETURNS TABLE(
  chain_name text,
  portal_name text,
  total_attempts bigint,
  success_count bigint,
  failed_count bigint,
  success_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.chain_name, i.portal_name,
    count(e.id)::bigint,
    count(e.id) FILTER (WHERE e.upload_outcome = 'success')::bigint,
    count(e.id) FILTER (WHERE e.upload_outcome = 'failed')::bigint,
    CASE WHEN count(e.id) = 0 THEN 0::numeric
         ELSE round((count(e.id) FILTER (WHERE e.upload_outcome = 'success'))::numeric * 100 / count(e.id)::numeric, 2)
    END
  FROM public.hospital_chain_portal_integrations_r2339 i
  LEFT JOIN public.hospital_chain_portal_upload_events_r2339 e
    ON e.integration_id = i.id AND e.attempted_at > now() - interval '30 days'
  GROUP BY i.id, i.chain_name, i.portal_name
  ORDER BY count(e.id) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2339_portal_success_rate_30d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2339_portal_success_rate_30d() TO authenticated;

COMMIT;
