BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_quarterly_updates_r1713 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text UNIQUE NOT NULL,
  draft_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','under_review','approved','sent','archived')),
  drafted_at timestamptz,
  drafter_email text,
  approved_at timestamptz,
  approved_by_email text,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_quarterly_update_reviewers_r1713 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  update_id uuid NOT NULL REFERENCES public.investor_quarterly_updates_r1713(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('approve','request_changes','comment','pending')),
  comment_md text,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iqu_r1713_status ON public.investor_quarterly_updates_r1713(status);
CREATE INDEX IF NOT EXISTS idx_iqur_r1713_update ON public.investor_quarterly_update_reviewers_r1713(update_id);

ALTER TABLE public.investor_quarterly_updates_r1713 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_quarterly_update_reviewers_r1713 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_iqu_r1713 ON public.investor_quarterly_updates_r1713;
CREATE POLICY founder_all_iqu_r1713 ON public.investor_quarterly_updates_r1713
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_iqur_r1713 ON public.investor_quarterly_update_reviewers_r1713;
CREATE POLICY founder_all_iqur_r1713 ON public.investor_quarterly_update_reviewers_r1713
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_updates
CREATE OR REPLACE FUNCTION public.list_updates_r1713()
RETURNS TABLE (
  id uuid,
  quarter text,
  status text,
  drafter_email text,
  drafted_at timestamptz,
  approved_at timestamptz,
  approved_by_email text,
  sent_at timestamptz,
  reviewer_count int,
  approve_count int,
  request_changes_count int,
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
    u.id,
    u.quarter,
    u.status,
    u.drafter_email,
    u.drafted_at,
    u.approved_at,
    u.approved_by_email,
    u.sent_at,
    (SELECT (COUNT(*))::int FROM public.investor_quarterly_update_reviewers_r1713 r WHERE r.update_id = u.id),
    (SELECT (COUNT(*))::int FROM public.investor_quarterly_update_reviewers_r1713 r WHERE r.update_id = u.id AND r.decision = 'approve'),
    (SELECT (COUNT(*))::int FROM public.investor_quarterly_update_reviewers_r1713 r WHERE r.update_id = u.id AND r.decision = 'request_changes'),
    u.created_at
  FROM public.investor_quarterly_updates_r1713 u
  ORDER BY u.created_at DESC
  LIMIT 200;
END;
$$;

-- 2. draft_update
CREATE OR REPLACE FUNCTION public.draft_update_r1713(p_quarter text, p_draft_md text)
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
  INSERT INTO public.investor_quarterly_updates_r1713(quarter, draft_md, status, drafted_at, drafter_email)
  VALUES (p_quarter, COALESCE(p_draft_md,''), 'draft', now(), v_email)
  ON CONFLICT (quarter) DO UPDATE
    SET draft_md = EXCLUDED.draft_md,
        status = 'draft',
        drafted_at = now(),
        drafter_email = v_email,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'draft_update_r1713', jsonb_build_object('id', v_id, 'quarter', p_quarter));

  RETURN v_id;
END;
$$;

-- 3. list_reviewers
CREATE OR REPLACE FUNCTION public.list_reviewers_r1713(p_update_id uuid)
RETURNS TABLE (
  id uuid,
  update_id uuid,
  reviewer_email text,
  decision text,
  comment_md text,
  decided_at timestamptz,
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
  SELECT r.id, r.update_id, r.reviewer_email, r.decision, r.comment_md, r.decided_at, r.created_at
  FROM public.investor_quarterly_update_reviewers_r1713 r
  WHERE r.update_id = p_update_id
  ORDER BY r.created_at DESC
  LIMIT 200;
END;
$$;

-- 4. record_decision
CREATE OR REPLACE FUNCTION public.record_decision_r1713(p_update_id uuid, p_reviewer_email text, p_decision text, p_comment_md text)
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
  IF p_decision NOT IN ('approve','request_changes','comment','pending') THEN
    RAISE EXCEPTION 'invalid_decision';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.investor_quarterly_update_reviewers_r1713(update_id, reviewer_email, decision, comment_md, decided_at)
  VALUES (p_update_id, p_reviewer_email, p_decision, p_comment_md, now())
  RETURNING id INTO v_id;

  UPDATE public.investor_quarterly_updates_r1713
    SET status = CASE WHEN status = 'draft' THEN 'under_review' ELSE status END,
        updated_at = now()
    WHERE id = p_update_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'record_decision_r1713', jsonb_build_object('id', v_id, 'update_id', p_update_id, 'decision', p_decision));

  RETURN v_id;
END;
$$;

-- 5. approve_update
CREATE OR REPLACE FUNCTION public.approve_update_r1713(p_update_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  UPDATE public.investor_quarterly_updates_r1713
    SET status = 'approved',
        approved_at = now(),
        approved_by_email = v_email,
        updated_at = now()
    WHERE id = p_update_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'approve_update_r1713', jsonb_build_object('id', p_update_id));
END;
$$;

-- 6. mark_sent
CREATE OR REPLACE FUNCTION public.mark_sent_r1713(p_update_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  UPDATE public.investor_quarterly_updates_r1713
    SET status = 'sent',
        sent_at = now(),
        updated_at = now()
    WHERE id = p_update_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'mark_sent_r1713', jsonb_build_object('id', p_update_id));
END;
$$;

-- 7. latest_update_summary
CREATE OR REPLACE FUNCTION public.latest_update_summary_r1713()
RETURNS TABLE (
  total_updates int,
  draft_count int,
  under_review_count int,
  approved_count int,
  sent_count int,
  archived_count int,
  latest_quarter text,
  latest_status text,
  latest_drafted_at timestamptz,
  latest_sent_at timestamptz
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
    (SELECT (COUNT(*))::int FROM public.investor_quarterly_updates_r1713),
    (SELECT (COUNT(*) FILTER (WHERE status = 'draft'))::int FROM public.investor_quarterly_updates_r1713),
    (SELECT (COUNT(*) FILTER (WHERE status = 'under_review'))::int FROM public.investor_quarterly_updates_r1713),
    (SELECT (COUNT(*) FILTER (WHERE status = 'approved'))::int FROM public.investor_quarterly_updates_r1713),
    (SELECT (COUNT(*) FILTER (WHERE status = 'sent'))::int FROM public.investor_quarterly_updates_r1713),
    (SELECT (COUNT(*) FILTER (WHERE status = 'archived'))::int FROM public.investor_quarterly_updates_r1713),
    (SELECT u.quarter FROM public.investor_quarterly_updates_r1713 u ORDER BY u.created_at DESC LIMIT 1),
    (SELECT u.status FROM public.investor_quarterly_updates_r1713 u ORDER BY u.created_at DESC LIMIT 1),
    (SELECT u.drafted_at FROM public.investor_quarterly_updates_r1713 u ORDER BY u.created_at DESC LIMIT 1),
    (SELECT u.sent_at FROM public.investor_quarterly_updates_r1713 u ORDER BY u.created_at DESC LIMIT 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_updates_r1713() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.draft_update_r1713(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reviewers_r1713(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_decision_r1713(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.approve_update_r1713(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_sent_r1713(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.latest_update_summary_r1713() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_updates_r1713() TO authenticated;
GRANT EXECUTE ON FUNCTION public.draft_update_r1713(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reviewers_r1713(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_decision_r1713(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_update_r1713(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_sent_r1713(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.latest_update_summary_r1713() TO authenticated;

COMMIT;