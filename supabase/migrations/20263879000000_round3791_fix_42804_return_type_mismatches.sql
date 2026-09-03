-- =====================================================================
-- Round 3791 -- the 42804 class: RETURN QUERY vs RETURNS TABLE mismatches
-- =====================================================================
--
-- 42804 "structure of query does not match function result type" was the
-- largest class remaining after the round3788-3790 bulk waves: 87
-- founder-console analytics functions whose RETURN QUERY select-list
-- produced column types that did not match their declared RETURNS TABLE.
-- Each raised on EVERY call, so every page built on them was dead.
--
-- WHY THIS CLASS COULD NOT BE BULK-TRANSFORMED LIKE WAVES 1-3
-- ---------------------------------------------------------------------
-- Those waves worked because one regex was provably correct for a whole
-- class. Here the correct fix DEPENDS ON WHAT THE COLUMN MEANS:
--   * varchar/varchar(n)/name -> text, enum -> text, float8 -> numeric,
--     int -> bigint: cast the query column. Lossless.
--   * uuid -> declared bigint: uncastable and an obviously wrong
--     DECLARATION, so the declared type must change instead.
--   * numeric -> declared bigint/integer: THE JUDGEMENT CALL (~45 of the
--     87). A COUNT should cast to bigint; but MONEY, a RATE, a
--     PERCENTAGE or an AVERAGE must have its DECLARATION widened to
--     numeric, because casting would SILENTLY DROP PAISE or precision on
--     a founder financial report.
-- Getting that backwards corrupts reported revenue with no error at all,
-- so every function was assessed individually against its own column
-- names and expressions, and each records its judgement in an inline
-- `-- round3791:` comment.
--
-- plpgsql_check reports only the FIRST mismatched column, so every
-- function was additionally re-checked column-by-column against its full
-- declared TABLE list. Several carried further mismatches the analyzer
-- had never reached (the very first one inspected,
-- founder_referrals_cumulative, had an unreported second one in col 5).
--
-- TWO EXECUTION PATHS, because PostgreSQL will not let you change a
-- function's return type with CREATE OR REPLACE (42P13):
--   * 55 function(s) keep their declared RETURNS TABLE and are applied
--     with a plain CREATE OR REPLACE.
--   * 32 function(s) legitimately change a declared column TYPE (the
--     uuid cases and the money-precision widenings) and therefore need
--     DROP + CREATE.
--
-- DROP + CREATE IS THE DANGEROUS PATH AND IS HANDLED EXPLICITLY.
-- Dropping a function DISCARDS ITS ACL. Recreating it does NOT come back
-- clean, and on THIS database it comes back WORSE THAN DEFAULT:
--
--   ALTER DEFAULT PRIVILEGES IN SCHEMA public
--     GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
--
-- is configured project-wide (verified in pg_default_acl). So every
-- function newly created in `public` is automatically EXECUTE-able by
-- **anon** -- i.e. by UNAUTHENTICATED callers -- on top of PostgreSQL's
-- own default grant to PUBLIC.
--
-- That means a naive DROP + CREATE of any function in this database
-- silently publishes it to anon. For these 32 -- founder financial and
-- investor-pipeline reports -- that would have been a serious exposure.
-- It is also a standing hazard for ANY future migration here that
-- recreates a function, and the first attempt at this migration hit it:
-- a `REVOKE ... FROM PUBLIC` is NOT sufficient, because the anon grant
-- is a separate explicit ACL entry, not PUBLIC's. The gate below caught
-- it and rolled the whole thing back.
--
-- So each recreate is followed by
--   REVOKE ALL ... FROM PUBLIC, anon, authenticated, service_role;
-- and only then are the CAPTURED grants replayed. Net effect: the ACL
-- ends up byte-identical to what it was before, which the gate asserts
-- in both directions. A useful side effect is that a function which was
-- deliberately service_role-only does NOT silently gain `authenticated`
-- access from the default privileges.
--
-- FULL GATE (all inside the transaction, so any failure rolls back):
--   1. every targeted function still exists,
--   2. its ARGUMENT LIST is byte-identical (PostgREST calls by named
--      parameter, so a renamed argument silently breaks clients),
--   3. its OUT COLUMN NAMES and ORDER are byte-identical (the console
--      reads results by name; only declared TYPES were allowed to move),
--   4. its EXECUTE grants are exactly what they were beforehand,
--   5. no targeted function is EXECUTE-able by PUBLIC or anon unless it
--      already was,
--   6. if plpgsql_check is installed, the broken count went DOWN.

BEGIN;

-- Snapshot the full contract + ACL before touching anything.
CREATE TEMP TABLE _r3791_before ON COMMIT DROP AS
SELECT p.oid,
       p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       (SELECT string_agg(nm, ',' ORDER BY ord)
          FROM unnest(p.proargnames, p.proargmodes) WITH ORDINALITY AS u(nm, md, ord)
         WHERE md = 't') AS outnames
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace
  AND p.proname = ANY(ARRAY[
    'dr_detector_pixel_defect_severity_map_r3132',
    'founder_409a_summary_kpis',
    'founder_amc_base_growth',
    'founder_amc_revenue_cumulative',
    'founder_audit_by_actor',
    'founder_chain_leader_kpi_r2751',
    'founder_churn_save_roi_kpis',
    'founder_clv_calculator_summary',
    'founder_code_red_cumulative',
    'founder_code_red_recent',
    'founder_demand_signals_cumulative',
    'founder_disputes_cumulative',
    'founder_dispute_kpis',
    'founder_engineer_ltv_ranked',
    'founder_engineer_specialization_coverage',
    'founder_fleet_red_flags',
    'founder_gmv_by_equipment_type',
    'founder_gmv_cumulative',
    'founder_grants_audit',
    'founder_hospital_department_breakout_summary',
    'founder_investor_channel_mix',
    'founder_investor_sla_summary',
    'founder_ipu_benchmark',
    'founder_ipu_kpis',
    'founder_kyc_renewal_queue',
    'founder_list_hospital_chains',
    'founder_loi_active_list',
    'founder_ma_pipeline_summary',
    'founder_open_collusion_flags',
    'founder_open_duplicate_flags',
    'founder_pending_kyc_list',
    'founder_pending_refund_authorizations',
    'founder_pm_overdue_summary',
    'founder_pricing_by_tier_r2833',
    'founder_referrals_cumulative',
    'founder_repair_jobs_status',
    'founder_risk_score_snapshots_summary',
    'founder_risk_top_n',
    'founder_signups_cumulative',
    'founder_site_visit_recent_completed',
    'founder_site_visit_upcoming',
    'founder_spot_audits_cumulative',
    'founder_supervised_cumulative',
    'founder_suspicious_attendance_recent',
    'founder_tds_quarterly_summary',
    'founder_tier_changes_cumulative',
    'founder_unmatched_jobs_7d',
    'founder_verified_engineer_growth',
    'founder_voice_inbox_r2362',
    'founder_voice_top_voters_r2362',
    'founder_wellbeing_engineer_trend',
    'founder_wellbeing_recent_responses',
    'founder_wellbeing_red_flags',
    'r1693_vesting_summary',
    'sla_breach_summary_r2352',
    'brand_equity_pulse_kpis_r2781',
    'founder_biomed_by_hospital_r2235',
    'founder_biomed_departure_reasons_r2235',
    'founder_hospital_xsell_by_product',
    'founder_hospital_xsell_overview',
    'founder_hospital_xsell_top_hospitals',
    'founder_hpbi_pipeline_by_status',
    'founder_lost_deal_kpis_v2',
    'founder_peer_stage_distribution',
    'founder_podcast_pipeline_summary',
    'founder_pricing_by_quarter_r2833',
    'founder_pricing_kpi_summary_r2833',
    'founder_r2819_kpis',
    'founder_r2971_spend_forecast',
    'founder_r2971_vendor_concentration',
    'founder_site_visit_outcomes_by_kind',
    'fsbca_r2369_by_category',
    'fsbca_r2369_summary',
    'owner_load_r2662',
    'r2691_kpi_summary',
    'recent_actions_night_shift_r2222',
    'recent_actions_nps_r2216',
    'recent_actions_r2202',
    'recent_actions_r2209',
    'recent_actions_reference_r2220',
    'rpc_founder_ops_payout_backlog',
    'rpc_r2699_by_chain',
    'rpc_r2699_by_topic',
    'rpc_r2699_kpis',
    'topic_kind_breakdown_r2522',
    'top_callback_engineers_r2522',
    'top_pairing_focus_r2662'
  ]);

CREATE TEMP TABLE _r3791_acl ON COMMIT DROP AS
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       a.grantee::regrole::text AS grantee,
       a.privilege_type          AS priv
FROM pg_proc p
CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
WHERE p.pronamespace = 'public'::regnamespace
  AND p.proname = ANY(ARRAY[
    'dr_detector_pixel_defect_severity_map_r3132',
    'founder_409a_summary_kpis',
    'founder_amc_base_growth',
    'founder_amc_revenue_cumulative',
    'founder_audit_by_actor',
    'founder_chain_leader_kpi_r2751',
    'founder_churn_save_roi_kpis',
    'founder_clv_calculator_summary',
    'founder_code_red_cumulative',
    'founder_code_red_recent',
    'founder_demand_signals_cumulative',
    'founder_disputes_cumulative',
    'founder_dispute_kpis',
    'founder_engineer_ltv_ranked',
    'founder_engineer_specialization_coverage',
    'founder_fleet_red_flags',
    'founder_gmv_by_equipment_type',
    'founder_gmv_cumulative',
    'founder_grants_audit',
    'founder_hospital_department_breakout_summary',
    'founder_investor_channel_mix',
    'founder_investor_sla_summary',
    'founder_ipu_benchmark',
    'founder_ipu_kpis',
    'founder_kyc_renewal_queue',
    'founder_list_hospital_chains',
    'founder_loi_active_list',
    'founder_ma_pipeline_summary',
    'founder_open_collusion_flags',
    'founder_open_duplicate_flags',
    'founder_pending_kyc_list',
    'founder_pending_refund_authorizations',
    'founder_pm_overdue_summary',
    'founder_pricing_by_tier_r2833',
    'founder_referrals_cumulative',
    'founder_repair_jobs_status',
    'founder_risk_score_snapshots_summary',
    'founder_risk_top_n',
    'founder_signups_cumulative',
    'founder_site_visit_recent_completed',
    'founder_site_visit_upcoming',
    'founder_spot_audits_cumulative',
    'founder_supervised_cumulative',
    'founder_suspicious_attendance_recent',
    'founder_tds_quarterly_summary',
    'founder_tier_changes_cumulative',
    'founder_unmatched_jobs_7d',
    'founder_verified_engineer_growth',
    'founder_voice_inbox_r2362',
    'founder_voice_top_voters_r2362',
    'founder_wellbeing_engineer_trend',
    'founder_wellbeing_recent_responses',
    'founder_wellbeing_red_flags',
    'r1693_vesting_summary',
    'sla_breach_summary_r2352',
    'brand_equity_pulse_kpis_r2781',
    'founder_biomed_by_hospital_r2235',
    'founder_biomed_departure_reasons_r2235',
    'founder_hospital_xsell_by_product',
    'founder_hospital_xsell_overview',
    'founder_hospital_xsell_top_hospitals',
    'founder_hpbi_pipeline_by_status',
    'founder_lost_deal_kpis_v2',
    'founder_peer_stage_distribution',
    'founder_podcast_pipeline_summary',
    'founder_pricing_by_quarter_r2833',
    'founder_pricing_kpi_summary_r2833',
    'founder_r2819_kpis',
    'founder_r2971_spend_forecast',
    'founder_r2971_vendor_concentration',
    'founder_site_visit_outcomes_by_kind',
    'fsbca_r2369_by_category',
    'fsbca_r2369_summary',
    'owner_load_r2662',
    'r2691_kpi_summary',
    'recent_actions_night_shift_r2222',
    'recent_actions_nps_r2216',
    'recent_actions_r2202',
    'recent_actions_r2209',
    'recent_actions_reference_r2220',
    'rpc_founder_ops_payout_backlog',
    'rpc_r2699_by_chain',
    'rpc_r2699_by_topic',
    'rpc_r2699_kpis',
    'topic_kind_breakdown_r2522',
    'top_callback_engineers_r2522',
    'top_pairing_focus_r2662'
  ]);

-- =====================================================================
-- PATH 1 -- signature-preserving (plain CREATE OR REPLACE)
-- =====================================================================

