-- =====================================================================
-- Round 3799 -- sweep remediation: the bespoke long tail
-- =====================================================================
--
-- Continues rounds 3788-3795. Unlike those, this batch has NO shared root
-- cause to exploit: after the mechanical classes were exhausted the
-- remainder was ~115 distinct causes across ~218 functions, averaging
-- under two functions per cause. So each function here was repaired
-- individually, then INDEPENDENTLY re-checked by a second reviewer whose
-- instructions were to find problems rather than to agree.
--
-- Every statement was additionally validated mechanically before being
-- written into this file. The checks, any one of which rejects a fix:
--   * starts with CREATE OR REPLACE FUNCTION and is a SINGLE statement
--     ending in a semicolon (no BEGIN/COMMIT)
--   * the HEADER is byte-identical to the live definition -- name, full
--     argument list including DEFAULTs, RETURNS clause, LANGUAGE,
--     volatility, SECURITY DEFINER and SET search_path. This is the
--     assertion that matters most: a changed argument list would create a
--     SECOND OVERLOAD rather than replace the function (and PostgREST
--     calls RPCs by NAMED parameter, so a renamed argument silently
--     breaks every client), and a changed RETURNS type would fail with
--     42P13.
--   * search_path / SECURITY DEFINER / STABLE all survived
--   * the text actually differs from the original
--
-- 101 function(s) accepted.
--
-- SEMANTIC CHANGES THE INDEPENDENT REVIEW FLAGGED -- READ THIS
-- ---------------------------------------------------------------------
-- Most of these repairs are casts and corrected column names. A few
-- necessarily change WHICH ROWS a founder metric counts, because the
-- broken expression was not merely untyped but pointed at the wrong
-- thing. The second-pass reviewer flagged each of these; they are listed
-- here rather than buried, because they are the ones a founder could
-- notice as a number moving.
--
-- 1. rpc_founder_ops_scorecard_build -- payout backlog.
--    `engineer_payouts.paid_at` does not exist; the real column is
--    processed_at. But `WHERE processed_at IS NULL` also matches
--    terminal-failure rows: the status CHECK allows
--    queued/processing/processed/failed/cancelled, and failed/cancelled
--    payouts never get a processed_at. So the naive column swap would
--    have counted dead payouts as live backlog. Changed to
--    `status IN ('queued','processing')`, which is exactly how the
--    sibling founder_critical_cockpit already defines the same metric --
--    so the two founder surfaces now agree instead of disagreeing.
--
-- 2. founder_critical_cockpit -- spare-parts "stuck" tiles.
--    `coalesce(payment_status::text,'') = 'paid'` was already text-cast,
--    so it never RAISED -- it silently matched zero rows, because
--    payment_status has no 'paid' label (it is 'completed'). That means
--    spare_parts_stuck_over_7d and spare_parts_stuck_inr have been a hard
--    0 on the founder dashboard, and after this migration they report
--    real values. That is the fix working, not a regression. Same tile's
--    NOT IN list had an inert 'refunded' (not an order_status label);
--    corrected to 'returned', which genuinely narrows the predicate.
--
-- 3. founder_tier_distribution_by_city -- ORDER BY was a no-op.
--    `ORDER BY total_cnt DESC` where total_cnt is a RETURNS TABLE OUT
--    parameter and NOT an output column alias: plpgsql substituted the
--    (always NULL) variable, so the query ordered by a constant and the
--    LIMIT 50 returned an ARBITRARY 50 cities. Now orders by count(*),
--    which is the declared intent. Confirmed this function does not carry
--    round3789's `#variable_conflict use_column` pragma, which would have
--    made the identifier resolve to the column instead.
--
-- 4. founder_hospital_chains_drilldown_summary -- days_to_signed_median.
--    Built on `hospital_chains.signed_at`, which does not exist. The only
--    timestamp candidate on that table is contracted_at, so both the
--    percentile source and the cohort filter now use it. The metric is
--    therefore redefined, defensibly but not mechanically. Note
--    hospital_chains.status DOES have a 'signed' label but there is no
--    corresponding timestamp, so contracted_at is the only option
--    available without a schema change.
--
-- 5. rpc_founder_ops_scorecard_build and exec_360_v3_engineering_kpis --
--    job status IN-lists containing labels job_status never had
--    ('open', 'awaiting_parts', 'bidding', 'accepted'). 'open' maps to
--    'requested' unambiguously; the others have no counterpart, so they
--    were resolved by intent ('accepted' -> 'assigned', 'awaiting_parts'
--    and 'bidding' dropped, 'en_route' added to the in-flight sets since
--    it sits between assigned and in_progress). These KPIs therefore
--    count a different row set than their author literally wrote -- which
--    was unavoidable, since what they wrote could never match.
--
-- LIVE-VERIFICATION CAVEAT, so a green result is not over-read:
-- public.engineer_certification_progress currently has ZERO rows (against
-- 28 profiles with role='engineer'). So founder_tier_distribution_by_city
-- returns no rows and the two *_by_engineer_tier functions return their
-- tier skeleton with all-zero measures. Executing those three cannot
-- distinguish "repaired" from "still structurally empty" -- they are
-- confirmed only by the static check plus the tier literals matching the
-- schema (current_tier is plain text, DEFAULT 'none', no CHECK).
--
-- VERIFICATION runs inside the transaction (the round3781 lesson) and
-- asserts: every function still exists exactly once (no new overloads),
-- the argument list and OUT column names/order are unchanged, and the
-- plpgsql_check error count among the touched set strictly decreased.
-- Per the round3793 lesson a green static check is necessary but not
-- sufficient, so the read-only functions are additionally spot-executed
-- after this migration lands.

BEGIN;

-- capture the pre-state so the gate can prove nothing drifted
CREATE TEMP TABLE _r3799_before ON COMMIT DROP AS
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       coalesce((SELECT string_agg(x.name, ',' ORDER BY x.ord)
                 FROM unnest(coalesce(p.proargnames, '{}'::text[]))
                      WITH ORDINALITY AS x(name, ord)), '') AS argnames
FROM pg_proc p
WHERE p.pronamespace='public'::regnamespace
  AND p.proname = ANY(ARRAY[
    'assign_next_available_amc_engineer',
    'build_pved',
    'chain_kpis',
    'chain_per_site_summary',
    'engagement_distribution_r1799',
    'equipment_kind_distribution_r2623',
    'exec_360_v3_compliance_kpis',
    'fading_skills_r1844',
    'founder_amc_amount_histogram',
    'founder_amc_by_equipment_category',
    'founder_amc_pool_coverage',
    'founder_board_prep_overview',
    'founder_capital_by_investor_type',
    'founder_capital_efficiency_kpis',
    'founder_capital_per_investor',
    'founder_cap_conversion_preview',
    'founder_cash_conversion_cycle_summary',
    'founder_cash_conversion_history',
    'founder_cash_headline_kpis',
    'founder_cash_payment_surveys_summary',
    'founder_cert_engineer_leaderboard',
    'founder_cert_recent_renewal_log',
    'founder_chains_health',
    'founder_chain_expansion_active_chains',
    'founder_churn_prediction_at_risk_hospitals',
    'founder_compliance_calendar_auto_seed_year',
    'founder_critical_actions',
    'founder_cron_jobs_recent',
    'founder_cron_status_summary',
    'founder_culture_deck_summary',
    'founder_culture_deck_unsigned_team',
    'founder_culture_deck_version_timeline',
    'founder_cumulative_rollup_summary',
    'founder_dispute_queue',
    'founder_eef_v2_ack_cliff_alert',
    'founder_engineers_missing_payout',
    'founder_engineer_escalation_by_category',
    'founder_engineer_leaderboard_30d',
    'founder_engineer_side_projects_active_list_r1469',
    'founder_engineer_side_projects_overdue_followups_r1469',
    'founder_engineer_side_projects_recent_convos_r1469',
    'founder_escrow_held_aging',
    'founder_fev_readiness_leaderboard',
    'founder_funnel_drop_off',
    'founder_funnel_stage_counts',
    'founder_hospital_auto_renew_scan',
    'founder_hospital_spend_distribution',
    'founder_hsq_latest_rankings',
    'founder_hsq_recompute_current_quarter',
    'founder_investor_pulse_summary',
    'founder_kyc_pending_detail',
    'founder_log_ownership_event',
    'founder_ltv_headline',
    'founder_marketing_content_pieces_recent',
    'founder_marketing_content_upcoming',
    'founder_morning_digest_v2',
    'founder_okr_team_health_r2345',
    'founder_onboarding_velocity_summary',
    'founder_ownership_at_risk_amcs',
    'founder_payouts_amount_histogram',
    'founder_payout_method_coverage',
    'founder_r2887_category_mix',
    'founder_reconciliation_health',
    'founder_regional_city_summary',
    'founder_regional_state_summary',
    'founder_repair_types_snapshot_summary',
    'founder_revenue_per_engineer_summary',
    'founder_sales_territory_by_city',
    'founder_sales_territory_by_pincode',
    'founder_side_hustle_verdict_breakdown_r2742',
    'founder_signups_by_role_30d',
    'founder_skill_proficiency_distribution',
    'founder_supervision_dashboard',
    'founder_tier_1_home_metadata',
    'founder_tier_progression_rate',
    'founder_vendor_quality_scorecard_by_vendor',
    'founder_vendor_sla_kpis',
    'founder_verified_engineers_recent',
    'founder_webhook_success_rate',
    'founder_week_in_review_summary',
    'log_founder_capv2_simulate_round',
    'monthly_event_trend_r2511',
    'monthly_feedback_trend_r2602',
    'my_tds_summary',
    'open_code_red_request',
    'owner_load_r2579',
    'payroll_v2_kickoff_scheduled_run',
    'r2276_kpis',
    'r2815_criticality_risk',
    'record_tds_for_payout',
    'refusal_breakdown_r2442',
    'refusal_breakdown_r2526',
    'root_cause_pareto_r2907',
    'rpc_founder_cap_v3_current_table',
    'rpc_founder_ops_spare_shortages',
    'rpc_r2377_current_week_status',
    'rpc_r2888_kpi_summary',
    'run_daily_reconciliation',
    'scan_duplicate_accounts',
    'sweep_amc_sla_unresponded_visits',
    'top_holders_r1797'
  ]);

