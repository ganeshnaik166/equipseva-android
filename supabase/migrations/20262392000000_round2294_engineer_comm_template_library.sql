BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_comm_templates_r2294 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  template_code text NOT NULL,
  template_title text NOT NULL,
  category text NOT NULL CHECK (category IN ('arrival_eta','quote_followup','part_delay','job_complete','amc_renewal','escalation','reschedule','custom')),
  channel text NOT NULL CHECK (channel IN ('whatsapp','sms','email','in_app')),
  body_text text NOT NULL,
  language text NOT NULL DEFAULT 'en' CHECK (language IN ('en','hi','te','ta','kn','bn','mr')),
  current_version int NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, template_code)
);

CREATE INDEX IF NOT EXISTS idx_ect_r2294_engineer ON public.engineer_comm_templates_r2294(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ect_r2294_category ON public.engineer_comm_templates_r2294(category);
CREATE INDEX IF NOT EXISTS idx_ect_r2294_active ON public.engineer_comm_templates_r2294(is_active) WHERE is_active = true;

ALTER TABLE public.engineer_comm_templates_r2294 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ect_r2294 ON public.engineer_comm_templates_r2294;
CREATE POLICY founder_all_ect_r2294 ON public.engineer_comm_templates_r2294
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_comm_template_usage_r2294 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid NOT NULL REFERENCES public.engineer_comm_templates_r2294(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_org_id uuid,
  version_used int NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  was_responded boolean NOT NULL DEFAULT false,
  response_at timestamptz,
  response_minutes int,
  edited_before_send boolean NOT NULL DEFAULT false,
  outcome text CHECK (outcome IN ('responded','no_response','bounced','opted_out'))
);

CREATE INDEX IF NOT EXISTS idx_ectu_r2294_template ON public.engineer_comm_template_usage_r2294(template_id);
CREATE INDEX IF NOT EXISTS idx_ectu_r2294_engineer ON public.engineer_comm_template_usage_r2294(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ectu_r2294_sent ON public.engineer_comm_template_usage_r2294(sent_at DESC);

ALTER TABLE public.engineer_comm_template_usage_r2294 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ectu_r2294 ON public.engineer_comm_template_usage_r2294;
CREATE POLICY founder_all_ectu_r2294 ON public.engineer_comm_template_usage_r2294
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: Overview KPIs
CREATE OR REPLACE FUNCTION public.r2294_template_overview()
RETURNS TABLE (
  total_templates int,
  active_templates int,
  total_sends_30d int,
  response_rate_pct numeric,
  avg_response_minutes numeric,
  edited_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.engineer_comm_templates_r2294),
    (SELECT (COUNT(*) FILTER (WHERE is_active))::int FROM public.engineer_comm_templates_r2294),
    (SELECT (COUNT(*) FILTER (WHERE sent_at >= now() - interval '30 days'))::int FROM public.engineer_comm_template_usage_r2294),
    (SELECT ROUND(100.0 * (COUNT(*) FILTER (WHERE was_responded))::numeric / NULLIF(COUNT(*),0), 2)
       FROM public.engineer_comm_template_usage_r2294 WHERE sent_at >= now() - interval '30 days'),
    (SELECT ROUND(AVG(response_minutes)::numeric, 1)
       FROM public.engineer_comm_template_usage_r2294 WHERE was_responded AND sent_at >= now() - interval '30 days'),
    (SELECT ROUND(100.0 * (COUNT(*) FILTER (WHERE edited_before_send))::numeric / NULLIF(COUNT(*),0), 2)
       FROM public.engineer_comm_template_usage_r2294 WHERE sent_at >= now() - interval '30 days');
END;
$$;

REVOKE ALL ON FUNCTION public.r2294_template_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2294_template_overview() TO authenticated;

-- RPC 2: Top templates by usage
CREATE OR REPLACE FUNCTION public.r2294_top_templates()
RETURNS TABLE (
  template_id uuid,
  template_title text,
  category text,
  channel text,
  language text,
  sends_30d int,
  response_rate_pct numeric,
  avg_response_minutes numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.template_title,
    t.category,
    t.channel,
    t.language,
    (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days'))::int,
    ROUND(100.0 * (COUNT(u.*) FILTER (WHERE u.was_responded AND u.sent_at >= now() - interval '30 days'))::numeric
          / NULLIF((COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')), 0), 2),
    ROUND(AVG(u.response_minutes) FILTER (WHERE u.was_responded AND u.sent_at >= now() - interval '30 days')::numeric, 1)
  FROM public.engineer_comm_templates_r2294 t
  LEFT JOIN public.engineer_comm_template_usage_r2294 u ON u.template_id = t.id
  GROUP BY t.id, t.template_title, t.category, t.channel, t.language
  ORDER BY (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')) DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.r2294_top_templates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2294_top_templates() TO authenticated;

-- RPC 3: Category breakdown
CREATE OR REPLACE FUNCTION public.r2294_category_breakdown()
RETURNS TABLE (
  category text,
  template_count int,
  sends_30d int,
  response_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.category,
    COUNT(DISTINCT t.id)::int,
    (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days'))::int,
    ROUND(100.0 * (COUNT(u.*) FILTER (WHERE u.was_responded AND u.sent_at >= now() - interval '30 days'))::numeric
          / NULLIF((COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')), 0), 2)
  FROM public.engineer_comm_templates_r2294 t
  LEFT JOIN public.engineer_comm_template_usage_r2294 u ON u.template_id = t.id
  GROUP BY t.category
  ORDER BY (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2294_category_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2294_category_breakdown() TO authenticated;

-- RPC 4: Channel breakdown
CREATE OR REPLACE FUNCTION public.r2294_channel_breakdown()
RETURNS TABLE (
  channel text,
  sends_30d int,
  response_rate_pct numeric,
  avg_response_minutes numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.channel,
    (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days'))::int,
    ROUND(100.0 * (COUNT(u.*) FILTER (WHERE u.was_responded AND u.sent_at >= now() - interval '30 days'))::numeric
          / NULLIF((COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')), 0), 2),
    ROUND(AVG(u.response_minutes) FILTER (WHERE u.was_responded AND u.sent_at >= now() - interval '30 days')::numeric, 1)
  FROM public.engineer_comm_templates_r2294 t
  LEFT JOIN public.engineer_comm_template_usage_r2294 u ON u.template_id = t.id
  GROUP BY t.channel
  ORDER BY (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2294_channel_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2294_channel_breakdown() TO authenticated;

-- RPC 5: Engineer leaderboard
CREATE OR REPLACE FUNCTION public.r2294_engineer_leaderboard()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  template_count int,
  sends_30d int,
  response_rate_pct numeric,
  edited_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.engineer_user_id,
    p.email,
    COUNT(DISTINCT t.id)::int,
    (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days'))::int,
    ROUND(100.0 * (COUNT(u.*) FILTER (WHERE u.was_responded AND u.sent_at >= now() - interval '30 days'))::numeric
          / NULLIF((COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')), 0), 2),
    ROUND(100.0 * (COUNT(u.*) FILTER (WHERE u.edited_before_send AND u.sent_at >= now() - interval '30 days'))::numeric
          / NULLIF((COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')), 0), 2)
  FROM public.engineer_comm_templates_r2294 t
  LEFT JOIN public.engineer_comm_template_usage_r2294 u ON u.template_id = t.id
  LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
  GROUP BY t.engineer_user_id, p.email
  ORDER BY (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')) DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.r2294_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2294_engineer_leaderboard() TO authenticated;

-- RPC 6: Recent version log
CREATE OR REPLACE FUNCTION public.r2294_recent_version_log()
RETURNS TABLE (
  template_id uuid,
  template_title text,
  category text,
  current_version int,
  updated_at timestamptz,
  engineer_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.template_title,
    t.category,
    t.current_version,
    t.updated_at,
    p.email
  FROM public.engineer_comm_templates_r2294 t
  LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
  ORDER BY t.updated_at DESC
  LIMIT 30;
END;
$$;

REVOKE ALL ON FUNCTION public.r2294_recent_version_log() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2294_recent_version_log() TO authenticated;

-- RPC 7: Low-response templates needing rewrite
CREATE OR REPLACE FUNCTION public.r2294_low_response_templates()
RETURNS TABLE (
  template_id uuid,
  template_title text,
  category text,
  channel text,
  sends_30d int,
  response_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.template_title,
    t.category,
    t.channel,
    (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days'))::int,
    ROUND(100.0 * (COUNT(u.*) FILTER (WHERE u.was_responded AND u.sent_at >= now() - interval '30 days'))::numeric
          / NULLIF((COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')), 0), 2)
  FROM public.engineer_comm_templates_r2294 t
  LEFT JOIN public.engineer_comm_template_usage_r2294 u ON u.template_id = t.id
  WHERE t.is_active
  GROUP BY t.id, t.template_title, t.category, t.channel
  HAVING (COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')) >= 5
  ORDER BY ROUND(100.0 * (COUNT(u.*) FILTER (WHERE u.was_responded AND u.sent_at >= now() - interval '30 days'))::numeric
                / NULLIF((COUNT(u.*) FILTER (WHERE u.sent_at >= now() - interval '30 days')), 0), 2) ASC NULLS LAST
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.r2294_low_response_templates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2294_low_response_templates() TO authenticated;

COMMIT;
