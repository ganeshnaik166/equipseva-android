BEGIN;

-- ============================================================================
-- r2256: Customer Service Deflection-via-Self-Help Tracker
-- Track chatbot/KB resolved tickets vs human-handled, cost saved, CSAT parity
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.deflection_tickets_r2256 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_ref text NOT NULL,
  customer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  channel text NOT NULL CHECK (channel IN ('chatbot','kb_search','help_center','whatsapp_bot','ivr_self_serve','human_agent','email_human','phone_human')),
  resolution_path text NOT NULL CHECK (resolution_path IN ('self_help_resolved','bot_resolved','escalated_to_human','human_only','abandoned')),
  intent_category text NOT NULL CHECK (intent_category IN ('amc_status','invoice_request','job_status','spare_part_query','complaint','refund_query','engineer_eta','warranty_check','general_info','technical_issue')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolution_minutes int,
  agent_minutes_saved numeric(8,2) NOT NULL DEFAULT 0,
  cost_saved_rupees numeric(10,2) NOT NULL DEFAULT 0,
  csat_score int CHECK (csat_score BETWEEN 1 AND 5),
  was_deflected boolean NOT NULL DEFAULT false,
  bot_confidence_score numeric(4,3) CHECK (bot_confidence_score BETWEEN 0 AND 1),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deflection_tickets_r2256_opened ON public.deflection_tickets_r2256(opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_deflection_tickets_r2256_channel ON public.deflection_tickets_r2256(channel);
CREATE INDEX IF NOT EXISTS idx_deflection_tickets_r2256_path ON public.deflection_tickets_r2256(resolution_path);

ALTER TABLE public.deflection_tickets_r2256 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS deflection_tickets_r2256_founder_all ON public.deflection_tickets_r2256;
CREATE POLICY deflection_tickets_r2256_founder_all ON public.deflection_tickets_r2256
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
CREATE TABLE IF NOT EXISTS public.deflection_kb_articles_r2256 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_slug text NOT NULL UNIQUE,
  article_title text NOT NULL,
  intent_category text NOT NULL CHECK (intent_category IN ('amc_status','invoice_request','job_status','spare_part_query','complaint','refund_query','engineer_eta','warranty_check','general_info','technical_issue')),
  views_count int NOT NULL DEFAULT 0,
  helpful_votes int NOT NULL DEFAULT 0,
  unhelpful_votes int NOT NULL DEFAULT 0,
  deflections_attributed int NOT NULL DEFAULT 0,
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('draft','published','archived','needs_update')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deflection_kb_r2256_intent ON public.deflection_kb_articles_r2256(intent_category);
CREATE INDEX IF NOT EXISTS idx_deflection_kb_r2256_views ON public.deflection_kb_articles_r2256(views_count DESC);

ALTER TABLE public.deflection_kb_articles_r2256 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS deflection_kb_articles_r2256_founder_all ON public.deflection_kb_articles_r2256;
CREATE POLICY deflection_kb_articles_r2256_founder_all ON public.deflection_kb_articles_r2256
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: KPI summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_deflection_kpis_r2256()
RETURNS TABLE (
  total_tickets int,
  deflected_tickets int,
  deflection_rate_pct numeric,
  total_cost_saved_rupees numeric,
  avg_csat_self_help numeric,
  avg_csat_human numeric,
  csat_parity_gap numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_tickets,
    (COUNT(*) FILTER (WHERE was_deflected = true))::int AS deflected_tickets,
    ROUND(
      (COUNT(*) FILTER (WHERE was_deflected = true))::numeric
      / NULLIF(COUNT(*),0)::numeric * 100, 2
    ) AS deflection_rate_pct,
    COALESCE(SUM(cost_saved_rupees), 0)::numeric AS total_cost_saved_rupees,
    ROUND(AVG(csat_score) FILTER (WHERE resolution_path IN ('self_help_resolved','bot_resolved'))::numeric, 2) AS avg_csat_self_help,
    ROUND(AVG(csat_score) FILTER (WHERE resolution_path IN ('human_only','escalated_to_human'))::numeric, 2) AS avg_csat_human,
    ROUND(
      (AVG(csat_score) FILTER (WHERE resolution_path IN ('human_only','escalated_to_human')))::numeric
      - (AVG(csat_score) FILTER (WHERE resolution_path IN ('self_help_resolved','bot_resolved')))::numeric, 2
    ) AS csat_parity_gap
  FROM public.deflection_tickets_r2256
  WHERE opened_at >= now() - interval '30 days';
END;
$$;

REVOKE ALL ON FUNCTION public.founder_deflection_kpis_r2256() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_deflection_kpis_r2256() TO authenticated;

-- ============================================================================
-- RPC 2: Channel breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_deflection_by_channel_r2256()
RETURNS TABLE (
  channel text,
  ticket_count int,
  resolved_count int,
  avg_resolution_minutes numeric,
  total_cost_saved numeric,
  avg_csat numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.channel,
    (COUNT(*))::int AS ticket_count,
    (COUNT(*) FILTER (WHERE t.resolved_at IS NOT NULL))::int AS resolved_count,
    ROUND(AVG(t.resolution_minutes)::numeric, 1) AS avg_resolution_minutes,
    COALESCE(SUM(t.cost_saved_rupees), 0)::numeric AS total_cost_saved,
    ROUND(AVG(t.csat_score)::numeric, 2) AS avg_csat
  FROM public.deflection_tickets_r2256 t
  WHERE t.opened_at >= now() - interval '30 days'
  GROUP BY t.channel
  ORDER BY ticket_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_deflection_by_channel_r2256() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_deflection_by_channel_r2256() TO authenticated;

-- ============================================================================
-- RPC 3: Intent breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_deflection_by_intent_r2256()
RETURNS TABLE (
  intent_category text,
  total_tickets int,
  deflected_count int,
  deflection_rate_pct numeric,
  escalation_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.intent_category,
    (COUNT(*))::int AS total_tickets,
    (COUNT(*) FILTER (WHERE t.was_deflected = true))::int AS deflected_count,
    ROUND(
      (COUNT(*) FILTER (WHERE t.was_deflected = true))::numeric
      / NULLIF(COUNT(*), 0)::numeric * 100, 2
    ) AS deflection_rate_pct,
    ROUND(
      (COUNT(*) FILTER (WHERE t.resolution_path = 'escalated_to_human'))::numeric
      / NULLIF(COUNT(*), 0)::numeric * 100, 2
    ) AS escalation_rate_pct
  FROM public.deflection_tickets_r2256 t
  WHERE t.opened_at >= now() - interval '30 days'
  GROUP BY t.intent_category
  ORDER BY total_tickets DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_deflection_by_intent_r2256() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_deflection_by_intent_r2256() TO authenticated;

-- ============================================================================
-- RPC 4: Top KB articles
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_deflection_top_kb_r2256()
RETURNS TABLE (
  article_title text,
  intent_category text,
  views_count int,
  helpful_pct numeric,
  deflections_attributed int,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    k.article_title,
    k.intent_category,
    k.views_count,
    ROUND(
      k.helpful_votes::numeric
      / NULLIF(k.helpful_votes + k.unhelpful_votes, 0)::numeric * 100, 1
    ) AS helpful_pct,
    k.deflections_attributed,
    k.status
  FROM public.deflection_kb_articles_r2256 k
  ORDER BY k.deflections_attributed DESC, k.views_count DESC
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_deflection_top_kb_r2256() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_deflection_top_kb_r2256() TO authenticated;

-- ============================================================================
-- RPC 5: Articles needing update (low helpful pct or stale)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_deflection_kb_needs_update_r2256()
RETURNS TABLE (
  article_title text,
  intent_category text,
  helpful_pct numeric,
  unhelpful_votes int,
  days_since_update int,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    k.article_title,
    k.intent_category,
    ROUND(
      k.helpful_votes::numeric
      / NULLIF(k.helpful_votes + k.unhelpful_votes, 0)::numeric * 100, 1
    ) AS helpful_pct,
    k.unhelpful_votes,
    EXTRACT(DAY FROM now() - k.last_updated_at)::int AS days_since_update,
    k.status
  FROM public.deflection_kb_articles_r2256 k
  WHERE
    k.status = 'needs_update'
    OR (k.helpful_votes + k.unhelpful_votes >= 10
        AND (k.helpful_votes::numeric / NULLIF(k.helpful_votes + k.unhelpful_votes, 0)::numeric) < 0.5)
    OR k.last_updated_at < now() - interval '90 days'
  ORDER BY k.unhelpful_votes DESC, days_since_update DESC
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_deflection_kb_needs_update_r2256() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_deflection_kb_needs_update_r2256() TO authenticated;

-- ============================================================================
-- RPC 6: Daily trend (last 14 days)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_deflection_daily_trend_r2256()
RETURNS TABLE (
  day_date date,
  total_tickets int,
  deflected_count int,
  cost_saved numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (t.opened_at AT TIME ZONE 'Asia/Kolkata')::date AS day_date,
    (COUNT(*))::int AS total_tickets,
    (COUNT(*) FILTER (WHERE t.was_deflected = true))::int AS deflected_count,
    COALESCE(SUM(t.cost_saved_rupees), 0)::numeric AS cost_saved
  FROM public.deflection_tickets_r2256 t
  WHERE t.opened_at >= now() - interval '14 days'
  GROUP BY day_date
  ORDER BY day_date DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_deflection_daily_trend_r2256() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_deflection_daily_trend_r2256() TO authenticated;

-- ============================================================================
-- RPC 7: Recent escalations (deflection failures)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_deflection_recent_escalations_r2256()
RETURNS TABLE (
  ticket_ref text,
  channel text,
  intent_category text,
  bot_confidence_score numeric,
  opened_at timestamptz,
  resolution_minutes int,
  csat_score int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.ticket_ref,
    t.channel,
    t.intent_category,
    t.bot_confidence_score,
    t.opened_at,
    t.resolution_minutes,
    t.csat_score
  FROM public.deflection_tickets_r2256 t
  WHERE t.resolution_path = 'escalated_to_human'
    AND t.opened_at >= now() - interval '7 days'
  ORDER BY t.opened_at DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_deflection_recent_escalations_r2256() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_deflection_recent_escalations_r2256() TO authenticated;

-- ============================================================================
-- Seed sample data
-- ============================================================================
INSERT INTO public.deflection_kb_articles_r2256
  (article_slug, article_title, intent_category, views_count, helpful_votes, unhelpful_votes, deflections_attributed, last_updated_at, status)
VALUES
  ('how-to-check-amc-status', 'How to check your AMC contract status', 'amc_status', 1240, 980, 45, 612, now() - interval '12 days', 'published'),
  ('download-gst-invoice', 'Download your GST invoice from app', 'invoice_request', 890, 720, 38, 445, now() - interval '8 days', 'published'),
  ('track-repair-job', 'Track your repair job in real time', 'job_status', 1560, 1320, 62, 780, now() - interval '5 days', 'published'),
  ('engineer-eta-info', 'Understanding your engineer ETA', 'engineer_eta', 670, 410, 180, 245, now() - interval '95 days', 'needs_update'),
  ('warranty-claim-guide', 'How to file a warranty claim', 'warranty_check', 520, 390, 25, 290, now() - interval '20 days', 'published'),
  ('refund-process-overview', 'Refund process and timelines', 'refund_query', 430, 180, 210, 95, now() - interval '110 days', 'needs_update'),
  ('order-spare-parts', 'Ordering OEM spare parts', 'spare_part_query', 380, 305, 22, 198, now() - interval '15 days', 'published'),
  ('lodge-complaint', 'How to lodge a complaint', 'complaint', 240, 140, 70, 78, now() - interval '45 days', 'published')
ON CONFLICT (article_slug) DO NOTHING;

INSERT INTO public.deflection_tickets_r2256
  (ticket_ref, channel, resolution_path, intent_category, opened_at, resolved_at, resolution_minutes, agent_minutes_saved, cost_saved_rupees, csat_score, was_deflected, bot_confidence_score, notes)
VALUES
  ('TKT-9001', 'chatbot', 'bot_resolved', 'amc_status', now() - interval '2 days', now() - interval '2 days' + interval '3 minutes', 3, 12.0, 60.00, 5, true, 0.940, 'Bot answered AMC renewal date'),
  ('TKT-9002', 'kb_search', 'self_help_resolved', 'invoice_request', now() - interval '1 days', now() - interval '1 days' + interval '4 minutes', 4, 10.0, 50.00, 4, true, NULL, 'Customer downloaded invoice via KB'),
  ('TKT-9003', 'whatsapp_bot', 'bot_resolved', 'job_status', now() - interval '3 hours', now() - interval '3 hours' + interval '2 minutes', 2, 8.0, 40.00, 5, true, 0.880, 'WhatsApp job tracker'),
  ('TKT-9004', 'chatbot', 'escalated_to_human', 'complaint', now() - interval '5 hours', now() - interval '5 hours' + interval '35 minutes', 35, 0.0, 0.00, 3, false, 0.430, 'Bot could not resolve complaint, escalated'),
  ('TKT-9005', 'human_agent', 'human_only', 'technical_issue', now() - interval '1 days', now() - interval '1 days' + interval '45 minutes', 45, 0.0, 0.00, 4, false, NULL, 'Complex technical issue, agent handled'),
  ('TKT-9006', 'ivr_self_serve', 'self_help_resolved', 'job_status', now() - interval '6 hours', now() - interval '6 hours' + interval '5 minutes', 5, 10.0, 50.00, 4, true, NULL, 'IVR job ETA lookup'),
  ('TKT-9007', 'kb_search', 'self_help_resolved', 'warranty_check', now() - interval '4 days', now() - interval '4 days' + interval '7 minutes', 7, 15.0, 75.00, 5, true, NULL, 'KB warranty article'),
  ('TKT-9008', 'chatbot', 'escalated_to_human', 'refund_query', now() - interval '8 hours', now() - interval '8 hours' + interval '40 minutes', 40, 0.0, 0.00, 2, false, 0.380, 'Refund disputed, escalated'),
  ('TKT-9009', 'help_center', 'self_help_resolved', 'spare_part_query', now() - interval '2 days', now() - interval '2 days' + interval '6 minutes', 6, 12.0, 60.00, 4, true, NULL, 'Spare part lookup via help center'),
  ('TKT-9010', 'chatbot', 'bot_resolved', 'general_info', now() - interval '12 hours', now() - interval '12 hours' + interval '1 minutes', 1, 5.0, 25.00, 5, true, 0.970, 'FAQ resolved instantly');

COMMIT;
