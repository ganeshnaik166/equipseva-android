BEGIN;

-- ============================================================
-- Round 2345: Founder OKR-cascade integrity check
-- Quarterly OKRs at company/team/individual levels with
-- parent/child alignment rollups.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_okrs_r2345 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,                                -- e.g. '2026-Q3'
  level text NOT NULL CHECK (level IN ('company','team','individual')),
  parent_okr_id uuid REFERENCES public.founder_okrs_r2345(id) ON DELETE SET NULL,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  team_name text,
  objective text NOT NULL,
  key_results jsonb NOT NULL DEFAULT '[]'::jsonb,       -- [{kr, target, current, unit}]
  progress_pct numeric(5,2) NOT NULL DEFAULT 0,         -- 0..100
  confidence text NOT NULL DEFAULT 'on_track' CHECK (confidence IN ('on_track','at_risk','off_track','done')),
  alignment_pct numeric(5,2),                           -- weighted child rollup
  last_check_in_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_okrs_r2345_quarter ON public.founder_okrs_r2345(quarter);
CREATE INDEX IF NOT EXISTS idx_okrs_r2345_parent ON public.founder_okrs_r2345(parent_okr_id);
CREATE INDEX IF NOT EXISTS idx_okrs_r2345_level ON public.founder_okrs_r2345(level);

ALTER TABLE public.founder_okrs_r2345 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_okrs_r2345 ON public.founder_okrs_r2345;
CREATE POLICY founder_all_okrs_r2345 ON public.founder_okrs_r2345
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.founder_okr_integrity_findings_r2345 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  okr_id uuid REFERENCES public.founder_okrs_r2345(id) ON DELETE CASCADE,
  finding_type text NOT NULL CHECK (finding_type IN (
    'orphan',              -- team/individual OKR with no parent
    'misaligned',          -- child progress < parent progress threshold
    'stale_checkin',       -- last_check_in_at older than 14 days
    'no_key_results',      -- key_results array empty
    'broken_rollup',       -- alignment_pct deviates from child weighted avg
    'duplicate_objective'  -- same objective text repeated within level
  )),
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  detail text,
  detected_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_okr_findings_r2345_quarter ON public.founder_okr_integrity_findings_r2345(quarter);
CREATE INDEX IF NOT EXISTS idx_okr_findings_r2345_open ON public.founder_okr_integrity_findings_r2345(resolved_at) WHERE resolved_at IS NULL;

