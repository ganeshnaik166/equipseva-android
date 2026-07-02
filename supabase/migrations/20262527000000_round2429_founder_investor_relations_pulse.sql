-- Round r2429: founder-investor-relations-pulse
-- Track investor touchpoints, sentiment, open asks, board pack engagement

BEGIN;

-- ============================================================
-- Table 1: investor_pulse_log_r2429
-- ============================================================
CREATE TABLE IF NOT EXISTS public.investor_pulse_log_r2429 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  investor_name text NOT NULL,
  firm_name text NOT NULL,
  investor_email text NOT NULL,
  last_touch_at timestamptz NOT NULL,
  touch_kind text NOT NULL CHECK (touch_kind IN ('call','email','meeting','board_pack','event')),
  cadence_target_days int NOT NULL CHECK (cadence_target_days > 0),
  gap_days int NOT NULL CHECK (gap_days >= 0),
  sentiment text NOT NULL CHECK (sentiment IN ('very_positive','positive','neutral','concerned','negative')),
  open_ask text,
  open_ask_due_at timestamptz,
  next_milestone text,
  next_milestone_due_at timestamptz,
  board_seat boolean NOT NULL DEFAULT false,
  notes text
);

ALTER TABLE public.investor_pulse_log_r2429 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.investor_pulse_log_r2429;
CREATE POLICY founder_all ON public.investor_pulse_log_r2429
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Table 2: investor_board_pack_sends_r2429
-- ============================================================
CREATE TABLE IF NOT EXISTS public.investor_board_pack_sends_r2429 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  quarter text NOT NULL,
  sent_at timestamptz NOT NULL,
  recipient_count int NOT NULL CHECK (recipient_count >= 0),
  viewed_count int NOT NULL CHECK (viewed_count >= 0),
  downloaded_count int NOT NULL CHECK (downloaded_count >= 0),
  top_questions_md text,
  founder_summary_md text,
  status text NOT NULL CHECK (status IN ('draft','sent','under_review','closed')),
  notes text
);

ALTER TABLE public.investor_board_pack_sends_r2429 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.investor_board_pack_sends_r2429;
CREATE POLICY founder_all ON public.investor_board_pack_sends_r2429
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seed data
-- ============================================================
INSERT INTO public.investor_pulse_log_r2429
  (investor_name, firm_name, investor_email, last_touch_at, touch_kind, cadence_target_days, gap_days, sentiment, open_ask, open_ask_due_at, next_milestone, next_milestone_due_at, board_seat, notes)
VALUES
  ('Aarav Mehta', 'Lightning Ventures', 'aarav@lightning.vc', now() - interval '12 days', 'meeting', 14, 12, 'very_positive', 'Q1 cohort retention deck', now() + interval '5 days', 'Series A term sheet', now() + interval '45 days', true, 'Lead investor, anchor of round'),
  ('Priya Sharma', 'Saffron Capital', 'priya@saffron.in', now() - interval '38 days', 'email', 21, 38, 'concerned', 'AMC churn breakdown', now() + interval '3 days', 'Q2 board meeting', now() + interval '20 days', true, 'Pushed on unit economics last call'),
  ('Rohit Iyer', 'Northwave Partners', 'rohit@northwave.co', now() - interval '7 days', 'call', 30, 7, 'positive', null, null, 'Hospital chain pilot KPI', now() + interval '30 days', false, 'Following warmly'),
  ('Meera Krishnan', 'Banyan Tree Fund', 'meera@banyan.fund', now() - interval '55 days', 'event', 30, 55, 'neutral', 'Cap table update', now() - interval '2 days', 'Reg AMC license proof', now() + interval '14 days', false, 'OVERDUE - last seen at conference'),
  ('Vikram Singh', 'Apex Angel Syndicate', 'vikram@apex.angel', now() - interval '2 days', 'board_pack', 45, 2, 'positive', 'Engineer tier ladder doc', now() + interval '10 days', 'v0.5 launch demo', now() + interval '60 days', false, 'Syndicate of 12 angels');

INSERT INTO public.investor_board_pack_sends_r2429
  (quarter, sent_at, recipient_count, viewed_count, downloaded_count, top_questions_md, founder_summary_md, status, notes)
VALUES
  ('Q1-2026', now() - interval '90 days', 18, 16, 11, '- AMC churn cohort\n- Engineer payout reliability\n- Hospital chain unit econ', 'Quarter closed with 38% MRR growth and first hospital chain pilot signed.', 'closed', 'Strongest engagement to date'),
  ('Q2-2026', now() - interval '5 days', 22, 14, 6, '- Cashfree KYC status\n- Engineer tier ladder progress\n- Spare-part counterfeit defense', 'Q2 focused on infra hardening and tier-2 city expansion.', 'under_review', 'Two LPs flagged follow-up questions'),
  ('Q3-2026', now() - interval '1 day', 24, 3, 1, null, 'Draft pending CFO review.', 'draft', 'To send EOD Friday');

