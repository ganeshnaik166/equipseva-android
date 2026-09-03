-- =====================================================================
-- Round 3788 -- bulk fix, wave 1: the four largest shared root causes
-- =====================================================================
--
-- The plpgsql_check sweep behind round3780-3785 found 576 statically
-- broken plpgsql functions spanning 260 distinct root messages. Rather
-- than patch them one at a time, this migration attacks the four
-- LARGEST SHARED root causes, where one well-scoped transformation
-- correctly fixes every member of the class.
--
-- 64 function names (67 definitions, counting overloads) are rewritten.
--
-- EVERY transformation WAS DRY-RUN AGAINST PRODUCTION FIRST -- computing
-- the rewritten definition and counting occurrences without executing
-- anything -- and each class's notes below record what that dry run
-- measured. The dry-run discipline earned its keep immediately: a naive
-- blanket replace of 'hospital' would have corrupted two
-- semantically-unrelated comparisons (see class A).
--
-- SAFETY MODEL
--   * Definitions come from pg_get_functiondef(), which reproduces the
--     signature, return type, volatility, SECURITY DEFINER flag and the
--     search_path pin verbatim. Only the targeted literal changes.
--   * Per function: assert the search_path pin survived the rewrite.
--   * Whole-migration: if plpgsql_check is installed, assert the number
--     of broken functions among the touched set went DOWN. Verification
--     runs INSIDE the transaction, so a regression rolls everything
--     back -- the lesson from round3781, which verified after COMMIT and
--     left production half-fixed with the migration unrecorded.
--   * plpgsql_check is a diagnostic extension installed only for this
--     sweep, so the check degrades gracefully if it is absent at replay.
--
-- NOTE ON STACKED DEFECTS: several of these functions carry MORE than
-- one defect (as profitability_for_repair_bid and investor_share_v2 did,
-- with three each). Fixing this class will unmask the next error in
-- some of them, so the post-condition is deliberately "strictly fewer
-- broken functions", NOT "zero". Later waves handle the remainder.

BEGIN;

