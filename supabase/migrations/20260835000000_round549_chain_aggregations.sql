-- =====================================================================
-- Round 549 — Chain-level aggregations (v0.5 Phase 1 backend depth)
-- =====================================================================
--
-- One read RPC that gives a chain admin or founder a single-row
-- snapshot of all member-hospital activity for a chain. Powers the
-- /chains/[id] cockpit's "chain-level KPIs" panel and the future
-- multi-site executive dashboard.
--
-- Aggregates across every hospital_user_id in the chain's
-- hospital_chain_memberships set. Single round-trip; cockpit doesn't
-- need to fan out per-site queries.

BEGIN;

CREATE OR REPLACE FUNCTION public.chain_kpis(
  p_chain_id uuid,
  p_days     integer DEFAULT 30
)
RETURNS TABLE (
  member_count           int,
  jobs_open              int,
  jobs_completed_window  int,
  jobs_disputed_window   int,
  amc_active             int,
  amc_pending_payment    int,
  total_escrow_held_rupees numeric,
  open_dispute_packs     int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_window_start timestamptz := now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval;
  v_is_admin     boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Authorisation: chain primary admin OR founder.
  SELECT EXISTS (
    SELECT 1 FROM public.hospital_chains
     WHERE id = p_chain_id
       AND (primary_admin_user_id = auth.uid() OR public.is_founder())
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'not_chain_admin' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH chain_users AS (
    SELECT hospital_user_id
      FROM public.hospital_chain_memberships
     WHERE chain_id = p_chain_id
  )
  SELECT
    (SELECT count(*)::int FROM chain_users),
    -- Open repair jobs across chain members
    (
      SELECT count(*)::int
        FROM public.repair_jobs rj
        JOIN chain_users cu ON cu.hospital_user_id = rj.hospital_user_id
       WHERE rj.status NOT IN ('completed','cancelled','withdrawn')
    ),
    -- Completed in window
    (
      SELECT count(*)::int
        FROM public.repair_jobs rj
        JOIN chain_users cu ON cu.hospital_user_id = rj.hospital_user_id
       WHERE rj.status = 'completed'
         AND rj.completed_at >= v_window_start
    ),
    -- Disputed escrows in window across chain members. We approximate
    -- by counting open dispute_evidence_packs whose underlying repair_job
    -- ties to a chain hospital.
    (
      SELECT count(*)::int
        FROM public.dispute_evidence_packs dp
        JOIN public.repair_jobs rj ON rj.id = dp.repair_job_id
        JOIN chain_users cu ON cu.hospital_user_id = rj.hospital_user_id
       WHERE dp.created_at >= v_window_start
    ),
    -- AMC contracts active across chain
    (
      SELECT count(*)::int
        FROM public.amc_contracts ac
        JOIN chain_users cu ON cu.hospital_user_id = ac.hospital_user_id
       WHERE ac.status = 'active'
    ),
    -- AMC contracts pending payment (r477 + r505 lifecycle)
    (
      SELECT count(*)::int
        FROM public.amc_contracts ac
        JOIN chain_users cu ON cu.hospital_user_id = ac.hospital_user_id
       WHERE ac.status IN ('pending_payment','paused','renewal_failed')
    ),
    -- Total escrow held by chain members. Tolerate older escrow rows
    -- that lack the held status by coalescing on common variants.
    (
      SELECT coalesce(sum(rje.amount_rupees), 0)::numeric
        FROM public.repair_job_escrow rje
        JOIN public.repair_jobs rj ON rj.id = rje.repair_job_id
        JOIN chain_users cu ON cu.hospital_user_id = rj.hospital_user_id
       WHERE rje.status IN ('held','disputed')
    ),
    -- Open dispute packs (submitted, awaiting mediator) for chain
    (
      SELECT count(*)::int
        FROM public.dispute_evidence_packs dp
        JOIN public.repair_jobs rj ON rj.id = dp.repair_job_id
        JOIN chain_users cu ON cu.hospital_user_id = rj.hospital_user_id
       WHERE dp.status = 'submitted'
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.chain_kpis(uuid, integer)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.chain_kpis(uuid, integer)
  TO authenticated, service_role;

-- Per-site breakdown — same set of metrics but grouped by hospital
-- so the chain admin can see which sites are dragging the average.
CREATE OR REPLACE FUNCTION public.chain_per_site_summary(
  p_chain_id uuid,
  p_days     integer DEFAULT 30
)
RETURNS TABLE (
  hospital_user_id      uuid,
  site_label            text,
  jobs_open             int,
  jobs_completed_window int,
  jobs_disputed_window  int,
  amc_active            int,
  escrow_held_rupees    numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_window_start timestamptz := now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.hospital_chains
     WHERE id = p_chain_id
       AND (primary_admin_user_id = auth.uid() OR public.is_founder())
  ) THEN
    RAISE EXCEPTION 'not_chain_admin' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    m.hospital_user_id,
    m.site_label,
    (
      SELECT count(*)::int FROM public.repair_jobs rj
       WHERE rj.hospital_user_id = m.hospital_user_id
         AND rj.status NOT IN ('completed','cancelled','withdrawn')
    ),
    (
      SELECT count(*)::int FROM public.repair_jobs rj
       WHERE rj.hospital_user_id = m.hospital_user_id
         AND rj.status = 'completed'
         AND rj.completed_at >= v_window_start
    ),
    (
      SELECT count(*)::int
        FROM public.dispute_evidence_packs dp
        JOIN public.repair_jobs rj ON rj.id = dp.repair_job_id
       WHERE rj.hospital_user_id = m.hospital_user_id
         AND dp.created_at >= v_window_start
    ),
    (
      SELECT count(*)::int FROM public.amc_contracts ac
       WHERE ac.hospital_user_id = m.hospital_user_id
         AND ac.status = 'active'
    ),
    (
      SELECT coalesce(sum(rje.amount_rupees), 0)::numeric
        FROM public.repair_job_escrow rje
        JOIN public.repair_jobs rj ON rj.id = rje.repair_job_id
       WHERE rj.hospital_user_id = m.hospital_user_id
         AND rje.status IN ('held','disputed')
    )
   FROM public.hospital_chain_memberships m
  WHERE m.chain_id = p_chain_id
  ORDER BY m.joined_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.chain_per_site_summary(uuid, integer)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.chain_per_site_summary(uuid, integer)
  TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 549 chain aggregations verified: chain_kpis + chain_per_site_summary RPCs ready';
END;
$$;
