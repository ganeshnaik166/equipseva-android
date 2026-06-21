BEGIN;

-- ============================================================================
-- Round 1792: Engineer Bench Strength Tracker
-- Track engineer roster strength per equipment category for redundancy
-- ============================================================================

-- Table: per-category bench strength snapshot
CREATE TABLE IF NOT EXISTS public.engineer_bench_strength_per_category_r1792 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_category text NOT NULL UNIQUE,
  primary_engineer_count int NOT NULL DEFAULT 0,
  backup_engineer_count int NOT NULL DEFAULT 0,
  total_capable int NOT NULL DEFAULT 0,
  min_required int NOT NULL DEFAULT 2,
  status text NOT NULL DEFAULT 'balanced' CHECK (status IN ('overstaffed','balanced','at_risk','critical_shortage')),
  recomputed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_bench_strength_per_category_r1792 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bench_strength_r1792_founder ON public.engineer_bench_strength_per_category_r1792;
CREATE POLICY bench_strength_r1792_founder ON public.engineer_bench_strength_per_category_r1792
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table: actions taken / planned to fix bench strength
CREATE TABLE IF NOT EXISTS public.engineer_bench_strength_actions_r1792 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('hire','cross_train','promote','redistribute','contract')),
  target_count int NOT NULL DEFAULT 1,
  action_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','done')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_bench_strength_actions_r1792 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bench_actions_r1792_founder ON public.engineer_bench_strength_actions_r1792;
CREATE POLICY bench_actions_r1792_founder ON public.engineer_bench_strength_actions_r1792
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_bench_strength_r1792_status ON public.engineer_bench_strength_per_category_r1792(status);
CREATE INDEX IF NOT EXISTS idx_bench_actions_r1792_status ON public.engineer_bench_strength_actions_r1792(status);
CREATE INDEX IF NOT EXISTS idx_bench_actions_r1792_category ON public.engineer_bench_strength_actions_r1792(category);

