BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_cross_sell_opportunity_r2312 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  opportunity_type text NOT NULL,
  product_sku text,
  estimated_value_rupees numeric(14,2) NOT NULL DEFAULT 0,
  ripeness_score numeric(6,2) NOT NULL DEFAULT 0,
  ripeness_tier text NOT NULL DEFAULT 'cold',
  signal_summary text,
  recommended_play text,
  detected_at timestamptz NOT NULL DEFAULT now(),
  detected_by uuid REFERENCES public.profiles(id),
  status text NOT NULL DEFAULT 'open',
  closed_at timestamptz,
  closed_outcome text,
  CHECK (opportunity_type IN ('amc_tier_up','new_equipment','training_package','consumables_subscription','spare_parts_pack','remote_monitoring')),
  CHECK (ripeness_tier IN ('hot','warm','lukewarm','cold')),
  CHECK (status IN ('open','playing','won','lost','snoozed'))
);

CREATE INDEX IF NOT EXISTS idx_ccsor_r2312_customer ON public.customer_cross_sell_opportunity_r2312 (customer_user_id);
CREATE INDEX IF NOT EXISTS idx_ccsor_r2312_status ON public.customer_cross_sell_opportunity_r2312 (status);
CREATE INDEX IF NOT EXISTS idx_ccsor_r2312_ripeness ON public.customer_cross_sell_opportunity_r2312 (ripeness_score DESC);
CREATE INDEX IF NOT EXISTS idx_ccsor_r2312_type ON public.customer_cross_sell_opportunity_r2312 (opportunity_type);
CREATE INDEX IF NOT EXISTS idx_ccsor_r2312_detected ON public.customer_cross_sell_opportunity_r2312 (detected_at DESC);

ALTER TABLE public.customer_cross_sell_opportunity_r2312 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ccsor_r2312_founder_all ON public.customer_cross_sell_opportunity_r2312;
CREATE POLICY ccsor_r2312_founder_all ON public.customer_cross_sell_opportunity_r2312
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_cross_sell_play_log_r2312 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id uuid NOT NULL REFERENCES public.customer_cross_sell_opportunity_r2312(id) ON DELETE CASCADE,
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  play_channel text NOT NULL,
  play_note text,
  outcome text,
  played_at timestamptz NOT NULL DEFAULT now(),
  played_by uuid REFERENCES public.profiles(id),
  next_step text,
  next_step_due date,
  CHECK (play_channel IN ('call','email','whatsapp','site_visit','demo','quote_sent','meeting'))
);

CREATE INDEX IF NOT EXISTS idx_ccspl_r2312_opp ON public.customer_cross_sell_play_log_r2312 (opportunity_id);
CREATE INDEX IF NOT EXISTS idx_ccspl_r2312_customer ON public.customer_cross_sell_play_log_r2312 (customer_user_id);
CREATE INDEX IF NOT EXISTS idx_ccspl_r2312_played ON public.customer_cross_sell_play_log_r2312 (played_at DESC);

