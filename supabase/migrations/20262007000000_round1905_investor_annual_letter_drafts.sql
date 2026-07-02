BEGIN;

-- Investor Annual Letter Drafts (r1905)

CREATE TABLE IF NOT EXISTS public.investor_annual_letter_drafts_r1905 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year int NOT NULL,
  letter_title text NOT NULL,
  draft_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','under_review','published','archived')),
  target_send_date date,
  drafted_at timestamptz NOT NULL DEFAULT now(),
  drafted_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_letter_revisions_r1905 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  letter_id uuid NOT NULL REFERENCES public.investor_annual_letter_drafts_r1905(id) ON DELETE CASCADE,
  revision_number int NOT NULL,
  revision_md text NOT NULL DEFAULT '',
  revised_at timestamptz NOT NULL DEFAULT now(),
  revised_by_email text,
  revision_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ialdr1905_year ON public.investor_annual_letter_drafts_r1905(year DESC);
CREATE INDEX IF NOT EXISTS idx_ialdr1905_status ON public.investor_annual_letter_drafts_r1905(status);
CREATE INDEX IF NOT EXISTS idx_ilrr1905_letter ON public.investor_letter_revisions_r1905(letter_id, revision_number DESC);

ALTER TABLE public.investor_annual_letter_drafts_r1905 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_letter_revisions_r1905 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ialdr1905_founder ON public.investor_annual_letter_drafts_r1905;
CREATE POLICY p_ialdr1905_founder ON public.investor_annual_letter_drafts_r1905
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_ilrr1905_founder ON public.investor_letter_revisions_r1905;
CREATE POLICY p_ilrr1905_founder ON public.investor_letter_revisions_r1905
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_letters
DROP FUNCTION IF EXISTS public.list_letters_r1905();
CREATE OR REPLACE FUNCTION public.list_letters_r1905()
RETURNS TABLE(id uuid, year int, letter_title text, status text, target_send_date date, drafted_at timestamptz, drafted_by_email text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.year, l.letter_title, l.status, l.target_send_date, l.drafted_at, l.drafted_by_email
  FROM public.investor_annual_letter_drafts_r1905 l
  ORDER BY l.year DESC, l.drafted_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log_letter
DROP FUNCTION IF EXISTS public.log_letter_r1905(int, text, text, text, date);
CREATE OR REPLACE FUNCTION public.log_letter_r1905(
  p_year int,
  p_title text,
  p_draft_md text,
  p_status text,
  p_target_send_date date
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.investor_annual_letter_drafts_r1905(year, letter_title, draft_md, status, target_send_date, drafted_by_email)
  VALUES (p_year, p_title, COALESCE(p_draft_md,''), COALESCE(p_status,'draft'), p_target_send_date, v_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_letter_r1905', jsonb_build_object('id', v_id, 'year', p_year, 'title', p_title));

  RETURN v_id;
END;
$$;

-- RPC 3: list_revisions
DROP FUNCTION IF EXISTS public.list_revisions_r1905(uuid);
CREATE OR REPLACE FUNCTION public.list_revisions_r1905(p_letter_id uuid)
RETURNS TABLE(id uuid, letter_id uuid, revision_number int, revised_at timestamptz, revised_by_email text, revision_note text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.letter_id, r.revision_number, r.revised_at, r.revised_by_email, r.revision_note
  FROM public.investor_letter_revisions_r1905 r
  WHERE r.letter_id = p_letter_id
  ORDER BY r.revision_number DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log_revision
DROP FUNCTION IF EXISTS public.log_revision_r1905(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_revision_r1905(
  p_letter_id uuid,
  p_revision_md text,
  p_revision_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
  v_next int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');

  SELECT COALESCE(MAX(revision_number),0) + 1 INTO v_next
  FROM public.investor_letter_revisions_r1905 WHERE letter_id = p_letter_id;

  INSERT INTO public.investor_letter_revisions_r1905(letter_id, revision_number, revision_md, revised_by_email, revision_note)
  VALUES (p_letter_id, v_next, COALESCE(p_revision_md,''), v_email, p_revision_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_revision_r1905', jsonb_build_object('id', v_id, 'letter_id', p_letter_id, 'revision_number', v_next));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_published
DROP FUNCTION IF EXISTS public.mark_published_r1905(uuid);
CREATE OR REPLACE FUNCTION public.mark_published_r1905(p_letter_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');

  UPDATE public.investor_annual_letter_drafts_r1905
  SET status = 'published', updated_at = now()
  WHERE id = p_letter_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'mark_published_r1905', jsonb_build_object('id', p_letter_id));
END;
$$;

-- RPC 6: recent_letters
DROP FUNCTION IF EXISTS public.recent_letters_r1905();
CREATE OR REPLACE FUNCTION public.recent_letters_r1905()
RETURNS TABLE(id uuid, year int, letter_title text, status text, drafted_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.year, l.letter_title, l.status, l.drafted_at
  FROM public.investor_annual_letter_drafts_r1905 l
  WHERE l.drafted_at > now() - interval '180 days'
  ORDER BY l.drafted_at DESC
  LIMIT 50;
END;
$$;

-- RPC 7: letters_needing_review
DROP FUNCTION IF EXISTS public.letters_needing_review_r1905();
CREATE OR REPLACE FUNCTION public.letters_needing_review_r1905()
RETURNS TABLE(id uuid, year int, letter_title text, status text, target_send_date date, drafted_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.year, l.letter_title, l.status, l.target_send_date, l.drafted_at
  FROM public.investor_annual_letter_drafts_r1905 l
  WHERE l.status IN ('draft','under_review')
  ORDER BY COALESCE(l.target_send_date, CURRENT_DATE + 365) ASC, l.drafted_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_letters_r1905() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_letter_r1905(int, text, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_revisions_r1905(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_revision_r1905(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_published_r1905(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_letters_r1905() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.letters_needing_review_r1905() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_letters_r1905() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_letter_r1905(int, text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_revisions_r1905(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_revision_r1905(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_published_r1905(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_letters_r1905() TO authenticated;
GRANT EXECUTE ON FUNCTION public.letters_needing_review_r1905() TO authenticated;

COMMIT;
