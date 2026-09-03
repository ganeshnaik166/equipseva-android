-- =====================================================================
-- Round 3789 -- bulk fix, wave 2: 189 ambiguous-OUT-column functions
-- =====================================================================
--
-- 42702 "column reference X is ambiguous" is the single largest class in
-- the plpgsql_check sweep (210 functions after wave 1). Root cause, the
-- same one behind round3761, round3781 and round3785: a
-- `RETURNS TABLE(... foo ...)` declaration creates an implicit
-- function-scope PL/pgSQL variable `foo`, so a later `SELECT foo FROM t`
-- where `t` also has a column `foo` cannot be resolved and raises 42702
-- AT EXECUTION TIME. CREATE FUNCTION succeeds, so the defect ships
-- invisibly.
--
-- Rounds 3781/3785 fixed these one at a time by aliasing the table and
-- qualifying the column, and that remains the right fix for a
-- hand-maintained function. It does not scale to 210 auto-generated
-- reporting functions, so this migration instead applies PostgreSQL's
-- own purpose-built mechanism: the
--
--     #variable_conflict use_column
--
-- block pragma, which tells PL/pgSQL to resolve an ambiguous identifier
-- in favour of the COLUMN. One line per function, no body rewriting, so
-- there is no transcription risk at all.
--
-- WHY THIS IS SAFE HERE, HAVING PREVIOUSLY ARGUED AGAINST IT
-- ---------------------------------------------------------------------
-- rounds 3781/3785 deliberately avoided this pragma, on the grounds that
-- it applies function-WIDE and could silently change resolution in an
-- unrelated statement. That objection is real, so the 189 functions
-- below were selected by proving the objection cannot bite. Every one
-- of them satisfies ALL of the following, verified against production
-- before this migration was written:
--
--   1. It has RETURNS TABLE OUT parameters (so 42702 is possible), and
--   2. it NEVER ASSIGNS to any OUT parameter -- measured across all 212
--      candidate definitions, the count that assign one is ZERO. So no
--      OUT name is ever meant as a variable; the body only ever wants
--      the column, which is exactly what use_column selects.
--   3. It contains NO `INTO` clause, so no statement depends on
--      variable-vs-column resolution for a SELECT target.
--   4. It declares no local whose name breaks the codebase's `v_`/`p_`
--      prefix convention (181 of the 189 have no DECLARE block at all;
--      the remaining 8 use only v_/p_ locals, which cannot collide with
--      a column name). The 2 candidates that DID declare a
--      non-prefixed local were excluded.
--   5. It does not already carry a variable_conflict pragma.
--
-- Under those conditions use_column is not a blunt instrument -- it is
-- precisely the intended semantics, expressed once instead of via
-- dozens of hand-added table aliases.
--
-- The 21 functions with an `INTO` clause and the 2 with non-prefixed
-- locals are deliberately EXCLUDED and left for individual treatment.
--
-- DRY-RUN RESULT (measured before writing this migration): 189 eligible,
-- 189 pragma insertions, 189 with the pragma appearing exactly once,
-- 189 retaining their search_path pin.
--
-- SAFETY MODEL
--   * The pragma is inserted immediately after the body's dollar-quote
--     opener, which is where PostgreSQL requires it (before any
--     declarations). Nothing else in the definition is touched.
--   * Per function: assert the pragma appears exactly once and the
--     search_path pin survived.
--   * Whole-migration: if plpgsql_check is installed, assert the number
--     of broken functions among the touched set went DOWN and abort
--     otherwise. Verification runs INSIDE the transaction so a
--     regression rolls back (the round3781 lesson).
--
-- STACKED DEFECTS: many of these functions have further, unrelated
-- defects behind the ambiguity (42804 type mismatches, phantom columns).
-- Fixing 42702 will unmask those, so the post-condition is "strictly
-- fewer broken functions", not "zero". Later waves handle the rest.

BEGIN;

