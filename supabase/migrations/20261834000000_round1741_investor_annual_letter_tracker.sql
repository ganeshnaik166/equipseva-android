BEGIN;

-- ============================================================
-- Round 1741: Investor Annual Letter Tracker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_annual_letters_r1741 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_year int NOT NULL UNIQUE,
  draft_md text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','under_review','finalized','sent','archived')),
  drafted_at timestamptz,
  finalized_at timestamptz,
  sent_at timestamptz,
  reach_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_annual_letter_reactions_r1741 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  letter_id uuid NOT NULL REFERENCES public.investor_annual_letters_r1741(id) ON DELETE CASCADE,
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL CHECK (reaction IN ('loved_it','positive','neutral','concerned','critical')),
  reaction_note text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ial_r1741_status ON public.investor_annual_letters_r1741(status);
CREATE INDEX IF NOT EXISTS idx_ialr_r1741_letter ON public.investor_annual_letter_reactions_r1741(letter_id);
CREATE INDEX IF NOT EXISTS idx_ialr_r1741_investor ON public.investor_annual_letter_reactions_r1741(investor_id);

ALTER TABLE public.investor_annual_letters_r1741 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_annual_letter_reactions_r1741 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ial_r1741 ON public.investor_annual_letters_r1741;
CREATE POLICY founder_all_ial_r1741 ON public.investor_annual_letters_r1741
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ialr_r1741 ON public.investor_annual_letter_reactions_r1741;
CREATE POLICY founder_all_ialr_r1741 ON public.investor_annual_letter_reactions_r1741
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_letters
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_letters_r1741()
RETURNS TABLE (
  id uuid,
  fiscal_year int,
  status text,
  drafted_at timestamptz,
  finalized_at timestamptz,
  sent_at timestamptz,
  reach_count int,
  reaction_count int
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
    l.fiscal_year,
    l.status,
    l.drafted_at,
    l.finalized_at,
    l.sent_at,
    l.reach_count,
    (SELECT COUNT(*) FROM public.investor_annual_letter_reactions_r1741 r WHERE r.letter_id = l.id)::int AS reaction_count
  FROM public.investor_annual_letters_r1741 l
  ORDER BY l.fiscal_year DESC;
END;
$$;

-- ============================================================
-- RPC 2: draft_letter
-- ============================================================
CREATE OR REPLACE FUNCTION public.draft_letter_r1741(
  p_fiscal_year int,
  p_draft_md text
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

  INSERT INTO public.investor_annual_letters_r1741 (fiscal_year, draft_md, status, drafted_at)
  VALUES (p_fiscal_year, p_draft_md, 'draft', now())
  ON CONFLICT (fiscal_year) DO UPDATE
    SET draft_md = EXCLUDED.draft_md,
        status = 'draft',
        drafted_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'draft_letter_r1741',
    jsonb_build_object('letter_id', v_id, 'fiscal_year', p_fiscal_year)
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: finalize_letter
-- ============================================================
CREATE OR REPLACE FUNCTION public.finalize_letter_r1741(
  p_letter_id uuid
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

  UPDATE public.investor_annual_letters_r1741
  SET status = 'finalized',
      finalized_at = now(),
      updated_at = now()
  WHERE id = p_letter_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'finalize_letter_r1741',
    jsonb_build_object('letter_id', p_letter_id)
  );
END;
$$;

-- ============================================================
-- RPC 4: mark_sent
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_sent_r1741(
  p_letter_id uuid,
  p_reach_count int
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

  UPDATE public.investor_annual_letters_r1741
  SET status = 'sent',
      sent_at = now(),
      reach_count = COALESCE(p_reach_count, 0),
      updated_at = now()
  WHERE id = p_letter_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_sent_r1741',
    jsonb_build_object('letter_id', p_letter_id, 'reach_count', p_reach_count)
  );
END;
$$;

-- ============================================================
-- RPC 5: list_reactions
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_reactions_r1741(
  p_letter_id uuid
)
RETURNS TABLE (
  id uuid,
  letter_id uuid,
  investor_id uuid,
  investor_email text,
  reaction text,
  reaction_note text,
  recorded_at timestamptz
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
    r.id,
    r.letter_id,
    r.investor_id,
    p.email AS investor_email,
    r.reaction,
    r.reaction_note,
    r.recorded_at
  FROM public.investor_annual_letter_reactions_r1741 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  WHERE r.letter_id = p_letter_id
  ORDER BY r.recorded_at DESC;
END;
$$;

-- ============================================================
-- RPC 6: log_reaction
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_reaction_r1741(
  p_letter_id uuid,
  p_investor_id uuid,
  p_reaction text,
  p_reaction_note text
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

  INSERT INTO public.investor_annual_letter_reactions_r1741 (letter_id, investor_id, reaction, reaction_note, recorded_at)
  VALUES (p_letter_id, p_investor_id, p_reaction, p_reaction_note, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_reaction_r1741',
    jsonb_build_object('reaction_id', v_id, 'letter_id', p_letter_id, 'investor_id', p_investor_id, 'reaction', p_reaction)
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 7: reaction_summary_per_letter
-- ============================================================
CREATE OR REPLACE FUNCTION public.reaction_summary_per_letter_r1741()
RETURNS TABLE (
  letter_id uuid,
  fiscal_year int,
  total_reactions int,
  loved_it_count int,
  positive_count int,
  neutral_count int,
  concerned_count int,
  critical_count int
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
    l.id AS letter_id,
    l.fiscal_year,
    (COUNT(r.id))::int AS total_reactions,
    (COUNT(*) FILTER (WHERE r.reaction = 'loved_it'))::int AS loved_it_count,
    (COUNT(*) FILTER (WHERE r.reaction = 'positive'))::int AS positive_count,
    (COUNT(*) FILTER (WHERE r.reaction = 'neutral'))::int AS neutral_count,
    (COUNT(*) FILTER (WHERE r.reaction = 'concerned'))::int AS concerned_count,
    (COUNT(*) FILTER (WHERE r.reaction = 'critical'))::int AS critical_count
  FROM public.investor_annual_letters_r1741 l
  LEFT JOIN public.investor_annual_letter_reactions_r1741 r ON r.letter_id = l.id
  GROUP BY l.id, l.fiscal_year
  ORDER BY l.fiscal_year DESC;
END;
$$;

-- ============================================================
-- Permissions
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_letters_r1741() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.draft_letter_r1741(int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.finalize_letter_r1741(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_sent_r1741(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reactions_r1741(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reaction_r1741(uuid, uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reaction_summary_per_letter_r1741() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_letters_r1741() TO authenticated;
GRANT EXECUTE ON FUNCTION public.draft_letter_r1741(int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_letter_r1741(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_sent_r1741(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reactions_r1741(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reaction_r1741(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reaction_summary_per_letter_r1741() TO authenticated;

COMMIT;