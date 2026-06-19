BEGIN;
-- r1343 — Founder investor meeting tracker.
--
-- Fundraising discipline: every investor conversation is a long arc — intro →
-- pitch → partner review → DD → term sheet → close (or pass). Founders forget
-- which firm last said what, which partner ghosted, which "warm intro" rotted
-- on the vine for 6 weeks. This module is the institutional memory of the
-- fundraise: who, what stage, last meeting, next follow-up, sentiment trend.
--
-- Two tables:
--   * founder_investor_targets — one row per firm/partner pairing. Holds the
--     deal-status state machine + priority + next-followup-due cadence.
--   * founder_investor_meetings — one row per meeting/touchpoint. Holds the
--     summary + sentiment + follow-up action.
--
-- KPIs surface: total targets, stage funnel (identified → closed_won), recent
-- meeting cadence (last 30d / this week), overdue follow-ups, avg sentiment.

-- ============================================================================
-- Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_investor_targets (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_firm_name       text NOT NULL UNIQUE,
  investor_partner_name    text,
  investor_partner_email   text,
  investor_partner_phone   text,
  check_size_min_rupees    numeric DEFAULT 0,
  check_size_max_rupees    numeric,
  stage_preference         text CHECK (stage_preference IN ('preseed','seed','seriesA','seriesB','growth','any')),
  sector_fit               text,
  deal_status              text NOT NULL DEFAULT 'identified' CHECK (deal_status IN
                             ('identified','first_meeting','partner_review','dd_in_progress','term_sheet','passed','closed_won')),
  priority                 text NOT NULL DEFAULT 'medium' CHECK (priority IN ('high','medium','low')),
  first_meeting_at         timestamptz,
  last_meeting_at          timestamptz,
  next_followup_due_at     date,
  referred_by              text,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_investor_targets IS
  'Investor pipeline — one row per firm/partner. Deal-status state machine + priority + follow-up cadence.';

CREATE INDEX IF NOT EXISTS idx_founder_investor_targets_status   ON public.founder_investor_targets (deal_status);
CREATE INDEX IF NOT EXISTS idx_founder_investor_targets_priority ON public.founder_investor_targets (priority);
CREATE INDEX IF NOT EXISTS idx_founder_investor_targets_followup ON public.founder_investor_targets (next_followup_due_at) WHERE next_followup_due_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_founder_investor_targets_lastmtg  ON public.founder_investor_targets (last_meeting_at DESC NULLS LAST);

ALTER TABLE public.founder_investor_targets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_investor_targets_no_direct ON public.founder_investor_targets;
CREATE POLICY founder_investor_targets_no_direct ON public.founder_investor_targets FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_investor_targets FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.founder_investor_meetings (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id           uuid NOT NULL REFERENCES public.founder_investor_targets(id) ON DELETE CASCADE,
  meeting_at          timestamptz NOT NULL,
  meeting_kind        text CHECK (meeting_kind IN
                        ('intro','pitch','deep_dive','partner_meeting','dd_call','term_negotiation','closing','social')),
  attendees           text,
  summary             text,
  sentiment           text CHECK (sentiment IN ('strongly_positive','positive','neutral','cool','negative')),
  follow_up_needed    boolean NOT NULL DEFAULT true,
  follow_up_action    text,
  follow_up_due       date,
  created_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_investor_meetings IS
  'Investor meeting log — one row per touchpoint. Summary + sentiment + follow-up commitment.';

CREATE INDEX IF NOT EXISTS idx_founder_investor_meetings_target  ON public.founder_investor_meetings (target_id, meeting_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_investor_meetings_when    ON public.founder_investor_meetings (meeting_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_investor_meetings_followup ON public.founder_investor_meetings (follow_up_due) WHERE follow_up_needed = true;

ALTER TABLE public.founder_investor_meetings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_investor_meetings_no_direct ON public.founder_investor_meetings;
CREATE POLICY founder_investor_meetings_no_direct ON public.founder_investor_meetings FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_investor_meetings FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Write-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_investor_register_target(text, text, text, text, numeric, numeric, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_investor_register_target(
  p_firm_name      text,
  p_partner_name   text DEFAULT NULL,
  p_partner_email  text DEFAULT NULL,
  p_partner_phone  text DEFAULT NULL,
  p_check_min      numeric DEFAULT 0,
  p_check_max      numeric DEFAULT NULL,
  p_stage_pref     text DEFAULT 'seed',
  p_sector_fit     text DEFAULT NULL,
  p_priority       text DEFAULT 'medium',
  p_referred_by    text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  INSERT INTO public.founder_investor_targets
    (investor_firm_name, investor_partner_name, investor_partner_email, investor_partner_phone,
     check_size_min_rupees, check_size_max_rupees, stage_preference, sector_fit,
     priority, referred_by)
  VALUES
    (p_firm_name, p_partner_name, p_partner_email, p_partner_phone,
     coalesce(p_check_min, 0), p_check_max, p_stage_pref, p_sector_fit,
     p_priority, p_referred_by)
  ON CONFLICT (investor_firm_name) DO UPDATE
    SET investor_partner_name  = coalesce(EXCLUDED.investor_partner_name,  public.founder_investor_targets.investor_partner_name),
        investor_partner_email = coalesce(EXCLUDED.investor_partner_email, public.founder_investor_targets.investor_partner_email),
        investor_partner_phone = coalesce(EXCLUDED.investor_partner_phone, public.founder_investor_targets.investor_partner_phone),
        priority               = EXCLUDED.priority,
        updated_at             = now()
    RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_investor_register_target(text, text, text, text, numeric, numeric, text, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_investor_register_target(text, text, text, text, numeric, numeric, text, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_investor_log_meeting(uuid, timestamptz, text, text, text, text, boolean, text, date);
CREATE OR REPLACE FUNCTION public.log_founder_investor_log_meeting(
  p_target_id        uuid,
  p_meeting_at       timestamptz,
  p_meeting_kind     text DEFAULT 'intro',
  p_attendees        text DEFAULT NULL,
  p_summary          text DEFAULT NULL,
  p_sentiment        text DEFAULT 'neutral',
  p_follow_up_needed boolean DEFAULT true,
  p_follow_up_action text DEFAULT NULL,
  p_follow_up_due    date DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  INSERT INTO public.founder_investor_meetings
    (target_id, meeting_at, meeting_kind, attendees, summary, sentiment,
     follow_up_needed, follow_up_action, follow_up_due, created_by)
  VALUES
    (p_target_id, p_meeting_at, p_meeting_kind, p_attendees, p_summary, p_sentiment,
     coalesce(p_follow_up_needed, true), p_follow_up_action, p_follow_up_due, auth.uid())
  RETURNING id INTO v_id;

  UPDATE public.founder_investor_targets
    SET last_meeting_at      = greatest(coalesce(last_meeting_at, p_meeting_at), p_meeting_at),
        first_meeting_at     = coalesce(first_meeting_at, p_meeting_at),
        next_followup_due_at = coalesce(p_follow_up_due, next_followup_due_at),
        updated_at           = now()
    WHERE id = p_target_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_investor_log_meeting(uuid, timestamptz, text, text, text, text, boolean, text, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_investor_log_meeting(uuid, timestamptz, text, text, text, text, boolean, text, date) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_investor_status_change(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_investor_status_change(
  p_target_id uuid,
  p_new_status text,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_new_status NOT IN ('identified','first_meeting','partner_review','dd_in_progress','term_sheet','passed','closed_won') THEN
    RAISE EXCEPTION 'invalid deal_status %', p_new_status USING ERRCODE = '22023';
  END IF;
  UPDATE public.founder_investor_targets
    SET deal_status = p_new_status,
        notes       = CASE WHEN p_note IS NULL THEN notes
                           ELSE coalesce(notes || E'\n', '') || to_char(now(), 'YYYY-MM-DD') || ' → ' || p_new_status || ': ' || p_note END,
        updated_at  = now()
    WHERE id = p_target_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_investor_status_change(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_investor_status_change(uuid, text, text) TO authenticated;

-- ============================================================================
-- Read-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_investor_meeting_tracker_summary();
CREATE OR REPLACE FUNCTION public.founder_investor_meeting_tracker_summary()
RETURNS TABLE (
  total_targets               bigint,
  identified_count            bigint,
  first_meeting_count         bigint,
  partner_review_count        bigint,
  dd_count                    bigint,
  term_sheet_count            bigint,
  closed_won_count            bigint,
  passed_count                bigint,
  total_meetings              bigint,
  meetings_last_30d           bigint,
  meetings_this_week          bigint,
  overdue_followups_count     bigint,
  avg_sentiment_score         numeric,
  top_priority_targets        bigint,
  days_to_next_meeting_min    int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets WHERE deal_status = 'identified'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets WHERE deal_status = 'first_meeting'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets WHERE deal_status = 'partner_review'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets WHERE deal_status = 'dd_in_progress'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets WHERE deal_status = 'term_sheet'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets WHERE deal_status = 'closed_won'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets WHERE deal_status = 'passed'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_meetings), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_meetings WHERE meeting_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_meetings WHERE meeting_at >= date_trunc('week', now())), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets
              WHERE next_followup_due_at IS NOT NULL AND next_followup_due_at < current_date
                AND deal_status NOT IN ('closed_won','passed')), 0),
    coalesce((SELECT round(avg(CASE sentiment
                                 WHEN 'strongly_positive' THEN 2
                                 WHEN 'positive'          THEN 1
                                 WHEN 'neutral'           THEN 0
                                 WHEN 'cool'              THEN -1
                                 WHEN 'negative'          THEN -2
                                 ELSE 0 END)::numeric, 2)
              FROM public.founder_investor_meetings WHERE meeting_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.founder_investor_targets
              WHERE priority = 'high' AND deal_status NOT IN ('closed_won','passed')), 0),
    coalesce((SELECT (next_followup_due_at - current_date)::int
              FROM public.founder_investor_targets
              WHERE next_followup_due_at IS NOT NULL
                AND next_followup_due_at >= current_date
                AND deal_status NOT IN ('closed_won','passed')
              ORDER BY next_followup_due_at ASC LIMIT 1), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_meeting_tracker_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_meeting_tracker_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_investor_targets_recent(int);
CREATE OR REPLACE FUNCTION public.founder_investor_targets_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  id                       uuid,
  investor_firm_name       text,
  investor_partner_name    text,
  deal_status              text,
  priority                 text,
  stage_preference         text,
  check_size_min_rupees    numeric,
  check_size_max_rupees    numeric,
  first_meeting_at         timestamptz,
  last_meeting_at          timestamptz,
  next_followup_due_at     date,
  days_since_last_meeting  int,
  meetings_count           bigint,
  referred_by              text,
  created_at               timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT t.id,
         t.investor_firm_name,
         t.investor_partner_name,
         t.deal_status,
         t.priority,
         t.stage_preference,
         t.check_size_min_rupees,
         t.check_size_max_rupees,
         t.first_meeting_at,
         t.last_meeting_at,
         t.next_followup_due_at,
         CASE WHEN t.last_meeting_at IS NULL THEN NULL
              ELSE extract(day from (now() - t.last_meeting_at))::int END,
         (SELECT count(*)::bigint FROM public.founder_investor_meetings m WHERE m.target_id = t.id),
         t.referred_by,
         t.created_at
    FROM public.founder_investor_targets t
    ORDER BY CASE t.priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END,
             t.last_meeting_at DESC NULLS LAST,
             t.created_at DESC
    LIMIT greatest(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_targets_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_targets_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_investor_meetings_recent(uuid, int);
CREATE OR REPLACE FUNCTION public.founder_investor_meetings_recent(p_target_id uuid DEFAULT NULL, p_limit int DEFAULT 50)
RETURNS TABLE (
  id                uuid,
  target_id         uuid,
  firm_name         text,
  partner_name      text,
  meeting_at        timestamptz,
  meeting_kind      text,
  attendees         text,
  summary           text,
  sentiment         text,
  follow_up_needed  boolean,
  follow_up_action  text,
  follow_up_due     date,
  created_at        timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT m.id,
         m.target_id,
         t.investor_firm_name,
         t.investor_partner_name,
         m.meeting_at,
         m.meeting_kind,
         m.attendees,
         m.summary,
         m.sentiment,
         m.follow_up_needed,
         m.follow_up_action,
         m.follow_up_due,
         m.created_at
    FROM public.founder_investor_meetings m
    JOIN public.founder_investor_targets t ON t.id = m.target_id
    WHERE (p_target_id IS NULL OR m.target_id = p_target_id)
    ORDER BY m.meeting_at DESC
    LIMIT greatest(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_meetings_recent(uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_meetings_recent(uuid, int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_investor_overdue_followups();
CREATE OR REPLACE FUNCTION public.founder_investor_overdue_followups()
RETURNS TABLE (
  id                    uuid,
  investor_firm_name    text,
  investor_partner_name text,
  deal_status           text,
  priority              text,
  next_followup_due_at  date,
  days_overdue          int,
  last_meeting_at       timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT t.id,
         t.investor_firm_name,
         t.investor_partner_name,
         t.deal_status,
         t.priority,
         t.next_followup_due_at,
         (current_date - t.next_followup_due_at)::int,
         t.last_meeting_at
    FROM public.founder_investor_targets t
    WHERE t.next_followup_due_at IS NOT NULL
      AND t.next_followup_due_at < current_date
      AND t.deal_status NOT IN ('closed_won','passed')
    ORDER BY (current_date - t.next_followup_due_at) DESC,
             CASE t.priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_overdue_followups() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_overdue_followups() TO authenticated;

COMMIT;