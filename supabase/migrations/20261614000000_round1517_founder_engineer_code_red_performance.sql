BEGIN;

-- ============================================================================
-- r1517 — Founder Engineer Code Red Response Performance
-- ============================================================================
-- Per-engineer Code Red emergency response metrics: first-response SLA,
-- on-site SLA, resolve-time SLA, hero board + dropout board.
-- ============================================================================

-- Tables ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.code_red_engineer_response_metrics_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  code_red_request_id uuid NOT NULL,
  acknowledged_at timestamptz,
  first_response_at timestamptz,
  on_site_at timestamptz,
  resolved_at timestamptz,
  first_response_seconds numeric,
  on_site_seconds numeric,
  resolve_seconds numeric,
  hit_first_response_sla boolean,
  hit_on_site_sla boolean,
  hit_resolve_sla boolean,
  dropped boolean NOT NULL DEFAULT false,
  drop_reason text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crerm_v2_engineer ON public.code_red_engineer_response_metrics_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_crerm_v2_recorded ON public.code_red_engineer_response_metrics_v2(recorded_at DESC);

ALTER TABLE public.code_red_engineer_response_metrics_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crerm_v2_founder_only ON public.code_red_engineer_response_metrics_v2;
CREATE POLICY crerm_v2_founder_only ON public.code_red_engineer_response_metrics_v2
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.code_red_engineer_sla_targets_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  severity text NOT NULL,
  first_response_target_seconds integer NOT NULL DEFAULT 300,
  on_site_target_seconds integer NOT NULL DEFAULT 7200,
  resolve_target_seconds integer NOT NULL DEFAULT 21600,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (severity)
);

ALTER TABLE public.code_red_engineer_sla_targets_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crest_v2_founder_only ON public.code_red_engineer_sla_targets_v2;
CREATE POLICY crest_v2_founder_only ON public.code_red_engineer_sla_targets_v2
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Helpers --------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.log_founder_code_red_engineer_metric_recorded(
  p_engineer_id uuid, p_first_response_seconds numeric, p_hit_sla boolean
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'code_red_engineer_metric_recorded',
          jsonb_build_object('engineer_id', p_engineer_id, 'first_response_seconds', p_first_response_seconds, 'hit_sla', p_hit_sla));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_code_red_sla_target_updated(
  p_severity text, p_first_response integer, p_on_site integer, p_resolve integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'code_red_sla_target_updated',
          jsonb_build_object('severity', p_severity, 'first_response', p_first_response, 'on_site', p_on_site, 'resolve', p_resolve));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_code_red_dropout_flagged(
  p_engineer_id uuid, p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'code_red_dropout_flagged',
          jsonb_build_object('engineer_id', p_engineer_id, 'reason', p_reason));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_code_red_hero_awarded(
  p_engineer_id uuid, p_streak integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'code_red_hero_awarded',
          jsonb_build_object('engineer_id', p_engineer_id, 'streak', p_streak));
END $$;

-- RPCs (read, STABLE) --------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_code_red_response_overview()
RETURNS TABLE(
  total_metrics bigint,
  engineers_with_metrics bigint,
  median_first_response_seconds numeric,
  median_on_site_seconds numeric,
  median_resolve_seconds numeric,
  first_response_sla_pct numeric,
  on_site_sla_pct numeric,
  resolve_sla_pct numeric,
  dropout_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(DISTINCT engineer_id)::bigint,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY first_response_seconds)::numeric,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY on_site_seconds)::numeric,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolve_seconds)::numeric,
    (100.0 * SUM(CASE WHEN hit_first_response_sla THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0))::numeric,
    (100.0 * SUM(CASE WHEN hit_on_site_sla THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0))::numeric,
    (100.0 * SUM(CASE WHEN hit_resolve_sla THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0))::numeric,
    SUM(CASE WHEN dropped THEN 1 ELSE 0 END)::bigint
  FROM code_red_engineer_response_metrics_v2;
END $$;

CREATE OR REPLACE FUNCTION public.founder_code_red_hero_board(p_limit integer DEFAULT 20)
RETURNS TABLE(
  id uuid,
  engineer_name text,
  total_responses bigint,
  median_first_response_seconds numeric,
  sla_hit_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, p.email, 'engineer')::text,
    COUNT(m.*)::bigint,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.first_response_seconds)::numeric,
    (100.0 * SUM(CASE WHEN m.hit_first_response_sla THEN 1 ELSE 0 END) / NULLIF(COUNT(m.*),0))::numeric
  FROM code_red_engineer_response_metrics_v2 m
  JOIN engineers e ON e.id = m.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE NOT m.dropped
  GROUP BY e.id, p.full_name, p.email
  HAVING COUNT(m.*) >= 3
  ORDER BY sla_hit_pct DESC NULLS LAST, median_first_response_seconds ASC NULLS LAST
  LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.founder_code_red_dropout_board(p_limit integer DEFAULT 20)
