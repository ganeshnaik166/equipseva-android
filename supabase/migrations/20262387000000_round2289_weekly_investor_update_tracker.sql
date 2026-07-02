BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_update_drafts_r2289 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  subject text NOT NULL,
  body_md text NOT NULL,
  highlights_md text,
  lowlights_md text,
  asks_md text,
  metrics_snapshot_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  changed_since_last_week_md text,
  drafted_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  drafted_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','reviewed','sent','archived')),
  sent_at timestamptz,
  recipient_count int NOT NULL DEFAULT 0,
  open_rate_pct numeric(5,2),
  reply_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_update_responses_r2289 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid REFERENCES public.investor_update_drafts_r2289(id) ON DELETE CASCADE,
  investor_email text NOT NULL,
  investor_name text,
  response_type text NOT NULL CHECK (response_type IN ('reply','question','intro_offer','follow_on_interest','concern','kudos','no_response')),
  body_md text,
  sentiment text CHECK (sentiment IN ('positive','neutral','negative')),
  action_required boolean NOT NULL DEFAULT false,
  action_owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action_resolved_at timestamptz,
  received_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_update_drafts_r2289 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_update_responses_r2289 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.investor_update_drafts_r2289;
CREATE POLICY founder_all ON public.investor_update_drafts_r2289 FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.investor_update_responses_r2289;
CREATE POLICY founder_all ON public.investor_update_responses_r2289 FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

INSERT INTO public.investor_update_drafts_r2289 (week_start, subject, body_md, highlights_md, lowlights_md, asks_md, changed_since_last_week_md, status, sent_at, recipient_count, open_rate_pct, reply_count)
VALUES
  ((date_trunc('week', now()) - interval '4 week')::date, 'EquipSeva Weekly #18 — AMC base crosses 400', 'Hi investors,\n\nThis week we crossed 400 AMC contracts...', 'AMC base 412 (+18 WoW); MRR 18.4L (+6%); 3 new hospital chains in pipeline', 'P0 incident Tue (3hr MRI downtime); 4.1% AMC churn (target <3%)', 'Intros to mid-size hospital CXOs in Bangalore + Chennai', 'AMC base growth accelerated; churn slightly worse; runway down to 14.2 months', 'sent', now() - interval '4 week', 24, 87.5, 6),
  ((date_trunc('week', now()) - interval '3 week')::date, 'EquipSeva Weekly #19 — First franchise LOI signed', 'Hi investors,\n\nBig week: signed first franchise LOI for Pune...', 'Franchise LOI Pune signed; engineer count 108 (+5); Cashfree payouts cleared 9.8L', 'SLA breach 7.2% (still above 5% target); 2 DPDP grievances filed', 'Franchisee referrals in Tier-2 cities (target list attached)', 'Franchise model validated; SLA breaches concerning; cashflow improved', 'sent', now() - interval '3 week', 24, 91.6, 8),
  ((date_trunc('week', now()) - interval '2 week')::date, 'EquipSeva Weekly #20 — v0.5 ships', 'Hi investors,\n\nWe shipped v0.5 with hospital chains support...', 'v0.5 shipped (8 of 10 phases); 11 new hospital signups; weekly board pack live', 'Cashfree KYC still pending (blocking Phase 1); 1 P0 ANR crash Tue', 'KYC contact at Cashfree if anyone has one', 'v0.5 release was the unlock; Cashfree KYC is now critical-path blocker', 'sent', now() - interval '2 week', 25, 88.0, 7),
  ((date_trunc('week', now()) - interval '1 week')::date, 'EquipSeva Weekly #21 — Tier-1 home dashboard live', 'Hi investors,\n\nTier-1 founder home dashboard went live...', 'Tier-1 home live; spot-audit cron active; GST filing auto-generation working', 'Hospital chain churn 1 (Aster Medcity paused); engineer payout delay 2 days', 'Aster Medcity recovery intro to Dr. Azad', 'Founder dashboard now drives all daily decisions; one chain churn this week', 'sent', now() - interval '1 week', 25, 92.0, 9),
  (date_trunc('week', now())::date, 'EquipSeva Weekly #22 — Draft in progress', 'Hi investors,\n\nDRAFT — to be finalized Fri 5pm...', 'AMC base projected 430; first international pilot conversation (SL)', 'Cashfree still pending; engineer cert-ladder uptake slow', 'Sri Lanka hospital association intros', 'International pilot signal is new; Cashfree blocker continues', 'draft', NULL, 0, NULL, 0)
ON CONFLICT (week_start) DO NOTHING;