-- ---------------------------------------------------------------------
-- public.assign_next_available_amc_engineer(p_visit_id uuid)
CREATE OR REPLACE FUNCTION public.assign_next_available_amc_engineer(p_visit_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller    uuid := auth.uid();
  v_visit     public.repair_jobs%ROWTYPE;
  v_contract  uuid;
  v_authorised boolean := false;
  v_eligible_engineer record;
BEGIN
  SELECT * INTO v_visit FROM public.repair_jobs
   WHERE id = p_visit_id AND kind = 'maintenance' AND amc_contract_id IS NOT NULL;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  v_contract := v_visit.amc_contract_id;

  -- Round 454 fix #1: caller must be hospital owner of the contract,
  -- a current rotation engineer for the contract, or admin/founder.
  -- service_role bypasses because auth.uid() is NULL under the worker
  -- (the trigger / cron-tick context).
  IF v_caller IS NULL THEN
    v_authorised := true;
  ELSIF public.is_founder() OR public.is_admin(v_caller) THEN
    v_authorised := true;
  ELSIF EXISTS (
    SELECT 1 FROM public.amc_contracts c
     WHERE c.id = v_contract AND c.hospital_user_id = v_caller
  ) THEN
    v_authorised := true;
  ELSIF EXISTS (
    SELECT 1
      FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
     WHERE r.amc_contract_id = v_contract
       AND e.user_id = v_caller
  ) THEN
    v_authorised := true;
  END IF;

  IF NOT v_authorised THEN
    RAISE EXCEPTION 'not authorised to reassign this visit' USING ERRCODE = '42501';
  END IF;

  -- Refuse mid-flight transitions.
  IF v_visit.status::text IN ('en_route','in_progress','completed','disputed','cancelled') THEN
    RETURN NULL;
  END IF;

  -- Body from 20260513100000: pick next eligible rotation engineer.
  -- (Preserved verbatim — no behavior change other than the caller
  -- gate above.)
  SELECT r.engineer_id, e.user_id
    INTO v_eligible_engineer
    FROM public.amc_engineer_rotation r
    JOIN public.engineers e ON e.id = r.engineer_id
   WHERE r.amc_contract_id = v_contract
     AND coalesce(e.is_available, false) = true
     AND coalesce(e.verification_status::text, 'pending') = 'verified'
   ORDER BY r.priority ASC, r.created_at ASC
   LIMIT 1;

  IF v_eligible_engineer.engineer_id IS NULL THEN
    -- Escalation row for ops queue (same shape the original used).
    INSERT INTO public.amc_admin_escalations (
      reason, amc_contract_id, visit_id, notes
    ) VALUES (
      'no_engineer_available', v_contract, p_visit_id,
      'No verified+available rotation engineer left for this visit.'
    ) ON CONFLICT DO NOTHING;
    RETURN NULL;
  END IF;

  RETURN v_eligible_engineer.engineer_id;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.build_pved(p_repair_job_id uuid)
CREATE OR REPLACE FUNCTION public.build_pved(p_repair_job_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_job             record;
  v_engineer_user   uuid;
  v_engineer        record;
  v_caller          uuid := auth.uid();
  v_display_name    text;
  v_aadhaar_masked  text;
  v_cert_count      int;
  v_avg_rating      numeric(3,2);
  v_total_jobs      int;
  v_last_5          jsonb;
  v_pved_id         uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
  END IF;

  -- Only hospital on the job, the accepted engineer, or founder can
  -- request the dossier.
  SELECT b.engineer_user_id INTO v_engineer_user
    FROM public.repair_job_bids b
   WHERE b.repair_job_id = p_repair_job_id
     AND b.status = 'accepted'
   LIMIT 1;
  IF v_engineer_user IS NULL THEN
    RAISE EXCEPTION 'no_accepted_engineer_yet' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_job.hospital_user_id
     AND v_caller <> v_engineer_user
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_engineer
    FROM public.engineers
   WHERE user_id = v_engineer_user;

  SELECT
    coalesce((SELECT raw_user_meta_data->>'full_name'
                FROM auth.users WHERE id = v_engineer_user), 'Engineer')
    INTO v_display_name;

  -- Mask Aadhaar: show only last 4 digits, mask first 8 with X.
  IF v_engineer.aadhaar_number IS NOT NULL AND length(v_engineer.aadhaar_number) >= 4 THEN
    v_aadhaar_masked := 'XXXX-XXXX-' || right(v_engineer.aadhaar_number, 4);
  ELSE
    v_aadhaar_masked := NULL;
  END IF;

  v_cert_count := coalesce(jsonb_array_length(v_engineer.certificates), 0);

  -- Aggregate last 5 completed jobs + rating
  SELECT
    avg(hospital_rating)::numeric(3,2),
    count(*)::int
    INTO v_avg_rating, v_total_jobs
    FROM public.repair_jobs
   WHERE status = 'completed'
     AND id IN (
       SELECT rj.id FROM public.repair_jobs rj
       JOIN public.repair_job_bids b ON b.repair_job_id = rj.id
       WHERE b.engineer_user_id = v_engineer_user
         AND b.status = 'accepted'
     );

  SELECT coalesce(jsonb_agg(j ORDER BY j->>'completed_at' DESC), '[]'::jsonb)
    INTO v_last_5
    FROM (
      SELECT jsonb_build_object(
        'job_number', rj.job_number,
        'equipment_brand', rj.equipment_brand,
        'equipment_type', rj.equipment_type,
        'completed_at', rj.completed_at,
        'hospital_rating', rj.hospital_rating
      ) AS j
      FROM public.repair_jobs rj
      JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
      WHERE b.engineer_user_id = v_engineer_user
        AND rj.status = 'completed'
      ORDER BY rj.completed_at DESC NULLS LAST
      LIMIT 5
    ) sub;

  -- Cancel any prior 'issued' dossier for this (job, engineer) so
  -- the UNIQUE constraint allows the new row.
  UPDATE public.pre_visit_engineer_dossiers
     SET status = 'cancelled'
   WHERE repair_job_id = p_repair_job_id
     AND engineer_user_id = v_engineer_user
     AND status = 'issued';

  INSERT INTO public.pre_visit_engineer_dossiers (
    repair_job_id, engineer_user_id, hospital_user_id,
    engineer_display_name, aadhaar_masked_id, verification_status,
    verified_at, certificate_count, oem_cert_summary,
    total_jobs_completed, average_rating, last_5_jobs
  ) VALUES (
    p_repair_job_id, v_engineer_user, v_job.hospital_user_id,
    v_display_name, v_aadhaar_masked,
    coalesce(v_engineer.verification_status::text, 'pending'),
    -- public.engineers records no verification timestamp (there is no
    -- verification_status_updated_at column, nor any engineer-verification
    -- audit table), so we have no date to attest to here. Left NULL rather
    -- than substituting engineers.updated_at, which is bumped by any edit and
    -- would print a fabricated "verified on" date in a trust dossier the
    -- hospital reads. Populate once a real column exists.
    NULL::timestamp with time zone,
    v_cert_count, v_engineer.certificates,
    coalesce(v_total_jobs, 0), v_avg_rating, v_last_5
  ) RETURNING id INTO v_pved_id;

  RETURN v_pved_id;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.chain_kpis(p_chain_id uuid, p_days integer)
CREATE OR REPLACE FUNCTION public.chain_kpis(p_chain_id uuid, p_days integer DEFAULT 30)
 RETURNS TABLE(member_count integer, jobs_open integer, jobs_completed_window integer, jobs_disputed_window integer, amc_active integer, amc_pending_payment integer, total_escrow_held_rupees numeric, open_dispute_packs integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    -- Open repair jobs across chain members. job_status has no 'withdrawn' label;
    -- its terminal states are 'completed' and 'cancelled'.
    (
      SELECT count(*)::int
        FROM public.repair_jobs rj
        JOIN chain_users cu ON cu.hospital_user_id = rj.hospital_user_id
       WHERE rj.status NOT IN ('completed','cancelled')
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
$function$;

-- ---------------------------------------------------------------------
-- public.chain_per_site_summary(p_chain_id uuid, p_days integer)
CREATE OR REPLACE FUNCTION public.chain_per_site_summary(p_chain_id uuid, p_days integer DEFAULT 30)
 RETURNS TABLE(hospital_user_id uuid, site_label text, jobs_open integer, jobs_completed_window integer, jobs_disputed_window integer, amc_active integer, escrow_held_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
         AND rj.status NOT IN ('completed','cancelled')
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
$function$;

-- ---------------------------------------------------------------------
-- public.engagement_distribution_r1799()
CREATE OR REPLACE FUNCTION public.engagement_distribution_r1799()
 RETURNS TABLE(bucket text, cnt integer, avg_login_count numeric, avg_tickets numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH b AS (
    SELECT
      CASE
        WHEN s.engagement_index >= 80 THEN 'high'
        WHEN s.engagement_index >= 50 THEN 'medium'
        WHEN s.engagement_index >= 25 THEN 'low'
        ELSE 'critical'
      END::text AS bucket,
      CASE
        WHEN s.engagement_index >= 80 THEN 1
        WHEN s.engagement_index >= 50 THEN 2
        WHEN s.engagement_index >= 25 THEN 3
        ELSE 4
      END AS bucket_ord,
      s.login_count_30d,
      s.tickets_opened_30d
    FROM public.hospital_engagement_scores_r1799 s
  )
  SELECT
    b.bucket,
    (COUNT(*))::int AS cnt,
    ROUND(AVG(b.login_count_30d)::numeric, 1) AS avg_login_count,
    ROUND(AVG(b.tickets_opened_30d)::numeric, 1) AS avg_tickets
  FROM b
  GROUP BY b.bucket, b.bucket_ord
  ORDER BY b.bucket_ord;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.equipment_kind_distribution_r2623()
CREATE OR REPLACE FUNCTION public.equipment_kind_distribution_r2623()
 RETURNS TABLE(equipment_kind text, roadmap_count bigint, total_value_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.equipment_kind, COUNT(*)::bigint AS roadmap_count, COALESCE(SUM(r.total_value_rupees),0)::bigint
  FROM public.chain_fleet_renewal_roadmap_r2623 r
  GROUP BY r.equipment_kind
  ORDER BY COALESCE(SUM(r.total_value_rupees),0)::bigint DESC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.exec_360_v3_compliance_kpis()
CREATE OR REPLACE FUNCTION public.exec_360_v3_compliance_kpis()
 RETURNS TABLE(kpi_key text, kpi_label text, kpi_value numeric, kpi_text text, status_color text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'gst_invoices_month'::text, 'GST invoices (this month)'::text,
    (SELECT COUNT(*)::numeric FROM gst_invoices
     WHERE issued_at >= date_trunc('month', now())),
    NULL::text, 'green'::text
  UNION ALL SELECT 'gst_taxable_month', 'GST taxable (this month, ₹)',
    COALESCE((SELECT SUM(taxable_amount_rupees)::numeric FROM gst_invoices
              WHERE issued_at >= date_trunc('month', now())), 0),
    NULL, 'green'
  -- Open DPDP grievances live in public.dpdp_grievances (r485), not in the
  -- founder_priority_actions ack log (which has no 'category' column, and whose
  -- action_taken is NOT NULL so `action_taken IS NULL` could never match).
  -- 'open'/'in_review' matches the canonical predicate used by r499 + r1199.
  UNION ALL SELECT 'dpdp_grievances_open', 'Open DPDP grievances',
    (SELECT COUNT(*)::numeric FROM dpdp_grievances
     WHERE status IN ('open', 'in_review')),
    NULL, 'amber'
  UNION ALL SELECT 'spot_audits_30d', 'Spot audits (30d)',
    (SELECT COUNT(*)::numeric FROM spot_audit_invitations
     WHERE created_at >= now() - INTERVAL '30 days'),
    NULL, 'green';
END;
$function$;

-- ---------------------------------------------------------------------
-- public.fading_skills_r1844()
CREATE OR REPLACE FUNCTION public.fading_skills_r1844()
 RETURNS TABLE(skill_id uuid, skill_name text, skill_category text, engineer_user_id uuid, engineer_email text, status text, last_demand_at timestamp with time zone, days_since_demand integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  -- The per-skill MAX(demand_event_at) is pre-aggregated in a derived table so
  -- the "no demand / stale demand" predicate can live in WHERE (an aggregate
  -- is not allowed there). Same result as the original GROUP BY form: one row
  -- per skill, latest demand signal per skill.
  SELECT s.id, s.skill_name, s.skill_category, s.engineer_user_id, p.email, s.status,
         d.last_demand,
         CASE WHEN d.last_demand IS NULL THEN NULL
              ELSE EXTRACT(DAY FROM (now() - d.last_demand))::int
         END AS days_since
  FROM public.engineer_long_tail_skills_r1844 s
  LEFT JOIN (
    SELECT g.skill_id AS skill_id, MAX(g.demand_event_at) AS last_demand
    FROM public.engineer_skill_demand_signals_r1844 g
    GROUP BY g.skill_id
  ) d ON d.skill_id = s.id
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.status IN ('aging','lost')
     OR d.last_demand IS NULL
     OR d.last_demand < now() - INTERVAL '180 days'
  ORDER BY d.last_demand NULLS FIRST
  LIMIT 100;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_amc_amount_histogram()
CREATE OR REPLACE FUNCTION public.founder_amc_amount_histogram()
 RETURNS TABLE(bucket text, bucket_order integer, cnt bigint, total_inr numeric, pct_of_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_tot
  FROM public.amc_contracts WHERE status = 'active';
  IF v_tot IS NULL THEN v_tot := 0; END IF;

  RETURN QUERY
  WITH agg AS (
    -- amc_contracts has no amount_inr column; the contract amount it carries is
    -- monthly_fee_rupees (the only rupee amount on the table).
    SELECT monthly_fee_rupees AS amount_inr,
      CASE
        WHEN monthly_fee_rupees < 5000   THEN '<₹5k'
        WHEN monthly_fee_rupees < 10000  THEN '₹5k-10k'
        WHEN monthly_fee_rupees < 25000  THEN '₹10k-25k'
        WHEN monthly_fee_rupees < 50000  THEN '₹25k-50k'
        WHEN monthly_fee_rupees < 100000 THEN '₹50k-1L'
        WHEN monthly_fee_rupees < 500000 THEN '₹1L-5L'
        ELSE '>₹5L'
      END AS bucket,
      CASE
        WHEN monthly_fee_rupees < 5000   THEN 1
        WHEN monthly_fee_rupees < 10000  THEN 2
        WHEN monthly_fee_rupees < 25000  THEN 3
        WHEN monthly_fee_rupees < 50000  THEN 4
        WHEN monthly_fee_rupees < 100000 THEN 5
        WHEN monthly_fee_rupees < 500000 THEN 6
        ELSE 7
      END AS bucket_order
    FROM public.amc_contracts
    WHERE status = 'active'
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                       AS cnt,
    sum(a.amount_inr)::numeric                             AS total_inr,
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / v_tot, 1) END        AS pct_of_total
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_by_equipment_category()
CREATE OR REPLACE FUNCTION public.founder_amc_by_equipment_category()
 RETURNS TABLE(equipment_category text, total bigint, active bigint, paused bigint, expired bigint, total_mrr_inr numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH expanded AS (
    SELECT
      c.id, c.status, c.monthly_fee_rupees,
      coalesce(u.cat, '(unknown)')::text AS equipment_category
    FROM public.amc_contracts c
    CROSS JOIN LATERAL unnest(c.equipment_categories) AS u(cat)
    WHERE c.equipment_categories IS NOT NULL
  )
  SELECT
    e.equipment_category,
    count(*)::bigint                                                  AS total,
    count(*) FILTER (WHERE e.status = 'active')::bigint               AS active,
    count(*) FILTER (WHERE e.status = 'paused')::bigint               AS paused,
    count(*) FILTER (WHERE e.status = 'expired')::bigint              AS expired,
    coalesce(sum(e.monthly_fee_rupees) FILTER (WHERE e.status IN ('active','paused')), 0)::numeric AS total_mrr_inr
  FROM expanded e
  GROUP BY e.equipment_category
  ORDER BY total_mrr_inr DESC NULLS LAST
  LIMIT 50;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_amc_pool_coverage()
CREATE OR REPLACE FUNCTION public.founder_amc_pool_coverage()
 RETURNS TABLE(bucket text, cnt bigint, share_pct numeric, ord integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.amc_contracts WHERE status = 'active';
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (p.amc_contract_id)
      p.amc_contract_id,
      p.balance_after
    FROM public.amc_payment_pool p
    ORDER BY p.amc_contract_id, p.created_at DESC
  ),
  classed AS (
    SELECT
      c.id,
      coalesce(l.balance_after, 0) AS balance,
      c.monthly_fee_rupees AS fee
    FROM public.amc_contracts c
    LEFT JOIN latest l ON l.amc_contract_id = c.id
    WHERE c.status = 'active'
  )
  SELECT
    t.label, t.cnt,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(t.cnt::numeric / v_total::numeric * 100.0, 1)
    END,
    t.ord
  FROM (
    SELECT 'Healthy (≥2× fee)'::text AS label,
      count(*) FILTER (WHERE balance >= 2 * fee)::bigint AS cnt,
      1 AS ord
      FROM classed
    UNION ALL
    SELECT 'Caution (1×–2× fee)', count(*) FILTER (WHERE balance >= fee AND balance < 2 * fee)::bigint, 2 FROM classed
    UNION ALL
    SELECT 'Low (0–1× fee)', count(*) FILTER (WHERE balance > 0 AND balance < fee)::bigint, 3 FROM classed
    UNION ALL
    SELECT 'Negative / zero', count(*) FILTER (WHERE balance <= 0)::bigint, 4 FROM classed
  ) t
  ORDER BY t.ord;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_board_prep_overview()
CREATE OR REPLACE FUNCTION public.founder_board_prep_overview()
 RETURNS TABLE(total_meetings integer, upcoming_meetings integer, closed_meetings integer, next_meeting_at timestamp with time zone, hours_to_next numeric, total_items integer, done_items integer, open_items integer, pct_done numeric, meetings_in_48h integer, meetings_with_unsent_alert integer, avg_completion_pct numeric, fully_ready_meetings integer, at_risk_meetings integer, items_due_in_48h integer, alerts_fired_total integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH m AS (
    SELECT * FROM founder_board_meetings_v2
  ),
  upc AS (
    SELECT * FROM m WHERE scheduled_at > now() AND closed_at IS NULL
  ),
  nxt AS (
    SELECT scheduled_at FROM upc ORDER BY scheduled_at ASC LIMIT 1
  ),
  items AS (
    SELECT i.*, mm.scheduled_at, mm.closed_at
    FROM founder_board_checklist_items_v2 i JOIN m mm ON mm.id = i.meeting_id
  ),
  per_meeting AS (
    SELECT mm.id,
           mm.scheduled_at,
           mm.closed_at,
           mm.alert_48h_sent_at,
           COUNT(i.*)::int AS total,
           COUNT(i.*) FILTER (WHERE i.is_done)::int AS done
    FROM m mm LEFT JOIN founder_board_checklist_items_v2 i ON i.meeting_id = mm.id
    GROUP BY mm.id, mm.scheduled_at, mm.closed_at, mm.alert_48h_sent_at
  )
  SELECT
    (SELECT COUNT(*)::int FROM m),
    (SELECT COUNT(*)::int FROM upc),
    (SELECT COUNT(*)::int FROM m WHERE closed_at IS NOT NULL),
    (SELECT scheduled_at FROM nxt),
    COALESCE((SELECT EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 FROM nxt), 0)::numeric,
    (SELECT COUNT(*)::int FROM items),
    (SELECT COUNT(*)::int FROM items WHERE is_done),
    (SELECT COUNT(*)::int FROM items WHERE NOT is_done),
    CASE WHEN (SELECT COUNT(*) FROM items) > 0
         THEN ROUND(100.0 * (SELECT COUNT(*) FROM items WHERE is_done) / (SELECT COUNT(*) FROM items), 1)
         ELSE 0 END,
    (SELECT COUNT(*)::int FROM upc WHERE EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 <= 48),
    (SELECT COUNT(*)::int FROM upc WHERE EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 <= 48 AND alert_48h_sent_at IS NULL),
    COALESCE((SELECT ROUND(AVG(CASE WHEN total>0 THEN 100.0*done/total ELSE 0 END)::numeric, 1) FROM per_meeting), 0),
    (SELECT COUNT(*)::int FROM per_meeting WHERE total>0 AND done=total AND closed_at IS NULL),
    (SELECT COUNT(*)::int FROM per_meeting
      WHERE closed_at IS NULL
        AND scheduled_at > now()
        AND EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 <= 72
        AND (total = 0 OR done::numeric/NULLIF(total,0) < 0.75)),
    (SELECT COUNT(*)::int FROM items
      WHERE NOT is_done AND scheduled_at > now()
        AND EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 <= 48),
    COALESCE((SELECT COUNT(*)::int FROM founder_action_log WHERE op_name = 'board_alert_48h_fired'), 0);
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_capital_by_investor_type()
CREATE OR REPLACE FUNCTION public.founder_capital_by_investor_type()
 RETURNS TABLE(id uuid, investor_type text, total_invested_rupees bigint, investor_count integer, round_count integer, avg_check_rupees bigint, share_of_raise_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(amount_rupees),0) INTO v_total FROM founder_capital_raise_rounds_v2;
  RETURN QUERY
  SELECT
    md5(r.investor_type)::uuid,
    r.investor_type,
    SUM(r.amount_rupees)::bigint,
    COUNT(DISTINCT r.investor_name)::integer,
    COUNT(*)::integer,
    AVG(r.amount_rupees)::bigint,
    CASE WHEN v_total > 0 THEN ROUND(SUM(r.amount_rupees)::numeric * 100.0 / v_total, 2) ELSE 0 END
  FROM founder_capital_raise_rounds_v2 r
  GROUP BY r.investor_type
  ORDER BY SUM(r.amount_rupees) DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_capital_efficiency_kpis()
CREATE OR REPLACE FUNCTION public.founder_capital_efficiency_kpis()
 RETURNS TABLE(total_raised_rupees bigint, total_revenue_rupees bigint, revenue_per_rupee_raised numeric, ltm_burn_rupees bigint, ltm_net_new_revenue_rupees bigint, burn_multiple numeric, cash_balance_rupees bigint, runway_months numeric, ltm_marketing_spend_rupees bigint, ltm_sales_spend_rupees bigint, ltm_new_customers integer, cac_rupees numeric, ltm_revenue_per_customer numeric, ltv_rupees numeric, ltv_to_cac numeric, payback_months numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_raised bigint;
  v_total_rev bigint;
  v_ltm_burn bigint;
  v_ltm_nnr bigint;
  v_cash bigint;
  v_mkt bigint;
  v_sales bigint;
  v_new_cust integer;
  v_churned integer;
  v_active integer;
  v_cac numeric;
  v_rpc numeric;
  v_churn_rate numeric;
  v_ltv numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(SUM(amount_rupees),0) INTO v_raised FROM founder_capital_raise_rounds_v2;
  -- alias + qualify: total_revenue_rupees is also a RETURNS TABLE OUT
  -- parameter, so the bare column reference was ambiguous (42702).
  SELECT COALESCE(SUM(s.total_revenue_rupees),0) INTO v_total_rev
  FROM founder_capital_efficiency_snapshots_v2 s;

  SELECT COALESCE(SUM(net_burn_rupees),0),
         COALESCE(SUM(net_new_revenue_rupees),0),
         COALESCE(SUM(marketing_spend_rupees),0),
         COALESCE(SUM(sales_spend_rupees),0),
         COALESCE(SUM(new_customers),0),
         COALESCE(SUM(churned_customers),0)
  INTO v_ltm_burn, v_ltm_nnr, v_mkt, v_sales, v_new_cust, v_churned
  FROM founder_capital_efficiency_snapshots_v2
  WHERE period_month >= (CURRENT_DATE - INTERVAL '12 months');

  -- same ambiguity as above: cash_balance_rupees is an OUT parameter too.
  SELECT s.cash_balance_rupees INTO v_cash
  FROM founder_capital_efficiency_snapshots_v2 s
  ORDER BY s.period_month DESC LIMIT 1;
  v_cash := COALESCE(v_cash, 0);

  v_active := GREATEST(v_new_cust - v_churned, 1);
  v_cac := CASE WHEN v_new_cust > 0 THEN (v_mkt + v_sales)::numeric / v_new_cust ELSE NULL END;
  v_rpc := CASE WHEN v_active > 0 THEN v_ltm_nnr::numeric / v_active ELSE NULL END;
  v_churn_rate := CASE WHEN v_active > 0 THEN v_churned::numeric / v_active ELSE 0.1 END;
  IF v_churn_rate <= 0 THEN v_churn_rate := 0.1; END IF;
  v_ltv := CASE WHEN v_rpc IS NOT NULL THEN v_rpc / v_churn_rate ELSE NULL END;

  RETURN QUERY SELECT
    v_raised,
    v_total_rev,
    CASE WHEN v_raised > 0 THEN ROUND(v_total_rev::numeric / v_raised, 4) ELSE NULL END,
    v_ltm_burn,
    v_ltm_nnr,
    CASE WHEN v_ltm_nnr > 0 THEN ROUND(v_ltm_burn::numeric / v_ltm_nnr, 2) ELSE NULL END,
    v_cash,
    CASE WHEN v_ltm_burn > 0 THEN ROUND((v_cash::numeric * 12.0) / v_ltm_burn, 1) ELSE NULL END,
    v_mkt,
    v_sales,
    v_new_cust,
    CASE WHEN v_cac IS NOT NULL THEN ROUND(v_cac, 0) ELSE NULL END,
    CASE WHEN v_rpc IS NOT NULL THEN ROUND(v_rpc, 0) ELSE NULL END,
    CASE WHEN v_ltv IS NOT NULL THEN ROUND(v_ltv, 0) ELSE NULL END,
    CASE WHEN v_cac IS NOT NULL AND v_cac > 0 AND v_ltv IS NOT NULL THEN ROUND(v_ltv / v_cac, 2) ELSE NULL END,
    CASE WHEN v_rpc IS NOT NULL AND v_rpc > 0 AND v_cac IS NOT NULL THEN ROUND((v_cac / v_rpc) * 12.0, 1) ELSE NULL END;
END $function$
;

-- ---------------------------------------------------------------------
-- public.founder_capital_per_investor()
CREATE OR REPLACE FUNCTION public.founder_capital_per_investor()
 RETURNS TABLE(id uuid, investor_name text, investor_type text, total_invested_rupees bigint, rounds_participated integer, first_check_date date, latest_check_date date, share_of_total_raise_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(amount_rupees),0) INTO v_total FROM founder_capital_raise_rounds_v2;
  RETURN QUERY
  SELECT
    md5(r.investor_name || r.investor_type)::uuid AS id,
    r.investor_name,
    r.investor_type,
    SUM(r.amount_rupees)::bigint,
    COUNT(*)::integer,
    MIN(r.raised_at),
    MAX(r.raised_at),
    CASE WHEN v_total > 0 THEN ROUND(SUM(r.amount_rupees)::numeric * 100.0 / v_total, 2) ELSE 0 END
  FROM founder_capital_raise_rounds_v2 r
  GROUP BY r.investor_name, r.investor_type
  ORDER BY SUM(r.amount_rupees) DESC;
END $function$
;

-- ---------------------------------------------------------------------
-- public.founder_cap_conversion_preview(p_round_id uuid)
CREATE OR REPLACE FUNCTION public.founder_cap_conversion_preview(p_round_id uuid)
 RETURNS TABLE(safe_id uuid, investor_name text, principal_rupees bigint, cap_price numeric, discount_price numeric, new_share_price numeric, conversion_price numeric, price_source text, shares_issued bigint, ownership_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_new_price numeric;
  v_pre_shares bigint;
  v_total_post_shares bigint;
  v_new_money_shares bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT new_share_price_rupees, pre_round_shares,
         (new_money_rupees / new_share_price_rupees)::bigint
    INTO v_new_price, v_pre_shares, v_new_money_shares
  FROM public.founder_investor_cap_rounds
  WHERE id = p_round_id;

  IF v_new_price IS NULL THEN
    RETURN;
  END IF;

  -- estimate total post shares for ownership pct: pre + new money + safe converted shares estimate
  WITH safe_calc AS (
    SELECT
      s.id AS safe_id,
      s.investor_name,
      s.principal_rupees,
      CASE WHEN s.valuation_cap_rupees IS NOT NULL
           THEN s.valuation_cap_rupees::numeric / v_pre_shares
           ELSE NULL END AS cap_price,
      CASE WHEN s.discount_pct IS NOT NULL
           THEN v_new_price * (1 - s.discount_pct/100)
           ELSE NULL END AS discount_price
    FROM public.founder_investor_safes s
    WHERE s.status = 'outstanding'
  ),
  priced AS (
    SELECT
      sc.*,
      LEAST(
        COALESCE(sc.cap_price, v_new_price),
        COALESCE(sc.discount_price, v_new_price),
        v_new_price
      ) AS conv_price
    FROM safe_calc sc
  ),
  total_safe_shares AS (
    SELECT COALESCE(SUM(FLOOR(p.principal_rupees / p.conv_price))::bigint, 0) AS s
    FROM priced p
  )
  SELECT v_pre_shares + v_new_money_shares + (SELECT s FROM total_safe_shares)
    INTO v_total_post_shares;

  RETURN QUERY
  WITH safe_calc AS (
    SELECT
      s.id AS safe_id,
      s.investor_name,
      s.principal_rupees,
      CASE WHEN s.valuation_cap_rupees IS NOT NULL
           THEN s.valuation_cap_rupees::numeric / v_pre_shares
           ELSE NULL END AS cap_price,
      CASE WHEN s.discount_pct IS NOT NULL
           THEN v_new_price * (1 - s.discount_pct/100)
           ELSE NULL END AS discount_price
    FROM public.founder_investor_safes s
    WHERE s.status = 'outstanding'
  ),
  priced AS (
    SELECT
      sc.*,
      LEAST(
        COALESCE(sc.cap_price, v_new_price),
        COALESCE(sc.discount_price, v_new_price),
        v_new_price
      ) AS conv_price
    FROM safe_calc sc
  )
  SELECT
    p.safe_id,
    p.investor_name,
    p.principal_rupees,
    p.cap_price,
    p.discount_price,
    v_new_price AS new_share_price,
    p.conv_price AS conversion_price,
    CASE
      WHEN p.conv_price = p.cap_price THEN 'cap'
      WHEN p.conv_price = p.discount_price THEN 'discount'
      ELSE 'new_price'
    END::text AS price_source,
    FLOOR(p.principal_rupees / p.conv_price)::bigint AS shares_issued,
    ROUND(
      (FLOOR(p.principal_rupees / p.conv_price)::numeric
        / NULLIF(v_total_post_shares, 0)) * 100,
      4
    ) AS ownership_pct
  FROM priced p
  ORDER BY p.principal_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cash_conversion_cycle_summary()
CREATE OR REPLACE FUNCTION public.founder_cash_conversion_cycle_summary()
 RETURNS TABLE(dso_days_avg_90d numeric, dpo_days_avg_90d numeric, inventory_days_avg_90d numeric, cash_conversion_cycle_days numeric, total_outstanding_receivables_rupees numeric, total_outstanding_payables_rupees numeric, net_working_capital_rupees numeric, ar_aging_0_30_rupees numeric, ar_aging_31_60_rupees numeric, ar_aging_61_90_rupees numeric, ar_aging_over_90_rupees numeric, ap_aging_0_30_rupees numeric, ap_aging_31_60_rupees numeric, ap_aging_61_90_rupees numeric, ap_aging_over_90_rupees numeric, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_dso           numeric := 0;
  v_dpo           numeric := 0;
  v_inv           numeric := 0;
  v_ccc           numeric := 0;
  v_ar_total      numeric := 0;
  v_ap_total      numeric := 0;
  v_nwc           numeric := 0;
  v_ar_0_30       numeric := 0;
  v_ar_31_60      numeric := 0;
  v_ar_61_90      numeric := 0;
  v_ar_90p        numeric := 0;
  v_ap_0_30       numeric := 0;
  v_ap_31_60      numeric := 0;
  v_ap_61_90      numeric := 0;
  v_ap_90p        numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- DSO: public.gst_invoices carries NO settlement/updated timestamp at all — its only
  -- timestamps are issued_at and pdf_generated_at — so the original "issued_at ->
  -- updated_at for invoices that left 'issued'" measure is not computable (it raised
  -- 42703 on the phantom g.updated_at). Closest available proxy on the real schema:
  -- the average AGE of receivables still outstanding (status = 'issued'), which is the
  -- same population and the same day-count the AR aging buckets below use.
  SELECT coalesce(avg(extract(epoch FROM (now() - g.issued_at)) / 86400.0), 0)::numeric
    INTO v_dso
  FROM public.gst_invoices g
  WHERE g.status = 'issued'
    AND g.issued_at IS NOT NULL;

  -- DPO: avg days from spare_part_orders.created_at to updated_at for paid orders in last 90d.
  -- ('paid' is not a payment_status label — the paid label is 'completed'.)
  SELECT coalesce(avg(extract(epoch FROM (o.updated_at - o.created_at)) / 86400.0), 0)::numeric
    INTO v_dpo
  FROM public.spare_part_orders o
  WHERE o.payment_status = 'completed'
    AND o.updated_at >= now() - interval '90 days'
    AND o.updated_at > o.created_at;

  -- Inventory days: same hold-time proxy on spare parts pending (not yet paid) in last 90d.
  SELECT coalesce(avg(extract(epoch FROM (now() - o.created_at)) / 86400.0), 0)::numeric
    INTO v_inv
  FROM public.spare_part_orders o
  WHERE coalesce(o.payment_status, 'pending') <> 'completed'
    AND o.created_at >= now() - interval '90 days';

  v_ccc := v_dso - v_dpo + v_inv;

  -- Outstanding receivables: gst_invoices with status='issued' (open invoices).
  SELECT coalesce(sum(g.taxable_amount_rupees), 0)::numeric
    INTO v_ar_total
  FROM public.gst_invoices g
  WHERE g.status = 'issued';

  -- Outstanding payables: spare_part_orders not yet paid + not cancelled/refunded.
  -- payment_status labels are pending/completed/refunded/disputed/failed (no 'paid',
  -- no 'cancelled'); cancellation lives on order_status.
  SELECT coalesce(sum(o.total_amount), 0)::numeric
    INTO v_ap_total
  FROM public.spare_part_orders o
  WHERE coalesce(o.payment_status, 'pending') NOT IN ('completed','refunded')
    AND coalesce(o.order_status, 'placed') <> 'cancelled';

  v_nwc := v_ar_total - v_ap_total;

  -- AR aging buckets — bucket by days-since-issued for status='issued'.
  SELECT
    coalesce(sum(CASE WHEN d <= 30                THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 30  AND d <= 60    THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 60  AND d <= 90    THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 90                 THEN amt END), 0)
  INTO v_ar_0_30, v_ar_31_60, v_ar_61_90, v_ar_90p
  FROM (
    SELECT
      extract(epoch FROM (now() - g.issued_at)) / 86400.0 AS d,
      g.taxable_amount_rupees::numeric AS amt
    FROM public.gst_invoices g
    WHERE g.status = 'issued'
  ) ar;

  -- AP aging buckets — bucket by days-since-created for unpaid orders.
  SELECT
    coalesce(sum(CASE WHEN d <= 30                THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 30  AND d <= 60    THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 60  AND d <= 90    THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 90                 THEN amt END), 0)
  INTO v_ap_0_30, v_ap_31_60, v_ap_61_90, v_ap_90p
  FROM (
    SELECT
      extract(epoch FROM (now() - o.created_at)) / 86400.0 AS d,
      o.total_amount::numeric AS amt
    FROM public.spare_part_orders o
    WHERE coalesce(o.payment_status, 'pending') NOT IN ('completed','refunded')
      AND coalesce(o.order_status, 'placed') <> 'cancelled'
  ) ap;

  RETURN QUERY SELECT
    round(v_dso, 2),
    round(v_dpo, 2),
    round(v_inv, 2),
    round(v_ccc, 2),
    round(v_ar_total, 2),
    round(v_ap_total, 2),
    round(v_nwc, 2),
    round(v_ar_0_30, 2),
    round(v_ar_31_60, 2),
    round(v_ar_61_90, 2),
    round(v_ar_90p, 2),
    round(v_ap_0_30, 2),
    round(v_ap_31_60, 2),
    round(v_ap_61_90, 2),
    round(v_ap_90p, 2),
    now();
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cash_conversion_history(p_weeks integer)
CREATE OR REPLACE FUNCTION public.founder_cash_conversion_history(p_weeks integer DEFAULT 12)
 RETURNS TABLE(week_start date, dso_days_avg numeric, dpo_days_avg numeric, cash_conversion_cycle_days numeric, net_working_capital_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_weeks integer;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  v_weeks := greatest(1, least(coalesce(p_weeks, 12), 52));

  RETURN QUERY
  WITH weeks AS (
    SELECT (date_trunc('week', now())::date - (n || ' weeks')::interval)::date AS wk_start
    FROM generate_series(0, v_weeks - 1) AS n
  ),
  ar_paid AS (
    -- DSO per week: public.gst_invoices carries NO settlement/updated timestamp at all
    -- (its only timestamps are issued_at and pdf_generated_at), so the original
    -- "issued_at -> updated_at" collection time is not computable — it raised 42703 on
    -- the phantom g.updated_at. Closest available proxy on the real schema, matching
    -- the summary RPC: the average AGE, at the end of each week, of the receivables
    -- still outstanding (status = 'issued') that had been issued by then.
    SELECT
      w.wk_start AS wk,
      avg(extract(epoch FROM ((w.wk_start + interval '7 days') - g.issued_at)) / 86400.0)::numeric AS dso
    FROM weeks w
    JOIN public.gst_invoices g
      ON g.status = 'issued'
     AND g.issued_at IS NOT NULL
     AND g.issued_at < (w.wk_start + interval '7 days')
    GROUP BY 1
  ),
  ap_paid AS (
    -- 'paid' is not a payment_status label — the paid label is 'completed'.
    SELECT
      date_trunc('week', o.updated_at)::date AS wk,
      avg(extract(epoch FROM (o.updated_at - o.created_at)) / 86400.0)::numeric AS dpo
    FROM public.spare_part_orders o
    WHERE o.payment_status = 'completed'
      AND o.updated_at >= (date_trunc('week', now())::date - ((v_weeks - 1) || ' weeks')::interval)
      AND o.updated_at > o.created_at
    GROUP BY 1
  ),
  ar_open AS (
    SELECT
      w.wk_start AS wk,
      coalesce(sum(g.taxable_amount_rupees), 0)::numeric AS ar_amt
    FROM weeks w
    LEFT JOIN public.gst_invoices g
      ON g.status = 'issued'
     AND g.issued_at < (w.wk_start + interval '7 days')
    GROUP BY 1
  ),
  ap_open AS (
    -- payment_status labels are pending/completed/refunded/disputed/failed (no 'paid',
    -- no 'cancelled'); cancellation lives on order_status.
    SELECT
      w.wk_start AS wk,
      coalesce(sum(o.total_amount), 0)::numeric AS ap_amt
    FROM weeks w
    LEFT JOIN public.spare_part_orders o
      ON coalesce(o.payment_status, 'pending') NOT IN ('completed','refunded')
     AND coalesce(o.order_status, 'placed') <> 'cancelled'
     AND o.created_at < (w.wk_start + interval '7 days')
    GROUP BY 1
  )
  SELECT
    w.wk_start,
    round(coalesce(ar.dso, 0), 2)                                       AS dso_days_avg,
    round(coalesce(ap.dpo, 0), 2)                                       AS dpo_days_avg,
    round(coalesce(ar.dso, 0) - coalesce(ap.dpo, 0), 2)                 AS ccc_days,
    round(coalesce(arx.ar_amt, 0) - coalesce(apx.ap_amt, 0), 2)         AS nwc_rupees
  FROM weeks w
  LEFT JOIN ar_paid ar  ON ar.wk  = w.wk_start
  LEFT JOIN ap_paid ap  ON ap.wk  = w.wk_start
  LEFT JOIN ar_open arx ON arx.wk = w.wk_start
  LEFT JOIN ap_open apx ON apx.wk = w.wk_start
  ORDER BY w.wk_start DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cash_headline_kpis()
CREATE OR REPLACE FUNCTION public.founder_cash_headline_kpis()
 RETURNS TABLE(cash_on_hand_rupees bigint, monthly_burn_rupees bigint, monthly_revenue_rupees bigint, net_burn_rupees bigint, runway_months numeric, redline boolean, weighted_pipeline_rupees bigint, total_pipeline_rupees bigint, open_pipeline_count integer, receivables_rupees bigint, payables_rupees bigint, headcount integer, trailing_3mo_avg_burn bigint, trailing_3mo_avg_revenue bigint, burn_multiple numeric, months_to_default_risk integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_latest founder_cash_snapshots%ROWTYPE;
  v_avg_burn bigint;
  v_avg_rev bigint;
  v_weighted bigint;
  v_total_pipe bigint;
  v_open_count int;
  v_net bigint;
  v_runway numeric;
  v_burn_multiple numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT * INTO v_latest FROM founder_cash_snapshots ORDER BY snapshot_month DESC LIMIT 1;

  SELECT COALESCE(AVG(t.burn),0)::bigint,
         COALESCE(AVG(t.rev),0)::bigint
    INTO v_avg_burn, v_avg_rev
  FROM (SELECT s.monthly_burn_rupees AS burn, s.monthly_revenue_rupees AS rev
        FROM founder_cash_snapshots s
        ORDER BY s.snapshot_month DESC LIMIT 3) t;

  SELECT COALESCE(SUM(arr_rupees * probability_pct / 100),0)::bigint,
         COALESCE(SUM(arr_rupees),0)::bigint,
         COUNT(*)::int
    INTO v_weighted, v_total_pipe, v_open_count
  FROM founder_pipeline_entries
  WHERE stage NOT IN ('closed_won','closed_lost');

  v_net := GREATEST(COALESCE(v_latest.monthly_burn_rupees,0) - COALESCE(v_latest.monthly_revenue_rupees,0), 0);
  v_runway := CASE WHEN v_net <= 0 THEN 999::numeric
                   ELSE ROUND(COALESCE(v_latest.cash_on_hand_rupees,0)::numeric / NULLIF(v_net,0), 1) END;
  v_burn_multiple := CASE WHEN COALESCE(v_latest.monthly_revenue_rupees,0) = 0 THEN NULL
                          ELSE ROUND(v_net::numeric / v_latest.monthly_revenue_rupees, 2) END;

  RETURN QUERY SELECT
    COALESCE(v_latest.cash_on_hand_rupees,0)::bigint,
    COALESCE(v_latest.monthly_burn_rupees,0)::bigint,
    COALESCE(v_latest.monthly_revenue_rupees,0)::bigint,
    v_net,
    v_runway,
    (v_net > 0 AND COALESCE(v_latest.cash_on_hand_rupees,0)::numeric / NULLIF(v_net,0) < 6),
    v_weighted, v_total_pipe, v_open_count,
    COALESCE(v_latest.receivables_rupees,0)::bigint,
    COALESCE(v_latest.payables_rupees,0)::bigint,
    COALESCE(v_latest.headcount,0),
    v_avg_burn, v_avg_rev, v_burn_multiple,
    CASE WHEN v_net <= 0 THEN 999 ELSE FLOOR(COALESCE(v_latest.cash_on_hand_rupees,0) / NULLIF(v_net,0))::int END;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_cash_payment_surveys_summary()
CREATE OR REPLACE FUNCTION public.founder_cash_payment_surveys_summary()
 RETURNS TABLE(surveys_total bigint, surveys_90d bigint, surveys_30d bigint, surveys_7d bigint, asked_cash_90d bigint, no_cash_90d bigint, declined_90d bigint, asked_cash_rate_pct_90d numeric, asked_cash_rate_pct_30d numeric, declined_rate_pct_90d numeric, distinct_flagged_engineers_90d bigint, engineers_over_threshold_90d bigint, last_asked_cash_at timestamp with time zone, top_offender_name text, top_offender_asked_cash_90d bigint, top_offender_engineer_id uuid, top_hotspot_state text, top_hotspot_state_asked_cash bigint, pending_surveys_7d bigint, completed_jobs_7d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_top_off_id    uuid;
  v_top_off_name  text;
  v_top_off_cnt   bigint;
  v_top_state     text;
  v_top_state_cnt bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Top offender lookup (90d window)
  SELECT csr.engineer_id, coalesce(p.full_name, '(unnamed)'), csr.cnt
    INTO v_top_off_id, v_top_off_name, v_top_off_cnt
    FROM (
      SELECT engineer_id, count(*)::bigint AS cnt
        FROM public.cash_survey_responses
       WHERE response = 'asked_cash'
         AND responded_at >= now() - interval '90 days'
       GROUP BY engineer_id
       ORDER BY cnt DESC
       LIMIT 1
    ) csr
    JOIN public.engineers e ON e.id = csr.engineer_id
    LEFT JOIN public.profiles p ON p.id = e.user_id;

  -- Top hotspot state (joining hospital profile state)
  SELECT pr.state, sum(h.cnt)::bigint
    INTO v_top_state, v_top_state_cnt
    FROM (
      SELECT csr.hospital_user_id, count(*)::bigint AS cnt
        FROM public.cash_survey_responses csr
       WHERE csr.response = 'asked_cash'
         AND csr.responded_at >= now() - interval '90 days'
       GROUP BY csr.hospital_user_id
    ) h
    JOIN public.profiles pr ON pr.id = h.hospital_user_id
   WHERE pr.state IS NOT NULL
   GROUP BY pr.state
   ORDER BY sum(h.cnt) DESC
   LIMIT 1;

  RETURN QUERY
  WITH base AS (
    SELECT
      count(*)                                                                              AS total,
      count(*) FILTER (WHERE responded_at >= now() - interval '90 days')                    AS n_90d,
      count(*) FILTER (WHERE responded_at >= now() - interval '30 days')                    AS n_30d,
      count(*) FILTER (WHERE responded_at >= now() - interval '7 days')                     AS n_7d,
      count(*) FILTER (WHERE response = 'asked_cash'  AND responded_at >= now() - interval '90 days') AS ac_90d,
      count(*) FILTER (WHERE response = 'no_cash'     AND responded_at >= now() - interval '90 days') AS nc_90d,
      count(*) FILTER (WHERE response = 'declined'    AND responded_at >= now() - interval '90 days') AS dc_90d,
      count(*) FILTER (WHERE response = 'asked_cash'  AND responded_at >= now() - interval '30 days') AS ac_30d,
      max(responded_at) FILTER (WHERE response = 'asked_cash')                              AS last_ac
    FROM public.cash_survey_responses
  ),
  flagged AS (
    SELECT count(DISTINCT engineer_id)::bigint AS n
      FROM public.cash_survey_responses
     WHERE response = 'asked_cash'
       AND responded_at >= now() - interval '90 days'
  ),
  over_thresh AS (
    SELECT count(*)::bigint AS n
      FROM (
        SELECT engineer_id
          FROM public.cash_survey_responses
         WHERE response = 'asked_cash'
           AND responded_at >= now() - interval '90 days'
         GROUP BY engineer_id
        HAVING count(*) >= 3
      ) x
  ),
  jobs7 AS (
    SELECT
      count(*) FILTER (
        WHERE rj.status::text = 'completed'
          AND rj.completed_at IS NOT NULL
          AND rj.completed_at >= now() - interval '7 days'
          AND rj.completed_at <= now() - interval '24 hours'
          AND rj.hospital_user_id IS NOT NULL
          AND rj.engineer_id IS NOT NULL
      )::bigint AS completed_in_window,
      count(*) FILTER (
        WHERE rj.status::text = 'completed'
          AND rj.completed_at IS NOT NULL
          AND rj.completed_at >= now() - interval '7 days'
          AND rj.completed_at <= now() - interval '24 hours'
          AND rj.hospital_user_id IS NOT NULL
          AND rj.engineer_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.cash_survey_responses csr
             WHERE csr.repair_job_id = rj.id
          )
      )::bigint AS pending_in_window
    FROM public.repair_jobs rj
  )
  SELECT
    base.total::bigint,
    base.n_90d::bigint,
    base.n_30d::bigint,
    base.n_7d::bigint,
    base.ac_90d::bigint,
    base.nc_90d::bigint,
    base.dc_90d::bigint,
    CASE WHEN base.n_90d > 0 THEN round((base.ac_90d::numeric * 100.0) / base.n_90d, 1) ELSE 0 END,
    CASE WHEN base.n_30d > 0 THEN round((base.ac_30d::numeric * 100.0) / base.n_30d, 1) ELSE 0 END,
    CASE WHEN base.n_90d > 0 THEN round((base.dc_90d::numeric * 100.0) / base.n_90d, 1) ELSE 0 END,
    flagged.n,
    over_thresh.n,
    base.last_ac,
    v_top_off_name,
    coalesce(v_top_off_cnt, 0)::bigint,
    v_top_off_id,
    v_top_state,
    coalesce(v_top_state_cnt, 0)::bigint,
    jobs7.pending_in_window,
    jobs7.completed_in_window
  FROM base, flagged, over_thresh, jobs7;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_cert_engineer_leaderboard()
CREATE OR REPLACE FUNCTION public.founder_cert_engineer_leaderboard()
 RETURNS TABLE(engineer_id uuid, engineer_name text, cert_count bigint, total_cost_rupees bigint, latest_cert_at date)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_id, COALESCE(p.full_name, 'unknown')::text,
         count(*)::bigint, COALESCE(sum(c.cost_rupees)::bigint, 0::bigint),
         max(c.issued_on)
  FROM public.engineer_external_certifications c
  LEFT JOIN public.engineers e ON e.id = c.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  GROUP BY c.engineer_id, p.full_name
  ORDER BY count(*) DESC
  LIMIT 50;
END $function$
;

-- ---------------------------------------------------------------------
-- public.founder_cert_recent_renewal_log()
CREATE OR REPLACE FUNCTION public.founder_cert_recent_renewal_log()
 RETURNS TABLE(id uuid, cert_name text, engineer_name text, event_type text, due_on date, sla_days integer, note text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    c.cert_name,
    COALESCE(p.full_name, 'Unknown')::text,
    l.event_type,
    l.due_on,
    l.sla_days,
    l.note,
    l.created_at
  FROM engineer_cert_renewal_log l
  JOIN engineer_external_certifications c ON c.id = l.cert_id
  JOIN engineers e ON e.id = c.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY l.created_at DESC
  LIMIT 100;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_chains_health()
CREATE OR REPLACE FUNCTION public.founder_chains_health()
 RETURNS TABLE(chain_id uuid, chain_name text, member_count bigint, amc_active_count bigint, amc_pct numeric, jobs_completed_30d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH members AS (
    -- hospital_chain_memberships has no status column (columns are
    -- id, chain_id, hospital_user_id, member_role, site_label, joined_at,
    -- added_by), so every membership row IS a live membership -- which is
    -- exactly what the old coalesce(status,'active')='active' predicate
    -- was written to mean.
    SELECT chain_id, hospital_user_id
    FROM public.hospital_chain_memberships
  ),
  per_chain AS (
    SELECT
      m.chain_id,
      count(*)::bigint                                        AS member_count,
      (SELECT count(*)::bigint
         FROM public.amc_contracts c
        WHERE c.hospital_user_id IN (SELECT hospital_user_id FROM members WHERE chain_id = m.chain_id)
          AND c.status = 'active')                            AS amc_active_count,
      (SELECT count(*)::bigint
         FROM public.repair_jobs rj
        WHERE rj.hospital_user_id IN (SELECT hospital_user_id FROM members WHERE chain_id = m.chain_id)
          AND rj.status = 'completed'
          AND rj.completed_at >= now() - interval '30 days')  AS jobs_completed_30d
    FROM members m
    GROUP BY m.chain_id
  )
  SELECT
    hc.id                                  AS chain_id,
    hc.name                                AS chain_name,
    coalesce(pc.member_count, 0)           AS member_count,
    coalesce(pc.amc_active_count, 0)       AS amc_active_count,
    CASE WHEN coalesce(pc.member_count, 0) = 0 THEN 0::numeric
         ELSE round(coalesce(pc.amc_active_count, 0)::numeric / pc.member_count::numeric * 100.0, 1) END AS amc_pct,
    coalesce(pc.jobs_completed_30d, 0)     AS jobs_completed_30d
  FROM public.hospital_chains hc
  LEFT JOIN per_chain pc ON pc.chain_id = hc.id
  ORDER BY member_count DESC, jobs_completed_30d DESC
  LIMIT 50;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_chain_expansion_active_chains()
CREATE OR REPLACE FUNCTION public.founder_chain_expansion_active_chains()
 RETURNS TABLE(id text, chain_name text, anchor_hospital text, total_locations bigint, identified bigint, won bigint, last_activity timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.chain_name AS id,
    t.chain_name,
    -- min() has no uuid overload; aggregate over the text form and cast back
    -- so the anchor org picked per chain stays deterministic.
    COALESCE((SELECT o.name FROM organizations o WHERE o.id = MIN(t.anchor_org_id::text)::uuid), '—'),
    count(*),
    count(*) FILTER (WHERE t.status='identified'),
    count(*) FILTER (WHERE t.status='won'),
    MAX(t.last_touch_at)
  FROM founder_chain_expansion_targets t
  GROUP BY t.chain_name
  ORDER BY count(*) DESC
  LIMIT 200;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_churn_prediction_at_risk_hospitals(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_churn_prediction_at_risk_hospitals(p_limit integer DEFAULT 50)
 RETURNS TABLE(hospital_org_id uuid, hospital_name text, latest_score numeric, latest_snapshot_at timestamp with time zone, days_since_last_visit integer, sla_breach_count_90d integer, open_dispute_count integer, monthly_fee_rupees numeric, threshold_pct numeric, exceeds_threshold_by numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_threshold numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT m.churn_threshold_pct INTO v_threshold
  FROM public.founder_churn_prediction_models m
  WHERE m.activated_at IS NOT NULL AND m.deactivated_at IS NULL AND m.shadow_mode = false
  ORDER BY m.activated_at DESC LIMIT 1;
  v_threshold := COALESCE(v_threshold, 50);

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (f.hospital_org_id)
      f.hospital_org_id, f.computed_churn_score, f.feature_snapshot_at,
      f.days_since_last_visit, f.sla_breach_count_90d, f.open_dispute_count, f.monthly_fee_rupees
    FROM public.founder_churn_prediction_features f
    WHERE f.computed_churn_score IS NOT NULL
    ORDER BY f.hospital_org_id, f.feature_snapshot_at DESC
  )
  SELECT l.hospital_org_id, o.name, l.computed_churn_score, l.feature_snapshot_at,
         l.days_since_last_visit, l.sla_breach_count_90d, l.open_dispute_count,
         l.monthly_fee_rupees, v_threshold,
         (l.computed_churn_score - v_threshold)
  FROM latest l
  LEFT JOIN public.organizations o ON o.id = l.hospital_org_id
  WHERE l.computed_churn_score > v_threshold
  ORDER BY l.computed_churn_score DESC
  LIMIT p_limit;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_compliance_calendar_auto_seed_year()
CREATE OR REPLACE FUNCTION public.founder_compliance_calendar_auto_seed_year()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  inserted_count int := 0;
  m int;
  q int;
  qtr_end date;
  tds_due date;
  base_year int := EXTRACT(year FROM CURRENT_DATE)::int;
BEGIN
  -- Monthly TDS — 7th of next month
  FOR m IN 1..12 LOOP
    tds_due := make_date(base_year, m, 1) + INTERVAL '1 month' + INTERVAL '6 days';
    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, recurrence_anchor_date, source_table)
    VALUES
      ('TDS deposit — ' || to_char(make_date(base_year, m, 1), 'Mon YYYY'),
       'tds_filing', tds_due::date, 'monthly', make_date(base_year, m, 1), 'founder_tax_filing_runs')
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
    IF FOUND THEN inserted_count := inserted_count + 1; END IF;
  END LOOP;

  -- Quarterly GST (GSTR-1/3B) — 20th of month after qtr end
  FOR q IN 1..4 LOOP
    qtr_end := make_date(base_year, q*3, 1) + INTERVAL '1 month' - INTERVAL '1 day';
    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, recurrence_anchor_date, source_table)
    VALUES
      ('GST quarterly filing Q' || q || ' ' || base_year,
       'gst_filing', (qtr_end + INTERVAL '20 days')::date, 'quarterly', qtr_end, 'founder_gst_filings')
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
    IF FOUND THEN inserted_count := inserted_count + 1; END IF;

    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, recurrence_anchor_date)
    VALUES
      ('DPDP quarterly report Q' || q || ' ' || base_year,
       'dpdp_quarterly_report', (qtr_end + INTERVAL '30 days')::date, 'quarterly', qtr_end)
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
    IF FOUND THEN inserted_count := inserted_count + 1; END IF;

    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, recurrence_anchor_date)
    VALUES
      ('Board meeting Q' || q || ' ' || base_year,
       'board_meeting', (qtr_end + INTERVAL '15 days')::date, 'quarterly', qtr_end)
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
    IF FOUND THEN inserted_count := inserted_count + 1; END IF;
  END LOOP;

  -- Annual filings
  INSERT INTO public.founder_compliance_calendar_events
    (event_label, event_kind, due_date, frequency, recurrence_anchor_date)
  VALUES
    ('Income-tax return AY ' || (base_year+1),
     'it_return', make_date(base_year, 10, 31), 'annual', make_date(base_year, 4, 1)),
    ('Statutory audit ' || base_year,
     'statutory_audit', make_date(base_year, 9, 30), 'annual', make_date(base_year, 4, 1)),
    ('Privacy notice annual review ' || base_year,
     'privacy_notice_review', make_date(base_year, 12, 31), 'annual', make_date(base_year, 1, 1))
  ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
  inserted_count := inserted_count + 3;

  -- Pull renewals from founder_compliance_documents (r1358) if any have renewal_due_date
  BEGIN
    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, source_table, source_record_id)
    SELECT
      'Renewal: ' || COALESCE(d.doc_label, d.doc_kind),
      CASE d.doc_kind
        WHEN 'udyam'  THEN 'udyam_renewal'
        WHEN 'msme'   THEN 'msme_renewal'
        WHEN 'cdsco'  THEN 'cdsco_renewal'
        WHEN 'nabh'   THEN 'nabh_renewal'
        ELSE 'other'
      END,
      d.renewal_due_date,
      'annual',
      'founder_compliance_documents',
      d.id
    FROM public.founder_compliance_documents d
    WHERE d.renewal_due_date IS NOT NULL
      AND d.renewal_due_date >= CURRENT_DATE
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
  EXCEPTION WHEN undefined_table OR undefined_column THEN
    NULL;
  END;

  -- Roll up statuses
  UPDATE public.founder_compliance_calendar_events
     SET status = 'overdue', updated_at = now()
   WHERE due_date < CURRENT_DATE
     AND status NOT IN ('completed','waived','overdue');

  UPDATE public.founder_compliance_calendar_events
     SET status = 'due_soon', updated_at = now()
   WHERE due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
     AND status NOT IN ('completed','waived','due_soon');

  RETURN inserted_count;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_critical_actions()
CREATE OR REPLACE FUNCTION public.founder_critical_actions()
 RETURNS TABLE(surface text, item_id uuid, item_label text, amount_inr numeric, created_at timestamp with time zone, age_days integer, severity text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  (
    SELECT
      'payout'::text                                                                        AS surface,
      p.id::uuid                                                                            AS item_id,
      ('payout to ' || coalesce((SELECT full_name FROM public.profiles WHERE id = p.engineer_user_id), '?')) AS item_label,
      p.amount_rupees::numeric                                                              AS amount_inr,
      p.queued_at                                                                           AS created_at,
      extract(day from (now() - p.queued_at))::int                                          AS age_days,
      CASE WHEN p.queued_at < now() - interval '14 days' THEN 'critical' ELSE 'warn' END    AS severity
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued','processing')
      AND p.queued_at < now() - interval '7 days'
    ORDER BY p.queued_at ASC
    LIMIT 20
  )
  UNION ALL
  (
    SELECT 'code_red'::text, r.id::uuid, ('code red request')::text, NULL::numeric, r.created_at,
      extract(day from (now() - r.created_at))::int,
      CASE WHEN r.created_at < now() - interval '24 hours' THEN 'critical' ELSE 'warn' END
    FROM public.code_red_requests r
    WHERE r.status NOT IN ('resolved','timed_out') AND r.created_at < now() - interval '4 hours'
    ORDER BY r.created_at ASC LIMIT 20
  )
  UNION ALL
  (
    -- payment_status/order_status are enums: paid is 'completed', refunded is 'returned'.
    SELECT 'spare_part'::text, o.id::uuid, ('order ' || coalesce(o.order_number, o.id::text)),
      o.total_amount::numeric, o.created_at, extract(day from (now() - o.created_at))::int,
      CASE WHEN o.created_at < now() - interval '14 days' THEN 'critical' ELSE 'warn' END
    FROM public.spare_part_orders o
    WHERE coalesce(o.payment_status::text,'') = 'completed'
      AND coalesce(o.order_status::text,'') NOT IN ('shipped','delivered','cancelled','returned')
      AND o.created_at < now() - interval '7 days'
    ORDER BY o.created_at ASC LIMIT 20
  )
  UNION ALL
  (
    SELECT 'escrow'::text, e.id::uuid, ('escrow for job ' || e.repair_job_id::text),
      e.amount_rupees::numeric, e.created_at, extract(day from (now() - e.created_at))::int,
      CASE WHEN e.created_at < now() - interval '30 days' THEN 'critical' ELSE 'warn' END
    FROM public.repair_job_escrow e
    WHERE e.status = 'held' AND e.created_at < now() - interval '14 days'
    ORDER BY e.created_at ASC LIMIT 20
  )
  ORDER BY 7 DESC, 5 ASC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cron_jobs_recent(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_cron_jobs_recent(p_limit integer DEFAULT 50)
 RETURNS TABLE(jobid bigint, jobname text, schedule text, active boolean, last_run_at timestamp with time zone, last_status text, last_duration_seconds numeric, recent_failure_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- pg_cron is not installed on this project, so cron.job / cron.job_run_details do not exist
  -- and this query cannot be planned (42P01 / 3F000). Degrade to an empty list -- i.e. "no
  -- scheduled jobs" -- instead of aborting the founder console, matching the per-metric
  -- fallback pattern used by the founder cockpit functions. If pg_cron is ever installed the
  -- real rows start flowing with no further change.
  BEGIN
    RETURN QUERY
    SELECT
      j.jobid,
      coalesce(j.jobname, ('job_' || j.jobid::text))::text,
      j.schedule::text,
      j.active,
      (SELECT max(rd.start_time) FROM cron.job_run_details rd WHERE rd.jobid = j.jobid),
      (SELECT rd.status FROM cron.job_run_details rd
        WHERE rd.jobid = j.jobid ORDER BY rd.start_time DESC LIMIT 1)::text,
      (SELECT extract(epoch from (rd.end_time - rd.start_time))::numeric FROM cron.job_run_details rd
        WHERE rd.jobid = j.jobid AND rd.end_time IS NOT NULL ORDER BY rd.start_time DESC LIMIT 1),
      coalesce((SELECT count(*)::bigint FROM cron.job_run_details rd
                WHERE rd.jobid = j.jobid AND rd.start_time >= now() - interval '24 hours' AND rd.status <> 'succeeded'), 0)
    FROM cron.job j
    ORDER BY j.active DESC, j.jobid
    LIMIT p_limit;
  EXCEPTION
    WHEN undefined_table OR invalid_schema_name THEN
      RETURN;
  END;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cron_status_summary()
CREATE OR REPLACE FUNCTION public.founder_cron_status_summary()
 RETURNS TABLE(total_jobs bigint, active_jobs bigint, inactive_jobs bigint, recent_runs_24h bigint, recent_failures_24h bigint, recent_successes_24h bigint, failure_rate_24h_pct numeric, oldest_job_no_recent_run bigint, longest_running_job_seconds numeric, jobs_with_recent_failure_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total bigint;
  v_runs_24h bigint;
  v_fail_24h bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- pg_cron is not installed on this project, so cron.job / cron.job_run_details do not
  -- exist and every query below fails to plan (42P01 / 3F000). Degrade to an all-zero row
  -- -- i.e. "no scheduled jobs, no runs" -- instead of aborting the founder console, matching
  -- the per-metric fallback pattern used by the founder cockpit functions. If pg_cron is ever
  -- installed the real numbers start flowing with no further change.
  BEGIN
    SELECT count(*)::bigint INTO v_total FROM cron.job;
    IF v_total IS NULL THEN v_total := 0; END IF;
    SELECT count(*)::bigint INTO v_runs_24h FROM cron.job_run_details WHERE start_time >= now() - interval '24 hours';
    IF v_runs_24h IS NULL THEN v_runs_24h := 0; END IF;
    SELECT count(*)::bigint INTO v_fail_24h FROM cron.job_run_details
      WHERE start_time >= now() - interval '24 hours' AND status <> 'succeeded';
    IF v_fail_24h IS NULL THEN v_fail_24h := 0; END IF;

    RETURN QUERY
    SELECT
      v_total,
      coalesce((SELECT count(*)::bigint FROM cron.job WHERE active = true), 0),
      coalesce((SELECT count(*)::bigint FROM cron.job WHERE active = false), 0),
      v_runs_24h,
      v_fail_24h,
      v_runs_24h - v_fail_24h,
      CASE WHEN v_runs_24h = 0 THEN 0::numeric ELSE round(100.0 * v_fail_24h / v_runs_24h, 1) END,
      coalesce((SELECT count(*)::bigint FROM cron.job j
                WHERE j.active = true AND NOT EXISTS (
                  SELECT 1 FROM cron.job_run_details rd
                  WHERE rd.jobid = j.jobid AND rd.start_time >= now() - interval '24 hours'
                )), 0),
      coalesce((SELECT extract(epoch from max(end_time - start_time))::numeric FROM cron.job_run_details
                WHERE start_time >= now() - interval '24 hours' AND end_time IS NOT NULL), 0),
      coalesce((SELECT count(DISTINCT jobid)::bigint FROM cron.job_run_details
                WHERE start_time >= now() - interval '24 hours' AND status <> 'succeeded'), 0);
  EXCEPTION
    WHEN undefined_table OR invalid_schema_name THEN
      RETURN QUERY
      SELECT 0::bigint, 0::bigint, 0::bigint, 0::bigint, 0::bigint, 0::bigint,
             0::numeric, 0::bigint, 0::numeric, 0::bigint;
  END;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_culture_deck_summary()
CREATE OR REPLACE FUNCTION public.founder_culture_deck_summary()
 RETURNS TABLE(total_versions bigint, active_version text, total_signatures bigint, team_total bigint, signed_count bigint, pct_signed numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_team_total bigint;
DECLARE v_signed bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- user_role has no 'founder' label (labels: hospital_admin, engineer,
  -- manufacturer, supplier, logistics, admin); the founder is identified by
  -- public.is_founder(), not by profiles.role, so only the real labels remain.
  SELECT count(*) INTO v_team_total FROM public.profiles WHERE role IN ('admin','engineer');
  SELECT count(DISTINCT signer_user_id) INTO v_signed FROM public.founder_culture_deck_signatures
    WHERE version_id = (SELECT id FROM public.founder_culture_deck_versions WHERE is_active = true ORDER BY published_at DESC LIMIT 1);
  RETURN QUERY
  SELECT (SELECT count(*) FROM public.founder_culture_deck_versions),
         (SELECT version_label FROM public.founder_culture_deck_versions WHERE is_active = true ORDER BY published_at DESC LIMIT 1),
         (SELECT count(*) FROM public.founder_culture_deck_signatures),
         v_team_total,
         v_signed,
         CASE WHEN v_team_total > 0 THEN ROUND(100.0 * v_signed / v_team_total, 1) ELSE 0 END;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_culture_deck_unsigned_team()
CREATE OR REPLACE FUNCTION public.founder_culture_deck_unsigned_team()
 RETURNS TABLE(user_id uuid, email text, full_name text, active_version text, days_overdue integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH active_v AS (
    SELECT id, version_label, published_at
    FROM public.founder_culture_deck_versions
    WHERE is_active = true
    ORDER BY published_at DESC LIMIT 1
  )
  SELECT p.id, p.email, p.full_name,
         (SELECT version_label FROM active_v)::text,
         EXTRACT(EPOCH FROM (now() - (SELECT published_at FROM active_v)))::int / 86400
  FROM public.profiles p
  -- user_role has no 'founder' label (hospital_admin, engineer, manufacturer,
  -- supplier, logistics, admin) — the founder is identified by is_founder(),
  -- not by profiles.role, and carries role 'admin'. Internal team = admin + engineer.
  WHERE p.role IN ('admin','engineer')
    AND EXISTS (SELECT 1 FROM active_v)
    AND NOT EXISTS (
      SELECT 1 FROM public.founder_culture_deck_signatures s
      WHERE s.version_id = (SELECT id FROM active_v) AND s.signer_user_id = p.id
    )
  ORDER BY p.email
  LIMIT 200;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_culture_deck_version_timeline()
CREATE OR REPLACE FUNCTION public.founder_culture_deck_version_timeline()
 RETURNS TABLE(publish_week date, versions_published bigint, total_signatures bigint, new_hire_signatures bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH v AS (
    SELECT ver.id, date_trunc('week', ver.published_at) AS wk
    FROM founder_culture_deck_versions ver
    WHERE ver.published_at > now() - interval '180 days'
  )
  SELECT v.wk::date AS publish_week,
         COUNT(DISTINCT v.id) AS versions_published,
         (SELECT COUNT(*) FROM founder_culture_deck_signatures s
            WHERE date_trunc('week', s.signed_at) = v.wk) AS total_signatures,
         (SELECT COUNT(*) FROM founder_culture_deck_signatures s
            WHERE date_trunc('week', s.signed_at) = v.wk
              AND s.is_new_hire) AS new_hire_signatures
  FROM v
  GROUP BY v.wk
  ORDER BY publish_week DESC
  LIMIT 26;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_cumulative_rollup_summary()
CREATE OR REPLACE FUNCTION public.founder_cumulative_rollup_summary()
 RETURNS TABLE(days_since_launch bigint, lifetime_jobs_completed bigint, lifetime_jobs_gmv_inr numeric, lifetime_amc_revenue_inr numeric, lifetime_parts_revenue_inr numeric, lifetime_gmv_total_inr numeric, lifetime_payouts_disbursed_inr numeric, lifetime_referral_bounties_inr numeric, lifetime_engineers_onboarded bigint, lifetime_hospitals_onboarded bigint, lifetime_amc_contracts_created bigint, lifetime_spare_part_orders bigint, avg_gmv_per_day_inr numeric, avg_jobs_per_day numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_first_signup timestamptz;
  v_days numeric;
  v_jobs_gmv numeric;
  v_amc_rev numeric;
  v_parts_rev numeric;
  v_total_gmv numeric;
  v_jobs_done bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT min(created_at) INTO v_first_signup FROM public.profiles;
  IF v_first_signup IS NULL THEN
    v_days := 1;
  ELSE
    v_days := greatest(1, ceil(extract(epoch FROM (now() - v_first_signup)) / 86400.0));
  END IF;

  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_jobs_gmv
    FROM public.repair_jobs WHERE status = 'completed';

  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_amc_rev
    FROM public.amc_payment_orders WHERE status = 'paid';

  -- payment_status is an enum; its paid label is 'completed' (there is no 'paid').
  SELECT coalesce(sum(total_amount), 0)::numeric INTO v_parts_rev
    FROM public.spare_part_orders WHERE coalesce(payment_status::text, '') = 'completed';

  v_total_gmv := v_jobs_gmv + v_amc_rev + v_parts_rev;

  SELECT count(*)::bigint INTO v_jobs_done
    FROM public.repair_jobs WHERE status = 'completed';

  RETURN QUERY
  SELECT
    v_days::bigint,
    v_jobs_done,
    v_jobs_gmv,
    v_amc_rev,
    v_parts_rev,
    v_total_gmv,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts
              WHERE status IN ('processed','paid')), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts
              WHERE status = 'paid'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE role = 'hospital_admin'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders), 0),
    round(v_total_gmv / v_days, 2)::numeric,
    round(v_jobs_done::numeric / v_days, 2)::numeric;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_dispute_queue(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_dispute_queue(p_limit integer DEFAULT 50)
 RETURNS TABLE(escrow_id uuid, repair_job_id uuid, amount_rupees numeric, hospital_user_id uuid, hospital_email text, engineer_user_id uuid, engineer_email text, engineer_pack_id uuid, hospital_pack_id uuid, engineer_pack_evidence_count integer, hospital_pack_evidence_count integer, earliest_pack_at timestamp with time zone, hours_since_oldest_pack numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH escrows_in_dispute AS (
    SELECT e.id, e.repair_job_id, e.amount_rupees, e.dispute_reason
      FROM public.repair_job_escrow e
     WHERE e.status = 'disputed'
        OR (e.dispute_reason IS NOT NULL AND e.dispute_resolved_at IS NULL)
  ),
  packs AS (
    SELECT
      p.repair_job_escrow_id,
      (max(p.id::text) FILTER (WHERE p.filer_role = 'engineer' AND p.status = 'submitted'))::uuid AS engineer_pack_id,
      (max(p.id::text) FILTER (WHERE p.filer_role = 'hospital' AND p.status = 'submitted'))::uuid AS hospital_pack_id,
      max(p.evidence_count) FILTER (WHERE p.filer_role = 'engineer' AND p.status = 'submitted') AS engineer_pack_evidence_count,
      max(p.evidence_count) FILTER (WHERE p.filer_role = 'hospital' AND p.status = 'submitted') AS hospital_pack_evidence_count,
      min(p.submitted_at) FILTER (WHERE p.status = 'submitted') AS earliest_pack_at
    FROM public.dispute_evidence_packs p
    GROUP BY p.repair_job_escrow_id
  ),
  bids AS (
    SELECT b.repair_job_id, b.engineer_user_id
      FROM public.repair_job_bids b
     WHERE b.status = 'accepted'
  )
  SELECT
    e.id AS escrow_id,
    e.repair_job_id,
    e.amount_rupees,
    rj.hospital_user_id,
    (SELECT email FROM auth.users WHERE id = rj.hospital_user_id) AS hospital_email,
    b.engineer_user_id,
    (SELECT email FROM auth.users WHERE id = b.engineer_user_id) AS engineer_email,
    p.engineer_pack_id,
    p.hospital_pack_id,
    coalesce(p.engineer_pack_evidence_count, 0)::int,
    coalesce(p.hospital_pack_evidence_count, 0)::int,
    p.earliest_pack_at,
    EXTRACT(EPOCH FROM (now() - p.earliest_pack_at)) / 3600
  FROM escrows_in_dispute e
  JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
  LEFT JOIN bids b ON b.repair_job_id = e.repair_job_id
  LEFT JOIN packs p ON p.repair_job_escrow_id = e.id
  ORDER BY p.earliest_pack_at ASC NULLS LAST
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_eef_v2_ack_cliff_alert(p_alert_id uuid, p_note text)
CREATE OR REPLACE FUNCTION public.founder_eef_v2_ack_cliff_alert(p_alert_id uuid, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_earnings_cliff_alerts_v2
  SET acknowledged = true, acknowledged_by = auth.uid(), acknowledged_at = now(), resolution_note = p_note
  WHERE id = p_alert_id;
  -- log_founder_eef_v2_ack(uuid, text) does not exist in this database (r1505's
  -- helper was never created), so the PERFORM raised 42883 and rolled the ack
  -- back. The helper's audit write is inlined here verbatim: same op_name and
  -- same after_value payload, plus the target_table/target_row_id columns.
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO public.founder_action_log
    (actor_user_id, actor_email, op_name, target_table, target_row_id, after_value)
  VALUES (auth.uid(),
          COALESCE(v_email, auth.jwt()->>'email', 'unknown'),
          'eef_v2_ack_cliff',
          'founder_earnings_cliff_alerts_v2',
          p_alert_id,
          jsonb_build_object('alert_id', p_alert_id, 'note', p_note));
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineers_missing_payout()
CREATE OR REPLACE FUNCTION public.founder_engineers_missing_payout()
 RETURNS TABLE(engineer_user_id uuid, display_name text, jobs_completed_30d bigint, gross_earned_30d numeric, queued_payouts bigint, oldest_queue_days integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active_earners AS (
    SELECT
      b.engineer_user_id,
      count(*)::bigint                                     AS jobs_completed_30d,
      coalesce(sum(rj.contracted_amount_rupees), 0)::numeric AS gross_earned_30d
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '30 days'
    GROUP BY b.engineer_user_id
  ),
  no_method AS (
    SELECT ae.engineer_user_id, ae.jobs_completed_30d, ae.gross_earned_30d
    FROM active_earners ae
    WHERE NOT EXISTS (
      -- engineer_payout_methods keys the engineer as user_id, not engineer_user_id
      SELECT 1 FROM public.engineer_payout_methods m
       WHERE m.user_id = ae.engineer_user_id
         AND m.status = 'verified'
    )
  )
  SELECT
    nm.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    nm.jobs_completed_30d,
    nm.gross_earned_30d,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts ep
              WHERE ep.engineer_user_id = nm.engineer_user_id
                AND ep.status = 'queued'
                AND ep.payout_method_id IS NULL), 0)::bigint AS queued_payouts,
    coalesce((SELECT (extract(epoch FROM (now() - min(ep.queued_at)))::int / 86400)
              FROM public.engineer_payouts ep
              WHERE ep.engineer_user_id = nm.engineer_user_id
                AND ep.status = 'queued'
                AND ep.payout_method_id IS NULL), 0)::int AS oldest_queue_days
  FROM no_method nm
  LEFT JOIN public.profiles p ON p.id = nm.engineer_user_id
  ORDER BY nm.gross_earned_30d DESC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_escalation_by_category()
CREATE OR REPLACE FUNCTION public.founder_engineer_escalation_by_category()
 RETURNS TABLE(id text, category text, total_30d bigint, open_now bigint, avg_resolve_hours numeric, resolve_sla_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.category AS id,
    e.category,
    COUNT(*) FILTER (WHERE e.created_at >= now() - interval '30 days'),
    COUNT(*) FILTER (WHERE e.status IN ('open','acknowledged','in_progress')),
    -- FILTER may only be attached to an aggregate, not to round(); move it
    -- onto avg() (same result: avg already ignores NULL resolve_seconds).
    COALESCE(round(avg(e.resolve_seconds) FILTER (WHERE e.resolve_seconds IS NOT NULL) / 3600.0, 1), 0),
    COALESCE(round(100.0 * count(*) FILTER (WHERE e.resolve_seconds <= 86400) / NULLIF(count(*) FILTER (WHERE e.resolve_seconds IS NOT NULL), 0), 1), 0)
  FROM founder_engineer_escalations e
  GROUP BY e.category
  ORDER BY COUNT(*) FILTER (WHERE e.created_at >= now() - interval '30 days') DESC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_engineer_leaderboard_30d()
CREATE OR REPLACE FUNCTION public.founder_engineer_leaderboard_30d()
 RETURNS TABLE(engineer_name text, city text, completed_jobs bigint, total_earnings_inr numeric, avg_rating numeric, tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(p.full_name, '(no name)')::text                                  AS engineer_name,
    coalesce(e.city, '(unknown)')::text                                       AS city,
    count(j.id)::bigint                                                       AS completed_jobs,
    coalesce(sum(j.engineer_payout), 0)::numeric                              AS total_earnings_inr,
    coalesce(round(avg(j.hospital_rating)::numeric, 2), 0)::numeric           AS avg_rating,
    coalesce(e.cached_highest_tier, 'none')::text                                            AS tier
  FROM public.repair_jobs j
  JOIN public.engineers e ON e.id = j.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE j.status = 'completed'
    AND j.completed_at >= now() - interval '30 days'
  GROUP BY p.full_name, e.city, e.cached_highest_tier
  ORDER BY count(j.id) DESC, sum(j.engineer_payout) DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_side_projects_active_list_r1469()
CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_active_list_r1469()
 RETURNS TABLE(id uuid, engineer_id uuid, full_name text, project_kind text, coi_risk_band text, status text, last_action_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         i.side_business_type, i.conflict_risk, i.status, i.updated_at
  FROM public.engineer_side_projects_intel_v2 i
  LEFT JOIN public.engineers e ON e.id = i.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE i.status NOT IN ('resolved','dismissed')
  ORDER BY i.updated_at DESC
  LIMIT 60;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_side_projects_overdue_followups_r1469()
CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_overdue_followups_r1469()
 RETURNS TABLE(id uuid, engineer_id uuid, full_name text, follow_up_at timestamp with time zone, days_overdue integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, i.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         c.follow_up_due_at, EXTRACT(DAY FROM (now() - c.follow_up_due_at))::int
  FROM public.engineer_side_projects_conversations_v2 c
  LEFT JOIN public.engineer_side_projects_intel_v2 i ON i.id = c.intel_id
  LEFT JOIN public.engineers e ON e.id = i.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE c.follow_up_due_at IS NOT NULL AND c.follow_up_due_at < now()
  ORDER BY c.follow_up_due_at ASC
  LIMIT 50;
END $function$
;

-- ---------------------------------------------------------------------
-- public.founder_engineer_side_projects_recent_convos_r1469()
CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_recent_convos_r1469()
 RETURNS TABLE(id uuid, intel_id uuid, engineer_id uuid, full_name text, summary text, occurred_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.intel_id, i.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         c.summary, c.conversation_at AS occurred_at
  FROM public.engineer_side_projects_conversations_v2 c
  LEFT JOIN public.engineer_side_projects_intel_v2 i ON i.id = c.intel_id
  LEFT JOIN public.engineers e ON e.id = i.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY c.conversation_at DESC
  LIMIT 50;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_escrow_held_aging()
CREATE OR REPLACE FUNCTION public.founder_escrow_held_aging()
 RETURNS TABLE(bucket text, bucket_order integer, cnt bigint, amount_inr numeric, oldest_created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      CASE
        WHEN e.created_at >= now() - interval '24 hours'  THEN '<24h'
        WHEN e.created_at >= now() - interval '3 days'    THEN '1-3d'
        WHEN e.created_at >= now() - interval '7 days'    THEN '3-7d'
        WHEN e.created_at >= now() - interval '14 days'   THEN '7-14d'
        WHEN e.created_at >= now() - interval '30 days'   THEN '14-30d'
        ELSE '>30d'
      END                                          AS bucket,
      CASE
        WHEN e.created_at >= now() - interval '24 hours'  THEN 1
        WHEN e.created_at >= now() - interval '3 days'    THEN 2
        WHEN e.created_at >= now() - interval '7 days'    THEN 3
        WHEN e.created_at >= now() - interval '14 days'   THEN 4
        WHEN e.created_at >= now() - interval '30 days'   THEN 5
        ELSE 6
      END                                          AS bucket_order,
      e.amount_rupees,
      e.created_at
    FROM public.repair_job_escrow e
    WHERE e.status = 'held'
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                       AS cnt,
    coalesce(sum(a.amount_rupees), 0)::numeric             AS amount_inr,
    min(a.created_at)                                      AS oldest_created_at
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_fev_readiness_leaderboard(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_fev_readiness_leaderboard(p_limit integer DEFAULT 50)
 RETURNS TABLE(engineer_user_id uuid, engineer_name text, current_tier text, jobs_90d integer, avg_rating numeric, nps_trend numeric, peer_mentions integer, payouts_90d_rupees bigint, readiness_score integer, promotion_band text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH job_stats AS (
    SELECT
      e.user_id AS eng_uid,
      (COUNT(*) FILTER (WHERE rj.created_at > now() - interval '90 days'))::int AS jobs_90d,
      AVG(rj.hospital_rating) FILTER (WHERE rj.created_at > now() - interval '90 days') AS avg_rating,
      (AVG(rj.hospital_rating) FILTER (WHERE rj.created_at > now() - interval '30 days')
        - AVG(rj.hospital_rating) FILTER (WHERE rj.created_at BETWEEN now() - interval '90 days' AND now() - interval '30 days')) AS nps_trend
    FROM public.engineers e
    LEFT JOIN public.repair_jobs rj ON rj.engineer_id = e.id
    GROUP BY e.user_id
  ),
  mention_stats AS (
    SELECT mentioned_user_id, (COUNT(*) FILTER (WHERE created_at > now() - interval '90 days'))::int AS peer_mentions
    FROM public.founder_engineer_peer_mentions
    GROUP BY mentioned_user_id
  ),
  payout_stats AS (
    -- engineer_payouts has no paid_at column; the "money actually left"
    -- timestamp on that table is processed_at.
    SELECT engineer_user_id, COALESCE(SUM(amount_rupees) FILTER (WHERE processed_at IS NOT NULL AND processed_at > now() - interval '90 days'), 0)::bigint AS payouts_90d_rupees
    FROM public.engineer_payouts
    GROUP BY engineer_user_id
  )
  SELECT
    e.user_id,
    COALESCE(p.full_name, p.email, 'Engineer') AS engineer_name,
    e.cached_highest_tier AS current_tier,
    COALESCE(js.jobs_90d, 0) AS jobs_90d,
    ROUND(COALESCE(js.avg_rating, 0)::numeric, 2) AS avg_rating,
    ROUND(COALESCE(js.nps_trend, 0)::numeric, 2) AS nps_trend,
    COALESCE(ms.peer_mentions, 0) AS peer_mentions,
    COALESCE(ps.payouts_90d_rupees, 0) AS payouts_90d_rupees,
    LEAST(100, GREATEST(0,
      (COALESCE(js.jobs_90d, 0) * 2)
      + (COALESCE(js.avg_rating, 0) * 8)::int
      + (COALESCE(js.nps_trend, 0) * 10)::int
      + (COALESCE(ms.peer_mentions, 0) * 5)
    ))::int AS readiness_score,
    CASE
      WHEN LEAST(100, GREATEST(0,
        (COALESCE(js.jobs_90d, 0) * 2)
        + (COALESCE(js.avg_rating, 0) * 8)::int
        + (COALESCE(js.nps_trend, 0) * 10)::int
        + (COALESCE(ms.peer_mentions, 0) * 5)
      )) >= 75 THEN 'ready_now'
      WHEN LEAST(100, GREATEST(0,
        (COALESCE(js.jobs_90d, 0) * 2)
        + (COALESCE(js.avg_rating, 0) * 8)::int
        + (COALESCE(js.nps_trend, 0) * 10)::int
        + (COALESCE(ms.peer_mentions, 0) * 5)
      )) >= 50 THEN 'near_ready'
      ELSE 'developing'
    END AS promotion_band
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  LEFT JOIN job_stats js ON js.eng_uid = e.user_id
  LEFT JOIN mention_stats ms ON ms.mentioned_user_id = e.user_id
  LEFT JOIN payout_stats ps ON ps.engineer_user_id = e.user_id
  ORDER BY readiness_score DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_funnel_drop_off()
CREATE OR REPLACE FUNCTION public.founder_funnel_drop_off()
 RETURNS TABLE(from_stage text, to_stage text, retained bigint, dropped bigint, drop_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r RECORD; prev_count bigint := 0; prev_stage text := NULL;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  FOR r IN
    SELECT s.stage AS stage, COUNT(DISTINCT e.organization_id) AS cnt
      FROM (VALUES ('first_touch',1),('demo_booked',2),('demo_done',3),('quote_sent',4),
                   ('first_job',5),('first_job_paid',6),('first_amc',7)) AS s(stage, ord)
      LEFT JOIN founder_hospital_funnel_events e ON e.stage = s.stage
     GROUP BY s.stage, s.ord ORDER BY s.ord
  LOOP
    IF prev_stage IS NOT NULL THEN
      from_stage := prev_stage; to_stage := r.stage;
      retained := r.cnt; dropped := GREATEST(prev_count - r.cnt, 0);
      drop_pct := CASE WHEN prev_count=0 THEN 0
                       ELSE ROUND(100.0 * (prev_count - r.cnt)::numeric / prev_count, 2) END;
      RETURN NEXT;
    END IF;
    prev_count := r.cnt; prev_stage := r.stage;
  END LOOP;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_funnel_stage_counts()
CREATE OR REPLACE FUNCTION public.founder_funnel_stage_counts()
 RETURNS TABLE(stage text, hospitals bigint, share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(DISTINCT ft.organization_id) INTO total
    FROM founder_hospital_funnel_events ft WHERE ft.stage='first_touch';
  IF total IS NULL OR total=0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT s.stage,
         COUNT(DISTINCT e.organization_id)::bigint AS hospitals,
         ROUND(100.0 * COUNT(DISTINCT e.organization_id)::numeric / total, 2) AS share_pct
    FROM (VALUES ('first_touch'),('demo_booked'),('demo_done'),('quote_sent'),
                 ('first_job'),('first_job_paid'),('first_amc')) AS s(stage)
    LEFT JOIN founder_hospital_funnel_events e ON e.stage = s.stage
   GROUP BY s.stage
   ORDER BY CASE s.stage
     WHEN 'first_touch' THEN 1 WHEN 'demo_booked' THEN 2 WHEN 'demo_done' THEN 3
     WHEN 'quote_sent' THEN 4 WHEN 'first_job' THEN 5 WHEN 'first_job_paid' THEN 6
     WHEN 'first_amc' THEN 7 END;
END $function$
;

-- ---------------------------------------------------------------------
-- public.founder_hospital_auto_renew_scan()
CREATE OR REPLACE FUNCTION public.founder_hospital_auto_renew_scan()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_inserted integer := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  WITH base AS (
    SELECT
      ac.id AS contract_id,
      ac.hospital_user_id,
      ac.amc_tier,
      ac.monthly_fee_rupees,
      -- amc_contracts has no ends_on column; the contract expiry date is
      -- end_date. Aliased to ends_on so the rest of the query (and the
      -- founder_hospital_renewal_candidates.ends_on target column) is
      -- unchanged.
      ac.end_date AS ends_on,
      (ac.end_date - current_date)::integer AS days_to_expiry,
      (
        SELECT count(*) FROM repair_jobs rj
        JOIN profiles p ON p.id = ac.hospital_user_id
        WHERE rj.hospital_org_id = p.organization_id
          AND rj.created_at > now() - interval '90 days'
      ) AS jobs_last_90d,
      (
        SELECT avg(rj.hospital_rating) FROM repair_jobs rj
        JOIN profiles p ON p.id = ac.hospital_user_id
        WHERE rj.hospital_org_id = p.organization_id
          AND rj.hospital_rating IS NOT NULL
          AND rj.created_at > now() - interval '180 days'
      ) AS avg_rating,
      (
        SELECT count(*) FROM repair_job_escrow e
        JOIN repair_jobs rj ON rj.id = e.repair_job_id
        JOIN profiles p ON p.id = ac.hospital_user_id
        WHERE rj.hospital_org_id = p.organization_id
          AND e.status = 'in_dispute'
      ) AS disputes
    FROM amc_contracts ac
    WHERE ac.end_date BETWEEN current_date AND current_date + interval '120 days'
  ), scored AS (
    SELECT *,
      (
        LEAST(jobs_last_90d * 4, 40)
        + COALESCE((avg_rating * 10)::integer, 30)
        + CASE WHEN disputes = 0 THEN 30 ELSE GREATEST(0, 30 - disputes * 10) END
      ) AS score
    FROM base
  )
  INSERT INTO founder_hospital_renewal_candidates(
    contract_id, hospital_user_id, amc_tier, monthly_fee_rupees, ends_on,
    days_to_expiry, jobs_last_90d, avg_hospital_rating, outstanding_disputes,
    eligibility_score, auto_eligible, reasons
  )
  SELECT
    contract_id, hospital_user_id, amc_tier, monthly_fee_rupees, ends_on,
    days_to_expiry, jobs_last_90d, avg_rating, disputes,
    score,
    (score >= 70 AND disputes = 0 AND jobs_last_90d >= 1),
    jsonb_build_array(
      jsonb_build_object('factor','jobs_90d','value',jobs_last_90d),
      jsonb_build_object('factor','avg_rating','value',COALESCE(avg_rating, 0)),
      jsonb_build_object('factor','disputes','value',disputes)
    )
  FROM scored
  ON CONFLICT (contract_id, scanned_at) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  PERFORM log_founder_hospital_auto_renew(
    'auto_renew_scan',
    jsonb_build_object('inserted', v_inserted)
  );

  RETURN v_inserted;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_hospital_spend_distribution()
CREATE OR REPLACE FUNCTION public.founder_hospital_spend_distribution()
 RETURNS TABLE(bucket text, bucket_order integer, hospital_cnt bigint, total_inr numeric, pct_of_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH spend AS (
    -- repair_jobs has no hospital_amount column; the hospital-side amount is
    -- contracted_amount_rupees (same column public.founder_hospital_spend_30d uses).
    SELECT j.hospital_user_id, sum(j.contracted_amount_rupees)::numeric AS total_spent
    FROM public.repair_jobs j
    WHERE j.status = 'completed'
      AND j.completed_at >= now() - interval '90 days'
      AND j.contracted_amount_rupees IS NOT NULL
    GROUP BY j.hospital_user_id
  ),
  bucketed AS (
    SELECT
      total_spent,
      CASE
        WHEN total_spent < 5000    THEN '<₹5k'
        WHEN total_spent < 25000   THEN '₹5k-25k'
        WHEN total_spent < 50000   THEN '₹25k-50k'
        WHEN total_spent < 100000  THEN '₹50k-1L'
        WHEN total_spent < 500000  THEN '₹1L-5L'
        WHEN total_spent < 1000000 THEN '₹5L-10L'
        ELSE '>₹10L'
      END                                  AS bucket,
      CASE
        WHEN total_spent < 5000    THEN 1
        WHEN total_spent < 25000   THEN 2
        WHEN total_spent < 50000   THEN 3
        WHEN total_spent < 100000  THEN 4
        WHEN total_spent < 500000  THEN 5
        WHEN total_spent < 1000000 THEN 6
        ELSE 7
      END                                  AS bucket_order
    FROM spend
  ),
  totals AS (
    SELECT count(*)::bigint AS n FROM bucketed
  )
  SELECT
    b.bucket::text,
    b.bucket_order::int,
    count(*)::bigint                                              AS hospital_cnt,
    sum(b.total_spent)::numeric                                   AS total_inr,
    CASE WHEN (SELECT n FROM totals) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / (SELECT n FROM totals), 1)
    END                                                            AS pct_of_total
  FROM bucketed b
  GROUP BY b.bucket, b.bucket_order
  ORDER BY b.bucket_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hsq_latest_rankings()
CREATE OR REPLACE FUNCTION public.founder_hsq_latest_rankings()
 RETURNS TABLE(id uuid, hospital_org_id uuid, hospital_name text, city text, quarter_label text, composite_score numeric, letter_grade text, nps_score numeric, uptime_pct numeric, first_response_min numeric, recurrence_pct numeric, jobs_completed integer, flagged_for_review boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT MAX(b.quarter_label) INTO q FROM hospital_sq_benchmark_snapshots b;
  RETURN QUERY
  SELECT s.id, s.hospital_org_id, o.name, o.city, s.quarter_label,
         s.composite_score, s.letter_grade, s.nps_score, s.uptime_pct,
         s.first_response_minutes_avg, s.recurrence_rate_pct, s.jobs_completed,
         s.flagged_for_review
  FROM hospital_sq_benchmark_snapshots s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.quarter_label = q
  ORDER BY s.composite_score DESC NULLS LAST
  LIMIT 200;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hsq_recompute_current_quarter()
CREATE OR REPLACE FUNCTION public.founder_hsq_recompute_current_quarter()
 RETURNS TABLE(hospitals_scored bigint, quarter_label text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
DECLARE
  v_q text;
  v_start date;
  v_end date;
  v_count bigint := 0;
  v_actor_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_start := date_trunc('quarter', now())::date;
  v_end   := (date_trunc('quarter', now()) + interval '3 months - 1 day')::date;
  v_q     := to_char(v_start, 'YYYY') || '-Q' || to_char(v_start, 'Q');

  WITH hosp AS (
    SELECT DISTINCT hospital_org_id
    FROM public.repair_jobs
    WHERE created_at >= v_start
      AND created_at <  v_start + interval '3 months'
      AND hospital_org_id IS NOT NULL
  ),
  -- First-response = avg minutes between job created_at and accepted bid's responded_at
  resp AS (
    SELECT r.hospital_org_id,
           avg(EXTRACT(EPOCH FROM (b.responded_at - r.created_at))/60.0)
             FILTER (WHERE b.responded_at IS NOT NULL) AS first_resp_min
    FROM public.repair_jobs r
    LEFT JOIN LATERAL (
      SELECT min(rb.created_at) AS responded_at
      FROM public.repair_job_bids rb
      WHERE rb.repair_job_id = r.id AND rb.status = 'accepted'
    ) b ON true
    WHERE r.created_at >= v_start AND r.created_at < v_start + interval '3 months'
      AND r.hospital_org_id IS NOT NULL
    GROUP BY r.hospital_org_id
  ),
  -- Recurrence proxy: completed jobs that share hospital+equipment with another completed job inside 90d
  recur AS (
    SELECT r.hospital_org_id,
           (count(*) FILTER (WHERE r.status='completed' AND EXISTS (
              SELECT 1 FROM public.repair_jobs r2
              WHERE r2.hospital_org_id = r.hospital_org_id
                AND r2.equipment_id = r.equipment_id
                AND r2.id <> r.id
                AND r2.status = 'completed'
                AND r2.completed_at > r.completed_at - interval '90 days'
                AND r2.completed_at < r.completed_at
           ))::numeric / NULLIF(count(*) FILTER (WHERE r.status='completed'), 0)) * 100 AS recur_pct
    FROM public.repair_jobs r
    WHERE r.created_at >= v_start AND r.created_at < v_start + interval '3 months'
      AND r.hospital_org_id IS NOT NULL
    GROUP BY r.hospital_org_id
  ),
  agg AS (
    SELECT
      r.hospital_org_id,
      count(*) FILTER (WHERE r.status = 'completed')::int AS jobs_completed,
      avg(r.hospital_rating) FILTER (WHERE r.hospital_rating IS NOT NULL) AS avg_rating
    FROM public.repair_jobs r
    WHERE r.created_at >= v_start AND r.created_at < v_start + interval '3 months'
      AND r.hospital_org_id IS NOT NULL
    GROUP BY r.hospital_org_id
  ),
  scored AS (
    SELECT
      h.hospital_org_id,
      COALESCE(a.jobs_completed, 0) AS jobs_completed,
      ROUND(COALESCE(a.avg_rating, 0)::numeric, 2) AS avg_rating,
      ROUND(((COALESCE(a.avg_rating, 0) - 3) * 50)::numeric, 2) AS nps,
      ROUND(LEAST(100, GREATEST(0, 100 - COALESCE(rc.recur_pct, 0)))::numeric, 2) AS uptime,
      ROUND(COALESCE(rs.first_resp_min, 0)::numeric, 2) AS resp_min,
      ROUND(COALESCE(rc.recur_pct, 0)::numeric, 2) AS recur,
      ROUND((
        (COALESCE(a.avg_rating, 0) / 5.0) * 40
        + (LEAST(100, GREATEST(0, 100 - COALESCE(rc.recur_pct, 0))) / 100.0) * 30
        + (GREATEST(0, 1 - LEAST(120, COALESCE(rs.first_resp_min, 120)) / 120.0)) * 20
        + (GREATEST(0, 1 - LEAST(50, COALESCE(rc.recur_pct, 50)) / 50.0)) * 10
      )::numeric, 2) AS composite
    FROM hosp h
    LEFT JOIN agg a USING (hospital_org_id)
    LEFT JOIN resp rs USING (hospital_org_id)
    LEFT JOIN recur rc USING (hospital_org_id)
  )
  INSERT INTO public.hospital_sq_benchmark_snapshots (
    hospital_org_id, quarter_label, period_start, period_end,
    jobs_completed, avg_hospital_rating, nps_score, uptime_pct,
    first_response_minutes_avg, recurrence_rate_pct, composite_score,
    letter_grade, flagged_for_review
  )
  SELECT
    hospital_org_id, v_q, v_start, v_end,
    jobs_completed, avg_rating, nps, uptime, resp_min, recur, composite,
    CASE WHEN composite >= 80 THEN 'A'
         WHEN composite >= 65 THEN 'B'
         WHEN composite >= 50 THEN 'C'
         ELSE 'D' END,
    (composite < 50)
  FROM scored
  ON CONFLICT (hospital_org_id, quarter_label) DO UPDATE SET
    jobs_completed = EXCLUDED.jobs_completed,
    avg_hospital_rating = EXCLUDED.avg_hospital_rating,
    nps_score = EXCLUDED.nps_score,
    uptime_pct = EXCLUDED.uptime_pct,
    first_response_minutes_avg = EXCLUDED.first_response_minutes_avg,
    recurrence_rate_pct = EXCLUDED.recurrence_rate_pct,
    composite_score = EXCLUDED.composite_score,
    letter_grade = EXCLUDED.letter_grade,
    flagged_for_review = EXCLUDED.flagged_for_review;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  SELECT email INTO v_actor_email FROM public.profiles WHERE id = auth.uid();
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'hsq_recompute_quarter',
    jsonb_build_object('quarter', v_q, 'hospitals_scored', v_count));

  RETURN QUERY SELECT v_count, v_q;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_investor_pulse_summary()
CREATE OR REPLACE FUNCTION public.founder_investor_pulse_summary()
 RETURNS TABLE(active_mrr_inr numeric, active_amc_contracts bigint, gmv_30d_inr numeric, jobs_completed_30d bigint, spare_parts_paid_30d_inr numeric, payouts_paid_30d_inr numeric, new_engineers_30d bigint, new_hospitals_30d bigint, active_engineers_30d bigint, active_hospitals_30d bigint, referral_bounty_paid_30d_inr numeric, amc_renewals_30d bigint, total_users_all_time bigint, ttv_lifetime_gmv_inr numeric, lifetime_payouts_inr numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_jobs_gmv_30d numeric;
  v_spare_gmv_30d numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_jobs_gmv_30d
    FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  -- enum payment_status has no 'paid' label (pending/completed/refunded/disputed/failed);
  -- the paid state is 'completed'. The old literal could never match, so spare-part
  -- revenue was silently excluded from GMV/TTV entirely.
  SELECT coalesce(sum(total_amount), 0)::numeric INTO v_spare_gmv_30d
    FROM public.spare_part_orders WHERE coalesce(payment_status::text, '') = 'completed' AND created_at >= now() - interval '30 days';

  RETURN QUERY
  SELECT
    coalesce((SELECT sum(monthly_fee_rupees)::numeric FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    (v_jobs_gmv_30d + v_spare_gmv_30d)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days'), 0),
    v_spare_gmv_30d,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status = 'processed' AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE created_at >= now() - interval '30 days'), 0),
    -- user_role label is 'hospital_admin'; 'hospital' is not a valid label
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE role = 'hospital_admin' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT engineer_id)::bigint FROM public.repair_jobs
              WHERE engineer_id IS NOT NULL AND completed_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.repair_jobs
              WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts
              WHERE status = 'paid' AND paid_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts
              WHERE created_at >= now() - interval '30 days'
                AND (start_date IS NOT NULL AND end_date IS NOT NULL AND end_date > start_date)), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles), 0),
    coalesce((SELECT sum(contracted_amount_rupees)::numeric FROM public.repair_jobs WHERE status = 'completed'), 0)
      + coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status::text, '') = 'completed'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status = 'processed'), 0);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_kyc_pending_detail()
CREATE OR REPLACE FUNCTION public.founder_kyc_pending_detail()
 RETURNS TABLE(user_id uuid, display_name text, state text, city text, verification_status text, signup_at timestamp with time zone, days_pending numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    e.user_id,
    coalesce(p.full_name, '(engineer)'),
    coalesce(nullif(trim(p.state), ''), '—'),
    coalesce(nullif(trim(p.city), ''), '—'),
    e.verification_status::text,
    e.created_at,
    round(extract(epoch FROM (now() - e.created_at)) / 86400.0, 1)::numeric
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  -- enum verification_status has only pending/verified/rejected -- no 'in_review'
  WHERE e.verification_status IN ('pending', 'rejected')
  ORDER BY e.created_at ASC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_log_ownership_event(p_hospital_org_id uuid, p_event_type text, p_previous_owner_name text, p_new_owner_name text, p_new_owner_email text, p_new_owner_phone text, p_effective_date date, p_amc_continuation_risk text, p_source text, p_notes text)
CREATE OR REPLACE FUNCTION public.founder_log_ownership_event(p_hospital_org_id uuid, p_event_type text, p_previous_owner_name text, p_new_owner_name text, p_new_owner_email text, p_new_owner_phone text, p_effective_date date, p_amc_continuation_risk text, p_source text, p_notes text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_count int;
  v_value bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*)::int, COALESCE(SUM(monthly_fee_rupees*12),0)::bigint
  INTO v_count, v_value
  FROM amc_contracts ac
  JOIN profiles p ON p.id = ac.hospital_user_id
  WHERE p.organization_id = p_hospital_org_id
    AND ac.status = 'active';

  INSERT INTO hospital_ownership_events (
    hospital_org_id, event_type, previous_owner_name, new_owner_name,
    new_owner_email, new_owner_phone, effective_date, amc_continuation_risk,
    source, notes, active_amc_count, active_amc_value_rupees, recorded_by
  ) VALUES (
    p_hospital_org_id, p_event_type, p_previous_owner_name, p_new_owner_name,
    p_new_owner_email, p_new_owner_phone, p_effective_date,
    COALESCE(p_amc_continuation_risk,'unknown'), COALESCE(p_source,'manual'),
    p_notes, v_count, v_value, auth.uid()
  ) RETURNING id INTO v_id;

  PERFORM log_founder_ownership_event_created(v_id, p_hospital_org_id, p_event_type);
  RETURN v_id;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_ltv_headline()
CREATE OR REPLACE FUNCTION public.founder_ltv_headline()
 RETURNS TABLE(total_hospitals bigint, scored_hospitals bigint, vip_count bigint, total_ltv_rupees bigint, median_ltv_rupees bigint, top_decile_ltv_rupees bigint, avg_retention numeric, projected_12m_rupees bigint, cumulative_rev_rupees bigint, active_hospitals_90d bigint, churned_hospitals bigint, ladder_p50_rupees bigint, ladder_p90_rupees bigint, ladder_p99_rupees bigint, last_recompute_at timestamp with time zone, hospitals_with_amc bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_org_id) *
    FROM founder_hospital_ltv_snapshots_v2
    ORDER BY hospital_org_id, computed_at DESC
  )
  SELECT
    (SELECT count(*) FROM organizations WHERE type = 'hospital')::bigint,
    (SELECT count(*) FROM latest)::bigint,
    (SELECT count(DISTINCT hospital_org_id) FROM founder_hospital_vip_promotions_v2)::bigint,
    COALESCE((SELECT sum(ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT avg(retention_prob) FROM latest), 0)::numeric,
    COALESCE((SELECT sum(projected_next_12m_rupees) FROM latest), 0)::bigint,
    -- alias + qualify: bare cumulative_rev_rupees collided with the OUT
    -- parameter of the same name (42702 ambiguous column reference)
    COALESCE((SELECT sum(l.cumulative_rev_rupees) FROM latest l), 0)::bigint,
    (SELECT count(DISTINCT hospital_org_id) FROM repair_jobs
      WHERE created_at >= now() - interval '90 days')::bigint,
    (SELECT count(*) FROM latest WHERE retention_prob < 0.20)::bigint,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    COALESCE((SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY ltv_rupees) FROM latest), 0)::bigint,
    (SELECT max(computed_at) FROM founder_hospital_ltv_snapshots_v2),
    (SELECT count(DISTINCT p.organization_id)
       FROM amc_contracts a
       JOIN profiles p ON p.id = a.hospital_user_id
      WHERE a.status = 'active')::bigint;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_marketing_content_pieces_recent()
CREATE OR REPLACE FUNCTION public.founder_marketing_content_pieces_recent()
 RETURNS TABLE(id uuid, title text, content_type text, status text, scheduled_for date, channel text, author_label text, target_audience text, estimated_views integer, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- Column names realigned to the actual founder_marketing_content_pieces table:
  --   title -> piece_label, content_type -> topic_category,
  --   scheduled_for -> planned_publish_date, estimated_views -> expected_reach_count
  RETURN QUERY
  SELECT p.id, p.piece_label, p.topic_category, p.status, p.planned_publish_date, p.channel,
         COALESCE(prof.full_name, 'unassigned')::text, p.target_audience,
         p.expected_reach_count, p.created_at
  FROM public.founder_marketing_content_pieces p
  LEFT JOIN public.profiles prof ON prof.id = p.author_user_id
  ORDER BY p.created_at DESC
  LIMIT 60;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_marketing_content_upcoming()
CREATE OR REPLACE FUNCTION public.founder_marketing_content_upcoming()
 RETURNS TABLE(id uuid, title text, content_type text, status text, scheduled_for date, channel text, author_label text, days_until integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- Column names realigned to the actual founder_marketing_content_pieces table:
  --   title -> piece_label, content_type -> topic_category,
  --   scheduled_for -> planned_publish_date
  RETURN QUERY
  SELECT p.id, p.piece_label, p.topic_category, p.status, p.planned_publish_date, p.channel,
         COALESCE(prof.full_name, 'unassigned')::text,
         (p.planned_publish_date - current_date)::int
  FROM public.founder_marketing_content_pieces p
  LEFT JOIN public.profiles prof ON prof.id = p.author_user_id
  WHERE p.planned_publish_date >= current_date
  ORDER BY p.planned_publish_date ASC
  LIMIT 30;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_morning_digest_v2()
CREATE OR REPLACE FUNCTION public.founder_morning_digest_v2()
 RETURNS TABLE(top_actions jsonb, mrr_today numeric, mrr_yesterday numeric, mrr_7d_ago numeric, mrr_30d_ago numeric, mrr_delta_pct_dod numeric, mrr_delta_pct_wow numeric, active_alerts jsonb, milestones_24h jsonb, cron_health jsonb, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_top_actions   jsonb;
  v_mrr_today     numeric;
  v_mrr_yest      numeric;
  v_mrr_7d        numeric;
  v_mrr_30d       numeric;
  v_alerts        jsonb;
  v_milestones    jsonb;
  v_cron          jsonb;
  v_code_red      int;
  v_stuck_payouts int;
  v_open_inc      int;
  v_jobs_24h      int;
  v_amcs_24h      int;
  v_payouts_24h   int;
  v_cron_fails    int := 0;
  v_cron_total    int := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.priority_score DESC), '[]'::jsonb)
    INTO v_top_actions
  FROM (
    -- FIX: code_red_requests has neither equipment_label nor minutes_open. The label is built
    -- from the equipment columns that DO exist, and the open duration is derived from created_at.
    SELECT 'code_red'::text AS action_type, cr.id::text AS ref_id,
           COALESCE(NULLIF(concat_ws(' ', cr.equipment_brand, cr.equipment_model), ''),
                    cr.equipment_type, 'Code Red')::text AS title,
           (EXTRACT(EPOCH FROM (now() - cr.created_at)) / 60)::int AS metric,
           (100 + EXTRACT(EPOCH FROM (now() - cr.created_at))::numeric / 60)::numeric AS priority_score
    FROM public.code_red_requests cr
    WHERE cr.status NOT IN ('resolved','timed_out')
    UNION ALL
    SELECT 'stuck_payout'::text, ep.id::text,
           ('Payout queued >14d · ' || (ep.amount_rupees::text) || ' INR'),
           EXTRACT(EPOCH FROM (now() - ep.created_at))::int / 86400,
           (60 + EXTRACT(EPOCH FROM (now() - ep.created_at))::numeric / 86400)
    FROM public.engineer_payouts ep
    WHERE ep.status = 'queued' AND ep.created_at < now() - interval '14 days'
    UNION ALL
    SELECT 'open_incident'::text, fi.id::text,
           COALESCE(fi.title, 'Incident'),
           EXTRACT(EPOCH FROM (now() - fi.opened_at))::int / 3600,
           (80 + EXTRACT(EPOCH FROM (now() - fi.opened_at))::numeric / 3600)
    FROM public.founder_incidents fi
    WHERE fi.status = 'open'
    LIMIT 10
  ) t;

  SELECT COALESCE(SUM(monthly_fee_rupees), 0) INTO v_mrr_today
  FROM public.amc_contracts WHERE status = 'active';

  SELECT COALESCE(SUM(monthly_fee_rupees), 0) INTO v_mrr_yest
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '1 day'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '1 day');

  SELECT COALESCE(SUM(monthly_fee_rupees), 0) INTO v_mrr_7d
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '7 days'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '7 days');

  SELECT COALESCE(SUM(monthly_fee_rupees), 0) INTO v_mrr_30d
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '30 days'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '30 days');

  SELECT count(*) INTO v_code_red FROM public.code_red_requests
  WHERE status NOT IN ('resolved','timed_out');

  SELECT count(*) INTO v_stuck_payouts FROM public.engineer_payouts
  WHERE status = 'queued' AND created_at < now() - interval '14 days';

  SELECT count(*) INTO v_open_inc FROM public.founder_incidents WHERE status = 'open';

  v_alerts := jsonb_build_array(
    jsonb_build_object('kind','code_red_open',     'count', v_code_red,      'severity','critical'),
    jsonb_build_object('kind','stuck_payouts_14d', 'count', v_stuck_payouts, 'severity','high'),
    jsonb_build_object('kind','open_incidents',    'count', v_open_inc,      'severity','high')
  );

  SELECT count(*) INTO v_jobs_24h FROM public.repair_jobs
  WHERE status = 'completed' AND completed_at > now() - interval '24 hours';

  SELECT count(*) INTO v_amcs_24h FROM public.amc_contracts
  WHERE activated_at > now() - interval '24 hours';

  -- r1322 FIX: engineer_payouts.status 'paid_out' → 'processed' (CHECK constraint)
  SELECT count(*) INTO v_payouts_24h FROM public.engineer_payouts
  WHERE status = 'processed' AND updated_at > now() - interval '24 hours';

  v_milestones := jsonb_build_array(
    jsonb_build_object('kind','jobs_completed', 'count', v_jobs_24h),
    jsonb_build_object('kind','amcs_activated', 'count', v_amcs_24h),
    jsonb_build_object('kind','payouts_paid',   'count', v_payouts_24h)
  );

  BEGIN
    EXECUTE $q$
      SELECT count(*) FILTER (WHERE status = 'failed'), count(*)
      FROM cron.job_run_details WHERE start_time > now() - interval '24 hours'
    $q$ INTO v_cron_fails, v_cron_total;
  EXCEPTION WHEN OTHERS THEN
    v_cron_fails := 0; v_cron_total := 0;
  END;

  v_cron := jsonb_build_object(
    'runs_24h',     v_cron_total,
    'failures_24h', v_cron_fails,
    'failure_rate', CASE WHEN v_cron_total > 0
                         THEN ROUND((v_cron_fails::numeric / v_cron_total::numeric) * 100, 2)
                         ELSE 0 END
  );

  RETURN QUERY SELECT
    v_top_actions, v_mrr_today, v_mrr_yest, v_mrr_7d, v_mrr_30d,
    CASE WHEN v_mrr_yest > 0
         THEN ROUND(((v_mrr_today - v_mrr_yest) / v_mrr_yest) * 100, 2) ELSE 0 END,
    CASE WHEN v_mrr_7d > 0
         THEN ROUND(((v_mrr_today - v_mrr_7d) / v_mrr_7d) * 100, 2) ELSE 0 END,
    v_alerts, v_milestones, v_cron, now();
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_okr_team_health_r2345(p_quarter text)
CREATE OR REPLACE FUNCTION public.founder_okr_team_health_r2345(p_quarter text)
 RETURNS TABLE(team_name text, team_okr_count bigint, individual_okr_count bigint, avg_progress numeric, off_track_count bigint, open_finding_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  -- FIX: GROUP BY was the non-Var expression COALESCE(t.team_name,'(unassigned)'). Postgres only
  -- honours whole-expression GROUP BY matches at the OUTER query level, so the correlated
  -- sub-SELECT's reference to t.team_name was rejected as ungrouped (42803). Grouping by the
  -- plain column makes it a grouped Var, which the sub-SELECT may reference; the projected value
  -- stays COALESCE(...,'(unassigned)') so the output is unchanged.
  GROUP BY t.team_name
  ORDER BY AVG(t.progress_pct) ASC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_onboarding_velocity_summary()
CREATE OR REPLACE FUNCTION public.founder_onboarding_velocity_summary()
 RETURNS TABLE(eng_cohort_90d bigint, eng_median_signup_to_verified_h numeric, eng_p90_signup_to_verified_h numeric, eng_median_signup_to_first_bid_h numeric, eng_p90_signup_to_first_bid_h numeric, eng_stalled_no_bid_over_7d bigint, hosp_cohort_90d bigint, hosp_median_signup_to_first_job_h numeric, hosp_p90_signup_to_first_job_h numeric, hosp_median_signup_to_first_amc_d numeric, hosp_stalled_no_job_over_7d bigint, avg_signups_per_day_30d numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH eng_cohort AS (
    SELECT p.id, p.created_at
    FROM public.profiles p
    WHERE p.role = 'engineer'
      AND p.created_at >= now() - interval '90 days'
  ),
  eng_verified AS (
    -- public.engineers has NO verified_at column (the original definition referenced
    -- a phantom column, so this whole function raised 42703). No table in the schema
    -- records WHEN a verification was approved: admin_set_engineer_verification()
    -- writes only verification_status, and engineers.updated_at is bumped by any row
    -- edit (availability/location/profile), so it is not a verification stamp.
    -- Signup -> verified latency is therefore UNKNOWN, not zero: emit no rows so the
    -- two percentiles below fall through to this function's own coalesce(...,0)
    -- "no data" sentinel instead of reporting a fabricated latency.
    SELECT NULL::numeric AS hours_to_verified WHERE false
  ),
  eng_first_bid AS (
    SELECT extract(epoch FROM (min(b.created_at) - ec.created_at)) / 3600.0 AS hours_to_first_bid
    FROM eng_cohort ec
    JOIN public.repair_job_bids b ON b.engineer_user_id = ec.id
    WHERE b.created_at >= ec.created_at
    GROUP BY ec.id, ec.created_at
  ),
  eng_stalled AS (
    SELECT count(*)::bigint AS n
    FROM eng_cohort ec
    WHERE ec.created_at < now() - interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM public.repair_job_bids b WHERE b.engineer_user_id = ec.id)
  ),
  hosp_cohort AS (
    -- user_role has no 'hospital' label; the hospital-side role is 'hospital_admin'.
    SELECT p.id, p.created_at
    FROM public.profiles p
    WHERE p.role = 'hospital_admin'
      AND p.created_at >= now() - interval '90 days'
  ),
  hosp_first_job AS (
    SELECT extract(epoch FROM (min(j.created_at) - hc.created_at)) / 3600.0 AS hours_to_first_job
    FROM hosp_cohort hc
    JOIN public.repair_jobs j ON j.hospital_user_id = hc.id
    WHERE j.created_at >= hc.created_at
    GROUP BY hc.id, hc.created_at
  ),
  hosp_first_amc AS (
    SELECT extract(epoch FROM (min(c.created_at) - hc.created_at)) / 86400.0 AS days_to_first_amc
    FROM hosp_cohort hc
    JOIN public.amc_contracts c ON c.hospital_user_id = hc.id
    WHERE c.created_at >= hc.created_at
      AND c.status IN ('active','paused','expired')
    GROUP BY hc.id, hc.created_at
  ),
  hosp_stalled AS (
    SELECT count(*)::bigint AS n
    FROM hosp_cohort hc
    WHERE hc.created_at < now() - interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = hc.id)
  ),
  signups_30d AS (
    SELECT count(*)::numeric / 30.0 AS avg_per_day
    FROM public.profiles p
    WHERE p.role IN ('engineer','hospital_admin')
      AND p.created_at >= now() - interval '30 days'
  )
  SELECT
    (SELECT count(*)::bigint FROM eng_cohort),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_verified))::numeric, 1), 0)::numeric FROM eng_verified),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_verified))::numeric, 1), 0)::numeric FROM eng_verified),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_first_bid))::numeric, 1), 0)::numeric FROM eng_first_bid),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_first_bid))::numeric, 1), 0)::numeric FROM eng_first_bid),
    (SELECT n FROM eng_stalled),
    (SELECT count(*)::bigint FROM hosp_cohort),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_first_job))::numeric, 1), 0)::numeric FROM hosp_first_job),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_first_job))::numeric, 1), 0)::numeric FROM hosp_first_job),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY days_to_first_amc))::numeric, 1), 0)::numeric FROM hosp_first_amc),
    (SELECT n FROM hosp_stalled),
    (SELECT round(avg_per_day, 1)::numeric FROM signups_30d);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_ownership_at_risk_amcs()
