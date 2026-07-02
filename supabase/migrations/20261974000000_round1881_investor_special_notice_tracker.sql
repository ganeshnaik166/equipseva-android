BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_special_notices_r1881 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notice_type text NOT NULL CHECK (notice_type IN ('rofr','drag_along','tag_along','right_of_first_refusal','recall','buyout_offer')),
  investor_ids uuid[] NOT NULL DEFAULT '{}',
  notice_amount_rupees bigint NOT NULL DEFAULT 0,
  notice_window_days int NOT NULL DEFAULT 30,
  sent_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','responses_pending','closed','disputed')),
  closed_at timestamptz,
  subject text,
  body text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_special_notice_responses_r1881 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notice_id uuid NOT NULL REFERENCES public.investor_special_notices_r1881(id) ON DELETE CASCADE,
  investor_id uuid NOT NULL,
  response_type text NOT NULL CHECK (response_type IN ('accepted','declined','waived','no_response')),
  responded_at timestamptz NOT NULL DEFAULT now(),
  response_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_special_notices_r1881 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_special_notice_responses_r1881 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_notices_r1881 ON public.investor_special_notices_r1881;
CREATE POLICY founder_all_notices_r1881 ON public.investor_special_notices_r1881
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_responses_r1881 ON public.investor_special_notice_responses_r1881;
CREATE POLICY founder_all_responses_r1881 ON public.investor_special_notice_responses_r1881
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_notices_r1881_status ON public.investor_special_notices_r1881(status);
CREATE INDEX IF NOT EXISTS idx_notices_r1881_sent_at ON public.investor_special_notices_r1881(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_responses_r1881_notice_id ON public.investor_special_notice_responses_r1881(notice_id);

CREATE OR REPLACE FUNCTION public.list_notices_r1881()
RETURNS TABLE (
  id uuid,
  notice_type text,
  investor_count int,
  notice_amount_rupees bigint,
  notice_window_days int,
  sent_at timestamptz,
  status text,
  closed_at timestamptz,
  response_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.id,
    n.notice_type,
    COALESCE(array_length(n.investor_ids,1), 0)::int AS investor_count,
    n.notice_amount_rupees,
    n.notice_window_days,
    n.sent_at,
    n.status,
    n.closed_at,
    (SELECT COUNT(*) FROM public.investor_special_notice_responses_r1881 r WHERE r.notice_id = n.id)::int AS response_count
  FROM public.investor_special_notices_r1881 n
  ORDER BY n.sent_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_notice_r1881(
  p_notice_type text,
  p_investor_ids uuid[],
  p_notice_amount_rupees bigint,
  p_notice_window_days int,
  p_subject text,
  p_body text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_special_notices_r1881(notice_type, investor_ids, notice_amount_rupees, notice_window_days, subject, body, status)
  VALUES (p_notice_type, COALESCE(p_investor_ids,'{}'::uuid[]), COALESCE(p_notice_amount_rupees,0), COALESCE(p_notice_window_days,30), p_subject, p_body, 'sent')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'send_notice_r1881', jsonb_build_object('id', v_id, 'notice_type', p_notice_type, 'investor_count', COALESCE(array_length(p_investor_ids,1),0)));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_responses_r1881(p_notice_id uuid)
RETURNS TABLE (
  id uuid,
  notice_id uuid,
  investor_id uuid,
  response_type text,
  responded_at timestamptz,
  response_note text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.notice_id, r.investor_id, r.response_type, r.responded_at, r.response_note
  FROM public.investor_special_notice_responses_r1881 r
  WHERE r.notice_id = p_notice_id
  ORDER BY r.responded_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_response_r1881(
  p_notice_id uuid,
  p_investor_id uuid,
  p_response_type text,
  p_response_note text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_special_notice_responses_r1881(notice_id, investor_id, response_type, response_note)
  VALUES (p_notice_id, p_investor_id, p_response_type, p_response_note)
  RETURNING id INTO v_id;

  UPDATE public.investor_special_notices_r1881
  SET status = 'responses_pending', updated_at = now()
  WHERE id = p_notice_id AND status = 'sent';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_response_r1881', jsonb_build_object('id', v_id, 'notice_id', p_notice_id, 'investor_id', p_investor_id, 'response_type', p_response_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.close_notice_r1881(p_notice_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_special_notices_r1881
  SET status = 'closed', closed_at = now(), updated_at = now()
  WHERE id = p_notice_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_notice_r1881', jsonb_build_object('notice_id', p_notice_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.response_rate_summary_r1881()
RETURNS TABLE (
  notice_type text,
  total_notices int,
  total_responses int,
  accepted_count int,
  declined_count int,
  waived_count int,
  no_response_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.notice_type,
    COUNT(DISTINCT n.id)::int AS total_notices,
    (SELECT COUNT(*) FROM public.investor_special_notice_responses_r1881 r WHERE r.notice_id IN (SELECT n2.id FROM public.investor_special_notices_r1881 n2 WHERE n2.notice_type = n.notice_type))::int AS total_responses,
    (SELECT COUNT(*) FILTER (WHERE r.response_type = 'accepted') FROM public.investor_special_notice_responses_r1881 r WHERE r.notice_id IN (SELECT n2.id FROM public.investor_special_notices_r1881 n2 WHERE n2.notice_type = n.notice_type))::int AS accepted_count,
    (SELECT COUNT(*) FILTER (WHERE r.response_type = 'declined') FROM public.investor_special_notice_responses_r1881 r WHERE r.notice_id IN (SELECT n2.id FROM public.investor_special_notices_r1881 n2 WHERE n2.notice_type = n.notice_type))::int AS declined_count,
    (SELECT COUNT(*) FILTER (WHERE r.response_type = 'waived') FROM public.investor_special_notice_responses_r1881 r WHERE r.notice_id IN (SELECT n2.id FROM public.investor_special_notices_r1881 n2 WHERE n2.notice_type = n.notice_type))::int AS waived_count,
    (SELECT COUNT(*) FILTER (WHERE r.response_type = 'no_response') FROM public.investor_special_notice_responses_r1881 r WHERE r.notice_id IN (SELECT n2.id FROM public.investor_special_notices_r1881 n2 WHERE n2.notice_type = n.notice_type))::int AS no_response_count
  FROM public.investor_special_notices_r1881 n
  GROUP BY n.notice_type
  ORDER BY n.notice_type;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_notices_r1881()
RETURNS TABLE (
  id uuid,
  notice_type text,
  investor_count int,
  notice_amount_rupees bigint,
  sent_at timestamptz,
  status text,
  days_open int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.id,
    n.notice_type,
    COALESCE(array_length(n.investor_ids,1), 0)::int AS investor_count,
    n.notice_amount_rupees,
    n.sent_at,
    n.status,
    EXTRACT(DAY FROM (now() - n.sent_at))::int AS days_open
  FROM public.investor_special_notices_r1881 n
  WHERE n.sent_at >= now() - interval '30 days'
  ORDER BY n.sent_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_notices_r1881() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.send_notice_r1881(text, uuid[], bigint, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_responses_r1881(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_response_r1881(uuid, uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_notice_r1881(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.response_rate_summary_r1881() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_notices_r1881() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_notices_r1881() TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_notice_r1881(text, uuid[], bigint, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_responses_r1881(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_response_r1881(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_notice_r1881(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.response_rate_summary_r1881() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_notices_r1881() TO authenticated;

COMMIT;