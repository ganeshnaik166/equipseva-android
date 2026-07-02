-- Round 2517: Founder Quarterly Investor Portfolio Correspondence
-- Tracks per-quarter investor updates, their responses, asks, commitments, and stalled signals.

CREATE TABLE IF NOT EXISTS public.founder_quarterly_investor_correspondence_r2517 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  investor_name text NOT NULL,
  firm_name text,
  update_sent_at timestamptz NOT NULL DEFAULT now(),
  response_received_at timestamptz,
  response_kind text NOT NULL DEFAULT 'no_response'
    CHECK (response_kind IN ('positive','neutral','concerned','intro_offered','no_response')),
  ask_text text,
  commitment_kind text NOT NULL DEFAULT 'none'
    CHECK (commitment_kind IN ('none','follow_on','intro_to_lp','help_with_kpi','board_observer')),
  commitment_realized boolean NOT NULL DEFAULT false,
  stalled boolean NOT NULL DEFAULT false,
  owner_email text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_correspondence_follow_ups_r2517 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  correspondence_id uuid NOT NULL REFERENCES public.founder_quarterly_investor_correspondence_r2517(id) ON DELETE CASCADE,
  follow_up_at timestamptz NOT NULL DEFAULT now(),
  follow_up_kind text NOT NULL
    CHECK (follow_up_kind IN ('call','email','meeting','event','intro')),
  outcome text NOT NULL DEFAULT 'pending'
    CHECK (outcome IN ('positive','neutral','negative','pending')),
  next_step text,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_quarterly_investor_correspondence_r2517 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_correspondence_follow_ups_r2517 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_quarterly_investor_correspondence_r2517;
CREATE POLICY founder_all ON public.founder_quarterly_investor_correspondence_r2517
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.investor_correspondence_follow_ups_r2517;
CREATE POLICY founder_all ON public.investor_correspondence_follow_ups_r2517
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed correspondence rows
DO $seed$
DECLARE
  c1 uuid; c2 uuid; c3 uuid; c4 uuid; c5 uuid;
