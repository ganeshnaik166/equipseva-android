BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_buyback_r2185 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyback_label text NOT NULL,
  shares_bought_back bigint NOT NULL DEFAULT 0,
  total_cost_rupees bigint NOT NULL DEFAULT 0,
  buyback_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'announced' CHECK (status IN ('announced','in_progress','completed','cancelled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_buyback_action_log_r2185 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyback_id uuid NOT NULL REFERENCES public.investor_cap_table_buyback_r2185(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('announced','executed','cancelled','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_change bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_buyback_r2185 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_buyback_action_log_r2185 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_buyback_r2185 ON public.investor_cap_table_buyback_r2185;
CREATE POLICY founder_all_buyback_r2185 ON public.investor_cap_table_buyback_r2185
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_buyback_actions_r2185 ON public.investor_buyback_action_log_r2185;
CREATE POLICY founder_all_buyback_actions_r2185 ON public.investor_buyback_action_log_r2185
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.list_buybacks_r2185();
CREATE OR REPLACE FUNCTION public.list_buybacks_r2185()
RETURNS TABLE (
  id uuid,
  buyback_label text,
  shares_bought_back bigint,
  total_cost_rupees bigint,
  buyback_date date,
  status text,
  captured_at timestamptz
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
  SELECT b.id, b.buyback_label, b.shares_bought_back, b.total_cost_rupees, b.buyback_date, b.status, b.captured_at
  FROM public.investor_cap_table_buyback_r2185 b
  ORDER BY b.buyback_date DESC, b.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_buybacks_r2185() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_buybacks_r2185() TO authenticated;

DROP FUNCTION IF EXISTS public.log_buyback_r2185(text, bigint, bigint, date, text);
CREATE OR REPLACE FUNCTION public.log_buyback_r2185(
  p_label text,
  p_shares bigint,
  p_cost bigint,
  p_date date,
  p_status text
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
  INSERT INTO public.investor_cap_table_buyback_r2185(buyback_label, shares_bought_back, total_cost_rupees, buyback_date, status)
  VALUES (p_label, COALESCE(p_shares,0), COALESCE(p_cost,0), COALESCE(p_date, CURRENT_DATE), COALESCE(p_status,'announced'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_buyback_r2185', jsonb_build_object('id', v_id, 'label', p_label, 'shares', p_shares));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_buyback_r2185(text, bigint, bigint, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_buyback_r2185(text, bigint, bigint, date, text) TO authenticated;

DROP FUNCTION IF EXISTS public.list_actions_r2185(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2185(p_buyback_id uuid)
RETURNS TABLE (
  id uuid,
  buyback_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_change bigint,
  notes_md text
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
  SELECT a.id, a.buyback_id, a.action_type, a.taken_at, a.by_email, a.shares_change, a.notes_md
  FROM public.investor_buyback_action_log_r2185 a
  WHERE a.buyback_id = p_buyback_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2185(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2185(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_action_r2185(uuid, text, bigint, text);
CREATE OR REPLACE FUNCTION public.log_action_r2185(
  p_buyback_id uuid,
  p_action_type text,
  p_shares_change bigint,
  p_notes text
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
  INSERT INTO public.investor_buyback_action_log_r2185(buyback_id, action_type, by_email, shares_change, notes_md)
  VALUES (p_buyback_id, p_action_type, v_email, COALESCE(p_shares_change,0), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r2185', jsonb_build_object('id', v_id, 'buyback_id', p_buyback_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2185(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2185(uuid, text, bigint, text) TO authenticated;

DROP FUNCTION IF EXISTS public.mark_status_r2185(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2185(p_buyback_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_cap_table_buyback_r2185
  SET status = p_status, updated_at = now()
  WHERE id = p_buyback_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2185', jsonb_build_object('id', p_buyback_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2185(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2185(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.recent_buybacks_r2185(integer);
CREATE OR REPLACE FUNCTION public.recent_buybacks_r2185(p_limit integer)
RETURNS TABLE (
  id uuid,
  buyback_label text,
  shares_bought_back bigint,
  total_cost_rupees bigint,
  buyback_date date,
  status text,
  captured_at timestamptz
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
  SELECT b.id, b.buyback_label, b.shares_bought_back, b.total_cost_rupees, b.buyback_date, b.status, b.captured_at
  FROM public.investor_cap_table_buyback_r2185 b
  ORDER BY b.captured_at DESC
  LIMIT COALESCE(p_limit, 25);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_buybacks_r2185(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_buybacks_r2185(integer) TO authenticated;

DROP FUNCTION IF EXISTS public.recent_actions_r2185(integer);
CREATE OR REPLACE FUNCTION public.recent_actions_r2185(p_limit integer)
RETURNS TABLE (
  id uuid,
  buyback_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_change bigint,
  notes_md text
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
  SELECT a.id, a.buyback_id, a.action_type, a.taken_at, a.by_email, a.shares_change, a.notes_md
  FROM public.investor_buyback_action_log_r2185 a
  ORDER BY a.taken_at DESC
  LIMIT COALESCE(p_limit, 25);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2185(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2185(integer) TO authenticated;

COMMIT;
