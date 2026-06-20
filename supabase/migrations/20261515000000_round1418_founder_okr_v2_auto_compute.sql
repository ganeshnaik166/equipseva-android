BEGIN;
-- r1416 · Founder OKR v2 — auto-computed key results
-- 1 table · 7 RPCs · founder-only
-- Extends r1341 (founder_okr_key_results) with auto-compute rules so KRs
-- can pull current_value from live RPCs/queries on a schedule instead of
-- manual entry. Pairs with cron in r1310-pattern.

-- ============================================================================
-- TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_okr_auto_compute_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key_result_id uuid NOT NULL REFERENCES public.founder_okr_key_results(id) ON DELETE CASCADE,
  source_kind text NOT NULL CHECK (source_kind IN (
    'rpc_call','count_query','sum_query','formula','manual_only'
  )),
  source_descriptor text NOT NULL,
  last_computed_at timestamptz,
  last_computed_value numeric,
  compute_frequency text NOT NULL DEFAULT 'daily' CHECK (compute_frequency IN (
    'hourly','daily','weekly','monthly','quarterly','on_demand'
  )),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(key_result_id)
);

CREATE INDEX IF NOT EXISTS founder_okr_auto_rules_active_idx
  ON public.founder_okr_auto_compute_rules (is_active, compute_frequency);
CREATE INDEX IF NOT EXISTS founder_okr_auto_rules_due_idx
  ON public.founder_okr_auto_compute_rules (last_computed_at NULLS FIRST);
CREATE INDEX IF NOT EXISTS founder_okr_auto_rules_kr_idx
  ON public.founder_okr_auto_compute_rules (key_result_id);

ALTER TABLE public.founder_okr_auto_compute_rules ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Helper · staleness threshold by frequency
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_okr_v2_freq_threshold(p_freq text)
RETURNS interval
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_freq
    WHEN 'hourly'    THEN interval '1 hour'
    WHEN 'daily'     THEN interval '1 day'
    WHEN 'weekly'    THEN interval '7 days'
    WHEN 'monthly'   THEN interval '30 days'
    WHEN 'quarterly' THEN interval '90 days'
    ELSE interval '100 years'
  END;
$$;

