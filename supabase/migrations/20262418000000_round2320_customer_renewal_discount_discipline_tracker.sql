BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_renewal_discount_requests_r2320 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  customer_label text NOT NULL,
  contract_ref text NOT NULL,
  product_category text NOT NULL DEFAULT 'amc' CHECK (product_category IN ('amc','spare_parts','repair_bundle','multi_year_amc','training','other')),
  original_price_rupees bigint NOT NULL CHECK (original_price_rupees > 0),
  proposed_price_rupees bigint NOT NULL CHECK (proposed_price_rupees > 0),
  discount_pct numeric(6,2) NOT NULL,
  discount_value_rupees bigint NOT NULL,
  renewal_term_months int NOT NULL DEFAULT 12 CHECK (renewal_term_months > 0),
  prior_discount_pct numeric(6,2) NOT NULL DEFAULT 0,
  justification_md text NOT NULL,
  competitor_quote_rupees bigint,
  requested_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  requested_by_email text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','withdrawn','escalated')),
  decided_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  decided_by_email text,
  decided_at timestamptz,
  decision_note_md text NOT NULL DEFAULT '',
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_renewal_discount_audit_r2320 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.customer_renewal_discount_requests_r2320(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('requested','approved','rejected','withdrawn','escalated','note_added','expired')),
  actor_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_email text,
  note_md text NOT NULL DEFAULT '',
  at_ts timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_renewal_discount_requests_r2320 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_renewal_discount_audit_r2320 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_reqs_r2320 ON public.customer_renewal_discount_requests_r2320;
