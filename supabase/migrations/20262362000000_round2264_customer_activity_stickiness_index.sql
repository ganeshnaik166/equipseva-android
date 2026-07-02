BEGIN;

-- ============================================================================
-- Round 2264: Customer Activity Stickiness Index
-- Tracks weekly customer logins/usage events, flags declining usage,
-- and logs re-engagement campaigns.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.customer_weekly_activity_r2264 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_start date NOT NULL,
  login_count int NOT NULL DEFAULT 0 CHECK (login_count >= 0),
  job_create_count int NOT NULL DEFAULT 0 CHECK (job_create_count >= 0),
  amc_view_count int NOT NULL DEFAULT 0 CHECK (amc_view_count >= 0),
  invoice_view_count int NOT NULL DEFAULT 0 CHECK (invoice_view_count >= 0),
  total_events int NOT NULL DEFAULT 0 CHECK (total_events >= 0),
  stickiness_score numeric(5,2) NOT NULL DEFAULT 0 CHECK (stickiness_score >= 0 AND stickiness_score <= 100),
  trend text NOT NULL DEFAULT 'stable' CHECK (trend IN ('rising','stable','declining','dormant')),
  declining_flag boolean NOT NULL DEFAULT false,
  computed_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  UNIQUE (customer_user_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_cwa_r2264_customer ON public.customer_weekly_activity_r2264 (customer_user_id);
CREATE INDEX IF NOT EXISTS idx_cwa_r2264_week ON public.customer_weekly_activity_r2264 (week_start DESC);
CREATE INDEX IF NOT EXISTS idx_cwa_r2264_trend ON public.customer_weekly_activity_r2264 (trend);
CREATE INDEX IF NOT EXISTS idx_cwa_r2264_decline ON public.customer_weekly_activity_r2264 (declining_flag) WHERE declining_flag = true;

ALTER TABLE public.customer_weekly_activity_r2264 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cwa_r2264_founder_all ON public.customer_weekly_activity_r2264;
CREATE POLICY cwa_r2264_founder_all ON public.customer_weekly_activity_r2264
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_reengagement_campaigns_r2264 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  campaign_type text NOT NULL CHECK (campaign_type IN ('email','sms','whatsapp','call','in_app','discount_offer')),
  campaign_name text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  sent_by uuid REFERENCES public.profiles(id),
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','delivered','opened','clicked','responded','no_response','failed')),
  offer_details text,
  outcome text CHECK (outcome IN ('reactivated','partial','no_change','churned','pending')),
  outcome_recorded_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crc_r2264_customer ON public.customer_reengagement_campaigns_r2264 (customer_user_id);
CREATE INDEX IF NOT EXISTS idx_crc_r2264_sent ON public.customer_reengagement_campaigns_r2264 (sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_crc_r2264_outcome ON public.customer_reengagement_campaigns_r2264 (outcome);

ALTER TABLE public.customer_reengagement_campaigns_r2264 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crc_r2264_founder_all ON public.customer_reengagement_campaigns_r2264;
CREATE POLICY crc_r2264_founder_all ON public.customer_reengagement_campaigns_r2264
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs (7 founder-gated)
-- ============================================================================

DROP FUNCTION IF EXISTS public.r2264_stickiness_overview();
CREATE FUNCTION public.r2264_stickiness_overview()
RETURNS TABLE (
  total_customers_tracked int,
  rising_count int,
  stable_count int,
  declining_count int,
  dormant_count int,
  avg_stickiness_score numeric,
  flagged_for_outreach int,
  campaigns_last_30d int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (customer_user_id)
      customer_user_id, trend, stickiness_score, declining_flag
    FROM public.customer_weekly_activity_r2264
    ORDER BY customer_user_id, week_start DESC
  )
  SELECT
    (SELECT COUNT(DISTINCT customer_user_id) FROM latest)::int,
    (COUNT(*) FILTER (WHERE trend = 'rising'))::int,
    (COUNT(*) FILTER (WHERE trend = 'stable'))::int,
    (COUNT(*) FILTER (WHERE trend = 'declining'))::int,
    (COUNT(*) FILTER (WHERE trend = 'dormant'))::int,
    COALESCE(ROUND(AVG(stickiness_score)::numeric, 2), 0),
    (COUNT(*) FILTER (WHERE declining_flag = true))::int,
    (SELECT COUNT(*) FROM public.customer_reengagement_campaigns_r2264 WHERE sent_at >= now() - interval '30 days')::int
  FROM latest;
END;
$$;

REVOKE ALL ON FUNCTION public.r2264_stickiness_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2264_stickiness_overview() TO authenticated;

-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2264_top_declining_customers(int);
CREATE FUNCTION public.r2264_top_declining_customers(p_limit int DEFAULT 25)
RETURNS TABLE (
  customer_user_id uuid,
  customer_email text,
  latest_week date,
  latest_score numeric,
  trend text,
  total_events int,
  weeks_declining int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (a.customer_user_id)
      a.customer_user_id, a.week_start, a.stickiness_score, a.trend, a.total_events
    FROM public.customer_weekly_activity_r2264 a
    WHERE a.declining_flag = true OR a.trend IN ('declining','dormant')
    ORDER BY a.customer_user_id, a.week_start DESC
  ),
  decl_count AS (
    SELECT a.customer_user_id, COUNT(*)::int AS weeks_decl
    FROM public.customer_weekly_activity_r2264 a
    WHERE a.trend = 'declining'
    GROUP BY a.customer_user_id
  )
  SELECT
    l.customer_user_id,
    p.email,
    l.week_start,
    l.stickiness_score,
    l.trend,
    l.total_events,
    COALESCE(d.weeks_decl, 0)
  FROM latest l
  JOIN public.profiles p ON p.id = l.customer_user_id
  LEFT JOIN decl_count d ON d.customer_user_id = l.customer_user_id
  ORDER BY l.stickiness_score ASC, l.week_start DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.r2264_top_declining_customers(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2264_top_declining_customers(int) TO authenticated;

-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2264_weekly_aggregate(int);
CREATE FUNCTION public.r2264_weekly_aggregate(p_weeks int DEFAULT 12)
RETURNS TABLE (
  week_start date,
  customers_active int,
  total_events bigint,
  avg_score numeric,
  declining_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.week_start,
    COUNT(DISTINCT a.customer_user_id)::int,
    SUM(a.total_events)::bigint,
    ROUND(AVG(a.stickiness_score)::numeric, 2),
    ROUND((100.0 * COUNT(*) FILTER (WHERE a.trend = 'declining') / NULLIF(COUNT(*),0))::numeric, 2)
  FROM public.customer_weekly_activity_r2264 a
  WHERE a.week_start >= (CURRENT_DATE - (p_weeks * 7))
  GROUP BY a.week_start
  ORDER BY a.week_start DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2264_weekly_aggregate(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2264_weekly_aggregate(int) TO authenticated;

-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2264_recent_campaigns(int);
CREATE FUNCTION public.r2264_recent_campaigns(p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  customer_email text,
  campaign_type text,
  campaign_name text,
  sent_at timestamptz,
  status text,
  outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id, p.email, c.campaign_type, c.campaign_name, c.sent_at, c.status, c.outcome
  FROM public.customer_reengagement_campaigns_r2264 c
  JOIN public.profiles p ON p.id = c.customer_user_id
  ORDER BY c.sent_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.r2264_recent_campaigns(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2264_recent_campaigns(int) TO authenticated;

-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2264_campaign_effectiveness();
CREATE FUNCTION public.r2264_campaign_effectiveness()
RETURNS TABLE (
  campaign_type text,
  sent_count int,
  reactivated_count int,
  no_change_count int,
  churned_count int,
  reactivation_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.campaign_type,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE c.outcome = 'reactivated'))::int,
    (COUNT(*) FILTER (WHERE c.outcome = 'no_change'))::int,
    (COUNT(*) FILTER (WHERE c.outcome = 'churned'))::int,
    ROUND((100.0 * COUNT(*) FILTER (WHERE c.outcome = 'reactivated') / NULLIF(COUNT(*),0))::numeric, 2)
  FROM public.customer_reengagement_campaigns_r2264 c
  GROUP BY c.campaign_type
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2264_campaign_effectiveness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2264_campaign_effectiveness() TO authenticated;

-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2264_customer_history(uuid, int);
CREATE FUNCTION public.r2264_customer_history(p_customer uuid, p_weeks int DEFAULT 12)
RETURNS TABLE (
  week_start date,
  login_count int,
  job_create_count int,
  total_events int,
  stickiness_score numeric,
  trend text,
  declining_flag boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.week_start, a.login_count, a.job_create_count, a.total_events,
         a.stickiness_score, a.trend, a.declining_flag
  FROM public.customer_weekly_activity_r2264 a
  WHERE a.customer_user_id = p_customer
    AND a.week_start >= (CURRENT_DATE - (p_weeks * 7))
  ORDER BY a.week_start DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2264_customer_history(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2264_customer_history(uuid, int) TO authenticated;

-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2264_log_campaign(uuid, text, text, text, text);
CREATE FUNCTION public.r2264_log_campaign(
  p_customer uuid,
  p_type text,
  p_name text,
  p_offer text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_user uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_user FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.customer_reengagement_campaigns_r2264
    (customer_user_id, campaign_type, campaign_name, sent_by, offer_details, notes, outcome)
  VALUES (p_customer, p_type, p_name, v_user, p_offer, p_notes, 'pending')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.r2264_log_campaign(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2264_log_campaign(uuid, text, text, text, text) TO authenticated;

-- ============================================================================
-- Seed sample data
-- ============================================================================
DO $$
DECLARE
  v_cust uuid;
  v_week date;
  v_i int;
BEGIN
  FOR v_cust IN
    SELECT id FROM public.profiles
    WHERE role = 'hospital_admin'
    ORDER BY created_at DESC
    LIMIT 8
  LOOP
    FOR v_i IN 0..7 LOOP
      v_week := date_trunc('week', CURRENT_DATE)::date - (v_i * 7);
      INSERT INTO public.customer_weekly_activity_r2264
        (customer_user_id, week_start, login_count, job_create_count, amc_view_count,
         invoice_view_count, total_events, stickiness_score, trend, declining_flag)
      VALUES (
        v_cust,
        v_week,
        GREATEST(0, 12 - v_i + (random()*4)::int),
        GREATEST(0, 4 - v_i + (random()*3)::int),
        GREATEST(0, 6 - v_i + (random()*3)::int),
        GREATEST(0, 3 - v_i + (random()*2)::int),
        GREATEST(0, 25 - (v_i*3) + (random()*8)::int),
        GREATEST(5, LEAST(99, 85 - (v_i*7) + (random()*10)::int))::numeric(5,2),
        CASE
          WHEN v_i = 0 THEN 'declining'
          WHEN v_i <= 2 THEN 'stable'
          WHEN v_i <= 5 THEN 'rising'
          ELSE 'stable'
        END,
        v_i = 0
      )
      ON CONFLICT (customer_user_id, week_start) DO NOTHING;
    END LOOP;

    INSERT INTO public.customer_reengagement_campaigns_r2264
      (customer_user_id, campaign_type, campaign_name, sent_at, status, offer_details, outcome, outcome_recorded_at)
    VALUES
      (v_cust, 'email', 'We miss you - Q3 reactivation', now() - interval '21 days',
       'opened', '10% off next AMC renewal', 'reactivated', now() - interval '14 days'),
      (v_cust, 'whatsapp', 'Free service check-up offer', now() - interval '7 days',
       'delivered', 'Free diagnostic visit', 'pending', NULL)
    ON CONFLICT DO NOTHING;
  END LOOP;
END $$;

COMMIT;