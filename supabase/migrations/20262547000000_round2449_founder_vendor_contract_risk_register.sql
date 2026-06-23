-- Round 2449: founder-vendor-contract-risk-register
-- vendor × contract × auto-renew × notice period × annual cost × exit risk × replacement option

CREATE TABLE IF NOT EXISTS public.vendor_contracts_r2449 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_name text NOT NULL,
  vendor_kind text NOT NULL CHECK (vendor_kind IN ('saas','insurance','legal','payroll','logistics','cloud','services')),
  contract_summary text NOT NULL,
  signed_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  auto_renew boolean NOT NULL DEFAULT false,
  notice_period_days int NOT NULL DEFAULT 30 CHECK (notice_period_days >= 0),
  annual_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (annual_cost_rupees >= 0),
  exit_risk text NOT NULL CHECK (exit_risk IN ('low','medium','high','critical')),
  replacement_options_md text,
  contract_owner_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','under_review','in_renewal','terminating','terminated')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vendor_risk_review_log_r2449 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.vendor_contracts_r2449(id) ON DELETE CASCADE,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  exit_risk_at_review text NOT NULL CHECK (exit_risk_at_review IN ('low','medium','high','critical')),
  action_plan_md text,
  owner_email text,
  next_review_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.vendor_contracts_r2449 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_risk_review_log_r2449 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.vendor_contracts_r2449;
CREATE POLICY founder_all ON public.vendor_contracts_r2449
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.vendor_risk_review_log_r2449;
CREATE POLICY founder_all ON public.vendor_risk_review_log_r2449
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.vendor_contracts_r2449 (vendor_name, vendor_kind, contract_summary, signed_at, expires_at, auto_renew, notice_period_days, annual_cost_rupees, exit_risk, replacement_options_md, contract_owner_email, status, notes) VALUES
  ('AWS India', 'cloud', 'EDP commitment with 20% discount on EC2/RDS/S3', '2025-09-01'::timestamptz, '2026-08-31'::timestamptz, true, 60, 1800000, 'high', '- GCP migration estimate 8 weeks\n- Azure migration estimate 10 weeks', 'founder@equipseva.in', 'active', 'Auto-renew toggle in console'),
  ('Zoho One', 'saas', 'CRM + Books + Mail bundle for 25 seats', '2025-11-15'::timestamptz, '2026-11-14'::timestamptz, true, 30, 750000, 'medium', '- HubSpot Starter + QuickBooks\n- Freshworks suite', 'ops@equipseva.in', 'active', 'Sticky data in Books'),
  ('ICICI Lombard', 'insurance', 'Engineer field-staff group health + accident', '2026-04-01'::timestamptz, '2027-03-31'::timestamptz, false, 45, 420000, 'low', '- Bajaj Allianz quote available\n- Star Health quote pending', 'hr@equipseva.in', 'active', 'IRDAI compliant'),
  ('Sundar & Co Legal', 'legal', 'Retainer for contracts + IP + compliance', '2025-06-01'::timestamptz, '2026-05-31'::timestamptz, false, 30, 600000, 'critical', '- Expiring; founder review pending\n- 2 boutique firms shortlisted', 'founder@equipseva.in', 'in_renewal', 'Knows our entire stack'),
  ('Delhivery B2B', 'logistics', 'Spare-parts hub-to-hub courier SLA', '2026-01-10'::timestamptz, '2027-01-09'::timestamptz, true, 60, 950000, 'medium', '- Blue Dart B2B option\n- DTDC enterprise tier', 'logistics@equipseva.in', 'under_review', 'NPS slipping last quarter');

INSERT INTO public.vendor_risk_review_log_r2449 (contract_id, reviewed_at, exit_risk_at_review, action_plan_md, owner_email, next_review_at, status, notes) VALUES
  ((SELECT id FROM public.vendor_contracts_r2449 WHERE vendor_name='Sundar & Co Legal'), '2026-06-10'::timestamptz, 'critical', '- Finalize new legal partner by 2026-07-15\n- Migrate all open matters', 'founder@equipseva.in', '2026-07-15'::timestamptz, 'in_progress', 'Top priority renewal'),
  ((SELECT id FROM public.vendor_contracts_r2449 WHERE vendor_name='AWS India'), '2026-05-20'::timestamptz, 'high', '- Re-quote GCP\n- Negotiate AWS EDP renewal', 'founder@equipseva.in', '2026-07-30'::timestamptz, 'open', 'Lever for next round of fundraising'),
  ((SELECT id FROM public.vendor_contracts_r2449 WHERE vendor_name='Delhivery B2B'), '2026-06-15'::timestamptz, 'medium', '- Score Blue Dart pilot\n- Demand SLA correction notice', 'logistics@equipseva.in', '2026-08-01'::timestamptz, 'open', 'NPS dropped 12 points'),
  ((SELECT id FROM public.vendor_contracts_r2449 WHERE vendor_name='Zoho One'), '2026-04-02'::timestamptz, 'medium', '- Export Books data quarterly\n- Maintain HubSpot trial', 'ops@equipseva.in', '2026-09-15'::timestamptz, 'done', 'Backups in place'),
  ((SELECT id FROM public.vendor_contracts_r2449 WHERE vendor_name='ICICI Lombard'), '2026-04-15'::timestamptz, 'low', '- No action; SLA solid', 'hr@equipseva.in', '2026-12-01'::timestamptz, 'done', 'Stable renewal track');

