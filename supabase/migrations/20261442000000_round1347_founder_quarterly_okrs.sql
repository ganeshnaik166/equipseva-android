BEGIN;
-- r1341 — Founder quarterly OKRs (Objectives + Key Results + Check-ins).
--
-- Discipline: 3-7 objectives per quarter, each with 2-5 key results, weekly
-- confidence-scored check-ins. Anti-revisionist tracking — confidence at
-- decision time + actual outcome at quarter close. Pairs with founder_decisions
-- (r1336) for institutional memory of judgement + execution quality.
--
-- Cadence:
--   * Quarter kickoff (week 1): draft + activate objectives, baseline confidence
--   * Weekly check-ins: log confidence_pct delta + summary + blockers
--   * Quarter close (week 13): mark achieved / missed, write retro

-- ============================================================================
-- Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_okr_objectives (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label    text NOT NULL,
  objective_title  text NOT NULL,
  objective_kind   text CHECK (objective_kind IN
                     ('north_star','growth','quality','financial','team','platform')),
  priority         text DEFAULT 'p1' CHECK (priority IN ('p0','p1','p2','p3')),
  status           text DEFAULT 'draft' CHECK (status IN
                     ('draft','active','at_risk','off_track','achieved','missed')),
  confidence_pct   int  DEFAULT 50 CHECK (confidence_pct >= 0 AND confidence_pct <= 100),
  started_at       timestamptz,
  closed_at        timestamptz,
  owner_user_id    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  notes            text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(quarter_label, objective_title)
);
COMMENT ON TABLE public.founder_okr_objectives IS
  'Quarterly OKRs — objectives with quarter_label (e.g. 2026Q3), kind, priority, lifecycle status, confidence.';

CREATE INDEX IF NOT EXISTS idx_founder_okr_obj_quarter ON public.founder_okr_objectives (quarter_label);
CREATE INDEX IF NOT EXISTS idx_founder_okr_obj_status  ON public.founder_okr_objectives (status);
CREATE INDEX IF NOT EXISTS idx_founder_okr_obj_kind    ON public.founder_okr_objectives (objective_kind);

