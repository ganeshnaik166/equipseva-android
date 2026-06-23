-- Round r2424: customer-warranty-claim-pipeline
-- claim × kind × status × approve/deny × refund × supplier liability

BEGIN;

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.warranty_claims_r2424 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  claim_external_ref text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_serial text,
  claim_kind text NOT NULL CHECK (claim_kind IN (
    'defective_part','workmanship','extended_warranty','recall','calibration_drift'
  )),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  decision_status text NOT NULL CHECK (decision_status IN (
    'pending','approved','denied','escalated','refunded'
  )),
  decision_at timestamptz,
  decision_owner_email text,
  refund_amount_rupees integer NOT NULL DEFAULT 0 CHECK (refund_amount_rupees >= 0),
  supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  supplier_liability_pct numeric(5,2) CHECK (supplier_liability_pct IS NULL OR (supplier_liability_pct >= 0 AND supplier_liability_pct <= 100)),
  notes text
);

CREATE TABLE IF NOT EXISTS public.warranty_supplier_liability_r2424 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  supplier_name text NOT NULL,
  claims_30d integer NOT NULL DEFAULT 0 CHECK (claims_30d >= 0),
  approved_30d integer NOT NULL DEFAULT 0 CHECK (approved_30d >= 0),
  denied_30d integer NOT NULL DEFAULT 0 CHECK (denied_30d >= 0),
  total_refund_owed_rupees bigint NOT NULL DEFAULT 0 CHECK (total_refund_owed_rupees >= 0),
  total_refund_paid_rupees bigint NOT NULL DEFAULT 0 CHECK (total_refund_paid_rupees >= 0),
  avg_decision_hours numeric(8,2) CHECK (avg_decision_hours IS NULL OR avg_decision_hours >= 0),
  last_claim_at timestamptz,
  notes text
);

ALTER TABLE public.warranty_claims_r2424 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warranty_supplier_liability_r2424 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.warranty_claims_r2424;
CREATE POLICY founder_all ON public.warranty_claims_r2424
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.warranty_supplier_liability_r2424;
CREATE POLICY founder_all ON public.warranty_supplier_liability_r2424
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- Seeds
-- ============================================================

INSERT INTO public.warranty_claims_r2424 (
  claim_external_ref, equipment_label, equipment_serial, claim_kind,
  submitted_at, decision_status, decision_at, decision_owner_email,
  refund_amount_rupees, supplier_liability_pct, notes
) VALUES
  ('WC-2024-0815-A','Philips MX450 Monitor','MX450-2231','defective_part',
    now() - interval '28 days','refunded', now() - interval '20 days','founder@equipseva.in',
    45000, 100.00,'screen module DOA replaced + supplier billed'),
  ('WC-2024-0902-B','GE Logiq P9 Ultrasound','LP9-7781','workmanship',
    now() - interval '20 days','approved', now() - interval '14 days','founder@equipseva.in',
    18000, 80.00,'transducer cable rework approved'),
  ('WC-2024-0910-C','Drager Fabius GS Anesthesia','FAB-3398','calibration_drift',
    now() - interval '14 days','escalated', now() - interval '8 days','founder@equipseva.in',
    0, 50.00,'OEM dispute over drift threshold; escalated to legal'),
  ('WC-2024-0915-D','Mindray BeneVision N15','N15-5510','recall',
    now() - interval '9 days','approved', now() - interval '3 days','founder@equipseva.in',
    62000, 100.00,'mandatory recall bulletin issued by OEM'),
  ('WC-2024-0918-E','Siemens Atellica CH','ATC-1129','extended_warranty',
    now() - interval '4 days','pending', null, null,
    0, null,'awaiting service ledger pull');