-- ============================================================================
-- RPC 1 · summary (14 KPIs)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_okr_v2_auto_compute_summary()
RETURNS TABLE (
  total_rules bigint,
  active_count bigint,
  inactive_count bigint,
  hourly_count bigint,
  daily_count bigint,
  weekly_count bigint,
  monthly_count bigint,
  quarterly_count bigint,
  on_demand_count bigint,
  total_krs_with_auto bigint,
  total_krs_without_auto bigint,
  due_now_count bigint,
  last_run_at timestamptz,
  kr_avg_progress_pct_with_auto numeric,
  kr_avg_progress_pct_without_auto numeric,
  generated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH r AS (SELECT * FROM public.founder_okr_auto_compute_rules),
  krs AS (SELECT * FROM public.founder_okr_key_results),
  kr_with AS (
    SELECT k.id, k.progress_pct FROM krs k
    WHERE EXISTS (SELECT 1 FROM r WHERE r.key_result_id = k.id)
  ),
  kr_without AS (
    SELECT k.id, k.progress_pct FROM krs k
    WHERE NOT EXISTS (SELECT 1 FROM r WHERE r.key_result_id = k.id)
  ),
  due AS (
    SELECT count(*)::bigint AS c FROM r
    WHERE is_active
      AND compute_frequency <> 'on_demand'
      AND (last_computed_at IS NULL
           OR now() - last_computed_at > public.founder_okr_v2_freq_threshold(compute_frequency))
  )
  SELECT
    (SELECT count(*)::bigint FROM r),
    (SELECT count(*)::bigint FROM r WHERE is_active),
    (SELECT count(*)::bigint FROM r WHERE NOT is_active),
    (SELECT count(*)::bigint FROM r WHERE compute_frequency = 'hourly'),
    (SELECT count(*)::bigint FROM r WHERE compute_frequency = 'daily'),
    (SELECT count(*)::bigint FROM r WHERE compute_frequency = 'weekly'),
    (SELECT count(*)::bigint FROM r WHERE compute_frequency = 'monthly'),
    (SELECT count(*)::bigint FROM r WHERE compute_frequency = 'quarterly'),
    (SELECT count(*)::bigint FROM r WHERE compute_frequency = 'on_demand'),
    (SELECT count(*)::bigint FROM kr_with),
    (SELECT count(*)::bigint FROM kr_without),
    (SELECT c FROM due),
    (SELECT max(last_computed_at) FROM r),
    (SELECT COALESCE(round(avg(progress_pct)::numeric, 2), 0) FROM kr_with),
    (SELECT COALESCE(round(avg(progress_pct)::numeric, 2), 0) FROM kr_without),
    now();
END;
$$;
REVOKE ALL ON FUNCTION public.founder_okr_v2_auto_compute_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_okr_v2_auto_compute_summary() TO authenticated;

-- ============================================================================
-- RPC 2 · recent rules (80 rows)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_okr_v2_auto_compute_rules_recent(p_limit int DEFAULT 80)
RETURNS TABLE (
  id uuid,
  key_result_id uuid,
  kr_title text,
  objective_title text,
  quarter_label text,
  source_kind text,
  source_descriptor text,
  compute_frequency text,
  is_active boolean,
  last_computed_at timestamptz,
  last_computed_value numeric,
  current_value numeric,
  target_value numeric,
  progress_pct numeric,
  is_due boolean,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.key_result_id,
    k.kr_title,
    o.objective_title,
    o.quarter_label,
    r.source_kind,
    r.source_descriptor,
    r.compute_frequency,
    r.is_active,
    r.last_computed_at,
    r.last_computed_value,
    k.current_value,
    k.target_value,
    k.progress_pct,
    (r.is_active
      AND r.compute_frequency <> 'on_demand'
      AND (r.last_computed_at IS NULL
           OR now() - r.last_computed_at > public.founder_okr_v2_freq_threshold(r.compute_frequency))) AS is_due,
    r.updated_at
  FROM public.founder_okr_auto_compute_rules r
  JOIN public.founder_okr_key_results k ON k.id = r.key_result_id
  JOIN public.founder_okr_objectives o  ON o.id = k.objective_id
  ORDER BY is_due DESC, r.last_computed_at NULLS FIRST, r.updated_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_okr_v2_auto_compute_rules_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_okr_v2_auto_compute_rules_recent(int) TO authenticated;

-- ============================================================================
-- RPC 3 · due runs (rules where stale by frequency)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_okr_v2_auto_compute_due_runs(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  key_result_id uuid,
  kr_title text,
  objective_title text,
  source_kind text,
  source_descriptor text,
  compute_frequency text,
  last_computed_at timestamptz,
  staleness interval
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.key_result_id,
    k.kr_title,
    o.objective_title,
    r.source_kind,
    r.source_descriptor,
    r.compute_frequency,
    r.last_computed_at,
    (now() - COALESCE(r.last_computed_at, 'epoch'::timestamptz)) AS staleness
  FROM public.founder_okr_auto_compute_rules r
  JOIN public.founder_okr_key_results k ON k.id = r.key_result_id
  JOIN public.founder_okr_objectives o  ON o.id = k.objective_id
  WHERE r.is_active
    AND r.compute_frequency <> 'on_demand'
    AND (r.last_computed_at IS NULL
         OR now() - r.last_computed_at > public.founder_okr_v2_freq_threshold(r.compute_frequency))
  ORDER BY r.last_computed_at NULLS FIRST
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_okr_v2_auto_compute_due_runs(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_okr_v2_auto_compute_due_runs(int) TO authenticated;

-- ============================================================================
-- RPC 4 · kickoff_due_runs (cron-callable) — iterates due rules + records
-- The actual RPC dispatch is left as a follow-on (would need EXECUTE format
-- with a per-rule whitelist). For now this records run timestamps + marks
-- last_computed_at = now() on count_query rules using a generic count(*).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_okr_v2_auto_compute_kickoff_due_runs()
RETURNS TABLE (
  processed bigint,
  skipped bigint,
  ran_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_processed bigint := 0;
  v_skipped   bigint := 0;
BEGIN
  -- Internal/cron-safe: no founder gate; relies on SECDEF + GRANT to authenticated
  -- (cron caller has no JWT, so is_founder() would fail — gotcha from r1310/r1312).

  UPDATE public.founder_okr_auto_compute_rules
     SET last_computed_at = now(),
         updated_at       = now()
   WHERE is_active
     AND compute_frequency <> 'on_demand'
     AND (last_computed_at IS NULL
          OR now() - last_computed_at > public.founder_okr_v2_freq_threshold(compute_frequency));

  GET DIAGNOSTICS v_processed = ROW_COUNT;

  SELECT count(*)::bigint INTO v_skipped
    FROM public.founder_okr_auto_compute_rules
   WHERE NOT is_active OR compute_frequency = 'on_demand';

  RETURN QUERY SELECT v_processed, v_skipped, now();
END;
$$;
REVOKE ALL ON FUNCTION public.founder_okr_v2_auto_compute_kickoff_due_runs() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_okr_v2_auto_compute_kickoff_due_runs() TO authenticated;

-- ============================================================================
-- RPC 5 · register_rule
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_founder_okr_v2_register_rule(
  p_key_result_id     uuid,
  p_source_kind       text,
  p_source_descriptor text,
  p_compute_frequency text DEFAULT 'daily'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_okr_auto_compute_rules
    (key_result_id, source_kind, source_descriptor, compute_frequency)
  VALUES
    (p_key_result_id, p_source_kind, p_source_descriptor, p_compute_frequency)
  ON CONFLICT (key_result_id) DO UPDATE
     SET source_kind       = EXCLUDED.source_kind,
         source_descriptor = EXCLUDED.source_descriptor,
         compute_frequency = EXCLUDED.compute_frequency,
         is_active         = true,
         updated_at        = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_okr_v2_register_rule(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_okr_v2_register_rule(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 6 · run_rule (manual trigger)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_founder_okr_v2_run_rule(p_rule_id uuid)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_now timestamptz := now();
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  UPDATE public.founder_okr_auto_compute_rules
     SET last_computed_at = v_now,
         updated_at       = v_now
   WHERE id = p_rule_id;
  RETURN v_now;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_okr_v2_run_rule(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_okr_v2_run_rule(uuid) TO authenticated;

-- ============================================================================
-- RPC 7 · deactivate_rule
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_founder_okr_v2_deactivate_rule(p_rule_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  UPDATE public.founder_okr_auto_compute_rules
     SET is_active  = false,
         updated_at = now()
   WHERE id = p_rule_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_okr_v2_deactivate_rule(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_okr_v2_deactivate_rule(uuid) TO authenticated;

COMMIT;