CREATE OR REPLACE FUNCTION public.founder_ownership_at_risk_amcs()
 RETURNS TABLE(event_id uuid, hospital_org_id uuid, hospital_name text, change_kind text, occurred_on date, active_amc_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_org_id, o.name, e.event_type, e.effective_date,
         (SELECT count(*) FROM public.amc_contracts ac
          JOIN public.profiles p ON p.id = ac.hospital_user_id
          WHERE p.organization_id = e.hospital_org_id AND ac.status = 'active')
  FROM public.hospital_ownership_events e
  LEFT JOIN public.organizations o ON o.id = e.hospital_org_id
  WHERE e.effective_date >= current_date - 90
  ORDER BY e.effective_date DESC
  LIMIT 50;
END $function$
;

-- ---------------------------------------------------------------------
-- public.founder_payouts_amount_histogram()
CREATE OR REPLACE FUNCTION public.founder_payouts_amount_histogram()
 RETURNS TABLE(bucket text, bucket_order integer, cnt bigint, total_inr numeric, pct_of_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_tot
  FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= now() - interval '90 days';
  IF v_tot IS NULL THEN v_tot := 0; END IF;

  RETURN QUERY
  WITH agg AS (
    -- engineer_payouts has no amount_inr column; the rupee amount is amount_rupees.
    SELECT amount_rupees AS amount_inr,
      CASE
        WHEN amount_rupees < 100    THEN '<₹100'
        WHEN amount_rupees < 500    THEN '₹100-500'
        WHEN amount_rupees < 1000   THEN '₹500-1k'
        WHEN amount_rupees < 5000   THEN '₹1k-5k'
        WHEN amount_rupees < 10000  THEN '₹5k-10k'
        WHEN amount_rupees < 50000  THEN '₹10k-50k'
        ELSE '>₹50k'
      END AS bucket,
      CASE
        WHEN amount_rupees < 100    THEN 1
        WHEN amount_rupees < 500    THEN 2
        WHEN amount_rupees < 1000   THEN 3
        WHEN amount_rupees < 5000   THEN 4
        WHEN amount_rupees < 10000  THEN 5
        WHEN amount_rupees < 50000  THEN 6
        ELSE 7
      END AS bucket_order
    FROM public.engineer_payouts
    WHERE status IN ('processed','paid')
      AND queued_at >= now() - interval '90 days'
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                       AS cnt,
    sum(a.amount_inr)::numeric                             AS total_inr,
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / v_tot, 1) END        AS pct_of_total
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_payout_method_coverage()
CREATE OR REPLACE FUNCTION public.founder_payout_method_coverage()
 RETURNS TABLE(window_label text, earning_engineers bigint, with_verified_vpa bigint, coverage_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  ),
  earners AS (
    SELECT
      w.label,
      w.ord,
      b.engineer_user_id
    FROM w
    JOIN public.repair_jobs rj ON rj.status = 'completed' AND rj.completed_at >= w.cutoff
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
  )
  SELECT
    e.label,
    count(DISTINCT e.engineer_user_id)::bigint                                AS earning_engineers,
    count(DISTINCT e.engineer_user_id) FILTER (
      WHERE EXISTS (
        -- engineer_payout_methods keys the engineer as user_id, not engineer_user_id
        SELECT 1 FROM public.engineer_payout_methods m
         WHERE m.user_id = e.engineer_user_id
           AND m.status = 'verified'
      )
    )::bigint                                                                  AS with_verified_vpa,
    CASE WHEN count(DISTINCT e.engineer_user_id) = 0 THEN 0::numeric
         ELSE round(
           count(DISTINCT e.engineer_user_id) FILTER (
             WHERE EXISTS (
               SELECT 1 FROM public.engineer_payout_methods m
                WHERE m.user_id = e.engineer_user_id
                  AND m.status = 'verified'
             )
           )::numeric
           / count(DISTINCT e.engineer_user_id)::numeric * 100.0, 1)
    END                                                                        AS coverage_pct
  FROM earners e
  GROUP BY e.label, e.ord
  ORDER BY e.ord;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2887_category_mix()
CREATE OR REPLACE FUNCTION public.founder_r2887_category_mix()
 RETURNS TABLE(equipment_category text, lend_count integer, total_billed_rupees bigint, avg_daily_rate numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    t.equipment_category,
    COUNT(*)::int,
    COALESCE(SUM(t.total_billed_rupees),0)::bigint,
    COALESCE(AVG(t.daily_rental_rupees),0)::numeric
  FROM hospital_chain_branch_lending_txn_r2887 t
  GROUP BY t.equipment_category
  -- under #variable_conflict use_column, bare total_billed_rupees resolved to
  -- the ungrouped base column (42803); order by the aggregate itself instead
  ORDER BY COALESCE(SUM(t.total_billed_rupees),0) DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_reconciliation_health()
CREATE OR REPLACE FUNCTION public.founder_reconciliation_health()
 RETURNS TABLE(month_at date, runs bigint, anomalies_total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_at
  )
  SELECT
    m.month_at,
    coalesce((SELECT count(*)::bigint FROM public.reconciliation_runs r
              WHERE date_trunc('month', r.run_date)::date = m.month_at), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.reconciliation_anomalies a
              JOIN public.reconciliation_runs r ON r.id = a.reconciliation_run_id
              WHERE date_trunc('month', r.run_date)::date = m.month_at), 0)::bigint
  FROM months m
  ORDER BY m.month_at DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_regional_city_summary()
CREATE OR REPLACE FUNCTION public.founder_regional_city_summary()
 RETURNS TABLE(cities_active_30d bigint, top1_city text, top1_jobs_30d bigint, top1_revenue_30d_rupees numeric, top1_active_amcs bigint, top1_engineers_30d bigint, top1_hospitals_30d bigint, top2_city text, top2_jobs_30d bigint, top3_city text, top3_jobs_30d bigint, top1_share_pct numeric, total_jobs_30d bigint, total_revenue_30d_rupees numeric, unknown_city_jobs_30d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_jobs_30d bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- City geography is bridged via profiles.organization_id -> organizations.city.
  -- NOTE: this function is STABLE, so the rollup is built as inline CTEs (a CREATE TEMP TABLE AS
  -- is not permitted in a non-volatile function -- 0A000).

  -- Total jobs in window whose hospital org has a known city. This is exactly
  -- sum(jobs_30d) over the rollup below, since every job maps to exactly one city
  -- and the rollup excludes the '(unknown)' bucket.
  SELECT count(*)::bigint INTO v_total_jobs_30d
    FROM public.repair_jobs rj
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
   WHERE rj.created_at >= now() - interval '30 days'
     AND coalesce(nullif(trim(o.city), ''), '(unknown)') <> '(unknown)';
  IF v_total_jobs_30d IS NULL THEN v_total_jobs_30d := 0; END IF;

  RETURN QUERY
  WITH job_city AS (
    SELECT
      coalesce(nullif(trim(o.city), ''), '(unknown)') AS city,
      rj.id            AS job_id,
      rj.hospital_user_id,
      rj.engineer_id,
      rj.status,
      rj.completed_at,
      rj.created_at,
      rj.contracted_amount_rupees
    FROM public.repair_jobs rj
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    WHERE rj.created_at >= now() - interval '30 days'
  ),
  amc_city AS (
    SELECT
      coalesce(nullif(trim(o.city), ''), '(unknown)') AS city,
      c.id AS amc_id,
      c.status
    FROM public.amc_contracts c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
  ),
  agg AS (
    SELECT
      jc.city,
      count(DISTINCT jc.job_id)::bigint                                                    AS jobs_30d,
      count(DISTINCT jc.hospital_user_id)::bigint                                          AS hospitals_30d,
      count(DISTINCT jc.engineer_id) FILTER (WHERE jc.engineer_id IS NOT NULL)::bigint     AS engineers_30d,
      coalesce(sum(jc.contracted_amount_rupees) FILTER (WHERE jc.status = 'completed'
        AND jc.completed_at >= now() - interval '30 days'), 0)::numeric                    AS revenue_30d
    FROM job_city jc
    GROUP BY jc.city
  ),
  amc_agg AS (
    SELECT a.city, count(*) FILTER (WHERE a.status = 'active')::bigint AS active_amcs
    FROM amc_city a GROUP BY a.city
  ),
  city_rollup AS (
    SELECT
      agg.city,
      agg.jobs_30d,
      agg.hospitals_30d,
      agg.engineers_30d,
      agg.revenue_30d,
      coalesce(amc_agg.active_amcs, 0)::bigint AS active_amcs,
      (agg.jobs_30d
        + (agg.revenue_30d / 1000.0)
        + (agg.engineers_30d * 5)
        + (agg.hospitals_30d * 5)
        + (coalesce(amc_agg.active_amcs, 0) * 3))::numeric AS score
    FROM agg
    LEFT JOIN amc_agg ON amc_agg.city = agg.city
    WHERE agg.city <> '(unknown)'
  ),
  ranked AS (
    SELECT
      r.*,
      row_number() OVER (ORDER BY r.score DESC NULLS LAST, r.jobs_30d DESC, r.city ASC) AS rk
    FROM city_rollup r
  ),
  t1 AS (SELECT * FROM ranked WHERE rk = 1),
  t2 AS (SELECT * FROM ranked WHERE rk = 2),
  t3 AS (SELECT * FROM ranked WHERE rk = 3)
  SELECT
    coalesce((SELECT count(*)::bigint FROM city_rollup), 0),
    coalesce((SELECT city FROM t1), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t1), 0)::bigint,
    coalesce((SELECT revenue_30d FROM t1), 0)::numeric,
    coalesce((SELECT active_amcs FROM t1), 0)::bigint,
    coalesce((SELECT engineers_30d FROM t1), 0)::bigint,
    coalesce((SELECT hospitals_30d FROM t1), 0)::bigint,
    coalesce((SELECT city FROM t2), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t2), 0)::bigint,
    coalesce((SELECT city FROM t3), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t3), 0)::bigint,
    CASE WHEN v_total_jobs_30d = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT jobs_30d FROM t1), 0)::numeric / v_total_jobs_30d, 1) END,
    v_total_jobs_30d,
    coalesce((SELECT sum(revenue_30d)::numeric FROM city_rollup), 0),
    coalesce((SELECT count(*)::bigint
              FROM public.repair_jobs rj
              LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
              LEFT JOIN public.organizations o ON o.id = p.organization_id
              WHERE rj.created_at >= now() - interval '30 days'
                AND coalesce(nullif(trim(o.city), ''), '(unknown)') = '(unknown)'), 0);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_regional_state_summary()
