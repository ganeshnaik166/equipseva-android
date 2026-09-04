-- =====================================================================
-- Round 3796 -- sweep remediation: the bespoke long tail
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
-- 108 function(s) accepted.
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
CREATE TEMP TABLE _r3796_before ON COMMIT DROP AS
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       coalesce((SELECT string_agg(x.name, ',' ORDER BY x.ord)
                 FROM unnest(coalesce(p.proargnames, '{}'::text[]))
                      WITH ORDINALITY AS x(name, ord)), '') AS argnames
FROM pg_proc p
WHERE p.pronamespace='public'::regnamespace
  AND p.proname = ANY(ARRAY[
    'engineer_sla_board',
    'exec_360_v3_engineering_kpis',
    'founder_acquisition_attribution_by_kind',
    'founder_acquisition_attribution_summary',
    'founder_amc_churn_scores',
    'founder_amc_mrr_by_tier',
    'founder_amc_revenue_by_tier',
    'founder_at_risk_revenue',
    'founder_bonded_intake_cumulative',
    'founder_bonded_intake_trend',
    'founder_bonded_parts_v2_concentration_risk',
    'founder_cert_by_vendor',
    'founder_cert_expiring_soon',
    'founder_cert_renewal_sla_breaches',
    'founder_clv_recent_snapshots',
    'founder_clv_top_customers',
    'founder_commission_by_week_13wk',
    'founder_complete_kyc_renewal',
    'founder_critical_cockpit',
    'founder_cs_playbook_runs_due',
    'founder_customer_health_score_by_hospital',
    'founder_customer_health_score_summary',
    'founder_demand_by_city',
    'founder_demand_priority_distribution',
    'founder_demand_signals_recent',
    'founder_engineer_availability_summary',
    'founder_engineer_earnings_distribution',
    'founder_engineer_fleet_expiring_docs',
    'founder_engineer_side_projects_by_risk_r1469',
    'founder_engineer_side_projects_kpis_r1469',
    'founder_engineer_skills_proficiency_recent',
    'founder_equipment_procurement_overdue',
    'founder_equipment_procurement_recent',
    'founder_equipment_type_breakdown',
    'founder_evidence_ledger_65b_summary',
    'founder_gst_invoices_by_month_by_source',
    'founder_heatmap_by_category',
    'founder_heatmap_by_hospital',
    'founder_heatmap_capture_snapshot',
    'founder_heatmap_cells',
    'founder_heatmap_gaps',
    'founder_heatmap_kpis',
    'founder_hospital_chains_drilldown_by_chain',
    'founder_hospital_chains_drilldown_summary',
    'founder_hospital_expansion_existing_action_queue',
    'founder_hospital_expansion_existing_candidates',
    'founder_hospital_expansion_existing_plays_list',
    'founder_hospital_leaderboard_30d',
    'founder_hospital_maintenance_calendar_overdue',
    'founder_hospital_maintenance_calendar_recent',
    'founder_jobs_by_engineer_tier',
    'founder_jobs_completion_by_tier',
    'founder_jobs_snapshot_summary',
    'founder_jobs_unassigned_aging',
    'founder_live_ops_cockpit_v2_heartbeat',
    'founder_monthly_cash_ledger_history',
    'founder_monthly_cash_ledger_summary',
    'founder_morning_pulse_v2',
    'founder_notifications_by_kind_30d',
    'founder_notifications_engagement_30d',
    'founder_payouts_by_engineer_tier',
    'founder_payout_cadence_kpis',
    'founder_platform_fee_cumulative',
    'founder_platform_fee_revenue_by_month',
    'founder_r2813_refactor_queue',
    'founder_r2813_verdict_mix',
    'founder_r3137_blind_spots_open',
    'founder_referral_volume_trend',
    'founder_referrers_by_tier',
    'founder_renewal_action_ladder',
    'founder_renewal_kpis',
    'founder_renewal_postmortem_log',
    'founder_renewal_queue',
    'founder_renewal_silent_contracts',
    'founder_repair_job_bids_snapshot_summary',
    'founder_revenue_leakage_history',
    'founder_revenue_leakage_summary',
    'founder_revenue_recognition_history',
    'founder_revenue_recognition_summary',
    'founder_runway_burn_summary',
    'founder_runway_forecast_v2_summary',
    'founder_runway_history',
    'founder_skill_gap_by_state',
    'founder_skill_gap_engineer_breakdown',
    'founder_skill_gap_overview',
    'founder_skill_gap_training_candidates',
    'founder_tier_distribution_by_city',
    'founder_tier_graduations_recent',
    'founder_top_suppliers_30d',
    'founder_weekly_board_pack',
    'list_interventions_r2430',
    'list_signals_r2430',
    'monthly_pulse_summary_r2497',
    'monthly_pulse_summary_r2549',
    'monthly_reading_trend_r1830',
    'my_sla_card',
    'r2815_chain_rollup',
    'r2815_outcome_distribution',
    'reap_expired_kyc_renewals',
    'recompute_heatmap_r1779',
    'refresh_affinity_r1896',
    'refresh_hospital_service_geo_hotspots_r1831',
    'rpc_founder_ops_open_jobs',
    'rpc_founder_ops_scorecard_build',
    'rpc_founder_ops_unassigned_escalations',
    'rpc_year_end_auto_metrics',
    'this_week_focus_r2430',
    'top_burnout_engineers_r2430'
  ]);

