BEGIN;

-- ============================================================================
-- Round 1719: Hospital Insurance Premium Tracker
-- Track hospital insurance premiums + claims for AMC bundling
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_insurance_premiums_r1719 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  insurer_name text NOT NULL,
  coverage_type text NOT NULL CHECK (coverage_type IN ('property','liability','equipment','cyber')),
  annual_premium_rupees bigint NOT NULL CHECK (annual_premium_rupees >= 0),
  policy_start_date date NOT NULL,
  policy_end_date date NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','cancelled','under_renewal')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hip_r1719_hospital ON public.hospital_insurance_premiums_r1719(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hip_r1719_status ON public.hospital_insurance_premiums_r1719(status);
CREATE INDEX IF NOT EXISTS idx_hip_r1719_insurer ON public.hospital_insurance_premiums_r1719(insurer_name);

CREATE TABLE IF NOT EXISTS public.hospital_insurance_claims_r1719 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  premium_id uuid NOT NULL REFERENCES public.hospital_insurance_premiums_r1719(id) ON DELETE CASCADE,
  claim_date date NOT NULL,
  claim_amount_rupees bigint NOT NULL CHECK (claim_amount_rupees >= 0),
  claim_status text NOT NULL DEFAULT 'filed' CHECK (claim_status IN ('filed','processing','approved','rejected','paid')),
  payout_rupees bigint NOT NULL DEFAULT 0 CHECK (payout_rupees >= 0),
  payout_date date,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hic_r1719_premium ON public.hospital_insurance_claims_r1719(premium_id);
CREATE INDEX IF NOT EXISTS idx_hic_r1719_status ON public.hospital_insurance_claims_r1719(claim_status);
CREATE INDEX IF NOT EXISTS idx_hic_r1719_date ON public.hospital_insurance_claims_r1719(claim_date DESC);

ALTER TABLE public.hospital_insurance_premiums_r1719 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_insurance_claims_r1719 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hip_r1719_founder_all ON public.hospital_insurance_premiums_r1719;
CREATE POLICY hip_r1719_founder_all ON public.hospital_insurance_premiums_r1719
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hic_r1719_founder_all ON public.hospital_insurance_claims_r1719;
CREATE POLICY hic_r1719_founder_all ON public.hospital_insurance_claims_r1719
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs (7)
-- ============================================================================

-- 1. list_premiums
CREATE OR REPLACE FUNCTION public.list_insurance_premiums_r1719()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  insurer_name text,
  coverage_type text,
  annual_premium_rupees bigint,
  policy_start_date date,
  policy_end_date date,
  status text,
  days_to_expiry int,
  created_at timestamptz
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
    p.id,
    p.hospital_user_id,
    pr.email,
    p.insurer_name,
    p.coverage_type,
    p.annual_premium_rupees,
    p.policy_start_date,
    p.policy_end_date,
    p.status,
    (p.policy_end_date - CURRENT_DATE)::int,
    p.created_at
  FROM public.hospital_insurance_premiums_r1719 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  ORDER BY p.policy_end_date ASC NULLS LAST, p.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_insurance_premiums_r1719() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_insurance_premiums_r1719() TO authenticated;

