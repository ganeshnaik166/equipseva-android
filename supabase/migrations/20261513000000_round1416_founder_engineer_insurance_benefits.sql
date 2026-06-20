BEGIN;
-- round1416: founder engineer insurance + benefits tracker


-- Table 1: policies
CREATE TABLE IF NOT EXISTS public.founder_engineer_insurance_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  policy_kind text NOT NULL CHECK (policy_kind IN ('health_individual','health_family','accident','life_term','disability','professional_indemnity','equipment_damage')),
  policy_number text NOT NULL,
  insurer_company text NOT NULL,
  sum_assured_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (sum_assured_rupees >= 0),
  premium_paid_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (premium_paid_rupees >= 0),
  premium_payer text NOT NULL DEFAULT 'company' CHECK (premium_payer IN ('company','engineer','split')),
  policy_start_date date NOT NULL DEFAULT CURRENT_DATE,
  policy_end_date date NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','cancelled','lapsed','renewed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_feip_engineer ON public.founder_engineer_insurance_policies(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_feip_status ON public.founder_engineer_insurance_policies(status);
CREATE INDEX IF NOT EXISTS idx_feip_end_date ON public.founder_engineer_insurance_policies(policy_end_date);
ALTER TABLE public.founder_engineer_insurance_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS feip_engineer_own ON public.founder_engineer_insurance_policies;
CREATE POLICY feip_engineer_own ON public.founder_engineer_insurance_policies
  FOR SELECT TO authenticated
  USING (engineer_user_id = auth.uid() OR public.is_founder());

DROP POLICY IF EXISTS feip_founder_write ON public.founder_engineer_insurance_policies;
CREATE POLICY feip_founder_write ON public.founder_engineer_insurance_policies
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: claims
CREATE TABLE IF NOT EXISTS public.founder_engineer_benefits_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id uuid NOT NULL REFERENCES public.founder_engineer_insurance_policies(id) ON DELETE CASCADE,
  claim_kind text NOT NULL CHECK (claim_kind IN ('medical','accident','equipment','liability','death','disability','wellness')),
  claimed_amount_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (claimed_amount_rupees >= 0),
  approved_amount_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (approved_amount_rupees >= 0),
  claim_status text NOT NULL DEFAULT 'submitted' CHECK (claim_status IN ('submitted','under_review','approved','rejected','paid','disputed')),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz,
  paid_at timestamptz,
  supporting_doc_urls text[] NOT NULL DEFAULT ARRAY[]::text[],
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_febc_policy ON public.founder_engineer_benefits_claims(policy_id);
CREATE INDEX IF NOT EXISTS idx_febc_status ON public.founder_engineer_benefits_claims(claim_status);
CREATE INDEX IF NOT EXISTS idx_febc_submitted ON public.founder_engineer_benefits_claims(submitted_at DESC);
ALTER TABLE public.founder_engineer_benefits_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS febc_engineer_own ON public.founder_engineer_benefits_claims;
CREATE POLICY febc_engineer_own ON public.founder_engineer_benefits_claims
  FOR SELECT TO authenticated
  USING (
    public.is_founder()
    OR EXISTS (
      SELECT 1 FROM public.founder_engineer_insurance_policies p
      WHERE p.id = policy_id AND p.engineer_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS febc_founder_write ON public.founder_engineer_benefits_claims;
CREATE POLICY febc_founder_write ON public.founder_engineer_benefits_claims
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: summary (16 KPIs)
CREATE OR REPLACE FUNCTION public.founder_engineer_insurance_summary()
RETURNS TABLE (
  total_policies bigint,
  active_policies bigint,
  expired_policies bigint,
  cancelled_policies bigint,
  lapsed_policies bigint,
  renewed_policies bigint,
  expiring_in_30d bigint,
  unique_engineers_covered bigint,
  total_sum_assured_rupees numeric,
  total_premium_paid_rupees numeric,
  company_paid_premium_rupees numeric,
  total_claims bigint,
  claims_paid bigint,
  claims_pending bigint,
  total_approved_payout_rupees numeric,
  policies_created_30d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_engineer_insurance_policies),
    (SELECT count(*) FROM public.founder_engineer_insurance_policies WHERE status = 'active'),
    (SELECT count(*) FROM public.founder_engineer_insurance_policies WHERE status = 'expired'),
    (SELECT count(*) FROM public.founder_engineer_insurance_policies WHERE status = 'cancelled'),
    (SELECT count(*) FROM public.founder_engineer_insurance_policies WHERE status = 'lapsed'),
    (SELECT count(*) FROM public.founder_engineer_insurance_policies WHERE status = 'renewed'),
    (SELECT count(*) FROM public.founder_engineer_insurance_policies WHERE status = 'active' AND policy_end_date <= CURRENT_DATE + INTERVAL '30 days' AND policy_end_date >= CURRENT_DATE),
    (SELECT count(DISTINCT engineer_user_id) FROM public.founder_engineer_insurance_policies WHERE status = 'active'),
    (SELECT COALESCE(sum(sum_assured_rupees),0) FROM public.founder_engineer_insurance_policies WHERE status = 'active'),
    (SELECT COALESCE(sum(premium_paid_rupees),0) FROM public.founder_engineer_insurance_policies),
    (SELECT COALESCE(sum(premium_paid_rupees),0) FROM public.founder_engineer_insurance_policies WHERE premium_payer = 'company'),
    (SELECT count(*) FROM public.founder_engineer_benefits_claims),
    (SELECT count(*) FROM public.founder_engineer_benefits_claims WHERE claim_status = 'paid'),
    (SELECT count(*) FROM public.founder_engineer_benefits_claims WHERE claim_status IN ('submitted','under_review')),
    (SELECT COALESCE(sum(approved_amount_rupees),0) FROM public.founder_engineer_benefits_claims WHERE claim_status IN ('approved','paid')),
    (SELECT count(*) FROM public.founder_engineer_insurance_policies WHERE created_at >= now() - INTERVAL '30 days');
END;
$$;
REVOKE ALL ON FUNCTION public.founder_engineer_insurance_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_insurance_summary() TO authenticated;

-- RPC 2: recent policies
CREATE OR REPLACE FUNCTION public.founder_engineer_insurance_policies_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid, engineer_user_id uuid, policy_kind text, policy_number text,
  insurer_company text, sum_assured_rupees numeric, premium_paid_rupees numeric,
  premium_payer text, policy_start_date date, policy_end_date date,
  status text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.policy_kind, p.policy_number,
         p.insurer_company, p.sum_assured_rupees, p.premium_paid_rupees,
         p.premium_payer, p.policy_start_date, p.policy_end_date,
         p.status, p.created_at
  FROM public.founder_engineer_insurance_policies p
  ORDER BY p.created_at DESC
  LIMIT GREATEST(LEAST(p_limit, 200), 1);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_engineer_insurance_policies_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_insurance_policies_recent(int) TO authenticated;

-- RPC 3: recent claims
CREATE OR REPLACE FUNCTION public.founder_engineer_insurance_claims_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  id uuid, policy_id uuid, policy_number text, engineer_user_id uuid,
  claim_kind text, claimed_amount_rupees numeric, approved_amount_rupees numeric,
  claim_status text, submitted_at timestamptz, approved_at timestamptz,
  paid_at timestamptz, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT c.id, c.policy_id, p.policy_number, p.engineer_user_id,
         c.claim_kind, c.claimed_amount_rupees, c.approved_amount_rupees,
         c.claim_status, c.submitted_at, c.approved_at,
         c.paid_at, c.notes
  FROM public.founder_engineer_benefits_claims c
  JOIN public.founder_engineer_insurance_policies p ON p.id = c.policy_id
  ORDER BY c.submitted_at DESC
  LIMIT GREATEST(LEAST(p_limit, 200), 1);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_engineer_insurance_claims_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_insurance_claims_recent(int) TO authenticated;

-- RPC 4: expiring soon (within 30d)
CREATE OR REPLACE FUNCTION public.founder_engineer_insurance_expiring_soon()
RETURNS TABLE (
  id uuid, engineer_user_id uuid, policy_kind text, policy_number text,
  insurer_company text, sum_assured_rupees numeric, policy_end_date date,
  days_until_expiry int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.policy_kind, p.policy_number,
         p.insurer_company, p.sum_assured_rupees, p.policy_end_date,
         (p.policy_end_date - CURRENT_DATE)::int
  FROM public.founder_engineer_insurance_policies p
  WHERE p.status = 'active'
    AND p.policy_end_date >= CURRENT_DATE
    AND p.policy_end_date <= CURRENT_DATE + INTERVAL '30 days'
  ORDER BY p.policy_end_date ASC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_engineer_insurance_expiring_soon() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_insurance_expiring_soon() TO authenticated;

-- RPC 5: register policy
CREATE OR REPLACE FUNCTION public.log_founder_engineer_insurance_register_policy(
  p_engineer_user_id uuid,
  p_policy_kind text,
  p_policy_number text,
  p_insurer_company text,
  p_sum_assured_rupees numeric,
  p_premium_paid_rupees numeric,
  p_premium_payer text,
  p_policy_start_date date,
  p_policy_end_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.founder_engineer_insurance_policies (
    engineer_user_id, policy_kind, policy_number, insurer_company,
    sum_assured_rupees, premium_paid_rupees, premium_payer,
    policy_start_date, policy_end_date, status
  ) VALUES (
    p_engineer_user_id, p_policy_kind, p_policy_number, p_insurer_company,
    COALESCE(p_sum_assured_rupees,0), COALESCE(p_premium_paid_rupees,0),
    COALESCE(p_premium_payer,'company'),
    COALESCE(p_policy_start_date, CURRENT_DATE), p_policy_end_date, 'active'
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_engineer_insurance_register_policy(uuid,text,text,text,numeric,numeric,text,date,date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_insurance_register_policy(uuid,text,text,text,numeric,numeric,text,date,date) TO authenticated;

-- RPC 6: register claim
CREATE OR REPLACE FUNCTION public.log_founder_engineer_insurance_register_claim(
  p_policy_id uuid,
  p_claim_kind text,
  p_claimed_amount_rupees numeric,
  p_supporting_doc_urls text[],
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.founder_engineer_benefits_claims (
    policy_id, claim_kind, claimed_amount_rupees,
    supporting_doc_urls, notes, claim_status, submitted_at
  ) VALUES (
    p_policy_id, p_claim_kind, COALESCE(p_claimed_amount_rupees,0),
    COALESCE(p_supporting_doc_urls, ARRAY[]::text[]), p_notes,
    'submitted', now()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_engineer_insurance_register_claim(uuid,text,numeric,text[],text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_insurance_register_claim(uuid,text,numeric,text[],text) TO authenticated;

-- RPC 7: claim status update
CREATE OR REPLACE FUNCTION public.log_founder_engineer_insurance_claim_status(
  p_claim_id uuid,
  p_new_status text,
  p_approved_amount_rupees numeric DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_new_status NOT IN ('submitted','under_review','approved','rejected','paid','disputed') THEN
    RAISE EXCEPTION 'invalid claim status' USING ERRCODE = '22023';
  END IF;
  UPDATE public.founder_engineer_benefits_claims
  SET claim_status = p_new_status,
      approved_amount_rupees = CASE
        WHEN p_new_status IN ('approved','paid') AND p_approved_amount_rupees IS NOT NULL
        THEN p_approved_amount_rupees
        ELSE approved_amount_rupees
      END,
      approved_at = CASE WHEN p_new_status = 'approved' AND approved_at IS NULL THEN now() ELSE approved_at END,
      paid_at = CASE WHEN p_new_status = 'paid' AND paid_at IS NULL THEN now() ELSE paid_at END
  WHERE id = p_claim_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_engineer_insurance_claim_status(uuid,text,numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_insurance_claim_status(uuid,text,numeric) TO authenticated;

COMMIT;