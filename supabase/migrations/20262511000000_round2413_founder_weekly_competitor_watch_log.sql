BEGIN;

-- =========================================================================
-- r2413: Founder weekly competitor watch log
-- Track competitor moves observed × threat level × counter-action × insight
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.competitor_moves_r2413 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_name text NOT NULL,
  observed_at timestamptz NOT NULL DEFAULT now(),
  move_kind text NOT NULL
    CHECK (move_kind IN ('pricing','feature_launch','funding','partnership','hire','lawsuit','exit')),
  summary text NOT NULL,
  source_url text,
  threat_level text NOT NULL DEFAULT 'low'
    CHECK (threat_level IN ('low','medium','high','critical')),
  insight_category text NOT NULL
    CHECK (insight_category IN ('commercial','product','legal','talent','market')),
  counter_action text,
  counter_owner_email text,
  counter_due_at timestamptz,
  counter_status text NOT NULL DEFAULT 'none'
    CHECK (counter_status IN ('none','planned','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_competitor_moves_r2413_observed
  ON public.competitor_moves_r2413 (observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_competitor_moves_r2413_competitor
  ON public.competitor_moves_r2413 (competitor_name);
CREATE INDEX IF NOT EXISTS idx_competitor_moves_r2413_threat
  ON public.competitor_moves_r2413 (threat_level);

CREATE TABLE IF NOT EXISTS public.competitor_weekly_digest_r2413 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  total_moves int NOT NULL DEFAULT 0,
  high_threat_count int NOT NULL DEFAULT 0,
  critical_threat_count int NOT NULL DEFAULT 0,
  top_competitor text,
  top_threat_level text
    CHECK (top_threat_level IS NULL OR top_threat_level IN ('low','medium','high','critical')),
  summary_md text,
  founder_takeaways_md text,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_competitor_digest_r2413_week
  ON public.competitor_weekly_digest_r2413 (week_start DESC);

ALTER TABLE public.competitor_moves_r2413 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competitor_weekly_digest_r2413 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.competitor_moves_r2413;
CREATE POLICY founder_all ON public.competitor_moves_r2413
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.competitor_weekly_digest_r2413;
CREATE POLICY founder_all ON public.competitor_weekly_digest_r2413
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_moves_r2413 — recent competitor moves with counter status
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_moves_r2413(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  observed_at timestamptz,
  competitor_name text,
  move_kind text,
  summary text,
  threat_level text,
  insight_category text,
  counter_action text,
  counter_owner_email text,
  counter_due_at timestamptz,
  counter_status text,
  source_url text,
  age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      m.id,
      m.observed_at,
      m.competitor_name,
      m.move_kind,
      m.summary,
      m.threat_level,
      m.insight_category,
      m.counter_action,
      m.counter_owner_email,
      m.counter_due_at,
      m.counter_status,
      m.source_url,
      GREATEST(0, (CURRENT_DATE - m.observed_at::date))::int AS age_days
    FROM public.competitor_moves_r2413 m
    ORDER BY m.observed_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_moves_r2413(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_moves_r2413(int) TO authenticated;

-- =========================================================================
-- RPC 2: threat_breakdown_r2413 — count moves by threat level
-- =========================================================================
CREATE OR REPLACE FUNCTION public.threat_breakdown_r2413(p_weeks int DEFAULT 12)
RETURNS TABLE (
  threat_level text,
  move_count bigint,
  with_counter bigint,
  counter_done bigint,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) INTO v_total
  FROM public.competitor_moves_r2413 m
  WHERE m.observed_at >= now() - make_interval(weeks => GREATEST(p_weeks, 1));

  RETURN QUERY
    SELECT
      m.threat_level,
      COUNT(*)::bigint AS move_count,
      COUNT(*) FILTER (WHERE m.counter_action IS NOT NULL)::bigint AS with_counter,
      COUNT(*) FILTER (WHERE m.counter_status = 'done')::bigint AS counter_done,
      CASE WHEN v_total > 0
        THEN ROUND((COUNT(*)::numeric / v_total) * 100, 1)
        ELSE 0 END AS share_pct
    FROM public.competitor_moves_r2413 m
    WHERE m.observed_at >= now() - make_interval(weeks => GREATEST(p_weeks, 1))
    GROUP BY m.threat_level
    ORDER BY
      CASE m.threat_level
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        ELSE 5
      END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.threat_breakdown_r2413(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.threat_breakdown_r2413(int) TO authenticated;

-- =========================================================================
-- RPC 3: by_competitor_r2413 — rollup per competitor
-- =========================================================================
CREATE OR REPLACE FUNCTION public.by_competitor_r2413(p_weeks int DEFAULT 12)
RETURNS TABLE (
  competitor_name text,
  move_count bigint,
  critical_count bigint,
  high_count bigint,
  last_observed_at timestamptz,
  top_kind text,
  open_counters bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH base AS (
      SELECT *
      FROM public.competitor_moves_r2413 m
      WHERE m.observed_at >= now() - make_interval(weeks => GREATEST(p_weeks, 1))
    ),
    top_kinds AS (
      SELECT b.competitor_name, b.move_kind,
        ROW_NUMBER() OVER (PARTITION BY b.competitor_name ORDER BY COUNT(*) DESC) AS rn
      FROM base b
      GROUP BY b.competitor_name, b.move_kind
    )
    SELECT
      b.competitor_name,
      COUNT(*)::bigint AS move_count,
      COUNT(*) FILTER (WHERE b.threat_level = 'critical')::bigint AS critical_count,
      COUNT(*) FILTER (WHERE b.threat_level = 'high')::bigint AS high_count,
      MAX(b.observed_at) AS last_observed_at,
      (SELECT tk.move_kind FROM top_kinds tk
        WHERE tk.competitor_name = b.competitor_name AND tk.rn = 1 LIMIT 1) AS top_kind,
      COUNT(*) FILTER (WHERE b.counter_status IN ('planned','in_progress'))::bigint AS open_counters
    FROM base b
    GROUP BY b.competitor_name
    ORDER BY move_count DESC, last_observed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.by_competitor_r2413(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.by_competitor_r2413(int) TO authenticated;

-- =========================================================================
-- RPC 4: top_threats_r2413 — most-recent high/critical moves
-- =========================================================================
CREATE OR REPLACE FUNCTION public.top_threats_r2413(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  observed_at timestamptz,
  competitor_name text,
  move_kind text,
  threat_level text,
  insight_category text,
  summary text,
  counter_status text,
  counter_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      m.id,
      m.observed_at,
      m.competitor_name,
      m.move_kind,
      m.threat_level,
      m.insight_category,
      m.summary,
      m.counter_status,
      m.counter_action
    FROM public.competitor_moves_r2413 m
    WHERE m.threat_level IN ('high','critical')
    ORDER BY
      CASE m.threat_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
      m.observed_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_threats_r2413(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_threats_r2413(int) TO authenticated;

-- =========================================================================
-- RPC 5: counter_actions_due_r2413 — outstanding counter-actions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.counter_actions_due_r2413()
RETURNS TABLE (
  id uuid,
  competitor_name text,
  threat_level text,
  counter_action text,
  counter_owner_email text,
  counter_due_at timestamptz,
  counter_status text,
  days_until_due int,
  is_overdue boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      m.id,
      m.competitor_name,
      m.threat_level,
      m.counter_action,
      m.counter_owner_email,
      m.counter_due_at,
      m.counter_status,
      CASE WHEN m.counter_due_at IS NOT NULL
        THEN (m.counter_due_at::date - CURRENT_DATE)::int
        ELSE NULL END AS days_until_due,
      (m.counter_due_at IS NOT NULL
        AND m.counter_due_at < now()
        AND m.counter_status NOT IN ('done','dropped')) AS is_overdue
    FROM public.competitor_moves_r2413 m
    WHERE m.counter_action IS NOT NULL
      AND m.counter_status IN ('planned','in_progress')
    ORDER BY
      (m.counter_due_at IS NULL),
      m.counter_due_at ASC NULLS LAST,
      CASE m.threat_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.counter_actions_due_r2413() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.counter_actions_due_r2413() TO authenticated;

-- =========================================================================
-- RPC 6: weekly_digest_history_r2413 — past weekly digests
-- =========================================================================
CREATE OR REPLACE FUNCTION public.weekly_digest_history_r2413(p_limit int DEFAULT 26)
RETURNS TABLE (
  id uuid,
  week_start date,
  total_moves int,
  high_threat_count int,
  critical_threat_count int,
  top_competitor text,
  top_threat_level text,
  sent_at timestamptz,
  summary_md text,
  founder_takeaways_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      d.id,
      d.week_start,
      d.total_moves,
      d.high_threat_count,
      d.critical_threat_count,
      d.top_competitor,
      d.top_threat_level,
      d.sent_at,
      d.summary_md,
      d.founder_takeaways_md
    FROM public.competitor_weekly_digest_r2413 d
    ORDER BY d.week_start DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_digest_history_r2413(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_digest_history_r2413(int) TO authenticated;

-- =========================================================================
-- RPC 7: generate_weekly_digest_r2413 — preview next digest from this week
-- =========================================================================
CREATE OR REPLACE FUNCTION public.generate_weekly_digest_r2413(p_week_start date DEFAULT NULL)
RETURNS TABLE (
  week_start date,
  week_end date,
  total_moves bigint,
  high_threat_count bigint,
  critical_threat_count bigint,
  top_competitor text,
  top_threat_level text,
  with_counter_count bigint,
  done_counter_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_week_start date;
  v_week_end date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_week_start := COALESCE(p_week_start, date_trunc('week', CURRENT_DATE)::date);
  v_week_end := v_week_start + 6;

  RETURN QUERY
    WITH window_moves AS (
      SELECT * FROM public.competitor_moves_r2413 m
      WHERE m.observed_at::date BETWEEN v_week_start AND v_week_end
    ),
    top_comp AS (
      SELECT wm.competitor_name, COUNT(*) AS c
      FROM window_moves wm
      GROUP BY wm.competitor_name
      ORDER BY c DESC, wm.competitor_name
      LIMIT 1
    ),
    top_threat AS (
      SELECT wm.threat_level
      FROM window_moves wm
      ORDER BY
        CASE wm.threat_level
          WHEN 'critical' THEN 1
          WHEN 'high' THEN 2
          WHEN 'medium' THEN 3
          WHEN 'low' THEN 4
          ELSE 5
        END
      LIMIT 1
    )
    SELECT
      v_week_start,
      v_week_end,
      (SELECT COUNT(*) FROM window_moves)::bigint,
      (SELECT COUNT(*) FROM window_moves WHERE threat_level = 'high')::bigint,
      (SELECT COUNT(*) FROM window_moves WHERE threat_level = 'critical')::bigint,
      (SELECT competitor_name FROM top_comp),
      (SELECT threat_level FROM top_threat),
      (SELECT COUNT(*) FROM window_moves WHERE counter_action IS NOT NULL)::bigint,
      (SELECT COUNT(*) FROM window_moves WHERE counter_status = 'done')::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.generate_weekly_digest_r2413(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_weekly_digest_r2413(date) TO authenticated;

-- =========================================================================
-- Seed rows (pass all CHECK constraints)
-- =========================================================================
INSERT INTO public.competitor_moves_r2413
  (competitor_name, observed_at, move_kind, summary, source_url, threat_level, insight_category, counter_action, counter_owner_email, counter_due_at, counter_status, notes)
VALUES
  ('MedEquip Care', now() - interval '2 days', 'pricing',
    'Dropped AMC tier-2 pricing to Rs 8000/month, undercutting our Silver tier by 18%.',
    'https://example.com/medequip-pricing', 'high', 'commercial',
    'Spin up retention offer for hospitals on Silver renewing in next 60 days; cap discount at 12%.',
    'founder@equipseva.com', now() + interval '5 days', 'in_progress',
    'Two hospital chains have already mentioned MedEquip in renewal calls.');

INSERT INTO public.competitor_moves_r2413
  (competitor_name, observed_at, move_kind, summary, threat_level, insight_category, counter_action, counter_owner_email, counter_due_at, counter_status)
VALUES
  ('TechServe Bio', now() - interval '5 days', 'funding',
    'Raised Series A USD 6M led by Inflection; expected to expand into south India in Q3.',
    'medium', 'market',
    'Lock in 12-month AMC pre-renewals in Hyderabad before TechServe lands sales reps.',
    'founder@equipseva.com', now() + interval '14 days', 'planned');

INSERT INTO public.competitor_moves_r2413
  (competitor_name, observed_at, move_kind, summary, threat_level, insight_category, counter_action, counter_status, notes)
VALUES
  ('FixCo Healthcare', now() - interval '9 days', 'feature_launch',
    'Launched engineer mobile app with offline parts catalog and barcode scan.',
    'medium', 'product',
    'Ship our v0.5 offline catalog within next 3 weeks; compare features in sales decks.',
    'in_progress',
    'Their engineer NPS still trailing ours per Glassdoor.');

INSERT INTO public.competitor_moves_r2413
  (competitor_name, observed_at, move_kind, summary, threat_level, insight_category, notes)
VALUES
  ('LabFix Solutions', now() - interval '14 days', 'hire',
    'Hired ex-Siemens AMC head Rohit Menon as VP Sales.',
    'low', 'talent',
    'Watch for new sales playbook; no immediate action.');

INSERT INTO public.competitor_moves_r2413
  (competitor_name, observed_at, move_kind, summary, source_url, threat_level, insight_category, counter_action, counter_owner_email, counter_due_at, counter_status)
VALUES
  ('CareCo Medical', now() - interval '1 day', 'partnership',
    'Signed exclusive AMC tie-up with Apollo cluster (8 hospitals) for 3 years.',
    'https://example.com/careco-apollo', 'critical', 'commercial',
    'Reach out to Apollo procurement re: any non-AMC opportunity (parts/training); brief board.',
    'founder@equipseva.com', now() + interval '3 days', 'planned');

INSERT INTO public.competitor_weekly_digest_r2413
  (week_start, total_moves, high_threat_count, critical_threat_count, top_competitor, top_threat_level, summary_md, founder_takeaways_md, sent_at)
VALUES
  (date_trunc('week', CURRENT_DATE - interval '7 days')::date,
    4, 1, 0, 'MedEquip Care', 'high',
    '## Last week\n- 4 moves logged across 4 competitors\n- 1 high-threat pricing cut by MedEquip\n- Mostly commercial signals',
    '- Defensive pricing on Silver tier needs sign-off this week\n- TechServe funding = south-India sales pressure in 8-12 weeks',
    now() - interval '6 days');

INSERT INTO public.competitor_weekly_digest_r2413
  (week_start, total_moves, high_threat_count, critical_threat_count, top_competitor, top_threat_level, summary_md, founder_takeaways_md)
VALUES
  (date_trunc('week', CURRENT_DATE)::date,
    5, 1, 1, 'CareCo Medical', 'critical',
    '## This week (preview)\n- 5 moves logged\n- 1 critical: CareCo + Apollo exclusive\n- 1 high: MedEquip pricing drop',
    '- Apollo exclusive likely closes future AMC door; pivot to parts/training revenue\n- Need pricing response approved by Friday');

COMMENT ON TABLE public.competitor_moves_r2413 IS
  'r2413 competitor moves observed with threat level, insight category, and counter-action tracking.';
COMMENT ON TABLE public.competitor_weekly_digest_r2413 IS
  'r2413 weekly digest snapshots summarising competitor activity per week.';
COMMENT ON FUNCTION public.list_moves_r2413(int) IS
  'r2413 recent competitor moves with counter status and age.';
COMMENT ON FUNCTION public.threat_breakdown_r2413(int) IS
  'r2413 move counts grouped by threat level over rolling window.';
COMMENT ON FUNCTION public.by_competitor_r2413(int) IS
  'r2413 rollup per competitor: move count, top kind, open counters.';
COMMENT ON FUNCTION public.top_threats_r2413(int) IS
  'r2413 most-recent high/critical moves for founder triage.';
COMMENT ON FUNCTION public.counter_actions_due_r2413() IS
  'r2413 outstanding counter-actions ranked by due date and threat.';
COMMENT ON FUNCTION public.weekly_digest_history_r2413(int) IS
  'r2413 past weekly digest snapshots.';
COMMENT ON FUNCTION public.generate_weekly_digest_r2413(date) IS
  'r2413 live preview of this-week digest (or specified week start).';

