BEGIN;

-- =========================================================================
-- r1475 — Board observer onboarding tracker (7-step playbook)
-- =========================================================================

CREATE TABLE IF NOT EXISTS board_observer_onboarding (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  observer_name text NOT NULL,
  observer_email text NOT NULL,
  observer_org text,
  role_type text NOT NULL CHECK (role_type IN ('observer','board_member','advisor')),
  investor_org text,
  added_at timestamptz NOT NULL DEFAULT now(),
  current_step int NOT NULL DEFAULT 1 CHECK (current_step BETWEEN 1 AND 7),
  step_status text NOT NULL DEFAULT 'in_progress' CHECK (step_status IN ('in_progress','completed','blocked','cancelled')),
  nda_signed_at timestamptz,
  data_room_granted_at timestamptz,
  intro_call_scheduled_at timestamptz,
  intro_call_completed_at timestamptz,
  monthly_cadence_setup_at timestamptz,
  first_board_pack_sent_at timestamptz,
  onboarding_completed_at timestamptz,
  cadence_day_of_month int CHECK (cadence_day_of_month BETWEEN 1 AND 28),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_board_observer_status ON board_observer_onboarding(step_status, current_step);
CREATE INDEX IF NOT EXISTS idx_board_observer_added ON board_observer_onboarding(added_at DESC);

ALTER TABLE board_observer_onboarding ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS board_observer_founder_only ON board_observer_onboarding;
CREATE POLICY board_observer_founder_only ON board_observer_onboarding
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS board_observer_step_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  observer_id uuid NOT NULL REFERENCES board_observer_onboarding(id) ON DELETE CASCADE,
  step_num int NOT NULL CHECK (step_num BETWEEN 1 AND 7),
  step_label text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('started','completed','blocked','note')),
  note text,
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_board_observer_log_obs ON board_observer_step_log(observer_id, created_at DESC);

