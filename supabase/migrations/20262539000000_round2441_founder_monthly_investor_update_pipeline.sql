-- Round 2441: Founder Monthly Investor Update Pipeline
-- Tracks monthly investor updates lifecycle (draft → sent → opened → replied → closed)
-- plus per-reply follow-up workflow.

CREATE TABLE IF NOT EXISTS public.investor_monthly_updates_r2441 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  month_label text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','sent','opened','replied','closed')),
  sent_at timestamptz,
  recipient_count int NOT NULL DEFAULT 0 CHECK (recipient_count >= 0),
  opened_count int NOT NULL DEFAULT 0 CHECK (opened_count >= 0),
  replied_count int NOT NULL DEFAULT 0 CHECK (replied_count >= 0),
  kpi_summary_md text,
  asks_md text,
  commitments_md text,
  top_question_summary_md text,
  notes text
);

CREATE TABLE IF NOT EXISTS public.update_recipient_replies_r2441 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  update_id uuid NOT NULL REFERENCES public.investor_monthly_updates_r2441(id) ON DELETE CASCADE,
  investor_name text NOT NULL,
  replied_at timestamptz NOT NULL DEFAULT now(),
  reply_kind text NOT NULL
    CHECK (reply_kind IN ('positive','neutral','concerned','intro_offer','follow_up_meeting','ask')),
  reply_summary text,
  follow_up_required boolean NOT NULL DEFAULT false,
  follow_up_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','dropped')),
  notes text
);

CREATE INDEX IF NOT EXISTS idx_imu_r2441_status ON public.investor_monthly_updates_r2441(status);
CREATE INDEX IF NOT EXISTS idx_imu_r2441_sent ON public.investor_monthly_updates_r2441(sent_at);
CREATE INDEX IF NOT EXISTS idx_urr_r2441_update ON public.update_recipient_replies_r2441(update_id);
CREATE INDEX IF NOT EXISTS idx_urr_r2441_followup ON public.update_recipient_replies_r2441(follow_up_at);

ALTER TABLE public.investor_monthly_updates_r2441 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.update_recipient_replies_r2441 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.investor_monthly_updates_r2441;
CREATE POLICY founder_all ON public.investor_monthly_updates_r2441
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.update_recipient_replies_r2441;
CREATE POLICY founder_all ON public.update_recipient_replies_r2441
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed 4 monthly updates
INSERT INTO public.investor_monthly_updates_r2441
  (month_label, status, sent_at, recipient_count, opened_count, replied_count, kpi_summary_md, asks_md, commitments_md, top_question_summary_md, notes)
VALUES
  ('2026-03', 'closed', '2026-04-02 09:00:00+05:30'::timestamptz, 24, 22, 11,
    '* MRR ₹14.2L (+18%)\n* AMC contracts: 312 (+27)\n* Engineer utilization 71%',
    '* Warm intros to 2 hospital chains in Pune\n* Feedback on AMC pricing tiers',
    '* Ship payment-first AMC by Apr 15\n* Cashfree KYC by Apr 30',
    'Mostly: unit economics + path to Series A',
    'Strong cohort response; 3 intro offers landed'),
  ('2026-04', 'closed', '2026-05-03 09:00:00+05:30'::timestamptz, 26, 24, 14,
    '* MRR ₹17.8L (+25%)\n* AMC contracts: 358 (+46)\n* NABH-ready hospitals: 8',
    '* Series A bridge ₹6Cr open\n* Dental vertical advisor intro',
    '* Close bridge by May 31\n* 2 hospital chain pilots',
    'Defensibility vs HealthPlix / Doctor365',
    '2 lead investors moved to DD'),
  ('2026-05', 'replied', '2026-06-02 09:00:00+05:30'::timestamptz, 28, 25, 9,
    '* MRR ₹21.4L (+20%)\n* AMC: 412\n* Engineer NPS 64',
    '* SAFE leads ₹2Cr remaining\n* Pricing reference benchmarks',
    '* Hospital chain v1 by Jun 30\n* Investor portal by Jul 15',
    'How are you handling counterfeit parts at scale?',
    'Counterfeit narrative landing well after r500 bonded parts ship'),
  ('2026-06', 'draft', null, 0, 0, 0,
    '* MRR ₹26.1L (+22%) projected\n* AMC: 478\n* 22 hospital chains active',
    '* Strategic intros to 3 PE healthtech funds\n* Hire VP Engineering',
    '* International pilot Sri Lanka by Aug\n* Engineer app v0.6',
    null,
    'Drafting after r1369 milestone wave')