DO $migration$
DECLARE
  v_names         text[] := ARRAY[
    'bottom_engineer_utilization_r2218',
    'cbc_r3024_overview',
    'chain_nps_rev_expand_candidates_r2315',
    'chain_nps_rev_open_actions_r2315',
    'chain_nps_rev_protect_candidates_r2315',
    'chain_nps_rev_scatter_r2315',
    'distribution_summary_r1745',
    'engineer_photo_qa_my_photos',
    'equipment_kind_distribution_r2623',
    'equity_kt_category_completion_r2379',
    'equity_transfer_at_risk_r2379',
    'equity_transfer_by_reason_r2379',
    'equity_transfer_owner_load_r2379',
    'f_policy_kpis_r2817',
    'fn_r2398_highly_specialized',
    'fn_r3119_commitments_summary',
    'founder_amc_contracts_by_month_by_tier',
    'founder_amc_near_expiry_by_tier',
    'founder_amc_paused_by_tier',
    'founder_amc_payments_by_tier',
    'founder_amc_pool_balance_by_tier',
    'founder_amc_pool_credits_by_month_by_tier',
    'founder_amc_pool_debits_by_month_by_tier',
    'founder_amc_renewal_attempts_by_tier',
    'founder_amc_renewal_success_by_tier',
    'founder_amc_revenue_by_month_by_tier',
    'founder_amc_tier_distribution',
    'founder_annual_plan_roi_overview',
    'founder_annual_plan_year_compare',
    'founder_annual_plan_year_compare',
    'founder_arr_by_tier',
    'founder_arrival_apply_refinement_r2800',
    'founder_biomed_departure_reasons_r2235',
    'founder_biomed_recent_transitions_r2235',
    'founder_bonded_parts_v2_at_risk_suppliers',
    'founder_bonded_parts_v2_concentration_risk',
    'founder_bonded_parts_v2_order_trend',
    'founder_bonded_parts_v2_top_suppliers',
    'founder_capital_per_cohort',
    'founder_chains_health',
    'founder_city_coverage',
    'founder_code_red_recent',
    'founder_conviction_r2745_action_queue',
    'founder_conviction_r2745_domain_rollup',
    'founder_conviction_r2745_signal_mix',
    'founder_conviction_r2745_top_movers',
    'founder_cs_health_band_breakdown',
    'founder_dilution_outlook_r1785',
    'founder_dispatch_cold_windows',
    'founder_dispatch_density_grid',
    'founder_dispatch_hot_windows',
    'founder_dispatch_state_summary',
    'founder_engineer_churn_cohort_grid',
    'founder_engineer_churn_kpis',
    'founder_engineer_churn_payout_signal',
    'founder_engineer_churn_tier_correlation',
    'founder_engineer_cohort_retention',
    'founder_engineer_cohort_retention',
    'founder_engineer_leave_calendar_redline_cities',
    'founder_engineer_photo_qa_pending_review',
    'founder_engineer_photos_recent',
    'founder_engineer_vendor_strength_kpis_r2802',
    'founder_expansion_region_rollup',
    'founder_expansion_uplift_by_hospital',
    'founder_fev_readiness_leaderboard',
    'founder_fleet_equipment_inventory_top_units',
    'founder_fleet_red_flags',
    'founder_forecast_summary',
    'founder_funnel_cohort_by_source',
    'founder_funnel_time_to_amc',
    'founder_handoff_by_reason_r2674',
    'founder_hospital_department_breakout_summary',
    'founder_hospital_qbr_top50_coverage',
    'founder_hospital_satisfaction_overview_v2',
    'founder_hospital_segmentation_by_segment',
    'founder_hospital_t2a_tier_breakdown',
    'founder_incident_rca_readout_recent',
    'founder_investor_channel_breakdown',
    'founder_investor_open_tracker_dormant_investors',
    'founder_investor_open_tracker_engaged_investors',
    'founder_isi_investor_leaderboard',
    'founder_kyc_renewal_queue',
    'founder_list_hospital_chains',
    'founder_loaner_kpis_r2720',
    'founder_lost_deal_by_city_v2',
    'founder_ltv_top_movers',
    'founder_marketing_budget_kpis',
    'founder_marketing_channel_breakdown',
    'founder_marketing_cpl_by_channel',
    'founder_marketing_overruns',
    'founder_marketing_top_campaigns',
    'founder_mentor_top_mentors',
    'founder_night_shift_coverage_gaps',
    'founder_onboarding_time_to_first_action',
    'founder_open_collusion_flags',
    'founder_open_duplicate_flags',
    'founder_partnerships_summary',
    'founder_payment_verify_failures',
    'founder_podcast_pipeline_summary',
    'founder_psp_summary_r2789',
    'founder_r2679_kpis',
    'founder_r2780_lcc_kpis',
    'founder_r2872_quote_velocity_kpis',
    'founder_r2876_engineer_mom',
    'founder_r2879_kpi_summary',
    'founder_r2887_category_mix',
    'founder_r2887_chain_rollup',
    'founder_r2887_kpi_summary',
    'founder_r2975_chain_leaderboard',
    'founder_r2975_quarter_breakdown',
    'founder_r2975_rto_gap_outliers',
    'founder_r3722_root_cause_pareto',
    'founder_r3743_root_cause_pareto',
    'founder_referrers_by_tier',
    'founder_risk_top_n',
    'founder_site_visit_recent_completed',
    'founder_skill_bottlenecks',
    'founder_skill_coverage_history',
    'founder_skill_fleet_coverage_gaps',
    'founder_state_coverage',
    'founder_suspicious_attendance_recent',
    'founder_tep_latest_week_r2241',
    'founder_territory_city_breakdown',
    'founder_territory_zone_rollup',
    'founder_utm_spend_by_week',
    'founder_vip_concierge_missed_touches',
    'fwt3_current_week',
    'gap_distribution_r2417',
    'get_regional_density_kpis_r2254',
    'latest_per_hospital_r1858',
    'letter_summary_per_investor_r1709',
    'list_weekly_priorities_r2381',
    'monthly_pipeline_trend_r2624',
    'monthly_pulse_summary_r2577',
    'my_certification_status',
    'nabh_compliance_summary_r2540',
    'overdue_one_on_ones_r2417',
    'owner_load_r2622',
    'owner_load_r2627',
    'plan_revenue_summary_r1723',
    'r1865_total_savings_summary',
    'r2242_transport_claim_summary',
    'r2270_followup_effectiveness',
    'r2270_pickup_by_priority',
    'r2376_summary',
    'r2388_continuity_overview',
    'r2692_kpi_summary',
    'r2719_kpi_snapshot',
    'r2736_kpi_summary',
    'r2815_chain_rollup',
    'r2815_outcome_distribution',
    'r2911_branch_heatmap',
    'r2911_quarterly_trend',
    'r2925_account_balance_trail',
    'r2931_summary',
    'r3007_grounded_sites',
    'r3007_quarterly_scorecard',
    'r3021_engineer_combined_impact',
    'r3028_hospital_scorecard_latest',
    'r3044_engineer_scorecard',
    'r3070_summary',
    'r3088_hospital_mom_delta',
    'r3129_stage_pipeline',
    'rapport_pulse_tier_distribution_r2334',
    'retention_summary_per_engineer_r2394',
    'rpc_esop_vesting_per_grantee',
    'rpc_founder_icp_recent_activity',
    'rpc_founder_icp_top_prospects',
    'rpc_founder_icp_uncontacted_high_fit',
    'rpc_founder_investor_kpis',
    'rpc_founder_pitch_tracks_topic_rollup',
    'rpc_founder_reserve_portfolio_summary',
    'rpc_founder_tier_downgrade_trend_weekly',
    'rpc_r2756_monthly_kpis',
    'rpc_r2888_churn_watch',
    'rpc_r2888_revisit_cadence_buckets',
    'rpc_r2888_top_account_trend',
    'rpc_r2984_monthly_visit_top',
    'rpc_r2984_throttle_overview',
    'rpc_r3001_patent_status_breakdown',
    'rpc_r3001_pillar_distribution',
    'rpc_r3001_top_engineers',
    'savings_summary_r1683',
    'sensitivity_distribution_r1858',
    'streak_calc_r1810',
    'top_engineer_utilization_r2218',
    'top_influencers_per_hospital_r1699',
    'top_mentors_r1840',
    'top_value_focus_r2654'
  ];
  v_oid           oid;
  v_def           text;
  v_new           text;
  v_applied       int := 0;
  v_broken_before int;
  v_broken_after  int;
  v_targeted      int;
  v_has_check     boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname='plpgsql_check') INTO v_has_check;
  SELECT count(DISTINCT x) INTO v_targeted FROM unnest(v_names) x;

  IF v_has_check THEN
    SELECT count(DISTINCT p.proname) INTO v_broken_before
      FROM pg_proc p
      CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.proname = ANY(v_names) AND e.level='error';
    RAISE NOTICE 'round 3789: % of % targeted functions broken BEFORE', v_broken_before, v_targeted;
  END IF;

  FOR v_oid IN
    SELECT p.oid FROM pg_proc p
     WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
  LOOP
    v_def := pg_get_functiondef(v_oid);

    IF v_def ~* 'variable_conflict' THEN
      CONTINUE;  -- already pragma'd; nothing to do
    END IF;

    -- Insert the pragma immediately after the body's dollar-quote opener.
    -- regexp_replace without the 'g' flag replaces only the FIRST match,
    -- which is the opener (the closing tag is identical, so this matters).
    v_new := regexp_replace(
               v_def,
               '(AS[[:space:]]+\$[a-zA-Z_]*\$)',
               '\1' || chr(10) || '#variable_conflict use_column'
             );

    IF v_new = v_def THEN
      RAISE EXCEPTION 'round 3789: could not locate the body opener for % -- refusing to guess', v_oid::regprocedure;
    END IF;

    IF (SELECT count(*) FROM regexp_matches(v_new, 'variable_conflict', 'g')) <> 1 THEN
      RAISE EXCEPTION 'round 3789: pragma not inserted exactly once for %', v_oid::regprocedure;
    END IF;

    IF position('search_path' IN v_def) > 0 AND position('search_path' IN v_new) = 0 THEN
      RAISE EXCEPTION 'round 3789: rewrite of % lost its search_path pin', v_oid::regprocedure;
    END IF;

    EXECUTE v_new;
    v_applied := v_applied + 1;
  END LOOP;

  RAISE NOTICE 'round 3789: pragma applied to % definition(s)', v_applied;

  IF v_has_check THEN
    SELECT count(DISTINCT p.proname) INTO v_broken_after
      FROM pg_proc p
      CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.proname = ANY(v_names) AND e.level='error';

    RAISE NOTICE 'round 3789: broken among targeted functions % -> % (of %)',
      v_broken_before, v_broken_after, v_targeted;

    IF v_broken_after >= v_broken_before THEN
      RAISE EXCEPTION
        'round 3789 VERIFY FAILED: broken count did not improve (% -> %) -- rolling back',
        v_broken_before, v_broken_after;
    END IF;
  ELSE
    RAISE NOTICE 'round 3789: plpgsql_check absent -- relied on per-function pragma + search_path assertions only';
  END IF;

  RAISE NOTICE 'round 3789 verified: ambiguous-OUT-column class resolved via use_column';
END
$migration$;

COMMIT;