CREATE TABLE IF NOT EXISTS public.founder_okr_key_results (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id  uuid NOT NULL REFERENCES public.founder_okr_objectives(id) ON DELETE CASCADE,
  kr_title      text NOT NULL,
  target_value  numeric,
  target_unit   text,
  current_value numeric DEFAULT 0,
  progress_pct  numeric GENERATED ALWAYS AS (
    CASE
      WHEN target_value IS NOT NULL AND target_value > 0
      THEN LEAST(100, ROUND((current_value / target_value) * 100, 2))
      ELSE 0
    END
  ) STORED,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_okr_key_results IS
  'Measurable key results per objective. progress_pct computed = current/target clamped to 100.';

CREATE INDEX IF NOT EXISTS idx_founder_okr_kr_objective ON public.founder_okr_key_results (objective_id);

CREATE TABLE IF NOT EXISTS public.founder_okr_check_ins (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id    uuid NOT NULL REFERENCES public.founder_okr_objectives(id) ON DELETE CASCADE,
  check_in_at     timestamptz NOT NULL DEFAULT now(),
  confidence_pct  int CHECK (confidence_pct >= 0 AND confidence_pct <= 100),
  summary         text,
  blockers        text,
  created_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
COMMENT ON TABLE public.founder_okr_check_ins IS
  'Weekly OKR check-in journal — confidence delta + summary + blockers.';

CREATE INDEX IF NOT EXISTS idx_founder_okr_chk_obj  ON public.founder_okr_check_ins (objective_id, check_in_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_okr_chk_when ON public.founder_okr_check_ins (check_in_at DESC);

-- RLS — no direct table access; only through SECDEF RPCs
ALTER TABLE public.founder_okr_objectives  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_okr_key_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_okr_check_ins   ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_okr_obj_no_direct ON public.founder_okr_objectives;
DROP POLICY IF EXISTS founder_okr_kr_no_direct  ON public.founder_okr_key_results;
DROP POLICY IF EXISTS founder_okr_chk_no_direct ON public.founder_okr_check_ins;
CREATE POLICY founder_okr_obj_no_direct ON public.founder_okr_objectives  FOR ALL USING (false);
CREATE POLICY founder_okr_kr_no_direct  ON public.founder_okr_key_results FOR ALL USING (false);
CREATE POLICY founder_okr_chk_no_direct ON public.founder_okr_check_ins   FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_okr_objectives  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.founder_okr_key_results FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.founder_okr_check_ins   FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Read RPC #1 — quarterly summary (14 KPIs)
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_okr_quarterly_summary(text);
CREATE OR REPLACE FUNCTION public.founder_okr_quarterly_summary(p_quarter text DEFAULT NULL)
RETURNS TABLE (
  latest_quarter             text,
  total_objectives           bigint,
  achieved_count             bigint,
  missed_count               bigint,
  at_risk_count              bigint,
  off_track_count            bigint,
  active_count               bigint,
  avg_confidence_pct         numeric,
  kr_total                   bigint,
  kr_avg_progress_pct        numeric,
  kr_complete_count          bigint,
  kr_at_risk_count           bigint,
  last_check_in_at           timestamptz,
  days_since_last_check_in   int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_quarter text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- Pick most-recent quarter if caller did not specify
  v_quarter := COALESCE(p_quarter,
    (SELECT quarter_label FROM public.founder_okr_objectives
     ORDER BY created_at DESC LIMIT 1));

  RETURN QUERY
  WITH obj AS (
    SELECT * FROM public.founder_okr_objectives WHERE quarter_label = v_quarter
  ),
  kr AS (
    SELECT k.* FROM public.founder_okr_key_results k
    JOIN obj o ON o.id = k.objective_id
  ),
  chk AS (
    SELECT c.* FROM public.founder_okr_check_ins c
    JOIN obj o ON o.id = c.objective_id
  )
  SELECT
    v_quarter,
    (SELECT COUNT(*) FROM obj),
    (SELECT COUNT(*) FROM obj WHERE status = 'achieved'),
    (SELECT COUNT(*) FROM obj WHERE status = 'missed'),
    (SELECT COUNT(*) FROM obj WHERE status = 'at_risk'),
    (SELECT COUNT(*) FROM obj WHERE status = 'off_track'),
    (SELECT COUNT(*) FROM obj WHERE status = 'active'),
    COALESCE((SELECT ROUND(AVG(confidence_pct)::numeric, 1) FROM obj), 0),
    (SELECT COUNT(*) FROM kr),
    COALESCE((SELECT ROUND(AVG(progress_pct)::numeric, 1) FROM kr), 0),
    (SELECT COUNT(*) FROM kr WHERE progress_pct >= 100),
    (SELECT COUNT(*) FROM kr WHERE progress_pct < 50),
    (SELECT MAX(check_in_at) FROM chk),
    COALESCE(EXTRACT(DAY FROM (now() - (SELECT MAX(check_in_at) FROM chk)))::int, 999);
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_okr_quarterly_summary(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_okr_quarterly_summary(text) TO authenticated;

-- ============================================================================
-- Read RPC #2 — objectives recent (30 rows default)
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_okr_objectives_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_okr_objectives_recent(
  p_quarter text DEFAULT NULL,
  p_limit   int  DEFAULT 30
)
RETURNS TABLE (
  id              uuid,
  quarter_label   text,
  objective_title text,
  objective_kind  text,
  priority        text,
  status          text,
  confidence_pct  int,
  kr_count        bigint,
  kr_avg_progress numeric,
  started_at      timestamptz,
  closed_at       timestamptz,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  SELECT
    o.id,
    o.quarter_label,
    o.objective_title,
    o.objective_kind,
    o.priority,
    o.status,
    o.confidence_pct,
    COALESCE((SELECT COUNT(*) FROM public.founder_okr_key_results k WHERE k.objective_id = o.id), 0),
    COALESCE((SELECT ROUND(AVG(k.progress_pct)::numeric, 1)
              FROM public.founder_okr_key_results k WHERE k.objective_id = o.id), 0),
    o.started_at,
    o.closed_at,
    o.created_at
  FROM public.founder_okr_objectives o
  WHERE (p_quarter IS NULL OR o.quarter_label = p_quarter)
  ORDER BY
    CASE o.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    o.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_okr_objectives_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_okr_objectives_recent(text, int) TO authenticated;

-- ============================================================================
-- Read RPC #3 — key results for a specific objective
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_okr_key_results_for(uuid);
CREATE OR REPLACE FUNCTION public.founder_okr_key_results_for(p_objective_id uuid)
RETURNS TABLE (
  id             uuid,
  kr_title       text,
  target_value   numeric,
  target_unit    text,
  current_value  numeric,
  progress_pct   numeric,
  notes          text,
  updated_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  SELECT k.id, k.kr_title, k.target_value, k.target_unit,
         k.current_value, k.progress_pct, k.notes, k.updated_at
  FROM public.founder_okr_key_results k
  WHERE k.objective_id = p_objective_id
  ORDER BY k.created_at ASC;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_okr_key_results_for(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_okr_key_results_for(uuid) TO authenticated;

-- ============================================================================
-- Read RPC #4 — recent check-ins (latest 50 across all objectives in quarter)
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_okr_check_ins_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_okr_check_ins_recent(
  p_quarter text DEFAULT NULL,
  p_limit   int  DEFAULT 50
)
RETURNS TABLE (
  id              uuid,
  objective_id    uuid,
  objective_title text,
  check_in_at     timestamptz,
  confidence_pct  int,
  summary         text,
  blockers        text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  SELECT c.id, c.objective_id, o.objective_title,
         c.check_in_at, c.confidence_pct, c.summary, c.blockers
  FROM public.founder_okr_check_ins c
  JOIN public.founder_okr_objectives o ON o.id = c.objective_id
  WHERE (p_quarter IS NULL OR o.quarter_label = p_quarter)
  ORDER BY c.check_in_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_okr_check_ins_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_okr_check_ins_recent(text, int) TO authenticated;

-- ============================================================================
-- Write RPC #1 — create objective
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_okr_create_objective(text, text, text, text, int, text);
CREATE OR REPLACE FUNCTION public.log_founder_okr_create_objective(
  p_quarter      text,
  p_title        text,
  p_kind         text DEFAULT NULL,
  p_priority     text DEFAULT 'p1',
  p_confidence   int  DEFAULT 50,
  p_notes        text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_quarter IS NULL OR length(trim(p_quarter)) = 0 THEN
    RAISE EXCEPTION 'quarter_label required' USING ERRCODE = '22023';
  END IF;
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RAISE EXCEPTION 'objective_title required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.founder_okr_objectives
    (quarter_label, objective_title, objective_kind, priority, status,
     confidence_pct, started_at, owner_user_id, notes)
  VALUES
    (p_quarter, p_title, p_kind, COALESCE(p_priority, 'p1'), 'active',
     COALESCE(p_confidence, 50), now(), auth.uid(), p_notes)
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.log_founder_okr_create_objective(text, text, text, text, int, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_okr_create_objective(text, text, text, text, int, text) TO authenticated;

-- ============================================================================
-- Write RPC #2 — add key result
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_okr_add_key_result(uuid, text, numeric, text, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_okr_add_key_result(
  p_objective_id  uuid,
  p_kr_title      text,
  p_target_value  numeric DEFAULT NULL,
  p_target_unit   text    DEFAULT NULL,
  p_current_value numeric DEFAULT 0,
  p_notes         text    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_objective_id IS NULL THEN
    RAISE EXCEPTION 'objective_id required' USING ERRCODE = '22023';
  END IF;
  IF p_kr_title IS NULL OR length(trim(p_kr_title)) = 0 THEN
    RAISE EXCEPTION 'kr_title required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.founder_okr_key_results
    (objective_id, kr_title, target_value, target_unit, current_value, notes)
  VALUES
    (p_objective_id, p_kr_title, p_target_value, p_target_unit,
     COALESCE(p_current_value, 0), p_notes)
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.log_founder_okr_add_key_result(uuid, text, numeric, text, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_okr_add_key_result(uuid, text, numeric, text, numeric, text) TO authenticated;

-- ============================================================================
-- Write RPC #3 — record check-in (weekly)
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_okr_check_in(uuid, int, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_okr_check_in(
  p_objective_id  uuid,
  p_confidence    int,
  p_summary       text DEFAULT NULL,
  p_blockers      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_objective_id IS NULL THEN
    RAISE EXCEPTION 'objective_id required' USING ERRCODE = '22023';
  END IF;
  IF p_confidence IS NULL OR p_confidence < 0 OR p_confidence > 100 THEN
    RAISE EXCEPTION 'confidence_pct 0..100 required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.founder_okr_check_ins
    (objective_id, confidence_pct, summary, blockers, created_by)
  VALUES
    (p_objective_id, p_confidence, p_summary, p_blockers, auth.uid())
  RETURNING id INTO v_id;

  -- Mirror latest confidence onto the objective for fast read-side rendering
  UPDATE public.founder_okr_objectives
     SET confidence_pct = p_confidence,
         status = CASE
           WHEN p_confidence < 30 THEN 'off_track'
           WHEN p_confidence < 60 THEN 'at_risk'
           WHEN status IN ('draft','active','at_risk','off_track') THEN 'active'
           ELSE status
         END
   WHERE id = p_objective_id;

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.log_founder_okr_check_in(uuid, int, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_okr_check_in(uuid, int, text, text) TO authenticated;

-- ============================================================================
-- Write RPC #4 — update KR current value
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_okr_update_kr(uuid, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_okr_update_kr(
  p_kr_id         uuid,
  p_current_value numeric
)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_kr_id IS NULL THEN
    RAISE EXCEPTION 'kr_id required' USING ERRCODE = '22023';
  END IF;
  IF p_current_value IS NULL THEN
    RAISE EXCEPTION 'current_value required' USING ERRCODE = '22023';
  END IF;

  UPDATE public.founder_okr_key_results
     SET current_value = p_current_value,
         updated_at    = now()
   WHERE id = p_kr_id;

  RETURN FOUND;
END $$;

REVOKE EXECUTE ON FUNCTION public.log_founder_okr_update_kr(uuid, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_okr_update_kr(uuid, numeric) TO authenticated;

COMMIT;