;

-- Seed replies (link to first two closed updates)
WITH apr AS (SELECT id FROM public.investor_monthly_updates_r2441 WHERE month_label='2026-04' LIMIT 1),
     mar AS (SELECT id FROM public.investor_monthly_updates_r2441 WHERE month_label='2026-03' LIMIT 1),
     may AS (SELECT id FROM public.investor_monthly_updates_r2441 WHERE month_label='2026-05' LIMIT 1)
INSERT INTO public.update_recipient_replies_r2441
  (update_id, investor_name, replied_at, reply_kind, reply_summary, follow_up_required, follow_up_at, owner_email, status, notes)
SELECT (SELECT id FROM apr), 'Blume Ventures', '2026-05-04 11:20:00+05:30'::timestamptz, 'follow_up_meeting',
       'Wants 30-min deep-dive on unit economics + cohort retention', true, '2026-05-10 16:00:00+05:30'::timestamptz,
       'ganesh@equipseva.com', 'done', 'Meeting happened; moved to term-sheet conversation'
UNION ALL
SELECT (SELECT id FROM apr), 'Kalaari Capital', '2026-05-05 09:14:00+05:30'::timestamptz, 'intro_offer',
       'Intro to 2 Tier-2 hospital chain CEOs', true, '2026-05-12 10:00:00+05:30'::timestamptz,
       'ganesh@equipseva.com', 'in_progress', 'Both intros sent; awaiting hospital responses'
UNION ALL
SELECT (SELECT id FROM mar), 'Stellaris', '2026-04-04 18:22:00+05:30'::timestamptz, 'concerned',
       'Worried about engineer churn given low payouts', true, '2026-04-15 11:00:00+05:30'::timestamptz,
       'ganesh@equipseva.com', 'done', 'Walked through tier ladder + retention data; resolved'
UNION ALL
SELECT (SELECT id FROM mar), 'Angel Aakash', '2026-04-03 21:00:00+05:30'::timestamptz, 'positive',
       'Loves the bonded-parts angle; ready to follow-on', false, null,
       'ganesh@equipseva.com', 'done', 'Confirmed pro-rata for bridge'
UNION ALL
SELECT (SELECT id FROM may), 'Accel India', '2026-06-03 10:11:00+05:30'::timestamptz, 'ask',
       'Wants counterfeit-parts unit economics breakdown', true, '2026-06-25 14:00:00+05:30'::timestamptz,
       'ganesh@equipseva.com', 'open', 'Building data pack from spare_parts_bonded ledger'
UNION ALL
SELECT (SELECT id FROM may), 'Matrix Partners', '2026-06-04 15:30:00+05:30'::timestamptz, 'neutral',
       'Will revisit at ₹50L MRR', false, null,
       'ganesh@equipseva.com', 'dropped', 'Not active for this round';