BEGIN
  INSERT INTO public.founder_quarterly_investor_correspondence_r2517
    (quarter_label, investor_name, firm_name, update_sent_at, response_received_at, response_kind, ask_text, commitment_kind, commitment_realized, stalled, owner_email, notes)
  VALUES ('Q1 2026','Aarti Mehra','BlueLotus Ventures','2026-04-05 09:00:00+05:30'::timestamptz,'2026-04-07 11:30:00+05:30'::timestamptz,'positive','Intro to 2 hospital-chain LPs','intro_to_lp',true,false,'founder@equipseva.in','Warm and engaged; promised intros within 2 weeks')
  RETURNING id INTO c1;

  INSERT INTO public.founder_quarterly_investor_correspondence_r2517
    (quarter_label, investor_name, firm_name, update_sent_at, response_received_at, response_kind, ask_text, commitment_kind, commitment_realized, stalled, owner_email, notes)
  VALUES ('Q1 2026','Rohan Iyer','SaltMine Capital','2026-04-06 10:00:00+05:30'::timestamptz,'2026-04-15 16:00:00+05:30'::timestamptz,'concerned','Clarify churn cohort math','none',false,false,'founder@equipseva.in','Pushed back on retention numbers; needs deeper cohort cut')
  RETURNING id INTO c2;

  INSERT INTO public.founder_quarterly_investor_correspondence_r2517
    (quarter_label, investor_name, firm_name, update_sent_at, response_received_at, response_kind, ask_text, commitment_kind, commitment_realized, stalled, owner_email, notes)
  VALUES ('Q1 2026','Sneha Kulkarni','Apex Health Fund','2026-04-08 12:00:00+05:30'::timestamptz, NULL,'no_response','Follow-on participation in Series A','follow_on',false,true,'founder@equipseva.in','Two follow-ups unanswered; stalled')
  RETURNING id INTO c3;

  INSERT INTO public.founder_quarterly_investor_correspondence_r2517
    (quarter_label, investor_name, firm_name, update_sent_at, response_received_at, response_kind, ask_text, commitment_kind, commitment_realized, stalled, owner_email, notes)
  VALUES ('Q4 2025','Vikram Shah','Crescent Angels','2026-01-10 09:30:00+05:30'::timestamptz,'2026-01-12 18:00:00+05:30'::timestamptz,'intro_offered','Connect to NABH consultant network','help_with_kpi',true,false,'founder@equipseva.in','Delivered 3 NABH consultant intros same week')
  RETURNING id INTO c4;

  INSERT INTO public.founder_quarterly_investor_correspondence_r2517
    (quarter_label, investor_name, firm_name, update_sent_at, response_received_at, response_kind, ask_text, commitment_kind, commitment_realized, stalled, owner_email, notes)
  VALUES ('Q1 2026','Priya Nair','Banyan Growth','2026-04-09 14:00:00+05:30'::timestamptz,'2026-04-22 10:00:00+05:30'::timestamptz,'neutral','Board observer seat in next round','board_observer',false,false,'cofounder@equipseva.in','Will revisit at Series A pricing conversation')
  RETURNING id INTO c5;

  INSERT INTO public.investor_correspondence_follow_ups_r2517
    (correspondence_id, follow_up_at, follow_up_kind, outcome, next_step, owner_email, status, notes)
  VALUES
    (c1,'2026-04-12 11:00:00+05:30'::timestamptz,'call','positive','Schedule intro calls with 2 LPs','founder@equipseva.in','closed','LPs confirmed for next week'),
    (c2,'2026-04-20 15:00:00+05:30'::timestamptz,'email','neutral','Send cohort retention deep-dive','founder@equipseva.in','in_progress','Drafting cohort appendix'),
    (c3,'2026-05-02 10:00:00+05:30'::timestamptz,'email','pending','Send Q2 mid-quarter nudge','founder@equipseva.in','open','No reply to two prior emails'),
    (c3,'2026-05-25 10:00:00+05:30'::timestamptz,'event','pending','Invite to NASSCOM healthtech dinner','founder@equipseva.in','open','Last try before marking dropped'),
    (c4,'2026-01-18 17:00:00+05:30'::timestamptz,'meeting','positive','Quarterly board observer chat','founder@equipseva.in','closed','NABH intros all converted to consultations'),
    (c5,'2026-05-05 11:00:00+05:30'::timestamptz,'call','neutral','Share Series A timing memo','cofounder@equipseva.in','in_progress','Wants traction proof points');
END
$seed$;

-- RPC: list_correspondence_r2517
CREATE OR REPLACE FUNCTION public.list_correspondence_r2517()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  investor_name text,
  firm_name text,
  update_sent_at timestamptz,
  response_received_at timestamptz,
  response_kind text,
  ask_text text,
  commitment_kind text,
  commitment_realized boolean,
  stalled boolean,
  owner_email text,
  follow_up_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.quarter_label, c.investor_name, c.firm_name, c.update_sent_at,
         c.response_received_at, c.response_kind, c.ask_text, c.commitment_kind,
         c.commitment_realized, c.stalled, c.owner_email,
         (SELECT count(*) FROM public.investor_correspondence_follow_ups_r2517 f WHERE f.correspondence_id = c.id) AS follow_up_count
  FROM public.founder_quarterly_investor_correspondence_r2517 c
  ORDER BY c.update_sent_at DESC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_correspondence_r2517() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_correspondence_r2517() TO authenticated;

