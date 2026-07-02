BEGIN;

CREATE TABLE IF NOT EXISTS public.warranty_expiry_pipeline_r2239 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  equipment_make text,
  equipment_model text,
  equipment_serial text,
  warranty_expires_on date NOT NULL,
  days_to_expiry int,
  pipeline_stage text NOT NULL DEFAULT 'identified' CHECK (pipeline_stage IN ('identified','contacted','quote_sent','negotiating','won','lost','expired_no_action')),
  proposed_amc_tier text CHECK (proposed_amc_tier IN ('basic','standard','premium','comprehensive')),
  proposed_annual_fee_rupees int CHECK (proposed_annual_fee_rupees IS NULL OR proposed_annual_fee_rupees >= 0),
  win_probability_pct int CHECK (win_probability_pct IS NULL OR (win_probability_pct BETWEEN 0 AND 100)),
  competitor_quote_rupees int CHECK (competitor_quote_rupees IS NULL OR competitor_quote_rupees >= 0),
  lost_reason text,
  contacted_at timestamptz,
  closed_at timestamptz,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wep_r2239_hospital ON public.warranty_expiry_pipeline_r2239(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_wep_r2239_stage ON public.warranty_expiry_pipeline_r2239(pipeline_stage);
CREATE INDEX IF NOT EXISTS idx_wep_r2239_expires ON public.warranty_expiry_pipeline_r2239(warranty_expires_on);

ALTER TABLE public.warranty_expiry_pipeline_r2239 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.warranty_expiry_pipeline_r2239;
CREATE POLICY founder_all ON public.warranty_expiry_pipeline_r2239
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.warranty_conversion_touches_r2239 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.warranty_expiry_pipeline_r2239(id) ON DELETE CASCADE,
  touch_kind text NOT NULL CHECK (touch_kind IN ('call','email','whatsapp','site_visit','quote','followup','demo')),
  touch_summary text,
  outcome text CHECK (outcome IN ('positive','neutral','negative','no_response','escalated')),
  next_action_on date,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wct_r2239_pipeline ON public.warranty_conversion_touches_r2239(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_wct_r2239_occurred ON public.warranty_conversion_touches_r2239(occurred_at);

ALTER TABLE public.warranty_conversion_touches_r2239 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.warranty_conversion_touches_r2239;
CREATE POLICY founder_all ON public.warranty_conversion_touches_r2239
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: pipeline summary
CREATE OR REPLACE FUNCTION public.warranty_pipeline_summary_r2239()
RETURNS TABLE(total_in_pipeline int, expiring_30d int, won_ytd int, lost_ytd int, win_rate_pct numeric, total_pipeline_value_rupees bigint, lost_revenue_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE pipeline_stage NOT IN ('won','lost','expired_no_action')))::int,
    (COUNT(*) FILTER (WHERE warranty_expires_on <= (CURRENT_DATE + INTERVAL '30 days') AND pipeline_stage NOT IN ('won','lost','expired_no_action')))::int,
    (COUNT(*) FILTER (WHERE pipeline_stage = 'won' AND closed_at >= date_trunc('year', now())))::int,
    (COUNT(*) FILTER (WHERE pipeline_stage = 'lost' AND closed_at >= date_trunc('year', now())))::int,
    CASE WHEN COUNT(*) FILTER (WHERE pipeline_stage IN ('won','lost')) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE pipeline_stage = 'won') / NULLIF(COUNT(*) FILTER (WHERE pipeline_stage IN ('won','lost')),0), 1)
      ELSE 0 END,
    COALESCE(SUM(proposed_annual_fee_rupees) FILTER (WHERE pipeline_stage NOT IN ('won','lost','expired_no_action')), 0)::bigint,
    COALESCE(SUM(proposed_annual_fee_rupees) FILTER (WHERE pipeline_stage = 'lost'), 0)::bigint
  FROM public.warranty_expiry_pipeline_r2239;
END $$;

REVOKE ALL ON FUNCTION public.warranty_pipeline_summary_r2239() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.warranty_pipeline_summary_r2239() TO authenticated;

