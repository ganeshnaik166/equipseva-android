-- Round 2604: customer-monthly-billing-anomaly-detection
-- hospital × invoice × anomaly kind × severity × dispute risk × auto-correction

CREATE TABLE IF NOT EXISTS public.customer_billing_anomalies_r2604 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  invoice_external_ref text NOT NULL,
  detected_at timestamptz NOT NULL DEFAULT now(),
  anomaly_kind text NOT NULL CHECK (anomaly_kind IN ('duplicate_line','wrong_tax','missing_discount','over_charge','under_charge')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  dispute_risk_kind text NOT NULL CHECK (dispute_risk_kind IN ('low','medium','high','critical')),
  auto_correction_applied boolean NOT NULL DEFAULT false,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','under_review','corrected','disputed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.billing_correction_actions_r2604 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anomaly_id uuid NOT NULL REFERENCES public.customer_billing_anomalies_r2604(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('reissue','credit_note','refund','escalation','manual_adjust')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_billing_anomalies_r2604 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_correction_actions_r2604 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_billing_anomalies_r2604;
CREATE POLICY founder_all ON public.customer_billing_anomalies_r2604
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.billing_correction_actions_r2604;
CREATE POLICY founder_all ON public.billing_correction_actions_r2604
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed anomalies
INSERT INTO public.customer_billing_anomalies_r2604 (hospital_user_id, invoice_external_ref, detected_at, anomaly_kind, severity, dispute_risk_kind, auto_correction_applied, owner_email, status, notes)
VALUES
  (NULL, 'INV-2026-06-1001', now() - interval '12 days', 'duplicate_line', 'high', 'high', false, 'billing@equipseva.in', 'under_review', 'Two identical service line items on same invoice'),
  (NULL, 'INV-2026-06-1014', now() - interval '9 days',  'wrong_tax',      'critical','critical', false, 'billing@equipseva.in', 'disputed',     'GST applied at 18 percent instead of 12 percent'),
  (NULL, 'INV-2026-06-1027', now() - interval '7 days',  'missing_discount','medium','medium', true,  'ops@equipseva.in',     'corrected',    'AMC discount auto-applied via correction job'),
  (NULL, 'INV-2026-06-1042', now() - interval '4 days',  'over_charge',    'high', 'high', false, 'billing@equipseva.in', 'open',         'Spare-part priced above contract rate'),
  (NULL, 'INV-2026-06-1058', now() - interval '2 days',  'under_charge',   'low',  'low',  true,  'ops@equipseva.in',     'corrected',    'Auto-corrected by reissue cron');

-- Seed correction actions tied to first anomaly
INSERT INTO public.billing_correction_actions_r2604 (anomaly_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '11 days', 'credit_note', 'positive', 'billing@equipseva.in', 'done', 'Credit note issued for duplicate line'
  FROM public.customer_billing_anomalies_r2604 WHERE invoice_external_ref = 'INV-2026-06-1001' LIMIT 1;

INSERT INTO public.billing_correction_actions_r2604 (anomaly_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '8 days', 'escalation', 'pending', 'founder@equipseva.in', 'open', 'Escalated to finance lead for GST recompute'
  FROM public.customer_billing_anomalies_r2604 WHERE invoice_external_ref = 'INV-2026-06-1014' LIMIT 1;

INSERT INTO public.billing_correction_actions_r2604 (anomaly_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '6 days', 'reissue', 'positive', 'ops@equipseva.in', 'done', 'Reissued invoice with AMC discount line'
  FROM public.customer_billing_anomalies_r2604 WHERE invoice_external_ref = 'INV-2026-06-1027' LIMIT 1;

INSERT INTO public.billing_correction_actions_r2604 (anomaly_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '3 days', 'manual_adjust', 'neutral', 'billing@equipseva.in', 'open', 'Manual recompute requested, awaiting supplier confirm'
  FROM public.customer_billing_anomalies_r2604 WHERE invoice_external_ref = 'INV-2026-06-1042' LIMIT 1;

INSERT INTO public.billing_correction_actions_r2604 (anomaly_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '1 days', 'refund', 'positive', 'ops@equipseva.in', 'done', 'Underbilled top-up refunded to customer wallet'
  FROM public.customer_billing_anomalies_r2604 WHERE invoice_external_ref = 'INV-2026-06-1058' LIMIT 1;

-- RPC 1: list_anomalies_r2604
CREATE OR REPLACE FUNCTION public.list_anomalies_r2604()
RETURNS TABLE (
  id uuid,
  invoice_external_ref text,
  detected_at timestamptz,
  anomaly_kind text,
  severity text,
  dispute_risk_kind text,
  auto_correction_applied boolean,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.invoice_external_ref, a.detected_at, a.anomaly_kind, a.severity,
         a.dispute_risk_kind, a.auto_correction_applied, a.owner_email, a.status, a.notes
    FROM public.customer_billing_anomalies_r2604 a
   ORDER BY a.detected_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_anomalies_r2604() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_anomalies_r2604() TO authenticated;

-- RPC 2: list_correction_actions_r2604
CREATE OR REPLACE FUNCTION public.list_correction_actions_r2604()
RETURNS TABLE (
  id uuid,
  anomaly_id uuid,
  invoice_external_ref text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.anomaly_id, a.invoice_external_ref, c.action_at, c.action_kind,
         c.outcome, c.owner_email, c.status, c.notes
    FROM public.billing_correction_actions_r2604 c
    LEFT JOIN public.customer_billing_anomalies_r2604 a ON a.id = c.anomaly_id
   ORDER BY c.action_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_correction_actions_r2604() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_correction_actions_r2604() TO authenticated;

-- RPC 3: top_dispute_risk_focus_r2604
CREATE OR REPLACE FUNCTION public.top_dispute_risk_focus_r2604()
RETURNS TABLE (
  id uuid,
  invoice_external_ref text,
  anomaly_kind text,
  severity text,
  dispute_risk_kind text,
  status text,
  detected_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.invoice_external_ref, a.anomaly_kind, a.severity, a.dispute_risk_kind, a.status, a.detected_at
    FROM public.customer_billing_anomalies_r2604 a
   WHERE a.dispute_risk_kind IN ('high','critical')
     AND a.status IN ('open','under_review','disputed')
   ORDER BY CASE a.dispute_risk_kind WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END ASC,
            a.detected_at DESC NULLS LAST
   LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_dispute_risk_focus_r2604() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.top_dispute_risk_focus_r2604() TO authenticated;

-- RPC 4: anomaly_kind_breakdown_r2604
CREATE OR REPLACE FUNCTION public.anomaly_kind_breakdown_r2604()
RETURNS TABLE (
  anomaly_kind text,
  total_count bigint,
  critical_count bigint,
  auto_corrected_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.anomaly_kind,
         count(*)::bigint AS total_count,
         count(*) FILTER (WHERE a.severity = 'critical')::bigint AS critical_count,
         count(*) FILTER (WHERE a.auto_correction_applied)::bigint AS auto_corrected_count
    FROM public.customer_billing_anomalies_r2604 a
   GROUP BY a.anomaly_kind
   ORDER BY total_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.anomaly_kind_breakdown_r2604() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.anomaly_kind_breakdown_r2604() TO authenticated;

-- RPC 5: auto_correction_rate_r2604
CREATE OR REPLACE FUNCTION public.auto_correction_rate_r2604()
RETURNS TABLE (
  total_anomalies bigint,
  auto_corrected bigint,
  auto_correction_pct numeric,
  manual_required bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint AS total_anomalies,
         count(*) FILTER (WHERE a.auto_correction_applied)::bigint AS auto_corrected,
         CASE WHEN count(*) = 0 THEN 0
              ELSE round(100.0 * count(*) FILTER (WHERE a.auto_correction_applied)::numeric / count(*)::numeric, 1)
         END AS auto_correction_pct,
         count(*) FILTER (WHERE NOT a.auto_correction_applied)::bigint AS manual_required
    FROM public.customer_billing_anomalies_r2604 a;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.auto_correction_rate_r2604() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.auto_correction_rate_r2604() TO authenticated;

-- RPC 6: monthly_anomaly_trend_r2604
CREATE OR REPLACE FUNCTION public.monthly_anomaly_trend_r2604()
RETURNS TABLE (
  month_label text,
  total_count bigint,
  critical_count bigint,
  auto_corrected_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', a.detected_at), 'YYYY-MM') AS month_label,
         count(*)::bigint AS total_count,
         count(*) FILTER (WHERE a.severity = 'critical')::bigint AS critical_count,
         count(*) FILTER (WHERE a.auto_correction_applied)::bigint AS auto_corrected_count
    FROM public.customer_billing_anomalies_r2604 a
   GROUP BY date_trunc('month', a.detected_at)
   ORDER BY date_trunc('month', a.detected_at) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_anomaly_trend_r2604() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.monthly_anomaly_trend_r2604() TO authenticated;

-- RPC 7: top_impacted_hospitals_r2604
CREATE OR REPLACE FUNCTION public.top_impacted_hospitals_r2604()
RETURNS TABLE (
  hospital_email text,
  anomaly_count bigint,
  critical_count bigint,
  disputed_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(p.email, 'unassigned') AS hospital_email,
         count(*)::bigint AS anomaly_count,
         count(*) FILTER (WHERE a.severity = 'critical')::bigint AS critical_count,
         count(*) FILTER (WHERE a.status = 'disputed')::bigint AS disputed_count
    FROM public.customer_billing_anomalies_r2604 a
    LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
   GROUP BY COALESCE(p.email, 'unassigned')
   ORDER BY anomaly_count DESC NULLS LAST
   LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_impacted_hospitals_r2604() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.top_impacted_hospitals_r2604() TO authenticated;
