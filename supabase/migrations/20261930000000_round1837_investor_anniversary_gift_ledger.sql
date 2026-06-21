BEGIN;

-- ============================================================
-- Round 1837 — Investor Anniversary Gift Ledger
-- Anniversary-gift tracking for big investors (relationship maintenance)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_anniversary_gifts_r1837 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  anniversary_date date NOT NULL,
  gift_type text NOT NULL CHECK (gift_type IN (
    'personal_call','handwritten_note','branded_swag','charity_donation',
    'gift_basket','founder_dinner','family_gift'
  )),
  gift_value_rupees bigint NOT NULL DEFAULT 0,
  ordered_at timestamptz,
  sent_at timestamptz,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN (
    'planned','ordered','sent','declined','skipped'
  )),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_gifts_r1837_investor ON public.investor_anniversary_gifts_r1837(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_gifts_r1837_anniv ON public.investor_anniversary_gifts_r1837(anniversary_date);
CREATE INDEX IF NOT EXISTS idx_inv_gifts_r1837_status ON public.investor_anniversary_gifts_r1837(status);

CREATE TABLE IF NOT EXISTS public.investor_gift_reaction_log_r1837 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gift_id uuid NOT NULL REFERENCES public.investor_anniversary_gifts_r1837(id) ON DELETE CASCADE,
  reaction_received boolean NOT NULL DEFAULT false,
  reaction_summary text,
  photo_received boolean NOT NULL DEFAULT false,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_gift_reactions_r1837_gift ON public.investor_gift_reaction_log_r1837(gift_id);

ALTER TABLE public.investor_anniversary_gifts_r1837 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_gift_reaction_log_r1837 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1837_gifts ON public.investor_anniversary_gifts_r1837;
CREATE POLICY founder_all_r1837_gifts ON public.investor_anniversary_gifts_r1837
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1837_reactions ON public.investor_gift_reaction_log_r1837;
CREATE POLICY founder_all_r1837_reactions ON public.investor_gift_reaction_log_r1837
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_gifts
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_gifts_r1837()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  anniversary_date date,
  gift_type text,
  gift_value_rupees bigint,
  ordered_at timestamptz,
  sent_at timestamptz,
  status text,
  founder_note text,
  reaction_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    g.id, g.investor_id, g.anniversary_date, g.gift_type, g.gift_value_rupees,
    g.ordered_at, g.sent_at, g.status, g.founder_note,
    (SELECT COUNT(*) FROM public.investor_gift_reaction_log_r1837 r WHERE r.gift_id = g.id)::int AS reaction_count,
    g.created_at
  FROM public.investor_anniversary_gifts_r1837 g
  ORDER BY g.anniversary_date DESC, g.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_gifts_r1837() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_gifts_r1837() TO authenticated;

-- ============================================================
-- RPC 2: plan_gift
-- ============================================================
CREATE OR REPLACE FUNCTION public.plan_gift_r1837(
  p_investor_id uuid,
  p_anniversary_date date,
  p_gift_type text,
  p_gift_value_rupees bigint,
  p_founder_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_anniversary_gifts_r1837 (
    investor_id, anniversary_date, gift_type, gift_value_rupees, founder_note, status
  ) VALUES (
    p_investor_id, p_anniversary_date, p_gift_type, COALESCE(p_gift_value_rupees, 0), p_founder_note, 'planned'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'plan_gift_r1837',
    jsonb_build_object(
      'gift_id', v_id,
      'investor_id', p_investor_id,
      'gift_type', p_gift_type,
      'gift_value_rupees', p_gift_value_rupees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.plan_gift_r1837(uuid, date, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plan_gift_r1837(uuid, date, text, bigint, text) TO authenticated;

-- ============================================================
-- RPC 3: list_reactions
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_reactions_r1837(p_gift_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  gift_id uuid,
  reaction_received boolean,
  reaction_summary text,
  photo_received boolean,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT r.id, r.gift_id, r.reaction_received, r.reaction_summary, r.photo_received, r.recorded_at
  FROM public.investor_gift_reaction_log_r1837 r
  WHERE p_gift_id IS NULL OR r.gift_id = p_gift_id
  ORDER BY r.recorded_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reactions_r1837(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reactions_r1837(uuid) TO authenticated;

-- ============================================================
-- RPC 4: log_reaction
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_reaction_r1837(
  p_gift_id uuid,
  p_reaction_received boolean,
  p_reaction_summary text DEFAULT NULL,
  p_photo_received boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_gift_reaction_log_r1837 (
    gift_id, reaction_received, reaction_summary, photo_received
  ) VALUES (
    p_gift_id, COALESCE(p_reaction_received, false), p_reaction_summary, COALESCE(p_photo_received, false)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_reaction_r1837',
    jsonb_build_object(
      'reaction_id', v_id,
      'gift_id', p_gift_id,
      'reaction_received', p_reaction_received,
      'photo_received', p_photo_received
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_reaction_r1837(uuid, boolean, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_reaction_r1837(uuid, boolean, text, boolean) TO authenticated;

-- ============================================================
-- RPC 5: mark_sent
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_sent_r1837(p_gift_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.investor_anniversary_gifts_r1837
  SET status = 'sent', sent_at = now(), updated_at = now()
  WHERE id = p_gift_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_sent_r1837',
    jsonb_build_object('gift_id', p_gift_id)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_sent_r1837(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_sent_r1837(uuid) TO authenticated;

-- ============================================================
-- RPC 6: upcoming_anniversaries
-- ============================================================
CREATE OR REPLACE FUNCTION public.upcoming_anniversaries_r1837(p_days int DEFAULT 60)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  anniversary_date date,
  gift_type text,
  status text,
  days_until int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    g.id, g.investor_id, g.anniversary_date, g.gift_type, g.status,
    (g.anniversary_date - CURRENT_DATE)::int AS days_until
  FROM public.investor_anniversary_gifts_r1837 g
  WHERE g.anniversary_date >= CURRENT_DATE
    AND g.anniversary_date <= CURRENT_DATE + (COALESCE(p_days, 60) || ' days')::interval
    AND g.status IN ('planned','ordered')
  ORDER BY g.anniversary_date ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.upcoming_anniversaries_r1837(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_anniversaries_r1837(int) TO authenticated;

-- ============================================================
-- RPC 7: top_gift_recipients
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_gift_recipients_r1837()
RETURNS TABLE (
  investor_id uuid,
  gift_count int,
  total_value_rupees bigint,
  sent_count int,
  last_gift_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    g.investor_id,
    COUNT(*)::int AS gift_count,
    COALESCE(SUM(g.gift_value_rupees), 0)::bigint AS total_value_rupees,
    (COUNT(*) FILTER (WHERE g.status = 'sent'))::int AS sent_count,
    MAX(g.sent_at) AS last_gift_at
  FROM public.investor_anniversary_gifts_r1837 g
  GROUP BY g.investor_id
  ORDER BY total_value_rupees DESC NULLS LAST
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_gift_recipients_r1837() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_gift_recipients_r1837() TO authenticated;

COMMIT;