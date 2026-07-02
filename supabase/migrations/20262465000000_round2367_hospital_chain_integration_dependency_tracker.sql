BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_integrations_r2367 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  integration_name text NOT NULL,
  integration_type text NOT NULL CHECK (integration_type IN ('his','lis','ris','pacs','erp','billing','inventory','sso','procurement','asset_tracking')),
  go_live_date date NOT NULL,
  primary_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  hospital_admin_email text NOT NULL,
  monthly_volume_cents bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'live' CHECK (status IN ('live','degraded','down','paused','retired')),
  criticality text NOT NULL DEFAULT 'high' CHECK (criticality IN ('low','medium','high','critical')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_integration_dependencies_r2367 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id uuid NOT NULL REFERENCES public.hospital_chain_integrations_r2367(id) ON DELETE CASCADE,
  vendor_name text NOT NULL,
  vendor_role text NOT NULL CHECK (vendor_role IN ('api','db','sso','middleware','file_drop','vpn','message_queue','cdn','dns','payments')),
  vendor_contact_email text,
  health_score int NOT NULL DEFAULT 100 CHECK (health_score BETWEEN 0 AND 100),
  last_incident_at timestamptz,
  sla_uptime_pct numeric(5,2) NOT NULL DEFAULT 99.50 CHECK (sla_uptime_pct BETWEEN 0 AND 100),
  fallback_plan text NOT NULL DEFAULT 'manual_csv_drop',
  fallback_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_blocking boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_integrations_r2367 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_integration_dependencies_r2367 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_integrations_r2367;
CREATE POLICY founder_all ON public.hospital_chain_integrations_r2367 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_integration_dependencies_r2367;
CREATE POLICY founder_all ON public.hospital_chain_integration_dependencies_r2367 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_hcid_int_id_r2367 ON public.hospital_chain_integration_dependencies_r2367(integration_id);
CREATE INDEX IF NOT EXISTS idx_hci_chain_r2367 ON public.hospital_chain_integrations_r2367(chain_name);

CREATE OR REPLACE FUNCTION public.r2367_list_integrations()
RETURNS TABLE(id uuid, chain_name text, integration_name text, integration_type text, status text, criticality text, go_live_date date, hospital_admin_email text, monthly_volume_cents bigint, dep_count bigint, blocking_count bigint, avg_health numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.chain_name, i.integration_name, i.integration_type, i.status, i.criticality, i.go_live_date, i.hospital_admin_email, i.monthly_volume_cents,
         COUNT(d.id) AS dep_count,
         COUNT(d.id) FILTER (WHERE d.is_blocking) AS blocking_count,
         COALESCE(AVG(d.health_score),100)::numeric AS avg_health
  FROM public.hospital_chain_integrations_r2367 i
  LEFT JOIN public.hospital_chain_integration_dependencies_r2367 d ON d.integration_id = i.id
  GROUP BY i.id
  ORDER BY i.criticality DESC, i.chain_name;
END$$;

CREATE OR REPLACE FUNCTION public.r2367_chain_rollup()
RETURNS TABLE(chain_name text, integration_count bigint, live_count bigint, degraded_count bigint, down_count bigint, total_monthly_volume_cents bigint, avg_health numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.chain_name,
         COUNT(i.id) AS integration_count,
         COUNT(i.id) FILTER (WHERE i.status='live') AS live_count,
         COUNT(i.id) FILTER (WHERE i.status='degraded') AS degraded_count,
         COUNT(i.id) FILTER (WHERE i.status='down') AS down_count,
         COALESCE(SUM(i.monthly_volume_cents),0)::bigint AS total_monthly_volume_cents,
         COALESCE(AVG(d.health_score),100)::numeric AS avg_health
  FROM public.hospital_chain_integrations_r2367 i
  LEFT JOIN public.hospital_chain_integration_dependencies_r2367 d ON d.integration_id = i.id
  GROUP BY i.chain_name
  ORDER BY total_monthly_volume_cents DESC;
END$$;

CREATE OR REPLACE FUNCTION public.r2367_dependencies(p_integration_id uuid)
RETURNS TABLE(id uuid, vendor_name text, vendor_role text, vendor_contact_email text, health_score int, last_incident_at timestamptz, sla_uptime_pct numeric, fallback_plan text, is_blocking boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.vendor_name, d.vendor_role, d.vendor_contact_email, d.health_score, d.last_incident_at, d.sla_uptime_pct, d.fallback_plan, d.is_blocking
  FROM public.hospital_chain_integration_dependencies_r2367 d
  WHERE d.integration_id = p_integration_id
  ORDER BY d.is_blocking DESC, d.health_score ASC;
END$$;

CREATE OR REPLACE FUNCTION public.r2367_top_risk_vendors()
RETURNS TABLE(vendor_name text, integration_count bigint, avg_health numeric, blocking_count bigint, last_incident_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.vendor_name,
         COUNT(DISTINCT d.integration_id) AS integration_count,
         AVG(d.health_score)::numeric AS avg_health,
         COUNT(d.id) FILTER (WHERE d.is_blocking) AS blocking_count,
         MAX(d.last_incident_at) AS last_incident_at
  FROM public.hospital_chain_integration_dependencies_r2367 d
  GROUP BY d.vendor_name
  ORDER BY avg_health ASC, blocking_count DESC
  LIMIT 25;
END$$;

CREATE OR REPLACE FUNCTION public.r2367_set_status(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('live','degraded','down','paused','retired') THEN RAISE EXCEPTION 'bad status'; END IF;
  UPDATE public.hospital_chain_integrations_r2367 SET status = p_status, updated_at = now() WHERE id = p_id;
END$$;

CREATE OR REPLACE FUNCTION public.r2367_log_incident(p_dep_id uuid, p_health int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_health < 0 OR p_health > 100 THEN RAISE EXCEPTION 'bad health'; END IF;
  UPDATE public.hospital_chain_integration_dependencies_r2367
  SET health_score = p_health, last_incident_at = now()
  WHERE id = p_dep_id;
END$$;

CREATE OR REPLACE FUNCTION public.r2367_summary()
RETURNS TABLE(total_integrations bigint, live_integrations bigint, degraded_integrations bigint, down_integrations bigint, total_deps bigint, blocking_deps bigint, avg_health numeric, total_monthly_volume_cents bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.hospital_chain_integrations_r2367),
    (SELECT COUNT(*) FROM public.hospital_chain_integrations_r2367 WHERE status='live'),
    (SELECT COUNT(*) FROM public.hospital_chain_integrations_r2367 WHERE status='degraded'),
    (SELECT COUNT(*) FROM public.hospital_chain_integrations_r2367 WHERE status='down'),
    (SELECT COUNT(*) FROM public.hospital_chain_integration_dependencies_r2367),
    (SELECT COUNT(*) FROM public.hospital_chain_integration_dependencies_r2367 WHERE is_blocking),
    (SELECT COALESCE(AVG(health_score),100)::numeric FROM public.hospital_chain_integration_dependencies_r2367),
    (SELECT COALESCE(SUM(monthly_volume_cents),0)::bigint FROM public.hospital_chain_integrations_r2367);
END$$;

REVOKE ALL ON FUNCTION public.r2367_list_integrations() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2367_chain_rollup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2367_dependencies(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2367_top_risk_vendors() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2367_set_status(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2367_log_incident(uuid, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2367_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2367_list_integrations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2367_chain_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2367_dependencies(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2367_top_risk_vendors() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2367_set_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2367_log_incident(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2367_summary() TO authenticated;

COMMIT;