ALTER TABLE board_observer_step_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS board_observer_log_founder_only ON board_observer_step_log;
CREATE POLICY board_observer_log_founder_only ON board_observer_step_log
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================================
-- READ RPCs (STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION board_observer_onboarding_list()
RETURNS TABLE (
  id uuid,
  observer_name text,
  observer_email text,
  observer_org text,
  role_type text,
  investor_org text,
  current_step int,
  step_status text,
  added_at timestamptz,
  onboarding_completed_at timestamptz,
  days_in_pipeline int,
  next_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.observer_name, b.observer_email, b.observer_org, b.role_type,
         b.investor_org, b.current_step, b.step_status, b.added_at, b.onboarding_completed_at,
         GREATEST(0, EXTRACT(day FROM (now() - b.added_at))::int) AS days_in_pipeline,
         CASE b.current_step
           WHEN 1 THEN 'Send NDA'
           WHEN 2 THEN 'Grant data room'
           WHEN 3 THEN 'Schedule intro call'
           WHEN 4 THEN 'Conduct intro call'
           WHEN 5 THEN 'Set monthly cadence'
           WHEN 6 THEN 'Send first board pack'
           WHEN 7 THEN 'Mark onboarded'
           ELSE 'Unknown'
         END AS next_action
  FROM board_observer_onboarding b
  ORDER BY b.step_status='completed' ASC, b.added_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION board_observer_onboarding_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION board_observer_onboarding_list() TO authenticated;

CREATE OR REPLACE FUNCTION board_observer_funnel_summary()
RETURNS TABLE (
  step_num int,
  step_label text,
  observers_at_or_past int,
  observers_currently_at int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH steps AS (
    SELECT * FROM (VALUES
      (1,'NDA sent'),(2,'NDA signed'),(3,'Data room granted'),
      (4,'Intro call scheduled'),(5,'Intro call completed'),
      (6,'Monthly cadence setup'),(7,'First board pack sent')
    ) AS s(n,l)
  )
  SELECT s.n AS step_num, s.l AS step_label,
    (SELECT COUNT(*)::int FROM board_observer_onboarding b WHERE b.current_step >= s.n) AS observers_at_or_past,
    (SELECT COUNT(*)::int FROM board_observer_onboarding b WHERE b.current_step = s.n AND b.step_status='in_progress') AS observers_currently_at
  FROM steps s
  ORDER BY s.n;
END;
$$;
REVOKE EXECUTE ON FUNCTION board_observer_funnel_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION board_observer_funnel_summary() TO authenticated;

CREATE OR REPLACE FUNCTION board_observer_blocked_list()
RETURNS TABLE (
  id uuid,
  observer_name text,
  observer_email text,
  investor_org text,
  current_step int,
  days_blocked int,
  note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.observer_name, b.observer_email, b.investor_org, b.current_step,
         GREATEST(0, EXTRACT(day FROM (now() - b.updated_at))::int) AS days_blocked,
         b.notes AS note
  FROM board_observer_onboarding b
  WHERE b.step_status='blocked'
  ORDER BY b.updated_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION board_observer_blocked_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION board_observer_blocked_list() TO authenticated;

CREATE OR REPLACE FUNCTION board_observer_recent_activity(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  observer_name text,
  step_num int,
  step_label text,
  event_type text,
  note text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, b.observer_name, l.step_num, l.step_label, l.event_type,
         l.note, l.actor_email, l.created_at
  FROM board_observer_step_log l
  JOIN board_observer_onboarding b ON b.id = l.observer_id
  ORDER BY l.created_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION board_observer_recent_activity(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION board_observer_recent_activity(int) TO authenticated;

CREATE OR REPLACE FUNCTION board_observer_cadence_calendar()
RETURNS TABLE (
  id uuid,
  observer_name text,
  investor_org text,
  cadence_day_of_month int,
  next_send_date date,
  last_board_pack_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.observer_name, b.investor_org, b.cadence_day_of_month,
         CASE
           WHEN b.cadence_day_of_month IS NULL THEN NULL
           WHEN EXTRACT(day FROM now())::int < b.cadence_day_of_month
             THEN (date_trunc('month', now()) + ((b.cadence_day_of_month - 1) || ' days')::interval)::date
           ELSE (date_trunc('month', now()) + interval '1 month' + ((b.cadence_day_of_month - 1) || ' days')::interval)::date
         END AS next_send_date,
         b.first_board_pack_sent_at AS last_board_pack_at
  FROM board_observer_onboarding b
  WHERE b.cadence_day_of_month IS NOT NULL
    AND b.step_status <> 'cancelled'
  ORDER BY b.cadence_day_of_month ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION board_observer_cadence_calendar() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION board_observer_cadence_calendar() TO authenticated;

CREATE OR REPLACE FUNCTION board_observer_kpis()
RETURNS TABLE (
  total_observers int,
  active_observers int,
  completed_observers int,
  blocked_observers int,
  cancelled_observers int,
  ndas_signed int,
  data_room_granted int,
  intro_calls_completed int,
  cadence_setup int,
  board_packs_sent int,
  avg_days_to_complete numeric,
  median_days_to_complete numeric,
  stuck_over_14d int,
  added_last_30d int,
  completed_last_30d int,
  pending_first_pack int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM board_observer_onboarding),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE step_status='in_progress'),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE step_status='completed'),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE step_status='blocked'),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE step_status='cancelled'),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE nda_signed_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE data_room_granted_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE intro_call_completed_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE monthly_cadence_setup_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE first_board_pack_sent_at IS NOT NULL),
    (SELECT COALESCE(AVG(EXTRACT(day FROM (onboarding_completed_at - added_at))),0)::numeric(10,2)
       FROM board_observer_onboarding WHERE onboarding_completed_at IS NOT NULL),
    (SELECT COALESCE(percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(day FROM (onboarding_completed_at - added_at))),0)::numeric(10,2)
       FROM board_observer_onboarding WHERE onboarding_completed_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM board_observer_onboarding
       WHERE step_status='in_progress' AND (now() - updated_at) > interval '14 days'),
    (SELECT COUNT(*)::int FROM board_observer_onboarding WHERE added_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM board_observer_onboarding
       WHERE onboarding_completed_at IS NOT NULL AND onboarding_completed_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM board_observer_onboarding
       WHERE monthly_cadence_setup_at IS NOT NULL AND first_board_pack_sent_at IS NULL);
END;
$$;
REVOKE EXECUTE ON FUNCTION board_observer_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION board_observer_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION board_observer_step_history(p_observer_id uuid)
RETURNS TABLE (
  id uuid,
  step_num int,
  step_label text,
  event_type text,
  note text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.step_num, l.step_label, l.event_type, l.note, l.actor_email, l.created_at
  FROM board_observer_step_log l
  WHERE l.observer_id = p_observer_id
  ORDER BY l.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION board_observer_step_history(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION board_observer_step_history(uuid) TO authenticated;

-- =========================================================================
-- WRITE helpers (VOLATILE, founder-gated, audit-logged)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_board_observer_add(
  p_observer_name text,
  p_observer_email text,
  p_observer_org text,
  p_role_type text,
  p_investor_org text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();

  INSERT INTO board_observer_onboarding(observer_name, observer_email, observer_org, role_type, investor_org)
  VALUES (p_observer_name, p_observer_email, p_observer_org, p_role_type, p_investor_org)
  RETURNING id INTO v_id;

  INSERT INTO board_observer_step_log(observer_id, step_num, step_label, event_type, actor_email, note)
  VALUES (v_id, 1, 'NDA sent', 'started', v_email, 'Observer added to pipeline');

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'board_observer_add', jsonb_build_object(
    'observer_id', v_id, 'name', p_observer_name, 'email', p_observer_email, 'role', p_role_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_observer_add(text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_observer_add(text,text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_observer_advance_step(
  p_observer_id uuid,
  p_next_step int,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
  v_label text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_next_step < 1 OR p_next_step > 7 THEN RAISE EXCEPTION 'invalid_step'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();

  v_label := CASE p_next_step
    WHEN 1 THEN 'NDA sent' WHEN 2 THEN 'NDA signed' WHEN 3 THEN 'Data room granted'
    WHEN 4 THEN 'Intro call scheduled' WHEN 5 THEN 'Intro call completed'
    WHEN 6 THEN 'Monthly cadence setup' WHEN 7 THEN 'First board pack sent' END;

  UPDATE board_observer_onboarding
     SET current_step = p_next_step,
         step_status = CASE WHEN p_next_step = 7 THEN 'completed' ELSE 'in_progress' END,
         nda_signed_at = CASE WHEN p_next_step >= 2 AND nda_signed_at IS NULL THEN now() ELSE nda_signed_at END,
         data_room_granted_at = CASE WHEN p_next_step >= 3 AND data_room_granted_at IS NULL THEN now() ELSE data_room_granted_at END,
         intro_call_scheduled_at = CASE WHEN p_next_step >= 4 AND intro_call_scheduled_at IS NULL THEN now() ELSE intro_call_scheduled_at END,
         intro_call_completed_at = CASE WHEN p_next_step >= 5 AND intro_call_completed_at IS NULL THEN now() ELSE intro_call_completed_at END,
         monthly_cadence_setup_at = CASE WHEN p_next_step >= 6 AND monthly_cadence_setup_at IS NULL THEN now() ELSE monthly_cadence_setup_at END,
         first_board_pack_sent_at = CASE WHEN p_next_step >= 7 AND first_board_pack_sent_at IS NULL THEN now() ELSE first_board_pack_sent_at END,
         onboarding_completed_at = CASE WHEN p_next_step = 7 THEN now() ELSE onboarding_completed_at END,
         updated_at = now()
   WHERE id = p_observer_id;

  INSERT INTO board_observer_step_log(observer_id, step_num, step_label, event_type, actor_email, note)
  VALUES (p_observer_id, p_next_step, v_label,
          CASE WHEN p_next_step = 7 THEN 'completed' ELSE 'started' END, v_email, p_note);

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'board_observer_advance_step',
          jsonb_build_object('observer_id', p_observer_id, 'next_step', p_next_step, 'note', p_note));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_observer_advance_step(uuid,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_observer_advance_step(uuid,int,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_observer_block(
  p_observer_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
  v_step int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  SELECT current_step INTO v_step FROM board_observer_onboarding WHERE id = p_observer_id;

  UPDATE board_observer_onboarding
     SET step_status = 'blocked', notes = p_reason, updated_at = now()
   WHERE id = p_observer_id;

  INSERT INTO board_observer_step_log(observer_id, step_num, step_label, event_type, actor_email, note)
  VALUES (p_observer_id, COALESCE(v_step,1), 'blocked', 'blocked', v_email, p_reason);

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'board_observer_block',
          jsonb_build_object('observer_id', p_observer_id, 'reason', p_reason));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_observer_block(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_observer_block(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_observer_set_cadence(
  p_observer_id uuid,
  p_day_of_month int
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_day_of_month < 1 OR p_day_of_month > 28 THEN RAISE EXCEPTION 'invalid_day'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();

  UPDATE board_observer_onboarding
     SET cadence_day_of_month = p_day_of_month,
         monthly_cadence_setup_at = COALESCE(monthly_cadence_setup_at, now()),
         updated_at = now()
   WHERE id = p_observer_id;

  INSERT INTO board_observer_step_log(observer_id, step_num, step_label, event_type, actor_email, note)
  VALUES (p_observer_id, 6, 'Monthly cadence setup', 'note', v_email,
          'Cadence day set to ' || p_day_of_month::text);

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'board_observer_set_cadence',
          jsonb_build_object('observer_id', p_observer_id, 'day_of_month', p_day_of_month));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_observer_set_cadence(uuid,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_observer_set_cadence(uuid,int) TO authenticated;

COMMIT;