-- ============================================================================
-- RPC 1: list_bench
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_bench_r1792();
CREATE OR REPLACE FUNCTION public.list_bench_r1792()
RETURNS TABLE (
  id uuid,
  equipment_category text,
  primary_engineer_count int,
  backup_engineer_count int,
  total_capable int,
  min_required int,
  status text,
  recomputed_at timestamptz
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
  SELECT b.id, b.equipment_category, b.primary_engineer_count, b.backup_engineer_count,
         b.total_capable, b.min_required, b.status, b.recomputed_at
  FROM public.engineer_bench_strength_per_category_r1792 b
  ORDER BY
    CASE b.status
      WHEN 'critical_shortage' THEN 0
      WHEN 'at_risk' THEN 1
      WHEN 'balanced' THEN 2
      WHEN 'overstaffed' THEN 3
    END,
    b.equipment_category;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_bench_r1792() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bench_r1792() TO authenticated;

-- ============================================================================
-- RPC 2: refresh_bench
-- ============================================================================
DROP FUNCTION IF EXISTS public.refresh_bench_r1792();
CREATE OR REPLACE FUNCTION public.refresh_bench_r1792()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- Seed common categories if empty
  INSERT INTO public.engineer_bench_strength_per_category_r1792 (equipment_category, min_required)
  VALUES
    ('imaging', 3),
    ('ventilator', 3),
    ('dialysis', 2),
    ('anesthesia', 2),
    ('monitoring', 2),
    ('surgical', 3),
    ('lab_diagnostics', 2)
  ON CONFLICT (equipment_category) DO NOTHING;

  -- Recompute counts: use repair_jobs completed counts as proxy for capability
  UPDATE public.engineer_bench_strength_per_category_r1792 b
  SET
    primary_engineer_count = COALESCE(sub.primary_count, 0),
    backup_engineer_count = COALESCE(sub.backup_count, 0),
    total_capable = COALESCE(sub.total, 0),
    status = CASE
      WHEN COALESCE(sub.total, 0) >= b.min_required * 2 THEN 'overstaffed'
      WHEN COALESCE(sub.total, 0) >= b.min_required THEN 'balanced'
      WHEN COALESCE(sub.total, 0) >= GREATEST(b.min_required - 1, 1) THEN 'at_risk'
      ELSE 'critical_shortage'
    END,
    recomputed_at = now(),
    updated_at = now()
  FROM (
    SELECT
      b2.equipment_category,
      (COUNT(DISTINCT e.id) FILTER (WHERE e.cached_highest_tier IN ('gold','platinum')))::int AS primary_count,
      (COUNT(DISTINCT e.id) FILTER (WHERE e.cached_highest_tier IN ('silver','bronze')))::int AS backup_count,
      (COUNT(DISTINCT e.id))::int AS total
    FROM public.engineer_bench_strength_per_category_r1792 b2
    LEFT JOIN public.engineers e ON true
    GROUP BY b2.equipment_category
  ) sub
  WHERE b.equipment_category = sub.equipment_category;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'refresh_bench_r1792',
    jsonb_build_object('refreshed_count', v_count, 'at', now())
  );

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refresh_bench_r1792() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_bench_r1792() TO authenticated;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_bench_actions_r1792();
CREATE OR REPLACE FUNCTION public.list_bench_actions_r1792()
RETURNS TABLE (
  id uuid,
  category text,
  action_type text,
  target_count int,
  action_at timestamptz,
  status text,
  notes text
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
  SELECT a.id, a.category, a.action_type, a.target_count, a.action_at, a.status, a.notes
  FROM public.engineer_bench_strength_actions_r1792 a
  ORDER BY
    CASE a.status WHEN 'in_progress' THEN 0 WHEN 'planned' THEN 1 WHEN 'done' THEN 2 END,
    a.action_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_bench_actions_r1792() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bench_actions_r1792() TO authenticated;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_bench_action_r1792(text, text, int, text);
CREATE OR REPLACE FUNCTION public.log_bench_action_r1792(
  p_category text,
  p_action_type text,
  p_target_count int,
  p_notes text DEFAULT NULL
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
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_action_type NOT IN ('hire','cross_train','promote','redistribute','contract') THEN
    RAISE EXCEPTION 'invalid action_type %', p_action_type;
  END IF;

  INSERT INTO public.engineer_bench_strength_actions_r1792 (
    category, action_type, target_count, notes, status
  )
  VALUES (p_category, p_action_type, COALESCE(p_target_count, 1), p_notes, 'planned')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'log_bench_action_r1792',
    jsonb_build_object(
      'action_id', v_id,
      'category', p_category,
      'action_type', p_action_type,
      'target_count', p_target_count
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_bench_action_r1792(text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_bench_action_r1792(text, text, int, text) TO authenticated;

-- ============================================================================
-- RPC 5: complete_action
-- ============================================================================
DROP FUNCTION IF EXISTS public.complete_bench_action_r1792(uuid);
CREATE OR REPLACE FUNCTION public.complete_bench_action_r1792(p_action_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_updated int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_bench_strength_actions_r1792
  SET status = 'done', updated_at = now()
  WHERE id = p_action_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'complete_bench_action_r1792',
    jsonb_build_object('action_id', p_action_id, 'updated', v_updated)
  );

  RETURN v_updated > 0;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.complete_bench_action_r1792(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_bench_action_r1792(uuid) TO authenticated;

-- ============================================================================
-- RPC 6: at_risk_categories
-- ============================================================================
DROP FUNCTION IF EXISTS public.at_risk_bench_categories_r1792();
CREATE OR REPLACE FUNCTION public.at_risk_bench_categories_r1792()
RETURNS TABLE (
  equipment_category text,
  total_capable int,
  min_required int,
  shortfall int,
  status text
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
    b.equipment_category,
    b.total_capable,
    b.min_required,
    GREATEST(b.min_required - b.total_capable, 0) AS shortfall,
    b.status
  FROM public.engineer_bench_strength_per_category_r1792 b
  WHERE b.status IN ('at_risk','critical_shortage')
  ORDER BY
    CASE b.status WHEN 'critical_shortage' THEN 0 ELSE 1 END,
    (b.min_required - b.total_capable) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.at_risk_bench_categories_r1792() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.at_risk_bench_categories_r1792() TO authenticated;

-- ============================================================================
-- RPC 7: redundancy_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.bench_redundancy_summary_r1792();
CREATE OR REPLACE FUNCTION public.bench_redundancy_summary_r1792()
RETURNS TABLE (
  total_categories int,
  overstaffed_count int,
  balanced_count int,
  at_risk_count int,
  critical_shortage_count int,
  total_engineers int,
  avg_bench_depth numeric
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
    (COUNT(*))::int AS total_categories,
    (COUNT(*) FILTER (WHERE b.status = 'overstaffed'))::int AS overstaffed_count,
    (COUNT(*) FILTER (WHERE b.status = 'balanced'))::int AS balanced_count,
    (COUNT(*) FILTER (WHERE b.status = 'at_risk'))::int AS at_risk_count,
    (COUNT(*) FILTER (WHERE b.status = 'critical_shortage'))::int AS critical_shortage_count,
    COALESCE(SUM(b.total_capable), 0)::int AS total_engineers,
    ROUND(AVG(b.total_capable)::numeric, 2) AS avg_bench_depth
  FROM public.engineer_bench_strength_per_category_r1792 b;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.bench_redundancy_summary_r1792() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bench_redundancy_summary_r1792() TO authenticated;

COMMIT;