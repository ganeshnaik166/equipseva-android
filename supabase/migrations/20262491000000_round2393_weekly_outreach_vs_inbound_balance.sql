BEGIN;

-- ============================================================================
-- Round 2393 — Founder weekly outreach-vs-inbound balance
-- Tracks outbound (founder reaching out) vs inbound (people reaching out)
-- weekly counts, trend, and balance ratio.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_outreach_events_r2393 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  counterparty_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  counterparty_name text NOT NULL,
  counterparty_role text,
  direction text NOT NULL CHECK (direction IN ('outbound','inbound')),
  channel text NOT NULL CHECK (channel IN ('email','whatsapp','call','meeting','linkedin','dm','sms','other')),
  topic text NOT NULL,
  subject_line text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  week_start date NOT NULL DEFAULT date_trunc('week', now())::date,
  response_received boolean NOT NULL DEFAULT false,
  response_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_outreach_events_r2393_week
  ON public.founder_outreach_events_r2393 (week_start DESC, direction);
CREATE INDEX IF NOT EXISTS idx_outreach_events_r2393_founder
  ON public.founder_outreach_events_r2393 (founder_id, occurred_at DESC);

ALTER TABLE public.founder_outreach_events_r2393 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_outreach_events_r2393 ON public.founder_outreach_events_r2393;
CREATE POLICY founder_all_outreach_events_r2393
  ON public.founder_outreach_events_r2393
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.founder_outreach_weekly_targets_r2393 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  outbound_target int NOT NULL DEFAULT 25,
  inbound_target int NOT NULL DEFAULT 15,
  target_ratio numeric(5,2) NOT NULL DEFAULT 1.67, -- outbound/inbound goal
  notes text,
  set_by_email text,
  set_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_outreach_targets_r2393_week
  ON public.founder_outreach_weekly_targets_r2393 (week_start DESC);

ALTER TABLE public.founder_outreach_weekly_targets_r2393 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_outreach_targets_r2393 ON public.founder_outreach_weekly_targets_r2393;
CREATE POLICY founder_all_outreach_targets_r2393
  ON public.founder_outreach_weekly_targets_r2393
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================================
-- RPC 1: weekly balance summary (last 12 weeks)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2393_weekly_balance()
RETURNS TABLE (
  week_start date,
  outbound_count bigint,
  inbound_count bigint,
  total_count bigint,
  outbound_pct numeric,
  inbound_pct numeric,
  ratio numeric,
  outbound_target int,
  inbound_target int,
  balance_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now())::date - INTERVAL '11 weeks',
      date_trunc('week', now())::date,
      INTERVAL '1 week'
    )::date AS wk
  ),
  counts AS (
    SELECT
      e.week_start,
      COUNT(*) FILTER (WHERE e.direction = 'outbound') AS ob,
      COUNT(*) FILTER (WHERE e.direction = 'inbound')  AS ib
    FROM public.founder_outreach_events_r2393 e
    WHERE e.week_start >= date_trunc('week', now())::date - INTERVAL '11 weeks'
    GROUP BY e.week_start
  )
  SELECT
    w.wk AS week_start,
    COALESCE(c.ob, 0) AS outbound_count,
    COALESCE(c.ib, 0) AS inbound_count,
    COALESCE(c.ob, 0) + COALESCE(c.ib, 0) AS total_count,
    CASE WHEN COALESCE(c.ob, 0) + COALESCE(c.ib, 0) = 0 THEN 0
         ELSE ROUND(100.0 * COALESCE(c.ob, 0) / (COALESCE(c.ob, 0) + COALESCE(c.ib, 0)), 1) END AS outbound_pct,
    CASE WHEN COALESCE(c.ob, 0) + COALESCE(c.ib, 0) = 0 THEN 0
         ELSE ROUND(100.0 * COALESCE(c.ib, 0) / (COALESCE(c.ob, 0) + COALESCE(c.ib, 0)), 1) END AS inbound_pct,
    CASE WHEN COALESCE(c.ib, 0) = 0 THEN NULL
         ELSE ROUND(COALESCE(c.ob, 0)::numeric / c.ib::numeric, 2) END AS ratio,
    COALESCE(t.outbound_target, 25) AS outbound_target,
    COALESCE(t.inbound_target, 15) AS inbound_target,
    CASE
      WHEN COALESCE(c.ob, 0) + COALESCE(c.ib, 0) = 0 THEN 'no activity'
      WHEN COALESCE(c.ib, 0) = 0 THEN 'all outbound'
      WHEN COALESCE(c.ob, 0)::numeric / c.ib::numeric >= 2.0 THEN 'push heavy'
      WHEN COALESCE(c.ob, 0)::numeric / c.ib::numeric <= 0.5 THEN 'pull heavy'
      ELSE 'balanced'
    END AS balance_status
  FROM weeks w
  LEFT JOIN counts c ON c.week_start = w.wk
  LEFT JOIN public.founder_outreach_weekly_targets_r2393 t ON t.week_start = w.wk
  ORDER BY w.wk DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2393_weekly_balance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2393_weekly_balance() TO authenticated;


