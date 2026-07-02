BEGIN;
-- round1412: Engineer Mobile App v0.6 — field service module registry
-- 2 tables (engineer_field_service_modules + engineer_field_service_module_runs)
-- 7 RPCs (founder summary/listings + engineer auth start/complete/list + audit log)



-- =========================================================================
-- TABLE 1: engineer_field_service_modules — catalog of v0.6 field modules
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_field_service_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_label text NOT NULL UNIQUE,
  module_kind text NOT NULL CHECK (module_kind IN (
    'safety_check','equipment_inspection','calibration','spare_part_swap',
    'firmware_update','user_training','documentation','code_red_dispatch',
    'warranty_claim','custom'
  )),
  required_steps_count integer NOT NULL DEFAULT 1 CHECK (required_steps_count >= 1),
  is_active boolean NOT NULL DEFAULT true,
  mobile_min_version text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efsm_active ON public.engineer_field_service_modules(is_active);
CREATE INDEX IF NOT EXISTS idx_efsm_kind ON public.engineer_field_service_modules(module_kind);

ALTER TABLE public.engineer_field_service_modules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efsm_founder_all ON public.engineer_field_service_modules;
CREATE POLICY efsm_founder_all ON public.engineer_field_service_modules
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS efsm_engineer_read_active ON public.engineer_field_service_modules;
CREATE POLICY efsm_engineer_read_active ON public.engineer_field_service_modules
  FOR SELECT TO authenticated USING (is_active = true);

