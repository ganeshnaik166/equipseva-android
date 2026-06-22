BEGIN;

-- Round 2288: Customer Referral Revenue Tracker
-- Track customers acquired via referrals, source customer, lifetime revenue, bonus paid

CREATE TABLE IF NOT EXISTS public.customer_referral_links_r2288 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referred_customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  source_customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referral_code text NOT NULL,
  referral_channel text NOT NULL CHECK (referral_channel IN ('whatsapp','email','direct','event','word_of_mouth')),
  signed_up_at timestamptz NOT NULL DEFAULT now(),
  first_paid_job_at timestamptz,
  lifetime_revenue_paise bigint NOT NULL DEFAULT 0,
  job_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','dormant','churned')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT no_self_referral CHECK (referred_customer_id <> source_customer_id),
  UNIQUE (referred_customer_id)
);

CREATE INDEX IF NOT EXISTS idx_crl_r2288_source ON public.customer_referral_links_r2288 (source_customer_id);
CREATE INDEX IF NOT EXISTS idx_crl_r2288_status ON public.customer_referral_links_r2288 (status);
CREATE INDEX IF NOT EXISTS idx_crl_r2288_signed_up ON public.customer_referral_links_r2288 (signed_up_at DESC);

ALTER TABLE public.customer_referral_links_r2288 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_crl_r2288 ON public.customer_referral_links_r2288;
CREATE POLICY founder_all_crl_r2288 ON public.customer_referral_links_r2288
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_referral_bonus_payouts_r2288 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_link_id uuid NOT NULL REFERENCES public.customer_referral_links_r2288(id) ON DELETE CASCADE,
  source_customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  bonus_amount_paise bigint NOT NULL CHECK (bonus_amount_paise > 0),
  bonus_type text NOT NULL CHECK (bonus_type IN ('signup','first_job','milestone','annual')),
  trigger_revenue_paise bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','paid','rejected')),
  approved_by_email text,
  approved_at timestamptz,
  paid_at timestamptz,
  payment_reference text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crbp_r2288_link ON public.customer_referral_bonus_payouts_r2288 (referral_link_id);
CREATE INDEX IF NOT EXISTS idx_crbp_r2288_source ON public.customer_referral_bonus_payouts_r2288 (source_customer_id);
CREATE INDEX IF NOT EXISTS idx_crbp_r2288_status ON public.customer_referral_bonus_payouts_r2288 (status);

