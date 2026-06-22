BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_tag_along_rights_r2109 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  tag_along_label text NOT NULL,
  max_tag_along_shares bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exercised','waived','expired')),
  expires_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_tag_along_action_log_r2109 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  right_id uuid NOT NULL REFERENCES public.investor_tag_along_rights_r2109(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('granted','exercised','waived','expired','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_tagged bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_tag_along_rights_r2109 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_tag_along_action_log_r2109 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_rights_r2109 ON public.investor_tag_along_rights_r2109;
CREATE POLICY founder_all_rights_r2109 ON public.investor_tag_along_rights_r2109
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2109 ON public.investor_tag_along_action_log_r2109;
CREATE POLICY founder_all_actions_r2109 ON public.investor_tag_along_action_log_r2109
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1) list_rights
CREATE OR REPLACE FUNCTION public.list_tag_along_rights_r2109(p_limit int DEFAULT 200)
RETURNS TABLE(id uuid, investor_id uuid, tag_along_label text, max_tag_along_shares bigint, status text, expires_at timestamptz, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.investor_id, r.tag_along_label, r.max_tag_along_shares, r.status, r.expires_at, r.captured_at
    FROM public.investor_tag_along_rights_r2109 r
    ORDER BY r.captured_at DESC LIMIT p_limit;
END; $$;

-- 2) log_right
CREATE OR REPLACE FUNCTION public.log_tag_along_right_r2109(p_investor_id uuid, p_label text, p_max_shares bigint, p_expires_at timestamptz)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_tag_along_rights_r2109(investor_id, tag_along_label, max_tag_along_shares, expires_at)
    VALUES (p_investor_id, p_label, COALESCE(p_max_shares,0), p_expires_at)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tag_along_right_r2109',
            jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'label', p_label, 'max_shares', p_max_shares), now());
  RETURN v_id;
END; $$;

-- 3) list_actions
CREATE OR REPLACE FUNCTION public.list_tag_along_actions_r2109(p_right_id uuid, p_limit int DEFAULT 200)
RETURNS TABLE(id uuid, right_id uuid, action_type text, taken_at timestamptz, by_email text, shares_tagged bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.right_id, a.action_type, a.taken_at, a.by_email, a.shares_tagged, a.notes_md
    FROM public.investor_tag_along_action_log_r2109 a
    WHERE p_right_id IS NULL OR a.right_id = p_right_id
    ORDER BY a.taken_at DESC LIMIT p_limit;
END; $$;

-- 4) log_action
CREATE OR REPLACE FUNCTION public.log_tag_along_action_r2109(p_right_id uuid, p_action_type text, p_by_email text, p_shares_tagged bigint, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_tag_along_action_log_r2109(right_id, action_type, by_email, shares_tagged, notes_md)
    VALUES (p_right_id, p_action_type, p_by_email, COALESCE(p_shares_tagged,0), p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tag_along_action_r2109',
            jsonb_build_object('id', v_id, 'right_id', p_right_id, 'action_type', p_action_type, 'shares', p_shares_tagged), now());
  RETURN v_id;
END; $$;

-- 5) mark_status
CREATE OR REPLACE FUNCTION public.mark_tag_along_status_r2109(p_right_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_tag_along_rights_r2109 SET status = p_status, updated_at = now() WHERE id = p_right_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_tag_along_status_r2109',
            jsonb_build_object('right_id', p_right_id, 'status', p_status), now());
END; $$;

-- 6) expiring_soon
CREATE OR REPLACE FUNCTION public.expiring_tag_along_rights_r2109(p_days int DEFAULT 30)
RETURNS TABLE(id uuid, tag_along_label text, status text, expires_at timestamptz, max_tag_along_shares bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.tag_along_label, r.status, r.expires_at, r.max_tag_along_shares
    FROM public.investor_tag_along_rights_r2109 r
    WHERE r.status = 'active' AND r.expires_at IS NOT NULL AND r.expires_at <= now() + (p_days || ' days')::interval
    ORDER BY r.expires_at ASC;
END; $$;

-- 7) recent_actions
CREATE OR REPLACE FUNCTION public.recent_tag_along_actions_r2109(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, right_id uuid, action_type text, taken_at timestamptz, by_email text, shares_tagged bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.right_id, a.action_type, a.taken_at, a.by_email, a.shares_tagged
    FROM public.investor_tag_along_action_log_r2109 a
    ORDER BY a.taken_at DESC LIMIT p_limit;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_tag_along_rights_r2109(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tag_along_right_r2109(uuid, text, bigint, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_tag_along_actions_r2109(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tag_along_action_r2109(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_tag_along_status_r2109(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_tag_along_rights_r2109(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_tag_along_actions_r2109(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tag_along_rights_r2109(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tag_along_right_r2109(uuid, text, bigint, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_tag_along_actions_r2109(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tag_along_action_r2109(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_tag_along_status_r2109(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_tag_along_rights_r2109(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_tag_along_actions_r2109(int) TO authenticated;

COMMIT;
