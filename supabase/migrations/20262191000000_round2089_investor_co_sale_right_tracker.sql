BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_co_sale_rights_r2089 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  co_sale_label text NOT NULL,
  max_co_sale_shares bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exercised','waived','expired')),
  expires_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_co_sale_action_log_r2089 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  right_id uuid NOT NULL REFERENCES public.investor_co_sale_rights_r2089(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('granted','exercised','waived','expired','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_co_sold bigint DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_co_sale_rights_r2089 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_co_sale_action_log_r2089 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_rights_r2089 ON public.investor_co_sale_rights_r2089;
CREATE POLICY founder_all_rights_r2089 ON public.investor_co_sale_rights_r2089
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2089 ON public.investor_co_sale_action_log_r2089;
CREATE POLICY founder_all_actions_r2089 ON public.investor_co_sale_action_log_r2089
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_co_sale_rights_r2089_status ON public.investor_co_sale_rights_r2089(status);
CREATE INDEX IF NOT EXISTS idx_co_sale_rights_r2089_expires ON public.investor_co_sale_rights_r2089(expires_at);
CREATE INDEX IF NOT EXISTS idx_co_sale_actions_r2089_right ON public.investor_co_sale_action_log_r2089(right_id);
CREATE INDEX IF NOT EXISTS idx_co_sale_actions_r2089_taken ON public.investor_co_sale_action_log_r2089(taken_at DESC);

CREATE OR REPLACE FUNCTION public.list_co_sale_rights_r2089()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  co_sale_label text,
  max_co_sale_shares bigint,
  status text,
  expires_at timestamptz,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.investor_id, r.co_sale_label, r.max_co_sale_shares, r.status, r.expires_at, r.captured_at
    FROM public.investor_co_sale_rights_r2089 r
    ORDER BY r.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_co_sale_right_r2089(
  p_investor_id uuid,
  p_co_sale_label text,
  p_max_co_sale_shares bigint,
  p_status text,
  p_expires_at timestamptz
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
  INSERT INTO public.investor_co_sale_rights_r2089(investor_id, co_sale_label, max_co_sale_shares, status, expires_at)
  VALUES (p_investor_id, p_co_sale_label, COALESCE(p_max_co_sale_shares,0), COALESCE(p_status,'active'), p_expires_at)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_co_sale_right_r2089',
    jsonb_build_object('right_id', v_id, 'label', p_co_sale_label, 'shares', p_max_co_sale_shares, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_co_sale_actions_r2089(p_right_id uuid)
RETURNS TABLE (
  id uuid,
  right_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_co_sold bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.right_id, a.action_type, a.taken_at, a.by_email, a.shares_co_sold, a.notes_md
    FROM public.investor_co_sale_action_log_r2089 a
    WHERE a.right_id = p_right_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_co_sale_action_r2089(
  p_right_id uuid,
  p_action_type text,
  p_by_email text,
  p_shares_co_sold bigint,
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
  INSERT INTO public.investor_co_sale_action_log_r2089(right_id, action_type, by_email, shares_co_sold, notes_md)
  VALUES (p_right_id, p_action_type, p_by_email, COALESCE(p_shares_co_sold,0), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_co_sale_action_r2089',
    jsonb_build_object('action_id', v_id, 'right_id', p_right_id, 'action_type', p_action_type, 'shares', p_shares_co_sold));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_co_sale_status_r2089(
  p_right_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_co_sale_rights_r2089
    SET status = p_status, updated_at = now()
    WHERE id = p_right_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_co_sale_status_r2089',
    jsonb_build_object('right_id', p_right_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.co_sale_expiring_soon_r2089()
RETURNS TABLE (
  id uuid,
  co_sale_label text,
  max_co_sale_shares bigint,
  status text,
  expires_at timestamptz,
  days_remaining int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.co_sale_label, r.max_co_sale_shares, r.status, r.expires_at,
      GREATEST(0, EXTRACT(DAY FROM (r.expires_at - now()))::int) AS days_remaining
    FROM public.investor_co_sale_rights_r2089 r
    WHERE r.status = 'active'
      AND r.expires_at IS NOT NULL
      AND r.expires_at <= now() + interval '30 days'
    ORDER BY r.expires_at ASC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_co_sale_actions_r2089()
RETURNS TABLE (
  id uuid,
  right_id uuid,
  co_sale_label text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_co_sold bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.right_id, r.co_sale_label, a.action_type, a.taken_at, a.by_email, a.shares_co_sold
    FROM public.investor_co_sale_action_log_r2089 a
    LEFT JOIN public.investor_co_sale_rights_r2089 r ON r.id = a.right_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_co_sale_rights_r2089() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_co_sale_right_r2089(uuid, text, bigint, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_co_sale_actions_r2089(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_co_sale_action_r2089(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_co_sale_status_r2089(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.co_sale_expiring_soon_r2089() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_co_sale_actions_r2089() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_co_sale_rights_r2089() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_co_sale_right_r2089(uuid, text, bigint, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_co_sale_actions_r2089(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_co_sale_action_r2089(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_co_sale_status_r2089(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.co_sale_expiring_soon_r2089() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_co_sale_actions_r2089() TO authenticated;

COMMIT;