INSERT INTO public.investor_update_responses_r2289 (draft_id, investor_email, investor_name, response_type, body_md, sentiment, action_required, received_at)
SELECT id, 'lp1@accel.example', 'Subrata Mitra', 'reply', 'Great progress on AMC. Watch SLA closely.', 'positive', false, sent_at + interval '4 hour' FROM public.investor_update_drafts_r2289 WHERE status = 'sent' LIMIT 1;
INSERT INTO public.investor_update_responses_r2289 (draft_id, investor_email, investor_name, response_type, body_md, sentiment, action_required, received_at)
SELECT id, 'lp2@sequoia.example', 'Rajan Anandan', 'follow_on_interest', 'Interested in leading next round. Lets chat.', 'positive', true, sent_at + interval '6 hour' FROM public.investor_update_drafts_r2289 WHERE status = 'sent' LIMIT 1;
INSERT INTO public.investor_update_responses_r2289 (draft_id, investor_email, investor_name, response_type, body_md, sentiment, action_required, received_at)
SELECT id, 'lp3@matrix.example', 'Avnish Bajaj', 'question', 'What is the SLA breach root cause?', 'neutral', true, sent_at + interval '2 hour' FROM public.investor_update_drafts_r2289 WHERE status = 'sent' OFFSET 1 LIMIT 1;
INSERT INTO public.investor_update_responses_r2289 (draft_id, investor_email, investor_name, response_type, body_md, sentiment, action_required, received_at)
SELECT id, 'lp4@blume.example', 'Karthik Reddy', 'intro_offer', 'Can intro you to Apollo Hospitals CFO.', 'positive', true, sent_at + interval '1 day' FROM public.investor_update_drafts_r2289 WHERE status = 'sent' OFFSET 2 LIMIT 1;
INSERT INTO public.investor_update_responses_r2289 (draft_id, investor_email, investor_name, response_type, body_md, sentiment, action_required, received_at)
SELECT id, 'lp5@nexus.example', 'Jishnu Bhattacharjee', 'concern', 'Cashfree KYC delay is concerning. Backup plan?', 'negative', true, sent_at + interval '8 hour' FROM public.investor_update_drafts_r2289 WHERE status = 'sent' OFFSET 2 LIMIT 1;
INSERT INTO public.investor_update_responses_r2289 (draft_id, investor_email, investor_name, response_type, body_md, sentiment, action_required, received_at)
SELECT id, 'lp6@kalaari.example', 'Vani Kola', 'kudos', 'Love the v0.5 ship. Keep it up.', 'positive', false, sent_at + interval '3 hour' FROM public.investor_update_drafts_r2289 WHERE status = 'sent' OFFSET 3 LIMIT 1;

