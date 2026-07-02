-- Round 2536: customer-contract-renewal-discount-justification-ledger
-- Tables: customer_renewal_discounts_r2536, discount_decision_log_r2536
-- RPCs: list_renewal_discounts_r2536, list_decision_log_r2536, top_discount_focus_r2536,
--       reason_kind_breakdown_r2536, founder_approval_summary_r2536, monthly_discount_trend_r2536,
--       roi_distribution_r2536

BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_renewal_discounts_r2536 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  contract_external_ref text NOT NULL,
  renewal_at timestamptz,
  discount_asked_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (discount_asked_pct BETWEEN 0 AND 100),
  discount_given_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (discount_given_pct BETWEEN 0 AND 100),
  reason_kind text NOT NULL CHECK (reason_kind IN ('competitive_pressure','loyalty','volume','relationship','risk_offset','founder_judgement')),
  roi_estimate_rupees bigint NOT NULL DEFAULT 0,
  founder_approval_required boolean NOT NULL DEFAULT false,
  founder_approved boolean NOT NULL DEFAULT false,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','approved','rejected','withdrawn')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.discount_decision_log_r2536 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discount_id uuid NOT NULL REFERENCES public.customer_renewal_discounts_r2536(id) ON DELETE CASCADE,
  decision_at timestamptz NOT NULL DEFAULT now(),
  decision_kind text NOT NULL CHECK (decision_kind IN ('approve','reject','counter_offer','escalate')),
  decision_summary text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_renewal_discounts_r2536 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_decision_log_r2536 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_renewal_discounts_r2536;
CREATE POLICY founder_all ON public.customer_renewal_discounts_r2536
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.discount_decision_log_r2536;
CREATE POLICY founder_all ON public.discount_decision_log_r2536
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed discount rows
WITH d1 AS (
  INSERT INTO public.customer_renewal_discounts_r2536
    (contract_external_ref, renewal_at, discount_asked_pct, discount_given_pct, reason_kind,
     roi_estimate_rupees, founder_approval_required, founder_approved, owner_email, status, notes)
  VALUES
    ('CT-APOLLO-2026-04', '2026-04-15T00:00:00Z'::timestamptz, 18.00, 12.00, 'competitive_pressure',
     2400000, true, true, 'founder@equipseva.in', 'approved', 'Siemens undercut; held 12pct')
  RETURNING id
), d2 AS (
  INSERT INTO public.customer_renewal_discounts_r2536
    (contract_external_ref, renewal_at, discount_asked_pct, discount_given_pct, reason_kind,
     roi_estimate_rupees, founder_approval_required, founder_approved, owner_email, status, notes)
  VALUES
    ('CT-FORTIS-2026-05', '2026-05-20T00:00:00Z'::timestamptz, 10.00, 8.00, 'loyalty',
     1800000, false, false, 'sales@equipseva.in', 'approved', '3 year loyalty; small bump')
  RETURNING id
), d3 AS (
  INSERT INTO public.customer_renewal_discounts_r2536
    (contract_external_ref, renewal_at, discount_asked_pct, discount_given_pct, reason_kind,
     roi_estimate_rupees, founder_approval_required, founder_approved, owner_email, status, notes)
  VALUES
    ('CT-MAX-2026-06', '2026-06-10T00:00:00Z'::timestamptz, 22.00, 0.00, 'founder_judgement',
     0, true, false, 'founder@equipseva.in', 'rejected', 'Walked away; bad unit economics')
  RETURNING id
), d4 AS (
  INSERT INTO public.customer_renewal_discounts_r2536
    (contract_external_ref, renewal_at, discount_asked_pct, discount_given_pct, reason_kind,
     roi_estimate_rupees, founder_approval_required, founder_approved, owner_email, status, notes)
  VALUES
    ('CT-MEDANTA-2026-07', '2026-07-01T00:00:00Z'::timestamptz, 15.00, 10.00, 'volume',
     3200000, true, true, 'founder@equipseva.in', 'approved', '4 sites bundled; volume play')
  RETURNING id
), d5 AS (
  INSERT INTO public.customer_renewal_discounts_r2536
    (contract_external_ref, renewal_at, discount_asked_pct, discount_given_pct, reason_kind,
     roi_estimate_rupees, founder_approval_required, founder_approved, owner_email, status, notes)
  VALUES
    ('CT-NARAYANA-2026-07', '2026-07-15T00:00:00Z'::timestamptz, 12.00, 6.00, 'risk_offset',
     1100000, false, false, 'sales@equipseva.in', 'open', 'Risk-offset against late payments')
  RETURNING id
)
INSERT INTO public.discount_decision_log_r2536
  (discount_id, decision_at, decision_kind, decision_summary, owner_email, notes)
SELECT id, '2026-04-10T11:00:00Z'::timestamptz, 'counter_offer', 'Countered 18 with 12', 'founder@equipseva.in', 'phone call' FROM d1
UNION ALL
SELECT id, '2026-04-12T15:30:00Z'::timestamptz, 'approve', 'Approved at 12pct', 'founder@equipseva.in', 'closed' FROM d1
UNION ALL
SELECT id, '2026-05-18T09:00:00Z'::timestamptz, 'approve', 'Loyalty 8pct OK', 'sales@equipseva.in', 'auto-approved' FROM d2
UNION ALL
SELECT id, '2026-06-08T14:00:00Z'::timestamptz, 'escalate', 'Bad ROI; escalating', 'sales@equipseva.in', 'CFO review' FROM d3
UNION ALL
SELECT id, '2026-06-09T18:00:00Z'::timestamptz, 'reject', 'Walked away', 'founder@equipseva.in', 'no deal' FROM d3
UNION ALL
SELECT id, '2026-06-28T10:00:00Z'::timestamptz, 'counter_offer', 'Bundled 4 sites at 10pct', 'founder@equipseva.in', 'negotiation' FROM d4
UNION ALL
SELECT id, '2026-06-30T16:00:00Z'::timestamptz, 'approve', 'Volume deal approved', 'founder@equipseva.in', 'signed' FROM d4
UNION ALL
SELECT id, '2026-07-12T11:00:00Z'::timestamptz, 'counter_offer', 'Risk-offset 6pct on prompt-pay', 'sales@equipseva.in', 'pending' FROM d5;

