BEGIN;

-- =========================================================================
-- Round 1861 — Investor Open Items Tracker
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.investor_open_items_tracker_r1861 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  item_title text NOT NULL,
  request_type text NOT NULL CHECK (request_type IN ('intro_request','info_request','feedback_request','diligence_query','personal_ask')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('critical','high','medium','low')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','blocked')),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_open_items_r1861_investor ON public.investor_open_items_tracker_r1861(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_open_items_r1861_status   ON public.investor_open_items_tracker_r1861(status);
CREATE INDEX IF NOT EXISTS idx_inv_open_items_r1861_priority ON public.investor_open_items_tracker_r1861(priority);

ALTER TABLE public.investor_open_items_tracker_r1861 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_inv_open_items_r1861 ON public.investor_open_items_tracker_r1861;
CREATE POLICY p_founder_all_inv_open_items_r1861
  ON public.investor_open_items_tracker_r1861
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.investor_open_item_updates_r1861 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.investor_open_items_tracker_r1861(id) ON DELETE CASCADE,
  update_at timestamptz NOT NULL DEFAULT now(),
  update_text text NOT NULL,
  by_email text,
  customer_response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_open_item_updates_r1861_item ON public.investor_open_item_updates_r1861(item_id);

ALTER TABLE public.investor_open_item_updates_r1861 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_inv_open_item_updates_r1861 ON public.investor_open_item_updates_r1861;
CREATE POLICY p_founder_all_inv_open_item_updates_r1861
  ON public.investor_open_item_updates_r1861
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_items
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1861_list_items(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  item_title text,
  request_type text,
  requested_at timestamptz,
  priority text,
  status text,
  closed_at timestamptz,
  updates_count int
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
    i.id,
    i.investor_id,
    p.email AS investor_email,
    i.item_title,
    i.request_type,
    i.requested_at,
    i.priority,
    i.status,
    i.closed_at,
    (SELECT COUNT(*) FROM public.investor_open_item_updates_r1861 u WHERE u.item_id = i.id)::int AS updates_count
  FROM public.investor_open_items_tracker_r1861 i
  LEFT JOIN public.profiles p ON p.id = i.investor_id
  WHERE p_status IS NULL OR i.status = p_status
  ORDER BY
    CASE i.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    i.requested_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1861_list_items(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1861_list_items(text) TO authenticated;

-- =========================================================================
-- RPC 2: log_item
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1861_log_item(
  p_investor_id uuid,
  p_item_title text,
  p_request_type text,
  p_priority text DEFAULT 'medium'
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

  INSERT INTO public.investor_open_items_tracker_r1861(investor_id, item_title, request_type, priority)
  VALUES (p_investor_id, p_item_title, p_request_type, COALESCE(p_priority, 'medium'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1861_log_item',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'item_title', p_item_title, 'request_type', p_request_type, 'priority', p_priority));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1861_log_item(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1861_log_item(uuid, text, text, text) TO authenticated;

-- =========================================================================
-- RPC 3: list_updates
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1861_list_updates(p_item_id uuid)
RETURNS TABLE (
  id uuid,
  item_id uuid,
  update_at timestamptz,
  update_text text,
  by_email text,
  customer_response text
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
  SELECT u.id, u.item_id, u.update_at, u.update_text, u.by_email, u.customer_response
  FROM public.investor_open_item_updates_r1861 u
  WHERE u.item_id = p_item_id
  ORDER BY u.update_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1861_list_updates(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1861_list_updates(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: log_update
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1861_log_update(
  p_item_id uuid,
  p_update_text text,
  p_customer_response text DEFAULT NULL
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

  INSERT INTO public.investor_open_item_updates_r1861(item_id, update_text, by_email, customer_response)
  VALUES (p_item_id, p_update_text, v_email, p_customer_response)
  RETURNING id INTO v_id;

  UPDATE public.investor_open_items_tracker_r1861
  SET updated_at = now(),
      status = CASE WHEN status = 'open' THEN 'in_progress' ELSE status END
  WHERE id = p_item_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'r1861_log_update',
    jsonb_build_object('id', v_id, 'item_id', p_item_id, 'update_text', p_update_text));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1861_log_update(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1861_log_update(uuid, text, text) TO authenticated;

-- =========================================================================
-- RPC 5: close_item
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1861_close_item(p_item_id uuid, p_close_note text DEFAULT NULL)
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

  UPDATE public.investor_open_items_tracker_r1861
  SET status = 'closed',
      closed_at = now(),
      updated_at = now()
  WHERE id = p_item_id;

  IF p_close_note IS NOT NULL THEN
    INSERT INTO public.investor_open_item_updates_r1861(item_id, update_text, by_email)
    VALUES (p_item_id, p_close_note, v_email);
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'r1861_close_item',
    jsonb_build_object('item_id', p_item_id, 'close_note', p_close_note));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1861_close_item(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1861_close_item(uuid, text) TO authenticated;

-- =========================================================================
-- RPC 6: open_items_summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1861_open_items_summary()
RETURNS TABLE (
  total_items int,
  open_count int,
  in_progress_count int,
  closed_count int,
  blocked_count int,
  critical_open int,
  high_open int,
  avg_days_to_close numeric
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
    COUNT(*)::int AS total_items,
    (COUNT(*) FILTER (WHERE status = 'open'))::int AS open_count,
    (COUNT(*) FILTER (WHERE status = 'in_progress'))::int AS in_progress_count,
    (COUNT(*) FILTER (WHERE status = 'closed'))::int AS closed_count,
    (COUNT(*) FILTER (WHERE status = 'blocked'))::int AS blocked_count,
    (COUNT(*) FILTER (WHERE status IN ('open','in_progress') AND priority = 'critical'))::int AS critical_open,
    (COUNT(*) FILTER (WHERE status IN ('open','in_progress') AND priority = 'high'))::int AS high_open,
    (AVG(EXTRACT(EPOCH FROM (closed_at - requested_at)) / 86400.0) FILTER (WHERE status = 'closed' AND closed_at IS NOT NULL))::numeric(10,2) AS avg_days_to_close
  FROM public.investor_open_items_tracker_r1861;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1861_open_items_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1861_open_items_summary() TO authenticated;

-- =========================================================================
-- RPC 7: top_priority_open
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1861_top_priority_open(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  item_title text,
  request_type text,
  priority text,
  status text,
  requested_at timestamptz,
  days_open int
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
    i.id,
    i.investor_id,
    p.email AS investor_email,
    i.item_title,
    i.request_type,
    i.priority,
    i.status,
    i.requested_at,
    EXTRACT(DAY FROM (now() - i.requested_at))::int AS days_open
  FROM public.investor_open_items_tracker_r1861 i
  LEFT JOIN public.profiles p ON p.id = i.investor_id
  WHERE i.status IN ('open','in_progress','blocked')
  ORDER BY
    CASE i.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    i.requested_at ASC
  LIMIT COALESCE(p_limit, 10);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1861_top_priority_open(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1861_top_priority_open(int) TO authenticated;

COMMIT;