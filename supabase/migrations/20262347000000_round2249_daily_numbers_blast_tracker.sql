BEGIN;

CREATE TABLE IF NOT EXISTS public.daily_numbers_blasts_r2249 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blast_date date NOT NULL,
  subject text NOT NULL,
  revenue_rupees bigint NOT NULL DEFAULT 0,
  jobs_completed int NOT NULL DEFAULT 0,
  jobs_open int NOT NULL DEFAULT 0,
  nps_score numeric(4,1),
  founder_commentary text,
  channel text NOT NULL DEFAULT 'email' CHECK (channel IN ('email','slack','whatsapp','sms')),
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('queued','sent','failed','skipped')),
  recipient_count int NOT NULL DEFAULT 0,
  opened_count int NOT NULL DEFAULT 0,
  sent_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.daily_numbers_blast_opens_r2249 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blast_id uuid NOT NULL REFERENCES public.daily_numbers_blasts_r2249(id) ON DELETE CASCADE,
  recipient_email text NOT NULL,
  recipient_role text NOT NULL CHECK (recipient_role IN ('founder','exec','engineer','ops','investor','advisor')),
  opened_at timestamptz,
  click_count int NOT NULL DEFAULT 0,
  reply_text text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.daily_numbers_blasts_r2249 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_numbers_blast_opens_r2249 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.daily_numbers_blasts_r2249;
CREATE POLICY founder_all ON public.daily_numbers_blasts_r2249
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.daily_numbers_blast_opens_r2249;
CREATE POLICY founder_all ON public.daily_numbers_blast_opens_r2249
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

INSERT INTO public.daily_numbers_blasts_r2249 (blast_date, subject, revenue_rupees, jobs_completed, jobs_open, nps_score, founder_commentary, channel, status, recipient_count, opened_count, sent_at) VALUES
  (current_date - 0, 'Daily Numbers — Jun 22', 184500, 23, 41, 58.2, 'Strong day. Hospital chain pipeline up. Watch dispute backlog.', 'email', 'sent', 18, 14, now() - interval '4 hours'),
  (current_date - 1, 'Daily Numbers — Jun 21', 142300, 19, 37, 54.8, 'AMC renewals soft. Push engineer rotation Monday.', 'email', 'sent', 18, 15, now() - interval '28 hours'),
  (current_date - 2, 'Daily Numbers — Jun 20', 0, 0, 0, NULL, 'Weekend skip.', 'email', 'skipped', 18, 0, now() - interval '52 hours'),
  (current_date - 3, 'Daily Numbers — Jun 19', 211800, 27, 35, 61.0, 'New record on Tier-1 city completions.', 'email', 'sent', 18, 17, now() - interval '76 hours'),
  (current_date - 4, 'Daily Numbers — Jun 18', 168900, 22, 39, 56.4, NULL, 'slack', 'sent', 22, 12, now() - interval '100 hours'),
  (current_date - 5, 'Daily Numbers — Jun 17', 0, 0, 0, NULL, 'Edge function timeout — manual resend tomorrow.', 'email', 'failed', 18, 0, now() - interval '124 hours');

WITH b AS (SELECT id, blast_date FROM public.daily_numbers_blasts_r2249)
INSERT INTO public.daily_numbers_blast_opens_r2249 (blast_id, recipient_email, recipient_role, opened_at, click_count)
SELECT b.id, e.email, e.role,
  CASE WHEN random() < 0.75 THEN b.blast_date + interval '8 hours' ELSE NULL END,
  CASE WHEN random() < 0.4 THEN (random()*3)::int ELSE 0 END
FROM b
CROSS JOIN (VALUES
  ('ganesh@equipseva.in','founder'),
  ('cto@equipseva.in','exec'),
  ('ops@equipseva.in','ops'),
  ('lead.eng@equipseva.in','engineer'),
  ('investor1@vc.in','investor'),
  ('advisor@board.in','advisor')
) AS e(email, role);

