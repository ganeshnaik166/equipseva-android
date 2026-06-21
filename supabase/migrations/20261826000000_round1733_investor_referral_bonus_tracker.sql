BEGIN;

-- ============================================================================
-- Round 1733 — Investor Referral Bonus Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_referral_bonuses_r1733 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referring_investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referred_investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referral_date date NOT NULL DEFAULT CURRENT_DATE,
  funded_at timestamptz,
  funding_amount_rupees bigint NOT NULL DEFAULT 0,
  bonus_amount_rupees bigint NOT NULL DEFAULT 0,
  bonus_status text NOT NULL DEFAULT 'pending' CHECK (bonus_status IN ('pending','approved','paid','declined')),
  paid_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_referral_communications_r1733 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bonus_id uuid NOT NULL REFERENCES public.investor_referral_bonuses_r1733(id) ON DELETE CASCADE,
  message_type text NOT NULL CHECK (message_type IN ('thanks_email','payout_confirmation','dispute_response')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irb_r1733_referring ON public.investor_referral_bonuses_r1733(referring_investor_id);
CREATE INDEX IF NOT EXISTS idx_irb_r1733_status ON public.investor_referral_bonuses_r1733(bonus_status);
CREATE INDEX IF NOT EXISTS idx_irc_r1733_bonus ON public.investor_referral_communications_r1733(bonus_id);

ALTER TABLE public.investor_referral_bonuses_r1733 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_referral_communications_r1733 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_irb_r1733 ON public.investor_referral_bonuses_r1733;
CREATE POLICY founder_all_irb_r1733 ON public.investor_referral_bonuses_r1733
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_irc_r1733 ON public.investor_referral_communications_r1733;
CREATE POLICY founder_all_irc_r1733 ON public.investor_referral_communications_r1733
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_bonuses
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_bonuses_r1733();
CREATE OR REPLACE FUNCTION public.list_bonuses_r1733()
RETURNS TABLE (
  id uuid,
  referring_email text,
  referred_email text,
  referral_date date,
  funded_at timestamptz,
  funding_amount_rupees bigint,
  bonus_amount_rupees bigint,
  bonus_status text,
  paid_at timestamptz,
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
    b.id,
    p1.email::text AS referring_email,
    p2.email::text AS referred_email,
    b.referral_date,
    b.funded_at,
    b.funding_amount_rupees,
    b.bonus_amount_rupees,
    b.bonus_status,
    b.paid_at,
    b.notes,
    b.created_at
  FROM public.investor_referral_bonuses_r1733 b
  LEFT JOIN public.profiles p1 ON p1.id = b.referring_investor_id
  LEFT JOIN public.profiles p2 ON p2.id = b.referred_investor_id
  ORDER BY b.created_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_referral
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_referral_r1733(uuid, uuid, date, bigint, bigint, text);
CREATE OR REPLACE FUNCTION public.log_referral_r1733(
  p_referring_investor_id uuid,
  p_referred_investor_id uuid,
  p_referral_date date,
  p_funding_amount_rupees bigint,
  p_bonus_amount_rupees bigint,
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
  INSERT INTO public.investor_referral_bonuses_r1733
    (referring_investor_id, referred_investor_id, referral_date, funding_amount_rupees, bonus_amount_rupees, notes)
  VALUES
    (p_referring_investor_id, p_referred_investor_id, COALESCE(p_referral_date, CURRENT_DATE), COALESCE(p_funding_amount_rupees, 0), COALESCE(p_bonus_amount_rupees, 0), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_referral_r1733',
    jsonb_build_object('id', v_id, 'referring', p_referring_investor_id, 'referred', p_referred_investor_id, 'funding', p_funding_amount_rupees, 'bonus', p_bonus_amount_rupees)
  );
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_communications
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_communications_r1733(uuid);
CREATE OR REPLACE FUNCTION public.list_communications_r1733(p_bonus_id uuid)
RETURNS TABLE (
  id uuid,
  bonus_id uuid,
  message_type text,
  sent_at timestamptz,
  by_email text,
  message text
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
  SELECT c.id, c.bonus_id, c.message_type, c.sent_at, c.by_email, c.message
  FROM public.investor_referral_communications_r1733 c
  WHERE p_bonus_id IS NULL OR c.bonus_id = p_bonus_id
  ORDER BY c.sent_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_communication
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_communication_r1733(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_communication_r1733(
  p_bonus_id uuid,
  p_message_type text,
  p_by_email text,
  p_message text
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
  INSERT INTO public.investor_referral_communications_r1733
    (bonus_id, message_type, by_email, message)
  VALUES (p_bonus_id, p_message_type, p_by_email, p_message)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_communication_r1733',
    jsonb_build_object('id', v_id, 'bonus_id', p_bonus_id, 'message_type', p_message_type)
  );
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_bonus_paid
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_bonus_paid_r1733(uuid);
CREATE OR REPLACE FUNCTION public.mark_bonus_paid_r1733(p_bonus_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_referral_bonuses_r1733
  SET bonus_status = 'paid', paid_at = now(), updated_at = now()
  WHERE id = p_bonus_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_bonus_paid_r1733',
    jsonb_build_object('id', p_bonus_id)
  );
END;
$$;

-- ============================================================================
-- RPC 6: bonus_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.bonus_summary_r1733();
CREATE OR REPLACE FUNCTION public.bonus_summary_r1733()
RETURNS TABLE (
  total_bonuses int,
  pending_count int,
  approved_count int,
  paid_count int,
  declined_count int,
  total_funding_rupees bigint,
  total_bonus_paid_rupees bigint,
  total_bonus_pending_rupees bigint
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
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE bonus_status = 'pending'))::int,
    (COUNT(*) FILTER (WHERE bonus_status = 'approved'))::int,
    (COUNT(*) FILTER (WHERE bonus_status = 'paid'))::int,
    (COUNT(*) FILTER (WHERE bonus_status = 'declined'))::int,
    COALESCE(SUM(funding_amount_rupees), 0)::bigint,
    COALESCE(SUM(bonus_amount_rupees) FILTER (WHERE bonus_status = 'paid'), 0)::bigint,
    COALESCE(SUM(bonus_amount_rupees) FILTER (WHERE bonus_status IN ('pending','approved')), 0)::bigint
  FROM public.investor_referral_bonuses_r1733;
END;
$$;

-- ============================================================================
-- RPC 7: top_referring_investors
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_referring_investors_r1733();
CREATE OR REPLACE FUNCTION public.top_referring_investors_r1733()
RETURNS TABLE (
  referring_investor_id uuid,
  referring_email text,
  referral_count int,
  total_funding_rupees bigint,
  total_bonus_rupees bigint,
  paid_bonus_rupees bigint
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
    b.referring_investor_id,
    p.email::text AS referring_email,
    COUNT(*)::int AS referral_count,
    COALESCE(SUM(b.funding_amount_rupees), 0)::bigint AS total_funding_rupees,
    COALESCE(SUM(b.bonus_amount_rupees), 0)::bigint AS total_bonus_rupees,
    COALESCE(SUM(b.bonus_amount_rupees) FILTER (WHERE b.bonus_status = 'paid'), 0)::bigint AS paid_bonus_rupees
  FROM public.investor_referral_bonuses_r1733 b
  LEFT JOIN public.profiles p ON p.id = b.referring_investor_id
  GROUP BY b.referring_investor_id, p.email
  ORDER BY referral_count DESC, total_bonus_rupees DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_bonuses_r1733() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bonuses_r1733() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_referral_r1733(uuid, uuid, date, bigint, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_referral_r1733(uuid, uuid, date, bigint, bigint, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_communications_r1733(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_communications_r1733(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_communication_r1733(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_communication_r1733(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_bonus_paid_r1733(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_bonus_paid_r1733(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.bonus_summary_r1733() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bonus_summary_r1733() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_referring_investors_r1733() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_referring_investors_r1733() TO authenticated;

COMMIT;