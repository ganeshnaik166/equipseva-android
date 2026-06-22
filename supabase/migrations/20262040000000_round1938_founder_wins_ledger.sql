BEGIN;

-- ============================================================
-- Round 1938: Founder Wins Ledger
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_wins_ledger_r1938 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  win_label text NOT NULL,
  win_category text NOT NULL CHECK (win_category IN ('product','customer','team','financial','operational','strategic')),
  impact text NOT NULL CHECK (impact IN ('small','medium','large','transformational')),
  win_at timestamptz NOT NULL DEFAULT now(),
  summary_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','celebrated','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_win_celebration_log_r1938 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  win_id uuid NOT NULL REFERENCES public.founder_wins_ledger_r1938(id) ON DELETE CASCADE,
  celebration_type text NOT NULL CHECK (celebration_type IN ('team_share','investor_share','customer_share','personal_note','external_announcement')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  content_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwl_r1938_at ON public.founder_wins_ledger_r1938(win_at DESC);
CREATE INDEX IF NOT EXISTS idx_fwl_r1938_cat ON public.founder_wins_ledger_r1938(win_category);
CREATE INDEX IF NOT EXISTS idx_fwl_r1938_status ON public.founder_wins_ledger_r1938(status);
CREATE INDEX IF NOT EXISTS idx_fwcl_r1938_win ON public.founder_win_celebration_log_r1938(win_id);
CREATE INDEX IF NOT EXISTS idx_fwcl_r1938_at ON public.founder_win_celebration_log_r1938(taken_at DESC);

ALTER TABLE public.founder_wins_ledger_r1938 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_win_celebration_log_r1938 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwl_r1938_founder_all ON public.founder_wins_ledger_r1938;
CREATE POLICY fwl_r1938_founder_all ON public.founder_wins_ledger_r1938
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fwcl_r1938_founder_all ON public.founder_win_celebration_log_r1938;
CREATE POLICY fwcl_r1938_founder_all ON public.founder_win_celebration_log_r1938
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_wins_r1938(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid, win_label text, win_category text, impact text,
  win_at timestamptz, summary_md text, status text, celebration_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT w.id, w.win_label, w.win_category, w.impact, w.win_at, w.summary_md, w.status,
           (SELECT COUNT(*) FROM public.founder_win_celebration_log_r1938 c WHERE c.win_id = w.id) AS celebration_count
    FROM public.founder_wins_ledger_r1938 w
    ORDER BY w.win_at DESC
    LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.log_win_r1938(
  p_label text, p_category text, p_impact text, p_summary text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_wins_ledger_r1938(win_label, win_category, impact, summary_md)
  VALUES (p_label, p_category, p_impact, p_summary) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_win_r1938',
          jsonb_build_object('id', v_id, 'label', p_label, 'category', p_category, 'impact', p_impact));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_celebrations_r1938(p_win_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid, win_id uuid, win_label text, celebration_type text,
  taken_at timestamptz, by_email text, content_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.win_id, w.win_label, c.celebration_type, c.taken_at, c.by_email, c.content_md
    FROM public.founder_win_celebration_log_r1938 c
    JOIN public.founder_wins_ledger_r1938 w ON w.id = c.win_id
    WHERE (p_win_id IS NULL OR c.win_id = p_win_id)
    ORDER BY c.taken_at DESC
    LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.log_celebration_r1938(
  p_win_id uuid, p_type text, p_content text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.founder_win_celebration_log_r1938(win_id, celebration_type, by_email, content_md)
  VALUES (p_win_id, p_type, v_email, p_content) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_celebration_r1938',
          jsonb_build_object('id', v_id, 'win_id', p_win_id, 'type', p_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1938(p_win_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_wins_ledger_r1938 SET status = p_status, updated_at = now()
  WHERE id = p_win_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1938',
          jsonb_build_object('id', p_win_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.top_categories_r1938()
RETURNS TABLE (win_category text, win_count bigint, transformational_count bigint, large_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT w.win_category,
           COUNT(*)::bigint AS win_count,
           SUM(CASE WHEN w.impact = 'transformational' THEN 1 ELSE 0 END)::bigint AS transformational_count,
           SUM(CASE WHEN w.impact = 'large' THEN 1 ELSE 0 END)::bigint AS large_count
    FROM public.founder_wins_ledger_r1938 w
    GROUP BY w.win_category
    ORDER BY win_count DESC;
END $$;

CREATE OR REPLACE FUNCTION public.recent_celebrations_r1938(p_days int DEFAULT 30)
RETURNS TABLE (
  celebration_type text, celebration_count bigint, unique_wins bigint, latest_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.celebration_type,
           COUNT(*)::bigint AS celebration_count,
           COUNT(DISTINCT c.win_id)::bigint AS unique_wins,
           MAX(c.taken_at) AS latest_at
    FROM public.founder_win_celebration_log_r1938 c
    WHERE c.taken_at >= now() - (p_days || ' days')::interval
    GROUP BY c.celebration_type
    ORDER BY celebration_count DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_wins_r1938(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_win_r1938(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_celebrations_r1938(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_celebration_r1938(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1938(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_categories_r1938() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_celebrations_r1938(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_wins_r1938(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_win_r1938(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_celebrations_r1938(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_celebration_r1938(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1938(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_categories_r1938() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_celebrations_r1938(int) TO authenticated;

COMMIT;