-- ---------------------------------------------------------------------
-- public.engineer_sla_board(p_days integer, p_limit integer)
CREATE OR REPLACE FUNCTION public.engineer_sla_board(p_days integer DEFAULT 30, p_limit integer DEFAULT 100)
 RETURNS TABLE(engineer_user_id uuid, engineer_email text, jobs_completed_window integer, jobs_disputed_window integer, dispute_rate_pct numeric, avg_accept_to_arrival_hrs numeric, avg_arrival_to_complete_hrs numeric, sla_breaches integer, on_time_pct numeric, current_risk_score integer, current_risk_band text, current_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_window_start timestamptz := now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH window_jobs AS (
    SELECT
      b.engineer_user_id,
      rj.id AS job_id,
      rj.status,
      rj.created_at,
      rj.completed_at,
      e.status AS escrow_status,
      -- Earliest arrival_checkin in window for this job
      (SELECT min(att.device_captured_at)
         FROM public.engineer_attendance att
        WHERE att.repair_job_id = rj.id
          AND att.event_kind = 'arrival_checkin') AS first_arrival,
      -- Accept timestamp from bid (repair_job_bids has no responded_at;
      -- updated_at is stamped when the bid row flips to status='accepted')
      b.updated_at AS accepted_at
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
    LEFT JOIN public.repair_job_escrow e ON e.repair_job_id = rj.id
    WHERE b.status = 'accepted'
      AND b.updated_at >= v_window_start
  ),
  per_engineer AS (
    SELECT
      wj.engineer_user_id,
      count(*) FILTER (WHERE wj.status = 'completed')::int AS jobs_completed,
      count(*) FILTER (WHERE wj.escrow_status = 'in_dispute')::int AS jobs_disputed,
      avg(EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0)
        FILTER (WHERE wj.first_arrival IS NOT NULL)::numeric(8,2) AS avg_accept_arrival,
      avg(EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0)
        FILTER (WHERE wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL)::numeric(8,2) AS avg_arrival_complete,
      count(*) FILTER (
        WHERE wj.first_arrival IS NOT NULL
          AND EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0 > 48
      )::int
      + count(*) FILTER (
        WHERE wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL
          AND EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0 > 24
      )::int AS breach_count
    FROM window_jobs wj
    GROUP BY wj.engineer_user_id
  ),
  risk AS (
    SELECT DISTINCT ON (s.user_id) s.user_id, s.score, s.band
      FROM public.risk_score_snapshots s
     WHERE s.role = 'engineer'
     ORDER BY s.user_id, s.computed_at DESC
  )
  SELECT
    pe.engineer_user_id,
    coalesce((SELECT email FROM auth.users WHERE id = pe.engineer_user_id), 'unknown'),
    pe.jobs_completed,
    pe.jobs_disputed,
    CASE WHEN pe.jobs_completed > 0
         THEN round(pe.jobs_disputed * 100.0 / pe.jobs_completed, 1)
         ELSE 0 END,
    pe.avg_accept_arrival,
    pe.avg_arrival_complete,
    pe.breach_count,
    CASE WHEN pe.jobs_completed > 0
         THEN round((pe.jobs_completed - pe.breach_count) * 100.0 / pe.jobs_completed, 1)
         ELSE 0 END,
    risk.score,
    risk.band,
    coalesce((SELECT cached_highest_tier FROM public.engineers WHERE user_id = pe.engineer_user_id), 'none')
  FROM per_engineer pe
  LEFT JOIN risk ON risk.user_id = pe.engineer_user_id
  ORDER BY pe.breach_count DESC, pe.jobs_disputed DESC, pe.jobs_completed DESC
  LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.exec_360_v3_engineering_kpis()
CREATE OR REPLACE FUNCTION public.exec_360_v3_engineering_kpis()
 RETURNS TABLE(kpi_key text, kpi_label text, kpi_value numeric, kpi_text text, status_color text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'engineers_active'::text, 'Active engineers'::text,
    (SELECT COUNT(*)::numeric FROM engineers WHERE cached_highest_tier <> 'none'),
    NULL::text, 'green'::text
  UNION ALL SELECT 'engineers_pro', 'Pro tier engineers',
    (SELECT COUNT(*)::numeric FROM engineers WHERE cached_highest_tier = 'pro'),
    NULL, 'green'
  UNION ALL SELECT 'engineers_bgc', 'BGC-verified engineers',
    (SELECT COUNT(*)::numeric FROM engineers WHERE cached_highest_tier IN ('pro','bgc')),
    NULL, 'green'
  UNION ALL SELECT 'jobs_open', 'Open repair jobs',
    (SELECT COUNT(*)::numeric FROM repair_jobs WHERE status IN ('requested','assigned','en_route','in_progress')),
    NULL, 'amber';
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_acquisition_attribution_by_kind()
CREATE OR REPLACE FUNCTION public.founder_acquisition_attribution_by_kind()
 RETURNS TABLE(kind text, touchpoint_count bigint, hospitals_touched bigint, hospitals_converted bigint, conversion_pct numeric, first_touch_attribution_count bigint, last_touch_attribution_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH tp AS (
    SELECT * FROM public.founder_acquisition_touchpoints
  ),
  hosp_first AS (
    SELECT hospital_org_id,
           (array_agg(touch_kind ORDER BY touched_at ASC))[1]  AS first_kind,
           (array_agg(touch_kind ORDER BY touched_at DESC))[1] AS last_kind
      FROM tp
     GROUP BY hospital_org_id
  ),
  converted AS (
    SELECT DISTINCT cp.organization_id AS hospital_org_id
      FROM public.amc_contracts cc
      JOIN public.profiles cp ON cp.id = cc.hospital_user_id
     WHERE cc.status = 'active'
       AND cp.organization_id IS NOT NULL
  ),
  hf_conv AS (
    SELECT hf.*, EXISTS (SELECT 1 FROM converted c WHERE c.hospital_org_id = hf.hospital_org_id) AS is_converted
      FROM hosp_first hf
  ),
  per_kind AS (
    SELECT touch_kind AS k,
           count(*)                          AS tp_count,
           count(DISTINCT hospital_org_id)   AS h_touched,
           count(DISTINCT hospital_org_id) FILTER (
             WHERE hospital_org_id IN (SELECT hospital_org_id FROM converted)
           )                                 AS h_converted
      FROM tp
     GROUP BY touch_kind
  ),
  first_attr AS (
    SELECT first_kind AS k, count(*) AS n FROM hf_conv WHERE is_converted GROUP BY first_kind
  ),
  last_attr AS (
    SELECT last_kind AS k, count(*) AS n FROM hf_conv WHERE is_converted GROUP BY last_kind
  ),
  kinds AS (
    SELECT unnest(ARRAY[
      'referral','cold_outreach','event','website_form',
      'phone_inbound','referred_by_chain','partner_referral',
      'google_ads','linkedin_ads','content_marketing','other'
    ]) AS k
  )
  SELECT
    k.k::text                                                       AS kind,
    COALESCE(pk.tp_count, 0)::bigint                                AS touchpoint_count,
    COALESCE(pk.h_touched, 0)::bigint                               AS hospitals_touched,
    COALESCE(pk.h_converted, 0)::bigint                             AS hospitals_converted,
    CASE WHEN COALESCE(pk.h_touched, 0) > 0
         THEN round(COALESCE(pk.h_converted, 0)::numeric * 100.0
                    / NULLIF(pk.h_touched, 0), 2)
         ELSE 0 END                                                 AS conversion_pct,
    COALESCE(fa.n, 0)::bigint                                       AS first_touch_attribution_count,
    COALESCE(la.n, 0)::bigint                                       AS last_touch_attribution_count
  FROM kinds k
  LEFT JOIN per_kind pk ON pk.k = k.k
  LEFT JOIN first_attr fa ON fa.k = k.k
  LEFT JOIN last_attr la ON la.k = k.k
  ORDER BY COALESCE(pk.tp_count, 0) DESC, k.k ASC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_acquisition_attribution_summary()
CREATE OR REPLACE FUNCTION public.founder_acquisition_attribution_summary()
 RETURNS TABLE(total_touchpoints bigint, total_hospitals_touched bigint, total_hospitals_converted bigint, conversion_pct numeric, avg_touches_per_conversion numeric, first_touch_top_kind text, last_touch_top_kind text, referral_attributed_count bigint, cold_outreach_attributed_count bigint, event_attributed_count bigint, website_form_attributed_count bigint, partner_referral_attributed_count bigint, other_kinds_attributed_count bigint, first_touch_to_signed_median_days numeric, touchpoints_last_30d bigint, hospitals_with_zero_touchpoints bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH tp AS (
    SELECT * FROM public.founder_acquisition_touchpoints
  ),
  hosp_first AS (
    SELECT hospital_org_id,
           (array_agg(touch_kind ORDER BY touched_at ASC))[1]  AS first_kind,
           (array_agg(touched_at ORDER BY touched_at ASC))[1]  AS first_at,
           (array_agg(touch_kind ORDER BY touched_at DESC))[1] AS last_kind,
           count(*)                                            AS touch_count
      FROM tp
     GROUP BY hospital_org_id
  ),
  converted AS (
    SELECT DISTINCT cp.organization_id AS hospital_org_id
      FROM public.amc_contracts cc
      JOIN public.profiles cp ON cp.id = cc.hospital_user_id
     WHERE cc.status = 'active'
       AND cp.organization_id IS NOT NULL
  ),
  hf_conv AS (
    SELECT hf.*,
           EXISTS (SELECT 1 FROM converted c WHERE c.hospital_org_id = hf.hospital_org_id) AS is_converted,
           (SELECT min(a.start_date)::timestamptz FROM public.amc_contracts a
              JOIN public.profiles ap ON ap.id = a.hospital_user_id
             WHERE ap.organization_id = hf.hospital_org_id AND a.status = 'active') AS first_signed_at
      FROM hosp_first hf
  ),
  first_kind_rank AS (
    SELECT first_kind, count(*) AS n
      FROM hf_conv WHERE is_converted
     GROUP BY first_kind
     ORDER BY n DESC NULLS LAST
     LIMIT 1
  ),
  last_kind_rank AS (
    SELECT last_kind, count(*) AS n
      FROM hf_conv WHERE is_converted
     GROUP BY last_kind
     ORDER BY n DESC NULLS LAST
     LIMIT 1
  ),
  attributed AS (
    SELECT first_kind FROM hf_conv WHERE is_converted
  ),
  med_days AS (
    SELECT percentile_cont(0.5) WITHIN GROUP (
             ORDER BY EXTRACT(EPOCH FROM (first_signed_at - first_at)) / 86400.0
           ) AS m
      FROM hf_conv
     WHERE is_converted AND first_signed_at IS NOT NULL AND first_at IS NOT NULL
  ),
  hospitals_total AS (
    SELECT count(*) AS n FROM public.organizations o WHERE o.type = 'hospital'::org_type
  ),
  hospitals_with AS (
    SELECT count(DISTINCT hospital_org_id) AS n FROM tp
  )
  SELECT
    (SELECT count(*) FROM tp)::bigint                                                AS total_touchpoints,
    (SELECT count(DISTINCT hospital_org_id) FROM tp)::bigint                         AS total_hospitals_touched,
    (SELECT count(*) FROM hf_conv WHERE is_converted)::bigint                        AS total_hospitals_converted,
    CASE WHEN (SELECT count(DISTINCT hospital_org_id) FROM tp) > 0
         THEN round(
           (SELECT count(*) FROM hf_conv WHERE is_converted)::numeric * 100.0
           / NULLIF((SELECT count(DISTINCT hospital_org_id) FROM tp), 0), 2)
         ELSE 0 END                                                                  AS conversion_pct,
    CASE WHEN (SELECT count(*) FROM hf_conv WHERE is_converted) > 0
         THEN round(
           (SELECT count(*) FROM tp t
             WHERE t.hospital_org_id IN (SELECT hospital_org_id FROM hf_conv WHERE is_converted)
           )::numeric
           / NULLIF((SELECT count(*) FROM hf_conv WHERE is_converted), 0), 2)
         ELSE 0 END                                                                  AS avg_touches_per_conversion,
    (SELECT first_kind FROM first_kind_rank)                                         AS first_touch_top_kind,
    (SELECT last_kind  FROM last_kind_rank)                                          AS last_touch_top_kind,
    (SELECT count(*) FROM attributed WHERE first_kind = 'referral')::bigint          AS referral_attributed_count,
    (SELECT count(*) FROM attributed WHERE first_kind = 'cold_outreach')::bigint     AS cold_outreach_attributed_count,
    (SELECT count(*) FROM attributed WHERE first_kind = 'event')::bigint             AS event_attributed_count,
    (SELECT count(*) FROM attributed WHERE first_kind = 'website_form')::bigint      AS website_form_attributed_count,
    (SELECT count(*) FROM attributed WHERE first_kind = 'partner_referral')::bigint  AS partner_referral_attributed_count,
    (SELECT count(*) FROM attributed
      WHERE first_kind NOT IN ('referral','cold_outreach','event','website_form','partner_referral')
    )::bigint                                                                        AS other_kinds_attributed_count,
    COALESCE(round((SELECT m FROM med_days)::numeric, 1), 0)                         AS first_touch_to_signed_median_days,
    (SELECT count(*) FROM tp WHERE touched_at >= now() - interval '30 days')::bigint AS touchpoints_last_30d,
    GREATEST(
      (SELECT n FROM hospitals_total) - (SELECT n FROM hospitals_with), 0
    )::bigint                                                                        AS hospitals_with_zero_touchpoints;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_amc_churn_scores(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_amc_churn_scores(p_limit integer DEFAULT 100)
 RETURNS TABLE(contract_id uuid, hospital_org_id uuid, hospital_name text, amc_tier text, monthly_fee_rupees numeric, activated_at timestamp with time zone, days_active integer, last_repair_completed_at timestamp with time zone, days_since_last_visit integer, overdue_visits_count integer, payment_overdue_days integer, sla_breaches_count integer, open_disputes_count integer, code_red_count_180d integer, churn_score numeric, churn_band text, primary_signal text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      c.id AS contract_id,
      hp.organization_id AS hospital_org_id,
      COALESCE(o.name, '—') AS hospital_name,
      c.amc_tier::text AS amc_tier,
      c.monthly_fee_rupees,
      c.activated_at,
      GREATEST(0, EXTRACT(DAY FROM (now() - c.activated_at))::int) AS days_active
    FROM public.amc_contracts c
    LEFT JOIN public.profiles hp ON hp.id = c.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = hp.organization_id
    WHERE c.status = 'active'
  ),
  last_visit AS (
    SELECT rj.amc_contract_id AS contract_id, MAX(rj.completed_at) AS last_repair_completed_at
    FROM public.repair_jobs rj
    WHERE rj.amc_contract_id IS NOT NULL AND rj.completed_at IS NOT NULL
    GROUP BY rj.amc_contract_id
  ),
  -- r1322 FIX: amc_sla_breaches uses credit_issued_rupees + detected_at;
  -- table exists but joins on amc_contract_id only when set.
  sla AS (
    SELECT b.amc_contract_id AS contract_id, COUNT(*)::int AS sla_breaches_count
    FROM public.amc_sla_breaches b
    WHERE b.amc_contract_id IS NOT NULL
    GROUP BY b.amc_contract_id
  ),
  -- r1322 FIX: code_red_incidents → code_red_requests (no amc_contract_id join,
  -- so we go through repair_jobs to find which contract a Code Red belongs to)
  code_red AS (
    SELECT rj.amc_contract_id AS contract_id, COUNT(DISTINCT crr.id)::int AS code_red_count_180d
    FROM public.code_red_requests crr
    JOIN public.repair_jobs rj ON rj.id = crr.resolution_repair_job_id
    WHERE crr.created_at >= now() - interval '180 days'
      AND rj.amc_contract_id IS NOT NULL
    GROUP BY rj.amc_contract_id
  ),
  joined AS (
    SELECT
      b.contract_id, b.hospital_org_id, b.hospital_name, b.amc_tier,
      b.monthly_fee_rupees, b.activated_at, b.days_active,
      lv.last_repair_completed_at,
      GREATEST(0, EXTRACT(DAY FROM (now() - COALESCE(lv.last_repair_completed_at, b.activated_at)))::int) AS days_since_last_visit,
      0::int AS overdue_visits_count,           -- amc_scheduled_visits table does not exist
      0::int AS payment_overdue_days,           -- amc_payments table does not exist
      COALESCE(sla.sla_breaches_count, 0) AS sla_breaches_count,
      0::int AS open_disputes_count,            -- amc_disputes table does not exist
      COALESCE(cr.code_red_count_180d, 0) AS code_red_count_180d
    FROM base b
    LEFT JOIN last_visit lv ON lv.contract_id = b.contract_id
    LEFT JOIN sla           ON sla.contract_id = b.contract_id
    LEFT JOIN code_red cr   ON cr.contract_id  = b.contract_id
  ),
  scored AS (
    SELECT j.*,
      LEAST(1.0, GREATEST(0.0,
          LEAST(1.0, j.days_since_last_visit::numeric / 90.0) * 0.35
        + LEAST(1.0, j.sla_breaches_count::numeric / 5.0)     * 0.30
        + LEAST(1.0, j.code_red_count_180d::numeric / 3.0)    * 0.35
      )) AS churn_score_raw
    FROM joined j
  )
  SELECT
    s.contract_id, s.hospital_org_id, s.hospital_name, s.amc_tier,
    s.monthly_fee_rupees, s.activated_at, s.days_active,
    s.last_repair_completed_at, s.days_since_last_visit,
    s.overdue_visits_count, s.payment_overdue_days, s.sla_breaches_count,
    s.open_disputes_count, s.code_red_count_180d,
    ROUND(s.churn_score_raw, 4) AS churn_score,
    CASE WHEN s.churn_score_raw >= 0.75 THEN 'critical'
         WHEN s.churn_score_raw >= 0.50 THEN 'high'
         WHEN s.churn_score_raw >= 0.25 THEN 'medium'
         ELSE 'low' END AS churn_band,
    CASE WHEN s.code_red_count_180d  >= 2 THEN 'multiple code-red incidents'
         WHEN s.sla_breaches_count   >= 3 THEN 'sla breach pattern'
         WHEN s.days_since_last_visit >= 60 THEN 'no visit ' || s.days_since_last_visit::text || 'd'
         ELSE 'baseline' END AS primary_signal
  FROM scored s
  ORDER BY s.churn_score_raw DESC, s.monthly_fee_rupees DESC NULLS LAST
  LIMIT GREATEST(p_limit, 1);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_mrr_by_tier()
CREATE OR REPLACE FUNCTION public.founder_amc_mrr_by_tier()
 RETURNS TABLE(tier text, active_cnt bigint, mrr_rupees numeric, arr_rupees numeric, avg_fee numeric, share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_mrr numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_total_mrr
    FROM public.amc_contracts WHERE status='active';
  RETURN QUERY
  WITH tiers AS (
    SELECT st.tier AS tier, st.display_order AS display_order FROM public.amc_subscription_tiers st
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0)::bigint,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0)::numeric,
    coalesce((SELECT sum(c.monthly_fee_rupees * 12)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0)::numeric,
    CASE WHEN coalesce((SELECT count(*) FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active')
           / (SELECT count(*)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 2)
    END,
    CASE WHEN v_total_mrr = 0 THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0)
           / v_total_mrr * 100.0, 1)
    END
  FROM tiers t
  ORDER BY t.display_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_revenue_by_tier()
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_by_tier()
 RETURNS TABLE(tier text, active_contracts bigint, monthly_mrr numeric, annual_arr numeric, share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_total
    FROM public.amc_contracts WHERE status = 'active';
  RETURN QUERY
  WITH tiers AS (
    SELECT st.tier, st.display_order FROM public.amc_subscription_tiers st
  )
  SELECT
    t.tier,
    coalesce(count(c.id), 0)::bigint                       AS active_contracts,
    coalesce(sum(c.monthly_fee_rupees), 0)::numeric        AS monthly_mrr,
    coalesce(sum(c.monthly_fee_rupees) * 12, 0)::numeric   AS annual_arr,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(coalesce(sum(c.monthly_fee_rupees), 0)::numeric / v_total * 100.0, 1)
    END AS share_pct
  FROM tiers t
  LEFT JOIN public.amc_contracts c ON c.amc_tier = t.tier AND c.status = 'active'
  GROUP BY t.tier, t.display_order
  ORDER BY t.display_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_at_risk_revenue()
CREATE OR REPLACE FUNCTION public.founder_at_risk_revenue()
 RETURNS TABLE(category text, count_v bigint, rupees_v numeric, ord integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT 'AMCs expiring within 30d'::text, count(*)::bigint, coalesce(sum(monthly_fee_rupees), 0)::numeric, 1
    FROM public.amc_contracts WHERE status = 'active' AND end_date BETWEEN v_today AND (v_today + 30)
  UNION ALL
  SELECT 'AMCs paused (pool low)', count(*)::bigint, coalesce(sum(monthly_fee_rupees), 0)::numeric, 2
    FROM public.amc_contracts WHERE status = 'paused'
  UNION ALL
  SELECT 'AMCs renewal_failed', count(*)::bigint, coalesce(sum(monthly_fee_rupees), 0)::numeric, 3
    FROM public.amc_contracts WHERE status = 'renewal_failed'
  UNION ALL
  SELECT 'Escrow stuck >30d', count(*)::bigint, coalesce(sum(amount_rupees), 0)::numeric, 4
    FROM public.repair_job_escrow WHERE status IN ('pending','held','in_dispute') AND created_at < now() - interval '30 days'
  UNION ALL
  SELECT 'Open disputes (money at stake)', count(*)::bigint, coalesce(sum(total_money_at_stake_rupees), 0)::numeric, 5
    FROM public.dispute_evidence_packs WHERE status = 'submitted'
  UNION ALL
  SELECT 'Payouts queued/processing', count(*)::bigint, round(coalesce(sum(amount_paise), 0)::numeric / 100.0, 2), 6
    FROM public.engineer_payouts WHERE status IN ('queued','processing')
  ORDER BY 4;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_bonded_intake_cumulative()
CREATE OR REPLACE FUNCTION public.founder_bonded_intake_cumulative()
 RETURNS TABLE(month_ist date, rows_in bigint, cum_rows bigint, qty bigint, cum_qty bigint, cum_cost numeric)
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
      coalesce((SELECT count(*)::bigint FROM public.bonded_parts_intake i
                WHERE date_trunc('month', (i.intake_received_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n,
      coalesce((SELECT sum(i.quantity_received)::bigint FROM public.bonded_parts_intake i
                WHERE date_trunc('month', (i.intake_received_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS q,
      coalesce((SELECT sum(i.total_cost_rupees)::numeric FROM public.bonded_parts_intake i
                WHERE date_trunc('month', (i.intake_received_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS c
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    sum(monthly.n) OVER (ORDER BY monthly.month_ist),
    monthly.q,
    sum(monthly.q) OVER (ORDER BY monthly.month_ist),
    sum(monthly.c) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_bonded_intake_trend()
CREATE OR REPLACE FUNCTION public.founder_bonded_intake_trend()
 RETURNS TABLE(day_ist date, intake_rows bigint, qty_received bigint, total_cost numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 13,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.bonded_parts_intake i
       WHERE (i.intake_received_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT sum(i.quantity_received)::bigint FROM public.bonded_parts_intake i
       WHERE (i.intake_received_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT sum(i.total_cost_rupees)::numeric FROM public.bonded_parts_intake i
       WHERE (i.intake_received_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_bonded_parts_v2_concentration_risk()
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_v2_concentration_risk()
 RETURNS TABLE(rank_no integer, supplier_org_id uuid, supplier_name text, volume_rupees numeric, pct_of_total numeric, cumulative_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  WITH bonded_names AS (
    SELECT supplier_org_id, supplier_name FROM public.dental_bonded_parts_suppliers
    UNION
    SELECT supplier_org_id, supplier_name FROM public.lab_diagnostics_bonded_parts_suppliers
  ),
  per_supp AS (
    SELECT bn.supplier_org_id, MAX(bn.supplier_name) AS supplier_name,
           COALESCE(SUM(o.total_amount),0) AS vol
      FROM bonded_names bn
      LEFT JOIN public.spare_part_orders o
             ON o.supplier_org_id = bn.supplier_org_id
            AND o.payment_status = 'completed'
            AND o.created_at >= now() - interval '90 days'
     GROUP BY bn.supplier_org_id
  ),
  ranked AS (
    SELECT supplier_org_id, supplier_name, vol,
           ROW_NUMBER() OVER (ORDER BY vol DESC) AS rk,
           SUM(vol) OVER () AS grand
      FROM per_supp
  ),
  scored AS (
    SELECT rk::int AS rank_no, supplier_org_id, supplier_name, vol,
           CASE WHEN grand = 0 THEN 0 ELSE ROUND(100.0 * vol / grand, 2) END AS pct,
           CASE WHEN grand = 0 THEN 0
                ELSE ROUND(100.0 * SUM(vol) OVER (ORDER BY vol DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / grand, 2)
           END AS cum_pct
      FROM ranked
  )
  SELECT rank_no, supplier_org_id, supplier_name, vol, pct, cum_pct
    FROM scored
   WHERE rank_no <= 10
   ORDER BY rank_no;
END
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cert_by_vendor()
CREATE OR REPLACE FUNCTION public.founder_cert_by_vendor()
 RETURNS TABLE(vendor text, cert_count bigint, active_count bigint, expiring_30d bigint, expired_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.oem_vendor::text, count(*)::bigint,
         count(*) FILTER (WHERE c.expires_on > current_date)::bigint,
         count(*) FILTER (WHERE c.expires_on BETWEEN current_date AND current_date + 30)::bigint,
         count(*) FILTER (WHERE c.expires_on < current_date)::bigint
  FROM public.engineer_external_certifications c
  GROUP BY c.oem_vendor
  ORDER BY count(*) DESC
  LIMIT 50;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_cert_expiring_soon()
CREATE OR REPLACE FUNCTION public.founder_cert_expiring_soon()
 RETURNS TABLE(cert_id uuid, engineer_id uuid, engineer_name text, vendor text, expires_on date, days_until integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_id, COALESCE(p.full_name, 'unknown')::text, c.oem_vendor, c.expires_on,
         (c.expires_on - current_date)::int
  FROM public.engineer_external_certifications c
  LEFT JOIN public.engineers e ON e.id = c.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE c.expires_on IS NOT NULL AND c.expires_on <= current_date + 90
  ORDER BY c.expires_on ASC
  LIMIT 100;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_cert_renewal_sla_breaches()
CREATE OR REPLACE FUNCTION public.founder_cert_renewal_sla_breaches()
 RETURNS TABLE(cert_id uuid, engineer_id uuid, engineer_name text, vendor text, expires_on date, days_overdue integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_id, COALESCE(p.full_name, 'unknown')::text, c.oem_vendor, c.expires_on,
         (current_date - c.expires_on)::int
  FROM public.engineer_external_certifications c
  LEFT JOIN public.engineers e ON e.id = c.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE c.expires_on < current_date
  ORDER BY c.expires_on ASC
  LIMIT 50;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_clv_recent_snapshots(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_clv_recent_snapshots(p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, hospital_user_id uuid, hospital_name text, snapshot_at timestamp with time zone, total_lifetime_revenue_rupees numeric, total_lifetime_gross_profit_rupees numeric, total_projected_clv_rupees numeric, days_active integer, churn_risk_band text, value_segment text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id,
         coalesce(o.name, p.full_name, s.hospital_user_id::text) AS hospital_name,
         s.snapshot_at, s.total_lifetime_revenue_rupees, s.total_lifetime_gross_profit_rupees,
         s.total_projected_clv_rupees, s.days_active, s.churn_risk_band, s.value_segment
  FROM public.founder_customer_lifetime_value_snapshots s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.snapshot_at DESC
  LIMIT greatest(1, least(p_limit, 200));
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_clv_top_customers(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_clv_top_customers(p_limit integer DEFAULT 50)
 RETURNS TABLE(hospital_user_id uuid, hospital_name text, city text, snapshot_at timestamp with time zone, total_lifetime_revenue_rupees numeric, total_lifetime_gross_profit_rupees numeric, total_projected_clv_rupees numeric, days_active integer, value_segment text, churn_risk_band text)
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
  )
  SELECT l.hospital_user_id,
         coalesce(o.name, p.full_name, l.hospital_user_id::text) AS hospital_name,
         o.city,
         l.snapshot_at, l.total_lifetime_revenue_rupees, l.total_lifetime_gross_profit_rupees,
         l.total_projected_clv_rupees, l.days_active, l.value_segment, l.churn_risk_band
  FROM latest l
  LEFT JOIN public.profiles p ON p.id = l.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY l.total_projected_clv_rupees DESC NULLS LAST
  LIMIT greatest(1, least(p_limit, 200));
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_commission_by_week_13wk()
CREATE OR REPLACE FUNCTION public.founder_commission_by_week_13wk()
 RETURNS TABLE(week_start date, total_fees_inr numeric, invoice_cnt bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind IN ('repair_job_platform_fee','amc_visit_platform_fee','spare_part_platform_fee','amc_subscription_fee')
                AND date_trunc('week', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS total_fees_inr,
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind IN ('repair_job_platform_fee','amc_visit_platform_fee','spare_part_platform_fee','amc_subscription_fee')
                AND date_trunc('week', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS invoice_cnt
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_complete_kyc_renewal(p_renewal_id uuid, p_outcome text, p_note text)
CREATE OR REPLACE FUNCTION public.founder_complete_kyc_renewal(p_renewal_id uuid, p_outcome text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_outcome NOT IN ('completed','expired','waived') THEN
    RAISE EXCEPTION 'invalid_outcome' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row FROM public.engineer_kyc_renewals WHERE id = p_renewal_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'renewal_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_row.status NOT IN ('pending','in_progress') THEN
    RAISE EXCEPTION 'renewal_already_closed (status=%)', v_row.status USING ERRCODE = '22023';
  END IF;

  UPDATE public.engineer_kyc_renewals
     SET status = p_outcome,
         completed_at = CASE WHEN p_outcome = 'completed' THEN now() ELSE NULL END,
         expired_at   = CASE WHEN p_outcome = 'expired'   THEN now() ELSE NULL END,
         completed_by_admin = auth.uid(),
         rejection_note = p_note
   WHERE id = p_renewal_id;

  -- If expired: revert the engineer's verification_status to pending
  -- so the directory hides them until they re-verify.
  -- (engineers has no verification_status_updated_at column; the
  --  update_engineers_updated_at BEFORE UPDATE trigger stamps updated_at.)
  IF p_outcome = 'expired' THEN
    UPDATE public.engineers
       SET verification_status = 'pending'
     WHERE user_id = v_row.engineer_user_id;
  END IF;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_complete_kyc_renewal',
    p_target_table  => 'engineer_kyc_renewals',
    p_target_row_id => p_renewal_id,
    p_before_value  => jsonb_build_object('status', v_row.status, 'engineer_user_id', v_row.engineer_user_id),
    p_after_value   => jsonb_build_object('status', p_outcome),
    p_reason        => p_note
  );
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_critical_cockpit()
CREATE OR REPLACE FUNCTION public.founder_critical_cockpit()
 RETURNS TABLE(payouts_stuck_over_7d bigint, payouts_stuck_inr numeric, code_red_stuck_over_4h bigint, spare_parts_stuck_over_7d bigint, spare_parts_stuck_inr numeric, jobs_unassigned_over_1d bigint, bids_stuck_over_1d bigint, escrow_held_over_14d bigint, escrow_held_inr numeric, engineers_no_jobs_90d bigint, hospitals_no_jobs_90d bigint, amc_renewing_30d bigint, amc_renewing_mrr_inr numeric, amc_pool_zero_balance bigint, amc_pool_zero_mrr_inr numeric, kyc_pending_over_7d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status NOT IN ('resolved','timed_out') AND created_at < now() - interval '4 hours'), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(payment_status::text,'') = 'completed' AND coalesce(order_status::text,'') NOT IN ('shipped','delivered','cancelled','returned') AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status::text,'') = 'completed' AND coalesce(order_status::text,'') NOT IN ('shipped','delivered','cancelled','returned') AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE engineer_id IS NULL AND status = 'requested' AND created_at < now() - interval '1 day'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status IN ('submitted','pending') AND created_at < now() - interval '1 day'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    -- engineers_no_jobs_90d — fixed FK join (was j.engineer_id = profile.id, never matched)
    coalesce((SELECT count(*)::bigint FROM public.engineers e
              WHERE NOT EXISTS (
                SELECT 1 FROM public.repair_jobs j
                WHERE j.engineer_id = e.id
                  AND j.status = 'completed'
                  AND j.completed_at >= now() - interval '90 days'
              )), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'hospital_admin'
              AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = p.id AND j.created_at >= now() - interval '90 days')), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date + 30 AND c.status IN ('active','paused')), 0),
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date + 30 AND c.status IN ('active','paused')), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.status = 'active'
              AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.status = 'active'
              AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers e WHERE coalesce(e.verification_status, 'pending') = 'pending' AND e.created_at < now() - interval '7 days'), 0);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cs_playbook_runs_due(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_cs_playbook_runs_due(p_limit integer DEFAULT 50)
 RETURNS TABLE(run_id uuid, amc_contract_id uuid, hospital_name text, amc_tier text, step_kind text, step_title text, due_at date, overdue_days integer, monthly_fee_rupees numeric)
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
    r.id,
    r.amc_contract_id,
    COALESCE(o.name, p.full_name, 'Unknown hospital')::text,
    s.amc_tier::text,
    s.step_kind::text,
    s.step_title::text,
    r.due_at,
    GREATEST((current_date - r.due_at)::int, 0),
    c.monthly_fee_rupees
  FROM public.founder_cs_playbook_runs r
  JOIN public.founder_cs_playbook_steps s ON s.id = r.step_id
  JOIN public.amc_contracts c              ON c.id = r.amc_contract_id
  LEFT JOIN public.profiles p              ON p.id = c.hospital_user_id
  LEFT JOIN public.organizations o         ON o.id = p.organization_id
  WHERE r.completed_at IS NULL
    AND r.due_at IS NOT NULL
    AND r.due_at <= current_date
  ORDER BY (current_date - r.due_at) DESC, r.due_at ASC
  LIMIT GREATEST(p_limit, 1);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_customer_health_score_by_hospital(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_customer_health_score_by_hospital(p_limit integer DEFAULT 100)
 RETURNS TABLE(hospital_org_id uuid, hospital_name text, amc_tier text, monthly_fee_rupees numeric, days_active integer, last_visit_at timestamp with time zone, days_since_last_visit integer, open_codered_count integer, open_dispute_count integer, sla_breach_count_180d integer, nps_latest_score integer, latest_nps_category text, health_score numeric, health_band text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH primary_amc AS (
    SELECT DISTINCT ON (hp.organization_id)
      hp.organization_id AS hospital_org_id,
      ac.amc_tier,
      ac.monthly_fee_rupees,
      ac.start_date,
      ac.activated_at
    FROM public.amc_contracts ac
    JOIN public.profiles hp ON hp.id = ac.hospital_user_id
    WHERE ac.status IN ('active','paused')
      AND hp.organization_id IS NOT NULL
    ORDER BY hp.organization_id, ac.activated_at DESC NULLS LAST, ac.start_date DESC NULLS LAST
  ),
  last_visit AS (
    SELECT rj.hospital_org_id, max(rj.completed_at) AS last_visit_at
    FROM public.repair_jobs rj
    WHERE rj.completed_at IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  codered AS (
    SELECT p.organization_id AS hospital_org_id, count(*)::int AS open_codered
    FROM public.code_red_requests cr
    JOIN public.profiles p ON p.id = cr.hospital_user_id
    WHERE cr.status IN ('open','engineer_accepted')
      AND p.organization_id IS NOT NULL
    GROUP BY p.organization_id
  ),
  disputes AS (
    SELECT rj.hospital_org_id, count(*)::int AS open_disputes
    FROM public.repair_job_escrow rje
    JOIN public.repair_jobs rj ON rj.id = rje.repair_job_id
    WHERE rje.status = 'in_dispute'
      AND rj.hospital_org_id IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  sla AS (
    SELECT hp.organization_id AS hospital_org_id, count(*)::int AS breach_180d
    FROM public.amc_sla_breaches sb
    JOIN public.amc_contracts ac ON ac.id = sb.amc_contract_id
    JOIN public.profiles hp ON hp.id = ac.hospital_user_id
    WHERE sb.detected_at >= now() - interval '180 days'
      AND hp.organization_id IS NOT NULL
    GROUP BY hp.organization_id
  ),
  latest_nps AS (
    SELECT DISTINCT ON (n.hospital_org_id)
      n.hospital_org_id,
      n.score,
      n.category
    FROM public.founder_nps_responses n
    ORDER BY n.hospital_org_id, n.responded_at DESC
  )
  SELECT
    pa.hospital_org_id,
    o.name::text                                       AS hospital_name,
    pa.amc_tier::text                                  AS amc_tier,
    pa.monthly_fee_rupees::numeric                     AS monthly_fee_rupees,
    GREATEST(0, coalesce(
      extract(day FROM (now() - coalesce(pa.activated_at, pa.start_date::timestamptz)))::int,
      0
    ))                                                 AS days_active,
    lv.last_visit_at                                   AS last_visit_at,
    coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)
                                                       AS days_since_last_visit,
    coalesce(cr.open_codered, 0)::int                  AS open_codered_count,
    coalesce(d.open_disputes, 0)::int                  AS open_dispute_count,
    coalesce(s.breach_180d, 0)::int                    AS sla_breach_count_180d,
    ln.score                                           AS nps_latest_score,
    ln.category::text                                  AS latest_nps_category,
    round(
      GREATEST(
        0::numeric,
        LEAST(
          100::numeric,
          100::numeric
          - LEAST(25::numeric,
                  (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
          - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
          - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
          - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
          + CASE ln.category
              WHEN 'promoter'  THEN 10::numeric
              WHEN 'detractor' THEN -15::numeric
              ELSE 0::numeric
            END
        )
      )::numeric,
      1
    )                                                  AS health_score,
    CASE
      WHEN GREATEST(0::numeric, LEAST(100::numeric,
        100::numeric
        - LEAST(25::numeric, (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
        - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
        - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
        - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
        + CASE ln.category WHEN 'promoter' THEN 10::numeric WHEN 'detractor' THEN -15::numeric ELSE 0::numeric END
      )) >= 80 THEN 'healthy'
      WHEN GREATEST(0::numeric, LEAST(100::numeric,
        100::numeric
        - LEAST(25::numeric, (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
        - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
        - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
        - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
        + CASE ln.category WHEN 'promoter' THEN 10::numeric WHEN 'detractor' THEN -15::numeric ELSE 0::numeric END
      )) >= 60 THEN 'watch'
      WHEN GREATEST(0::numeric, LEAST(100::numeric,
        100::numeric
        - LEAST(25::numeric, (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
        - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
        - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
        - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
        + CASE ln.category WHEN 'promoter' THEN 10::numeric WHEN 'detractor' THEN -15::numeric ELSE 0::numeric END
      )) >= 30 THEN 'at_risk'
      ELSE 'critical'
    END                                                AS health_band
  FROM primary_amc pa
  JOIN public.organizations o ON o.id = pa.hospital_org_id
  LEFT JOIN last_visit lv ON lv.hospital_org_id = pa.hospital_org_id
  LEFT JOIN codered   cr ON cr.hospital_org_id = pa.hospital_org_id
  LEFT JOIN disputes  d  ON d.hospital_org_id  = pa.hospital_org_id
  LEFT JOIN sla       s  ON s.hospital_org_id  = pa.hospital_org_id
  LEFT JOIN latest_nps ln ON ln.hospital_org_id = pa.hospital_org_id
  ORDER BY health_score ASC NULLS LAST, hospital_name ASC
  LIMIT GREATEST(1, LEAST(coalesce(p_limit, 100), 500));
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_customer_health_score_summary()
CREATE OR REPLACE FUNCTION public.founder_customer_health_score_summary()
 RETURNS TABLE(total_active_hospitals bigint, healthy_count bigint, watch_count bigint, at_risk_count bigint, critical_count bigint, avg_health_score numeric, top_health_hospital_name text, top_health_score numeric, lowest_health_hospital_name text, lowest_health_score numeric, hospitals_improved_30d bigint, hospitals_declined_30d bigint, nps_promoter_count bigint, nps_detractor_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH active_amc AS (
    SELECT DISTINCT p.organization_id AS hospital_org_id
    FROM public.amc_contracts ac
    JOIN public.profiles p ON p.id = ac.hospital_user_id
    WHERE ac.status IN ('active','paused')
      AND p.organization_id IS NOT NULL
  ),
  last_visit AS (
    SELECT rj.hospital_org_id, max(rj.completed_at) AS last_visit_at
    FROM public.repair_jobs rj
    WHERE rj.completed_at IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  codered AS (
    SELECT p.organization_id AS hospital_org_id, count(*)::bigint AS open_codered
    FROM public.code_red_requests cr
    JOIN public.profiles p ON p.id = cr.hospital_user_id
    WHERE cr.status IN ('open','engineer_accepted')
      AND p.organization_id IS NOT NULL
    GROUP BY p.organization_id
  ),
  disputes AS (
    SELECT rj.hospital_org_id, count(*)::bigint AS open_disputes
    FROM public.repair_job_escrow rje
    JOIN public.repair_jobs rj ON rj.id = rje.repair_job_id
    WHERE rje.status = 'in_dispute'
      AND rj.hospital_org_id IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  sla AS (
    SELECT p.organization_id AS hospital_org_id, count(*)::bigint AS breach_180d
    FROM public.amc_sla_breaches sb
    JOIN public.amc_contracts ac ON ac.id = sb.amc_contract_id
    JOIN public.profiles p ON p.id = ac.hospital_user_id
    WHERE sb.detected_at >= now() - interval '180 days'
      AND p.organization_id IS NOT NULL
    GROUP BY p.organization_id
  ),
  latest_nps AS (
    SELECT DISTINCT ON (n.hospital_org_id)
      n.hospital_org_id,
      n.score,
      n.category
    FROM public.founder_nps_responses n
    ORDER BY n.hospital_org_id, n.responded_at DESC
  ),
  scored AS (
    SELECT
      a.hospital_org_id,
      o.name AS hospital_name,
      coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999) AS dslv,
      coalesce(cr.open_codered, 0) AS open_cr,
      coalesce(d.open_disputes, 0) AS open_dp,
      coalesce(s.breach_180d, 0)   AS breaches,
      ln.category                  AS nps_cat,
      GREATEST(
        0::numeric,
        LEAST(
          100::numeric,
          100::numeric
          - LEAST(25::numeric,
                  (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
          - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
          - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
          - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
          + CASE ln.category
              WHEN 'promoter'  THEN 10::numeric
              WHEN 'detractor' THEN -15::numeric
              ELSE 0::numeric
            END
        )
      ) AS health_score
    FROM active_amc a
    JOIN public.organizations o ON o.id = a.hospital_org_id
    LEFT JOIN last_visit lv ON lv.hospital_org_id = a.hospital_org_id
    LEFT JOIN codered   cr ON cr.hospital_org_id = a.hospital_org_id
    LEFT JOIN disputes  d  ON d.hospital_org_id  = a.hospital_org_id
    LEFT JOIN sla       s  ON s.hospital_org_id  = a.hospital_org_id
    LEFT JOIN latest_nps ln ON ln.hospital_org_id = a.hospital_org_id
  ),
  top_h AS (
    SELECT hospital_name, health_score
    FROM scored
    ORDER BY health_score DESC NULLS LAST, hospital_name ASC
    LIMIT 1
  ),
  low_h AS (
    SELECT hospital_name, health_score
    FROM scored
    ORDER BY health_score ASC NULLS LAST, hospital_name ASC
    LIMIT 1
  )
  SELECT
    (SELECT count(*)::bigint FROM scored)                                                    AS total_active_hospitals,
    (SELECT count(*) FILTER (WHERE health_score >= 80)::bigint FROM scored)                  AS healthy_count,
    (SELECT count(*) FILTER (WHERE health_score >= 60 AND health_score < 80)::bigint FROM scored) AS watch_count,
    (SELECT count(*) FILTER (WHERE health_score >= 30 AND health_score < 60)::bigint FROM scored) AS at_risk_count,
    (SELECT count(*) FILTER (WHERE health_score < 30)::bigint FROM scored)                   AS critical_count,
    (SELECT coalesce(round(avg(health_score)::numeric, 1), 0) FROM scored)                   AS avg_health_score,
    (SELECT hospital_name FROM top_h)                                                        AS top_health_hospital_name,
    (SELECT round(health_score::numeric, 1) FROM top_h)                                      AS top_health_score,
    (SELECT hospital_name FROM low_h)                                                        AS lowest_health_hospital_name,
    (SELECT round(health_score::numeric, 1) FROM low_h)                                      AS lowest_health_score,
    0::bigint                                                                                AS hospitals_improved_30d,
    0::bigint                                                                                AS hospitals_declined_30d,
    (SELECT count(*) FILTER (WHERE nps_cat = 'promoter')::bigint  FROM scored)               AS nps_promoter_count,
    (SELECT count(*) FILTER (WHERE nps_cat = 'detractor')::bigint FROM scored)               AS nps_detractor_count;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_demand_by_city()
CREATE OR REPLACE FUNCTION public.founder_demand_by_city()
 RETURNS TABLE(city text, signals_90d bigint, reporters bigint, distinct_skus bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH recent AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      d.reporter_user_id,
      coalesce(d.part_number, d.equipment_model, '(none)') AS sku
    FROM public.spare_part_demand_signals d
    LEFT JOIN public.profiles p ON p.id = d.reporter_user_id
    WHERE d.occurred_at >= now() - interval '90 days'
  )
  SELECT
    r.city,
    count(*)::bigint,
    count(DISTINCT r.reporter_user_id)::bigint,
    count(DISTINCT r.sku)::bigint
  FROM recent r
  GROUP BY r.city
  ORDER BY 2 DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_demand_priority_distribution()
CREATE OR REPLACE FUNCTION public.founder_demand_priority_distribution()
 RETURNS TABLE(priority text, cnt bigint, resolved bigint, open bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH p(label, ord) AS (
    VALUES ('high'::text, 1), ('med', 2), ('low', 3), ('(unprioritised)', 4)
  )
  SELECT
    p.label,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals d
              WHERE d.occurred_at >= now() - interval '90 days'
                AND (CASE WHEN p.label = '(unprioritised)' THEN d.founder_priority IS NULL
                          ELSE d.founder_priority = p.label END)), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals d
              WHERE d.occurred_at >= now() - interval '90 days'
                AND d.resolved_at IS NOT NULL
                AND (CASE WHEN p.label = '(unprioritised)' THEN d.founder_priority IS NULL
                          ELSE d.founder_priority = p.label END)), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals d
              WHERE d.occurred_at >= now() - interval '90 days'
                AND d.resolved_at IS NULL
                AND (CASE WHEN p.label = '(unprioritised)' THEN d.founder_priority IS NULL
                          ELSE d.founder_priority = p.label END)), 0)::bigint
  FROM p
  ORDER BY p.ord;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_demand_signals_recent()
CREATE OR REPLACE FUNCTION public.founder_demand_signals_recent()
 RETURNS TABLE(id uuid, source text, reporter_role text, part_number text, equipment_model text, founder_priority text, resolved_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.source,
    d.reporter_role,
    d.part_number,
    d.equipment_model,
    d.founder_priority,
    d.resolved_at,
    d.occurred_at
  FROM public.spare_part_demand_signals d
  WHERE d.occurred_at >= now() - interval '30 days'
  ORDER BY d.occurred_at DESC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_availability_summary()
CREATE OR REPLACE FUNCTION public.founder_engineer_availability_summary()
 RETURNS TABLE(verified_engineers bigint, reachable_1h bigint, reachable_24h bigint, reachable_7d bigint, reachable_24h_pct numeric, open_repair_jobs bigint, open_code_reds bigint, unassigned_code_reds bigint, bids_last_1h bigint, bids_last_24h bigint, supply_to_open_demand numeric, hot_supply_share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_verified bigint;
  v_r24h     bigint;
  v_open_demand bigint;
  v_open_jobs bigint;
  v_open_reds bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_verified
    FROM public.engineers e
    WHERE coalesce(e.verification_status,'pending') = 'verified';

  SELECT count(DISTINCT b.engineer_user_id)::bigint INTO v_r24h
    FROM public.repair_job_bids b
    WHERE b.created_at >= now() - interval '24 hours';

  SELECT count(*)::bigint INTO v_open_jobs
    FROM public.repair_jobs WHERE status = 'requested';

  SELECT count(*)::bigint INTO v_open_reds
    FROM public.code_red_requests WHERE status = 'open';

  v_open_demand := coalesce(v_open_jobs,0) + coalesce(v_open_reds,0);

  RETURN QUERY
  SELECT
    coalesce(v_verified, 0),
    coalesce((SELECT count(DISTINCT b.engineer_user_id)::bigint FROM public.repair_job_bids b WHERE b.created_at >= now() - interval '1 hour'), 0),
    coalesce(v_r24h, 0),
    coalesce((SELECT count(DISTINCT b.engineer_user_id)::bigint FROM public.repair_job_bids b WHERE b.created_at >= now() - interval '7 days'), 0),
    CASE WHEN coalesce(v_verified,0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_r24h / v_verified, 1) END,
    coalesce(v_open_jobs, 0),
    coalesce(v_open_reds, 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status = 'open' AND accepted_engineer_user_id IS NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE created_at >= now() - interval '1 hour'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE created_at >= now() - interval '24 hours'), 0),
    CASE WHEN v_open_demand = 0 THEN 0::numeric
         ELSE round(v_r24h::numeric / v_open_demand::numeric, 2) END,
    CASE WHEN coalesce(v_verified,0) = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(DISTINCT b.engineer_user_id) FROM public.repair_job_bids b WHERE b.created_at >= now() - interval '1 hour'), 0) / v_verified, 1) END;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_earnings_distribution()
CREATE OR REPLACE FUNCTION public.founder_engineer_earnings_distribution()
 RETURNS TABLE(bucket text, bucket_order integer, engineer_cnt bigint, total_inr numeric, pct_of_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH earnings AS (
    SELECT p.engineer_user_id, sum(p.amount_rupees)::numeric AS total_earned
    FROM public.engineer_payouts p
    WHERE p.status IN ('processed','paid')
      AND p.queued_at >= now() - interval '90 days'
    GROUP BY p.engineer_user_id
  ),
  bucketed AS (
    SELECT
      total_earned,
      CASE
        WHEN total_earned < 1000   THEN '<₹1k'
        WHEN total_earned < 5000   THEN '₹1k-5k'
        WHEN total_earned < 10000  THEN '₹5k-10k'
        WHEN total_earned < 25000  THEN '₹10k-25k'
        WHEN total_earned < 50000  THEN '₹25k-50k'
        WHEN total_earned < 100000 THEN '₹50k-1L'
        ELSE '>₹1L'
      END                                  AS bucket,
      CASE
        WHEN total_earned < 1000   THEN 1
        WHEN total_earned < 5000   THEN 2
        WHEN total_earned < 10000  THEN 3
        WHEN total_earned < 25000  THEN 4
        WHEN total_earned < 50000  THEN 5
        WHEN total_earned < 100000 THEN 6
        ELSE 7
      END                                  AS bucket_order
    FROM earnings
  ),
  totals AS (
    SELECT count(*)::bigint AS n FROM bucketed
  )
  SELECT
    b.bucket::text,
    b.bucket_order::int,
    count(*)::bigint                                              AS engineer_cnt,
    sum(b.total_earned)::numeric                                  AS total_inr,
    CASE WHEN (SELECT n FROM totals) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / (SELECT n FROM totals), 1)
    END                                                            AS pct_of_total
  FROM bucketed b
  GROUP BY b.bucket, b.bucket_order
  ORDER BY b.bucket_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_fleet_expiring_docs(p_days integer)
CREATE OR REPLACE FUNCTION public.founder_engineer_fleet_expiring_docs(p_days integer DEFAULT 30)
 RETURNS TABLE(vehicle_id uuid, engineer_email text, registration_number text, make_model text, doc_kind text, expires_on date, days_until_expiry integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT v.id, u.email::text, v.registration_number, v.make_model,
         'insurance'::text, v.insurance_expiry,
         (v.insurance_expiry - current_date)::int
  FROM public.engineer_fleet_vehicles v
  LEFT JOIN auth.users u ON u.id = v.engineer_user_id
  WHERE v.insurance_expiry IS NOT NULL
    AND v.insurance_expiry <= (current_date + (COALESCE(p_days, 30) || ' days')::interval)::date
  UNION ALL
  SELECT v.id, u.email::text, v.registration_number, v.make_model,
         'puc'::text, v.puc_expiry,
         (v.puc_expiry - current_date)::int
  FROM public.engineer_fleet_vehicles v
  LEFT JOIN auth.users u ON u.id = v.engineer_user_id
  WHERE v.puc_expiry IS NOT NULL
    AND v.puc_expiry <= (current_date + (COALESCE(p_days, 30) || ' days')::interval)::date
  ORDER BY 6 ASC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_engineer_side_projects_by_risk_r1469()
CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_by_risk_r1469()
 RETURNS TABLE(coi_risk_band text, intel_count bigint, engineers_affected bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.conflict_risk, count(*)::bigint, count(DISTINCT i.engineer_id)::bigint
  FROM public.engineer_side_projects_intel_v2 i
  GROUP BY i.conflict_risk
  ORDER BY count(*) DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_side_projects_kpis_r1469()
CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_kpis_r1469()
 RETURNS TABLE(total_intel bigint, active_intel bigint, coi_flagged bigint, resolved_30d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE status NOT IN ('resolved','dismissed'))::bigint,
    count(*) FILTER (WHERE conflict_risk IN ('high','critical'))::bigint,
    count(*) FILTER (WHERE status='resolved' AND updated_at >= now() - interval '30 days')::bigint
  FROM public.engineer_side_projects_intel_v2;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_skills_proficiency_recent(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_engineer_skills_proficiency_recent(p_limit integer DEFAULT 80)
 RETURNS TABLE(id uuid, engineer_user_id uuid, engineer_name text, skill_label text, skill_kind text, importance_band text, proficiency_level text, self_assessed_at timestamp with time zone, founder_assessed_at timestamp with time zone, evidence_count integer, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder-only';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.engineer_user_id,
    COALESCE(pr.full_name, 'engineer'),
    t.skill_label,
    t.skill_kind,
    t.importance_band,
    p.proficiency_level,
    p.self_assessed_at,
    p.founder_assessed_at,
    COALESCE(array_length(p.evidence_uris, 1), 0),
    p.updated_at
  FROM public.engineer_skills_proficiency p
  JOIN public.engineer_skills_taxonomy   t ON t.id = p.skill_id
  LEFT JOIN public.profiles              pr ON pr.id = p.engineer_user_id
  ORDER BY p.updated_at DESC
  LIMIT COALESCE(p_limit, 80);
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_equipment_procurement_overdue()
CREATE OR REPLACE FUNCTION public.founder_equipment_procurement_overdue()
 RETURNS TABLE(id uuid, equipment_label text, procurement_stage text, expected_value_rupees numeric, expected_delivery_date date, days_overdue integer, hospital_label text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT p.id, p.equipment_label, p.procurement_stage, p.expected_value_rupees,
         p.expected_delivery_date,
         (current_date - p.expected_delivery_date)::int AS days_overdue,
         coalesce(o.name, prof.full_name, 'hospital'::text) AS hospital_label
    FROM public.founder_hospital_equipment_procurement_pipeline p
    LEFT JOIN public.profiles prof ON prof.id = p.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = prof.organization_id
   WHERE p.expected_delivery_date IS NOT NULL
     AND p.expected_delivery_date < current_date
     AND p.procurement_stage NOT IN ('delivered','installed','commissioned','cancelled')
   ORDER BY (current_date - p.expected_delivery_date) DESC
   LIMIT 30;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_equipment_procurement_recent()
CREATE OR REPLACE FUNCTION public.founder_equipment_procurement_recent()
 RETURNS TABLE(id uuid, equipment_label text, equipment_category text, procurement_stage text, expected_value_rupees numeric, vendor_org_id uuid, hospital_label text, expected_delivery_date date, actual_delivery_date date, days_in_stage integer, is_overdue boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT p.id,
         p.equipment_label,
         p.equipment_category,
         p.procurement_stage,
         p.expected_value_rupees,
         p.vendor_org_id,
         coalesce(o.name, prof.full_name, 'hospital'::text) AS hospital_label,
         p.expected_delivery_date,
         p.actual_delivery_date,
         extract(day FROM (now() - p.updated_at))::int AS days_in_stage,
         (p.expected_delivery_date IS NOT NULL
          AND p.expected_delivery_date < current_date
          AND p.procurement_stage NOT IN ('delivered','installed','commissioned','cancelled')) AS is_overdue,
         p.created_at,
         p.updated_at
    FROM public.founder_hospital_equipment_procurement_pipeline p
    LEFT JOIN public.profiles prof ON prof.id = p.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = prof.organization_id
   ORDER BY
     CASE p.procurement_stage
       WHEN 'commissioned' THEN 9 WHEN 'cancelled' THEN 10
       WHEN 'installed' THEN 8 WHEN 'delivered' THEN 7
       ELSE 0 END,
     p.updated_at DESC
   LIMIT 40;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_equipment_type_breakdown()
CREATE OR REPLACE FUNCTION public.founder_equipment_type_breakdown()
 RETURNS TABLE(equipment_type text, total_jobs bigint, completed_jobs bigint, open_jobs bigint, avg_completion_h numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(j.equipment_type::text), ''), '(unspecified)')::text       AS equipment_type,
    count(*)::bigint                                                          AS total_jobs,
    count(*) FILTER (WHERE j.status = 'completed')::bigint                    AS completed_jobs,
    count(*) FILTER (WHERE j.status = 'requested')::bigint                    AS open_jobs,
    round(
      avg(extract(epoch from (j.completed_at - j.created_at)) / 3600.0)
        FILTER (WHERE j.status = 'completed' AND j.completed_at IS NOT NULL),
      1
    )::numeric                                                                AS avg_completion_h
  FROM public.repair_jobs j
  WHERE j.created_at >= now() - interval '90 days'
  GROUP BY coalesce(nullif(trim(j.equipment_type::text), ''), '(unspecified)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_evidence_ledger_65b_summary()
CREATE OR REPLACE FUNCTION public.founder_evidence_ledger_65b_summary()
 RETURNS TABLE(total_evidence_rows bigint, rows_today bigint, rows_7d bigint, rows_30d bigint, distinct_evidence_kinds bigint, distinct_source_jobs bigint, top_kind text, top_kind_count bigint, pved_pdf_count bigint, dsr_pdf_count bigint, photo_before_count bigint, photo_after_count bigint, photo_during_count bigint, signature_engineer_count bigint, signature_hospital_count bigint, chat_archive_count bigint, amc_affidavit_count bigint, gst_invoice_pdf_count bigint, tds_certificate_count bigint, voice_note_count bigint, job_completion_otp_count bigint, parts_receipt_count bigint, producer_engineer_count bigint, producer_hospital_count bigint, producer_system_count bigint, producer_founder_count bigint, total_bytes_stored bigint, avg_bytes_per_row bigint, duplicate_hash_collisions bigint, unknown_platform_count bigint, jobs_missing_photo_before bigint, jobs_missing_photo_after bigint, jobs_with_full_photo_set bigint, newest_row_at timestamp with time zone, oldest_row_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_top_kind  text;
  v_top_count bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT evidence_kind, cnt INTO v_top_kind, v_top_count
  FROM (
    SELECT evidence_kind, count(*) AS cnt
      FROM public.evidence_ledger
     GROUP BY evidence_kind
     ORDER BY cnt DESC
     LIMIT 1
  ) t;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.evidence_ledger
  ),
  closed_jobs AS (
    SELECT id FROM public.repair_jobs
     WHERE status = 'completed'
  ),
  jobs_with_before AS (
    SELECT DISTINCT source_id FROM base
     WHERE source_kind = 'repair_job' AND evidence_kind = 'photo_before'
  ),
  jobs_with_after AS (
    SELECT DISTINCT source_id FROM base
     WHERE source_kind = 'repair_job' AND evidence_kind = 'photo_after'
  ),
  dup AS (
    SELECT content_sha256 FROM base
     GROUP BY content_sha256
    HAVING count(*) > 1
  )
  SELECT
    (SELECT count(*) FROM base)::bigint,
    (SELECT count(*) FROM base WHERE (created_at AT TIME ZONE 'Asia/Kolkata')::date = (now() AT TIME ZONE 'Asia/Kolkata')::date)::bigint,
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '7 days')::bigint,
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '30 days')::bigint,
    (SELECT count(DISTINCT evidence_kind) FROM base)::bigint,
    (SELECT count(DISTINCT source_id) FROM base WHERE source_kind = 'repair_job')::bigint,
    COALESCE(v_top_kind, 'none')::text,
    COALESCE(v_top_count, 0)::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'pved_pdf')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'dsr_pdf')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'photo_before')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'photo_after')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'photo_during')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'signature_engineer')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'signature_hospital')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'chat_archive')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'amc_affidavit')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'gst_invoice_pdf')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'tds_certificate')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'voice_note')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'job_completion_otp')::bigint,
    (SELECT count(*) FROM base WHERE evidence_kind = 'parts_receipt')::bigint,
    (SELECT count(*) FROM base WHERE producer_kind = 'engineer')::bigint,
    (SELECT count(*) FROM base WHERE producer_kind = 'hospital')::bigint,
    (SELECT count(*) FROM base WHERE producer_kind = 'system')::bigint,
    (SELECT count(*) FROM base WHERE producer_kind = 'founder')::bigint,
    COALESCE((SELECT sum(content_size_bytes) FROM base), 0)::bigint,
    COALESCE((SELECT (sum(content_size_bytes) / NULLIF(count(*),0))::bigint FROM base), 0)::bigint,
    (SELECT count(*) FROM dup)::bigint,
    (SELECT count(*) FROM base WHERE platform_version = 'unknown' OR platform_version IS NULL)::bigint,
    (SELECT count(*) FROM closed_jobs cj
       WHERE cj.id NOT IN (SELECT source_id FROM jobs_with_before))::bigint,
    (SELECT count(*) FROM closed_jobs cj
       WHERE cj.id NOT IN (SELECT source_id FROM jobs_with_after))::bigint,
    (SELECT count(*) FROM closed_jobs cj
       WHERE cj.id IN (SELECT source_id FROM jobs_with_before)
         AND cj.id IN (SELECT source_id FROM jobs_with_after))::bigint,
    (SELECT max(created_at) FROM base),
    (SELECT min(created_at) FROM base);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_gst_invoices_by_month_by_source()
CREATE OR REPLACE FUNCTION public.founder_gst_invoices_by_month_by_source()
 RETURNS TABLE(month_ist date, total_cnt bigint, repair_job_platform_fee_cnt bigint, amc_visit_platform_fee_cnt bigint, spare_part_platform_fee_cnt bigint, engineer_service_cnt bigint, refund_credit_note_cnt bigint, amc_subscription_fee_cnt bigint, total_taxable_inr numeric, total_gst_inr numeric, total_invoice_inr numeric)
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
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'repair_job_platform_fee'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'amc_visit_platform_fee'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'spare_part_platform_fee'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'engineer_service_to_hospital'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'refund_credit_note'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'amc_subscription_fee'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(i.taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(i.total_gst_rupees)::numeric FROM public.gst_invoices i
              WHERE date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(i.total_invoice_rupees)::numeric FROM public.gst_invoices i
              WHERE date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_heatmap_by_category()
CREATE OR REPLACE FUNCTION public.founder_heatmap_by_category()
 RETURNS TABLE(equipment_category text, contracts bigint, hospitals bigint, monthly_value_rupees bigint, annual_value_rupees bigint, avg_contract_rupees bigint, share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total bigint := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0) INTO v_total
    FROM amc_contracts WHERE status = 'active';

  RETURN QUERY
  SELECT cat.equipment_category,
         COUNT(*),
         COUNT(DISTINCT p.organization_id),
         COALESCE(SUM(ac.monthly_fee_rupees),0)::bigint,
         (COALESCE(SUM(ac.monthly_fee_rupees),0) * 12)::bigint,
         COALESCE(AVG(ac.monthly_fee_rupees)::bigint, 0),
         ROUND(COALESCE(SUM(ac.monthly_fee_rupees),0)::numeric / NULLIF(v_total,0) * 100, 3)
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
    CROSS JOIN LATERAL unnest(ac.equipment_categories) AS cat(equipment_category)
   WHERE ac.status = 'active'
   GROUP BY cat.equipment_category
   ORDER BY 4 DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_heatmap_by_hospital()
CREATE OR REPLACE FUNCTION public.founder_heatmap_by_hospital()
 RETURNS TABLE(hospital_org_id uuid, hospital_name text, hospital_city text, active_contracts bigint, distinct_categories bigint, monthly_value_rupees bigint, annual_value_rupees bigint, revenue_share_pct numeric, rn bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total bigint := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0) INTO v_total
    FROM amc_contracts WHERE status = 'active';

  RETURN QUERY
  SELECT o.id,
         o.name,
         o.city,
         COUNT(ac.id),
         (SELECT COUNT(DISTINCT cat.equipment_category)
            FROM amc_contracts ac2
            JOIN profiles p2 ON p2.id = ac2.hospital_user_id
            CROSS JOIN LATERAL unnest(ac2.equipment_categories) AS cat(equipment_category)
           WHERE ac2.status = 'active'
             AND p2.organization_id = o.id),
         COALESCE(SUM(ac.monthly_fee_rupees),0)::bigint,
         (COALESCE(SUM(ac.monthly_fee_rupees),0) * 12)::bigint,
         ROUND(COALESCE(SUM(ac.monthly_fee_rupees),0)::numeric / NULLIF(v_total,0) * 100, 3),
         ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(ac.monthly_fee_rupees),0) DESC)
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
   WHERE ac.status = 'active'
   GROUP BY o.id, o.name, o.city
   ORDER BY 6 DESC
   LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_heatmap_capture_snapshot()
CREATE OR REPLACE FUNCTION public.founder_heatmap_capture_snapshot()
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total bigint := 0;
  v_rows bigint := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0) INTO v_total
    FROM amc_contracts WHERE status = 'active';

  INSERT INTO founder_hospital_contract_heatmap_snapshots(
    hospital_org_id, hospital_name, hospital_city, equipment_category,
    active_contract_count, total_monthly_value_rupees, total_annualized_value_rupees,
    tier_mix, concentration_pct, diversification_score)
  SELECT o.id, o.name, o.city, cat.equipment_category,
         COUNT(*),
         COALESCE(SUM(ac.monthly_fee_rupees),0),
         COALESCE(SUM(ac.monthly_fee_rupees),0) * 12,
         jsonb_object_agg(COALESCE(ac.amc_tier::text,'unknown'), 1),
         COALESCE(ROUND(COALESCE(SUM(ac.monthly_fee_rupees),0)::numeric / NULLIF(v_total,0) * 100, 3), 0),
         0
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
    CROSS JOIN LATERAL unnest(ac.equipment_categories) AS cat(equipment_category)
   WHERE ac.status = 'active'
     AND cat.equipment_category IS NOT NULL
   GROUP BY o.id, o.name, o.city, cat.equipment_category;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'heatmap_capture_snapshot', jsonb_build_object('rows', v_rows));

  RETURN v_rows;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_heatmap_cells()
CREATE OR REPLACE FUNCTION public.founder_heatmap_cells()
 RETURNS TABLE(id text, hospital_org_id uuid, hospital_name text, equipment_category text, contract_count bigint, monthly_value_rupees bigint, amc_tier_mix text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT (o.id::text || ':' || cat.equipment_category),
         o.id,
         o.name,
         cat.equipment_category,
         COUNT(*),
         COALESCE(SUM(ac.monthly_fee_rupees),0)::bigint,
         string_agg(DISTINCT ac.amc_tier::text, ',' ORDER BY ac.amc_tier::text)
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
    CROSS JOIN LATERAL unnest(ac.equipment_categories) AS cat(equipment_category)
   WHERE ac.status = 'active'
   GROUP BY o.id, o.name, cat.equipment_category
   ORDER BY 6 DESC
   LIMIT 200;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_heatmap_gaps()
CREATE OR REPLACE FUNCTION public.founder_heatmap_gaps()
 RETURNS TABLE(hospital_org_id uuid, hospital_name text, hospital_city text, current_categories bigint, missing_categories text, monthly_value_rupees bigint, upsell_priority text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH all_cats AS (
    SELECT DISTINCT cat.equipment_category AS equipment_category
      FROM amc_contracts ac
      CROSS JOIN LATERAL unnest(ac.equipment_categories) AS cat(equipment_category)
     WHERE ac.status='active'
  ),
  hosp_fees AS (
    SELECT p.organization_id AS hospital_org_id,
           SUM(ac.monthly_fee_rupees) AS monthly_value
      FROM amc_contracts ac
      JOIN profiles p ON p.id = ac.hospital_user_id
     WHERE ac.status='active'
     GROUP BY p.organization_id
  ),
  hosp_cats AS (
    SELECT p.organization_id AS hospital_org_id,
           array_agg(DISTINCT cat.equipment_category) AS cats,
           COUNT(DISTINCT cat.equipment_category) AS cat_count
      FROM amc_contracts ac
      JOIN profiles p ON p.id = ac.hospital_user_id
      LEFT JOIN LATERAL unnest(ac.equipment_categories) AS cat(equipment_category) ON true
     WHERE ac.status='active'
     GROUP BY p.organization_id
  )
  SELECT o.id,
         o.name,
         o.city,
         hc.cat_count,
         (SELECT string_agg(equipment_category, ', ')
            FROM all_cats WHERE equipment_category != ALL(hc.cats)),
         COALESCE(hf.monthly_value,0)::bigint,
         CASE WHEN hf.monthly_value > 50000 THEN 'high'
              WHEN hf.monthly_value > 20000 THEN 'medium'
              ELSE 'low' END
    FROM hosp_cats hc
    JOIN hosp_fees hf ON hf.hospital_org_id = hc.hospital_org_id
    JOIN organizations o ON o.id = hc.hospital_org_id
   WHERE hc.cat_count < (SELECT COUNT(*) FROM all_cats)
   ORDER BY hf.monthly_value DESC NULLS LAST
   LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_heatmap_kpis()
CREATE OR REPLACE FUNCTION public.founder_heatmap_kpis()
 RETURNS TABLE(total_active_contracts bigint, total_hospitals bigint, total_monthly_revenue_rupees bigint, total_annual_revenue_rupees bigint, top1_hospital_share_pct numeric, top5_hospital_share_pct numeric, top10_hospital_share_pct numeric, herfindahl_index numeric, distinct_categories bigint, distinct_cities bigint, open_concentration_alerts bigint, largest_single_contract_rupees bigint, median_contract_rupees bigint, hospitals_with_single_category bigint, hospitals_with_three_plus_categories bigint, diversification_score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total_monthly bigint := 0;
  v_total_contracts bigint := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0), COUNT(*)
    INTO v_total_monthly, v_total_contracts
    FROM amc_contracts
   WHERE status = 'active';

  RETURN QUERY
  WITH hosp AS (
    SELECT p.organization_id AS hospital_org_id,
           SUM(ac.monthly_fee_rupees) AS monthly_value
      FROM amc_contracts ac
      JOIN profiles p ON p.id = ac.hospital_user_id
     WHERE ac.status = 'active'
     GROUP BY p.organization_id
  ),
  ranked AS (
    SELECT hospital_org_id, monthly_value,
           ROW_NUMBER() OVER (ORDER BY monthly_value DESC NULLS LAST) AS rn
      FROM hosp
  ),
  cat_per_hosp AS (
    SELECT p.organization_id AS hospital_org_id,
           COUNT(DISTINCT cat.equipment_category) AS cat_count
      FROM amc_contracts ac
      JOIN profiles p ON p.id = ac.hospital_user_id
      LEFT JOIN LATERAL unnest(ac.equipment_categories) AS cat(equipment_category) ON true
     WHERE ac.status = 'active'
     GROUP BY p.organization_id
  )
  SELECT
    v_total_contracts,
    (SELECT COUNT(*) FROM hosp),
    v_total_monthly,
    v_total_monthly * 12,
    COALESCE((SELECT ROUND(monthly_value::numeric / NULLIF(v_total_monthly,0) * 100, 2) FROM ranked WHERE rn = 1), 0),
    COALESCE((SELECT ROUND(SUM(monthly_value)::numeric / NULLIF(v_total_monthly,0) * 100, 2) FROM ranked WHERE rn <= 5), 0),
    COALESCE((SELECT ROUND(SUM(monthly_value)::numeric / NULLIF(v_total_monthly,0) * 100, 2) FROM ranked WHERE rn <= 10), 0),
    COALESCE((SELECT ROUND(SUM(POWER(monthly_value::numeric / NULLIF(v_total_monthly,0) * 100, 2)), 2) FROM ranked), 0),
    (SELECT COUNT(DISTINCT cat.equipment_category)
       FROM amc_contracts ac2
       CROSS JOIN LATERAL unnest(ac2.equipment_categories) AS cat(equipment_category)
      WHERE ac2.status = 'active'),
    (SELECT COUNT(DISTINCT o.city) FROM amc_contracts ac
        JOIN profiles p ON p.id = ac.hospital_user_id
        JOIN organizations o ON o.id = p.organization_id
       WHERE ac.status = 'active'),
    (SELECT COUNT(*) FROM founder_hospital_concentration_alerts WHERE acknowledged_at IS NULL),
    COALESCE((SELECT MAX(monthly_fee_rupees)::bigint FROM amc_contracts WHERE status='active'), 0),
    COALESCE((SELECT (percentile_cont(0.5) WITHIN GROUP (ORDER BY monthly_fee_rupees))::bigint
                FROM amc_contracts WHERE status='active'), 0),
    (SELECT COUNT(*) FROM cat_per_hosp WHERE cat_count = 1),
    (SELECT COUNT(*) FROM cat_per_hosp WHERE cat_count >= 3),
    COALESCE((SELECT ROUND(100 - SUM(POWER(monthly_value::numeric / NULLIF(v_total_monthly,0) * 100, 2)) / 100.0, 2) FROM ranked), 0);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_chains_drilldown_by_chain(p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_hospital_chains_drilldown_by_chain(p_limit integer DEFAULT 30)
 RETURNS TABLE(chain_id uuid, chain_name text, status text, total_hospitals_onboarded bigint, total_active_amcs bigint, total_mrr_rupees numeric, last_activity_at timestamp with time zone, days_since_last_activity numeric, churn_risk_band text, primary_state text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH per_chain AS (
    SELECT
      c.id   AS chain_id,
      c.name AS chain_name,
      c.status,
      coalesce((SELECT count(*)::bigint FROM public.hospital_chain_memberships m
                 WHERE m.chain_id = c.id), 0) AS hospitals,
      coalesce((SELECT count(*)::bigint
                  FROM public.amc_contracts a
                  JOIN public.hospital_chain_memberships m
                    ON m.hospital_user_id = a.hospital_user_id
                 WHERE m.chain_id = c.id AND a.status = 'active'), 0) AS amcs,
      coalesce((SELECT sum(a.monthly_fee_rupees)::numeric
                  FROM public.amc_contracts a
                  JOIN public.hospital_chain_memberships m
                    ON m.hospital_user_id = a.hospital_user_id
                 WHERE m.chain_id = c.id AND a.status = 'active'), 0) AS mrr,
      (SELECT max(rj.created_at)
         FROM public.repair_jobs rj
         JOIN public.hospital_chain_memberships m
           ON m.hospital_user_id = rj.hospital_user_id
        WHERE m.chain_id = c.id) AS last_act,
      (SELECT o.state
         FROM public.hospital_chain_memberships m
         JOIN public.profiles p ON p.id = m.hospital_user_id
         JOIN public.organizations o ON o.id = p.organization_id
        WHERE m.chain_id = c.id AND o.state IS NOT NULL
        GROUP BY o.state
        ORDER BY count(*) DESC
        LIMIT 1) AS p_state
    FROM public.hospital_chains c
  )
  SELECT
    pc.chain_id,
    pc.chain_name,
    pc.status,
    pc.hospitals,
    pc.amcs,
    pc.mrr,
    pc.last_act,
    CASE WHEN pc.last_act IS NULL THEN NULL
         ELSE round(EXTRACT(epoch FROM (now() - pc.last_act)) / 86400.0, 1) END,
    CASE
      WHEN pc.status = 'churned' THEN 'high'
      WHEN pc.last_act IS NULL THEN 'high'
      WHEN pc.last_act < now() - interval '60 days' THEN 'high'
      WHEN pc.last_act < now() - interval '30 days' THEN 'medium'
      ELSE 'low'
    END,
    coalesce(pc.p_state, '—')
  FROM per_chain pc
  ORDER BY pc.mrr DESC NULLS LAST, pc.hospitals DESC
  LIMIT greatest(coalesce(p_limit, 30), 1);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_chains_drilldown_summary()
CREATE OR REPLACE FUNCTION public.founder_hospital_chains_drilldown_summary()
 RETURNS TABLE(total_chains bigint, prospecting_count bigint, signed_count bigint, live_count bigint, churned_count bigint, total_hospitals_under_chains bigint, total_engineers_serving_chains bigint, total_amc_mrr_from_chains_rupees numeric, top_chain_by_hospital_count text, top_chain_name text, top_chain_hospital_count bigint, avg_hospitals_per_chain numeric, top_state_for_chains text, conversion_pct_prospecting_to_live numeric, days_to_signed_median numeric, chain_revenue_concentration_top3_pct numeric, chain_revenue_concentration_top10_pct numeric, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_chains       bigint;
  v_total_mrr          numeric;
  v_total_hospitals    bigint;
  v_total_engineers    bigint;
  v_top_chain_id       uuid;
  v_top_chain_name     text;
  v_top_chain_count    bigint;
  v_top_state          text;
  v_prospecting        bigint;
  v_live               bigint;
  v_conv_pct           numeric;
  v_median_days        numeric;
  v_top3_pct           numeric;
  v_top10_pct          numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT count(*)::bigint INTO v_total_chains FROM public.hospital_chains;
  v_total_chains := coalesce(v_total_chains, 0);

  SELECT count(*)::bigint INTO v_prospecting
    FROM public.hospital_chains WHERE status = 'prospecting';
  v_prospecting := coalesce(v_prospecting, 0);

  SELECT count(*)::bigint INTO v_live
    FROM public.hospital_chains WHERE status = 'live';
  v_live := coalesce(v_live, 0);

  SELECT count(DISTINCT m.hospital_user_id)::bigint
    INTO v_total_hospitals
    FROM public.hospital_chain_memberships m;
  v_total_hospitals := coalesce(v_total_hospitals, 0);

  SELECT count(DISTINCT rj.engineer_id)::bigint
    INTO v_total_engineers
    FROM public.repair_jobs rj
    JOIN public.hospital_chain_memberships m
      ON m.hospital_user_id = rj.hospital_user_id
   WHERE rj.engineer_id IS NOT NULL
     AND rj.created_at >= now() - interval '90 days';
  v_total_engineers := coalesce(v_total_engineers, 0);

  SELECT coalesce(sum(a.monthly_fee_rupees), 0)::numeric
    INTO v_total_mrr
    FROM public.amc_contracts a
    JOIN public.hospital_chain_memberships m
      ON m.hospital_user_id = a.hospital_user_id
   WHERE a.status = 'active';

  SELECT c.id, c.name, cnt
    INTO v_top_chain_id, v_top_chain_name, v_top_chain_count
    FROM (
      SELECT m.chain_id, count(*)::bigint AS cnt
        FROM public.hospital_chain_memberships m
       GROUP BY m.chain_id
       ORDER BY cnt DESC
       LIMIT 1
    ) x
    JOIN public.hospital_chains c ON c.id = x.chain_id;

  SELECT o.state INTO v_top_state
    FROM public.hospital_chain_memberships m
    JOIN public.profiles p ON p.id = m.hospital_user_id
    JOIN public.organizations o ON o.id = p.organization_id
   WHERE o.state IS NOT NULL
   GROUP BY o.state
   ORDER BY count(*) DESC
   LIMIT 1;

  v_conv_pct := CASE WHEN v_prospecting + v_live = 0 THEN 0
    ELSE round(100.0 * v_live::numeric / (v_prospecting + v_live)::numeric, 1) END;

  SELECT percentile_cont(0.5) WITHIN GROUP (
    ORDER BY EXTRACT(epoch FROM (contracted_at - created_at)) / 86400.0
  )::numeric
    INTO v_median_days
    FROM public.hospital_chains
   WHERE contracted_at IS NOT NULL;
  v_median_days := coalesce(v_median_days, 0);

  WITH chain_mrr AS (
    SELECT m.chain_id, sum(a.monthly_fee_rupees)::numeric AS mrr
      FROM public.amc_contracts a
      JOIN public.hospital_chain_memberships m
        ON m.hospital_user_id = a.hospital_user_id
     WHERE a.status = 'active'
     GROUP BY m.chain_id
  ),
  ranked AS (
    SELECT mrr, row_number() OVER (ORDER BY mrr DESC) AS rn,
           sum(mrr) OVER () AS total
      FROM chain_mrr
  )
  SELECT
    CASE WHEN max(total) = 0 THEN 0
         ELSE round(100.0 * coalesce(sum(mrr) FILTER (WHERE rn <= 3), 0) / max(total), 1) END,
    CASE WHEN max(total) = 0 THEN 0
         ELSE round(100.0 * coalesce(sum(mrr) FILTER (WHERE rn <= 10), 0) / max(total), 1) END
    INTO v_top3_pct, v_top10_pct
    FROM ranked;

  RETURN QUERY SELECT
    v_total_chains,
    v_prospecting,
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains WHERE status = 'signed'), 0),
    v_live,
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains WHERE status = 'churned'), 0),
    v_total_hospitals,
    v_total_engineers,
    coalesce(v_total_mrr, 0),
    coalesce(v_top_chain_name, '—'),
    coalesce(v_top_chain_name, '—'),
    coalesce(v_top_chain_count, 0),
    CASE WHEN v_total_chains = 0 THEN 0
         ELSE round(v_total_hospitals::numeric / v_total_chains, 2) END,
    coalesce(v_top_state, '—'),
    v_conv_pct,
    v_median_days,
    coalesce(v_top3_pct, 0),
    coalesce(v_top10_pct, 0),
    now();
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_expansion_existing_action_queue()
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_action_queue()
 RETURNS TABLE(id uuid, hospital_user_id uuid, hospital_name text, action_kind text, due_date date, priority integer, done boolean, notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT q.id,
         q.hospital_user_id,
         coalesce(o.name, p.full_name, p.email) AS hospital_name,
         q.action_kind,
         q.due_date,
         q.priority,
         q.done,
         q.notes,
         q.created_at
  FROM public.founder_hospital_expansion_action_queue q
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY q.done ASC, q.priority ASC, q.due_date ASC
  LIMIT 300;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_expansion_existing_candidates()
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_candidates()
 RETURNS TABLE(hospital_user_id uuid, hospital_name text, state text, active_amcs bigint, current_tier text, current_categories text[], ltm_repair_spend_rupees numeric, jobs_ltm bigint, avg_rating numeric, upgrade_signal_score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH amc AS (
    SELECT a.hospital_user_id,
           count(*) AS active_amcs,
           max(a.amc_tier) AS current_tier,
           coalesce(array_agg(DISTINCT cat) FILTER (WHERE cat IS NOT NULL), ARRAY[]::text[]) AS current_categories
    FROM public.amc_contracts a
    LEFT JOIN LATERAL unnest(a.equipment_categories) cat ON true
    GROUP BY a.hospital_user_id
  ),
  jobs AS (
    SELECT r.hospital_org_id,
           coalesce(sum(r.contracted_amount_rupees),0) AS spend,
           count(*) AS jobs_ltm,
           avg(r.hospital_rating) AS avg_rating
    FROM public.repair_jobs r
    WHERE r.created_at > now() - interval '365 days'
    GROUP BY r.hospital_org_id
  )
  SELECT p.id,
         coalesce(o.name, p.full_name, p.email) AS hospital_name,
         o.state,
         coalesce(amc.active_amcs,0),
         amc.current_tier,
         coalesce(amc.current_categories, ARRAY[]::text[]),
         coalesce(j.spend, 0),
         coalesce(j.jobs_ltm, 0),
         round(coalesce(j.avg_rating,0)::numeric, 2),
         round(
           (coalesce(j.spend,0)/10000.0)
           + (coalesce(j.jobs_ltm,0) * 2)
           + (coalesce(j.avg_rating,0) * 5)
         , 2) AS upgrade_signal_score
  FROM public.profiles p
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  LEFT JOIN amc ON amc.hospital_user_id = p.id
  LEFT JOIN jobs j ON j.hospital_org_id = p.organization_id
  WHERE amc.active_amcs > 0
  ORDER BY upgrade_signal_score DESC NULLS LAST
  LIMIT 200;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_expansion_existing_plays_list()
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_plays_list()
 RETURNS TABLE(id uuid, hospital_user_id uuid, hospital_name text, play_kind text, current_tier text, target_tier text, monthly_uplift_rupees numeric, confidence_score numeric, status text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT pl.id,
         pl.hospital_user_id,
         coalesce(o.name, p.full_name, p.email),
         pl.play_kind,
         pl.current_tier,
         pl.target_tier,
         pl.monthly_uplift_rupees,
         pl.confidence_score,
         pl.status,
         pl.created_at
  FROM public.founder_hospital_expansion_plays pl
  LEFT JOIN public.profiles p ON p.id = pl.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY pl.created_at DESC
  LIMIT 200;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_leaderboard_30d()
CREATE OR REPLACE FUNCTION public.founder_hospital_leaderboard_30d()
 RETURNS TABLE(hospital_name text, jobs_posted bigint, jobs_completed bigint, total_spend_inr numeric, amc_count bigint, last_active_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH posted AS (
    SELECT j.hospital_user_id,
           count(*)::bigint                              AS jobs_posted,
           count(*) FILTER (WHERE j.status = 'completed')::bigint AS jobs_completed,
           coalesce(sum(j.contracted_amount_rupees) FILTER (WHERE j.status = 'completed'), 0)::numeric AS spend,
           max(j.created_at)                             AS last_at
    FROM public.repair_jobs j
    WHERE j.hospital_user_id IS NOT NULL
      AND j.created_at >= now() - interval '30 days'
    GROUP BY j.hospital_user_id
  )
  SELECT
    coalesce(p2.full_name, '(no name)')::text                            AS hospital_name,
    pp.jobs_posted,
    pp.jobs_completed,
    pp.spend                                                              AS total_spend_inr,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.hospital_user_id = pp.hospital_user_id
                AND c.status IN ('active','paused')), 0)::bigint          AS amc_count,
    pp.last_at                                                            AS last_active_at
  FROM posted pp
  LEFT JOIN public.profiles p2 ON p2.id = pp.hospital_user_id
  ORDER BY pp.jobs_posted DESC, pp.spend DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_maintenance_calendar_overdue()
CREATE OR REPLACE FUNCTION public.founder_hospital_maintenance_calendar_overdue()
 RETURNS TABLE(id uuid, amc_contract_id uuid, equipment_label text, scheduled_date date, visit_kind text, status text, days_overdue integer, hospital_name text, amc_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.amc_contract_id,
    s.equipment_label,
    s.scheduled_date,
    s.visit_kind,
    s.status,
    (current_date - s.scheduled_date)::int AS days_overdue,
    coalesce(o.name, p.full_name, 'Unknown') AS hospital_name,
    a.amc_tier::text
  FROM public.founder_hospital_maintenance_schedule s
  LEFT JOIN public.amc_contracts a ON a.id = s.amc_contract_id
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE s.scheduled_date < current_date
    AND s.status IN ('scheduled','assigned')
  ORDER BY s.scheduled_date ASC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_maintenance_calendar_recent()
CREATE OR REPLACE FUNCTION public.founder_hospital_maintenance_calendar_recent()
 RETURNS TABLE(id uuid, amc_contract_id uuid, equipment_label text, scheduled_date date, visit_kind text, status text, expected_minutes integer, assigned_engineer_id uuid, amc_tier text, hospital_name text, days_until integer, is_overdue boolean, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.amc_contract_id,
    s.equipment_label,
    s.scheduled_date,
    s.visit_kind,
    s.status,
    s.expected_minutes,
    s.assigned_engineer_id,
    a.amc_tier::text,
    coalesce(o.name, p.full_name, 'Unknown') AS hospital_name,
    (s.scheduled_date - current_date)::int AS days_until,
    (s.scheduled_date < current_date AND s.status IN ('scheduled','assigned')) AS is_overdue,
    s.created_at
  FROM public.founder_hospital_maintenance_schedule s
  LEFT JOIN public.amc_contracts a ON a.id = s.amc_contract_id
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.scheduled_date ASC, s.created_at DESC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_jobs_by_engineer_tier()
CREATE OR REPLACE FUNCTION public.founder_jobs_by_engineer_tier()
 RETURNS TABLE(tier text, jobs_90d bigint, gross_90d numeric, engineers bigint, avg_per_engineer numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers(tier, ord) AS (
    VALUES ('none'::text, 1), ('bronze'::text, 2), ('silver'::text, 3), ('gold'::text, 4)
  ),
  per_tier AS (
    SELECT
      coalesce(ecp.current_tier, 'none') AS tier,
      rj.contracted_amount_rupees,
      b.engineer_user_id
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    LEFT JOIN public.engineer_certification_progress ecp ON ecp.engineer_user_id = b.engineer_user_id
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM per_tier pt WHERE pt.tier = t.tier), 0)::bigint,
    coalesce((SELECT sum(pt.contracted_amount_rupees)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 0)::numeric,
    coalesce((SELECT count(DISTINCT pt.engineer_user_id)::bigint FROM per_tier pt WHERE pt.tier = t.tier), 0)::bigint,
    CASE WHEN coalesce((SELECT count(DISTINCT pt.engineer_user_id) FROM per_tier pt WHERE pt.tier = t.tier), 0) = 0 THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(pt.contracted_amount_rupees)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 0)
           / coalesce((SELECT count(DISTINCT pt.engineer_user_id)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 1)
         , 2)
    END
  FROM tiers t
  ORDER BY t.ord;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_jobs_completion_by_tier()
CREATE OR REPLACE FUNCTION public.founder_jobs_completion_by_tier()
 RETURNS TABLE(tier text, accepted_90d bigint, completed_90d bigint, cancelled_90d bigint, completion_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers(tier, ord) AS (
    VALUES ('none'::text, 1), ('bronze', 2), ('silver', 3), ('gold', 4)
  ),
  base AS (
    SELECT
      coalesce(ecp.current_tier, 'none') AS tier,
      rj.status
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
    LEFT JOIN public.engineer_certification_progress ecp ON ecp.engineer_user_id = b.engineer_user_id
    WHERE b.status = 'accepted'
      AND b.created_at >= now() - interval '90 days'
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM base b WHERE b.tier = t.tier), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM base b WHERE b.tier = t.tier AND b.status = 'completed'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM base b WHERE b.tier = t.tier AND b.status = 'cancelled'), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM base b WHERE b.tier = t.tier), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM base b WHERE b.tier = t.tier AND b.status = 'completed')
           / (SELECT count(*)::numeric FROM base b WHERE b.tier = t.tier)
           * 100.0, 1)
    END
  FROM tiers t
  ORDER BY t.ord;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_jobs_snapshot_summary()
CREATE OR REPLACE FUNCTION public.founder_jobs_snapshot_summary()
 RETURNS TABLE(total_all_time bigint, open_now bigint, in_progress_now bigint, completed_30d bigint, cancelled_30d bigint, unassigned_over_24h bigint, bids_pending_now bigint, hospitals_active_30d bigint, engineers_active_30d bigint, posted_today bigint, completed_today bigint, avg_completion_hours numeric)
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
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'requested'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status IN ('in_progress','assigned')), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'cancelled' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'requested' AND engineer_id IS NULL AND created_at < now() - interval '24 hours'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status IN ('submitted','pending')), 0),
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.repair_jobs WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT engineer_id)::bigint FROM public.repair_jobs WHERE engineer_id IS NOT NULL AND status = 'completed' AND completed_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= v_today_start AND completed_at < v_today_end), 0),
    coalesce((SELECT round(avg(extract(epoch FROM (completed_at - created_at)) / 3600.0)::numeric, 1)
              FROM public.repair_jobs
              WHERE status = 'completed' AND completed_at >= now() - interval '30 days' AND completed_at IS NOT NULL), 0)::numeric;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_jobs_unassigned_aging()
CREATE OR REPLACE FUNCTION public.founder_jobs_unassigned_aging()
 RETURNS TABLE(bucket text, bucket_order integer, cnt bigint, oldest_created_at timestamp with time zone)
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
        WHEN j.created_at >= now() - interval '1 hour'    THEN '<1h'
        WHEN j.created_at >= now() - interval '4 hours'   THEN '1-4h'
        WHEN j.created_at >= now() - interval '24 hours'  THEN '4-24h'
        WHEN j.created_at >= now() - interval '3 days'    THEN '1-3d'
        WHEN j.created_at >= now() - interval '7 days'    THEN '3-7d'
        ELSE '>7d'
      END                                          AS bucket,
      CASE
        WHEN j.created_at >= now() - interval '1 hour'    THEN 1
        WHEN j.created_at >= now() - interval '4 hours'   THEN 2
        WHEN j.created_at >= now() - interval '24 hours'  THEN 3
        WHEN j.created_at >= now() - interval '3 days'    THEN 4
        WHEN j.created_at >= now() - interval '7 days'    THEN 5
        ELSE 6
      END                                          AS bucket_order,
      j.created_at
    FROM public.repair_jobs j
    WHERE j.engineer_id IS NULL
      AND j.status = 'requested'
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint           AS cnt,
    min(a.created_at)          AS oldest_created_at
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_live_ops_cockpit_v2_heartbeat()
CREATE OR REPLACE FUNCTION public.founder_live_ops_cockpit_v2_heartbeat()
 RETURNS TABLE(open_priority_actions integer, open_incidents integer, code_red_open integer, cron_failure_rate_24h numeric, dpdp_grievances_open integer, payouts_queued integer, billing_invoiced_30d_rupees bigint, billing_outstanding_rupees bigint, calendar_overdue_count integer, calendar_due_30d integer, total_active_amcs integer, total_active_engineers integer, generated_at timestamp with time zone, last_morning_pulse_at timestamp with time zone, hospitals_at_risk_count integer, system_health_score integer, most_recent_critical_event_at timestamp with time zone, alerts_red_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_open_priority integer := 0;
  v_open_incidents integer := 0;
  v_code_red integer := 0;
  v_cron_fail numeric := 0;
  v_dpdp integer := 0;
  v_payouts integer := 0;
  v_billed bigint := 0;
  v_outstanding bigint := 0;
  v_overdue integer := 0;
  v_due_30 integer := 0;
  v_amcs integer := 0;
  v_engineers integer := 0;
  v_pulse_at timestamptz;
  v_risk integer := 0;
  v_health integer := 100;
  v_critical_at timestamptz;
  v_alerts_red integer := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  -- 1. Open priority actions
  BEGIN
    SELECT COUNT(*) INTO v_open_priority
      FROM public.founder_priority_actions
      WHERE action_taken IS NULL;
  EXCEPTION WHEN OTHERS THEN v_open_priority := 0; END;

  -- 2. Open incidents (last 30d, not resolved)
  BEGIN
    SELECT COUNT(*) INTO v_open_incidents
      FROM public.founder_incidents
      WHERE resolved_at IS NULL
        AND opened_at >= now() - interval '30 days';
  EXCEPTION WHEN OTHERS THEN v_open_incidents := 0; END;

  -- 3. Code red open
  BEGIN
    SELECT COUNT(*) INTO v_code_red
      FROM public.code_red_requests
      WHERE status IN ('open','engineer_accepted');
  EXCEPTION WHEN OTHERS THEN v_code_red := 0; END;

  -- 4. Cron failure rate 24h
  BEGIN
    SELECT COALESCE(
      ROUND(
        100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END)::numeric
             / NULLIF(COUNT(*),0)::numeric,
      2), 0)
    INTO v_cron_fail
    FROM cron.job_run_details
    WHERE start_time >= now() - interval '24 hours';
  EXCEPTION WHEN OTHERS THEN v_cron_fail := 0; END;

  -- 5. DPDP grievances open
  BEGIN
    SELECT COUNT(*) INTO v_dpdp
      FROM public.dpdp_grievances
      WHERE status IN ('open','in_review','escalated');
  EXCEPTION WHEN OTHERS THEN v_dpdp := 0; END;

  -- 6. Payouts queued
  BEGIN
    SELECT COUNT(*) INTO v_payouts
      FROM public.engineer_payouts
      WHERE status IN ('queued','processing');
  EXCEPTION WHEN OTHERS THEN v_payouts := 0; END;

  -- 7. Billing invoiced 30d
  BEGIN
    SELECT COALESCE(SUM(amount),0)::bigint INTO v_billed
      FROM public.payments
      WHERE created_at >= now() - interval '30 days'
        AND status = 'completed';
  EXCEPTION WHEN OTHERS THEN v_billed := 0; END;

  -- 8. Billing outstanding (pending/failed unsettled)
  BEGIN
    SELECT COALESCE(SUM(amount),0)::bigint INTO v_outstanding
      FROM public.payments
      WHERE created_at >= now() - interval '60 days'
        AND status IN ('pending','failed');
  EXCEPTION WHEN OTHERS THEN v_outstanding := 0; END;

  -- 9. Calendar overdue (maintenance jobs past due, not completed)
  BEGIN
    SELECT COUNT(*) INTO v_overdue
      FROM public.repair_jobs
      WHERE kind = 'maintenance'
        AND completed_at IS NULL
        AND scheduled_date < current_date;
  EXCEPTION WHEN OTHERS THEN v_overdue := 0; END;

  -- 10. Calendar due in next 30d
  BEGIN
    SELECT COUNT(*) INTO v_due_30
      FROM public.repair_jobs
      WHERE kind = 'maintenance'
        AND completed_at IS NULL
        AND scheduled_date BETWEEN current_date AND current_date + 30;
  EXCEPTION WHEN OTHERS THEN v_due_30 := 0; END;

  -- 11. Total active AMCs
  BEGIN
    SELECT COUNT(*) INTO v_amcs
      FROM public.amc_contracts
      WHERE status = 'active';
  EXCEPTION WHEN OTHERS THEN v_amcs := 0; END;

  -- 12. Total active engineers
  BEGIN
    SELECT COUNT(*) INTO v_engineers
      FROM public.engineers
      WHERE verification_status = 'verified';
  EXCEPTION WHEN OTHERS THEN v_engineers := 0; END;

  -- 13. Last morning pulse run (cron timestamp)
  BEGIN
    SELECT MAX(start_time) INTO v_pulse_at
      FROM cron.job_run_details d
      JOIN cron.job j ON j.jobid = d.jobid
      WHERE j.jobname ILIKE '%morning%pulse%';
  EXCEPTION WHEN OTHERS THEN v_pulse_at := NULL; END;

  -- 14. Hospitals at risk proxy (open incidents + open disputes)
  BEGIN
    SELECT COALESCE(
      (SELECT COUNT(DISTINCT source_item_id)
         FROM public.founder_incidents
         WHERE resolved_at IS NULL),
      0
    ) + COALESCE(
      (SELECT COUNT(DISTINCT raised_by_org_id)
         FROM public.disputes
         WHERE status IN ('open','escalated')),
      0
    ) INTO v_risk;
  EXCEPTION WHEN OTHERS THEN v_risk := 0; END;

  -- 15. Most recent critical event (incident severity = high)
  BEGIN
    SELECT MAX(opened_at) INTO v_critical_at
      FROM public.founder_incidents
      WHERE severity IN ('p0','p1')
        AND opened_at >= now() - interval '7 days';
  EXCEPTION WHEN OTHERS THEN v_critical_at := NULL; END;

  -- 16. Red alerts: cron fail >10% OR code-red >5 OR payouts queued >20 OR overdue >10
  v_alerts_red := 0;
  IF v_cron_fail > 10 THEN v_alerts_red := v_alerts_red + 1; END IF;
  IF v_code_red > 5 THEN v_alerts_red := v_alerts_red + 1; END IF;
  IF v_payouts > 20 THEN v_alerts_red := v_alerts_red + 1; END IF;
  IF v_overdue > 10 THEN v_alerts_red := v_alerts_red + 1; END IF;
  IF v_dpdp > 3 THEN v_alerts_red := v_alerts_red + 1; END IF;

  -- 17. System health 0..100 (subtract per red flag class)
  v_health := 100
    - LEAST(40, (v_cron_fail * 2)::integer)
    - LEAST(15, v_code_red * 3)
    - LEAST(15, v_open_incidents)
    - LEAST(10, v_dpdp * 3)
    - LEAST(10, v_overdue)
    - LEAST(10, v_alerts_red * 5);
  IF v_health < 0 THEN v_health := 0; END IF;

  RETURN QUERY SELECT
    v_open_priority,
    v_open_incidents,
    v_code_red,
    v_cron_fail,
    v_dpdp,
    v_payouts,
    v_billed,
    v_outstanding,
    v_overdue,
    v_due_30,
    v_amcs,
    v_engineers,
    now() AS generated_at,
    v_pulse_at,
    v_risk,
    v_health,
    v_critical_at,
    v_alerts_red;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_monthly_cash_ledger_history(p_months integer)
CREATE OR REPLACE FUNCTION public.founder_monthly_cash_ledger_history(p_months integer DEFAULT 12)
 RETURNS TABLE(month_start date, snapshot_balance_rupees numeric, inflow_captured_rupees numeric, outflow_payouts_rupees numeric, outflow_spares_rupees numeric, net_change_rupees numeric, reconciliation_diff_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_months int := GREATEST(1, LEAST(COALESCE(p_months, 12), 36));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', CURRENT_DATE) - ((v_months - 1) || ' months')::interval,
      date_trunc('month', CURRENT_DATE),
      INTERVAL '1 month'
    )::date AS m
  ),
  snap_per_month AS (
    SELECT DISTINCT ON (date_trunc('month', snapshot_date))
      date_trunc('month', snapshot_date)::date AS m,
      cash_balance_rupees
    FROM public.founder_cash_position_snapshots
    ORDER BY date_trunc('month', snapshot_date), snapshot_date DESC
  ),
  inflow AS (
    SELECT
      date_trunc('month', created_at)::date AS m,
      COALESCE(SUM(amount), 0)::numeric AS amt
    FROM public.payments
    WHERE status = 'completed'
    GROUP BY 1
  ),
  payouts AS (
    SELECT
      date_trunc('month', COALESCE(processed_at, created_at))::date AS m,
      COALESCE(SUM(amount_rupees), 0)::numeric AS amt
    FROM public.engineer_payouts
    WHERE status = 'processed'
    GROUP BY 1
  ),
  spares AS (
    SELECT
      date_trunc('month', created_at)::date AS m,
      COALESCE(SUM(total_amount), 0)::numeric AS amt
    FROM public.spare_part_orders
    WHERE payment_status = 'completed'
    GROUP BY 1
  ),
  computed AS (
    SELECT
      mo.m AS month_start,
      sp.cash_balance_rupees AS snap_bal,
      COALESCE(i.amt, 0) AS inflow_amt,
      COALESCE(p.amt, 0) AS payout_amt,
      COALESCE(s.amt, 0) AS spare_amt,
      (COALESCE(i.amt, 0) - COALESCE(p.amt, 0) - COALESCE(s.amt, 0)) AS net_amt,
      LAG(sp.cash_balance_rupees) OVER (ORDER BY mo.m) AS prev_snap_bal
    FROM months mo
    LEFT JOIN snap_per_month sp ON sp.m = mo.m
    LEFT JOIN inflow i ON i.m = mo.m
    LEFT JOIN payouts p ON p.m = mo.m
    LEFT JOIN spares s ON s.m = mo.m
  )
  SELECT
    c.month_start,
    c.snap_bal,
    c.inflow_amt,
    c.payout_amt,
    c.spare_amt,
    c.net_amt,
    CASE
      WHEN c.snap_bal IS NULL OR c.prev_snap_bal IS NULL THEN NULL
      ELSE (c.snap_bal - c.prev_snap_bal) - c.net_amt
    END AS reconciliation_diff_rupees
  FROM computed c
  ORDER BY c.month_start DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_monthly_cash_ledger_summary()
CREATE OR REPLACE FUNCTION public.founder_monthly_cash_ledger_summary()
 RETURNS TABLE(total_snapshots_recorded bigint, snapshots_last_12m bigint, last_snapshot_at date, last_snapshot_balance_rupees numeric, first_snapshot_at date, first_snapshot_balance_rupees numeric, net_cash_change_lifetime_rupees numeric, avg_monthly_change_rupees numeric, biggest_inflow_month text, biggest_inflow_amount_rupees numeric, biggest_outflow_month text, biggest_outflow_amount_rupees numeric, months_with_negative_cash_change integer, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH snap AS (
    SELECT
      snapshot_date,
      cash_balance_rupees
    FROM public.founder_cash_position_snapshots
  ),
  ranked AS (
    SELECT
      snapshot_date,
      cash_balance_rupees,
      ROW_NUMBER() OVER (ORDER BY snapshot_date ASC) AS rn_asc,
      ROW_NUMBER() OVER (ORDER BY snapshot_date DESC) AS rn_desc
    FROM snap
  ),
  first_snap AS (
    SELECT snapshot_date, cash_balance_rupees
    FROM ranked WHERE rn_asc = 1
  ),
  last_snap AS (
    SELECT snapshot_date, cash_balance_rupees
    FROM ranked WHERE rn_desc = 1
  ),
  monthly_inflow AS (
    SELECT
      to_char(date_trunc('month', created_at), 'YYYY-MM') AS m,
      COALESCE(SUM(amount), 0)::numeric AS inflow
    FROM public.payments
    WHERE status = 'completed'
    GROUP BY 1
  ),
  monthly_outflow AS (
    SELECT
      to_char(date_trunc('month', COALESCE(processed_at, created_at)), 'YYYY-MM') AS m,
      COALESCE(SUM(amount_rupees), 0)::numeric AS outflow
    FROM public.engineer_payouts
    WHERE status = 'processed'
    GROUP BY 1
  ),
  monthly_spares AS (
    SELECT
      to_char(date_trunc('month', created_at), 'YYYY-MM') AS m,
      COALESCE(SUM(total_amount), 0)::numeric AS spares
    FROM public.spare_part_orders
    WHERE payment_status = 'completed'
    GROUP BY 1
  ),
  combined AS (
    SELECT m FROM monthly_inflow
    UNION
    SELECT m FROM monthly_outflow
    UNION
    SELECT m FROM monthly_spares
  ),
  monthly_net AS (
    SELECT
      c.m,
      COALESCE(i.inflow, 0) AS inflow,
      COALESCE(o.outflow, 0) + COALESCE(s.spares, 0) AS outflow,
      COALESCE(i.inflow, 0) - (COALESCE(o.outflow, 0) + COALESCE(s.spares, 0)) AS net
    FROM combined c
    LEFT JOIN monthly_inflow i ON i.m = c.m
    LEFT JOIN monthly_outflow o ON o.m = c.m
    LEFT JOIN monthly_spares s ON s.m = c.m
  ),
  biggest_in AS (
    SELECT m, inflow FROM monthly_net ORDER BY inflow DESC NULLS LAST LIMIT 1
  ),
  biggest_out AS (
    SELECT m, outflow FROM monthly_net ORDER BY outflow DESC NULLS LAST LIMIT 1
  ),
  neg_months AS (
    SELECT COUNT(*)::int AS c FROM monthly_net WHERE net < 0
  )
  SELECT
    (SELECT COUNT(*) FROM snap)::bigint,
    (SELECT COUNT(*) FROM snap WHERE snapshot_date >= (CURRENT_DATE - INTERVAL '12 months'))::bigint,
    (SELECT snapshot_date FROM last_snap),
    (SELECT cash_balance_rupees FROM last_snap),
    (SELECT snapshot_date FROM first_snap),
    (SELECT cash_balance_rupees FROM first_snap),
    COALESCE(
      (SELECT cash_balance_rupees FROM last_snap) - (SELECT cash_balance_rupees FROM first_snap),
      0
    )::numeric,
    CASE
      WHEN (SELECT COUNT(*) FROM monthly_net) > 0
        THEN (SELECT AVG(net) FROM monthly_net)::numeric
      ELSE 0::numeric
    END,
    COALESCE((SELECT m FROM biggest_in), '—'),
    COALESCE((SELECT inflow FROM biggest_in), 0)::numeric,
    COALESCE((SELECT m FROM biggest_out), '—'),
    COALESCE((SELECT outflow FROM biggest_out), 0)::numeric,
    COALESCE((SELECT c FROM neg_months), 0),
    NOW();
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_morning_pulse_v2()
CREATE OR REPLACE FUNCTION public.founder_morning_pulse_v2()
 RETURNS TABLE(metric text, metric_order integer, today_val bigint, yesterday_val bigint, delta bigint, category text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_yest  date := (now() AT TIME ZONE 'Asia/Kolkata')::date - 1;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH metrics AS (
    SELECT 'Signups (engineer)'::text AS metric, 1 AS metric_order, 'Growth'::text AS category,
      coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'engineer' AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint AS today_val,
      coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'engineer' AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint AS yesterday_val
    UNION ALL
    SELECT 'Signups (hospital)', 2, 'Growth',
      coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'hospital_admin' AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'hospital_admin' AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Jobs posted', 3, 'Marketplace',
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j WHERE (j.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j WHERE (j.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Jobs completed', 4, 'Marketplace',
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j WHERE j.status='completed' AND (j.completed_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j WHERE j.status='completed' AND (j.completed_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Bids placed', 5, 'Marketplace',
      coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'New AMCs', 6, 'Revenue',
      coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Payouts processed', 7, 'Revenue',
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Payouts failed', 8, 'Trust',
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status = 'failed' AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status = 'failed' AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Code Red opened', 9, 'Trust',
      coalesce((SELECT count(*)::bigint FROM public.code_red_requests r WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.code_red_requests r WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Disputes submitted', 10, 'Trust',
      coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d WHERE d.submitted_at IS NOT NULL AND (d.submitted_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d WHERE d.submitted_at IS NOT NULL AND (d.submitted_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Spare orders paid', 11, 'Revenue',
      coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o WHERE o.payment_status='completed' AND (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o WHERE o.payment_status='completed' AND (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Tier promotions', 12, 'Growth',
      coalesce((SELECT count(*)::bigint FROM public.engineer_tier_history h WHERE (h.changed_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.engineer_tier_history h WHERE (h.changed_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
  )
  SELECT m.metric, m.metric_order, m.today_val, m.yesterday_val,
         (m.today_val - m.yesterday_val)::bigint AS delta,
         m.category
  FROM metrics m
  ORDER BY m.metric_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_notifications_by_kind_30d()
CREATE OR REPLACE FUNCTION public.founder_notifications_by_kind_30d()
 RETURNS TABLE(kind text, sent bigint, read bigint, read_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(n.kind, '(unknown)')::text                                           AS kind,
    count(*)::bigint                                                              AS sent,
    count(*) FILTER (WHERE n.read_at IS NOT NULL)::bigint                         AS read,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE n.read_at IS NOT NULL) / count(*), 1)
    END                                                                            AS read_pct
  FROM public.notifications n
  WHERE n.sent_at >= now() - interval '30 days'
  GROUP BY coalesce(n.kind, '(unknown)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_notifications_engagement_30d()
CREATE OR REPLACE FUNCTION public.founder_notifications_engagement_30d()
 RETURNS TABLE(day_ist date, sent bigint, read bigint, unread_ratio_pct numeric)
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
    coalesce((SELECT count(*)::bigint FROM public.notifications n
              WHERE (n.sent_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)               AS sent,
    coalesce((SELECT count(*)::bigint FROM public.notifications n
              WHERE n.read_at IS NOT NULL
                AND (n.sent_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS read,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.notifications n
                     WHERE (n.sent_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 - (100.0 * coalesce((SELECT count(*)::numeric FROM public.notifications n
                                   WHERE n.read_at IS NOT NULL
                                     AND (n.sent_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)
                 / coalesce((SELECT count(*)::numeric FROM public.notifications n
                             WHERE (n.sent_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 1)),
        1)
    END                                                                                            AS unread_ratio_pct
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_payouts_by_engineer_tier()
CREATE OR REPLACE FUNCTION public.founder_payouts_by_engineer_tier()
 RETURNS TABLE(tier text, payouts_90d bigint, rupees_90d numeric, engineers bigint, avg_per_engineer numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers(tier, ord) AS (
    VALUES ('none'::text, 1), ('bronze'::text, 2), ('silver'::text, 3), ('gold'::text, 4)
  ),
  per_tier AS (
    SELECT
      coalesce(ecp.current_tier, 'none') AS tier,
      round(p.amount_paise::numeric / 100.0, 2) AS amount_rupees,
      p.engineer_user_id
    FROM public.engineer_payouts p
    LEFT JOIN public.engineer_certification_progress ecp ON ecp.engineer_user_id = p.engineer_user_id
    WHERE p.status = 'processed'
      AND p.queued_at >= now() - interval '90 days'
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM per_tier pt WHERE pt.tier = t.tier), 0)::bigint,
    coalesce((SELECT sum(pt.amount_rupees)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 0)::numeric,
    coalesce((SELECT count(DISTINCT pt.engineer_user_id)::bigint FROM per_tier pt WHERE pt.tier = t.tier), 0)::bigint,
    CASE WHEN coalesce((SELECT count(DISTINCT pt.engineer_user_id) FROM per_tier pt WHERE pt.tier = t.tier), 0) = 0 THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(pt.amount_rupees)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 0)
           / coalesce((SELECT count(DISTINCT pt.engineer_user_id)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 1)
         , 2)
    END
  FROM tiers t
  ORDER BY t.ord;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_payout_cadence_kpis()
CREATE OR REPLACE FUNCTION public.founder_payout_cadence_kpis()
 RETURNS TABLE(total_engineers integer, with_preference integer, weekly_count integer, biweekly_count integer, monthly_count integer, on_demand_count integer, total_pending_payouts integer, total_pending_rupees bigint, total_paid_90d_rupees bigint, median_gap_days numeric, avg_match_score numeric, engineers_overdue integer, engineers_below_min integer, snapshots_total integer, snapshots_last_7d integer, avg_min_payout_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH eng AS (
    SELECT id FROM public.engineers
  ),
  pref AS (
    SELECT preferred_cadence, min_payout_rupees FROM public.founder_engineer_payout_cadence_v2
  ),
  payouts AS (
    SELECT
      COUNT(*) FILTER (WHERE processed_at IS NULL)::int AS pending_n,
      COALESCE(SUM(amount_rupees) FILTER (WHERE processed_at IS NULL), 0)::bigint AS pending_sum,
      COALESCE(SUM(amount_rupees) FILTER (WHERE processed_at IS NOT NULL AND processed_at > now() - interval '90 days'), 0)::bigint AS paid_90d_sum
    FROM public.engineer_payouts
  ),
  gaps AS (
    SELECT
      EXTRACT(EPOCH FROM (created_at - LAG(created_at) OVER (PARTITION BY engineer_user_id ORDER BY created_at)))/86400.0 AS gap_days,
      engineer_user_id
    FROM public.engineer_payouts
    WHERE processed_at IS NOT NULL AND processed_at > now() - interval '180 days'
  ),
  snaps AS (
    SELECT s.median_gap_days, s.cadence_match_score, s.snapshot_at FROM public.founder_engineer_payout_cadence_snapshots_v2 s
  )
  SELECT
    (SELECT COUNT(*) FROM eng)::int,
    (SELECT COUNT(*) FROM pref)::int,
    (SELECT COUNT(*) FROM pref WHERE preferred_cadence='weekly')::int,
    (SELECT COUNT(*) FROM pref WHERE preferred_cadence='biweekly')::int,
    (SELECT COUNT(*) FROM pref WHERE preferred_cadence='monthly')::int,
    (SELECT COUNT(*) FROM pref WHERE preferred_cadence='on_demand')::int,
    (SELECT pending_n FROM payouts),
    (SELECT pending_sum FROM payouts),
    (SELECT paid_90d_sum FROM payouts),
    (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY gap_days) FROM gaps WHERE gap_days IS NOT NULL)::numeric,
    (SELECT AVG(cadence_match_score) FROM snaps),
    (SELECT COUNT(DISTINCT engineer_user_id) FROM public.engineer_payouts WHERE processed_at IS NULL AND created_at < now() - interval '14 days')::int,
    (SELECT COUNT(*) FROM public.founder_engineer_payout_cadence_v2 c
      WHERE EXISTS (
        SELECT 1 FROM public.engineers e WHERE e.id=c.engineer_id
        AND COALESCE((SELECT SUM(amount_rupees) FROM public.engineer_payouts p WHERE p.engineer_user_id=e.user_id AND p.processed_at IS NULL),0) < c.min_payout_rupees
      ))::int,
    (SELECT COUNT(*) FROM snaps)::int,
    (SELECT COUNT(*) FROM snaps WHERE snapshot_at > now() - interval '7 days')::int,
    (SELECT AVG(min_payout_rupees) FROM pref);
END;$function$;

-- ---------------------------------------------------------------------
-- public.founder_platform_fee_cumulative()
CREATE OR REPLACE FUNCTION public.founder_platform_fee_cumulative()
 RETURNS TABLE(month_ist date, monthly_fee_inr numeric, cumulative_fee_inr numeric)
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
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
                WHERE i.source_kind IN ('repair_job_platform_fee','amc_visit_platform_fee','spare_part_platform_fee','amc_subscription_fee')
                  AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS monthly_fee_inr
    FROM months m
  )
  SELECT
    m.month_ist,
    m.monthly_fee_inr,
    sum(m.monthly_fee_inr) OVER (ORDER BY m.month_ist ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::numeric
                                                AS cumulative_fee_inr
  FROM monthly m
  ORDER BY m.month_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_platform_fee_revenue_by_month()
CREATE OR REPLACE FUNCTION public.founder_platform_fee_revenue_by_month()
 RETURNS TABLE(month_ist date, repair_job_fee numeric, amc_visit_fee numeric, spare_part_fee numeric, amc_sub_fee numeric, total_fee_inr numeric)
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
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind = 'repair_job_platform_fee'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind = 'amc_visit_platform_fee'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind = 'spare_part_platform_fee'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind = 'amc_subscription_fee'
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind IN ('repair_job_platform_fee','amc_visit_platform_fee','spare_part_platform_fee','amc_subscription_fee')
                AND date_trunc('month', (i.issued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2813_refactor_queue()
CREATE OR REPLACE FUNCTION public.founder_r2813_refactor_queue()
 RETURNS TABLE(source text, name text, bucket text, workload integer, verdict text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'token'::text, t.token_name, t.token_category, t.override_count, t.verdict
  FROM design_system_quarter_tokens_r2813 t
  WHERE t.refactor_required
  UNION ALL
  SELECT 'component'::text, c.component_name, c.surface_area, c.refactor_backlog, c.verdict
  FROM design_system_quarter_components_r2813 c
  WHERE c.refactor_backlog > 0
  ORDER BY 4 DESC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_r2813_verdict_mix()
CREATE OR REPLACE FUNCTION public.founder_r2813_verdict_mix()
 RETURNS TABLE(source text, verdict text, cnt integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'token'::text, t.verdict, COUNT(*)::int
  FROM design_system_quarter_tokens_r2813 t
  GROUP BY t.verdict
  UNION ALL
  SELECT 'component'::text, c.verdict, COUNT(*)::int
  FROM design_system_quarter_components_r2813 c
  GROUP BY c.verdict
  ORDER BY 1, 3 DESC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_r3137_blind_spots_open()
CREATE OR REPLACE FUNCTION public.founder_r3137_blind_spots_open()
 RETURNS TABLE(source text, session_or_feedback_code text, topic text, blind_spot text, action_taken_or_status text, dt date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'coach_session'::text, s.session_code, s.primary_topic, s.blind_spot_flagged, s.session_status, s.session_date
  FROM founder_exec_coach_sessions_r3137 s
  WHERE s.blind_spot_flagged IS NOT NULL
  UNION ALL
  SELECT 'peer_feedback'::text, f.feedback_code, f.feedback_topic, f.blind_spot_called_out, f.action_taken, f.feedback_date
  FROM founder_peer_ceo_circle_feedback_r3137 f
  WHERE f.blind_spot_called_out IS NOT NULL
  ORDER BY 6 DESC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.founder_referral_volume_trend()
CREATE OR REPLACE FUNCTION public.founder_referral_volume_trend()
 RETURNS TABLE(day_ist date, referrals bigint, first_jobs bigint, bounties_paid bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 13,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_referrals r
       WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS referrals,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_referrals r
       WHERE r.referee_first_completed_at IS NOT NULL
         AND (r.referee_first_completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS first_jobs,
    coalesce(
      (SELECT count(*)::bigint FROM public.referral_bounty_payouts bp
       WHERE bp.paid_at IS NOT NULL
         AND (bp.paid_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS bounties_paid
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_referrers_by_tier()
CREATE OR REPLACE FUNCTION public.founder_referrers_by_tier()
 RETURNS TABLE(tier text, referrers_cnt bigint, referrals_90d bigint, paid_bounties_90d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers AS (
    SELECT tier, display_order FROM public.amc_subscription_tiers
    UNION ALL VALUES ('none'::text, 0)
  )
  SELECT
    t.tier,
    coalesce((SELECT count(DISTINCT r.referrer_user_id)::bigint FROM public.engineer_referrals r
              LEFT JOIN public.engineer_certification_progress ecp ON ecp.engineer_user_id = r.referrer_user_id
              WHERE coalesce(ecp.current_tier, 'none') = t.tier
                AND r.created_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals r
              LEFT JOIN public.engineer_certification_progress ecp ON ecp.engineer_user_id = r.referrer_user_id
              WHERE coalesce(ecp.current_tier, 'none') = t.tier
                AND r.created_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts bp
              JOIN public.engineer_referrals r ON r.id = bp.referral_id
              LEFT JOIN public.engineer_certification_progress ecp ON ecp.engineer_user_id = r.referrer_user_id
              WHERE coalesce(ecp.current_tier, 'none') = t.tier
                AND r.created_at >= now() - interval '90 days'), 0)::bigint
  FROM tiers t
  ORDER BY t.display_order;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_renewal_action_ladder()
CREATE OR REPLACE FUNCTION public.founder_renewal_action_ladder()
 RETURNS TABLE(action_id uuid, contract_id uuid, org_name text, rung text, outcome text, notes text, taken_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.contract_id, o.name, a.rung, a.outcome, a.notes, a.taken_at
  FROM founder_renewal_actions a
  JOIN amc_contracts c ON c.id = a.contract_id
  JOIN profiles hp ON hp.id = c.hospital_user_id
  JOIN organizations o ON o.id = hp.organization_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_renewal_kpis()
CREATE OR REPLACE FUNCTION public.founder_renewal_kpis()
 RETURNS TABLE(contracts_due_90d integer, contracts_due_30d integer, contracts_due_7d integer, contracts_overdue integer, arr_at_risk_rupees bigint, arr_due_30d_rupees bigint, high_likelihood_count integer, med_likelihood_count integer, low_likelihood_count integer, actions_logged_30d integer, postmortems_30d integer, preventable_losses_30d integer, avg_likelihood_pct numeric, total_at_risk_orgs integer, silent_orgs_count integer, escalations_pending integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH due AS (
    SELECT c.id, c.end_date, c.monthly_fee_rupees, hp.organization_id
    FROM amc_contracts c
    LEFT JOIN profiles hp ON hp.id = c.hospital_user_id
    WHERE c.status = 'active'
      AND c.end_date <= (now()::date + 90)
  ),
  scored AS (
    SELECT d.*,
      -- crude likelihood: base 60, +20 if recent action, -15 if no service ticket in 60d, capped 5..95
      LEAST(95, GREATEST(5,
        60
        + CASE WHEN EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = d.id AND a.outcome = 'promised_renew') THEN 25 ELSE 0 END
        - CASE WHEN EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = d.id AND a.outcome IN ('will_not_renew','silent')) THEN 30 ELSE 0 END
      ))::int AS likelihood
    FROM due d
  )
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE end_date <= now()::date + 30)::int,
    COUNT(*) FILTER (WHERE end_date <= now()::date + 7)::int,
    COUNT(*) FILTER (WHERE end_date < now()::date)::int,
    COALESCE(SUM(monthly_fee_rupees * 12), 0)::bigint,
    COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE end_date <= now()::date + 30), 0)::bigint,
    COUNT(*) FILTER (WHERE likelihood >= 70)::int,
    COUNT(*) FILTER (WHERE likelihood BETWEEN 40 AND 69)::int,
    COUNT(*) FILTER (WHERE likelihood < 40)::int,
    (SELECT COUNT(*) FROM founder_renewal_actions WHERE taken_at >= now() - interval '30 days')::int,
    (SELECT COUNT(*) FROM founder_renewal_postmortems WHERE captured_at >= now() - interval '30 days')::int,
    (SELECT COUNT(*) FROM founder_renewal_postmortems WHERE captured_at >= now() - interval '30 days' AND preventable)::int,
    COALESCE(ROUND(AVG(likelihood)::numeric, 1), 0),
    COUNT(DISTINCT organization_id)::int,
    COUNT(DISTINCT organization_id) FILTER (WHERE NOT EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = scored.id))::int,
    COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = scored.id AND a.rung = 'escalate_md' AND a.outcome IS NULL))::int
  FROM scored;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_renewal_postmortem_log()
CREATE OR REPLACE FUNCTION public.founder_renewal_postmortem_log()
 RETURNS TABLE(postmortem_id uuid, contract_id uuid, org_name text, loss_reason text, competitor_name text, price_gap_rupees integer, preventable boolean, lessons_learned text, captured_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.contract_id, o.name, p.loss_reason, p.competitor_name, p.price_gap_rupees, p.preventable, p.lessons_learned, p.captured_at
  FROM founder_renewal_postmortems p
  JOIN amc_contracts c ON c.id = p.contract_id
  JOIN profiles hp ON hp.id = c.hospital_user_id
  JOIN organizations o ON o.id = hp.organization_id
  ORDER BY p.captured_at DESC
  LIMIT 100;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_renewal_queue()
CREATE OR REPLACE FUNCTION public.founder_renewal_queue()
 RETURNS TABLE(contract_id uuid, organization_id uuid, org_name text, org_city text, amc_tier text, monthly_fee_rupees integer, annual_value_rupees bigint, end_date date, days_to_expiry integer, likelihood_pct integer, bucket text, last_action_rung text, last_action_outcome text, last_action_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH due AS (
    SELECT c.id, hp.organization_id, c.amc_tier, c.monthly_fee_rupees, c.end_date
    FROM amc_contracts c
    LEFT JOIN profiles hp ON hp.id = c.hospital_user_id
    WHERE c.status = 'active' AND c.end_date <= now()::date + 90
  ),
  last_act AS (
    SELECT DISTINCT ON (a.contract_id) a.contract_id, a.rung, a.outcome, a.taken_at
    FROM founder_renewal_actions a
    ORDER BY a.contract_id, a.taken_at DESC
  )
  SELECT
    d.id,
    d.organization_id,
    o.name,
    o.city,
    d.amc_tier,
    d.monthly_fee_rupees::int,
    (d.monthly_fee_rupees * 12)::bigint,
    d.end_date,
    (d.end_date - now()::date)::int,
    LEAST(95, GREATEST(5,
      60
      + CASE WHEN la.outcome = 'promised_renew' THEN 25 ELSE 0 END
      - CASE WHEN la.outcome IN ('will_not_renew','silent') THEN 30 ELSE 0 END
    ))::int,
    CASE
      WHEN d.end_date < now()::date THEN 'overdue'
      WHEN d.end_date <= now()::date + 7 THEN 'this_week'
      WHEN d.end_date <= now()::date + 30 THEN 'this_month'
      ELSE 'next_quarter'
    END,
    la.rung,
    la.outcome,
    la.taken_at
  FROM due d
  JOIN organizations o ON o.id = d.organization_id
  LEFT JOIN last_act la ON la.contract_id = d.id
  ORDER BY d.end_date ASC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_renewal_silent_contracts()
CREATE OR REPLACE FUNCTION public.founder_renewal_silent_contracts()
 RETURNS TABLE(contract_id uuid, org_name text, org_city text, end_date date, days_to_expiry integer, annual_value_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, o.name, o.city, c.end_date,
         (c.end_date - now()::date)::int,
         (c.monthly_fee_rupees * 12)::bigint
  FROM amc_contracts c
  JOIN profiles hp ON hp.id = c.hospital_user_id
  JOIN organizations o ON o.id = hp.organization_id
  WHERE c.status = 'active'
    AND c.end_date <= now()::date + 60
    AND NOT EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = c.id)
  ORDER BY c.end_date ASC
  LIMIT 50;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_repair_job_bids_snapshot_summary()
CREATE OR REPLACE FUNCTION public.founder_repair_job_bids_snapshot_summary()
 RETURNS TABLE(total_all_time bigint, pending_now bigint, accepted_30d bigint, rejected_30d bigint, withdrawn_30d bigint, acceptance_pct_30d numeric, active_engineers_30d bigint, avg_amount_30d_inr numeric, max_amount_30d_inr numeric, created_today bigint, accepted_today bigint, avg_bids_per_open_job numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_settled_30d bigint;
  v_accepted_30d bigint;
  v_open_jobs bigint;
  v_pending_bids bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_accepted_30d FROM public.repair_job_bids WHERE status = 'accepted' AND created_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_settled_30d FROM public.repair_job_bids WHERE status IN ('accepted','rejected','withdrawn') AND created_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_open_jobs FROM public.repair_jobs WHERE status = 'requested';
  SELECT count(*)::bigint INTO v_pending_bids FROM public.repair_job_bids WHERE status IN ('pending','submitted');
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids), 0),
    v_pending_bids,
    v_accepted_30d,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status = 'rejected' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status = 'withdrawn' AND created_at >= now() - interval '30 days'), 0),
    CASE WHEN coalesce(v_settled_30d, 0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_accepted_30d / v_settled_30d, 1) END,
    coalesce((SELECT count(DISTINCT engineer_user_id)::bigint FROM public.repair_job_bids WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT round(avg(amount_rupees)::numeric, 2) FROM public.repair_job_bids WHERE created_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT max(amount_rupees)::numeric FROM public.repair_job_bids WHERE created_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status = 'accepted' AND created_at >= v_today_start AND created_at < v_today_end), 0),
    CASE WHEN coalesce(v_open_jobs, 0) = 0 THEN 0::numeric
         ELSE round(v_pending_bids::numeric / v_open_jobs, 2) END;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_revenue_leakage_history(p_months integer)
CREATE OR REPLACE FUNCTION public.founder_revenue_leakage_history(p_months integer DEFAULT 12)
 RETURNS TABLE(month_start text, refunds_rupees numeric, sla_credits_rupees numeric, escrow_refunds_rupees numeric, total_leakage_rupees numeric, gmv_captured_rupees numeric, leakage_pct_of_gmv numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now()) - (COALESCE(p_months, 12) - 1) * interval '1 month',
      date_trunc('month', now()),
      interval '1 month'
    ) AS m
  ),
  refunds_m AS (
    SELECT date_trunc('month', created_at) AS m,
           COALESCE(SUM(amount), 0)::numeric AS amt
      FROM public.payments
     WHERE status = 'refunded'
     GROUP BY 1
  ),
  sla_m AS (
    SELECT date_trunc('month', detected_at) AS m,
           COALESCE(SUM(credit_issued_rupees), 0)::numeric AS amt
      FROM public.amc_sla_breaches
     GROUP BY 1
  ),
  escrow_m AS (
    SELECT date_trunc('month', COALESCE(refunded_at, created_at)) AS m,
           COALESCE(SUM(amount_rupees), 0)::numeric AS amt
      FROM public.repair_job_escrow
     WHERE status = 'refunded'
     GROUP BY 1
  ),
  gmv_m AS (
    SELECT date_trunc('month', created_at) AS m,
           COALESCE(SUM(amount), 0)::numeric AS amt
      FROM public.payments
     WHERE status = 'completed'
     GROUP BY 1
  )
  SELECT
    to_char(months.m, 'YYYY-MM') AS month_start,
    COALESCE(refunds_m.amt, 0)::numeric AS refunds_rupees,
    COALESCE(sla_m.amt, 0)::numeric AS sla_credits_rupees,
    COALESCE(escrow_m.amt, 0)::numeric AS escrow_refunds_rupees,
    (COALESCE(refunds_m.amt, 0) + COALESCE(sla_m.amt, 0) + COALESCE(escrow_m.amt, 0))::numeric AS total_leakage_rupees,
    COALESCE(gmv_m.amt, 0)::numeric AS gmv_captured_rupees,
    CASE
      WHEN COALESCE(gmv_m.amt, 0) > 0
      THEN ROUND(((COALESCE(refunds_m.amt, 0) + COALESCE(sla_m.amt, 0) + COALESCE(escrow_m.amt, 0)) / gmv_m.amt) * 100, 2)
      ELSE 0
    END::numeric AS leakage_pct_of_gmv
  FROM months
  LEFT JOIN refunds_m ON refunds_m.m = months.m
  LEFT JOIN sla_m ON sla_m.m = months.m
  LEFT JOIN escrow_m ON escrow_m.m = months.m
  LEFT JOIN gmv_m ON gmv_m.m = months.m
  ORDER BY months.m DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_revenue_leakage_summary()
CREATE OR REPLACE FUNCTION public.founder_revenue_leakage_summary()
 RETURNS TABLE(total_refunds_lifetime_rupees numeric, refunds_30d_rupees numeric, refunds_90d_rupees numeric, total_sla_credits_lifetime_rupees numeric, sla_credits_30d_rupees numeric, escrow_refunds_lifetime_rupees numeric, escrow_refunds_30d_rupees numeric, total_leakage_lifetime_rupees numeric, total_leakage_30d_rupees numeric, leakage_pct_of_gmv_30d numeric, biggest_single_refund_rupees numeric, biggest_sla_credit_rupees numeric, count_of_credit_events_30d bigint, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_refunds_lifetime numeric;
  v_refunds_30d numeric;
  v_refunds_90d numeric;
  v_sla_lifetime numeric;
  v_sla_30d numeric;
  v_escrow_lifetime numeric;
  v_escrow_30d numeric;
  v_gmv_30d numeric;
  v_biggest_refund numeric;
  v_biggest_sla numeric;
  v_credit_events_30d bigint;
  v_leak_lifetime numeric;
  v_leak_30d numeric;
  v_leak_pct numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Lifetime refunds (payments table, status='refunded')
  SELECT COALESCE(SUM(amount), 0)::numeric
    INTO v_refunds_lifetime
    FROM public.payments
   WHERE status = 'refunded';

  -- 30d refunds
  SELECT COALESCE(SUM(amount), 0)::numeric
    INTO v_refunds_30d
    FROM public.payments
   WHERE status = 'refunded'
     AND created_at >= now() - interval '30 days';

  -- 90d refunds
  SELECT COALESCE(SUM(amount), 0)::numeric
    INTO v_refunds_90d
    FROM public.payments
   WHERE status = 'refunded'
     AND created_at >= now() - interval '90 days';

  -- Lifetime SLA credits issued
  SELECT COALESCE(SUM(credit_issued_rupees), 0)::numeric
    INTO v_sla_lifetime
    FROM public.amc_sla_breaches;

  -- 30d SLA credits
  SELECT COALESCE(SUM(credit_issued_rupees), 0)::numeric
    INTO v_sla_30d
    FROM public.amc_sla_breaches
   WHERE detected_at >= now() - interval '30 days';

  -- Lifetime escrow refunds (status='refunded')
  SELECT COALESCE(SUM(amount_rupees), 0)::numeric
    INTO v_escrow_lifetime
    FROM public.repair_job_escrow
   WHERE status = 'refunded';

  -- 30d escrow refunds (use refunded_at when present, else created)
  SELECT COALESCE(SUM(amount_rupees), 0)::numeric
    INTO v_escrow_30d
    FROM public.repair_job_escrow
   WHERE status = 'refunded'
     AND COALESCE(refunded_at, created_at) >= now() - interval '30 days';

  -- 30d GMV = captured payments
  SELECT COALESCE(SUM(amount), 0)::numeric
    INTO v_gmv_30d
    FROM public.payments
   WHERE status = 'completed'
     AND created_at >= now() - interval '30 days';

  -- Biggest single refund (lifetime)
  SELECT COALESCE(MAX(amount), 0)::numeric
    INTO v_biggest_refund
    FROM public.payments
   WHERE status = 'refunded';

  -- Biggest SLA credit (lifetime)
  SELECT COALESCE(MAX(credit_issued_rupees), 0)::numeric
    INTO v_biggest_sla
    FROM public.amc_sla_breaches;

  -- Count of credit events 30d (refunds + sla + escrow refunds)
  SELECT
    (SELECT COUNT(*) FROM public.payments
       WHERE status = 'refunded' AND created_at >= now() - interval '30 days')
    + (SELECT COUNT(*) FROM public.amc_sla_breaches
         WHERE detected_at >= now() - interval '30 days')
    + (SELECT COUNT(*) FROM public.repair_job_escrow
         WHERE status = 'refunded'
           AND COALESCE(refunded_at, created_at) >= now() - interval '30 days')
    INTO v_credit_events_30d;

  v_leak_lifetime := v_refunds_lifetime + v_sla_lifetime + v_escrow_lifetime;
  v_leak_30d := v_refunds_30d + v_sla_30d + v_escrow_30d;
  v_leak_pct := CASE
    WHEN v_gmv_30d > 0 THEN ROUND((v_leak_30d / v_gmv_30d) * 100, 2)
    ELSE 0
  END;

  RETURN QUERY SELECT
    v_refunds_lifetime,
    v_refunds_30d,
    v_refunds_90d,
    v_sla_lifetime,
    v_sla_30d,
    v_escrow_lifetime,
    v_escrow_30d,
    v_leak_lifetime,
    v_leak_30d,
    v_leak_pct,
    v_biggest_refund,
    v_biggest_sla,
    v_credit_events_30d,
    now();
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_revenue_recognition_history(p_months integer)
CREATE OR REPLACE FUNCTION public.founder_revenue_recognition_history(p_months integer DEFAULT 12)
 RETURNS TABLE(month_start date, accrued_rupees numeric, invoiced_rupees numeric, cash_collected_rupees numeric, gst_remitted_rupees numeric, net_recognized_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_months int := GREATEST(1, LEAST(36, COALESCE(p_months, 12)));
  v_anchor date := date_trunc('month', now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT (v_anchor - (gs || ' months')::interval)::date AS m_start
      FROM generate_series(0, v_months - 1) AS gs
  ),
  accrued AS (
    SELECT m.m_start,
           COALESCE(SUM(c.monthly_fee_rupees), 0)::numeric AS accr
      FROM months m
      LEFT JOIN public.amc_contracts c
        ON c.start_date < (m.m_start + interval '1 month')::date
       AND (c.end_date IS NULL OR c.end_date >= m.m_start)
     GROUP BY m.m_start
  ),
  invoiced AS (
    SELECT date_trunc('month', g.issued_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(g.taxable_amount_rupees + g.cgst_rupees + g.sgst_rupees + g.igst_rupees)::numeric AS inv,
           SUM(g.cgst_rupees + g.sgst_rupees + g.igst_rupees)::numeric AS tax
      FROM public.gst_invoices g
     WHERE g.status <> 'cancelled'
       AND g.issued_at >= (v_anchor - ((v_months) || ' months')::interval)
     GROUP BY 1
  ),
  cash AS (
    SELECT date_trunc('month', p.created_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(p.amount)::numeric AS csh
      FROM public.payments p
     WHERE p.status = 'completed'
       AND p.created_at >= (v_anchor - ((v_months) || ' months')::interval)
     GROUP BY 1
  )
  SELECT m.m_start,
         COALESCE(a.accr, 0)::numeric,
         COALESCE(i.inv,  0)::numeric,
         COALESCE(c.csh,  0)::numeric,
         COALESCE(i.tax,  0)::numeric,
         (COALESCE(i.inv, 0) - COALESCE(i.tax, 0))::numeric
    FROM months m
    LEFT JOIN accrued  a ON a.m_start = m.m_start
    LEFT JOIN invoiced i ON i.m_start = m.m_start
    LEFT JOIN cash     c ON c.m_start = m.m_start
   ORDER BY m.m_start DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_revenue_recognition_summary()
CREATE OR REPLACE FUNCTION public.founder_revenue_recognition_summary()
 RETURNS TABLE(this_month_accrued_revenue_rupees numeric, this_month_invoiced_rupees numeric, this_month_cash_collected_rupees numeric, last_month_accrued_rupees numeric, last_month_invoiced_rupees numeric, last_month_cash_collected_rupees numeric, ytd_accrued_rupees numeric, ytd_invoiced_rupees numeric, ytd_cash_collected_rupees numeric, mom_accrued_delta_pct numeric, mom_cash_delta_pct numeric, deferred_revenue_estimate_rupees numeric, bad_debt_estimate_rupees numeric, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_now            timestamptz := now();
  v_tm_start       date := date_trunc('month', v_now AT TIME ZONE 'Asia/Kolkata')::date;
  v_tm_end         date := (v_tm_start + interval '1 month')::date;
  v_lm_start       date := (v_tm_start - interval '1 month')::date;
  v_lm_end         date := v_tm_start;
  v_ytd_start      date := date_trunc('year', v_now AT TIME ZONE 'Asia/Kolkata')::date;
  v_bad_debt_cut   timestamptz := v_now - interval '90 days';

  v_tm_accrued     numeric := 0;
  v_tm_invoiced    numeric := 0;
  v_tm_cash        numeric := 0;
  v_lm_accrued     numeric := 0;
  v_lm_invoiced    numeric := 0;
  v_lm_cash        numeric := 0;
  v_ytd_accrued    numeric := 0;
  v_ytd_invoiced   numeric := 0;
  v_ytd_cash       numeric := 0;
  v_mom_accr_pct   numeric := 0;
  v_mom_cash_pct   numeric := 0;
  v_total_invoiced numeric := 0;
  v_total_cash     numeric := 0;
  v_deferred       numeric := 0;
  v_bad_debt       numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- This-month ACCRUED: monthly_fee for any contract whose active span
  -- overlaps the current calendar month (start_date <= month_end AND
  -- (end_date IS NULL OR end_date >= month_start) AND status='active').
  SELECT COALESCE(SUM(monthly_fee_rupees), 0)
    INTO v_tm_accrued
    FROM public.amc_contracts
   WHERE status = 'active'
     AND start_date < v_tm_end
     AND (end_date IS NULL OR end_date >= v_tm_start);

  -- Last-month ACCRUED: same logic, prior month window.
  SELECT COALESCE(SUM(monthly_fee_rupees), 0)
    INTO v_lm_accrued
    FROM public.amc_contracts
   WHERE start_date < v_lm_end
     AND (end_date IS NULL OR end_date >= v_lm_start)
     AND (deactivated_at IS NULL OR deactivated_at >= v_lm_start);

  -- YTD ACCRUED: approximate as monthly_fee × months_elapsed_in_year for
  -- every contract whose span intersected the YTD window.
  SELECT COALESCE(
           SUM(
             monthly_fee_rupees *
             GREATEST(
               1,
               EXTRACT(MONTH FROM age(
                 LEAST(COALESCE(end_date, v_now::date), v_now::date),
                 GREATEST(start_date, v_ytd_start)
               ))::int + 1
             )
           ),
           0
         )
    INTO v_ytd_accrued
    FROM public.amc_contracts
   WHERE start_date < v_now::date
     AND (end_date IS NULL OR end_date >= v_ytd_start);

  -- INVOICED: sum taxable + cgst + sgst + igst issued in window, status<>'cancelled'.
  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_tm_invoiced
    FROM public.gst_invoices
   WHERE status <> 'cancelled'
     AND issued_at >= v_tm_start
     AND issued_at <  v_tm_end;

  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_lm_invoiced
    FROM public.gst_invoices
   WHERE status <> 'cancelled'
     AND issued_at >= v_lm_start
     AND issued_at <  v_lm_end;

  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_ytd_invoiced
    FROM public.gst_invoices
   WHERE status <> 'cancelled'
     AND issued_at >= v_ytd_start;

  -- CASH collected: payments status='completed' in window.
  SELECT COALESCE(SUM(amount), 0)
    INTO v_tm_cash
    FROM public.payments
   WHERE status = 'completed'
     AND created_at >= v_tm_start
     AND created_at <  v_tm_end;

  SELECT COALESCE(SUM(amount), 0)
    INTO v_lm_cash
    FROM public.payments
   WHERE status = 'completed'
     AND created_at >= v_lm_start
     AND created_at <  v_lm_end;

  SELECT COALESCE(SUM(amount), 0)
    INTO v_ytd_cash
    FROM public.payments
   WHERE status = 'completed'
     AND created_at >= v_ytd_start;

  -- MoM deltas (percent).
  IF v_lm_accrued > 0 THEN
    v_mom_accr_pct := ROUND(((v_tm_accrued - v_lm_accrued) / v_lm_accrued) * 100.0, 2);
  END IF;
  IF v_lm_cash > 0 THEN
    v_mom_cash_pct := ROUND(((v_tm_cash - v_lm_cash) / v_lm_cash) * 100.0, 2);
  END IF;

  -- Deferred revenue estimate: total invoiced - total cash (all-time).
  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_total_invoiced
    FROM public.gst_invoices
   WHERE status <> 'cancelled';

  SELECT COALESCE(SUM(amount), 0)
    INTO v_total_cash
    FROM public.payments
   WHERE status = 'completed';

  v_deferred := GREATEST(0, v_total_invoiced - v_total_cash);

  -- Bad-debt estimate: invoices issued > 90 days ago that have no matching
  -- captured payment (very rough — no FK between gst_invoices and payments
  -- on every path, so we proxy via the deferred bucket aged > 90d).
  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_bad_debt
    FROM public.gst_invoices
   WHERE status = 'issued'
     AND issued_at < v_bad_debt_cut;

  -- Bad debt can't exceed the deferred pool.
  v_bad_debt := LEAST(v_bad_debt, v_deferred);

  RETURN QUERY SELECT
    v_tm_accrued,
    v_tm_invoiced,
    v_tm_cash,
    v_lm_accrued,
    v_lm_invoiced,
    v_lm_cash,
    v_ytd_accrued,
    v_ytd_invoiced,
    v_ytd_cash,
    v_mom_accr_pct,
    v_mom_cash_pct,
    v_deferred,
    v_bad_debt,
    v_now;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_runway_burn_summary()
CREATE OR REPLACE FUNCTION public.founder_runway_burn_summary()
 RETURNS TABLE(latest_cash_balance_rupees numeric, latest_snapshot_date date, days_since_last_snapshot integer, monthly_burn_avg_3m_rupees numeric, monthly_burn_last_30d_rupees numeric, estimated_runway_months numeric, estimated_zero_cash_date date, monthly_inflow_avg_3m_rupees numeric, monthly_payouts_avg_3m_rupees numeric, monthly_refunds_avg_3m_rupees numeric, monthly_net_position_rupees numeric, cash_cumulative_change_30d_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cash numeric := 0;
  v_snap_date date := NULL;
  v_days_since int := NULL;
  v_burn_3m numeric := 0;
  v_burn_30d numeric := 0;
  v_payouts_3m numeric := 0;
  v_spares_3m numeric := 0;
  v_refunds_3m numeric := 0;
  v_inflow_3m numeric := 0;
  v_inflow_30d numeric := 0;
  v_net numeric := 0;
  v_runway numeric := NULL;
  v_zero_date date := NULL;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Latest manual cash snapshot
  SELECT cash_balance_rupees, snapshot_date
    INTO v_cash, v_snap_date
    FROM public.founder_cash_position_snapshots
   ORDER BY snapshot_date DESC
   LIMIT 1;

  IF v_snap_date IS NOT NULL THEN
    v_days_since := GREATEST(0, (CURRENT_DATE - v_snap_date)::int);
  END IF;

  -- Engineer payouts (processed) last 90 days → /3 for monthly avg
  SELECT COALESCE(SUM(amount_rupees), 0) / 3.0
    INTO v_payouts_3m
    FROM public.engineer_payouts
   WHERE status = 'processed'
     AND created_at >= now() - interval '90 days';

  -- Spare-part orders (paid) last 90 days → /3
  SELECT COALESCE(SUM(total_amount), 0) / 3.0
    INTO v_spares_3m
    FROM public.spare_part_orders
   WHERE COALESCE(payment_status::text,'') = 'completed'
     AND created_at >= now() - interval '90 days';

  -- Escrow refunds last 90 days → /3
  SELECT COALESCE(SUM(amount_rupees), 0) / 3.0
    INTO v_refunds_3m
    FROM public.repair_job_escrow
   WHERE status = 'refunded'
     AND refunded_at >= now() - interval '90 days';

  v_burn_3m := v_payouts_3m + v_spares_3m + v_refunds_3m;

  -- Last-30d burn (all three) for short-term trend
  SELECT
    COALESCE((SELECT SUM(amount_rupees) FROM public.engineer_payouts
              WHERE status = 'processed' AND created_at >= now() - interval '30 days'), 0)
  + COALESCE((SELECT SUM(total_amount) FROM public.spare_part_orders
              WHERE COALESCE(payment_status::text,'') = 'completed' AND created_at >= now() - interval '30 days'), 0)
  + COALESCE((SELECT SUM(amount_rupees) FROM public.repair_job_escrow
              WHERE status = 'refunded' AND refunded_at >= now() - interval '30 days'), 0)
    INTO v_burn_30d;

  -- Inflow (captured payments) 90d → /3
  SELECT COALESCE(SUM(amount), 0) / 3.0
    INTO v_inflow_3m
    FROM public.payments
   WHERE status = 'completed'
     AND created_at >= now() - interval '90 days';

  -- Last-30d inflow
  SELECT COALESCE(SUM(amount), 0)
    INTO v_inflow_30d
    FROM public.payments
   WHERE status = 'completed'
     AND created_at >= now() - interval '30 days';

  v_net := v_inflow_3m - v_burn_3m;

  -- Runway projection: if net is positive (revenue covers burn), runway = NULL (infinite)
  -- Otherwise: cash / abs(monthly_net) months from latest snapshot
  IF v_cash > 0 AND v_burn_3m > 0 THEN
    IF v_net < 0 THEN
      v_runway := ROUND(v_cash / ABS(v_net), 2);
      v_zero_date := COALESCE(v_snap_date, CURRENT_DATE) + (v_runway * 30)::int;
    ELSE
      v_runway := NULL;
      v_zero_date := NULL;
    END IF;
  END IF;

  RETURN QUERY SELECT
    v_cash,
    v_snap_date,
    v_days_since,
    ROUND(v_burn_3m::numeric, 2),
    ROUND(v_burn_30d::numeric, 2),
    v_runway,
    v_zero_date,
    ROUND(v_inflow_3m::numeric, 2),
    ROUND(v_payouts_3m::numeric, 2),
    ROUND(v_refunds_3m::numeric, 2),
    ROUND(v_net::numeric, 2),
    ROUND((v_inflow_30d - v_burn_30d)::numeric, 2);
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_runway_forecast_v2_summary()
CREATE OR REPLACE FUNCTION public.founder_runway_forecast_v2_summary()
 RETURNS TABLE(current_cash_balance_rupees numeric, days_since_snapshot integer, base_runway_months numeric, base_zero_cash_date date, upside_runway_months numeric, downside_runway_months numeric, stress_runway_months numeric, actual_burn_last_30d_rupees numeric, actual_inflow_last_30d_rupees numeric, actual_net_last_30d_rupees numeric, burn_vs_base_variance_pct numeric, scenarios_active_count bigint, longest_runway_scenario_label text, shortest_runway_scenario_label text, newest_scenario_at timestamp with time zone, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cash numeric := 0; v_snap_date date := NULL; v_days_since int := NULL;
  v_base_burn numeric := 0; v_upside_burn numeric := 0; v_downside_burn numeric := 0; v_stress_burn numeric := 0;
  v_base_inflow numeric := 0; v_upside_inflow numeric := 0; v_downside_inflow numeric := 0; v_stress_inflow numeric := 0;
  v_base_runway numeric := NULL; v_upside_runway numeric := NULL; v_downside_runway numeric := NULL; v_stress_runway numeric := NULL;
  v_zero_date date := NULL;
  v_actual_burn numeric := 0; v_actual_inflow numeric := 0;
  v_variance numeric := 0;
  v_longest text := NULL; v_shortest text := NULL;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT cash_balance_rupees, snapshot_date INTO v_cash, v_snap_date
  FROM public.founder_cash_position_snapshots ORDER BY snapshot_date DESC LIMIT 1;
  IF v_snap_date IS NOT NULL THEN
    v_days_since := greatest(0, (current_date - v_snap_date)::int);
  END IF;

  SELECT assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees
  INTO v_base_burn, v_base_inflow
  FROM public.founder_runway_forecast_scenarios
  WHERE scenario_kind='base' AND is_active=true
  ORDER BY created_at DESC LIMIT 1;

  SELECT assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees
  INTO v_upside_burn, v_upside_inflow
  FROM public.founder_runway_forecast_scenarios
  WHERE scenario_kind='upside' AND is_active=true
  ORDER BY created_at DESC LIMIT 1;

  SELECT assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees
  INTO v_downside_burn, v_downside_inflow
  FROM public.founder_runway_forecast_scenarios
  WHERE scenario_kind='downside' AND is_active=true
  ORDER BY created_at DESC LIMIT 1;

  SELECT assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees
  INTO v_stress_burn, v_stress_inflow
  FROM public.founder_runway_forecast_scenarios
  WHERE scenario_kind='stress' AND is_active=true
  ORDER BY created_at DESC LIMIT 1;

  IF v_cash > 0 AND coalesce(v_base_burn, 0) > coalesce(v_base_inflow, 0) THEN
    v_base_runway := round(v_cash / (v_base_burn - v_base_inflow), 2);
    v_zero_date := coalesce(v_snap_date, current_date) + (v_base_runway * 30)::int;
  END IF;
  IF v_cash > 0 AND coalesce(v_upside_burn, 0) > coalesce(v_upside_inflow, 0) THEN
    v_upside_runway := round(v_cash / (v_upside_burn - v_upside_inflow), 2);
  END IF;
  IF v_cash > 0 AND coalesce(v_downside_burn, 0) > coalesce(v_downside_inflow, 0) THEN
    v_downside_runway := round(v_cash / (v_downside_burn - v_downside_inflow), 2);
  END IF;
  IF v_cash > 0 AND coalesce(v_stress_burn, 0) > coalesce(v_stress_inflow, 0) THEN
    v_stress_runway := round(v_cash / (v_stress_burn - v_stress_inflow), 2);
  END IF;

  SELECT coalesce(sum(amount_rupees), 0) INTO v_actual_burn
  FROM public.engineer_payouts
  WHERE status = 'processed' AND created_at >= now() - interval '30 days';
  SELECT v_actual_burn + coalesce(sum(total_amount), 0) INTO v_actual_burn
  FROM public.spare_part_orders
  WHERE coalesce(payment_status::text, '') = 'completed' AND created_at >= now() - interval '30 days';

  SELECT coalesce(sum(amount), 0) INTO v_actual_inflow
  FROM public.payments
  WHERE status = 'completed' AND created_at >= now() - interval '30 days';

  IF coalesce(v_base_burn, 0) > 0 THEN
    v_variance := round(((v_actual_burn - v_base_burn) / v_base_burn) * 100, 2);
  END IF;

  SELECT scenario_label INTO v_longest
  FROM (
    SELECT scenario_label, assumed_starting_cash_rupees, assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees,
           CASE WHEN assumed_monthly_burn_rupees > assumed_monthly_inflow_rupees
                THEN coalesce(assumed_starting_cash_rupees, v_cash) / (assumed_monthly_burn_rupees - assumed_monthly_inflow_rupees)
                ELSE 999::numeric END AS rw
    FROM public.founder_runway_forecast_scenarios WHERE is_active=true
  ) t ORDER BY rw DESC LIMIT 1;

  SELECT scenario_label INTO v_shortest
  FROM (
    SELECT scenario_label, assumed_starting_cash_rupees, assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees,
           CASE WHEN assumed_monthly_burn_rupees > assumed_monthly_inflow_rupees
                THEN coalesce(assumed_starting_cash_rupees, v_cash) / (assumed_monthly_burn_rupees - assumed_monthly_inflow_rupees)
                ELSE 999::numeric END AS rw
    FROM public.founder_runway_forecast_scenarios WHERE is_active=true
  ) t ORDER BY rw ASC LIMIT 1;

  RETURN QUERY SELECT
    v_cash, v_days_since,
    v_base_runway, v_zero_date,
    v_upside_runway, v_downside_runway, v_stress_runway,
    round(v_actual_burn, 2), round(v_actual_inflow, 2), round(v_actual_inflow - v_actual_burn, 2),
    v_variance,
    (SELECT count(*) FROM public.founder_runway_forecast_scenarios WHERE is_active=true)::bigint,
    coalesce(v_longest, '(none)'), coalesce(v_shortest, '(none)'),
    (SELECT max(created_at) FROM public.founder_runway_forecast_scenarios),
    now();
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_runway_history(p_months integer)
CREATE OR REPLACE FUNCTION public.founder_runway_history(p_months integer DEFAULT 12)
 RETURNS TABLE(month_start date, snapshot_date date, cash_balance_rupees numeric, month_inflow_rupees numeric, month_burn_rupees numeric, month_net_rupees numeric, snapshot_note text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT (date_trunc('month', generate_series(
              date_trunc('month', now()) - ((p_months - 1) || ' months')::interval,
              date_trunc('month', now()),
              interval '1 month'))::date) AS m_start
  ),
  inflow AS (
    SELECT date_trunc('month', created_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(amount)::numeric AS infl
      FROM public.payments
     WHERE status = 'completed'
       AND created_at >= now() - ((p_months + 1) || ' months')::interval
     GROUP BY 1
  ),
  payouts AS (
    SELECT date_trunc('month', created_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(amount_rupees)::numeric AS amt
      FROM public.engineer_payouts
     WHERE status = 'processed'
       AND created_at >= now() - ((p_months + 1) || ' months')::interval
     GROUP BY 1
  ),
  spares AS (
    SELECT date_trunc('month', created_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(total_amount)::numeric AS amt
      FROM public.spare_part_orders
     WHERE COALESCE(payment_status::text,'') = 'completed'
       AND created_at >= now() - ((p_months + 1) || ' months')::interval
     GROUP BY 1
  ),
  refunds AS (
    SELECT date_trunc('month', refunded_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(amount_rupees)::numeric AS amt
      FROM public.repair_job_escrow
     WHERE status = 'refunded'
       AND refunded_at >= now() - ((p_months + 1) || ' months')::interval
     GROUP BY 1
  ),
  snaps AS (
    SELECT DISTINCT ON (date_trunc('month', snapshot_date))
           date_trunc('month', snapshot_date)::date AS m_start,
           snapshot_date,
           cash_balance_rupees,
           snapshot_note
      FROM public.founder_cash_position_snapshots
     ORDER BY date_trunc('month', snapshot_date), snapshot_date DESC
  )
  SELECT
    m.m_start                                                    AS month_start,
    s.snapshot_date                                              AS snapshot_date,
    s.cash_balance_rupees                                        AS cash_balance_rupees,
    COALESCE(i.infl, 0)                                          AS month_inflow_rupees,
    COALESCE(p.amt, 0) + COALESCE(sp.amt, 0) + COALESCE(r.amt,0) AS month_burn_rupees,
    COALESCE(i.infl, 0)
      - (COALESCE(p.amt, 0) + COALESCE(sp.amt, 0) + COALESCE(r.amt, 0)) AS month_net_rupees,
    s.snapshot_note                                              AS snapshot_note
  FROM months m
  LEFT JOIN inflow  i  ON i.m_start  = m.m_start
  LEFT JOIN payouts p  ON p.m_start  = m.m_start
  LEFT JOIN spares  sp ON sp.m_start = m.m_start
  LEFT JOIN refunds r  ON r.m_start  = m.m_start
  LEFT JOIN snaps   s  ON s.m_start  = m.m_start
  ORDER BY m.m_start DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_skill_gap_by_state(p_category text)
CREATE OR REPLACE FUNCTION public.founder_skill_gap_by_state(p_category text)
 RETURNS TABLE(state text, engineer_count integer, active_amc_count integer, open_jobs_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(o.state, 'unknown') AS state,
    (COUNT(DISTINCT e.user_id) FILTER (WHERE p_category = ANY(e.specializations::text[])))::int AS engineer_count,
    (COUNT(DISTINCT a.id) FILTER (WHERE p_category = ANY(a.equipment_categories) AND a.status = 'active'))::int AS active_amc_count,
    (COUNT(DISTINCT rj.id) FILTER (WHERE rj.equipment_type::text = p_category AND rj.status IN ('requested','assigned','en_route','in_progress')))::int AS open_jobs_count
  FROM organizations o
  LEFT JOIN profiles p ON p.organization_id = o.id
  LEFT JOIN engineers e ON e.user_id = p.id
  LEFT JOIN amc_contracts a ON a.hospital_user_id = p.id
  LEFT JOIN repair_jobs rj ON rj.hospital_org_id = o.id
  GROUP BY o.state
  ORDER BY engineer_count ASC, open_jobs_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_skill_gap_engineer_breakdown()
CREATE OR REPLACE FUNCTION public.founder_skill_gap_engineer_breakdown()
 RETURNS TABLE(category text, tier text, engineer_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    unnest(e.specializations)::text AS category,
    COALESCE(e.cached_highest_tier, 'unranked') AS tier,
    COUNT(*)::int AS engineer_count
  FROM engineers e
  WHERE e.specializations IS NOT NULL
  GROUP BY 1, 2
  ORDER BY 1, 2;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_skill_gap_overview()
CREATE OR REPLACE FUNCTION public.founder_skill_gap_overview()
 RETURNS TABLE(category text, target_count integer, current_count integer, gap integer, criticality text, min_tier text, amc_contracts_count integer, open_jobs_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.category,
    c.target_engineer_count AS target_count,
    COALESCE(eng.cnt, 0)::int AS current_count,
    GREATEST(c.target_engineer_count - COALESCE(eng.cnt, 0), 0)::int AS gap,
    c.criticality,
    c.min_tier,
    COALESCE(amc.cnt, 0)::int AS amc_contracts_count,
    COALESCE(jobs.cnt, 0)::int AS open_jobs_count
  FROM founder_skill_gap_categories c
  LEFT JOIN (
    SELECT unnest(specializations)::text AS skill, COUNT(DISTINCT user_id)::int AS cnt
    FROM engineers
    WHERE specializations IS NOT NULL
    GROUP BY 1
  ) eng ON eng.skill = c.category
  LEFT JOIN (
    SELECT unnest(equipment_categories) AS cat, COUNT(*)::int AS cnt
    FROM amc_contracts
    WHERE status = 'active'
    GROUP BY 1
  ) amc ON amc.cat = c.category
  LEFT JOIN (
    SELECT equipment_type::text AS cat, COUNT(*)::int AS cnt
    FROM repair_jobs
    WHERE status IN ('requested','assigned','en_route','in_progress')
    GROUP BY 1
  ) jobs ON jobs.cat = c.category
  ORDER BY GREATEST(c.target_engineer_count - COALESCE(eng.cnt, 0), 0) DESC,
           CASE c.criticality
             WHEN 'critical' THEN 4 WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END DESC;
END $function$
;

-- ---------------------------------------------------------------------
-- public.founder_skill_gap_training_candidates(p_category text)
CREATE OR REPLACE FUNCTION public.founder_skill_gap_training_candidates(p_category text)
 RETURNS TABLE(engineer_user_id uuid, engineer_email text, current_skills text[], cached_highest_tier text, completed_jobs_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.user_id AS engineer_user_id,
    p.email AS engineer_email,
    e.specializations::text[] AS current_skills,
    COALESCE(e.cached_highest_tier, 'unranked') AS cached_highest_tier,
    (SELECT COUNT(*) FROM repair_jobs rj
      WHERE rj.engineer_id = e.id AND rj.status = 'completed')::int AS completed_jobs_count
  FROM engineers e
  JOIN profiles p ON p.id = e.user_id
  WHERE e.specializations IS NOT NULL
    AND NOT (p_category = ANY(e.specializations::text[]))
    AND array_length(e.specializations, 1) >= 1
  ORDER BY array_length(e.specializations, 1) DESC,
           CASE COALESCE(e.cached_highest_tier, 'unranked')
             WHEN 'platinum' THEN 5 WHEN 'gold' THEN 4 WHEN 'silver' THEN 3 WHEN 'bronze' THEN 2 ELSE 1 END DESC
  LIMIT 50;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_tier_distribution_by_city()
CREATE OR REPLACE FUNCTION public.founder_tier_distribution_by_city()
 RETURNS TABLE(city text, none_cnt bigint, bronze_cnt bigint, silver_cnt bigint, gold_cnt bigint, total_cnt bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      coalesce(ecp.current_tier, 'none') AS tier
    FROM public.engineer_certification_progress ecp
    JOIN public.profiles p ON p.id = ecp.engineer_user_id
    WHERE p.role = 'engineer'
  )
  SELECT
    b.city,
    count(*) FILTER (WHERE b.tier = 'none')::bigint,
    count(*) FILTER (WHERE b.tier = 'bronze')::bigint,
    count(*) FILTER (WHERE b.tier = 'silver')::bigint,
    count(*) FILTER (WHERE b.tier = 'gold')::bigint,
    count(*)::bigint
  FROM base b
  GROUP BY b.city
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_tier_graduations_recent()
CREATE OR REPLACE FUNCTION public.founder_tier_graduations_recent()
 RETURNS TABLE(user_id uuid, display_name text, old_tier text, new_tier text, direction text, changed_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tier_rank(tier, rank) AS (
    VALUES ('none'::text, 0), ('bronze', 1), ('silver', 2), ('gold', 3)
  )
  SELECT
    h.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    h.prev_tier,
    h.new_tier,
    CASE WHEN tr_new.rank > tr_old.rank THEN 'promotion'
         WHEN tr_new.rank < tr_old.rank THEN 'demotion'
         ELSE 'lateral'
    END,
    h.changed_at
  FROM public.engineer_tier_history h
  LEFT JOIN public.profiles p ON p.id = h.engineer_user_id
  LEFT JOIN tier_rank tr_old ON tr_old.tier = h.prev_tier
  LEFT JOIN tier_rank tr_new ON tr_new.tier = h.new_tier
  WHERE h.changed_at >= now() - interval '30 days'
  ORDER BY h.changed_at DESC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_top_suppliers_30d()
CREATE OR REPLACE FUNCTION public.founder_top_suppliers_30d()
 RETURNS TABLE(supplier_name text, supplier_tier text, intake_rows bigint, total_qty bigint, total_cost numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    s.supplier_name,
    s.supplier_tier,
    count(i.id)::bigint,
    coalesce(sum(i.quantity_received), 0)::bigint,
    coalesce(sum(i.total_cost_rupees), 0)::numeric
  FROM public.bonded_parts_suppliers s
  LEFT JOIN public.bonded_parts_intake i ON i.supplier_id = s.id
    AND i.intake_received_at >= now() - interval '30 days'
  GROUP BY s.supplier_name, s.supplier_tier
  HAVING count(i.id) > 0
  ORDER BY 4 DESC
  LIMIT 25;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_weekly_board_pack(p_week_end date)
CREATE OR REPLACE FUNCTION public.founder_weekly_board_pack(p_week_end date DEFAULT CURRENT_DATE)
 RETURNS TABLE(payload jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_week_start date := p_week_end - INTERVAL '6 days';
  v_4wk_ago    date := p_week_end - INTERVAL '28 days';
  v_result     jsonb;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  WITH
    rev AS (
      SELECT
        COALESCE(SUM(amount) FILTER (WHERE status = 'completed' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS weekly_gmv,
        COALESCE(SUM(amount) FILTER (WHERE status = 'completed' AND payment_method IN ('upi','cash') AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS cash_collected,
        COALESCE(SUM(amount) FILTER (WHERE status = 'refunded' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS refunds_issued
      FROM public.payments
    ),
    payouts_week AS (
      -- r1322 FIX: 'paid_out' → 'processed'
      SELECT COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'processed' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS weekly_payouts,
             COUNT(*) FILTER (WHERE status IN ('queued','processing'))::int AS open_payouts
      FROM public.engineer_payouts
    ),
    mrr_now AS (
      SELECT COALESCE(SUM(monthly_fee_rupees), 0)::numeric AS mrr
      FROM public.amc_contracts
      WHERE status = 'active' AND (start_date IS NULL OR start_date <= p_week_end)
        AND (end_date IS NULL OR end_date >= p_week_end)
    ),
    mrr_4wk AS (
      SELECT COALESCE(SUM(monthly_fee_rupees), 0)::numeric AS mrr
      FROM public.amc_contracts
      WHERE (start_date IS NULL OR start_date <= v_4wk_ago)
        AND (end_date IS NULL OR end_date >= v_4wk_ago)
        AND status IN ('active','churned')
    ),
    amc AS (
      SELECT
        COUNT(*) FILTER (WHERE status = 'active' AND (end_date IS NULL OR end_date >= p_week_end))::int AS active_eop,
        COUNT(*) FILTER (WHERE start_date BETWEEN v_week_start AND p_week_end)::int AS signed_week,
        COUNT(*) FILTER (WHERE end_date BETWEEN v_week_start AND p_week_end AND status = 'churned')::int AS churned_week
      FROM public.amc_contracts
    ),
    eng AS (
      SELECT
        COUNT(*) FILTER (WHERE verification_status::text = 'verified')::int AS active_eop,
        COUNT(*) FILTER (WHERE created_at::date BETWEEN v_week_start AND p_week_end)::int AS added_week,
        COUNT(*) FILTER (WHERE verification_status::text = 'suspended' AND updated_at::date BETWEEN v_week_start AND p_week_end)::int AS churned_week
      FROM public.engineers
    ),
    eng_jobs AS (
      SELECT COUNT(*)::int AS completed_week
      FROM public.repair_jobs
      WHERE completed_at::date BETWEEN v_week_start AND p_week_end
    ),
    hosp AS (
      SELECT
        COUNT(DISTINCT o.id) FILTER (WHERE o.type = 'hospital')::int AS active_eop,
        COUNT(DISTINCT o.id) FILTER (WHERE o.type = 'hospital' AND o.created_at::date BETWEEN v_week_start AND p_week_end)::int AS added_week
      FROM public.organizations o
    ),
    top_state AS (
      SELECT o.state AS state_name, COUNT(rj.id)::int AS jobs_count
      FROM public.repair_jobs rj
      JOIN public.organizations o ON o.id = rj.hospital_org_id
      WHERE rj.completed_at::date BETWEEN v_week_start AND p_week_end
      GROUP BY o.state
      ORDER BY jobs_count DESC
      LIMIT 1
    ),
    ops AS (
      SELECT
        COUNT(*) FILTER (WHERE completed_at::date BETWEEN v_week_start AND p_week_end)::int AS completed_week,
        COUNT(*) FILTER (WHERE created_at::date BETWEEN v_week_start AND p_week_end)::int AS initiated_week,
        AVG(EXTRACT(EPOCH FROM (completed_at - created_at)) / 3600.0) FILTER (WHERE completed_at::date BETWEEN v_week_start AND p_week_end)::numeric AS avg_complete_hours
      FROM public.repair_jobs
    ),
    code_red AS (
      -- r1322 FIX: code_red_events doesn't exist → code_red_requests
      SELECT COUNT(*)::int AS cnt
      FROM public.code_red_requests
      WHERE created_at::date BETWEEN v_week_start AND p_week_end
    ),
    disputes AS (
      SELECT
        COUNT(*) FILTER (WHERE created_at::date BETWEEN v_week_start AND p_week_end)::int AS week_count,
        COUNT(*) FILTER (WHERE status = 'open')::int AS open_count
      FROM public.disputes
    ),
    grievances AS (
      SELECT
        COUNT(*) FILTER (WHERE created_at::date BETWEEN v_week_start AND p_week_end)::int AS week_count,
        COUNT(*) FILTER (WHERE status IN ('open','in_review'))::int AS open_count
      FROM public.dpdp_grievances
    ),
    incidents AS (
      SELECT COUNT(*) FILTER (WHERE resolved_at IS NULL)::int AS open_count
      FROM public.founder_incidents
    ),
    -- r1322 FIX: spot_audit_invites doesn't exist → invitations LEFT JOIN responses
    audit AS (
      SELECT
        AVG(sr.rating)::numeric AS avg_rating,
        COUNT(*) FILTER (WHERE si.created_at::date BETWEEN v_week_start AND p_week_end)::int AS invites_sent,
        COUNT(sr.id) FILTER (WHERE sr.responded_at::date BETWEEN v_week_start AND p_week_end)::int AS invites_responded
      FROM public.spot_audit_invitations si
      LEFT JOIN public.spot_audit_responses sr ON sr.invitation_id = si.id
      WHERE si.created_at::date BETWEEN v_week_start AND p_week_end
    )
  SELECT jsonb_build_object(
    'week_end', p_week_end,
    'week_start', v_week_start,
    'weekly_gmv_rupees', rev.weekly_gmv,
    'weekly_payouts_rupees', payouts_week.weekly_payouts,
    'weekly_take_rate_pct', CASE WHEN rev.weekly_gmv > 0 THEN ROUND(((rev.weekly_gmv - payouts_week.weekly_payouts) / rev.weekly_gmv) * 100, 2) ELSE 0 END,
    'mrr_eop', mrr_now.mrr,
    'mrr_eop_4wk_ago', mrr_4wk.mrr,
    'mrr_delta_pct_4wk', CASE WHEN mrr_4wk.mrr > 0 THEN ROUND(((mrr_now.mrr - mrr_4wk.mrr) / mrr_4wk.mrr) * 100, 2) ELSE NULL END,
    'amc_active_count_eop', amc.active_eop,
    'amc_signed_this_week', amc.signed_week,
    'amc_churned_this_week', amc.churned_week,
    'amc_net_new', amc.signed_week - amc.churned_week,
    'engineers_active_count_eop', eng.active_eop,
    'engineers_added_this_week', eng.added_week,
    'engineers_churned_this_week', eng.churned_week,
    'engineer_jobs_completed_week', eng_jobs.completed_week,
    'hospitals_active_count_eop', hosp.active_eop,
    'hospitals_added_this_week', hosp.added_week,
    'top_state_by_jobs', COALESCE(top_state.state_name, '—'),
    'top_state_jobs_count', COALESCE(top_state.jobs_count, 0),
    'jobs_completed_this_week', ops.completed_week,
    'jobs_initiated_this_week', ops.initiated_week,
    'average_completion_hours', ROUND(COALESCE(ops.avg_complete_hours, 0), 1),
    'code_red_count_this_week', code_red.cnt,
    'dispute_count_this_week', disputes.week_count,
    'open_disputes_count', disputes.open_count,
    'dpdp_grievance_count_this_week', grievances.week_count,
    'open_grievances_count', grievances.open_count,
    'spot_audit_rating_avg_week', ROUND(COALESCE(audit.avg_rating, 0), 2),
    'spot_audit_invites_sent_week', audit.invites_sent,
    'spot_audit_invites_responded_week', audit.invites_responded,
    'cash_collected_this_week', rev.cash_collected,
    'refunds_issued_this_week', rev.refunds_issued,
    'open_payouts_count', payouts_week.open_payouts,
    'open_incidents_count', incidents.open_count,
    'generated_at', now()
  ) INTO v_result
  FROM rev, payouts_week, mrr_now, mrr_4wk, amc, eng, eng_jobs, hosp,
       LATERAL (SELECT state_name, jobs_count FROM top_state UNION ALL SELECT NULL, 0 LIMIT 1) top_state,
       ops, code_red, disputes, grievances, incidents, audit;

  RETURN QUERY SELECT v_result;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.list_interventions_r2430()
CREATE OR REPLACE FUNCTION public.list_interventions_r2430()
 RETURNS TABLE(id uuid, engineer_user_id uuid, engineer_name text, intervention_kind text, opened_at timestamp with time zone, owner_email text, planned_action text, status text, outcome text, follow_up_at timestamp with time zone, closed_at timestamp with time zone, closed_by_email text, notes text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id,
         COALESCE(p.full_name, p.email, 'Engineer ' || left(i.engineer_user_id::text, 8)) AS engineer_name,
         i.intervention_kind, i.opened_at, i.owner_email, i.planned_action,
         i.status, i.outcome, i.follow_up_at, i.closed_at, i.closed_by_email, i.notes
  FROM public.burnout_interventions_r2430 i
  LEFT JOIN public.engineers e ON e.id = i.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY i.opened_at DESC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.list_signals_r2430()
CREATE OR REPLACE FUNCTION public.list_signals_r2430()
 RETURNS TABLE(id uuid, engineer_user_id uuid, engineer_name text, signal_week_start date, hours_worked_7d numeric, days_no_rest integer, csat_slip_pct numeric, cancellations_count integer, miss_count integer, signal_score integer, severity text, top_signal text, notes text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id,
         COALESCE(p.full_name, p.email, 'Engineer ' || left(s.engineer_user_id::text, 8)) AS engineer_name,
         s.signal_week_start, s.hours_worked_7d, s.days_no_rest, s.csat_slip_pct,
         s.cancellations_count, s.miss_count, s.signal_score, s.severity,
         s.top_signal, s.notes
  FROM public.engineer_burnout_signals_r2430 s
  LEFT JOIN public.engineers e ON e.id = s.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY s.signal_score DESC, s.signal_week_start DESC;
END;
$function$
;

-- ---------------------------------------------------------------------
-- public.monthly_pulse_summary_r2497()
CREATE OR REPLACE FUNCTION public.monthly_pulse_summary_r2497()
 RETURNS TABLE(month_start date, weeks_logged integer, avg_mood numeric, avg_energy numeric, total_decisions integer, total_regretted integer, regret_rate_pct numeric, open_correlations integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.month_start AS month_start,
    (COUNT(*))::int AS weeks_logged,
    ROUND(AVG(m.mood_score), 2) AS avg_mood,
    ROUND(AVG(m.energy_score), 2) AS avg_energy,
    (COALESCE(SUM(m.decisions_made_count),0))::int AS total_decisions,
    (COALESCE(SUM(m.decisions_regret_count),0))::int AS total_regretted,
    CASE WHEN COALESCE(SUM(m.decisions_made_count),0) = 0 THEN 0
      ELSE ROUND((SUM(m.decisions_regret_count)::numeric / SUM(m.decisions_made_count)::numeric) * 100, 2)
    END AS regret_rate_pct,
    (SELECT (COUNT(*))::int FROM public.emotion_decision_correlations_r2497 c
      WHERE date_trunc('month', c.week_start)::date = m.month_start
        AND c.status IN ('open','in_progress')) AS open_correlations
  FROM (SELECT w.*, date_trunc('month', w.week_start)::date AS month_start
        FROM public.founder_weekly_mood_r2497 w) m
  GROUP BY m.month_start
  ORDER BY m.month_start DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.monthly_pulse_summary_r2549()
CREATE OR REPLACE FUNCTION public.monthly_pulse_summary_r2549()
 RETURNS TABLE(month_start date, weeks_logged bigint, avg_strategic_hours numeric, avg_firefighting_hours numeric, avg_leverage numeric, corrections_done bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.month_start AS month_start,
         COUNT(*)::bigint AS weeks_logged,
         ROUND(AVG(a.strategic_hours)::numeric, 1) AS avg_strategic_hours,
         ROUND(AVG(a.firefighting_hours)::numeric, 1) AS avg_firefighting_hours,
         ROUND(AVG(a.leverage_score)::numeric, 1) AS avg_leverage,
         (SELECT COUNT(*) FROM public.energy_allocation_corrections_r2549 cc
          JOIN public.founder_weekly_energy_allocation_r2549 aa ON aa.id = cc.allocation_id
          WHERE date_trunc('month', aa.week_start)::date = a.month_start
            AND cc.status = 'done')::bigint AS corrections_done
  FROM (SELECT w.*, date_trunc('month', w.week_start)::date AS month_start
        FROM public.founder_weekly_energy_allocation_r2549 w) a
  GROUP BY a.month_start
  ORDER BY a.month_start DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.monthly_reading_trend_r1830(p_months integer)
CREATE OR REPLACE FUNCTION public.monthly_reading_trend_r1830(p_months integer DEFAULT 12)
 RETURNS TABLE(month_start date, weeks_logged integer, total_articles integer, total_book_pages integer, total_podcast_minutes integer, total_talks integer, avg_helpful_score numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH mon AS (
    SELECT
      date_trunc('month', l.week_start) AS month_key,
      (COUNT(*) )::int AS n_weeks,
      COALESCE(SUM(l.articles_read),0)::int AS n_articles,
      COALESCE(SUM(l.books_pages_read),0)::int AS n_pages,
      COALESCE(SUM(l.podcasts_minutes),0)::int AS n_minutes,
      COALESCE(SUM(l.talks_watched),0)::int AS n_talks
    FROM public.founder_weekly_reading_log_r1830 l
    WHERE l.week_start >= (CURRENT_DATE - (p_months || ' months')::interval)
    GROUP BY date_trunc('month', l.week_start)
  )
  SELECT
    m.month_key::date AS month_start,
    m.n_weeks,
    m.n_articles,
    m.n_pages,
    m.n_minutes,
    m.n_talks,
    COALESCE((
      SELECT ROUND(AVG(s.helpful_score)::numeric, 2)
      FROM public.founder_reading_source_breakdown_r1830 s
      WHERE date_trunc('month', s.week_start) = m.month_key
    ), 0) AS avg_helpful_score
  FROM mon m
  ORDER BY month_start DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.my_sla_card()
CREATE OR REPLACE FUNCTION public.my_sla_card()
 RETURNS TABLE(jobs_completed_window integer, jobs_disputed_window integer, dispute_rate_pct numeric, avg_accept_to_arrival_hrs numeric, avg_arrival_to_complete_hrs numeric, sla_breaches integer, on_time_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_window_start timestamptz := now() - interval '30 days';
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH window_jobs AS (
    SELECT
      rj.id AS job_id,
      rj.status,
      rj.completed_at,
      e.status AS escrow_status,
      (SELECT min(att.device_captured_at)
         FROM public.engineer_attendance att
        WHERE att.repair_job_id = rj.id
          AND att.event_kind = 'arrival_checkin') AS first_arrival,
      b.updated_at AS accepted_at
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
    LEFT JOIN public.repair_job_escrow e ON e.repair_job_id = rj.id
    WHERE b.status = 'accepted'
      AND b.engineer_user_id = v_user
      AND b.updated_at >= v_window_start
  )
  SELECT
    count(*) FILTER (WHERE wj.status = 'completed')::int,
    count(*) FILTER (WHERE wj.escrow_status = 'disputed')::int,
    CASE WHEN count(*) FILTER (WHERE wj.status = 'completed') > 0
         THEN round(count(*) FILTER (WHERE wj.escrow_status = 'disputed') * 100.0
                    / count(*) FILTER (WHERE wj.status = 'completed'), 1)
         ELSE 0 END,
    avg(EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0)
      FILTER (WHERE wj.first_arrival IS NOT NULL)::numeric(8,2),
    avg(EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0)
      FILTER (WHERE wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL)::numeric(8,2),
    (count(*) FILTER (
      WHERE wj.first_arrival IS NOT NULL
        AND EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0 > 48
    )::int
    + count(*) FILTER (
      WHERE wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL
        AND EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0 > 24
    )::int)::int,
    CASE WHEN count(*) FILTER (WHERE wj.status = 'completed') > 0
         THEN round(((count(*) FILTER (WHERE wj.status = 'completed')
                       - count(*) FILTER (
                           WHERE (wj.first_arrival IS NOT NULL
                                  AND EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0 > 48)
                              OR (wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL
                                  AND EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0 > 24)
                         )
                      ) * 100.0
                      / count(*) FILTER (WHERE wj.status = 'completed')), 1)
         ELSE 0 END
  FROM window_jobs wj;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2815_chain_rollup()
CREATE OR REPLACE FUNCTION public.r2815_chain_rollup()
 RETURNS TABLE(chain_name text, fridges integer, audited_events integer, total_deviation_minutes integer, rupees_at_risk bigint, rupees_lost bigint, loss_ratio_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    i.chain_name,
    COUNT(DISTINCT i.id)::int,
    COUNT(e.id)::int,
    COALESCE(SUM(e.duration_minutes),0)::int,
    COALESCE(SUM(e.rupees_at_risk),0)::bigint,
    COALESCE(SUM(e.rupees_lost),0)::bigint,
    CASE WHEN COALESCE(SUM(e.rupees_at_risk),0) = 0 THEN 0
         ELSE ROUND((SUM(e.rupees_lost)::numeric / SUM(e.rupees_at_risk)::numeric) * 100, 1)
    END
  FROM pharmacy_fridge_inventory_r2815 i
  LEFT JOIN fridge_temp_audit_events_r2815 e ON e.fridge_id = i.id
  GROUP BY i.chain_name
  ORDER BY COALESCE(SUM(e.rupees_lost),0) DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2815_outcome_distribution()
CREATE OR REPLACE FUNCTION public.r2815_outcome_distribution()
 RETURNS TABLE(outcome text, events integer, rupees_at_risk bigint, rupees_lost bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
#variable_conflict use_column
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.outcome,
         COUNT(*)::int,
         COALESCE(SUM(e.rupees_at_risk),0)::bigint,
         COALESCE(SUM(e.rupees_lost),0)::bigint
  FROM fridge_temp_audit_events_r2815 e
  GROUP BY e.outcome
  ORDER BY COALESCE(SUM(e.rupees_lost),0) DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.reap_expired_kyc_renewals()
CREATE OR REPLACE FUNCTION public.reap_expired_kyc_renewals()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count int := 0;
  v_row   record;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  FOR v_row IN
    SELECT id, engineer_user_id
      FROM public.engineer_kyc_renewals
     WHERE status IN ('pending','in_progress')
       AND grace_until < now()
  LOOP
    UPDATE public.engineer_kyc_renewals
       SET status = 'expired',
           expired_at = now()
     WHERE id = v_row.id;

    -- engineers has no verification_status_updated_at column; the
    -- update_engineers_updated_at BEFORE UPDATE trigger stamps updated_at.
    UPDATE public.engineers
       SET verification_status = 'pending'
     WHERE user_id = v_row.engineer_user_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.recompute_heatmap_r1779(p_hospital_user_id uuid, p_window_start date, p_window_end date)
CREATE OR REPLACE FUNCTION public.recompute_heatmap_r1779(p_hospital_user_id uuid, p_window_start date, p_window_end date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rows int := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  DELETE FROM public.hospital_service_volume_heatmap_r1779
  WHERE hospital_user_id = p_hospital_user_id
    AND recorded_window_start = p_window_start
    AND recorded_window_end = p_window_end;

  INSERT INTO public.hospital_service_volume_heatmap_r1779
    (hospital_user_id, day_of_week, hour_of_day, avg_service_count, recorded_window_start, recorded_window_end)
  SELECT
    p_hospital_user_id,
    EXTRACT(DOW FROM rj.completed_at)::int,
    EXTRACT(HOUR FROM rj.completed_at)::int,
    COUNT(*)::numeric,
    p_window_start,
    p_window_end
  FROM public.repair_jobs rj
  WHERE rj.hospital_user_id = p_hospital_user_id
    AND rj.completed_at IS NOT NULL
    AND rj.completed_at::date BETWEEN p_window_start AND p_window_end
  GROUP BY EXTRACT(DOW FROM rj.completed_at)::int, EXTRACT(HOUR FROM rj.completed_at)::int;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'recompute_heatmap_r1779',
          jsonb_build_object('hospital_user_id', p_hospital_user_id, 'window_start', p_window_start, 'window_end', p_window_end, 'rows', v_rows));

  RETURN v_rows;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.refresh_affinity_r1896(p_engineer_user_id uuid, p_hospital_user_id uuid)
CREATE OR REPLACE FUNCTION public.refresh_affinity_r1896(p_engineer_user_id uuid, p_hospital_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_jobs int;
  v_repeat int;
  v_avg_hosp numeric;
  v_score int;
  v_status text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*)::int,
         (COUNT(*) FILTER (WHERE rj.completed_at IS NOT NULL))::int,
         AVG(rj.hospital_rating)
    INTO v_total_jobs, v_repeat, v_avg_hosp
    FROM public.repair_jobs rj
    JOIN public.engineers e ON e.id = rj.engineer_id
   WHERE e.user_id = p_engineer_user_id
     AND rj.hospital_user_id = p_hospital_user_id;

  v_score := LEAST(100, GREATEST(0, COALESCE(v_repeat,0)*10 + COALESCE(ROUND(v_avg_hosp*10)::int,0)));
  v_status := CASE
    WHEN v_score >= 70 THEN 'strong'
    WHEN v_score >= 40 THEN 'moderate'
    ELSE 'weak'
  END;

  INSERT INTO public.engineer_hospital_affinity_r1896
    (engineer_user_id, hospital_user_id, repeat_assignment_count, avg_hospital_rating, total_jobs, affinity_score, status, updated_at)
  VALUES (p_engineer_user_id, p_hospital_user_id, COALESCE(v_repeat,0), v_avg_hosp, COALESCE(v_total_jobs,0), v_score, v_status, now())
  ON CONFLICT (engineer_user_id, hospital_user_id) DO UPDATE
    SET repeat_assignment_count = EXCLUDED.repeat_assignment_count,
        avg_hospital_rating = EXCLUDED.avg_hospital_rating,
        total_jobs = EXCLUDED.total_jobs,
        affinity_score = EXCLUDED.affinity_score,
        status = CASE WHEN public.engineer_hospital_affinity_r1896.status = 'blocked' THEN 'blocked' ELSE EXCLUDED.status END,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_affinity_r1896',
          jsonb_build_object('engineer_user_id', p_engineer_user_id, 'hospital_user_id', p_hospital_user_id, 'score', v_score));

  RETURN v_id;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.refresh_hospital_service_geo_hotspots_r1831()
CREATE OR REPLACE FUNCTION public.refresh_hospital_service_geo_hotspots_r1831()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  DELETE FROM public.hospital_service_geo_hotspots_r1831;

  INSERT INTO public.hospital_service_geo_hotspots_r1831
    (area, total_jobs_30d, avg_response_min, density_score, recommended_engineer_cluster)
  SELECT
    COALESCE(l.area, 'unknown'),
    (COUNT(rj.id))::int,
    0,
    (COUNT(rj.id) * 10)::int,
    GREATEST(1, (COUNT(rj.id) / 20)::int)
  FROM public.hospital_service_geo_locations_r1831 l
  LEFT JOIN public.repair_jobs rj
    ON rj.hospital_user_id = l.hospital_user_id
   AND rj.completed_at >= now() - interval '30 days'
  GROUP BY COALESCE(l.area, 'unknown');

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_hospital_service_geo_hotspots_r1831',
          jsonb_build_object('rows', v_count));

  RETURN v_count;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_founder_ops_open_jobs(p_limit integer)
CREATE OR REPLACE FUNCTION public.rpc_founder_ops_open_jobs(p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, status text, kind text, hospital_org_id uuid, contracted_amount_rupees bigint, created_at timestamp with time zone, age_days numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.id, j.status::text, j.kind::text, j.hospital_org_id,
         j.contracted_amount_rupees::bigint, j.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - j.created_at))/86400.0, 1)::numeric AS age_days
  FROM repair_jobs j
  WHERE j.status IN ('requested','assigned','en_route','in_progress')
  ORDER BY j.created_at ASC
  LIMIT GREATEST(p_limit, 1);
END $function$;

-- ---------------------------------------------------------------------
-- public.rpc_founder_ops_scorecard_build()
CREATE OR REPLACE FUNCTION public.rpc_founder_ops_scorecard_build()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_open int := 0; v_unassigned int := 0; v_stuck int := 0;
  v_payout_count int := 0; v_payout_rupees bigint := 0;
  v_spare int := 0; v_p0 int := 0; v_p1 int := 0;
  v_amc_overdue int := 0; v_score int := 100; v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) INTO v_open FROM repair_jobs
    WHERE status IN ('requested','assigned','en_route','in_progress');

  SELECT COUNT(*) INTO v_unassigned FROM repair_jobs
    WHERE status='requested' AND engineer_id IS NULL
      AND created_at < now() - interval '48 hours';

  SELECT COUNT(*) INTO v_stuck FROM repair_jobs
    WHERE status IN ('in_progress','en_route')
      AND created_at < now() - interval '7 days';

  SELECT COUNT(*), COALESCE(SUM(amount_rupees),0) INTO v_payout_count, v_payout_rupees
  FROM engineer_payouts WHERE status IN ('queued','processing');

  SELECT COUNT(*) INTO v_spare FROM spare_part_orders
    WHERE delivered_at IS NULL AND created_at < now() - interval '24 hours';

  SELECT COUNT(*) INTO v_p0 FROM founder_incidents WHERE severity='p0' AND resolved_at IS NULL;
  SELECT COUNT(*) INTO v_p1 FROM founder_incidents WHERE severity='p1' AND resolved_at IS NULL;

  SELECT COUNT(*) INTO v_amc_overdue FROM amc_contracts
    WHERE status='active' AND end_date < CURRENT_DATE;

  v_score := GREATEST(0, 100 - (v_p0*25) - (v_p1*10) - LEAST(v_unassigned*2, 20) - LEAST(v_stuck, 15) - LEAST(v_spare, 10));

  INSERT INTO founder_ops_scorecard_snapshots (
    snapshot_date, open_jobs_count, unassigned_jobs_count, stuck_jobs_count,
    payout_backlog_count, payout_backlog_rupees, spare_shortage_count,
    p0_incidents_open, p1_incidents_open, amc_overdue_count, health_score, built_at
  ) VALUES (
    CURRENT_DATE, v_open, v_unassigned, v_stuck,
    v_payout_count, v_payout_rupees, v_spare,
    v_p0, v_p1, v_amc_overdue, v_score, now()
  )
  ON CONFLICT (snapshot_date) DO UPDATE SET
    open_jobs_count = EXCLUDED.open_jobs_count,
    unassigned_jobs_count = EXCLUDED.unassigned_jobs_count,
    stuck_jobs_count = EXCLUDED.stuck_jobs_count,
    payout_backlog_count = EXCLUDED.payout_backlog_count,
    payout_backlog_rupees = EXCLUDED.payout_backlog_rupees,
    spare_shortage_count = EXCLUDED.spare_shortage_count,
    p0_incidents_open = EXCLUDED.p0_incidents_open,
    p1_incidents_open = EXCLUDED.p1_incidents_open,
    amc_overdue_count = EXCLUDED.amc_overdue_count,
    health_score = EXCLUDED.health_score,
    built_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END $function$;

-- ---------------------------------------------------------------------
-- public.rpc_founder_ops_unassigned_escalations()
CREATE OR REPLACE FUNCTION public.rpc_founder_ops_unassigned_escalations()
 RETURNS TABLE(id uuid, hospital_org_id uuid, kind text, created_at timestamp with time zone, hours_open numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.id, j.hospital_org_id, j.kind::text, j.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - j.created_at))/3600.0, 1)::numeric AS hours_open
  FROM repair_jobs j
  WHERE j.status = 'requested'
    AND j.engineer_id IS NULL
    AND j.created_at < now() - interval '48 hours'
  ORDER BY j.created_at ASC
  LIMIT 200;
END $function$;

-- ---------------------------------------------------------------------
-- public.rpc_year_end_auto_metrics()
CREATE OR REPLACE FUNCTION public.rpc_year_end_auto_metrics()
 RETURNS TABLE(metric_name text, metric_value numeric, metric_unit text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH rev AS (
    SELECT COALESCE(SUM(contracted_amount_rupees),0)::numeric AS v
    FROM repair_jobs
    WHERE status = 'completed'
      AND created_at >= date_trunc('year', now())
  ),
  jobs AS (
    SELECT count(*)::numeric AS v
    FROM repair_jobs
    WHERE status = 'completed'
      AND created_at >= date_trunc('year', now())
  ),
  amc AS (
    SELECT count(*)::numeric AS v
    FROM amc_contracts
    WHERE created_at >= date_trunc('year', now())
  ),
  rating AS (
    SELECT COALESCE(AVG(hospital_rating),0)::numeric AS v
    FROM repair_jobs
    WHERE hospital_rating IS NOT NULL
      AND created_at >= date_trunc('year', now())
  )
  SELECT 'revenue'::text, (SELECT v FROM rev), 'rupees'::text
  UNION ALL
  SELECT 'jobs_closed'::text, (SELECT v FROM jobs), 'count'::text
  UNION ALL
  SELECT 'amc_contracts'::text, (SELECT v FROM amc), 'count'::text
  UNION ALL
  SELECT 'avg_rating'::text, (SELECT v FROM rating), 'stars'::text;
END; $function$;

-- ---------------------------------------------------------------------
-- public.this_week_focus_r2430()
CREATE OR REPLACE FUNCTION public.this_week_focus_r2430()
 RETURNS TABLE(engineer_user_id uuid, engineer_name text, signal_score integer, severity text, top_signal text, hours_worked_7d numeric, days_no_rest integer, open_interventions bigint, recommended_action text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.engineer_user_id)
      s.engineer_user_id, s.signal_score, s.severity, s.top_signal,
      s.hours_worked_7d, s.days_no_rest
    FROM public.engineer_burnout_signals_r2430 s
    ORDER BY s.engineer_user_id, s.signal_week_start DESC
  ),
  open_ints AS (
    SELECT i.engineer_user_id, count(*)::bigint AS open_count
    FROM public.burnout_interventions_r2430 i
    WHERE i.status IN ('open','in_progress')
    GROUP BY i.engineer_user_id
  )
  SELECT l.engineer_user_id,
         COALESCE(p.full_name, 'Engineer ' || left(l.engineer_user_id::text, 8)) AS engineer_name,
         l.signal_score, l.severity, l.top_signal, l.hours_worked_7d, l.days_no_rest,
         COALESCE(o.open_count, 0) AS open_interventions,
         CASE
           WHEN l.severity = 'critical' AND COALESCE(o.open_count, 0) = 0 THEN 'OPEN INTERVENTION NOW - mandatory time off'
           WHEN l.severity = 'critical' THEN 'Monitor active intervention - escalate if no recovery'
           WHEN l.severity = 'high' AND COALESCE(o.open_count, 0) = 0 THEN 'Load reduction + coaching this week'
           WHEN l.severity = 'high' THEN 'Continue active intervention'
           WHEN l.severity = 'medium' THEN 'Schedule check-in within 7 days'
           ELSE 'Healthy - maintain cadence'
         END AS recommended_action
  FROM latest l
  LEFT JOIN public.engineers e ON e.id = l.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  LEFT JOIN open_ints o ON o.engineer_user_id = l.engineer_user_id
  WHERE l.severity IN ('critical','high','medium')
  ORDER BY
    CASE l.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    l.signal_score DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.top_burnout_engineers_r2430()
CREATE OR REPLACE FUNCTION public.top_burnout_engineers_r2430()
 RETURNS TABLE(engineer_user_id uuid, engineer_name text, latest_score integer, latest_severity text, latest_top_signal text, latest_week_start date, hours_worked_7d numeric, days_no_rest integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.engineer_user_id)
         s.engineer_user_id,
         COALESCE(p.full_name, p.email, 'Engineer ' || left(s.engineer_user_id::text, 8)) AS engineer_name,
         s.signal_score, s.severity, s.top_signal, s.signal_week_start,
         s.hours_worked_7d, s.days_no_rest
  FROM public.engineer_burnout_signals_r2430 s
  LEFT JOIN public.engineers e ON e.id = s.engineer_user_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY s.engineer_user_id, s.signal_week_start DESC, s.signal_score DESC;
END;
$function$
;

-- =====================================================================
-- VERIFY
-- =====================================================================
DO $gate$
DECLARE
  v_names text[] := ARRAY[
    'engineer_sla_board',
    'exec_360_v3_engineering_kpis',
    'founder_acquisition_attribution_by_kind',
    'founder_acquisition_attribution_summary',
    'founder_amc_churn_scores',
    'founder_amc_mrr_by_tier',
    'founder_amc_revenue_by_tier',
    'founder_at_risk_revenue',
    'founder_bonded_intake_cumulative',
    'founder_bonded_intake_trend',
    'founder_bonded_parts_v2_concentration_risk',
    'founder_cert_by_vendor',
    'founder_cert_expiring_soon',
    'founder_cert_renewal_sla_breaches',
    'founder_clv_recent_snapshots',
    'founder_clv_top_customers',
    'founder_commission_by_week_13wk',
    'founder_complete_kyc_renewal',
    'founder_critical_cockpit',
    'founder_cs_playbook_runs_due',
    'founder_customer_health_score_by_hospital',
    'founder_customer_health_score_summary',
    'founder_demand_by_city',
    'founder_demand_priority_distribution',
    'founder_demand_signals_recent',
    'founder_engineer_availability_summary',
    'founder_engineer_earnings_distribution',
    'founder_engineer_fleet_expiring_docs',
    'founder_engineer_side_projects_by_risk_r1469',
    'founder_engineer_side_projects_kpis_r1469',
    'founder_engineer_skills_proficiency_recent',
    'founder_equipment_procurement_overdue',
    'founder_equipment_procurement_recent',
    'founder_equipment_type_breakdown',
    'founder_evidence_ledger_65b_summary',
    'founder_gst_invoices_by_month_by_source',
    'founder_heatmap_by_category',
    'founder_heatmap_by_hospital',
    'founder_heatmap_capture_snapshot',
    'founder_heatmap_cells',
    'founder_heatmap_gaps',
    'founder_heatmap_kpis',
    'founder_hospital_chains_drilldown_by_chain',
    'founder_hospital_chains_drilldown_summary',
    'founder_hospital_expansion_existing_action_queue',
    'founder_hospital_expansion_existing_candidates',
    'founder_hospital_expansion_existing_plays_list',
    'founder_hospital_leaderboard_30d',
    'founder_hospital_maintenance_calendar_overdue',
    'founder_hospital_maintenance_calendar_recent',
    'founder_jobs_by_engineer_tier',
    'founder_jobs_completion_by_tier',
    'founder_jobs_snapshot_summary',
    'founder_jobs_unassigned_aging',
    'founder_live_ops_cockpit_v2_heartbeat',
    'founder_monthly_cash_ledger_history',
    'founder_monthly_cash_ledger_summary',
    'founder_morning_pulse_v2',
    'founder_notifications_by_kind_30d',
    'founder_notifications_engagement_30d',
    'founder_payouts_by_engineer_tier',
    'founder_payout_cadence_kpis',
    'founder_platform_fee_cumulative',
    'founder_platform_fee_revenue_by_month',
    'founder_r2813_refactor_queue',
    'founder_r2813_verdict_mix',
    'founder_r3137_blind_spots_open',
    'founder_referral_volume_trend',
    'founder_referrers_by_tier',
    'founder_renewal_action_ladder',
    'founder_renewal_kpis',
    'founder_renewal_postmortem_log',
    'founder_renewal_queue',
    'founder_renewal_silent_contracts',
    'founder_repair_job_bids_snapshot_summary',
    'founder_revenue_leakage_history',
    'founder_revenue_leakage_summary',
    'founder_revenue_recognition_history',
    'founder_revenue_recognition_summary',
    'founder_runway_burn_summary',
    'founder_runway_forecast_v2_summary',
    'founder_runway_history',
    'founder_skill_gap_by_state',
    'founder_skill_gap_engineer_breakdown',
    'founder_skill_gap_overview',
    'founder_skill_gap_training_candidates',
    'founder_tier_distribution_by_city',
    'founder_tier_graduations_recent',
    'founder_top_suppliers_30d',
    'founder_weekly_board_pack',
    'list_interventions_r2430',
    'list_signals_r2430',
    'monthly_pulse_summary_r2497',
    'monthly_pulse_summary_r2549',
    'monthly_reading_trend_r1830',
    'my_sla_card',
    'r2815_chain_rollup',
    'r2815_outcome_distribution',
    'reap_expired_kyc_renewals',
    'recompute_heatmap_r1779',
    'refresh_affinity_r1896',
    'refresh_hospital_service_geo_hotspots_r1831',
    'rpc_founder_ops_open_jobs',
    'rpc_founder_ops_scorecard_build',
    'rpc_founder_ops_unassigned_escalations',
    'rpc_year_end_auto_metrics',
    'this_week_focus_r2430',
    'top_burnout_engineers_r2430'
  ];
  v_bad   text;
  v_n     int;
BEGIN
  -- 1. all present, exactly once
  SELECT string_agg(x, ', ') INTO v_bad FROM unnest(v_names) x
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p
                      WHERE p.pronamespace='public'::regnamespace AND p.proname = x);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3796 VERIFY FAILED: function(s) vanished: %', v_bad;
  END IF;

  SELECT string_agg(q.proname || ' x' || q.c, ', ') INTO v_bad
    FROM (SELECT p.proname, count(*) c FROM pg_proc p
           WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
           GROUP BY p.proname) q WHERE q.c > 1;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3796 VERIFY FAILED: extra overload(s) created: %', v_bad;
  END IF;

  -- 2. argument list and parameter NAMES unchanged (PostgREST calls by name)
  SELECT string_agg(b.proname, ', ') INTO v_bad
    FROM _r3796_before b
    JOIN pg_proc p ON p.proname = b.proname AND p.pronamespace='public'::regnamespace
   WHERE pg_get_function_identity_arguments(p.oid) <> b.args
      OR coalesce((SELECT string_agg(x.name, ',' ORDER BY x.ord)
                   FROM unnest(coalesce(p.proargnames, '{}'::text[]))
                        WITH ORDINALITY AS x(name, ord)), '') <> b.argnames;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3796 VERIFY FAILED: signature/param-name drift in: %', v_bad;
  END IF;

  -- 3. the static errors among the touched set must be GONE (or far fewer)
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='plpgsql_check') THEN
    SELECT count(DISTINCT p.proname) INTO v_n
      FROM pg_proc p CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.prolang=(SELECT oid FROM pg_language WHERE lanname='plpgsql')
       AND p.prorettype <> 'trigger'::regtype
       AND p.proname = ANY(v_names) AND e.level='error';
    RAISE NOTICE 'round 3796: still statically broken among the % touched: %',
      array_length(v_names,1), v_n;
    IF v_n >= array_length(v_names,1) THEN
      RAISE EXCEPTION 'round 3796 VERIFY FAILED: broken count did not improve (% of %)',
        v_n, array_length(v_names,1);
    END IF;
  END IF;

  RAISE NOTICE 'round 3796 verified: % function(s) repaired, contract intact',
    array_length(v_names,1);
END
$gate$;

COMMIT;