-- 2. add_premium
CREATE OR REPLACE FUNCTION public.add_insurance_premium_r1719(
  p_hospital_user_id uuid,
  p_insurer_name text,
  p_coverage_type text,
  p_annual_premium_rupees bigint,
  p_policy_start_date date,
  p_policy_end_date date,
  p_status text DEFAULT 'active',
  p_notes text DEFAULT NULL
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

  INSERT INTO public.hospital_insurance_premiums_r1719(
    hospital_user_id, insurer_name, coverage_type,
    annual_premium_rupees, policy_start_date, policy_end_date,
    status, notes
  ) VALUES (
    p_hospital_user_id, p_insurer_name, p_coverage_type,
    p_annual_premium_rupees, p_policy_start_date, p_policy_end_date,
    COALESCE(p_status, 'active'), p_notes
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_insurance_premium_r1719',
    jsonb_build_object(
      'premium_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'insurer_name', p_insurer_name,
      'coverage_type', p_coverage_type,
      'annual_premium_rupees', p_annual_premium_rupees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_insurance_premium_r1719(uuid, text, text, bigint, date, date, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_insurance_premium_r1719(uuid, text, text, bigint, date, date, text, text) TO authenticated;

-- 3. list_claims
CREATE OR REPLACE FUNCTION public.list_insurance_claims_r1719()
RETURNS TABLE (
  id uuid,
  premium_id uuid,
  insurer_name text,
  coverage_type text,
  hospital_email text,
  claim_date date,
  claim_amount_rupees bigint,
  claim_status text,
  payout_rupees bigint,
  payout_date date,
  created_at timestamptz
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
    c.id,
    c.premium_id,
    p.insurer_name,
    p.coverage_type,
    pr.email,
    c.claim_date,
    c.claim_amount_rupees,
    c.claim_status,
    c.payout_rupees,
    c.payout_date,
    c.created_at
  FROM public.hospital_insurance_claims_r1719 c
  JOIN public.hospital_insurance_premiums_r1719 p ON p.id = c.premium_id
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  ORDER BY c.claim_date DESC, c.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_insurance_claims_r1719() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_insurance_claims_r1719() TO authenticated;

-- 4. file_claim
CREATE OR REPLACE FUNCTION public.file_insurance_claim_r1719(
  p_premium_id uuid,
  p_claim_date date,
  p_claim_amount_rupees bigint,
  p_reason text DEFAULT NULL
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

  INSERT INTO public.hospital_insurance_claims_r1719(
    premium_id, claim_date, claim_amount_rupees, claim_status, reason
  ) VALUES (
    p_premium_id, p_claim_date, p_claim_amount_rupees, 'filed', p_reason
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'file_insurance_claim_r1719',
    jsonb_build_object(
      'claim_id', v_id,
      'premium_id', p_premium_id,
      'claim_date', p_claim_date,
      'claim_amount_rupees', p_claim_amount_rupees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.file_insurance_claim_r1719(uuid, date, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.file_insurance_claim_r1719(uuid, date, bigint, text) TO authenticated;

-- 5. update_claim_status
CREATE OR REPLACE FUNCTION public.update_insurance_claim_status_r1719(
  p_claim_id uuid,
  p_claim_status text,
  p_payout_rupees bigint DEFAULT NULL,
  p_payout_date date DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_claim_status NOT IN ('filed','processing','approved','rejected','paid') THEN
    RAISE EXCEPTION 'invalid claim_status';
  END IF;

  UPDATE public.hospital_insurance_claims_r1719
  SET claim_status = p_claim_status,
      payout_rupees = COALESCE(p_payout_rupees, payout_rupees),
      payout_date = COALESCE(p_payout_date, payout_date),
      updated_at = now()
  WHERE id = p_claim_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'update_insurance_claim_status_r1719',
    jsonb_build_object(
      'claim_id', p_claim_id,
      'claim_status', p_claim_status,
      'payout_rupees', p_payout_rupees,
      'payout_date', p_payout_date
    )
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_insurance_claim_status_r1719(uuid, text, bigint, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_insurance_claim_status_r1719(uuid, text, bigint, date) TO authenticated;

-- 6. premium_summary
CREATE OR REPLACE FUNCTION public.insurance_premium_summary_r1719()
RETURNS TABLE (
  total_premiums int,
  active_premiums int,
  expired_premiums int,
  under_renewal int,
  total_annual_premium_rupees bigint,
  expiring_30d int,
  expiring_60d int
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
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE status = 'active'))::int,
    (COUNT(*) FILTER (WHERE status = 'expired'))::int,
    (COUNT(*) FILTER (WHERE status = 'under_renewal'))::int,
    COALESCE(SUM(annual_premium_rupees) FILTER (WHERE status = 'active'), 0)::bigint,
    (COUNT(*) FILTER (WHERE status = 'active' AND policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'))::int,
    (COUNT(*) FILTER (WHERE status = 'active' AND policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days'))::int
  FROM public.hospital_insurance_premiums_r1719;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.insurance_premium_summary_r1719() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.insurance_premium_summary_r1719() TO authenticated;

-- 7. claims_ratio_per_insurer
CREATE OR REPLACE FUNCTION public.insurance_claims_ratio_per_insurer_r1719()
RETURNS TABLE (
  insurer_name text,
  total_premiums int,
  total_premium_rupees bigint,
  total_claims int,
  total_claim_amount_rupees bigint,
  total_payout_rupees bigint,
  claims_ratio_pct numeric,
  payout_ratio_pct numeric
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
    p.insurer_name,
    (COUNT(DISTINCT p.id))::int,
    COALESCE(SUM(DISTINCT p.annual_premium_rupees), 0)::bigint,
    (COUNT(c.id))::int,
    COALESCE(SUM(c.claim_amount_rupees), 0)::bigint,
    COALESCE(SUM(c.payout_rupees), 0)::bigint,
    CASE WHEN COALESCE(SUM(DISTINCT p.annual_premium_rupees), 0) > 0
         THEN ROUND((COALESCE(SUM(c.claim_amount_rupees), 0)::numeric / NULLIF(SUM(DISTINCT p.annual_premium_rupees), 0)::numeric) * 100, 2)
         ELSE 0 END,
    CASE WHEN COALESCE(SUM(DISTINCT p.annual_premium_rupees), 0) > 0
         THEN ROUND((COALESCE(SUM(c.payout_rupees), 0)::numeric / NULLIF(SUM(DISTINCT p.annual_premium_rupees), 0)::numeric) * 100, 2)
         ELSE 0 END
  FROM public.hospital_insurance_premiums_r1719 p
  LEFT JOIN public.hospital_insurance_claims_r1719 c ON c.premium_id = p.id
  GROUP BY p.insurer_name
  ORDER BY COALESCE(SUM(DISTINCT p.annual_premium_rupees), 0) DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.insurance_claims_ratio_per_insurer_r1719() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.insurance_claims_ratio_per_insurer_r1719() TO authenticated;

COMMIT;