CREATE POLICY founder_all_reqs_r2320 ON public.customer_renewal_discount_requests_r2320
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_audit_r2320 ON public.customer_renewal_discount_audit_r2320;
CREATE POLICY founder_all_audit_r2320 ON public.customer_renewal_discount_audit_r2320
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list all renewal-discount requests with audit count
CREATE OR REPLACE FUNCTION public.list_renewal_discount_requests_r2320()
RETURNS TABLE (
  id uuid,
  customer_label text,
  contract_ref text,
  product_category text,
  original_price_rupees bigint,
  proposed_price_rupees bigint,
  discount_pct numeric,
  discount_value_rupees bigint,
  renewal_term_months int,
  prior_discount_pct numeric,
  delta_vs_prior_pct numeric,
  requested_by_email text,
  requested_at timestamptz,
  status text,
  decided_by_email text,
  decided_at timestamptz,
  expires_at timestamptz,
  audit_count int,
  justification_preview text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.customer_label, r.contract_ref, r.product_category,
    r.original_price_rupees, r.proposed_price_rupees, r.discount_pct, r.discount_value_rupees,
    r.renewal_term_months, r.prior_discount_pct,
    (r.discount_pct - r.prior_discount_pct)::numeric AS delta_vs_prior_pct,
    r.requested_by_email, r.requested_at, r.status, r.decided_by_email, r.decided_at, r.expires_at,
    (SELECT (COUNT(*))::int FROM public.customer_renewal_discount_audit_r2320 a WHERE a.request_id = r.id) AS audit_count,
    LEFT(r.justification_md, 160) AS justification_preview
  FROM public.customer_renewal_discount_requests_r2320 r
  ORDER BY r.requested_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: submit a renewal-discount request (any authenticated founder-only path)
CREATE OR REPLACE FUNCTION public.submit_renewal_discount_request_r2320(
  p_customer_user_id uuid,
  p_customer_label text,
  p_contract_ref text,
  p_product_category text,
  p_original_price_rupees bigint,
  p_proposed_price_rupees bigint,
  p_renewal_term_months int,
  p_prior_discount_pct numeric,
  p_justification_md text,
  p_competitor_quote_rupees bigint,
  p_expires_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_pct numeric(6,2);
  v_val bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_original_price_rupees IS NULL OR p_original_price_rupees <= 0 THEN RAISE EXCEPTION 'invalid_original_price'; END IF;
  IF p_proposed_price_rupees IS NULL OR p_proposed_price_rupees <= 0 THEN RAISE EXCEPTION 'invalid_proposed_price'; END IF;
  IF p_proposed_price_rupees > p_original_price_rupees THEN RAISE EXCEPTION 'proposed_exceeds_original'; END IF;
  v_val := p_original_price_rupees - p_proposed_price_rupees;
  v_pct := ROUND((v_val::numeric / p_original_price_rupees::numeric) * 100.0, 2);

  INSERT INTO public.customer_renewal_discount_requests_r2320 (
    customer_user_id, customer_label, contract_ref, product_category,
    original_price_rupees, proposed_price_rupees, discount_pct, discount_value_rupees,
    renewal_term_months, prior_discount_pct, justification_md, competitor_quote_rupees,
    requested_by_user_id, requested_by_email, expires_at
  ) VALUES (
    p_customer_user_id, p_customer_label, p_contract_ref, COALESCE(p_product_category,'amc'),
    p_original_price_rupees, p_proposed_price_rupees, v_pct, v_val,
    COALESCE(p_renewal_term_months, 12), COALESCE(p_prior_discount_pct, 0), p_justification_md, p_competitor_quote_rupees,
    auth.uid(), (auth.jwt()->>'email'), p_expires_at
  )
  RETURNING id INTO v_id;

  INSERT INTO public.customer_renewal_discount_audit_r2320 (request_id, event_type, actor_user_id, actor_email, note_md)
  VALUES (v_id, 'requested', auth.uid(), (auth.jwt()->>'email'), 'request submitted');

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'submit_renewal_discount_request_r2320',
    jsonb_build_object('request_id', v_id, 'customer', p_customer_label, 'discount_pct', v_pct, 'discount_value_rupees', v_val));
  RETURN v_id;
END;
$$;

-- RPC 3: decide a request (approve / reject / escalate)
CREATE OR REPLACE FUNCTION public.decide_renewal_discount_request_r2320(
  p_request_id uuid,
  p_decision text,
  p_decision_note_md text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision NOT IN ('approved','rejected','escalated','withdrawn') THEN
    RAISE EXCEPTION 'invalid_decision';
  END IF;
  UPDATE public.customer_renewal_discount_requests_r2320
  SET status = p_decision,
      decided_by_user_id = auth.uid(),
      decided_by_email = (auth.jwt()->>'email'),
      decided_at = now(),
      decision_note_md = COALESCE(p_decision_note_md,''),
      updated_at = now()
  WHERE id = p_request_id AND status = 'pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_pending_or_missing'; END IF;
  INSERT INTO public.customer_renewal_discount_audit_r2320 (request_id, event_type, actor_user_id, actor_email, note_md)
  VALUES (p_request_id, p_decision, auth.uid(), (auth.jwt()->>'email'), COALESCE(p_decision_note_md,''));
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'decide_renewal_discount_request_r2320',
    jsonb_build_object('request_id', p_request_id, 'decision', p_decision));
END;
$$;

-- RPC 4: top pending requests by discount-value impact
CREATE OR REPLACE FUNCTION public.top_pending_renewal_discount_r2320()
RETURNS TABLE (
  id uuid,
  customer_label text,
  contract_ref text,
  product_category text,
  original_price_rupees bigint,
  proposed_price_rupees bigint,
  discount_pct numeric,
  discount_value_rupees bigint,
  renewal_term_months int,
  prior_discount_pct numeric,
  delta_vs_prior_pct numeric,
  requested_at timestamptz,
  expires_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.customer_label, r.contract_ref, r.product_category,
    r.original_price_rupees, r.proposed_price_rupees, r.discount_pct, r.discount_value_rupees,
    r.renewal_term_months, r.prior_discount_pct,
    (r.discount_pct - r.prior_discount_pct)::numeric AS delta_vs_prior_pct,
    r.requested_at, r.expires_at
  FROM public.customer_renewal_discount_requests_r2320 r
  WHERE r.status = 'pending'
  ORDER BY r.discount_value_rupees DESC, r.discount_pct DESC
  LIMIT 25;
END;
$$;

-- RPC 5: discount-discipline summary by product category
CREATE OR REPLACE FUNCTION public.discount_discipline_by_category_r2320()
RETURNS TABLE (
  product_category text,
  total_requests int,
  approved_count int,
  rejected_count int,
  pending_count int,
  approval_rate_pct numeric,
  avg_discount_pct numeric,
  median_discount_pct numeric,
  max_discount_pct numeric,
  total_discount_given_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.product_category,
    (COUNT(*))::int AS total_requests,
    (COUNT(*) FILTER (WHERE r.status='approved'))::int AS approved_count,
    (COUNT(*) FILTER (WHERE r.status='rejected'))::int AS rejected_count,
    (COUNT(*) FILTER (WHERE r.status='pending'))::int AS pending_count,
    ROUND(
      (COUNT(*) FILTER (WHERE r.status='approved'))::numeric
      / NULLIF((COUNT(*) FILTER (WHERE r.status IN ('approved','rejected')))::numeric, 0) * 100.0, 2
    ) AS approval_rate_pct,
    ROUND(AVG(r.discount_pct)::numeric, 2) AS avg_discount_pct,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.discount_pct))::numeric, 2) AS median_discount_pct,
    ROUND(MAX(r.discount_pct)::numeric, 2) AS max_discount_pct,
    COALESCE(SUM(r.discount_value_rupees) FILTER (WHERE r.status='approved'), 0)::bigint AS total_discount_given_rupees
  FROM public.customer_renewal_discount_requests_r2320 r
  GROUP BY r.product_category
  ORDER BY total_discount_given_rupees DESC, total_requests DESC;
