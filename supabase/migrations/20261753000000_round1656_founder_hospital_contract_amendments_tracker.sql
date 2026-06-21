BEGIN;
-- r1656 — Hospital contract amendments tracker
-- Logs AMC amendments (price changes, scope expansion, exclusions) with per-amendment approval + signature.

-- =========================================================
-- Tables
-- =========================================================

CREATE TABLE IF NOT EXISTS public.hospital_contract_amendments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id     uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL,
  amendment_kind  text NOT NULL CHECK (amendment_kind IN ('price_change','scope_expansion','exclusion','tier_change','term_extension','equipment_added','equipment_removed','other')),
  title           text NOT NULL,
  description     text,
  prior_tier      text,
  new_tier        text,
  prior_monthly_fee_rupees integer,
  new_monthly_fee_rupees   integer,
  prior_equipment_categories text[],
  new_equipment_categories   text[],
  effective_from  date,
  effective_to    date,
  status          text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','pending_approval','approved','rejected','signed','active','rescinded')),
  approval_required boolean NOT NULL DEFAULT true,
  approved_by_founder boolean NOT NULL DEFAULT false,
  approved_at     timestamptz,
  signed_by_hospital boolean NOT NULL DEFAULT false,
  signed_at       timestamptz,
  signature_payload jsonb,
  rejection_reason text,
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hca_contract     ON public.hospital_contract_amendments(contract_id);
CREATE INDEX IF NOT EXISTS idx_hca_hospital     ON public.hospital_contract_amendments(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hca_status       ON public.hospital_contract_amendments(status);
CREATE INDEX IF NOT EXISTS idx_hca_created_at   ON public.hospital_contract_amendments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hca_kind         ON public.hospital_contract_amendments(amendment_kind);

CREATE TABLE IF NOT EXISTS public.hospital_contract_amendment_audit (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amendment_id  uuid NOT NULL REFERENCES public.hospital_contract_amendments(id) ON DELETE CASCADE,
  event         text NOT NULL CHECK (event IN ('created','submitted','approved','rejected','signed','activated','rescinded','noted')),
  prior_status  text,
  new_status    text,
  notes         text,
  actor_user_id uuid,
  actor_email   text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hca_audit_amendment ON public.hospital_contract_amendment_audit(amendment_id);
CREATE INDEX IF NOT EXISTS idx_hca_audit_created   ON public.hospital_contract_amendment_audit(created_at DESC);

ALTER TABLE public.hospital_contract_amendments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_contract_amendment_audit  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hca_founder_all ON public.hospital_contract_amendments;
CREATE POLICY hca_founder_all
  ON public.hospital_contract_amendments
  FOR ALL
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hca_audit_founder_all ON public.hospital_contract_amendment_audit;
CREATE POLICY hca_audit_founder_all
  ON public.hospital_contract_amendment_audit
  FOR ALL
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================
-- helper: founder action log writer (INSERT only, real cols)
-- =========================================================
CREATE OR REPLACE FUNCTION public.log_founder_amendment_op(p_op text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, COALESCE(p_after, '{}'::jsonb), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_amendment_op(text, jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_amendment_op(text, jsonb) TO authenticated;

-- =========================================================
-- RPC 1 — list amendments (STABLE)
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_amendments_list(p_status text DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  contract_id uuid,
  hospital_user_id uuid,
  hospital_email text,
  amendment_kind text,
  title text,
  status text,
  prior_tier text,
  new_tier text,
  prior_monthly_fee_rupees int,
  new_monthly_fee_rupees int,
  effective_from date,
  effective_to date,
  approval_required boolean,
  approved_by_founder boolean,
  signed_by_hospital boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.contract_id,
    a.hospital_user_id,
    p.email,
    a.amendment_kind,
    a.title,
    a.status,
    a.prior_tier,
    a.new_tier,
    a.prior_monthly_fee_rupees,
    a.new_monthly_fee_rupees,
    a.effective_from,
    a.effective_to,
    a.approval_required,
    a.approved_by_founder,
    a.signed_by_hospital,
    a.created_at
  FROM public.hospital_contract_amendments a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  WHERE (p_status IS NULL OR a.status = p_status)
  ORDER BY a.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 200), 1000));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amendments_list(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amendments_list(text, int) TO authenticated;

-- =========================================================
-- RPC 2 — summary (STABLE)
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_amendments_summary()
RETURNS TABLE (
  total int,
  drafts int,
  pending int,
  approved int,
  rejected int,
  signed int,
  active int,
  rescinded int,
  price_changes int,
  scope_expansions int,
  exclusions int,
  net_monthly_delta_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total,
    (COUNT(*) FILTER (WHERE status='draft'))::int AS drafts,
    (COUNT(*) FILTER (WHERE status='pending_approval'))::int AS pending,
    (COUNT(*) FILTER (WHERE status='approved'))::int AS approved,
    (COUNT(*) FILTER (WHERE status='rejected'))::int AS rejected,
    (COUNT(*) FILTER (WHERE status='signed'))::int AS signed,
    (COUNT(*) FILTER (WHERE status='active'))::int AS active,
    (COUNT(*) FILTER (WHERE status='rescinded'))::int AS rescinded,
    (COUNT(*) FILTER (WHERE amendment_kind='price_change'))::int AS price_changes,
    (COUNT(*) FILTER (WHERE amendment_kind='scope_expansion'))::int AS scope_expansions,
    (COUNT(*) FILTER (WHERE amendment_kind='exclusion'))::int AS exclusions,
    COALESCE(SUM(COALESCE(new_monthly_fee_rupees,0) - COALESCE(prior_monthly_fee_rupees,0)) FILTER (WHERE status IN ('approved','signed','active')), 0)::bigint AS net_monthly_delta_rupees
  FROM public.hospital_contract_amendments;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amendments_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amendments_summary() TO authenticated;

-- =========================================================
-- RPC 3 — by kind breakdown (STABLE)
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_amendments_by_kind()
RETURNS TABLE (
  amendment_kind text,
  total int,
  approved int,
  pending int,
  rejected int,
  net_fee_delta_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.amendment_kind,
    (COUNT(*))::int AS total,
    (COUNT(*) FILTER (WHERE a.status IN ('approved','signed','active')))::int AS approved,
    (COUNT(*) FILTER (WHERE a.status='pending_approval'))::int AS pending,
    (COUNT(*) FILTER (WHERE a.status='rejected'))::int AS rejected,
    COALESCE(SUM(COALESCE(a.new_monthly_fee_rupees,0) - COALESCE(a.prior_monthly_fee_rupees,0)) FILTER (WHERE a.status IN ('approved','signed','active')), 0)::bigint AS net_fee_delta_rupees
  FROM public.hospital_contract_amendments a
  GROUP BY a.amendment_kind
  ORDER BY total DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amendments_by_kind() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amendments_by_kind() TO authenticated;

-- =========================================================
-- RPC 4 — recent audit trail (STABLE)
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_amendments_recent_audit(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  amendment_id uuid,
  amendment_title text,
  event text,
  prior_status text,
  new_status text,
  notes text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    au.id,
    au.amendment_id,
    a.title,
    au.event,
    au.prior_status,
    au.new_status,
    au.notes,
    au.actor_email,
    au.created_at
  FROM public.hospital_contract_amendment_audit au
  LEFT JOIN public.hospital_contract_amendments a ON a.id = au.amendment_id
  ORDER BY au.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amendments_recent_audit(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amendments_recent_audit(int) TO authenticated;

-- =========================================================
-- RPC 5 — top hospitals by amendment volume (STABLE)
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_amendments_top_hospitals(p_limit int DEFAULT 20)
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  total int,
  price_changes int,
  scope_expansions int,
  exclusions int,
  net_monthly_delta_rupees bigint,
  last_amendment_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.hospital_user_id,
    p.email,
    (COUNT(*))::int AS total,
    (COUNT(*) FILTER (WHERE a.amendment_kind='price_change'))::int AS price_changes,
    (COUNT(*) FILTER (WHERE a.amendment_kind='scope_expansion'))::int AS scope_expansions,
    (COUNT(*) FILTER (WHERE a.amendment_kind='exclusion'))::int AS exclusions,
    COALESCE(SUM(COALESCE(a.new_monthly_fee_rupees,0) - COALESCE(a.prior_monthly_fee_rupees,0)) FILTER (WHERE a.status IN ('approved','signed','active')), 0)::bigint AS net_monthly_delta_rupees,
    MAX(a.created_at) AS last_amendment_at
  FROM public.hospital_contract_amendments a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  GROUP BY a.hospital_user_id, p.email
  ORDER BY total DESC, last_amendment_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amendments_top_hospitals(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amendments_top_hospitals(int) TO authenticated;

-- =========================================================
-- RPC 6 — pending approval queue (STABLE)
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_amendments_pending_queue(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  contract_id uuid,
  hospital_email text,
  amendment_kind text,
  title text,
  prior_tier text,
  new_tier text,
  fee_delta_rupees int,
  effective_from date,
  age_hours int,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.contract_id,
    p.email,
    a.amendment_kind,
    a.title,
    a.prior_tier,
    a.new_tier,
    (COALESCE(a.new_monthly_fee_rupees,0) - COALESCE(a.prior_monthly_fee_rupees,0))::int AS fee_delta_rupees,
    a.effective_from,
    (EXTRACT(EPOCH FROM (now() - a.created_at))/3600.0)::int AS age_hours,
    a.created_at
  FROM public.hospital_contract_amendments a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  WHERE a.status = 'pending_approval'
  ORDER BY a.created_at ASC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amendments_pending_queue(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amendments_pending_queue(int) TO authenticated;

-- =========================================================
-- RPC 7 — monthly trend (last 12 months) (STABLE)
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_amendments_monthly_trend()
RETURNS TABLE (
  month_start date,
  total int,
  approved int,
  rejected int,
  signed int,
  net_monthly_delta_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (date_trunc('month', a.created_at))::date AS month_start,
    (COUNT(*))::int AS total,
    (COUNT(*) FILTER (WHERE a.status IN ('approved','active')))::int AS approved,
    (COUNT(*) FILTER (WHERE a.status='rejected'))::int AS rejected,
    (COUNT(*) FILTER (WHERE a.status='signed'))::int AS signed,
    COALESCE(SUM(COALESCE(a.new_monthly_fee_rupees,0) - COALESCE(a.prior_monthly_fee_rupees,0)) FILTER (WHERE a.status IN ('approved','signed','active')), 0)::bigint AS net_monthly_delta_rupees
  FROM public.hospital_contract_amendments a
  WHERE a.created_at >= (now() - interval '12 months')
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amendments_monthly_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amendments_monthly_trend() TO authenticated;

COMMIT;