-- ============================================================
-- RPC 1: list_investor_pulse_r2429
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_investor_pulse_r2429()
RETURNS TABLE (
  id uuid,
  investor_name text,
  firm_name text,
  investor_email text,
  last_touch_at timestamptz,
  touch_kind text,
  cadence_target_days int,
  gap_days int,
  sentiment text,
  open_ask text,
  open_ask_due_at timestamptz,
  next_milestone text,
  next_milestone_due_at timestamptz,
  board_seat boolean,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_name, p.firm_name, p.investor_email, p.last_touch_at,
         p.touch_kind, p.cadence_target_days, p.gap_days, p.sentiment,
         p.open_ask, p.open_ask_due_at, p.next_milestone, p.next_milestone_due_at,
         p.board_seat, p.notes
  FROM public.investor_pulse_log_r2429 p
  ORDER BY p.gap_days DESC, p.last_touch_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_investor_pulse_r2429() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_pulse_r2429() TO authenticated;

-- ============================================================
-- RPC 2: list_board_pack_sends_r2429
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_board_pack_sends_r2429()
RETURNS TABLE (
  id uuid,
  quarter text,
  sent_at timestamptz,
  recipient_count int,
  viewed_count int,
  downloaded_count int,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.quarter, b.sent_at, b.recipient_count, b.viewed_count,
         b.downloaded_count, b.status, b.notes
  FROM public.investor_board_pack_sends_r2429 b
  ORDER BY b.sent_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_board_pack_sends_r2429() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_board_pack_sends_r2429() TO authenticated;

-- ============================================================
-- RPC 3: overdue_pulse_r2429
-- ============================================================
CREATE OR REPLACE FUNCTION public.overdue_pulse_r2429()
RETURNS TABLE (
  id uuid,
  investor_name text,
  firm_name text,
  gap_days int,
  cadence_target_days int,
  days_over int,
  sentiment text,
  board_seat boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_name, p.firm_name, p.gap_days, p.cadence_target_days,
         (p.gap_days - p.cadence_target_days)::int AS days_over,
         p.sentiment, p.board_seat
  FROM public.investor_pulse_log_r2429 p
  WHERE p.gap_days > p.cadence_target_days
  ORDER BY (p.gap_days - p.cadence_target_days) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.overdue_pulse_r2429() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_pulse_r2429() TO authenticated;

-- ============================================================
-- RPC 4: sentiment_breakdown_r2429
-- ============================================================
CREATE OR REPLACE FUNCTION public.sentiment_breakdown_r2429()
RETURNS TABLE (
  sentiment text,
  investor_count bigint,
  board_seat_count bigint,
  avg_gap_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.sentiment,
         count(*)::bigint AS investor_count,
         count(*) FILTER (WHERE p.board_seat)::bigint AS board_seat_count,
         round(avg(p.gap_days)::numeric, 1) AS avg_gap_days
  FROM public.investor_pulse_log_r2429 p
  GROUP BY p.sentiment
  ORDER BY investor_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.sentiment_breakdown_r2429() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sentiment_breakdown_r2429() TO authenticated;

-- ============================================================
-- RPC 5: open_asks_r2429
-- ============================================================
CREATE OR REPLACE FUNCTION public.open_asks_r2429()
RETURNS TABLE (
  id uuid,
  investor_name text,
  firm_name text,
  open_ask text,
  open_ask_due_at timestamptz,
  days_until_due int,
  sentiment text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_name, p.firm_name, p.open_ask, p.open_ask_due_at,
         extract(day FROM (p.open_ask_due_at - now()))::int AS days_until_due,
         p.sentiment
  FROM public.investor_pulse_log_r2429 p
  WHERE p.open_ask IS NOT NULL
  ORDER BY p.open_ask_due_at ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.open_asks_r2429() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_asks_r2429() TO authenticated;

-- ============================================================
-- RPC 6: upcoming_milestones_r2429
-- ============================================================
CREATE OR REPLACE FUNCTION public.upcoming_milestones_r2429()
RETURNS TABLE (
  id uuid,
  investor_name text,
  firm_name text,
  next_milestone text,
  next_milestone_due_at timestamptz,
  days_until int,
  board_seat boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_name, p.firm_name, p.next_milestone, p.next_milestone_due_at,
         extract(day FROM (p.next_milestone_due_at - now()))::int AS days_until,
         p.board_seat
  FROM public.investor_pulse_log_r2429 p
  WHERE p.next_milestone IS NOT NULL
    AND p.next_milestone_due_at IS NOT NULL
  ORDER BY p.next_milestone_due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.upcoming_milestones_r2429() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_milestones_r2429() TO authenticated;

-- ============================================================
-- RPC 7: board_pack_engagement_r2429
-- ============================================================
CREATE OR REPLACE FUNCTION public.board_pack_engagement_r2429()
RETURNS TABLE (
  id uuid,
  quarter text,
  sent_at timestamptz,
  recipient_count int,
  viewed_count int,
  downloaded_count int,
  view_rate_pct numeric,
  download_rate_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.quarter, b.sent_at, b.recipient_count, b.viewed_count, b.downloaded_count,
         CASE WHEN b.recipient_count > 0
              THEN round((b.viewed_count::numeric / b.recipient_count) * 100, 1)
              ELSE 0 END AS view_rate_pct,
         CASE WHEN b.recipient_count > 0
              THEN round((b.downloaded_count::numeric / b.recipient_count) * 100, 1)
              ELSE 0 END AS download_rate_pct,
         b.status
  FROM public.investor_board_pack_sends_r2429 b
  ORDER BY b.sent_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.board_pack_engagement_r2429() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.board_pack_engagement_r2429() TO authenticated;