-- RPC 1: list_updates_r2441
CREATE OR REPLACE FUNCTION public.list_updates_r2441()
RETURNS TABLE (
  id uuid,
  month_label text,
  status text,
  sent_at timestamptz,
  recipient_count int,
  opened_count int,
  replied_count int,
  open_rate_pct numeric,
  reply_rate_pct numeric,
  kpi_summary_md text,
  asks_md text,
  commitments_md text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.month_label, u.status, u.sent_at, u.recipient_count, u.opened_count, u.replied_count,
         CASE WHEN u.recipient_count > 0
              THEN round(100.0 * u.opened_count / u.recipient_count, 1)
              ELSE 0 END,
         CASE WHEN u.recipient_count > 0
              THEN round(100.0 * u.replied_count / u.recipient_count, 1)
              ELSE 0 END,
         u.kpi_summary_md, u.asks_md, u.commitments_md, u.notes
  FROM public.investor_monthly_updates_r2441 u
  ORDER BY u.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_updates_r2441() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_updates_r2441() TO authenticated;

-- RPC 2: list_replies_r2441
CREATE OR REPLACE FUNCTION public.list_replies_r2441()
RETURNS TABLE (
  id uuid,
  month_label text,
  investor_name text,
  replied_at timestamptz,
  reply_kind text,
  reply_summary text,
  follow_up_required boolean,
  follow_up_at timestamptz,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, u.month_label, r.investor_name, r.replied_at, r.reply_kind, r.reply_summary,
         r.follow_up_required, r.follow_up_at, r.owner_email, r.status, r.notes
  FROM public.update_recipient_replies_r2441 r
  JOIN public.investor_monthly_updates_r2441 u ON u.id = r.update_id
  ORDER BY r.replied_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_replies_r2441() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_replies_r2441() TO authenticated;

-- RPC 3: status_funnel_r2441
CREATE OR REPLACE FUNCTION public.status_funnel_r2441()
RETURNS TABLE (
  stage text,
  update_count int,
  total_recipients int,
  total_opens int,
  total_replies int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.status,
         count(*)::int,
         coalesce(sum(u.recipient_count),0)::int,
         coalesce(sum(u.opened_count),0)::int,
         coalesce(sum(u.replied_count),0)::int
  FROM public.investor_monthly_updates_r2441 u
  GROUP BY u.status
  ORDER BY CASE u.status
    WHEN 'draft' THEN 1
    WHEN 'sent' THEN 2
    WHEN 'opened' THEN 3
    WHEN 'replied' THEN 4
    WHEN 'closed' THEN 5
    ELSE 9 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2441() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2441() TO authenticated;

-- RPC 4: top_reply_investors_r2441
CREATE OR REPLACE FUNCTION public.top_reply_investors_r2441()
RETURNS TABLE (
  investor_name text,
  reply_count int,
  positive_count int,
  intro_offer_count int,
  ask_count int,
  last_replied_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.investor_name,
         count(*)::int,
         count(*) FILTER (WHERE r.reply_kind='positive')::int,
         count(*) FILTER (WHERE r.reply_kind='intro_offer')::int,
         count(*) FILTER (WHERE r.reply_kind='ask')::int,
         max(r.replied_at)
  FROM public.update_recipient_replies_r2441 r
  GROUP BY r.investor_name
  ORDER BY count(*) DESC, max(r.replied_at) DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_reply_investors_r2441() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_reply_investors_r2441() TO authenticated;

-- RPC 5: follow_up_calendar_r2441
CREATE OR REPLACE FUNCTION public.follow_up_calendar_r2441()
RETURNS TABLE (
  id uuid,
  investor_name text,
  follow_up_at timestamptz,
  reply_kind text,
  status text,
  owner_email text,
  days_out int,
  reply_summary text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.follow_up_at, r.reply_kind, r.status, r.owner_email,
         EXTRACT(DAY FROM (r.follow_up_at - now()))::int,
         r.reply_summary
  FROM public.update_recipient_replies_r2441 r
  WHERE r.follow_up_required = true
    AND r.follow_up_at IS NOT NULL
    AND r.status IN ('open','in_progress')
  ORDER BY r.follow_up_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.follow_up_calendar_r2441() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.follow_up_calendar_r2441() TO authenticated;

-- RPC 6: monthly_open_rate_trend_r2441
CREATE OR REPLACE FUNCTION public.monthly_open_rate_trend_r2441()
RETURNS TABLE (
  month_label text,
  recipient_count int,
  opened_count int,
  replied_count int,
  open_rate_pct numeric,
  reply_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.month_label, u.recipient_count, u.opened_count, u.replied_count,
         CASE WHEN u.recipient_count > 0
              THEN round(100.0 * u.opened_count / u.recipient_count, 1)
              ELSE 0 END,
         CASE WHEN u.recipient_count > 0
              THEN round(100.0 * u.replied_count / u.recipient_count, 1)
              ELSE 0 END
  FROM public.investor_monthly_updates_r2441 u
  WHERE u.status <> 'draft'
  ORDER BY u.month_label ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_open_rate_trend_r2441() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_open_rate_trend_r2441() TO authenticated;

-- RPC 7: ask_pipeline_summary_r2441
CREATE OR REPLACE FUNCTION public.ask_pipeline_summary_r2441()
RETURNS TABLE (
  reply_kind text,
  total int,
  open_count int,
  in_progress_count int,
  done_count int,
  dropped_count int,
  follow_up_required_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.reply_kind,
         count(*)::int,
         count(*) FILTER (WHERE r.status='open')::int,
         count(*) FILTER (WHERE r.status='in_progress')::int,
         count(*) FILTER (WHERE r.status='done')::int,
         count(*) FILTER (WHERE r.status='dropped')::int,
         count(*) FILTER (WHERE r.follow_up_required=true)::int
  FROM public.update_recipient_replies_r2441 r
  GROUP BY r.reply_kind
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.ask_pipeline_summary_r2441() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ask_pipeline_summary_r2441() TO authenticated;
