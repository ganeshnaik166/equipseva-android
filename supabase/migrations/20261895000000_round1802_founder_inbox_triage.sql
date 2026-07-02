BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_inbox_triage_r1802 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel text NOT NULL CHECK (channel IN ('email','whatsapp','linkedin','sms','phone','in_person')),
  from_name text NOT NULL,
  from_email text,
  subject text NOT NULL,
  urgency text NOT NULL CHECK (urgency IN ('critical','high','medium','low')),
  received_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'inbox' CHECK (status IN ('inbox','triaged','replied','archived','delegated')),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_inbox_triage_decisions_r1802 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  triage_id uuid NOT NULL REFERENCES public.founder_inbox_triage_r1802(id) ON DELETE CASCADE,
  decision text NOT NULL CHECK (decision IN ('reply','delegate','snooze','archive','escalate')),
  decision_at timestamptz NOT NULL DEFAULT now(),
  decision_note text,
  delegated_to_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_inbox_triage_r1802 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_inbox_triage_decisions_r1802 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_triage_r1802 ON public.founder_inbox_triage_r1802;
CREATE POLICY founder_all_triage_r1802 ON public.founder_inbox_triage_r1802
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_decisions_r1802 ON public.founder_inbox_triage_decisions_r1802;
CREATE POLICY founder_all_decisions_r1802 ON public.founder_inbox_triage_decisions_r1802
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_triage_r1802()
RETURNS TABLE (
  id uuid,
  channel text,
  from_name text,
  from_email text,
  subject text,
  urgency text,
  received_at timestamptz,
  status text,
  founder_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.channel, t.from_name, t.from_email, t.subject, t.urgency, t.received_at, t.status, t.founder_note
  FROM public.founder_inbox_triage_r1802 t
  ORDER BY
    CASE t.urgency WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    t.received_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_message_r1802(
  p_channel text,
  p_from_name text,
  p_from_email text,
  p_subject text,
  p_urgency text,
  p_received_at timestamptz
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
  INSERT INTO public.founder_inbox_triage_r1802 (channel, from_name, from_email, subject, urgency, received_at)
  VALUES (p_channel, p_from_name, p_from_email, p_subject, p_urgency, COALESCE(p_received_at, now()))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_message_r1802',
    jsonb_build_object('triage_id', v_id, 'channel', p_channel, 'from_email', p_from_email, 'urgency', p_urgency));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_decisions_r1802(p_triage_id uuid)
RETURNS TABLE (
  id uuid,
  triage_id uuid,
  decision text,
  decision_at timestamptz,
  decision_note text,
  delegated_to_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.triage_id, d.decision, d.decision_at, d.decision_note, d.delegated_to_email
  FROM public.founder_inbox_triage_decisions_r1802 d
  WHERE p_triage_id IS NULL OR d.triage_id = p_triage_id
  ORDER BY d.decision_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_decision_r1802(
  p_triage_id uuid,
  p_decision text,
  p_decision_note text,
  p_delegated_to_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_new_status text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_inbox_triage_decisions_r1802 (triage_id, decision, decision_note, delegated_to_email)
  VALUES (p_triage_id, p_decision, p_decision_note, p_delegated_to_email)
  RETURNING id INTO v_id;

  v_new_status := CASE p_decision
    WHEN 'reply' THEN 'replied'
    WHEN 'delegate' THEN 'delegated'
    WHEN 'archive' THEN 'archived'
    WHEN 'escalate' THEN 'triaged'
    WHEN 'snooze' THEN 'triaged'
    ELSE 'triaged'
  END;

  UPDATE public.founder_inbox_triage_r1802
  SET status = v_new_status, updated_at = now()
  WHERE id = p_triage_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_decision_r1802',
    jsonb_build_object('triage_id', p_triage_id, 'decision', p_decision, 'delegated_to_email', p_delegated_to_email));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_message_r1802(p_triage_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_inbox_triage_r1802
  SET status = 'archived', updated_at = now()
  WHERE id = p_triage_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'archive_message_r1802',
    jsonb_build_object('triage_id', p_triage_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.urgency_summary_r1802()
RETURNS TABLE (
  urgency text,
  total_count int,
  open_count int,
  resolved_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.urgency,
    COUNT(*)::int AS total_count,
    (COUNT(*) FILTER (WHERE t.status IN ('inbox','triaged')))::int AS open_count,
    (COUNT(*) FILTER (WHERE t.status IN ('replied','archived','delegated')))::int AS resolved_count
  FROM public.founder_inbox_triage_r1802 t
  GROUP BY t.urgency
  ORDER BY CASE t.urgency WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;

CREATE OR REPLACE FUNCTION public.inbox_zero_metric_r1802()
RETURNS TABLE (
  total_msgs int,
  open_msgs int,
  archived_msgs int,
  inbox_zero_pct numeric,
  critical_open int,
  oldest_open_received_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int AS total_msgs,
    (COUNT(*) FILTER (WHERE t.status IN ('inbox','triaged')))::int AS open_msgs,
    (COUNT(*) FILTER (WHERE t.status = 'archived'))::int AS archived_msgs,
    CASE WHEN COUNT(*) = 0 THEN 0::numeric
         ELSE ROUND(100.0 * (COUNT(*) FILTER (WHERE t.status IN ('replied','archived','delegated')))::numeric / COUNT(*)::numeric, 2)
    END AS inbox_zero_pct,
    (COUNT(*) FILTER (WHERE t.urgency = 'critical' AND t.status IN ('inbox','triaged')))::int AS critical_open,
    MIN(t.received_at) FILTER (WHERE t.status IN ('inbox','triaged')) AS oldest_open_received_at
  FROM public.founder_inbox_triage_r1802 t;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_triage_r1802() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_message_r1802(text, text, text, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_decisions_r1802(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_decision_r1802(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.archive_message_r1802(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.urgency_summary_r1802() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.inbox_zero_metric_r1802() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_triage_r1802() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_message_r1802(text, text, text, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_decisions_r1802(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_decision_r1802(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archive_message_r1802(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.urgency_summary_r1802() TO authenticated;
GRANT EXECUTE ON FUNCTION public.inbox_zero_metric_r1802() TO authenticated;

COMMIT;