INSERT INTO public.warranty_supplier_liability_r2424 (
  supplier_name, claims_30d, approved_30d, denied_30d,
  total_refund_owed_rupees, total_refund_paid_rupees, avg_decision_hours, last_claim_at, notes
) VALUES
  ('Philips Healthcare India', 6, 5, 0, 240000, 195000, 96.5, now() - interval '2 days','reliable but slow paperwork'),
  ('GE Healthcare India', 4, 3, 1, 145000, 118000, 142.2, now() - interval '5 days','transducer batch flagged'),
  ('Drager India', 2, 0, 0, 0, 0, 198.0, now() - interval '8 days','escalation pending'),
  ('Mindray Medical India', 3, 3, 0, 186000, 124000, 72.4, now() - interval '3 days','responsive recall handling'),
  ('Siemens Healthineers', 1, 0, 0, 0, 0, null, now() - interval '4 days','no decisions yet');

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_claims_r2424()
RETURNS TABLE(
  id uuid,
  claim_external_ref text,
  equipment_label text,
  equipment_serial text,
  claim_kind text,
  submitted_at timestamptz,
  decision_status text,
  decision_at timestamptz,
  decision_owner_email text,
  refund_amount_rupees integer,
  supplier_liability_pct numeric,
  hours_to_decision numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.claim_external_ref, c.equipment_label, c.equipment_serial,
           c.claim_kind, c.submitted_at, c.decision_status, c.decision_at,
           c.decision_owner_email, c.refund_amount_rupees, c.supplier_liability_pct,
           CASE WHEN c.decision_at IS NULL THEN null::numeric
                ELSE round(extract(epoch FROM (c.decision_at - c.submitted_at))/3600.0, 2)
           END AS hours_to_decision,
           c.notes
      FROM public.warranty_claims_r2424 c
     ORDER BY c.submitted_at DESC
     LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_claims_r2424() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_claims_r2424() TO authenticated;

CREATE OR REPLACE FUNCTION public.supplier_liability_r2424()
RETURNS TABLE(
  supplier_name text,
  claims_30d integer,
  approved_30d integer,
  denied_30d integer,
  total_refund_owed_rupees bigint,
  total_refund_paid_rupees bigint,
  unpaid_rupees bigint,
  avg_decision_hours numeric,
  last_claim_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.supplier_name, s.claims_30d, s.approved_30d, s.denied_30d,
           s.total_refund_owed_rupees, s.total_refund_paid_rupees,
           (s.total_refund_owed_rupees - s.total_refund_paid_rupees) AS unpaid_rupees,
           s.avg_decision_hours, s.last_claim_at, s.notes
      FROM public.warranty_supplier_liability_r2424 s
     ORDER BY (s.total_refund_owed_rupees - s.total_refund_paid_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.supplier_liability_r2424() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supplier_liability_r2424() TO authenticated;

CREATE OR REPLACE FUNCTION public.decision_funnel_r2424()
RETURNS TABLE(
  decision_status text,
  claim_count bigint,
  refund_total_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.decision_status,
           count(*)::bigint AS claim_count,
           coalesce(sum(c.refund_amount_rupees),0)::bigint AS refund_total_rupees
      FROM public.warranty_claims_r2424 c
     GROUP BY c.decision_status
     ORDER BY claim_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.decision_funnel_r2424() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_funnel_r2424() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_offending_suppliers_r2424()
RETURNS TABLE(
  supplier_name text,
  claims_30d integer,
  approved_30d integer,
  unpaid_rupees bigint,
  avg_decision_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.supplier_name, s.claims_30d, s.approved_30d,
           (s.total_refund_owed_rupees - s.total_refund_paid_rupees) AS unpaid_rupees,
           s.avg_decision_hours
      FROM public.warranty_supplier_liability_r2424 s
     ORDER BY s.claims_30d DESC, unpaid_rupees DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_offending_suppliers_r2424() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_offending_suppliers_r2424() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_claim_trend_r2424()
RETURNS TABLE(
  month_start date,
  claims bigint,
  approved bigint,
  denied bigint,
  refunded_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', c.submitted_at)::date AS month_start,
           count(*)::bigint AS claims,
           count(*) FILTER (WHERE c.decision_status IN ('approved','refunded'))::bigint AS approved,
           count(*) FILTER (WHERE c.decision_status = 'denied')::bigint AS denied,
           coalesce(sum(c.refund_amount_rupees) FILTER (WHERE c.decision_status = 'refunded'),0)::bigint AS refunded_rupees
      FROM public.warranty_claims_r2424 c
     GROUP BY 1
     ORDER BY 1 DESC
     LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_claim_trend_r2424() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_claim_trend_r2424() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_impacted_hospitals_r2424()
RETURNS TABLE(
  hospital_label text,
  claims bigint,
  refunded_rupees bigint,
  last_claim_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT coalesce(p.full_name, 'Unassigned hospital')::text AS hospital_label,
           count(*)::bigint AS claims,
           coalesce(sum(c.refund_amount_rupees),0)::bigint AS refunded_rupees,
           max(c.submitted_at) AS last_claim_at
      FROM public.warranty_claims_r2424 c
      LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
     GROUP BY 1
     ORDER BY claims DESC, refunded_rupees DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_impacted_hospitals_r2424() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_impacted_hospitals_r2424() TO authenticated;

CREATE OR REPLACE FUNCTION public.escalated_claims_r2424()
RETURNS TABLE(
  id uuid,
  claim_external_ref text,
  equipment_label text,
  claim_kind text,
  submitted_at timestamptz,
  hours_open numeric,
  refund_amount_rupees integer,
  supplier_liability_pct numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.claim_external_ref, c.equipment_label, c.claim_kind,
           c.submitted_at,
           round(extract(epoch FROM (now() - c.submitted_at))/3600.0, 2) AS hours_open,
           c.refund_amount_rupees, c.supplier_liability_pct, c.notes
      FROM public.warranty_claims_r2424 c
     WHERE c.decision_status = 'escalated'
        OR (c.decision_status = 'pending' AND c.submitted_at < now() - interval '7 days')
     ORDER BY c.submitted_at ASC
     LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.escalated_claims_r2424() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escalated_claims_r2424() TO authenticated;

