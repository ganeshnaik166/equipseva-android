BEGIN;

-- Round 2402: Engineer late-night call answering rate
-- When customers call engineers after-hours (22:00-06:00 IST), track
-- % engineers answer, call topic, urgency assessment, and downstream outcome.

CREATE TABLE IF NOT EXISTS public.engineer_late_night_calls_r2402 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  called_at timestamptz NOT NULL DEFAULT now(),
  hour_of_day_ist int NOT NULL CHECK (hour_of_day_ist >= 0 AND hour_of_day_ist < 24),
  was_answered boolean NOT NULL DEFAULT false,
  ring_seconds int NOT NULL DEFAULT 0,
  call_duration_seconds int NOT NULL DEFAULT 0,
  call_topic text NOT NULL DEFAULT 'unknown' CHECK (call_topic IN ('equipment_down','panic_help','clarification','quote_chase','followup','wrong_number','unknown')),
  urgency_self_reported text NOT NULL DEFAULT 'unknown' CHECK (urgency_self_reported IN ('p0_life_safety','p1_revenue_critical','p2_inconvenience','p3_nice_to_know','unknown')),
  urgency_assessed text NOT NULL DEFAULT 'unknown' CHECK (urgency_assessed IN ('p0_life_safety','p1_revenue_critical','p2_inconvenience','p3_nice_to_know','unknown')),
  led_to_repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  callback_within_minutes int,
  resolution_note text,
  source_channel text NOT NULL DEFAULT 'voice' CHECK (source_channel IN ('voice','whatsapp','sms','app')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_elnc_r2402_engineer ON public.engineer_late_night_calls_r2402 (engineer_id, called_at DESC);
CREATE INDEX IF NOT EXISTS idx_elnc_r2402_answered ON public.engineer_late_night_calls_r2402 (was_answered, called_at DESC);
CREATE INDEX IF NOT EXISTS idx_elnc_r2402_topic ON public.engineer_late_night_calls_r2402 (call_topic, called_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_late_night_scorecards_r2402 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_calls int NOT NULL DEFAULT 0,
  answered_calls int NOT NULL DEFAULT 0,
  answer_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  avg_ring_seconds numeric(6,2) NOT NULL DEFAULT 0,
  p0_calls int NOT NULL DEFAULT 0,
  p0_answered int NOT NULL DEFAULT 0,
  p0_answer_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  tier_grade text NOT NULL DEFAULT 'unrated' CHECK (tier_grade IN ('unrated','rockstar','solid','at_risk','ghost')),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id, period_start)
);

CREATE INDEX IF NOT EXISTS idx_elns_r2402_grade ON public.engineer_late_night_scorecards_r2402 (tier_grade, period_start DESC);

