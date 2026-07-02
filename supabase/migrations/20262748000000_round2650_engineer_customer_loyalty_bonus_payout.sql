-- r2650 engineer customer loyalty bonus payout

CREATE TABLE IF NOT EXISTS public.engineer_loyalty_bonuses_r2650 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  bonus_kind text NOT NULL CHECK (bonus_kind IN ('retention_save','upsell','csat_5','long_term_relationship','referral_made')),
  bonus_rupees integer NOT NULL CHECK (bonus_rupees >= 0),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'awarded' CHECK (status IN ('awarded','paid','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_loyalty_bonuses_r2650_eng ON public.engineer_loyalty_bonuses_r2650(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_loyalty_bonuses_r2650_hosp ON public.engineer_loyalty_bonuses_r2650(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_loyalty_bonuses_r2650_kind ON public.engineer_loyalty_bonuses_r2650(bonus_kind);
CREATE INDEX IF NOT EXISTS idx_engineer_loyalty_bonuses_r2650_status ON public.engineer_loyalty_bonuses_r2650(status);

ALTER TABLE public.engineer_loyalty_bonuses_r2650 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_loyalty_bonuses_r2650;
CREATE POLICY founder_all ON public.engineer_loyalty_bonuses_r2650
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.loyalty_bonus_payout_log_r2650 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bonus_id uuid NOT NULL REFERENCES public.engineer_loyalty_bonuses_r2650(id) ON DELETE CASCADE,
  paid_at timestamptz NOT NULL DEFAULT now(),
  payout_method text NOT NULL CHECK (payout_method IN ('payroll','cashfree','bank_transfer','cash')),
  payout_proof_ref text,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_loyalty_bonus_payout_log_r2650_bonus ON public.loyalty_bonus_payout_log_r2650(bonus_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_bonus_payout_log_r2650_status ON public.loyalty_bonus_payout_log_r2650(status);
CREATE INDEX IF NOT EXISTS idx_loyalty_bonus_payout_log_r2650_method ON public.loyalty_bonus_payout_log_r2650(payout_method);

ALTER TABLE public.loyalty_bonus_payout_log_r2650 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.loyalty_bonus_payout_log_r2650;
CREATE POLICY founder_all ON public.loyalty_bonus_payout_log_r2650
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
  v_b1 uuid;
  v_b2 uuid;
  v_b3 uuid;
  v_b4 uuid;
  v_b5 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at OFFSET 2 LIMIT 1;
  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_hosp3 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 2 LIMIT 1;

  IF v_eng1 IS NOT NULL AND v_hosp1 IS NOT NULL THEN
    INSERT INTO public.engineer_loyalty_bonuses_r2650 (engineer_user_id, hospital_user_id, awarded_at, bonus_kind, bonus_rupees, owner_email, status, notes)
    VALUES (v_eng1, v_hosp1, '2026-06-10T10:00:00Z'::timestamptz, 'retention_save', 5000, 'finance@equipseva.com', 'paid', 'Saved hospital from churn')
    RETURNING id INTO v_b1;

    INSERT INTO public.engineer_loyalty_bonuses_r2650 (engineer_user_id, hospital_user_id, awarded_at, bonus_kind, bonus_rupees, owner_email, status, notes)
    VALUES (COALESCE(v_eng2, v_eng1), COALESCE(v_hosp2, v_hosp1), '2026-06-12T11:00:00Z'::timestamptz, 'upsell', 3000, 'finance@equipseva.com', 'awarded', 'AMC tier upgrade')
    RETURNING id INTO v_b2;

    INSERT INTO public.engineer_loyalty_bonuses_r2650 (engineer_user_id, hospital_user_id, awarded_at, bonus_kind, bonus_rupees, owner_email, status, notes)
    VALUES (COALESCE(v_eng3, v_eng1), COALESCE(v_hosp3, v_hosp1), '2026-06-15T09:30:00Z'::timestamptz, 'csat_5', 1500, 'ops@equipseva.com', 'paid', 'Five star streak six months')
    RETURNING id INTO v_b3;

    INSERT INTO public.engineer_loyalty_bonuses_r2650 (engineer_user_id, hospital_user_id, awarded_at, bonus_kind, bonus_rupees, owner_email, status, notes)
    VALUES (v_eng1, COALESCE(v_hosp2, v_hosp1), '2026-06-18T14:00:00Z'::timestamptz, 'long_term_relationship', 7500, 'founder@equipseva.com', 'awarded', 'Two year hospital tenure')
    RETURNING id INTO v_b4;

    INSERT INTO public.engineer_loyalty_bonuses_r2650 (engineer_user_id, hospital_user_id, awarded_at, bonus_kind, bonus_rupees, owner_email, status, notes)
    VALUES (COALESCE(v_eng2, v_eng1), v_hosp1, '2026-06-20T16:00:00Z'::timestamptz, 'referral_made', 2500, 'ops@equipseva.com', 'cancelled', 'Referral did not convert')
    RETURNING id INTO v_b5;

    INSERT INTO public.loyalty_bonus_payout_log_r2650 (bonus_id, paid_at, payout_method, payout_proof_ref, owner_email, status, notes)
    VALUES (v_b1, '2026-06-11T10:00:00Z'::timestamptz, 'payroll', 'PAYROLL-JUN-001', 'finance@equipseva.com', 'done', 'Included in June payroll');

    INSERT INTO public.loyalty_bonus_payout_log_r2650 (bonus_id, paid_at, payout_method, payout_proof_ref, owner_email, status, notes)
    VALUES (v_b3, '2026-06-16T10:00:00Z'::timestamptz, 'cashfree', 'CF-TXN-9981', 'finance@equipseva.com', 'done', 'Direct disbursement');

    INSERT INTO public.loyalty_bonus_payout_log_r2650 (bonus_id, paid_at, payout_method, payout_proof_ref, owner_email, status, notes)
    VALUES (v_b2, '2026-06-19T10:00:00Z'::timestamptz, 'bank_transfer', NULL, 'finance@equipseva.com', 'open', 'Awaiting bank confirmation');

    INSERT INTO public.loyalty_bonus_payout_log_r2650 (bonus_id, paid_at, payout_method, payout_proof_ref, owner_email, status, notes)
    VALUES (v_b4, '2026-06-21T10:00:00Z'::timestamptz, 'payroll', NULL, 'founder@equipseva.com', 'open', 'Queued for July payroll');
  END IF;
END
$seed$;

-- RPC 1: list bonuses
CREATE OR REPLACE FUNCTION public.list_bonuses_r2650()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  awarded_at timestamptz,
  bonus_kind text,
  bonus_rupees integer,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.engineer_user_id, b.hospital_user_id, b.awarded_at, b.bonus_kind, b.bonus_rupees, b.owner_email, b.status, b.notes
  FROM public.engineer_loyalty_bonuses_r2650 b
  ORDER BY b.awarded_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_bonuses_r2650() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bonuses_r2650() TO authenticated;

-- RPC 2: list payout log
CREATE OR REPLACE FUNCTION public.list_payout_log_r2650()
RETURNS TABLE (
  id uuid,
  bonus_id uuid,
  paid_at timestamptz,
  payout_method text,
  payout_proof_ref text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.bonus_id, l.paid_at, l.payout_method, l.payout_proof_ref, l.owner_email, l.status, l.notes
  FROM public.loyalty_bonus_payout_log_r2650 l
  ORDER BY l.paid_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_payout_log_r2650() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_payout_log_r2650() TO authenticated;

-- RPC 3: top value focus
CREATE OR REPLACE FUNCTION public.top_value_focus_r2650()
RETURNS TABLE (
  bonus_id uuid,
  bonus_kind text,
  bonus_rupees integer,
  status text,
  awarded_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.bonus_kind, b.bonus_rupees, b.status, b.awarded_at
  FROM public.engineer_loyalty_bonuses_r2650 b
  ORDER BY b.bonus_rupees DESC, b.awarded_at DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_value_focus_r2650() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_focus_r2650() TO authenticated;

-- RPC 4: bonus kind distribution
CREATE OR REPLACE FUNCTION public.bonus_kind_distribution_r2650()
RETURNS TABLE (
  bonus_kind text,
  bonus_count bigint,
  total_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.bonus_kind, COUNT(*)::bigint, COALESCE(SUM(b.bonus_rupees), 0)::bigint
  FROM public.engineer_loyalty_bonuses_r2650 b
  GROUP BY b.bonus_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.bonus_kind_distribution_r2650() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bonus_kind_distribution_r2650() TO authenticated;

-- RPC 5: status funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2650()
RETURNS TABLE (
  status text,
  bonus_count bigint,
  total_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.status, COUNT(*)::bigint, COALESCE(SUM(b.bonus_rupees), 0)::bigint
  FROM public.engineer_loyalty_bonuses_r2650 b
  GROUP BY b.status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2650() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2650() TO authenticated;

-- RPC 6: monthly bonus trend
CREATE OR REPLACE FUNCTION public.monthly_bonus_trend_r2650()
RETURNS TABLE (
  month_label text,
  bonus_count bigint,
  total_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', b.awarded_at), 'YYYY-MM'),
         COUNT(*)::bigint,
         COALESCE(SUM(b.bonus_rupees), 0)::bigint
  FROM public.engineer_loyalty_bonuses_r2650 b
  GROUP BY date_trunc('month', b.awarded_at)
  ORDER BY date_trunc('month', b.awarded_at) DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_bonus_trend_r2650() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_bonus_trend_r2650() TO authenticated;

-- RPC 7: owner load
CREATE OR REPLACE FUNCTION public.owner_load_r2650()
RETURNS TABLE (
  owner_email text,
  bonus_count bigint,
  total_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.owner_email, COUNT(*)::bigint, COALESCE(SUM(b.bonus_rupees), 0)::bigint
  FROM public.engineer_loyalty_bonuses_r2650 b
  GROUP BY b.owner_email
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2650() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2650() TO authenticated;
