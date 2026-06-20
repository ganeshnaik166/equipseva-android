BEGIN;
-- r1431: founder inbox triage cockpit
-- 1 table (founder_inbox_items) + 7 RPCs unifying email/slack/sms/escalations


CREATE TABLE IF NOT EXISTS public.founder_inbox_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_kind text NOT NULL CHECK (source_kind IN ('email','slack','sms','whatsapp','phone_voicemail','escalation','priority_action','dunning','dispute','code_red')),
  source_id_ref text,
  sender_label text,
  subject text,
  snippet text,
  urgency_band text NOT NULL CHECK (urgency_band IN ('p0_critical','p1_high','medium','low')),
  category text NOT NULL CHECK (category IN ('investor','customer','team','vendor','press','personal','spam_noise','automated')),
  triage_status text NOT NULL DEFAULT 'unread' CHECK (triage_status IN ('unread','triaged','snoozed','replied','escalated','archived','closed')),
  snooze_until timestamptz,
  last_action_at timestamptz,
  response_due_at timestamptz,
  notes text,
  received_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_inbox_items_received_at ON public.founder_inbox_items (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_inbox_items_status ON public.founder_inbox_items (triage_status);
CREATE INDEX IF NOT EXISTS idx_founder_inbox_items_urgency ON public.founder_inbox_items (urgency_band);
CREATE INDEX IF NOT EXISTS idx_founder_inbox_items_category ON public.founder_inbox_items (category);
CREATE INDEX IF NOT EXISTS idx_founder_inbox_items_response_due_at ON public.founder_inbox_items (response_due_at);

ALTER TABLE public.founder_inbox_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.founder_inbox_items FROM anon, authenticated;

-- RPC 1: summary (16 KPIs)
DROP FUNCTION IF EXISTS public.founder_inbox_triage_summary();
CREATE OR REPLACE FUNCTION public.founder_inbox_triage_summary()
RETURNS TABLE (
  total_items bigint,
  unread_count bigint,
  p0_count bigint,
  p1_count bigint,
  medium_count bigint,
  low_count bigint,
  snoozed_count bigint,
  replied_30d bigint,
  escalated_30d bigint,
  archived_30d bigint,
  closed_30d bigint,
  items_30d bigint,
  items_7d bigint,
  overdue_count bigint,
  avg_response_lag_hours numeric,
  top_source_kind text,
  top_category text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_inbox_items
  ),
  top_src AS (
    SELECT source_kind, count(*) AS c FROM base GROUP BY source_kind ORDER BY c DESC LIMIT 1
  ),
  top_cat AS (
    SELECT category, count(*) AS c FROM base GROUP BY category ORDER BY c DESC LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM base),
    (SELECT count(*) FROM base WHERE triage_status = 'unread'),
    (SELECT count(*) FROM base WHERE urgency_band = 'p0_critical' AND triage_status NOT IN ('closed','archived')),
    (SELECT count(*) FROM base WHERE urgency_band = 'p1_high' AND triage_status NOT IN ('closed','archived')),
    (SELECT count(*) FROM base WHERE urgency_band = 'medium' AND triage_status NOT IN ('closed','archived')),
    (SELECT count(*) FROM base WHERE urgency_band = 'low' AND triage_status NOT IN ('closed','archived')),
    (SELECT count(*) FROM base WHERE triage_status = 'snoozed'),
    (SELECT count(*) FROM base WHERE triage_status = 'replied' AND last_action_at >= now() - interval '30 days'),
    (SELECT count(*) FROM base WHERE triage_status = 'escalated' AND last_action_at >= now() - interval '30 days'),
    (SELECT count(*) FROM base WHERE triage_status = 'archived' AND last_action_at >= now() - interval '30 days'),
    (SELECT count(*) FROM base WHERE triage_status = 'closed' AND last_action_at >= now() - interval '30 days'),
    (SELECT count(*) FROM base WHERE received_at >= now() - interval '30 days'),
    (SELECT count(*) FROM base WHERE received_at >= now() - interval '7 days'),
    (SELECT count(*) FROM base WHERE response_due_at IS NOT NULL AND response_due_at < now() AND triage_status NOT IN ('replied','closed','archived')),
    COALESCE((SELECT round(avg(extract(epoch FROM (last_action_at - received_at)) / 3600.0)::numeric, 2)
              FROM base WHERE last_action_at IS NOT NULL AND last_action_at >= received_at), 0),
    COALESCE((SELECT source_kind FROM top_src), 'none'),
    COALESCE((SELECT category FROM top_cat), 'none');
END;
$$;
REVOKE ALL ON FUNCTION public.founder_inbox_triage_summary() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_inbox_triage_summary() TO authenticated;

-- RPC 2: recent items
DROP FUNCTION IF EXISTS public.founder_inbox_items_recent(int);
CREATE OR REPLACE FUNCTION public.founder_inbox_items_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  source_kind text,
  sender_label text,
  subject text,
  snippet text,
  urgency_band text,
  category text,
  triage_status text,
  response_due_at timestamptz,
  received_at timestamptz,
  age_hours numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT i.id, i.source_kind, i.sender_label, i.subject, i.snippet,
         i.urgency_band, i.category, i.triage_status, i.response_due_at, i.received_at,
         round(extract(epoch FROM (now() - i.received_at)) / 3600.0, 2)::numeric AS age_hours
  FROM public.founder_inbox_items i
  ORDER BY i.received_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_inbox_items_recent(int) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_inbox_items_recent(int) TO authenticated;

-- RPC 3: unread items
DROP FUNCTION IF EXISTS public.founder_inbox_items_unread(int);
CREATE OR REPLACE FUNCTION public.founder_inbox_items_unread(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  source_kind text,
  sender_label text,
  subject text,
  urgency_band text,
  category text,
  received_at timestamptz,
  age_hours numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT i.id, i.source_kind, i.sender_label, i.subject,
         i.urgency_band, i.category, i.received_at,
         round(extract(epoch FROM (now() - i.received_at)) / 3600.0, 2)::numeric AS age_hours
  FROM public.founder_inbox_items i
  WHERE i.triage_status = 'unread'
  ORDER BY
    CASE i.urgency_band
      WHEN 'p0_critical' THEN 1
      WHEN 'p1_high' THEN 2
      WHEN 'medium' THEN 3
      ELSE 4
    END,
    i.received_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_inbox_items_unread(int) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_inbox_items_unread(int) TO authenticated;

-- RPC 4: overdue items
DROP FUNCTION IF EXISTS public.founder_inbox_items_overdue(int);
CREATE OR REPLACE FUNCTION public.founder_inbox_items_overdue(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  source_kind text,
  sender_label text,
  subject text,
  urgency_band text,
  category text,
  response_due_at timestamptz,
  hours_overdue numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT i.id, i.source_kind, i.sender_label, i.subject,
         i.urgency_band, i.category, i.response_due_at,
         round(extract(epoch FROM (now() - i.response_due_at)) / 3600.0, 2)::numeric AS hours_overdue
  FROM public.founder_inbox_items i
  WHERE i.response_due_at IS NOT NULL
    AND i.response_due_at < now()
    AND i.triage_status NOT IN ('replied','closed','archived')
  ORDER BY i.response_due_at ASC
  LIMIT COALESCE(p_limit, 100);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_inbox_items_overdue(int) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_inbox_items_overdue(int) TO authenticated;

-- RPC 5: register new inbox item (log/insert)
DROP FUNCTION IF EXISTS public.log_founder_inbox_register_item(text, text, text, text, text, text, text, timestamptz, timestamptz);
CREATE OR REPLACE FUNCTION public.log_founder_inbox_register_item(
  p_source_kind text,
  p_source_id_ref text,
  p_sender_label text,
  p_subject text,
  p_snippet text,
  p_urgency_band text,
  p_category text,
  p_received_at timestamptz,
  p_response_due_at timestamptz DEFAULT NULL
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
  INSERT INTO public.founder_inbox_items (
    source_kind, source_id_ref, sender_label, subject, snippet,
    urgency_band, category, triage_status, received_at, response_due_at
  ) VALUES (
    p_source_kind, p_source_id_ref, p_sender_label, p_subject, p_snippet,
    p_urgency_band, p_category, 'unread', p_received_at, p_response_due_at
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_inbox_register_item(text, text, text, text, text, text, text, timestamptz, timestamptz) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_inbox_register_item(text, text, text, text, text, text, text, timestamptz, timestamptz) TO authenticated;

-- RPC 6: update triage status
DROP FUNCTION IF EXISTS public.log_founder_inbox_triage_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_inbox_triage_status(
  p_item_id uuid,
  p_new_status text,
  p_notes text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_new_status NOT IN ('unread','triaged','snoozed','replied','escalated','archived','closed') THEN
    RAISE EXCEPTION 'invalid status: %', p_new_status;
  END IF;
  UPDATE public.founder_inbox_items
     SET triage_status = p_new_status,
         last_action_at = now(),
         notes = COALESCE(p_notes, notes)
   WHERE id = p_item_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_inbox_triage_status(uuid, text, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_inbox_triage_status(uuid, text, text) TO authenticated;

-- RPC 7: snooze item
DROP FUNCTION IF EXISTS public.log_founder_inbox_snooze(uuid, timestamptz);
CREATE OR REPLACE FUNCTION public.log_founder_inbox_snooze(
  p_item_id uuid,
  p_snooze_until timestamptz
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_snooze_until <= now() THEN
    RAISE EXCEPTION 'snooze_until must be in the future';
  END IF;
  UPDATE public.founder_inbox_items
     SET triage_status = 'snoozed',
         snooze_until = p_snooze_until,
         last_action_at = now()
   WHERE id = p_item_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_inbox_snooze(uuid, timestamptz) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_inbox_snooze(uuid, timestamptz) TO authenticated;

COMMIT;