CREATE OR REPLACE FUNCTION public.list_investor_update_drafts_r2289()
RETURNS TABLE(id uuid, week_start date, subject text, status text, drafted_at timestamptz, sent_at timestamptz, recipient_count int, open_rate_pct numeric, reply_count int, has_changed_since_last_week boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.week_start, d.subject, d.status, d.drafted_at, d.sent_at,
         d.recipient_count, d.open_rate_pct, d.reply_count,
         (d.changed_since_last_week_md IS NOT NULL AND length(d.changed_since_last_week_md) > 0) AS has_changed_since_last_week
  FROM public.investor_update_drafts_r2289 d
  ORDER BY d.week_start DESC;
END $$;

CREATE OR REPLACE FUNCTION public.investor_update_send_log_r2289()
RETURNS TABLE(week_start date, subject text, sent_at timestamptz, recipient_count int, open_rate_pct numeric, reply_count int, response_count int, action_required_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.week_start, d.subject, d.sent_at, d.recipient_count, d.open_rate_pct, d.reply_count,
         (SELECT (COUNT(*))::int FROM public.investor_update_responses_r2289 r WHERE r.draft_id = d.id) AS response_count,
         (SELECT (COUNT(*) FILTER (WHERE r.action_required AND r.action_resolved_at IS NULL))::int FROM public.investor_update_responses_r2289 r WHERE r.draft_id = d.id) AS action_required_count
  FROM public.investor_update_drafts_r2289 d
  WHERE d.status = 'sent'
  ORDER BY d.sent_at DESC NULLS LAST;
END $$;

CREATE OR REPLACE FUNCTION public.investor_responses_recent_r2289()
RETURNS TABLE(id uuid, week_start date, investor_email text, investor_name text, response_type text, sentiment text, action_required boolean, action_resolved boolean, received_at timestamptz, body_preview text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, d.week_start, r.investor_email, r.investor_name, r.response_type, r.sentiment,
         r.action_required, (r.action_resolved_at IS NOT NULL) AS action_resolved,
         r.received_at,
         CASE WHEN r.body_md IS NULL THEN ''
              WHEN length(r.body_md) > 80 THEN substring(r.body_md, 1, 80) || '...'
              ELSE r.body_md END AS body_preview
  FROM public.investor_update_responses_r2289 r
  JOIN public.investor_update_drafts_r2289 d ON d.id = r.draft_id
  ORDER BY r.received_at DESC
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.investor_update_changes_log_r2289()
RETURNS TABLE(week_start date, subject text, status text, changed_since_last_week_md text, highlights_md text, lowlights_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.week_start, d.subject, d.status, d.changed_since_last_week_md, d.highlights_md, d.lowlights_md
  FROM public.investor_update_drafts_r2289 d
  WHERE d.changed_since_last_week_md IS NOT NULL
  ORDER BY d.week_start DESC;
END $$;

CREATE OR REPLACE FUNCTION public.investor_update_response_breakdown_r2289()
RETURNS TABLE(response_type text, total_count int, action_required_count int, action_resolved_count int, positive_count int, negative_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.response_type,
         (COUNT(*))::int AS total_count,
         (COUNT(*) FILTER (WHERE r.action_required))::int AS action_required_count,
         (COUNT(*) FILTER (WHERE r.action_resolved_at IS NOT NULL))::int AS action_resolved_count,
         (COUNT(*) FILTER (WHERE r.sentiment = 'positive'))::int AS positive_count,
         (COUNT(*) FILTER (WHERE r.sentiment = 'negative'))::int AS negative_count
  FROM public.investor_update_responses_r2289 r
  GROUP BY r.response_type
  ORDER BY total_count DESC;
END $$;

CREATE OR REPLACE FUNCTION public.investor_update_pending_actions_r2289()
RETURNS TABLE(id uuid, week_start date, investor_email text, investor_name text, response_type text, body_preview text, age_days numeric, sentiment text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, d.week_start, r.investor_email, r.investor_name, r.response_type,
         CASE WHEN r.body_md IS NULL THEN ''
              WHEN length(r.body_md) > 80 THEN substring(r.body_md, 1, 80) || '...'
              ELSE r.body_md END AS body_preview,
         ROUND(EXTRACT(EPOCH FROM (now() - r.received_at)) / 86400.0, 1) AS age_days,
         r.sentiment
  FROM public.investor_update_responses_r2289 r
  JOIN public.investor_update_drafts_r2289 d ON d.id = r.draft_id
  WHERE r.action_required AND r.action_resolved_at IS NULL
  ORDER BY r.received_at ASC;
END $$;

CREATE OR REPLACE FUNCTION public.investor_update_overview_r2289()
RETURNS TABLE(total_drafts int, sent_drafts int, draft_in_progress int, total_responses int, pending_actions int, avg_open_rate_pct numeric, avg_reply_count numeric, positive_response_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT (COUNT(*))::int FROM public.investor_update_drafts_r2289) AS total_drafts,
    (SELECT (COUNT(*) FILTER (WHERE status = 'sent'))::int FROM public.investor_update_drafts_r2289) AS sent_drafts,
    (SELECT (COUNT(*) FILTER (WHERE status = 'draft'))::int FROM public.investor_update_drafts_r2289) AS draft_in_progress,
    (SELECT (COUNT(*))::int FROM public.investor_update_responses_r2289) AS total_responses,
    (SELECT (COUNT(*) FILTER (WHERE action_required AND action_resolved_at IS NULL))::int FROM public.investor_update_responses_r2289) AS pending_actions,
    (SELECT ROUND(AVG(open_rate_pct)::numeric, 2) FROM public.investor_update_drafts_r2289 WHERE open_rate_pct IS NOT NULL) AS avg_open_rate_pct,
    (SELECT ROUND(AVG(reply_count)::numeric, 2) FROM public.investor_update_drafts_r2289 WHERE status = 'sent') AS avg_reply_count,
    (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE sentiment = 'positive') / NULLIF(COUNT(*), 0), 1)::numeric FROM public.investor_update_responses_r2289) AS positive_response_pct;
END $$;

REVOKE ALL ON FUNCTION public.list_investor_update_drafts_r2289() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.investor_update_send_log_r2289() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.investor_responses_recent_r2289() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.investor_update_changes_log_r2289() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.investor_update_response_breakdown_r2289() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.investor_update_pending_actions_r2289() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.investor_update_overview_r2289() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_update_drafts_r2289() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_update_send_log_r2289() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_responses_recent_r2289() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_update_changes_log_r2289() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_update_response_breakdown_r2289() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_update_pending_actions_r2289() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_update_overview_r2289() TO authenticated;

COMMIT;