-- RPC: list_follow_ups_r2517
CREATE OR REPLACE FUNCTION public.list_follow_ups_r2517()
RETURNS TABLE (
  id uuid,
  correspondence_id uuid,
  investor_name text,
  quarter_label text,
  follow_up_at timestamptz,
  follow_up_kind text,
  outcome text,
  next_step text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.correspondence_id, c.investor_name, c.quarter_label,
         f.follow_up_at, f.follow_up_kind, f.outcome, f.next_step,
         f.owner_email, f.status
  FROM public.investor_correspondence_follow_ups_r2517 f
  JOIN public.founder_quarterly_investor_correspondence_r2517 c ON c.id = f.correspondence_id
  ORDER BY f.follow_up_at DESC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_follow_ups_r2517() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_follow_ups_r2517() TO authenticated;

-- RPC: stalled_investors_focus_r2517
CREATE OR REPLACE FUNCTION public.stalled_investors_focus_r2517()
RETURNS TABLE (
  investor_name text,
  firm_name text,
  quarter_label text,
  update_sent_at timestamptz,
  days_since_update integer,
  ask_text text,
  owner_email text,
  open_follow_ups bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.investor_name, c.firm_name, c.quarter_label, c.update_sent_at,
         EXTRACT(day FROM (now() - c.update_sent_at))::integer AS days_since_update,
         c.ask_text, c.owner_email,
         (SELECT count(*) FROM public.investor_correspondence_follow_ups_r2517 f
           WHERE f.correspondence_id = c.id AND f.status IN ('open','in_progress')) AS open_follow_ups
  FROM public.founder_quarterly_investor_correspondence_r2517 c
  WHERE c.stalled = true OR c.response_kind = 'no_response'
  ORDER BY c.update_sent_at ASC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.stalled_investors_focus_r2517() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stalled_investors_focus_r2517() TO authenticated;

-- RPC: commitment_distribution_r2517
CREATE OR REPLACE FUNCTION public.commitment_distribution_r2517()
RETURNS TABLE (
  commitment_kind text,
  total_count bigint,
  realized_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.commitment_kind,
         count(*) AS total_count,
         count(*) FILTER (WHERE c.commitment_realized) AS realized_count,
         count(*) FILTER (WHERE NOT c.commitment_realized) AS pending_count
  FROM public.founder_quarterly_investor_correspondence_r2517 c
  GROUP BY c.commitment_kind
  ORDER BY total_count DESC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.commitment_distribution_r2517() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commitment_distribution_r2517() TO authenticated;

-- RPC: response_kind_summary_r2517
CREATE OR REPLACE FUNCTION public.response_kind_summary_r2517()
RETURNS TABLE (
  response_kind text,
  total_count bigint,
  stalled_count bigint,
  avg_response_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.response_kind,
         count(*) AS total_count,
         count(*) FILTER (WHERE c.stalled) AS stalled_count,
         round(avg(EXTRACT(epoch FROM (c.response_received_at - c.update_sent_at)) / 3600.0)::numeric, 1) AS avg_response_hours
  FROM public.founder_quarterly_investor_correspondence_r2517 c
  GROUP BY c.response_kind
  ORDER BY total_count DESC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.response_kind_summary_r2517() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.response_kind_summary_r2517() TO authenticated;

-- RPC: quarterly_correspondence_trend_r2517
CREATE OR REPLACE FUNCTION public.quarterly_correspondence_trend_r2517()
RETURNS TABLE (
  quarter_label text,
  updates_sent bigint,
  responses_received bigint,
  positive_responses bigint,
  stalled_count bigint,
  commitments_realized bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.quarter_label,
         count(*) AS updates_sent,
         count(*) FILTER (WHERE c.response_received_at IS NOT NULL) AS responses_received,
         count(*) FILTER (WHERE c.response_kind = 'positive') AS positive_responses,
         count(*) FILTER (WHERE c.stalled) AS stalled_count,
         count(*) FILTER (WHERE c.commitment_realized) AS commitments_realized
  FROM public.founder_quarterly_investor_correspondence_r2517 c
  GROUP BY c.quarter_label
  ORDER BY c.quarter_label DESC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.quarterly_correspondence_trend_r2517() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_correspondence_trend_r2517() TO authenticated;

-- RPC: owner_load_r2517
CREATE OR REPLACE FUNCTION public.owner_load_r2517()
RETURNS TABLE (
  owner_email text,
  correspondence_count bigint,
  follow_up_count bigint,
  open_follow_ups bigint,
  stalled_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.owner_email,
         count(DISTINCT c.id) AS correspondence_count,
         (SELECT count(*) FROM public.investor_correspondence_follow_ups_r2517 f WHERE f.owner_email = c.owner_email) AS follow_up_count,
         (SELECT count(*) FROM public.investor_correspondence_follow_ups_r2517 f WHERE f.owner_email = c.owner_email AND f.status IN ('open','in_progress')) AS open_follow_ups,
         count(*) FILTER (WHERE c.stalled) AS stalled_count
  FROM public.founder_quarterly_investor_correspondence_r2517 c
  GROUP BY c.owner_email
  ORDER BY correspondence_count DESC;
END
$fn$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2517() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2517() TO authenticated;