ALTER TABLE public.founder_okr_integrity_findings_r2345 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_okr_findings_r2345 ON public.founder_okr_integrity_findings_r2345;
CREATE POLICY founder_all_okr_findings_r2345 ON public.founder_okr_integrity_findings_r2345
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================
-- RPC 1: Cascade summary by level for a quarter
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_okr_cascade_summary_r2345(p_quarter text)
RETURNS TABLE (
  level text,
  okr_count bigint,
  avg_progress numeric,
  avg_alignment numeric,
  on_track_count bigint,
  at_risk_count bigint,
  off_track_count bigint,
  done_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.level,
    COUNT(*)::bigint,
    ROUND(AVG(o.progress_pct)::numeric, 2),
    ROUND(AVG(COALESCE(o.alignment_pct, 0))::numeric, 2),
    COUNT(*) FILTER (WHERE o.confidence = 'on_track')::bigint,
    COUNT(*) FILTER (WHERE o.confidence = 'at_risk')::bigint,
    COUNT(*) FILTER (WHERE o.confidence = 'off_track')::bigint,
    COUNT(*) FILTER (WHERE o.confidence = 'done')::bigint
  FROM public.founder_okrs_r2345 o
  WHERE o.quarter = p_quarter
  GROUP BY o.level
  ORDER BY CASE o.level WHEN 'company' THEN 1 WHEN 'team' THEN 2 ELSE 3 END;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_okr_cascade_summary_r2345(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_okr_cascade_summary_r2345(text) TO authenticated;


-- ============================================================
-- RPC 2: Company OKRs with rolled-up alignment
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_okr_company_rollup_r2345(p_quarter text)
RETURNS TABLE (
  okr_id uuid,
  objective text,
  progress_pct numeric,
  alignment_pct numeric,
  confidence text,
  child_count bigint,
  child_avg_progress numeric,
  rollup_drift numeric,
  last_check_in_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    parent.id,
    parent.objective,
    parent.progress_pct,
    parent.alignment_pct,
    parent.confidence,
    COUNT(child.id)::bigint,
    ROUND(AVG(child.progress_pct)::numeric, 2),
    ROUND((parent.progress_pct - COALESCE(AVG(child.progress_pct), parent.progress_pct))::numeric, 2),
    parent.last_check_in_at
  FROM public.founder_okrs_r2345 parent
  LEFT JOIN public.founder_okrs_r2345 child
    ON child.parent_okr_id = parent.id AND child.quarter = parent.quarter
  WHERE parent.quarter = p_quarter AND parent.level = 'company'
  GROUP BY parent.id, parent.objective, parent.progress_pct, parent.alignment_pct, parent.confidence, parent.last_check_in_at
  ORDER BY parent.progress_pct DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_okr_company_rollup_r2345(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_okr_company_rollup_r2345(text) TO authenticated;


-- ============================================================
-- RPC 3: Orphan OKRs (no parent at team/individual level)
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_okr_orphans_r2345(p_quarter text)
RETURNS TABLE (
  okr_id uuid,
  level text,
  objective text,
  owner_email text,
  team_name text,
  progress_pct numeric,
  confidence text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.level,
    o.objective,
    p.email,
    o.team_name,
    o.progress_pct,
    o.confidence
  FROM public.founder_okrs_r2345 o
  LEFT JOIN public.profiles p ON p.id = o.owner_user_id
  WHERE o.quarter = p_quarter
    AND o.level IN ('team','individual')
    AND o.parent_okr_id IS NULL
  ORDER BY o.level, o.objective;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_okr_orphans_r2345(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_okr_orphans_r2345(text) TO authenticated;


-- ============================================================
-- RPC 4: Misaligned OKRs (child progress lags parent by >= threshold)
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_okr_misaligned_r2345(p_quarter text, p_threshold numeric DEFAULT 25)
RETURNS TABLE (
  child_okr_id uuid,
  child_objective text,
  child_level text,
  child_progress numeric,
  parent_okr_id uuid,
  parent_objective text,
  parent_progress numeric,
  delta numeric,
  owner_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.objective,
    c.level,
    c.progress_pct,
    pr.id,
    pr.objective,
    pr.progress_pct,
    ROUND((pr.progress_pct - c.progress_pct)::numeric, 2),
    p.email
  FROM public.founder_okrs_r2345 c
  JOIN public.founder_okrs_r2345 pr ON pr.id = c.parent_okr_id
  LEFT JOIN public.profiles p ON p.id = c.owner_user_id
  WHERE c.quarter = p_quarter
    AND (pr.progress_pct - c.progress_pct) >= p_threshold
  ORDER BY (pr.progress_pct - c.progress_pct) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_okr_misaligned_r2345(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_okr_misaligned_r2345(text, numeric) TO authenticated;


-- ============================================================
-- RPC 5: Stale check-ins (last check-in older than N days)
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_okr_stale_checkins_r2345(p_quarter text, p_days int DEFAULT 14)
RETURNS TABLE (
  okr_id uuid,
  level text,
  objective text,
  owner_email text,
  team_name text,
  last_check_in_at timestamptz,
  days_stale int,
  progress_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.level,
    o.objective,
    p.email,
    o.team_name,
    o.last_check_in_at,
    EXTRACT(DAY FROM (now() - COALESCE(o.last_check_in_at, o.created_at)))::int,
    o.progress_pct
  FROM public.founder_okrs_r2345 o
  LEFT JOIN public.profiles p ON p.id = o.owner_user_id
  WHERE o.quarter = p_quarter
    AND o.confidence <> 'done'
    AND (o.last_check_in_at IS NULL OR o.last_check_in_at < now() - (p_days || ' days')::interval)
  ORDER BY COALESCE(o.last_check_in_at, o.created_at) ASC NULLS FIRST;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_okr_stale_checkins_r2345(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_okr_stale_checkins_r2345(text, int) TO authenticated;


-- ============================================================
-- RPC 6: Open integrity findings
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_okr_open_findings_r2345(p_quarter text)
RETURNS TABLE (
  finding_id uuid,
  finding_type text,
  severity text,
  okr_objective text,
  okr_level text,
  detail text,
  detected_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    f.finding_type,
    f.severity,
    o.objective,
    o.level,
    f.detail,
    f.detected_at
  FROM public.founder_okr_integrity_findings_r2345 f
  LEFT JOIN public.founder_okrs_r2345 o ON o.id = f.okr_id
  WHERE f.quarter = p_quarter
    AND f.resolved_at IS NULL
  ORDER BY
    CASE f.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    f.detected_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_okr_open_findings_r2345(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_okr_open_findings_r2345(text) TO authenticated;


-- ============================================================
-- RPC 7: Team-level health roster
-- ============================================================
CREATE OR REPLACE FUNCTION public.founder_okr_team_health_r2345(p_quarter text)
RETURNS TABLE (
  team_name text,
  team_okr_count bigint,
  individual_okr_count bigint,
  avg_progress numeric,
  off_track_count bigint,
  open_finding_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(t.team_name, '(unassigned)'),
    COUNT(*) FILTER (WHERE t.level = 'team')::bigint,
    COUNT(*) FILTER (WHERE t.level = 'individual')::bigint,
    ROUND(AVG(t.progress_pct)::numeric, 2),
    COUNT(*) FILTER (WHERE t.confidence = 'off_track')::bigint,
    (SELECT COUNT(*) FROM public.founder_okr_integrity_findings_r2345 f
       JOIN public.founder_okrs_r2345 o2 ON o2.id = f.okr_id
       WHERE f.quarter = p_quarter AND f.resolved_at IS NULL
         AND COALESCE(o2.team_name,'(unassigned)') = COALESCE(t.team_name,'(unassigned)'))::bigint
  FROM public.founder_okrs_r2345 t
  WHERE t.quarter = p_quarter
    AND t.level IN ('team','individual')
  GROUP BY COALESCE(t.team_name, '(unassigned)')
  ORDER BY AVG(t.progress_pct) ASC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_okr_team_health_r2345(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_okr_team_health_r2345(text) TO authenticated;

COMMIT;