ALTER TABLE public.engineer_late_night_calls_r2402 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_late_night_scorecards_r2402 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_late_night_calls_r2402;
CREATE POLICY founder_all ON public.engineer_late_night_calls_r2402 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_late_night_scorecards_r2402;
CREATE POLICY founder_all ON public.engineer_late_night_scorecards_r2402 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: per-engineer rollup with answer rate + p0 answer rate
DROP FUNCTION IF EXISTS public.engineer_late_night_rollup_r2402(int);
CREATE FUNCTION public.engineer_late_night_rollup_r2402(p_days int DEFAULT 30)
RETURNS TABLE (
  engineer_id uuid,
  engineer_name text,
  engineer_email text,
  total_calls int,
  answered_calls int,
  answer_rate_pct numeric,
  p0_calls int,
  p0_answered int,
  p0_answer_rate_pct numeric,
  avg_ring_seconds numeric,
  last_call_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.engineer_id,
    p.full_name,
    p.email,
    COUNT(*)::int,
    SUM(CASE WHEN c.was_answered THEN 1 ELSE 0 END)::int,
    ROUND(SUM(CASE WHEN c.was_answered THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0) * 100, 1),
    SUM(CASE WHEN c.urgency_assessed = 'p0_life_safety' THEN 1 ELSE 0 END)::int,
    SUM(CASE WHEN c.urgency_assessed = 'p0_life_safety' AND c.was_answered THEN 1 ELSE 0 END)::int,
    ROUND(
      SUM(CASE WHEN c.urgency_assessed = 'p0_life_safety' AND c.was_answered THEN 1 ELSE 0 END)::numeric
      / NULLIF(SUM(CASE WHEN c.urgency_assessed = 'p0_life_safety' THEN 1 ELSE 0 END),0) * 100, 1),
    ROUND(AVG(c.ring_seconds)::numeric, 1),
    MAX(c.called_at)
  FROM public.engineer_late_night_calls_r2402 c
  JOIN public.profiles p ON p.id = c.engineer_id
  WHERE c.called_at >= now() - make_interval(days => p_days)
  GROUP BY c.engineer_id, p.full_name, p.email
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.engineer_late_night_rollup_r2402(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_late_night_rollup_r2402(int) TO authenticated;

-- RPC 2: call topic breakdown
DROP FUNCTION IF EXISTS public.engineer_late_night_topic_breakdown_r2402(int);
CREATE FUNCTION public.engineer_late_night_topic_breakdown_r2402(p_days int DEFAULT 30)
RETURNS TABLE (
  call_topic text,
  call_count int,
  answered_count int,
  answer_rate_pct numeric,
  avg_duration_seconds numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.call_topic,
    COUNT(*)::int,
    SUM(CASE WHEN c.was_answered THEN 1 ELSE 0 END)::int,
    ROUND(SUM(CASE WHEN c.was_answered THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0) * 100, 1),
    ROUND(AVG(c.call_duration_seconds)::numeric, 1)
  FROM public.engineer_late_night_calls_r2402 c
  WHERE c.called_at >= now() - make_interval(days => p_days)
  GROUP BY c.call_topic
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.engineer_late_night_topic_breakdown_r2402(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_late_night_topic_breakdown_r2402(int) TO authenticated;

-- RPC 3: hour-of-day heatmap
DROP FUNCTION IF EXISTS public.engineer_late_night_hour_heatmap_r2402(int);
CREATE FUNCTION public.engineer_late_night_hour_heatmap_r2402(p_days int DEFAULT 30)
RETURNS TABLE (
  hour_of_day_ist int,
  call_count int,
  answered_count int,
  answer_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.hour_of_day_ist,
    COUNT(*)::int,
    SUM(CASE WHEN c.was_answered THEN 1 ELSE 0 END)::int,
    ROUND(SUM(CASE WHEN c.was_answered THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0) * 100, 1)
  FROM public.engineer_late_night_calls_r2402 c
  WHERE c.called_at >= now() - make_interval(days => p_days)
  GROUP BY c.hour_of_day_ist
  ORDER BY c.hour_of_day_ist;
END $$;
REVOKE ALL ON FUNCTION public.engineer_late_night_hour_heatmap_r2402(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_late_night_hour_heatmap_r2402(int) TO authenticated;

-- RPC 4: recent call log with engineer + customer org
DROP FUNCTION IF EXISTS public.engineer_late_night_recent_r2402(int);
CREATE FUNCTION public.engineer_late_night_recent_r2402(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  called_at timestamptz,
  engineer_name text,
  customer_org text,
  hour_of_day_ist int,
  was_answered boolean,
  ring_seconds int,
  call_topic text,
  urgency_assessed text,
  callback_within_minutes int,
  resolution_note text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.called_at,
    p.full_name,
    o.name,
    c.hour_of_day_ist,
    c.was_answered,
    c.ring_seconds,
    c.call_topic,
    c.urgency_assessed,
    c.callback_within_minutes,
    c.resolution_note
  FROM public.engineer_late_night_calls_r2402 c
  JOIN public.profiles p ON p.id = c.engineer_id
  LEFT JOIN public.organizations o ON o.id = c.customer_org_id
  ORDER BY c.called_at DESC
  LIMIT p_limit;
END $$;
REVOKE ALL ON FUNCTION public.engineer_late_night_recent_r2402(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_late_night_recent_r2402(int) TO authenticated;

-- RPC 5: log a late-night call (and auto-fill hour_of_day_ist if zero)
DROP FUNCTION IF EXISTS public.engineer_late_night_log_call_r2402(uuid, uuid, boolean, int, int, text, text, text, int, text, text);
CREATE FUNCTION public.engineer_late_night_log_call_r2402(
  p_engineer_id uuid,
  p_customer_org_id uuid,
  p_was_answered boolean,
  p_ring_seconds int,
  p_call_duration_seconds int,
  p_call_topic text,
  p_urgency_self_reported text,
  p_urgency_assessed text,
  p_callback_within_minutes int,
  p_resolution_note text,
  p_source_channel text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_hour int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_call_topic NOT IN ('equipment_down','panic_help','clarification','quote_chase','followup','wrong_number','unknown') THEN
    RAISE EXCEPTION 'bad_topic';
  END IF;
  IF p_urgency_assessed NOT IN ('p0_life_safety','p1_revenue_critical','p2_inconvenience','p3_nice_to_know','unknown') THEN
    RAISE EXCEPTION 'bad_urgency';
  END IF;

  v_hour := EXTRACT(HOUR FROM (now() AT TIME ZONE 'Asia/Kolkata'))::int;

  INSERT INTO public.engineer_late_night_calls_r2402 (
    engineer_id, customer_org_id, hour_of_day_ist,
    was_answered, ring_seconds, call_duration_seconds,
    call_topic, urgency_self_reported, urgency_assessed,
    callback_within_minutes, resolution_note, source_channel
  ) VALUES (
    p_engineer_id, p_customer_org_id, v_hour,
    COALESCE(p_was_answered,false), COALESCE(p_ring_seconds,0), COALESCE(p_call_duration_seconds,0),
    p_call_topic, COALESCE(p_urgency_self_reported,'unknown'), p_urgency_assessed,
    p_callback_within_minutes, p_resolution_note, COALESCE(p_source_channel,'voice')
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.engineer_late_night_log_call_r2402(uuid, uuid, boolean, int, int, text, text, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_late_night_log_call_r2402(uuid, uuid, boolean, int, int, text, text, text, int, text, text) TO authenticated;

-- RPC 6: rebuild scorecard for an engineer + period
DROP FUNCTION IF EXISTS public.engineer_late_night_rebuild_scorecard_r2402(uuid, date, date);
CREATE FUNCTION public.engineer_late_night_rebuild_scorecard_r2402(
  p_engineer_id uuid,
  p_period_start date,
  p_period_end date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total int; v_answered int; v_rate numeric;
  v_p0 int; v_p0a int; v_p0_rate numeric;
  v_ring numeric;
  v_grade text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT
    COUNT(*)::int,
    SUM(CASE WHEN was_answered THEN 1 ELSE 0 END)::int,
    SUM(CASE WHEN urgency_assessed = 'p0_life_safety' THEN 1 ELSE 0 END)::int,
    SUM(CASE WHEN urgency_assessed = 'p0_life_safety' AND was_answered THEN 1 ELSE 0 END)::int,
    COALESCE(AVG(ring_seconds),0)::numeric
  INTO v_total, v_answered, v_p0, v_p0a, v_ring
  FROM public.engineer_late_night_calls_r2402
  WHERE engineer_id = p_engineer_id
    AND called_at::date BETWEEN p_period_start AND p_period_end;

  v_rate := CASE WHEN v_total > 0 THEN ROUND(v_answered::numeric / v_total * 100, 1) ELSE 0 END;
  v_p0_rate := CASE WHEN v_p0 > 0 THEN ROUND(v_p0a::numeric / v_p0 * 100, 1) ELSE 0 END;

  v_grade := CASE
    WHEN v_total = 0 THEN 'unrated'
    WHEN v_p0 > 0 AND v_p0_rate >= 95 AND v_rate >= 80 THEN 'rockstar'
    WHEN v_rate >= 65 THEN 'solid'
    WHEN v_rate >= 35 THEN 'at_risk'
    ELSE 'ghost'
  END;

  INSERT INTO public.engineer_late_night_scorecards_r2402 (
    engineer_id, period_start, period_end,
    total_calls, answered_calls, answer_rate_pct,
    avg_ring_seconds, p0_calls, p0_answered, p0_answer_rate_pct,
    tier_grade
  ) VALUES (
    p_engineer_id, p_period_start, p_period_end,
    v_total, v_answered, v_rate, v_ring, v_p0, v_p0a, v_p0_rate, v_grade
  )
  ON CONFLICT (engineer_id, period_start) DO UPDATE SET
    period_end = EXCLUDED.period_end,
    total_calls = EXCLUDED.total_calls,
    answered_calls = EXCLUDED.answered_calls,
    answer_rate_pct = EXCLUDED.answer_rate_pct,
    avg_ring_seconds = EXCLUDED.avg_ring_seconds,
    p0_calls = EXCLUDED.p0_calls,
    p0_answered = EXCLUDED.p0_answered,
    p0_answer_rate_pct = EXCLUDED.p0_answer_rate_pct,
    tier_grade = EXCLUDED.tier_grade,
    updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.engineer_late_night_rebuild_scorecard_r2402(uuid, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_late_night_rebuild_scorecard_r2402(uuid, date, date) TO authenticated;

-- RPC 7: scorecard list + founder note set
DROP FUNCTION IF EXISTS public.engineer_late_night_scorecards_list_r2402(int);
CREATE FUNCTION public.engineer_late_night_scorecards_list_r2402(p_limit int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  engineer_name text,
  period_start date,
  period_end date,
  total_calls int,
  answer_rate_pct numeric,
  p0_calls int,
  p0_answer_rate_pct numeric,
  avg_ring_seconds numeric,
  tier_grade text,
  founder_note text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    p.full_name,
    s.period_start,
    s.period_end,
    s.total_calls,
    s.answer_rate_pct,
    s.p0_calls,
    s.p0_answer_rate_pct,
    s.avg_ring_seconds,
    s.tier_grade,
    s.founder_note
  FROM public.engineer_late_night_scorecards_r2402 s
  JOIN public.profiles p ON p.id = s.engineer_id
  ORDER BY s.period_start DESC, s.answer_rate_pct ASC
  LIMIT p_limit;
END $$;
REVOKE ALL ON FUNCTION public.engineer_late_night_scorecards_list_r2402(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_late_night_scorecards_list_r2402(int) TO authenticated;

COMMIT;