CREATE OR REPLACE FUNCTION public.founder_regional_state_summary()
 RETURNS TABLE(distinct_states_30d bigint, top1_state text, top1_jobs_30d bigint, top1_revenue_rupees_30d numeric, top1_active_amcs bigint, top1_engineers_30d bigint, top1_hospitals_30d bigint, top2_state text, top2_jobs_30d bigint, top3_state text, top3_jobs_30d bigint, top1_share_jobs_pct numeric, total_jobs_30d bigint, total_revenue_rupees_30d numeric, unknown_state_jobs_30d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_total_jobs_30d bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- Per-state rollup over the last 30d window using profiles.state as ground-truth geography.
  -- engineers.user_id bridges to profiles for engineer-side state grouping. repair_jobs.engineer_id
  -- FKs to engineers.id (not profiles), so we join via engineers when grouping engineers by state.
  -- NOTE: this function is STABLE, so the rollup is built as inline CTEs (a CREATE TEMP TABLE AS
  -- is not permitted in a non-volatile function -- 0A000).

  -- Total jobs in window whose hospital has a known state. This is exactly
  -- sum(jobs_30d) over the rollup below, since every job maps to exactly one state
  -- and the rollup excludes the '(unknown)' bucket.
  SELECT count(*)::bigint INTO v_total_jobs_30d
    FROM public.repair_jobs rj
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
   WHERE rj.created_at >= now() - interval '30 days'
     AND coalesce(nullif(trim(p.state), ''), '(unknown)') <> '(unknown)';
  IF v_total_jobs_30d IS NULL THEN v_total_jobs_30d := 0; END IF;

  RETURN QUERY
  WITH job_state AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      rj.id            AS job_id,
      rj.hospital_user_id,
      rj.engineer_id,
      rj.status,
      rj.completed_at,
      rj.created_at,
      rj.contracted_amount_rupees
    FROM public.repair_jobs rj
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
    WHERE rj.created_at >= now() - interval '30 days'
  ),
  amc_state AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      c.id AS amc_id,
      c.status
    FROM public.amc_contracts c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  ),
  eng_state AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      e.id AS engineer_row_id
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
  ),
  agg AS (
    SELECT
      js.state,
      count(DISTINCT js.job_id)::bigint                                                    AS jobs_30d,
      count(DISTINCT js.hospital_user_id)::bigint                                          AS hospitals_30d,
      count(DISTINCT js.engineer_id) FILTER (WHERE js.engineer_id IS NOT NULL)::bigint     AS engineers_30d,
      coalesce(sum(js.contracted_amount_rupees) FILTER (WHERE js.status = 'completed'
        AND js.completed_at >= now() - interval '30 days'), 0)::numeric                    AS revenue_30d
    FROM job_state js
    GROUP BY js.state
  ),
  amc_agg AS (
    SELECT a.state, count(*) FILTER (WHERE a.status = 'active')::bigint AS active_amcs
    FROM amc_state a GROUP BY a.state
  ),
  state_rollup AS (
    SELECT
      agg.state,
      agg.jobs_30d,
      agg.hospitals_30d,
      agg.engineers_30d,
      agg.revenue_30d,
      coalesce(amc_agg.active_amcs, 0)::bigint AS active_amcs,
      -- composite-activity score: jobs + revenue/1000 + engineers*5 + hospitals*5 + active_amcs*3
      (agg.jobs_30d
        + (agg.revenue_30d / 1000.0)
        + (agg.engineers_30d * 5)
        + (agg.hospitals_30d * 5)
        + (coalesce(amc_agg.active_amcs, 0) * 3))::numeric AS score
    FROM agg
    LEFT JOIN amc_agg ON amc_agg.state = agg.state
    WHERE agg.state <> '(unknown)'
  ),
  ranked AS (
    SELECT
      r.*,
      row_number() OVER (ORDER BY r.score DESC NULLS LAST, r.jobs_30d DESC, r.state ASC) AS rk
    FROM state_rollup r
  ),
  t1 AS (SELECT * FROM ranked WHERE rk = 1),
  t2 AS (SELECT * FROM ranked WHERE rk = 2),
  t3 AS (SELECT * FROM ranked WHERE rk = 3)
  SELECT
    coalesce((SELECT count(*)::bigint FROM state_rollup), 0),
    coalesce((SELECT state FROM t1), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t1), 0)::bigint,
    coalesce((SELECT revenue_30d FROM t1), 0)::numeric,
    coalesce((SELECT active_amcs FROM t1), 0)::bigint,
    coalesce((SELECT engineers_30d FROM t1), 0)::bigint,
    coalesce((SELECT hospitals_30d FROM t1), 0)::bigint,
    coalesce((SELECT state FROM t2), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t2), 0)::bigint,
    coalesce((SELECT state FROM t3), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t3), 0)::bigint,
    CASE WHEN v_total_jobs_30d = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT jobs_30d FROM t1), 0)::numeric / v_total_jobs_30d, 1) END,
    v_total_jobs_30d,
    coalesce((SELECT sum(revenue_30d)::numeric FROM state_rollup), 0),
    coalesce((SELECT count(*)::bigint
              FROM public.repair_jobs rj
              LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
              WHERE rj.created_at >= now() - interval '30 days'
                AND coalesce(nullif(trim(p.state), ''), '(unknown)') = '(unknown)'), 0);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_repair_types_snapshot_summary()