CREATE OR REPLACE FUNCTION public.r2249_blast_summary()
RETURNS TABLE(total_blasts int, sent_blasts int, failed_blasts int, skipped_blasts int, total_revenue_rupees bigint, avg_nps numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE status = 'sent'))::int,
    (COUNT(*) FILTER (WHERE status = 'failed'))::int,
    (COUNT(*) FILTER (WHERE status = 'skipped'))::int,
    COALESCE(SUM(revenue_rupees) FILTER (WHERE status = 'sent'), 0)::bigint,
    ROUND(AVG(nps_score) FILTER (WHERE nps_score IS NOT NULL), 1)
  FROM public.daily_numbers_blasts_r2249
  WHERE blast_date >= current_date - 30;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2249_recent_blasts()
RETURNS TABLE(blast_date date, subject text, revenue_rupees bigint, jobs_completed int, jobs_open int, nps_score numeric, channel text, status text, recipient_count int, opened_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.blast_date, b.subject, b.revenue_rupees, b.jobs_completed, b.jobs_open, b.nps_score, b.channel, b.status, b.recipient_count, b.opened_count
  FROM public.daily_numbers_blasts_r2249 b
  ORDER BY b.blast_date DESC
  LIMIT 30;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2249_open_rate_by_role()
RETURNS TABLE(recipient_role text, total int, opened int, open_rate_pct numeric, avg_clicks numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.recipient_role,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE o.opened_at IS NOT NULL))::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.opened_at IS NOT NULL) / NULLIF(COUNT(*), 0), 1),
    ROUND(AVG(o.click_count), 2)
  FROM public.daily_numbers_blast_opens_r2249 o
  GROUP BY o.recipient_role
  ORDER BY o.recipient_role;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2249_low_engagement_recipients()
RETURNS TABLE(recipient_email text, recipient_role text, total_blasts int, opened_blasts int, open_rate_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.recipient_email,
    o.recipient_role,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE o.opened_at IS NOT NULL))::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.opened_at IS NOT NULL) / NULLIF(COUNT(*), 0), 1)
  FROM public.daily_numbers_blast_opens_r2249 o
  GROUP BY o.recipient_email, o.recipient_role
  HAVING ROUND(100.0 * COUNT(*) FILTER (WHERE o.opened_at IS NOT NULL) / NULLIF(COUNT(*), 0), 1) < 50
  ORDER BY open_rate_pct ASC NULLS FIRST
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2249_commentary_log()
RETURNS TABLE(blast_date date, subject text, founder_commentary text, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.blast_date, b.subject, b.founder_commentary, b.status
  FROM public.daily_numbers_blasts_r2249 b
  WHERE b.founder_commentary IS NOT NULL AND length(b.founder_commentary) > 0
  ORDER BY b.blast_date DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2249_channel_mix()
RETURNS TABLE(channel text, blast_count int, avg_open_rate_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.channel,
    (COUNT(*))::int,
    ROUND(AVG(100.0 * b.opened_count / NULLIF(b.recipient_count, 0)), 1)
  FROM public.daily_numbers_blasts_r2249 b
  WHERE b.status = 'sent'
  GROUP BY b.channel
  ORDER BY blast_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2249_failed_blast_alerts()
RETURNS TABLE(blast_date date, subject text, channel text, status text, sent_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.blast_date, b.subject, b.channel, b.status, b.sent_at
  FROM public.daily_numbers_blasts_r2249 b
  WHERE b.status IN ('failed','skipped')
  ORDER BY b.blast_date DESC
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.r2249_blast_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2249_recent_blasts() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2249_open_rate_by_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2249_low_engagement_recipients() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2249_commentary_log() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2249_channel_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2249_failed_blast_alerts() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2249_blast_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2249_recent_blasts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2249_open_rate_by_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2249_low_engagement_recipients() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2249_commentary_log() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2249_channel_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2249_failed_blast_alerts() TO authenticated;

COMMIT;
