BEGIN;
-- r1447 founder investor coffee chat calendar + conversation notes


CREATE TABLE IF NOT EXISTS public.founder_investor_coffee_meetings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_firm_name text NOT NULL,
  investor_partner_name text,
  investor_partner_email text,
  meeting_at timestamptz NOT NULL,
  meeting_kind text NOT NULL DEFAULT 'informal_coffee'
    CHECK (meeting_kind IN ('informal_coffee','intro_meeting','warm_intro','followup','quarterly_update','board_observer','deal_close')),
  location text,
  virtual_meeting_url text,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','completed','cancelled','rescheduled','no_show')),
  duration_minutes int,
  our_attendees text,
  outcome_summary text,
  sentiment text
    CHECK (sentiment IS NULL OR sentiment IN ('strongly_positive','positive','neutral','cool','negative')),
  follow_up_required boolean NOT NULL DEFAULT true,
  follow_up_due_date date,
  follow_up_action_text text,
  deal_track text
    CHECK (deal_track IS NULL OR deal_track IN ('pure_relationship','warm_lead','active_diligence','term_sheet','pass','no_response')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fic_meetings_meeting_at ON public.founder_investor_coffee_meetings (meeting_at DESC);
CREATE INDEX IF NOT EXISTS idx_fic_meetings_firm ON public.founder_investor_coffee_meetings (investor_firm_name);
CREATE INDEX IF NOT EXISTS idx_fic_meetings_status ON public.founder_investor_coffee_meetings (status);
CREATE INDEX IF NOT EXISTS idx_fic_meetings_followup ON public.founder_investor_coffee_meetings (follow_up_due_date) WHERE follow_up_required AND follow_up_due_date IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.founder_investor_coffee_conversation_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.founder_investor_coffee_meetings(id) ON DELETE CASCADE,
  topic text NOT NULL
    CHECK (topic IN ('product_market_fit','traction','team','market_size','competition','financials','use_of_funds','dd_questions','introductions_offered','other')),
  note_text text NOT NULL,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fic_notes_meeting ON public.founder_investor_coffee_conversation_notes (meeting_id, created_at DESC);

ALTER TABLE public.founder_investor_coffee_meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_investor_coffee_conversation_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fic_meetings_founder ON public.founder_investor_coffee_meetings;
CREATE POLICY p_fic_meetings_founder ON public.founder_investor_coffee_meetings FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_fic_notes_founder ON public.founder_investor_coffee_conversation_notes;
CREATE POLICY p_fic_notes_founder ON public.founder_investor_coffee_conversation_notes FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_investor_coffee_meetings FROM authenticated, anon;
REVOKE ALL ON public.founder_investor_coffee_conversation_notes FROM authenticated, anon;

-- ============ RPC 1: summary (16 KPIs) ============
DROP FUNCTION IF EXISTS public.founder_investor_coffee_calendar_summary();
CREATE OR REPLACE FUNCTION public.founder_investor_coffee_calendar_summary()
RETURNS TABLE (
  total_meetings_lifetime int,
  meetings_scheduled int,
  meetings_completed int,
  meetings_cancelled_or_no_show int,
  meetings_upcoming_7d int,
  meetings_upcoming_30d int,
  meetings_completed_30d int,
  meetings_completed_90d int,
  distinct_firms_total int,
  distinct_firms_active_90d int,
  overdue_followups int,
  followups_due_7d int,
  active_diligence_count int,
  term_sheet_count int,
  pass_count int,
  positive_sentiment_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH m AS (SELECT * FROM public.founder_investor_coffee_meetings),
  sentiment_calc AS (
    SELECT COUNT(*) FILTER (WHERE sentiment IN ('strongly_positive','positive'))::numeric AS pos,
           NULLIF(COUNT(*) FILTER (WHERE sentiment IS NOT NULL), 0)::numeric AS total
    FROM m WHERE status='completed'
  )
  SELECT
    (SELECT COUNT(*)::int FROM m),
    (SELECT COUNT(*)::int FROM m WHERE status='scheduled'),
    (SELECT COUNT(*)::int FROM m WHERE status='completed'),
    (SELECT COUNT(*)::int FROM m WHERE status IN ('cancelled','no_show')),
    (SELECT COUNT(*)::int FROM m WHERE status='scheduled' AND meeting_at BETWEEN now() AND now()+interval '7 days'),
    (SELECT COUNT(*)::int FROM m WHERE status='scheduled' AND meeting_at BETWEEN now() AND now()+interval '30 days'),
    (SELECT COUNT(*)::int FROM m WHERE status='completed' AND meeting_at >= now()-interval '30 days'),
    (SELECT COUNT(*)::int FROM m WHERE status='completed' AND meeting_at >= now()-interval '90 days'),
    (SELECT COUNT(DISTINCT investor_firm_name)::int FROM m),
    (SELECT COUNT(DISTINCT investor_firm_name)::int FROM m WHERE meeting_at >= now()-interval '90 days'),
    (SELECT COUNT(*)::int FROM m WHERE follow_up_required AND follow_up_due_date IS NOT NULL AND follow_up_due_date < CURRENT_DATE AND status='completed'),
    (SELECT COUNT(*)::int FROM m WHERE follow_up_required AND follow_up_due_date IS NOT NULL AND follow_up_due_date BETWEEN CURRENT_DATE AND CURRENT_DATE+7 AND status='completed'),
    (SELECT COUNT(DISTINCT investor_firm_name)::int FROM m WHERE deal_track='active_diligence'),
    (SELECT COUNT(DISTINCT investor_firm_name)::int FROM m WHERE deal_track='term_sheet'),
    (SELECT COUNT(DISTINCT investor_firm_name)::int FROM m WHERE deal_track='pass'),
    COALESCE((SELECT ROUND((pos*100.0)/NULLIF(total,0), 1) FROM sentiment_calc), 0)::numeric;
END;
$fn$;

REVOKE ALL ON FUNCTION public.founder_investor_coffee_calendar_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_coffee_calendar_summary() TO authenticated;

-- ============ RPC 2: recent meetings ============
DROP FUNCTION IF EXISTS public.founder_investor_coffee_meetings_recent();
CREATE OR REPLACE FUNCTION public.founder_investor_coffee_meetings_recent()
RETURNS TABLE (
  id uuid,
  investor_firm_name text,
  investor_partner_name text,
  meeting_at timestamptz,
  meeting_kind text,
  status text,
  sentiment text,
  deal_track text,
  outcome_summary text,
  follow_up_required boolean,
  follow_up_due_date date,
  notes_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.investor_firm_name, m.investor_partner_name, m.meeting_at, m.meeting_kind,
         m.status, m.sentiment, m.deal_track, m.outcome_summary, m.follow_up_required, m.follow_up_due_date,
         (SELECT COUNT(*)::int FROM public.founder_investor_coffee_conversation_notes n WHERE n.meeting_id = m.id)
  FROM public.founder_investor_coffee_meetings m
  WHERE m.meeting_at <= now()
  ORDER BY m.meeting_at DESC
  LIMIT 50;
END;
$fn$;
REVOKE ALL ON FUNCTION public.founder_investor_coffee_meetings_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_coffee_meetings_recent() TO authenticated;

-- ============ RPC 3: upcoming meetings ============
DROP FUNCTION IF EXISTS public.founder_investor_coffee_meetings_upcoming();
CREATE OR REPLACE FUNCTION public.founder_investor_coffee_meetings_upcoming()
RETURNS TABLE (
  id uuid,
  investor_firm_name text,
  investor_partner_name text,
  meeting_at timestamptz,
  meeting_kind text,
  location text,
  virtual_meeting_url text,
  duration_minutes int,
  days_until int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.investor_firm_name, m.investor_partner_name, m.meeting_at, m.meeting_kind,
         m.location, m.virtual_meeting_url, m.duration_minutes,
         GREATEST(0, EXTRACT(DAY FROM (m.meeting_at - now()))::int)
  FROM public.founder_investor_coffee_meetings m
  WHERE m.status='scheduled' AND m.meeting_at > now()
  ORDER BY m.meeting_at ASC
  LIMIT 30;
END;
$fn$;
REVOKE ALL ON FUNCTION public.founder_investor_coffee_meetings_upcoming() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_coffee_meetings_upcoming() TO authenticated;

-- ============ RPC 4: overdue follow-ups ============
DROP FUNCTION IF EXISTS public.founder_investor_coffee_overdue_followups();
CREATE OR REPLACE FUNCTION public.founder_investor_coffee_overdue_followups()
RETURNS TABLE (
  id uuid,
  investor_firm_name text,
  investor_partner_name text,
  meeting_at timestamptz,
  follow_up_due_date date,
  days_overdue int,
  follow_up_action_text text,
  deal_track text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.investor_firm_name, m.investor_partner_name, m.meeting_at, m.follow_up_due_date,
         (CURRENT_DATE - m.follow_up_due_date)::int,
         m.follow_up_action_text, m.deal_track
  FROM public.founder_investor_coffee_meetings m
  WHERE m.follow_up_required AND m.follow_up_due_date IS NOT NULL
    AND m.follow_up_due_date < CURRENT_DATE
    AND m.status='completed'
  ORDER BY m.follow_up_due_date ASC
  LIMIT 30;
END;
$fn$;
REVOKE ALL ON FUNCTION public.founder_investor_coffee_overdue_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_coffee_overdue_followups() TO authenticated;

-- ============ RPC 5: register meeting (write) ============
DROP FUNCTION IF EXISTS public.log_founder_coffee_register_meeting(text, text, text, timestamptz, text, text, text, int, text);
CREATE OR REPLACE FUNCTION public.log_founder_coffee_register_meeting(
  p_firm_name text,
  p_partner_name text,
  p_partner_email text,
  p_meeting_at timestamptz,
  p_meeting_kind text,
  p_location text,
  p_virtual_meeting_url text,
  p_duration_minutes int,
  p_our_attendees text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_firm_name IS NULL OR length(trim(p_firm_name))=0 THEN RAISE EXCEPTION 'firm_name required'; END IF;
  IF p_meeting_at IS NULL THEN RAISE EXCEPTION 'meeting_at required'; END IF;
  INSERT INTO public.founder_investor_coffee_meetings
    (investor_firm_name, investor_partner_name, investor_partner_email, meeting_at, meeting_kind, location, virtual_meeting_url, duration_minutes, our_attendees)
  VALUES
    (p_firm_name, p_partner_name, p_partner_email, p_meeting_at, COALESCE(p_meeting_kind,'informal_coffee'), p_location, p_virtual_meeting_url, p_duration_minutes, p_our_attendees)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$fn$;
REVOKE ALL ON FUNCTION public.log_founder_coffee_register_meeting(text, text, text, timestamptz, text, text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_coffee_register_meeting(text, text, text, timestamptz, text, text, text, int, text) TO authenticated;

-- ============ RPC 6: record outcome (write) ============
DROP FUNCTION IF EXISTS public.log_founder_coffee_record_outcome(uuid, text, text, boolean, date, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_coffee_record_outcome(
  p_meeting_id uuid,
  p_outcome_summary text,
  p_sentiment text,
  p_follow_up_required boolean,
  p_follow_up_due_date date,
  p_follow_up_action_text text,
  p_deal_track text,
  p_notes text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_meeting_id IS NULL THEN RAISE EXCEPTION 'meeting_id required'; END IF;
  UPDATE public.founder_investor_coffee_meetings
    SET status = 'completed',
        outcome_summary = COALESCE(p_outcome_summary, outcome_summary),
        sentiment = COALESCE(p_sentiment, sentiment),
        follow_up_required = COALESCE(p_follow_up_required, follow_up_required),
        follow_up_due_date = COALESCE(p_follow_up_due_date, follow_up_due_date),
        follow_up_action_text = COALESCE(p_follow_up_action_text, follow_up_action_text),
        deal_track = COALESCE(p_deal_track, deal_track),
        notes = COALESCE(p_notes, notes),
        updated_at = now()
  WHERE id = p_meeting_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'meeting not found'; END IF;
END;
$fn$;
REVOKE ALL ON FUNCTION public.log_founder_coffee_record_outcome(uuid, text, text, boolean, date, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_coffee_record_outcome(uuid, text, text, boolean, date, text, text, text) TO authenticated;

-- ============ RPC 7: add conversation note (write) ============
DROP FUNCTION IF EXISTS public.log_founder_coffee_add_conversation_note(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_coffee_add_conversation_note(
  p_meeting_id uuid,
  p_topic text,
  p_note_text text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_meeting_id IS NULL OR p_topic IS NULL OR p_note_text IS NULL THEN RAISE EXCEPTION 'all params required'; END IF;
  INSERT INTO public.founder_investor_coffee_conversation_notes (meeting_id, topic, note_text, created_by)
  VALUES (p_meeting_id, p_topic, p_note_text, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$fn$;
REVOKE ALL ON FUNCTION public.log_founder_coffee_add_conversation_note(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_coffee_add_conversation_note(uuid, text, text) TO authenticated;

COMMIT;