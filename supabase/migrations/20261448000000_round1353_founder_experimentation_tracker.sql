BEGIN;
-- round1353 — Founder experimentation tracker
-- A/B test + KPI lift ledger. All RPCs founder-gated. STABLE SECURITY DEFINER plpgsql.

-- 1. Experiments ledger
CREATE TABLE IF NOT EXISTS public.founder_experiments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exp_label text UNIQUE NOT NULL,
  hypothesis text NOT NULL,
  primary_kpi text NOT NULL,
  secondary_kpis text[],
  surface text CHECK (surface IN (
    'android_engineer','android_hospital','founder_console','public_share',
    'cron_logic','onboarding_flow','payouts','amc_lifecycle','other'
  )),
  variant_kind text DEFAULT 'a_b' CHECK (variant_kind IN (
    'a_b','multi_variant','feature_flag','holdout','staged_rollout'
  )),
  status text DEFAULT 'designed' CHECK (status IN (
    'designed','running','paused','analyzing','shipped','killed'
  )),
  expected_lift_pct numeric,
  actual_lift_pct numeric,
  sample_size_target int,
  sample_size_actual int,
  started_at timestamptz,
  ended_at timestamptz,
  decision_notes text,
  decision_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_experiments_status_idx
  ON public.founder_experiments (status, created_at DESC);
CREATE INDEX IF NOT EXISTS founder_experiments_surface_idx
  ON public.founder_experiments (surface);
CREATE INDEX IF NOT EXISTS founder_experiments_running_idx
  ON public.founder_experiments (started_at)
  WHERE status = 'running';

ALTER TABLE public.founder_experiments ENABLE ROW LEVEL SECURITY;

-- 2. Summary RPC — 14 KPIs
DROP FUNCTION IF EXISTS public.founder_experimentation_summary();
CREATE OR REPLACE FUNCTION public.founder_experimentation_summary()
RETURNS TABLE (
  total_experiments       bigint,
  designed_count          bigint,
  running_count           bigint,
  paused_count            bigint,
  shipped_count           bigint,
  killed_count            bigint,
  ship_rate_pct           numeric,
  avg_actual_lift_pct     numeric,
  avg_expected_lift_pct   numeric,
  lift_realization_pct    numeric,
  running_avg_age_days    numeric,
  oldest_running_age_days int,
  last_decision_at        timestamptz,
  top_surface_by_volume   text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_decided bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*) INTO total_experiments FROM public.founder_experiments;

  SELECT COUNT(*) FILTER (WHERE status = 'designed'),
         COUNT(*) FILTER (WHERE status = 'running'),
         COUNT(*) FILTER (WHERE status = 'paused'),
         COUNT(*) FILTER (WHERE status = 'shipped'),
         COUNT(*) FILTER (WHERE status = 'killed')
    INTO designed_count, running_count, paused_count, shipped_count, killed_count
    FROM public.founder_experiments;

  v_decided := shipped_count + killed_count;
  ship_rate_pct := CASE WHEN v_decided > 0
                        THEN round((shipped_count::numeric * 100.0) / v_decided, 1)
                        ELSE NULL END;

  SELECT round(AVG(actual_lift_pct)::numeric, 2) INTO avg_actual_lift_pct
    FROM public.founder_experiments
   WHERE actual_lift_pct IS NOT NULL;

  SELECT round(AVG(expected_lift_pct)::numeric, 2) INTO avg_expected_lift_pct
    FROM public.founder_experiments
   WHERE expected_lift_pct IS NOT NULL;

  lift_realization_pct := CASE
    WHEN avg_expected_lift_pct IS NOT NULL
     AND avg_expected_lift_pct <> 0
     AND avg_actual_lift_pct IS NOT NULL
    THEN round((avg_actual_lift_pct / avg_expected_lift_pct) * 100.0, 1)
    ELSE NULL
  END;

  SELECT round(AVG(EXTRACT(EPOCH FROM (now() - started_at)) / 86400.0)::numeric, 1)
    INTO running_avg_age_days
    FROM public.founder_experiments
   WHERE status = 'running' AND started_at IS NOT NULL;

  SELECT GREATEST(EXTRACT(DAY FROM (now() - MIN(started_at)))::int, 0)
    INTO oldest_running_age_days
    FROM public.founder_experiments
   WHERE status = 'running' AND started_at IS NOT NULL;

  SELECT MAX(decision_at) INTO last_decision_at
    FROM public.founder_experiments
   WHERE decision_at IS NOT NULL;

  SELECT surface INTO top_surface_by_volume
    FROM public.founder_experiments
   WHERE surface IS NOT NULL
   GROUP BY surface
   ORDER BY COUNT(*) DESC, surface ASC
   LIMIT 1;

  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_experimentation_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_experimentation_summary() TO authenticated;

