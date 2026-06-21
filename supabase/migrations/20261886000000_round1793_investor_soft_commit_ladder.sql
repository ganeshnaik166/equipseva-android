BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_soft_commits_r1793 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  soft_commit_amount_rupees bigint NOT NULL CHECK (soft_commit_amount_rupees >= 0),
  soft_commit_at timestamptz NOT NULL DEFAULT now(),
  expected_hard_commit_date date,
  current_state text NOT NULL DEFAULT 'soft' CHECK (current_state IN ('soft','escalating','firming','firm','dropped')),
  last_touch_at timestamptz,
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isc_r1793_investor ON public.investor_soft_commits_r1793(investor_id);
CREATE INDEX IF NOT EXISTS idx_isc_r1793_state ON public.investor_soft_commits_r1793(current_state);
CREATE INDEX IF NOT EXISTS idx_isc_r1793_softat ON public.investor_soft_commits_r1793(soft_commit_at DESC);

CREATE TABLE IF NOT EXISTS public.investor_commit_state_changes_r1793 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commit_id uuid NOT NULL REFERENCES public.investor_soft_commits_r1793(id) ON DELETE CASCADE,
  from_state text,
  to_state text NOT NULL,
  change_at timestamptz NOT NULL DEFAULT now(),
  change_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icsc_r1793_commit ON public.investor_commit_state_changes_r1793(commit_id);
CREATE INDEX IF NOT EXISTS idx_icsc_r1793_changeat ON public.investor_commit_state_changes_r1793(change_at DESC);

ALTER TABLE public.investor_soft_commits_r1793 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_commit_state_changes_r1793 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS isc_r1793_founder ON public.investor_soft_commits_r1793;
CREATE POLICY isc_r1793_founder ON public.investor_soft_commits_r1793
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS icsc_r1793_founder ON public.investor_commit_state_changes_r1793;
CREATE POLICY icsc_r1793_founder ON public.investor_commit_state_changes_r1793
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_commits_r1793()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  soft_commit_amount_rupees bigint,
  soft_commit_at timestamptz,
  expected_hard_commit_date date,
  current_state text,
  last_touch_at timestamptz,
  founder_note text
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
    SELECT c.id, c.investor_id, p.email, c.soft_commit_amount_rupees, c.soft_commit_at,
           c.expected_hard_commit_date, c.current_state, c.last_touch_at, c.founder_note
    FROM public.investor_soft_commits_r1793 c
    LEFT JOIN public.profiles p ON p.id = c.investor_id
    ORDER BY c.soft_commit_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_commit_r1793(
  p_investor_id uuid,
  p_amount_rupees bigint,
  p_expected_hard_commit_date date,
  p_founder_note text
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
  INSERT INTO public.investor_soft_commits_r1793(investor_id, soft_commit_amount_rupees, expected_hard_commit_date, founder_note, last_touch_at)
  VALUES (p_investor_id, p_amount_rupees, p_expected_hard_commit_date, p_founder_note, now())
  RETURNING id INTO v_id;

  INSERT INTO public.investor_commit_state_changes_r1793(commit_id, from_state, to_state, change_note)
  VALUES (v_id, NULL, 'soft', 'initial soft commit');

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_commit_r1793',
    jsonb_build_object('commit_id', v_id, 'investor_id', p_investor_id, 'amount', p_amount_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_state_changes_r1793(p_commit_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  commit_id uuid,
  from_state text,
  to_state text,
  change_at timestamptz,
  change_note text
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
    SELECT s.id, s.commit_id, s.from_state, s.to_state, s.change_at, s.change_note
    FROM public.investor_commit_state_changes_r1793 s
    WHERE p_commit_id IS NULL OR s.commit_id = p_commit_id
    ORDER BY s.change_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_state_r1793(
  p_commit_id uuid,
  p_to_state text,
  p_change_note text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_from text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_to_state NOT IN ('soft','escalating','firming','firm','dropped') THEN
    RAISE EXCEPTION 'invalid state';
  END IF;

  SELECT current_state INTO v_from FROM public.investor_soft_commits_r1793 WHERE id = p_commit_id;
  IF v_from IS NULL THEN
    RAISE EXCEPTION 'commit not found';
  END IF;

  UPDATE public.investor_soft_commits_r1793
     SET current_state = p_to_state,
         last_touch_at = now(),
         updated_at = now()
   WHERE id = p_commit_id;

  INSERT INTO public.investor_commit_state_changes_r1793(commit_id, from_state, to_state, change_note)
  VALUES (p_commit_id, v_from, p_to_state, p_change_note);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_state_r1793',
    jsonb_build_object('commit_id', p_commit_id, 'from', v_from, 'to', p_to_state));
END;
$$;

CREATE OR REPLACE FUNCTION public.dropped_commits_r1793()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  soft_commit_amount_rupees bigint,
  soft_commit_at timestamptz,
  last_touch_at timestamptz,
  founder_note text
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
    SELECT c.id, c.investor_id, p.email, c.soft_commit_amount_rupees, c.soft_commit_at,
           c.last_touch_at, c.founder_note
    FROM public.investor_soft_commits_r1793 c
    LEFT JOIN public.profiles p ON p.id = c.investor_id
    WHERE c.current_state = 'dropped'
    ORDER BY c.last_touch_at DESC NULLS LAST
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.total_soft_committed_r1793()
RETURNS TABLE (
  total_soft_rupees bigint,
  total_firm_rupees bigint,
  total_dropped_rupees bigint,
  active_count int,
  firm_count int,
  dropped_count int
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
      COALESCE(SUM(soft_commit_amount_rupees) FILTER (WHERE current_state IN ('soft','escalating','firming')), 0)::bigint,
      COALESCE(SUM(soft_commit_amount_rupees) FILTER (WHERE current_state = 'firm'), 0)::bigint,
      COALESCE(SUM(soft_commit_amount_rupees) FILTER (WHERE current_state = 'dropped'), 0)::bigint,
      (COUNT(*) FILTER (WHERE current_state IN ('soft','escalating','firming')))::int,
      (COUNT(*) FILTER (WHERE current_state = 'firm'))::int,
      (COUNT(*) FILTER (WHERE current_state = 'dropped'))::int
    FROM public.investor_soft_commits_r1793;
END;
$$;

CREATE OR REPLACE FUNCTION public.conversion_funnel_r1793()
RETURNS TABLE (
  state text,
  commit_count int,
  total_rupees bigint
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
    SELECT c.current_state,
           (COUNT(*))::int,
           COALESCE(SUM(c.soft_commit_amount_rupees), 0)::bigint
    FROM public.investor_soft_commits_r1793 c
    GROUP BY c.current_state
    ORDER BY c.current_state;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_commits_r1793() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_commit_r1793(uuid, bigint, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_state_changes_r1793(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_state_r1793(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.dropped_commits_r1793() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_soft_committed_r1793() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.conversion_funnel_r1793() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_commits_r1793() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_commit_r1793(uuid, bigint, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_state_changes_r1793(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_state_r1793(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dropped_commits_r1793() TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_soft_committed_r1793() TO authenticated;
GRANT EXECUTE ON FUNCTION public.conversion_funnel_r1793() TO authenticated;

COMMIT;