DO $migration$
DECLARE
  v_names         text[];
  v_pats          text[];
  v_reps          text[];
  v_class         text;
  v_label         text;
  v_oid           oid;
  v_def           text;
  v_new           text;
  v_i             int;
  v_rewritten     int;
  v_occ           int;
  v_all_names     text[] := ARRAY[]::text[];
  v_broken_before int;
  v_broken_after  int;
  v_targeted      int;
  v_has_check     boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname='plpgsql_check') INTO v_has_check;

  v_all_names := v_all_names || ARRAY[
    'founder_city_coverage',
    'founder_demand_quality_summary',
    'founder_hospital_amc_coverage_by_city',
    'founder_hospital_cohort_retention',
    'founder_hospital_loyalty_funnel',
    'founder_hospital_onboarding_funnel',
    'founder_hospital_recency',
    'founder_hospital_retention_cohort',
    'founder_hospitals_no_jobs_30d',
    'founder_hospitals_snapshot_summary',
    'founder_hospitals_with_no_amc',
    'founder_jobs_by_state',
    'founder_morning_pulse_v2',
    'founder_onboarding_time_to_first_action',
    'founder_signups_by_hour_7d',
    'founder_signups_by_month_by_role',
    'founder_signups_by_role_30d',
    'founder_signups_by_state',
    'founder_signups_by_week_13wk',
    'founder_signups_first_action_rate_by_week',
    'founder_signups_funnel_snapshot_summary',
    'founder_state_coverage',
    'founder_trust_pulse_summary',
    'r1703_hospitals_without_cluster'
  ];
  v_all_names := v_all_names || ARRAY[
    'exec_360_v3_capital_kpis',
    'founder_eng6mo_refresh_snapshots',
    'founder_engineer_churn_at_risk_list',
    'founder_engineer_churn_payout_signal',
    'founder_engineer_pnl_v2_kpis',
    'founder_engineer_wage_arrears_scan',
    'founder_forecast_current_state',
    'founder_night_shift_reconciliation',
    'founder_payout_cadence_capture',
    'founder_payout_cadence_kpis',
    'founder_payout_cadence_roster',
    'founder_promotion_review_scorecard',
    'founder_recompute_engineer_cohorts',
    'rpc_founder_exit_iv_record',
    'rpc_founder_ops_payout_backlog'
  ];
  v_all_names := v_all_names || ARRAY[
    'founder_bonded_parts_supply_chain_v2_summary',
    'founder_spare_part_order_funnel_30d',
    'founder_spare_part_orders_by_day_30d',
    'founder_spare_part_orders_by_week_13wk',
    'founder_spare_parts_by_supplier_30d',
    'founder_spare_parts_delivery_rate_by_week',
    'founder_spare_parts_revenue_by_month'
  ];
  v_all_names := v_all_names || ARRAY[
    'founder_action_center',
    'founder_cart_abandonment_summary',
    'founder_critical_actions',
    'founder_critical_cockpit',
    'founder_cumulative_rollup_summary',
    'founder_investor_pulse_summary',
    'founder_money_in_flight_summary',
    'founder_monthly_revenue_summary',
    'founder_razorpay_payments_pulse_summary',
    'founder_runway_burn_summary',
    'founder_runway_forecast_v2_summary',
    'founder_spare_parts_by_month_by_status',
    'founder_spare_parts_demand_forecast_summary',
    'founder_spare_parts_snapshot_summary',
    'founder_spare_parts_stuck_aging',
    'founder_vendor_payables_by_supplier',
    'founder_vendor_payables_summary',
    'founder_weekly_revenue_summary'
  ];

  SELECT count(DISTINCT x) INTO v_targeted FROM unnest(v_all_names) x;

  IF v_has_check THEN
    SELECT count(DISTINCT p.proname) INTO v_broken_before
      FROM pg_proc p
      CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.proname = ANY(v_all_names)
       AND e.level='error';
    RAISE NOTICE 'round 3788: % of % targeted functions broken BEFORE', v_broken_before, v_targeted;
  END IF;

  -- ===================================================================
  -- CLASS A -- user_role label hospital -> hospital_admin
  -- ===================================================================
  -- user_role's real labels are hospital_admin, engineer, manufacturer, supplier, logistics, admin. 'hospital' is not one of them, so every comparison against it raised 22P02 at execution time.
  --
  -- 1 occurrence is INTENTIONALLY left untouched: `organizations.kind = 'hospital'`. That is a DIFFERENT defect (organizations has a `type` column, not `kind`) belonging to the 42703 class, and 'hospital' is plausibly a valid value of it. A naive blanket replace of 'hospital' would have corrupted this and one other unrelated comparison -- which is exactly what the dry run caught.
  v_class := 'A';
  v_label := 'user_role label hospital -> hospital_admin';
  v_names := ARRAY[
    'founder_city_coverage',
    'founder_demand_quality_summary',
    'founder_hospital_amc_coverage_by_city',
    'founder_hospital_cohort_retention',
    'founder_hospital_loyalty_funnel',
    'founder_hospital_onboarding_funnel',
    'founder_hospital_recency',
    'founder_hospital_retention_cohort',
    'founder_hospitals_no_jobs_30d',
    'founder_hospitals_snapshot_summary',
    'founder_hospitals_with_no_amc',
    'founder_jobs_by_state',
    'founder_morning_pulse_v2',
    'founder_onboarding_time_to_first_action',
    'founder_signups_by_hour_7d',
    'founder_signups_by_month_by_role',
    'founder_signups_by_role_30d',
    'founder_signups_by_state',
    'founder_signups_by_week_13wk',
    'founder_signups_first_action_rate_by_week',
    'founder_signups_funnel_snapshot_summary',
    'founder_state_coverage',
    'founder_trust_pulse_summary',
    'r1703_hospitals_without_cluster'
  ];
  v_pats  := ARRAY['(role[[:space:]]*(=|<>|!=)[[:space:]]*)''hospital''', '((engineer|admin|manufacturer|supplier|logistics|hospital_admin)''[[:space:]]*,[[:space:]]*)''hospital''', '''hospital''([[:space:]]*,[[:space:]]*''(engineer|admin|manufacturer|supplier|logistics|hospital_admin)'')', '(WHEN[[:space:]]*)''hospital'''];
  v_reps  := ARRAY['\1''hospital_admin''', '\1''hospital_admin''', '''hospital_admin''\1', '\1''hospital_admin'''];
  v_rewritten := 0;

  SELECT coalesce(sum((SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), v_pats[1], 'g'))), 0)
    INTO v_occ
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names);
  IF v_occ = 0 THEN
    RAISE EXCEPTION 'round 3788 class %: found 0 occurrences of the class pattern -- inventory is stale, refusing to proceed', v_class;
  END IF;

  FOR v_oid IN
    SELECT p.oid FROM pg_proc p
     WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
  LOOP
    v_def := pg_get_functiondef(v_oid);
    v_new := v_def;
    FOR v_i IN 1 .. array_length(v_pats, 1) LOOP
      v_new := regexp_replace(v_new, v_pats[v_i], v_reps[v_i], 'g');
    END LOOP;

    IF v_new <> v_def THEN
      IF position('search_path' IN v_def) > 0 AND position('search_path' IN v_new) = 0 THEN
        RAISE EXCEPTION 'round 3788 class %: rewrite of % lost its search_path pin', v_class, v_oid::regprocedure;
      END IF;
      EXECUTE v_new;
      v_rewritten := v_rewritten + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'round 3788 class % (%): % occurrence(s), % definition(s) rewritten', v_class, v_label, v_occ, v_rewritten;

  -- ===================================================================
  -- CLASS B -- engineer_payouts.paid_at -> processed_at
  -- ===================================================================
  -- engineer_payouts has no paid_at column. Its completion timestamp is processed_at (real columns: queued_at, last_attempt_at, processed_at, created_at, updated_at).
  --
  -- Verified before applying: all 15 of these functions reference engineer_payouts and NONE reference amc_payment_orders -- so there is no risk of rewriting the amc_payment_orders.paid_at column that round3784 legitimately added.
  v_class := 'B';
  v_label := 'engineer_payouts.paid_at -> processed_at';
  v_names := ARRAY[
    'exec_360_v3_capital_kpis',
    'founder_eng6mo_refresh_snapshots',
    'founder_engineer_churn_at_risk_list',
    'founder_engineer_churn_payout_signal',
    'founder_engineer_pnl_v2_kpis',
    'founder_engineer_wage_arrears_scan',
    'founder_forecast_current_state',
    'founder_night_shift_reconciliation',
    'founder_payout_cadence_capture',
    'founder_payout_cadence_kpis',
    'founder_payout_cadence_roster',
    'founder_promotion_review_scorecard',
    'founder_recompute_engineer_cohorts',
    'rpc_founder_exit_iv_record',
    'rpc_founder_ops_payout_backlog'
  ];
  v_pats  := ARRAY['\mpaid_at\M'];
  v_reps  := ARRAY['processed_at'];
  v_rewritten := 0;

  SELECT coalesce(sum((SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), v_pats[1], 'g'))), 0)
    INTO v_occ
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names);
  IF v_occ = 0 THEN
    RAISE EXCEPTION 'round 3788 class %: found 0 occurrences of the class pattern -- inventory is stale, refusing to proceed', v_class;
  END IF;

  FOR v_oid IN
    SELECT p.oid FROM pg_proc p
     WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
  LOOP
    v_def := pg_get_functiondef(v_oid);
    v_new := v_def;
    FOR v_i IN 1 .. array_length(v_pats, 1) LOOP
      v_new := regexp_replace(v_new, v_pats[v_i], v_reps[v_i], 'g');
    END LOOP;

    IF v_new <> v_def THEN
      IF position('search_path' IN v_def) > 0 AND position('search_path' IN v_new) = 0 THEN
        RAISE EXCEPTION 'round 3788 class %: rewrite of % lost its search_path pin', v_class, v_oid::regprocedure;
      END IF;
      EXECUTE v_new;
      v_rewritten := v_rewritten + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'round 3788 class % (%): % occurrence(s), % definition(s) rewritten', v_class, v_label, v_occ, v_rewritten;

  -- ===================================================================
  -- CLASS C -- payment_status = paid -> completed
  -- ===================================================================
  -- the payment_status enum's labels are pending, completed, refunded, disputed, failed. 'paid' is not one of them; 'completed' is its semantic equivalent.
  --
  -- Verified before applying: across these 7 functions the total number of `'paid'` literals EQUALS the number of `payment_status = 'paid'` comparisons, so no display string is at risk. (The funnel label in founder_spare_part_order_funnel_30d is '2. Paid' with a capital P and does not match.)
  v_class := 'C';
  v_label := 'payment_status = paid -> completed';
  v_names := ARRAY[
    'founder_bonded_parts_supply_chain_v2_summary',
    'founder_spare_part_order_funnel_30d',
    'founder_spare_part_orders_by_day_30d',
    'founder_spare_part_orders_by_week_13wk',
    'founder_spare_parts_by_supplier_30d',
    'founder_spare_parts_delivery_rate_by_week',
    'founder_spare_parts_revenue_by_month'
  ];
  v_pats  := ARRAY['(payment_status[[:space:]]*=[[:space:]]*)''paid'''];
  v_reps  := ARRAY['\1''completed'''];
  v_rewritten := 0;

  SELECT coalesce(sum((SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), v_pats[1], 'g'))), 0)
    INTO v_occ
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names);
  IF v_occ = 0 THEN
    RAISE EXCEPTION 'round 3788 class %: found 0 occurrences of the class pattern -- inventory is stale, refusing to proceed', v_class;
  END IF;

  FOR v_oid IN
    SELECT p.oid FROM pg_proc p
     WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
  LOOP
    v_def := pg_get_functiondef(v_oid);
    v_new := v_def;
    FOR v_i IN 1 .. array_length(v_pats, 1) LOOP
      v_new := regexp_replace(v_new, v_pats[v_i], v_reps[v_i], 'g');
    END LOOP;

    IF v_new <> v_def THEN
      IF position('search_path' IN v_def) > 0 AND position('search_path' IN v_new) = 0 THEN
        RAISE EXCEPTION 'round 3788 class %: rewrite of % lost its search_path pin', v_class, v_oid::regprocedure;
      END IF;
      EXECUTE v_new;
      v_rewritten := v_rewritten + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'round 3788 class % (%): % occurrence(s), % definition(s) rewritten', v_class, v_label, v_occ, v_rewritten;

  -- ===================================================================
  -- CLASS D -- coalesce(payment_status, '') -> coalesce(payment_status::text, '')
  -- ===================================================================
  -- payment_status is an ENUM, so coalesce(payment_status,'') tries to coerce '' into it and raises 22P02. Casting to text first preserves the semantics exactly -- a NULL status did not equal the compared literal before and still does not.
  --
  -- Identical defect to the one fixed by hand in round3784 for investor_share_v2; this is the same pattern across 18 more functions.
  v_class := 'D';
  v_label := 'coalesce(payment_status, '''') -> coalesce(payment_status::text, '''')';
  v_names := ARRAY[
    'founder_action_center',
    'founder_cart_abandonment_summary',
    'founder_critical_actions',
    'founder_critical_cockpit',
    'founder_cumulative_rollup_summary',
    'founder_investor_pulse_summary',
    'founder_money_in_flight_summary',
    'founder_monthly_revenue_summary',
    'founder_razorpay_payments_pulse_summary',
    'founder_runway_burn_summary',
    'founder_runway_forecast_v2_summary',
    'founder_spare_parts_by_month_by_status',
    'founder_spare_parts_demand_forecast_summary',
    'founder_spare_parts_snapshot_summary',
    'founder_spare_parts_stuck_aging',
    'founder_vendor_payables_by_supplier',
    'founder_vendor_payables_summary',
    'founder_weekly_revenue_summary'
  ];
  v_pats  := ARRAY['coalesce\([[:space:]]*([a-z_]*\.?)payment_status[[:space:]]*,'];
  v_reps  := ARRAY['coalesce(\1payment_status::text,'];
  v_rewritten := 0;

  SELECT coalesce(sum((SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), v_pats[1], 'g'))), 0)
    INTO v_occ
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names);
  IF v_occ = 0 THEN
    RAISE EXCEPTION 'round 3788 class %: found 0 occurrences of the class pattern -- inventory is stale, refusing to proceed', v_class;
  END IF;

  FOR v_oid IN
    SELECT p.oid FROM pg_proc p
     WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
  LOOP
    v_def := pg_get_functiondef(v_oid);
    v_new := v_def;
    FOR v_i IN 1 .. array_length(v_pats, 1) LOOP
      v_new := regexp_replace(v_new, v_pats[v_i], v_reps[v_i], 'g');
    END LOOP;

    IF v_new <> v_def THEN
      IF position('search_path' IN v_def) > 0 AND position('search_path' IN v_new) = 0 THEN
        RAISE EXCEPTION 'round 3788 class %: rewrite of % lost its search_path pin', v_class, v_oid::regprocedure;
      END IF;
      EXECUTE v_new;
      v_rewritten := v_rewritten + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'round 3788 class % (%): % occurrence(s), % definition(s) rewritten', v_class, v_label, v_occ, v_rewritten;

  IF v_has_check THEN
    SELECT count(DISTINCT p.proname) INTO v_broken_after
      FROM pg_proc p
      CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.proname = ANY(v_all_names)
       AND e.level='error';

    RAISE NOTICE 'round 3788: broken among targeted functions % -> % (of %)', v_broken_before, v_broken_after, v_targeted;

    IF v_broken_after >= v_broken_before THEN
      RAISE EXCEPTION
        'round 3788 VERIFY FAILED: broken count did not improve (% -> %) -- rolling back',
        v_broken_before, v_broken_after;
    END IF;
  ELSE
    RAISE NOTICE 'round 3788: plpgsql_check absent -- relied on per-class occurrence + search_path assertions only';
  END IF;

  RAISE NOTICE 'round 3788 verified: wave-1 shared-root-cause classes applied';
END
$migration$;

COMMIT;