-- 3. Recent experiments RPC
DROP FUNCTION IF EXISTS public.founder_experiments_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_experiments_recent(
  p_status text DEFAULT NULL,
  p_limit  int  DEFAULT 50
)
RETURNS TABLE (
  id                  uuid,
  exp_label           text,
  hypothesis          text,
  primary_kpi         text,
  surface             text,
  variant_kind        text,
  status              text,
  expected_lift_pct   numeric,
  actual_lift_pct     numeric,
  lift_realization_pct numeric,
  sample_size_target  int,
  sample_size_actual  int,
  sample_size_pct     numeric,
  started_at          timestamptz,
  ended_at            timestamptz,
  decision_at         timestamptz,
  age_days            int,
  created_at          timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.exp_label,
    e.hypothesis,
    e.primary_kpi,
    e.surface,
    e.variant_kind,
    e.status,
    e.expected_lift_pct,
    e.actual_lift_pct,
    CASE
      WHEN e.expected_lift_pct IS NOT NULL
       AND e.expected_lift_pct <> 0
       AND e.actual_lift_pct  IS NOT NULL
      THEN round((e.actual_lift_pct / e.expected_lift_pct) * 100.0, 1)
      ELSE NULL
    END,
    e.sample_size_target,
    e.sample_size_actual,
    CASE
      WHEN e.sample_size_target IS NOT NULL
       AND e.sample_size_target > 0
       AND e.sample_size_actual IS NOT NULL
      THEN round((e.sample_size_actual::numeric * 100.0) / e.sample_size_target, 1)
      ELSE NULL
    END,
    e.started_at,
    e.ended_at,
    e.decision_at,
    GREATEST(EXTRACT(DAY FROM (now() - e.created_at))::int, 0),
    e.created_at
  FROM public.founder_experiments e
  WHERE (p_status IS NULL OR e.status = p_status)
  ORDER BY e.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_experiments_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_experiments_recent(text, int) TO authenticated;

-- 4. Register experiment
DROP FUNCTION IF EXISTS public.log_founder_experiment_register(text, text, text, text[], text, text, numeric, int);
CREATE OR REPLACE FUNCTION public.log_founder_experiment_register(
  p_exp_label          text,
  p_hypothesis         text,
  p_primary_kpi        text,
  p_secondary_kpis     text[]   DEFAULT NULL,
  p_surface            text     DEFAULT 'other',
  p_variant_kind       text     DEFAULT 'a_b',
  p_expected_lift_pct  numeric  DEFAULT NULL,
  p_sample_size_target int      DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_experiments (
    exp_label, hypothesis, primary_kpi, secondary_kpis,
    surface, variant_kind, expected_lift_pct, sample_size_target
  ) VALUES (
    p_exp_label, p_hypothesis, p_primary_kpi, p_secondary_kpis,
    COALESCE(p_surface, 'other'), COALESCE(p_variant_kind, 'a_b'),
    p_expected_lift_pct, p_sample_size_target
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_experiment_register(text, text, text, text[], text, text, numeric, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_experiment_register(text, text, text, text[], text, text, numeric, int) TO authenticated;

-- 5. Start experiment
DROP FUNCTION IF EXISTS public.log_founder_experiment_start(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_experiment_start(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_experiments
     SET status     = 'running',
         started_at = COALESCE(started_at, now()),
         updated_at = now()
   WHERE id = p_id
     AND status IN ('designed','paused');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_experiment_start(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_experiment_start(uuid) TO authenticated;

-- 6. Decide (ship / kill / pause / analyze)
DROP FUNCTION IF EXISTS public.log_founder_experiment_decide(uuid, text, numeric, int, text);
CREATE OR REPLACE FUNCTION public.log_founder_experiment_decide(
  p_id                 uuid,
  p_new_status         text,
  p_actual_lift_pct    numeric,
  p_sample_size_actual int,
  p_decision_notes     text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_new_status NOT IN ('paused','analyzing','shipped','killed') THEN
    RAISE EXCEPTION 'invalid decision status: %', p_new_status USING ERRCODE = '22023';
  END IF;

  UPDATE public.founder_experiments
     SET status             = p_new_status,
         actual_lift_pct    = COALESCE(p_actual_lift_pct, actual_lift_pct),
         sample_size_actual = COALESCE(p_sample_size_actual, sample_size_actual),
         decision_notes     = COALESCE(p_decision_notes, decision_notes),
         decision_at        = now(),
         ended_at           = CASE WHEN p_new_status IN ('shipped','killed')
                                   THEN COALESCE(ended_at, now())
                                   ELSE ended_at END,
         updated_at         = now()
   WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_experiment_decide(uuid, text, numeric, int, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_experiment_decide(uuid, text, numeric, int, text) TO authenticated;

COMMIT;