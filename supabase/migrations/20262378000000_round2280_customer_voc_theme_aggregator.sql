BEGIN;

-- =========================================================================
-- Round 2280 — Customer Voice-of-Customer (VoC) Theme Aggregator
-- Pull complaints/feedback from all sources, theme cluster, recurring alert
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.customer_voc_feedback_items_r2280 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_channel text NOT NULL CHECK (source_channel IN (
    'repair_job_rating','amc_renewal_survey','support_ticket',
    'nps_response','app_review','sales_call_note',
    'social_media_mention','engineer_field_note','hospital_admin_email'
  )),
  source_ref_id uuid,
  hospital_org_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reporter_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reporter_role text,
  raw_text text NOT NULL,
  sentiment_score numeric(4,2) CHECK (sentiment_score BETWEEN -1 AND 1),
  urgency_level text NOT NULL DEFAULT 'normal' CHECK (urgency_level IN ('low','normal','high','critical')),
  themes_assigned text[] NOT NULL DEFAULT '{}',
  product_area text CHECK (product_area IN (
    'repair_speed','engineer_quality','parts_availability','amc_value',
    'pricing','app_ux','billing','communication','warranty','other'
  )),
  is_actionable boolean NOT NULL DEFAULT false,
  triaged_at timestamptz,
  triaged_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_note text,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_voc_items_r2280_channel ON public.customer_voc_feedback_items_r2280(source_channel, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_voc_items_r2280_sentiment ON public.customer_voc_feedback_items_r2280(sentiment_score) WHERE sentiment_score IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_voc_items_r2280_themes ON public.customer_voc_feedback_items_r2280 USING gin(themes_assigned);
CREATE INDEX IF NOT EXISTS idx_voc_items_r2280_urgency ON public.customer_voc_feedback_items_r2280(urgency_level, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_voc_items_r2280_product_area ON public.customer_voc_feedback_items_r2280(product_area, captured_at DESC);

ALTER TABLE public.customer_voc_feedback_items_r2280 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_voc_feedback_items_r2280;
CREATE POLICY founder_all ON public.customer_voc_feedback_items_r2280
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_voc_theme_alerts_r2280 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  theme_label text NOT NULL,
  product_area text,
  mention_count_7d int NOT NULL DEFAULT 0,
  mention_count_30d int NOT NULL DEFAULT 0,
  baseline_avg_30d numeric(8,2) NOT NULL DEFAULT 0,
  spike_ratio numeric(6,2) NOT NULL DEFAULT 1.0,
  avg_sentiment numeric(4,2),
  alert_severity text NOT NULL DEFAULT 'watch' CHECK (alert_severity IN ('watch','warning','urgent','code_red')),
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  acknowledged_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action_owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','mitigated','closed','false_positive')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_voc_alerts_r2280_severity ON public.customer_voc_theme_alerts_r2280(alert_severity, status, last_seen_at DESC);
CREATE INDEX IF NOT EXISTS idx_voc_alerts_r2280_theme ON public.customer_voc_theme_alerts_r2280(theme_label, status);

ALTER TABLE public.customer_voc_theme_alerts_r2280 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_voc_theme_alerts_r2280;
CREATE POLICY founder_all ON public.customer_voc_theme_alerts_r2280
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================================
-- Seed data — synthetic VoC entries pulled across channels
-- =========================================================================
DO $seed$
DECLARE
  v_hospitals uuid[];
  v_engineers uuid[];
BEGIN
  SELECT array_agg(id) INTO v_hospitals FROM (
    SELECT id FROM public.profiles WHERE role = 'hospital_admin' LIMIT 6
  ) h;

  SELECT array_agg(id) INTO v_engineers FROM (
    SELECT id FROM public.profiles WHERE role = 'engineer' LIMIT 4
  ) e;

  IF v_hospitals IS NULL OR array_length(v_hospitals, 1) < 1 THEN
    RETURN;
  END IF;

  INSERT INTO public.customer_voc_feedback_items_r2280
    (source_channel, hospital_org_id, reporter_role, raw_text, sentiment_score, urgency_level, themes_assigned, product_area, is_actionable, captured_at)
  VALUES
    ('repair_job_rating', v_hospitals[1], 'hospital_admin', 'Engineer took 3 days to arrive for a CRITICAL ventilator fault. Unacceptable.', -0.85, 'critical', ARRAY['slow_response','sla_breach'], 'repair_speed', true, now() - interval '2 days'),
    ('amc_renewal_survey', v_hospitals[1], 'hospital_admin', 'AMC fee went up but service quality dropped. Considering competitor.', -0.7, 'high', ARRAY['churn_risk','price_concern'], 'amc_value', true, now() - interval '3 days'),
    ('support_ticket', v_hospitals[2], 'hospital_admin', 'Spare part backordered for 11 days. CT scanner offline costing us 4 lakh/day.', -0.95, 'critical', ARRAY['parts_shortage','revenue_impact'], 'parts_availability', true, now() - interval '1 day'),
    ('nps_response', v_hospitals[2], 'hospital_admin', 'NPS 3/10. App crashes when uploading photos.', -0.6, 'high', ARRAY['app_crash','ux_bug'], 'app_ux', true, now() - interval '5 days'),
    ('app_review', v_hospitals[3], 'hospital_admin', 'Two-star: billing showed wrong GST rate, had to escalate.', -0.5, 'normal', ARRAY['billing_error','gst_issue'], 'billing', true, now() - interval '6 days'),
    ('sales_call_note', v_hospitals[3], 'hospital_admin', 'Prospect declined: said pricing is 18% above competitor.', -0.4, 'normal', ARRAY['price_concern','competitive_loss'], 'pricing', true, now() - interval '8 days'),
    ('social_media_mention', NULL, NULL, 'Twitter: @equipseva engineer was rude on site visit. Not what I paid for.', -0.75, 'high', ARRAY['engineer_conduct','brand_damage'], 'engineer_quality', true, now() - interval '4 days'),
    ('engineer_field_note', v_hospitals[4], 'engineer', 'Hospital admin frustrated: third repeat visit for same X-ray detector issue.', -0.6, 'high', ARRAY['repeat_repair','quality_issue'], 'engineer_quality', true, now() - interval '7 days'),
    ('hospital_admin_email', v_hospitals[4], 'hospital_admin', 'Why no proactive update on scheduled maintenance? We discover delays only after the SLA breach.', -0.55, 'high', ARRAY['communication_gap','sla_breach'], 'communication', true, now() - interval '9 days'),
    ('repair_job_rating', v_hospitals[5], 'hospital_admin', 'Excellent engineer Ravi. 5 stars. Wish all visits were like this.', 0.9, 'low', ARRAY['positive_engineer','retention_signal'], 'engineer_quality', false, now() - interval '10 days'),
    ('amc_renewal_survey', v_hospitals[5], 'hospital_admin', 'AMC value good but want SLA tier upgrade option.', 0.3, 'low', ARRAY['upsell_signal','tier_request'], 'amc_value', true, now() - interval '11 days'),
    ('support_ticket', v_hospitals[6], 'hospital_admin', 'Parts back-order delay again — this is the 4th time in 60 days for ECG cables.', -0.8, 'critical', ARRAY['parts_shortage','repeat_complaint'], 'parts_availability', true, now() - interval '12 days'),
    ('nps_response', v_hospitals[6], 'hospital_admin', 'App photo upload still broken on Android 14.', -0.65, 'high', ARRAY['app_crash','ux_bug','platform_specific'], 'app_ux', true, now() - interval '13 days'),
    ('app_review', v_hospitals[1], 'hospital_admin', 'GST invoice download button missing on iPad.', -0.4, 'normal', ARRAY['ux_bug','tablet_issue'], 'app_ux', true, now() - interval '14 days'),
    ('engineer_field_note', v_hospitals[2], 'engineer', 'Customer asked why warranty claim took 9 days. I had no answer.', -0.5, 'normal', ARRAY['warranty_friction','communication_gap'], 'warranty', true, now() - interval '15 days');

  -- Pre-aggregated theme alerts (post-cluster)
  INSERT INTO public.customer_voc_theme_alerts_r2280
    (theme_label, product_area, mention_count_7d, mention_count_30d, baseline_avg_30d, spike_ratio, avg_sentiment, alert_severity, first_seen_at, last_seen_at, status, notes)
  VALUES
    ('parts_shortage', 'parts_availability', 4, 11, 3.2, 3.44, -0.85, 'code_red', now() - interval '15 days', now() - interval '1 day', 'investigating', 'Repeat parts back-order across 3 hospitals — supplier escalation needed'),
    ('app_crash', 'app_ux', 3, 7, 1.8, 3.89, -0.62, 'urgent', now() - interval '13 days', now() - interval '5 days', 'open', 'Android 14 photo-upload crash cluster'),
    ('sla_breach', 'repair_speed', 2, 6, 1.5, 4.0, -0.7, 'urgent', now() - interval '9 days', now() - interval '2 days', 'open', 'Slow engineer dispatch on critical jobs'),
    ('price_concern', 'pricing', 2, 4, 2.1, 1.9, -0.55, 'warning', now() - interval '8 days', now() - interval '3 days', 'open', 'Competitor undercut by ~18%'),
    ('communication_gap', 'communication', 2, 5, 1.2, 4.17, -0.52, 'urgent', now() - interval '15 days', now() - interval '9 days', 'open', 'Proactive update gap on scheduled maintenance'),
    ('engineer_conduct', 'engineer_quality', 1, 2, 0.4, 5.0, -0.75, 'warning', now() - interval '4 days', now() - interval '4 days', 'open', 'One social-media incident — investigate engineer'),
    ('churn_risk', 'amc_value', 1, 3, 0.8, 3.75, -0.7, 'urgent', now() - interval '3 days', now() - interval '3 days', 'investigating', 'AMC renewal at risk — hospital comparing competitors'),
    ('billing_error', 'billing', 1, 2, 0.5, 4.0, -0.5, 'warning', now() - interval '6 days', now() - interval '6 days', 'mitigated', 'GST rate correction applied'),
    ('warranty_friction', 'warranty', 1, 2, 0.7, 2.86, -0.5, 'watch', now() - interval '15 days', now() - interval '15 days', 'open', 'Slow warranty claim cycle'),
    ('positive_engineer', 'engineer_quality', 1, 4, 3.5, 1.14, 0.85, 'watch', now() - interval '20 days', now() - interval '10 days', 'closed', 'Retention signal — promote engineer Ravi as exemplar');

END
$seed$;

-- =========================================================================
-- RPC 1 — overview KPIs
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fn_voc_overview_r2280()
RETURNS TABLE(
  total_items_30d int,
  critical_items_30d int,
  open_alerts int,
  code_red_alerts int,
  avg_sentiment_30d numeric,
  unique_themes_30d int,
  actionable_pending int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.customer_voc_feedback_items_r2280 WHERE captured_at > now() - interval '30 days')::int,
    (SELECT COUNT(*) FROM public.customer_voc_feedback_items_r2280 WHERE captured_at > now() - interval '30 days' AND urgency_level = 'critical')::int,
    (SELECT COUNT(*) FROM public.customer_voc_theme_alerts_r2280 WHERE status IN ('open','investigating'))::int,
    (SELECT COUNT(*) FROM public.customer_voc_theme_alerts_r2280 WHERE alert_severity = 'code_red' AND status IN ('open','investigating'))::int,
    COALESCE((SELECT ROUND(AVG(sentiment_score)::numeric, 2) FROM public.customer_voc_feedback_items_r2280 WHERE captured_at > now() - interval '30 days' AND sentiment_score IS NOT NULL), 0)::numeric,
    (SELECT COUNT(DISTINCT t) FROM public.customer_voc_feedback_items_r2280, LATERAL unnest(themes_assigned) t WHERE captured_at > now() - interval '30 days')::int,
    (SELECT COUNT(*) FROM public.customer_voc_feedback_items_r2280 WHERE is_actionable = true AND triaged_at IS NULL)::int;
END $$;

REVOKE ALL ON FUNCTION public.fn_voc_overview_r2280() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_voc_overview_r2280() TO authenticated;

-- =========================================================================
-- RPC 2 — channel breakdown
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fn_voc_channel_breakdown_r2280()
RETURNS TABLE(
  source_channel text,
  item_count int,
  critical_count int,
  avg_sentiment numeric,
  last_captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    f.source_channel,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE f.urgency_level = 'critical'))::int,
    ROUND(AVG(f.sentiment_score)::numeric, 2),
    MAX(f.captured_at)
  FROM public.customer_voc_feedback_items_r2280 f
  WHERE f.captured_at > now() - interval '30 days'
  GROUP BY f.source_channel
  ORDER BY COUNT(*) DESC;
END $$;

REVOKE ALL ON FUNCTION public.fn_voc_channel_breakdown_r2280() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_voc_channel_breakdown_r2280() TO authenticated;

-- =========================================================================
-- RPC 3 — theme alerts (with severity filter)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fn_voc_theme_alerts_r2280()
RETURNS TABLE(
  id uuid,
  theme_label text,
  product_area text,
  mention_count_7d int,
  mention_count_30d int,
  spike_ratio numeric,
  avg_sentiment numeric,
  alert_severity text,
  status text,
  last_seen_at timestamptz,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    a.id, a.theme_label, a.product_area,
    a.mention_count_7d, a.mention_count_30d,
    a.spike_ratio, a.avg_sentiment,
    a.alert_severity, a.status, a.last_seen_at, a.notes
  FROM public.customer_voc_theme_alerts_r2280 a
  ORDER BY
    CASE a.alert_severity
      WHEN 'code_red' THEN 1
      WHEN 'urgent' THEN 2
      WHEN 'warning' THEN 3
      WHEN 'watch' THEN 4
    END,
    a.last_seen_at DESC;
END $$;

REVOKE ALL ON FUNCTION public.fn_voc_theme_alerts_r2280() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_voc_theme_alerts_r2280() TO authenticated;

-- =========================================================================
-- RPC 4 — product area sentiment trend
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fn_voc_product_area_sentiment_r2280()
RETURNS TABLE(
  product_area text,
  item_count int,
  avg_sentiment numeric,
  critical_count int,
  actionable_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(f.product_area, 'unknown'),
    COUNT(*)::int,
    ROUND(AVG(f.sentiment_score)::numeric, 2),
    (COUNT(*) FILTER (WHERE f.urgency_level = 'critical'))::int,
    (COUNT(*) FILTER (WHERE f.is_actionable = true))::int
  FROM public.customer_voc_feedback_items_r2280 f
  WHERE f.captured_at > now() - interval '30 days'
  GROUP BY f.product_area
  ORDER BY AVG(f.sentiment_score) ASC NULLS LAST;
END $$;

REVOKE ALL ON FUNCTION public.fn_voc_product_area_sentiment_r2280() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_voc_product_area_sentiment_r2280() TO authenticated;

-- =========================================================================
-- RPC 5 — recent actionable items (untriaged)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fn_voc_recent_actionable_r2280()
RETURNS TABLE(
  id uuid,
  source_channel text,
  reporter_role text,
  raw_text text,
  sentiment_score numeric,
  urgency_level text,
  themes_assigned text[],
  product_area text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    f.id, f.source_channel, f.reporter_role, f.raw_text,
    f.sentiment_score, f.urgency_level, f.themes_assigned,
    f.product_area, f.captured_at
  FROM public.customer_voc_feedback_items_r2280 f
  WHERE f.is_actionable = true AND f.triaged_at IS NULL
  ORDER BY
    CASE f.urgency_level
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
    END,
    f.captured_at DESC
  LIMIT 25;
END $$;

REVOKE ALL ON FUNCTION public.fn_voc_recent_actionable_r2280() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_voc_recent_actionable_r2280() TO authenticated;

-- =========================================================================
-- RPC 6 — top recurring themes (cluster snapshot)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fn_voc_top_recurring_themes_r2280()
RETURNS TABLE(
  theme text,
  mention_count int,
  avg_sentiment numeric,
  channels_seen text[],
  last_seen timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t AS theme,
    COUNT(*)::int,
    ROUND(AVG(f.sentiment_score)::numeric, 2),
    array_agg(DISTINCT f.source_channel),
    MAX(f.captured_at)
  FROM public.customer_voc_feedback_items_r2280 f,
       LATERAL unnest(f.themes_assigned) AS t
  WHERE f.captured_at > now() - interval '30 days'
  GROUP BY t
  ORDER BY COUNT(*) DESC, AVG(f.sentiment_score) ASC NULLS LAST
  LIMIT 15;
END $$;

REVOKE ALL ON FUNCTION public.fn_voc_top_recurring_themes_r2280() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_voc_top_recurring_themes_r2280() TO authenticated;

-- =========================================================================
-- RPC 7 — acknowledge alert (founder action)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fn_voc_acknowledge_alert_r2280(
  p_alert_id uuid,
  p_action_owner uuid DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_founder_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_founder_id FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;

  UPDATE public.customer_voc_theme_alerts_r2280
  SET
    acknowledged_at = now(),
    acknowledged_by = v_founder_id,
    action_owner_user_id = COALESCE(p_action_owner, action_owner_user_id),
    notes = COALESCE(p_notes, notes),
    status = CASE WHEN status = 'open' THEN 'investigating' ELSE status END,
    updated_at = now()
  WHERE id = p_alert_id;

  RETURN p_alert_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_voc_acknowledge_alert_r2280(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_voc_acknowledge_alert_r2280(uuid, uuid, text) TO authenticated;

COMMIT;