ALTER TABLE public.customer_referral_bonus_payouts_r2288 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_crbp_r2288 ON public.customer_referral_bonus_payouts_r2288;
CREATE POLICY founder_all_crbp_r2288 ON public.customer_referral_bonus_payouts_r2288
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list referral links
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_r2288_list_referral_links()
RETURNS TABLE (
  id uuid,
  referred_customer_id uuid,
  referred_customer_email text,
  source_customer_id uuid,
  source_customer_email text,
  referral_code text,
  referral_channel text,
  signed_up_at timestamptz,
  first_paid_job_at timestamptz,
  lifetime_revenue_paise bigint,
  job_count int,
  status text,
  notes text,
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
    l.id,
    l.referred_customer_id,
    rc.email AS referred_customer_email,
    l.source_customer_id,
    sc.email AS source_customer_email,
    l.referral_code,
    l.referral_channel,
    l.signed_up_at,
    l.first_paid_job_at,
    l.lifetime_revenue_paise,
    l.job_count,
    l.status,
    l.notes,
    l.created_at
  FROM public.customer_referral_links_r2288 l
  LEFT JOIN public.profiles rc ON rc.id = l.referred_customer_id
  LEFT JOIN public.profiles sc ON sc.id = l.source_customer_id
  ORDER BY l.signed_up_at DESC
  LIMIT 500;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2288_list_referral_links() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2288_list_referral_links() TO authenticated;

-- ============================================================
-- RPC 2: list bonus payouts
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_r2288_list_bonus_payouts()
RETURNS TABLE (
  id uuid,
  referral_link_id uuid,
  source_customer_id uuid,
  source_customer_email text,
  bonus_amount_paise bigint,
  bonus_type text,
  trigger_revenue_paise bigint,
  status text,
  approved_by_email text,
  approved_at timestamptz,
  paid_at timestamptz,
  payment_reference text,
  notes text,
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
    p.referral_link_id,
    p.source_customer_id,
    sc.email AS source_customer_email,
    p.bonus_amount_paise,
    p.bonus_type,
    p.trigger_revenue_paise,
    p.status,
    p.approved_by_email,
    p.approved_at,
    p.paid_at,
    p.payment_reference,
    p.notes,
    p.created_at
  FROM public.customer_referral_bonus_payouts_r2288 p
  LEFT JOIN public.profiles sc ON sc.id = p.source_customer_id
  ORDER BY p.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2288_list_bonus_payouts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2288_list_bonus_payouts() TO authenticated;

-- ============================================================
-- RPC 3: top referrers (aggregate by source customer)
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_r2288_top_referrers()
RETURNS TABLE (
  source_customer_id uuid,
  source_customer_email text,
  total_referred int,
  active_referred int,
  total_lifetime_revenue_paise bigint,
  total_bonus_paid_paise bigint,
  bonus_pending_paise bigint
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
    l.source_customer_id,
    sc.email AS source_customer_email,
    COUNT(l.id)::int AS total_referred,
    COUNT(l.id) FILTER (WHERE l.status = 'active')::int AS active_referred,
    COALESCE(SUM(l.lifetime_revenue_paise),0)::bigint AS total_lifetime_revenue_paise,
    COALESCE((
      SELECT SUM(p.bonus_amount_paise)
      FROM public.customer_referral_bonus_payouts_r2288 p
      WHERE p.source_customer_id = l.source_customer_id
        AND p.status = 'paid'
    ),0)::bigint AS total_bonus_paid_paise,
    COALESCE((
      SELECT SUM(p.bonus_amount_paise)
      FROM public.customer_referral_bonus_payouts_r2288 p
      WHERE p.source_customer_id = l.source_customer_id
        AND p.status IN ('pending','approved')
    ),0)::bigint AS bonus_pending_paise
  FROM public.customer_referral_links_r2288 l
  LEFT JOIN public.profiles sc ON sc.id = l.source_customer_id
  GROUP BY l.source_customer_id, sc.email
  ORDER BY total_lifetime_revenue_paise DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2288_top_referrers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2288_top_referrers() TO authenticated;

-- ============================================================
-- RPC 4: program totals
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_r2288_program_totals()
RETURNS TABLE (
  total_links int,
  active_links int,
  pending_links int,
  churned_links int,
  total_lifetime_revenue_paise bigint,
  total_bonus_paid_paise bigint,
  total_bonus_pending_paise bigint,
  unique_referrers int,
  avg_revenue_per_link_paise bigint
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
    (SELECT COUNT(*)::int FROM public.customer_referral_links_r2288),
    (SELECT COUNT(*)::int FROM public.customer_referral_links_r2288 WHERE status = 'active'),
    (SELECT COUNT(*)::int FROM public.customer_referral_links_r2288 WHERE status = 'pending'),
    (SELECT COUNT(*)::int FROM public.customer_referral_links_r2288 WHERE status = 'churned'),
    (SELECT COALESCE(SUM(lifetime_revenue_paise),0)::bigint FROM public.customer_referral_links_r2288),
    (SELECT COALESCE(SUM(bonus_amount_paise),0)::bigint FROM public.customer_referral_bonus_payouts_r2288 WHERE status = 'paid'),
    (SELECT COALESCE(SUM(bonus_amount_paise),0)::bigint FROM public.customer_referral_bonus_payouts_r2288 WHERE status IN ('pending','approved')),
    (SELECT COUNT(DISTINCT source_customer_id)::int FROM public.customer_referral_links_r2288),
    (SELECT COALESCE(AVG(lifetime_revenue_paise),0)::bigint FROM public.customer_referral_links_r2288);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2288_program_totals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2288_program_totals() TO authenticated;

-- ============================================================
-- RPC 5: update link status + lifetime revenue
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_r2288_update_link(
  p_link_id uuid,
  p_status text,
  p_lifetime_revenue_paise bigint,
  p_job_count int,
  p_notes text
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
  IF p_status NOT IN ('pending','active','dormant','churned') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.customer_referral_links_r2288
  SET status = p_status,
      lifetime_revenue_paise = COALESCE(p_lifetime_revenue_paise, lifetime_revenue_paise),
      job_count = COALESCE(p_job_count, job_count),
      notes = COALESCE(p_notes, notes),
      updated_at = now(),
      first_paid_job_at = CASE
        WHEN first_paid_job_at IS NULL AND COALESCE(p_lifetime_revenue_paise,0) > 0 THEN now()
        ELSE first_paid_job_at
      END
  WHERE id = p_link_id
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'link not found';
  END IF;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2288_update_link(uuid, text, bigint, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2288_update_link(uuid, text, bigint, int, text) TO authenticated;

-- ============================================================
-- RPC 6: queue a bonus payout
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_r2288_queue_bonus(
  p_link_id uuid,
  p_bonus_amount_paise bigint,
  p_bonus_type text,
  p_trigger_revenue_paise bigint,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_source uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_bonus_type NOT IN ('signup','first_job','milestone','annual') THEN
    RAISE EXCEPTION 'invalid bonus_type';
  END IF;
  IF p_bonus_amount_paise IS NULL OR p_bonus_amount_paise <= 0 THEN
    RAISE EXCEPTION 'bonus_amount_paise must be positive';
  END IF;
  SELECT source_customer_id INTO v_source
  FROM public.customer_referral_links_r2288 WHERE id = p_link_id;
  IF v_source IS NULL THEN
    RAISE EXCEPTION 'link not found';
  END IF;
  INSERT INTO public.customer_referral_bonus_payouts_r2288 (
    referral_link_id, source_customer_id, bonus_amount_paise, bonus_type,
    trigger_revenue_paise, status, notes
  ) VALUES (
    p_link_id, v_source, p_bonus_amount_paise, p_bonus_type,
    COALESCE(p_trigger_revenue_paise, 0), 'pending', p_notes
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2288_queue_bonus(uuid, bigint, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2288_queue_bonus(uuid, bigint, text, bigint, text) TO authenticated;

-- ============================================================
-- RPC 7: settle bonus payout (approve / pay / reject)
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_r2288_settle_bonus(
  p_bonus_id uuid,
  p_action text,
  p_payment_reference text,
  p_notes text
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
  IF p_action NOT IN ('approve','pay','reject') THEN
    RAISE EXCEPTION 'invalid action';
  END IF;
  v_email := auth.jwt()->>'email';
  IF p_action = 'approve' THEN
    UPDATE public.customer_referral_bonus_payouts_r2288
    SET status = 'approved',
        approved_by_email = v_email,
        approved_at = now(),
        notes = COALESCE(p_notes, notes),
        updated_at = now()
    WHERE id = p_bonus_id AND status = 'pending'
    RETURNING id INTO v_id;
  ELSIF p_action = 'pay' THEN
    UPDATE public.customer_referral_bonus_payouts_r2288
    SET status = 'paid',
        paid_at = now(),
        payment_reference = COALESCE(p_payment_reference, payment_reference),
        notes = COALESCE(p_notes, notes),
        updated_at = now()
    WHERE id = p_bonus_id AND status IN ('pending','approved')
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.customer_referral_bonus_payouts_r2288
    SET status = 'rejected',
        notes = COALESCE(p_notes, notes),
        updated_at = now()
    WHERE id = p_bonus_id AND status IN ('pending','approved')
    RETURNING id INTO v_id;
  END IF;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'bonus not found or invalid state';
  END IF;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2288_settle_bonus(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2288_settle_bonus(uuid, text, text, text) TO authenticated;

COMMIT;
