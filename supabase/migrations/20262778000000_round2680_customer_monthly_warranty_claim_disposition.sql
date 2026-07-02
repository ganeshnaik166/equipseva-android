BEGIN;

-- =====================================================================
-- Round 2680: Customer monthly warranty claim disposition
-- Equipment x claim kind x OEM covered x our covered x dispute x outcome
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: claim ledger
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS public.warranty_claim_disposition_r2680 CASCADE;
CREATE TABLE public.warranty_claim_disposition_r2680 (
  id              bigserial PRIMARY KEY,
  claim_code      text NOT NULL UNIQUE,
  month_label     text NOT NULL,
  equipment_kind  text NOT NULL CHECK (equipment_kind IN ('dental_chair','xray','autoclave','ultrasound','ecg','suction','centrifuge','monitor')),
  customer_org    text NOT NULL,
  claim_kind      text NOT NULL CHECK (claim_kind IN ('parts','labour','full_unit','transit','accidental','wear_tear')),
  oem_covered_rs  numeric(12,2) NOT NULL DEFAULT 0 CHECK (oem_covered_rs >= 0),
  our_covered_rs  numeric(12,2) NOT NULL DEFAULT 0 CHECK (our_covered_rs >= 0),
  total_claim_rs  numeric(12,2) NOT NULL CHECK (total_claim_rs >= 0),
  dispute_state   text NOT NULL CHECK (dispute_state IN ('none','customer_open','oem_open','resolved','escalated')),
  outcome         text NOT NULL CHECK (outcome IN ('approved','partial','rejected','pending','withdrawn')),
  resolution_days int NOT NULL DEFAULT 0 CHECK (resolution_days >= 0),
  filed_at        timestamptz NOT NULL DEFAULT now(),
  closed_at       timestamptz
);

ALTER TABLE public.warranty_claim_disposition_r2680 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.warranty_claim_disposition_r2680;
CREATE POLICY founder_all ON public.warranty_claim_disposition_r2680
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.warranty_claim_disposition_r2680
  (claim_code, month_label, equipment_kind, customer_org, claim_kind, oem_covered_rs, our_covered_rs, total_claim_rs, dispute_state, outcome, resolution_days, filed_at, closed_at)
VALUES
  ('WC-2680-001','2026-05','dental_chair','Apollo Hyderabad','parts',18000.00,4500.00,22500.00,'none','approved',4,now() - interval '38 days', now() - interval '34 days'),
  ('WC-2680-002','2026-05','xray','KIMS Secunderabad','labour',0.00,8200.00,8200.00,'customer_open','partial',9,now() - interval '34 days', now() - interval '25 days'),
  ('WC-2680-003','2026-05','autoclave','Yashoda Somajiguda','full_unit',62000.00,12000.00,74000.00,'oem_open','approved',12,now() - interval '32 days', now() - interval '20 days'),
  ('WC-2680-004','2026-06','ultrasound','Continental Gachibowli','transit',0.00,15000.00,15000.00,'resolved','approved',3,now() - interval '20 days', now() - interval '17 days'),
  ('WC-2680-005','2026-06','ecg','Sunshine Paradise','accidental',0.00,0.00,3200.00,'escalated','rejected',7,now() - interval '14 days', now() - interval '7 days'),
  ('WC-2680-006','2026-06','suction','Care Banjara','wear_tear',2400.00,1200.00,3600.00,'none','approved',2,now() - interval '12 days', now() - interval '10 days'),
  ('WC-2680-007','2026-06','centrifuge','Rainbow Vikrampuri','parts',8500.00,0.00,8500.00,'customer_open','pending',5,now() - interval '6 days', NULL),
  ('WC-2680-008','2026-06','monitor','Medicover HiTec','labour',0.00,5500.00,5500.00,'none','withdrawn',1,now() - interval '4 days', now() - interval '3 days');

