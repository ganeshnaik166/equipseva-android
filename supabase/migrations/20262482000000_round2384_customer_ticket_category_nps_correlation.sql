BEGIN;

-- ============================================================================
-- r2384: Customer ticket category vs NPS correlation
-- Does ticket category (delay/quality/billing) correlate with NPS drop?
-- Broken out by hospital tier.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ticket_nps_correlation_samples_r2384 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_tier text NOT NULL CHECK (hospital_tier IN ('tier_1','tier_2','tier_3','tier_4')),
  ticket_category text NOT NULL CHECK (ticket_category IN ('delay','quality','billing','communication','parts','other')),
  ticket_count_30d integer NOT NULL DEFAULT 0 CHECK (ticket_count_30d >= 0),
  nps_before integer CHECK (nps_before BETWEEN -100 AND 100),
  nps_after integer CHECK (nps_after BETWEEN -100 AND 100),
  nps_delta integer GENERATED ALWAYS AS (COALESCE(nps_after,0) - COALESCE(nps_before,0)) STORED,
  sampled_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tnc_r2384_hospital ON public.ticket_nps_correlation_samples_r2384(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_tnc_r2384_category ON public.ticket_nps_correlation_samples_r2384(ticket_category);
CREATE INDEX IF NOT EXISTS idx_tnc_r2384_tier ON public.ticket_nps_correlation_samples_r2384(hospital_tier);
CREATE INDEX IF NOT EXISTS idx_tnc_r2384_sampled ON public.ticket_nps_correlation_samples_r2384(sampled_at DESC);

ALTER TABLE public.ticket_nps_correlation_samples_r2384 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.ticket_nps_correlation_samples_r2384;
CREATE POLICY founder_all ON public.ticket_nps_correlation_samples_r2384
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.ticket_nps_correlation_actions_r2384 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_category text NOT NULL CHECK (ticket_category IN ('delay','quality','billing','communication','parts','other')),
  hospital_tier text CHECK (hospital_tier IN ('tier_1','tier_2','tier_3','tier_4')),
  action_title text NOT NULL,
  action_owner text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  expected_nps_lift integer,
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tnca_r2384_category ON public.ticket_nps_correlation_actions_r2384(ticket_category);
CREATE INDEX IF NOT EXISTS idx_tnca_r2384_status ON public.ticket_nps_correlation_actions_r2384(status);

ALTER TABLE public.ticket_nps_correlation_actions_r2384 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.ticket_nps_correlation_actions_r2384;
CREATE POLICY founder_all ON public.ticket_nps_correlation_actions_r2384
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================================
-- RPC 1: Correlation matrix — category x tier, avg nps_delta + ticket volume
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_ticket_nps_matrix_r2384()
RETURNS TABLE (
  ticket_category text,
  hospital_tier text,
  sample_count bigint,
  avg_nps_delta numeric,
  avg_nps_before numeric,
  avg_nps_after numeric,
  total_tickets bigint
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
    s.ticket_category,
    s.hospital_tier,
    COUNT(*)::bigint AS sample_count,
    ROUND(AVG(s.nps_delta)::numeric, 2) AS avg_nps_delta,
    ROUND(AVG(s.nps_before)::numeric, 2) AS avg_nps_before,
    ROUND(AVG(s.nps_after)::numeric, 2) AS avg_nps_after,
    COALESCE(SUM(s.ticket_count_30d), 0)::bigint AS total_tickets
  FROM public.ticket_nps_correlation_samples_r2384 s
  GROUP BY s.ticket_category, s.hospital_tier
  ORDER BY s.ticket_category, s.hospital_tier;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ticket_nps_matrix_r2384() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ticket_nps_matrix_r2384() TO authenticated;


-- ============================================================================
-- RPC 2: Worst categories ranked by avg nps drop
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_ticket_nps_worst_categories_r2384()
RETURNS TABLE (
  ticket_category text,
  sample_count bigint,
  avg_nps_delta numeric,
  worst_tier text,
  worst_tier_delta numeric
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
  WITH per_cat AS (
    SELECT
      s.ticket_category,
      COUNT(*)::bigint AS sample_count,
      ROUND(AVG(s.nps_delta)::numeric, 2) AS avg_nps_delta
    FROM public.ticket_nps_correlation_samples_r2384 s
    GROUP BY s.ticket_category
  ),
  per_cat_tier AS (
    SELECT
      s.ticket_category,
      s.hospital_tier,
      ROUND(AVG(s.nps_delta)::numeric, 2) AS tier_delta,
      ROW_NUMBER() OVER (PARTITION BY s.ticket_category ORDER BY AVG(s.nps_delta) ASC) AS rn
    FROM public.ticket_nps_correlation_samples_r2384 s
    GROUP BY s.ticket_category, s.hospital_tier
  )
  SELECT
    pc.ticket_category,
    pc.sample_count,
    pc.avg_nps_delta,
    pct.hospital_tier AS worst_tier,
    pct.tier_delta AS worst_tier_delta
  FROM per_cat pc
  LEFT JOIN per_cat_tier pct ON pct.ticket_category = pc.ticket_category AND pct.rn = 1
  ORDER BY pc.avg_nps_delta ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ticket_nps_worst_categories_r2384() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ticket_nps_worst_categories_r2384() TO authenticated;


-- ============================================================================
-- RPC 3: Tier breakdown — which tier hurts most across all categories
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_ticket_nps_tier_breakdown_r2384()
RETURNS TABLE (
  hospital_tier text,
  sample_count bigint,
  avg_nps_delta numeric,
  total_tickets bigint,
  hospitals_sampled bigint
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
    s.hospital_tier,
    COUNT(*)::bigint AS sample_count,
    ROUND(AVG(s.nps_delta)::numeric, 2) AS avg_nps_delta,
    COALESCE(SUM(s.ticket_count_30d), 0)::bigint AS total_tickets,
    COUNT(DISTINCT s.hospital_user_id)::bigint AS hospitals_sampled
  FROM public.ticket_nps_correlation_samples_r2384 s
  GROUP BY s.hospital_tier
  ORDER BY avg_nps_delta ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ticket_nps_tier_breakdown_r2384() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ticket_nps_tier_breakdown_r2384() TO authenticated;


-- ============================================================================
-- RPC 4: Recent samples list — top N most recent for review
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_ticket_nps_recent_samples_r2384(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_email text,
  hospital_tier text,
  ticket_category text,
  ticket_count_30d integer,
  nps_before integer,
  nps_after integer,
  nps_delta integer,
  sampled_at timestamptz,
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
  SELECT
    s.id,
    p.email AS hospital_email,
    s.hospital_tier,
    s.ticket_category,
    s.ticket_count_30d,
    s.nps_before,
    s.nps_after,
    s.nps_delta,
    s.sampled_at,
    s.notes
  FROM public.ticket_nps_correlation_samples_r2384 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.sampled_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 50), 1);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ticket_nps_recent_samples_r2384(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ticket_nps_recent_samples_r2384(integer) TO authenticated;


-- ============================================================================
-- RPC 5: Headline stats — overall correlation strength
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_ticket_nps_headline_r2384()
RETURNS TABLE (
  total_samples bigint,
  total_hospitals bigint,
  avg_nps_delta numeric,
  worst_category text,
  worst_category_delta numeric,
  worst_tier text,
  worst_tier_delta numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_samples bigint;
  v_total_hospitals bigint;
  v_avg_delta numeric;
  v_worst_cat text;
  v_worst_cat_delta numeric;
  v_worst_tier text;
  v_worst_tier_delta numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COUNT(*), COUNT(DISTINCT hospital_user_id), ROUND(AVG(nps_delta)::numeric, 2)
    INTO v_total_samples, v_total_hospitals, v_avg_delta
    FROM public.ticket_nps_correlation_samples_r2384;

  SELECT ticket_category, ROUND(AVG(nps_delta)::numeric, 2)
    INTO v_worst_cat, v_worst_cat_delta
    FROM public.ticket_nps_correlation_samples_r2384
    GROUP BY ticket_category
    ORDER BY AVG(nps_delta) ASC
    LIMIT 1;

  SELECT hospital_tier, ROUND(AVG(nps_delta)::numeric, 2)
    INTO v_worst_tier, v_worst_tier_delta
    FROM public.ticket_nps_correlation_samples_r2384
    GROUP BY hospital_tier
    ORDER BY AVG(nps_delta) ASC
    LIMIT 1;

  RETURN QUERY SELECT
    COALESCE(v_total_samples, 0),
    COALESCE(v_total_hospitals, 0),
    COALESCE(v_avg_delta, 0::numeric),
    v_worst_cat,
    v_worst_cat_delta,
    v_worst_tier,
    v_worst_tier_delta;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ticket_nps_headline_r2384() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ticket_nps_headline_r2384() TO authenticated;


-- ============================================================================
-- RPC 6: List actions queued against worst categories
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_ticket_nps_actions_r2384()
RETURNS TABLE (
  id uuid,
  ticket_category text,
  hospital_tier text,
  action_title text,
  action_owner text,
  status text,
  expected_nps_lift integer,
  notes text,
  created_at timestamptz
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
    a.id,
    a.ticket_category,
    a.hospital_tier,
    a.action_title,
    a.action_owner,
    a.status,
    a.expected_nps_lift,
    a.notes,
    a.created_at
  FROM public.ticket_nps_correlation_actions_r2384 a
  ORDER BY
    CASE a.status WHEN 'open' THEN 0 WHEN 'in_progress' THEN 1 WHEN 'done' THEN 2 ELSE 3 END,
    a.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ticket_nps_actions_r2384() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ticket_nps_actions_r2384() TO authenticated;


-- ============================================================================
-- RPC 7: Category trend by tier — bottom-quartile hospitals only
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_ticket_nps_bottom_quartile_r2384()
RETURNS TABLE (
  ticket_category text,
  hospital_tier text,
  hospital_email text,
  ticket_count_30d integer,
  nps_delta integer,
  sampled_at timestamptz
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
  WITH ranked AS (
    SELECT
      s.*,
      NTILE(4) OVER (PARTITION BY s.ticket_category ORDER BY s.nps_delta ASC) AS quartile
    FROM public.ticket_nps_correlation_samples_r2384 s
  )
  SELECT
    r.ticket_category,
    r.hospital_tier,
    p.email AS hospital_email,
    r.ticket_count_30d,
    r.nps_delta,
    r.sampled_at
  FROM ranked r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  WHERE r.quartile = 1
  ORDER BY r.ticket_category, r.nps_delta ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_ticket_nps_bottom_quartile_r2384() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ticket_nps_bottom_quartile_r2384() TO authenticated;

COMMIT;