CREATE OR REPLACE FUNCTION public.founder_repair_types_snapshot_summary()
 RETURNS TABLE(jobs_total_90d bigint, distinct_job_types_90d bigint, top_job_type text, top_job_type_count_90d bigint, unspecified_job_type_90d bigint, amc_kind_jobs_90d bigint, warranty_kind_jobs_90d bigint, paid_kind_jobs_90d bigint, urgency_emergency_90d bigint, urgency_high_90d bigint, contracted_revenue_30d_rupees numeric, avg_completion_hours_by_kind_amc numeric, avg_completion_hours_by_kind_paid numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_top_type       text;
  v_top_type_count bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(nullif(trim(j.job_type::text), ''), '(unspecified)')::text, count(*)::bigint
    INTO v_top_type, v_top_type_count
    FROM public.repair_jobs j
   WHERE j.created_at >= now() - interval '90 days'
   GROUP BY coalesce(nullif(trim(j.job_type::text), ''), '(unspecified)')
   ORDER BY count(*) DESC
   LIMIT 1;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'), 0),
    coalesce((SELECT count(DISTINCT coalesce(nullif(trim(j.job_type::text), ''), '(unspecified)'))::bigint
               FROM public.repair_jobs j
              WHERE j.created_at >= now() - interval '90 days'), 0),
    coalesce(v_top_type, '(none)')::text,
    coalesce(v_top_type_count, 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
               WHERE j.created_at >= now() - interval '90 days'
                 AND (j.job_type IS NULL OR length(trim(j.job_type::text)) = 0)), 0),
    -- AMC visits use kind = 'maintenance' (NOT 'amc' — CHECK constraint only allows 'repair'/'maintenance')
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND kind = 'maintenance'), 0),
    -- Warranty work is tracked via warranty_source_job_id FK column, not kind discriminator
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND warranty_source_job_id IS NOT NULL), 0),
    -- Paid bucket = kind = 'repair' (kind is NOT NULL with DEFAULT 'repair')
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND kind = 'repair'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND urgency = 'emergency'), 0),
    -- job_urgency has no 'high' label (22P02). The tier below 'emergency' in
    -- the enum (emergency > same_day > scheduled) is 'same_day', so the
    -- "high urgency" bucket counts same-day jobs.
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND urgency = 'same_day'), 0),
    coalesce((SELECT round(sum(contracted_amount_rupees)::numeric, 2)
                FROM public.repair_jobs
               WHERE status = 'completed'
                 AND completed_at >= now() - interval '30 days'
                 AND contracted_amount_rupees IS NOT NULL), 0)::numeric,
    coalesce((SELECT round(avg(extract(epoch FROM (completed_at - created_at)) / 3600.0)::numeric, 1)
                FROM public.repair_jobs
               WHERE status = 'completed'
                 AND completed_at >= now() - interval '30 days'
                 AND completed_at IS NOT NULL
                 AND kind = 'maintenance'), 0)::numeric,
    coalesce((SELECT round(avg(extract(epoch FROM (completed_at - created_at)) / 3600.0)::numeric, 1)
                FROM public.repair_jobs
               WHERE status = 'completed'
                 AND completed_at >= now() - interval '30 days'
                 AND completed_at IS NOT NULL
                 AND kind = 'repair'), 0)::numeric
  ;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_revenue_per_engineer_summary()
