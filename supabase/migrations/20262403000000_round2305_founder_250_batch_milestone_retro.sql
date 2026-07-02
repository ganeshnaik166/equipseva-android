BEGIN;

-- ============================================================
-- r2305: Founder 250-batch milestone retro
-- 2 tables:
--   founder_milestone_retros_r2305   (one row per batch milestone)
--   founder_milestone_patterns_r2305 (system-level patterns observed)
-- 7 RPCs, all is_founder() gated
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_milestone_retros_r2305 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_number int NOT NULL CHECK (batch_number > 0),
  ships_at_milestone int NOT NULL CHECK (ships_at_milestone >= 0),
  heavy_ships_at_milestone int NOT NULL DEFAULT 0 CHECK (heavy_ships_at_milestone >= 0),
  hit_at timestamptz NOT NULL DEFAULT now(),
  prior_milestone_ships int,
  ships_delta int,
  velocity_ships_per_day numeric(8,2),
  audit_bugs_caught int NOT NULL DEFAULT 0 CHECK (audit_bugs_caught >= 0),
  prod_incidents int NOT NULL DEFAULT 0 CHECK (prod_incidents >= 0),
  schema_gotchas_added int NOT NULL DEFAULT 0,
  normalizer_rules_added int NOT NULL DEFAULT 0,
  retro_summary text,
  top_win text,
  top_regret text,
  next_250_north_star text,
  authored_by uuid REFERENCES public.profiles(id),
  authored_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_milestone_patterns_r2305 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retro_id uuid NOT NULL REFERENCES public.founder_milestone_retros_r2305(id) ON DELETE CASCADE,
  rank int NOT NULL CHECK (rank BETWEEN 1 AND 50),
  pattern_title text NOT NULL,
  pattern_category text NOT NULL CHECK (pattern_category IN (
    'schema_typo','rls_gap','workflow_hygiene','agent_drift',
    'normalizer','founder_gate','perf','data_model','ux','process'
  )),
  observation text,
  evidence_round_refs text,
  impact_level text NOT NULL DEFAULT 'medium' CHECK (impact_level IN ('low','medium','high','critical')),
  proposed_next_250_change text,
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','accepted','rejected','shipped')),
  shipped_round int,
  noted_by uuid REFERENCES public.profiles(id),
  noted_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (retro_id, rank)
);

CREATE INDEX IF NOT EXISTS idx_milestone_retros_r2305_batch
  ON public.founder_milestone_retros_r2305(batch_number DESC);
CREATE INDEX IF NOT EXISTS idx_milestone_retros_r2305_hit_at
  ON public.founder_milestone_retros_r2305(hit_at DESC);
CREATE INDEX IF NOT EXISTS idx_milestone_patterns_r2305_retro
  ON public.founder_milestone_patterns_r2305(retro_id, rank);
CREATE INDEX IF NOT EXISTS idx_milestone_patterns_r2305_status
  ON public.founder_milestone_patterns_r2305(status);