-- RPC 2: stage breakdown
CREATE OR REPLACE FUNCTION public.warranty_stage_breakdown_r2239()
RETURNS TABLE(stage text, deal_count int, total_value_rupees bigint, avg_win_prob_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    pipeline_stage,
    COUNT(*)::int,
    COALESCE(SUM(proposed_annual_fee_rupees), 0)::bigint,
    ROUND(COALESCE(AVG(win_probability_pct), 0), 1)
  FROM public.warranty_expiry_pipeline_r2239
  GROUP BY pipeline_stage
  ORDER BY deal_count DESC;
END $$;

REVOKE ALL ON FUNCTION public.warranty_stage_breakdown_r2239() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.warranty_stage_breakdown_r2239() TO authenticated;

-- RPC 3: hot leads (expiring soon)
CREATE OR REPLACE FUNCTION public.warranty_hot_leads_r2239()
RETURNS TABLE(equipment_label text, hospital_org_id uuid, warranty_expires_on date, days_left int, pipeline_stage text, proposed_annual_fee_rupees int, win_probability_pct int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.equipment_label,
    p.hospital_org_id,
    p.warranty_expires_on,
    (p.warranty_expires_on - CURRENT_DATE)::int,
    p.pipeline_stage,
    p.proposed_annual_fee_rupees,
    p.win_probability_pct
  FROM public.warranty_expiry_pipeline_r2239 p
  WHERE p.pipeline_stage NOT IN ('won','lost','expired_no_action')
    AND p.warranty_expires_on <= (CURRENT_DATE + INTERVAL '60 days')
  ORDER BY p.warranty_expires_on ASC
  LIMIT 50;
END $$;

REVOKE ALL ON FUNCTION public.warranty_hot_leads_r2239() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.warranty_hot_leads_r2239() TO authenticated;

-- RPC 4: lost reason breakdown
CREATE OR REPLACE FUNCTION public.warranty_lost_reasons_r2239()
RETURNS TABLE(lost_reason text, deal_count int, lost_value_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(p.lost_reason, 'unspecified')::text,
    COUNT(*)::int,
    COALESCE(SUM(p.proposed_annual_fee_rupees), 0)::bigint
  FROM public.warranty_expiry_pipeline_r2239 p
  WHERE p.pipeline_stage = 'lost'
  GROUP BY p.lost_reason
  ORDER BY deal_count DESC
  LIMIT 20;
END $$;

REVOKE ALL ON FUNCTION public.warranty_lost_reasons_r2239() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.warranty_lost_reasons_r2239() TO authenticated;

-- RPC 5: tier mix on won deals
CREATE OR REPLACE FUNCTION public.warranty_won_tier_mix_r2239()
RETURNS TABLE(amc_tier text, deals_won int, total_fee_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(p.proposed_amc_tier, 'unset')::text,
    COUNT(*)::int,
    COALESCE(SUM(p.proposed_annual_fee_rupees), 0)::bigint
  FROM public.warranty_expiry_pipeline_r2239 p
  WHERE p.pipeline_stage = 'won'
  GROUP BY p.proposed_amc_tier
  ORDER BY deals_won DESC;
END $$;

REVOKE ALL ON FUNCTION public.warranty_won_tier_mix_r2239() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.warranty_won_tier_mix_r2239() TO authenticated;

-- RPC 6: recent touches
CREATE OR REPLACE FUNCTION public.warranty_recent_touches_r2239()
RETURNS TABLE(occurred_at timestamptz, equipment_label text, touch_kind text, outcome text, touch_summary text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.occurred_at,
    p.equipment_label,
    t.touch_kind,
    COALESCE(t.outcome, 'pending')::text,
    t.touch_summary
  FROM public.warranty_conversion_touches_r2239 t
  JOIN public.warranty_expiry_pipeline_r2239 p ON p.id = t.pipeline_id
  ORDER BY t.occurred_at DESC
  LIMIT 50;
END $$;

REVOKE ALL ON FUNCTION public.warranty_recent_touches_r2239() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.warranty_recent_touches_r2239() TO authenticated;

-- RPC 7: monthly trend (last 6 months)
CREATE OR REPLACE FUNCTION public.warranty_monthly_trend_r2239()
RETURNS TABLE(month_label text, won_count int, lost_count int, won_value_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('month', p.closed_at), 'YYYY-MM')::text,
    (COUNT(*) FILTER (WHERE p.pipeline_stage = 'won'))::int,
    (COUNT(*) FILTER (WHERE p.pipeline_stage = 'lost'))::int,
    COALESCE(SUM(p.proposed_annual_fee_rupees) FILTER (WHERE p.pipeline_stage = 'won'), 0)::bigint
  FROM public.warranty_expiry_pipeline_r2239 p
  WHERE p.closed_at >= (now() - INTERVAL '6 months')
    AND p.pipeline_stage IN ('won','lost')
  GROUP BY date_trunc('month', p.closed_at)
  ORDER BY date_trunc('month', p.closed_at) DESC;
END $$;

REVOKE ALL ON FUNCTION public.warranty_monthly_trend_r2239() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.warranty_monthly_trend_r2239() TO authenticated;

COMMIT;