ALTER TABLE public.customer_cross_sell_play_log_r2312 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ccspl_r2312_founder_all ON public.customer_cross_sell_play_log_r2312;
CREATE POLICY ccspl_r2312_founder_all ON public.customer_cross_sell_play_log_r2312
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.ccsor_r2312_detect_opportunity(uuid, text, text, numeric, numeric, text, text);
CREATE OR REPLACE FUNCTION public.ccsor_r2312_detect_opportunity(
  p_customer_user_id uuid,
  p_opportunity_type text,
  p_product_sku text,
  p_estimated_value_rupees numeric,
  p_ripeness_score numeric,
  p_signal_summary text,
  p_recommended_play text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid;
  v_tier text;
  v_id uuid;
  v_score numeric(6,2);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_caller FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;

  v_score := LEAST(100, GREATEST(0, COALESCE(p_ripeness_score, 0)));

  v_tier := CASE
    WHEN v_score >= 75 THEN 'hot'
    WHEN v_score >= 50 THEN 'warm'
    WHEN v_score >= 25 THEN 'lukewarm'
    ELSE 'cold'
  END;

  INSERT INTO public.customer_cross_sell_opportunity_r2312 (
    customer_user_id, opportunity_type, product_sku, estimated_value_rupees,
    ripeness_score, ripeness_tier, signal_summary, recommended_play, detected_by
  ) VALUES (
    p_customer_user_id, p_opportunity_type, p_product_sku,
    COALESCE(p_estimated_value_rupees, 0), v_score, v_tier,
    p_signal_summary, p_recommended_play, v_caller
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ccsor_r2312_detect_opportunity(uuid, text, text, numeric, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ccsor_r2312_detect_opportunity(uuid, text, text, numeric, numeric, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.ccsor_r2312_log_play(uuid, text, text, text, text, date);
CREATE OR REPLACE FUNCTION public.ccsor_r2312_log_play(
  p_opportunity_id uuid,
  p_play_channel text,
  p_play_note text,
  p_outcome text,
  p_next_step text,
  p_next_step_due date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid;
  v_customer uuid;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_caller FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;

  SELECT customer_user_id INTO v_customer
  FROM public.customer_cross_sell_opportunity_r2312 WHERE id = p_opportunity_id;

  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'opportunity_not_found';
  END IF;

  INSERT INTO public.customer_cross_sell_play_log_r2312 (
    opportunity_id, customer_user_id, play_channel, play_note, outcome,
    played_by, next_step, next_step_due
  ) VALUES (
    p_opportunity_id, v_customer, p_play_channel, p_play_note, p_outcome,
    v_caller, p_next_step, p_next_step_due
  )
  RETURNING id INTO v_id;

  UPDATE public.customer_cross_sell_opportunity_r2312
  SET status = CASE WHEN status = 'open' THEN 'playing' ELSE status END
  WHERE id = p_opportunity_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ccsor_r2312_log_play(uuid, text, text, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ccsor_r2312_log_play(uuid, text, text, text, text, date) TO authenticated;

DROP FUNCTION IF EXISTS public.ccsor_r2312_close_opportunity(uuid, text, text);
CREATE OR REPLACE FUNCTION public.ccsor_r2312_close_opportunity(
  p_opportunity_id uuid,
  p_status text,
  p_outcome text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('won','lost','snoozed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.customer_cross_sell_opportunity_r2312
  SET status = p_status,
      closed_outcome = p_outcome,
      closed_at = now()
  WHERE id = p_opportunity_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ccsor_r2312_close_opportunity(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ccsor_r2312_close_opportunity(uuid, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.ccsor_r2312_radar(integer);
CREATE OR REPLACE FUNCTION public.ccsor_r2312_radar(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  customer_email text,
  opportunity_type text,
  product_sku text,
  estimated_value_rupees numeric,
  ripeness_score numeric,
  ripeness_tier text,
  status text,
  detected_at timestamptz
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
  SELECT o.id, p.email, o.opportunity_type, o.product_sku, o.estimated_value_rupees,
         o.ripeness_score, o.ripeness_tier, o.status, o.detected_at
  FROM public.customer_cross_sell_opportunity_r2312 o
  JOIN public.profiles p ON p.id = o.customer_user_id
  WHERE o.status IN ('open','playing')
  ORDER BY o.ripeness_score DESC, o.estimated_value_rupees DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE ALL ON FUNCTION public.ccsor_r2312_radar(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ccsor_r2312_radar(integer) TO authenticated;

DROP FUNCTION IF EXISTS public.ccsor_r2312_type_breakdown();
CREATE OR REPLACE FUNCTION public.ccsor_r2312_type_breakdown()
RETURNS TABLE (
  opportunity_type text,
  open_count integer,
  pipeline_value_rupees numeric,
  avg_ripeness numeric
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
  SELECT o.opportunity_type,
         COUNT(*)::integer,
         COALESCE(SUM(o.estimated_value_rupees), 0),
         ROUND(AVG(o.ripeness_score), 2)
  FROM public.customer_cross_sell_opportunity_r2312 o
  WHERE o.status IN ('open','playing')
  GROUP BY o.opportunity_type
  ORDER BY COALESCE(SUM(o.estimated_value_rupees), 0) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.ccsor_r2312_type_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ccsor_r2312_type_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS public.ccsor_r2312_recent_plays(integer);
CREATE OR REPLACE FUNCTION public.ccsor_r2312_recent_plays(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  customer_email text,
  opportunity_type text,
  play_channel text,
  outcome text,
  next_step text,
  next_step_due date,
  played_at timestamptz
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
  SELECT l.id, p.email, o.opportunity_type, l.play_channel, l.outcome,
         l.next_step, l.next_step_due, l.played_at
  FROM public.customer_cross_sell_play_log_r2312 l
  JOIN public.profiles p ON p.id = l.customer_user_id
  JOIN public.customer_cross_sell_opportunity_r2312 o ON o.id = l.opportunity_id
  ORDER BY l.played_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE ALL ON FUNCTION public.ccsor_r2312_recent_plays(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ccsor_r2312_recent_plays(integer) TO authenticated;

DROP FUNCTION IF EXISTS public.ccsor_r2312_hot_list(integer);
CREATE OR REPLACE FUNCTION public.ccsor_r2312_hot_list(p_limit integer DEFAULT 20)
RETURNS TABLE (
  id uuid,
  customer_email text,
  opportunity_type text,
  ripeness_score numeric,
  estimated_value_rupees numeric,
  recommended_play text,
  detected_at timestamptz
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
  SELECT o.id, p.email, o.opportunity_type, o.ripeness_score, o.estimated_value_rupees,
         o.recommended_play, o.detected_at
  FROM public.customer_cross_sell_opportunity_r2312 o
  JOIN public.profiles p ON p.id = o.customer_user_id
  WHERE o.ripeness_tier = 'hot' AND o.status IN ('open','playing')
  ORDER BY o.ripeness_score DESC, o.estimated_value_rupees DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 20));
END;
$$;

REVOKE ALL ON FUNCTION public.ccsor_r2312_hot_list(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ccsor_r2312_hot_list(integer) TO authenticated;

DROP FUNCTION IF EXISTS public.ccsor_r2312_summary();
CREATE OR REPLACE FUNCTION public.ccsor_r2312_summary()
RETURNS TABLE (
  total_open integer,
  hot_count integer,
  pipeline_value_rupees numeric,
  won_count integer,
  lost_count integer,
  plays_logged integer
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
    (SELECT COUNT(*)::integer FROM public.customer_cross_sell_opportunity_r2312 WHERE status IN ('open','playing')),
    (SELECT COUNT(*)::integer FROM public.customer_cross_sell_opportunity_r2312 WHERE ripeness_tier = 'hot' AND status IN ('open','playing')),
    (SELECT COALESCE(SUM(estimated_value_rupees), 0) FROM public.customer_cross_sell_opportunity_r2312 WHERE status IN ('open','playing')),
    (SELECT COUNT(*)::integer FROM public.customer_cross_sell_opportunity_r2312 WHERE status = 'won'),
    (SELECT COUNT(*)::integer FROM public.customer_cross_sell_opportunity_r2312 WHERE status = 'lost'),
    (SELECT COUNT(*)::integer FROM public.customer_cross_sell_play_log_r2312);
END;
$$;

REVOKE ALL ON FUNCTION public.ccsor_r2312_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ccsor_r2312_summary() TO authenticated;

COMMIT;
