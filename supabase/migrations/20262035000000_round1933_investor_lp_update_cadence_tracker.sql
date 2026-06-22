BEGIN;

-- ============================================================================
-- Round 1933 — Investor LP Update Cadence Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_lp_update_cadence_r1933 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  cadence text NOT NULL CHECK (cadence IN ('monthly','quarterly','annual','ad_hoc')),
  last_sent_at timestamptz,
  next_due_date date,
  current_status text NOT NULL DEFAULT 'on_schedule' CHECK (current_status IN ('on_schedule','due','overdue','paused')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_lp_update_send_log_r1933 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cadence_id uuid NOT NULL REFERENCES public.investor_lp_update_cadence_r1933(id) ON DELETE CASCADE,
  send_type text NOT NULL CHECK (send_type IN ('monthly_update','quarterly_review','annual_recap','special_announcement')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  content_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_lp_update_cadence_r1933 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_lp_update_send_log_r1933 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cadence_r1933 ON public.investor_lp_update_cadence_r1933;
CREATE POLICY founder_all_cadence_r1933 ON public.investor_lp_update_cadence_r1933
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_send_log_r1933 ON public.investor_lp_update_send_log_r1933;
CREATE POLICY founder_all_send_log_r1933 ON public.investor_lp_update_send_log_r1933
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_cadences
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_cadences_r1933();
CREATE OR REPLACE FUNCTION public.list_cadences_r1933()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  cadence text,
  last_sent_at timestamptz,
  next_due_date date,
  current_status text,
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
  SELECT c.id, c.investor_id, p.email, c.cadence, c.last_sent_at, c.next_due_date, c.current_status, c.created_at
  FROM public.investor_lp_update_cadence_r1933 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY c.next_due_date NULLS LAST, c.created_at DESC;
END;
$$;

-- ============================================================================
-- RPC 2: log_cadence
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_cadence_r1933(uuid, text, date);
CREATE OR REPLACE FUNCTION public.log_cadence_r1933(
  p_investor_id uuid,
  p_cadence text,
  p_next_due_date date
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

  INSERT INTO public.investor_lp_update_cadence_r1933 (investor_id, cadence, next_due_date)
  VALUES (p_investor_id, p_cadence, p_next_due_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cadence_r1933',
    jsonb_build_object('cadence_id', v_id, 'investor_id', p_investor_id, 'cadence', p_cadence, 'next_due_date', p_next_due_date));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_sends
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_sends_r1933(uuid);
CREATE OR REPLACE FUNCTION public.list_sends_r1933(p_cadence_id uuid)
RETURNS TABLE (
  id uuid,
  cadence_id uuid,
  send_type text,
  sent_at timestamptz,
  by_email text,
  content_url text
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
  SELECT s.id, s.cadence_id, s.send_type, s.sent_at, s.by_email, s.content_url
  FROM public.investor_lp_update_send_log_r1933 s
  WHERE s.cadence_id = p_cadence_id
  ORDER BY s.sent_at DESC;
END;
$$;

-- ============================================================================
-- RPC 4: log_send
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_send_r1933(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_send_r1933(
  p_cadence_id uuid,
  p_send_type text,
  p_by_email text,
  p_content_url text
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

  INSERT INTO public.investor_lp_update_send_log_r1933 (cadence_id, send_type, by_email, content_url)
  VALUES (p_cadence_id, p_send_type, p_by_email, p_content_url)
  RETURNING id INTO v_id;

  UPDATE public.investor_lp_update_cadence_r1933
  SET last_sent_at = now(), updated_at = now()
  WHERE id = p_cadence_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_send_r1933',
    jsonb_build_object('send_id', v_id, 'cadence_id', p_cadence_id, 'send_type', p_send_type));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_status_r1933(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r1933(
  p_cadence_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.investor_lp_update_cadence_r1933
  SET current_status = p_status, updated_at = now()
  WHERE id = p_cadence_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1933',
    jsonb_build_object('cadence_id', p_cadence_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: due_or_overdue
-- ============================================================================
DROP FUNCTION IF EXISTS public.due_or_overdue_r1933();
CREATE OR REPLACE FUNCTION public.due_or_overdue_r1933()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  cadence text,
  next_due_date date,
  days_overdue int,
  current_status text
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
  SELECT c.id, c.investor_id, p.email, c.cadence, c.next_due_date,
    (CURRENT_DATE - c.next_due_date)::int AS days_overdue,
    c.current_status
  FROM public.investor_lp_update_cadence_r1933 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  WHERE c.current_status IN ('due','overdue')
     OR (c.next_due_date IS NOT NULL AND c.next_due_date <= CURRENT_DATE AND c.current_status <> 'paused')
  ORDER BY c.next_due_date ASC NULLS LAST;
END;
$$;

-- ============================================================================
-- RPC 7: recent_sends
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_sends_r1933(int);
CREATE OR REPLACE FUNCTION public.recent_sends_r1933(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  cadence_id uuid,
  investor_email text,
  send_type text,
  sent_at timestamptz,
  by_email text,
  content_url text
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
  SELECT s.id, s.cadence_id, p.email, s.send_type, s.sent_at, s.by_email, s.content_url
  FROM public.investor_lp_update_send_log_r1933 s
  JOIN public.investor_lp_update_cadence_r1933 c ON c.id = s.cadence_id
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY s.sent_at DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_cadences_r1933() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cadences_r1933() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_cadence_r1933(uuid, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_cadence_r1933(uuid, text, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_sends_r1933(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_sends_r1933(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_send_r1933(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_send_r1933(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_status_r1933(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r1933(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.due_or_overdue_r1933() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.due_or_overdue_r1933() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_sends_r1933(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_sends_r1933(int) TO authenticated;

COMMIT;