-- ============================================================================
-- RPC 2: channel breakdown current week
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2393_channel_breakdown()
RETURNS TABLE (
  channel text,
  outbound_count bigint,
  inbound_count bigint,
  total_count bigint,
  response_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.channel,
    COUNT(*) FILTER (WHERE e.direction = 'outbound') AS outbound_count,
    COUNT(*) FILTER (WHERE e.direction = 'inbound')  AS inbound_count,
    COUNT(*) AS total_count,
    CASE WHEN COUNT(*) FILTER (WHERE e.direction = 'outbound') = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE e.direction = 'outbound' AND e.response_received)
                    / COUNT(*) FILTER (WHERE e.direction = 'outbound'), 1) END AS response_rate_pct
  FROM public.founder_outreach_events_r2393 e
  WHERE e.week_start = date_trunc('week', now())::date
  GROUP BY e.channel
  ORDER BY total_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2393_channel_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2393_channel_breakdown() TO authenticated;


-- ============================================================================
-- RPC 3: top counterparties this month
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2393_top_counterparties()
RETURNS TABLE (
  counterparty_name text,
  counterparty_role text,
  outbound_count bigint,
  inbound_count bigint,
  total_touches bigint,
  last_touch_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.counterparty_name,
    e.counterparty_role,
    COUNT(*) FILTER (WHERE e.direction = 'outbound') AS outbound_count,
    COUNT(*) FILTER (WHERE e.direction = 'inbound')  AS inbound_count,
    COUNT(*) AS total_touches,
    MAX(e.occurred_at) AS last_touch_at
  FROM public.founder_outreach_events_r2393 e
  WHERE e.occurred_at >= now() - INTERVAL '30 days'
  GROUP BY e.counterparty_name, e.counterparty_role
  ORDER BY total_touches DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2393_top_counterparties() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2393_top_counterparties() TO authenticated;


-- ============================================================================
-- RPC 4: recent events (last 50)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2393_recent_events()
RETURNS TABLE (
  id uuid,
  direction text,
  channel text,
  counterparty_name text,
  counterparty_role text,
  topic text,
  occurred_at timestamptz,
  response_received boolean,
  week_start date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.id, e.direction, e.channel, e.counterparty_name, e.counterparty_role,
    e.topic, e.occurred_at, e.response_received, e.week_start
  FROM public.founder_outreach_events_r2393 e
  ORDER BY e.occurred_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2393_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2393_recent_events() TO authenticated;


-- ============================================================================
-- RPC 5: log new event
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2393_log_event(
  p_direction text,
  p_channel text,
  p_counterparty_name text,
  p_topic text,
  p_counterparty_role text DEFAULT NULL,
  p_subject_line text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_founder_id uuid;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT id INTO v_founder_id FROM public.profiles
   WHERE email = auth.jwt()->>'email' LIMIT 1;

  INSERT INTO public.founder_outreach_events_r2393
    (founder_id, counterparty_name, counterparty_role, direction, channel, topic, subject_line, notes)
  VALUES
    (v_founder_id, p_counterparty_name, p_counterparty_role, p_direction, p_channel, p_topic, p_subject_line, p_notes)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2393_log_event(text,text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2393_log_event(text,text,text,text,text,text,text) TO authenticated;


-- ============================================================================
-- RPC 6: set weekly targets
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2393_set_targets(
  p_week_start date,
  p_outbound_target int,
  p_inbound_target int,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_ratio numeric(5,2);
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_ratio := CASE WHEN p_inbound_target = 0 THEN 0
                  ELSE ROUND(p_outbound_target::numeric / p_inbound_target::numeric, 2) END;

  INSERT INTO public.founder_outreach_weekly_targets_r2393
    (week_start, outbound_target, inbound_target, target_ratio, notes, set_by_email)
  VALUES
    (p_week_start, p_outbound_target, p_inbound_target, v_ratio, p_notes, auth.jwt()->>'email')
  ON CONFLICT (week_start) DO UPDATE
    SET outbound_target = EXCLUDED.outbound_target,
        inbound_target = EXCLUDED.inbound_target,
        target_ratio = EXCLUDED.target_ratio,
        notes = EXCLUDED.notes,
        set_by_email = EXCLUDED.set_by_email,
        set_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2393_set_targets(date,int,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2393_set_targets(date,int,int,text) TO authenticated;


-- ============================================================================
-- RPC 7: headline KPIs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_r2393_headline_kpis()
RETURNS TABLE (
  current_week_outbound bigint,
  current_week_inbound bigint,
  current_week_ratio numeric,
  prior_week_outbound bigint,
  prior_week_inbound bigint,
  prior_week_ratio numeric,
  outbound_wow_delta_pct numeric,
  inbound_wow_delta_pct numeric,
  trailing_4w_outbound bigint,
  trailing_4w_inbound bigint,
  response_rate_pct numeric,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cw_start date := date_trunc('week', now())::date;
  v_pw_start date := v_cw_start - INTERVAL '1 week';
  v_cw_ob bigint; v_cw_ib bigint;
  v_pw_ob bigint; v_pw_ib bigint;
  v_4w_ob bigint; v_4w_ib bigint;
  v_resp_total bigint; v_resp_yes bigint;
  v_status text;
  v_cw_ratio numeric; v_pw_ratio numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT
    COUNT(*) FILTER (WHERE direction = 'outbound'),
    COUNT(*) FILTER (WHERE direction = 'inbound')
  INTO v_cw_ob, v_cw_ib
  FROM public.founder_outreach_events_r2393
  WHERE week_start = v_cw_start;

  SELECT
    COUNT(*) FILTER (WHERE direction = 'outbound'),
    COUNT(*) FILTER (WHERE direction = 'inbound')
  INTO v_pw_ob, v_pw_ib
  FROM public.founder_outreach_events_r2393
  WHERE week_start = v_pw_start;

  SELECT
    COUNT(*) FILTER (WHERE direction = 'outbound'),
    COUNT(*) FILTER (WHERE direction = 'inbound')
  INTO v_4w_ob, v_4w_ib
  FROM public.founder_outreach_events_r2393
  WHERE week_start >= v_cw_start - INTERVAL '3 weeks';

  SELECT
    COUNT(*) FILTER (WHERE direction = 'outbound'),
    COUNT(*) FILTER (WHERE direction = 'outbound' AND response_received)
  INTO v_resp_total, v_resp_yes
  FROM public.founder_outreach_events_r2393
  WHERE occurred_at >= now() - INTERVAL '30 days';

  v_cw_ratio := CASE WHEN v_cw_ib = 0 THEN NULL ELSE ROUND(v_cw_ob::numeric / v_cw_ib::numeric, 2) END;
  v_pw_ratio := CASE WHEN v_pw_ib = 0 THEN NULL ELSE ROUND(v_pw_ob::numeric / v_pw_ib::numeric, 2) END;

  v_status := CASE
    WHEN v_cw_ob + v_cw_ib = 0 THEN 'no activity'
    WHEN v_cw_ib = 0 THEN 'all outbound'
    WHEN v_cw_ratio >= 2.0 THEN 'push heavy'
    WHEN v_cw_ratio <= 0.5 THEN 'pull heavy'
    ELSE 'balanced'
  END;

  RETURN QUERY
  SELECT
    v_cw_ob,
    v_cw_ib,
    v_cw_ratio,
    v_pw_ob,
    v_pw_ib,
    v_pw_ratio,
    CASE WHEN v_pw_ob = 0 THEN NULL ELSE ROUND(100.0 * (v_cw_ob - v_pw_ob) / v_pw_ob, 1) END,
    CASE WHEN v_pw_ib = 0 THEN NULL ELSE ROUND(100.0 * (v_cw_ib - v_pw_ib) / v_pw_ib, 1) END,
    v_4w_ob,
    v_4w_ib,
    CASE WHEN v_resp_total = 0 THEN 0 ELSE ROUND(100.0 * v_resp_yes / v_resp_total, 1) END,
    v_status;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2393_headline_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2393_headline_kpis() TO authenticated;

COMMIT;