RETURNS TABLE(
  id uuid,
  engineer_name text,
  dropout_count bigint,
  last_drop_at timestamptz,
  last_reason text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, p.email, 'engineer')::text,
    COUNT(*)::bigint,
    MAX(m.recorded_at),
    (ARRAY_AGG(m.drop_reason ORDER BY m.recorded_at DESC))[1]
  FROM code_red_engineer_response_metrics_v2 m
  JOIN engineers e ON e.id = m.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE m.dropped
  GROUP BY e.id, p.full_name, p.email
  ORDER BY dropout_count DESC, last_drop_at DESC
  LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.founder_code_red_per_engineer_breakdown(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_name text,
  cached_highest_tier text,
  total_responses bigint,
  median_first_response_seconds numeric,
  median_on_site_seconds numeric,
  median_resolve_seconds numeric,
  dropout_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, p.email, 'engineer')::text,
    e.cached_highest_tier::text,
    COUNT(m.*)::bigint,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.first_response_seconds)::numeric,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.on_site_seconds)::numeric,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.resolve_seconds)::numeric,
    SUM(CASE WHEN m.dropped THEN 1 ELSE 0 END)::bigint
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN code_red_engineer_response_metrics_v2 m ON m.engineer_id = e.id
  GROUP BY e.id, p.full_name, p.email, e.cached_highest_tier
  HAVING COUNT(m.*) > 0
  ORDER BY total_responses DESC
  LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.founder_code_red_sla_targets()
RETURNS TABLE(
  id uuid,
  severity text,
  first_response_target_seconds integer,
  on_site_target_seconds integer,
  resolve_target_seconds integer,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.severity, t.first_response_target_seconds, t.on_site_target_seconds, t.resolve_target_seconds, t.updated_at
  FROM code_red_engineer_sla_targets_v2 t
  ORDER BY t.severity;
END $$;

CREATE OR REPLACE FUNCTION public.founder_code_red_recent_metrics(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_name text,
  first_response_seconds numeric,
  on_site_seconds numeric,
  resolve_seconds numeric,
  hit_first_response_sla boolean,
  dropped boolean,
  recorded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id,
         COALESCE(p.full_name, p.email, 'engineer')::text,
         m.first_response_seconds, m.on_site_seconds, m.resolve_seconds,
         m.hit_first_response_sla, m.dropped, m.recorded_at
  FROM code_red_engineer_response_metrics_v2 m
  JOIN engineers e ON e.id = m.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY m.recorded_at DESC
  LIMIT p_limit;
END $$;

-- RPC (write, VOLATILE) ------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_code_red_upsert_sla_target(
  p_severity text,
  p_first_response integer,
  p_on_site integer,
  p_resolve integer
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO code_red_engineer_sla_targets_v2(severity, first_response_target_seconds, on_site_target_seconds, resolve_target_seconds, updated_at)
  VALUES (p_severity, p_first_response, p_on_site, p_resolve, now())
  ON CONFLICT (severity) DO UPDATE
    SET first_response_target_seconds = EXCLUDED.first_response_target_seconds,
        on_site_target_seconds = EXCLUDED.on_site_target_seconds,
        resolve_target_seconds = EXCLUDED.resolve_target_seconds,
        updated_at = now()
  RETURNING id INTO v_id;

  PERFORM log_founder_code_red_sla_target_updated(p_severity, p_first_response, p_on_site, p_resolve);
  RETURN v_id;
END $$;

-- Grants ---------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.founder_code_red_response_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_code_red_response_overview() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_code_red_hero_board(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_code_red_hero_board(integer) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_code_red_dropout_board(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_code_red_dropout_board(integer) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_code_red_per_engineer_breakdown(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_code_red_per_engineer_breakdown(integer) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_code_red_sla_targets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_code_red_sla_targets() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_code_red_recent_metrics(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_code_red_recent_metrics(integer) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_code_red_upsert_sla_target(text, integer, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_code_red_upsert_sla_target(text, integer, integer, integer) TO authenticated;

COMMIT;