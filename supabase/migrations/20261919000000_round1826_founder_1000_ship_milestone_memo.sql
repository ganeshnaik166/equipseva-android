BEGIN;

-- ============================================================================
-- Round 1826: Founder 1000-Ship Milestone Memo
-- Auto-curated memo of all 1000 ships shipped (read-only, append on hits)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_milestone_memos_r1826 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_num int NOT NULL UNIQUE,
  milestone_at timestamptz NOT NULL DEFAULT now(),
  summary_md text NOT NULL DEFAULT '',
  top_features text[] NOT NULL DEFAULT '{}'::text[],
  lessons_md text NOT NULL DEFAULT '',
  founder_quote_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_milestone_witnesses_r1826 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_milestone_memos_r1826(id) ON DELETE CASCADE,
  witness_email text NOT NULL,
  witness_role text NOT NULL CHECK (witness_role IN ('team','investor','customer','board')),
  reaction_md text NOT NULL DEFAULT '',
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_milestone_memos_r1826_num
  ON public.founder_milestone_memos_r1826(milestone_num DESC);
CREATE INDEX IF NOT EXISTS idx_milestone_memos_r1826_at
  ON public.founder_milestone_memos_r1826(milestone_at DESC);
CREATE INDEX IF NOT EXISTS idx_milestone_witnesses_r1826_memo
  ON public.founder_milestone_witnesses_r1826(memo_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_milestone_witnesses_r1826_role
  ON public.founder_milestone_witnesses_r1826(witness_role);

ALTER TABLE public.founder_milestone_memos_r1826 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_milestone_witnesses_r1826 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_milestone_memos_r1826_founder ON public.founder_milestone_memos_r1826;
CREATE POLICY p_milestone_memos_r1826_founder
  ON public.founder_milestone_memos_r1826
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_milestone_witnesses_r1826_founder ON public.founder_milestone_witnesses_r1826;
CREATE POLICY p_milestone_witnesses_r1826_founder
  ON public.founder_milestone_witnesses_r1826
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_milestone_memos_r1826 FROM PUBLIC, anon;
REVOKE ALL ON public.founder_milestone_witnesses_r1826 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.founder_milestone_memos_r1826 TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.founder_milestone_witnesses_r1826 TO authenticated;

-- ============================================================================
-- RPCs (7) — all SECDEF, gated by is_founder()
-- ============================================================================

CREATE OR REPLACE FUNCTION public.founder_milestone_list_memos_r1826()
RETURNS TABLE(
  id uuid,
  milestone_num int,
  milestone_at timestamptz,
  summary_md text,
  top_features text[],
  lessons_md text,
  founder_quote_md text,
  witness_count int
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
  SELECT m.id, m.milestone_num, m.milestone_at, m.summary_md, m.top_features,
         m.lessons_md, m.founder_quote_md,
         (SELECT COUNT(*) FROM public.founder_milestone_witnesses_r1826 w WHERE w.memo_id = m.id)::int
    FROM public.founder_milestone_memos_r1826 m
   ORDER BY m.milestone_num DESC
   LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_milestone_list_memos_r1826() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_milestone_list_memos_r1826() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_milestone_log_r1826(
  p_milestone_num int,
  p_summary_md text,
  p_top_features text[],
  p_lessons_md text,
  p_founder_quote_md text
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

  INSERT INTO public.founder_milestone_memos_r1826(
    milestone_num, summary_md, top_features, lessons_md, founder_quote_md
  )
  VALUES (
    p_milestone_num,
    COALESCE(p_summary_md,''),
    COALESCE(p_top_features,'{}'::text[]),
    COALESCE(p_lessons_md,''),
    COALESCE(p_founder_quote_md,'')
  )
  ON CONFLICT (milestone_num) DO UPDATE SET
    summary_md = EXCLUDED.summary_md,
    top_features = EXCLUDED.top_features,
    lessons_md = EXCLUDED.lessons_md,
    founder_quote_md = EXCLUDED.founder_quote_md,
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_milestone_log_r1826',
    jsonb_build_object('milestone_num', p_milestone_num, 'memo_id', v_id)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_milestone_log_r1826(int, text, text[], text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_milestone_log_r1826(int, text, text[], text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_milestone_list_witnesses_r1826(p_memo_id uuid)
RETURNS TABLE(
  id uuid,
  memo_id uuid,
  witness_email text,
  witness_role text,
  reaction_md text,
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
  SELECT w.id, w.memo_id, w.witness_email, w.witness_role, w.reaction_md, w.recorded_at
    FROM public.founder_milestone_witnesses_r1826 w
   WHERE w.memo_id = p_memo_id
   ORDER BY w.recorded_at DESC
   LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_milestone_list_witnesses_r1826(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_milestone_list_witnesses_r1826(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_milestone_add_witness_r1826(
  p_memo_id uuid,
  p_witness_email text,
  p_witness_role text,
  p_reaction_md text
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

  IF p_witness_role NOT IN ('team','investor','customer','board') THEN
    RAISE EXCEPTION 'invalid_role: %', p_witness_role;
  END IF;

  INSERT INTO public.founder_milestone_witnesses_r1826(
    memo_id, witness_email, witness_role, reaction_md
  )
  VALUES (p_memo_id, p_witness_email, p_witness_role, COALESCE(p_reaction_md,''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_milestone_add_witness_r1826',
    jsonb_build_object('memo_id', p_memo_id, 'witness_id', v_id, 'witness_email', p_witness_email, 'witness_role', p_witness_role)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_milestone_add_witness_r1826(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_milestone_add_witness_r1826(uuid, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_milestone_latest_r1826()
RETURNS TABLE(
  id uuid,
  milestone_num int,
  milestone_at timestamptz,
  summary_md text,
  top_features text[],
  lessons_md text,
  founder_quote_md text,
  witness_count int
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
  SELECT m.id, m.milestone_num, m.milestone_at, m.summary_md, m.top_features,
         m.lessons_md, m.founder_quote_md,
         (SELECT COUNT(*) FROM public.founder_milestone_witnesses_r1826 w WHERE w.memo_id = m.id)::int
    FROM public.founder_milestone_memos_r1826 m
   ORDER BY m.milestone_num DESC
   LIMIT 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_milestone_latest_r1826() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_milestone_latest_r1826() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_milestone_year_summary_r1826()
RETURNS TABLE(
  year_label text,
  memo_count int,
  total_witnesses int,
  highest_milestone int,
  first_at timestamptz,
  last_at timestamptz
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
    to_char(date_trunc('year', m.milestone_at), 'YYYY') AS year_label,
    (COUNT(*))::int AS memo_count,
    (COALESCE(SUM((SELECT COUNT(*) FROM public.founder_milestone_witnesses_r1826 w WHERE w.memo_id = m.id)), 0))::int AS total_witnesses,
    (MAX(m.milestone_num))::int AS highest_milestone,
    MIN(m.milestone_at) AS first_at,
    MAX(m.milestone_at) AS last_at
  FROM public.founder_milestone_memos_r1826 m
  GROUP BY date_trunc('year', m.milestone_at)
  ORDER BY date_trunc('year', m.milestone_at) DESC
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_milestone_year_summary_r1826() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_milestone_year_summary_r1826() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_milestone_recent_witnesses_r1826()
RETURNS TABLE(
  id uuid,
  memo_id uuid,
  milestone_num int,
  witness_email text,
  witness_role text,
  reaction_md text,
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
  SELECT w.id, w.memo_id, m.milestone_num, w.witness_email, w.witness_role, w.reaction_md, w.recorded_at
    FROM public.founder_milestone_witnesses_r1826 w
    JOIN public.founder_milestone_memos_r1826 m ON m.id = w.memo_id
   ORDER BY w.recorded_at DESC
   LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_milestone_recent_witnesses_r1826() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_milestone_recent_witnesses_r1826() TO authenticated;

COMMIT;