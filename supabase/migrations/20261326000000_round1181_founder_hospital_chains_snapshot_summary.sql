BEGIN;

DROP FUNCTION IF EXISTS public.founder_hospital_chains_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_hospital_chains_snapshot_summary()
RETURNS TABLE (
  total_chains              bigint,
  active_chains             bigint,
  paused_chains             bigint,
  offboarded_chains         bigint,
  total_member_hospitals    bigint,
  avg_members_per_chain     numeric,
  members_with_active_amc   bigint,
  amc_coverage_pct          numeric,
  pending_invites           bigint,
  new_chains_30d            bigint,
  new_chains_today          bigint,
  chain_revenue_90d_rupees  numeric,
  chains_zero_amc_coverage  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_total_chains bigint;
  v_total_members bigint;
  v_members_with_amc bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*)::bigint INTO v_total_chains FROM public.hospital_chains;
  IF v_total_chains IS NULL THEN v_total_chains := 0; END IF;

  SELECT count(*)::bigint INTO v_total_members FROM public.hospital_chain_memberships;
  IF v_total_members IS NULL THEN v_total_members := 0; END IF;

  SELECT count(DISTINCT m.hospital_user_id)::bigint INTO v_members_with_amc
    FROM public.hospital_chain_memberships m
   WHERE EXISTS (
     SELECT 1 FROM public.amc_contracts a
      WHERE a.hospital_user_id = m.hospital_user_id
        AND a.status = 'active'
   );
  IF v_members_with_amc IS NULL THEN v_members_with_amc := 0; END IF;

  RETURN QUERY
  SELECT
    v_total_chains,
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains WHERE status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains WHERE status = 'paused'), 0),
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains WHERE status = 'offboarded'), 0),
    v_total_members,
    CASE WHEN v_total_chains = 0 THEN 0::numeric
         ELSE round(v_total_members::numeric / v_total_chains, 2) END,
    v_members_with_amc,
    CASE WHEN v_total_members = 0 THEN 0::numeric
         ELSE round(100.0 * v_members_with_amc::numeric / v_total_members, 1) END,
    coalesce((SELECT count(*)::bigint FROM public.hospital_chain_invites
               WHERE status = 'pending' AND expires_at > now()), 0),
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains
               WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains
               WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((
      SELECT sum(o.amount_rupees)::numeric
        FROM public.amc_payment_orders o
        JOIN public.amc_contracts a ON a.id = o.amc_contract_id
        JOIN public.hospital_chain_memberships m ON m.hospital_user_id = a.hospital_user_id
       WHERE o.status = 'paid'
         AND o.created_at >= now() - interval '90 days'
    ), 0)::numeric
    +
    coalesce((
      SELECT sum(rj.contracted_amount_rupees)::numeric
        FROM public.repair_jobs rj
        JOIN public.hospital_chain_memberships m ON m.hospital_user_id = rj.hospital_user_id
       WHERE rj.status = 'completed'
         AND rj.completed_at >= now() - interval '90 days'
    ), 0)::numeric,
    coalesce((
      SELECT count(*)::bigint FROM public.hospital_chains c
       WHERE EXISTS (SELECT 1 FROM public.hospital_chain_memberships m WHERE m.chain_id = c.id)
         AND NOT EXISTS (
           SELECT 1 FROM public.hospital_chain_memberships m
            JOIN public.amc_contracts a ON a.hospital_user_id = m.hospital_user_id
            WHERE m.chain_id = c.id AND a.status = 'active'
         )
    ), 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_chains_snapshot_summary() TO authenticated;

COMMIT;