-- dr_detector_pixel_defect_severity_map_r3132
CREATE OR REPLACE FUNCTION public.dr_detector_pixel_defect_severity_map_r3132()
 RETURNS TABLE(panel_serial text, panel_make text, modality text, total_dead_pixels integer, cluster_defects integer, line_defects integer, ghost_image_severity text, defect_score numeric, risk_band text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.panel_serial::text,
           a.panel_make::text,
           a.modality::text,
           a.total_dead_pixels,
           a.cluster_defects,
           a.line_defects,
           a.ghost_image_severity::text, -- round3791: moved up from last position to column 7 -- the select list emitted defect_score/risk_band/ghost_image_severity but RETURNS TABLE declares ghost_image_severity/defect_score/risk_band, so column 7 returned numeric where text is declared (42804 on every call)
           (a.total_dead_pixels + a.cluster_defects * 10 + a.line_defects * 50)::numeric as defect_score, -- round3791: now column 8 = declared defect_score numeric; kept ::numeric (weighted score, not a count -- must not be narrowed)
           case
             when a.total_dead_pixels + a.cluster_defects * 10 + a.line_defects * 50 >= 2000 then 'red'
             when a.total_dead_pixels + a.cluster_defects * 10 + a.line_defects * 50 >= 500 then 'amber'
             when a.total_dead_pixels + a.cluster_defects * 10 + a.line_defects * 50 >= 100 then 'yellow'
             else 'green'
           end::text as risk_band -- round3791: now column 9 = declared risk_band text; trailing comma dropped as this is now the last select expression
    from dr_detector_panel_audits_r3132 a
    order by defect_score desc;
end;
$function$;

-- founder_409a_summary_kpis
CREATE OR REPLACE FUNCTION public.founder_409a_summary_kpis()
 RETURNS TABLE(total_valuations bigint, approved_count bigint, draft_count bigint, under_review_count bigint, superseded_count bigint, current_common_paise bigint, current_preferred_paise bigint, current_ratio_pct numeric, current_enterprise_value_paise bigint, current_vendor text, current_methodology text, current_safe_harbor boolean, days_until_expiry integer, pending_repricing_triggers bigint, affected_options_total bigint, total_repriced_options bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH current_val AS (
    SELECT * FROM founder_409a_valuations
    WHERE status = 'approved'
    ORDER BY effective_date DESC LIMIT 1
  )
  SELECT
    (SELECT COUNT(*) FROM founder_409a_valuations),
    (SELECT COUNT(*) FROM founder_409a_valuations WHERE status = 'approved'),
    (SELECT COUNT(*) FROM founder_409a_valuations WHERE status = 'draft'),
    (SELECT COUNT(*) FROM founder_409a_valuations WHERE status = 'under_review'),
    (SELECT COUNT(*) FROM founder_409a_valuations WHERE status = 'superseded'),
    (SELECT common_price_per_share_paise FROM current_val),
    (SELECT preferred_price_per_share_paise FROM current_val),
    COALESCE((SELECT round((common_price_per_share_paise::numeric / NULLIF(preferred_price_per_share_paise,0)) * 100, 2) FROM current_val), 0),
    (SELECT enterprise_value_paise FROM current_val),
    (SELECT vendor FROM current_val),
    (SELECT methodology FROM current_val),
    (SELECT safe_harbor FROM current_val),
    (SELECT (expires_on - CURRENT_DATE)::int FROM current_val),
    (SELECT COUNT(*) FROM founder_409a_esop_repricing_triggers WHERE decision = 'pending'),
    -- round3791: col 15 (affected_options_total) was the reported 42804 mismatch. affected_options is bigint, and SUM(bigint) returns numeric in Postgres. This is an option TALLY (a sum of counts), not money/rate, so bigint is the correct contract -> cast the query column instead of widening the declaration. Cast is exact: SUM of bigints is always integral.
    COALESCE((SELECT SUM(affected_options) FROM founder_409a_esop_repricing_triggers WHERE decision = 'pending'), 0)::bigint,
    -- round3791: col 16 (total_repriced_options) is the identical SUM(bigint)->numeric mismatch and would have failed on the very next call. Same reasoning: an option tally, so cast to bigint.
    COALESCE((SELECT SUM(affected_options) FROM founder_409a_esop_repricing_triggers WHERE decision = 'executed'), 0)::bigint;
END;
$function$
;

-- founder_amc_base_growth
CREATE OR REPLACE FUNCTION public.founder_amc_base_growth()
 RETURNS TABLE(month_ist date, new_amcs bigint, new_mrr numeric, cumulative bigint, cum_mrr numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
                WHERE date_trunc('month', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n,
      coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
                WHERE date_trunc('month', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS mrr
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    monthly.mrr,
    -- round3791: sum(bigint) returns numeric in PostgreSQL, which broke the declared bigint contract (42804).
    -- round3791: `cumulative` is a running tally of counted AMC contracts (monthly.n is count(*)), not money/rate/avg,
    -- round3791: so bigint is the correct contract and the ::bigint cast is lossless -- cast the query, not the declaration.
    (sum(monthly.n) OVER (ORDER BY monthly.month_ist))::bigint AS cumulative,
    -- round3791: cum_mrr left as numeric: sum(numeric) is already numeric and it is MONEY (rupees+paise),
    -- round3791: so no cast is added here -- casting would silently drop paise from a founder financial report.
    sum(monthly.mrr) OVER (ORDER BY monthly.month_ist) AS cum_mrr
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$
;

-- founder_amc_revenue_cumulative
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_cumulative()
 RETURNS TABLE(month_ist date, paid_count bigint, paid_rupees numeric, cum_count bigint, cum_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.amc_payment_orders o
                WHERE o.status = 'paid'
                  AND date_trunc('month', (o.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n,
      coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
                WHERE o.status = 'paid'
                  AND date_trunc('month', (o.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS r
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    monthly.r,
    (sum(monthly.n) OVER (ORDER BY monthly.month_ist))::bigint, -- round3791: sum(bigint) returns numeric but cum_count is declared bigint (42804); it is a running tally of count(*) so bigint is the right contract and the cast is lossless (no fractional part).
    sum(monthly.r) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_audit_by_actor
CREATE OR REPLACE FUNCTION public.founder_audit_by_actor()
 RETURNS TABLE(actor_user_id uuid, actor_email text, display_name text, ops_30d bigint, distinct_ops bigint, last_op_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    l.actor_user_id,
    coalesce((SELECT email FROM auth.users u WHERE u.id = l.actor_user_id), 'unknown')::text, -- round3791: auth.users.email is character varying(255), so this coalesce yielded varchar against declared text (col 2) — cast to text, lossless
    coalesce((SELECT full_name FROM public.profiles p WHERE p.id = l.actor_user_id), '(no profile)'),
    count(*)::bigint,
    count(DISTINCT l.op_name)::bigint,
    max(l.created_at)
  FROM public.founder_action_log l
  WHERE l.created_at >= now() - interval '30 days'
  GROUP BY l.actor_user_id
  ORDER BY ops_30d DESC
  LIMIT 50;
END;
$function$;

-- founder_chain_leader_kpi_r2751
CREATE OR REPLACE FUNCTION public.founder_chain_leader_kpi_r2751()
 RETURNS TABLE(total_leaders bigint, deciders bigint, champions bigint, blockers bigint, avg_warmth numeric, touchpoints_this_q bigint, open_commitments bigint, pipeline_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM hospital_chain_clinical_leaders_r2751),
    (SELECT count(*) FROM hospital_chain_clinical_leaders_r2751 WHERE influence_tier = 'decider'),
    (SELECT count(*) FROM hospital_chain_clinical_leaders_r2751 WHERE influence_tier = 'champion'),
    (SELECT count(*) FROM hospital_chain_clinical_leaders_r2751 WHERE influence_tier = 'blocker'),
    (SELECT round(avg(warmth_score)::numeric, 2) FROM hospital_chain_clinical_leaders_r2751),
    (SELECT count(*) FROM hospital_chain_leader_touchpoints_r2751 WHERE quarter = 'FY27Q1'),
    (SELECT count(*) FROM hospital_chain_leader_touchpoints_r2751 WHERE commitment_status IN ('open','in_progress')),
    -- round3791: sum(bigint) returns numeric, which broke the declared bigint (42804 on every call).
    -- round3791: cast to bigint rather than widening the declaration -- revenue_impact_rupees is
    -- round3791: itself bigint (whole rupees, no paise column exists), so the sum is mathematically
    -- round3791: an integer and ::bigint is lossless; sibling RPCs in the same migration
    -- round3791: (outcome_funnel, warmth_by_chain) already cast this exact expression ::bigint.
    (SELECT coalesce(sum(revenue_impact_rupees),0)::bigint FROM hospital_chain_leader_touchpoints_r2751 WHERE commitment_status IN ('open','in_progress'));
END $function$;

-- founder_churn_save_roi_kpis
CREATE OR REPLACE FUNCTION public.founder_churn_save_roi_kpis()
 RETURNS TABLE(total_saves integer, retained_count integer, churned_count integer, pending_count integer, total_cost_rupees numeric, total_revenue_saved_rupees numeric, blended_roi numeric, median_roi numeric, top_roi numeric, worst_roi numeric, saves_last_30d integer, saves_last_90d integer, retained_rate_pct numeric, cost_per_retained_rupees numeric, unique_hospitals integer, best_action text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM founder_churn_save_roi_v2
  ),
  per_action AS (
    SELECT save_action, AVG(roi_ratio) AS avg_roi
    FROM base WHERE roi_ratio IS NOT NULL
    GROUP BY save_action
    ORDER BY avg_roi DESC NULLS LAST LIMIT 1
  )
  SELECT
    (SELECT COUNT(*)::int FROM base),
    (SELECT COUNT(*)::int FROM base WHERE outcome='retained'),
    (SELECT COUNT(*)::int FROM base WHERE outcome='churned'),
    (SELECT COUNT(*)::int FROM base WHERE outcome='pending'),
    COALESCE((SELECT SUM(cost_of_save_rupees) FROM base),0),
    COALESCE((SELECT SUM(revenue_saved_12mo_rupees) FROM base),0),
    CASE WHEN COALESCE((SELECT SUM(cost_of_save_rupees) FROM base),0) > 0
      THEN (SELECT SUM(revenue_saved_12mo_rupees) FROM base) / (SELECT SUM(cost_of_save_rupees) FROM base)
      ELSE 0 END,
    -- round3791: col 8 median_roi -- percentile_cont has no numeric variant, so it upcasts
    -- roi_ratio and returns double precision (the 42804 cause); cast back to the declared numeric.
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY roi_ratio) FROM base WHERE roi_ratio IS NOT NULL),0)::numeric,
    COALESCE((SELECT MAX(roi_ratio) FROM base),0),
    COALESCE((SELECT MIN(roi_ratio) FROM base WHERE roi_ratio IS NOT NULL),0),
    (SELECT COUNT(*)::int FROM base WHERE action_taken_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM base WHERE action_taken_at > now() - interval '90 days'),
    CASE WHEN (SELECT COUNT(*) FROM base WHERE outcome IN ('retained','churned')) > 0
      THEN ROUND(100.0 * (SELECT COUNT(*) FROM base WHERE outcome='retained') / (SELECT COUNT(*) FROM base WHERE outcome IN ('retained','churned')),1)
      ELSE 0 END,
    CASE WHEN (SELECT COUNT(*) FROM base WHERE outcome='retained') > 0
      THEN ROUND((SELECT SUM(cost_of_save_rupees) FROM base WHERE outcome='retained') / (SELECT COUNT(*) FROM base WHERE outcome='retained'),0)
      ELSE 0 END,
    (SELECT COUNT(DISTINCT hospital_org_id)::int FROM base),
    COALESCE((SELECT save_action FROM per_action),'-');
END $function$;

-- founder_clv_calculator_summary
CREATE OR REPLACE FUNCTION public.founder_clv_calculator_summary()
 RETURNS TABLE(total_snapshots integer, unique_hospitals integer, snapshots_last_7d integer, snapshots_last_30d integer, avg_clv_rupees numeric, top_clv_rupees numeric, bottom_clv_rupees numeric, median_clv_rupees numeric, p90_clv_threshold_rupees numeric, total_clv_book_rupees numeric, platinum_count integer, gold_count integer, silver_count integer, bronze_count integer, critical_band_count integer, gold_to_bronze_ratio numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_user_id) *
    FROM public.founder_customer_lifetime_value_snapshots
    ORDER BY hospital_user_id, snapshot_at DESC
  ),
  s AS (SELECT * FROM public.founder_customer_lifetime_value_snapshots)
  SELECT
    (SELECT count(*)::int FROM s),
    (SELECT count(DISTINCT hospital_user_id)::int FROM s),
    (SELECT count(*)::int FROM s WHERE snapshot_at >= now() - interval '7 days'),
    (SELECT count(*)::int FROM s WHERE snapshot_at >= now() - interval '30 days'),
    (SELECT round(avg(total_projected_clv_rupees)::numeric, 2) FROM latest),
    (SELECT max(total_projected_clv_rupees) FROM latest),
    (SELECT min(total_projected_clv_rupees) FROM latest),
    -- round3791: col 8 median_clv_rupees -- percentile_cont has no numeric variant, so it returned double precision (42804); cast result to numeric to match the declared money column (declaration kept numeric: rupee amounts must not be narrowed).
    (SELECT (percentile_cont(0.5) WITHIN GROUP (ORDER BY total_projected_clv_rupees))::numeric FROM latest),
    -- round3791: col 9 p90_clv_threshold_rupees -- same percentile_cont double-precision return as col 8; cast result to numeric (declaration kept numeric for the same money-precision reason).
    (SELECT (percentile_cont(0.9) WITHIN GROUP (ORDER BY total_projected_clv_rupees))::numeric FROM latest),
    (SELECT coalesce(sum(total_projected_clv_rupees), 0) FROM latest),
    (SELECT count(*)::int FROM latest WHERE value_segment = 'platinum'),
    (SELECT count(*)::int FROM latest WHERE value_segment = 'gold'),
    (SELECT count(*)::int FROM latest WHERE value_segment = 'silver'),
    (SELECT count(*)::int FROM latest WHERE value_segment = 'bronze'),
    (SELECT count(*)::int FROM latest WHERE churn_risk_band = 'critical'),
    (SELECT CASE WHEN nullif(count(*) FILTER (WHERE value_segment='bronze'),0) IS NULL THEN NULL
                 ELSE round((count(*) FILTER (WHERE value_segment='gold'))::numeric
                          / nullif(count(*) FILTER (WHERE value_segment='bronze'),0)::numeric, 3) END
     FROM latest);
END;
$function$;

-- founder_code_red_cumulative
CREATE OR REPLACE FUNCTION public.founder_code_red_cumulative()
 RETURNS TABLE(month_ist date, opened bigint, cum_opened bigint, resolved bigint, cum_resolved bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
                WHERE date_trunc('month', (r.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS o,
      coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
                WHERE r.status = 'resolved'
                  AND date_trunc('month', (r.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS r
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.o,
    (sum(monthly.o) OVER (ORDER BY monthly.month_ist))::bigint, -- round3791: sum(bigint) returns numeric, not bigint (42804 in column 3); cum_opened is a running tally of count(*), so bigint is the correct contract and the cast is lossless
    monthly.r,
    (sum(monthly.r) OVER (ORDER BY monthly.month_ist))::bigint -- round3791: same numeric-vs-bigint mismatch the analyzer never reached; cum_resolved is also a running tally of count(*), so cast rather than widen
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_code_red_recent
CREATE OR REPLACE FUNCTION public.founder_code_red_recent(p_days integer DEFAULT 30, p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, hospital_email text, equipment_type text, description text, status text, sla_minutes integer, sla_deadline_at timestamp with time zone, accepted_engineer_email text, time_to_accept_minutes numeric, paged_count integer, declined_count integer, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    -- round3791: auth.users.email is character varying(255) but OUT col 2 hospital_email is declared text -> lossless ::text cast (this was the reported 42804 column)
    coalesce((SELECT email FROM auth.users WHERE id = r.hospital_user_id), 'unknown')::text,
    r.equipment_type, r.description, r.status,
    r.sla_minutes, r.sla_deadline_at,
    -- round3791: same character varying(255) -> text mismatch on OUT col 8 accepted_engineer_email; the analyzer stopped at col 2 and never reached this one
    coalesce((SELECT email FROM auth.users WHERE id = r.accepted_engineer_user_id), NULL)::text,
    CASE WHEN r.accepted_at IS NOT NULL
         THEN round(EXTRACT(EPOCH FROM (r.accepted_at - r.created_at)) / 60.0, 1)
         ELSE NULL END,
    (SELECT count(*)::int FROM public.code_red_dispatch_events e
       WHERE e.code_red_id = r.id),
    (SELECT count(*)::int FROM public.code_red_dispatch_events e
       WHERE e.code_red_id = r.id AND e.outcome = 'declined'),
    r.created_at
  FROM public.code_red_requests r
  WHERE r.created_at >= now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval
  ORDER BY r.created_at DESC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$function$;

-- founder_demand_signals_cumulative
CREATE OR REPLACE FUNCTION public.founder_demand_signals_cumulative()
 RETURNS TABLE(month_ist date, signals bigint, cum_signals bigint, resolved bigint, cum_resolved bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals s
                WHERE date_trunc('month', (s.occurred_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS s,
      coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals s
                WHERE s.resolved_at IS NOT NULL
                  AND date_trunc('month', (s.resolved_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS r
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.s,
    -- round3791: sum(bigint) returns numeric -> col 3 (cum_signals bigint) raised 42804. Cast to bigint: this is a running tally of count(*), so an integer contract is correct and the cast is lossless (no fractional part exists).
    (sum(monthly.s) OVER (ORDER BY monthly.month_ist))::bigint,
    monthly.r,
    -- round3791: same defect in col 5 (cum_resolved bigint), not yet reported because the analyzer stops at the first mismatch. Also a running tally of count(*), so ::bigint is lossless.
    (sum(monthly.r) OVER (ORDER BY monthly.month_ist))::bigint
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_disputes_cumulative
CREATE OR REPLACE FUNCTION public.founder_disputes_cumulative()
 RETURNS TABLE(month_ist date, submitted bigint, cum_submitted bigint, accepted bigint, rejected bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
                WHERE d.submitted_at IS NOT NULL
                  AND date_trunc('month', (d.submitted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS s,
      coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
                WHERE d.status = 'accepted' AND d.mediator_decision_at IS NOT NULL
                  AND date_trunc('month', (d.mediator_decision_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS a,
      coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
                WHERE d.status = 'rejected' AND d.mediator_decision_at IS NOT NULL
                  AND date_trunc('month', (d.mediator_decision_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS r
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.s,
    -- round3791: sum(bigint) returns numeric, but col 3 cum_submitted is declared bigint (42804).
    -- round3791: cum_submitted is a running tally OF count(*) values, so bigint is the correct
    -- round3791: contract -- cast the query column (no precision to lose on integer counts).
    (sum(monthly.s) OVER (ORDER BY monthly.month_ist))::bigint,
    monthly.a,
    monthly.r
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_dispute_kpis
CREATE OR REPLACE FUNCTION public.founder_dispute_kpis()
 RETURNS TABLE(total_disputes integer, open_count integer, raised_count integer, investigating_count integer, resolved_count integer, escalated_count integer, closed_count integer, sla_breached integer, sla_within_4h integer, median_resolution_hours numeric, total_delta_rupees integer, paid_back_rupees integer, urgent_count integer, last_24h_raised integer, amount_disputes integer, missing_disputes integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status IN ('raised','investigating','escalated'))::int,
    COUNT(*) FILTER (WHERE status='raised')::int,
    COUNT(*) FILTER (WHERE status='investigating')::int,
    COUNT(*) FILTER (WHERE status='resolved')::int,
    COUNT(*) FILTER (WHERE status='escalated')::int,
    COUNT(*) FILTER (WHERE status='closed')::int,
    COUNT(*) FILTER (WHERE sla_target_at < now() AND status IN ('raised','investigating'))::int,
    COUNT(*) FILTER (WHERE sla_target_at < now() + interval '4 hours' AND sla_target_at >= now() AND status IN ('raised','investigating'))::int,
    -- round3791: col 10 median_resolution_hours -- percentile_cont has only float8/interval variants, so this aggregate returns double precision while the column is declared numeric (the 42804). Cast the query column to numeric; the declaration stays numeric because this is a median (precision matters), not a count.
    (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolved_at - raised_at))/3600.0) FILTER (WHERE resolved_at IS NOT NULL))::numeric,
    COALESCE(SUM(delta_rupees),0)::int,
    COALESCE(SUM(resolved_amount_rupees) FILTER (WHERE status IN ('resolved','closed')),0)::int,
    COUNT(*) FILTER (WHERE priority='urgent' AND status IN ('raised','investigating','escalated'))::int,
    COUNT(*) FILTER (WHERE raised_at > now() - interval '24 hours')::int,
    COUNT(*) FILTER (WHERE dispute_type='amount_mismatch')::int,
    COUNT(*) FILTER (WHERE dispute_type='missing_payout')::int
  FROM engineer_payout_disputes;
END $function$;

-- founder_engineer_ltv_ranked
CREATE OR REPLACE FUNCTION public.founder_engineer_ltv_ranked(p_limit integer DEFAULT 50)
 RETURNS TABLE(engineer_user_id uuid, engineer_email text, first_active_at timestamp with time zone, total_jobs_completed bigint, total_gross_rupees numeric, total_net_paid_rupees numeric, total_tds_rupees numeric, avg_rating numeric, dispute_count bigint, current_risk_score integer, risk_band text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      ep.engineer_user_id,
      min(ep.updated_at) AS first_active_at,
      count(*) FILTER (WHERE ep.status = 'processed') AS jobs_paid,
      coalesce(
        sum(round(ep.amount_paise::numeric / 100.0, 2))
          FILTER (WHERE ep.status = 'processed'),
        0
      ) AS gross,
      coalesce(sum(t.net_payable_rupees) FILTER (WHERE t.id IS NOT NULL), 0) AS net_paid,
      coalesce(sum(t.tds_rupees) FILTER (WHERE t.id IS NOT NULL), 0) AS tds
    FROM public.engineer_payouts ep
    LEFT JOIN public.tds_deductions t ON t.payout_id = ep.id
    GROUP BY ep.engineer_user_id
  ),
  ratings AS (
    SELECT b.engineer_user_id, avg(rj.hospital_rating)::numeric(3,2) AS avg_rating
      FROM public.repair_job_bids b
      JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
     WHERE b.status = 'accepted'
       AND rj.status = 'completed'
       AND rj.hospital_rating IS NOT NULL
     GROUP BY b.engineer_user_id
  ),
  disputes AS (
    SELECT b.engineer_user_id, count(*)::bigint AS dispute_count
      FROM public.repair_job_bids b
      JOIN public.repair_job_escrow e ON e.repair_job_id = b.repair_job_id
     WHERE b.status = 'accepted'
       AND e.status = 'disputed'
     GROUP BY b.engineer_user_id
  ),
  risk AS (
    SELECT DISTINCT ON (s.user_id) s.user_id, s.score, s.band
      FROM public.risk_score_snapshots s
     WHERE s.role = 'engineer'
     ORDER BY s.user_id, s.computed_at DESC
  )
  SELECT
    base.engineer_user_id,
    -- round3791: auth.users.email is character varying(255), so this coalesce yielded varchar and broke the declared `engineer_email text` (42804, column 2). Cast to text -- lossless.
    coalesce((SELECT email FROM auth.users WHERE id = base.engineer_user_id), 'unknown')::text,
    base.first_active_at,
    base.jobs_paid,
    base.gross,
    base.net_paid,
    base.tds,
    ratings.avg_rating,
    coalesce(disputes.dispute_count, 0)::bigint,
    risk.score,
    risk.band
  FROM base
  LEFT JOIN ratings  ON ratings.engineer_user_id  = base.engineer_user_id
  LEFT JOIN disputes ON disputes.engineer_user_id = base.engineer_user_id
  LEFT JOIN risk     ON risk.user_id              = base.engineer_user_id
  ORDER BY base.gross DESC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$function$;

-- founder_engineer_specialization_coverage
CREATE OR REPLACE FUNCTION public.founder_engineer_specialization_coverage()
 RETURNS TABLE(category text, verified_cnt bigint, total_cnt bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH unrolled AS (
    SELECT e.id, e.verification_status, unnest(e.specializations) AS cat
    FROM public.engineers e
    WHERE e.specializations IS NOT NULL
      AND array_length(e.specializations, 1) IS NOT NULL
  )
  SELECT
    cat::text, -- round3791: engineers.specializations is equipment_category[], so unnest() yields the equipment_category enum; cast to text to match declared column 1 (category text). Lossless.
    count(*) FILTER (WHERE verification_status = 'verified')::bigint AS verified_cnt,
    count(*)::bigint                                                  AS total_cnt
  FROM unrolled
  GROUP BY cat
  ORDER BY verified_cnt DESC, total_cnt DESC
  LIMIT 50;
END;
$function$;

-- founder_fleet_red_flags
CREATE OR REPLACE FUNCTION public.founder_fleet_red_flags(p_limit integer DEFAULT 50)
 RETURNS TABLE(hospital_user_id uuid, hospital_email text, total_failures_90d integer, unique_assets_90d integer, avg_mttr_hours numeric, replacement_candidates integer, oldest_unresolved_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH window_jobs AS (
    SELECT
      rj.hospital_user_id,
      rj.equipment_type,
      rj.equipment_brand,
      rj.equipment_model,
      rj.equipment_serial,
      rj.created_at,
      rj.completed_at,
      rj.status
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '90 days'
      AND rj.hospital_user_id IS NOT NULL
  ),
  per_eq AS (
    SELECT
      hospital_user_id,
      equipment_type, equipment_brand, equipment_model, equipment_serial,
      count(*) AS failures
    FROM window_jobs
    GROUP BY hospital_user_id, equipment_type, equipment_brand, equipment_model, equipment_serial
  ),
  per_hospital AS (
    SELECT
      hospital_user_id,
      sum(failures)::int AS total_failures,
      count(*)::int AS unique_assets,
      count(*) FILTER (WHERE failures > 3)::int AS replacement_count
    FROM per_eq
    GROUP BY hospital_user_id
  ),
  mttr AS (
    SELECT
      hospital_user_id,
      avg(EXTRACT(EPOCH FROM (completed_at - created_at)) / 3600.0)
        FILTER (WHERE completed_at IS NOT NULL)::numeric(8,2) AS avg_mttr
    FROM window_jobs
    GROUP BY hospital_user_id
  ),
  oldest AS (
    SELECT
      hospital_user_id,
      min(created_at) FILTER (WHERE status NOT IN ('completed','cancelled')) AS oldest_unresolved
    FROM window_jobs
    GROUP BY hospital_user_id
  )
  SELECT
    ph.hospital_user_id,
    -- round3791: added ::text — auth.users.email is character varying(255), so this
    -- coalesce() resolved to varchar while OUT column 2 hospital_email is declared
    -- text, which is what raised 42804. varchar->text is lossless.
    coalesce((SELECT email FROM auth.users WHERE id = ph.hospital_user_id), 'unknown')::text,
    ph.total_failures,
    ph.unique_assets,
    m.avg_mttr,
    ph.replacement_count,
    o.oldest_unresolved
  FROM per_hospital ph
  LEFT JOIN mttr   m ON m.hospital_user_id = ph.hospital_user_id
  LEFT JOIN oldest o ON o.hospital_user_id = ph.hospital_user_id
  WHERE ph.total_failures > 5
     OR coalesce(m.avg_mttr, 0) > 48
     OR ph.replacement_count > 0
  ORDER BY ph.replacement_count DESC, ph.total_failures DESC, m.avg_mttr DESC NULLS LAST
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$function$;

-- founder_gmv_by_equipment_type
CREATE OR REPLACE FUNCTION public.founder_gmv_by_equipment_type(p_days integer DEFAULT 30)
 RETURNS TABLE(equipment_type text, job_count bigint, gmv_rupees numeric, avg_ticket_rupees numeric, dispute_count bigint, dispute_rate_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH window_jobs AS (
    SELECT rj.id, rj.equipment_type, e.amount_rupees, e.status
      FROM public.repair_jobs rj
      LEFT JOIN public.repair_job_escrow e ON e.repair_job_id = rj.id
     WHERE rj.created_at >= now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval
       AND rj.equipment_type IS NOT NULL
  )
  SELECT wj.equipment_type::text,  -- round3791: col 1 is the equipment_category ENUM but is declared text (the 42804) — lossless enum->text cast, matching this repo's convention elsewhere (r1449/parts-outliers); GROUP BY still on the enum, so no semantic change
         count(*)::bigint,
         coalesce(sum(wj.amount_rupees), 0)::numeric,
         coalesce(avg(wj.amount_rupees), 0)::numeric,
         count(*) FILTER (WHERE wj.status = 'disputed')::bigint,
         CASE WHEN count(*) > 0 THEN
              round(count(*) FILTER (WHERE wj.status = 'disputed') * 100.0 / count(*), 1)
              ELSE 0 END
    FROM window_jobs wj
   GROUP BY wj.equipment_type
   ORDER BY sum(wj.amount_rupees) DESC NULLS LAST;
END;
$function$;

-- founder_gmv_cumulative
CREATE OR REPLACE FUNCTION public.founder_gmv_cumulative()
 RETURNS TABLE(month_ist date, monthly_gmv numeric, cumulative_gmv numeric, monthly_jobs bigint, cumulative_jobs bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
                WHERE rj.status = 'completed'
                  AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS gmv,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
                WHERE rj.status = 'completed'
                  AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS j
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.gmv,
    sum(monthly.gmv) OVER (ORDER BY monthly.month_ist),
    monthly.j,
    -- round3791: sum(bigint) returns numeric in PostgreSQL, but out column 5 (cumulative_jobs) is declared bigint -> 42804 on every call. Cast to bigint: this is a running tally of count(*) values, so bigint is the correct contract and the cast is exactly lossless (a sum of bigints is integral). Not widened to numeric because it is a job COUNT, not money -- unlike cumulative_gmv above, which stays numeric to preserve paise.
    (sum(monthly.j) OVER (ORDER BY monthly.month_ist))::bigint
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_grants_audit
CREATE OR REPLACE FUNCTION public.founder_grants_audit()
 RETURNS TABLE(function_name text, authenticated boolean, service_role boolean, anon boolean, arg_signature text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH fns AS (
    SELECT
      n.nspname                                  AS schema_name,
      p.proname                                   AS fn_name,
      pg_get_function_identity_arguments(p.oid)   AS args,
      p.oid                                       AS fn_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'founder_%'
  ),
  privs AS (
    SELECT
      f.fn_name,
      f.args,
      has_function_privilege('authenticated', f.fn_oid, 'EXECUTE') AS can_auth,
      has_function_privilege('service_role',  f.fn_oid, 'EXECUTE') AS can_svc,
      has_function_privilege('anon',          f.fn_oid, 'EXECUTE') AS can_anon
    FROM fns f
  )
  SELECT
    pr.fn_name::text,  -- round3791: pg_proc.proname is type `name`, declared OUT col 1 is text -> 42804 on every call. Lossless cast. Cast here (not in the fns CTE) so ORDER BY pr.fn_name still sorts the `name`-typed input column and row order is unchanged.
    pr.can_auth,
    pr.can_svc,
    pr.can_anon,
    pr.args
  FROM privs pr
  ORDER BY pr.fn_name;
END;
$function$;

-- founder_hospital_department_breakout_summary
CREATE OR REPLACE FUNCTION public.founder_hospital_department_breakout_summary()
 RETURNS TABLE(total_departments bigint, top_dept_kind text, top_dept_kind_count bigint, hospitals_with_departments bigint, avg_departments_per_hospital numeric, total_equipment_across_depts bigint, total_visits_30d bigint, top_dept_by_visits text, top_dept_by_visits_count bigint, depts_with_no_visits_30d bigint, depts_idle_over_60d bigint, unique_engineers_assigned bigint, max_equipment_in_one_dept bigint, avg_equipment_per_dept numeric, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder gate' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_hospital_departments
  ),
  kind_agg AS (
    SELECT department_kind, COUNT(*)::bigint AS c
    FROM base GROUP BY department_kind
    ORDER BY c DESC NULLS LAST LIMIT 1
  ),
  visit_top AS (
    SELECT department_label, total_visits_30d
    FROM base ORDER BY total_visits_30d DESC NULLS LAST LIMIT 1
  )
  SELECT
    (SELECT COUNT(*)::bigint FROM base),
    (SELECT department_kind FROM kind_agg),
    COALESCE((SELECT c FROM kind_agg), 0),
    (SELECT COUNT(DISTINCT hospital_user_id)::bigint FROM base),
    COALESCE((SELECT ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT hospital_user_id), 0), 2) FROM base), 0),
    COALESCE((SELECT SUM(total_equipment_count)::bigint FROM base), 0),
    COALESCE((SELECT SUM(total_visits_30d)::bigint FROM base), 0),
    (SELECT department_label FROM visit_top),
    -- round3791: was integer (founder_hospital_departments.total_visits_30d is `int`, selected raw through visit_top with no cast) vs declared bigint -> 42804. Cast to bigint; this OUT col is a visit TALLY, so the bigint contract is correct and widening int->bigint is lossless.
    COALESCE((SELECT total_visits_30d::bigint FROM visit_top), 0),
    (SELECT COUNT(*)::bigint FROM base WHERE total_visits_30d = 0),
    (SELECT COUNT(*)::bigint FROM base WHERE last_visit_at IS NULL OR last_visit_at < now() - interval '60 days'),
    (SELECT COUNT(DISTINCT primary_engineer_id)::bigint FROM base WHERE primary_engineer_id IS NOT NULL),
    COALESCE((SELECT MAX(total_equipment_count)::bigint FROM base), 0),
    COALESCE((SELECT ROUND(AVG(total_equipment_count)::numeric, 2) FROM base), 0),
    now();
END;
$function$;

-- founder_investor_channel_mix
CREATE OR REPLACE FUNCTION public.founder_investor_channel_mix()
 RETURNS TABLE(channel text, total_count integer, open_count integer, overdue_count integer, median_clear_hours numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.channel,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE i.cleared_at IS NULL)::int,
         COUNT(*) FILTER (WHERE i.cleared_at IS NULL AND i.followup_due_at < now())::int,
         -- round3791: cast col 5 to numeric -- percentile_cont has no numeric variant, so the numeric ORDER BY expr is promoted to float8 and the aggregate returned double precision, which is not binary-coercible to the declared `median_clear_hours numeric` (SQLSTATE 42804). Cast the QUERY column rather than widening the declaration to float8, because this is a median (precision value), so numeric is the correct contract.
         (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (i.cleared_at - i.contacted_at))/3600.0) FILTER (WHERE i.cleared_at IS NOT NULL))::numeric
  FROM founder_investor_interactions_v2 i
  GROUP BY i.channel
  ORDER BY COUNT(*) DESC;
END $function$;

-- founder_investor_sla_summary
CREATE OR REPLACE FUNCTION public.founder_investor_sla_summary()
 RETURNS TABLE(total_open integer, overdue_count integer, due_24h integer, cleared_7d integer, median_clear_hours numeric, oldest_overdue_hours numeric, unique_investors integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE cleared_at IS NULL)::int,
    COUNT(*) FILTER (WHERE cleared_at IS NULL AND followup_due_at < now())::int,
    COUNT(*) FILTER (WHERE cleared_at IS NULL AND followup_due_at BETWEEN now() AND now() + interval '24 hours')::int,
    COUNT(*) FILTER (WHERE cleared_at >= now() - interval '7 days')::int,
    -- round3791: col 5 median_clear_hours - percentile_cont has no numeric variant (only ORDER BY double precision / interval), so the numeric ORDER BY expr is implicitly cast to float8 and the aggregate returned double precision vs declared numeric -> cast result ::numeric (lossless; keeps the numeric contract the web console reads)
    (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (cleared_at - contacted_at))/3600.0) FILTER (WHERE cleared_at IS NOT NULL))::numeric,
    -- round3791: col 6 oldest_overdue_hours - same defect class, next in the select list: EXTRACT(EPOCH FROM interval) is numeric on PG14+ but double precision earlier, so max(...) can be float8 vs declared numeric -> pin it with ::numeric (no-op when already numeric, correct fix when float8) so the call cannot fail on this column
    (MAX(EXTRACT(EPOCH FROM (now() - followup_due_at))/3600.0) FILTER (WHERE cleared_at IS NULL AND followup_due_at < now()))::numeric,
    COUNT(DISTINCT investor_name)::int
  FROM founder_investor_interactions_v2;
END $function$;

-- founder_ipu_benchmark
CREATE OR REPLACE FUNCTION public.founder_ipu_benchmark()
 RETURNS TABLE(id text, metric text, our_value numeric, peer_median numeric, peer_p75 numeric, delta_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  our_mrr numeric;
  our_growth numeric;
  our_churn numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT coalesce(sum(amount_rupees),0) INTO our_mrr
  FROM amc_payment_pool
  WHERE created_at >= date_trunc('month', now());

  our_growth := 12.5;
  our_churn := 3.2;

  RETURN QUERY
  SELECT 'mrr'::text, 'MRR (₹)'::text, our_mrr,
         coalesce((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY mrr_rupees) FROM investor_portfolio_updates WHERE mrr_rupees IS NOT NULL),0)::numeric, -- round3791: percentile_cont returns double precision (no numeric overload), declared peer_median is numeric -> cast col 4
         coalesce((SELECT percentile_cont(0.75) WITHIN GROUP (ORDER BY mrr_rupees) FROM investor_portfolio_updates WHERE mrr_rupees IS NOT NULL),0)::numeric, -- round3791: same double precision -> numeric mismatch on col 5 (peer_p75); would have failed next
         0::numeric
  UNION ALL
  SELECT 'growth'::text, 'MoM growth %'::text, our_growth,
         coalesce((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY growth_mom_pct) FROM investor_portfolio_updates WHERE growth_mom_pct IS NOT NULL),0)::numeric, -- round3791: percentile_cont returns double precision, declared peer_median is numeric -> cast col 4
         coalesce((SELECT percentile_cont(0.75) WITHIN GROUP (ORDER BY growth_mom_pct) FROM investor_portfolio_updates WHERE growth_mom_pct IS NOT NULL),0)::numeric, -- round3791: percentile_cont returns double precision, declared peer_p75 is numeric -> cast col 5
         0::numeric
  UNION ALL
  SELECT 'churn'::text, 'Churn %'::text, our_churn,
         coalesce((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY churn_pct) FROM investor_portfolio_updates WHERE churn_pct IS NOT NULL),0)::numeric, -- round3791: percentile_cont returns double precision, declared peer_median is numeric -> cast col 4
         coalesce((SELECT percentile_cont(0.75) WITHIN GROUP (ORDER BY churn_pct) FROM investor_portfolio_updates WHERE churn_pct IS NOT NULL),0)::numeric, -- round3791: percentile_cont returns double precision, declared peer_p75 is numeric -> cast col 5
         0::numeric;
END $function$;

-- founder_ipu_kpis
CREATE OR REPLACE FUNCTION public.founder_ipu_kpis()
 RETURNS TABLE(total_updates bigint, unread_count bigint, starred_count bigint, archived_count bigint, this_month_count bigint, last_month_count bigint, unique_senders bigint, unique_sectors bigint, avg_mrr_rupees bigint, median_growth_mom_pct numeric, avg_runway_months numeric, highest_growth_pct numeric, lowest_runway_months numeric, actions_logged bigint, followups_open bigint, meetings_booked bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM investor_portfolio_updates),
    (SELECT count(*) FROM investor_portfolio_updates WHERE read_state='unread'),
    (SELECT count(*) FROM investor_portfolio_updates WHERE read_state='starred'),
    (SELECT count(*) FROM investor_portfolio_updates WHERE read_state='archived'),
    (SELECT count(*) FROM investor_portfolio_updates WHERE reporting_month >= date_trunc('month', now())::date),
    (SELECT count(*) FROM investor_portfolio_updates WHERE reporting_month >= (date_trunc('month', now()) - interval '1 month')::date AND reporting_month < date_trunc('month', now())::date),
    (SELECT count(DISTINCT sender_company) FROM investor_portfolio_updates),
    (SELECT count(DISTINCT sector) FROM investor_portfolio_updates),
    (SELECT coalesce(avg(mrr_rupees),0)::bigint FROM investor_portfolio_updates WHERE mrr_rupees IS NOT NULL),
    (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY growth_mom_pct) FROM investor_portfolio_updates WHERE growth_mom_pct IS NOT NULL)::numeric, -- round3791: percentile_cont has no numeric variant, so it returns double precision; cast to declared numeric (col 10) to fix SQLSTATE 42804
    (SELECT coalesce(avg(runway_months),0) FROM investor_portfolio_updates WHERE runway_months IS NOT NULL),
    (SELECT coalesce(max(growth_mom_pct),0) FROM investor_portfolio_updates WHERE growth_mom_pct IS NOT NULL),
    (SELECT coalesce(min(runway_months),0) FROM investor_portfolio_updates WHERE runway_months IS NOT NULL),
    (SELECT count(*) FROM investor_portfolio_update_actions),
    (SELECT count(*) FROM investor_portfolio_update_actions WHERE action_type='followup_scheduled'),
    (SELECT count(*) FROM investor_portfolio_update_actions WHERE action_type='meeting_booked');
END $function$;

-- founder_kyc_renewal_queue
CREATE OR REPLACE FUNCTION public.founder_kyc_renewal_queue(p_status text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, engineer_user_id uuid, engineer_email text, status text, due_at timestamp with time zone, grace_until timestamp with time zone, days_overdue numeric, refreshed_items text[])
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id,
         coalesce((SELECT email FROM auth.users WHERE id = r.engineer_user_id), 'unknown')::text, -- round3791: col 3 engineer_email — auth.users.email is varchar(255) so the coalesce resolved to character varying, not the declared text; ::text is lossless.
         r.status, r.due_at, r.grace_until,
         EXTRACT(EPOCH FROM (now() - r.due_at)) / 86400 AS days_overdue,
         r.refreshed_items
    FROM public.engineer_kyc_renewals r
   WHERE (p_status IS NULL OR r.status = p_status)
   ORDER BY r.due_at ASC
   LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$function$;

-- founder_list_hospital_chains
CREATE OR REPLACE FUNCTION public.founder_list_hospital_chains(p_status text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, name text, billing_gstin text, primary_admin_user_id uuid, primary_admin_email text, status text, member_count integer, pending_invite_count integer, contracted_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.billing_gstin,
    c.primary_admin_user_id,
    (SELECT email::text FROM auth.users WHERE id = c.primary_admin_user_id), -- round3791: auth.users.email is character varying(255); cast to text to match declared OUT column 5 (primary_admin_email text) — was the 42804 cause. Lossless.
    c.status,
    (SELECT count(*)::int FROM public.hospital_chain_memberships m WHERE m.chain_id = c.id),
    (SELECT count(*)::int FROM public.hospital_chain_invites i
       WHERE i.chain_id = c.id AND i.status = 'pending' AND i.expires_at > now()),
    c.contracted_at,
    c.created_at
   FROM public.hospital_chains c
  WHERE (p_status IS NULL OR c.status = p_status)
  ORDER BY c.created_at DESC
  LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$function$;

-- founder_loi_active_list
CREATE OR REPLACE FUNCTION public.founder_loi_active_list()
 RETURNS TABLE(id uuid, hospital_name text, city text, state text, status text, intended_amc_tier text, intended_monthly_fee_rupees integer, intended_equipment_count integer, signed_at timestamp with time zone, expected_close_date date, days_since_signed integer, signatory_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    o.name,
    o.city,
    o.state,
    l.status,
    l.intended_amc_tier,
    l.intended_monthly_fee_rupees,
    l.intended_equipment_count,
    l.signed_at,
    l.expected_close_date,
    -- round3791: cast numeric -> integer to match declared days_since_signed integer. This is a whole-day age tally (not money/rate/avg), so rounding to whole days is semantically fine; declared type kept as integer.
    (EXTRACT(EPOCH FROM (now() - l.signed_at))::numeric / 86400.0)::integer AS days_since_signed_raw,
    l.signatory_name
  FROM public.founder_hospital_lois l
  JOIN public.organizations o ON o.id = l.hospital_org_id
  WHERE l.status NOT IN ('converted','lost','expired')
  ORDER BY l.signed_at DESC;
END;
$function$;

-- founder_ma_pipeline_summary
CREATE OR REPLACE FUNCTION public.founder_ma_pipeline_summary()
 RETURNS TABLE(total_targets bigint, identified_count bigint, contacted_count bigint, nda_signed_count bigint, dd_count bigint, loi_count bigint, term_sheet_count bigint, closed_count bigint, passed_count bigint, total_estimated_acquisition_rupees numeric, total_closed_rupees numeric, total_pipeline_value numeric, top_priority_open_count bigint, days_since_last_activity_median numeric, active_integrations_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_ma_targets
  ),
  last_activity AS (
    SELECT target_id, MAX(happened_at) AS last_at
    FROM public.founder_ma_activity_log
    GROUP BY target_id
  )
  SELECT
    (SELECT COUNT(*) FROM base),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'identified'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'contacted'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'nda_signed'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'dd_in_progress'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'loi_sent'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'term_sheet'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'closed'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'passed'),
    COALESCE((SELECT SUM(estimated_acquisition_rupees) FROM base), 0),
    COALESCE((SELECT SUM(estimated_acquisition_rupees) FROM base WHERE deal_status = 'closed'), 0),
    COALESCE((SELECT SUM(estimated_acquisition_rupees) FROM base
              WHERE deal_status NOT IN ('closed','passed')), 0),
    (SELECT COUNT(*) FROM base
       WHERE deal_priority IN ('p0_critical','p1_high')
         AND deal_status NOT IN ('closed','passed')),
    COALESCE((
      SELECT percentile_cont(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (now() - la.last_at)) / 86400.0
      )
      FROM last_activity la
      JOIN base b ON b.id = la.target_id
      WHERE b.deal_status NOT IN ('closed','passed')
    ), 0)::numeric,  -- round3791: percentile_cont returns double precision (only its float8 overload applies, so the numeric ORDER BY expr is implicitly cast up); declared column 14 is numeric -> cast the result back to numeric to fix SQLSTATE 42804
    (SELECT COUNT(*) FROM base WHERE integration_status IN ('planning','migrating'));
END;
$function$;

-- founder_open_collusion_flags
CREATE OR REPLACE FUNCTION public.founder_open_collusion_flags(p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, engineer_email text, hospital_email text, signal_kind text, job_count_30d integer, total_value_rupees_30d numeric, evidence jsonb, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT c.id,
         coalesce((SELECT email FROM auth.users WHERE id = c.engineer_user_id), 'unknown')::text,  -- round3791: auth.users.email is varchar(255), so coalesce(varchar,'unknown') yields character varying, not the declared text (DETAIL col 2); ::text is lossless
         coalesce((SELECT email FROM auth.users WHERE id = c.hospital_user_id), 'unknown')::text,  -- round3791: identical varchar->text mismatch in col 3; analyzer stopped at col 2 so this one was unreported
         c.signal_kind, c.job_count_30d, c.total_value_rupees_30d, c.evidence, c.created_at
    FROM public.collusion_flags c
   WHERE c.status IN ('open','investigating')
   ORDER BY c.created_at DESC
   LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$function$;

-- founder_open_duplicate_flags
CREATE OR REPLACE FUNCTION public.founder_open_duplicate_flags(p_severity text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, user_id_a uuid, email_a text, user_id_b uuid, email_b text, signal_kind text, severity text, evidence jsonb, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT d.id, d.user_id_a,
         coalesce((SELECT email FROM auth.users WHERE id = d.user_id_a), 'unknown')::text, -- round3791: cast to text — auth.users.email is character varying(255), declared out column email_a is text (42804 col 3)
         d.user_id_b,
         coalesce((SELECT email FROM auth.users WHERE id = d.user_id_b), 'unknown')::text, -- round3791: same varchar->text mismatch on email_b (col 5); analyzer stopped at col 3 and never reached this one
         d.signal_kind, d.severity, d.evidence, d.created_at
    FROM public.duplicate_account_flags d
   WHERE d.status IN ('open','investigating')
     AND (p_severity IS NULL OR d.severity = p_severity)
   ORDER BY
     CASE d.severity
       WHEN 'critical' THEN 0
       WHEN 'high'     THEN 1
       WHEN 'medium'   THEN 2
       ELSE 3
     END,
     d.created_at DESC
   LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$function$;

-- founder_pending_kyc_list
CREATE OR REPLACE FUNCTION public.founder_pending_kyc_list()
 RETURNS TABLE(engineer_id uuid, user_id uuid, display_name text, city text, created_at timestamp with time zone, days_waiting integer, status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.user_id,
    coalesce(p.full_name, '(engineer)'),
    e.city,
    e.created_at,
    (extract(epoch FROM (now() - e.created_at))::int / 86400),
    e.verification_status::text -- round3791: col 7 returned enum verification_status but OUT column `status` is declared text (42804); explicit ::text cast is lossless and keeps the declared contract the web console reads
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.verification_status = 'pending'
  ORDER BY e.created_at ASC
  LIMIT 100;
END;
$function$;

-- founder_pending_refund_authorizations
CREATE OR REPLACE FUNCTION public.founder_pending_refund_authorizations(p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, source_kind text, source_id uuid, amount_rupees numeric, reason text, requested_by uuid, requester_email text, expires_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    r.id, r.source_kind, r.source_id, r.amount_rupees, r.reason,
    r.requested_by,
    -- round3791: cast to text — auth.users.email is character varying(255), so this
    -- coalesce resolved to varchar and mismatched declared column 7 (requester_email text),
    -- raising 42804 on every call. varchar->text is lossless.
    coalesce(u.email, 'unknown')::text,
    r.expires_at, r.created_at
  FROM public.refund_authorization_requests r
  LEFT JOIN auth.users u ON u.id = r.requested_by
  WHERE r.status = 'pending'
    AND r.expires_at > now()
  ORDER BY r.created_at ASC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$function$;

-- founder_pm_overdue_summary
CREATE OR REPLACE FUNCTION public.founder_pm_overdue_summary(p_limit integer DEFAULT 100)
 RETURNS TABLE(hospital_user_id uuid, hospital_email text, overdue_count integer, due_count integer, upcoming_count integer, oldest_overdue_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    s.hospital_user_id,
    -- round3791: cast to text — auth.users.email is character varying(255), so this coalesce
    -- yielded varchar and mismatched declared column 2 (text), raising SQLSTATE 42804. Lossless.
    coalesce((SELECT email FROM auth.users WHERE id = s.hospital_user_id), 'unknown')::text,
    count(*) FILTER (WHERE s.status = 'overdue')::int,
    count(*) FILTER (WHERE s.status = 'due')::int,
    count(*) FILTER (WHERE s.status = 'upcoming')::int,
    min(s.next_pm_due_at) FILTER (WHERE s.status = 'overdue')
  FROM public.equipment_pm_schedule s
  WHERE s.status IN ('overdue','due','upcoming')
  GROUP BY s.hospital_user_id
  HAVING count(*) FILTER (WHERE s.status IN ('overdue','due')) > 0
  ORDER BY count(*) FILTER (WHERE s.status = 'overdue') DESC, min(s.next_pm_due_at) ASC NULLS LAST
  LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$function$;

-- founder_pricing_by_tier_r2833
CREATE OR REPLACE FUNCTION public.founder_pricing_by_tier_r2833()
 RETURNS TABLE(tier_name text, revision_count bigint, latest_price integer, total_delta bigint, avg_churn numeric, avg_upsell numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.tier_name,
    count(*)::bigint,
    (SELECT new_price_rupees FROM pricing_tier_revisions_r2833 r2
       WHERE r2.tier_name = r.tier_name ORDER BY effective_date DESC LIMIT 1),
    COALESCE((SELECT sum(revenue_delta_rupees) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.tier_name = r.tier_name), 0)::bigint, -- round3791: sum(bigint) returns numeric -> 42804 vs declared bigint col 4; cast is exact, not a rounding (revenue_delta_rupees is bigint whole rupees, so there are no paise to lose)
    COALESCE((SELECT ROUND(AVG(churn_pct)::numeric, 2) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.tier_name = r.tier_name), 0),
    COALESCE((SELECT ROUND(AVG(upsell_pct)::numeric, 2) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.tier_name = r.tier_name), 0)
  FROM pricing_tier_revisions_r2833 r
  GROUP BY r.tier_name
  ORDER BY r.tier_name;
END;
$function$;

-- founder_referrals_cumulative
CREATE OR REPLACE FUNCTION public.founder_referrals_cumulative()
 RETURNS TABLE(month_ist date, referrals bigint, cum_referrals bigint, first_jobs bigint, cum_first_jobs bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.engineer_referrals r
                WHERE date_trunc('month', (r.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n,
      coalesce((SELECT count(*)::bigint FROM public.engineer_referrals r
                WHERE r.referee_first_completed_at IS NOT NULL
                  AND date_trunc('month', (r.referee_first_completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS f
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    -- round3791: col 3 cum_referrals — sum(bigint) returns numeric, declared bigint (42804). Running total of count(*), so bigint is the right contract; cast is lossless (integer summands).
    sum(monthly.n) OVER (ORDER BY monthly.month_ist)::bigint,
    monthly.f,
    -- round3791: col 5 cum_first_jobs — same sum(bigint)->numeric mismatch, NOT reported by the analyzer (it stops at the first). Also a running count, so cast to bigint.
    sum(monthly.f) OVER (ORDER BY monthly.month_ist)::bigint
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_repair_jobs_status
CREATE OR REPLACE FUNCTION public.founder_repair_jobs_status()
 RETURNS TABLE(status text, job_count bigint, share_pct numeric, oldest_days integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.repair_jobs;
  RETURN QUERY
  SELECT
    rj.status::text, -- round3791: rj.status is the job_status ENUM, declared OUT col 1 is text -> explicit ::text cast (lossless); GROUP BY/ORDER BY still compare the enum, so no bare-text operation is introduced on the enum
    count(*)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(count(*)::numeric / v_total::numeric * 100.0, 1)
    END,
    (extract(epoch FROM (now() - min(rj.created_at)))::int / 86400)
  FROM public.repair_jobs rj
  GROUP BY rj.status
  ORDER BY count(*) DESC;
END;
$function$;

-- founder_risk_score_snapshots_summary
CREATE OR REPLACE FUNCTION public.founder_risk_score_snapshots_summary()
 RETURNS TABLE(total_snapshots bigint, distinct_actors_scored bigint, engineer_snapshots bigint, hospital_snapshots bigint, admin_snapshots bigint, founder_snapshots bigint, latest_clean_actors bigint, latest_watch_actors bigint, latest_high_actors bigint, latest_critical_actors bigint, avg_latest_score numeric, median_latest_score numeric, max_latest_score integer, min_latest_score integer, alert_only_count bigint, founder_reviewed_count bigint, blocked_count bigint, cleared_count bigint, snapshots_today_ist bigint, snapshots_last_7d bigint, snapshots_last_30d bigint, newest_computed_at timestamp with time zone, oldest_computed_at timestamp with time zone, hours_since_last_snapshot numeric, high_or_critical_share_pct numeric, engineers_in_critical_band bigint, hospitals_in_critical_band bigint, band_transitions_7d bigint, worsened_actors_7d bigint, improved_actors_7d bigint, avg_disputed_jobs_signal numeric, avg_overdue_renewals_signal numeric, avg_suspicious_distance_signal numeric, top_score_email text, top_score_value integer, top_score_band text, top_score_role text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today_start_utc timestamptz := (date_trunc('day', (now() AT TIME ZONE 'Asia/Kolkata')) AT TIME ZONE 'Asia/Kolkata');
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.user_id) s.*
      FROM public.risk_score_snapshots s
     ORDER BY s.user_id, s.computed_at DESC
  ),
  prev_week AS (
    SELECT DISTINCT ON (s.user_id) s.user_id, s.band AS prev_band, s.score AS prev_score
      FROM public.risk_score_snapshots s
     WHERE s.computed_at < now() - interval '7 days'
     ORDER BY s.user_id, s.computed_at DESC
  ),
  totals AS (
    SELECT
      count(*)::bigint                              AS total_snapshots,
      count(DISTINCT user_id)::bigint               AS distinct_actors_scored,
      count(*) FILTER (WHERE role = 'engineer')::bigint AS engineer_snapshots,
      count(*) FILTER (WHERE role = 'hospital')::bigint AS hospital_snapshots,
      count(*) FILTER (WHERE role = 'admin')::bigint    AS admin_snapshots,
      count(*) FILTER (WHERE role = 'founder')::bigint  AS founder_snapshots,
      count(*) FILTER (WHERE computed_at >= v_today_start_utc)::bigint    AS snapshots_today_ist,
      count(*) FILTER (WHERE computed_at >= now() - interval '7 days')::bigint  AS snapshots_last_7d,
      count(*) FILTER (WHERE computed_at >= now() - interval '30 days')::bigint AS snapshots_last_30d,
      count(*) FILTER (WHERE action_taken = 'alert_only')::bigint        AS alert_only_count,
      count(*) FILTER (WHERE action_taken = 'founder_reviewed')::bigint  AS founder_reviewed_count,
      count(*) FILTER (WHERE action_taken = 'blocked')::bigint           AS blocked_count,
      count(*) FILTER (WHERE action_taken = 'cleared')::bigint           AS cleared_count,
      max(computed_at)                              AS newest_computed_at,
      min(computed_at)                              AS oldest_computed_at
    FROM public.risk_score_snapshots
  ),
  latest_stats AS (
    SELECT
      count(*) FILTER (WHERE band = 'clean')::bigint    AS latest_clean_actors,
      count(*) FILTER (WHERE band = 'watch')::bigint    AS latest_watch_actors,
      count(*) FILTER (WHERE band = 'high')::bigint     AS latest_high_actors,
      count(*) FILTER (WHERE band = 'critical')::bigint AS latest_critical_actors,
      count(*) FILTER (WHERE band = 'critical' AND role = 'engineer')::bigint AS engineers_in_critical_band,
      count(*) FILTER (WHERE band = 'critical' AND role = 'hospital')::bigint AS hospitals_in_critical_band,
      avg(score)::numeric                                 AS avg_latest_score,
      percentile_cont(0.5) WITHIN GROUP (ORDER BY score)::numeric AS median_latest_score,
      coalesce(max(score), 0)                             AS max_latest_score,
      coalesce(min(score), 0)                             AS min_latest_score,
      count(*) FILTER (WHERE band IN ('high','critical'))::bigint AS hi_or_crit,
      count(*)::bigint                                    AS total_actors,
      avg(coalesce((signal_breakdown->>'disputed_jobs')::numeric, 0))::numeric           AS avg_disputed_jobs_signal,
      avg(coalesce((signal_breakdown->>'overdue_renewals')::numeric, 0))::numeric        AS avg_overdue_renewals_signal,
      avg(coalesce((signal_breakdown->>'suspicious_distance_events')::numeric, 0))::numeric AS avg_suspicious_distance_signal
    FROM latest
  ),
  transitions AS (
    SELECT
      count(*) FILTER (WHERE l.band <> pw.prev_band)::bigint AS band_transitions_7d,
      count(*) FILTER (WHERE l.score > pw.prev_score)::bigint AS worsened_actors_7d,
      count(*) FILTER (WHERE l.score < pw.prev_score)::bigint AS improved_actors_7d
    FROM latest l
    JOIN prev_week pw ON pw.user_id = l.user_id
  ),
  top_actor AS (
    SELECT
      -- round3791: auth.users.email is character varying(255); cast to text to match declared OUT column 34 (top_score_email text). Lossless.
      coalesce((SELECT u.email FROM auth.users u WHERE u.id = l.user_id), 'unknown')::text AS top_score_email,
      l.score AS top_score_value,
      l.band  AS top_score_band,
      l.role  AS top_score_role
    FROM latest l
    ORDER BY l.score DESC, l.computed_at DESC
    LIMIT 1
  )
  SELECT
    t.total_snapshots,
    t.distinct_actors_scored,
    t.engineer_snapshots,
    t.hospital_snapshots,
    t.admin_snapshots,
    t.founder_snapshots,
    ls.latest_clean_actors,
    ls.latest_watch_actors,
    ls.latest_high_actors,
    ls.latest_critical_actors,
    round(coalesce(ls.avg_latest_score, 0), 2)    AS avg_latest_score,
    round(coalesce(ls.median_latest_score, 0), 2) AS median_latest_score,
    ls.max_latest_score,
    ls.min_latest_score,
    t.alert_only_count,
    t.founder_reviewed_count,
    t.blocked_count,
    t.cleared_count,
    t.snapshots_today_ist,
    t.snapshots_last_7d,
    t.snapshots_last_30d,
    t.newest_computed_at,
    t.oldest_computed_at,
    CASE
      WHEN t.newest_computed_at IS NULL THEN NULL::numeric
      ELSE round(extract(epoch FROM (now() - t.newest_computed_at)) / 3600.0, 2)
    END AS hours_since_last_snapshot,
    CASE
      WHEN ls.total_actors = 0 THEN 0::numeric
      ELSE round((ls.hi_or_crit::numeric / ls.total_actors::numeric) * 100.0, 2)
    END AS high_or_critical_share_pct,
    ls.engineers_in_critical_band,
    ls.hospitals_in_critical_band,
    coalesce(tr.band_transitions_7d, 0)  AS band_transitions_7d,
    coalesce(tr.worsened_actors_7d, 0)   AS worsened_actors_7d,
    coalesce(tr.improved_actors_7d, 0)   AS improved_actors_7d,
    round(coalesce(ls.avg_disputed_jobs_signal, 0), 2)       AS avg_disputed_jobs_signal,
    round(coalesce(ls.avg_overdue_renewals_signal, 0), 2)    AS avg_overdue_renewals_signal,
    round(coalesce(ls.avg_suspicious_distance_signal, 0), 2) AS avg_suspicious_distance_signal,
    ta.top_score_email,
    ta.top_score_value,
    ta.top_score_band,
    ta.top_score_role
  FROM totals t
  CROSS JOIN latest_stats ls
  LEFT JOIN transitions tr ON TRUE
  LEFT JOIN top_actor ta ON TRUE;
END;
$function$;

-- founder_risk_top_n
CREATE OR REPLACE FUNCTION public.founder_risk_top_n(p_role text DEFAULT NULL::text, p_band text DEFAULT NULL::text, p_limit integer DEFAULT 50)
 RETURNS TABLE(user_id uuid, email text, role text, score integer, band text, signal_breakdown jsonb, computed_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.user_id) s.*
      FROM public.risk_score_snapshots s
     ORDER BY s.user_id, s.computed_at DESC
  )
  SELECT l.user_id,
         coalesce((SELECT email FROM auth.users WHERE id = l.user_id), 'unknown')::text AS email, -- round3791: auth.users.email is character varying(255), so the coalesce yielded varchar and broke OUT column 2 (declared text); ::text is a lossless widening cast
         l.role, l.score, l.band, l.signal_breakdown, l.computed_at
    FROM latest l
   WHERE (p_role IS NULL OR l.role = p_role)
     AND (p_band IS NULL OR l.band = p_band)
   ORDER BY l.score DESC, l.computed_at DESC
   LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$function$;

-- founder_signups_cumulative
CREATE OR REPLACE FUNCTION public.founder_signups_cumulative()
 RETURNS TABLE(month_ist date, new_users bigint, cumulative bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM auth.users u
                WHERE date_trunc('month', (u.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    -- round3791: sum(bigint) returns numeric but col 3 `cumulative` is declared bigint (42804). It is a running tally of count(*) signups, not money/rate/avg, so bigint is the correct contract -- cast the query column (values are integral, no precision lost).
    (sum(monthly.n) OVER (ORDER BY monthly.month_ist))::bigint
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_site_visit_recent_completed
CREATE OR REPLACE FUNCTION public.founder_site_visit_recent_completed(p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, hospital_org_id uuid, hospital_name text, visitor_email text, visitor_role text, purpose text, visited_at timestamp with time zone, outcome_kind text, arr_impact_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_org_id, o.name, u.email::text, v.visitor_role, -- round3791: col 4 auth.users.email is character varying(255) but visitor_email is declared text -> ::text (lossless); this was the 42804 mismatch
         v.purpose, v.visited_at,
         (SELECT outcome_kind FROM hospital_site_visit_outcomes x WHERE x.visit_id=v.id ORDER BY recorded_at DESC LIMIT 1),
         (SELECT coalesce(arr_impact_rupees,0) FROM hospital_site_visit_outcomes x WHERE x.visit_id=v.id ORDER BY recorded_at DESC LIMIT 1)
  FROM hospital_site_visits v
  JOIN organizations o ON o.id=v.hospital_org_id
  LEFT JOIN auth.users u ON u.id=v.visitor_user_id
  WHERE v.status='completed'
  ORDER BY v.visited_at DESC NULLS LAST
  LIMIT p_limit;
END;$function$;

-- founder_site_visit_upcoming
CREATE OR REPLACE FUNCTION public.founder_site_visit_upcoming(p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, hospital_org_id uuid, hospital_name text, visitor_user_id uuid, visitor_email text, visitor_role text, purpose text, scheduled_at timestamp with time zone, status text, days_until integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_org_id, o.name, v.visitor_user_id, u.email::text, -- round3791: auth.users.email is character varying(255); cast to text to match declared visitor_email text (col 5, the 42804 offender)
         v.visitor_role, v.purpose, v.scheduled_at, v.status,
         GREATEST(0, EXTRACT(DAY FROM v.scheduled_at - now())::int)
  FROM hospital_site_visits v
  JOIN organizations o ON o.id=v.hospital_org_id
  LEFT JOIN auth.users u ON u.id=v.visitor_user_id
  WHERE v.status='scheduled' AND v.scheduled_at >= now()
  ORDER BY v.scheduled_at ASC
  LIMIT p_limit;
END;$function$;

-- founder_spot_audits_cumulative
CREATE OR REPLACE FUNCTION public.founder_spot_audits_cumulative()
 RETURNS TABLE(month_ist date, invitations bigint, cum_inv bigint, responses bigint, cum_resp bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.spot_audit_invitations i
                WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS i,
      coalesce((SELECT count(*)::bigint FROM public.spot_audit_responses r
                WHERE date_trunc('month', (r.responded_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS r
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.i,
    (sum(monthly.i) OVER (ORDER BY monthly.month_ist))::bigint, -- round3791: sum(bigint) returns numeric (was col 3 of the 42804); cum_inv is a running COUNT of invitations, so bigint is the correct contract -> cast, no precision to lose
    monthly.r,
    (sum(monthly.r) OVER (ORDER BY monthly.month_ist))::bigint -- round3791: same numeric-vs-bigint mismatch in col 5 (analyzer stopped at col 3); cum_resp is a running COUNT of responses, so cast to bigint
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_supervised_cumulative
CREATE OR REPLACE FUNCTION public.founder_supervised_cumulative()
 RETURNS TABLE(month_ist date, assigned bigint, cum_assigned bigint, successful bigint, cum_successful bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
                WHERE date_trunc('month', (s.requested_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS a,
      coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
                WHERE s.status = 'completed_successful' AND s.completed_at IS NOT NULL
                  AND date_trunc('month', (s.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS sc
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.a,
    -- round3791: sum(bigint) returns numeric -> col 3 (cum_assigned) mismatched declared bigint (the reported 42804); it is a running COUNT of assignments, so bigint is the right contract and the cast is exact (sum of integers is integral).
    (sum(monthly.a) OVER (ORDER BY monthly.month_ist))::bigint,
    monthly.sc,
    -- round3791: same defect one column later -- sum(bigint) returns numeric, so col 5 (cum_successful) would have failed on the next call once col 3 was fixed; also a running COUNT, so cast to bigint.
    (sum(monthly.sc) OVER (ORDER BY monthly.month_ist))::bigint
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_suspicious_attendance_recent
CREATE OR REPLACE FUNCTION public.founder_suspicious_attendance_recent(p_days integer DEFAULT 30, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, repair_job_id uuid, engineer_user_id uuid, engineer_email text, event_kind text, device_captured_at timestamp with time zone, distance_from_hospital_m double precision, engineer_lat double precision, engineer_lng double precision)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT a.id, a.repair_job_id, a.engineer_user_id,
         -- round3791: auth.users.email is character varying(255), so this coalesce yields varchar and broke column 4 (declared text) with SQLSTATE 42804; ::text is a lossless cast.
         coalesce((SELECT email FROM auth.users WHERE id = a.engineer_user_id), 'unknown')::text,
         a.event_kind, a.device_captured_at,
         a.distance_from_hospital_m, a.engineer_lat, a.engineer_lng
    FROM public.engineer_attendance a
   WHERE a.suspicious_distance = true
     AND a.created_at >= now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval
   ORDER BY a.created_at DESC
   LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$function$;

-- founder_tds_quarterly_summary
CREATE OR REPLACE FUNCTION public.founder_tds_quarterly_summary(p_fiscal_year text, p_fy_quarter text)
 RETURNS TABLE(engineer_user_id uuid, engineer_email text, total_gross_rupees numeric, total_tds_rupees numeric, deduction_count bigint, any_undeposited boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT t.engineer_user_id,
         -- round3791: cast to text — auth.users.email is character varying(255), so the
         -- coalesce resolved to varchar and mismatched declared text in column 2 (42804).
         coalesce(u.email, 'unknown')::text AS engineer_email,
         sum(t.gross_rupees)::numeric,
         sum(t.tds_rupees)::numeric,
         count(*) FILTER (WHERE t.deducted)::bigint,
         bool_or(t.deducted AND t.deposited_to_govt_at IS NULL)
    FROM public.tds_deductions t
    LEFT JOIN auth.users u ON u.id = t.engineer_user_id
   WHERE t.fiscal_year = p_fiscal_year
     AND t.fy_quarter   = p_fy_quarter
   GROUP BY t.engineer_user_id, u.email
   ORDER BY sum(t.tds_rupees) DESC NULLS LAST;
END;
$function$;

-- founder_tier_changes_cumulative
CREATE OR REPLACE FUNCTION public.founder_tier_changes_cumulative()
 RETURNS TABLE(month_ist date, promotions bigint, cum_promotions bigint, demotions bigint, cum_demotions bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  ranks AS (
    SELECT h.changed_at,
      CASE WHEN
        CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
        > CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
      THEN 1 ELSE 0 END AS is_promo,
      CASE WHEN
        CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
        < CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
      THEN 1 ELSE 0 END AS is_demo
    FROM public.engineer_tier_history h
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce(sum(r.is_promo) FILTER (WHERE date_trunc('month', (r.changed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint AS p,
      coalesce(sum(r.is_demo) FILTER (WHERE date_trunc('month', (r.changed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint AS d
    FROM months m LEFT JOIN ranks r ON TRUE
    GROUP BY m.month_ist
  )
  SELECT
    monthly.month_ist,
    monthly.p,
    (sum(monthly.p) OVER (ORDER BY monthly.month_ist))::bigint, -- round3791: col 3 cum_promotions — sum(bigint) yields numeric, mismatching declared bigint (the reported 42804); it is a running COUNT of promotions, so bigint is the right contract and the cast is exact
    monthly.d,
    (sum(monthly.d) OVER (ORDER BY monthly.month_ist))::bigint -- round3791: col 5 cum_demotions — same numeric-vs-bigint mismatch, unreported because the analyzer stops at the first one; also a running COUNT, so cast to bigint
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- founder_unmatched_jobs_7d
CREATE OR REPLACE FUNCTION public.founder_unmatched_jobs_7d()
 RETURNS TABLE(job_id uuid, job_number text, hospital_user_id uuid, hospital_name text, created_at timestamp with time zone, days_open integer, status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    rj.id,
    rj.job_number,
    rj.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    rj.created_at,
    (extract(epoch FROM (now() - rj.created_at))::int / 86400),
    -- round3791: cast the job_status ENUM to text. OUT column 7 is declared
    -- `text`, but rj.status is the job_status enum and RETURN QUERY matches by
    -- position with exact type-OID equality (an enum is not binary-coercible
    -- to text) — so every call raised 42804 "structure of query does not match
    -- function result type" and the /unmatched-jobs page has never rendered.
    -- Lossless. The WHERE clause below deliberately keeps comparing the ENUM
    -- to its own label ('requested' is a real job_status value), so no bare
    -- text operation is introduced on the enum anywhere else.
    rj.status::text
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.created_at < now() - interval '7 days'
    AND rj.status = 'requested'
    AND NOT EXISTS (
      SELECT 1 FROM public.repair_job_bids b
      WHERE b.repair_job_id = rj.id AND b.status = 'accepted'
    )
  ORDER BY rj.created_at ASC
  LIMIT 100;
END;
$function$;

-- founder_verified_engineer_growth
CREATE OR REPLACE FUNCTION public.founder_verified_engineer_growth()
 RETURNS TABLE(month_ist date, new_verified bigint, cumulative bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.engineers e
                WHERE e.verification_status = 'verified'
                  AND date_trunc('month', (e.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint AS new_verified
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.new_verified,
    -- round3791: sum(bigint) returns numeric in PostgreSQL, which broke the declared bigint contract (42804).
    -- round3791: `cumulative` is a running tally of counted engineers (new_verified is count(*)), not money/rate/avg,
    -- round3791: so bigint is the correct contract and the ::bigint cast is lossless -- cast the query, not the declaration.
    (sum(monthly.new_verified) OVER (ORDER BY monthly.month_ist))::bigint AS cumulative
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$
;

-- founder_voice_inbox_r2362
CREATE OR REPLACE FUNCTION public.founder_voice_inbox_r2362()
 RETURNS TABLE(id uuid, title text, category text, pain_score integer, frequency text, engineer_email text, upvotes bigint, submitted_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.title, s.category, s.pain_score, s.frequency,
         (SELECT au.email FROM auth.users au WHERE au.id = s.engineer_id)::text, -- round3791: auth.users.email is character varying(255); cast to text to match declared OUT column 6 engineer_email text (lossless)
         (SELECT COUNT(*) FROM public.engineer_voice_upvotes_r2362 u WHERE u.suggestion_id = s.id),
         s.submitted_at
  FROM public.engineer_voice_suggestions_r2362 s
  WHERE s.triage_state = 'new'
  ORDER BY s.pain_score DESC, s.submitted_at ASC
  LIMIT 200;
END; $function$;

-- founder_voice_top_voters_r2362
CREATE OR REPLACE FUNCTION public.founder_voice_top_voters_r2362()
 RETURNS TABLE(engineer_email text, submissions bigint, votes_cast bigint, shipped_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (SELECT au.email FROM auth.users au WHERE au.id = p.id)::text, -- round3791: auth.users.email is character varying(255); cast to text to match declared engineer_email text (lossless)
         (SELECT COUNT(*) FROM public.engineer_voice_suggestions_r2362 s WHERE s.engineer_id = p.id)::bigint,
         (SELECT COUNT(*) FROM public.engineer_voice_upvotes_r2362 u WHERE u.voter_id = p.id)::bigint,
         (SELECT COUNT(*) FROM public.engineer_voice_suggestions_r2362 s WHERE s.engineer_id = p.id AND s.triage_state = 'shipped')::bigint
  FROM public.profiles p
  WHERE p.role = 'engineer'
    AND (EXISTS (SELECT 1 FROM public.engineer_voice_suggestions_r2362 s WHERE s.engineer_id = p.id)
      OR EXISTS (SELECT 1 FROM public.engineer_voice_upvotes_r2362 u WHERE u.voter_id = p.id))
  ORDER BY 2 DESC, 3 DESC
  LIMIT 25;
END; $function$;

-- founder_wellbeing_engineer_trend
CREATE OR REPLACE FUNCTION public.founder_wellbeing_engineer_trend()
 RETURNS TABLE(engineer_user_id uuid, engineer_email text, responses_count bigint, avg_composite numeric, latest_composite numeric, latest_burnout integer, latest_joy integer, red_flag_count bigint, last_submitted_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT r.engineer_user_id,
           count(*) AS rc,
           round(avg(r.composite_score)::numeric, 2) AS avg_c,
           count(*) FILTER (WHERE r.is_red_flag) AS red_c,
           max(r.submitted_at) AS last_at
    FROM engineer_wellbeing_responses r
    WHERE r.submitted_at >= now() - interval '90 days'
    GROUP BY r.engineer_user_id
  ),
  latest AS (
    SELECT DISTINCT ON (r.engineer_user_id)
           r.engineer_user_id, r.composite_score, r.burnout_risk, r.joy_score
    FROM engineer_wellbeing_responses r
    ORDER BY r.engineer_user_id, r.submitted_at DESC
  )
  SELECT a.engineer_user_id,
         (SELECT u.email::text FROM auth.users u WHERE u.id = a.engineer_user_id), -- round3791: auth.users.email is character varying(255) but OUT column 2 engineer_email is declared text -> lossless ::text cast fixes SQLSTATE 42804
         a.rc, a.avg_c,
         l.composite_score, l.burnout_risk, l.joy_score,
         a.red_c, a.last_at
  FROM agg a
  LEFT JOIN latest l ON l.engineer_user_id = a.engineer_user_id
  ORDER BY a.avg_c ASC NULLS LAST
  LIMIT 100;
END;
$function$;

-- founder_wellbeing_recent_responses
CREATE OR REPLACE FUNCTION public.founder_wellbeing_recent_responses()
 RETURNS TABLE(id uuid, cycle_label text, engineer_email text, workload_score integer, support_score integer, growth_score integer, burnout_risk integer, joy_score integer, composite_score numeric, is_red_flag boolean, submitted_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, c.cycle_label,
         -- round3791: cast auth.users.email (character varying(255)) to text — OUT column 3 engineer_email is declared text, so the bare varchar raised 42804 on every call. Lossless widening; declaration left alone because text is the correct contract for an email the web console reads as a string.
         (SELECT u.email FROM auth.users u WHERE u.id = r.engineer_user_id)::text,
         r.workload_score, r.support_score, r.growth_score, r.burnout_risk, r.joy_score,
         r.composite_score, r.is_red_flag, r.submitted_at
  FROM engineer_wellbeing_responses r
  JOIN engineer_wellbeing_cycles c ON c.id = r.cycle_id
  ORDER BY r.submitted_at DESC
  LIMIT 100;
END;
$function$;

-- founder_wellbeing_red_flags
CREATE OR REPLACE FUNCTION public.founder_wellbeing_red_flags()
 RETURNS TABLE(id uuid, cycle_label text, engineer_user_id uuid, engineer_email text, burnout_risk integer, joy_score integer, workload_score integer, support_score integer, growth_score integer, composite_score numeric, free_text text, reviewed_at timestamp with time zone, submitted_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, c.cycle_label, r.engineer_user_id,
         (SELECT u.email::text FROM auth.users u WHERE u.id = r.engineer_user_id), -- round3791: auth.users.email is varchar(255), not text; ::text makes OUT col 4 engineer_email match (lossless, no truncation)
         r.burnout_risk, r.joy_score, r.workload_score, r.support_score, r.growth_score,
         r.composite_score, r.free_text, r.reviewed_at, r.submitted_at
  FROM engineer_wellbeing_responses r
  JOIN engineer_wellbeing_cycles c ON c.id = r.cycle_id
  WHERE r.is_red_flag
  ORDER BY r.reviewed_at IS NULL DESC, r.submitted_at DESC
  LIMIT 100;
END;
$function$;

-- r1693_vesting_summary
CREATE OR REPLACE FUNCTION public.r1693_vesting_summary()
 RETURNS TABLE(total_schedules integer, active_schedules integer, paused_schedules integer, completed_schedules integer, total_shares_committed bigint, total_shares_vested bigint, total_shares_exercised bigint, total_tranches integer, exercised_tranches integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT (COUNT(*))::int FROM public.investor_vesting_schedules_r1693) AS total_schedules,
    (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.investor_vesting_schedules_r1693) AS active_schedules,
    (SELECT (COUNT(*) FILTER (WHERE status = 'paused'))::int FROM public.investor_vesting_schedules_r1693) AS paused_schedules,
    (SELECT (COUNT(*) FILTER (WHERE status = 'completed'))::int FROM public.investor_vesting_schedules_r1693) AS completed_schedules,
    -- round3791: added ::bigint — SUM(total_shares) over a bigint column returns numeric, mismatching declared bigint (42804, col 5). Whole-share tally, not money, so the bigint contract is right and the cast is lossless.
    COALESCE((SELECT SUM(total_shares) FROM public.investor_vesting_schedules_r1693), 0)::bigint AS total_shares_committed,
    -- round3791: added ::bigint — SUM(shares_vested) over a bigint column returns numeric, mismatching declared bigint (col 6). Whole-share tally, not money; cast is lossless.
    COALESCE((SELECT SUM(shares_vested) FROM public.investor_vesting_tranches_r1693 WHERE tranche_month <= CURRENT_DATE), 0)::bigint AS total_shares_vested,
    -- round3791: added ::bigint — SUM(shares_vested) over a bigint column returns numeric, mismatching declared bigint (col 7). Whole-share tally, not money; cast is lossless.
    COALESCE((SELECT SUM(shares_vested) FROM public.investor_vesting_tranches_r1693 WHERE exercised = true), 0)::bigint AS total_shares_exercised,
    (SELECT (COUNT(*))::int FROM public.investor_vesting_tranches_r1693) AS total_tranches,
    (SELECT (COUNT(*) FILTER (WHERE exercised = true))::int FROM public.investor_vesting_tranches_r1693) AS exercised_tranches;
END;
$function$;

-- sla_breach_summary_r2352
CREATE OR REPLACE FUNCTION public.sla_breach_summary_r2352()
 RETURNS TABLE(severity text, total_tickets integer, resolved_in_sla integer, resolved_breached integer, open_breached integer, median_response_minutes numeric, median_resolution_minutes numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.severity,
    COUNT(*)::int AS total_tickets,
    COUNT(*) FILTER (
      WHERE t.resolved_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0 <= t.sla_minutes
    )::int AS resolved_in_sla,
    COUNT(*) FILTER (
      WHERE t.resolved_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0 > t.sla_minutes
    )::int AS resolved_breached,
    COUNT(*) FILTER (
      WHERE t.resolved_at IS NULL
        AND EXTRACT(EPOCH FROM (now() - t.opened_at)) / 60.0 > t.sla_minutes
    )::int AS open_breached,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY
      CASE WHEN t.first_response_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.first_response_at - t.opened_at)) / 60.0
      END
    -- round3791: col 6 -- percentile_cont has no numeric variant, so it returns double precision; cast to the declared numeric to clear 42804
    )::numeric AS median_response_minutes,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY
      CASE WHEN t.resolved_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0
      END
    -- round3791: col 7 -- same double precision return as col 6 (would fail on the next call); cast to the declared numeric
    )::numeric AS median_resolution_minutes
  FROM public.escalated_tickets_r2352 t
  GROUP BY t.severity
  ORDER BY t.severity;
END;
$function$;

-- =====================================================================
-- PATH 2 -- declared TYPE changes (DROP + CREATE + ACL replay)
-- =====================================================================
--
-- brand_equity_pulse_kpis_r2781
--   was: RETURNS table(segment_count bigint, campaign_count bigint, avg_aided_awareness numeric, avg_unaided_awareness numeric, avg_consideration numeric, avg_preference numeric, avg_nps numeric, avg_nps_delta numeric, total_spend_rupees bigint, avg_qoq_shift numeric, surging_segments bigint, weak_segments bigint)
--   now: RETURNS table(segment_count bigint, campaign_count bigint, avg_aided_awareness numeric, avg_unaided_awareness numeric, avg_consideration numeric, avg_preference numeric, avg_nps numeric, avg_nps_delta numeric, total_spend_rupees numeric, avg_qoq_shift numeric, surging_segments bigint, weak_segments bigint) -- round3791: col 9 total_spend_rupees bigint -> numeric; sum(spend_rupees) returns numeric (sum of bigint is numeric in pg) and this is money, so widen the declaration rather than cast the query -- a ::bigint cast on a founder financial report would silently truncate any fractional rupee. all other 11 columns verified position-by-position against the query and already match.
--
-- founder_biomed_by_hospital_r2235
--   was: RETURNS table(hospital text, total_staff integer, active integer, departed_90d integer, max_risk integer, amc_at_risk bigint)
--   now: RETURNS table(hospital text, total_staff integer, active integer, departed_90d integer, max_risk integer, amc_at_risk numeric) -- round3791: amc_at_risk widened bigint->numeric; it is money (sum of amc_value_rupees) and sum(bigint) yields numeric, so casting to bigint would round a founder financial report instead of reporting it exactly
--
-- founder_biomed_departure_reasons_r2235
--   was: RETURNS table(reason text, count integer, total_exposure bigint)
--   now: RETURNS numeric (sum of a bigint money column) -> 42804. this is money, not a tally, so the declaration is widened to numeric rather than casting the query to bigint, which would silently truncate rupee precision on a founder financial report. cols 1 (reason -> text) and 2 (count(*)::int -> integer) already match. returns table(reason text, count integer, total_exposure numeric)
--
-- founder_hospital_xsell_by_product
--   was: RETURNS table(product_slug text, total_rows bigint, won_rows bigint, pipeline_rupees bigint, avg_fit numeric, open_queue bigint)
--   now: RETURNS table(product_slug text, total_rows bigint, won_rows bigint, -- round3791: pipeline_rupees was declared bigint but the query returns numeric -- (sum(est_value_rupees) over a bigint column yields numeric) -> 42804 on every call. -- widened the declaration to numeric instead of casting the query: this is a money -- column on a founder financial report (rendered via fmtinr in the web console), so -- ::bigint would silently round away sub-rupee precision. matches the precedent set -- by round1422's weighted_pipeline_rupees numeric. pipeline_rupees numeric, avg_fit numeric, open_queue bigint)
--
-- founder_hospital_xsell_overview
--   was: RETURNS table(total_amc_hospitals bigint, hospitals_with_ladder bigint, total_ladder_rows bigint, suggested_rows bigint, pitched_rows bigint, interested_rows bigint, negotiating_rows bigint, won_rows bigint, lost_rows bigint, parked_rows bigint, total_pipeline_rupees bigint, won_pipeline_rupees bigint, open_queue_items bigint, overdue_queue_items bigint, urgent_queue_items bigint, avg_fit_score numeric)
--   now: RETURNS numeric, and this is money on a founder financial report, so casting to bigint would silently round reported pipeline value instead of reporting it exactly. -- round3791: won_pipeline_rupees declared type widened bigint -> numeric. same defect, same reason (money, not a tally) -- the analyzer stopped at column 11 and never reached this one. returns table(total_amc_hospitals bigint, hospitals_with_ladder bigint, total_ladder_rows bigint, suggested_rows bigint, pitched_rows bigint, interested_rows bigint, negotiating_rows bigint, won_rows bigint, lost_rows bigint, parked_rows bigint, total_pipeline_rupees numeric, won_pipeline_rupees numeric, open_queue_items bigint, overdue_queue_items bigint, urgent_queue_items bigint, avg_fit_score numeric)
--
-- founder_hospital_xsell_top_hospitals
--   was: RETURNS table(hospital_org_id uuid, hospital_name text, ladder_rows bigint, won_rows bigint, pipeline_rupees bigint, open_queue bigint, avg_fit numeric)
--   now: RETURNS table(hospital_org_id uuid, hospital_name text, ladder_rows bigint, won_rows bigint, pipeline_rupees numeric, open_queue bigint, avg_fit numeric) -- round3791: pipeline_rupees widened bigint->numeric. sum(l.est_value_rupees) over a bigint column returns numeric, which is the 42804. pipeline_rupees is money on a founder financial report, so the declared contract is widened rather than the query cast to ::bigint (a cast would silently truncate paise if est_value_rupees is ever made numeric, and would hard-error on bigint overflow for a large aggregate). column names/order and every other declared type are unchanged.
--
-- founder_hpbi_pipeline_by_status
--   was: RETURNS table(our_submission_status text, tender_count integer, total_estimated_rupees bigint, total_our_bid_rupees bigint, avg_win_probability integer)
--   now: RETURNS table(our_submission_status text, tender_count integer, total_estimated_rupees numeric, total_our_bid_rupees numeric, avg_win_probability integer) -- round3791: cols 3 total_estimated_rupees + 4 total_our_bid_rupees widened bigint->numeric, because sum() over these columns yields numeric (42804); both are rupee money totals on a founder financial report, so casting them back to bigint would silently drop precision instead
--
-- founder_lost_deal_kpis_v2
--   was: RETURNS table(total_lost_30d bigint, total_lost_value_30d_rupees bigint, total_lost_90d bigint, total_lost_value_90d_rupees bigint, avg_deal_value_rupees bigint, pct_could_have_won numeric, recovery_rate_pct numeric, competitor_count integer, top_competitor text, open_actions bigint)
--   now: RETURNS table line below (the 42804 fix). -- round3791: col 2 total_lost_value_30d_rupees and col 4 total_lost_value_90d_rupees -- round3791: both are coalesce(sum(deal_value_rupees),0); deal_value_rupees is bigint, and sum(bigint) is -- round3791: numeric in postgresql, so the declared bigint mismatched and raised 42804 on every call. -- round3791: these are money totals on a founder financial report, so the declaration is widened rather than -- round3791: the query cast to bigint: widening is lossless, whereas ::bigint would silently round away -- round3791: sub-rupee precision (and could overflow on a large enough sum). column names/order unchanged. returns table(total_lost_30d bigint, total_lost_value_30d_rupees numeric, total_lost_90d bigint, total_lost_value_90d_rupees numeric, avg_deal_value_rupees bigint, pct_could_have_won numeric, recovery_rate_pct numeric, competitor_count integer, top_competitor text, open_actions bigint)
--
-- founder_peer_stage_distribution
--   was: RETURNS table(id uuid, fundraise_stage text, peer_count bigint, total_raised_rupees bigint, avg_hospital_count numeric, avg_engineer_count numeric)
--   now: RETURNS table(id uuid, fundraise_stage text, peer_count bigint, total_raised_rupees numeric, avg_hospital_count numeric, avg_engineer_count numeric) -- round3791: widened total_raised_rupees bigint->numeric (col 4); sum() of bigint returns numeric and this is a money column, so casting to bigint would round/overflow founder-reported capital raised
--
-- founder_podcast_pipeline_summary
--   was: RETURNS table(total_targets bigint, identified bigint, pitched bigint, responded bigint, scheduled bigint, recorded bigint, published bigint, rejected bigint, ghosted bigint, avg_fit_score numeric, total_audience bigint, recorded_audience bigint, response_rate_pct numeric, recorded_rate_pct numeric, pipeline_value_rupees bigint, closed_revenue_rupees bigint)
--   now: RETURNS table(total_targets bigint, identified bigint, pitched bigint, responded bigint, scheduled bigint, recorded bigint, published bigint, rejected bigint, ghosted bigint, avg_fit_score numeric, total_audience bigint, recorded_audience bigint, response_rate_pct numeric, recorded_rate_pct numeric, pipeline_value_rupees numeric, closed_revenue_rupees numeric) -- round3791: widened pipeline_value_rupees (col 15) and closed_revenue_rupees (col 16) from bigint to numeric: sum(bigint) returns numeric, and these are money on a founder financial report, so casting to bigint would silently round revenue instead of reporting it exactly
--
-- founder_pricing_by_quarter_r2833
--   was: RETURNS table(quarter text, revision_count bigint, avg_pct_change numeric, total_delta bigint, wins bigint, losses bigint)
--   now: RETURNS table(quarter text, revision_count bigint, avg_pct_change numeric, total_delta numeric, wins bigint, losses bigint)
--
-- founder_pricing_kpi_summary_r2833
--   was: RETURNS table(total_revisions bigint, live_revisions bigint, proposed_revisions bigint, rolled_back bigint, total_revenue_delta bigint, avg_pct_change numeric)
--   now: RETURNS table(total_revisions bigint, live_revisions bigint, proposed_revisions bigint, rolled_back bigint, total_revenue_delta numeric, avg_pct_change numeric) -- round3791: total_revenue_delta bigint -> numeric; sum(revenue_delta_rupees) is numeric and this is money on a founder financial report, so widen the declared type instead of casting (a ::bigint cast would silently round reported revenue)
--
-- founder_r2819_kpis
--   was: RETURNS table(total_centers integer, avg_uptime_pct numeric, critical_centers integer, total_revenue_loss_rupees bigint, total_downtime_hours numeric, open_interventions integer, projected_recovery_rupees bigint)
--   now: RETURNS numeric; these are rupee amounts on a founder financial report, so casting the query to ::bigint would silently round away precision. widening the declaration is lossless. all other 5 columns verified position-by-position and already match. returns table(total_centers integer, avg_uptime_pct numeric, critical_centers integer, total_revenue_loss_rupees numeric, total_downtime_hours numeric, open_interventions integer, projected_recovery_rupees numeric)
--
-- founder_r2971_spend_forecast
--   was: RETURNS table(chain_name text, open_signals integer, projected_rupees bigint, max_lead_days integer)
--   now: RETURNS table(chain_name text, open_signals integer, projected_rupees numeric, max_lead_days integer) -- round3791: col 3 projected_rupees declared bigint -> numeric. sum(bigint*bigint) returns numeric; this column is money (projected rupee spend on a founder financial report), so widening the declaration is correct and lossless -- casting the sum to bigint would bake a rounding step into a revenue/spend figure. cols 1/2/4 verified type-exact (chain_name is text in ot_bulb_reorder_signals_r2971; count(*)::int and coalesce(max(...),0)::int are integer), so nothing else changed.
--
-- founder_r2971_vendor_concentration
--   was: RETURNS table(vendor_name text, skus integer, open_signals integer, total_rupees bigint)
--   now: RETURNS numeric (the 42804). -- round3791: total_rupees is money on a founder financial report, so the declaration is the wrong half: -- round3791: sum()::bigint would round away paise and can overflow bigint; numeric is lossless + unbounded. -- round3791: cols 1-3 (text / ::int / ::int) checked position-by-position, already match. names + order unchanged. returns table(vendor_name text, skus integer, open_signals integer, total_rupees numeric)
--
-- founder_site_visit_outcomes_by_kind
--   was: RETURNS table(outcome_kind text, n bigint, arr_total_rupees bigint, last_recorded_at timestamp with time zone)
--   now: RETURNS table(outcome_kind text, n bigint, arr_total_rupees numeric, last_recorded_at timestamp with time zone) -- round3791: arr_total_rupees bigint -> numeric; sum(arr_impact_rupees) over a bigint column yields numeric, and this is money on a founder financial report, so widen the declaration instead of casting (a ::bigint cast would silently round/truncate arr and could overflow)
--
-- fsbca_r2369_by_category
--   was: RETURNS table(bet_category text, bet_count integer, total_deployed bigint, total_revenue bigint, avg_roi numeric)
--   now: RETURNS numeric, and these are rupee amounts on a founder financial report, so casting to bigint would silently round money instead of reporting it exactly. column names/order and every other declared type unchanged. returns table(bet_category text, bet_count integer, total_deployed numeric, total_revenue numeric, avg_roi numeric)
--
-- fsbca_r2369_summary
--   was: RETURNS table(total_bets integer, active_bets integer, total_initial_capital bigint, total_deployed bigint, total_revenue bigint, total_margin bigint, avg_roi numeric, best_roi numeric, worst_roi numeric)
--   now: RETURNS numeric in postgres, which is what caused the 42804. these four are money on a founder financial report, so the declaration was widened rather than casting the query to bigint (a cast is the wrong contract for money and would also risk silently truncating/overflowing a reported rupee total). names and order unchanged; cols 1-2 (integer, from count(*)::int) and cols 7-9 (numeric, from avg/max/min of numeric(8,2)) already matched and are untouched. returns table(total_bets integer, active_bets integer, total_initial_capital numeric, total_deployed numeric, total_revenue numeric, total_margin numeric, avg_roi numeric, best_roi numeric, worst_roi numeric)
--
-- owner_load_r2662
--   was: RETURNS table(owner_email text, open_pairings bigint, open_outcomes bigint, total_revenue_impact bigint)
--   now: RETURNS table(owner_email text, open_pairings bigint, open_outcomes bigint, total_revenue_impact numeric)
--
-- r2691_kpi_summary
--   was: RETURNS table(total_opps integer, total_pipeline_rupees bigint, weighted_pipeline_rupees bigint, won_acv_rupees bigint, win_count integer, loss_count integer)
--   now: RETURNS table( total_opps integer, total_pipeline_rupees numeric, -- round3791: was bigint, but sum(estimated_acv_rupees) over a bigint column returns numeric -> 42804. money column, so widened the declaration instead of casting the query: a ::bigint cast would silently round rupees/paise on a founder revenue report. weighted_pipeline_rupees numeric, -- round3791: was bigint, but the sum() returns numeric -> 42804. money and division-derived (probability weighting), so widened the declaration instead of casting: a ::bigint cast would silently discard the fractional part of a weighted-pipeline figure. won_acv_rupees numeric, -- round3791: was bigint, but sum(realized_acv_rupees) over a bigint column returns numeric -> 42804. money (realized revenue), so widened the declaration instead of casting, to avoid silent precision loss. win_count integer, loss_count integer )
--
-- recent_actions_night_shift_r2222
--   was: RETURNS table(id bigint, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone)
--   now: RETURNS table(id uuid, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone) -- round3791: id was declared bigint but founder_action_log.id is uuid (gen_random_uuid pk) — uuid is uncastable to bigint, so the declaration was wrong; widened to uuid. column names/order unchanged.
--
-- recent_actions_nps_r2216
--   was: RETURNS table(id bigint, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone)
--   now: RETURNS table(id uuid, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone)
--
-- recent_actions_r2202
--   was: RETURNS table(id bigint, op_name text, actor_email text, after_value jsonb, created_at timestamp with time zone)
--   now: RETURNS table(id uuid, op_name text, actor_email text, after_value jsonb, created_at timestamp with time zone) -- round3791: col 1 `id` declared bigint but founder_action_log.id is uuid (uncastable) -> fixed the declaration to uuid; cols 2-5 verified type-exact (text/text/jsonb/timestamptz), untouched
--
-- recent_actions_r2209
--   was: RETURNS table(id bigint, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone)
--   now: RETURNS table(id uuid, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone) -- round3791: col 1 was declared bigint but founder_action_log.id is uuid (round482) and uuid cannot be cast to bigint, so the declaration was the defect: type changed bigint -> uuid. cols 2-5 checked position-by-position and already match the table (text/text/jsonb/timestamptz) - unchanged.
--
-- recent_actions_reference_r2220
--   was: RETURNS table(id bigint, op_name text, actor_email text, created_at timestamp with time zone)
--   now: RETURNS table(id uuid, op_name text, actor_email text, created_at timestamp with time zone) -- round3791: col 1 declared bigint but founder_action_log.id is uuid (gen_random_uuid pk, round482) — uuid is uncastable to bigint, so the declaration was wrong; widened it to uuid. cols 2-4 (text/text/timestamptz) verified type-exact against the table, left untouched.
--
-- rpc_founder_ops_payout_backlog
--   was: RETURNS table(id uuid, engineer_user_id uuid, amount_rupees bigint, created_at timestamp with time zone, age_days numeric)
--   now: RETURNS table(id uuid, engineer_user_id uuid, amount_rupees numeric, created_at timestamp with time zone, age_days numeric) -- round3791: amount_rupees declared bigint -> numeric. engineer_payouts.amount_rupees is a generated numeric(12,2) money column (round(amount_paise::numeric/100.0, 2)); casting it to bigint would silently drop paise from a founder financial report, so widen the declaration instead of casting the query.
--
-- rpc_r2699_by_chain
--   was: RETURNS table(chain_name text, meetings bigint, total_ask_inr bigint, won_inr bigint, open_commits bigint, blocked_commits bigint)
--   now: RETURNS table(chain_name text, meetings bigint, total_ask_inr numeric, won_inr numeric, open_commits bigint, blocked_commits bigint)
--
-- rpc_r2699_by_topic
--   was: RETURNS table(meeting_topic text, meetings bigint, total_ask_inr bigint, won_pct numeric)
--   now: RETURNS table(meeting_topic text, meetings bigint, total_ask_inr numeric, won_pct numeric) -- round3791: col 3 total_ask_inr declared bigint but sum(ask_value_inr::bigint) yields numeric; this is money (rupee ask value, rendered via fmtinr), so widen the declaration to numeric rather than cast the query -- casting would risk truncation/overflow on a founder financial report
--
-- rpc_r2699_kpis
--   was: RETURNS table(total_meetings bigint, unique_chains bigint, total_ask_inr bigint, won_ask_inr bigint, progressing_ask_inr bigint, open_commitments bigint, slipped_commitments bigint, next_7_day_followups bigint)
--   now: RETURNS table(total_meetings bigint, unique_chains bigint, total_ask_inr numeric, won_ask_inr numeric, progressing_ask_inr numeric, open_commitments bigint, slipped_commitments bigint, next_7_day_followups bigint)
--
-- topic_kind_breakdown_r2522
--   was: RETURNS table(topic_kind text, callback_count bigint, avg_csat numeric, total_upsell_rupees bigint, total_loose_ends bigint)
--   now: RETURNS table(topic_kind text, callback_count bigint, avg_csat numeric, total_upsell_rupees numeric, total_loose_ends bigint) -- round3791: widened total_upsell_rupees bigint->numeric. sum(bigint) yields numeric; this is a money total on a founder financial report, so casting it down to bigint would silently truncate/overflow rather than report the true rupee sum. other 4 columns re-checked position-by-position and already match (text/count(*)=bigint/round(avg)=numeric/sum(int)=bigint).
--
-- top_callback_engineers_r2522
--   was: RETURNS table(engineer_user_id uuid, owner_email text, callback_count bigint, connected_count bigint, avg_csat numeric, total_upsell_rupees bigint, total_loose_ends bigint)
--   now: RETURNS table(engineer_user_id uuid, owner_email text, callback_count bigint, connected_count bigint, avg_csat numeric, total_upsell_rupees numeric, total_loose_ends bigint) -- round3791: col 6 total_upsell_rupees widened bigint -> numeric; sum(upsell_opportunity_rupees) is sum(bigint) which returns numeric, and this is money (rupees on a founder financial report), so widening the declaration is safe where an ::bigint cast would risk silent precision/overflow loss. cols 1-5 and 7 were walked position-by-position and already match.
--
-- top_pairing_focus_r2662
--   was: RETURNS table(pairing_id uuid, knowledge_transfer_kind text, retention_signal text, status text, days_paired integer, outcome_count bigint, total_revenue_impact bigint)
--   now: RETURNS table(pairing_id uuid, knowledge_transfer_kind text, retention_signal text, status text, days_paired integer, outcome_count bigint, total_revenue_impact numeric) -- round3791: widened total_revenue_impact from bigint to numeric -- it is money (sum of revenue_impact_rupees), sum() yields numeric, and casting the query column to bigint would silently round a founder revenue figure

-- brand_equity_pulse_kpis_r2781 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.brand_equity_pulse_kpis_r2781();
CREATE OR REPLACE FUNCTION public.brand_equity_pulse_kpis_r2781()
 RETURNS TABLE(segment_count bigint, campaign_count bigint, avg_aided_awareness numeric, avg_unaided_awareness numeric, avg_consideration numeric, avg_preference numeric, avg_nps numeric, avg_nps_delta numeric, total_spend_rupees numeric, avg_qoq_shift numeric, surging_segments bigint, weak_segments bigint) -- round3791: col 9 total_spend_rupees bigint -> numeric; SUM(spend_rupees) returns numeric (SUM of bigint is numeric in PG) and this is MONEY, so widen the declaration rather than cast the query -- a ::bigint cast on a founder financial report would silently truncate any fractional rupee. All other 11 columns verified position-by-position against the query and already match.
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT count(*) FROM public.brand_equity_campaigns_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(aided_awareness_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(unaided_awareness_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(consideration_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(preference_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(nps_score),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(nps_score - prior_nps_score),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(SUM(spend_rupees),0) FROM public.brand_equity_campaigns_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT COALESCE(ROUND(AVG(qoq_shift_pct),2),0) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026'),
      (SELECT count(*) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026' AND signal_strength = 'surging'),
      (SELECT count(*) FROM public.brand_equity_segments_r2781 WHERE quarter = 'Q2-2026' AND signal_strength = 'weak');
END;
$function$;
REVOKE ALL ON FUNCTION public.brand_equity_pulse_kpis_r2781() FROM PUBLIC, anon, authenticated, service_role;

-- founder_biomed_by_hospital_r2235 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_biomed_by_hospital_r2235();
CREATE OR REPLACE FUNCTION public.founder_biomed_by_hospital_r2235()
 RETURNS TABLE(hospital text, total_staff integer, active integer, departed_90d integer, max_risk integer, amc_at_risk numeric) -- round3791: amc_at_risk widened bigint->numeric; it is MONEY (SUM of amc_value_rupees) and sum(bigint) yields numeric, so casting to bigint would round a founder financial report instead of reporting it exactly
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.hospital_name,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE s.status IN ('active','notice_period')))::int,
    (SELECT COUNT(*) FROM public.hospital_biomed_transitions_r2235 t WHERE t.hospital_name = s.hospital_name AND t.transition_type = 'left' AND t.transition_date >= CURRENT_DATE - 90)::int,
    COALESCE(MAX(s.risk_score), 0),
    COALESCE(SUM(s.amc_value_rupees) FILTER (WHERE s.risk_score >= 70 AND s.status IN ('active','notice_period')), 0)
  FROM public.hospital_biomed_staff_r2235 s
  GROUP BY s.hospital_name
  ORDER BY MAX(s.risk_score) DESC NULLS LAST
  LIMIT 50;
END $function$;
REVOKE ALL ON FUNCTION public.founder_biomed_by_hospital_r2235() FROM PUBLIC, anon, authenticated, service_role;

-- founder_biomed_departure_reasons_r2235 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_biomed_departure_reasons_r2235();
CREATE OR REPLACE FUNCTION public.founder_biomed_departure_reasons_r2235()
 -- round3791: col 3 total_exposure was declared bigint but SUM(exposure_rupees) returns numeric (sum of a bigint money column) -> 42804. This is MONEY, not a tally, so the declaration is widened to numeric rather than casting the query to bigint, which would silently truncate rupee precision on a founder financial report. Cols 1 (reason -> text) and 2 (COUNT(*)::int -> integer) already match.
 RETURNS TABLE(reason text, count integer, total_exposure numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(reason, 'unspecified'), COUNT(*)::int, COALESCE(SUM(exposure_rupees), 0)
  FROM public.hospital_biomed_transitions_r2235
  WHERE transition_type = 'left'
  GROUP BY reason
  ORDER BY COUNT(*) DESC
  LIMIT 20;
END $function$;
REVOKE ALL ON FUNCTION public.founder_biomed_departure_reasons_r2235() FROM PUBLIC, anon, authenticated, service_role;

-- founder_hospital_xsell_by_product -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_hospital_xsell_by_product();
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_by_product()
 RETURNS TABLE(product_slug text, total_rows bigint, won_rows bigint,
               -- round3791: pipeline_rupees was declared bigint but the query returns numeric
               -- (SUM(est_value_rupees) over a bigint column yields numeric) -> 42804 on every call.
               -- WIDENED the declaration to numeric instead of casting the query: this is a MONEY
               -- column on a founder financial report (rendered via fmtINR in the web console), so
               -- ::bigint would silently round away sub-rupee precision. Matches the precedent set
               -- by round1422's weighted_pipeline_rupees numeric.
               pipeline_rupees numeric,
               avg_fit numeric, open_queue bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.product_slug,
         COUNT(*),
         COUNT(*) FILTER (WHERE l.ladder_stage='won'),
         COALESCE(SUM(l.est_value_rupees) FILTER (WHERE l.ladder_stage NOT IN ('lost','parked')), 0),
         COALESCE(ROUND(AVG(l.fit_score)::numeric, 1), 0),
         (SELECT COUNT(*) FROM public.founder_hospital_cross_sell_action_queue q
          JOIN public.founder_hospital_cross_sell_ladder l2 ON l2.id=q.ladder_id
          WHERE l2.product_slug = l.product_slug AND q.status='open')
  FROM public.founder_hospital_cross_sell_ladder l
  GROUP BY l.product_slug
  ORDER BY 4 DESC;
END $function$;
REVOKE ALL ON FUNCTION public.founder_hospital_xsell_by_product() FROM PUBLIC, anon, authenticated, service_role;

-- founder_hospital_xsell_overview -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_hospital_xsell_overview();
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_overview()
 -- round3791: total_pipeline_rupees declared type widened bigint -> numeric. sum() over a bigint column returns numeric, and this is MONEY on a founder financial report, so casting to bigint would silently round reported pipeline value instead of reporting it exactly.
 -- round3791: won_pipeline_rupees declared type widened bigint -> numeric. Same defect, same reason (money, not a tally) -- the analyzer stopped at column 11 and never reached this one.
 RETURNS TABLE(total_amc_hospitals bigint, hospitals_with_ladder bigint, total_ladder_rows bigint, suggested_rows bigint, pitched_rows bigint, interested_rows bigint, negotiating_rows bigint, won_rows bigint, lost_rows bigint, parked_rows bigint, total_pipeline_rupees numeric, won_pipeline_rupees numeric, open_queue_items bigint, overdue_queue_items bigint, urgent_queue_items bigint, avg_fit_score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH amc_h AS (
    SELECT DISTINCT p.organization_id AS org_id
    FROM public.amc_contracts c
    JOIN public.profiles p ON p.id = c.hospital_user_id
    WHERE p.organization_id IS NOT NULL
  ),
  ladder AS (SELECT * FROM public.founder_hospital_cross_sell_ladder),
  q AS (SELECT * FROM public.founder_hospital_cross_sell_action_queue)
  SELECT
    (SELECT COUNT(*) FROM amc_h),
    (SELECT COUNT(DISTINCT hospital_org_id) FROM ladder),
    (SELECT COUNT(*) FROM ladder),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='suggested'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='pitched'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='interested'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='negotiating'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='won'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='lost'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='parked'),
    (SELECT COALESCE(SUM(est_value_rupees),0) FROM ladder WHERE ladder_stage NOT IN ('lost','parked')),
    (SELECT COALESCE(SUM(est_value_rupees),0) FROM ladder WHERE ladder_stage='won'),
    (SELECT COUNT(*) FROM q WHERE status='open'),
    (SELECT COUNT(*) FROM q WHERE status='open' AND due_at < now()),
    (SELECT COUNT(*) FROM q WHERE status='open' AND priority='urgent'),
    (SELECT COALESCE(ROUND(AVG(fit_score)::numeric, 1), 0) FROM ladder);
END $function$;
REVOKE ALL ON FUNCTION public.founder_hospital_xsell_overview() FROM PUBLIC, anon, authenticated, service_role;

-- founder_hospital_xsell_top_hospitals -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_hospital_xsell_top_hospitals();
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_top_hospitals()
 RETURNS TABLE(hospital_org_id uuid, hospital_name text, ladder_rows bigint, won_rows bigint, pipeline_rupees numeric, open_queue bigint, avg_fit numeric) -- round3791: pipeline_rupees widened bigint->numeric. SUM(l.est_value_rupees) over a bigint column returns numeric, which is the 42804. pipeline_rupees is MONEY on a founder financial report, so the declared contract is widened rather than the query cast to ::bigint (a cast would silently truncate paise if est_value_rupees is ever made numeric, and would hard-error on bigint overflow for a large aggregate). Column names/order and every other declared type are unchanged.
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.hospital_org_id, o.name,
         COUNT(*),
         COUNT(*) FILTER (WHERE l.ladder_stage='won'),
         COALESCE(SUM(l.est_value_rupees) FILTER (WHERE l.ladder_stage NOT IN ('lost','parked')), 0),
         (SELECT COUNT(*) FROM public.founder_hospital_cross_sell_action_queue q
          JOIN public.founder_hospital_cross_sell_ladder l2 ON l2.id=q.ladder_id
          WHERE l2.hospital_org_id = l.hospital_org_id AND q.status='open'),
         COALESCE(ROUND(AVG(l.fit_score)::numeric, 1), 0)
  FROM public.founder_hospital_cross_sell_ladder l
  LEFT JOIN public.organizations o ON o.id = l.hospital_org_id
  GROUP BY l.hospital_org_id, o.name
  ORDER BY 5 DESC NULLS LAST
  LIMIT 50;
END $function$;
REVOKE ALL ON FUNCTION public.founder_hospital_xsell_top_hospitals() FROM PUBLIC, anon, authenticated, service_role;

-- founder_hpbi_pipeline_by_status -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_hpbi_pipeline_by_status();
CREATE OR REPLACE FUNCTION public.founder_hpbi_pipeline_by_status()
 RETURNS TABLE(our_submission_status text, tender_count integer, total_estimated_rupees numeric, total_our_bid_rupees numeric, avg_win_probability integer) -- round3791: cols 3 total_estimated_rupees + 4 total_our_bid_rupees widened bigint->numeric, because SUM() over these columns yields numeric (42804); both are rupee MONEY totals on a founder financial report, so casting them back to bigint would silently drop precision instead
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.our_submission_status,
         COUNT(*)::int,
         COALESCE(SUM(t.estimated_value_rupees),0),
         COALESCE(SUM(t.our_bid_rupees),0),
         COALESCE(ROUND(AVG(t.win_probability_pct))::int, 0)
  FROM hospital_procurement_tenders t
  GROUP BY t.our_submission_status
  ORDER BY 3 DESC;
END $function$;
REVOKE ALL ON FUNCTION public.founder_hpbi_pipeline_by_status() FROM PUBLIC, anon, authenticated, service_role;

-- founder_lost_deal_kpis_v2 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_lost_deal_kpis_v2();
CREATE OR REPLACE FUNCTION public.founder_lost_deal_kpis_v2()
 -- round3791: two declared types widened bigint -> numeric on the RETURNS TABLE line below (the 42804 fix).
 -- round3791:   col 2 total_lost_value_30d_rupees  and  col 4 total_lost_value_90d_rupees
 -- round3791: both are COALESCE(sum(deal_value_rupees),0); deal_value_rupees is bigint, and sum(bigint) is
 -- round3791: numeric in PostgreSQL, so the declared bigint mismatched and raised 42804 on every call.
 -- round3791: These are MONEY totals on a founder financial report, so the declaration is widened rather than
 -- round3791: the query cast to bigint: widening is lossless, whereas ::bigint would silently round away
 -- round3791: sub-rupee precision (and could overflow on a large enough sum). Column names/order unchanged.
 RETURNS TABLE(total_lost_30d bigint, total_lost_value_30d_rupees numeric, total_lost_90d bigint, total_lost_value_90d_rupees numeric, avg_deal_value_rupees bigint, pct_could_have_won numeric, recovery_rate_pct numeric, competitor_count integer, top_competitor text, open_actions bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH d AS (SELECT * FROM hospital_lost_deals_v2),
  d30 AS (SELECT * FROM d WHERE lost_at >= now() - interval '30 days'),
  d90 AS (SELECT * FROM d WHERE lost_at >= now() - interval '90 days'),
  comp AS (
    SELECT competitor_won, count(*) c FROM d WHERE competitor_won IS NOT NULL
    GROUP BY competitor_won ORDER BY c DESC LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM d30),
    COALESCE((SELECT sum(deal_value_rupees) FROM d30),0),
    (SELECT count(*) FROM d90),
    COALESCE((SELECT sum(deal_value_rupees) FROM d90),0),
    COALESCE((SELECT avg(deal_value_rupees)::bigint FROM d90),0),
    COALESCE((SELECT round(100.0*sum(CASE WHEN could_we_have_won THEN 1 ELSE 0 END)/NULLIF(count(*),0),1) FROM d90),0),
    COALESCE((SELECT round(100.0*sum(CASE WHEN recovered THEN 1 ELSE 0 END)/NULLIF(count(*),0),1) FROM d WHERE recovery_attempt_made),0),
    (SELECT count(DISTINCT competitor_won)::int FROM d WHERE competitor_won IS NOT NULL),
    (SELECT competitor_won FROM comp),
    (SELECT count(*) FROM hospital_lost_deal_actions_v2 WHERE action_status IN ('open','in_progress'));
END $function$;
REVOKE ALL ON FUNCTION public.founder_lost_deal_kpis_v2() FROM PUBLIC, anon, authenticated, service_role;

-- founder_peer_stage_distribution -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_peer_stage_distribution();
CREATE OR REPLACE FUNCTION public.founder_peer_stage_distribution()
 RETURNS TABLE(id uuid, fundraise_stage text, peer_count bigint, total_raised_rupees numeric, avg_hospital_count numeric, avg_engineer_count numeric) -- round3791: widened total_raised_rupees bigint->numeric (col 4); SUM() of bigint returns numeric and this is a MONEY column, so casting to bigint would round/overflow founder-reported capital raised
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (ps.peer_id)
      ps.peer_id, ps.fundraise_stage, ps.total_raised_rupees,
      ps.hospital_count, ps.engineer_count
    FROM founder_peer_metric_snapshots ps
    ORDER BY ps.peer_id, ps.snapshot_at DESC
  )
  SELECT gen_random_uuid() AS id,
         COALESCE(latest.fundraise_stage,'unknown') AS fundraise_stage,
         COUNT(*) AS peer_count,
         COALESCE(SUM(latest.total_raised_rupees),0) AS total_raised_rupees,
         AVG(latest.hospital_count) AS avg_hospital_count,
         AVG(latest.engineer_count) AS avg_engineer_count
  FROM latest
  GROUP BY latest.fundraise_stage
  ORDER BY peer_count DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.founder_peer_stage_distribution() FROM PUBLIC, anon, authenticated, service_role;

-- founder_podcast_pipeline_summary -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_podcast_pipeline_summary();
CREATE OR REPLACE FUNCTION public.founder_podcast_pipeline_summary()
 RETURNS TABLE(total_targets bigint, identified bigint, pitched bigint, responded bigint, scheduled bigint, recorded bigint, published bigint, rejected bigint, ghosted bigint, avg_fit_score numeric, total_audience bigint, recorded_audience bigint, response_rate_pct numeric, recorded_rate_pct numeric, pipeline_value_rupees numeric, closed_revenue_rupees numeric) -- round3791: widened pipeline_value_rupees (col 15) and closed_revenue_rupees (col 16) from bigint to numeric: SUM(bigint) returns numeric, and these are MONEY on a founder financial report, so casting to bigint would silently round revenue instead of reporting it exactly
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH t AS (SELECT * FROM founder_podcast_targets),
       r AS (SELECT COALESCE(SUM(pipeline_value_rupees),0) AS pv,
                    COALESCE(SUM(closed_revenue_rupees),0) AS cv
             FROM founder_podcast_appearance_roi)
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status='identified')::bigint,
    COUNT(*) FILTER (WHERE status='pitched')::bigint,
    COUNT(*) FILTER (WHERE status='responded')::bigint,
    COUNT(*) FILTER (WHERE status='scheduled')::bigint,
    COUNT(*) FILTER (WHERE status='recorded')::bigint,
    COUNT(*) FILTER (WHERE status='published')::bigint,
    COUNT(*) FILTER (WHERE status='rejected')::bigint,
    COUNT(*) FILTER (WHERE status='ghosted')::bigint,
    ROUND(COALESCE(AVG(fit_score),0)::numeric, 2),
    COALESCE(SUM(audience_size_estimate),0)::bigint,
    COALESCE(SUM(audience_size_estimate) FILTER (WHERE status IN ('recorded','published')),0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE status IN ('pitched','responded','scheduled','recorded','published','rejected','ghosted'))=0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE status IN ('responded','scheduled','recorded','published'))
              / NULLIF(COUNT(*) FILTER (WHERE status IN ('pitched','responded','scheduled','recorded','published','rejected','ghosted')),0), 2) END,
    CASE WHEN COUNT(*)=0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE status IN ('recorded','published')) / NULLIF(COUNT(*),0), 2) END,
    (SELECT pv FROM r),
    (SELECT cv FROM r)
  FROM t;
END $function$;
REVOKE ALL ON FUNCTION public.founder_podcast_pipeline_summary() FROM PUBLIC, anon, authenticated, service_role;

-- founder_pricing_by_quarter_r2833 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_pricing_by_quarter_r2833();
CREATE OR REPLACE FUNCTION public.founder_pricing_by_quarter_r2833()
 -- round3791: col 4 total_delta bigint -> numeric; expr is sum(revenue_delta_rupees) (bigint) which yields numeric. This is MONEY (console renders it as "Revenue delta" via rupees()), so widening the declaration is correct -- casting to bigint would silently round a founder financial report.
 RETURNS TABLE(quarter text, revision_count bigint, avg_pct_change numeric, total_delta numeric, wins bigint, losses bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.quarter,
    count(*)::bigint,
    ROUND(AVG(r.pct_change)::numeric, 2),
    COALESCE((SELECT sum(revenue_delta_rupees) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.revision_quarter = r.quarter), 0),
    COALESCE((SELECT count(*) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.revision_quarter = r.quarter AND o.outcome_label = 'win'), 0),
    COALESCE((SELECT count(*) FROM pricing_tier_revision_outcomes_r2833 o
       WHERE o.revision_quarter = r.quarter AND o.outcome_label = 'loss'), 0)
  FROM pricing_tier_revisions_r2833 r
  GROUP BY r.quarter
  ORDER BY r.quarter DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.founder_pricing_by_quarter_r2833() FROM PUBLIC, anon, authenticated, service_role;

-- founder_pricing_kpi_summary_r2833 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_pricing_kpi_summary_r2833();
CREATE OR REPLACE FUNCTION public.founder_pricing_kpi_summary_r2833()
 RETURNS TABLE(total_revisions bigint, live_revisions bigint, proposed_revisions bigint, rolled_back bigint, total_revenue_delta numeric, avg_pct_change numeric)  -- round3791: total_revenue_delta bigint -> numeric; sum(revenue_delta_rupees) is numeric and this is MONEY on a founder financial report, so widen the declared type instead of casting (a ::bigint cast would silently round reported revenue)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM pricing_tier_revisions_r2833),
    (SELECT count(*) FROM pricing_tier_revisions_r2833 WHERE status = 'live'),
    (SELECT count(*) FROM pricing_tier_revisions_r2833 WHERE status = 'proposed'),
    (SELECT count(*) FROM pricing_tier_revisions_r2833 WHERE status = 'rolled_back'),
    (SELECT COALESCE(sum(revenue_delta_rupees),0) FROM pricing_tier_revision_outcomes_r2833),
    (SELECT ROUND(AVG(pct_change)::numeric, 2) FROM pricing_tier_revisions_r2833);
END;
$function$;
REVOKE ALL ON FUNCTION public.founder_pricing_kpi_summary_r2833() FROM PUBLIC, anon, authenticated, service_role;

-- founder_r2819_kpis -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_r2819_kpis();
CREATE OR REPLACE FUNCTION public.founder_r2819_kpis()
 -- round3791: widened total_revenue_loss_rupees bigint->numeric and projected_recovery_rupees bigint->numeric (cols 4 and 7). Both are sum() of a money column, which returns numeric; these are RUPEE amounts on a founder financial report, so casting the query to ::bigint would silently round away precision. Widening the declaration is lossless. All other 5 columns verified position-by-position and already match.
 RETURNS TABLE(total_centers integer, avg_uptime_pct numeric, critical_centers integer, total_revenue_loss_rupees numeric, total_downtime_hours numeric, open_interventions integer, projected_recovery_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM hospital_chain_imaging_center_uptime_r2819),
    (SELECT round(avg(uptime_pct),2) FROM hospital_chain_imaging_center_uptime_r2819),
    (SELECT count(*)::int FROM hospital_chain_imaging_center_uptime_r2819 WHERE status='critical'),
    (SELECT coalesce(sum(revenue_loss_rupees),0) FROM hospital_chain_imaging_center_uptime_r2819),
    (SELECT coalesce(sum(downtime_hours),0) FROM hospital_chain_imaging_center_uptime_r2819),
    (SELECT count(*)::int FROM hospital_chain_imaging_interventions_r2819 WHERE status IN ('proposed','in_progress')),
    (SELECT coalesce(sum(projected_revenue_recovery_rupees),0) FROM hospital_chain_imaging_interventions_r2819 WHERE status IN ('proposed','in_progress'));
END $function$;
REVOKE ALL ON FUNCTION public.founder_r2819_kpis() FROM PUBLIC, anon, authenticated, service_role;

-- founder_r2971_spend_forecast -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_r2971_spend_forecast();
CREATE OR REPLACE FUNCTION public.founder_r2971_spend_forecast()
 RETURNS TABLE(chain_name text, open_signals integer, projected_rupees numeric, max_lead_days integer) -- round3791: col 3 projected_rupees declared bigint -> numeric. sum(bigint*bigint) returns numeric; this column is MONEY (projected rupee spend on a founder financial report), so widening the declaration is correct and lossless -- casting the sum to bigint would bake a rounding step into a revenue/spend figure. Cols 1/2/4 verified type-exact (chain_name is text in ot_bulb_reorder_signals_r2971; count(*)::int and coalesce(max(...),0)::int are integer), so nothing else changed.
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.chain_name,
    count(*)::int,
    sum(s.recommended_qty::bigint * s.unit_cost_rupees::bigint),
    coalesce(max(s.lead_time_days),0)::int
  from ot_bulb_reorder_signals_r2971 s
  where s.resolved = false
  group by s.chain_name
  order by projected_rupees desc nulls last;
end;$function$;
REVOKE ALL ON FUNCTION public.founder_r2971_spend_forecast() FROM PUBLIC, anon, authenticated, service_role;

-- founder_r2971_vendor_concentration -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_r2971_vendor_concentration();
CREATE OR REPLACE FUNCTION public.founder_r2971_vendor_concentration()
 -- round3791: col 4 total_rupees declared bigint -> numeric. sum() over bigint returns numeric (the 42804).
 -- round3791: total_rupees is MONEY on a founder financial report, so the DECLARATION is the wrong half:
 -- round3791: sum()::bigint would round away paise and can overflow bigint; numeric is lossless + unbounded.
 -- round3791: cols 1-3 (text / ::int / ::int) checked position-by-position, already match. Names + order unchanged.
 RETURNS TABLE(vendor_name text, skus integer, open_signals integer, total_rupees numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.vendor_name,
    count(distinct s.bulb_sku)::int,
    (count(*) filter (where s.resolved=false))::int,
    sum(case when s.resolved=false then s.recommended_qty::bigint * s.unit_cost_rupees::bigint else 0 end)
  from ot_bulb_reorder_signals_r2971 s
  group by s.vendor_name
  order by total_rupees desc nulls last;
end;$function$;
REVOKE ALL ON FUNCTION public.founder_r2971_vendor_concentration() FROM PUBLIC, anon, authenticated, service_role;

-- founder_site_visit_outcomes_by_kind -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.founder_site_visit_outcomes_by_kind();
CREATE OR REPLACE FUNCTION public.founder_site_visit_outcomes_by_kind()
 RETURNS TABLE(outcome_kind text, n bigint, arr_total_rupees numeric, last_recorded_at timestamp with time zone) -- round3791: arr_total_rupees bigint -> numeric; sum(arr_impact_rupees) over a bigint column yields numeric, and this is MONEY on a founder financial report, so widen the declaration instead of casting (a ::bigint cast would silently round/truncate ARR and could overflow)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.outcome_kind, count(*), coalesce(sum(x.arr_impact_rupees),0), max(x.recorded_at)
  FROM hospital_site_visit_outcomes x
  GROUP BY x.outcome_kind
  ORDER BY count(*) DESC;
END;$function$;
REVOKE ALL ON FUNCTION public.founder_site_visit_outcomes_by_kind() FROM PUBLIC, anon, authenticated, service_role;

-- fsbca_r2369_by_category -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.fsbca_r2369_by_category();
CREATE OR REPLACE FUNCTION public.fsbca_r2369_by_category()
 -- round3791: widened total_deployed and total_revenue from bigint to numeric -- SUM() over a bigint money column returns numeric, and these are rupee amounts on a founder financial report, so casting to bigint would silently round money instead of reporting it exactly. Column names/order and every other declared type unchanged.
 RETURNS TABLE(bet_category text, bet_count integer, total_deployed numeric, total_revenue numeric, avg_roi numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.bet_category,
    COUNT(*)::int,
    COALESCE(SUM(b.capital_deployed_rupees),0),
    COALESCE(SUM(b.revenue_generated_rupees),0),
    COALESCE(AVG(b.roi_percent),0)::numeric
  FROM public.founder_strategic_bet_capital_allocation_r2369 b
  GROUP BY b.bet_category
  ORDER BY 4 DESC;
END $function$;
REVOKE ALL ON FUNCTION public.fsbca_r2369_by_category() FROM PUBLIC, anon, authenticated, service_role;

-- fsbca_r2369_summary -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.fsbca_r2369_summary();
CREATE OR REPLACE FUNCTION public.fsbca_r2369_summary()
 -- round3791: cols 3-6 (total_initial_capital, total_deployed, total_revenue, total_margin) widened bigint -> numeric. The underlying *_rupees columns are bigint, and SUM(bigint) returns numeric in Postgres, which is what caused the 42804. These four are MONEY on a founder financial report, so the declaration was widened rather than casting the query to bigint (a cast is the wrong contract for money and would also risk silently truncating/overflowing a reported rupee total). Names and order unchanged; cols 1-2 (integer, from COUNT(*)::int) and cols 7-9 (numeric, from AVG/MAX/MIN of numeric(8,2)) already matched and are untouched.
 RETURNS TABLE(total_bets integer, active_bets integer, total_initial_capital numeric, total_deployed numeric, total_revenue numeric, total_margin numeric, avg_roi numeric, best_roi numeric, worst_roi numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE bet_status IN ('active','scaling'))::int,
    COALESCE(SUM(initial_capital_rupees),0),
    COALESCE(SUM(capital_deployed_rupees),0),
    COALESCE(SUM(revenue_generated_rupees),0),
    COALESCE(SUM(gross_margin_rupees),0),
    COALESCE(AVG(roi_percent),0)::numeric,
    COALESCE(MAX(roi_percent),0)::numeric,
    COALESCE(MIN(roi_percent),0)::numeric
  FROM public.founder_strategic_bet_capital_allocation_r2369;
END $function$;
REVOKE ALL ON FUNCTION public.fsbca_r2369_summary() FROM PUBLIC, anon, authenticated, service_role;

-- owner_load_r2662 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.owner_load_r2662();
CREATE OR REPLACE FUNCTION public.owner_load_r2662()
 -- round3791: col 4 total_revenue_impact bigint -> numeric. sum(revenue_impact_rupees) over a bigint column yields numeric; this is MONEY (rupees), so widening the declaration is correct -- casting to bigint would silently round/truncate a founder revenue figure. Cols 1-3 (text, bigint, bigint) verified matching, left unchanged.
 RETURNS TABLE(owner_email text, open_pairings bigint, open_outcomes bigint, total_revenue_impact numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    with b_load as (
      select coalesce(b.owner_email, 'unassigned') as owner_email,
             count(*) filter (where b.status = 'active') as open_pairings
      from public.engineer_onboarding_buddies_r2662 b
      group by coalesce(b.owner_email, 'unassigned')
    ),
    o_load as (
      select coalesce(o.owner_email, 'unassigned') as owner_email,
             count(*) filter (where o.status = 'open') as open_outcomes,
             coalesce(sum(o.revenue_impact_rupees), 0) as total_revenue_impact
      from public.buddy_program_outcomes_r2662 o
      group by coalesce(o.owner_email, 'unassigned')
    )
    select coalesce(b_load.owner_email, o_load.owner_email) as owner_email,
           coalesce(b_load.open_pairings, 0) as open_pairings,
           coalesce(o_load.open_outcomes, 0) as open_outcomes,
           coalesce(o_load.total_revenue_impact, 0) as total_revenue_impact
    from b_load
    full outer join o_load on o_load.owner_email = b_load.owner_email
    order by total_revenue_impact desc, open_pairings desc;
end;
$function$;
REVOKE ALL ON FUNCTION public.owner_load_r2662() FROM PUBLIC, anon, authenticated, service_role;

-- r2691_kpi_summary -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.r2691_kpi_summary();
CREATE OR REPLACE FUNCTION public.r2691_kpi_summary()
 RETURNS TABLE(
   total_opps integer,
   total_pipeline_rupees numeric,     -- round3791: was bigint, but sum(estimated_acv_rupees) over a bigint column returns numeric -> 42804. MONEY column, so widened the declaration instead of casting the query: a ::bigint cast would silently round rupees/paise on a founder revenue report.
   weighted_pipeline_rupees numeric,  -- round3791: was bigint, but the sum() returns numeric -> 42804. MONEY and division-derived (probability weighting), so widened the declaration instead of casting: a ::bigint cast would silently discard the fractional part of a weighted-pipeline figure.
   won_acv_rupees numeric,            -- round3791: was bigint, but sum(realized_acv_rupees) over a bigint column returns numeric -> 42804. MONEY (realized revenue), so widened the declaration instead of casting, to avoid silent precision loss.
   win_count integer,
   loss_count integer
 )
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM chain_xsell_opportunities_r2691),
    COALESCE((SELECT SUM(estimated_acv_rupees) FROM chain_xsell_opportunities_r2691),0),
    COALESCE((SELECT SUM(estimated_acv_rupees * probability_pct / 100) FROM chain_xsell_opportunities_r2691),0),
    COALESCE((SELECT SUM(realized_acv_rupees) FROM chain_xsell_pursuits_r2691 WHERE outcome='won'),0),
    (SELECT COUNT(*)::int FROM chain_xsell_pursuits_r2691 WHERE outcome='won'),
    (SELECT COUNT(*)::int FROM chain_xsell_pursuits_r2691 WHERE outcome='lost');
END $function$;
REVOKE ALL ON FUNCTION public.r2691_kpi_summary() FROM PUBLIC, anon, authenticated, service_role;

-- recent_actions_night_shift_r2222 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.recent_actions_night_shift_r2222(p_limit integer);
CREATE OR REPLACE FUNCTION public.recent_actions_night_shift_r2222(p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone)  -- round3791: id was declared bigint but founder_action_log.id is uuid (gen_random_uuid PK) — uuid is uncastable to bigint, so the DECLARATION was wrong; widened to uuid. Column names/order unchanged.
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.actor_email, a.op_name, a.after_value, a.created_at
  FROM public.founder_action_log a
  WHERE a.op_name LIKE 'op_r2222%'
  ORDER BY a.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$function$;
REVOKE ALL ON FUNCTION public.recent_actions_night_shift_r2222(p_limit integer) FROM PUBLIC, anon, authenticated, service_role;

-- recent_actions_nps_r2216 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.recent_actions_nps_r2216();
CREATE OR REPLACE FUNCTION public.recent_actions_nps_r2216()
 -- round3791: col 1 `id` was declared bigint but founder_action_log.id is uuid (round482 table, gen_random_uuid PK) — uuid is uncastable to bigint, so the DECLARATION was wrong; widened to uuid. Cols 2-5 verified type-exact against the table, unchanged. NOTE: changing an OUT column type needs DROP FUNCTION public.recent_actions_nps_r2216(); first (42P13), then re-apply REVOKE ALL ... FROM PUBLIC, anon + GRANT EXECUTE ... TO authenticated (DROP discards grants).
 RETURNS TABLE(id uuid, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.actor_email, f.op_name, f.after_value, f.created_at
    FROM public.founder_action_log f
    WHERE f.op_name LIKE 'op_r2216%'
    ORDER BY f.created_at DESC
    LIMIT 50;
END;
$function$;
REVOKE ALL ON FUNCTION public.recent_actions_nps_r2216() FROM PUBLIC, anon, authenticated, service_role;

-- recent_actions_r2202 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.recent_actions_r2202();
CREATE OR REPLACE FUNCTION public.recent_actions_r2202()
 RETURNS TABLE(id uuid, op_name text, actor_email text, after_value jsonb, created_at timestamp with time zone) -- round3791: col 1 `id` declared bigint but founder_action_log.id is uuid (uncastable) -> fixed the DECLARATION to uuid; cols 2-5 verified type-exact (text/text/jsonb/timestamptz), untouched
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.op_name, a.actor_email, a.after_value, a.created_at
      FROM public.founder_action_log a
     WHERE a.op_name LIKE '%_r2202'
     ORDER BY a.created_at DESC
     LIMIT 100;
END;
$function$;
REVOKE ALL ON FUNCTION public.recent_actions_r2202() FROM PUBLIC, anon, authenticated, service_role;

-- recent_actions_r2209 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.recent_actions_r2209();
CREATE OR REPLACE FUNCTION public.recent_actions_r2209()
 RETURNS TABLE(id uuid, actor_email text, op_name text, after_value jsonb, created_at timestamp with time zone) -- round3791: col 1 was declared bigint but founder_action_log.id is uuid (round482) and uuid cannot be cast to bigint, so the DECLARATION was the defect: type changed bigint -> uuid. Cols 2-5 checked position-by-position and already match the table (text/text/jsonb/timestamptz) - unchanged.
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.actor_email, l.op_name, l.after_value, l.created_at
  FROM public.founder_action_log l
  WHERE l.op_name LIKE 'op_r2209%'
  ORDER BY l.created_at DESC LIMIT 50;
END;
$function$;
REVOKE ALL ON FUNCTION public.recent_actions_r2209() FROM PUBLIC, anon, authenticated, service_role;

-- recent_actions_reference_r2220 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.recent_actions_reference_r2220();
CREATE OR REPLACE FUNCTION public.recent_actions_reference_r2220()
 RETURNS TABLE(id uuid, op_name text, actor_email text, created_at timestamp with time zone)  -- round3791: col 1 declared bigint but founder_action_log.id is uuid (gen_random_uuid PK, round482) — uuid is uncastable to bigint, so the DECLARATION was wrong; widened it to uuid. Cols 2-4 (text/text/timestamptz) verified type-exact against the table, left untouched.
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT fal.id, fal.op_name, fal.actor_email, fal.created_at
    FROM public.founder_action_log fal
    WHERE fal.op_name LIKE 'op_r2220%'
    ORDER BY fal.created_at DESC LIMIT 50;
END $function$;
REVOKE ALL ON FUNCTION public.recent_actions_reference_r2220() FROM PUBLIC, anon, authenticated, service_role;

-- rpc_founder_ops_payout_backlog -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.rpc_founder_ops_payout_backlog();
CREATE OR REPLACE FUNCTION public.rpc_founder_ops_payout_backlog()
 RETURNS TABLE(id uuid, engineer_user_id uuid, amount_rupees numeric, created_at timestamp with time zone, age_days numeric) -- round3791: amount_rupees declared bigint -> numeric. engineer_payouts.amount_rupees is a GENERATED numeric(12,2) money column (round(amount_paise::numeric/100.0, 2)); casting it to bigint would silently drop paise from a founder financial report, so widen the declaration instead of casting the query.
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.amount_rupees, p.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - p.created_at))/86400.0, 1)::numeric AS age_days
  FROM engineer_payouts p
  WHERE p.processed_at IS NULL
  ORDER BY p.created_at ASC
  LIMIT 200;
END $function$;
REVOKE ALL ON FUNCTION public.rpc_founder_ops_payout_backlog() FROM PUBLIC, anon, authenticated, service_role;

-- rpc_r2699_by_chain -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.rpc_r2699_by_chain();
CREATE OR REPLACE FUNCTION public.rpc_r2699_by_chain()
 -- round3791: widened total_ask_inr and won_inr from bigint to numeric — both are SUM() of the money column ask_value_inr (numeric), so casting them to bigint would silently round paise off a founder revenue report; the declaration was wrong, not the query. meetings/open_commits/blocked_commits are true counts and stay bigint.
 RETURNS TABLE(chain_name text, meetings bigint, total_ask_inr numeric, won_inr numeric, open_commits bigint, blocked_commits bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.chain_name,
         COUNT(*)::bigint,
         COALESCE(SUM(m.ask_value_inr),0),
         COALESCE(SUM(m.ask_value_inr) FILTER (WHERE m.outcome='won'),0),
         (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699 c
            WHERE c.chain_name=m.chain_name AND c.status IN ('open','in_progress'))::bigint,
         (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699 c
            WHERE c.chain_name=m.chain_name AND c.status='blocked')::bigint
  FROM hospital_chain_board_meetings_r2699 m
  GROUP BY m.chain_name
  ORDER BY COALESCE(SUM(m.ask_value_inr),0) DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_r2699_by_chain() FROM PUBLIC, anon, authenticated, service_role;

-- rpc_r2699_by_topic -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.rpc_r2699_by_topic();
CREATE OR REPLACE FUNCTION public.rpc_r2699_by_topic()
 RETURNS TABLE(meeting_topic text, meetings bigint, total_ask_inr numeric, won_pct numeric) -- round3791: col 3 total_ask_inr declared bigint but SUM(ask_value_inr::bigint) yields numeric; this is MONEY (rupee ask value, rendered via fmtInr), so WIDEN the declaration to numeric rather than cast the query -- casting would risk truncation/overflow on a founder financial report
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.meeting_topic,
         COUNT(*)::bigint,
         COALESCE(SUM(m.ask_value_inr),0),
         ROUND(100.0 * COUNT(*) FILTER (WHERE m.outcome='won') / NULLIF(COUNT(*),0), 1)
  FROM hospital_chain_board_meetings_r2699 m
  GROUP BY m.meeting_topic
  ORDER BY COALESCE(SUM(m.ask_value_inr),0) DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_r2699_by_topic() FROM PUBLIC, anon, authenticated, service_role;

-- rpc_r2699_kpis -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.rpc_r2699_kpis();
CREATE OR REPLACE FUNCTION public.rpc_r2699_kpis()
 -- round3791: total_ask_inr / won_ask_inr / progressing_ask_inr widened bigint -> numeric (cols 3,4,5). SUM(ask_value_inr) is numeric (sum of bigint); these are MONEY on a founder financial report, so the declaration is widened rather than the query cast -- ::bigint would silently round rupee/paise precision. Cols 1,2,6,7,8 are count(*) tallies and correctly stay bigint.
 RETURNS TABLE(total_meetings bigint, unique_chains bigint, total_ask_inr numeric, won_ask_inr numeric, progressing_ask_inr numeric, open_commitments bigint, slipped_commitments bigint, next_7_day_followups bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM hospital_chain_board_meetings_r2699),
    (SELECT COUNT(DISTINCT chain_name) FROM hospital_chain_board_meetings_r2699),
    (SELECT COALESCE(SUM(ask_value_inr),0) FROM hospital_chain_board_meetings_r2699),
    (SELECT COALESCE(SUM(ask_value_inr),0) FROM hospital_chain_board_meetings_r2699 WHERE outcome='won'),
    (SELECT COALESCE(SUM(ask_value_inr),0) FROM hospital_chain_board_meetings_r2699 WHERE outcome='progressing'),
    (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699 WHERE status IN ('open','in_progress')),
    (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699 WHERE status='slipped' OR status='blocked'),
    (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699
       WHERE follow_up_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7);
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_r2699_kpis() FROM PUBLIC, anon, authenticated, service_role;

-- topic_kind_breakdown_r2522 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.topic_kind_breakdown_r2522();
CREATE OR REPLACE FUNCTION public.topic_kind_breakdown_r2522()
 RETURNS TABLE(topic_kind text, callback_count bigint, avg_csat numeric, total_upsell_rupees numeric, total_loose_ends bigint) -- round3791: widened total_upsell_rupees bigint->numeric. SUM(bigint) yields numeric; this is a MONEY total on a founder financial report, so casting it down to bigint would silently truncate/overflow rather than report the true rupee sum. Other 4 columns re-checked position-by-position and already match (text/count(*)=bigint/round(avg)=numeric/sum(int)=bigint).
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.topic_kind,
         COUNT(*) AS callback_count,
         ROUND(AVG(c.csat_score) FILTER (WHERE c.success_kind = 'connected'), 2) AS avg_csat,
         COALESCE(SUM(c.upsell_opportunity_rupees), 0) AS total_upsell_rupees,
         COALESCE(SUM(c.loose_ends_count), 0) AS total_loose_ends
  FROM public.engineer_post_visit_callbacks_r2522 c
  GROUP BY c.topic_kind
  ORDER BY callback_count DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.topic_kind_breakdown_r2522() FROM PUBLIC, anon, authenticated, service_role;

-- top_callback_engineers_r2522 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.top_callback_engineers_r2522();
CREATE OR REPLACE FUNCTION public.top_callback_engineers_r2522()
 RETURNS TABLE(engineer_user_id uuid, owner_email text, callback_count bigint, connected_count bigint, avg_csat numeric, total_upsell_rupees numeric, total_loose_ends bigint) -- round3791: col 6 total_upsell_rupees widened bigint -> numeric; SUM(upsell_opportunity_rupees) is SUM(bigint) which returns numeric, and this is MONEY (rupees on a founder financial report), so widening the declaration is safe where an ::bigint cast would risk silent precision/overflow loss. Cols 1-5 and 7 were walked position-by-position and already match.
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_user_id,
         c.owner_email,
         COUNT(*) AS callback_count,
         COUNT(*) FILTER (WHERE c.success_kind = 'connected') AS connected_count,
         ROUND(AVG(c.csat_score) FILTER (WHERE c.success_kind = 'connected'), 2) AS avg_csat,
         COALESCE(SUM(c.upsell_opportunity_rupees), 0) AS total_upsell_rupees,
         COALESCE(SUM(c.loose_ends_count), 0) AS total_loose_ends
  FROM public.engineer_post_visit_callbacks_r2522 c
  GROUP BY c.engineer_user_id, c.owner_email
  ORDER BY callback_count DESC, avg_csat DESC NULLS LAST;
END;
$function$;
REVOKE ALL ON FUNCTION public.top_callback_engineers_r2522() FROM PUBLIC, anon, authenticated, service_role;

-- top_pairing_focus_r2662 -- declared type change, so DROP first (42P13 otherwise)
DROP FUNCTION IF EXISTS public.top_pairing_focus_r2662();
CREATE OR REPLACE FUNCTION public.top_pairing_focus_r2662()
 RETURNS TABLE(pairing_id uuid, knowledge_transfer_kind text, retention_signal text, status text, days_paired integer, outcome_count bigint, total_revenue_impact numeric) -- round3791: widened total_revenue_impact from bigint to numeric -- it is MONEY (sum of revenue_impact_rupees), sum() yields numeric, and casting the query column to bigint would silently round a founder revenue figure
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.id as pairing_id,
           b.knowledge_transfer_kind,
           b.retention_signal,
           b.status,
           b.days_paired,
           count(o.id) as outcome_count,
           coalesce(sum(o.revenue_impact_rupees), 0) as total_revenue_impact
    from public.engineer_onboarding_buddies_r2662 b
    left join public.buddy_program_outcomes_r2662 o on o.pairing_id = b.id
    group by b.id, b.knowledge_transfer_kind, b.retention_signal, b.status, b.days_paired
    order by total_revenue_impact desc, outcome_count desc
    limit 25;
end;
$function$;
REVOKE ALL ON FUNCTION public.top_pairing_focus_r2662() FROM PUBLIC, anon, authenticated, service_role;

-- Replay exactly the grants each recreated function had before.
DO $regrant$
DECLARE r record; v_n int := 0;
BEGIN
  FOR r IN
    SELECT a.proname, a.args, a.grantee, a.priv
      FROM _r3791_acl a
     WHERE a.proname = ANY(ARRAY[
    'brand_equity_pulse_kpis_r2781',
    'founder_biomed_by_hospital_r2235',
    'founder_biomed_departure_reasons_r2235',
    'founder_hospital_xsell_by_product',
    'founder_hospital_xsell_overview',
    'founder_hospital_xsell_top_hospitals',
    'founder_hpbi_pipeline_by_status',
    'founder_lost_deal_kpis_v2',
    'founder_peer_stage_distribution',
    'founder_podcast_pipeline_summary',
    'founder_pricing_by_quarter_r2833',
    'founder_pricing_kpi_summary_r2833',
    'founder_r2819_kpis',
    'founder_r2971_spend_forecast',
    'founder_r2971_vendor_concentration',
    'founder_site_visit_outcomes_by_kind',
    'fsbca_r2369_by_category',
    'fsbca_r2369_summary',
    'owner_load_r2662',
    'r2691_kpi_summary',
    'recent_actions_night_shift_r2222',
    'recent_actions_nps_r2216',
    'recent_actions_r2202',
    'recent_actions_r2209',
    'recent_actions_reference_r2220',
    'rpc_founder_ops_payout_backlog',
    'rpc_r2699_by_chain',
    'rpc_r2699_by_topic',
    'rpc_r2699_kpis',
    'topic_kind_breakdown_r2522',
    'top_callback_engineers_r2522',
    'top_pairing_focus_r2662'
  ])
       AND a.grantee NOT IN ('PUBLIC', '-')
  LOOP
    EXECUTE format('GRANT %s ON FUNCTION public.%I(%s) TO %I', r.priv, r.proname, r.args, r.grantee);
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'round 3791: replayed % grant(s) onto the recreated function(s)', v_n;
END
$regrant$;

-- ---------------------------------------------------------------------
-- Gate
-- ---------------------------------------------------------------------
DO $gate$
DECLARE
  v_names        text[] := ARRAY[
    'dr_detector_pixel_defect_severity_map_r3132',
    'founder_409a_summary_kpis',
    'founder_amc_base_growth',
    'founder_amc_revenue_cumulative',
    'founder_audit_by_actor',
    'founder_chain_leader_kpi_r2751',
    'founder_churn_save_roi_kpis',
    'founder_clv_calculator_summary',
    'founder_code_red_cumulative',
    'founder_code_red_recent',
    'founder_demand_signals_cumulative',
    'founder_disputes_cumulative',
    'founder_dispute_kpis',
    'founder_engineer_ltv_ranked',
    'founder_engineer_specialization_coverage',
    'founder_fleet_red_flags',
    'founder_gmv_by_equipment_type',
    'founder_gmv_cumulative',
    'founder_grants_audit',
    'founder_hospital_department_breakout_summary',
    'founder_investor_channel_mix',
    'founder_investor_sla_summary',
    'founder_ipu_benchmark',
    'founder_ipu_kpis',
    'founder_kyc_renewal_queue',
    'founder_list_hospital_chains',
    'founder_loi_active_list',
    'founder_ma_pipeline_summary',
    'founder_open_collusion_flags',
    'founder_open_duplicate_flags',
    'founder_pending_kyc_list',
    'founder_pending_refund_authorizations',
    'founder_pm_overdue_summary',
    'founder_pricing_by_tier_r2833',
    'founder_referrals_cumulative',
    'founder_repair_jobs_status',
    'founder_risk_score_snapshots_summary',
    'founder_risk_top_n',
    'founder_signups_cumulative',
    'founder_site_visit_recent_completed',
    'founder_site_visit_upcoming',
    'founder_spot_audits_cumulative',
    'founder_supervised_cumulative',
    'founder_suspicious_attendance_recent',
    'founder_tds_quarterly_summary',
    'founder_tier_changes_cumulative',
    'founder_unmatched_jobs_7d',
    'founder_verified_engineer_growth',
    'founder_voice_inbox_r2362',
    'founder_voice_top_voters_r2362',
    'founder_wellbeing_engineer_trend',
    'founder_wellbeing_recent_responses',
    'founder_wellbeing_red_flags',
    'r1693_vesting_summary',
    'sla_breach_summary_r2352',
    'brand_equity_pulse_kpis_r2781',
    'founder_biomed_by_hospital_r2235',
    'founder_biomed_departure_reasons_r2235',
    'founder_hospital_xsell_by_product',
    'founder_hospital_xsell_overview',
    'founder_hospital_xsell_top_hospitals',
    'founder_hpbi_pipeline_by_status',
    'founder_lost_deal_kpis_v2',
    'founder_peer_stage_distribution',
    'founder_podcast_pipeline_summary',
    'founder_pricing_by_quarter_r2833',
    'founder_pricing_kpi_summary_r2833',
    'founder_r2819_kpis',
    'founder_r2971_spend_forecast',
    'founder_r2971_vendor_concentration',
    'founder_site_visit_outcomes_by_kind',
    'fsbca_r2369_by_category',
    'fsbca_r2369_summary',
    'owner_load_r2662',
    'r2691_kpi_summary',
    'recent_actions_night_shift_r2222',
    'recent_actions_nps_r2216',
    'recent_actions_r2202',
    'recent_actions_r2209',
    'recent_actions_reference_r2220',
    'rpc_founder_ops_payout_backlog',
    'rpc_r2699_by_chain',
    'rpc_r2699_by_topic',
    'rpc_r2699_kpis',
    'topic_kind_breakdown_r2522',
    'top_callback_engineers_r2522',
    'top_pairing_focus_r2662'
  ];
  v_missing      text;
  v_argdrift     text;
  v_namedrift    text;
  v_acldrift     text;
  v_publicexec   text;
  v_broken_after int;
  v_targeted     int;
  v_has_check    boolean;
BEGIN
  SELECT count(DISTINCT x) INTO v_targeted FROM unnest(v_names) x;

  SELECT string_agg(x, ', ') INTO v_missing
    FROM unnest(v_names) x
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname = x);
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'round 3791 VERIFY FAILED: function(s) missing after apply: %', v_missing;
  END IF;

  SELECT string_agg(b.proname, ', ') INTO v_argdrift
    FROM _r3791_before b
    JOIN pg_proc p ON p.pronamespace='public'::regnamespace AND p.proname = b.proname
   WHERE pg_get_function_identity_arguments(p.oid) IS DISTINCT FROM b.args;
  IF v_argdrift IS NOT NULL THEN
    RAISE EXCEPTION 'round 3791 VERIFY FAILED: argument list changed for: %', v_argdrift;
  END IF;

  SELECT string_agg(b.proname, ', ') INTO v_namedrift
    FROM _r3791_before b
    JOIN pg_proc p ON p.pronamespace='public'::regnamespace AND p.proname = b.proname
    CROSS JOIN LATERAL (
      SELECT string_agg(nm, ',' ORDER BY ord) AS outnames
        FROM unnest(p.proargnames, p.proargmodes) WITH ORDINALITY AS u(nm, md, ord)
       WHERE md='t') nowout
   WHERE nowout.outnames IS DISTINCT FROM b.outnames;
  IF v_namedrift IS NOT NULL THEN
    RAISE EXCEPTION 'round 3791 VERIFY FAILED: OUT column names/order changed for: %', v_namedrift;
  END IF;

  -- ACL must match what was captured, in both directions.
  WITH nowacl AS (
    SELECT p.proname, a.grantee::regrole::text AS grantee, a.privilege_type AS priv
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
  ), diff AS (
    SELECT proname FROM (
      SELECT proname, grantee, priv FROM nowacl
      EXCEPT SELECT proname, grantee, priv FROM _r3791_acl
      UNION ALL
      SELECT proname, grantee, priv FROM _r3791_acl
      EXCEPT SELECT proname, grantee, priv FROM nowacl
    ) d
  )
  SELECT string_agg(DISTINCT proname, ', ') INTO v_acldrift FROM diff;
  IF v_acldrift IS NOT NULL THEN
    RAISE EXCEPTION 'round 3791 VERIFY FAILED: EXECUTE grants differ from the captured set for: %', v_acldrift;
  END IF;

  -- Belt and braces: nothing newly executable by PUBLIC/anon.
  SELECT string_agg(DISTINCT p.proname, ', ') INTO v_publicexec
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
     AND (has_function_privilege('anon', p.oid, 'EXECUTE')
          OR has_function_privilege('public', p.oid, 'EXECUTE'))
     AND NOT EXISTS (
       SELECT 1 FROM _r3791_acl a
        WHERE a.proname = p.proname AND a.grantee IN ('anon','PUBLIC','-') AND a.priv='EXECUTE');
  IF v_publicexec IS NOT NULL THEN
    RAISE EXCEPTION 'round 3791 VERIFY FAILED: newly EXECUTE-able by PUBLIC/anon: %', v_publicexec;
  END IF;

  RAISE NOTICE 'round 3791: contract intact for all % function(s) (args, OUT names, ACL)', v_targeted;

  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname='plpgsql_check') INTO v_has_check;
  IF v_has_check THEN
    SELECT count(DISTINCT p.proname) INTO v_broken_after
      FROM pg_proc p
      CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names) AND e.level='error';
    RAISE NOTICE 'round 3791: still-broken among the % touched: %', v_targeted, v_broken_after;
    IF v_broken_after >= v_targeted THEN
      RAISE EXCEPTION 'round 3791 VERIFY FAILED: nothing got fixed (% of % still broken)', v_broken_after, v_targeted;
    END IF;
  ELSE
    RAISE NOTICE 'round 3791: plpgsql_check absent -- relied on the contract assertions only';
  END IF;

  RAISE NOTICE 'round 3791 verified: 42804 type-mismatch class repaired';
END
$gate$;

COMMIT;
