-- =====================================================================
-- Round 3790 -- bulk fix, wave 3: three more shared root causes
-- =====================================================================
--
-- Continues the sweep remediation (round3788 wave 1, round3789 wave 2).
-- Running total before this migration: 576 baseline -> 365 remaining.
--
-- As in the previous waves, every transformation was DRY-RUN against
-- production first and each class's scoping decisions below record what
-- that dry run measured. Class F in particular was NARROWED as a direct
-- result: the obvious `kind -> type` rename would have corrupted two
-- unrelated tables.

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
    'founder_action_center',
    'founder_critical_actions',
    'founder_critical_cockpit',
    'founder_money_in_flight_summary',
    'founder_spare_parts_snapshot_summary',
    'founder_spare_parts_stuck_aging',
    'founder_vendor_quality_monthly_trend',
    'founder_vendor_quality_scorecard_by_vendor',
    'founder_vendor_quality_scorecard_summary'
  ];
  v_all_names := v_all_names || ARRAY[
    'exec_360_v3_drill_cards',
    'exec_360_v3_growth_kpis',
    'founder_hospital_matrix_overview',
    'founder_hospital_matrix_recompute',
    'founder_hsq_overview',
    'founder_hssv2_kpi_snapshot',
    'founder_ltv_headline',
    'founder_our_trajectory',
    'founder_peer_benchmark_gaps',
    'nps_auto_runner_kickoff_quarter'
  ];
  v_all_names := v_all_names || ARRAY[
    'assign_next_available_amc_engineer',
    'founder_board_pack_kpi_snapshot',
    'founder_hospital_cohort_retention',
    'founder_site_visit_kpis',
    'founder_site_visit_per_hospital',
    'founder_site_visit_redline_90d',
    'founder_vendor_sla_kpis'
  ];

  SELECT count(DISTINCT x) INTO v_targeted FROM unnest(v_all_names) x;

  IF v_has_check THEN
    SELECT count(DISTINCT p.proname) INTO v_broken_before
      FROM pg_proc p
      CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.proname = ANY(v_all_names) AND e.level='error';
    RAISE NOTICE 'round 3790: % of % targeted functions broken BEFORE', v_broken_before, v_targeted;
  END IF;

  -- ===================================================================
  -- CLASS E -- coalesce(order_status, '') -> coalesce(order_status::text, '')
  -- ===================================================================
  -- spare_part_orders.order_status is an ENUM, so coalesce(order_status,'') tries to coerce '' into it and raises 22P02. Casting to text first preserves the semantics exactly. Identical in shape to round3788 class D (payment_status) and to the round3784 hand-fix in investor_share_v2.
  --
  -- No residual expected -- the pattern is unambiguous and matches only a coalesce() whose first argument is that column.
  v_class := 'E';
  v_label := 'coalesce(order_status, '''') -> coalesce(order_status::text, '''')';
  v_names := ARRAY[
    'founder_action_center',
    'founder_critical_actions',
    'founder_critical_cockpit',
    'founder_money_in_flight_summary',
    'founder_spare_parts_snapshot_summary',
    'founder_spare_parts_stuck_aging',
    'founder_vendor_quality_monthly_trend',
    'founder_vendor_quality_scorecard_by_vendor',
    'founder_vendor_quality_scorecard_summary'
  ];
  v_pats  := ARRAY['coalesce\([[:space:]]*([a-z_]*\.?)order_status[[:space:]]*,'];
  v_reps  := ARRAY['coalesce(\1order_status::text,'];
  v_rewritten := 0;

  SELECT coalesce(sum((SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), v_pats[1], 'g'))), 0)
    INTO v_occ
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names);
  IF v_occ = 0 THEN
    RAISE EXCEPTION 'round 3790 class %: 0 occurrences of the class pattern -- inventory stale, refusing to proceed', v_class;
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
        RAISE EXCEPTION 'round 3790 class %: rewrite of % lost its search_path pin', v_class, v_oid::regprocedure;
      END IF;
      EXECUTE v_new;
      v_rewritten := v_rewritten + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'round 3790 class % (%): % occurrence(s), % definition(s) rewritten', v_class, v_label, v_occ, v_rewritten;

  -- ===================================================================
  -- CLASS G -- organizations column org_type -> type
  -- ===================================================================
  -- public.organizations has no org_type COLUMN. Its column is `type`, whose TYPE happens to be the enum named org_type -- so the code used the type's name as the column's name. Verified live: organizations.type is of type org_type and its actual stored value is 'hospital', so the compared literals are already correct; only the column name was wrong.
  --
  -- Verified before applying: across these 10 definitions there are 11 org_type occurrences and ZERO of them are `::org_type` casts, so every occurrence is a column reference. The pattern additionally refuses to match anything preceded by a colon, so a future cast could not be corrupted.
  v_class := 'G';
  v_label := 'organizations column org_type -> type';
  v_names := ARRAY[
    'exec_360_v3_drill_cards',
    'exec_360_v3_growth_kpis',
    'founder_hospital_matrix_overview',
    'founder_hospital_matrix_recompute',
    'founder_hsq_overview',
    'founder_hssv2_kpi_snapshot',
    'founder_ltv_headline',
    'founder_our_trajectory',
    'founder_peer_benchmark_gaps',
    'nps_auto_runner_kickoff_quarter'
  ];
  v_pats  := ARRAY['(^|[^:])\morg_type\M'];
  v_reps  := ARRAY['\1type'];
  v_rewritten := 0;

  SELECT coalesce(sum((SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), v_pats[1], 'g'))), 0)
    INTO v_occ
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names);
  IF v_occ = 0 THEN
    RAISE EXCEPTION 'round 3790 class %: 0 occurrences of the class pattern -- inventory stale, refusing to proceed', v_class;
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
        RAISE EXCEPTION 'round 3790 class %: rewrite of % lost its search_path pin', v_class, v_oid::regprocedure;
      END IF;
      EXECUTE v_new;
      v_rewritten := v_rewritten + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'round 3790 class % (%): % occurrence(s), % definition(s) rewritten', v_class, v_label, v_occ, v_rewritten;

  -- ===================================================================
  -- CLASS F -- organizations alias column o.kind -> o.type
  -- ===================================================================
  -- Same root cause as class G, reached through an alias: `FROM organizations o ... WHERE o.kind = 'hospital'`. organizations has no `kind` column.
  --
  -- DELIBERATELY SCOPED to the exact `o.kind` form. Of the 9 `kind` occurrences in this cluster, only 6 are organizations-bound `o.kind`; the other 3 are NOT organizations at all -- one is `INSERT INTO amc_admin_escalations (kind, ...)` and one is a visit row's `kind = 'maintenance'` (both separate phantom-column defects on other tables), plus one unqualified `FROM organizations WHERE kind = 'vendor'`. A blanket kind->type replace would have corrupted the first two, so they are left for individual treatment. `notifications.kind` and `repair_jobs.kind` are real columns elsewhere in the schema, which is exactly why this class must not be broadened.
  v_class := 'F';
  v_label := 'organizations alias column o.kind -> o.type';
  v_names := ARRAY[
    'assign_next_available_amc_engineer',
    'founder_board_pack_kpi_snapshot',
    'founder_hospital_cohort_retention',
    'founder_site_visit_kpis',
    'founder_site_visit_per_hospital',
    'founder_site_visit_redline_90d',
    'founder_vendor_sla_kpis'
  ];
  v_pats  := ARRAY['\mo\.kind\M'];
  v_reps  := ARRAY['o.type'];
  v_rewritten := 0;

  SELECT coalesce(sum((SELECT count(*) FROM regexp_matches(pg_get_functiondef(p.oid), v_pats[1], 'g'))), 0)
    INTO v_occ
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names);
  IF v_occ = 0 THEN
    RAISE EXCEPTION 'round 3790 class %: 0 occurrences of the class pattern -- inventory stale, refusing to proceed', v_class;
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
        RAISE EXCEPTION 'round 3790 class %: rewrite of % lost its search_path pin', v_class, v_oid::regprocedure;
      END IF;
      EXECUTE v_new;
      v_rewritten := v_rewritten + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'round 3790 class % (%): % occurrence(s), % definition(s) rewritten', v_class, v_label, v_occ, v_rewritten;

  IF v_has_check THEN
    SELECT count(DISTINCT p.proname) INTO v_broken_after
      FROM pg_proc p
      CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.proname = ANY(v_all_names) AND e.level='error';

    RAISE NOTICE 'round 3790: broken among targeted functions % -> % (of %)', v_broken_before, v_broken_after, v_targeted;

    IF v_broken_after >= v_broken_before THEN
      RAISE EXCEPTION
        'round 3790 VERIFY FAILED: broken count did not improve (% -> %) -- rolling back',
        v_broken_before, v_broken_after;
    END IF;
  ELSE
    RAISE NOTICE 'round 3790: plpgsql_check absent -- relied on per-class occurrence + search_path assertions only';
  END IF;

  RAISE NOTICE 'round 3790 verified: wave-3 classes applied';
END
$migration$;

COMMIT;
