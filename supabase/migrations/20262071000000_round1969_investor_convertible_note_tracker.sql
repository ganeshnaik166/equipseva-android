BEGIN;

-- ============================================================================
-- Round 1969: Investor Convertible Note Tracker
-- ============================================================================

-- Tables ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.investor_convertible_notes_r1969 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  note_label text NOT NULL,
  principal_amount_rupees bigint NOT NULL DEFAULT 0,
  interest_rate_pct numeric NOT NULL DEFAULT 0,
  valuation_cap_rupees bigint NOT NULL DEFAULT 0,
  discount_pct numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','converted','repaid','written_off')),
  issued_at timestamptz NOT NULL DEFAULT now(),
  matures_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_convertible_note_log_r1969 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES public.investor_convertible_notes_r1969(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('issued','interest_accrued','converted','repaid','matured','extended')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icn_r1969_status ON public.investor_convertible_notes_r1969(status);
CREATE INDEX IF NOT EXISTS idx_icn_r1969_investor ON public.investor_convertible_notes_r1969(investor_id);
CREATE INDEX IF NOT EXISTS idx_icn_log_r1969_note ON public.investor_convertible_note_log_r1969(note_id);
CREATE INDEX IF NOT EXISTS idx_icn_log_r1969_taken_at ON public.investor_convertible_note_log_r1969(taken_at DESC);

-- RLS ------------------------------------------------------------------------

ALTER TABLE public.investor_convertible_notes_r1969 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_convertible_note_log_r1969 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_icn_r1969_founder ON public.investor_convertible_notes_r1969;
CREATE POLICY p_icn_r1969_founder ON public.investor_convertible_notes_r1969
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_icn_log_r1969_founder ON public.investor_convertible_note_log_r1969;
CREATE POLICY p_icn_log_r1969_founder ON public.investor_convertible_note_log_r1969
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPCs -----------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.icn_r1969_list_notes();
CREATE OR REPLACE FUNCTION public.icn_r1969_list_notes()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  note_label text,
  principal_amount_rupees bigint,
  interest_rate_pct numeric,
  valuation_cap_rupees bigint,
  discount_pct numeric,
  status text,
  issued_at timestamptz,
  matures_on date
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
  SELECT n.id, n.investor_id, n.note_label, n.principal_amount_rupees,
         n.interest_rate_pct, n.valuation_cap_rupees, n.discount_pct,
         n.status, n.issued_at, n.matures_on
  FROM public.investor_convertible_notes_r1969 n
  ORDER BY n.issued_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.icn_r1969_log_note(uuid, text, bigint, numeric, bigint, numeric, date);
CREATE OR REPLACE FUNCTION public.icn_r1969_log_note(
  p_investor_id uuid,
  p_note_label text,
  p_principal_amount_rupees bigint,
  p_interest_rate_pct numeric,
  p_valuation_cap_rupees bigint,
  p_discount_pct numeric,
  p_matures_on date
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

  INSERT INTO public.investor_convertible_notes_r1969(
    investor_id, note_label, principal_amount_rupees, interest_rate_pct,
    valuation_cap_rupees, discount_pct, matures_on
  ) VALUES (
    p_investor_id, p_note_label, COALESCE(p_principal_amount_rupees,0),
    COALESCE(p_interest_rate_pct,0), COALESCE(p_valuation_cap_rupees,0),
    COALESCE(p_discount_pct,0), p_matures_on
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'icn_r1969_log_note',
    jsonb_build_object('note_id', v_id, 'label', p_note_label, 'principal', p_principal_amount_rupees));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.icn_r1969_list_actions(uuid);
CREATE OR REPLACE FUNCTION public.icn_r1969_list_actions(p_note_id uuid)
RETURNS TABLE (
  id uuid,
  note_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
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
  SELECT l.id, l.note_id, l.action_type, l.taken_at, l.by_email, l.amount_rupees, l.notes_md
  FROM public.investor_convertible_note_log_r1969 l
  WHERE l.note_id = p_note_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.icn_r1969_log_action(uuid, text, bigint, text);
CREATE OR REPLACE FUNCTION public.icn_r1969_log_action(
  p_note_id uuid,
  p_action_type text,
  p_amount_rupees bigint,
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

  v_email := auth.jwt()->>'email';

  INSERT INTO public.investor_convertible_note_log_r1969(
    note_id, action_type, by_email, amount_rupees, notes_md
  ) VALUES (
    p_note_id, p_action_type, v_email, COALESCE(p_amount_rupees,0), p_notes_md
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'icn_r1969_log_action',
    jsonb_build_object('note_id', p_note_id, 'action', p_action_type, 'amount', p_amount_rupees));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.icn_r1969_mark_status(uuid, text);
CREATE OR REPLACE FUNCTION public.icn_r1969_mark_status(p_note_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('active','converted','repaid','written_off') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.investor_convertible_notes_r1969
  SET status = p_status, updated_at = now()
  WHERE id = p_note_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'icn_r1969_mark_status',
    jsonb_build_object('note_id', p_note_id, 'status', p_status));
END;
$$;

DROP FUNCTION IF EXISTS public.icn_r1969_outstanding_principal();
CREATE OR REPLACE FUNCTION public.icn_r1969_outstanding_principal()
RETURNS TABLE (
  status text,
  note_count bigint,
  total_principal_rupees bigint
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
  SELECT n.status,
         COUNT(*)::bigint AS note_count,
         COALESCE(SUM(n.principal_amount_rupees),0)::bigint AS total_principal_rupees
  FROM public.investor_convertible_notes_r1969 n
  GROUP BY n.status
  ORDER BY n.status;
END;
$$;

DROP FUNCTION IF EXISTS public.icn_r1969_recent_actions();
CREATE OR REPLACE FUNCTION public.icn_r1969_recent_actions()
RETURNS TABLE (
  id uuid,
  note_id uuid,
  note_label text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint
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
  SELECT l.id, l.note_id, n.note_label, l.action_type, l.taken_at, l.by_email, l.amount_rupees
  FROM public.investor_convertible_note_log_r1969 l
  JOIN public.investor_convertible_notes_r1969 n ON n.id = l.note_id
  ORDER BY l.taken_at DESC
  LIMIT 100;
END;
$$;

-- Grants ---------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.icn_r1969_list_notes() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.icn_r1969_log_note(uuid, text, bigint, numeric, bigint, numeric, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.icn_r1969_list_actions(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.icn_r1969_log_action(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.icn_r1969_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.icn_r1969_outstanding_principal() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.icn_r1969_recent_actions() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.icn_r1969_list_notes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.icn_r1969_log_note(uuid, text, bigint, numeric, bigint, numeric, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.icn_r1969_list_actions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.icn_r1969_log_action(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.icn_r1969_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.icn_r1969_outstanding_principal() TO authenticated;
GRANT EXECUTE ON FUNCTION public.icn_r1969_recent_actions() TO authenticated;

COMMIT;