-- RPCs

CREATE OR REPLACE FUNCTION public.list_contracts_r2449()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_kind text,
  contract_summary text,
  signed_at timestamptz,
  expires_at timestamptz,
  auto_renew boolean,
  notice_period_days int,
  annual_cost_rupees bigint,
  exit_risk text,
  contract_owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.vendor_name, c.vendor_kind, c.contract_summary,
           c.signed_at, c.expires_at, c.auto_renew, c.notice_period_days,
           c.annual_cost_rupees, c.exit_risk, c.contract_owner_email, c.status
    FROM public.vendor_contracts_r2449 c
    ORDER BY c.expires_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_contracts_r2449() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_contracts_r2449() TO authenticated;


CREATE OR REPLACE FUNCTION public.list_risk_reviews_r2449()
RETURNS TABLE (
  id uuid,
  contract_id uuid,
  vendor_name text,
  reviewed_at timestamptz,
  exit_risk_at_review text,
  owner_email text,
  next_review_at timestamptz,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.contract_id, c.vendor_name, r.reviewed_at,
           r.exit_risk_at_review, r.owner_email, r.next_review_at, r.status
    FROM public.vendor_risk_review_log_r2449 r
    JOIN public.vendor_contracts_r2449 c ON c.id = r.contract_id
    ORDER BY r.reviewed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_risk_reviews_r2449() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_risk_reviews_r2449() TO authenticated;


CREATE OR REPLACE FUNCTION public.expiring_60d_r2449()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_kind text,
  expires_at timestamptz,
  days_to_expire int,
  auto_renew boolean,
  notice_period_days int,
  exit_risk text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.vendor_name, c.vendor_kind, c.expires_at,
           EXTRACT(DAY FROM (c.expires_at - now()))::int AS days_to_expire,
           c.auto_renew, c.notice_period_days, c.exit_risk, c.status
    FROM public.vendor_contracts_r2449 c
    WHERE c.expires_at <= (now() + interval '60 days')
      AND c.status NOT IN ('terminated')
    ORDER BY c.expires_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.expiring_60d_r2449() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_60d_r2449() TO authenticated;


CREATE OR REPLACE FUNCTION public.high_risk_focus_r2449()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_kind text,
  exit_risk text,
  annual_cost_rupees bigint,
  expires_at timestamptz,
  replacement_options_md text,
  contract_owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.vendor_name, c.vendor_kind, c.exit_risk,
           c.annual_cost_rupees, c.expires_at, c.replacement_options_md,
           c.contract_owner_email
    FROM public.vendor_contracts_r2449 c
    WHERE c.exit_risk IN ('high','critical')
      AND c.status NOT IN ('terminated')
    ORDER BY
      CASE c.exit_risk WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
      c.annual_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.high_risk_focus_r2449() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.high_risk_focus_r2449() TO authenticated;


CREATE OR REPLACE FUNCTION public.vendor_kind_summary_r2449()
RETURNS TABLE (
  vendor_kind text,
  contracts int,
  annual_cost_rupees bigint,
  high_risk_count int,
  critical_risk_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.vendor_kind,
           COUNT(*)::int AS contracts,
           COALESCE(SUM(c.annual_cost_rupees), 0)::bigint AS annual_cost_rupees,
           COUNT(*) FILTER (WHERE c.exit_risk = 'high')::int AS high_risk_count,
           COUNT(*) FILTER (WHERE c.exit_risk = 'critical')::int AS critical_risk_count
    FROM public.vendor_contracts_r2449 c
    WHERE c.status NOT IN ('terminated')
    GROUP BY c.vendor_kind
    ORDER BY annual_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.vendor_kind_summary_r2449() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vendor_kind_summary_r2449() TO authenticated;


CREATE OR REPLACE FUNCTION public.annual_cost_breakdown_r2449()
RETURNS TABLE (
  bucket text,
  contracts int,
  annual_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT bucketed.bucket,
           COUNT(*)::int AS contracts,
           COALESCE(SUM(bucketed.annual_cost_rupees), 0)::bigint AS annual_cost_rupees
    FROM (
      SELECT
        CASE
          WHEN c.annual_cost_rupees < 500000 THEN 'under_5L'
          WHEN c.annual_cost_rupees < 1000000 THEN '5L_to_10L'
          WHEN c.annual_cost_rupees < 2000000 THEN '10L_to_20L'
          ELSE 'over_20L'
        END AS bucket,
        c.annual_cost_rupees
      FROM public.vendor_contracts_r2449 c
      WHERE c.status NOT IN ('terminated')
    ) bucketed
    GROUP BY bucketed.bucket
    ORDER BY annual_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.annual_cost_breakdown_r2449() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.annual_cost_breakdown_r2449() TO authenticated;


CREATE OR REPLACE FUNCTION public.upcoming_reviews_r2449()
RETURNS TABLE (
  id uuid,
  contract_id uuid,
  vendor_name text,
  next_review_at timestamptz,
  exit_risk_at_review text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.contract_id, c.vendor_name, r.next_review_at,
           r.exit_risk_at_review, r.owner_email, r.status
    FROM public.vendor_risk_review_log_r2449 r
    JOIN public.vendor_contracts_r2449 c ON c.id = r.contract_id
    WHERE r.status IN ('open','in_progress')
      AND r.next_review_at IS NOT NULL
    ORDER BY r.next_review_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.upcoming_reviews_r2449() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_reviews_r2449() TO authenticated;
