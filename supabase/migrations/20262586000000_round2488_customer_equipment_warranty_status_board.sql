-- Round 2488: customer-equipment-warranty-status-board
-- Tables: customer_equipment_warranties_r2488, warranty_claim_decisions_r2488

BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_equipment_warranties_r2488 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_model text,
  warranty_start_date date NOT NULL,
  warranty_end_date date NOT NULL,
  oem_name text,
  oem_responsibility_kind text NOT NULL CHECK (oem_responsibility_kind IN ('parts_only','parts_labor','replacement','no_coverage')),
  days_until_expiry int,
  status text NOT NULL CHECK (status IN ('active','expiring_60d','expiring_30d','expired','lapsed')),
  renewal_quote_rupees bigint,
  renewal_decision text CHECK (renewal_decision IN ('renewing','dropping','negotiating','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.warranty_claim_decisions_r2488 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warranty_id uuid REFERENCES public.customer_equipment_warranties_r2488(id) ON DELETE CASCADE,
  claim_filed_at timestamptz NOT NULL DEFAULT now(),
  claim_kind text NOT NULL CHECK (claim_kind IN ('parts','labor','replacement','calibration')),
  oem_decision_at timestamptz,
  oem_decision text NOT NULL CHECK (oem_decision IN ('approved','denied','escalated','pending')),
  claim_value_rupees bigint,
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','closed','disputed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_equipment_warranties_r2488 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warranty_claim_decisions_r2488 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_equipment_warranties_r2488;
CREATE POLICY founder_all ON public.customer_equipment_warranties_r2488
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.warranty_claim_decisions_r2488;
CREATE POLICY founder_all ON public.warranty_claim_decisions_r2488
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ----- RPC 1: list_warranties_r2488 -----
CREATE OR REPLACE FUNCTION public.list_warranties_r2488()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  equipment_model text,
  warranty_start_date date,
  warranty_end_date date,
  oem_name text,
  oem_responsibility_kind text,
  days_until_expiry int,
  status text,
  renewal_quote_rupees bigint,
  renewal_decision text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT w.id, w.equipment_label, w.equipment_model, w.warranty_start_date, w.warranty_end_date,
           w.oem_name, w.oem_responsibility_kind, w.days_until_expiry, w.status,
           w.renewal_quote_rupees, w.renewal_decision, w.notes, w.created_at
    FROM public.customer_equipment_warranties_r2488 w
    ORDER BY w.warranty_end_date ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_warranties_r2488() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_warranties_r2488() TO authenticated;

-- ----- RPC 2: list_claim_decisions_r2488 -----
CREATE OR REPLACE FUNCTION public.list_claim_decisions_r2488()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  claim_filed_at timestamptz,
  claim_kind text,
  oem_decision_at timestamptz,
  oem_decision text,
  claim_value_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, w.equipment_label, c.claim_filed_at, c.claim_kind, c.oem_decision_at,
           c.oem_decision, c.claim_value_rupees, c.owner_email, c.status, c.notes
    FROM public.warranty_claim_decisions_r2488 c
    LEFT JOIN public.customer_equipment_warranties_r2488 w ON w.id = c.warranty_id
    ORDER BY c.claim_filed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_claim_decisions_r2488() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_claim_decisions_r2488() TO authenticated;

-- ----- RPC 3: expiring_60d_r2488 -----
CREATE OR REPLACE FUNCTION public.expiring_60d_r2488()
RETURNS TABLE (
  equipment_label text,
  oem_name text,
  warranty_end_date date,
  days_until_expiry int,
  status text,
  renewal_quote_rupees bigint,
  renewal_decision text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT w.equipment_label, w.oem_name, w.warranty_end_date, w.days_until_expiry,
           w.status, w.renewal_quote_rupees, w.renewal_decision
    FROM public.customer_equipment_warranties_r2488 w
    WHERE w.status IN ('expiring_60d','expiring_30d')
       OR (w.days_until_expiry IS NOT NULL AND w.days_until_expiry <= 60 AND w.days_until_expiry >= 0)
    ORDER BY w.days_until_expiry ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.expiring_60d_r2488() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_60d_r2488() TO authenticated;

-- ----- RPC 4: top_renewal_decisions_r2488 -----
CREATE OR REPLACE FUNCTION public.top_renewal_decisions_r2488()
RETURNS TABLE (
  renewal_decision text,
  warranty_count bigint,
  total_quote_rupees bigint,
  avg_quote_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(w.renewal_decision,'undecided')::text AS renewal_decision,
           COUNT(*)::bigint AS warranty_count,
           COALESCE(SUM(w.renewal_quote_rupees),0)::bigint AS total_quote_rupees,
           COALESCE(AVG(w.renewal_quote_rupees),0)::bigint AS avg_quote_rupees
    FROM public.customer_equipment_warranties_r2488 w
    GROUP BY COALESCE(w.renewal_decision,'undecided')
    ORDER BY total_quote_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_renewal_decisions_r2488() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_renewal_decisions_r2488() TO authenticated;

-- ----- RPC 5: oem_breakdown_r2488 -----
CREATE OR REPLACE FUNCTION public.oem_breakdown_r2488()
RETURNS TABLE (
  oem_name text,
  warranty_count bigint,
  active_count bigint,
  expired_or_lapsed_count bigint,
  avg_days_until_expiry numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(w.oem_name,'unknown')::text AS oem_name,
           COUNT(*)::bigint AS warranty_count,
           COUNT(*) FILTER (WHERE w.status='active')::bigint AS active_count,
           COUNT(*) FILTER (WHERE w.status IN ('expired','lapsed'))::bigint AS expired_or_lapsed_count,
           COALESCE(AVG(w.days_until_expiry),0)::numeric AS avg_days_until_expiry
    FROM public.customer_equipment_warranties_r2488 w
    GROUP BY COALESCE(w.oem_name,'unknown')
    ORDER BY warranty_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.oem_breakdown_r2488() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.oem_breakdown_r2488() TO authenticated;

-- ----- RPC 6: claim_outcome_summary_r2488 -----
CREATE OR REPLACE FUNCTION public.claim_outcome_summary_r2488()
RETURNS TABLE (
  oem_decision text,
  claim_count bigint,
  total_claim_value_rupees bigint,
  open_count bigint,
  closed_count bigint,
  disputed_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.oem_decision,
           COUNT(*)::bigint AS claim_count,
           COALESCE(SUM(c.claim_value_rupees),0)::bigint AS total_claim_value_rupees,
           COUNT(*) FILTER (WHERE c.status='open')::bigint AS open_count,
           COUNT(*) FILTER (WHERE c.status='closed')::bigint AS closed_count,
           COUNT(*) FILTER (WHERE c.status='disputed')::bigint AS disputed_count
    FROM public.warranty_claim_decisions_r2488 c
    GROUP BY c.oem_decision
    ORDER BY claim_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.claim_outcome_summary_r2488() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_outcome_summary_r2488() TO authenticated;

-- ----- RPC 7: lapsed_warranty_focus_r2488 -----
CREATE OR REPLACE FUNCTION public.lapsed_warranty_focus_r2488()
RETURNS TABLE (
  equipment_label text,
  equipment_model text,
  oem_name text,
  warranty_end_date date,
  status text,
  days_until_expiry int,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT w.equipment_label, w.equipment_model, w.oem_name, w.warranty_end_date,
           w.status, w.days_until_expiry, w.notes
    FROM public.customer_equipment_warranties_r2488 w
    WHERE w.status IN ('expired','lapsed')
    ORDER BY w.warranty_end_date DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.lapsed_warranty_focus_r2488() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lapsed_warranty_focus_r2488() TO authenticated;

-- ----- Seed: warranties -----
INSERT INTO public.customer_equipment_warranties_r2488
  (equipment_label, equipment_model, warranty_start_date, warranty_end_date, oem_name, oem_responsibility_kind, days_until_expiry, status, renewal_quote_rupees, renewal_decision, notes)
VALUES
  ('Ultrasound Cart A','GE Voluson E10','2025-01-15','2026-08-15','GE Healthcare','parts_labor', 53,'expiring_60d', 480000,'negotiating','Negotiating annual renewal; OEM offered 5% off'),
  ('Endoscope Tower','Olympus EVIS X1','2024-06-01','2026-06-30','Olympus','parts_only', 7,'expiring_30d', 320000,'renewing','Renewal sign-off pending hospital CFO'),
  ('MRI 1.5T','Siemens Magnetom','2023-04-10','2026-04-10','Siemens Healthineers','replacement', -74,'expired', 1800000,'dropping','Dropped — moved to in-house engineer support'),
  ('CT Scanner','Philips Brilliance','2024-09-01','2027-09-01','Philips','parts_labor', 802,'active', NULL, NULL,'Under active OEM AMC'),
  ('Patient Monitor x6','Mindray BeneVision N17','2023-12-01','2025-12-01','Mindray','no_coverage', -204,'lapsed', 90000,'dropped','Lapsed > 6 months; OEM refusing reinstatement');

-- ----- Seed: claim decisions -----
INSERT INTO public.warranty_claim_decisions_r2488
  (warranty_id, claim_filed_at, claim_kind, oem_decision_at, oem_decision, claim_value_rupees, owner_email, status, notes)
SELECT id, now() - interval '12 days','parts', now() - interval '5 days','approved', 145000,'biomed@hospital.in','closed','OEM shipped replacement transducer head'
FROM public.customer_equipment_warranties_r2488 WHERE equipment_label='Ultrasound Cart A' LIMIT 1;

INSERT INTO public.warranty_claim_decisions_r2488
  (warranty_id, claim_filed_at, claim_kind, oem_decision_at, oem_decision, claim_value_rupees, owner_email, status, notes)
SELECT id, now() - interval '6 days','calibration', NULL,'pending', 60000,'biomed@hospital.in','open','Scope calibration request — OEM SLA 7 business days'
FROM public.customer_equipment_warranties_r2488 WHERE equipment_label='Endoscope Tower' LIMIT 1;

INSERT INTO public.warranty_claim_decisions_r2488
  (warranty_id, claim_filed_at, claim_kind, oem_decision_at, oem_decision, claim_value_rupees, owner_email, status, notes)
SELECT id, now() - interval '90 days','replacement', now() - interval '70 days','denied', 1200000,'cfo@hospital.in','disputed','OEM denied citing expired contract; escalated to legal'
FROM public.customer_equipment_warranties_r2488 WHERE equipment_label='MRI 1.5T' LIMIT 1;

INSERT INTO public.warranty_claim_decisions_r2488
  (warranty_id, claim_filed_at, claim_kind, oem_decision_at, oem_decision, claim_value_rupees, owner_email, status, notes)
SELECT id, now() - interval '40 days','labor', now() - interval '30 days','approved', 75000,'biomed@hospital.in','closed','Tube head replacement labor covered'
FROM public.customer_equipment_warranties_r2488 WHERE equipment_label='CT Scanner' LIMIT 1;

INSERT INTO public.warranty_claim_decisions_r2488
  (warranty_id, claim_filed_at, claim_kind, oem_decision_at, oem_decision, claim_value_rupees, owner_email, status, notes)
SELECT id, now() - interval '20 days','parts', now() - interval '10 days','escalated', 35000,'biomed@hospital.in','open','OEM escalated to regional service head; awaiting visit'
FROM public.customer_equipment_warranties_r2488 WHERE equipment_label='Patient Monitor x6' LIMIT 1;

