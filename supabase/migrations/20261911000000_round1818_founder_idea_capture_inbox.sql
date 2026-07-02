BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_idea_capture_inbox_r1818 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idea_title text NOT NULL,
  idea_body_md text,
  source text NOT NULL CHECK (source IN ('shower','walk','customer_call','conversation','random')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  urgency text NOT NULL CHECK (urgency IN ('pulse','important','critical')),
  status text NOT NULL DEFAULT 'inbox' CHECK (status IN ('inbox','triaged','promoted','parked','killed')),
  founder_decision_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_idea_promotion_log_r1818 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idea_id uuid NOT NULL REFERENCES public.founder_idea_capture_inbox_r1818(id) ON DELETE CASCADE,
  promoted_to text NOT NULL CHECK (promoted_to IN ('roadmap','sprint','project','blog_post','talk')),
  promoted_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_idea_capture_inbox_r1818 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_idea_promotion_log_r1818 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_inbox_r1818 ON public.founder_idea_capture_inbox_r1818;
CREATE POLICY founder_all_inbox_r1818 ON public.founder_idea_capture_inbox_r1818
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_promo_r1818 ON public.founder_idea_promotion_log_r1818;
CREATE POLICY founder_all_promo_r1818 ON public.founder_idea_promotion_log_r1818
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_inbox
CREATE OR REPLACE FUNCTION public.list_inbox_r1818()
RETURNS TABLE (
  id uuid,
  idea_title text,
  idea_body_md text,
  source text,
  captured_at timestamptz,
  urgency text,
  status text,
  founder_decision_at timestamptz
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
  SELECT i.id, i.idea_title, i.idea_body_md, i.source, i.captured_at, i.urgency, i.status, i.founder_decision_at
  FROM public.founder_idea_capture_inbox_r1818 i
  ORDER BY i.captured_at DESC
  LIMIT 500;
END;
$$;

-- 2. capture_idea
CREATE OR REPLACE FUNCTION public.capture_idea_r1818(
  p_idea_title text,
  p_idea_body_md text,
  p_source text,
  p_urgency text
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
  INSERT INTO public.founder_idea_capture_inbox_r1818 (idea_title, idea_body_md, source, urgency)
  VALUES (p_idea_title, p_idea_body_md, p_source, p_urgency)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'capture_idea_r1818',
    jsonb_build_object('idea_id', v_id, 'title', p_idea_title, 'source', p_source, 'urgency', p_urgency));

  RETURN v_id;
END;
$$;

-- 3. list_promotions
CREATE OR REPLACE FUNCTION public.list_promotions_r1818()
RETURNS TABLE (
  id uuid,
  idea_id uuid,
  idea_title text,
  promoted_to text,
  promoted_at timestamptz,
  by_email text,
  outcome text
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
  SELECT p.id, p.idea_id, i.idea_title, p.promoted_to, p.promoted_at, p.by_email, p.outcome
  FROM public.founder_idea_promotion_log_r1818 p
  JOIN public.founder_idea_capture_inbox_r1818 i ON i.id = p.idea_id
  ORDER BY p.promoted_at DESC
  LIMIT 500;
END;
$$;

-- 4. log_promotion
CREATE OR REPLACE FUNCTION public.log_promotion_r1818(
  p_idea_id uuid,
  p_promoted_to text,
  p_outcome text
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
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_idea_promotion_log_r1818 (idea_id, promoted_to, by_email, outcome)
  VALUES (p_idea_id, p_promoted_to, v_email, p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.founder_idea_capture_inbox_r1818
  SET status = 'promoted', founder_decision_at = now(), updated_at = now()
  WHERE id = p_idea_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_promotion_r1818',
    jsonb_build_object('idea_id', p_idea_id, 'promoted_to', p_promoted_to, 'outcome', p_outcome));

  RETURN v_id;
END;
$$;

-- 5. triage_idea
CREATE OR REPLACE FUNCTION public.triage_idea_r1818(
  p_idea_id uuid,
  p_new_status text
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
  IF p_new_status NOT IN ('inbox','triaged','promoted','parked','killed') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status;
  END IF;

  UPDATE public.founder_idea_capture_inbox_r1818
  SET status = p_new_status, founder_decision_at = now(), updated_at = now()
  WHERE id = p_idea_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'triage_idea_r1818',
    jsonb_build_object('idea_id', p_idea_id, 'new_status', p_new_status));
END;
$$;

-- 6. recent_promotions (last 30 days)
CREATE OR REPLACE FUNCTION public.recent_promotions_r1818()
RETURNS TABLE (
  id uuid,
  idea_id uuid,
  idea_title text,
  promoted_to text,
  promoted_at timestamptz,
  by_email text,
  outcome text
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
  SELECT p.id, p.idea_id, i.idea_title, p.promoted_to, p.promoted_at, p.by_email, p.outcome
  FROM public.founder_idea_promotion_log_r1818 p
  JOIN public.founder_idea_capture_inbox_r1818 i ON i.id = p.idea_id
  WHERE p.promoted_at >= now() - interval '30 days'
  ORDER BY p.promoted_at DESC;
END;
$$;

-- 7. kill_rate_summary
CREATE OR REPLACE FUNCTION public.kill_rate_summary_r1818()
RETURNS TABLE (
  total_captured int,
  inbox_count int,
  triaged_count int,
  promoted_count int,
  parked_count int,
  killed_count int,
  kill_rate_pct numeric,
  promote_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COUNT(*)::int INTO v_total FROM public.founder_idea_capture_inbox_r1818;

  RETURN QUERY
  SELECT
    v_total AS total_captured,
    (COUNT(*) FILTER (WHERE status = 'inbox'))::int AS inbox_count,
    (COUNT(*) FILTER (WHERE status = 'triaged'))::int AS triaged_count,
    (COUNT(*) FILTER (WHERE status = 'promoted'))::int AS promoted_count,
    (COUNT(*) FILTER (WHERE status = 'parked'))::int AS parked_count,
    (COUNT(*) FILTER (WHERE status = 'killed'))::int AS killed_count,
    CASE WHEN v_total > 0
      THEN ROUND((COUNT(*) FILTER (WHERE status = 'killed'))::numeric * 100.0 / v_total, 2)
      ELSE 0 END AS kill_rate_pct,
    CASE WHEN v_total > 0
      THEN ROUND((COUNT(*) FILTER (WHERE status = 'promoted'))::numeric * 100.0 / v_total, 2)
      ELSE 0 END AS promote_rate_pct
  FROM public.founder_idea_capture_inbox_r1818;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_inbox_r1818() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.capture_idea_r1818(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_promotions_r1818() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_promotion_r1818(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.triage_idea_r1818(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_promotions_r1818() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.kill_rate_summary_r1818() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_inbox_r1818() TO authenticated;
GRANT EXECUTE ON FUNCTION public.capture_idea_r1818(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_promotions_r1818() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_promotion_r1818(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.triage_idea_r1818(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_promotions_r1818() TO authenticated;
GRANT EXECUTE ON FUNCTION public.kill_rate_summary_r1818() TO authenticated;

COMMIT;