-- ---------------------------------------------------------------------
-- Table 2: dispute notes
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS public.warranty_claim_dispute_notes_r2680 CASCADE;
CREATE TABLE public.warranty_claim_dispute_notes_r2680 (
  id            bigserial PRIMARY KEY,
  claim_id      bigint NOT NULL REFERENCES public.warranty_claim_disposition_r2680(id) ON DELETE CASCADE,
  note_kind     text NOT NULL CHECK (note_kind IN ('oem_response','customer_complaint','field_report','escalation','resolution')),
  severity      text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  note_body     text NOT NULL,
  author_role   text NOT NULL CHECK (author_role IN ('founder','ops','engineer','customer','oem')),
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.warranty_claim_dispute_notes_r2680 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.warranty_claim_dispute_notes_r2680;
CREATE POLICY founder_all ON public.warranty_claim_dispute_notes_r2680
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.warranty_claim_dispute_notes_r2680
  (claim_id, note_kind, severity, note_body, author_role)
VALUES
  (2,'customer_complaint','high','Customer says labour estimate was 2x quoted','customer'),
  (2,'oem_response','medium','OEM declined labour reimbursement per contract clause 4b','oem'),
  (3,'field_report','medium','Autoclave PCB confirmed dead on arrival; OEM approved swap','engineer'),
  (5,'escalation','critical','ECG dropped during transit; customer demands full refund','customer'),
  (5,'oem_response','high','OEM rejects accidental damage; outside warranty scope','oem'),
  (7,'field_report','low','Parts inbound from Mumbai warehouse; ETA 3 days','ops'),
  (8,'resolution','low','Customer withdrew claim after re-test passed','founder');

-- ---------------------------------------------------------------------
-- RPC 1: month rollup
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2680_month_rollup();
CREATE OR REPLACE FUNCTION public.r2680_month_rollup()
RETURNS TABLE (
  month_label text,
  claims int,
  oem_total numeric,
  our_total numeric,
  gross_total numeric,
  approved_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.month_label,
    COUNT(*)::int,
    COALESCE(SUM(w.oem_covered_rs),0),
    COALESCE(SUM(w.our_covered_rs),0),
    COALESCE(SUM(w.total_claim_rs),0),
    ROUND(100.0 * SUM(CASE WHEN w.outcome = 'approved' THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 1)
  FROM public.warranty_claim_disposition_r2680 w
  GROUP BY w.month_label
  ORDER BY w.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2680_month_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2680_month_rollup() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: equipment breakdown
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2680_equipment_breakdown();
CREATE OR REPLACE FUNCTION public.r2680_equipment_breakdown()
RETURNS TABLE (
  equipment_kind text,
  claims int,
  total_rs numeric,
  avg_resolution_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.equipment_kind,
    COUNT(*)::int,
    COALESCE(SUM(w.total_claim_rs),0),
    ROUND(AVG(w.resolution_days)::numeric, 1)
  FROM public.warranty_claim_disposition_r2680 w
  GROUP BY w.equipment_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2680_equipment_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2680_equipment_breakdown() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: claim kind mix
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2680_claim_kind_mix();
CREATE OR REPLACE FUNCTION public.r2680_claim_kind_mix()
RETURNS TABLE (
  claim_kind text,
  claims int,
  oem_share numeric,
  our_share numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.claim_kind,
    COUNT(*)::int,
    COALESCE(SUM(w.oem_covered_rs),0),
    COALESCE(SUM(w.our_covered_rs),0)
  FROM public.warranty_claim_disposition_r2680 w
  GROUP BY w.claim_kind
  ORDER BY SUM(w.total_claim_rs) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2680_claim_kind_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2680_claim_kind_mix() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: dispute heatmap
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2680_dispute_heatmap();
CREATE OR REPLACE FUNCTION public.r2680_dispute_heatmap()
RETURNS TABLE (
  dispute_state text,
  claims int,
  open_amount_rs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.dispute_state,
    COUNT(*)::int,
    COALESCE(SUM(w.total_claim_rs),0)
  FROM public.warranty_claim_disposition_r2680 w
  GROUP BY w.dispute_state
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2680_dispute_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2680_dispute_heatmap() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: outcome funnel
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2680_outcome_funnel();
CREATE OR REPLACE FUNCTION public.r2680_outcome_funnel()
RETURNS TABLE (
  outcome text,
  claims int,
  amount_rs numeric,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total_claims int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_claims FROM public.warranty_claim_disposition_r2680;
  RETURN QUERY
  SELECT
    w.outcome,
    COUNT(*)::int,
    COALESCE(SUM(w.total_claim_rs),0),
    ROUND(100.0 * COUNT(*)::numeric / NULLIF(total_claims,0), 1)
  FROM public.warranty_claim_disposition_r2680 w
  GROUP BY w.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2680_outcome_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2680_outcome_funnel() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: open claims
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2680_open_claims();
CREATE OR REPLACE FUNCTION public.r2680_open_claims()
RETURNS TABLE (
  claim_code text,
  customer_org text,
  equipment_kind text,
  claim_kind text,
  dispute_state text,
  total_claim_rs numeric,
  filed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.claim_code,
    w.customer_org,
    w.equipment_kind,
    w.claim_kind,
    w.dispute_state,
    w.total_claim_rs,
    w.filed_at
  FROM public.warranty_claim_disposition_r2680 w
  WHERE w.outcome = 'pending' OR w.dispute_state IN ('customer_open','oem_open','escalated')
  ORDER BY w.filed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2680_open_claims() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2680_open_claims() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: recent dispute notes
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2680_recent_dispute_notes();
CREATE OR REPLACE FUNCTION public.r2680_recent_dispute_notes()
RETURNS TABLE (
  claim_code text,
  note_kind text,
  severity text,
  author_role text,
  note_body text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.claim_code,
    n.note_kind,
    n.severity,
    n.author_role,
    n.note_body,
    n.created_at
  FROM public.warranty_claim_dispute_notes_r2680 n
  JOIN public.warranty_claim_disposition_r2680 w ON w.id = n.claim_id
  ORDER BY n.created_at DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2680_recent_dispute_notes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2680_recent_dispute_notes() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 8: cost split summary
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2680_cost_split_summary();
CREATE OR REPLACE FUNCTION public.r2680_cost_split_summary()
RETURNS TABLE (
  metric text,
  value_rs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  oem_sum numeric;
  our_sum numeric;
  gross_sum numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT
    COALESCE(SUM(oem_covered_rs),0),
    COALESCE(SUM(our_covered_rs),0),
    COALESCE(SUM(total_claim_rs),0)
  INTO oem_sum, our_sum, gross_sum
  FROM public.warranty_claim_disposition_r2680;

  RETURN QUERY
  SELECT 'oem_covered_total'::text, oem_sum
  UNION ALL SELECT 'our_covered_total'::text, our_sum
  UNION ALL SELECT 'customer_borne_total'::text, GREATEST(gross_sum - oem_sum - our_sum, 0)
  UNION ALL SELECT 'gross_claims_total'::text, gross_sum;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2680_cost_split_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2680_cost_split_summary() TO authenticated;

COMMIT;