END;
$$;

-- RPC 6: customers who keep escalating discounts (top abusers)
CREATE OR REPLACE FUNCTION public.top_discount_escalators_r2320()
RETURNS TABLE (
  customer_label text,
  request_count int,
  approved_count int,
  total_discount_given_rupees bigint,
  avg_discount_pct numeric,
  latest_discount_pct numeric,
  latest_prior_discount_pct numeric,
  escalation_delta_pct numeric,
  last_requested_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (r.customer_label)
      r.customer_label, r.discount_pct, r.prior_discount_pct, r.requested_at
    FROM public.customer_renewal_discount_requests_r2320 r
    ORDER BY r.customer_label, r.requested_at DESC
  )
  SELECT
    r.customer_label,
    (COUNT(*))::int AS request_count,
    (COUNT(*) FILTER (WHERE r.status='approved'))::int AS approved_count,
    COALESCE(SUM(r.discount_value_rupees) FILTER (WHERE r.status='approved'), 0)::bigint AS total_discount_given_rupees,
    ROUND(AVG(r.discount_pct)::numeric, 2) AS avg_discount_pct,
    MAX(l.discount_pct)::numeric AS latest_discount_pct,
    MAX(l.prior_discount_pct)::numeric AS latest_prior_discount_pct,
    ROUND((MAX(l.discount_pct) - MAX(l.prior_discount_pct))::numeric, 2) AS escalation_delta_pct,
    MAX(r.requested_at) AS last_requested_at
  FROM public.customer_renewal_discount_requests_r2320 r
  JOIN latest l ON l.customer_label = r.customer_label
  GROUP BY r.customer_label
  HAVING COUNT(*) >= 2
  ORDER BY escalation_delta_pct DESC NULLS LAST, total_discount_given_rupees DESC
  LIMIT 30;
END;
$$;

-- RPC 7: recent decisions audit (last 200)
CREATE OR REPLACE FUNCTION public.recent_renewal_discount_audit_r2320()
RETURNS TABLE (
  id uuid,
  request_id uuid,
  customer_label text,
  product_category text,
  event_type text,
  actor_email text,
  note_md text,
  at_ts timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.request_id, r.customer_label, r.product_category,
    a.event_type, a.actor_email, a.note_md, a.at_ts
  FROM public.customer_renewal_discount_audit_r2320 a
  JOIN public.customer_renewal_discount_requests_r2320 r ON r.id = a.request_id
  ORDER BY a.at_ts DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_renewal_discount_requests_r2320() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.submit_renewal_discount_request_r2320(uuid, text, text, text, bigint, bigint, int, numeric, text, bigint, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decide_renewal_discount_request_r2320(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_pending_renewal_discount_r2320() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.discount_discipline_by_category_r2320() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_discount_escalators_r2320() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_renewal_discount_audit_r2320() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_renewal_discount_requests_r2320() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_renewal_discount_request_r2320(uuid, text, text, text, bigint, bigint, int, numeric, text, bigint, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_renewal_discount_request_r2320(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_pending_renewal_discount_r2320() TO authenticated;
GRANT EXECUTE ON FUNCTION public.discount_discipline_by_category_r2320() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_discount_escalators_r2320() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_renewal_discount_audit_r2320() TO authenticated;

COMMIT;
