BEGIN;

-- ============================================================================
-- Round 1958 — Founder Vendor Spend Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_vendor_spend_tracker_r1958 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_name text NOT NULL,
  vendor_category text NOT NULL CHECK (vendor_category IN ('saas','tools','agency','contractor','legal','accounting','other')),
  monthly_spend_rupees bigint NOT NULL DEFAULT 0,
  contract_end_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','cancelled','expired','renegotiating')),
  renewal_alert_days int NOT NULL DEFAULT 30,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_vendor_review_log_r1958 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.founder_vendor_spend_tracker_r1958(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('review_completed','cancelled','renegotiated','replaced','cost_audit')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  cost_savings_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fvst_r1958_status ON public.founder_vendor_spend_tracker_r1958(status);
CREATE INDEX IF NOT EXISTS idx_fvst_r1958_spend ON public.founder_vendor_spend_tracker_r1958(monthly_spend_rupees DESC);
CREATE INDEX IF NOT EXISTS idx_fvrl_r1958_vendor ON public.founder_vendor_review_log_r1958(vendor_id);
CREATE INDEX IF NOT EXISTS idx_fvrl_r1958_taken ON public.founder_vendor_review_log_r1958(taken_at DESC);

ALTER TABLE public.founder_vendor_spend_tracker_r1958 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_vendor_review_log_r1958 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fvst_r1958_founder ON public.founder_vendor_spend_tracker_r1958;
CREATE POLICY p_fvst_r1958_founder ON public.founder_vendor_spend_tracker_r1958
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_fvrl_r1958_founder ON public.founder_vendor_review_log_r1958;
CREATE POLICY p_fvrl_r1958_founder ON public.founder_vendor_review_log_r1958
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_vendors_r1958()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_category text,
  monthly_spend_rupees bigint,
  contract_end_date date,
  status text,
  renewal_alert_days int,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT v.id, v.vendor_name, v.vendor_category, v.monthly_spend_rupees,
         v.contract_end_date, v.status, v.renewal_alert_days, v.captured_at
  FROM public.founder_vendor_spend_tracker_r1958 v
  ORDER BY v.monthly_spend_rupees DESC, v.captured_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_vendor_r1958(
  p_vendor_name text,
  p_vendor_category text,
  p_monthly_spend_rupees bigint,
  p_contract_end_date date,
  p_renewal_alert_days int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_vendor_spend_tracker_r1958(
    vendor_name, vendor_category, monthly_spend_rupees,
    contract_end_date, renewal_alert_days
  )
  VALUES (
    p_vendor_name, p_vendor_category, COALESCE(p_monthly_spend_rupees, 0),
    p_contract_end_date, COALESCE(p_renewal_alert_days, 30)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_vendor_r1958',
    jsonb_build_object(
      'vendor_id', v_id,
      'vendor_name', p_vendor_name,
      'vendor_category', p_vendor_category,
      'monthly_spend_rupees', p_monthly_spend_rupees
    )
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_reviews_r1958(p_vendor_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  vendor_id uuid,
  vendor_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  cost_savings_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT r.id, r.vendor_id, v.vendor_name, r.action_type, r.taken_at,
         r.by_email, r.cost_savings_rupees, r.notes_md
  FROM public.founder_vendor_review_log_r1958 r
  LEFT JOIN public.founder_vendor_spend_tracker_r1958 v ON v.id = r.vendor_id
  WHERE p_vendor_id IS NULL OR r.vendor_id = p_vendor_id
  ORDER BY r.taken_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_review_r1958(
  p_vendor_id uuid,
  p_action_type text,
  p_cost_savings_rupees bigint,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.founder_vendor_review_log_r1958(
    vendor_id, action_type, by_email, cost_savings_rupees, notes_md
  )
  VALUES (
    p_vendor_id, p_action_type, v_email,
    COALESCE(p_cost_savings_rupees, 0), p_notes_md
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_review_r1958',
    jsonb_build_object(
      'review_id', v_id,
      'vendor_id', p_vendor_id,
      'action_type', p_action_type,
      'cost_savings_rupees', p_cost_savings_rupees
    )
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1958(
  p_vendor_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_vendor_spend_tracker_r1958
  SET status = p_status, updated_at = now()
  WHERE id = p_vendor_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r1958',
    jsonb_build_object('vendor_id', p_vendor_id, 'status', p_status)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.top_spenders_r1958()
RETURNS TABLE (
  vendor_category text,
  vendor_count bigint,
  total_monthly_spend bigint,
  active_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    v.vendor_category,
    COUNT(*)::bigint AS vendor_count,
    COALESCE(SUM(v.monthly_spend_rupees), 0)::bigint AS total_monthly_spend,
    COUNT(*) FILTER (WHERE v.status = 'active')::bigint AS active_count
  FROM public.founder_vendor_spend_tracker_r1958 v
  GROUP BY v.vendor_category
  ORDER BY total_monthly_spend DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_reviews_r1958()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  cost_savings_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT r.id, v.vendor_name, r.action_type, r.taken_at, r.by_email, r.cost_savings_rupees
  FROM public.founder_vendor_review_log_r1958 r
  LEFT JOIN public.founder_vendor_spend_tracker_r1958 v ON v.id = r.vendor_id
  ORDER BY r.taken_at DESC
  LIMIT 30;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_vendors_r1958() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_vendors_r1958() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_vendor_r1958(text, text, bigint, date, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_vendor_r1958(text, text, bigint, date, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_reviews_r1958(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1958(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_review_r1958(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_review_r1958(uuid, text, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_status_r1958(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r1958(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_spenders_r1958() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_spenders_r1958() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_reviews_r1958() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_reviews_r1958() TO authenticated;

COMMIT;
