BEGIN;

-- =====================================================================
-- Round 2017 — Investor Quarterly Letter Composer
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.investor_quarterly_letters_r2017 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  letter_title text NOT NULL,
  letter_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','review','sent','archived')),
  sent_at timestamptz,
  sent_count int NOT NULL DEFAULT 0,
  drafted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS investor_quarterly_letters_r2017_status_idx
  ON public.investor_quarterly_letters_r2017(status);
CREATE INDEX IF NOT EXISTS investor_quarterly_letters_r2017_drafted_idx
  ON public.investor_quarterly_letters_r2017(drafted_at DESC);

CREATE TABLE IF NOT EXISTS public.investor_letter_send_log_r2017 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  letter_id uuid NOT NULL REFERENCES public.investor_quarterly_letters_r2017(id) ON DELETE CASCADE,
  send_type text NOT NULL CHECK (send_type IN ('broadcast','personalized','special_announce')),
  recipient_count int NOT NULL DEFAULT 0,
  sent_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS investor_letter_send_log_r2017_letter_idx
  ON public.investor_letter_send_log_r2017(letter_id);
CREATE INDEX IF NOT EXISTS investor_letter_send_log_r2017_sent_idx
  ON public.investor_letter_send_log_r2017(sent_at DESC);

ALTER TABLE public.investor_quarterly_letters_r2017 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_letter_send_log_r2017 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_iql_r2017 ON public.investor_quarterly_letters_r2017;
CREATE POLICY founder_all_iql_r2017 ON public.investor_quarterly_letters_r2017
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ilsl_r2017 ON public.investor_letter_send_log_r2017;
CREATE POLICY founder_all_ilsl_r2017 ON public.investor_letter_send_log_r2017
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1 — list_letters
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_letters_r2017(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  quarter_label text,
  letter_title text,
  status text,
  drafted_at timestamptz,
  sent_at timestamptz,
  sent_count int
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
  SELECT l.id, l.quarter_label, l.letter_title, l.status, l.drafted_at, l.sent_at, l.sent_count
  FROM public.investor_quarterly_letters_r2017 l
  WHERE p_status IS NULL OR l.status = p_status
  ORDER BY l.drafted_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

-- =====================================================================
-- RPC 2 — log_letter
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_letter_r2017(
  p_quarter_label text,
  p_letter_title text,
  p_letter_md text DEFAULT '',
  p_status text DEFAULT 'draft'
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
  INSERT INTO public.investor_quarterly_letters_r2017(quarter_label, letter_title, letter_md, status)
  VALUES (p_quarter_label, p_letter_title, COALESCE(p_letter_md, ''), COALESCE(p_status, 'draft'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_letter_r2017',
    jsonb_build_object('letter_id', v_id, 'quarter_label', p_quarter_label, 'title', p_letter_title, 'status', p_status)
  );
  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3 — list_sends
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_sends_r2017(
  p_letter_id uuid DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  letter_id uuid,
  send_type text,
  recipient_count int,
  sent_at timestamptz,
  by_email text,
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
  SELECT s.id, s.letter_id, s.send_type, s.recipient_count, s.sent_at, s.by_email, s.notes_md
  FROM public.investor_letter_send_log_r2017 s
  WHERE p_letter_id IS NULL OR s.letter_id = p_letter_id
  ORDER BY s.sent_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

-- =====================================================================
-- RPC 4 — log_send
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_send_r2017(
  p_letter_id uuid,
  p_send_type text,
  p_recipient_count int,
  p_by_email text DEFAULT NULL,
  p_notes_md text DEFAULT NULL
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
  INSERT INTO public.investor_letter_send_log_r2017(letter_id, send_type, recipient_count, by_email, notes_md)
  VALUES (p_letter_id, p_send_type, COALESCE(p_recipient_count, 0), p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  UPDATE public.investor_quarterly_letters_r2017
  SET sent_count = sent_count + COALESCE(p_recipient_count, 0),
      sent_at = COALESCE(sent_at, now()),
      status = CASE WHEN status IN ('draft','review') THEN 'sent' ELSE status END,
      updated_at = now()
  WHERE id = p_letter_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_send_r2017',
    jsonb_build_object('send_id', v_id, 'letter_id', p_letter_id, 'send_type', p_send_type, 'recipient_count', p_recipient_count)
  );
  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5 — mark_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2017(
  p_letter_id uuid,
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
  IF p_status NOT IN ('draft','review','sent','archived') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_quarterly_letters_r2017
  SET status = p_status,
      sent_at = CASE WHEN p_status = 'sent' AND sent_at IS NULL THEN now() ELSE sent_at END,
      updated_at = now()
  WHERE id = p_letter_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r2017',
    jsonb_build_object('letter_id', p_letter_id, 'status', p_status)
  );
END;
$$;

-- =====================================================================
-- RPC 6 — recent_letters
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_letters_r2017(
  p_days int DEFAULT 90
)
RETURNS TABLE (
  id uuid,
  quarter_label text,
  letter_title text,
  status text,
  drafted_at timestamptz,
  sent_at timestamptz,
  sent_count int
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
  SELECT l.id, l.quarter_label, l.letter_title, l.status, l.drafted_at, l.sent_at, l.sent_count
  FROM public.investor_quarterly_letters_r2017 l
  WHERE l.drafted_at >= now() - (COALESCE(p_days, 90) || ' days')::interval
  ORDER BY l.drafted_at DESC
  LIMIT 100;
END;
$$;

-- =====================================================================
-- RPC 7 — recent_sends
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_sends_r2017(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  id uuid,
  letter_id uuid,
  send_type text,
  recipient_count int,
  sent_at timestamptz,
  by_email text
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
  SELECT s.id, s.letter_id, s.send_type, s.recipient_count, s.sent_at, s.by_email
  FROM public.investor_letter_send_log_r2017 s
  WHERE s.sent_at >= now() - (COALESCE(p_days, 30) || ' days')::interval
  ORDER BY s.sent_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- Grants
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_letters_r2017(text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_letter_r2017(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_sends_r2017(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_send_r2017(uuid, text, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2017(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_letters_r2017(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_sends_r2017(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_letters_r2017(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_letter_r2017(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_sends_r2017(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_send_r2017(uuid, text, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2017(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_letters_r2017(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_sends_r2017(int) TO authenticated;

COMMIT;