ALTER TABLE public.founder_milestone_retros_r2305 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_milestone_patterns_r2305 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_milestone_retros_r2305;
CREATE POLICY founder_all ON public.founder_milestone_retros_r2305
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_milestone_patterns_r2305;
CREATE POLICY founder_all ON public.founder_milestone_patterns_r2305
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: log a new milestone retro
-- ============================================================
DROP FUNCTION IF EXISTS public.r2305_log_milestone_retro(int,int,int,int,numeric,int,int,int,int,text,text,text,text);
CREATE FUNCTION public.r2305_log_milestone_retro(
  p_batch_number int,
  p_ships_at_milestone int,
  p_heavy_ships_at_milestone int,
  p_prior_milestone_ships int,
  p_velocity_ships_per_day numeric,
  p_audit_bugs_caught int,
  p_prod_incidents int,
  p_schema_gotchas_added int,
  p_normalizer_rules_added int,
  p_retro_summary text,
  p_top_win text,
  p_top_regret text,
  p_next_250_north_star text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
  v_uid uuid;
  v_delta int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_email := auth.jwt()->>'email';
  SELECT id INTO v_uid FROM public.profiles WHERE email = v_email LIMIT 1;
  v_delta := COALESCE(p_ships_at_milestone,0) - COALESCE(p_prior_milestone_ships,0);

  INSERT INTO public.founder_milestone_retros_r2305 (
    batch_number, ships_at_milestone, heavy_ships_at_milestone,
    prior_milestone_ships, ships_delta, velocity_ships_per_day,
    audit_bugs_caught, prod_incidents, schema_gotchas_added,
    normalizer_rules_added, retro_summary, top_win, top_regret,
    next_250_north_star, authored_by, authored_by_email
  ) VALUES (
    p_batch_number, p_ships_at_milestone, p_heavy_ships_at_milestone,
    p_prior_milestone_ships, v_delta, p_velocity_ships_per_day,
    p_audit_bugs_caught, p_prod_incidents, p_schema_gotchas_added,
    p_normalizer_rules_added, p_retro_summary, p_top_win, p_top_regret,
    p_next_250_north_star, v_uid, v_email
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 2: add a pattern observation
-- ============================================================
DROP FUNCTION IF EXISTS public.r2305_add_pattern(uuid,int,text,text,text,text,text,text);
CREATE FUNCTION public.r2305_add_pattern(
  p_retro_id uuid,
  p_rank int,
  p_pattern_title text,
  p_pattern_category text,
  p_observation text,
  p_evidence_round_refs text,
  p_impact_level text,
  p_proposed_next_250_change text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
  v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_email := auth.jwt()->>'email';
  SELECT id INTO v_uid FROM public.profiles WHERE email = v_email LIMIT 1;

  INSERT INTO public.founder_milestone_patterns_r2305 (
    retro_id, rank, pattern_title, pattern_category, observation,
    evidence_round_refs, impact_level, proposed_next_250_change,
    noted_by, noted_by_email
  ) VALUES (
    p_retro_id, p_rank, p_pattern_title, p_pattern_category, p_observation,
    p_evidence_round_refs, p_impact_level, p_proposed_next_250_change,
    v_uid, v_email
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: accept a pattern
-- ============================================================
DROP FUNCTION IF EXISTS public.r2305_accept_pattern(uuid);
CREATE FUNCTION public.r2305_accept_pattern(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_milestone_patterns_r2305
     SET status = 'accepted', updated_at = now()
   WHERE id = p_id;
END;
$$;

-- ============================================================
-- RPC 4: reject a pattern
-- ============================================================
DROP FUNCTION IF EXISTS public.r2305_reject_pattern(uuid);
CREATE FUNCTION public.r2305_reject_pattern(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_milestone_patterns_r2305
     SET status = 'rejected', updated_at = now()
   WHERE id = p_id;
END;
$$;

-- ============================================================
-- RPC 5: mark pattern as shipped in a round
-- ============================================================
DROP FUNCTION IF EXISTS public.r2305_mark_pattern_shipped(uuid,int);
CREATE FUNCTION public.r2305_mark_pattern_shipped(p_id uuid, p_round int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_milestone_patterns_r2305
     SET status = 'shipped', shipped_round = p_round, updated_at = now()
   WHERE id = p_id;
END;
$$;

-- ============================================================
-- RPC 6: list milestone retros (most-recent first)
-- ============================================================
DROP FUNCTION IF EXISTS public.r2305_list_retros(int);
CREATE FUNCTION public.r2305_list_retros(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  batch_number int,
  ships_at_milestone int,
  heavy_ships_at_milestone int,
  hit_at timestamptz,
  ships_delta int,
  velocity_ships_per_day numeric,
  audit_bugs_caught int,
  prod_incidents int,
  retro_summary text,
  top_win text,
  next_250_north_star text,
  pattern_count bigint,
  shipped_pattern_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT r.id, r.batch_number, r.ships_at_milestone, r.heavy_ships_at_milestone,
         r.hit_at, r.ships_delta, r.velocity_ships_per_day,
         r.audit_bugs_caught, r.prod_incidents, r.retro_summary,
         r.top_win, r.next_250_north_star,
         COUNT(p.id) AS pattern_count,
         COUNT(p.id) FILTER (WHERE p.status = 'shipped') AS shipped_pattern_count
    FROM public.founder_milestone_retros_r2305 r
    LEFT JOIN public.founder_milestone_patterns_r2305 p ON p.retro_id = r.id
   GROUP BY r.id
   ORDER BY r.batch_number DESC
   LIMIT GREATEST(p_limit, 1);
END;
$$;

-- ============================================================
-- RPC 7: list patterns for a retro
-- ============================================================
DROP FUNCTION IF EXISTS public.r2305_list_patterns(uuid);
CREATE FUNCTION public.r2305_list_patterns(p_retro_id uuid)
RETURNS TABLE (
  id uuid,
  rank int,
  pattern_title text,
  pattern_category text,
  observation text,
  evidence_round_refs text,
  impact_level text,
  proposed_next_250_change text,
  status text,
  shipped_round int,
  noted_by_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT p.id, p.rank, p.pattern_title, p.pattern_category, p.observation,
         p.evidence_round_refs, p.impact_level, p.proposed_next_250_change,
         p.status, p.shipped_round, p.noted_by_email, p.created_at
    FROM public.founder_milestone_patterns_r2305 p
   WHERE p.retro_id = p_retro_id
   ORDER BY p.rank ASC;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
GRANT EXECUTE ON FUNCTION public.r2305_log_milestone_retro(int,int,int,int,numeric,int,int,int,int,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2305_add_pattern(uuid,int,text,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2305_accept_pattern(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2305_reject_pattern(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2305_mark_pattern_shipped(uuid,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2305_list_retros(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2305_list_patterns(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r2305_log_milestone_retro(int,int,int,int,numeric,int,int,int,int,text,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2305_add_pattern(uuid,int,text,text,text,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2305_accept_pattern(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2305_reject_pattern(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2305_mark_pattern_shipped(uuid,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2305_list_retros(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2305_list_patterns(uuid) FROM PUBLIC, anon;

COMMIT;
