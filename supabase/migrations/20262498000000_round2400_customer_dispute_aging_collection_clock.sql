BEGIN;

-- Round 2400: Customer dispute-aging vs collection clock
-- For each disputed invoice: aging days vs collection effort; write-off threshold breach alert

CREATE TABLE IF NOT EXISTS public.customer_dispute_aging_r2400 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  invoice_number text NOT NULL,
  invoice_amount_rupees numeric(12,2) NOT NULL CHECK (invoice_amount_rupees > 0),
  invoice_issued_on date NOT NULL,
  dispute_opened_on date NOT NULL,
  dispute_reason text NOT NULL CHECK (dispute_reason IN ('quality','billing_error','service_incomplete','part_mismatch','scope_creep','duplicate_charge','other')),
  dispute_status text NOT NULL DEFAULT 'open' CHECK (dispute_status IN ('open','in_review','negotiating','settled','written_off','escalated_legal')),
  amount_disputed_rupees numeric(12,2) NOT NULL CHECK (amount_disputed_rupees >= 0),
  amount_collected_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (amount_collected_rupees >= 0),
  write_off_threshold_rupees numeric(12,2) NOT NULL DEFAULT 5000,
  write_off_breach boolean NOT NULL DEFAULT false,
  last_collection_attempt_on date,
  resolved_on date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (customer_user_id, invoice_number)
);