-- =========================================================================
-- TABLE 2: engineer_field_service_module_runs — per-engineer execution log
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_field_service_module_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  module_id uuid NOT NULL REFERENCES public.engineer_field_service_modules(id) ON DELETE RESTRICT,
  repair_job_id uuid,
  status text NOT NULL DEFAULT 'started' CHECK (status IN (
    'started','in_progress','completed','aborted','synced'
  )),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  steps_completed integer NOT NULL DEFAULT 0 CHECK (steps_completed >= 0),
  signature_uri text,
  geo_lat numeric(9,6),
  geo_lng numeric(9,6),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efsmr_engineer ON public.engineer_field_service_module_runs(engineer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_efsmr_module ON public.engineer_field_service_module_runs(module_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_efsmr_status ON public.engineer_field_service_module_runs(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_efsmr_job ON public.engineer_field_service_module_runs(repair_job_id);

ALTER TABLE public.engineer_field_service_module_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efsmr_founder_all ON public.engineer_field_service_module_runs;
CREATE POLICY efsmr_founder_all ON public.engineer_field_service_module_runs
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS efsmr_engineer_own ON public.engineer_field_service_module_runs;
CREATE POLICY efsmr_engineer_own ON public.engineer_field_service_module_runs
  FOR SELECT TO authenticated USING (engineer_user_id = auth.uid());

-- =========================================================================
-- RPC 1: founder_field_service_modules_summary — 14 KPI cards
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_field_service_modules_summary();
CREATE OR REPLACE FUNCTION public.founder_field_service_modules_summary()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v jsonb;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT jsonb_build_object(
    'modules_total',          (SELECT count(*) FROM engineer_field_service_modules),
    'modules_active',         (SELECT count(*) FROM engineer_field_service_modules WHERE is_active),
    'modules_inactive',       (SELECT count(*) FROM engineer_field_service_modules WHERE NOT is_active),
    'module_kinds_distinct',  (SELECT count(DISTINCT module_kind) FROM engineer_field_service_modules),
    'runs_total',             (SELECT count(*) FROM engineer_field_service_module_runs),
    'runs_started',           (SELECT count(*) FROM engineer_field_service_module_runs WHERE status='started'),
    'runs_in_progress',       (SELECT count(*) FROM engineer_field_service_module_runs WHERE status='in_progress'),
    'runs_completed',         (SELECT count(*) FROM engineer_field_service_module_runs WHERE status='completed'),
    'runs_aborted',           (SELECT count(*) FROM engineer_field_service_module_runs WHERE status='aborted'),
    'runs_synced',            (SELECT count(*) FROM engineer_field_service_module_runs WHERE status='synced'),
    'runs_24h',               (SELECT count(*) FROM engineer_field_service_module_runs WHERE created_at >= now() - interval '24 hours'),
    'runs_7d',                (SELECT count(*) FROM engineer_field_service_module_runs WHERE created_at >= now() - interval '7 days'),
    'engineers_active_30d',   (SELECT count(DISTINCT engineer_user_id) FROM engineer_field_service_module_runs WHERE created_at >= now() - interval '30 days'),
    'completion_rate_pct',    (
      SELECT CASE WHEN count(*) = 0 THEN 0
                  ELSE round(100.0 * count(*) FILTER (WHERE status IN ('completed','synced'))::numeric / count(*)::numeric, 1)
             END
      FROM engineer_field_service_module_runs
    )
  ) INTO v;
  RETURN v;
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_field_service_modules_summary() TO authenticated;

-- =========================================================================
-- RPC 2: founder_field_service_modules_recent — module catalog listing
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_field_service_modules_recent(integer);
CREATE OR REPLACE FUNCTION public.founder_field_service_modules_recent(p_limit integer DEFAULT 60)
RETURNS TABLE (
  id uuid,
  module_label text,
  module_kind text,
  required_steps_count integer,
  is_active boolean,
  mobile_min_version text,
  runs_total bigint,
  runs_completed bigint,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT m.id, m.module_label, m.module_kind, m.required_steps_count,
         m.is_active, m.mobile_min_version,
         COALESCE(r.runs_total, 0) AS runs_total,
         COALESCE(r.runs_completed, 0) AS runs_completed,
         m.created_at
  FROM engineer_field_service_modules m
  LEFT JOIN LATERAL (
    SELECT count(*) AS runs_total,
           count(*) FILTER (WHERE status IN ('completed','synced')) AS runs_completed
    FROM engineer_field_service_module_runs r
    WHERE r.module_id = m.id
  ) r ON true
  ORDER BY m.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_field_service_modules_recent(integer) TO authenticated;

-- =========================================================================
-- RPC 3: founder_field_service_runs_recent — recent run ledger
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_field_service_runs_recent(integer);
CREATE OR REPLACE FUNCTION public.founder_field_service_runs_recent(p_limit integer DEFAULT 80)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  module_label text,
  module_kind text,
  status text,
  steps_completed integer,
  required_steps_count integer,
  repair_job_id uuid,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, m.module_label, m.module_kind,
         r.status, r.steps_completed, m.required_steps_count,
         r.repair_job_id, r.started_at, r.completed_at, r.created_at
  FROM engineer_field_service_module_runs r
  JOIN engineer_field_service_modules m ON m.id = r.module_id
  ORDER BY r.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_field_service_runs_recent(integer) TO authenticated;

-- =========================================================================
-- RPC 4: engineer_field_service_my_runs — engineer's own runs
-- =========================================================================
DROP FUNCTION IF EXISTS public.engineer_field_service_my_runs(integer);
CREATE OR REPLACE FUNCTION public.engineer_field_service_my_runs(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  module_label text,
  module_kind text,
  status text,
  steps_completed integer,
  required_steps_count integer,
  started_at timestamptz,
  completed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT r.id, m.module_label, m.module_kind, r.status,
         r.steps_completed, m.required_steps_count,
         r.started_at, r.completed_at
  FROM engineer_field_service_module_runs r
  JOIN engineer_field_service_modules m ON m.id = r.module_id
  WHERE r.engineer_user_id = auth.uid()
  ORDER BY r.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.engineer_field_service_my_runs(integer) TO authenticated;

-- =========================================================================
-- RPC 5: engineer_field_service_start_module_run — start new run
-- =========================================================================
DROP FUNCTION IF EXISTS public.engineer_field_service_start_module_run(uuid, uuid, numeric, numeric);
CREATE OR REPLACE FUNCTION public.engineer_field_service_start_module_run(
  p_module_id uuid,
  p_repair_job_id uuid DEFAULT NULL,
  p_geo_lat numeric DEFAULT NULL,
  p_geo_lng numeric DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_active boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;

  SELECT is_active INTO v_active FROM engineer_field_service_modules WHERE id = p_module_id;
  IF v_active IS NULL THEN RAISE EXCEPTION 'module not found' USING ERRCODE='P0002'; END IF;
  IF NOT v_active THEN RAISE EXCEPTION 'module inactive' USING ERRCODE='22023'; END IF;

  INSERT INTO engineer_field_service_module_runs
    (engineer_user_id, module_id, repair_job_id, status, geo_lat, geo_lng)
  VALUES (auth.uid(), p_module_id, p_repair_job_id, 'started', p_geo_lat, p_geo_lng)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.engineer_field_service_start_module_run(uuid, uuid, numeric, numeric) TO authenticated;

-- =========================================================================
-- RPC 6: engineer_field_service_complete_module_run — mark complete
-- =========================================================================
DROP FUNCTION IF EXISTS public.engineer_field_service_complete_module_run(uuid, integer, text);
CREATE OR REPLACE FUNCTION public.engineer_field_service_complete_module_run(
  p_run_id uuid,
  p_steps_completed integer,
  p_signature_uri text DEFAULT NULL
) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;

  SELECT engineer_user_id INTO v_owner FROM engineer_field_service_module_runs WHERE id = p_run_id;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'run not found' USING ERRCODE='P0002'; END IF;
  IF v_owner <> auth.uid() THEN RAISE EXCEPTION 'not your run' USING ERRCODE='42501'; END IF;

  UPDATE engineer_field_service_module_runs
  SET status = 'completed',
      steps_completed = GREATEST(p_steps_completed, 0),
      signature_uri = COALESCE(p_signature_uri, signature_uri),
      completed_at = now()
  WHERE id = p_run_id;
  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.engineer_field_service_complete_module_run(uuid, integer, text) TO authenticated;

-- =========================================================================
-- RPC 7: log_founder_field_service_register_module — register module (audit)
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_field_service_register_module(text, text, integer, text);
CREATE OR REPLACE FUNCTION public.log_founder_field_service_register_module(
  p_module_label text,
  p_module_kind text,
  p_required_steps_count integer,
  p_mobile_min_version text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  INSERT INTO engineer_field_service_modules
    (module_label, module_kind, required_steps_count, mobile_min_version, is_active)
  VALUES (p_module_label, p_module_kind, GREATEST(p_required_steps_count, 1), p_mobile_min_version, true)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_founder_field_service_register_module(text, text, integer, text) TO authenticated;

COMMIT;