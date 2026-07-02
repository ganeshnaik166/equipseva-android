BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_1300_ship_memo_r2126 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  written_at timestamptz NOT NULL DEFAULT now(),
  summary_md text NOT NULL,
  top_lessons_md text,
  next_chapter_md text,
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_1300_ship_reaction_log_r2126 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_1300_ship_memo_r2126(id) ON DELETE CASCADE,
  reactor_email text NOT NULL,
  reactor_role text NOT NULL CHECK (reactor_role IN ('team','investor','customer','external_observer','founder_self')),
  reaction_md text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_1300_ship_memo_r2126 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_1300_ship_reaction_log_r2126 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_memo_r2126 ON public.founder_1300_ship_memo_r2126;
CREATE POLICY founder_all_memo_r2126 ON public.founder_1300_ship_memo_r2126
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_reaction_r2126 ON public.founder_1300_ship_reaction_log_r2126;
CREATE POLICY founder_all_reaction_r2126 ON public.founder_1300_ship_reaction_log_r2126
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_memos_r2126()
RETURNS TABLE(id uuid, milestone_label text, written_at timestamptz, summary_md text, top_lessons_md text, next_chapter_md text, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.id, m.milestone_label, m.written_at, m.summary_md, m.top_lessons_md, m.next_chapter_md, m.status
    FROM public.founder_1300_ship_memo_r2126 m
    ORDER BY m.written_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_memo_r2126(p_label text, p_summary text, p_lessons text, p_next text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_1300_ship_memo_r2126(milestone_label, summary_md, top_lessons_md, next_chapter_md)
    VALUES (p_label, p_summary, p_lessons, p_next) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_memo_r2126', jsonb_build_object('id', v_id, 'label', p_label));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_reactions_r2126(p_memo_id uuid)
RETURNS TABLE(id uuid, reactor_email text, reactor_role text, reaction_md text, recorded_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.reactor_email, r.reactor_role, r.reaction_md, r.recorded_at
    FROM public.founder_1300_ship_reaction_log_r2126 r
    WHERE r.memo_id = p_memo_id
    ORDER BY r.recorded_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_reaction_r2126(p_memo uuid, p_email text, p_role text, p_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_1300_ship_reaction_log_r2126(memo_id, reactor_email, reactor_role, reaction_md)
    VALUES (p_memo, p_email, p_role, p_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reaction_r2126', jsonb_build_object('id', v_id, 'memo', p_memo, 'role', p_role));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2126(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_1300_ship_memo_r2126 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2126', jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.recent_reactions_r2126()
RETURNS TABLE(id uuid, memo_id uuid, milestone_label text, reactor_email text, reactor_role text, reaction_md text, recorded_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.memo_id, m.milestone_label, r.reactor_email, r.reactor_role, r.reaction_md, r.recorded_at
    FROM public.founder_1300_ship_reaction_log_r2126 r
    JOIN public.founder_1300_ship_memo_r2126 m ON m.id = r.memo_id
    ORDER BY r.recorded_at DESC
    LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.top_reactions_r2126()
RETURNS TABLE(reactor_role text, reaction_count bigint, latest_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.reactor_role, COUNT(*)::bigint AS reaction_count, MAX(r.recorded_at) AS latest_at
    FROM public.founder_1300_ship_reaction_log_r2126 r
    GROUP BY r.reactor_role
    ORDER BY COUNT(*) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_memos_r2126() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_memo_r2126(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reactions_r2126(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reaction_r2126(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2126(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reactions_r2126() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_reactions_r2126() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_memos_r2126() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_memo_r2126(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reactions_r2126(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reaction_r2126(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2126(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reactions_r2126() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_reactions_r2126() TO authenticated;

COMMIT;
