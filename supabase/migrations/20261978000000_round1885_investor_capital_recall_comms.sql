BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_capital_recall_comms_r1885 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  comm_type text NOT NULL CHECK (comm_type IN ('pre_recall_notice','recall_event','recall_completed','recall_disputed')),
  message_md text NOT NULL,
  sent_at timestamptz,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','acknowledged','disputed','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_recall_comm_responses_r1885 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  comm_id uuid NOT NULL REFERENCES public.investor_capital_recall_comms_r1885(id) ON DELETE CASCADE,
  response_text text NOT NULL,
  response_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  attachment_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_capital_recall_comms_r1885 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_recall_comm_responses_r1885 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_recall_comms_r1885 ON public.investor_capital_recall_comms_r1885;
CREATE POLICY founder_all_recall_comms_r1885 ON public.investor_capital_recall_comms_r1885
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_recall_responses_r1885 ON public.investor_recall_comm_responses_r1885;
CREATE POLICY founder_all_recall_responses_r1885 ON public.investor_recall_comm_responses_r1885
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_recall_comms_r1885_investor ON public.investor_capital_recall_comms_r1885(investor_id);
CREATE INDEX IF NOT EXISTS idx_recall_comms_r1885_sent_at ON public.investor_capital_recall_comms_r1885(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_recall_responses_r1885_comm ON public.investor_recall_comm_responses_r1885(comm_id);

-- RPC 1: list_comms
DROP FUNCTION IF EXISTS public.list_recall_comms_r1885();
CREATE OR REPLACE FUNCTION public.list_recall_comms_r1885()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  comm_type text,
  message_md text,
  sent_at timestamptz,
  status text,
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
    SELECT c.id, c.investor_id, p.email::text, c.comm_type, c.message_md, c.sent_at, c.status, c.created_at
      FROM public.investor_capital_recall_comms_r1885 c
      LEFT JOIN public.profiles p ON p.id = c.investor_id
     ORDER BY c.created_at DESC
     LIMIT 200;
END;
$$;

-- RPC 2: send_comm
DROP FUNCTION IF EXISTS public.send_recall_comm_r1885(uuid, text, text);
CREATE OR REPLACE FUNCTION public.send_recall_comm_r1885(p_investor_id uuid, p_comm_type text, p_message_md text)
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
  INSERT INTO public.investor_capital_recall_comms_r1885(investor_id, comm_type, message_md, sent_at, status)
    VALUES (p_investor_id, p_comm_type, p_message_md, now(), 'sent')
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'send_recall_comm_r1885',
            jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'comm_type', p_comm_type));
  RETURN v_id;
END;
$$;

-- RPC 3: list_responses
DROP FUNCTION IF EXISTS public.list_recall_comm_responses_r1885(uuid);
CREATE OR REPLACE FUNCTION public.list_recall_comm_responses_r1885(p_comm_id uuid)
RETURNS TABLE (
  id uuid,
  comm_id uuid,
  response_text text,
  response_at timestamptz,
  by_email text,
  attachment_url text
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
    SELECT r.id, r.comm_id, r.response_text, r.response_at, r.by_email, r.attachment_url
      FROM public.investor_recall_comm_responses_r1885 r
     WHERE r.comm_id = p_comm_id
     ORDER BY r.response_at DESC;
END;
$$;

-- RPC 4: log_response
DROP FUNCTION IF EXISTS public.log_recall_comm_response_r1885(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_recall_comm_response_r1885(p_comm_id uuid, p_response_text text, p_by_email text, p_attachment_url text)
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
  INSERT INTO public.investor_recall_comm_responses_r1885(comm_id, response_text, by_email, attachment_url)
    VALUES (p_comm_id, p_response_text, p_by_email, p_attachment_url)
    RETURNING id INTO v_id;
  UPDATE public.investor_capital_recall_comms_r1885
     SET status = 'acknowledged', updated_at = now()
   WHERE id = p_comm_id AND status = 'sent';
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_recall_comm_response_r1885',
            jsonb_build_object('id', v_id, 'comm_id', p_comm_id));
  RETURN v_id;
END;
$$;

-- RPC 5: close_comm
DROP FUNCTION IF EXISTS public.close_recall_comm_r1885(uuid);
CREATE OR REPLACE FUNCTION public.close_recall_comm_r1885(p_comm_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_capital_recall_comms_r1885
     SET status = 'closed', updated_at = now()
   WHERE id = p_comm_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_recall_comm_r1885',
            jsonb_build_object('comm_id', p_comm_id));
END;
$$;

-- RPC 6: recent_recalls
DROP FUNCTION IF EXISTS public.recent_recall_comms_r1885(int);
CREATE OR REPLACE FUNCTION public.recent_recall_comms_r1885(p_days int)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  comm_type text,
  status text,
  sent_at timestamptz
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
    SELECT c.id, c.investor_id, p.email::text, c.comm_type, c.status, c.sent_at
      FROM public.investor_capital_recall_comms_r1885 c
      LEFT JOIN public.profiles p ON p.id = c.investor_id
     WHERE c.sent_at >= now() - (COALESCE(p_days, 30) || ' days')::interval
     ORDER BY c.sent_at DESC NULLS LAST
     LIMIT 100;
END;
$$;

-- RPC 7: response_rate
DROP FUNCTION IF EXISTS public.recall_comm_response_rate_r1885();
CREATE OR REPLACE FUNCTION public.recall_comm_response_rate_r1885()
RETURNS TABLE (
  comm_type text,
  sent_count int,
  responded_count int,
  acknowledged_count int,
  disputed_count int,
  closed_count int,
  response_rate_pct numeric
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
    SELECT c.comm_type,
           COUNT(*)::int AS sent_count,
           (COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM public.investor_recall_comm_responses_r1885 r WHERE r.comm_id = c.id)))::int AS responded_count,
           (COUNT(*) FILTER (WHERE c.status = 'acknowledged'))::int AS acknowledged_count,
           (COUNT(*) FILTER (WHERE c.status = 'disputed'))::int AS disputed_count,
           (COUNT(*) FILTER (WHERE c.status = 'closed'))::int AS closed_count,
           ROUND(
             (COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM public.investor_recall_comm_responses_r1885 r WHERE r.comm_id = c.id)))::numeric
             * 100.0 / NULLIF(COUNT(*), 0), 2
           ) AS response_rate_pct
      FROM public.investor_capital_recall_comms_r1885 c
     GROUP BY c.comm_type
     ORDER BY c.comm_type;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_recall_comms_r1885() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.send_recall_comm_r1885(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_recall_comm_responses_r1885(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_recall_comm_response_r1885(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_recall_comm_r1885(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_recall_comms_r1885(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recall_comm_response_rate_r1885() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_recall_comms_r1885() TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_recall_comm_r1885(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_recall_comm_responses_r1885(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_recall_comm_response_r1885(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_recall_comm_r1885(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_recall_comms_r1885(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recall_comm_response_rate_r1885() TO authenticated;

COMMIT;