BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_deal_closing_pipeline_r2085 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  deal_label text NOT NULL,
  round_label text,
  target_close_date date,
  amount_committed_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed_won','lost','walked_away','postponed')),
  closed_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_deal_closing_action_log_r2085 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id uuid NOT NULL REFERENCES public.investor_deal_closing_pipeline_r2085(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('term_sheet_signed','legal_drafted','wire_received','closed','lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_deal_closing_pipeline_r2085 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_deal_closing_action_log_r2085 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pipeline_r2085 ON public.investor_deal_closing_pipeline_r2085;
CREATE POLICY founder_all_pipeline_r2085 ON public.investor_deal_closing_pipeline_r2085
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2085 ON public.investor_deal_closing_action_log_r2085;
CREATE POLICY founder_all_action_r2085 ON public.investor_deal_closing_action_log_r2085
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1) list_deals
CREATE OR REPLACE FUNCTION public.list_deals_r2085()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  deal_label text,
  round_label text,
  target_close_date date,
  amount_committed_rupees bigint,
  status text,
  closed_at timestamptz,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.investor_id, p.deal_label, p.round_label, p.target_close_date,
           p.amount_committed_rupees, p.status, p.closed_at, p.captured_at
    FROM public.investor_deal_closing_pipeline_r2085 p
    ORDER BY p.captured_at DESC
    LIMIT 200;
END;
$$;

-- 2) log_deal
CREATE OR REPLACE FUNCTION public.log_deal_r2085(
  p_investor_id uuid,
  p_deal_label text,
  p_round_label text,
  p_target_close_date date,
  p_amount_committed_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_deal_closing_pipeline_r2085 (
    investor_id, deal_label, round_label, target_close_date, amount_committed_rupees
  ) VALUES (
    p_investor_id, p_deal_label, p_round_label, p_target_close_date, COALESCE(p_amount_committed_rupees, 0)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_deal_r2085',
          jsonb_build_object('deal_id', v_id, 'deal_label', p_deal_label, 'amount', p_amount_committed_rupees));
  RETURN v_id;
END;
$$;

-- 3) list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2085(p_deal_id uuid)
RETURNS TABLE (
  id uuid,
  deal_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.deal_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_deal_closing_action_log_r2085 a
    WHERE a.deal_id = p_deal_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

-- 4) log_action
CREATE OR REPLACE FUNCTION public.log_action_r2085(
  p_deal_id uuid,
  p_action_type text,
  p_by_email text,
  p_amount_rupees bigint,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_deal_closing_action_log_r2085 (
    deal_id, action_type, by_email, amount_rupees, notes_md
  ) VALUES (
    p_deal_id, p_action_type, p_by_email, p_amount_rupees, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2085',
          jsonb_build_object('action_id', v_id, 'deal_id', p_deal_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- 5) mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2085(
  p_deal_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','closed_won','lost','walked_away','postponed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_deal_closing_pipeline_r2085
     SET status = p_status,
         closed_at = CASE WHEN p_status IN ('closed_won','lost','walked_away') THEN now() ELSE closed_at END,
         updated_at = now()
   WHERE id = p_deal_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2085',
          jsonb_build_object('deal_id', p_deal_id, 'status', p_status));
END;
$$;

-- 6) active_deals
CREATE OR REPLACE FUNCTION public.active_deals_r2085()
RETURNS TABLE (
  id uuid,
  deal_label text,
  round_label text,
  target_close_date date,
  amount_committed_rupees bigint,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.deal_label, p.round_label, p.target_close_date,
           p.amount_committed_rupees, p.status, p.captured_at
    FROM public.investor_deal_closing_pipeline_r2085 p
    WHERE p.status = 'active'
    ORDER BY p.target_close_date NULLS LAST, p.captured_at DESC
    LIMIT 200;
END;
$$;

-- 7) recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2085()
RETURNS TABLE (
  id uuid,
  deal_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.deal_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_deal_closing_action_log_r2085 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_deals_r2085() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_deal_r2085(uuid, text, text, date, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2085(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2085(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2085(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_deals_r2085() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2085() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_deals_r2085() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_deal_r2085(uuid, text, text, date, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2085(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2085(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2085(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_deals_r2085() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2085() TO authenticated;

COMMIT;