CREATE OR REPLACE FUNCTION public.list_renewal_discounts_r2536()
RETURNS TABLE (id uuid, hospital_user_id uuid, contract_external_ref text, renewal_at timestamptz,
               discount_asked_pct numeric, discount_given_pct numeric, reason_kind text,
               roi_estimate_rupees bigint, founder_approval_required boolean, founder_approved boolean,
               status text, owner_email text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.hospital_user_id, d.contract_external_ref, d.renewal_at,
           d.discount_asked_pct, d.discount_given_pct, d.reason_kind,
           d.roi_estimate_rupees, d.founder_approval_required, d.founder_approved,
           d.status, d.owner_email, d.created_at
    FROM public.customer_renewal_discounts_r2536 d
    ORDER BY d.renewal_at DESC NULLS LAST, d.created_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_renewal_discounts_r2536() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_renewal_discounts_r2536() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_decision_log_r2536()
RETURNS TABLE (id uuid, discount_id uuid, decision_at timestamptz, decision_kind text,
               decision_summary text, owner_email text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.discount_id, l.decision_at, l.decision_kind,
           l.decision_summary, l.owner_email, l.notes
    FROM public.discount_decision_log_r2536 l
    ORDER BY l.decision_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_decision_log_r2536() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decision_log_r2536() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_discount_focus_r2536()
RETURNS TABLE (id uuid, contract_external_ref text, discount_asked_pct numeric, discount_given_pct numeric,
               reason_kind text, roi_estimate_rupees bigint, status text, renewal_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.contract_external_ref, d.discount_asked_pct, d.discount_given_pct,
           d.reason_kind, d.roi_estimate_rupees, d.status, d.renewal_at
    FROM public.customer_renewal_discounts_r2536 d
    ORDER BY d.discount_given_pct DESC, d.roi_estimate_rupees DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_discount_focus_r2536() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_discount_focus_r2536() TO authenticated;

CREATE OR REPLACE FUNCTION public.reason_kind_breakdown_r2536()
RETURNS TABLE (reason_kind text, cases_count bigint, avg_asked numeric, avg_given numeric, total_roi_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.reason_kind, count(*)::bigint,
           round(avg(d.discount_asked_pct)::numeric, 2),
           round(avg(d.discount_given_pct)::numeric, 2),
           coalesce(sum(d.roi_estimate_rupees), 0)::bigint
    FROM public.customer_renewal_discounts_r2536 d
    GROUP BY d.reason_kind
    ORDER BY count(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.reason_kind_breakdown_r2536() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reason_kind_breakdown_r2536() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_approval_summary_r2536()
RETURNS TABLE (total_required bigint, total_approved bigint, total_pending bigint,
               approved_avg_given numeric, approved_total_roi bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::bigint FROM public.customer_renewal_discounts_r2536 WHERE founder_approval_required),
      (SELECT count(*)::bigint FROM public.customer_renewal_discounts_r2536 WHERE founder_approval_required AND founder_approved),
      (SELECT count(*)::bigint FROM public.customer_renewal_discounts_r2536 WHERE founder_approval_required AND NOT founder_approved AND status = 'open'),
      (SELECT round(avg(discount_given_pct)::numeric, 2) FROM public.customer_renewal_discounts_r2536 WHERE founder_approved),
      (SELECT coalesce(sum(roi_estimate_rupees), 0)::bigint FROM public.customer_renewal_discounts_r2536 WHERE founder_approved);
END;$$;
REVOKE EXECUTE ON FUNCTION public.founder_approval_summary_r2536() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_approval_summary_r2536() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_discount_trend_r2536()
RETURNS TABLE (month_label text, cases_count bigint, avg_given numeric, total_roi_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(d.renewal_at, 'YYYY-MM') AS month_label,
           count(*)::bigint,
           round(avg(d.discount_given_pct)::numeric, 2),
           coalesce(sum(d.roi_estimate_rupees), 0)::bigint
    FROM public.customer_renewal_discounts_r2536 d
    WHERE d.renewal_at IS NOT NULL
    GROUP BY to_char(d.renewal_at, 'YYYY-MM')
    ORDER BY month_label ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_discount_trend_r2536() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_discount_trend_r2536() TO authenticated;

CREATE OR REPLACE FUNCTION public.roi_distribution_r2536()
RETURNS TABLE (bucket text, cases_count bigint, total_roi_rupees bigint, avg_given numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN d.roi_estimate_rupees = 0 THEN '0_no_roi'
        WHEN d.roi_estimate_rupees < 1000000 THEN '1_under_10L'
        WHEN d.roi_estimate_rupees < 2500000 THEN '2_10L_to_25L'
        WHEN d.roi_estimate_rupees < 5000000 THEN '3_25L_to_50L'
        ELSE '4_over_50L'
      END AS bucket,
      count(*)::bigint,
      coalesce(sum(d.roi_estimate_rupees), 0)::bigint,
      round(avg(d.discount_given_pct)::numeric, 2)
    FROM public.customer_renewal_discounts_r2536 d
    GROUP BY 1
    ORDER BY 1 ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.roi_distribution_r2536() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_distribution_r2536() TO authenticated;

