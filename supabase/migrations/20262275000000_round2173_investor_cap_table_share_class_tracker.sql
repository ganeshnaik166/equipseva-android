BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.investor_cap_table_share_class_tracker_r2173 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  share_class_label text NOT NULL CHECK (share_class_label IN ('common','preferred_a','preferred_b','preferred_c','founders','options_pool')),
  total_shares bigint NOT NULL DEFAULT 0,
  conversion_ratio numeric NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','converted','retired')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_share_class_action_log_r2173 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES public.investor_cap_table_share_class_tracker_r2173(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('issued','converted','repurchased','retired','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_change bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.investor_cap_table_share_class_tracker_r2173 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_share_class_action_log_r2173 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_classes_r2173 ON public.investor_cap_table_share_class_tracker_r2173;
CREATE POLICY founder_all_classes_r2173 ON public.investor_cap_table_share_class_tracker_r2173
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2173 ON public.investor_share_class_action_log_r2173;
CREATE POLICY founder_all_actions_r2173 ON public.investor_share_class_action_log_r2173
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_classes
DROP FUNCTION IF EXISTS public.list_classes_r2173();
CREATE OR REPLACE FUNCTION public.list_classes_r2173()
RETURNS TABLE (
  id uuid,
  share_class_label text,
  total_shares bigint,
  conversion_ratio numeric,
  status text,
  captured_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.share_class_label, t.total_shares, t.conversion_ratio, t.status, t.captured_at, t.created_at
  FROM public.investor_cap_table_share_class_tracker_r2173 t
  ORDER BY t.captured_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_classes_r2173() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_classes_r2173() TO authenticated;

-- 2. log_class
DROP FUNCTION IF EXISTS public.log_class_r2173(text, bigint, numeric);
CREATE OR REPLACE FUNCTION public.log_class_r2173(p_label text, p_shares bigint, p_ratio numeric)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_share_class_tracker_r2173(share_class_label, total_shares, conversion_ratio)
  VALUES (p_label, p_shares, p_ratio)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_class_r2173', jsonb_build_object('id', v_id, 'label', p_label, 'shares', p_shares));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_class_r2173(text, bigint, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_class_r2173(text, bigint, numeric) TO authenticated;

-- 3. list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2173();
CREATE OR REPLACE FUNCTION public.list_actions_r2173()
RETURNS TABLE (
  id uuid,
  class_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_change bigint,
  notes_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.class_id, a.action_type, a.taken_at, a.by_email, a.shares_change, a.notes_md, a.created_at
  FROM public.investor_share_class_action_log_r2173 a
  ORDER BY a.taken_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2173() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2173() TO authenticated;

-- 4. log_action
DROP FUNCTION IF EXISTS public.log_action_r2173(uuid, text, bigint, text);
CREATE OR REPLACE FUNCTION public.log_action_r2173(p_class_id uuid, p_action text, p_shares bigint, p_notes text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_share_class_action_log_r2173(class_id, action_type, by_email, shares_change, notes_md)
  VALUES (p_class_id, p_action, (auth.jwt()->>'email'), p_shares, p_notes)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2173', jsonb_build_object('id', v_id, 'class_id', p_class_id, 'action', p_action));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2173(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2173(uuid, text, bigint, text) TO authenticated;

-- 5. mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2173(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2173(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_share_class_tracker_r2173
     SET status = p_status, updated_at = now()
   WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2173', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2173(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2173(uuid, text) TO authenticated;

-- 6. active_classes
DROP FUNCTION IF EXISTS public.active_classes_r2173();
CREATE OR REPLACE FUNCTION public.active_classes_r2173()
RETURNS TABLE (
  id uuid,
  share_class_label text,
  total_shares bigint,
  conversion_ratio numeric,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.share_class_label, t.total_shares, t.conversion_ratio, t.captured_at
  FROM public.investor_cap_table_share_class_tracker_r2173 t
  WHERE t.status = 'active'
  ORDER BY t.total_shares DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.active_classes_r2173() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_classes_r2173() TO authenticated;

-- 7. recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2173();
CREATE OR REPLACE FUNCTION public.recent_actions_r2173()
RETURNS TABLE (
  id uuid,
  class_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  shares_change bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.class_id, a.action_type, a.taken_at, a.by_email, a.shares_change
  FROM public.investor_share_class_action_log_r2173 a
  WHERE a.taken_at >= now() - interval '30 days'
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2173() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2173() TO authenticated;

COMMIT;
