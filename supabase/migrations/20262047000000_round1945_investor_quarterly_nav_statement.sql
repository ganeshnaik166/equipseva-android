BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_quarterly_nav_r1945 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  quarter_label text NOT NULL,
  invested_principal_rupees bigint NOT NULL DEFAULT 0,
  current_nav_rupees bigint NOT NULL DEFAULT 0,
  irr_pct numeric(8,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','acknowledged','disputed')),
  calculated_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_nav_action_log_r1945 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nav_id uuid NOT NULL REFERENCES public.investor_quarterly_nav_r1945(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('sent','acknowledged','dispute_opened','dispute_resolved','restated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_quarterly_nav_r1945 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_nav_action_log_r1945 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_nav_r1945 ON public.investor_quarterly_nav_r1945;
CREATE POLICY founder_all_nav_r1945 ON public.investor_quarterly_nav_r1945
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_nav_log_r1945 ON public.investor_nav_action_log_r1945;
CREATE POLICY founder_all_nav_log_r1945 ON public.investor_nav_action_log_r1945
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- list_navs
CREATE OR REPLACE FUNCTION public.list_navs_r1945()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  quarter_label text,
  invested_principal_rupees bigint,
  current_nav_rupees bigint,
  irr_pct numeric,
  status text,
  calculated_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.investor_id, n.quarter_label, n.invested_principal_rupees,
         n.current_nav_rupees, n.irr_pct, n.status, n.calculated_at, n.sent_at, n.created_at
  FROM public.investor_quarterly_nav_r1945 n
  ORDER BY n.created_at DESC
  LIMIT 200;
END;
$$;

-- log_nav
CREATE OR REPLACE FUNCTION public.log_nav_r1945(
  p_investor_id uuid,
  p_quarter_label text,
  p_invested_principal_rupees bigint,
  p_current_nav_rupees bigint,
  p_irr_pct numeric
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
  INSERT INTO public.investor_quarterly_nav_r1945(
    investor_id, quarter_label, invested_principal_rupees,
    current_nav_rupees, irr_pct, status, calculated_at
  )
  VALUES (p_investor_id, p_quarter_label, p_invested_principal_rupees,
          p_current_nav_rupees, p_irr_pct, 'draft', now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_nav_r1945',
          jsonb_build_object('nav_id', v_id, 'investor_id', p_investor_id,
                             'quarter_label', p_quarter_label,
                             'invested_principal_rupees', p_invested_principal_rupees,
                             'current_nav_rupees', p_current_nav_rupees,
                             'irr_pct', p_irr_pct));
  RETURN v_id;
END;
$$;

-- list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1945(p_nav_id uuid)
RETURNS TABLE (
  id uuid,
  nav_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
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
  SELECT a.id, a.nav_id, a.action_type, a.taken_at, a.by_email, a.notes_md, a.created_at
  FROM public.investor_nav_action_log_r1945 a
  WHERE a.nav_id = p_nav_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- log_action
CREATE OR REPLACE FUNCTION public.log_action_r1945(
  p_nav_id uuid,
  p_action_type text,
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
  INSERT INTO public.investor_nav_action_log_r1945(nav_id, action_type, by_email, notes_md)
  VALUES (p_nav_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1945',
          jsonb_build_object('action_id', v_id, 'nav_id', p_nav_id,
                             'action_type', p_action_type, 'by_email', p_by_email));
  RETURN v_id;
END;
$$;

-- mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1945(
  p_nav_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('draft','sent','acknowledged','disputed') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE public.investor_quarterly_nav_r1945
    SET status = p_status,
        sent_at = CASE WHEN p_status = 'sent' THEN now() ELSE sent_at END,
        updated_at = now()
    WHERE id = p_nav_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1945',
          jsonb_build_object('nav_id', p_nav_id, 'status', p_status));
END;
$$;

-- recent_navs
CREATE OR REPLACE FUNCTION public.recent_navs_r1945()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  quarter_label text,
  current_nav_rupees bigint,
  irr_pct numeric,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.investor_id, n.quarter_label, n.current_nav_rupees,
         n.irr_pct, n.status, n.created_at
  FROM public.investor_quarterly_nav_r1945 n
  ORDER BY n.created_at DESC
  LIMIT 25;
END;
$$;

-- recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r1945()
RETURNS TABLE (
  id uuid,
  nav_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.nav_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_nav_action_log_r1945 a
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_navs_r1945() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_nav_r1945(uuid, text, bigint, bigint, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1945(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1945(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1945(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_navs_r1945() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1945() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_navs_r1945() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_nav_r1945(uuid, text, bigint, bigint, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1945(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1945(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1945(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_navs_r1945() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1945() TO authenticated;

COMMIT;
