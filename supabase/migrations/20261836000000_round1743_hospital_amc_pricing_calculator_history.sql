BEGIN;
-- Round 1743 — Hospital AMC Pricing Calculator History
-- Track every AMC quote generated + acceptance rate.


-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_amc_quotes_r1743 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quote_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  base_price_rupees bigint NOT NULL CHECK (base_price_rupees >= 0),
  equipment_count int NOT NULL CHECK (equipment_count >= 0),
  hospital_tier text NOT NULL CHECK (hospital_tier IN ('tier_1','tier_2','tier_3')),
  computed_price_rupees bigint NOT NULL CHECK (computed_price_rupees >= 0),
  discount_applied_pct numeric NOT NULL DEFAULT 0 CHECK (discount_applied_pct >= 0 AND discount_applied_pct <= 100),
  final_price_rupees bigint NOT NULL CHECK (final_price_rupees >= 0),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','accepted','declined','expired')),
  decided_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_amc_quotes_r1743_hospital ON public.hospital_amc_quotes_r1743(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_amc_quotes_r1743_status ON public.hospital_amc_quotes_r1743(status);
CREATE INDEX IF NOT EXISTS idx_amc_quotes_r1743_quote_date ON public.hospital_amc_quotes_r1743(quote_date DESC);
CREATE INDEX IF NOT EXISTS idx_amc_quotes_r1743_tier ON public.hospital_amc_quotes_r1743(hospital_tier);

CREATE TABLE IF NOT EXISTS public.hospital_amc_quote_discounts_r1743 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_id uuid NOT NULL REFERENCES public.hospital_amc_quotes_r1743(id) ON DELETE CASCADE,
  discount_type text NOT NULL CHECK (discount_type IN ('loyalty','volume','founder_override','festival','competitive')),
  discount_pct numeric NOT NULL CHECK (discount_pct >= 0 AND discount_pct <= 100),
  approved_by_email text,
  approved_at timestamptz NOT NULL DEFAULT now(),
  reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_amc_quote_discounts_r1743_quote ON public.hospital_amc_quote_discounts_r1743(quote_id);
CREATE INDEX IF NOT EXISTS idx_amc_quote_discounts_r1743_type ON public.hospital_amc_quote_discounts_r1743(discount_type);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.hospital_amc_quotes_r1743 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_amc_quote_discounts_r1743 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS amc_quotes_r1743_founder_all ON public.hospital_amc_quotes_r1743;
CREATE POLICY amc_quotes_r1743_founder_all ON public.hospital_amc_quotes_r1743
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS amc_quote_discounts_r1743_founder_all ON public.hospital_amc_quote_discounts_r1743;
CREATE POLICY amc_quote_discounts_r1743_founder_all ON public.hospital_amc_quote_discounts_r1743
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_quotes
-- ============================================================

DROP FUNCTION IF EXISTS public.list_quotes_r1743();
CREATE OR REPLACE FUNCTION public.list_quotes_r1743()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  quote_date date,
  base_price_rupees bigint,
  equipment_count int,
  hospital_tier text,
  computed_price_rupees bigint,
  discount_applied_pct numeric,
  final_price_rupees bigint,
  status text,
  decided_at timestamptz,
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
    q.id,
    q.hospital_user_id,
    p.email::text AS hospital_email,
    q.quote_date,
    q.base_price_rupees,
    q.equipment_count,
    q.hospital_tier,
    q.computed_price_rupees,
    q.discount_applied_pct,
    q.final_price_rupees,
    q.status,
    q.decided_at,
    q.notes,
    q.created_at
  FROM public.hospital_amc_quotes_r1743 q
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  ORDER BY q.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_quotes_r1743() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_quotes_r1743() TO authenticated;

-- ============================================================
-- RPC 2: generate_quote
-- ============================================================

DROP FUNCTION IF EXISTS public.generate_quote_r1743(uuid, bigint, int, text, numeric, text);
CREATE OR REPLACE FUNCTION public.generate_quote_r1743(
  p_hospital_user_id uuid,
  p_base_price_rupees bigint,
  p_equipment_count int,
  p_hospital_tier text,
  p_discount_pct numeric DEFAULT 0,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_tier_multiplier numeric;
  v_computed bigint;
  v_final bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_hospital_tier NOT IN ('tier_1','tier_2','tier_3') THEN
    RAISE EXCEPTION 'invalid hospital_tier';
  END IF;

  v_tier_multiplier := CASE p_hospital_tier
    WHEN 'tier_1' THEN 1.25
    WHEN 'tier_2' THEN 1.10
    WHEN 'tier_3' THEN 1.00
  END;

  v_computed := (p_base_price_rupees * p_equipment_count * v_tier_multiplier)::bigint;
  v_final := (v_computed * (100 - COALESCE(p_discount_pct, 0)) / 100)::bigint;

  INSERT INTO public.hospital_amc_quotes_r1743 (
    hospital_user_id, base_price_rupees, equipment_count, hospital_tier,
    computed_price_rupees, discount_applied_pct, final_price_rupees, notes
  ) VALUES (
    p_hospital_user_id, p_base_price_rupees, p_equipment_count, p_hospital_tier,
    v_computed, COALESCE(p_discount_pct, 0), v_final, p_notes
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'generate_quote_r1743',
    jsonb_build_object(
      'quote_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'final_price_rupees', v_final,
      'hospital_tier', p_hospital_tier
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.generate_quote_r1743(uuid, bigint, int, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_quote_r1743(uuid, bigint, int, text, numeric, text) TO authenticated;

-- ============================================================
-- RPC 3: list_discounts
-- ============================================================

DROP FUNCTION IF EXISTS public.list_discounts_r1743();
CREATE OR REPLACE FUNCTION public.list_discounts_r1743()
RETURNS TABLE (
  id uuid,
  quote_id uuid,
  hospital_user_id uuid,
  discount_type text,
  discount_pct numeric,
  approved_by_email text,
  approved_at timestamptz,
  reason text,
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
    d.id,
    d.quote_id,
    q.hospital_user_id,
    d.discount_type,
    d.discount_pct,
    d.approved_by_email,
    d.approved_at,
    d.reason,
    d.created_at
  FROM public.hospital_amc_quote_discounts_r1743 d
  LEFT JOIN public.hospital_amc_quotes_r1743 q ON q.id = d.quote_id
  ORDER BY d.approved_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_discounts_r1743() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_discounts_r1743() TO authenticated;

-- ============================================================
-- RPC 4: apply_discount
-- ============================================================

DROP FUNCTION IF EXISTS public.apply_discount_r1743(uuid, text, numeric, text);
CREATE OR REPLACE FUNCTION public.apply_discount_r1743(
  p_quote_id uuid,
  p_discount_type text,
  p_discount_pct numeric,
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
  v_computed bigint;
  v_new_final bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_discount_type NOT IN ('loyalty','volume','founder_override','festival','competitive') THEN
    RAISE EXCEPTION 'invalid discount_type';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.hospital_amc_quote_discounts_r1743 (
    quote_id, discount_type, discount_pct, approved_by_email, reason
  ) VALUES (
    p_quote_id, p_discount_type, p_discount_pct, v_email, p_reason
  )
  RETURNING id INTO v_id;

  SELECT computed_price_rupees INTO v_computed
  FROM public.hospital_amc_quotes_r1743
  WHERE id = p_quote_id;

  v_new_final := (v_computed * (100 - p_discount_pct) / 100)::bigint;

  UPDATE public.hospital_amc_quotes_r1743
  SET discount_applied_pct = p_discount_pct,
      final_price_rupees = v_new_final,
      updated_at = now()
  WHERE id = p_quote_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'apply_discount_r1743',
    jsonb_build_object(
      'quote_id', p_quote_id,
      'discount_id', v_id,
      'discount_type', p_discount_type,
      'discount_pct', p_discount_pct,
      'new_final_rupees', v_new_final
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_discount_r1743(uuid, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_discount_r1743(uuid, text, numeric, text) TO authenticated;

-- ============================================================
-- RPC 5: mark_decided
-- ============================================================

DROP FUNCTION IF EXISTS public.mark_decided_r1743(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_decided_r1743(
  p_quote_id uuid,
  p_decision text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_decision NOT IN ('sent','accepted','declined','expired') THEN
    RAISE EXCEPTION 'invalid decision';
  END IF;

  UPDATE public.hospital_amc_quotes_r1743
  SET status = p_decision,
      decided_at = CASE WHEN p_decision IN ('accepted','declined','expired') THEN now() ELSE decided_at END,
      updated_at = now()
  WHERE id = p_quote_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_decided_r1743',
    jsonb_build_object(
      'quote_id', p_quote_id,
      'decision', p_decision
    )
  );

  RETURN p_quote_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_decided_r1743(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_decided_r1743(uuid, text) TO authenticated;

-- ============================================================
-- RPC 6: acceptance_rate_summary
-- ============================================================

DROP FUNCTION IF EXISTS public.acceptance_rate_summary_r1743();
CREATE OR REPLACE FUNCTION public.acceptance_rate_summary_r1743()
RETURNS TABLE (
  hospital_tier text,
  total_quotes int,
  pending_count int,
  sent_count int,
  accepted_count int,
  declined_count int,
  expired_count int,
  acceptance_rate_pct numeric,
  avg_final_price_rupees bigint
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
    q.hospital_tier,
    COUNT(*)::int AS total_quotes,
    (COUNT(*) FILTER (WHERE q.status = 'pending'))::int AS pending_count,
    (COUNT(*) FILTER (WHERE q.status = 'sent'))::int AS sent_count,
    (COUNT(*) FILTER (WHERE q.status = 'accepted'))::int AS accepted_count,
    (COUNT(*) FILTER (WHERE q.status = 'declined'))::int AS declined_count,
    (COUNT(*) FILTER (WHERE q.status = 'expired'))::int AS expired_count,
    CASE
      WHEN COUNT(*) FILTER (WHERE q.status IN ('accepted','declined','expired')) = 0 THEN 0
      ELSE ROUND(
        100.0 * (COUNT(*) FILTER (WHERE q.status = 'accepted'))::numeric
              / NULLIF((COUNT(*) FILTER (WHERE q.status IN ('accepted','declined','expired')))::numeric, 0),
        2
      )
    END AS acceptance_rate_pct,
    COALESCE(AVG(q.final_price_rupees)::bigint, 0) AS avg_final_price_rupees
  FROM public.hospital_amc_quotes_r1743 q
  GROUP BY q.hospital_tier
  ORDER BY q.hospital_tier;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.acceptance_rate_summary_r1743() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acceptance_rate_summary_r1743() TO authenticated;

-- ============================================================
-- RPC 7: discount_overuse
-- ============================================================

DROP FUNCTION IF EXISTS public.discount_overuse_r1743();
CREATE OR REPLACE FUNCTION public.discount_overuse_r1743()
RETURNS TABLE (
  discount_type text,
  usage_count int,
  avg_discount_pct numeric,
  max_discount_pct numeric,
  distinct_approvers int,
  last_used_at timestamptz
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
    d.discount_type,
    COUNT(*)::int AS usage_count,
    ROUND(AVG(d.discount_pct)::numeric, 2) AS avg_discount_pct,
    MAX(d.discount_pct) AS max_discount_pct,
    COUNT(DISTINCT d.approved_by_email)::int AS distinct_approvers,
    MAX(d.approved_at) AS last_used_at
  FROM public.hospital_amc_quote_discounts_r1743 d
  GROUP BY d.discount_type
  ORDER BY usage_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.discount_overuse_r1743() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.discount_overuse_r1743() TO authenticated;

COMMIT;