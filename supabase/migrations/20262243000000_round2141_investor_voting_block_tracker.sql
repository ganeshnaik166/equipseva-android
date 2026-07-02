BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_voting_block_tracker_r2141 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_label text NOT NULL,
  total_shares_in_block bigint NOT NULL DEFAULT 0,
  member_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'forming' CHECK (status IN ('forming','active','dissolved','superseded')),
  formed_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_voting_block_action_log_r2141 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id uuid NOT NULL REFERENCES public.investor_voting_block_tracker_r2141(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('formed','member_added','member_removed','voted','dissolved')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_voting_block_tracker_r2141 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_voting_block_action_log_r2141 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_blocks_r2141 ON public.investor_voting_block_tracker_r2141;
CREATE POLICY founder_all_blocks_r2141 ON public.investor_voting_block_tracker_r2141
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2141 ON public.investor_voting_block_action_log_r2141;
CREATE POLICY founder_all_actions_r2141 ON public.investor_voting_block_action_log_r2141
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_voting_blocks_r2141()
RETURNS SETOF public.investor_voting_block_tracker_r2141
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_voting_block_tracker_r2141 ORDER BY captured_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_voting_block_r2141(
  p_block_label text,
  p_total_shares_in_block bigint,
  p_member_count int,
  p_status text,
  p_formed_at timestamptz
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
  INSERT INTO public.investor_voting_block_tracker_r2141(block_label, total_shares_in_block, member_count, status, formed_at)
  VALUES (p_block_label, COALESCE(p_total_shares_in_block,0), COALESCE(p_member_count,0), COALESCE(p_status,'forming'), p_formed_at)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_voting_block_r2141',
    jsonb_build_object('id', v_id, 'block_label', p_block_label, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_voting_block_actions_r2141(p_block_id uuid)
RETURNS SETOF public.investor_voting_block_action_log_r2141
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_voting_block_action_log_r2141
    WHERE block_id = p_block_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_voting_block_action_r2141(
  p_block_id uuid,
  p_action_type text,
  p_taken_at timestamptz,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.investor_voting_block_action_log_r2141(block_id, action_type, taken_at, by_email, notes_md)
  VALUES (p_block_id, p_action_type, COALESCE(p_taken_at, now()), p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_voting_block_action_r2141',
    jsonb_build_object('id', v_id, 'block_id', p_block_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_voting_block_status_r2141(
  p_block_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_voting_block_tracker_r2141
    SET status = p_status, updated_at = now()
    WHERE id = p_block_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_voting_block_status_r2141',
    jsonb_build_object('id', p_block_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.active_voting_blocks_r2141()
RETURNS SETOF public.investor_voting_block_tracker_r2141
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_voting_block_tracker_r2141
    WHERE status = 'active' ORDER BY total_shares_in_block DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_voting_block_actions_r2141()
RETURNS SETOF public.investor_voting_block_action_log_r2141
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_voting_block_action_log_r2141
    ORDER BY taken_at DESC LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_voting_blocks_r2141() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_voting_block_r2141(text, bigint, int, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_voting_block_actions_r2141(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_voting_block_action_r2141(uuid, text, timestamptz, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_voting_block_status_r2141(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_voting_blocks_r2141() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_voting_block_actions_r2141() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_voting_blocks_r2141() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_voting_block_r2141(text, bigint, int, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_voting_block_actions_r2141(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_voting_block_action_r2141(uuid, text, timestamptz, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_voting_block_status_r2141(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_voting_blocks_r2141() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_voting_block_actions_r2141() TO authenticated;

COMMIT;