CREATE INDEX IF NOT EXISTS idx_cda_r2400_customer ON public.customer_dispute_aging_r2400(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_cda_r2400_status ON public.customer_dispute_aging_r2400(dispute_status);
CREATE INDEX IF NOT EXISTS idx_cda_r2400_opened ON public.customer_dispute_aging_r2400(dispute_opened_on DESC);

ALTER TABLE public.customer_dispute_aging_r2400 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cda_r2400_founder_all ON public.customer_dispute_aging_r2400;
CREATE POLICY cda_r2400_founder_all ON public.customer_dispute_aging_r2400
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_dispute_collection_actions_r2400 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id uuid NOT NULL REFERENCES public.customer_dispute_aging_r2400(id) ON DELETE CASCADE,
  action_on date NOT NULL DEFAULT CURRENT_DATE,
  action_type text NOT NULL CHECK (action_type IN ('phone_call','email','sms','whatsapp','site_visit','legal_notice','collection_agency','founder_call','settled')),
  effort_minutes integer NOT NULL DEFAULT 0 CHECK (effort_minutes >= 0),
  outcome text NOT NULL CHECK (outcome IN ('no_response','promised_payment','partial_received','full_received','refused','requested_more_info','escalated')),
  amount_promised_rupees numeric(12,2) DEFAULT 0,
  amount_received_rupees numeric(12,2) DEFAULT 0,
  performed_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cdca_r2400_dispute ON public.customer_dispute_collection_actions_r2400(dispute_id);
CREATE INDEX IF NOT EXISTS idx_cdca_r2400_action_on ON public.customer_dispute_collection_actions_r2400(action_on DESC);

ALTER TABLE public.customer_dispute_collection_actions_r2400 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cdca_r2400_founder_all ON public.customer_dispute_collection_actions_r2400;
CREATE POLICY cdca_r2400_founder_all ON public.customer_dispute_collection_actions_r2400
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: summary KPIs
CREATE OR REPLACE FUNCTION public.dispute_aging_collection_summary_r2400()
RETURNS TABLE (
  total_open_disputes integer,
  total_disputed_amount_rupees numeric,
  total_collected_rupees numeric,
  avg_aging_days numeric,
  write_off_breach_count integer,
  settled_count integer,
  escalated_legal_count integer,
  collection_recovery_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE dispute_status IN ('open','in_review','negotiating'))::integer,
    COALESCE(SUM(amount_disputed_rupees), 0)::numeric,
    COALESCE(SUM(amount_collected_rupees), 0)::numeric,
    COALESCE(AVG(CURRENT_DATE - dispute_opened_on) FILTER (WHERE resolved_on IS NULL), 0)::numeric,
    COUNT(*) FILTER (WHERE write_off_breach)::integer,
    COUNT(*) FILTER (WHERE dispute_status = 'settled')::integer,
    COUNT(*) FILTER (WHERE dispute_status = 'escalated_legal')::integer,
    CASE WHEN SUM(amount_disputed_rupees) > 0
      THEN ROUND((SUM(amount_collected_rupees) / SUM(amount_disputed_rupees) * 100)::numeric, 2)
      ELSE 0
    END
  FROM public.customer_dispute_aging_r2400;
END;
$$;

REVOKE ALL ON FUNCTION public.dispute_aging_collection_summary_r2400() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_aging_collection_summary_r2400() TO authenticated;

-- RPC 2: dispute aging buckets
CREATE OR REPLACE FUNCTION public.dispute_aging_buckets_r2400()
RETURNS TABLE (
  bucket text,
  dispute_count integer,
  total_amount_rupees numeric,
  avg_collected_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH aging AS (
    SELECT
      CASE
        WHEN CURRENT_DATE - dispute_opened_on <= 7 THEN '0-7d'
        WHEN CURRENT_DATE - dispute_opened_on <= 30 THEN '8-30d'
        WHEN CURRENT_DATE - dispute_opened_on <= 60 THEN '31-60d'
        WHEN CURRENT_DATE - dispute_opened_on <= 90 THEN '61-90d'
        ELSE '90d+'
      END AS bucket,
      amount_disputed_rupees,
      amount_collected_rupees
    FROM public.customer_dispute_aging_r2400
    WHERE resolved_on IS NULL
  )
  SELECT
    a.bucket,
    COUNT(*)::integer,
    COALESCE(SUM(a.amount_disputed_rupees), 0)::numeric,
    CASE WHEN SUM(a.amount_disputed_rupees) > 0
      THEN ROUND((SUM(a.amount_collected_rupees) / SUM(a.amount_disputed_rupees) * 100)::numeric, 2)
      ELSE 0
    END
  FROM aging a
  GROUP BY a.bucket
  ORDER BY
    CASE a.bucket
      WHEN '0-7d' THEN 1
      WHEN '8-30d' THEN 2
      WHEN '31-60d' THEN 3
      WHEN '61-90d' THEN 4
      ELSE 5
    END;
END;
$$;

REVOKE ALL ON FUNCTION public.dispute_aging_buckets_r2400() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_aging_buckets_r2400() TO authenticated;

-- RPC 3: top aged disputes (>30d unresolved, sorted by aging)
CREATE OR REPLACE FUNCTION public.dispute_aging_top_aged_r2400()
RETURNS TABLE (
  dispute_id uuid,
  customer_email text,
  invoice_number text,
  invoice_amount_rupees numeric,
  amount_disputed_rupees numeric,
  amount_collected_rupees numeric,
  aging_days integer,
  dispute_status text,
  dispute_reason text,
  collection_attempts integer,
  total_effort_minutes integer,
  write_off_breach boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    p.email,
    d.invoice_number,
    d.invoice_amount_rupees,
    d.amount_disputed_rupees,
    d.amount_collected_rupees,
    (CURRENT_DATE - d.dispute_opened_on)::integer,
    d.dispute_status,
    d.dispute_reason,
    COALESCE((SELECT COUNT(*) FROM public.customer_dispute_collection_actions_r2400 a WHERE a.dispute_id = d.id), 0)::integer,
    COALESCE((SELECT SUM(effort_minutes) FROM public.customer_dispute_collection_actions_r2400 a WHERE a.dispute_id = d.id), 0)::integer,
    d.write_off_breach
  FROM public.customer_dispute_aging_r2400 d
  JOIN public.profiles p ON p.id = d.customer_user_id
  WHERE d.resolved_on IS NULL
    AND (CURRENT_DATE - d.dispute_opened_on) > 30
  ORDER BY (CURRENT_DATE - d.dispute_opened_on) DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.dispute_aging_top_aged_r2400() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_aging_top_aged_r2400() TO authenticated;

-- RPC 4: write-off threshold breach alerts
CREATE OR REPLACE FUNCTION public.dispute_aging_writeoff_breaches_r2400()
RETURNS TABLE (
  dispute_id uuid,
  customer_email text,
  invoice_number text,
  amount_disputed_rupees numeric,
  amount_collected_rupees numeric,
  write_off_threshold_rupees numeric,
  exposure_rupees numeric,
  aging_days integer,
  dispute_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    p.email,
    d.invoice_number,
    d.amount_disputed_rupees,
    d.amount_collected_rupees,
    d.write_off_threshold_rupees,
    (d.amount_disputed_rupees - d.amount_collected_rupees)::numeric,
    (CURRENT_DATE - d.dispute_opened_on)::integer,
    d.dispute_status
  FROM public.customer_dispute_aging_r2400 d
  JOIN public.profiles p ON p.id = d.customer_user_id
  WHERE d.write_off_breach = true
     OR (d.amount_disputed_rupees - d.amount_collected_rupees) > d.write_off_threshold_rupees
  ORDER BY (d.amount_disputed_rupees - d.amount_collected_rupees) DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.dispute_aging_writeoff_breaches_r2400() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_aging_writeoff_breaches_r2400() TO authenticated;

-- RPC 5: collection effort vs recovery efficiency by dispute reason
CREATE OR REPLACE FUNCTION public.dispute_aging_effort_efficiency_r2400()
RETURNS TABLE (
  dispute_reason text,
  dispute_count integer,
  total_effort_minutes integer,
  total_disputed_rupees numeric,
  total_collected_rupees numeric,
  recovery_pct numeric,
  effort_per_dispute_minutes numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.dispute_reason,
    COUNT(DISTINCT d.id)::integer,
    COALESCE(SUM(a.effort_minutes), 0)::integer,
    COALESCE(SUM(DISTINCT d.amount_disputed_rupees), 0)::numeric,
    COALESCE(SUM(DISTINCT d.amount_collected_rupees), 0)::numeric,
    CASE WHEN SUM(DISTINCT d.amount_disputed_rupees) > 0
      THEN ROUND((SUM(DISTINCT d.amount_collected_rupees) / SUM(DISTINCT d.amount_disputed_rupees) * 100)::numeric, 2)
      ELSE 0
    END,
    CASE WHEN COUNT(DISTINCT d.id) > 0
      THEN ROUND((COALESCE(SUM(a.effort_minutes), 0)::numeric / COUNT(DISTINCT d.id)), 2)
      ELSE 0
    END
  FROM public.customer_dispute_aging_r2400 d
  LEFT JOIN public.customer_dispute_collection_actions_r2400 a ON a.dispute_id = d.id
  GROUP BY d.dispute_reason
  ORDER BY COUNT(DISTINCT d.id) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.dispute_aging_effort_efficiency_r2400() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_aging_effort_efficiency_r2400() TO authenticated;

-- RPC 6: recent collection actions feed
CREATE OR REPLACE FUNCTION public.dispute_aging_recent_actions_r2400()
RETURNS TABLE (
  action_id uuid,
  invoice_number text,
  customer_email text,
  action_on date,
  action_type text,
  effort_minutes integer,
  outcome text,
  amount_received_rupees numeric,
  performed_by_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    d.invoice_number,
    cust.email,
    a.action_on,
    a.action_type,
    a.effort_minutes,
    a.outcome,
    COALESCE(a.amount_received_rupees, 0)::numeric,
    actor.email
  FROM public.customer_dispute_collection_actions_r2400 a
  JOIN public.customer_dispute_aging_r2400 d ON d.id = a.dispute_id
  JOIN public.profiles cust ON cust.id = d.customer_user_id
  LEFT JOIN public.profiles actor ON actor.id = a.performed_by_user_id
  ORDER BY a.action_on DESC, a.created_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.dispute_aging_recent_actions_r2400() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_aging_recent_actions_r2400() TO authenticated;

-- RPC 7: status distribution
CREATE OR REPLACE FUNCTION public.dispute_aging_status_distribution_r2400()
RETURNS TABLE (
  dispute_status text,
  dispute_count integer,
  total_amount_rupees numeric,
  avg_aging_days numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.dispute_status,
    COUNT(*)::integer,
    COALESCE(SUM(d.amount_disputed_rupees), 0)::numeric,
    COALESCE(AVG(COALESCE(d.resolved_on, CURRENT_DATE) - d.dispute_opened_on), 0)::numeric
  FROM public.customer_dispute_aging_r2400 d
  GROUP BY d.dispute_status
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.dispute_aging_status_distribution_r2400() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_aging_status_distribution_r2400() TO authenticated;

COMMIT;