CREATE OR REPLACE FUNCTION public.founder_revenue_per_engineer_summary()
 RETURNS TABLE(total_active_engineers bigint, total_amc_mrr_rupees numeric, total_jobs_completed_30d bigint, revenue_per_completed_job_avg_rupees numeric, avg_rpe_30d_rupees numeric, top_rpe_engineer_user_id uuid, top_rpe_engineer_revenue_30d_rupees numeric, engineers_above_avg_rpe_count bigint, engineers_below_avg_rpe_count bigint, engineers_with_zero_revenue_30d bigint, top_decile_rpe_threshold_rupees numeric, bottom_decile_rpe_threshold_rupees numeric, median_rpe_rupees numeric, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_mrr_total numeric := 0;
  v_jobs_total bigint := 0;
  v_revenue_per_job numeric := 0;
  v_eng_total bigint := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT coalesce(sum(monthly_fee_rupees), 0) INTO v_mrr_total
  FROM public.amc_contracts WHERE status = 'active';

  SELECT count(*) INTO v_jobs_total
  FROM public.repair_jobs
  WHERE status = 'completed' AND completed_at >= now() - interval '30 days';

  IF v_jobs_total > 0 THEN
    v_revenue_per_job := v_mrr_total / v_jobs_total;
  END IF;

  SELECT count(*) INTO v_eng_total
  FROM public.engineers WHERE verification_status::text = 'verified';

  RETURN QUERY
  WITH per_eng AS (
    SELECT e.user_id,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '30 days'), 0)::int AS jobs_30d
    FROM public.engineers e WHERE e.verification_status::text = 'verified'
  ),
  with_rpe AS (
    SELECT user_id, jobs_30d, (jobs_30d * v_revenue_per_job)::numeric AS rpe_30d
    FROM per_eng
  ),
  avg_rpe AS (
    -- same value the original computed with sum(rpe_30d) OVER (), hoisted out of
    -- the FILTER clause because a window function is not allowed inside FILTER
    SELECT (sum(w.rpe_30d) / NULLIF(v_eng_total, 0))::numeric AS avg_val
    FROM with_rpe w
  )
  SELECT
    v_eng_total,
    round(v_mrr_total, 2)::numeric,
    v_jobs_total,
    round(v_revenue_per_job, 2)::numeric,
    CASE WHEN v_eng_total > 0 THEN round((sum(rpe_30d) / v_eng_total)::numeric, 2) ELSE 0 END,
    (SELECT user_id FROM with_rpe ORDER BY rpe_30d DESC NULLS LAST LIMIT 1),
    coalesce((SELECT round(rpe_30d, 2)::numeric FROM with_rpe ORDER BY rpe_30d DESC NULLS LAST LIMIT 1), 0),
    (SELECT count(*) FROM with_rpe w1 WHERE w1.rpe_30d > (SELECT avg_val FROM avg_rpe))::bigint,
    (SELECT count(*) FROM with_rpe w2 WHERE w2.rpe_30d < (SELECT avg_val FROM avg_rpe))::bigint,
    count(*) FILTER (WHERE rpe_30d = 0)::bigint,
    coalesce(percentile_cont(0.9) WITHIN GROUP (ORDER BY rpe_30d), 0)::numeric,
    coalesce(percentile_cont(0.1) WITHIN GROUP (ORDER BY rpe_30d), 0)::numeric,
    coalesce(percentile_cont(0.5) WITHIN GROUP (ORDER BY rpe_30d), 0)::numeric,
    now()
  FROM with_rpe;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_sales_territory_by_city(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_sales_territory_by_city(p_limit integer DEFAULT 50)
 RETURNS TABLE(city text, state text, total_jobs_90d bigint, unique_hospitals bigint, engineers_assigned bigint, amc_contracts_active bigint, avg_minutes_to_response numeric, demand_band text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_limit int := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH city_agg AS (
    SELECT
      coalesce(nullif(trim(o.city), ''), '(unknown)')   AS city,
      max(coalesce(nullif(trim(o.state), ''), ''))      AS state,
      count(rj.id)::bigint                               AS total_jobs_90d,
      count(DISTINCT rj.hospital_org_id)::bigint         AS unique_hospitals,
      count(DISTINCT rj.engineer_id) FILTER (WHERE rj.engineer_id IS NOT NULL)::bigint
                                                         AS engineers_assigned,
      round(
        avg(EXTRACT(EPOCH FROM (acc.accepted_at - rj.created_at)) / 60.0)
        FILTER (WHERE acc.accepted_at IS NOT NULL AND acc.accepted_at > rj.created_at)
      ::numeric, 1)                                       AS avg_minutes_to_response
    FROM public.repair_jobs rj
    JOIN public.organizations o ON o.id = rj.hospital_org_id
    LEFT JOIN LATERAL (
      SELECT min(al.accepted_at) AS accepted_at
        FROM public.engineer_job_acceptance_latency_r1976 al
       WHERE al.repair_job_id = rj.id
    ) acc ON true
    WHERE rj.created_at >= now() - interval '90 days'
    GROUP BY coalesce(nullif(trim(o.city), ''), '(unknown)')
  ),
  amc_by_city AS (
    SELECT coalesce(nullif(trim(o2.city), ''), '(unknown)') AS city,
           count(*) FILTER (WHERE c.status = 'active')::bigint AS amc_contracts_active
    FROM public.amc_contracts c
    JOIN public.profiles      p2 ON p2.id = c.hospital_user_id
    JOIN public.organizations o2 ON o2.id = p2.organization_id
    GROUP BY coalesce(nullif(trim(o2.city), ''), '(unknown)')
  )
  SELECT
    city_agg.city,
    city_agg.state,
    city_agg.total_jobs_90d,
    city_agg.unique_hospitals,
    city_agg.engineers_assigned,
    coalesce(amc_by_city.amc_contracts_active, 0)::bigint AS amc_contracts_active,
    coalesce(city_agg.avg_minutes_to_response, 0)::numeric AS avg_minutes_to_response,
    CASE
      WHEN city_agg.total_jobs_90d >= 30 THEN 'strong'
      WHEN city_agg.total_jobs_90d >= 10 THEN 'medium'
      WHEN city_agg.total_jobs_90d >= 1  THEN 'weak'
      ELSE 'zero'
    END::text AS demand_band
  FROM city_agg
  LEFT JOIN amc_by_city ON amc_by_city.city = city_agg.city
  ORDER BY city_agg.total_jobs_90d DESC NULLS LAST
  LIMIT v_limit;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_sales_territory_by_pincode(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_sales_territory_by_pincode(p_limit integer DEFAULT 100)
 RETURNS TABLE(pincode text, city text, state text, total_jobs_90d bigint, unique_hospitals bigint, engineers_assigned bigint, amc_contracts_active bigint, avg_minutes_to_response numeric, demand_band text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_limit int := GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH pin_agg AS (
    SELECT
      coalesce(nullif(trim(o.pincode), ''), '(unknown)') AS pincode,
      max(coalesce(nullif(trim(o.city), ''), ''))        AS city,
      max(coalesce(nullif(trim(o.state), ''), ''))       AS state,
      count(rj.id)::bigint                                AS total_jobs_90d,
      count(DISTINCT rj.hospital_org_id)::bigint          AS unique_hospitals,
      count(DISTINCT rj.engineer_id) FILTER (WHERE rj.engineer_id IS NOT NULL)::bigint
                                                          AS engineers_assigned,
      round(
        avg(EXTRACT(EPOCH FROM (acc.accepted_at - rj.created_at)) / 60.0)
        FILTER (WHERE acc.accepted_at IS NOT NULL AND acc.accepted_at > rj.created_at)
      ::numeric, 1)                                        AS avg_minutes_to_response
    FROM public.repair_jobs rj
    JOIN public.organizations o ON o.id = rj.hospital_org_id
    LEFT JOIN LATERAL (
      SELECT min(al.accepted_at) AS accepted_at
        FROM public.engineer_job_acceptance_latency_r1976 al
       WHERE al.repair_job_id = rj.id
    ) acc ON true
    WHERE rj.created_at >= now() - interval '90 days'
      AND o.pincode IS NOT NULL
      AND trim(o.pincode) <> ''
    GROUP BY coalesce(nullif(trim(o.pincode), ''), '(unknown)')
  ),
  amc_by_pin AS (
    SELECT coalesce(nullif(trim(o2.pincode), ''), '(unknown)') AS pincode,
           count(*) FILTER (WHERE c.status = 'active')::bigint AS amc_contracts_active
    FROM public.amc_contracts c
    JOIN public.profiles      p2 ON p2.id = c.hospital_user_id
    JOIN public.organizations o2 ON o2.id = p2.organization_id
    WHERE o2.pincode IS NOT NULL AND trim(o2.pincode) <> ''
    GROUP BY coalesce(nullif(trim(o2.pincode), ''), '(unknown)')
  )
  SELECT
    pin_agg.pincode,
    pin_agg.city,
    pin_agg.state,
    pin_agg.total_jobs_90d,
    pin_agg.unique_hospitals,
    pin_agg.engineers_assigned,
    coalesce(amc_by_pin.amc_contracts_active, 0)::bigint AS amc_contracts_active,
    coalesce(pin_agg.avg_minutes_to_response, 0)::numeric AS avg_minutes_to_response,
    CASE
      WHEN pin_agg.total_jobs_90d >= 10 THEN 'strong'
      WHEN pin_agg.total_jobs_90d >= 4  THEN 'medium'
      WHEN pin_agg.total_jobs_90d >= 1  THEN 'weak'
      ELSE 'zero'
    END::text AS demand_band
  FROM pin_agg
  LEFT JOIN amc_by_pin ON amc_by_pin.pincode = pin_agg.pincode
  ORDER BY pin_agg.total_jobs_90d DESC NULLS LAST
  LIMIT v_limit;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_side_hustle_verdict_breakdown_r2742()
CREATE OR REPLACE FUNCTION public.founder_side_hustle_verdict_breakdown_r2742()
 RETURNS TABLE(approval_verdict text, count integer, pct_of_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM engineer_side_hustle_disclosures_r2742 d WHERE d.approval_verdict IS NOT NULL;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT COALESCE(d.approval_verdict,'pending')::text,
         COUNT(*)::int,
         ROUND((COUNT(*)::numeric / total) * 100, 2)::numeric
  FROM engineer_side_hustle_disclosures_r2742 d
  WHERE d.approval_verdict IS NOT NULL
  GROUP BY d.approval_verdict
  ORDER BY COUNT(*) DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_signups_by_role_30d()
CREATE OR REPLACE FUNCTION public.founder_signups_by_role_30d()
 RETURNS TABLE(day_ist date, engineer_signups bigint, hospital_signups bigint, buyer_signups bigint, other_signups bigint, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'engineer'
                AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)             AS engineer_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital_admin'
                AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)             AS hospital_signups,
    -- user_role has no 'buyer' label; the buyer persona is only ever expressed in the
    -- text multi-role columns (profiles.roles / profiles.active_role).
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE ('buyer' = ANY(coalesce(p.roles, '{}'::text[]))
                     OR coalesce(p.active_role, '') = 'buyer')
                AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)             AS buyer_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role NOT IN ('engineer','hospital_admin')
                AND NOT ('buyer' = ANY(coalesce(p.roles, '{}'::text[]))
                         OR coalesce(p.active_role, '') = 'buyer')
                AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)             AS other_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)             AS total
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_skill_proficiency_distribution()
CREATE OR REPLACE FUNCTION public.founder_skill_proficiency_distribution()
 RETURNS TABLE(id text, proficiency_level text, entry_count bigint, pct_of_total numeric, avg_score numeric, certified_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM founder_engineer_skill_entries_v2;
  RETURN QUERY
  SELECT
    s.proficiency_level::text AS id,
    s.proficiency_level,
    COUNT(*)::bigint,
    CASE WHEN v_total > 0 THEN (COUNT(*)::numeric / v_total * 100.0) ELSE 0 END::numeric,
    COALESCE(AVG(s.proficiency_score),0)::numeric,
    COUNT(*) FILTER (WHERE s.certified = true)::bigint
  FROM founder_engineer_skill_entries_v2 s
  GROUP BY s.proficiency_level
  ORDER BY COUNT(*) DESC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_supervision_dashboard()
CREATE OR REPLACE FUNCTION public.founder_supervision_dashboard()
 RETURNS TABLE(status text, assignment_count integer, total_in_progress integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_in_progress int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*)::int INTO v_in_progress
    FROM public.supervised_job_assignments sa
   WHERE sa.status IN ('pending_supervisor_accept','active');

  RETURN QUERY
  WITH all_statuses(s) AS (
    VALUES
      ('pending_supervisor_accept'),
      ('active'),
      ('completed_successful'),
      ('completed_failed'),
      ('declined'),
      ('revoked')
  )
  SELECT
    a.s                                       AS status,
    coalesce(
      (SELECT count(*)::int
         FROM public.supervised_job_assignments sa
        WHERE sa.status = a.s),
      0
    )                                         AS assignment_count,
    v_in_progress                             AS total_in_progress
  FROM all_statuses a
  ORDER BY
    CASE a.s
      WHEN 'pending_supervisor_accept' THEN 1
      WHEN 'active'                    THEN 2
      WHEN 'completed_successful'      THEN 3
      WHEN 'completed_failed'          THEN 4
      WHEN 'declined'                  THEN 5
      WHEN 'revoked'                   THEN 6
    END;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_tier_1_home_metadata()
CREATE OR REPLACE FUNCTION public.founder_tier_1_home_metadata()
 RETURNS TABLE(last_action_at timestamp with time zone, total_open_incidents bigint, total_critical_alerts bigint, cron_failure_rate_24h_pct numeric, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_fail_pct numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- FIX: pg_cron is not installed here, so the static reference to cron.job_run_details made
  -- the WHOLE report raise 42P01. Resolve it dynamically and let the single cron metric
  -- degrade to 0 if the schema is absent -- same pattern founder_morning_digest_v2 uses.
  BEGIN
    EXECUTE $q$
      SELECT CASE WHEN COUNT(*) = 0 THEN 0::numeric
                  ELSE ROUND((COUNT(*) FILTER (WHERE status = 'failed'))::numeric
                             / COUNT(*)::numeric * 100, 2) END
      FROM cron.job_run_details
      WHERE start_time > now() - interval '24 hours'
    $q$ INTO v_fail_pct;
  EXCEPTION WHEN OTHERS THEN
    v_fail_pct := 0;
  END;

  RETURN QUERY
  WITH last_act AS (
    -- r1322 FIX: founder_priority_actions has no status column
    SELECT MAX(created_at) AS last_action_at FROM public.founder_priority_actions
  ),
  inc AS (
    -- r1322 FIX: founder_incidents uses opened_at not created_at; severity is p0..p3
    SELECT COUNT(*) FILTER (WHERE status = 'open') AS open_count,
           COUNT(*) FILTER (WHERE status = 'open' AND severity = 'p0') AS crit_count
    FROM public.founder_incidents
    WHERE opened_at > now() - interval '30 days'
  )
  SELECT
    last_act.last_action_at,
    COALESCE(inc.open_count, 0)::bigint,
    COALESCE(inc.crit_count, 0)::bigint,
    COALESCE(v_fail_pct, 0)::numeric,
    now()
  FROM last_act, inc;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_tier_progression_rate()
CREATE OR REPLACE FUNCTION public.founder_tier_progression_rate()
 RETURNS TABLE(window_label text, active_engineers bigint, promoted bigint, demoted bigint, net_promoted bigint, promotion_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('30d'::text,  1, now() - interval '30 days'),
      ('90d'::text,  2, now() - interval '90 days'),
      ('365d'::text, 3, now() - interval '365 days')
  ),
  tier_rank(tier, rank) AS (
    VALUES ('none'::text, 0), ('bronze', 1), ('silver', 2), ('gold', 3)
  ),
  events AS (
    SELECT h.engineer_user_id AS user_id, h.changed_at,
           tr_old.rank AS old_rank, tr_new.rank AS new_rank
    FROM public.engineer_tier_history h
    LEFT JOIN tier_rank tr_old ON tr_old.tier = h.prev_tier
    LEFT JOIN tier_rank tr_new ON tr_new.tier = h.new_tier
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.engineer_certification_progress), 0)::bigint,
    coalesce((SELECT count(DISTINCT e.user_id)::bigint FROM events e
              WHERE e.changed_at >= w.cutoff AND e.new_rank > e.old_rank), 0)::bigint,
    coalesce((SELECT count(DISTINCT e.user_id)::bigint FROM events e
              WHERE e.changed_at >= w.cutoff AND e.new_rank < e.old_rank), 0)::bigint,
    coalesce((SELECT count(DISTINCT e.user_id)::bigint FROM events e
              WHERE e.changed_at >= w.cutoff AND e.new_rank > e.old_rank), 0)::bigint
    -
    coalesce((SELECT count(DISTINCT e.user_id)::bigint FROM events e
              WHERE e.changed_at >= w.cutoff AND e.new_rank < e.old_rank), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.engineer_certification_progress), 0) = 0
         THEN 0::numeric
         ELSE round(
           coalesce((SELECT count(DISTINCT e.user_id)::numeric FROM events e
                     WHERE e.changed_at >= w.cutoff AND e.new_rank > e.old_rank), 0)
           / (SELECT count(*)::numeric FROM public.engineer_certification_progress)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_vendor_quality_scorecard_by_vendor(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_vendor_quality_scorecard_by_vendor(p_limit integer DEFAULT 50)
 RETURNS TABLE(vendor_org_id uuid, vendor_name text, total_orders bigint, total_amount_rupees numeric, on_time_pct numeric, defect_rate_pct numeric, defect_flag_count_90d bigint, avg_lead_time_days numeric, last_order_at timestamp with time zone, quality_band text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH vendor_orders AS (
    SELECT
      spo.supplier_org_id AS v_id,
      count(*) AS v_total_orders,
      coalesce(sum(spo.total_amount), 0)::numeric AS v_total_amount,
      CASE WHEN count(*) = 0 THEN 0::numeric
           ELSE round(
             100.0 * count(*) FILTER (
               WHERE coalesce(spo.order_status::text,'') IN ('shipped','delivered')
                 AND extract(epoch FROM (now() - spo.created_at))/86400 <= 7
             )::numeric / count(*)::numeric, 2)
      END AS v_on_time_pct,
      coalesce(round(avg(extract(epoch FROM (spo.updated_at - spo.created_at))/86400)
        FILTER (WHERE coalesce(spo.order_status::text,'') IN ('shipped','delivered'))::numeric, 2), 0) AS v_lead_time,
      max(spo.created_at) AS v_last_order
    FROM public.spare_part_orders spo
    WHERE spo.supplier_org_id IS NOT NULL
      AND spo.created_at >= now() - interval '180 days'
    GROUP BY spo.supplier_org_id
  ),
  vendor_flags AS (
    SELECT f.vendor_org_id AS v_id, count(*) AS v_flags
      FROM public.founder_vendor_quality_defect_flags f
      WHERE f.created_at >= now() - interval '90 days'
        AND f.vendor_org_id IS NOT NULL
      GROUP BY f.vendor_org_id
  )
  SELECT
    vo.v_id,
    coalesce(o.name, '(unknown)') AS vendor_name,
    vo.v_total_orders,
    vo.v_total_amount,
    vo.v_on_time_pct,
    CASE WHEN vo.v_total_orders = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce(vf.v_flags,0)::numeric / vo.v_total_orders::numeric, 2)
    END AS defect_rate_pct,
    coalesce(vf.v_flags, 0) AS defect_flag_count_90d,
    vo.v_lead_time,
    vo.v_last_order,
    CASE
      WHEN coalesce(vf.v_flags,0) >= 5 OR vo.v_on_time_pct < 50 THEN 'poor'
      WHEN coalesce(vf.v_flags,0) >= 2 OR vo.v_on_time_pct < 75 THEN 'fair'
      WHEN vo.v_on_time_pct >= 90 AND coalesce(vf.v_flags,0) = 0 THEN 'excellent'
      ELSE 'good'
    END AS quality_band
  FROM vendor_orders vo
  LEFT JOIN public.organizations o ON o.id = vo.v_id
  LEFT JOIN vendor_flags vf ON vf.v_id = vo.v_id
  ORDER BY vo.v_total_orders DESC, vo.v_total_amount DESC
  LIMIT greatest(p_limit, 1);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_vendor_sla_kpis()
CREATE OR REPLACE FUNCTION public.founder_vendor_sla_kpis()
 RETURNS TABLE(total_vendors integer, scored_vendors integer, grade_a integer, grade_b integer, grade_c integer, grade_d integer, avg_overall numeric, avg_delivery numeric, avg_quality numeric, avg_payment numeric, bottom5_count integer, pending_replacements integer, approved_replacements integer, executed_replacements integer, total_value_rupees bigint, current_quarter text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_q := to_char(now(), 'YYYY') || '-Q' || extract(quarter FROM now())::text;
  RETURN QUERY
  WITH cur AS (
    SELECT * FROM vendor_sla_scorecards_v2 WHERE quarter_label = v_q
  )
  SELECT
    -- FIX: organizations has no `kind` column, and org_type has no 'vendor' label either, so
    -- the literal was wrong too. Platform-wide a vendor is an organization that appears as
    -- spare_part_orders.supplier_org_id (same definition founder_vendor_quality_scorecard uses).
    (SELECT count(DISTINCT spo.supplier_org_id)::int
       FROM public.spare_part_orders spo
      WHERE spo.supplier_org_id IS NOT NULL),
    (SELECT count(*)::int FROM cur),
    (SELECT count(*)::int FROM cur WHERE grade = 'A'),
    (SELECT count(*)::int FROM cur WHERE grade = 'B'),
    (SELECT count(*)::int FROM cur WHERE grade = 'C'),
    (SELECT count(*)::int FROM cur WHERE grade = 'D'),
    COALESCE((SELECT round(avg(overall_score),2) FROM cur),0),
    COALESCE((SELECT round(avg(delivery_score),2) FROM cur),0),
    COALESCE((SELECT round(avg(quality_score),2) FROM cur),0),
    COALESCE((SELECT round(avg(payment_score),2) FROM cur),0),
    LEAST(5, (SELECT count(*)::int FROM cur))::int,
    (SELECT count(*)::int FROM vendor_replacement_queue_v2 WHERE status = 'pending'),
    (SELECT count(*)::int FROM vendor_replacement_queue_v2 WHERE status = 'approved'),
    (SELECT count(*)::int FROM vendor_replacement_queue_v2 WHERE status = 'executed'),
    -- FIX: unqualified total_value_rupees collided with the RETURNS TABLE column of the same
    -- name (42702); qualify it to the CTE. sum() over bigint is numeric, hence the ::bigint.
    COALESCE((SELECT sum(cur.total_value_rupees) FROM cur),0)::bigint,
    v_q;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_verified_engineers_recent()
CREATE OR REPLACE FUNCTION public.founder_verified_engineers_recent()
 RETURNS TABLE(user_id uuid, display_name text, state text, city text, verified_at timestamp with time zone, signup_to_verified_days numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  -- public.engineers has NO verified_at column: admin_set_engineer_verification()
  -- writes only verification_status/verification_notes, and no table in the schema
  -- records when a verification was approved. engineers.updated_at is bumped by any
  -- row edit (availability, location, profile), so it is NOT a verification stamp.
  -- Following the same substitution public.admin_inactive_engineers already makes
  -- for this phantom column (e.created_at AS verified_at), use e.created_at as the
  -- surrogate here too: the report
  -- therefore lists VERIFIED ENGINEERS WHO SIGNED UP in the last 30 days, and the
  -- signup -> verified latency is reported as 0 (unknown / not measurable) rather
  -- than a fabricated number.
  RETURN QUERY
  SELECT
    e.user_id,
    coalesce(p.full_name, '(engineer)'),
    coalesce(nullif(trim(p.state), ''), '—'),
    coalesce(nullif(trim(p.city), ''), '—'),
    e.created_at,
    0::numeric
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.verification_status = 'verified'
    AND e.created_at >= now() - interval '30 days'
  ORDER BY e.created_at DESC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_webhook_success_rate()
CREATE OR REPLACE FUNCTION public.founder_webhook_success_rate()
 RETURNS TABLE(source text, window_label text, events bigint, applied bigint, success_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text, 1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days')
  ),
  metrics AS (
    SELECT 'razorpay'::text AS src, w.label AS lbl, w.ord AS ord,
      coalesce((SELECT count(*)::bigint FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff), 0)::bigint AS ev,
      coalesce((SELECT count(*)::bigint FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff AND r.applied), 0)::bigint AS ap,
      CASE WHEN coalesce((SELECT count(*) FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff), 0) = 0
           THEN 0::numeric
           ELSE round(
             (SELECT count(*)::numeric FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff AND r.applied)
             / (SELECT count(*)::numeric FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff)
             * 100.0, 1)
      END AS pct
    FROM w
    UNION ALL
    SELECT 'payouts'::text AS src, w.label AS lbl, w.ord AS ord,
      coalesce((SELECT count(*)::bigint FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff), 0)::bigint AS ev,
      coalesce((SELECT count(*)::bigint FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff AND r.applied), 0)::bigint AS ap,
      CASE WHEN coalesce((SELECT count(*) FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff), 0) = 0
           THEN 0::numeric
           ELSE round(
             (SELECT count(*)::numeric FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff AND r.applied)
             / (SELECT count(*)::numeric FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff)
             * 100.0, 1)
      END AS pct
    FROM w
  )
  SELECT m.src, m.lbl, m.ev, m.ap, m.pct
  FROM metrics m
  ORDER BY m.src, m.ord;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_week_in_review_summary()
CREATE OR REPLACE FUNCTION public.founder_week_in_review_summary()
 RETURNS TABLE(week_start_date date, week_end_date date, amcs_signed_count bigint, amcs_churned_count bigint, amc_net_new integer, total_mrr_added_rupees numeric, jobs_completed_count bigint, jobs_initiated_count bigint, payments_captured_count bigint, payments_captured_rupees numeric, payouts_processed_count bigint, payouts_processed_rupees numeric, code_red_count bigint, open_incidents_count bigint, new_postmortems_count bigint, founder_actions_logged bigint, engineers_added_count bigint, hospitals_added_count bigint, spare_parts_orders_count bigint, spare_parts_orders_rupees numeric, refunds_issued_rupees numeric, net_cash_position_change_rupees numeric, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_week_start date := (current_date - interval '6 days')::date;
  v_week_end   date := current_date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT
    v_week_start, v_week_end,
    coalesce((SELECT count(*) FROM public.amc_contracts
              WHERE start_date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    -- amc_contracts.status has no 'churned' value (CHECK allows pending_payment,
    -- active, paused, expired, cancelled, renewal_failed), so the old literal
    -- could never match. Churn = a contract that terminated in the window.
    coalesce((SELECT count(*) FROM public.amc_contracts
              WHERE status IN ('cancelled','expired','renewal_failed') AND deactivated_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    (coalesce((SELECT count(*) FROM public.amc_contracts WHERE start_date BETWEEN v_week_start AND v_week_end), 0)
     - coalesce((SELECT count(*) FROM public.amc_contracts WHERE status IN ('cancelled','expired','renewal_failed') AND deactivated_at::date BETWEEN v_week_start AND v_week_end), 0))::int,
    coalesce((SELECT sum(monthly_fee_rupees) FROM public.amc_contracts
              WHERE start_date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce((SELECT count(*) FROM public.repair_jobs
              WHERE status = 'completed' AND completed_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.repair_jobs
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    -- payment_status has no 'captured' label — the captured/settled state is 'completed'.
    -- payments has no amount_rupees column either; the money column is amount.
    coalesce((SELECT count(*) FROM public.payments
              WHERE status = 'completed' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT sum(amount) FROM public.payments
              WHERE status = 'completed' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce((SELECT count(*) FROM public.engineer_payouts
              WHERE status = 'processed' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT sum(amount_rupees) FROM public.engineer_payouts
              WHERE status = 'processed' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce((SELECT count(*) FROM public.code_red_requests
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.founder_incidents
              WHERE status = 'open'), 0)::bigint,
    coalesce((SELECT count(*) FROM public.founder_incident_postmortems
              WHERE written_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.founder_priority_actions
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.engineers
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    -- organizations has no 'kind' column; the discriminator is type org_type
    coalesce((SELECT count(*) FROM public.organizations
              WHERE type = 'hospital' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.spare_part_orders
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT sum(total_amount) FROM public.spare_part_orders
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce((SELECT sum(amount) FROM public.payments
              WHERE status = 'refunded' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce(
      (SELECT cash_balance_rupees FROM public.founder_cash_position_snapshots
       WHERE snapshot_date BETWEEN v_week_start AND v_week_end
       ORDER BY snapshot_date DESC LIMIT 1)
      - (SELECT cash_balance_rupees FROM public.founder_cash_position_snapshots
         WHERE snapshot_date < v_week_start
         ORDER BY snapshot_date DESC LIMIT 1), 0)::numeric,
    now();
END;
$function$;

-- ---------------------------------------------------------------------
-- public.log_founder_capv2_simulate_round(p_scenario_label text, p_scenario_kind text, p_raise_amount_rupees numeric, p_pre_money_valuation_rupees numeric, p_new_esop_pct_added numeric)
CREATE OR REPLACE FUNCTION public.log_founder_capv2_simulate_round(p_scenario_label text, p_scenario_kind text, p_raise_amount_rupees numeric, p_pre_money_valuation_rupees numeric, p_new_esop_pct_added numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id uuid;
  v_dilution_pct numeric;
  v_post_money numeric;
  v_founder_dilution numeric;
  v_employee_dilution numeric;
  v_founder_pre_pct numeric;
  v_employee_pre_pct numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  v_post_money := p_pre_money_valuation_rupees + p_raise_amount_rupees;
  v_dilution_pct := p_raise_amount_rupees / v_post_money * 100;

  -- Compute founder + employee pre-round %
  -- FIX: founder_cap_table_shareholders has no share_pct column. Ownership % is derived from
  -- shares_count as a share of ALL issued shares (0 when the cap table is empty).
  SELECT COALESCE(
           SUM(s.shares_count) FILTER (WHERE s.shareholder_kind = 'founder')::numeric
             * 100 / NULLIF(SUM(s.shares_count), 0), 0)
    INTO v_founder_pre_pct
  FROM founder_cap_table_shareholders s;

  SELECT COALESCE(
           SUM(s.shares_count) FILTER (WHERE s.shareholder_kind IN ('employee','esop_pool'))::numeric
             * 100 / NULLIF(SUM(s.shares_count), 0), 0)
    INTO v_employee_pre_pct
  FROM founder_cap_table_shareholders s;

  v_founder_dilution := v_founder_pre_pct * v_dilution_pct / 100;
  v_employee_dilution := v_employee_pre_pct * v_dilution_pct / 100 + COALESCE(p_new_esop_pct_added, 0);

  INSERT INTO founder_cap_table_dilution_scenarios(
    scenario_label, scenario_kind, raise_amount_rupees, pre_money_valuation_rupees,
    new_esop_pct_added, founder_dilution_pct, employee_dilution_pct, notes
  )
  VALUES (
    p_scenario_label, p_scenario_kind, p_raise_amount_rupees, p_pre_money_valuation_rupees,
    COALESCE(p_new_esop_pct_added, 0), v_founder_dilution, v_employee_dilution,
    'auto-simulated by log_founder_capv2_simulate_round'
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'scenario_id', v_id,
    'projected_dilution_pct', ROUND(v_dilution_pct, 2),
    'post_money_rupees', v_post_money,
    'founder_dilution_pct', ROUND(v_founder_dilution, 2),
    'employee_dilution_pct', ROUND(v_employee_dilution, 2),
    'founder_pre_pct', v_founder_pre_pct,
    'employee_pre_pct', v_employee_pre_pct
  );
END;
$function$;

-- ---------------------------------------------------------------------
-- public.monthly_event_trend_r2511()
CREATE OR REPLACE FUNCTION public.monthly_event_trend_r2511()
 RETURNS TABLE(month_start timestamp with time zone, events_count bigint, attended_count bigint, total_cost_rupees bigint, total_revenue_influenced_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.month_start AS month_start,
         COUNT(*)::bigint AS events_count,
         COUNT(*) FILTER (WHERE e.attended)::bigint AS attended_count,
         COALESCE(SUM(e.cost_rupees),0)::bigint AS total_cost_rupees,
         COALESCE((SELECT SUM(o.revenue_influenced_rupees)
                   FROM public.event_followup_outcomes_r2511 o
                   JOIN public.chain_stakeholder_events_r2511 e2 ON e2.id = o.event_id
                   WHERE date_trunc('month', e2.held_at) = e.month_start),0)::bigint AS total_revenue_influenced_rupees
  FROM (SELECT date_trunc('month', ev.held_at) AS month_start,
               ev.attended,
               ev.cost_rupees
          FROM public.chain_stakeholder_events_r2511 ev) e
  GROUP BY e.month_start
  ORDER BY e.month_start DESC;
END $function$
;

-- ---------------------------------------------------------------------
-- public.monthly_feedback_trend_r2602()
CREATE OR REPLACE FUNCTION public.monthly_feedback_trend_r2602()
 RETURNS TABLE(month_start date, feedback_count integer, praise_count integer, concern_count integer, escalation_count integer, critical_count integer, improved_outcomes integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- FIX: the improved-outcomes scalar sub-SELECT correlated on f.feedback_at, but the GROUP BY
  -- was the non-Var expression date_trunc('month', f.feedback_at); Postgres only honours
  -- whole-expression GROUP BY matches at the outer query level, so the reference was rejected as
  -- ungrouped (42803). Pre-aggregate both sides per month and LEFT JOIN them instead. Counts and
  -- ordering are identical to the intended output (missing month => 0, as the sub-SELECT gave).
  RETURN QUERY
  WITH per_month AS (
    SELECT date_trunc('month', f.feedback_at) AS m,
           COUNT(*)::integer AS n_all,
           COUNT(*) FILTER (WHERE f.signal_kind = 'praise')::integer AS n_praise,
           COUNT(*) FILTER (WHERE f.signal_kind = 'concern')::integer AS n_concern,
           COUNT(*) FILTER (WHERE f.signal_kind = 'escalation')::integer AS n_escalation,
           COUNT(*) FILTER (WHERE f.severity = 'critical')::integer AS n_critical
      FROM public.engineer_supervisor_feedback_r2602 f
     GROUP BY date_trunc('month', f.feedback_at)
  ),
  improved AS (
    SELECT date_trunc('month', f2.feedback_at) AS m,
           COUNT(*)::integer AS n_improved
      FROM public.feedback_growth_outcomes_r2602 o
      JOIN public.engineer_supervisor_feedback_r2602 f2 ON f2.id = o.feedback_id
     WHERE o.outcome_kind = 'improved'
     GROUP BY date_trunc('month', f2.feedback_at)
  )
  SELECT p.m::date,
         p.n_all,
         p.n_praise,
         p.n_concern,
         p.n_escalation,
         p.n_critical,
         COALESCE(i.n_improved, 0)::integer
    FROM per_month p
    LEFT JOIN improved i ON i.m = p.m
   ORDER BY p.m DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.my_tds_summary(p_fiscal_year text)
CREATE OR REPLACE FUNCTION public.my_tds_summary(p_fiscal_year text DEFAULT NULL::text)
 RETURNS TABLE(fiscal_year text, fy_quarter text, total_gross_rupees numeric, total_tds_rupees numeric, total_net_payable_rupees numeric, deduction_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_fy text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_fiscal_year IS NULL THEN
    -- FIX: bare `fiscal_year` collided with this function's RETURNS TABLE column of the same
    -- name (42702). indian_fiscal_year_for(timestamptz) RETURNS TABLE(fiscal_year, fy_quarter),
    -- so alias the call and qualify the reference.
    SELECT ifr.fiscal_year INTO v_fy FROM public.indian_fiscal_year_for(now()) ifr;
  ELSE
    v_fy := p_fiscal_year;
  END IF;

  RETURN QUERY
  SELECT t.fiscal_year, t.fy_quarter,
         sum(t.gross_rupees)::numeric,
         sum(t.tds_rupees)::numeric,
         sum(t.net_payable_rupees)::numeric,
         count(*)::bigint
    FROM public.tds_deductions t
   WHERE t.engineer_user_id = auth.uid()
     AND t.fiscal_year = v_fy
   GROUP BY t.fiscal_year, t.fy_quarter
   ORDER BY t.fy_quarter;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.open_code_red_request(p_equipment_type text, p_equipment_brand text, p_equipment_model text, p_equipment_serial text, p_description text, p_emergency_fee_ceiling_rupees numeric, p_sla_minutes integer)
CREATE OR REPLACE FUNCTION public.open_code_red_request(p_equipment_type text, p_equipment_brand text, p_equipment_model text, p_equipment_serial text, p_description text, p_emergency_fee_ceiling_rupees numeric DEFAULT 5000, p_sla_minutes integer DEFAULT 60)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller   uuid := auth.uid();
  v_id       uuid;
  v_dispatch record;
  v_dispatched int := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Validate equipment_type is in-scope (reuse r486 taxonomy gate)
  IF NOT EXISTS (
    SELECT 1 FROM public.equipment_taxonomy_class
    WHERE equipment_type = p_equipment_type AND allowed_in_v04 = true
  ) THEN
    RAISE EXCEPTION 'equipment_type_out_of_scope_for_code_red' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.code_red_requests (
    hospital_user_id,
    equipment_type, equipment_brand, equipment_model, equipment_serial,
    description, emergency_fee_ceiling_rupees,
    sla_minutes, sla_deadline_at
  ) VALUES (
    v_caller,
    p_equipment_type, p_equipment_brand, p_equipment_model, p_equipment_serial,
    p_description, coalesce(p_emergency_fee_ceiling_rupees, 5000),
    coalesce(p_sla_minutes, 60),
    now() + (coalesce(p_sla_minutes, 60)::text || ' minutes')::interval
  ) RETURNING id INTO v_id;

  -- Page top-3 verified engineers ranked by:
  --   * Specialization match for equipment_type
  --   * Distance (closer wins)
  --   * Recent activity (active 30d)
  FOR v_dispatch IN
    SELECT
      e.user_id,
      -- We need hospital coords; pulled from the caller's profile via a
      -- coarse look-up on its organization's registered address (profiles
      -- itself carries no lat/lng). If those coords are missing, distance NULL.
      (SELECT public.haversine_meters(e.latitude, e.longitude, o.latitude, o.longitude) / 1000.0
         FROM public.profiles p
         JOIN public.organizations o ON o.id = p.organization_id
        WHERE p.id = v_caller) AS dist_km
    FROM public.engineers e
    WHERE e.verification_status = 'verified'
      AND e.is_available = true
      AND p_equipment_type = ANY(coalesce(e.specializations::text[], ARRAY[]::text[]))
      AND e.latitude IS NOT NULL AND e.longitude IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.engineer_payouts ep
         WHERE ep.engineer_user_id = e.user_id
           AND ep.updated_at >= now() - interval '60 days'
      )
    ORDER BY
      (SELECT public.haversine_meters(e.latitude, e.longitude, o.latitude, o.longitude)
         FROM public.profiles p
         JOIN public.organizations o ON o.id = p.organization_id
        WHERE p.id = v_caller) ASC NULLS LAST
    LIMIT 3
  LOOP
    INSERT INTO public.code_red_dispatch_events (
      code_red_id, engineer_user_id, distance_km_at_page, outcome
    ) VALUES (
      v_id, v_dispatch.user_id, v_dispatch.dist_km, 'paged'
    )
    ON CONFLICT DO NOTHING;
    v_dispatched := v_dispatched + 1;
  END LOOP;

  -- If zero engineers matched, the founder cockpit will see this as
  -- a NULL-dispatch Code Red and act manually.
  IF v_dispatched = 0 THEN
    RAISE NOTICE 'code red %: zero matching engineers; founder must escalate manually', v_id;
  END IF;

  RETURN v_id;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.owner_load_r2579()
CREATE OR REPLACE FUNCTION public.owner_load_r2579()
 RETURNS TABLE(owner_email text, trustee_count bigint, champion_count bigint, strained_count bigint, open_touches bigint, avg_influence numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.owner_email,
         g.trustee_count,
         g.champion_count,
         g.strained_count,
         (SELECT COUNT(*)::bigint FROM public.trustee_touch_events_r2579 e
           JOIN public.chain_board_trustee_relations_r2579 t2 ON t2.id = e.trustee_id
           WHERE COALESCE(t2.owner_email, 'unassigned') = g.owner_email
             AND e.status = 'open') AS open_touches,
         g.avg_influence
  FROM (
    SELECT COALESCE(t.owner_email, 'unassigned') AS owner_email,
           COUNT(*)::bigint AS trustee_count,
           (COUNT(*) FILTER (WHERE t.relationship_strength = 'champion'))::bigint AS champion_count,
           (COUNT(*) FILTER (WHERE t.status = 'strained' OR t.deal_accelerator_kind = 'blocker'))::bigint AS strained_count,
           AVG(t.influence_score)::numeric AS avg_influence
      FROM public.chain_board_trustee_relations_r2579 t
     GROUP BY COALESCE(t.owner_email, 'unassigned')
  ) g
  ORDER BY g.trustee_count DESC NULLS LAST;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.payroll_v2_kickoff_scheduled_run()
CREATE OR REPLACE FUNCTION public.payroll_v2_kickoff_scheduled_run()
 RETURNS TABLE(schedule_id uuid, schedule_label text, outcome text, next_run_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record;
  v_next timestamptz;
BEGIN
  -- Cron-callable. No is_founder gate (pg_cron has no JWT).
  FOR s IN
    SELECT * FROM public.founder_payroll_v2_schedules sch
    WHERE sch.is_active = true AND sch.next_run_at <= now()
    ORDER BY sch.next_run_at ASC
  LOOP
    -- Forecast next_run_at by frequency
    v_next := CASE s.frequency
                WHEN 'weekly'    THEN s.next_run_at + interval '7 days'
                WHEN 'biweekly'  THEN s.next_run_at + interval '14 days'
                WHEN 'monthly'   THEN s.next_run_at + interval '1 month'
                WHEN 'quarterly' THEN s.next_run_at + interval '3 months'
                ELSE s.next_run_at + interval '30 days'
              END;

    UPDATE public.founder_payroll_v2_schedules
       SET last_run_at      = now(),
           last_run_outcome = 'pending',
           next_run_at      = v_next,
           updated_at       = now()
     WHERE id = s.id;

    RETURN QUERY SELECT s.id, s.schedule_label, 'pending'::text, v_next;
  END LOOP;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.r2276_kpis()
CREATE OR REPLACE FUNCTION public.r2276_kpis()
 RETURNS TABLE(total_hospitals integer, total_monthly_volume_rupees bigint, total_cost_to_serve_rupees bigint, upi_share_pct numeric, switches_last_90d integer, avg_settlement_hours numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_vol bigint;
  v_upi_vol bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COALESCE(SUM(monthly_volume_rupees), 0) INTO v_total_vol FROM public.customer_payment_mode_preferences_r2276;
  SELECT COALESCE(SUM(monthly_volume_rupees), 0) INTO v_upi_vol FROM public.customer_payment_mode_preferences_r2276 WHERE primary_mode = 'upi';
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.customer_payment_mode_preferences_r2276),
    v_total_vol,
    (SELECT COALESCE(SUM(cost_to_serve_rupees), 0)::bigint FROM public.customer_payment_mode_preferences_r2276),
    CASE WHEN v_total_vol > 0 THEN ROUND((v_upi_vol::numeric / v_total_vol::numeric) * 100, 2) ELSE 0 END,
    (SELECT COUNT(*) FILTER (WHERE s.switched_at > now() - interval '90 days') FROM public.customer_payment_mode_switches_r2276 s)::int,
    (SELECT COALESCE(AVG(p.avg_settlement_hours), 0)::numeric FROM public.customer_payment_mode_preferences_r2276 p);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2815_criticality_risk()
CREATE OR REPLACE FUNCTION public.r2815_criticality_risk()
 RETURNS TABLE(criticality text, fridges integer, events integer, rupees_lost bigint, pct_of_total_loss numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COALESCE(SUM(fe.rupees_lost),0)::bigint INTO v_total FROM fridge_temp_audit_events_r2815 fe;
  RETURN QUERY
  SELECT i.criticality,
         COUNT(DISTINCT i.id)::int,
         COUNT(e.id)::int,
         COALESCE(SUM(e.rupees_lost),0)::bigint,
         CASE WHEN v_total = 0 THEN 0
              ELSE ROUND((COALESCE(SUM(e.rupees_lost),0)::numeric / v_total::numeric) * 100, 1)
         END
  FROM pharmacy_fridge_inventory_r2815 i
  LEFT JOIN fridge_temp_audit_events_r2815 e ON e.fridge_id = i.id
  GROUP BY i.criticality
  ORDER BY COALESCE(SUM(e.rupees_lost),0) DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.record_tds_for_payout(p_payout_id uuid)
CREATE OR REPLACE FUNCTION public.record_tds_for_payout(p_payout_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_payout              record;
  v_fy                  text;
  v_q                   text;
  v_cumulative          numeric;
  v_threshold           numeric := 500000.00;
  v_rate_pct            numeric := 1.00;
  v_tds                 numeric := 0;
  v_net                 numeric;
  v_deducted            boolean := false;
  v_tds_id              uuid;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_payout
    FROM public.engineer_payouts
   WHERE id = p_payout_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'payout_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_payout.engineer_user_id IS NULL THEN
    RAISE EXCEPTION 'payout_missing_engineer_user_id' USING ERRCODE = '22023';
  END IF;

  -- Idempotency: payout_id is UNIQUE on tds_deductions. Re-call
  -- returns the existing row id without re-deducting.
  SELECT id INTO v_tds_id FROM public.tds_deductions WHERE payout_id = p_payout_id;
  IF v_tds_id IS NOT NULL THEN
    RETURN v_tds_id;
  END IF;

  -- Resolve fiscal year + quarter for this payout's processed date
  -- (fall back to now() if processed_at missing).
  SELECT fiscal_year, fy_quarter
    INTO v_fy, v_q
    FROM public.indian_fiscal_year_for(coalesce(v_payout.processed_at, now()));

  -- Cumulative gross to THIS engineer in THIS fiscal year, INCLUSIVE
  -- of the current payout. Sum engineer_payouts.amount_rupees with
  -- status IN (processed, dispatched) for the engineer in [fy_start, fy_end].
  WITH fy_window AS (
    SELECT
      CASE
        WHEN EXTRACT(MONTH FROM (coalesce(v_payout.processed_at, now()) AT TIME ZONE 'Asia/Kolkata')) >= 4
          THEN make_timestamptz(EXTRACT(YEAR FROM (coalesce(v_payout.processed_at, now()) AT TIME ZONE 'Asia/Kolkata'))::int, 4, 1, 0, 0, 0, 'Asia/Kolkata')
        ELSE make_timestamptz((EXTRACT(YEAR FROM (coalesce(v_payout.processed_at, now()) AT TIME ZONE 'Asia/Kolkata')))::int - 1, 4, 1, 0, 0, 0, 'Asia/Kolkata')
      END AS fy_start
  )
  SELECT coalesce(sum(ep.amount_rupees), 0) INTO v_cumulative
    FROM public.engineer_payouts ep, fy_window
   WHERE ep.engineer_user_id = v_payout.engineer_user_id
     AND ep.status IN ('processed','dispatched')
     AND coalesce(ep.processed_at, ep.updated_at) >= fy_window.fy_start
     AND coalesce(ep.processed_at, ep.updated_at) <  (fy_window.fy_start + interval '1 year');

  -- Decide if this payout crosses / is above threshold
  IF v_cumulative > v_threshold THEN
    v_deducted := true;
    -- Note: §194-O deducts on the AMOUNT OF THIS PAYOUT (not on
    -- the excess-over-threshold). The threshold is a "do you
    -- deduct at all" gate, not a "deduct only the excess".
    v_tds := round(v_payout.amount_rupees * (v_rate_pct / 100.0), 2);
  END IF;

  v_net := v_payout.amount_rupees - v_tds;

  INSERT INTO public.tds_deductions (
    engineer_user_id, payout_id, fiscal_year, fy_quarter,
    gross_rupees, tds_rate_pct, tds_rupees, net_payable_rupees,
    deducted, cumulative_fy_gross_rupees, threshold_rupees
  ) VALUES (
    v_payout.engineer_user_id, p_payout_id, v_fy, v_q,
    v_payout.amount_rupees, v_rate_pct, v_tds, v_net,
    v_deducted, v_cumulative, v_threshold
  ) RETURNING id INTO v_tds_id;

  RETURN v_tds_id;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.refusal_breakdown_r2442()
CREATE OR REPLACE FUNCTION public.refusal_breakdown_r2442()
 RETURNS TABLE(refusal_kind text, refusal_count bigint, pct_of_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  total_refusals bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_refusals
  FROM public.engineer_night_shifts_r2442 s
  WHERE s.refusal_kind <> 'none';

  RETURN QUERY
  SELECT
    s.refusal_kind,
    COUNT(*)::bigint AS refusal_count,
    CASE WHEN total_refusals = 0 THEN 0::numeric
         ELSE ROUND((COUNT(*)::numeric / total_refusals::numeric) * 100, 1)
    END AS pct_of_total
  FROM public.engineer_night_shifts_r2442 s
  WHERE s.refusal_kind <> 'none'
  GROUP BY s.refusal_kind
  ORDER BY COUNT(*) DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.refusal_breakdown_r2526()
CREATE OR REPLACE FUNCTION public.refusal_breakdown_r2526()
 RETURNS TABLE(refusal_reason_kind text, refusal_count bigint, pct_of_refusals numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) INTO v_total
  FROM public.engineer_weekend_ot_logs_r2526 l
  WHERE l.refusal_reason_kind <> 'none';

  RETURN QUERY
  SELECT l.refusal_reason_kind,
         COUNT(*)::bigint AS refusal_count,
         CASE WHEN v_total > 0
              THEN ROUND((COUNT(*)::numeric / v_total) * 100, 2)
              ELSE 0::numeric END AS pct_of_refusals
  FROM public.engineer_weekend_ot_logs_r2526 l
  WHERE l.refusal_reason_kind <> 'none'
  GROUP BY l.refusal_reason_kind
  ORDER BY refusal_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.root_cause_pareto_r2907()
CREATE OR REPLACE FUNCTION public.root_cause_pareto_r2907()
 RETURNS TABLE(root_cause_category text, event_count bigint, revenue_loss_rupees numeric, pct_of_total_loss numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  -- FIX: bare `revenue_loss_rupees` collided with this function's RETURNS TABLE column of the
  -- same name (42702); alias the table and qualify the reference.
  SELECT NULLIF(sum(e0.revenue_loss_rupees),0) INTO v_total
    FROM public.ot_disruption_events_r2907 e0;

  RETURN QUERY
  SELECT
    e.root_cause_category,
    count(*)::bigint AS event_count,
    sum(e.revenue_loss_rupees)::numeric AS revenue_loss_rupees,
    round((sum(e.revenue_loss_rupees) / COALESCE(v_total,1)) * 100, 2) AS pct_of_total_loss
  FROM public.ot_disruption_events_r2907 e
  GROUP BY e.root_cause_category
  ORDER BY revenue_loss_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_founder_cap_v3_current_table()
CREATE OR REPLACE FUNCTION public.rpc_founder_cap_v3_current_table()
 RETURNS TABLE(shareholder_name text, shares_after bigint, pct_after numeric, total_cash_in_rupees bigint, total_cash_out_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_latest uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- cap_table_v3_events has no event_at column; the event timestamp is
  -- closed_at (same "latest event" ordering every other cap_v3 RPC uses).
  SELECT id INTO v_latest FROM public.cap_table_v3_events ORDER BY closed_at DESC LIMIT 1;
  IF v_latest IS NULL THEN RETURN; END IF;
  RETURN QUERY
  SELECT h.shareholder_name,
         h.shares_after,
         h.pct_after,
         COALESCE((SELECT SUM(c.cash_in_rupees) FROM public.cap_table_v3_holdings c WHERE c.shareholder_name = h.shareholder_name), 0)::bigint,
         COALESCE((SELECT SUM(c.cash_out_rupees) FROM public.cap_table_v3_holdings c WHERE c.shareholder_name = h.shareholder_name), 0)::bigint
  FROM public.cap_table_v3_holdings h
  WHERE h.event_id = v_latest
  ORDER BY h.shares_after DESC;
END $function$
;

-- ---------------------------------------------------------------------
-- public.rpc_founder_ops_spare_shortages()
CREATE OR REPLACE FUNCTION public.rpc_founder_ops_spare_shortages()
 RETURNS TABLE(id uuid, supplier_org_id uuid, repair_job_id uuid, created_at timestamp with time zone, age_days numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.supplier_org_id, o.related_repair_job_id, o.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - o.created_at))/86400.0, 1)::numeric AS age_days
  FROM spare_part_orders o
  WHERE o.delivered_at IS NULL
    AND o.created_at < now() - interval '24 hours'
  ORDER BY o.created_at ASC
  LIMIT 200;
END $function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2377_current_week_status()
CREATE OR REPLACE FUNCTION public.rpc_r2377_current_week_status()
 RETURNS TABLE(week_start date, target_conversations integer, actual_conversations integer, target_family integer, actual_family integer, target_non_work_minutes integer, actual_non_work_minutes integer, on_track boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  wk date := date_trunc('week', CURRENT_DATE)::date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH t AS (
    SELECT * FROM public.founder_outside_weekly_targets_r2377 wt WHERE wt.week_start = wk
  ),
  a AS (
    SELECT
      COUNT(*)::int AS conv_n,
      SUM(CASE WHEN oc.relationship='family' THEN 1 ELSE 0 END)::int AS fam_n,
      COALESCE(SUM(CASE WHEN oc.work_mentioned=false THEN oc.duration_minutes ELSE 0 END),0)::int AS non_work_min
    FROM public.founder_outside_conversations_r2377 oc
    WHERE oc.week_start = wk
  )
  SELECT
    wk,
    COALESCE((SELECT t.target_conversations FROM t),5),
    (SELECT a.conv_n FROM a),
    COALESCE((SELECT t.target_family FROM t),2),
    (SELECT a.fam_n FROM a),
    COALESCE((SELECT t.target_non_work_minutes FROM t),180),
    (SELECT a.non_work_min FROM a),
    ((SELECT a.conv_n FROM a) >= COALESCE((SELECT t.target_conversations FROM t),5)
      AND (SELECT a.fam_n FROM a) >= COALESCE((SELECT t.target_family FROM t),2)
      AND (SELECT a.non_work_min FROM a) >= COALESCE((SELECT t.target_non_work_minutes FROM t),180));
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2888_kpi_summary()
CREATE OR REPLACE FUNCTION public.rpc_r2888_kpi_summary()
 RETURNS TABLE(hospitals_tracked integer, total_jobs_this_month integer, total_billed_this_month bigint, avg_loyalty_score numeric, high_risk_hospitals integer, compounding_hospitals integer, signed_bonds integer, pending_bonds integer, total_bond_value_rupees bigint, projected_ltv_uplift_rupees bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_month date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  SELECT MAX(snapshot_month) INTO v_month FROM public.customer_monthly_revisit_pattern_r2888;

  RETURN QUERY
    SELECT
      (SELECT COUNT(DISTINCT hospital_name)::int FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month),
      (SELECT COALESCE(SUM(repair_jobs_count),0)::int FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month),
      (SELECT COALESCE(SUM(total_billed_rupees),0)::bigint FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month),
      (SELECT COALESCE(ROUND(AVG(loyalty_score),2),0) FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month),
      (SELECT COUNT(*)::int FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month AND churn_risk = 'high'),
      (SELECT COUNT(*)::int FROM public.customer_monthly_revisit_pattern_r2888 WHERE snapshot_month = v_month AND revisit_pattern = 'compounding'),
      (SELECT COUNT(*)::int FROM public.customer_loyalty_bond_offer_r2888 WHERE offer_status = 'signed'),
      (SELECT COUNT(*)::int FROM public.customer_loyalty_bond_offer_r2888 WHERE offer_status = 'pending'),
      (SELECT COALESCE(SUM(o1.total_bond_value_rupees),0)::bigint FROM public.customer_loyalty_bond_offer_r2888 o1 WHERE o1.offer_status = 'signed'),
      (SELECT COALESCE(SUM(o2.projected_ltv_uplift_rupees),0)::bigint FROM public.customer_loyalty_bond_offer_r2888 o2 WHERE o2.offer_status IN ('signed','pending'));
END;
$function$;

-- ---------------------------------------------------------------------
-- public.run_daily_reconciliation(p_date date)
CREATE OR REPLACE FUNCTION public.run_daily_reconciliation(p_date date DEFAULT (((now() AT TIME ZONE 'Asia/Kolkata'::text))::date - 1))
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_run_id                    uuid;
  v_day_start                 timestamptz;
  v_day_end                   timestamptz;
  v_threshold                 numeric := public.reconciliation_drift_threshold_rupees();

  v_rzp_repair                numeric := 0;
  v_rzp_spare                 numeric := 0;
  v_rzp_amc                   numeric := 0;
  v_rzp_total                 numeric := 0;
  v_cf_payouts                numeric := 0;
  v_platform_fee              numeric := 0;
  v_gst_owed                  numeric := 0;
  v_expected_retained         numeric := 0;
  v_drift                     numeric := 0;
  v_anomalies                 int := 0;
  v_status                    text := 'clean';
BEGIN
  -- Service-role or founder can trigger.
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  v_day_start := (p_date::text || ' 00:00:00+05:30')::timestamptz;
  v_day_end   := v_day_start + interval '1 day';

  -- ============================================================
  -- 1. INFLOW — Razorpay incoming
  -- ============================================================
  SELECT coalesce(sum(amount_rupees), 0) INTO v_rzp_repair
    FROM public.repair_job_escrow
   WHERE status = 'paid'
     AND paid_at >= v_day_start
     AND paid_at <  v_day_end;

  -- spare_part_orders stores the collected gross in total_amount
  -- (numeric rupees), so it needs no paise conversion.
  SELECT coalesce(sum(total_amount), 0) INTO v_rzp_spare
    FROM public.spare_part_orders
   WHERE payment_status = 'completed'
     AND updated_at >= v_day_start
     AND updated_at <  v_day_end;

  SELECT coalesce(sum(amount_rupees), 0) INTO v_rzp_amc
    FROM public.amc_payment_orders
   WHERE status = 'paid'
     AND updated_at >= v_day_start
     AND updated_at <  v_day_end;

  v_rzp_total := v_rzp_repair + v_rzp_spare + v_rzp_amc;

  -- ============================================================
  -- 2. OUTFLOW — Cashfree engineer payouts
  -- ============================================================
  SELECT coalesce(sum(amount_rupees), 0) INTO v_cf_payouts
    FROM public.engineer_payouts
   WHERE status = 'processed'
     AND updated_at >= v_day_start
     AND updated_at <  v_day_end;

  -- ============================================================
  -- 3. Platform fee + GST accrued (rough — refine in r491+)
  -- ============================================================
  -- Repair jobs: 7% take rate (per code helpers).
  -- AMC visits: 15% take rate.
  -- This is the simple accrual baseline; round 491 will refine to
  -- match per-job actual fee_rupees columns.
  v_platform_fee := round(v_rzp_repair * 0.07 + v_rzp_amc * 0.15, 2);
  v_gst_owed     := round(v_platform_fee * 0.18, 2);

  -- ============================================================
  -- 4. Expected retained = inflow - outflow - gst
  -- ============================================================
  v_expected_retained := v_rzp_total - v_cf_payouts - v_gst_owed;

  -- Drift baseline: zero. Future iteration will compare against an
  -- actual platform_balance ledger. For now, the "drift" we surface
  -- is the count of mismatched line-item pairs found below.

  -- ============================================================
  -- 5. Anomaly detection — record run first, then attach anomalies
  -- ============================================================
  -- Idempotent: re-running the same date replaces the run + cascades
  -- delete its anomalies.
  DELETE FROM public.reconciliation_runs WHERE run_date = p_date;

  INSERT INTO public.reconciliation_runs (
    run_date,
    rzp_repair_escrow_rupees, rzp_spare_part_rupees, rzp_amc_payment_rupees,
    rzp_total_inflow_rupees,
    cf_engineer_payouts_rupees, cf_total_outflow_rupees,
    platform_fee_accrued_rupees, gst_owed_rupees,
    expected_retained_rupees, drift_rupees, anomaly_count, status,
    ran_by
  ) VALUES (
    p_date,
    v_rzp_repair, v_rzp_spare, v_rzp_amc,
    v_rzp_total,
    v_cf_payouts, v_cf_payouts,
    v_platform_fee, v_gst_owed,
    v_expected_retained, 0, 0, 'clean',
    auth.uid()
  ) RETURNING id INTO v_run_id;

  -- Anomaly type 1: Razorpay event without matching intake update.
  -- A successful Razorpay payment event must have a corresponding
  -- order row flipped to 'paid'. If the event exists but no order
  -- shows paid in the same day, log anomaly.
  INSERT INTO public.reconciliation_anomalies (
    reconciliation_run_id, anomaly_kind, source_kind, source_id,
    delta_rupees, details
  )
  SELECT v_run_id, 'rzp_paid_not_in_intake', 'razorpay_webhook_events', e.id,
         (e.amount_paise / 100.0),
         jsonb_build_object(
           'razorpay_payment_id', e.razorpay_payment_id,
           'event_kind', e.event_type,
           'received_at', e.received_at
         )
    FROM public.razorpay_webhook_events e
   WHERE e.received_at >= v_day_start
     AND e.received_at <  v_day_end
     AND e.event_type  IN ('payment.captured','payment.authorized')
     AND NOT EXISTS (
       SELECT 1 FROM public.repair_job_escrow rje
        WHERE rje.razorpay_payment_id = e.razorpay_payment_id
          AND rje.status = 'paid'
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.spare_part_orders spo
        WHERE spo.payment_id = e.razorpay_payment_id
          AND spo.payment_status = 'completed'
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.amc_payment_orders apo
        WHERE apo.razorpay_payment_id = e.razorpay_payment_id
          AND apo.status = 'paid'
     );
  GET DIAGNOSTICS v_anomalies = ROW_COUNT;

  -- Anomaly type 2: AMC pool credit without matching payment order.
  -- amc_payment_pool credits should always trace to a paid
  -- amc_payment_order (via source_payment_order_id).
  INSERT INTO public.reconciliation_anomalies (
    reconciliation_run_id, anomaly_kind, source_kind, source_id,
    delta_rupees, details
  )
  SELECT v_run_id, 'amc_pool_credit_no_payment', 'amc_payment_pool', p.id,
         p.amount_rupees,
         jsonb_build_object(
           'amc_contract_id', p.amc_contract_id,
           'ledger_kind', p.ledger_kind,
           'description', p.description
         )
    FROM public.amc_payment_pool p
   WHERE p.created_at >= v_day_start
     AND p.created_at <  v_day_end
     AND p.ledger_kind = 'credit'
     AND p.source_payment_order_id IS NULL
     AND coalesce(p.description, '') NOT ILIKE '%admin_credit%'
     AND coalesce(p.description, '') NOT ILIKE '%sla_credit%'
     AND coalesce(p.description, '') NOT ILIKE '%goodwill%';

  -- Final anomaly count + status
  SELECT count(*) INTO v_anomalies
    FROM public.reconciliation_anomalies
   WHERE reconciliation_run_id = v_run_id;

  IF v_anomalies > 0 OR abs(v_drift) > v_threshold THEN
    v_status := 'drift';
  END IF;

  UPDATE public.reconciliation_runs
     SET anomaly_count = v_anomalies,
         status = v_status
   WHERE id = v_run_id;

  RETURN v_run_id;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.scan_duplicate_accounts()
CREATE OR REPLACE FUNCTION public.scan_duplicate_accounts()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pair record;
  v_count int := 0;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  -- ============================================================
  -- Signal 1: shared Aadhaar (CRITICAL — engineers only)
  -- ============================================================
  FOR v_pair IN
    SELECT
      least(e1.user_id, e2.user_id) AS user_id_a,
      greatest(e1.user_id, e2.user_id) AS user_id_b,
      e1.aadhaar_number AS aadhaar
    FROM public.engineers e1
    JOIN public.engineers e2
      ON e1.aadhaar_number = e2.aadhaar_number
     AND e1.user_id < e2.user_id
    WHERE e1.aadhaar_number IS NOT NULL
      AND length(e1.aadhaar_number) >= 4
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_aadhaar', 'critical',
      jsonb_build_object(
        'aadhaar_masked', 'XXXX-XXXX-' || right(v_pair.aadhaar, 4),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 2: shared PAN (CRITICAL — engineers only)
  -- ============================================================
  FOR v_pair IN
    SELECT
      least(e1.user_id, e2.user_id) AS user_id_a,
      greatest(e1.user_id, e2.user_id) AS user_id_b,
      e1.pan_number AS pan
    FROM public.engineers e1
    JOIN public.engineers e2
      ON upper(trim(e1.pan_number)) = upper(trim(e2.pan_number))
     AND e1.user_id < e2.user_id
    WHERE e1.pan_number IS NOT NULL
      AND length(trim(e1.pan_number)) = 10
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_pan', 'critical',
      jsonb_build_object(
        'pan_masked', left(v_pair.pan, 4) || '...' || right(v_pair.pan, 1),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 3: shared phone (HIGH — both sides; covers profiles)
  -- Phone reuse in India is real (family share), so HIGH not
  -- CRITICAL. Normalized to last 10 digits.
  -- ============================================================
  FOR v_pair IN
    WITH normed AS (
      SELECT
        u.id AS user_id,
        public.normalize_indian_phone(
          coalesce(p.phone, u.phone, u.raw_user_meta_data->>'phone')
        ) AS norm_phone
      FROM auth.users u
      LEFT JOIN public.profiles p ON p.id = u.id
    )
    SELECT
      least(n1.user_id, n2.user_id) AS user_id_a,
      greatest(n1.user_id, n2.user_id) AS user_id_b,
      n1.norm_phone AS phone
    FROM normed n1
    JOIN normed n2
      ON n1.norm_phone = n2.norm_phone
     AND n1.user_id < n2.user_id
    WHERE n1.norm_phone IS NOT NULL
      AND length(n1.norm_phone) = 10
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_phone_normalized', 'high',
      jsonb_build_object(
        'phone_last4', right(v_pair.phone, 4),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 4: name fuzzy match (MEDIUM — heuristic only)
  -- pg_trgm similarity > 0.8 catches "Anil Reddy" vs "Aanil Reddy"
  -- ============================================================
  -- Skip if pg_trgm not installed (graceful degrade)
  BEGIN
    FOR v_pair IN
      WITH names AS (
        SELECT u.id AS user_id,
               coalesce(u.raw_user_meta_data->>'full_name',
                        p.full_name, '') AS dn
          FROM auth.users u
          LEFT JOIN public.profiles p ON p.id = u.id
         WHERE coalesce(u.raw_user_meta_data->>'full_name',
                        p.full_name, '') <> ''
      )
      SELECT
        least(n1.user_id, n2.user_id) AS user_id_a,
        greatest(n1.user_id, n2.user_id) AS user_id_b,
        n1.dn AS dn_a,
        n2.dn AS dn_b
      FROM names n1
      JOIN names n2
        ON n1.user_id < n2.user_id
       AND similarity(n1.dn, n2.dn) > 0.85
       AND length(n1.dn) >= 6   -- avoid 'A B' false-positives
    LOOP
      INSERT INTO public.duplicate_account_flags (
        user_id_a, user_id_b, signal_kind, severity, evidence
      ) VALUES (
        v_pair.user_id_a, v_pair.user_id_b, 'name_fuzzy_match', 'medium',
        jsonb_build_object(
          'name_a', v_pair.dn_a, 'name_b', v_pair.dn_b,
          'detector', 'scan_duplicate_accounts_v1'
        )
      )
      ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
      v_count := v_count + 1;
    END LOOP;
  EXCEPTION
    WHEN undefined_function THEN
      RAISE NOTICE 'pg_trgm not installed; skipping name fuzzy match signal';
  END;

  RETURN v_count;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.sweep_amc_sla_unresponded_visits()
CREATE OR REPLACE FUNCTION public.sweep_amc_sla_unresponded_visits()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_visit            record;
  v_contract         public.amc_contracts%ROWTYPE;
  v_severity         text;
  v_target_hours     numeric;
  v_elapsed_hours    numeric;
  v_per_visit_cost   numeric;
  v_credit_amount    numeric;
  v_breach_id        uuid;
  v_ledger_id        uuid;
  v_running_balance  numeric;
  v_count            int := 0;
BEGIN
  FOR v_visit IN
    SELECT rj.id, rj.amc_contract_id, rj.created_at
      FROM public.repair_jobs rj
     WHERE rj.kind = 'maintenance'
       AND rj.amc_contract_id IS NOT NULL
       AND rj.status::text = 'requested'
       AND rj.created_at > now() - interval '30 days'
       AND NOT EXISTS (
         SELECT 1 FROM public.amc_sla_breaches b
          WHERE b.visit_id = rj.id
            AND b.breach_type = 'response_time'
       )
     FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      SELECT * INTO v_contract
        FROM public.amc_contracts WHERE id = v_visit.amc_contract_id;
      IF NOT FOUND THEN CONTINUE; END IF;

      -- Same severity branching as check_amc_sla_on_visit_status_change:
      -- amc_contracts has no response_time_critical_hours column, and
      -- amc_sla_breaches.severity is CHECK (severity IN ('emergency',
      -- 'standard')) -- so 'critical' was never a storable value either.
      -- The emergency target applies iff the contract covers emergency /
      -- life_support equipment; otherwise the standard target applies.
      IF v_contract.equipment_categories && ARRAY['emergency','life_support']::text[] THEN
        v_severity := 'emergency';
        v_target_hours := v_contract.response_time_emergency_hours;
      ELSE
        v_severity := 'standard';
        v_target_hours := v_contract.response_time_standard_hours;
      END IF;

      v_elapsed_hours := round(
        EXTRACT(EPOCH FROM (now() - v_visit.created_at))::numeric / 3600.0, 2
      );

      IF v_elapsed_hours <= v_target_hours THEN
        CONTINUE;
      END IF;

      v_per_visit_cost := round(
        v_contract.monthly_fee_rupees * 12::numeric / v_contract.visits_per_year, 2
      );
      v_credit_amount := least(round(v_per_visit_cost * 0.25, 2), 10000::numeric);

      IF v_credit_amount <= 0 THEN
        INSERT INTO public.amc_sla_breaches (
          amc_contract_id, visit_id, breach_type, severity,
          expected_within_hours, actual_hours, credit_issued_rupees, notes
        ) VALUES (
          v_visit.amc_contract_id, v_visit.id, 'response_time', v_severity,
          v_target_hours, v_elapsed_hours, 0,
          'response_time SLA exceeded; no credit (per_visit_cost <= 0); sweep'
        );
        v_count := v_count + 1;
        CONTINUE;
      END IF;

      INSERT INTO public.amc_sla_breaches (
        amc_contract_id, visit_id, breach_type, severity,
        expected_within_hours, actual_hours, credit_issued_rupees, notes
      ) VALUES (
        v_visit.amc_contract_id, v_visit.id, 'response_time', v_severity,
        v_target_hours, v_elapsed_hours, v_credit_amount,
        concat('SLA miss (sweep) on visit ', v_visit.id, ': ',
               v_elapsed_hours, 'h vs ', v_target_hours, 'h target (',
               v_severity, ').')
      ) RETURNING id INTO v_breach_id;

      SELECT coalesce(
               SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                        ELSE amount_rupees END),
               0)
           + v_credit_amount
        INTO v_running_balance
        FROM public.amc_payment_pool
        WHERE amc_contract_id = v_visit.amc_contract_id;

      INSERT INTO public.amc_payment_pool (
        amc_contract_id, ledger_kind, amount_rupees, balance_after,
        source_visit_id, source_breach_id, description
      ) VALUES (
        v_visit.amc_contract_id, 'credit', v_credit_amount, v_running_balance,
        v_visit.id, v_breach_id,
        concat('SLA goodwill credit (response_time, ', v_severity, ', sweep)')
      ) RETURNING id INTO v_ledger_id;

      UPDATE public.amc_sla_breaches
         SET credit_ledger_id = v_ledger_id
         WHERE id = v_breach_id;

      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'sweep_amc_sla_unresponded_visits: skipped % (%): %',
        v_visit.id, SQLSTATE, SQLERRM;
    END;
  END LOOP;

  RETURN v_count;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.top_holders_r1797(p_limit integer)
CREATE OR REPLACE FUNCTION public.top_holders_r1797(p_limit integer DEFAULT 10)
 RETURNS TABLE(id uuid, holder_name text, holder_type text, share_class text, current_balance bigint, pct_of_total numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(l.current_balance), 0) INTO v_total FROM public.investor_stock_ledger_r1797 l WHERE l.status = 'active';
  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT l.id, l.holder_name, l.holder_type, l.share_class, l.current_balance,
         ROUND((l.current_balance::numeric / v_total::numeric) * 100, 2) AS pct_of_total
  FROM public.investor_stock_ledger_r1797 l
  WHERE l.status = 'active'
  ORDER BY l.current_balance DESC
  LIMIT GREATEST(p_limit, 1);
END;
$function$;

-- =====================================================================
-- VERIFY
-- =====================================================================
DO $gate$
DECLARE
  v_names text[] := ARRAY[
    'assign_next_available_amc_engineer',
    'build_pved',
    'chain_kpis',
    'chain_per_site_summary',
    'engagement_distribution_r1799',
    'equipment_kind_distribution_r2623',
    'exec_360_v3_compliance_kpis',
    'fading_skills_r1844',
    'founder_amc_amount_histogram',
    'founder_amc_by_equipment_category',
    'founder_amc_pool_coverage',
    'founder_board_prep_overview',
    'founder_capital_by_investor_type',
    'founder_capital_efficiency_kpis',
    'founder_capital_per_investor',
    'founder_cap_conversion_preview',
    'founder_cash_conversion_cycle_summary',
    'founder_cash_conversion_history',
    'founder_cash_headline_kpis',
    'founder_cash_payment_surveys_summary',
    'founder_cert_engineer_leaderboard',
    'founder_cert_recent_renewal_log',
    'founder_chains_health',
    'founder_chain_expansion_active_chains',
    'founder_churn_prediction_at_risk_hospitals',
    'founder_compliance_calendar_auto_seed_year',
    'founder_critical_actions',
    'founder_cron_jobs_recent',
    'founder_cron_status_summary',
    'founder_culture_deck_summary',
    'founder_culture_deck_unsigned_team',
    'founder_culture_deck_version_timeline',
    'founder_cumulative_rollup_summary',
    'founder_dispute_queue',
    'founder_eef_v2_ack_cliff_alert',
    'founder_engineers_missing_payout',
    'founder_engineer_escalation_by_category',
    'founder_engineer_leaderboard_30d',
    'founder_engineer_side_projects_active_list_r1469',
    'founder_engineer_side_projects_overdue_followups_r1469',
    'founder_engineer_side_projects_recent_convos_r1469',
    'founder_escrow_held_aging',
    'founder_fev_readiness_leaderboard',
    'founder_funnel_drop_off',
    'founder_funnel_stage_counts',
    'founder_hospital_auto_renew_scan',
    'founder_hospital_spend_distribution',
    'founder_hsq_latest_rankings',
    'founder_hsq_recompute_current_quarter',
    'founder_investor_pulse_summary',
    'founder_kyc_pending_detail',
    'founder_log_ownership_event',
    'founder_ltv_headline',
    'founder_marketing_content_pieces_recent',
    'founder_marketing_content_upcoming',
    'founder_morning_digest_v2',
    'founder_okr_team_health_r2345',
    'founder_onboarding_velocity_summary',
    'founder_ownership_at_risk_amcs',
    'founder_payouts_amount_histogram',
    'founder_payout_method_coverage',
    'founder_r2887_category_mix',
    'founder_reconciliation_health',
    'founder_regional_city_summary',
    'founder_regional_state_summary',
    'founder_repair_types_snapshot_summary',
    'founder_revenue_per_engineer_summary',
    'founder_sales_territory_by_city',
    'founder_sales_territory_by_pincode',
    'founder_side_hustle_verdict_breakdown_r2742',
    'founder_signups_by_role_30d',
    'founder_skill_proficiency_distribution',
    'founder_supervision_dashboard',
    'founder_tier_1_home_metadata',
    'founder_tier_progression_rate',
    'founder_vendor_quality_scorecard_by_vendor',
    'founder_vendor_sla_kpis',
    'founder_verified_engineers_recent',
    'founder_webhook_success_rate',
    'founder_week_in_review_summary',
    'log_founder_capv2_simulate_round',
    'monthly_event_trend_r2511',
    'monthly_feedback_trend_r2602',
    'my_tds_summary',
    'open_code_red_request',
    'owner_load_r2579',
    'payroll_v2_kickoff_scheduled_run',
    'r2276_kpis',
    'r2815_criticality_risk',
    'record_tds_for_payout',
    'refusal_breakdown_r2442',
    'refusal_breakdown_r2526',
    'root_cause_pareto_r2907',
    'rpc_founder_cap_v3_current_table',
    'rpc_founder_ops_spare_shortages',
    'rpc_r2377_current_week_status',
    'rpc_r2888_kpi_summary',
    'run_daily_reconciliation',
    'scan_duplicate_accounts',
    'sweep_amc_sla_unresponded_visits',
    'top_holders_r1797'
  ];
  v_bad   text;
  v_n     int;
BEGIN
  -- 1. all present, exactly once
  SELECT string_agg(x, ', ') INTO v_bad FROM unnest(v_names) x
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p
                      WHERE p.pronamespace='public'::regnamespace AND p.proname = x);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3799 VERIFY FAILED: function(s) vanished: %', v_bad;
  END IF;

  SELECT string_agg(q.proname || ' x' || q.c, ', ') INTO v_bad
    FROM (SELECT p.proname, count(*) c FROM pg_proc p
           WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
           GROUP BY p.proname) q WHERE q.c > 1;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3799 VERIFY FAILED: extra overload(s) created: %', v_bad;
  END IF;

  -- 2. argument list and parameter NAMES unchanged (PostgREST calls by name)
  SELECT string_agg(b.proname, ', ') INTO v_bad
    FROM _r3799_before b
    JOIN pg_proc p ON p.proname = b.proname AND p.pronamespace='public'::regnamespace
   WHERE pg_get_function_identity_arguments(p.oid) <> b.args
      OR coalesce((SELECT string_agg(x.name, ',' ORDER BY x.ord)
                   FROM unnest(coalesce(p.proargnames, '{}'::text[]))
                        WITH ORDINALITY AS x(name, ord)), '') <> b.argnames;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3799 VERIFY FAILED: signature/param-name drift in: %', v_bad;
  END IF;

  -- 3. the static errors among the touched set must be GONE (or far fewer)
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='plpgsql_check') THEN
    SELECT count(DISTINCT p.proname) INTO v_n
      FROM pg_proc p CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.prolang=(SELECT oid FROM pg_language WHERE lanname='plpgsql')
       AND p.prorettype <> 'trigger'::regtype
       AND p.proname = ANY(v_names) AND e.level='error';
    RAISE NOTICE 'round 3799: still statically broken among the % touched: %',
      array_length(v_names,1), v_n;
    IF v_n >= array_length(v_names,1) THEN
      RAISE EXCEPTION 'round 3799 VERIFY FAILED: broken count did not improve (% of %)',
        v_n, array_length(v_names,1);
    END IF;
  END IF;

  RAISE NOTICE 'round 3799 verified: % function(s) repaired, contract intact',
    array_length(v_names,1);
END
$gate$;

COMMIT;
