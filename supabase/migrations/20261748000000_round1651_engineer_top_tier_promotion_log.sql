BEGIN;

-- =========================================================================
-- r1651 — Engineer top-of-tier promotion log
-- Founder-only console feature. Tracks engineers maxed in their current tier
-- (top performers ready for next-tier elevation), candidate score per engineer,
-- promotion proposals, founder approvals/rejections, and ship history.
-- =========================================================================

-- -------------------------------------------------------------------------
-- TABLE 1: engineer_promotion_candidates
--   One row per engineer being evaluated for next-tier promotion.
--   Latest-snapshot row keyed by engineer_user_id.
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_promotion_candidates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL,
  current_tier text NOT NULL,
  proposed_tier text NOT NULL,
  candidate_score numeric(6,2) NOT NULL DEFAULT 0,
  jobs_completed int NOT NULL DEFAULT 0,
  avg_hospital_rating numeric(4,2),
  total_revenue_rupees bigint NOT NULL DEFAULT 0,
  months_in_tier int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','promoted')),
  founder_note text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS engineer_promotion_candidates_unique_open
  ON public.engineer_promotion_candidates (engineer_user_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS engineer_promotion_candidates_status_idx
  ON public.engineer_promotion_candidates (status, computed_at DESC);

CREATE INDEX IF NOT EXISTS engineer_promotion_candidates_score_idx
  ON public.engineer_promotion_candidates (candidate_score DESC);

ALTER TABLE public.engineer_promotion_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_promotion_candidates_founder_only
  ON public.engineer_promotion_candidates;
CREATE POLICY engineer_promotion_candidates_founder_only
  ON public.engineer_promotion_candidates
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- -------------------------------------------------------------------------
-- TABLE 2: engineer_promotion_decisions
--   Append-only audit trail of every founder action on a candidate row.
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_promotion_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL
    REFERENCES public.engineer_promotion_candidates(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  decision text NOT NULL
    CHECK (decision IN ('approved','rejected','promoted','reset')),
  from_tier text,
  to_tier text,
  note text,
  decided_by uuid,
  decided_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_promotion_decisions_engineer_idx
  ON public.engineer_promotion_decisions (engineer_user_id, decided_at DESC);

CREATE INDEX IF NOT EXISTS engineer_promotion_decisions_candidate_idx
  ON public.engineer_promotion_decisions (candidate_id, decided_at DESC);

ALTER TABLE public.engineer_promotion_decisions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_promotion_decisions_founder_only
  ON public.engineer_promotion_decisions;
CREATE POLICY engineer_promotion_decisions_founder_only
  ON public.engineer_promotion_decisions
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs — all founder-gated, search_path locked, no anon.
-- =========================================================================

-- RPC 1: list pending candidates with score breakdown.
DROP FUNCTION IF EXISTS public.r1651_list_pending_candidates();
CREATE OR REPLACE FUNCTION public.r1651_list_pending_candidates()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  current_tier text,
  proposed_tier text,
  candidate_score numeric,
  jobs_completed int,
  avg_hospital_rating numeric,
  total_revenue_rupees bigint,
  months_in_tier int,
  computed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.engineer_user_id,
    COALESCE(p.full_name, '(unknown)') AS engineer_name,
    c.current_tier,
    c.proposed_tier,
    c.candidate_score,
    c.jobs_completed,
    c.avg_hospital_rating,
    c.total_revenue_rupees,
    c.months_in_tier,
    c.computed_at
  FROM public.engineer_promotion_candidates c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.status = 'pending'
  ORDER BY c.candidate_score DESC NULLS LAST, c.computed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r1651_list_pending_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1651_list_pending_candidates() TO authenticated;

-- RPC 2: list decided history.
DROP FUNCTION IF EXISTS public.r1651_list_decisions(int);
CREATE OR REPLACE FUNCTION public.r1651_list_decisions(p_limit int DEFAULT 100)
RETURNS TABLE (
  decision_id uuid,
  engineer_user_id uuid,
  engineer_name text,
  decision text,
  from_tier text,
  to_tier text,
  note text,
  decided_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id AS decision_id,
    d.engineer_user_id,
    COALESCE(p.full_name, '(unknown)') AS engineer_name,
    d.decision,
    d.from_tier,
    d.to_tier,
    d.note,
    d.decided_at
  FROM public.engineer_promotion_decisions d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  ORDER BY d.decided_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r1651_list_decisions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1651_list_decisions(int) TO authenticated;

-- RPC 3: tier rollup — how many engineers are maxed per tier.
DROP FUNCTION IF EXISTS public.r1651_tier_rollup();
CREATE OR REPLACE FUNCTION public.r1651_tier_rollup()
RETURNS TABLE (
  tier text,
  engineers_in_tier int,
  pending_candidates int,
  approved_awaiting_promotion int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.cached_highest_tier AS tier,
    (COUNT(*) FILTER (WHERE e.cached_highest_tier IS NOT NULL))::int AS engineers_in_tier,
    (SELECT COUNT(*) FROM public.engineer_promotion_candidates c
       WHERE c.current_tier = e.cached_highest_tier AND c.status = 'pending')::int
      AS pending_candidates,
    (SELECT COUNT(*) FROM public.engineer_promotion_candidates c
       WHERE c.current_tier = e.cached_highest_tier AND c.status = 'approved')::int
      AS approved_awaiting_promotion
  FROM public.engineers e
  WHERE e.cached_highest_tier IS NOT NULL
  GROUP BY e.cached_highest_tier
  ORDER BY e.cached_highest_tier;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r1651_tier_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1651_tier_rollup() TO authenticated;

-- RPC 4: console summary scalars.
DROP FUNCTION IF EXISTS public.r1651_summary();
CREATE OR REPLACE FUNCTION public.r1651_summary()
RETURNS TABLE (
  pending_count int,
  approved_count int,
  promoted_last_30d int,
  rejected_last_30d int,
  avg_candidate_score numeric,
  top_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT (COUNT(*) FILTER (WHERE status='pending'))::int
       FROM public.engineer_promotion_candidates) AS pending_count,
    (SELECT (COUNT(*) FILTER (WHERE status='approved'))::int
       FROM public.engineer_promotion_candidates) AS approved_count,
    (SELECT (COUNT(*) FILTER (WHERE decision='promoted' AND decided_at >= now() - interval '30 days'))::int
       FROM public.engineer_promotion_decisions) AS promoted_last_30d,
    (SELECT (COUNT(*) FILTER (WHERE decision='rejected' AND decided_at >= now() - interval '30 days'))::int
       FROM public.engineer_promotion_decisions) AS rejected_last_30d,
    (SELECT ROUND(AVG(candidate_score)::numeric, 2)
       FROM public.engineer_promotion_candidates WHERE status='pending') AS avg_candidate_score,
    (SELECT MAX(candidate_score)
       FROM public.engineer_promotion_candidates WHERE status='pending') AS top_score;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r1651_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1651_summary() TO authenticated;

-- RPC 5 (VOLATILE WRITE): recompute candidate scores from raw job/rating data.
-- Builds a fresh snapshot of pending candidates for every engineer whose
-- recent track record looks tier-top.
DROP FUNCTION IF EXISTS public.r1651_recompute_candidates();
CREATE OR REPLACE FUNCTION public.r1651_recompute_candidates()
RETURNS int
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH job_stats AS (
    SELECT
      rj.engineer_id,
      (COUNT(*) FILTER (WHERE rj.status = 'completed'))::int AS jobs_done,
      AVG(rj.hospital_rating) FILTER (WHERE rj.hospital_rating IS NOT NULL) AS avg_rating,
      COALESCE(SUM(rj.contracted_amount_rupees) FILTER (WHERE rj.status = 'completed'), 0)::bigint
        AS revenue
    FROM public.repair_jobs rj
    WHERE rj.engineer_id IS NOT NULL
    GROUP BY rj.engineer_id
  ),
  eng AS (
    SELECT
      e.id AS engineer_pk,
      e.user_id,
      e.cached_highest_tier AS tier,
      js.jobs_done,
      js.avg_rating,
      js.revenue
    FROM public.engineers e
    LEFT JOIN job_stats js ON js.engineer_id = e.id
    WHERE e.cached_highest_tier IS NOT NULL
  ),
  scored AS (
    SELECT
      user_id,
      tier,
      CASE tier
        WHEN 'bronze' THEN 'silver'
        WHEN 'silver' THEN 'gold'
        WHEN 'gold'   THEN 'platinum'
        ELSE tier
      END AS next_tier,
      COALESCE(jobs_done, 0) AS jobs_done,
      avg_rating,
      COALESCE(revenue, 0) AS revenue,
      -- score: 0.5*jobs + 10*rating + 0.0001*revenue_rupees, clipped 0..100
      LEAST(
        100,
        GREATEST(
          0,
          (COALESCE(jobs_done,0) * 0.5)
          + (COALESCE(avg_rating,0) * 10)
          + (COALESCE(revenue,0) * 0.0001)
        )
      )::numeric(6,2) AS score
    FROM eng
  )
  INSERT INTO public.engineer_promotion_candidates AS c (
    engineer_user_id, current_tier, proposed_tier,
    candidate_score, jobs_completed, avg_hospital_rating,
    total_revenue_rupees, months_in_tier, status, computed_at, updated_at
  )
  SELECT
    s.user_id, s.tier, s.next_tier,
    s.score, s.jobs_done, s.avg_rating, s.revenue,
    0, 'pending', now(), now()
  FROM scored s
  WHERE s.tier <> s.next_tier
    AND s.score >= 60
    AND NOT EXISTS (
      SELECT 1 FROM public.engineer_promotion_candidates x
      WHERE x.engineer_user_id = s.user_id AND x.status = 'pending'
    );

  GET DIAGNOSTICS v_count = ROW_COUNT;

  PERFORM public.log_founder_action(
    'r1651_recompute_candidates',
    jsonb_build_object('inserted', v_count)
  );

  RETURN v_count;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r1651_recompute_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1651_recompute_candidates() TO authenticated;

-- RPC 6 (VOLATILE WRITE): founder approve/reject a candidate.
DROP FUNCTION IF EXISTS public.r1651_decide_candidate(uuid, text, text);
CREATE OR REPLACE FUNCTION public.r1651_decide_candidate(
  p_candidate_id uuid,
  p_decision text,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_decision_id uuid;
  v_engineer uuid;
  v_from text;
  v_to text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'invalid decision: %', p_decision;
  END IF;

  SELECT engineer_user_id, current_tier, proposed_tier
    INTO v_engineer, v_from, v_to
  FROM public.engineer_promotion_candidates
  WHERE id = p_candidate_id AND status = 'pending';

  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'candidate not found or already decided';
  END IF;

  UPDATE public.engineer_promotion_candidates
     SET status = p_decision,
         founder_note = p_note,
         decided_at = now(),
         decided_by = auth.uid(),
         updated_at = now()
   WHERE id = p_candidate_id;

  INSERT INTO public.engineer_promotion_decisions
    (candidate_id, engineer_user_id, decision, from_tier, to_tier, note, decided_by)
  VALUES
    (p_candidate_id, v_engineer, p_decision, v_from, v_to, p_note, auth.uid())
  RETURNING id INTO v_decision_id;

  PERFORM public.log_founder_action(
    'r1651_decide_candidate',
    jsonb_build_object(
      'candidate_id', p_candidate_id,
      'engineer_user_id', v_engineer,
      'decision', p_decision,
      'from_tier', v_from,
      'to_tier', v_to
    )
  );

  RETURN v_decision_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r1651_decide_candidate(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1651_decide_candidate(uuid, text, text) TO authenticated;

-- RPC 7 (VOLATILE WRITE): founder commits an approved candidate's tier change.
DROP FUNCTION IF EXISTS public.r1651_promote_engineer(uuid);
CREATE OR REPLACE FUNCTION public.r1651_promote_engineer(p_candidate_id uuid)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_decision_id uuid;
  v_engineer uuid;
  v_from text;
  v_to text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT engineer_user_id, current_tier, proposed_tier
    INTO v_engineer, v_from, v_to
  FROM public.engineer_promotion_candidates
  WHERE id = p_candidate_id AND status = 'approved';

  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'candidate not approved';
  END IF;

  UPDATE public.engineers
     SET cached_highest_tier = v_to
   WHERE user_id = v_engineer;

  UPDATE public.engineer_promotion_candidates
     SET status = 'promoted',
         updated_at = now()
   WHERE id = p_candidate_id;

  INSERT INTO public.engineer_promotion_decisions
    (candidate_id, engineer_user_id, decision, from_tier, to_tier, note, decided_by)
  VALUES
    (p_candidate_id, v_engineer, 'promoted', v_from, v_to, 'tier committed', auth.uid())
  RETURNING id INTO v_decision_id;

  PERFORM public.log_founder_action(
    'r1651_promote_engineer',
    jsonb_build_object(
      'candidate_id', p_candidate_id,
      'engineer_user_id', v_engineer,
      'from_tier', v_from,
      'to_tier', v_to
    )
  );

  RETURN v_decision_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r1651_promote_engineer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1651_promote_engineer(uuid) TO authenticated;

COMMIT;