-- Round r2584 — customer-equipment-data-portability-export
-- Track hospital equipment data portability/export feasibility, format, DPDP compliance and revenue.

BEGIN;

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.equipment_data_portability_r2584 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL,
  export_feasibility text NOT NULL CHECK (export_feasibility IN ('yes','partial','no')),
  format_kind text NOT NULL CHECK (format_kind IN ('dicom','hl7','csv','proprietary','none')),
  revenue_rupees bigint NOT NULL DEFAULT 0,
  dpdp_compliance text NOT NULL CHECK (dpdp_compliance IN ('compliant','marginal','non_compliant')),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'scoping' CHECK (status IN ('scoping','in_setup','live','broken','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_edp_r2584_kind       ON public.equipment_data_portability_r2584(equipment_kind);
CREATE INDEX IF NOT EXISTS idx_edp_r2584_feas       ON public.equipment_data_portability_r2584(export_feasibility);
CREATE INDEX IF NOT EXISTS idx_edp_r2584_format     ON public.equipment_data_portability_r2584(format_kind);
CREATE INDEX IF NOT EXISTS idx_edp_r2584_dpdp       ON public.equipment_data_portability_r2584(dpdp_compliance);
CREATE INDEX IF NOT EXISTS idx_edp_r2584_status     ON public.equipment_data_portability_r2584(status);

CREATE TABLE IF NOT EXISTS public.portability_revenue_log_r2584 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  portability_id uuid NOT NULL REFERENCES public.equipment_data_portability_r2584(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  revenue_kind text NOT NULL CHECK (revenue_kind IN ('data_subscription','api_seat','report_pack','training_credit')),
  amount_rupees bigint NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prl_r2584_portability ON public.portability_revenue_log_r2584(portability_id);
CREATE INDEX IF NOT EXISTS idx_prl_r2584_observed    ON public.portability_revenue_log_r2584(observed_at);
CREATE INDEX IF NOT EXISTS idx_prl_r2584_kind        ON public.portability_revenue_log_r2584(revenue_kind);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.equipment_data_portability_r2584 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portability_revenue_log_r2584    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.equipment_data_portability_r2584;
CREATE POLICY founder_all ON public.equipment_data_portability_r2584
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.portability_revenue_log_r2584;
CREATE POLICY founder_all ON public.portability_revenue_log_r2584
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEED
-- ============================================================

INSERT INTO public.equipment_data_portability_r2584
  (equipment_label, equipment_kind, export_feasibility, format_kind, revenue_rupees, dpdp_compliance, owner_email, status, notes)
VALUES
  ('Apollo Hyd CT-64 slice',     'ct_scanner',         'yes',     'dicom',       420000, 'compliant',      'data@equipseva.example', 'live',     'DICOM auto-export pipeline; PACS bridge stable'),
  ('Medanta MRI 3T',             'mri',                'partial', 'dicom',       180000, 'marginal',       'data@equipseva.example', 'in_setup', 'Vendor proprietary headers; partial anonymisation'),
  ('Aster Lab Auto-analyzer',    'lab_analyzer',       'yes',     'hl7',         260000, 'compliant',      'data@equipseva.example', 'live',     'HL7 v2 feed to LIMS; report pack monthly'),
  ('KIMS Ventilator V60',        'ventilator',         'no',      'proprietary',      0, 'non_compliant',  'data@equipseva.example', 'broken',   'Closed firmware; vendor refuses export'),
  ('Fortis Ultrasound GE LOGIQ', 'ultrasound',         'partial', 'csv',          95000, 'marginal',       'data@equipseva.example', 'scoping',  'CSV measurement export; no images')
ON CONFLICT DO NOTHING;

INSERT INTO public.portability_revenue_log_r2584
  (portability_id, observed_at, revenue_kind, amount_rupees, owner_email, status, notes)
SELECT id, now() - interval '5 days',  'data_subscription', 75000, 'data@equipseva.example', 'done', 'May DICOM subscription billed'
  FROM public.equipment_data_portability_r2584 WHERE equipment_label='Apollo Hyd CT-64 slice' LIMIT 1;

INSERT INTO public.portability_revenue_log_r2584
  (portability_id, observed_at, revenue_kind, amount_rupees, owner_email, status, notes)
SELECT id, now() - interval '12 days', 'api_seat',          42000, 'data@equipseva.example', 'done', '3 API seats activated for radiology team'
  FROM public.equipment_data_portability_r2584 WHERE equipment_label='Apollo Hyd CT-64 slice' LIMIT 1;

INSERT INTO public.portability_revenue_log_r2584
  (portability_id, observed_at, revenue_kind, amount_rupees, owner_email, status, notes)
SELECT id, now() - interval '8 days',  'report_pack',       28000, 'data@equipseva.example', 'done', 'Monthly LIMS report pack'
  FROM public.equipment_data_portability_r2584 WHERE equipment_label='Aster Lab Auto-analyzer' LIMIT 1;

INSERT INTO public.portability_revenue_log_r2584
  (portability_id, observed_at, revenue_kind, amount_rupees, owner_email, status, notes)
SELECT id, now() - interval '45 days', 'data_subscription', 60000, 'data@equipseva.example', 'done', 'Apr DICOM subscription'
  FROM public.equipment_data_portability_r2584 WHERE equipment_label='Apollo Hyd CT-64 slice' LIMIT 1;

INSERT INTO public.portability_revenue_log_r2584
  (portability_id, observed_at, revenue_kind, amount_rupees, owner_email, status, notes)
SELECT id, now() - interval '3 days',  'training_credit',   15000, 'data@equipseva.example', 'open', 'MRI radiographer training credits'
  FROM public.equipment_data_portability_r2584 WHERE equipment_label='Medanta MRI 3T' LIMIT 1;

-- ============================================================
-- RPCS
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_portability_r2584()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  equipment_kind text,
  export_feasibility text,
  format_kind text,
  revenue_rupees bigint,
  dpdp_compliance text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.equipment_label, p.equipment_kind, p.export_feasibility,
         p.format_kind, p.revenue_rupees, p.dpdp_compliance,
         p.owner_email, p.status, p.notes, p.created_at
    FROM public.equipment_data_portability_r2584 p
   ORDER BY p.revenue_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_portability_r2584() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_portability_r2584() TO authenticated;


CREATE OR REPLACE FUNCTION public.list_revenue_log_r2584()
RETURNS TABLE (
  id uuid,
  portability_id uuid,
  equipment_label text,
  observed_at timestamptz,
  revenue_kind text,
  amount_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.portability_id, p.equipment_label,
         l.observed_at, l.revenue_kind, l.amount_rupees,
         l.owner_email, l.status, l.notes
    FROM public.portability_revenue_log_r2584 l
    JOIN public.equipment_data_portability_r2584 p ON p.id = l.portability_id
   ORDER BY l.observed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_revenue_log_r2584() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_revenue_log_r2584() TO authenticated;


CREATE OR REPLACE FUNCTION public.top_revenue_focus_r2584()
RETURNS TABLE (
  equipment_label text,
  equipment_kind text,
  export_feasibility text,
  format_kind text,
  revenue_rupees bigint,
  dpdp_compliance text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.equipment_label, p.equipment_kind, p.export_feasibility,
         p.format_kind, p.revenue_rupees, p.dpdp_compliance, p.status
    FROM public.equipment_data_portability_r2584 p
   ORDER BY p.revenue_rupees DESC NULLS LAST
   LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_revenue_focus_r2584() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_revenue_focus_r2584() TO authenticated;


CREATE OR REPLACE FUNCTION public.feasibility_distribution_r2584()
RETURNS TABLE (
  export_feasibility text,
  equipment_count bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.export_feasibility,
         count(*)::bigint,
         COALESCE(sum(p.revenue_rupees),0)::bigint
    FROM public.equipment_data_portability_r2584 p
   GROUP BY p.export_feasibility
   ORDER BY count(*) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.feasibility_distribution_r2584() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.feasibility_distribution_r2584() TO authenticated;


CREATE OR REPLACE FUNCTION public.format_kind_breakdown_r2584()
RETURNS TABLE (
  format_kind text,
  equipment_count bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.format_kind,
         count(*)::bigint,
         COALESCE(sum(p.revenue_rupees),0)::bigint
    FROM public.equipment_data_portability_r2584 p
   GROUP BY p.format_kind
   ORDER BY sum(p.revenue_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.format_kind_breakdown_r2584() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.format_kind_breakdown_r2584() TO authenticated;


CREATE OR REPLACE FUNCTION public.dpdp_compliance_summary_r2584()
RETURNS TABLE (
  dpdp_compliance text,
  equipment_count bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.dpdp_compliance,
         count(*)::bigint,
         COALESCE(sum(p.revenue_rupees),0)::bigint
    FROM public.equipment_data_portability_r2584 p
   GROUP BY p.dpdp_compliance
   ORDER BY count(*) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dpdp_compliance_summary_r2584() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dpdp_compliance_summary_r2584() TO authenticated;


CREATE OR REPLACE FUNCTION public.monthly_revenue_trend_r2584()
RETURNS TABLE (
  month_bucket text,
  log_count bigint,
  total_amount_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', l.observed_at), 'YYYY-MM') AS month_bucket,
         count(*)::bigint,
         COALESCE(sum(l.amount_rupees),0)::bigint
    FROM public.portability_revenue_log_r2584 l
   GROUP BY date_trunc('month', l.observed_at)
   ORDER BY date_trunc('month', l.observed_at) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_revenue_trend_r2584() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_revenue_trend_r2584() TO authenticated;

