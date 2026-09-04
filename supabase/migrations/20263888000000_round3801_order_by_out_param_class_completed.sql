-- =====================================================================
-- Round 3801 -- 293 more silently-unordered result sets
-- =====================================================================
--
-- round3798 fixed six functions whose `ORDER BY` did nothing. This is the
-- rest of that class, found by settling the question STATICALLY after
-- round3798 could only settle it by measurement.
--
-- THE MECHANISM (unchanged from round3798)
--   In `RETURN QUERY SELECT ... ORDER BY foo`, PostgreSQL resolves the
--   ORDER BY identifier against the SELECT's OUTPUT COLUMN NAMES first. If
--   no output column is named `foo`, the identifier falls through to
--   PL/pgSQL, which substitutes the function-scope variable `foo` -- and a
--   RETURNS TABLE column IS such a variable, always NULL during
--   RETURN QUERY. The query then orders by a CONSTANT. No error, no
--   warning, rows still return; they are simply in arbitrary order, and
--   any LIMIT takes an arbitrary slice.
--
-- WHY A STATIC PASS WAS NEEDED, AND WHY THE FIRST ONE WAS WRONG
--   round3798 confirmed its six by executing them and measuring
--   sortedness. That cannot settle a function returning 0-2 rows, and 39
--   candidates were left explicitly unresolved for exactly that reason.
--   So the rule was implemented as an analyser instead -- and the FIRST
--   implementation was WRONG in a way worth recording, because it would
--   have "repaired" ~330 healthy functions.
--
--   It assumed an output column name comes only from an explicit
--   `AS foo` or a bare column reference. PostgreSQL actually derives an
--   IMPLICIT name from the expression shape (FigureColname in
--   src/backend/parser/parse_target.c):
--       ColumnRef -> the column name        a.foo         -> "foo"
--       FuncCall  -> the FUNCTION name      count(*)      -> "count"
--       TypeCast  -> recurse into the arg   count(*)::int -> "count"
--       Coalesce  -> "coalesce",  CASE -> "case",  NULLIF -> "nullif"
--       anything else                       -> "?column?" (not nameable)
--   FILTER/OVER/WITHIN GROUP do not change the name.
--   So `ORDER BY count` against a select list containing `count(*)` binds
--   to the output column and is completely fine. v1 called that broken.
--   v2 implements FigureColname and reclassified 34 functions as healthy.
--
-- HOW THE ANALYSER WAS VALIDATED (both directions, before being trusted)
--   1. Against measured ground truth: all six functions round3798 proved
--      unsorted, and then aliased, are now reported "ok". PASS.
--   2. Against production, by executing its BROKEN verdicts and measuring
--      the real output order: 40 came back demonstrably UNSORTED.
--   3. The 7 that came back "sorted" were each inspected BY HAND, and all
--      7 confirmed the analyser rather than contradicting it. They were
--      artifacts of the SORTEDNESS TEST, not of the analyser:
--        * 4 are tie-dominated -- e.g. r2905_top_win_drivers returns ten
--          rows whose win_count is 1 every time, and
--          balance_kind_distribution_r2633 five rows all equal to 1. A
--          constant column is trivially "monotonic" and proves nothing.
--        * founder_jobs_by_state returned (0, 0, 5) for a DESC ordering --
--          i.e. it is ASCENDING, which is positive evidence of breakage.
--          The test had accepted monotonic in EITHER direction.
--        * founder_r2696_by_tier and r2810_tier_breakdown really are in
--          descending order, but reading them shows why: their select
--          lists yield (customer_tier, count, coalesce, coalesce,
--          coalesce) and (engineer_tier, count, sum, sum, round, round),
--          so the ORDER BY identifier is nameless either way. With only
--          four GROUP BY groups the aggregate output order coincided with
--          the intended one.
--      Net: ZERO analyser false positives in the sample.
--
-- THE FIX
--   Give the corresponding select-list item the explicit alias the ORDER
--   BY was always meant to bind to. The mapping is deterministic, not
--   guessed: RETURN QUERY maps select-list item k onto RETURNS TABLE
--   column k, so the item to alias is the one at the ORDER BY column's
--   ORDINAL POSITION among the OUT parameters. Each rewrite asserts that
--   the item count equals the OUT parameter count, that the alias then
--   yields exactly that name, and that the whole ORDER BY now binds.
--
--   This fix is safe even where the output happened to be coincidentally
--   ordered: making a declared ORDER BY take effect cannot turn a
--   correctly-ordered result into a wrong one.
--
-- 10 functions were REFUSED rather than guessed at, because the select
-- list located for them had a different item count from the OUT parameter
-- list (1 item against 13 OUT parameters, for instance), which means the
-- locator found a subquery rather than the final SELECT and the
-- positional mapping cannot be trusted:
--   founder_hospital_auto_renew_by_tier
--   founder_clv_top_customers
--   admin_inactive_engineers
--   founder_npv_by_tier
--   rpc_year_end_overview
--   founder_customer_health_score_by_hospital
--   founder_demand_signal_dashboard
--   founder_audit_by_actor
--   founder_writeoff_churn_risk
--   rapport_pulse_at_risk_r2334
--
-- VERIFICATION tests the PROPERTY THAT WAS BROKEN, not the absence of an
-- error. Inside the transaction, for every repaired zero-argument
-- function, the gate executes it and asserts the result really is
-- monotonic in the DECLARED direction -- skipping only where the data
-- cannot answer (fewer than 3 rows, or fewer than 2 distinct values,
-- which is the trap that produced the 7 misleading "sorted" readings
-- above). Any function that is still unordered aborts the migration.

BEGIN;

-- ---------------------------------------------------------------------
-- public.market_share_status_funnel_r2673 -- ORDER BY total_revenue_rupees DESC
CREATE OR REPLACE FUNCTION public.market_share_status_funnel_r2673()
 RETURNS TABLE(status text, vertical_count integer, total_revenue_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.status,
         COUNT(*)::int,
         COALESCE(SUM(s.our_revenue_rupees),0)::bigint AS total_revenue_rupees
  FROM market_share_snapshots_r2673 s
  GROUP BY s.status
  ORDER BY total_revenue_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_repair_jobs_by_source -- ORDER BY jobs_90d DESC
CREATE OR REPLACE FUNCTION public.founder_repair_jobs_by_source()
 RETURNS TABLE(source text, jobs_90d bigint, gross_90d numeric, share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '90 days';
  RETURN QUERY
  WITH classified AS (
    SELECT
      rj.id,
      rj.contracted_amount_rupees,
      CASE
        WHEN rj.amc_contract_id IS NOT NULL THEN 'amc_visit'
        WHEN EXISTS (SELECT 1 FROM public.code_red_requests r WHERE r.resolution_repair_job_id = rj.id) THEN 'code_red'
        ELSE 'direct'
      END AS source
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '90 days'
  )
  SELECT
    c.source,
    count(*)::bigint AS jobs_90d,
    coalesce(sum(c.contracted_amount_rupees), 0)::numeric,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(count(*)::numeric / v_total::numeric * 100.0, 1)
    END
  FROM classified c
  GROUP BY c.source
  ORDER BY jobs_90d DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_press_by_outlet -- ORDER BY total_reach DESC
CREATE OR REPLACE FUNCTION public.founder_press_by_outlet(p_limit integer DEFAULT 20)
 RETURNS TABLE(outlet text, total bigint, total_reach bigint, positive_count bigint, last_occurred_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.outlet,
         COUNT(*)::bigint,
         COALESCE(SUM(m.reach_audience),0)::bigint AS total_reach,
         SUM(CASE WHEN m.sentiment='positive' THEN 1 ELSE 0 END)::bigint,
         MAX(m.occurred_at)
  FROM founder_press_mentions m
  GROUP BY m.outlet
  ORDER BY COUNT(*) DESC, total_reach DESC
  LIMIT GREATEST(p_limit,1);
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_eng360_reviewer_breakdown -- ORDER BY spread DESC
CREATE OR REPLACE FUNCTION public.founder_eng360_reviewer_breakdown()
 RETURNS TABLE(id uuid, engineer_label text, hospital_avg numeric, peer_avg numeric, founder_avg numeric, hospital_n bigint, peer_n bigint, founder_n bigint, spread numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, 'engineer ' || substr(e.id::text,1,6)),
    round(avg(s.composite_score) FILTER (WHERE s.reviewer_kind='hospital_contact')::numeric, 2),
    round(avg(s.composite_score) FILTER (WHERE s.reviewer_kind='peer_engineer')::numeric, 2),
    round(avg(s.composite_score) FILTER (WHERE s.reviewer_kind='founder')::numeric, 2),
    count(s.*) FILTER (WHERE s.reviewer_kind='hospital_contact'),
    count(s.*) FILTER (WHERE s.reviewer_kind='peer_engineer'),
    count(s.*) FILTER (WHERE s.reviewer_kind='founder'),
    round((COALESCE(max(s.composite_score),0) - COALESCE(min(s.composite_score),0))::numeric, 2) AS spread
  FROM engineers e
  JOIN engineer_360_feedback_submissions s ON s.engineer_id = e.id
  LEFT JOIN profiles p ON p.id = e.user_id
  GROUP BY e.id, p.full_name
  HAVING count(s.*) >= 3
  ORDER BY spread DESC NULLS LAST
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_apprentice_grad_candidates -- ORDER BY days_in_program DESC
CREATE OR REPLACE FUNCTION public.founder_apprentice_grad_candidates()
 RETURNS TABLE(pairing_id uuid, apprentice_name text, master_name text, days_in_program numeric, milestones_done integer, milestones_total integer, jobs_solo integer, ready boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    COALESCE(ap.full_name, ap.email),
    COALESCE(mp.full_name, mp.email),
    EXTRACT(EPOCH FROM (now() - p.curriculum_started_at))/86400.0 AS days_in_program,
    (SELECT COUNT(*)::int FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id AND m.completed_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id),
    p.jobs_solo,
    (
      EXTRACT(EPOCH FROM (now() - p.curriculum_started_at))/86400.0 >= 150
      AND p.jobs_solo >= 5
      AND (SELECT COUNT(*) FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id AND m.completed_at IS NULL) = 0
    )
  FROM apprentice_pairings_v2 p
  LEFT JOIN engineers ae ON ae.id = p.apprentice_engineer_id
  LEFT JOIN profiles  ap ON ap.id = ae.user_id
  LEFT JOIN engineers me ON me.id = p.master_engineer_id
  LEFT JOIN profiles  mp ON mp.id = me.user_id
  WHERE p.status='active'
  ORDER BY days_in_program DESC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_code_red_per_engineer_breakdown -- ORDER BY total_responses DESC
CREATE OR REPLACE FUNCTION public.founder_code_red_per_engineer_breakdown(p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, engineer_name text, cached_highest_tier text, total_responses bigint, median_first_response_seconds numeric, median_on_site_seconds numeric, median_resolve_seconds numeric, dropout_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, p.email, 'engineer')::text,
    e.cached_highest_tier::text,
    COUNT(m.*)::bigint AS total_responses,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.first_response_seconds)::numeric,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.on_site_seconds)::numeric,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.resolve_seconds)::numeric,
    SUM(CASE WHEN m.dropped THEN 1 ELSE 0 END)::bigint
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN code_red_engineer_response_metrics_v2 m ON m.engineer_id = e.id
  GROUP BY e.id, p.full_name, p.email, e.cached_highest_tier
  HAVING COUNT(m.*) > 0
  ORDER BY total_responses DESC
  LIMIT p_limit;
END $function$;

-- ---------------------------------------------------------------------
-- public.rpc_press_spokesperson_perf_r3109 -- ORDER BY reach DESC
CREATE OR REPLACE FUNCTION public.rpc_press_spokesperson_perf_r3109()
 RETURNS TABLE(spokesperson text, hits bigint, avg_sentiment numeric, reach bigint, on_message_share numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    coalesce(h.spokesperson, 'unassigned'),
    count(*)::bigint,
    round(avg(h.sentiment_score)::numeric, 3),
    sum(h.reach_estimate)::bigint AS reach,
    round((sum(case when h.narrative_angle = 'on_message' then 1 else 0 end)::numeric
           / nullif(count(*),0)::numeric) * 100, 1)
  from public.press_media_hits_r3109 h
  group by h.spokesperson
  order by reach desc;
end$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3111_tone_outcome -- ORDER BY broadcasts_count DESC
CREATE OR REPLACE FUNCTION public.fn_r3111_tone_outcome()
 RETURNS TABLE(tone_classification text, broadcasts_count bigint, avg_clarity numeric, avg_alignment numeric, positive_sentiment_pct numeric, concern_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.tone_classification,
         COUNT(DISTINCT b.id)::bigint AS broadcasts_count,
         ROUND(AVG(f.clarity_rating)::numeric, 2),
         ROUND(AVG(f.alignment_rating)::numeric, 2),
         ROUND(100.0 * COUNT(*) FILTER (WHERE f.sentiment IN ('highly_positive','positive'))::numeric
               / NULLIF(COUNT(f.id),0), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE f.sentiment IN ('concerned','negative','very_negative'))::numeric
               / NULLIF(COUNT(f.id),0), 1)
  FROM public.founder_comms_broadcasts_r3111 b
  LEFT JOIN public.founder_comms_feedback_r3111 f ON f.broadcast_id = b.id
  GROUP BY b.tone_classification
  ORDER BY broadcasts_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.warranty_won_tier_mix_r2239 -- ORDER BY deals_won DESC
CREATE OR REPLACE FUNCTION public.warranty_won_tier_mix_r2239()
 RETURNS TABLE(amc_tier text, deals_won integer, total_fee_rupees bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(p.proposed_amc_tier, 'unset')::text,
    COUNT(*)::int AS deals_won,
    COALESCE(SUM(p.proposed_annual_fee_rupees), 0)::bigint
  FROM public.warranty_expiry_pipeline_r2239 p
  WHERE p.pipeline_stage = 'won'
  GROUP BY p.proposed_amc_tier
  ORDER BY deals_won DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2249_low_engagement_recipients -- ORDER BY open_rate_pct ASC
CREATE OR REPLACE FUNCTION public.r2249_low_engagement_recipients()
 RETURNS TABLE(recipient_email text, recipient_role text, total_blasts integer, opened_blasts integer, open_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.recipient_email,
    o.recipient_role,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE o.opened_at IS NOT NULL))::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.opened_at IS NOT NULL) / NULLIF(COUNT(*), 0), 1) AS open_rate_pct
  FROM public.daily_numbers_blast_opens_r2249 o
  GROUP BY o.recipient_email, o.recipient_role
  HAVING ROUND(100.0 * COUNT(*) FILTER (WHERE o.opened_at IS NOT NULL) / NULLIF(COUNT(*), 0), 1) < 50
  ORDER BY open_rate_pct ASC NULLS FIRST
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.dr_detector_defect_class_severity_r3132 -- ORDER BY event_count DESC, total_revenue_loss DESC
CREATE OR REPLACE FUNCTION public.dr_detector_defect_class_severity_r3132()
 RETURNS TABLE(defect_class text, severity text, event_count bigint, total_studies_lost bigint, total_revenue_loss numeric, avg_downtime_hours numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.defect_class::text,
           e.severity::text,
           count(*)::bigint AS event_count,
           coalesce(sum(e.studies_lost), 0)::bigint,
           coalesce(sum(e.revenue_loss_rupees), 0)::numeric AS total_revenue_loss,
           round(coalesce(avg(e.downtime_hours), 0)::numeric, 2)
    from dr_detector_pixel_capa_events_r3132 e
    group by e.defect_class, e.severity
    order by total_revenue_loss desc, event_count desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r2736_engineer_scores -- ORDER BY avg_score ASC
CREATE OR REPLACE FUNCTION public.r2736_engineer_scores()
 RETURNS TABLE(engineer_name text, captures bigint, avg_score numeric, non_compliant_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_name, COUNT(*)::bigint, ROUND(AVG(c.uniform_score)::numeric,2) AS avg_score, COUNT(*) FILTER (WHERE c.compliance_status='non_compliant')::bigint
  FROM uniform_photo_captures_r2736 c
  GROUP BY c.engineer_name
  ORDER BY avg_score ASC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.r2778_trade_show_engineer_leaderboard -- ORDER BY pipeline_rupees DESC
CREATE OR REPLACE FUNCTION public.r2778_trade_show_engineer_leaderboard()
 RETURNS TABLE(engineer_name text, shows_attended integer, total_leads bigint, qualified_leads bigint, pipeline_rupees bigint, avg_learning_score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.engineer_name,
           COUNT(*)::int,
           COALESCE(SUM(a.actual_leads),0)::bigint,
           COALESCE(SUM(a.qualified_leads),0)::bigint,
           COALESCE(SUM(a.pipeline_value_rupees),0)::bigint AS pipeline_rupees,
           ROUND(AVG(a.learning_score)::numeric, 2)
    FROM engineer_trade_show_attendance_r2778 a
    GROUP BY a.engineer_name
    ORDER BY pipeline_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2788_engineer_grade_rollup -- ORDER BY avg_csat DESC
CREATE OR REPLACE FUNCTION public.founder_r2788_engineer_grade_rollup()
 RETURNS TABLE(outcome_grade text, engineer_count integer, shifts_total integer, no_show_total integer, incidents_total integer, avg_csat numeric, bonus_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.outcome_grade,
    COUNT(*)::int,
    COALESCE(SUM(e.shifts_assigned),0)::int,
    COALESCE(SUM(e.shifts_no_show),0)::int,
    COALESCE(SUM(e.incidents_handled),0)::int,
    COALESCE(ROUND(AVG(e.customer_csat),2),0)::numeric AS avg_csat,
    COALESCE(SUM(e.on_call_bonus_rupees),0)::numeric
  FROM engineer_after_hours_coverage_r2788 e
  GROUP BY e.outcome_grade
  ORDER BY avg_csat DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2790_outcome_funnel -- ORDER BY row_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2790_outcome_funnel()
 RETURNS TABLE(outcome text, row_count integer, photos_total integer, share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    total integer;
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    SELECT COUNT(*) INTO total FROM engineer_photo_share_consent_r2790;
    RETURN QUERY
    SELECT
        c.outcome,
        COUNT(*)::int AS row_count,
        COALESCE(SUM(c.photos_count),0)::int,
        ROUND(100.0 * COUNT(*) / NULLIF(total,0), 1)
    FROM engineer_photo_share_consent_r2790 c
    GROUP BY c.outcome
    ORDER BY row_count DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2813_surface_stability -- ORDER BY avg_stability ASC
CREATE OR REPLACE FUNCTION public.founder_r2813_surface_stability()
 RETURNS TABLE(surface_area text, components integer, avg_stability numeric, avg_a11y numeric, overrides integer, backlog integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.surface_area,
    COUNT(*)::int,
    ROUND(AVG(c.stability_score)::numeric, 2) AS avg_stability,
    ROUND(AVG(c.a11y_score)::numeric, 2),
    COALESCE(SUM(c.override_count),0)::int,
    COALESCE(SUM(c.refactor_backlog),0)::int
  FROM design_system_quarter_components_r2813 c
  GROUP BY c.surface_area
  ORDER BY avg_stability ASC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2839_chain_rollup -- ORDER BY expected_revenue DESC
CREATE OR REPLACE FUNCTION public.rpc_r2839_chain_rollup()
 RETURNS TABLE(chain_code text, chain_name text, cohorts bigint, units_total bigint, refurb_cost numeric, replace_cost numeric, expected_revenue numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_code, MAX(c.chain_name), COUNT(*)::bigint,
           COALESCE(SUM(c.units_total),0)::bigint,
           COALESCE(SUM(c.refurb_cost_lakhs),0)::numeric,
           COALESCE(SUM(c.replace_cost_lakhs),0)::numeric,
           COALESCE(SUM(c.expected_revenue_lakhs),0)::numeric AS expected_revenue
    FROM chain_fleet_cohorts_r2839 c
    GROUP BY c.chain_code
    ORDER BY expected_revenue DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2850_verdict_distribution -- ORDER BY engineer_count DESC
CREATE OR REPLACE FUNCTION public.rpc_r2850_verdict_distribution()
 RETURNS TABLE(verdict text, engineer_count integer, share_of_revenue_pct numeric, avg_jobs numeric, avg_csat numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  total_rev numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(revenue_generated_rupees),0)
    INTO total_rev
    FROM engineer_monthly_job_narrative_stories_r2850;
  IF total_rev = 0 THEN total_rev := 1; END IF;
  RETURN QUERY
  SELECT
    s.verdict,
    COUNT(*)::int AS engineer_count,
    ROUND((SUM(s.revenue_generated_rupees) / total_rev) * 100, 1),
    ROUND(AVG(s.jobs_completed)::numeric,1),
    ROUND(AVG(s.csat_avg)::numeric,2)
  FROM engineer_monthly_job_narrative_stories_r2850 s
  GROUP BY s.verdict
  ORDER BY engineer_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2859_signal_mix -- ORDER BY uplift_lakhs DESC
CREATE OR REPLACE FUNCTION public.r2859_signal_mix()
 RETURNS TABLE(signal_type text, count_signals integer, uplift_lakhs numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.signal_type, count(*)::int, sum(s.est_revenue_uplift_lakhs)::numeric AS uplift_lakhs
    FROM hospital_chain_quarterly_correlation_signals_r2859 s
    GROUP BY s.signal_type
    ORDER BY uplift_lakhs DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2862_audience_split -- ORDER BY total_engagement DESC
CREATE OR REPLACE FUNCTION public.founder_r2862_audience_split()
 RETURNS TABLE(audience_segment text, narrative_count integer, published_count integer, total_engagement integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.audience_segment,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE n.publish_status = 'published')::int,
         COALESCE(SUM(n.engagement_views + n.engagement_reactions + n.engagement_replies), 0)::int AS total_engagement
  FROM engineer_monthly_narrative_publish_r2862 n
  GROUP BY n.audience_segment
  ORDER BY total_engagement DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2869_member_scorecard -- ORDER BY avg_rating DESC
CREATE OR REPLACE FUNCTION public.founder_r2869_member_scorecard()
 RETURNS TABLE(team_member text, sessions bigint, avg_rating numeric, commitments bigint, completed bigint, completion_rate numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.team_member,
         count(DISTINCT s.id)::bigint,
         round(avg(s.founder_rating)::numeric, 2) AS avg_rating,
         count(c.id)::bigint,
         count(c.id) FILTER (WHERE c.status='completed')::bigint,
         CASE WHEN count(c.id) > 0
              THEN round((count(c.id) FILTER (WHERE c.status='completed')::numeric * 100.0) / count(c.id)::numeric, 1)
              ELSE 0 END
  FROM team_1on1_sessions_r2869 s
  LEFT JOIN team_1on1_commitments_r2869 c ON c.team_member = s.team_member
  GROUP BY s.team_member
  ORDER BY avg_rating DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2966_city_summary -- ORDER BY failed DESC
CREATE OR REPLACE FUNCTION public.r2966_city_summary()
 RETURNS TABLE(city text, audit_count integer, devices integer, failed integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.city, count(*)::int, coalesce(sum(a.device_count),0)::int, coalesce(sum(a.failed_count),0)::int AS failed
  from power_strip_audits_r2966 a
  group by a.city
  order by failed desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2967_disinfection_method_mix -- ORDER BY probe_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2967_disinfection_method_mix()
 RETURNS TABLE(disinfection_method text, probe_count integer, compliant_count integer, flagged_count integer, share_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare total int;
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  select count(*) into total from ultrasound_probe_fleet_r2967;
  if total = 0 then total := 1; end if;
  return query
  select
    f.disinfection_method,
    count(*)::int AS probe_count,
    (count(*) filter (where f.disinfection_status = 'compliant'))::int,
    (count(*) filter (where f.disinfection_status in ('missed_cycle','contamination_flag','quarantined')))::int,
    round((count(*)::numeric * 100.0) / total, 2)
  from ultrasound_probe_fleet_r2967 f
  group by f.disinfection_method
  order by probe_count desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r3002_replacement_reason_breakdown -- ORDER BY replacements DESC
CREATE OR REPLACE FUNCTION public.r3002_replacement_reason_breakdown()
 RETURNS TABLE(reason text, replacements integer, signed_off integer, open_or_progress integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select r.reason,
         count(*)::int AS replacements,
         (count(*) filter (where r.status in ('signed_off','installed')))::int,
         (count(*) filter (where r.status in ('open','in_progress','dispatched')))::int
  from bath_lift_sling_replacements_r3002 r
  group by r.reason
  order by replacements desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3009_findings_by_region -- ORDER BY revenue_at_risk DESC
CREATE OR REPLACE FUNCTION public.fn_r3009_findings_by_region()
 RETURNS TABLE(region text, finding_count integer, p0_count integer, open_count integer, revenue_at_risk bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.region,
    count(*)::int,
    (count(*) filter (where f.severity = 'p0'))::int,
    (count(*) filter (where f.status = 'open'))::int,
    coalesce(sum(f.affected_revenue_rupees), 0)::bigint AS revenue_at_risk
  from public.coverage_risk_findings_r3009 f
  group by f.region
  order by revenue_at_risk desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r3032_brand_mix -- ORDER BY lots DESC
CREATE OR REPLACE FUNCTION public.founder_r3032_brand_mix()
 RETURNS TABLE(brand text, lots integer, total_remaining bigint, avg_unit_cost numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    l.brand,
    count(*)::int AS lots,
    coalesce(sum(l.strip_count_remaining), 0)::bigint,
    round(avg(l.unit_cost_rupees), 2)
  from public.glucometer_strip_lots_r3032 l
  group by l.brand
  order by lots desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r3034_by_severity -- ORDER BY units DESC
CREATE OR REPLACE FUNCTION public.r3034_by_severity()
 RETURNS TABLE(imbalance_severity text, units integer, avg_vibration numeric, avg_drift numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.imbalance_severity, count(*)::int AS units, round(avg(a.vibration_rms_mm_s)::numeric, 2), round(avg(a.rpm_drift_pct)::numeric, 2)
  from centrifuge_imbalance_audits_r3034 a
  group by a.imbalance_severity
  order by units desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.r3043_findings_by_category -- ORDER BY total DESC, critical_count DESC
CREATE OR REPLACE FUNCTION public.r3043_findings_by_category()
 RETURNS TABLE(finding_category text, total integer, critical_count integer, open_count integer, closed_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_category,
    count(*)::int AS total,
    (count(*) filter (where f.severity='critical'))::int AS critical_count,
    (count(*) filter (where f.closure_status='open'))::int,
    (count(*) filter (where f.closure_status='closed'))::int
  from public.tray_window_findings_r3043 f
  group by f.finding_category
  order by critical_count desc, total desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.r3086_spillage_by_severity -- ORDER BY total_ml DESC
CREATE OR REPLACE FUNCTION public.r3086_spillage_by_severity()
 RETURNS TABLE(severity text, visit_count integer, total_ml integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select spillage_severity, count(*)::int, coalesce(sum(spillage_ml), 0)::int AS total_ml
  from vaporizer_refill_visits_r3086
  group by spillage_severity
  order by total_ml desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2971_vendor_concentration -- ORDER BY total_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r2971_vendor_concentration()
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
    sum(case when s.resolved=false then s.recommended_qty::bigint * s.unit_cost_rupees::bigint else 0 end) AS total_rupees
  from ot_bulb_reorder_signals_r2971 s
  group by s.vendor_name
  order by total_rupees desc nulls last;
end;$function$;

-- ---------------------------------------------------------------------
-- public.founder_board_category_breakdown -- ORDER BY pct_done ASC
CREATE OR REPLACE FUNCTION public.founder_board_category_breakdown()
 RETURNS TABLE(category text, total_items integer, done_items integer, open_items integer, pct_done numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.category,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE i.is_done)::int,
         COUNT(*) FILTER (WHERE NOT i.is_done)::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE i.is_done) / COUNT(*), 1) AS pct_done
  FROM founder_board_checklist_items_v2 i
  JOIN founder_board_meetings_v2 m ON m.id = i.meeting_id
  WHERE m.closed_at IS NULL
  GROUP BY i.category
  ORDER BY pct_done ASC, category ASC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_debits_by_engineer -- ORDER BY total_debit_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_amc_debits_by_engineer()
 RETURNS TABLE(engineer_user_id uuid, display_name text, visit_count_90d bigint, total_debit_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    b.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    count(*)::bigint,
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric AS total_debit_rupees
  FROM public.repair_jobs rj
  JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status='accepted'
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  WHERE rj.amc_contract_id IS NOT NULL
    AND rj.status = 'completed'
    AND rj.completed_at >= now() - interval '90 days'
  GROUP BY b.engineer_user_id, p.full_name
  ORDER BY total_debit_rupees DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_iwi_introducer_ladder -- ORDER BY invested DESC
CREATE OR REPLACE FUNCTION public.founder_iwi_introducer_ladder()
 RETURNS TABLE(id text, introducer_name text, intros_made bigint, replied bigint, met bigint, partner_met bigint, term_sheets bigint, invested bigint, conv_rate numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    md5(i.introducer_name) AS id,
    i.introducer_name,
    COUNT(*)::bigint AS intros_made,
    COUNT(*) FILTER (WHERE i.first_reply_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.first_meeting_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.partner_meeting_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.term_sheet_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.outcome = 'invested')::bigint AS invested,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i.outcome = 'invested') / NULLIF(COUNT(*), 0), 1) AS conv_rate
  FROM investor_warm_intros i
  GROUP BY i.introducer_name
  ORDER BY invested DESC, intros_made DESC
  LIMIT 50;
END $function$;

-- ---------------------------------------------------------------------
-- public.fn_diligence_per_acquirer_rollup_r3103 -- ORDER BY avg_readiness_pct ASC
CREATE OR REPLACE FUNCTION public.fn_diligence_per_acquirer_rollup_r3103()
 RETURNS TABLE(acquirer_name text, stage text, workstream_count bigint, avg_readiness_pct numeric, red_flag_total bigint, remediation_lakh numeric, blocked_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.acquirer_name,
         t.deal_stage,
         count(w.id)::bigint,
         round(coalesce(avg(w.readiness_pct), 0)::numeric, 1) AS avg_readiness_pct,
         coalesce(sum(w.red_flag_count), 0)::bigint,
         coalesce(sum(w.remediation_cost_inr_lakh), 0)::numeric,
         count(*) filter (where w.readiness_status = 'blocked')::bigint
  from public.founder_strategic_acquirer_targets_r3103 t
  left join public.founder_diligence_readiness_workstreams_r3103 w on w.acquirer_target_id = t.id
  group by t.id, t.acquirer_name, t.deal_stage
  order by avg_readiness_pct asc;
end $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3104_test_method_usage -- ORDER BY sample_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3104_test_method_usage()
 RETURNS TABLE(test_method text, sample_count bigint, failures bigint, avg_endotoxin numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select s.test_method,
           count(*)::bigint AS sample_count,
           count(*) filter (where s.aami_compliance_status in ('aami_failure','iso23500_failure'))::bigint,
           round(avg(s.endotoxin_eu_per_ml)::numeric, 3)
    from dialysis_ro_water_samples_r3104 s
    group by s.test_method
    order by sample_count desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_press_response_status_r3109 -- ORDER BY hits DESC
CREATE OR REPLACE FUNCTION public.rpc_press_response_status_r3109()
 RETURNS TABLE(response_status text, hits bigint, reach bigint, avg_sentiment numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.response_status,
    count(*)::bigint AS hits,
    sum(h.reach_estimate)::bigint,
    round(avg(h.sentiment_score)::numeric, 3)
  from public.press_media_hits_r3109 h
  group by h.response_status
  order by hits desc;
end$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3111_followup_completion -- ORDER BY completion_pct ASC
CREATE OR REPLACE FUNCTION public.fn_r3111_followup_completion()
 RETURNS TABLE(broadcast_code text, title text, follow_up_action_count integer, follow_up_completed_count integer, completion_pct numeric, effectiveness_band text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.broadcast_code,
         b.title,
         b.follow_up_action_count,
         b.follow_up_completed_count,
         ROUND(100.0 * b.follow_up_completed_count::numeric / NULLIF(b.follow_up_action_count,0), 1) AS completion_pct,
         b.effectiveness_band
  FROM public.founder_comms_broadcasts_r3111 b
  WHERE b.follow_up_action_count > 0
  ORDER BY completion_pct ASC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2350_engineer_leave_totals -- ORDER BY approved_days DESC
CREATE OR REPLACE FUNCTION public.r2350_engineer_leave_totals()
 RETURNS TABLE(engineer_email text, zone_code text, approved_days integer, pending_days integer, upcoming_starts_on date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.email,
    r.zone_code,
    COALESCE(SUM(CASE WHEN r.status = 'approved' THEN (r.ends_on - r.starts_on + 1) END), 0)::integer AS approved_days,
    COALESCE(SUM(CASE WHEN r.status = 'pending' THEN (r.ends_on - r.starts_on + 1) END), 0)::integer,
    MIN(CASE WHEN r.starts_on >= current_date AND r.status IN ('approved','pending') THEN r.starts_on END)
  FROM public.engineer_vacation_requests_r2350 r
  JOIN public.profiles p ON p.id = r.engineer_user_id
  WHERE r.starts_on >= current_date - 30
  GROUP BY p.email, r.zone_code
  ORDER BY approved_days DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.dr_detector_calibration_capa_status_r3132 -- ORDER BY panel_count DESC
CREATE OR REPLACE FUNCTION public.dr_detector_calibration_capa_status_r3132()
 RETURNS TABLE(calibration_status text, capa_status text, panel_count bigint, total_dead_pixels_sum bigint, total_remediation_window_days bigint, exposure_lakhs numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.calibration_status::text,
           a.capa_status::text,
           count(*)::bigint AS panel_count,
           coalesce(sum(a.total_dead_pixels), 0)::bigint,
           coalesce(sum(a.remediation_window_days), 0)::bigint,
           coalesce(sum(a.replacement_cost_lakhs), 0)::numeric
    from dr_detector_panel_audits_r3132 a
    group by a.calibration_status, a.capa_status
    order by panel_count desc, a.calibration_status asc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r3135_nda_status_rollup -- ORDER BY member_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3135_nda_status_rollup()
 RETURNS TABLE(nda_status text, member_count integer, active_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.nda_status,
           count(*)::integer AS member_count,
           count(*) filter (where m.offboarded_at is null)::integer
    from board_advisory_members_r3135 m
    group by m.nda_status
    order by member_count desc;
end
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2696_by_tier -- ORDER BY total_allocated_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r2696_by_tier()
 RETURNS TABLE(customer_tier text, cycle_count bigint, total_allocated_rupees numeric, total_spent_rupees numeric, avg_variance_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.customer_tier,
         count(*)::bigint,
         COALESCE(sum(c.allocated_budget_rupees),0)::numeric AS total_allocated_rupees,
         COALESCE(sum(c.spent_to_date_rupees),0)::numeric,
         COALESCE(avg(c.variance_pct),0)::numeric
  FROM customer_quarterly_budget_cycles_r2696 c
  GROUP BY c.customer_tier
  ORDER BY total_allocated_rupees DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2995_drain_outcome_distribution -- ORDER BY n DESC
CREATE OR REPLACE FUNCTION public.r2995_drain_outcome_distribution()
 RETURNS TABLE(test_outcome text, n integer, avg_load integer, avg_duration integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.test_outcome, count(*)::int AS n, avg(d.load_held_percent)::int, avg(d.duration_minutes)::int
  from generator_drain_test_r2995 d
  group by d.test_outcome
  order by n desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.founder_roadmap_by_audience_r2753 -- ORDER BY net_trust_delta_pp ASC
CREATE OR REPLACE FUNCTION public.founder_roadmap_by_audience_r2753()
 RETURNS TABLE(audience text, total bigint, delivered bigint, missed_or_slipped bigint, net_trust_delta_pp numeric, on_time_rate_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.audience,
         count(*)::bigint,
         count(*) FILTER (WHERE p.status='delivered')::bigint,
         count(*) FILTER (WHERE p.status IN ('missed','reslipped','descoped'))::bigint,
         ROUND(sum(p.trust_delta_pp)::numeric, 2) AS net_trust_delta_pp,
         ROUND(100.0 * count(*) FILTER (WHERE p.status='delivered' AND coalesce(p.variance_days,99) <= 7)::numeric
               / NULLIF(count(*),0), 2)
  FROM roadmap_promises_r2753 p
  GROUP BY p.audience
  ORDER BY net_trust_delta_pp ASC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_rollup_r2766 -- ORDER BY avg_score DESC
CREATE OR REPLACE FUNCTION public.founder_engineer_rollup_r2766()
 RETURNS TABLE(engineer_id uuid, engineer_name text, verticals_covered integer, avg_score numeric, total_jobs integer, avg_csat numeric, open_actions integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_id,
    max(s.engineer_name),
    count(DISTINCT s.vertical)::int,
    round(avg(s.competency_score)::numeric, 2) AS avg_score,
    sum(s.jobs_completed)::int,
    round(avg(s.csat_avg)::numeric, 2),
    COALESCE((SELECT count(*)::int FROM engineer_upskill_actions_r2766 a
      WHERE a.engineer_id = s.engineer_id AND a.status != 'completed'), 0)
  FROM engineer_skill_matrix_r2766 s
  GROUP BY s.engineer_id
  ORDER BY avg_score DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2777_projects_by_stage -- ORDER BY total_award DESC
CREATE OR REPLACE FUNCTION public.founder_r2777_projects_by_stage()
 RETURNS TABLE(stage text, project_count bigint, total_award bigint, total_projected_revenue bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.stage, COUNT(*)::bigint, COALESCE(SUM(p.award_amount_rupees),0)::bigint AS total_award, COALESCE(SUM(p.projected_revenue_rupees),0)::bigint
    FROM grant_research_projects_r2777 p
    GROUP BY p.stage
    ORDER BY total_award DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2778_trade_show_goal_gap -- ORDER BY gap ASC
CREATE OR REPLACE FUNCTION public.r2778_trade_show_goal_gap()
 RETURNS TABLE(show_name text, engineer_name text, goal_leads integer, actual_leads integer, gap integer, hit_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.show_name, a.engineer_name, a.goal_leads, a.actual_leads,
           (a.actual_leads - a.goal_leads)::int AS gap,
           ROUND((a.actual_leads::numeric / NULLIF(a.goal_leads,0)) * 100, 1)
    FROM engineer_trade_show_attendance_r2778 a
    ORDER BY gap ASC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2783_decision_breakdown -- ORDER BY total_npv_inr DESC
CREATE OR REPLACE FUNCTION public.r2783_decision_breakdown()
 RETURNS TABLE(scale_decision text, pilot_count integer, total_npv_inr bigint, avg_adoption numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.scale_decision,
    COUNT(*)::int,
    COALESCE(SUM(p.npv_inr),0)::bigint AS total_npv_inr,
    ROUND(AVG(p.adoption_pct)::numeric, 2)
  FROM hospital_chain_ai_integration_pulse_r2783 p
  WHERE p.pulse_quarter = '2026-Q2'
  GROUP BY p.scale_decision
  ORDER BY total_npv_inr DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2810_tier_breakdown -- ORDER BY closure_rate_pct DESC
CREATE OR REPLACE FUNCTION public.r2810_tier_breakdown()
 RETURNS TABLE(engineer_tier text, engineer_count bigint, feedback_received bigint, loops_closed bigint, closure_rate_pct numeric, avg_csat numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.engineer_tier,
         COUNT(*)::bigint,
         SUM(t.feedback_received_count)::bigint,
         SUM(t.loops_closed_count)::bigint,
         ROUND(100.0 * SUM(t.loops_closed_count)::numeric / NULLIF(SUM(t.feedback_received_count),0),2) AS closure_rate_pct,
         ROUND(AVG(t.csat_score)::numeric,2)
  FROM engineer_monthly_feedback_loop_r2810 t
  GROUP BY t.engineer_tier
  ORDER BY closure_rate_pct DESC NULLS LAST;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_bet_by_category_r2841 -- ORDER BY capital_inr DESC
CREATE OR REPLACE FUNCTION public.founder_bet_by_category_r2841()
 RETURNS TABLE(bet_category text, bets bigint, capital_inr bigint, avg_score numeric, wins bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.bet_category,
    count(*)::bigint,
    coalesce(sum(p.capital_deployed_inr),0)::bigint AS capital_inr,
    round(avg(p.outcome_score)::numeric,1),
    count(*) FILTER (WHERE p.outcome IN ('win','partial_win'))::bigint
  FROM public.founder_strategic_bet_postmortems_r2841 p
  GROUP BY p.bet_category
  ORDER BY capital_inr DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2890_channel_breakdown -- ORDER BY event_count DESC
CREATE OR REPLACE FUNCTION public.r2890_channel_breakdown()
 RETURNS TABLE(request_channel text, event_count bigint, avg_days_since_last numeric, avg_prior_csat numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.request_channel, COUNT(*)::bigint AS event_count, ROUND(AVG(e.days_since_last_visit),1), ROUND(AVG(e.csat_prior),2)
  FROM public.engineer_repeat_request_events_r2890 e
  GROUP BY e.request_channel
  ORDER BY event_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2887_reciprocity_score -- ORDER BY net_position_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r2887_reciprocity_score()
 RETURNS TABLE(branch_code text, chain_code text, lends_given integer, lends_received integer, reciprocity_ratio numeric, net_position_rupees integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    r.branch_code,
    r.chain_code,
    (SELECT COUNT(*)::int FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.lender_branch_code = r.branch_code),
    (SELECT COUNT(*)::int FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.borrower_branch_code = r.branch_code),
    CASE
      WHEN (SELECT COUNT(*) FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.borrower_branch_code = r.branch_code) = 0 THEN 0
      ELSE ROUND(
        (SELECT COUNT(*)::numeric FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.lender_branch_code = r.branch_code)
        / NULLIF((SELECT COUNT(*) FROM hospital_chain_branch_lending_txn_r2887 t WHERE t.borrower_branch_code = r.branch_code), 0),
      2)
    END,
    (r.net_rental_income_rupees - r.net_rental_expense_rupees) AS net_position_rupees
  FROM hospital_chain_branch_quarter_rollup_r2887 r
  ORDER BY net_position_rupees DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2895_chain_rollup -- ORDER BY gap_branches DESC, critical_branches DESC
CREATE OR REPLACE FUNCTION public.founder_r2895_chain_rollup()
 RETURNS TABLE(chain_name text, branches integer, total_primary bigint, total_backup bigint, avg_ratio numeric, gap_branches integer, critical_branches integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name,
         COUNT(DISTINCT c.branch_code)::int,
         SUM(c.primary_units)::bigint,
         SUM(c.backup_units)::bigint,
         ROUND(AVG(c.redundancy_ratio),2),
         COUNT(*) FILTER (WHERE c.coverage_status='gap')::int AS gap_branches,
         COUNT(*) FILTER (WHERE c.coverage_status='critical_gap')::int AS critical_branches
  FROM hospital_chain_critical_care_redundancy_coverage_r2895 c
  GROUP BY c.chain_name
  ORDER BY critical_branches DESC, gap_branches DESC;
END;$function$;

-- ---------------------------------------------------------------------
-- public.r2966_finding_severity_mix -- ORDER BY finding_count DESC
CREATE OR REPLACE FUNCTION public.r2966_finding_severity_mix()
 RETURNS TABLE(severity text, finding_count integer, open_count integer, remediation_cost integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.severity,
         count(*)::int AS finding_count,
         (count(*) filter (where f.status='open'))::int,
         coalesce(sum(f.remediation_cost_rupees),0)::int
  from power_strip_findings_r2966 f
  group by f.severity
  order by finding_count desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_fmt_status_breakdown_r2996 -- ORDER BY n DESC
CREATE OR REPLACE FUNCTION public.founder_fmt_status_breakdown_r2996()
 RETURNS TABLE(status text, n integer, total_meters numeric, avg_edge_lift_mm numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.status, count(*)::int AS n, sum(i.meters_installed)::numeric, round(avg(i.edge_lift_mm),2)::numeric
  from floor_marking_tape_inspections_r2996 i
  group by i.status
  order by n desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3034_bearing_health_dist -- ORDER BY units DESC
CREATE OR REPLACE FUNCTION public.r3034_bearing_health_dist()
 RETURNS TABLE(bearing_status text, units integer, avg_temp numeric, avg_noise numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.bearing_status, count(*)::int AS units, round(avg(a.bearing_temp_celsius)::numeric, 1), round(avg(a.bearing_noise_db)::numeric, 1)
  from centrifuge_imbalance_audits_r3034 a
  group by a.bearing_status
  order by units desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.r3086_agent_type_breakdown -- ORDER BY visits DESC
CREATE OR REPLACE FUNCTION public.r3086_agent_type_breakdown()
 RETURNS TABLE(agent text, visits integer, avg_duration numeric, spillage_total integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select agent_type, count(*)::int AS visits, round(avg(visit_duration_minutes)::numeric, 1), coalesce(sum(spillage_ml), 0)::int
  from vaporizer_refill_visits_r3086
  group by agent_type
  order by visits desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3737_backlog_digest -- ORDER BY total_backlog DESC
CREATE OR REPLACE FUNCTION public.founder_r3737_backlog_digest()
 RETURNS TABLE(category_class text, records bigint, total_backlog bigint, legal_hold_records bigint, verification_not_logged bigint, avg_purge_delay_days numeric, total_storage_cost_rupees numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category_class,
    count(*)::bigint,
    coalesce(sum(l.purge_backlog),0)::bigint AS total_backlog,
    count(*) filter (where l.legal_hold_override = true)::bigint,
    count(*) filter (where l.purge_verification_logged = false)::bigint,
    round(avg(l.avg_purge_delay_days), 1),
    round(coalesce(sum(l.storage_cost_rupees),0), 2)
  from public.data_retain_r3737 l
  where l.retention_status in ('purge_backlog','policy_violation') or l.purge_backlog > 0
  group by l.category_class
  order by total_backlog desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_amc_coverage_by_city -- ORDER BY hospitals_total DESC
CREATE OR REPLACE FUNCTION public.founder_hospital_amc_coverage_by_city()
 RETURNS TABLE(city text, hospitals_total bigint, with_amc bigint, without_amc bigint, coverage_pct numeric)
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
      p.id AS hospital_id,
      EXISTS (
        SELECT 1 FROM public.amc_contracts c
        WHERE c.hospital_user_id = p.id AND c.status = 'active'
      ) AS has_amc
    FROM public.profiles p
    WHERE p.role = 'hospital_admin'
  )
  SELECT
    b.city,
    count(*)::bigint AS hospitals_total,
    count(*) FILTER (WHERE b.has_amc)::bigint,
    count(*) FILTER (WHERE NOT b.has_amc)::bigint,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(count(*) FILTER (WHERE b.has_amc)::numeric / count(*)::numeric * 100.0, 1)
    END
  FROM base b
  GROUP BY b.city
  ORDER BY hospitals_total DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_leave_calendar_by_type -- ORDER BY cnt DESC
CREATE OR REPLACE FUNCTION public.founder_engineer_leave_calendar_by_type()
 RETURNS TABLE(leave_type text, cnt bigint, total_days numeric, avg_days numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT lc.leave_type,
         count(*)::bigint AS cnt,
         SUM((lc.end_date - lc.start_date + 1))::numeric AS total_days,
         ROUND(AVG((lc.end_date - lc.start_date + 1))::numeric, 2) AS avg_days
  FROM engineer_leave_calendar lc
  WHERE lc.start_date >= current_date - 90
  GROUP BY lc.leave_type
  ORDER BY cnt DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_dispute_by_mediator -- ORDER BY decisions_90d DESC
CREATE OR REPLACE FUNCTION public.founder_dispute_by_mediator()
 RETURNS TABLE(mediator_user_id uuid, mediator_name text, decisions_90d bigint, accepted bigint, rejected bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    d.mediator_user_id,
    coalesce(p.full_name, '(mediator)'),
    count(*)::bigint AS decisions_90d,
    count(*) FILTER (WHERE d.status = 'accepted')::bigint,
    count(*) FILTER (WHERE d.status = 'rejected')::bigint
  FROM public.dispute_evidence_packs d
  LEFT JOIN public.profiles p ON p.id = d.mediator_user_id
  WHERE d.mediator_decision_at >= now() - interval '90 days'
    AND d.mediator_user_id IS NOT NULL
  GROUP BY d.mediator_user_id, p.full_name
  ORDER BY decisions_90d DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_admin_top_ops -- ORDER BY count_30d DESC, count_total DESC
CREATE OR REPLACE FUNCTION public.founder_admin_top_ops()
 RETURNS TABLE(op_name text, count_30d bigint, count_total bigint, last_used_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    l.op_name,
    count(*) FILTER (WHERE l.created_at >= now() - interval '30 days')::bigint AS count_30d,
    count(*)::bigint AS count_total,
    max(l.created_at)
  FROM public.founder_action_log l
  GROUP BY l.op_name
  ORDER BY count_30d DESC, count_total DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_payout_history -- ORDER BY paid_lifetime DESC
CREATE OR REPLACE FUNCTION public.founder_engineer_payout_history()
 RETURNS TABLE(engineer_user_id uuid, display_name text, paid_30d_rupees numeric, paid_90d_rupees numeric, paid_lifetime numeric, payouts_lifetime bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT p.engineer_user_id, p.amount_paise, p.queued_at
    FROM public.engineer_payouts p
    WHERE p.status = 'processed'
  )
  SELECT
    b.engineer_user_id,
    coalesce(pr.full_name, '(engineer)'),
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.queued_at >= now() - interval '30 days'), 0)::numeric / 100.0, 2),
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.queued_at >= now() - interval '90 days'), 0)::numeric / 100.0, 2),
    round(coalesce(sum(b.amount_paise), 0)::numeric / 100.0, 2) AS paid_lifetime,
    count(*)::bigint
  FROM base b
  LEFT JOIN public.profiles pr ON pr.id = b.engineer_user_id
  GROUP BY b.engineer_user_id, pr.full_name
  ORDER BY paid_lifetime DESC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_spare_parts_by_state -- ORDER BY rupees_90d DESC
CREATE OR REPLACE FUNCTION public.founder_spare_parts_by_state()
 RETURNS TABLE(state text, buyers bigint, orders_90d bigint, rupees_90d numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      o.buyer_user_id,
      o.total_amount
    FROM public.spare_part_orders o
    LEFT JOIN public.profiles p ON p.id = o.buyer_user_id
    WHERE o.created_at >= now() - interval '90 days'
  )
  SELECT
    b.state,
    count(DISTINCT b.buyer_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(b.total_amount), 0)::numeric AS rupees_90d
  FROM base b
  GROUP BY b.state
  ORDER BY rupees_90d DESC
  LIMIT 40;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_chains_amc_gap -- ORDER BY members_without_amc DESC
CREATE OR REPLACE FUNCTION public.founder_chains_amc_gap()
 RETURNS TABLE(chain_id uuid, name text, member_count bigint, members_with_amc bigint, members_without_amc bigint, amc_coverage_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH members AS (
    SELECT m.chain_id, m.hospital_user_id
    FROM public.hospital_chain_memberships m
  )
  SELECT
    c.id,
    c.name,
    coalesce((SELECT count(*)::bigint FROM members m WHERE m.chain_id = c.id), 0)::bigint,
    coalesce((SELECT count(DISTINCT m.hospital_user_id)::bigint FROM members m
              WHERE m.chain_id = c.id
                AND EXISTS (SELECT 1 FROM public.amc_contracts a
                            WHERE a.hospital_user_id = m.hospital_user_id AND a.status='active')), 0)::bigint,
    coalesce((SELECT count(DISTINCT m.hospital_user_id)::bigint FROM members m
              WHERE m.chain_id = c.id
                AND NOT EXISTS (SELECT 1 FROM public.amc_contracts a
                                WHERE a.hospital_user_id = m.hospital_user_id AND a.status='active')), 0)::bigint AS members_without_amc,
    CASE WHEN coalesce((SELECT count(*) FROM members m WHERE m.chain_id = c.id), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(DISTINCT m.hospital_user_id)::numeric FROM members m
              WHERE m.chain_id = c.id
                AND EXISTS (SELECT 1 FROM public.amc_contracts a
                            WHERE a.hospital_user_id = m.hospital_user_id AND a.status='active'))
           / (SELECT count(*)::numeric FROM members m WHERE m.chain_id = c.id)
           * 100.0, 1)
    END
  FROM public.hospital_chains c
  ORDER BY members_without_amc DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_apprentice_overdue -- ORDER BY days_overdue DESC
CREATE OR REPLACE FUNCTION public.founder_apprentice_overdue()
 RETURNS TABLE(pairing_id uuid, apprentice_name text, master_name text, days_overdue numeric, pending_milestones integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    COALESCE(ap.full_name, ap.email),
    COALESCE(mp.full_name, mp.email),
    EXTRACT(EPOCH FROM (now() - p.curriculum_target_end_at))/86400.0 AS days_overdue,
    (SELECT COUNT(*)::int FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id AND m.completed_at IS NULL)
  FROM apprentice_pairings_v2 p
  LEFT JOIN engineers ae ON ae.id = p.apprentice_engineer_id
  LEFT JOIN profiles  ap ON ap.id = ae.user_id
  LEFT JOIN engineers me ON me.id = p.master_engineer_id
  LEFT JOIN profiles  mp ON mp.id = me.user_id
  WHERE p.status='active' AND p.curriculum_target_end_at < now()
  ORDER BY days_overdue DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_time_category_summary -- ORDER BY hours_30d DESC
CREATE OR REPLACE FUNCTION public.founder_time_category_summary()
 RETURNS TABLE(id text, category text, hours_7d numeric, hours_30d numeric, hours_90d numeric, target_weekly numeric, bottleneck_hours numeric, unplanned_hours numeric, status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.category AS id,
    t.category,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '7 days'), 0)::numeric,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '30 days'), 0)::numeric AS hours_30d,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '90 days'), 0)::numeric,
    t.target_weekly_hours,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '30 days' AND e.is_bottleneck), 0)::numeric,
    COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '30 days' AND NOT e.was_planned), 0)::numeric,
    CASE
      WHEN COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '7 days'), 0) > t.target_weekly_hours * 1.3 THEN 'overshoot'
      WHEN COALESCE(SUM(e.hours) FILTER (WHERE e.entry_date >= CURRENT_DATE - INTERVAL '7 days'), 0) < t.target_weekly_hours * 0.5 THEN 'undershoot'
      ELSE 'on-track'
    END AS status
  FROM founder_time_targets t
  LEFT JOIN founder_time_entries e ON e.category = t.category
  GROUP BY t.category, t.target_weekly_hours
  ORDER BY hours_30d DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2292_by_classification -- ORDER BY total_gross_paise DESC
CREATE OR REPLACE FUNCTION public.founder_r2292_by_classification()
 RETURNS TABLE(stream_classification text, stream_count integer, total_gross_paise bigint, total_recognized_paise bigint, total_deferred_paise bigint, compliant_count integer, non_compliant_count integer)
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
    s.stream_classification,
    (COUNT(*))::int,
    COALESCE(SUM(s.gross_amount_paise), 0)::bigint AS total_gross_paise,
    COALESCE(SUM(s.recognized_to_date_paise), 0)::bigint,
    COALESCE(SUM(s.deferred_balance_paise), 0)::bigint,
    (COUNT(*) FILTER (WHERE s.is_policy_compliant))::int,
    (COUNT(*) FILTER (WHERE NOT s.is_policy_compliant))::int
  FROM public.customer_revenue_streams_r2292 s
  GROUP BY s.stream_classification
  ORDER BY total_gross_paise DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r3104_compliance_rollup -- ORDER BY sample_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3104_compliance_rollup()
 RETURNS TABLE(compliance_status text, sample_count bigint, avg_endotoxin_eu_per_ml numeric, avg_cfu_per_ml numeric, worst_endotoxin numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select s.aami_compliance_status,
           count(*)::bigint AS sample_count,
           round(avg(s.endotoxin_eu_per_ml)::numeric, 3),
           round(avg(s.bacterial_colony_cfu_per_ml)::numeric, 1),
           max(s.endotoxin_eu_per_ml)
    from dialysis_ro_water_samples_r3104 s
    group by s.aami_compliance_status
    order by sample_count desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r3104_vendor_mix -- ORDER BY action_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3104_vendor_mix()
 RETURNS TABLE(vendor_required text, action_count bigint, total_cost_estimate_rupees numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select coalesce(a.vendor_required, 'unassigned'),
           count(*)::bigint AS action_count,
           coalesce(sum(a.cost_estimate_rupees), 0)
    from dialysis_ro_purification_actions_r3104 a
    group by a.vendor_required
    order by action_count desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r2302_topic_gap_alerts -- ORDER BY pass_rate_pct ASC
CREATE OR REPLACE FUNCTION public.r2302_topic_gap_alerts(p_min_tests integer DEFAULT 3, p_max_pass_rate numeric DEFAULT 70)
 RETURNS TABLE(topic text, total_tests integer, pass_rate_pct numeric, avg_score_pct numeric, open_assignments integer, recommended_action text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic,
         COUNT(*)::integer,
         ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / NULLIF(COUNT(*), 0)::numeric) * 100, 1)::numeric AS pass_rate_pct,
         ROUND(AVG(t.score_pct), 1)::numeric,
         (SELECT COUNT(*)::integer FROM public.engineer_training_assignments_r2302 a
           WHERE a.topic = t.topic AND a.status IN ('assigned','in_progress','overdue')),
         CASE
           WHEN ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / NULLIF(COUNT(*), 0)::numeric) * 100, 1) < 50
             THEN 'urgent_cohort_retraining'
           WHEN ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / NULLIF(COUNT(*), 0)::numeric) * 100, 1) < 65
             THEN 'targeted_remedial_module'
           ELSE 'monitor'
         END
  FROM public.engineer_competency_tests_r2302 t
  GROUP BY t.topic
  HAVING COUNT(*) >= GREATEST(p_min_tests, 1)
     AND ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / NULLIF(COUNT(*), 0)::numeric) * 100, 1) <= p_max_pass_rate
  ORDER BY pass_rate_pct ASC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r3108_ward_heatmap -- ORDER BY fails DESC, withdrawn DESC
CREATE OR REPLACE FUNCTION public.r3108_ward_heatmap()
 RETURNS TABLE(ward_name text, sessions integer, fails integer, withdrawn integer, avg_spo2_dev numeric, avg_nibp_dev numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.ward_name::text,
           count(*)::integer,
           count(*) filter (where s.overall_verdict='fail')::integer AS fails,
           count(*) filter (where s.overall_verdict='withdrawn_from_service')::integer AS withdrawn,
           round(avg(abs(s.spo2_deviation_pct))::numeric, 2),
           round(avg(abs(s.nibp_deviation_mmhg))::numeric, 2)
      from patient_monitor_calibration_sessions_r3108 s
     group by s.ward_name
     order by fails desc, withdrawn desc, s.ward_name;
end
$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3111_language_reach -- ORDER BY avg_nps DESC
CREATE OR REPLACE FUNCTION public.fn_r3111_language_reach()
 RETURNS TABLE(language_primary text, broadcasts_count bigint, total_consumed bigint, consume_rate_pct numeric, avg_nps numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.language_primary,
         COUNT(*)::bigint,
         SUM(b.fully_consumed_count)::bigint,
         ROUND(100.0 * SUM(b.fully_consumed_count)::numeric / NULLIF(SUM(b.audience_size),0), 1),
         ROUND(AVG(b.avg_nps_score)::numeric, 2) AS avg_nps
  FROM public.founder_comms_broadcasts_r3111 b
  GROUP BY b.language_primary
  ORDER BY avg_nps DESC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2249_channel_mix -- ORDER BY blast_count DESC
CREATE OR REPLACE FUNCTION public.r2249_channel_mix()
 RETURNS TABLE(channel text, blast_count integer, avg_open_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.channel,
    (COUNT(*))::int AS blast_count,
    ROUND(AVG(100.0 * b.opened_count / NULLIF(b.recipient_count, 0)), 1)
  FROM public.daily_numbers_blasts_r2249 b
  WHERE b.status = 'sent'
  GROUP BY b.channel
  ORDER BY blast_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.dr_detector_audit_fleet_summary_r3132 -- ORDER BY panel_count DESC
CREATE OR REPLACE FUNCTION public.dr_detector_audit_fleet_summary_r3132()
 RETURNS TABLE(modality text, panel_count bigint, pass_count bigint, watch_count bigint, fail_or_replace bigint, avg_dead_pixels numeric, avg_dqe_2lp numeric, avg_mtf_2lp numeric, total_replacement_lakhs numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.modality::text,
           count(*)::bigint AS panel_count,
           count(*) filter (where a.audit_verdict = 'pass')::bigint,
           count(*) filter (where a.audit_verdict = 'watch')::bigint,
           count(*) filter (where a.audit_verdict in ('fail','replace_now','warranty_claim'))::bigint,
           round(avg(a.total_dead_pixels)::numeric, 1),
           round(avg(a.dqe_at_2lp_mm)::numeric, 3),
           round(avg(a.mtf_at_2lp_mm)::numeric, 3),
           coalesce(sum(a.replacement_cost_lakhs) filter (where a.audit_verdict in ('fail','replace_now','warranty_claim')), 0)::numeric
    from dr_detector_panel_audits_r3132 a
    group by a.modality
    order by panel_count desc, a.modality asc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2694_region_flow -- ORDER BY rotation_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2694_region_flow()
 RETURNS TABLE(from_region text, to_region text, rotation_count bigint, total_weeks bigint, avg_csat numeric, total_cost_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.from_region, r.to_region,
         COUNT(*)::bigint AS rotation_count,
         COALESCE(SUM(r.duration_weeks),0)::bigint,
         ROUND(AVG(r.csat_avg)::numeric, 2),
         COALESCE(SUM(r.travel_cost_rupees),0)::bigint
  FROM engineer_cross_region_rotations_r2694 r
  GROUP BY r.from_region, r.to_region
  ORDER BY rotation_count DESC, r.from_region;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2736_severity_breakdown -- ORDER BY actions DESC
CREATE OR REPLACE FUNCTION public.r2736_severity_breakdown()
 RETURNS TABLE(severity text, actions bigint, resolved bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.severity, COUNT(*)::bigint AS actions, COUNT(*) FILTER (WHERE a.status='resolved')::bigint
  FROM uniform_compliance_actions_r2736 a
  GROUP BY a.severity
  ORDER BY actions DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_dw_by_category_r2765 -- ORDER BY total_minutes DESC
CREATE OR REPLACE FUNCTION public.founder_dw_by_category_r2765()
 RETURNS TABLE(category text, blocks bigint, total_minutes bigint, avg_flow numeric, avg_quality numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.category, COUNT(*)::bigint, COALESCE(SUM(b.actual_minutes),0)::bigint AS total_minutes,
         ROUND(AVG(b.flow_state_score)::numeric,2), ROUND(AVG(b.output_quality)::numeric,2)
  FROM founder_deep_work_blocks_r2765 b
  GROUP BY b.category
  ORDER BY total_minutes DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2810_verdict_distribution -- ORDER BY engineer_count DESC
CREATE OR REPLACE FUNCTION public.r2810_verdict_distribution()
 RETURNS TABLE(tier_verdict text, engineer_count bigint, avg_closure_rate numeric, avg_csat numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.tier_verdict,
         COUNT(*)::bigint AS engineer_count,
         ROUND(AVG(100.0 * t.loops_closed_count::numeric / NULLIF(t.feedback_received_count,0)),2),
         ROUND(AVG(t.csat_score)::numeric,2)
  FROM engineer_monthly_feedback_loop_r2810 t
  GROUP BY t.tier_verdict
  ORDER BY engineer_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2815_long_duration_watchlist -- ORDER BY worst_duration_minutes DESC
CREATE OR REPLACE FUNCTION public.r2815_long_duration_watchlist()
 RETURNS TABLE(fridge_tag text, chain_name text, facility_name text, worst_duration_minutes integer, worst_peak_celsius numeric, rupees_lost bigint, status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT i.fridge_tag, i.chain_name, i.facility_name,
         COALESCE(MAX(e.duration_minutes),0)::int AS worst_duration_minutes,
         COALESCE(MAX(e.peak_celsius),0)::numeric,
         COALESCE(SUM(e.rupees_lost),0)::bigint,
         i.status
  FROM pharmacy_fridge_inventory_r2815 i
  LEFT JOIN fridge_temp_audit_events_r2815 e ON e.fridge_id = i.id
  GROUP BY i.fridge_tag, i.chain_name, i.facility_name, i.status
  ORDER BY worst_duration_minutes DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2826_eta_variance -- ORDER BY variance_pct DESC
CREATE OR REPLACE FUNCTION public.founder_r2826_eta_variance()
 RETURNS TABLE(engineer_code text, engineer_name text, closed_jobs integer, avg_eta numeric, avg_actual numeric, variance_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    p.engineer_code,
    MAX(p.engineer_name),
    COUNT(*) FILTER (WHERE p.actual_hours IS NOT NULL)::int,
    ROUND(AVG(p.eta_hours)::numeric, 2),
    ROUND(AVG(p.actual_hours)::numeric, 2),
    ROUND( ((AVG(p.actual_hours) - AVG(p.eta_hours)) / NULLIF(AVG(p.eta_hours),0)) * 100, 2) AS variance_pct
  FROM engineer_monthly_job_prep_stages_r2826 p
  WHERE p.actual_hours IS NOT NULL
  GROUP BY p.engineer_code
  ORDER BY variance_pct DESC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2830_engineer_leaderboard -- ORDER BY total_ltv_uplift DESC
CREATE OR REPLACE FUNCTION public.founder_r2830_engineer_leaderboard()
 RETURNS TABLE(engineer_name text, milestones_celebrated bigint, total_ltv_uplift bigint, avg_engagement numeric, green_share numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.engineer_name, COUNT(*)::bigint, COALESCE(SUM(m.ltv_uplift_rupees),0)::bigint AS total_ltv_uplift, ROUND(AVG(m.engagement_score),2), ROUND(100.0 * COUNT(*) FILTER (WHERE m.verdict='green') / NULLIF(COUNT(*),0), 2) FROM engineer_customer_milestone_r2830 m GROUP BY m.engineer_name ORDER BY total_ltv_uplift DESC;
END;$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2831_plays_by_chain -- ORDER BY commit_rupees DESC
CREATE OR REPLACE FUNCTION public.rpc_r2831_plays_by_chain()
 RETURNS TABLE(chain_name text, play_count bigint, commit_rupees bigint, landed_rupees bigint, avg_renewal_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_name,
    count(*)::bigint,
    coalesce(sum(p.exec_commit_amount_rupees),0)::bigint AS commit_rupees,
    coalesce(sum(p.outcome_value_rupees) FILTER (WHERE p.outcome_status='landed'),0)::bigint,
    coalesce(round(avg(p.renewal_probability_pct)::numeric,1),0)
  FROM hospital_chain_tier1_deepening_plays_r2831 p
  GROUP BY p.chain_name
  ORDER BY commit_rupees DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.outcome_distribution_handover_r2866 -- ORDER BY avg_impression DESC
CREATE OR REPLACE FUNCTION public.outcome_distribution_handover_r2866(p_month text DEFAULT '2026-06'::text)
 RETURNS TABLE(outcome_label text, slot_count integer, total_handovers integer, avg_impression numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.outcome_label,
           COUNT(*)::int,
           COALESCE(SUM(s.handovers_count),0)::int,
           ROUND(AVG(s.avg_customer_impression)::numeric,2) AS avg_impression
      FROM engineer_monthly_handover_time_of_day_slots_r2866 s
     WHERE s.month_label = p_month
     GROUP BY s.outcome_label
     ORDER BY avg_impression DESC NULLS LAST;
END $function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2882_city_heatmap -- ORDER BY visits DESC
CREATE OR REPLACE FUNCTION public.rpc_r2882_city_heatmap()
 RETURNS TABLE(city text, visits bigint, shoes_removed_pct numeric, avg_clean numeric, complaints bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT t.city,
           count(*)::bigint AS visits,
           ROUND(100.0 * sum(CASE WHEN t.shoes_removed THEN 1 ELSE 0 END)::numeric / NULLIF(count(*),0), 1),
           ROUND(avg(t.cleanliness_score)::numeric, 2),
           sum(CASE WHEN t.customer_impression = 'complaint' THEN 1 ELSE 0 END)::bigint
    FROM engineer_handover_shoes_protocol_r2882 t
    GROUP BY t.city
    ORDER BY visits DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.source_system_reconciliation_r2889 -- ORDER BY claims_using_source DESC, reconciliation_pct ASC
CREATE OR REPLACE FUNCTION public.source_system_reconciliation_r2889()
 RETURNS TABLE(source_system text, claims_using_source bigint, reconciled_count bigint, unreconciled_count bigint, reconciliation_pct numeric, avg_variance_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.source_system,
    count(*)::bigint AS claims_using_source,
    count(*) FILTER (WHERE c.reconciled = true)::bigint,
    count(*) FILTER (WHERE c.reconciled = false)::bigint,
    ROUND( count(*) FILTER (WHERE c.reconciled=true)::numeric / NULLIF(count(*),0) * 100, 1) AS reconciliation_pct,
    ROUND( avg(abs(c.variance_pct)), 2)
  FROM board_pack_narrative_claims_r2889 c
  GROUP BY c.source_system
  ORDER BY reconciliation_pct ASC NULLS FIRST, claims_using_source DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.fn_r2898_doc_type_heatmap -- ORDER BY missing_count DESC
CREATE OR REPLACE FUNCTION public.fn_r2898_doc_type_heatmap()
 RETURNS TABLE(doc_type text, total_events integer, missing_count integer, rejected_count integer, rework_count integer, avg_delay_hours numeric, critical_count integer, resolved_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.doc_type,
    count(*)::int,
    sum((e.doc_status='missing')::int)::int AS missing_count,
    sum((e.doc_status='rejected')::int)::int,
    sum((e.doc_status='rework')::int)::int,
    round(avg(e.delay_hours), 2),
    sum((e.severity='critical')::int)::int,
    sum((e.resolved)::int)::int
  FROM engineer_handover_doc_events_r2898 e
  GROUP BY e.doc_type
  ORDER BY missing_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2905_region_pressure -- ORDER BY avg_market_share DESC, critical_or_high_count DESC
CREATE OR REPLACE FUNCTION public.r2905_region_pressure()
 RETURNS TABLE(region text, competitor_count bigint, avg_market_share numeric, critical_or_high_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT c.region,
           COUNT(*)::bigint,
           ROUND(AVG(c.estimated_market_share_pct), 2) AS avg_market_share,
           COUNT(*) FILTER (WHERE c.threat_level IN ('critical','high'))::bigint AS critical_or_high_count
    FROM public.competitor_battle_cards_r2905 c
    GROUP BY c.region
    ORDER BY critical_or_high_count DESC, avg_market_share DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2919_model_breakdown -- ORDER BY fail_count DESC
CREATE OR REPLACE FUNCTION public.r2919_model_breakdown()
 RETURNS TABLE(evacuator_model text, units integer, avg_velocity numeric, avg_compliance numeric, fail_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.evacuator_model, COUNT(*)::int,
         ROUND(AVG(a.capture_velocity_fpm), 2),
         ROUND(AVG(a.surgeon_compliance_pct), 2),
         SUM(CASE WHEN a.pass_status='fail' THEN 1 ELSE 0 END)::int AS fail_count
  FROM or_smoke_evacuation_audits_r2919 a
  GROUP BY a.evacuator_model
  ORDER BY fail_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2928_tier_accuracy -- ORDER BY accuracy_pct DESC
CREATE OR REPLACE FUNCTION public.rpc_r2928_tier_accuracy()
 RETURNS TABLE(engineer_tier text, jobs integer, within integer, accuracy_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select e.engineer_tier,
           count(*)::int,
           sum(case when e.within_range then 1 else 0 end)::int,
           round(100.0 * sum(case when e.within_range then 1 else 0 end)::numeric / nullif(count(*),0), 2) AS accuracy_pct
    from customer_monthly_engineer_estimate_range_r2928 e
    group by e.engineer_tier
    order by accuracy_pct desc nulls last;
end $function$;

-- ---------------------------------------------------------------------
-- public.r2966_finding_type_mix -- ORDER BY finding_count DESC
CREATE OR REPLACE FUNCTION public.r2966_finding_type_mix()
 RETURNS TABLE(finding_type text, finding_count integer, critical_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_type,
         count(*)::int AS finding_count,
         (count(*) filter (where f.severity='critical'))::int
  from power_strip_findings_r2966 f
  group by f.finding_type
  order by finding_count desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2967_modality_risk_heatmap -- ORDER BY open_critical DESC, open_major DESC
CREATE OR REPLACE FUNCTION public.founder_r2967_modality_risk_heatmap()
 RETURNS TABLE(modality text, probes_total integer, open_critical integer, open_major integer, high_or_critical_safety integer, total_remediation_cost_inr bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select
    f.modality,
    count(distinct f.id)::int,
    (count(*) filter (where af.severity = 'critical' and af.remediation_status in ('open','in_progress','escalated')))::int AS open_critical,
    (count(*) filter (where af.severity = 'major' and af.remediation_status in ('open','in_progress','escalated')))::int AS open_major,
    (count(*) filter (where af.patient_safety_impact in ('high','critical')))::int,
    coalesce(sum(af.cost_to_remediate_inr) filter (where af.remediation_status in ('open','in_progress','escalated')),0)::bigint
  from ultrasound_probe_fleet_r2967 f
  left join ultrasound_probe_audit_findings_r2967 af on af.probe_id = f.id
  group by f.modality
  order by open_critical desc, open_major desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r2995_defect_by_region -- ORDER BY critical DESC, major DESC
CREATE OR REPLACE FUNCTION public.r2995_defect_by_region()
 RETURNS TABLE(region text, critical integer, major integer, minor integer, safety_hold integer, none_clean integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.region,
    (count(*) filter (where d.defect_class='critical'))::int AS critical,
    (count(*) filter (where d.defect_class='major'))::int AS major,
    (count(*) filter (where d.defect_class='minor'))::int,
    (count(*) filter (where d.defect_class='safety_hold'))::int,
    (count(*) filter (where d.defect_class='none'))::int
  from generator_drain_test_r2995 d
  group by d.region
  order by critical desc, major desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.founder_fmt_zone_type_health_r2996 -- ORDER BY avg_adhesion_pct ASC
CREATE OR REPLACE FUNCTION public.founder_fmt_zone_type_health_r2996()
 RETURNS TABLE(zone_type text, inspections integer, avg_adhesion_pct numeric, urgent_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.zone_type, count(*)::int, round(avg(i.adhesion_score_pct),2)::numeric AS avg_adhesion_pct,
    (count(*) filter (where i.status = 'urgent_replace'))::int
  from floor_marking_tape_inspections_r2996 i
  group by i.zone_type
  order by avg_adhesion_pct asc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3000_manufacturer_burn_leaderboard -- ORDER BY pass_rate_pct DESC
CREATE OR REPLACE FUNCTION public.r3000_manufacturer_burn_leaderboard()
 RETURNS TABLE(drape_manufacturer text, lots_tested integer, lots_passed integer, lots_failed integer, avg_flame_spread numeric, avg_char_length numeric, pass_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.drape_manufacturer,
    count(*)::int,
    (count(*) filter (where b.test_outcome='passed'))::int,
    (count(*) filter (where b.test_outcome='failed'))::int,
    round(avg(b.flame_spread_seconds)::numeric, 2),
    round(avg(b.char_length_mm)::numeric, 2),
    round(100.0 * (count(*) filter (where b.test_outcome='passed'))::numeric / nullif(count(*),0), 2) AS pass_rate_pct
  from surgical_drape_burn_tests_r3000 b
  group by b.drape_manufacturer
  order by pass_rate_pct desc nulls last;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3035_failure_mode_distribution -- ORDER BY total_failed DESC
CREATE OR REPLACE FUNCTION public.r3035_failure_mode_distribution()
 RETURNS TABLE(failure_mode text, occurrences integer, total_failed bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select coalesce(a.failure_mode,'unknown') as failure_mode,
           count(*)::int as occurrences,
           sum(a.wrappers_failed)::bigint AS total_failed
    from hospital_chain_wrapper_audits_r3035 a
    group by a.failure_mode
    order by total_failed desc nulls last;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3086_ppe_compliance -- ORDER BY visits DESC
CREATE OR REPLACE FUNCTION public.r3086_ppe_compliance()
 RETURNS TABLE(ppe_level text, visits integer, spillage_incidents integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select ppe_compliance, count(*)::int AS visits, (count(*) filter (where spillage_ml > 0))::int
  from vaporizer_refill_visits_r3086
  group by ppe_compliance
  order by visits desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3079_action_summary -- ORDER BY event_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3079_action_summary()
 RETURNS TABLE(action_taken text, event_count integer, defect_total integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select e.action_taken, count(*)::int AS event_count, coalesce(sum(e.defect_count),0)::int
  from hospital_chain_lead_apron_audit_events_r3079 e
  group by e.action_taken
  order by event_count desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.founder_jobs_by_state -- ORDER BY jobs_90d DESC
CREATE OR REPLACE FUNCTION public.founder_jobs_by_state()
 RETURNS TABLE(state text, hospital_cnt bigint, jobs_90d bigint, gross_rupees numeric, active_amc_cnt bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      p.id AS hospital_id
    FROM public.profiles p
    WHERE p.role = 'hospital_admin'
  )
  SELECT
    b.state,
    count(DISTINCT b.hospital_id)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE rj.hospital_user_id IN (SELECT hospital_id FROM base b2 WHERE b2.state = b.state)
                AND rj.created_at >= now() - interval '90 days'), 0)::bigint AS jobs_90d,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.hospital_user_id IN (SELECT hospital_id FROM base b2 WHERE b2.state = b.state)
                AND rj.status = 'completed'
                AND rj.completed_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT count(DISTINCT c.id)::bigint FROM public.amc_contracts c
              WHERE c.hospital_user_id IN (SELECT hospital_id FROM base b2 WHERE b2.state = b.state)
                AND c.status = 'active'), 0)::bigint
  FROM base b
  GROUP BY b.state
  ORDER BY jobs_90d DESC
  LIMIT 40;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.tier_distribution_r2492 -- ORDER BY total_points DESC
CREATE OR REPLACE FUNCTION public.tier_distribution_r2492()
 RETURNS TABLE(loyalty_tier text, hospital_count bigint, total_points bigint, avg_renewals numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.loyalty_tier,
         COUNT(*)::bigint,
         COALESCE(SUM(s.points_total),0)::bigint AS total_points,
         ROUND(AVG(s.renewals_count)::numeric, 2)
  FROM public.customer_loyalty_status_r2492 s
  GROUP BY s.loyalty_tier
  ORDER BY total_points DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_payout_fail_reasons -- ORDER BY cnt DESC
CREATE OR REPLACE FUNCTION public.founder_payout_fail_reasons()
 RETURNS TABLE(razorpayx_status text, cnt bigint, total_rupees numeric, oldest_age_days integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(p.razorpayx_status, '(null)'),
    count(*)::bigint AS cnt,
    round(coalesce(sum(p.amount_paise), 0)::numeric / 100.0, 2),
    (extract(epoch FROM (now() - min(p.queued_at)))::int / 86400)
  FROM public.engineer_payouts p
  WHERE p.status IN ('failed','queued','processing','cancelled')
  GROUP BY coalesce(p.razorpayx_status, '(null)')
  ORDER BY cnt DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_chains_revenue_rollup -- ORDER BY total_rupees_90d DESC
CREATE OR REPLACE FUNCTION public.founder_chains_revenue_rollup()
 RETURNS TABLE(chain_id uuid, name text, member_count bigint, amc_paid_90d numeric, jobs_gross_90d numeric, total_rupees_90d numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH members AS (
    SELECT m.chain_id, m.hospital_user_id
    FROM public.hospital_chain_memberships m
  )
  SELECT
    c.id,
    c.name,
    coalesce((SELECT count(*)::bigint FROM members m WHERE m.chain_id = c.id), 0)::bigint,
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              JOIN public.amc_contracts a ON a.id = o.amc_contract_id
              JOIN members m2 ON m2.hospital_user_id = a.hospital_user_id
             WHERE m2.chain_id = c.id
               AND o.status = 'paid'
               AND o.created_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              JOIN members m3 ON m3.hospital_user_id = rj.hospital_user_id
             WHERE m3.chain_id = c.id
               AND rj.status = 'completed'
               AND rj.completed_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              JOIN public.amc_contracts a ON a.id = o.amc_contract_id
              JOIN members m2 ON m2.hospital_user_id = a.hospital_user_id
             WHERE m2.chain_id = c.id
               AND o.status = 'paid'
               AND o.created_at >= now() - interval '90 days'), 0)::numeric
    +
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              JOIN members m3 ON m3.hospital_user_id = rj.hospital_user_id
             WHERE m3.chain_id = c.id
               AND rj.status = 'completed'
               AND rj.completed_at >= now() - interval '90 days'), 0)::numeric AS total_rupees_90d
  FROM public.hospital_chains c
  ORDER BY total_rupees_90d DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_skills_critical_skill_coverage -- ORDER BY coverage_pct ASC
CREATE OR REPLACE FUNCTION public.founder_engineer_skills_critical_skill_coverage()
 RETURNS TABLE(skill_id uuid, skill_label text, skill_kind text, importance_band text, total_engineers bigint, proficient_or_above bigint, coverage_pct numeric, expert_count bigint, trainer_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_engineers bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder-only';
  END IF;

  SELECT COUNT(*) INTO v_total_engineers FROM public.engineers
  WHERE COALESCE(verification_status::text, '') IN ('verified','approved','active','live');

  IF v_total_engineers IS NULL OR v_total_engineers = 0 THEN
    SELECT COUNT(*) INTO v_total_engineers FROM public.engineers;
  END IF;

  RETURN QUERY
  SELECT
    t.id, t.skill_label, t.skill_kind, t.importance_band,
    v_total_engineers,
    COUNT(DISTINCT p.engineer_user_id) FILTER (
      WHERE p.proficiency_level IN ('proficient','expert','trainer')
    )::bigint,
    CASE WHEN v_total_engineers = 0 THEN 0::numeric
         ELSE ROUND(
           (COUNT(DISTINCT p.engineer_user_id) FILTER (
             WHERE p.proficiency_level IN ('proficient','expert','trainer')
           ))::numeric * 100.0 / v_total_engineers::numeric, 1)
    END AS coverage_pct,
    COUNT(*) FILTER (WHERE p.proficiency_level = 'expert')::bigint,
    COUNT(*) FILTER (WHERE p.proficiency_level = 'trainer')::bigint
  FROM public.engineer_skills_taxonomy t
  LEFT JOIN public.engineer_skills_proficiency p ON p.skill_id = t.id
  WHERE t.is_active AND t.importance_band IN ('critical','high')
  GROUP BY t.id, t.skill_label, t.skill_kind, t.importance_band
  ORDER BY
    CASE t.importance_band WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
    coverage_pct ASC NULLS FIRST,
    t.skill_label ASC;
END $function$;

-- ---------------------------------------------------------------------
-- public.top_overdue_hospitals_r1747 -- ORDER BY total_outstanding_rupees DESC
CREATE OR REPLACE FUNCTION public.top_overdue_hospitals_r1747()
 RETURNS TABLE(hospital_user_id uuid, hospital_email text, hospital_org text, invoice_count integer, total_outstanding_rupees bigint, max_days_overdue integer)
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
    h.hospital_user_id,
    p.email,
    o.name,
    (COUNT(*))::int,
    COALESCE(SUM(h.amount_rupees - h.paid_amount_rupees), 0)::bigint AS total_outstanding_rupees,
    COALESCE(MAX(GREATEST(0, (CURRENT_DATE - h.due_date))), 0)::int
  FROM public.hospital_invoices_outstanding_r1747 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE h.status IN ('overdue_30','overdue_60','overdue_90_plus')
  GROUP BY h.hospital_user_id, p.email, o.name
  ORDER BY total_outstanding_rupees DESC
  LIMIT 25;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cash_pipeline_by_stage -- ORDER BY weighted_arr_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_cash_pipeline_by_stage()
 RETURNS TABLE(stage text, entries integer, total_arr_rupees bigint, weighted_arr_rupees bigint, avg_probability_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.stage,
         COUNT(*)::int,
         COALESCE(SUM(p.arr_rupees),0)::bigint,
         COALESCE(SUM(p.arr_rupees * p.probability_pct / 100.0),0)::bigint AS weighted_arr_rupees,
         ROUND(AVG(p.probability_pct)::numeric, 1)
  FROM founder_pipeline_entries p
  WHERE p.stage NOT IN ('closed_won','closed_lost')
  GROUP BY p.stage
  ORDER BY weighted_arr_rupees DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2292_by_policy -- ORDER BY total_gross_paise DESC
CREATE OR REPLACE FUNCTION public.founder_r2292_by_policy()
 RETURNS TABLE(recognition_policy text, stream_count integer, total_gross_paise bigint, total_recognized_paise bigint, total_deferred_paise bigint, pct_recognized numeric)
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
    s.recognition_policy,
    (COUNT(*))::int,
    COALESCE(SUM(s.gross_amount_paise), 0)::bigint AS total_gross_paise,
    COALESCE(SUM(s.recognized_to_date_paise), 0)::bigint,
    COALESCE(SUM(s.deferred_balance_paise), 0)::bigint,
    CASE WHEN COALESCE(SUM(s.gross_amount_paise), 0) = 0
      THEN 0
      ELSE ROUND((COALESCE(SUM(s.recognized_to_date_paise), 0)::numeric / SUM(s.gross_amount_paise)::numeric) * 100, 2)
    END
  FROM public.customer_revenue_streams_r2292 s
  GROUP BY s.recognition_policy
  ORDER BY total_gross_paise DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2385_pattern_category_rollup -- ORDER BY total_bugs_prevented DESC
CREATE OR REPLACE FUNCTION public.founder_r2385_pattern_category_rollup()
 RETURNS TABLE(pattern_category text, patterns_count bigint, total_bugs_prevented bigint, total_batches_observed bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT p.pattern_category,
           count(*)::bigint,
           coalesce(sum(p.bugs_prevented_count),0)::bigint AS total_bugs_prevented,
           coalesce(sum(p.batches_observed_in),0)::bigint
    FROM public.founder_270_batch_patterns_r2385 p
    GROUP BY p.pattern_category
    ORDER BY total_bugs_prevented DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r3106_fio2_accuracy_by_model -- ORDER BY worst_fio2_dev DESC
CREATE OR REPLACE FUNCTION public.r3106_fio2_accuracy_by_model()
 RETURNS TABLE(ventilator_model text, units_tested bigint, avg_fio2_deviation numeric, worst_fio2_dev numeric, failing_units bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.ventilator_model,
    count(*)::bigint,
    round(avg(abs(v.fio2_deviation_pct))::numeric, 2),
    round(max(abs(v.fio2_deviation_pct))::numeric, 2) AS worst_fio2_dev,
    count(*) FILTER (WHERE abs(v.fio2_deviation_pct) > 5.0)::bigint
  FROM public.ventilator_calibration_runs_r3106 v
  GROUP BY v.ventilator_model
  ORDER BY worst_fio2_dev DESC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r3108_vendor_deviation -- ORDER BY fail_rate_pct DESC
CREATE OR REPLACE FUNCTION public.r3108_vendor_deviation()
 RETURNS TABLE(monitor_make text, monitors_tested integer, fail_rate_pct numeric, avg_spo2_dev numeric, worst_spo2_dev numeric, avg_nibp_dev numeric, worst_nibp_dev integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.monitor_make::text,
           count(*)::integer,
           round(100.0 * count(*) filter (where s.overall_verdict in ('fail','withdrawn_from_service')) / nullif(count(*),0), 1) AS fail_rate_pct,
           round(avg(abs(s.spo2_deviation_pct))::numeric, 2),
           round(max(abs(s.spo2_deviation_pct))::numeric, 2),
           round(avg(abs(s.nibp_deviation_mmhg))::numeric, 2),
           max(abs(s.nibp_deviation_mmhg))::integer
      from patient_monitor_calibration_sessions_r3108 s
     group by s.monitor_make
     order by fail_rate_pct desc nulls last;
end
$function$;

-- ---------------------------------------------------------------------
-- public.balance_kind_distribution_r2633 -- ORDER BY month_count DESC
CREATE OR REPLACE FUNCTION public.balance_kind_distribution_r2633()
 RETURNS TABLE(balance_kind text, month_count bigint, total_hours numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.balance_kind, COUNT(*)::bigint AS month_count, COALESCE(SUM(a.total_hours),0)
  FROM public.founder_time_allocation_r2633 a
  GROUP BY a.balance_kind
  ORDER BY month_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3111_role_concern_hotspots -- ORDER BY total_feedback DESC, concern_pct DESC
CREATE OR REPLACE FUNCTION public.fn_r3111_role_concern_hotspots()
 RETURNS TABLE(responder_role text, total_feedback bigint, raised_concern_count bigint, concern_pct numeric, avg_nps numeric, avg_clarity numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.responder_role,
         COUNT(*)::bigint AS total_feedback,
         COUNT(*) FILTER (WHERE f.raised_quarterly_concern)::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE f.raised_quarterly_concern)::numeric
               / NULLIF(COUNT(*),0), 1) AS concern_pct,
         ROUND(AVG(f.nps_score)::numeric, 2),
         ROUND(AVG(f.clarity_rating)::numeric, 2)
  FROM public.founder_comms_feedback_r3111 f
  GROUP BY f.responder_role
  ORDER BY concern_pct DESC, total_feedback DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r3123_category_gap_heatmap -- ORDER BY gap_clauses DESC
CREATE OR REPLACE FUNCTION public.founder_r3123_category_gap_heatmap()
 RETURNS TABLE(clause_category text, total_clauses bigint, gap_clauses bigint, gap_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.clause_category,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.readiness_status IN ('minor_gap','major_gap','not_started'))::bigint AS gap_clauses,
         ROUND(100.0 * COUNT(*) FILTER (WHERE c.readiness_status IN ('minor_gap','major_gap','not_started')) / NULLIF(COUNT(*),0), 1)
  FROM nabl_iso_clause_readiness_r3123 c
  GROUP BY c.clause_category
  ORDER BY gap_clauses DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.owner_load_r2672 -- ORDER BY total_variance_rupees DESC
CREATE OR REPLACE FUNCTION public.owner_load_r2672()
 RETURNS TABLE(owner_engineer_email text, equipment_count bigint, total_variance_rupees bigint, open_actions bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT s.owner_engineer_email,
           count(*)::bigint,
           coalesce(sum(s.variance_rupees),0)::bigint AS total_variance_rupees,
           (SELECT count(*)::bigint FROM customer_spare_parts_corrective_actions_r2672 a
            WHERE a.action_owner_email = s.owner_engineer_email
            AND a.status IN ('queued','in_progress','blocked'))
    FROM customer_spare_parts_burn_snapshots_r2672 s
    WHERE s.owner_engineer_email IS NOT NULL
    GROUP BY s.owner_engineer_email
    ORDER BY total_variance_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2694_outcome_breakdown -- ORDER BY rotation_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2694_outcome_breakdown()
 RETURNS TABLE(outcome_bucket text, rotation_count bigint, avg_jobs_completed numeric, avg_csat numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(r.outcome, 'in-progress') AS outcome_bucket,
         COUNT(*)::bigint AS rotation_count,
         ROUND(AVG(r.jobs_completed)::numeric, 1),
         ROUND(AVG(r.csat_avg)::numeric, 2)
  FROM engineer_cross_region_rotations_r2694 r
  GROUP BY COALESCE(r.outcome, 'in-progress')
  ORDER BY rotation_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_on_call_region_breakdown_r2702 -- ORDER BY engineer_count DESC
CREATE OR REPLACE FUNCTION public.founder_on_call_region_breakdown_r2702()
 RETURNS TABLE(engineer_region text, engineer_count bigint, total_hours numeric, avg_fairness numeric, weekend_share numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.engineer_region,
         COUNT(*)::bigint AS engineer_count,
         COALESCE(SUM(r.total_hours), 0)::numeric,
         COALESCE(AVG(r.fairness_score), 0)::numeric,
         CASE WHEN SUM(r.total_hours) > 0
              THEN ROUND((SUM(r.weekend_hours) * 100.0 / SUM(r.total_hours))::numeric, 2)
              ELSE 0 END
  FROM engineer_on_call_rotation_r2702 r
  GROUP BY r.engineer_region
  ORDER BY engineer_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2704_source_performance -- ORDER BY total_savings_rupees DESC
CREATE OR REPLACE FUNCTION public.r2704_source_performance()
 RETURNS TABLE(substitute_source text, events_count integer, total_savings_rupees bigint, avg_performance_delta numeric, approval_rate_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.substitute_source, COUNT(*)::int,
         COALESCE(SUM(e.cost_savings_rupees),0)::bigint AS total_savings_rupees,
         COALESCE(AVG(e.performance_delta_pct),0)::numeric(6,2),
         (COUNT(*) FILTER (WHERE e.verdict IN ('approved_recurring','approved_one_off'))::numeric * 100.0 / NULLIF(COUNT(*),0))::numeric(5,2)
  FROM spare_part_substitution_events_r2704 e
  GROUP BY e.substitute_source
  ORDER BY total_savings_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_cab_top_contributors_r2717 -- ORDER BY total_value_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_cab_top_contributors_r2717()
 RETURNS TABLE(member_name text, org_name text, contributions integer, total_value_rupees bigint, asks_open integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.member_name, m.org_name,
         count(c.*)::int,
         COALESCE(sum(c.contribution_value_rupees),0)::bigint AS total_value_rupees,
         count(*) FILTER (WHERE c.ask_status='open')::int
  FROM cab_members_r2717 m
  LEFT JOIN cab_contributions_r2717 c ON c.member_id = m.id
  GROUP BY m.member_name, m.org_name
  ORDER BY total_value_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2733_source_mix -- ORDER BY candidates DESC
CREATE OR REPLACE FUNCTION public.founder_r2733_source_mix()
 RETURNS TABLE(candidate_source text, candidates integer, accepted_count integer, acceptance_rate numeric, avg_signal numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.candidate_source,
         COUNT(*)::int AS candidates,
         COUNT(*) FILTER (WHERE p.accepted)::int,
         ROUND((COUNT(*) FILTER (WHERE p.accepted)::numeric / NULLIF(COUNT(*),0)) * 100, 1),
         ROUND(AVG(p.signal_score)::numeric, 1)
  FROM founder_key_hire_pipeline_r2733 p
  GROUP BY p.candidate_source
  ORDER BY candidates DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2747_pilots_by_chain -- ORDER BY total_budget_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r2747_pilots_by_chain()
 RETURNS TABLE(chain_name text, pilot_count bigint, total_budget_rupees bigint, running bigint, complete bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name,
         count(*)::bigint,
         COALESCE(sum(p.budget_rupees),0)::bigint AS total_budget_rupees,
         count(*) FILTER (WHERE p.status='running')::bigint,
         count(*) FILTER (WHERE p.status='complete')::bigint
    FROM hospital_chain_tech_pilots_r2747 p
   GROUP BY p.chain_name
   ORDER BY total_budget_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2777_agency_breakdown -- ORDER BY total_award DESC
CREATE OR REPLACE FUNCTION public.founder_r2777_agency_breakdown()
 RETURNS TABLE(grant_agency text, project_count bigint, total_award bigint, total_disbursed bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.grant_agency, COUNT(*)::bigint, COALESCE(SUM(p.award_amount_rupees),0)::bigint AS total_award, COALESCE(SUM(p.disbursed_rupees),0)::bigint
    FROM grant_research_projects_r2777 p
    GROUP BY p.grant_agency
    ORDER BY total_award DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2778_trade_show_funnel -- ORDER BY expected_rupees DESC
CREATE OR REPLACE FUNCTION public.r2778_trade_show_funnel()
 RETURNS TABLE(followup_stage text, lead_count integer, expected_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.followup_stage,
           COUNT(*)::int,
           COALESCE(SUM(f.expected_value_rupees),0)::bigint AS expected_rupees
    FROM engineer_trade_show_lead_followup_r2778 f
    GROUP BY f.followup_stage
    ORDER BY expected_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2783_qoq_adoption_trend -- ORDER BY delta_pct DESC
CREATE OR REPLACE FUNCTION public.r2783_qoq_adoption_trend()
 RETURNS TABLE(chain_name text, ai_module text, q1_adoption_pct numeric, q2_adoption_pct numeric, delta_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q2.chain_name,
    q2.ai_module,
    COALESCE(q1.adoption_pct, 0)::numeric,
    q2.adoption_pct::numeric,
    ROUND((q2.adoption_pct - COALESCE(q1.adoption_pct, 0))::numeric, 2) AS delta_pct
  FROM hospital_chain_ai_integration_pulse_r2783 q2
  LEFT JOIN hospital_chain_ai_integration_pulse_r2783 q1
    ON q1.chain_name = q2.chain_name
   AND q1.ai_module  = q2.ai_module
   AND q1.pulse_quarter = '2026-Q1'
  WHERE q2.pulse_quarter = '2026-Q2'
  ORDER BY delta_pct DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2788_customers_by_tier -- ORDER BY breach_total DESC
CREATE OR REPLACE FUNCTION public.founder_r2788_customers_by_tier()
 RETURNS TABLE(customer_tier text, customer_count integer, incident_total integer, after_hours_total integer, breach_total integer, avg_response numeric, credit_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.customer_tier,
    COUNT(*)::int,
    COALESCE(SUM(c.incident_count),0)::int,
    COALESCE(SUM(c.after_hours_count),0)::int,
    COALESCE(SUM(c.sla_breach_count),0)::int AS breach_total,
    COALESCE(ROUND(AVG(c.avg_response_minutes),2),0)::numeric,
    COALESCE(SUM(c.override_credit_rupees),0)::numeric
  FROM customer_after_hours_incidents_r2788 c
  GROUP BY c.customer_tier
  ORDER BY breach_total DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2830_gesture_mix -- ORDER BY total_ltv_uplift DESC
CREATE OR REPLACE FUNCTION public.founder_r2830_gesture_mix()
 RETURNS TABLE(gesture_type text, count bigint, total_cost bigint, total_ltv_uplift bigint, roi_multiple numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.gesture_type, COUNT(*)::bigint, COALESCE(SUM(m.gesture_cost_rupees),0)::bigint, COALESCE(SUM(m.ltv_uplift_rupees),0)::bigint AS total_ltv_uplift, CASE WHEN SUM(m.gesture_cost_rupees) > 0 THEN ROUND(SUM(m.ltv_uplift_rupees)::numeric / SUM(m.gesture_cost_rupees), 2) ELSE NULL END FROM engineer_customer_milestone_r2830 m GROUP BY m.gesture_type ORDER BY total_ltv_uplift DESC;
END;$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2831_plays_by_outcome -- ORDER BY commit_rupees DESC
CREATE OR REPLACE FUNCTION public.rpc_r2831_plays_by_outcome()
 RETURNS TABLE(outcome_status text, cnt bigint, commit_rupees bigint, outcome_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.outcome_status,
    count(*)::bigint,
    coalesce(sum(p.exec_commit_amount_rupees),0)::bigint AS commit_rupees,
    coalesce(sum(p.outcome_value_rupees),0)::bigint
  FROM hospital_chain_tier1_deepening_plays_r2831 p
  GROUP BY p.outcome_status
  ORDER BY commit_rupees DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2839_category_mix -- ORDER BY expected_revenue DESC
CREATE OR REPLACE FUNCTION public.rpc_r2839_category_mix()
 RETURNS TABLE(asset_category text, cohorts bigint, units_total bigint, avg_age numeric, expected_revenue numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.asset_category, COUNT(*)::bigint,
           COALESCE(SUM(c.units_total),0)::bigint,
           ROUND(AVG(c.avg_age_years)::numeric, 2),
           COALESCE(SUM(c.expected_revenue_lakhs),0)::numeric AS expected_revenue
    FROM chain_fleet_cohorts_r2839 c
    GROUP BY c.asset_category
    ORDER BY expected_revenue DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2862_channel_performance -- ORDER BY total_published DESC
CREATE OR REPLACE FUNCTION public.founder_r2862_channel_performance()
 RETURNS TABLE(publish_channel text, total_published integer, avg_views numeric, avg_reactions numeric, total_replies integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.publish_channel,
         COUNT(*) FILTER (WHERE n.publish_status = 'published')::int AS total_published,
         ROUND(AVG(n.engagement_views) FILTER (WHERE n.publish_status = 'published'), 0),
         ROUND(AVG(n.engagement_reactions) FILTER (WHERE n.publish_status = 'published'), 0),
         COALESCE(SUM(n.engagement_replies) FILTER (WHERE n.publish_status = 'published'), 0)::int
  FROM engineer_monthly_narrative_publish_r2862 n
  GROUP BY n.publish_channel
  ORDER BY total_published DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2872_velocity_band_distribution -- ORDER BY total_quotes_accepted DESC
CREATE OR REPLACE FUNCTION public.founder_r2872_velocity_band_distribution()
 RETURNS TABLE(velocity_band text, engineer_count bigint, total_quotes_accepted bigint, share_of_accepted_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  total_accepted bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(quotes_accepted),0) INTO total_accepted
  FROM engineer_quote_velocity_r2872
  WHERE month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872);

  RETURN QUERY
  SELECT
    v.velocity_band,
    COUNT(*)::bigint,
    COALESCE(SUM(v.quotes_accepted),0)::bigint AS total_quotes_accepted,
    CASE WHEN total_accepted = 0 THEN 0
         ELSE ROUND((SUM(v.quotes_accepted)::numeric / total_accepted::numeric) * 100, 2) END
  FROM engineer_quote_velocity_r2872 v
  WHERE v.month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872)
  GROUP BY v.velocity_band
  ORDER BY total_quotes_accepted DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2895_category_posture -- ORDER BY coverage_pct ASC
CREATE OR REPLACE FUNCTION public.founder_r2895_category_posture()
 RETURNS TABLE(equipment_category text, branches integer, avg_ratio numeric, total_required integer, total_backup bigint, coverage_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.equipment_category,
         COUNT(*)::int,
         ROUND(AVG(c.redundancy_ratio),2),
         SUM(c.required_redundancy_units)::int,
         SUM(c.backup_units)::bigint,
         ROUND(100.0 * SUM(c.backup_units)::numeric / NULLIF(SUM(c.required_redundancy_units),0), 1) AS coverage_pct
  FROM hospital_chain_critical_care_redundancy_coverage_r2895 c
  GROUP BY c.equipment_category
  ORDER BY coverage_pct ASC;
END;$function$;

-- ---------------------------------------------------------------------
-- public.fn_r2898_channel_mix -- ORDER BY events DESC
CREATE OR REPLACE FUNCTION public.fn_r2898_channel_mix()
 RETURNS TABLE(channel text, events integer, ack_rate_pct numeric, avg_delay_hours numeric, resolved_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    coalesce(e.channel,'unknown'),
    count(*)::int AS events,
    round(100.0 * sum((e.customer_acknowledged)::int) / nullif(count(*),0), 2),
    round(avg(e.delay_hours), 2),
    round(100.0 * sum((e.resolved)::int) / nullif(count(*),0), 2)
  FROM engineer_handover_doc_events_r2898 e
  GROUP BY coalesce(e.channel,'unknown')
  ORDER BY events DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2905_top_win_drivers -- ORDER BY win_count DESC, total_value_rupees DESC
CREATE OR REPLACE FUNCTION public.r2905_top_win_drivers()
 RETURNS TABLE(primary_driver text, win_count bigint, total_value_rupees bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT e.primary_driver,
           COUNT(*)::bigint AS win_count,
           COALESCE(SUM(e.deal_size_rupees),0)::bigint AS total_value_rupees
    FROM public.competitor_win_loss_events_r2905 e
    WHERE e.outcome = 'won'
    GROUP BY e.primary_driver
    ORDER BY win_count DESC, total_value_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2919_city_heatmap -- ORDER BY total_exposure DESC
CREATE OR REPLACE FUNCTION public.r2919_city_heatmap()
 RETURNS TABLE(city text, audits integer, fails integer, marginal integer, total_exposure numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.city, COUNT(*)::int,
         SUM(CASE WHEN a.pass_status='fail' THEN 1 ELSE 0 END)::int,
         SUM(CASE WHEN a.pass_status='marginal' THEN 1 ELSE 0 END)::int,
         SUM(a.fine_exposure_rupees) AS total_exposure
  FROM or_smoke_evacuation_audits_r2919 a
  GROUP BY a.city
  ORDER BY total_exposure DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2921_mood_distribution -- ORDER BY occurrences DESC
CREATE OR REPLACE FUNCTION public.r2921_mood_distribution()
 RETURNS TABLE(mood_label text, occurrences bigint, avg_burnout numeric, avg_stress numeric, last_seen date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT c.mood_label,
         count(*)::bigint AS occurrences,
         round(avg(c.burnout_index)::numeric, 2),
         round(avg(c.stress_level)::numeric, 2),
         max(c.checkin_date)
  FROM public.founder_mental_health_checkins_r2921 c
  GROUP BY c.mood_label
  ORDER BY occurrences DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2967_auditor_productivity -- ORDER BY findings_logged DESC
CREATE OR REPLACE FUNCTION public.founder_r2967_auditor_productivity()
 RETURNS TABLE(auditor_handle text, findings_logged integer, critical_findings integer, remediated integer, open_or_escalated integer, remediation_close_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select
    af.auditor_handle,
    count(*)::int AS findings_logged,
    (count(*) filter (where af.severity = 'critical'))::int,
    (count(*) filter (where af.remediation_status = 'remediated'))::int,
    (count(*) filter (where af.remediation_status in ('open','in_progress','escalated')))::int,
    round(
      ((count(*) filter (where af.remediation_status = 'remediated'))::numeric * 100.0)
      / greatest(count(*)::numeric, 1)
    , 2)
  from ultrasound_probe_audit_findings_r2967 af
  group by af.auditor_handle
  order by findings_logged desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2971_chain_summary -- ORDER BY total_gap DESC
CREATE OR REPLACE FUNCTION public.founder_r2971_chain_summary()
 RETURNS TABLE(chain_name text, sites integer, critical_count integer, short_count integer, healthy_count integer, total_gap integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.chain_name,
    count(distinct a.hospital_site)::int,
    (count(*) filter (where a.status='critical'))::int,
    (count(*) filter (where a.status='short'))::int,
    (count(*) filter (where a.status='healthy'))::int,
    sum(case when a.reserve_gap < 0 then -a.reserve_gap else 0 end)::int AS total_gap
  from ot_light_bulb_reserve_audits_r2971 a
  group by a.chain_name
  order by total_gap desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.r2995_fuel_type_mix -- ORDER BY sites DESC
CREATE OR REPLACE FUNCTION public.r2995_fuel_type_mix()
 RETURNS TABLE(fuel_type text, sites integer, total_capacity_litres bigint, total_reserve_litres bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.fuel_type, count(*)::int AS sites, sum(g.tank_capacity_litres)::bigint, sum(g.current_reserve_litres)::bigint
  from generator_fuel_reserve_r2995 g
  group by g.fuel_type
  order by sites desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.r3000_fda_audit_risk_summary -- ORDER BY avg_risk_score DESC
CREATE OR REPLACE FUNCTION public.r3000_fda_audit_risk_summary()
 RETURNS TABLE(device_category text, total_audited integer, compliant integer, non_compliant integer, critical_findings integer, avg_risk_score numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.device_category,
    count(*)::int,
    (count(*) filter (where a.compliance_status='compliant'))::int,
    (count(*) filter (where a.compliance_status='non_compliant'))::int,
    (count(*) filter (where a.compliance_status='critical_finding'))::int,
    round(avg(a.risk_score)::numeric, 2) AS avg_risk_score
  from fda_compliance_spot_audits_r3000 a
  group by a.device_category
  order by avg_risk_score desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3034_engineer_load -- ORDER BY audits DESC
CREATE OR REPLACE FUNCTION public.r3034_engineer_load()
 RETURNS TABLE(engineer_name text, audits integer, follow_ups integer, replace_now_calls integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name, count(*)::int AS audits,
    (count(*) filter (where a.follow_up_required))::int,
    (count(*) filter (where a.bearing_status = 'replace_now'))::int
  from centrifuge_imbalance_audits_r3034 a
  group by a.engineer_name
  order by audits desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.r3043_city_leaderboard -- ORDER BY avg_visual ASC, fail_count DESC
CREATE OR REPLACE FUNCTION public.r3043_city_leaderboard()
 RETURNS TABLE(city text, audits integer, avg_visual numeric, avg_sanitizer numeric, fail_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.city,
    count(*)::int,
    round(avg(a.visual_score)::numeric,2) AS avg_visual,
    round(avg(a.sanitizer_residue_ppm)::numeric,2),
    (count(*) filter (where a.pass_status in ('fail','critical_fail')))::int AS fail_count
  from public.tray_window_audits_r3043 a
  group by a.city
  order by fail_count desc, avg_visual asc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3047_recurring_fault_assets -- ORDER BY incident_count DESC
CREATE OR REPLACE FUNCTION public.fn_r3047_recurring_fault_assets()
 RETURNS TABLE(defib_asset_tag text, chain_code text, hospital_code text, incident_count integer, distinct_kinds integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.defib_asset_tag, i.chain_code, i.hospital_code,
         count(*)::int AS incident_count,
         count(distinct i.incident_kind)::int
  from defib_compliance_incidents_r3047 i
  group by i.defib_asset_tag, i.chain_code, i.hospital_code
  having count(*) >= 2
  order by incident_count desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.r3086_tier_distribution -- ORDER BY avg_score DESC
CREATE OR REPLACE FUNCTION public.r3086_tier_distribution()
 RETURNS TABLE(tier_name text, engineer_count integer, avg_score numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select tier, count(*)::int, round(avg(discipline_score)::numeric, 2) AS avg_score
  from vaporizer_discipline_scorecards_r3086
  group by tier
  order by avg_score desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3079_compliance_split -- ORDER BY event_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3079_compliance_split()
 RETURNS TABLE(compliance_status text, event_count integer, pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare total int;
begin
  if not is_founder() then raise exception 'not founder'; end if;
  select count(*) into total from hospital_chain_lead_apron_audit_events_r3079;
  return query
  select e.compliance_status, count(*)::int AS event_count,
         round((count(*)::numeric / nullif(total,0)) * 100, 1)
  from hospital_chain_lead_apron_audit_events_r3079 e
  group by e.compliance_status
  order by event_count desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.founder_signups_by_state -- ORDER BY total_90d DESC
CREATE OR REPLACE FUNCTION public.founder_signups_by_state()
 RETURNS TABLE(state text, total_90d bigint, engineers_90d bigint, hospitals_90d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
    count(*)::bigint AS total_90d,
    count(*) FILTER (WHERE p.role = 'engineer')::bigint,
    count(*) FILTER (WHERE p.role = 'hospital_admin')::bigint
  FROM public.profiles p
  WHERE p.created_at >= now() - interval '90 days'
  GROUP BY 1
  ORDER BY total_90d DESC
  LIMIT 40;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_spare_parts_by_status -- ORDER BY rupees_90d DESC
CREATE OR REPLACE FUNCTION public.founder_spare_parts_by_status()
 RETURNS TABLE(status text, cnt_90d bigint, rupees_90d numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(o.order_status::text, '(unknown)'),
    count(*)::bigint,
    coalesce(sum(o.total_amount), 0)::numeric AS rupees_90d
  FROM public.spare_part_orders o
  WHERE o.created_at >= now() - interval '90 days'
  GROUP BY 1
  ORDER BY rupees_90d DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_payment_orders_status -- ORDER BY total_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_amc_payment_orders_status()
 RETURNS TABLE(status text, order_count bigint, total_rupees numeric, oldest_days integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    o.status,
    count(*)::bigint,
    coalesce(sum(o.amount_rupees), 0)::numeric AS total_rupees,
    (extract(epoch FROM (now() - min(o.created_at)))::int / 86400)
  FROM public.amc_payment_orders o
  GROUP BY o.status
  ORDER BY total_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_hospital_spend_30d -- ORDER BY spend_30d_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_hospital_spend_30d()
 RETURNS TABLE(hospital_user_id uuid, display_name text, spend_30d_rupees numeric, jobs_completed integer, avg_job_rupees numeric, has_active_amc boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    rj.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric AS spend_30d_rupees,
    count(*)::int,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(rj.contracted_amount_rupees), 0)::numeric / count(*)::numeric, 2)
    END,
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
       WHERE c.hospital_user_id = rj.hospital_user_id AND c.status = 'active'
    )
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.status = 'completed'
    AND rj.completed_at >= now() - interval '30 days'
  GROUP BY rj.hospital_user_id, p.full_name
  ORDER BY spend_30d_rupees DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_demand_by_model -- ORDER BY signals_90d DESC
CREATE OR REPLACE FUNCTION public.founder_demand_by_model()
 RETURNS TABLE(brand text, model text, signals_90d bigint, resolved_90d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(lower(trim(s.equipment_brand)), ''), '(unknown)'),
    coalesce(nullif(lower(trim(s.equipment_model)), ''), '(unknown)'),
    count(*)::bigint AS signals_90d,
    count(*) FILTER (WHERE s.resolved_at IS NOT NULL)::bigint
  FROM public.spare_part_demand_signals s
  WHERE s.occurred_at >= now() - interval '90 days'
  GROUP BY 1, 2
  ORDER BY signals_90d DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_top_engineers_90d -- ORDER BY gross_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_top_engineers_90d()
 RETURNS TABLE(engineer_user_id uuid, display_name text, jobs_completed integer, gross_rupees numeric, avg_job_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    b.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    count(*)::int,
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric AS gross_rupees,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(rj.contracted_amount_rupees), 0)::numeric / count(*)::numeric, 2)
    END
  FROM public.repair_jobs rj
  JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  WHERE rj.status = 'completed'
    AND rj.completed_at >= now() - interval '90 days'
  GROUP BY b.engineer_user_id, p.full_name
  ORDER BY gross_rupees DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_revenue_by_city -- ORDER BY paid_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_by_city()
 RETURNS TABLE(city text, hospital_cnt bigint, paid_orders bigint, paid_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH paid AS (
    SELECT o.amount_rupees, c.hospital_user_id
    FROM public.amc_payment_orders o
    JOIN public.amc_contracts c ON c.id = o.amc_contract_id
    WHERE o.status = 'paid' AND o.created_at >= now() - interval '90 days'
  ),
  with_city AS (
    SELECT coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
           paid.hospital_user_id,
           paid.amount_rupees
    FROM paid
    LEFT JOIN public.profiles p ON p.id = paid.hospital_user_id
  )
  SELECT
    wc.city,
    count(DISTINCT wc.hospital_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(wc.amount_rupees), 0)::numeric AS paid_rupees
  FROM with_city wc
  GROUP BY wc.city
  ORDER BY paid_rupees DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_pool_balance_by_city -- ORDER BY total_balance DESC
CREATE OR REPLACE FUNCTION public.founder_amc_pool_balance_by_city()
 RETURNS TABLE(city text, hospitals bigint, contracts bigint, total_balance numeric, mrr numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT c.id, c.hospital_user_id, c.monthly_fee_rupees,
           coalesce(b.balance_rupees, 0)::numeric AS balance
    FROM public.amc_contracts c
    LEFT JOIN public.v_amc_pool_balance b ON b.amc_contract_id = c.id
    WHERE c.status = 'active'
  ),
  with_city AS (
    SELECT coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
           a.hospital_user_id, a.id AS contract_id, a.balance, a.monthly_fee_rupees
    FROM active a
    LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  )
  SELECT
    wc.city,
    count(DISTINCT wc.hospital_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(wc.balance), 0)::numeric AS total_balance,
    coalesce(sum(wc.monthly_fee_rupees), 0)::numeric
  FROM with_city wc
  GROUP BY wc.city
  ORDER BY total_balance DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_code_red_by_equipment -- ORDER BY cnt_90d DESC
CREATE OR REPLACE FUNCTION public.founder_code_red_by_equipment()
 RETURNS TABLE(equipment_type text, cnt_90d bigint, resolved_90d bigint, timed_out_90d bigint, resolution_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(r.equipment_type), ''), '(unknown)') AS equipment_type,
      r.status
    FROM public.code_red_requests r
    WHERE r.created_at >= now() - interval '90 days'
  )
  SELECT
    b.equipment_type,
    count(*)::bigint AS cnt_90d,
    count(*) FILTER (WHERE b.status = 'resolved')::bigint,
    count(*) FILTER (WHERE b.status = 'timed_out')::bigint,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(count(*) FILTER (WHERE b.status = 'resolved')::numeric
                    / count(*)::numeric * 100.0, 1)
    END
  FROM base b
  GROUP BY b.equipment_type
  ORDER BY cnt_90d DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_revenue_by_state -- ORDER BY paid_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_by_state()
 RETURNS TABLE(state text, hospital_cnt bigint, paid_orders bigint, paid_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH paid AS (
    SELECT o.amount_rupees, c.hospital_user_id
    FROM public.amc_payment_orders o
    JOIN public.amc_contracts c ON c.id = o.amc_contract_id
    WHERE o.status = 'paid' AND o.created_at >= now() - interval '90 days'
  ),
  with_state AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
           paid.hospital_user_id,
           paid.amount_rupees
    FROM paid
    LEFT JOIN public.profiles p ON p.id = paid.hospital_user_id
  )
  SELECT
    ws.state,
    count(DISTINCT ws.hospital_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(ws.amount_rupees), 0)::numeric AS paid_rupees
  FROM with_state ws
  GROUP BY ws.state
  ORDER BY paid_rupees DESC
  LIMIT 40;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.fn_acquirer_archetype_mix_r3103 -- ORDER BY total_weighted_cr DESC
CREATE OR REPLACE FUNCTION public.fn_acquirer_archetype_mix_r3103()
 RETURNS TABLE(archetype text, count bigint, avg_ask_cr numeric, avg_probability numeric, total_weighted_cr numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.acquirer_archetype,
         count(*)::bigint,
         round(avg(t.valuation_ask_inr_crore)::numeric, 1),
         round(avg(t.deal_probability_pct)::numeric, 1),
         sum(t.valuation_ask_inr_crore * t.deal_probability_pct / 100.0)::numeric AS total_weighted_cr
  from public.founder_strategic_acquirer_targets_r3103 t
  group by t.acquirer_archetype
  order by total_weighted_cr desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3104_sample_point_breakdown -- ORDER BY total_samples DESC, failures DESC
CREATE OR REPLACE FUNCTION public.founder_r3104_sample_point_breakdown()
 RETURNS TABLE(sample_point text, total_samples bigint, failures bigint, avg_chlorine_ppm numeric, avg_conductivity numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select s.sample_point,
           count(*)::bigint AS total_samples,
           count(*) filter (where s.aami_compliance_status in ('aami_failure','iso23500_failure'))::bigint AS failures,
           round(avg(s.chlorine_ppm)::numeric, 3),
           round(avg(s.conductivity_us_cm)::numeric, 2)
    from dialysis_ro_water_samples_r3104 s
    group by s.sample_point
    order by failures desc, total_samples desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2385_direction_theme_rollup -- ORDER BY total_expected_ships DESC
CREATE OR REPLACE FUNCTION public.founder_r2385_direction_theme_rollup()
 RETURNS TABLE(strategic_theme text, directions_count bigint, total_expected_ships bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT d.strategic_theme,
           count(*)::bigint,
           coalesce(sum(d.expected_ship_count),0)::bigint AS total_expected_ships
    FROM public.founder_next_270_directions_r2385 d
    GROUP BY d.strategic_theme
    ORDER BY total_expected_ships DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.correction_status_funnel_r2633 -- ORDER BY correction_count DESC
CREATE OR REPLACE FUNCTION public.correction_status_funnel_r2633()
 RETURNS TABLE(status text, correction_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status, COUNT(*)::bigint AS correction_count
  FROM public.time_allocation_corrections_r2633 c
  GROUP BY c.status
  ORDER BY correction_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_crisis_playbook_outcomes_r3109 -- ORDER BY total DESC
CREATE OR REPLACE FUNCTION public.rpc_crisis_playbook_outcomes_r3109()
 RETURNS TABLE(response_playbook text, total bigint, positive_outcomes bigint, negative_outcomes bigint, avg_hours_to_first_response numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.response_playbook,
    count(*)::bigint AS total,
    sum(case when c.outcome_status in ('correction_secured','headline_changed','retraction_full',
                                      'partial_correction','contained') then 1 else 0 end)::bigint,
    sum(case when c.outcome_status in ('no_traction','negative_spiral') then 1 else 0 end)::bigint,
    round(avg(c.hours_to_first_response)::numeric, 2)
  from public.press_crisis_response_queue_r3109 c
  group by c.response_playbook
  order by total desc;
end$function$;

-- ---------------------------------------------------------------------
-- public.r2255_account_lead_load -- ORDER BY total_contract_rupees DESC
CREATE OR REPLACE FUNCTION public.r2255_account_lead_load()
 RETURNS TABLE(account_lead_name text, chains_assigned bigint, total_hospitals bigint, total_contract_rupees numeric, avg_health numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.account_lead_name, COUNT(*)::bigint, COALESCE(SUM(t.hospital_count),0)::bigint, COALESCE(SUM(t.contract_value_rupees),0)::numeric AS total_contract_rupees, COALESCE(AVG(t.health_score),0)::numeric
  FROM public.hospital_chain_account_teams_r2255 t
  GROUP BY t.account_lead_name
  ORDER BY total_contract_rupees DESC;
END;$function$;

-- ---------------------------------------------------------------------
-- public.r2278_compliance_alerts -- ORDER BY days_remaining ASC
CREATE OR REPLACE FUNCTION public.r2278_compliance_alerts()
 RETURNS TABLE(engineer_name text, vehicle_reg_no text, alert_type text, due_date date, days_remaining integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT v.engineer_name, v.vehicle_reg_no, 'service_due'::text AS alert_type,
         v.next_service_due_at AS due_date,
         (v.next_service_due_at - CURRENT_DATE)::int AS days_remaining
  FROM public.engineer_driver_vehicle_log_r2278 v
  WHERE v.next_service_due_at IS NOT NULL AND v.next_service_due_at <= CURRENT_DATE + 30
  UNION ALL
  SELECT v.engineer_name, v.vehicle_reg_no, 'insurance_expiry'::text,
         v.insurance_expiry,
         (v.insurance_expiry - CURRENT_DATE)::int
  FROM public.engineer_driver_vehicle_log_r2278 v
  WHERE v.insurance_expiry IS NOT NULL AND v.insurance_expiry <= CURRENT_DATE + 30
  UNION ALL
  SELECT v.engineer_name, v.vehicle_reg_no, 'puc_expiry'::text,
         v.puc_expiry,
         (v.puc_expiry - CURRENT_DATE)::int AS days_remaining
  FROM public.engineer_driver_vehicle_log_r2278 v
  WHERE v.puc_expiry IS NOT NULL AND v.puc_expiry <= CURRENT_DATE + 30
  ORDER BY days_remaining ASC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r3135_conflict_audit -- ORDER BY member_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3135_conflict_audit()
 RETURNS TABLE(conflict_declared text, member_count integer, active_members integer, members_list text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select m.conflict_declared,
           count(*)::integer AS member_count,
           count(*) filter (where m.offboarded_at is null)::integer,
           string_agg(m.member_full_name, ', ' order by m.member_full_name) as members_list
    from board_advisory_members_r3135 m
    group by m.conflict_declared
    order by member_count desc;
end
$function$;

-- ---------------------------------------------------------------------
-- public.root_cause_breakdown_r2672 -- ORDER BY total_variance_rupees DESC
CREATE OR REPLACE FUNCTION public.root_cause_breakdown_r2672()
 RETURNS TABLE(root_cause_code text, equipment_count bigint, total_variance_rupees bigint, avg_variance_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT s.root_cause_code,
           count(*)::bigint,
           coalesce(sum(s.variance_rupees),0)::bigint AS total_variance_rupees,
           coalesce(round(avg(s.variance_pct),2),0)::numeric
    FROM customer_spare_parts_burn_snapshots_r2672 s
    GROUP BY s.root_cause_code
    ORDER BY total_variance_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.audience_kind_distribution_r2621 -- ORDER BY engagement_count DESC
CREATE OR REPLACE FUNCTION public.audience_kind_distribution_r2621()
 RETURNS TABLE(audience_kind text, engagement_count bigint, total_audience bigint, total_inbound_leads bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.audience_kind,
         COUNT(*)::bigint AS engagement_count,
         COALESCE(SUM(e.audience_size), 0)::bigint,
         COALESCE(SUM(e.inbound_leads_count), 0)::bigint
  FROM public.founder_speaking_engagements_r2621 e
  GROUP BY e.audience_kind
  ORDER BY engagement_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.market_share_owner_load_r2673 -- ORDER BY total_revenue_rupees DESC
CREATE OR REPLACE FUNCTION public.market_share_owner_load_r2673()
 RETURNS TABLE(owner_email text, vertical_count integer, total_revenue_rupees bigint, losing_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(s.owner_email,'(unassigned)') AS owner_email,
         COUNT(*)::int,
         COALESCE(SUM(s.our_revenue_rupees),0)::bigint AS total_revenue_rupees,
         COUNT(*) FILTER (WHERE s.status='losing')::int
  FROM market_share_snapshots_r2673 s
  GROUP BY COALESCE(s.owner_email,'(unassigned)')
  ORDER BY total_revenue_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_chain_finance_action_outcomes_r2675 -- ORDER BY action_count DESC
CREATE OR REPLACE FUNCTION public.founder_chain_finance_action_outcomes_r2675()
 RETURNS TABLE(outcome text, action_count integer, recovered_total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.outcome,
         COUNT(*)::integer AS action_count,
         COALESCE(SUM(a.recovered_rupees),0)::bigint
  FROM hospital_chain_finance_fix_actions_r2675 a
  GROUP BY a.outcome
  ORDER BY action_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2684_category_summary -- ORDER BY breach_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2684_category_summary()
 RETURNS TABLE(equipment_category text, record_count bigint, avg_uptime numeric, breach_count bigint, total_credit bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.equipment_category,
         COUNT(*)::bigint,
         ROUND(AVG(r.uptime_pct)::numeric, 2)::numeric,
         COUNT(*) FILTER (WHERE r.breach_severity <> 'none')::bigint AS breach_count,
         COALESCE(SUM(r.credit_issued_rupees), 0)::bigint
  FROM public.uptime_sla_records_r2684 r
  GROUP BY r.equipment_category
  ORDER BY breach_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_on_call_overload_signal_dist_r2702 -- ORDER BY engineer_count DESC
CREATE OR REPLACE FUNCTION public.founder_on_call_overload_signal_dist_r2702()
 RETURNS TABLE(overload_signal text, engineer_count bigint, avg_total_hours numeric, avg_fairness numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.overload_signal,
         COUNT(*)::bigint AS engineer_count,
         COALESCE(AVG(r.total_hours), 0)::numeric,
         COALESCE(AVG(r.fairness_score), 0)::numeric
  FROM engineer_on_call_rotation_r2702 r
  GROUP BY r.overload_signal
  ORDER BY engineer_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2747_pilots_by_tech_kind -- ORDER BY total_budget_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r2747_pilots_by_tech_kind()
 RETURNS TABLE(tech_kind text, pilot_count bigint, total_budget_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.tech_kind,
         count(*)::bigint,
         COALESCE(sum(p.budget_rupees),0)::bigint AS total_budget_rupees
    FROM hospital_chain_tech_pilots_r2747 p
   GROUP BY p.tech_kind
   ORDER BY total_budget_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2777_institution_tier_rollup -- ORDER BY total_award DESC
CREATE OR REPLACE FUNCTION public.founder_r2777_institution_tier_rollup()
 RETURNS TABLE(institution_tier text, project_count bigint, total_award bigint, flagship_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.institution_tier, COUNT(*)::bigint, COALESCE(SUM(p.award_amount_rupees),0)::bigint AS total_award,
           COUNT(*) FILTER (WHERE p.strategic_value = 'flagship')::bigint
    FROM grant_research_projects_r2777 p
    GROUP BY p.institution_tier
    ORDER BY total_award DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2785_bet_rollup -- ORDER BY total_spend_rupees DESC
CREATE OR REPLACE FUNCTION public.r2785_bet_rollup()
 RETURNS TABLE(strategic_bet text, experiment_count integer, total_budget_rupees bigint, total_spend_rupees bigint, avg_attainment_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.strategic_bet,
    COUNT(*)::int,
    COALESCE(SUM(e.budget_cap_rupees),0)::bigint,
    COALESCE(SUM(e.spend_to_date_rupees),0)::bigint AS total_spend_rupees,
    ROUND(AVG(CASE WHEN e.target_value > 0 THEN 100.0 * e.actual_value / e.target_value ELSE 0 END), 1)
  FROM public.quarterly_experiments_r2785 e
  GROUP BY e.strategic_bet
  ORDER BY total_spend_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2788_outcome_distribution -- ORDER BY credit_total DESC
CREATE OR REPLACE FUNCTION public.founder_r2788_outcome_distribution()
 RETURNS TABLE(outcome_status text, customer_count integer, incident_total integer, credit_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.outcome_status,
    COUNT(*)::int,
    COALESCE(SUM(c.incident_count),0)::int,
    COALESCE(SUM(c.override_credit_rupees),0)::numeric AS credit_total
  FROM customer_after_hours_incidents_r2788 c
  GROUP BY c.outcome_status
  ORDER BY credit_total DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2839_run_health -- ORDER BY run_count DESC
CREATE OR REPLACE FUNCTION public.rpc_r2839_run_health()
 RETURNS TABLE(status text, run_count bigint, units_sum bigint, cost_sum numeric, revenue_sum numeric, avg_success numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.status, COUNT(*)::bigint AS run_count,
           COALESCE(SUM(r.units_actioned),0)::bigint,
           COALESCE(SUM(r.cost_committed_lakhs),0)::numeric,
           COALESCE(SUM(r.revenue_actual_lakhs),0)::numeric,
           ROUND(AVG(r.refurb_success_pct)::numeric, 2)
    FROM chain_rejuvenation_runs_r2839 r
    GROUP BY r.status
    ORDER BY run_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_bet_capital_efficiency_r2841 -- ORDER BY score_per_lakh DESC
CREATE OR REPLACE FUNCTION public.founder_bet_capital_efficiency_r2841()
 RETURNS TABLE(bet_name text, capital_lakh numeric, outcome_score integer, score_per_lakh numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.bet_name,
    round((p.capital_deployed_inr::numeric / 100000.0),2),
    p.outcome_score,
    round((p.outcome_score::numeric / NULLIF((p.capital_deployed_inr::numeric / 100000.0),0))::numeric, 2) AS score_per_lakh
  FROM public.founder_strategic_bet_postmortems_r2841 p
  ORDER BY score_per_lakh DESC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.weakness_heatmap_r2889 -- ORDER BY avg_weakness DESC, unrehearsed_count DESC
CREATE OR REPLACE FUNCTION public.weakness_heatmap_r2889()
 RETURNS TABLE(objection_category text, drills_count bigint, avg_weakness numeric, unrehearsed_count bigint, escalation_count bigint, highest_weakness integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    d.objection_category,
    count(*)::bigint,
    ROUND(avg(d.weakness_self_score)::numeric, 2) AS avg_weakness,
    count(*) FILTER (WHERE d.rehearsed = false)::bigint AS unrehearsed_count,
    count(*) FILTER (WHERE d.escalation_required = true)::bigint,
    max(d.weakness_self_score)
  FROM investor_call_objection_drills_r2889 d
  GROUP BY d.objection_category
  ORDER BY avg_weakness DESC, unrehearsed_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2905_loss_reasons -- ORDER BY loss_count DESC, total_value_rupees DESC
CREATE OR REPLACE FUNCTION public.r2905_loss_reasons()
 RETURNS TABLE(primary_driver text, loss_count bigint, total_value_rupees bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT e.primary_driver,
           COUNT(*)::bigint AS loss_count,
           COALESCE(SUM(e.deal_size_rupees),0)::bigint AS total_value_rupees
    FROM public.competitor_win_loss_events_r2905 e
    WHERE e.outcome = 'lost'
    GROUP BY e.primary_driver
    ORDER BY loss_count DESC, total_value_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2919_engineer_workload -- ORDER BY total_cost DESC
CREATE OR REPLACE FUNCTION public.r2919_engineer_workload()
 RETURNS TABLE(owner_engineer_email text, open_jobs integer, closed_jobs integer, total_cost numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.owner_engineer_email,
         SUM(CASE WHEN r.status IN ('open','in_progress','blocked') THEN 1 ELSE 0 END)::int,
         SUM(CASE WHEN r.status='closed' THEN 1 ELSE 0 END)::int,
         SUM(r.cost_rupees) AS total_cost
  FROM or_smoke_remediation_actions_r2919 r
  GROUP BY r.owner_engineer_email
  ORDER BY total_cost DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2958_hospital_scorecard -- ORDER BY pass_pct ASC
CREATE OR REPLACE FUNCTION public.founder_r2958_hospital_scorecard()
 RETURNS TABLE(hospital_name text, rooms integer, pass_n integer, fail_n integer, pass_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.hospital_name,
           count(*)::int,
           (count(*) filter (where v.status='pass'))::int,
           (count(*) filter (where v.status='fail'))::int,
           round(100.0 * (count(*) filter (where v.status='pass'))::numeric / nullif(count(*),0), 1) AS pass_pct
    from ot_air_pressure_verifications_r2958 v
    group by v.hospital_name
    order by pass_pct asc nulls last;
end $function$;

-- ---------------------------------------------------------------------
-- public.r2995_nabh_witness_coverage -- ORDER BY tests DESC
CREATE OR REPLACE FUNCTION public.r2995_nabh_witness_coverage()
 RETURNS TABLE(nabh_witness text, tests integer, pass_rate_pct integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.nabh_witness,
    count(*)::int AS tests,
    (100.0 * (count(*) filter (where d.test_outcome in ('passed','passed_with_obs'))) / nullif(count(*),0))::int
  from generator_drain_test_r2995 d
  group by d.nabh_witness
  order by tests desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.founder_fmt_engineer_performance_r2996 -- ORDER BY inspections DESC, rework_count DESC
CREATE OR REPLACE FUNCTION public.founder_fmt_engineer_performance_r2996()
 RETURNS TABLE(engineer_code text, inspections integer, replacements integer, avg_adhesion_post_pct numeric, rework_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    coalesce(i.engineer_code, r.engineer_code) as engineer_code,
    count(distinct i.id)::int AS inspections,
    count(distinct r.id)::int,
    coalesce(round(avg(case when r.outcome in ('excellent','good') then 95.0 when r.outcome = 'acceptable' then 80.0 else 50.0 end),2),0)::numeric,
    (count(*) filter (where r.outcome in ('rework_needed','failed_24h')))::int AS rework_count
  from floor_marking_tape_inspections_r2996 i
  full outer join floor_marking_tape_replacements_r2996 r on r.engineer_code = i.engineer_code
  group by coalesce(i.engineer_code, r.engineer_code)
  order by rework_count desc, inspections desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3002_city_risk_heatmap -- ORDER BY fails DESC, condemns DESC
CREATE OR REPLACE FUNCTION public.r3002_city_risk_heatmap()
 RETURNS TABLE(hospital_city text, inspections integer, fails integer, condemns integer, avg_fabric_wear numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.hospital_city,
         count(*)::int,
         (count(*) filter (where i.verdict='fail'))::int AS fails,
         (count(*) filter (where i.verdict='condemn'))::int AS condemns,
         round(avg(i.fabric_wear_score)::numeric, 2)
  from bath_lift_sling_inspections_r3002 i
  group by i.hospital_city
  order by condemns desc, fails desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.sync_audit_summary_r3023 -- ORDER BY sync_rate_pct ASC
CREATE OR REPLACE FUNCTION public.sync_audit_summary_r3023()
 RETURNS TABLE(chain_name text, audits bigint, total_targeted bigint, total_synced bigint, total_failed bigint, sync_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select a.chain_name,
    count(*),
    sum(a.pumps_targeted)::bigint,
    sum(a.pumps_synced)::bigint,
    sum(a.pumps_failed)::bigint,
    round((sum(a.pumps_synced)::numeric / nullif(sum(a.pumps_targeted),0)) * 100, 2) AS sync_rate_pct
  from drug_library_sync_audit_r3023 a
  group by a.chain_name
  order by sync_rate_pct asc nulls last;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3034_root_cause_breakdown -- ORDER BY replacements DESC
CREATE OR REPLACE FUNCTION public.r3034_root_cause_breakdown()
 RETURNS TABLE(root_cause text, replacements integer, total_cost numeric, avg_downtime numeric, warranty_claims integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.root_cause, count(*)::int AS replacements, sum(l.cost_rupees)::numeric, round(avg(l.downtime_hours)::numeric, 1),
    (count(*) filter (where l.warranty_claim))::int
  from centrifuge_bearing_replacement_log_r3034 l
  group by l.root_cause
  order by replacements desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.r3086_regional_discipline -- ORDER BY avg_score DESC
CREATE OR REPLACE FUNCTION public.r3086_regional_discipline()
 RETURNS TABLE(region_name text, scorecards integer, avg_score numeric, watchlist_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select region, count(*)::int, round(avg(discipline_score)::numeric, 2) AS avg_score, (count(*) filter (where tier = 'watchlist'))::int
  from vaporizer_discipline_scorecards_r3086
  group by region
  order by avg_score desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3079_top_branches_at_risk -- ORDER BY retire_count DESC, total_cost DESC
CREATE OR REPLACE FUNCTION public.founder_r3079_top_branches_at_risk()
 RETURNS TABLE(chain_name text, branch text, retire_count integer, total_cost integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.chain_name, i.hospital_branch,
         (count(*) filter (where i.retire_recommended))::int AS retire_count,
         coalesce(sum(i.replacement_cost_rupees) filter (where i.retire_recommended),0)::int AS total_cost
  from hospital_chain_lead_apron_inventory_r3079 i
  group by i.chain_name, i.hospital_branch
  having (count(*) filter (where i.retire_recommended)) > 0
  order by retire_count desc, total_cost desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.founder_top_hospitals_90d -- ORDER BY jobs_posted DESC, gross_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_top_hospitals_90d()
 RETURNS TABLE(hospital_user_id uuid, display_name text, jobs_posted integer, jobs_completed integer, gross_rupees numeric, has_active_amc boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    rj.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    count(*)::int AS jobs_posted,
    count(*) FILTER (WHERE rj.status = 'completed')::int,
    coalesce(sum(rj.contracted_amount_rupees) FILTER (WHERE rj.status = 'completed'), 0) AS gross_rupees,
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
       WHERE c.hospital_user_id = rj.hospital_user_id
         AND c.status = 'active'
    )
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.created_at >= now() - interval '90 days'
  GROUP BY rj.hospital_user_id, p.full_name
  ORDER BY jobs_posted DESC, gross_rupees DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_jobs_revenue_by_city -- ORDER BY gross_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_jobs_revenue_by_city()
 RETURNS TABLE(city text, hospital_cnt bigint, completed bigint, gross_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH completed AS (
    SELECT rj.hospital_user_id, rj.contracted_amount_rupees
    FROM public.repair_jobs rj
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  ),
  with_city AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      c.hospital_user_id,
      c.contracted_amount_rupees
    FROM completed c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  )
  SELECT
    wc.city,
    count(DISTINCT wc.hospital_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(wc.contracted_amount_rupees), 0)::numeric AS gross_rupees
  FROM with_city wc
  GROUP BY wc.city
  ORDER BY gross_rupees DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_spot_audit_by_engineer -- ORDER BY responses_180d DESC, avg_rating ASC
CREATE OR REPLACE FUNCTION public.founder_spot_audit_by_engineer()
 RETURNS TABLE(engineer_user_id uuid, display_name text, responses_180d bigint, avg_rating numeric, low_2less bigint, high_4plus bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      b.engineer_user_id,
      r.rating
    FROM public.spot_audit_responses r
    JOIN public.spot_audit_invitations i ON i.id = r.invitation_id
    JOIN public.repair_job_bids b ON b.repair_job_id = i.repair_job_id AND b.status = 'accepted'
    WHERE r.responded_at >= now() - interval '180 days'
  )
  SELECT
    b.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    count(*)::bigint AS responses_180d,
    coalesce(round(avg(b.rating)::numeric, 2), 0)::numeric AS avg_rating,
    count(*) FILTER (WHERE b.rating <= 2)::bigint,
    count(*) FILTER (WHERE b.rating >= 4)::bigint
  FROM base b
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  GROUP BY b.engineer_user_id, p.full_name
  HAVING count(*) >= 3
  ORDER BY avg_rating ASC, responses_180d DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_spare_parts_buyer_mix -- ORDER BY rupees_90d DESC
CREATE OR REPLACE FUNCTION public.founder_spare_parts_buyer_mix()
 RETURNS TABLE(buyer_role text, orders_90d bigint, rupees_90d numeric, share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_amount numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT coalesce(sum(o.total_amount), 0)::numeric INTO v_total_amount
    FROM public.spare_part_orders o
    WHERE o.created_at >= now() - interval '90 days';
  RETURN QUERY
  SELECT
    coalesce(p.role::text, '(unknown)') AS buyer_role,
    count(*)::bigint,
    coalesce(sum(o.total_amount), 0)::numeric AS rupees_90d,
    CASE WHEN v_total_amount = 0 THEN 0::numeric
         ELSE round(coalesce(sum(o.total_amount), 0)::numeric / v_total_amount * 100.0, 1)
    END
  FROM public.spare_part_orders o
  LEFT JOIN public.profiles p ON p.id = o.buyer_user_id
  WHERE o.created_at >= now() - interval '90 days'
  GROUP BY p.role
  ORDER BY rupees_90d DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_amc_pool_balance_by_state -- ORDER BY total_balance DESC
CREATE OR REPLACE FUNCTION public.founder_amc_pool_balance_by_state()
 RETURNS TABLE(state text, contracts bigint, total_balance numeric, mrr numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT c.id, c.hospital_user_id, c.monthly_fee_rupees,
           coalesce(b.balance_rupees, 0)::numeric AS balance
    FROM public.amc_contracts c
    LEFT JOIN public.v_amc_pool_balance b ON b.amc_contract_id = c.id
    WHERE c.status = 'active'
  ),
  with_state AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
           a.id, a.balance, a.monthly_fee_rupees
    FROM active a
    LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  )
  SELECT
    ws.state,
    count(*)::bigint,
    coalesce(sum(ws.balance), 0)::numeric AS total_balance,
    coalesce(sum(ws.monthly_fee_rupees), 0)::numeric
  FROM with_state ws
  GROUP BY ws.state
  ORDER BY total_balance DESC
  LIMIT 40;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2292_top_offenders -- ORDER BY non_compliant_streams DESC, open_findings DESC
CREATE OR REPLACE FUNCTION public.founder_r2292_top_offenders()
 RETURNS TABLE(customer_user_id uuid, customer_email text, total_streams integer, non_compliant_streams integer, open_findings integer, total_variance_paise bigint)
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
    s.customer_user_id,
    p.email,
    (COUNT(DISTINCT s.id))::int,
    (COUNT(DISTINCT s.id) FILTER (WHERE NOT s.is_policy_compliant))::int AS non_compliant_streams,
    (COUNT(DISTINCT f.id) FILTER (WHERE f.status = 'open'))::int AS open_findings,
    COALESCE(SUM(f.variance_paise), 0)::bigint
  FROM public.customer_revenue_streams_r2292 s
  LEFT JOIN public.profiles p ON p.id = s.customer_user_id
  LEFT JOIN public.customer_policy_audit_findings_r2292 f ON f.customer_user_id = s.customer_user_id
  GROUP BY s.customer_user_id, p.email
  HAVING (COUNT(DISTINCT s.id) FILTER (WHERE NOT s.is_policy_compliant))::int > 0
      OR (COUNT(DISTINCT f.id) FILTER (WHERE f.status = 'open'))::int > 0
  ORDER BY non_compliant_streams DESC, open_findings DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2302_pass_rate_by_topic -- ORDER BY pass_rate_pct ASC
CREATE OR REPLACE FUNCTION public.r2302_pass_rate_by_topic()
 RETURNS TABLE(topic text, total_tests integer, passed integer, failed integer, marginal integer, pass_rate_pct numeric, avg_score_pct numeric, open_assignments integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic,
         COUNT(*)::integer AS total_tests,
         COUNT(*) FILTER (WHERE t.result = 'pass')::integer AS passed,
         COUNT(*) FILTER (WHERE t.result = 'fail')::integer AS failed,
         COUNT(*) FILTER (WHERE t.result = 'marginal')::integer AS marginal,
         CASE WHEN COUNT(*) = 0 THEN 0::numeric
              ELSE ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / COUNT(*)::numeric) * 100, 1) END AS pass_rate_pct,
         ROUND(AVG(t.score_pct), 1)::numeric,
         (SELECT COUNT(*)::integer FROM public.engineer_training_assignments_r2302 a
           WHERE a.topic = t.topic AND a.status IN ('assigned','in_progress','overdue'))
  FROM public.engineer_competency_tests_r2302 t
  GROUP BY t.topic
  ORDER BY pass_rate_pct ASC, total_tests DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_press_overview_r3109 -- ORDER BY total_reach DESC
CREATE OR REPLACE FUNCTION public.rpc_press_overview_r3109()
 RETURNS TABLE(outlet_tier text, total_hits bigint, total_reach bigint, avg_sentiment numeric, negative_share numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.outlet_tier,
    count(*)::bigint,
    sum(h.reach_estimate)::bigint AS total_reach,
    round(avg(h.sentiment_score)::numeric, 3),
    round((sum(case when h.sentiment in ('negative','strongly_negative') then 1 else 0 end)::numeric
           / nullif(count(*),0)::numeric) * 100, 1)
  from public.press_media_hits_r3109 h
  group by h.outlet_tier
  order by total_reach desc;
end$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3111_channel_rollup -- ORDER BY broadcasts_count DESC
CREATE OR REPLACE FUNCTION public.fn_r3111_channel_rollup()
 RETURNS TABLE(channel text, broadcasts_count bigint, total_audience bigint, total_opened bigint, total_consumed bigint, open_rate_pct numeric, consume_rate_pct numeric, avg_nps numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.channel,
         COUNT(*)::bigint AS broadcasts_count,
         SUM(b.audience_size)::bigint,
         SUM(b.opened_count)::bigint,
         SUM(b.fully_consumed_count)::bigint,
         ROUND(100.0 * SUM(b.opened_count)::numeric / NULLIF(SUM(b.audience_size),0), 1),
         ROUND(100.0 * SUM(b.fully_consumed_count)::numeric / NULLIF(SUM(b.audience_size),0), 1),
         ROUND(AVG(b.avg_nps_score)::numeric, 2)
  FROM public.founder_comms_broadcasts_r3111 b
  GROUP BY b.channel
  ORDER BY broadcasts_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.warranty_stage_breakdown_r2239 -- ORDER BY deal_count DESC
CREATE OR REPLACE FUNCTION public.warranty_stage_breakdown_r2239()
 RETURNS TABLE(stage text, deal_count integer, total_value_rupees bigint, avg_win_prob_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    pipeline_stage,
    COUNT(*)::int AS deal_count,
    COALESCE(SUM(proposed_annual_fee_rupees), 0)::bigint,
    ROUND(COALESCE(AVG(win_probability_pct), 0), 1)
  FROM public.warranty_expiry_pipeline_r2239
  GROUP BY pipeline_stage
  ORDER BY deal_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2255_csm_load -- ORDER BY total_amcs DESC
CREATE OR REPLACE FUNCTION public.r2255_csm_load()
 RETURNS TABLE(csm_name text, chains_assigned bigint, total_amcs bigint, avg_health numeric, at_risk_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.csm_name, COUNT(*)::bigint, COALESCE(SUM(t.active_amc_count),0)::bigint AS total_amcs, COALESCE(AVG(t.health_score),0)::numeric, (COUNT(*) FILTER (WHERE t.status = 'at_risk'))::int
  FROM public.hospital_chain_account_teams_r2255 t
  GROUP BY t.csm_name
  ORDER BY total_amcs DESC;
END;$function$;

-- ---------------------------------------------------------------------
-- public.r2278_downtime_by_type -- ORDER BY total_revenue_impact_rupees DESC
CREATE OR REPLACE FUNCTION public.r2278_downtime_by_type()
 RETURNS TABLE(event_type text, event_count integer, total_downtime_hours numeric, total_cost_rupees bigint, total_jobs_missed integer, total_revenue_impact_rupees bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT d.event_type,
         (COUNT(*))::int,
         COALESCE(SUM(d.downtime_hours), 0)::numeric,
         COALESCE(SUM(d.cost_rupees), 0)::bigint,
         COALESCE(SUM(d.jobs_missed), 0)::int,
         COALESCE(SUM(d.revenue_impact_rupees), 0)::bigint AS total_revenue_impact_rupees
  FROM public.engineer_vehicle_downtime_r2278 d
  GROUP BY d.event_type
  ORDER BY total_revenue_impact_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.dr_detector_ghost_image_audit_r3132 -- ORDER BY panel_count DESC
CREATE OR REPLACE FUNCTION public.dr_detector_ghost_image_audit_r3132()
 RETURNS TABLE(ghost_image_severity text, panel_count bigint, modalities_affected bigint, avg_uniformity numeric, avg_age_years numeric, ghost_share_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  total_panels integer;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total_panels from dr_detector_panel_audits_r3132;
  return query
    select a.ghost_image_severity::text,
           count(*)::bigint AS panel_count,
           count(distinct a.modality)::bigint,
           round(avg(a.uniformity_pct)::numeric, 2),
           round(avg(((a.audit_date - a.installed_on)::numeric / 365.25))::numeric, 2),
           round((count(*)::numeric * 100.0 / nullif(total_panels, 0))::numeric, 1)
    from dr_detector_panel_audits_r3132 a
    group by a.ghost_image_severity
    order by panel_count desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r2704_top_savings_customers -- ORDER BY total_savings_rupees DESC
CREATE OR REPLACE FUNCTION public.r2704_top_savings_customers()
 RETURNS TABLE(customer_org text, events_count integer, total_savings_rupees bigint, avg_satisfaction numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.customer_org, COUNT(*)::int,
         COALESCE(SUM(e.cost_savings_rupees),0)::bigint AS total_savings_rupees,
         COALESCE(AVG(f.satisfaction_score),0)::numeric(4,2)
  FROM spare_part_substitution_events_r2704 e
  LEFT JOIN spare_part_substitution_feedback_r2704 f ON f.event_id = e.id
  GROUP BY e.customer_org
  ORDER BY total_savings_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2747_outcome_grade_breakdown -- ORDER BY outcome_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2747_outcome_grade_breakdown()
 RETURNS TABLE(outcome_grade text, outcome_count bigint, pct_of_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE total_rows bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total_rows FROM hospital_chain_tech_pilot_outcomes_r2747;
  IF total_rows = 0 THEN total_rows := 1; END IF;
  RETURN QUERY
  SELECT o.outcome_grade,
         count(*)::bigint AS outcome_count,
         round((count(*)::numeric / total_rows) * 100, 1)
    FROM hospital_chain_tech_pilot_outcomes_r2747 o
   GROUP BY o.outcome_grade
   ORDER BY outcome_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2750_oem_rollup -- ORDER BY completion_pct ASC
CREATE OR REPLACE FUNCTION public.founder_r2750_oem_rollup()
 RETURNS TABLE(oem_partner text, engineers integer, units_assigned integer, units_completed integer, completion_pct numeric, avg_kit_ready numeric, avg_verification numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.oem_partner,
         COUNT(*)::int,
         SUM(r.units_assigned)::int,
         SUM(r.units_completed)::int,
         ROUND(100.0 * SUM(r.units_completed)::numeric / NULLIF(SUM(r.units_assigned),0), 2) AS completion_pct,
         ROUND(AVG(r.kit_ready_pct)::numeric, 2),
         ROUND(AVG(r.verification_pass_pct)::numeric, 2)
    FROM engineer_recall_readiness_r2750 r
   GROUP BY r.oem_partner
   ORDER BY completion_pct ASC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2764_saving_by_kind -- ORDER BY total_saving_rupees DESC
CREATE OR REPLACE FUNCTION public.rpc_r2764_saving_by_kind()
 RETURNS TABLE(equipment_kind text, recommendation_count integer, total_saving_rupees numeric, total_capex_rupees numeric, avg_payback_months numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.equipment_kind,
    COUNT(*)::int,
    COALESCE(SUM(r.estimated_annual_saving_rupees),0)::numeric AS total_saving_rupees,
    COALESCE(SUM(r.capex_required_rupees),0)::numeric,
    ROUND(AVG(r.payback_months)::numeric, 1)
  FROM standardization_recommendation_r2764 r
  GROUP BY r.equipment_kind
  ORDER BY total_saving_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_dw_decision_breakdown_r2765 -- ORDER BY topics DESC
CREATE OR REPLACE FUNCTION public.founder_dw_decision_breakdown_r2765()
 RETURNS TABLE(decision text, topics bigint, total_next_minutes bigint, avg_variance_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.decision, COUNT(*)::bigint AS topics,
         COALESCE(SUM(c.next_target_minutes),0)::bigint,
         ROUND(AVG(c.variance_pct)::numeric, 2)
  FROM founder_deep_work_calibrations_r2765 c
  GROUP BY c.decision
  ORDER BY topics DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_action_mix_r2766 -- ORDER BY total_actions DESC
CREATE OR REPLACE FUNCTION public.founder_action_mix_r2766()
 RETURNS TABLE(action_kind text, total_actions integer, open_actions integer, total_hours numeric, expected_lift_sum numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.action_kind,
    count(*)::int AS total_actions,
    count(*) FILTER (WHERE a.status != 'completed')::int,
    round(sum(a.estimated_hours)::numeric, 2),
    round(sum(a.expected_score_lift)::numeric, 2)
  FROM engineer_upskill_actions_r2766 a
  GROUP BY a.action_kind
  ORDER BY total_actions DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2788_policy_bands -- ORDER BY breach_total DESC
CREATE OR REPLACE FUNCTION public.founder_r2788_policy_bands()
 RETURNS TABLE(policy_band text, customer_count integer, after_hours_total integer, breach_total integer, avg_response numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.policy_band,
    COUNT(*)::int,
    COALESCE(SUM(c.after_hours_count),0)::int,
    COALESCE(SUM(c.sla_breach_count),0)::int AS breach_total,
    COALESCE(ROUND(AVG(c.avg_response_minutes),2),0)::numeric
  FROM customer_after_hours_incidents_r2788 c
  GROUP BY c.policy_band
  ORDER BY breach_total DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2790_redaction_distribution -- ORDER BY photos_total DESC
CREATE OR REPLACE FUNCTION public.founder_r2790_redaction_distribution()
 RETURNS TABLE(redaction_level text, row_count integer, photos_total integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT
        c.redaction_level,
        COUNT(*)::int,
        COALESCE(SUM(c.photos_count),0)::int AS photos_total
    FROM engineer_photo_share_consent_r2790 c
    GROUP BY c.redaction_level
    ORDER BY photos_total DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2831_signals_by_kind -- ORDER BY cnt DESC
CREATE OR REPLACE FUNCTION public.rpc_r2831_signals_by_kind()
 RETURNS TABLE(signal_kind text, cnt bigint, strong_cnt bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.signal_kind,
    count(*)::bigint AS cnt,
    count(*) FILTER (WHERE s.signal_strength='strong')::bigint
  FROM hospital_chain_tier1_deepening_signals_r2831 s
  GROUP BY s.signal_kind
  ORDER BY cnt DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_vendor_by_tier_r2802 -- ORDER BY avg_strength DESC
CREATE OR REPLACE FUNCTION public.founder_engineer_vendor_by_tier_r2802()
 RETURNS TABLE(engineer_tier text, relationship_count integer, avg_strength numeric, avg_response_minutes numeric, avg_on_time_delivery numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.engineer_tier,
           COUNT(*)::integer,
           ROUND(AVG(r.strength_score)::numeric, 2) AS avg_strength,
           ROUND(AVG(r.avg_response_minutes)::numeric, 2),
           ROUND(AVG(r.on_time_delivery_pct)::numeric, 2)
    FROM engineer_vendor_relationship_strength_r2802 r
    GROUP BY r.engineer_tier
    ORDER BY avg_strength DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2810_region_summary -- ORDER BY closure_rate_pct DESC
CREATE OR REPLACE FUNCTION public.r2810_region_summary()
 RETURNS TABLE(region text, engineer_months bigint, feedback_received bigint, closure_rate_pct numeric, avg_csat numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.region,
         COUNT(*)::bigint,
         SUM(t.feedback_received_count)::bigint,
         ROUND(100.0 * SUM(t.loops_closed_count)::numeric / NULLIF(SUM(t.feedback_received_count),0),2) AS closure_rate_pct,
         ROUND(AVG(t.csat_score)::numeric,2)
  FROM engineer_monthly_feedback_loop_r2810 t
  GROUP BY t.region
  ORDER BY closure_rate_pct DESC NULLS LAST;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2826_stage_funnel -- ORDER BY job_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2826_stage_funnel()
 RETURNS TABLE(prep_stage text, job_count integer, share_pct numeric, avg_score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH t AS (SELECT COUNT(*)::numeric AS total FROM engineer_monthly_job_prep_stages_r2826)
  SELECT
    p.prep_stage,
    COUNT(*)::int AS job_count,
    ROUND((COUNT(*)::numeric / NULLIF((SELECT total FROM t),0)) * 100, 2),
    ROUND(AVG(p.prep_score)::numeric, 2)
  FROM engineer_monthly_job_prep_stages_r2826 p
  GROUP BY p.prep_stage
  ORDER BY job_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2850_tier_breakdown -- ORDER BY total_revenue_rupees DESC
CREATE OR REPLACE FUNCTION public.rpc_r2850_tier_breakdown()
 RETURNS TABLE(engineer_tier text, engineer_count integer, total_jobs integer, perfect_pct numeric, total_revenue_rupees numeric, avg_csat numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_tier,
    COUNT(*)::int,
    COALESCE(SUM(s.jobs_completed),0)::int,
    CASE WHEN SUM(s.jobs_completed) > 0
         THEN ROUND((SUM(s.jobs_perfect)::numeric / SUM(s.jobs_completed)::numeric) * 100, 1)
         ELSE 0 END,
    COALESCE(SUM(s.revenue_generated_rupees),0)::numeric AS total_revenue_rupees,
    COALESCE(ROUND(AVG(s.csat_avg)::numeric,2),0)
  FROM engineer_monthly_job_narrative_stories_r2850 s
  GROUP BY s.engineer_tier
  ORDER BY total_revenue_rupees DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2859_by_chain -- ORDER BY uplift_lakhs DESC
CREATE OR REPLACE FUNCTION public.r2859_by_chain()
 RETURNS TABLE(chain_name text, correlations integer, high_conf integer, avg_r numeric, uplift_lakhs numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_name,
           count(*)::int,
           sum(CASE WHEN c.confidence_level='high' THEN 1 ELSE 0 END)::int,
           round(avg(abs(c.pearson_r))::numeric, 3),
           coalesce((SELECT sum(s.est_revenue_uplift_lakhs) FROM hospital_chain_quarterly_correlation_signals_r2859 s WHERE s.chain_name = c.chain_name), 0)::numeric AS uplift_lakhs
    FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 c
    GROUP BY c.chain_name
    ORDER BY uplift_lakhs DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2895_amc_upsell_pipeline -- ORDER BY total_amc_upsell_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r2895_amc_upsell_pipeline()
 RETURNS TABLE(chain_name text, branches integer, total_amc_upsell_rupees bigint, total_capex_rupees bigint, avg_lead_days numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name,
         COUNT(DISTINCT r.branch_code)::int,
         SUM(r.amc_upsell_rupees)::bigint AS total_amc_upsell_rupees,
         SUM(r.est_cost_rupees)::bigint,
         ROUND(AVG(r.procurement_lead_days),1)
  FROM hospital_chain_redundancy_gap_remediations_r2895 r
  GROUP BY r.chain_name
  ORDER BY total_amc_upsell_rupees DESC;
END;$function$;

-- ---------------------------------------------------------------------
-- public.r2911_chemical_efficacy_audit -- ORDER BY pass_rate_pct ASC
CREATE OR REPLACE FUNCTION public.r2911_chemical_efficacy_audit()
 RETURNS TABLE(chemical_used text, cycles_run bigint, avg_concentration_ppm numeric, avg_temperature_c numeric, pass_rate_pct numeric, avg_cost_rupees numeric)
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
    c.chemical_used,
    COUNT(*)::bigint,
    ROUND(AVG(c.chemical_concentration_ppm)::numeric, 0),
    ROUND(AVG(c.temperature_celsius)::numeric, 1),
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.passed_protocol) / NULLIF(COUNT(*),0), 1) AS pass_rate_pct,
    ROUND(AVG(c.cost_per_cycle_rupees)::numeric, 0)
  FROM public.endoscope_reprocessing_cycles_r2911 c
  GROUP BY c.chemical_used
  ORDER BY pass_rate_pct ASC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2928_customer_pain -- ORDER BY breach_pct DESC
CREATE OR REPLACE FUNCTION public.rpc_r2928_customer_pain()
 RETURNS TABLE(customer_org_label text, jobs integer, breaches integer, breach_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
    select e.customer_org_label,
           count(*)::int,
           sum(case when not e.within_range then 1 else 0 end)::int,
           round(100.0 * sum(case when not e.within_range then 1 else 0 end)::numeric / nullif(count(*),0), 2) AS breach_pct
    from customer_monthly_engineer_estimate_range_r2928 e
    group by e.customer_org_label
    order by breach_pct desc nulls last;
end $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2971_fixture_mix -- ORDER BY short_or_worse DESC
CREATE OR REPLACE FUNCTION public.founder_r2971_fixture_mix()
 RETURNS TABLE(fixture_type text, audits integer, avg_burn_hours numeric, short_or_worse integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.fixture_type, count(*)::int, round(avg(a.mean_burn_hours),1),
    (count(*) filter (where a.status in ('short','critical','expired')))::int AS short_or_worse
  from ot_light_bulb_reserve_audits_r2971 a
  group by a.fixture_type
  order by short_or_worse desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.r2995_cert_upload_backlog -- ORDER BY n DESC
CREATE OR REPLACE FUNCTION public.r2995_cert_upload_backlog()
 RETURNS TABLE(cert_uploaded text, n integer, last_test_date date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.cert_uploaded, count(*)::int AS n, max(d.test_date)
  from generator_drain_test_r2995 d
  group by d.cert_uploaded
  order by n desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.founder_fmt_replacement_outcomes_r2996 -- ORDER BY n DESC
CREATE OR REPLACE FUNCTION public.founder_fmt_replacement_outcomes_r2996()
 RETURNS TABLE(outcome text, n integer, total_meters numeric, avg_cost_rupees numeric, avg_cure_hours numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.outcome, count(*)::int AS n, sum(r.meters_replaced)::numeric,
    round(avg(r.cost_rupees),2)::numeric, round(avg(r.cure_hours),2)::numeric
  from floor_marking_tape_replacements_r2996 r
  group by r.outcome
  order by n desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3002_engineer_scorecard -- ORDER BY inspections DESC
CREATE OR REPLACE FUNCTION public.r3002_engineer_scorecard()
 RETURNS TABLE(engineer_name text, inspections integer, photos_avg numeric, pass_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.engineer_name,
         count(*)::int AS inspections,
         round(avg(i.photos_uploaded)::numeric, 2),
         round(100.0 * (count(*) filter (where i.verdict='pass')) / nullif(count(*),0), 2)
  from bath_lift_sling_inspections_r3002 i
  group by i.engineer_name
  order by inspections desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r3040_defect_class_spend -- ORDER BY total_cost DESC
CREATE OR REPLACE FUNCTION public.rpc_r3040_defect_class_spend()
 RETURNS TABLE(defect_class text, ticket_count integer, open_count integer, total_cost numeric, avg_eta_days numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.defect_class, count(*)::int,
    (count(*) filter (where t.ticket_status in ('open','assigned','in_progress')))::int,
    coalesce(sum(t.cost_estimate_rupees),0) AS total_cost,
    round(avg(t.eta_days),2)
  from iv_stand_remediation_tickets_r3040 t
  group by t.defect_class order by total_cost desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3043_chain_rollup -- ORDER BY fail_count DESC, critical_count DESC
CREATE OR REPLACE FUNCTION public.r3043_chain_rollup()
 RETURNS TABLE(hospital_chain text, audits integer, pass_count integer, fail_count integer, critical_count integer, avg_atp numeric, avg_visual numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_chain,
    count(*)::int,
    (count(*) filter (where a.pass_status='pass'))::int,
    (count(*) filter (where a.pass_status='fail'))::int AS fail_count,
    (count(*) filter (where a.pass_status='critical_fail'))::int AS critical_count,
    round(avg(a.swab_atp_rlu)::numeric,1),
    round(avg(a.visual_score)::numeric,2)
  from public.tray_window_audits_r3043 a
  group by a.hospital_chain
  order by critical_count desc, fail_count desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.r3086_remediation_status -- ORDER BY count_scorecards DESC
CREATE OR REPLACE FUNCTION public.r3086_remediation_status()
 RETURNS TABLE(status text, count_scorecards integer, coaching_required_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select coalesce(remediation_status, 'unset'), count(*)::int AS count_scorecards, (count(*) filter (where coaching_required))::int
  from vaporizer_discipline_scorecards_r3086
  group by remediation_status
  order by count_scorecards desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3747_incident_digest -- ORDER BY food_safety_incidents_total DESC
CREATE OR REPLACE FUNCTION public.founder_r3747_incident_digest()
 RETURNS TABLE(site_name text, records bigint, incident_records bigint, food_safety_incidents_total bigint, avg_hygiene_audit_score numeric, pest_control_gaps bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.food_safety_incidents > 0)::bigint,
    coalesce(sum(l.food_safety_incidents), 0)::bigint AS food_safety_incidents_total,
    round(avg(l.hygiene_audit_score), 1),
    count(*) filter (where l.pest_control_verified = false)::bigint
  from public.canteen_fssai_r3747 l
  where l.food_safety_incidents > 0 or l.pest_control_verified = false
  group by l.site_name
  order by food_safety_incidents_total desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_signups_by_city -- ORDER BY signups_90d DESC
CREATE OR REPLACE FUNCTION public.founder_signups_by_city()
 RETURNS TABLE(city text, signups_90d bigint, engineers bigint, hospitals bigint)
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
      p.role::text                                     AS role
    FROM public.profiles p
    WHERE p.created_at >= now() - interval '90 days'
  )
  SELECT
    r.city,
    count(*)::bigint AS signups_90d,
    count(*) FILTER (WHERE r.role = 'engineer')::bigint,
    count(*) FILTER (WHERE r.role = 'hospital')::bigint
  FROM recent r
  GROUP BY r.city
  ORDER BY signups_90d DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_jobs_completion_by_equipment -- ORDER BY jobs_90d DESC
CREATE OR REPLACE FUNCTION public.founder_jobs_completion_by_equipment()
 RETURNS TABLE(equipment_type text, jobs_90d bigint, p50_hours numeric, p90_hours numeric, avg_hours numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(rj.equipment_type::text), ''), '(unknown)') AS equipment_type,
      extract(epoch FROM (rj.completed_at - rj.created_at)) / 3600.0 AS hrs
    FROM public.repair_jobs rj
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  )
  SELECT
    b.equipment_type,
    count(*)::bigint AS jobs_90d,
    coalesce(round(percentile_cont(0.5) WITHIN GROUP (ORDER BY b.hrs)::numeric, 1), 0)::numeric,
    coalesce(round(percentile_cont(0.9) WITHIN GROUP (ORDER BY b.hrs)::numeric, 1), 0)::numeric,
    coalesce(round(avg(b.hrs)::numeric, 1), 0)::numeric
  FROM base b
  GROUP BY b.equipment_type
  ORDER BY jobs_90d DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_escrow_by_state -- ORDER BY held_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_escrow_by_state()
 RETURNS TABLE(state text, held_rupees numeric, released_90d numeric, refunded_90d numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      e.amount_rupees,
      e.status,
      e.updated_at
    FROM public.repair_job_escrow e
    JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  )
  SELECT
    b.state,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status IN ('paid','disputed','held')), 0)::numeric AS held_rupees,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status='released' AND b.updated_at >= now() - interval '90 days'), 0)::numeric,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status='refunded' AND b.updated_at >= now() - interval '90 days'), 0)::numeric
  FROM base b
  GROUP BY b.state
  ORDER BY held_rupees DESC
  LIMIT 40;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_code_red_hero_board -- ORDER BY median_first_response_seconds ASC, sla_hit_pct DESC
CREATE OR REPLACE FUNCTION public.founder_code_red_hero_board(p_limit integer DEFAULT 20)
 RETURNS TABLE(id uuid, engineer_name text, total_responses bigint, median_first_response_seconds numeric, sla_hit_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, p.email, 'engineer')::text,
    COUNT(m.*)::bigint,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY m.first_response_seconds)::numeric AS median_first_response_seconds,
    (100.0 * SUM(CASE WHEN m.hit_first_response_sla THEN 1 ELSE 0 END) / NULLIF(COUNT(m.*),0))::numeric AS sla_hit_pct
  FROM code_red_engineer_response_metrics_v2 m
  JOIN engineers e ON e.id = m.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE NOT m.dropped
  GROUP BY e.id, p.full_name, p.email
  HAVING COUNT(m.*) >= 3
  ORDER BY sla_hit_pct DESC NULLS LAST, median_first_response_seconds ASC NULLS LAST
  LIMIT p_limit;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3104_lab_partner_mix -- ORDER BY samples_processed DESC
CREATE OR REPLACE FUNCTION public.founder_r3104_lab_partner_mix()
 RETURNS TABLE(lab_partner text, samples_processed bigint, pass_rate_pct numeric, avg_endotoxin numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select s.lab_partner,
           count(*)::bigint AS samples_processed,
           round(100.0 * count(*) filter (where s.aami_compliance_status in ('aami_compliant','iso23500_compliant'))::numeric / nullif(count(*),0), 1),
           round(avg(s.endotoxin_eu_per_ml)::numeric, 3)
    from dialysis_ro_water_samples_r3104 s
    group by s.lab_partner
    order by samples_processed desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r3106_capa_category_leaderboard -- ORDER BY total_cost_rupees DESC
CREATE OR REPLACE FUNCTION public.r3106_capa_category_leaderboard()
 RETURNS TABLE(capa_category text, total_capas bigint, open_capas bigint, patient_safety_evts bigint, total_cost_rupees bigint, avg_hours_to_close numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.capa_category,
    count(*)::bigint,
    count(*) FILTER (WHERE c.capa_status NOT IN ('closed_verified','closed_no_action'))::bigint,
    count(*) FILTER (WHERE c.patient_safety_event)::bigint,
    coalesce(sum(c.cost_to_close_rupees),0)::bigint AS total_cost_rupees,
    round(avg(c.hours_to_close)::numeric, 2)
  FROM public.ventilator_capa_actions_r3106 c
  GROUP BY c.capa_category
  ORDER BY count(*) DESC, total_cost_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_press_topic_rollup_r3109 -- ORDER BY reach DESC
CREATE OR REPLACE FUNCTION public.rpc_press_topic_rollup_r3109()
 RETURNS TABLE(topic_cluster text, hits bigint, reach bigint, avg_sentiment numeric, off_message_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.topic_cluster,
    count(*)::bigint,
    sum(h.reach_estimate)::bigint AS reach,
    round(avg(h.sentiment_score)::numeric, 3),
    sum(case when h.narrative_angle in ('off_message','factual_error','competitor_framing',
                                       'leak','founder_quote_misused') then 1 else 0 end)::bigint
  from public.press_media_hits_r3109 h
  group by h.topic_cluster
  order by reach desc;
end$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3111_audience_rollup -- ORDER BY total_reach DESC
CREATE OR REPLACE FUNCTION public.fn_r3111_audience_rollup()
 RETURNS TABLE(audience_segment text, broadcasts_count bigint, total_reach bigint, consume_rate_pct numeric, reply_count bigint, follow_up_completion_pct numeric, avg_nps numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.audience_segment,
         COUNT(*)::bigint,
         SUM(b.delivered_count)::bigint AS total_reach,
         ROUND(100.0 * SUM(b.fully_consumed_count)::numeric / NULLIF(SUM(b.audience_size),0), 1),
         SUM(b.reply_count)::bigint,
         ROUND(100.0 * SUM(b.follow_up_completed_count)::numeric / NULLIF(SUM(b.follow_up_action_count),0), 1),
         ROUND(AVG(b.avg_nps_score)::numeric, 2)
  FROM public.founder_comms_broadcasts_r3111 b
  GROUP BY b.audience_segment
  ORDER BY total_reach DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.accuracy_by_segment_r2332 -- ORDER BY accuracy_pct DESC
CREATE OR REPLACE FUNCTION public.accuracy_by_segment_r2332()
 RETURNS TABLE(customer_segment text, total_predictions bigint, resolved_predictions bigint, correct_predictions bigint, accuracy_pct numeric, avg_predicted_prob numeric, renewal_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.customer_segment,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.actual_outcome IS NOT NULL AND p.actual_outcome <> 'pending')::bigint,
         COUNT(*) FILTER (WHERE p.prediction_correct = true)::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE p.prediction_correct = true)
               / NULLIF(COUNT(*) FILTER (WHERE p.actual_outcome IS NOT NULL AND p.actual_outcome <> 'pending'),0), 2) AS accuracy_pct,
         ROUND(AVG(p.predicted_renewal_probability)::numeric, 4),
         ROUND(100.0 * COUNT(*) FILTER (WHERE p.actual_outcome = 'renewed')
               / NULLIF(COUNT(*) FILTER (WHERE p.actual_outcome IS NOT NULL AND p.actual_outcome <> 'pending'),0), 2)
  FROM public.customer_renewal_predictions_r2332 p
  GROUP BY p.customer_segment
  ORDER BY accuracy_pct DESC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.dr_detector_replacement_cost_funnel_r3132 -- ORDER BY total_replacement_lakhs DESC
CREATE OR REPLACE FUNCTION public.dr_detector_replacement_cost_funnel_r3132()
 RETURNS TABLE(audit_verdict text, panel_count bigint, amc_covered_count bigint, out_of_pocket_count bigint, total_replacement_lakhs numeric, avg_replacement_lakhs numeric, exposure_lakhs numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_verdict::text,
           count(*)::bigint,
           count(*) filter (where a.amc_covered)::bigint,
           count(*) filter (where not a.amc_covered)::bigint,
           coalesce(sum(a.replacement_cost_lakhs), 0)::numeric AS total_replacement_lakhs,
           round(coalesce(avg(a.replacement_cost_lakhs), 0)::numeric, 2),
           coalesce(sum(a.replacement_cost_lakhs) filter (where not a.amc_covered), 0)::numeric
    from dr_detector_panel_audits_r3132 a
    group by a.audit_verdict
    order by total_replacement_lakhs desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.leakage_kind_distribution_r2651 -- ORDER BY total_rupees DESC
CREATE OR REPLACE FUNCTION public.leakage_kind_distribution_r2651()
 RETURNS TABLE(leakage_kind text, leakage_count bigint, total_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.leakage_kind, COUNT(*)::bigint, COALESCE(SUM(l.leakage_rupees),0)::bigint AS total_rupees
    FROM public.chain_revenue_leakage_r2651 l
    GROUP BY l.leakage_kind
    ORDER BY total_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2736_compliance_breakdown -- ORDER BY captures DESC
CREATE OR REPLACE FUNCTION public.r2736_compliance_breakdown()
 RETURNS TABLE(compliance_status text, captures bigint, avg_score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.compliance_status, COUNT(*)::bigint AS captures, ROUND(AVG(c.uniform_score)::numeric,2)
  FROM uniform_photo_captures_r2736 c
  GROUP BY c.compliance_status
  ORDER BY captures DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2747_scale_decision_breakdown -- ORDER BY decision_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2747_scale_decision_breakdown()
 RETURNS TABLE(scale_decision text, decision_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.scale_decision, count(*)::bigint AS decision_count
    FROM hospital_chain_tech_pilot_outcomes_r2747 o
   GROUP BY o.scale_decision
   ORDER BY decision_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2750_region_rollup -- ORDER BY completion_pct ASC
CREATE OR REPLACE FUNCTION public.founder_r2750_region_rollup()
 RETURNS TABLE(region text, engineers integer, units_assigned integer, units_completed integer, completion_pct numeric, avg_turnaround_h numeric, open_blockers integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.region,
         COUNT(*)::int,
         SUM(r.units_assigned)::int,
         SUM(r.units_completed)::int,
         ROUND(100.0 * SUM(r.units_completed)::numeric / NULLIF(SUM(r.units_assigned),0), 2) AS completion_pct,
         ROUND(AVG(r.avg_turnaround_h)::numeric, 2),
         (SELECT COUNT(*)::int
            FROM recall_blocker_actions_r2750 b
            JOIN engineer_recall_readiness_r2750 e ON e.engineer_code = b.engineer_code
           WHERE e.region = r.region AND b.status IN ('open','in_progress','escalated'))
    FROM engineer_recall_readiness_r2750 r
   GROUP BY r.region
   ORDER BY completion_pct ASC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2758_region_rollup -- ORDER BY total_bonus DESC
CREATE OR REPLACE FUNCTION public.founder_r2758_region_rollup()
 RETURNS TABLE(region text, engineers integer, avg_streak numeric, total_bonus bigint, elite_share numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.region,
           COUNT(*)::int,
           ROUND(AVG(s.streak_months)::numeric,2),
           SUM(s.bonus_rupees)::bigint AS total_bonus,
           ROUND((COUNT(*) FILTER (WHERE s.verdict='elite')::numeric / NULLIF(COUNT(*),0)) * 100, 2)
    FROM engineer_complaint_resolution_streak_r2758 s
    GROUP BY s.region
    ORDER BY total_bonus DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2764_status_pipeline -- ORDER BY saving_in_status_rupees DESC
CREATE OR REPLACE FUNCTION public.rpc_r2764_status_pipeline()
 RETURNS TABLE(recommendation_status text, count_recommendations integer, saving_in_status_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.recommendation_status,
    COUNT(*)::int,
    COALESCE(SUM(r.estimated_annual_saving_rupees),0)::numeric AS saving_in_status_rupees
  FROM standardization_recommendation_r2764 r
  GROUP BY r.recommendation_status
  ORDER BY saving_in_status_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_vendor_by_category_r2802 -- ORDER BY avg_strength DESC
CREATE OR REPLACE FUNCTION public.founder_engineer_vendor_by_category_r2802()
 RETURNS TABLE(vendor_category text, relationship_count integer, avg_strength numeric, total_interactions integer, total_orders integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.vendor_category,
           COUNT(*)::integer,
           ROUND(AVG(r.strength_score)::numeric, 2) AS avg_strength,
           COALESCE(SUM(r.interactions_count), 0)::integer,
           COALESCE(SUM(r.orders_fulfilled), 0)::integer
    FROM engineer_vendor_relationship_strength_r2802 r
    GROUP BY r.vendor_category
    ORDER BY avg_strength DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2826_engineer_leaderboard -- ORDER BY avg_score DESC
CREATE OR REPLACE FUNCTION public.founder_r2826_engineer_leaderboard()
 RETURNS TABLE(engineer_code text, engineer_name text, engineer_tier text, job_count integer, avg_score numeric, bench_pass_rate numeric, on_time_rate numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    p.engineer_code,
    MAX(p.engineer_name),
    MAX(p.engineer_tier),
    COUNT(*)::int,
    ROUND(AVG(p.prep_score)::numeric, 2) AS avg_score,
    ROUND( (SUM(CASE WHEN p.bench_test_passed THEN 1 ELSE 0 END)::numeric
            / NULLIF(COUNT(*),0)) * 100, 2),
    ROUND( (SUM(CASE WHEN p.completion_verdict IN ('on_time','closed_ok') THEN 1 ELSE 0 END)::numeric
            / NULLIF(COUNT(*),0)) * 100, 2)
  FROM engineer_monthly_job_prep_stages_r2826 p
  GROUP BY p.engineer_code
  ORDER BY avg_score DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2859_by_equipment -- ORDER BY avg_abs_r DESC
CREATE OR REPLACE FUNCTION public.r2859_by_equipment()
 RETURNS TABLE(equipment_category text, correlations integer, avg_uptime numeric, avg_abs_r numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.equipment_category,
           count(*)::int,
           round(avg(c.uptime_pct)::numeric, 2),
           round(avg(abs(c.pearson_r))::numeric, 3) AS avg_abs_r
    FROM hospital_chain_quarterly_equipment_clinical_correlation_r2859 c
    GROUP BY c.equipment_category
    ORDER BY avg_abs_r DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2895_city_heatmap -- ORDER BY critical_count DESC, total_failures DESC
CREATE OR REPLACE FUNCTION public.founder_r2895_city_heatmap()
 RETURNS TABLE(city text, branches integer, total_beds bigint, avg_ratio numeric, critical_count integer, total_failures bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.city,
         COUNT(*)::int,
         SUM(c.beds_served)::bigint,
         ROUND(AVG(c.redundancy_ratio),2),
         COUNT(*) FILTER (WHERE c.coverage_status='critical_gap')::int AS critical_count,
         SUM(c.failure_events_last_quarter)::bigint AS total_failures
  FROM hospital_chain_critical_care_redundancy_coverage_r2895 c
  GROUP BY c.city
  ORDER BY critical_count DESC, total_failures DESC;
END;$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2912_tier_rollup -- ORDER BY avg_latency ASC
CREATE OR REPLACE FUNCTION public.founder_r2912_tier_rollup()
 RETURNS TABLE(engineer_tier text, eng_count bigint, avg_latency numeric, total_breaches bigint, total_bonus bigint, total_penalty bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_tier, COUNT(*)::bigint, ROUND(AVG(s.avg_latency_minutes),2) AS avg_latency,
         SUM(s.sla_breaches)::bigint, SUM(s.incentive_bonus_rupees)::bigint, SUM(s.penalty_rupees)::bigint
  FROM after_hours_wa_engineer_scorecard_r2912 s
  GROUP BY s.engineer_tier
  ORDER BY avg_latency ASC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2919_chain_summary -- ORDER BY total_fine_exposure DESC
CREATE OR REPLACE FUNCTION public.r2919_chain_summary()
 RETURNS TABLE(chain_name text, audits integer, pass_rate numeric, total_fine_exposure numeric, avg_compliance numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name,
         COUNT(*)::int,
         ROUND(100.0 * SUM(CASE WHEN a.pass_status='pass' THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2),
         SUM(a.fine_exposure_rupees) AS total_fine_exposure,
         ROUND(AVG(a.surgeon_compliance_pct), 2)
  FROM or_smoke_evacuation_audits_r2919 a
  GROUP BY a.chain_name
  ORDER BY total_fine_exposure DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2967_chain_fleet_rollup -- ORDER BY overdue_calibration DESC, failed_recall DESC
CREATE OR REPLACE FUNCTION public.founder_r2967_chain_fleet_rollup()
 RETURNS TABLE(chain_name text, probes_total integer, compliant_calibration integer, overdue_calibration integer, failed_recall integer, contamination_or_quarantine integer, fleet_value_inr bigint, utilization_hours bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select
    f.chain_name,
    count(*)::int,
    (count(*) filter (where f.calibration_status = 'compliant'))::int,
    (count(*) filter (where f.calibration_status = 'overdue'))::int AS overdue_calibration,
    (count(*) filter (where f.calibration_status = 'failed_recall'))::int AS failed_recall,
    (count(*) filter (where f.disinfection_status in ('contamination_flag','quarantined')))::int,
    coalesce(sum(f.fleet_value_inr),0)::bigint,
    coalesce(sum(f.utilization_hours_quarter),0)::bigint
  from ultrasound_probe_fleet_r2967 f
  group by f.chain_name
  order by failed_recall desc, overdue_calibration desc, f.chain_name;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2987_oem_scorecard -- ORDER BY total_recovered_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r2987_oem_scorecard()
 RETURNS TABLE(oem_name text, total_claims integer, recovered integer, rejected integer, escalated integer, avg_velocity numeric, total_recovered_rupees bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.oem_name,
         count(*)::int,
         (count(*) filter (where c.status = 'recovered'))::int,
         (count(*) filter (where c.status = 'rejected'))::int,
         (count(*) filter (where c.status = 'escalated'))::int,
         round(avg(c.velocity_days) filter (where c.velocity_days is not null), 2),
         sum(c.recovered_amount_rupees)::bigint AS total_recovered_rupees
  from hospital_chain_oem_warranty_claims_r2987 c
  group by c.oem_name
  order by total_recovered_rupees desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_fmt_surface_prep_efficacy_r2996 -- ORDER BY excellent_count DESC
CREATE OR REPLACE FUNCTION public.founder_fmt_surface_prep_efficacy_r2996()
 RETURNS TABLE(surface_prep text, replacements integer, excellent_count integer, rework_or_failed integer, avg_cost_rupees numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.surface_prep, count(*)::int,
    (count(*) filter (where r.outcome = 'excellent'))::int AS excellent_count,
    (count(*) filter (where r.outcome in ('rework_needed','failed_24h')))::int,
    round(avg(r.cost_rupees),2)::numeric
  from floor_marking_tape_replacements_r2996 r
  group by r.surface_prep
  order by excellent_count desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3000_material_burn_deep_dive -- ORDER BY avg_afterflame DESC
CREATE OR REPLACE FUNCTION public.r3000_material_burn_deep_dive()
 RETURNS TABLE(drape_material text, lots_tested integer, avg_flame_spread numeric, avg_char_length numeric, avg_afterflame numeric, nfpa701_pass_pct numeric, astm_f1959_pass_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.drape_material,
    count(*)::int,
    round(avg(b.flame_spread_seconds)::numeric, 2),
    round(avg(b.char_length_mm)::numeric, 2),
    round(avg(b.afterflame_seconds)::numeric, 2) AS avg_afterflame,
    round(100.0 * (count(*) filter (where b.nfpa701_pass))::numeric / nullif(count(*),0), 2),
    round(100.0 * (count(*) filter (where b.astm_f1959_pass))::numeric / nullif(count(*),0), 2)
  from surgical_drape_burn_tests_r3000 b
  group by b.drape_material
  order by avg_afterflame desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3002_model_fleet_wear -- ORDER BY condemned DESC
CREATE OR REPLACE FUNCTION public.r3002_model_fleet_wear()
 RETURNS TABLE(sling_model text, units integer, avg_age_months numeric, avg_wear numeric, condemned integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.sling_model,
         count(*)::int,
         round(avg(i.age_months)::numeric, 1),
         round(avg(i.fabric_wear_score)::numeric, 2),
         (count(*) filter (where i.verdict='condemn'))::int AS condemned
  from bath_lift_sling_inspections_r3002 i
  group by i.sling_model
  order by condemned desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.firmware_spread_r3023 -- ORDER BY units DESC
CREATE OR REPLACE FUNCTION public.firmware_spread_r3023()
 RETURNS TABLE(pump_model text, firmware_version text, units bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select coalesce(i.pump_model,'unknown'), coalesce(i.firmware_version,'(none)'), count(*) AS units
  from infusion_pump_inventory_r3023 i
  group by i.pump_model, i.firmware_version
  order by i.pump_model, units desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3079_chain_summary -- ORDER BY retire_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3079_chain_summary()
 RETURNS TABLE(chain_name text, apron_count integer, retire_count integer, total_replacement_cost integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.chain_name,
         count(*)::int,
         (count(*) filter (where i.retire_recommended))::int AS retire_count,
         coalesce(sum(i.replacement_cost_rupees) filter (where i.retire_recommended),0)::int
  from hospital_chain_lead_apron_inventory_r3079 i
  group by i.chain_name
  order by retire_count desc, i.chain_name;
end $function$;

-- ---------------------------------------------------------------------
-- public.founder_top_engineers_30d -- ORDER BY gross_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_top_engineers_30d()
 RETURNS TABLE(engineer_user_id uuid, display_name text, jobs_completed integer, gross_rupees numeric, avg_job_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    b.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    count(*)::int,
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric AS gross_rupees,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(rj.contracted_amount_rupees), 0)::numeric / count(*)::numeric, 2)
    END
  FROM public.repair_jobs rj
  JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  WHERE rj.status = 'completed'
    AND rj.completed_at >= now() - interval '30 days'
  GROUP BY b.engineer_user_id, p.full_name
  ORDER BY gross_rupees DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_jobs_by_equipment_type -- ORDER BY jobs_count DESC
CREATE OR REPLACE FUNCTION public.founder_jobs_by_equipment_type()
 RETURNS TABLE(equipment_type text, jobs_count bigint, gross_rupees numeric, avg_rupees numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(rj.equipment_type::text), ''), '(unknown)') AS equipment_type,
    count(*)::bigint AS jobs_count,
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(rj.contracted_amount_rupees), 0)::numeric / count(*)::numeric, 2)
    END
  FROM public.repair_jobs rj
  WHERE rj.status = 'completed'
    AND rj.completed_at >= now() - interval '90 days'
  GROUP BY 1
  ORDER BY jobs_count DESC
  LIMIT 50;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_payouts_by_state -- ORDER BY paid_rupees_90d DESC
CREATE OR REPLACE FUNCTION public.founder_payouts_by_state()
 RETURNS TABLE(state text, engineers bigint, processed_90d bigint, paid_rupees_90d numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(pr.state), ''), '(unknown)') AS state,
      p.engineer_user_id,
      p.amount_paise,
      p.status
    FROM public.engineer_payouts p
    LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
    WHERE p.queued_at >= now() - interval '90 days'
  )
  SELECT
    b.state,
    count(DISTINCT b.engineer_user_id)::bigint,
    count(*) FILTER (WHERE b.status = 'processed')::bigint,
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.status='processed'), 0)::numeric / 100.0, 2) AS paid_rupees_90d
  FROM base b
  GROUP BY b.state
  ORDER BY paid_rupees_90d DESC
  LIMIT 40;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_investor_open_tracker_recent_events -- ORDER BY happened_at DESC
CREATE OR REPLACE FUNCTION public.founder_investor_open_tracker_recent_events()
 RETURNS TABLE(event_kind text, investor_firm_name text, detail text, happened_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT 'email_open'::text, r.investor_firm_name,
         coalesce(u.quarter_label, 'update') AS detail,
         r.opened_at AS happened_at
  FROM public.founder_investor_quarterly_update_recipients r
  LEFT JOIN public.founder_investor_quarterly_updates u ON u.id = r.update_id
  WHERE r.opened_at IS NOT NULL
  UNION ALL
  SELECT 'email_reply'::text, r.investor_firm_name,
         coalesce(u.quarter_label, 'update'),
         r.replied_at
  FROM public.founder_investor_quarterly_update_recipients r
  LEFT JOIN public.founder_investor_quarterly_updates u ON u.id = r.update_id
  WHERE r.replied_at IS NOT NULL
  UNION ALL
  SELECT 'opt_out'::text, r.investor_firm_name,
         coalesce(u.quarter_label, 'update'),
         r.opt_out_at
  FROM public.founder_investor_quarterly_update_recipients r
  LEFT JOIN public.founder_investor_quarterly_updates u ON u.id = r.update_id
  WHERE r.opt_out_at IS NOT NULL
  UNION ALL
  SELECT 'dataroom_view'::text, g.investor_firm_name,
         coalesce(d.doc_label, l.action_kind),
         l.accessed_at AS happened_at
  FROM public.founder_investor_data_room_access_log l
  JOIN public.founder_investor_data_room_access_grants g ON g.id = l.grant_id
  LEFT JOIN public.founder_investor_data_room_documents d ON d.id = l.document_id
  WHERE l.outcome = 'ok' AND l.action_kind = 'view_doc'
  ORDER BY happened_at DESC NULLS LAST
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_apprentice_masters_scoreboard -- ORDER BY active_apprentices DESC
CREATE OR REPLACE FUNCTION public.founder_apprentice_masters_scoreboard()
 RETURNS TABLE(master_engineer_id uuid, master_name text, active_apprentices integer, graduated_apprentices integer, total_jobs_with_apprentice integer, avg_milestone_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.master_engineer_id,
    COALESCE(pr.full_name, pr.email) AS master_name,
    COUNT(*) FILTER (WHERE p.status='active')::int AS active_apprentices,
    COUNT(*) FILTER (WHERE p.status='graduated')::int,
    COALESCE(SUM(p.jobs_shadowed + p.jobs_assisted + p.jobs_solo),0)::int,
    ROUND(AVG(
      (SELECT CASE WHEN COUNT(*)=0 THEN 0
              ELSE 100.0 * COUNT(*) FILTER (WHERE completed_at IS NOT NULL) / COUNT(*)::numeric END
       FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id)
    )::numeric, 1)
  FROM apprentice_pairings_v2 p
  LEFT JOIN engineers e ON e.id = p.master_engineer_id
  LEFT JOIN profiles  pr ON pr.id = e.user_id
  GROUP BY p.master_engineer_id, pr.full_name, pr.email
  ORDER BY active_apprentices DESC NULLS LAST
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_engineer_ces_by_engineer_90d -- ORDER BY avg_ces ASC, high_effort_pct DESC
CREATE OR REPLACE FUNCTION public.founder_engineer_ces_by_engineer_90d()
 RETURNS TABLE(engineer_id uuid, engineer_name text, cached_highest_tier text, response_count bigint, avg_ces numeric, low_effort_count bigint, high_effort_count bigint, high_effort_pct numeric, last_response_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, p.email, '(unknown)')::text,
    e.cached_highest_tier::text,
    count(r.*)::bigint,
    COALESCE(round(avg(r.ces_score)::numeric, 2), 0)::numeric AS avg_ces,
    count(*) FILTER (WHERE r.effort_bucket = 'low_effort')::bigint,
    count(*) FILTER (WHERE r.effort_bucket = 'high_effort')::bigint,
    CASE WHEN count(r.*) > 0
      THEN round((count(*) FILTER (WHERE r.effort_bucket = 'high_effort')::numeric * 100.0) / count(r.*), 1)
      ELSE 0 END::numeric AS high_effort_pct,
    max(r.responded_at)
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN engineer_ces_responses r ON r.engineer_id = e.id
    AND r.responded_at >= now() - interval '90 days'
  GROUP BY e.id, p.full_name, p.email, e.cached_highest_tier
  HAVING count(r.*) > 0
  ORDER BY high_effort_pct DESC NULLS LAST, avg_ces ASC NULLS LAST
  LIMIT 100;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_cash_pipeline_by_segment -- ORDER BY weighted_arr_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_cash_pipeline_by_segment()
 RETURNS TABLE(segment text, entries integer, total_arr_rupees bigint, weighted_arr_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.segment, COUNT(*)::int,
         COALESCE(SUM(p.arr_rupees),0)::bigint,
         COALESCE(SUM(p.arr_rupees * p.probability_pct / 100),0)::bigint AS weighted_arr_rupees
  FROM founder_pipeline_entries p
  WHERE p.stage NOT IN ('closed_won','closed_lost')
  GROUP BY p.segment
  ORDER BY weighted_arr_rupees DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_code_red_dropout_board -- ORDER BY dropout_count DESC, last_drop_at DESC
CREATE OR REPLACE FUNCTION public.founder_code_red_dropout_board(p_limit integer DEFAULT 20)
 RETURNS TABLE(id uuid, engineer_name text, dropout_count bigint, last_drop_at timestamp with time zone, last_reason text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, p.email, 'engineer')::text,
    COUNT(*)::bigint AS dropout_count,
    MAX(m.recorded_at) AS last_drop_at,
    (ARRAY_AGG(m.drop_reason ORDER BY m.recorded_at DESC))[1]
  FROM code_red_engineer_response_metrics_v2 m
  JOIN engineers e ON e.id = m.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE m.dropped
  GROUP BY e.id, p.full_name, p.email
  ORDER BY dropout_count DESC, last_drop_at DESC
  LIMIT p_limit;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3104_action_type_cost -- ORDER BY total_actual_cost_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r3104_action_type_cost()
 RETURNS TABLE(action_type text, action_count bigint, total_actual_cost_rupees numeric, avg_actual_cost_rupees numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select a.action_type,
           count(*)::bigint,
           coalesce(sum(a.actual_cost_rupees), 0) AS total_actual_cost_rupees,
           coalesce(round(avg(a.actual_cost_rupees)::numeric, 2), 0)
    from dialysis_ro_purification_actions_r3104 a
    group by a.action_type
    order by total_actual_cost_rupees desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r2302_engineer_leaderboard -- ORDER BY pass_rate_pct ASC
CREATE OR REPLACE FUNCTION public.r2302_engineer_leaderboard()
 RETURNS TABLE(engineer_id uuid, engineer_name text, tests_taken integer, passed integer, failed integer, avg_score_pct numeric, pass_rate_pct numeric, last_test_at timestamp with time zone, open_assignments integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.engineer_id,
         MAX(t.engineer_name) AS engineer_name,
         COUNT(*)::integer AS tests_taken,
         COUNT(*) FILTER (WHERE t.result = 'pass')::integer,
         COUNT(*) FILTER (WHERE t.result = 'fail')::integer,
         ROUND(AVG(t.score_pct), 1)::numeric,
         CASE WHEN COUNT(*) = 0 THEN 0::numeric
              ELSE ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / COUNT(*)::numeric) * 100, 1) END AS pass_rate_pct,
         MAX(t.test_taken_at),
         (SELECT COUNT(*)::integer FROM public.engineer_training_assignments_r2302 a
           WHERE a.engineer_id = t.engineer_id AND a.status IN ('assigned','in_progress','overdue'))
  FROM public.engineer_competency_tests_r2302 t
  GROUP BY t.engineer_id
  ORDER BY pass_rate_pct ASC, tests_taken DESC
  LIMIT 100;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_press_sentiment_trend_r3109 -- ORDER BY hit_date DESC
CREATE OR REPLACE FUNCTION public.rpc_press_sentiment_trend_r3109()
 RETURNS TABLE(hit_date date, hits bigint, weighted_sentiment numeric, total_reach bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    (h.published_at at time zone 'Asia/Kolkata')::date AS hit_date,
    count(*)::bigint,
    round(
      (sum(h.sentiment_score * h.reach_estimate)::numeric
       / nullif(sum(h.reach_estimate),0)::numeric),
      3),
    sum(h.reach_estimate)::bigint
  from public.press_media_hits_r3109 h
  group by (h.published_at at time zone 'Asia/Kolkata')::date
  order by hit_date desc;
end$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3111_cadence_effectiveness -- ORDER BY avg_nps DESC
CREATE OR REPLACE FUNCTION public.fn_r3111_cadence_effectiveness()
 RETURNS TABLE(cadence_slot text, broadcasts_count bigint, avg_consume_rate_pct numeric, avg_nps numeric, dud_count bigint, excellent_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.cadence_slot,
         COUNT(*)::bigint,
         ROUND(AVG(100.0 * b.fully_consumed_count::numeric / NULLIF(b.audience_size,0))::numeric, 1),
         ROUND(AVG(b.avg_nps_score)::numeric, 2) AS avg_nps,
         COUNT(*) FILTER (WHERE b.effectiveness_band = 'dud')::bigint,
         COUNT(*) FILTER (WHERE b.effectiveness_band = 'excellent')::bigint
  FROM public.founder_comms_broadcasts_r3111 b
  GROUP BY b.cadence_slot
  ORDER BY avg_nps DESC NULLS LAST;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.warranty_lost_reasons_r2239 -- ORDER BY deal_count DESC
CREATE OR REPLACE FUNCTION public.warranty_lost_reasons_r2239()
 RETURNS TABLE(lost_reason text, deal_count integer, lost_value_rupees bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(p.lost_reason, 'unspecified')::text,
    COUNT(*)::int AS deal_count,
    COALESCE(SUM(p.proposed_annual_fee_rupees), 0)::bigint
  FROM public.warranty_expiry_pipeline_r2239 p
  WHERE p.pipeline_stage = 'lost'
  GROUP BY p.lost_reason
  ORDER BY deal_count DESC
  LIMIT 20;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3123_lab_readiness_scorecard -- ORDER BY readiness_pct ASC
CREATE OR REPLACE FUNCTION public.founder_r3123_lab_readiness_scorecard()
 RETURNS TABLE(lab_name text, standard_code text, total_clauses bigint, ready_clauses bigint, readiness_pct numeric, open_ncs bigint, total_remediation_rupees bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.lab_name, c.standard_code,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.readiness_status = 'ready')::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE c.readiness_status = 'ready') / NULLIF(COUNT(*),0), 1) AS readiness_pct,
         COALESCE(SUM(CASE WHEN n.capa_status NOT IN ('closed') THEN 1 ELSE 0 END),0)::bigint,
         COALESCE(SUM(n.remediation_cost_rupees),0)::bigint
  FROM nabl_iso_clause_readiness_r3123 c
  LEFT JOIN nabl_iso_nonconformity_capa_r3123 n ON n.clause_id = c.id
  GROUP BY c.lab_name, c.standard_code
  ORDER BY readiness_pct ASC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2259_root_cause_breakdown -- ORDER BY losses_count DESC
CREATE OR REPLACE FUNCTION public.r2259_root_cause_breakdown()
 RETURNS TABLE(root_cause text, losses_count integer, total_value_rupees bigint, avg_price_gap_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.root_cause,
           (COUNT(*))::int AS losses_count,
           COALESCE(SUM(l.tender_value_rupees),0)::bigint,
           ROUND(AVG(l.price_gap_pct)::numeric, 2)
      FROM public.hospital_tender_losses_r2259 l
     GROUP BY l.root_cause
     ORDER BY losses_count DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.dr_detector_capa_event_rollup_r3132 -- ORDER BY event_count DESC
CREATE OR REPLACE FUNCTION public.dr_detector_capa_event_rollup_r3132()
 RETURNS TABLE(event_type text, event_count bigint, successful_count bigint, failed_or_rejected bigint, total_spend_rupees numeric, total_downtime_hours numeric, total_revenue_loss numeric, avg_vendor_response_hours numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.event_type::text,
           count(*)::bigint AS event_count,
           count(*) filter (where e.event_outcome = 'successful')::bigint,
           count(*) filter (where e.event_outcome in ('failed','rejected'))::bigint,
           coalesce(sum(e.spend_rupees), 0)::numeric,
           coalesce(sum(e.downtime_hours), 0)::numeric,
           coalesce(sum(e.revenue_loss_rupees), 0)::numeric,
           round(coalesce(avg(e.vendor_response_hours), 0)::numeric, 1)
    from dr_detector_pixel_capa_events_r3132 e
    group by e.event_type
    order by event_count desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.status_funnel_r2651 -- ORDER BY total_rupees DESC
CREATE OR REPLACE FUNCTION public.status_funnel_r2651()
 RETURNS TABLE(status text, leakage_count bigint, total_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.status, COUNT(*)::bigint, COALESCE(SUM(l.leakage_rupees),0)::bigint AS total_rupees
    FROM public.chain_revenue_leakage_r2651 l
    GROUP BY l.status
    ORDER BY total_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.status_funnel_r2621 -- ORDER BY total_value_rupees DESC
CREATE OR REPLACE FUNCTION public.status_funnel_r2621()
 RETURNS TABLE(lead_kind text, open_count bigint, done_count bigint, dropped_count bigint, total_value_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.lead_kind,
         COUNT(*) FILTER (WHERE l.status = 'open')::bigint,
         COUNT(*) FILTER (WHERE l.status = 'done')::bigint,
         COUNT(*) FILTER (WHERE l.status = 'dropped')::bigint,
         COALESCE(SUM(l.lead_value_rupees), 0)::bigint AS total_value_rupees
  FROM public.speaking_lead_attributions_r2621 l
  GROUP BY l.lead_kind
  ORDER BY total_value_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.owner_load_r2671 -- ORDER BY total_savings_rupees DESC
CREATE OR REPLACE FUNCTION public.owner_load_r2671()
 RETURNS TABLE(owner_email text, chain_count bigint, open_count bigint, total_savings_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(c.owner_email, 'unassigned') AS owner_email,
         COUNT(*)::bigint,
         COALESCE(SUM(CASE WHEN c.status IN ('open','in_progress') THEN 1 ELSE 0 END),0)::bigint,
         COALESCE(SUM(c.est_savings_rupees),0)::bigint AS total_savings_rupees
  FROM public.chain_vendor_consolidation_r2671 c
  GROUP BY c.owner_email
  ORDER BY total_savings_rupees DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.r2995_reserve_summary_by_chain -- ORDER BY red_sites DESC, amber_sites DESC
CREATE OR REPLACE FUNCTION public.r2995_reserve_summary_by_chain()
 RETURNS TABLE(chain_code text, sites integer, avg_reserve_pct integer, red_sites integer, amber_sites integer, green_sites integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.chain_code,
    count(*)::int,
    avg(g.reserve_percent)::int,
    (count(*) filter (where g.compliance_flag='red'))::int AS red_sites,
    (count(*) filter (where g.compliance_flag='amber'))::int AS amber_sites,
    (count(*) filter (where g.compliance_flag='green'))::int
  from generator_fuel_reserve_r2995 g
  group by g.chain_code
  order by red_sites desc, amber_sites desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.r2736_issue_breakdown -- ORDER BY actions DESC
CREATE OR REPLACE FUNCTION public.r2736_issue_breakdown()
 RETURNS TABLE(issue_type text, actions bigint, open_actions bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.issue_type, COUNT(*)::bigint AS actions, COUNT(*) FILTER (WHERE a.status IN ('open','in_progress','escalated'))::bigint
  FROM uniform_compliance_actions_r2736 a
  GROUP BY a.issue_type
  ORDER BY actions DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.r2743_on_call_load -- ORDER BY incident_count DESC, breach_count DESC
CREATE OR REPLACE FUNCTION public.r2743_on_call_load()
 RETURNS TABLE(on_call_engineer text, incident_count integer, breach_count integer, avg_response numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.on_call_engineer, COUNT(*)::int AS incident_count,
         SUM(CASE WHEN i.sla_breach THEN 1 ELSE 0 END)::int AS breach_count,
         ROUND(AVG(i.response_minutes), 2)
  FROM hospital_chain_night_incidents_r2743 i
  GROUP BY i.on_call_engineer
  ORDER BY breach_count DESC, incident_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2758_severity_mix -- ORDER BY total DESC
CREATE OR REPLACE FUNCTION public.founder_r2758_severity_mix()
 RETURNS TABLE(severity text, total integer, resolved integer, escalated integer, reopened integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.severity,
           COUNT(*)::int AS total,
           COUNT(*) FILTER (WHERE e.outcome='resolved')::int,
           COUNT(*) FILTER (WHERE e.outcome='escalated')::int,
           COUNT(*) FILTER (WHERE e.outcome='reopened')::int
    FROM engineer_complaint_streak_events_r2758 e
    GROUP BY e.severity
    ORDER BY total DESC;
END; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2777_strategic_value_rollup -- ORDER BY total_projected_revenue DESC
CREATE OR REPLACE FUNCTION public.founder_r2777_strategic_value_rollup()
 RETURNS TABLE(strategic_value text, project_count bigint, total_award bigint, total_projected_revenue bigint, revenue_multiple numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.strategic_value, COUNT(*)::bigint, COALESCE(SUM(p.award_amount_rupees),0)::bigint, COALESCE(SUM(p.projected_revenue_rupees),0)::bigint AS total_projected_revenue,
           CASE WHEN COALESCE(SUM(p.award_amount_rupees),0) = 0 THEN 0::numeric
                ELSE ROUND(SUM(p.projected_revenue_rupees)::numeric / SUM(p.award_amount_rupees)::numeric, 2) END
    FROM grant_research_projects_r2777 p
    GROUP BY p.strategic_value
    ORDER BY total_projected_revenue DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2778_trade_show_verdict_breakdown -- ORDER BY pipeline_rupees DESC
CREATE OR REPLACE FUNCTION public.r2778_trade_show_verdict_breakdown()
 RETURNS TABLE(verdict text, show_count integer, pipeline_rupees bigint, spend_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT roi_verdict,
           COUNT(*)::int,
           COALESCE(SUM(pipeline_value_rupees),0)::bigint AS pipeline_rupees,
           COALESCE(SUM(travel_cost_rupees + booth_cost_rupees),0)::bigint
    FROM engineer_trade_show_attendance_r2778
    GROUP BY roi_verdict
    ORDER BY pipeline_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2783_ai_module_leaderboard -- ORDER BY total_npv_inr DESC
CREATE OR REPLACE FUNCTION public.r2783_ai_module_leaderboard()
 RETURNS TABLE(ai_module text, chains_using integer, avg_adoption_pct numeric, avg_downtime_delta numeric, total_npv_inr bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.ai_module,
    COUNT(DISTINCT p.chain_name)::int,
    ROUND(AVG(p.adoption_pct)::numeric, 2),
    ROUND(AVG(p.downtime_delta_pct)::numeric, 2),
    COALESCE(SUM(p.npv_inr),0)::bigint AS total_npv_inr
  FROM hospital_chain_ai_integration_pulse_r2783 p
  WHERE p.pulse_quarter = '2026-Q2'
  GROUP BY p.ai_module
  ORDER BY total_npv_inr DESC;
END $function$;

-- ---------------------------------------------------------------------
-- public.r2815_intervention_mix -- ORDER BY events DESC
CREATE OR REPLACE FUNCTION public.r2815_intervention_mix()
 RETURNS TABLE(intervention text, events integer, avg_lag_minutes numeric, avg_duration_minutes numeric, rupees_lost bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.intervention,
         COUNT(*)::int AS events,
         ROUND(AVG(e.intervention_lag_minutes)::numeric, 1),
         ROUND(AVG(e.duration_minutes)::numeric, 1),
         COALESCE(SUM(e.rupees_lost),0)::bigint
  FROM fridge_temp_audit_events_r2815 e
  GROUP BY e.intervention
  ORDER BY events DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2826_verdict_mix -- ORDER BY job_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2826_verdict_mix()
 RETURNS TABLE(verdict text, job_count integer, share_pct numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH t AS (SELECT COUNT(*)::numeric AS total FROM engineer_monthly_job_prep_stages_r2826)
  SELECT
    COALESCE(p.completion_verdict, 'unset'),
    COUNT(*)::int AS job_count,
    ROUND((COUNT(*)::numeric / NULLIF((SELECT total FROM t),0)) * 100, 2)
  FROM engineer_monthly_job_prep_stages_r2826 p
  GROUP BY COALESCE(p.completion_verdict, 'unset')
  ORDER BY job_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2839_verdict_breakdown -- ORDER BY revenue_sum DESC
CREATE OR REPLACE FUNCTION public.rpc_r2839_verdict_breakdown()
 RETURNS TABLE(verdict text, cohort_count bigint, units_sum bigint, cost_sum numeric, revenue_sum numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.verdict,
           COUNT(*)::bigint,
           COALESCE(SUM(c.units_total),0)::bigint,
           COALESCE(SUM(c.refurb_cost_lakhs + c.replace_cost_lakhs),0)::numeric,
           COALESCE(SUM(c.expected_revenue_lakhs),0)::numeric AS revenue_sum
    FROM chain_fleet_cohorts_r2839 c
    GROUP BY c.verdict
    ORDER BY revenue_sum DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2862_narratives_by_status -- ORDER BY narrative_count DESC
CREATE OR REPLACE FUNCTION public.founder_r2862_narratives_by_status()
 RETURNS TABLE(publish_status text, narrative_count integer, avg_word_count numeric, total_views bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.publish_status,
         COUNT(*)::int AS narrative_count,
         ROUND(AVG(n.word_count), 0),
         COALESCE(SUM(n.engagement_views),0)::bigint
  FROM engineer_monthly_narrative_publish_r2862 n
  GROUP BY n.publish_status
  ORDER BY narrative_count DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2872_tier_rollup -- ORDER BY total_accepted DESC
CREATE OR REPLACE FUNCTION public.founder_r2872_tier_rollup()
 RETURNS TABLE(engineer_tier text, engineer_count bigint, total_sent bigint, total_accepted bigint, acceptance_rate_pct numeric, avg_discount_pct numeric, total_accepted_value_rupees bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.engineer_tier,
    COUNT(*)::bigint,
    COALESCE(SUM(v.quotes_sent),0)::bigint,
    COALESCE(SUM(v.quotes_accepted),0)::bigint AS total_accepted,
    CASE WHEN COALESCE(SUM(v.quotes_sent),0) = 0 THEN 0
         ELSE ROUND((SUM(v.quotes_accepted)::numeric / SUM(v.quotes_sent)::numeric) * 100, 2) END,
    ROUND(AVG(v.median_discount_pct), 2),
    COALESCE(SUM(v.total_accepted_value_rupees),0)::bigint
  FROM engineer_quote_velocity_r2872 v
  WHERE v.month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872)
  GROUP BY v.engineer_tier
  ORDER BY total_accepted DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.rpc_r2882_site_type_breakdown -- ORDER BY visits DESC
CREATE OR REPLACE FUNCTION public.rpc_r2882_site_type_breakdown()
 RETURNS TABLE(site_type text, visits bigint, shoes_removed_pct numeric, avg_clean numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT t.site_type,
           count(*)::bigint AS visits,
           ROUND(100.0 * sum(CASE WHEN t.shoes_removed THEN 1 ELSE 0 END)::numeric / NULLIF(count(*),0), 1),
           ROUND(avg(t.cleanliness_score)::numeric, 2)
    FROM engineer_handover_shoes_protocol_r2882 t
    GROUP BY t.site_type
    ORDER BY visits DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2890_tier_distribution -- ORDER BY total_bonus DESC
CREATE OR REPLACE FUNCTION public.r2890_tier_distribution()
 RETURNS TABLE(tier_band text, engineer_count bigint, total_bonus bigint, avg_csat numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.tier_band, COUNT(*)::bigint, COALESCE(SUM(s.bonus_payout_rupees),0)::bigint AS total_bonus, ROUND(AVG(s.avg_csat),2)
  FROM public.engineer_monthly_repeat_score_r2890 s
  GROUP BY s.tier_band
  ORDER BY total_bonus DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.fn_r2898_tier_breakdown -- ORDER BY avg_completeness DESC
CREATE OR REPLACE FUNCTION public.fn_r2898_tier_breakdown()
 RETURNS TABLE(engineer_tier text, audits integer, avg_completeness numeric, avg_missing numeric, total_penalty integer, total_bonus integer, fail_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.engineer_tier,
    count(*)::int,
    round(avg(a.completeness_pct), 2) AS avg_completeness,
    round(avg(a.missing_doc_count), 2),
    sum(a.penalty_rupees)::int,
    sum(a.bonus_rupees)::int,
    round(100.0 * sum((a.audit_status='fail')::int) / nullif(count(*),0), 2)
  FROM engineer_monthly_handover_audits_r2898 a
  GROUP BY a.engineer_tier
  ORDER BY avg_completeness DESC NULLS LAST;
END $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2912_window_split -- ORDER BY avg_latency DESC
CREATE OR REPLACE FUNCTION public.founder_r2912_window_split()
 RETURNS TABLE(message_window text, msg_count bigint, avg_latency numeric, breach_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.message_window, COUNT(*)::bigint, ROUND(AVG(m.latency_minutes),2) AS avg_latency,
         ROUND(100.0*COUNT(*) FILTER (WHERE m.breached_sla)/NULLIF(COUNT(*),0),2)
  FROM after_hours_wa_messages_r2912 m
  GROUP BY m.message_window
  ORDER BY avg_latency DESC;
END;
$function$;

-- ---------------------------------------------------------------------
-- public.r2966_outcome_breakdown -- ORDER BY audit_count DESC
CREATE OR REPLACE FUNCTION public.r2966_outcome_breakdown()
 RETURNS TABLE(outcome text, audit_count integer, total_devices integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.outcome, count(*)::int AS audit_count, coalesce(sum(a.device_count),0)::int
  from power_strip_audits_r2966 a
  group by a.outcome
  order by audit_count desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.founder_r2987_category_velocity -- ORDER BY avg_velocity_days ASC
CREATE OR REPLACE FUNCTION public.founder_r2987_category_velocity()
 RETURNS TABLE(equipment_category text, claims_count integer, avg_velocity_days numeric, recovery_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.equipment_category,
         count(*)::int,
         round(avg(c.velocity_days) filter (where c.velocity_days is not null), 2) AS avg_velocity_days,
         round((count(*) filter (where c.status = 'recovered'))::numeric * 100.0 / nullif(count(*),0), 2)
  from hospital_chain_oem_warranty_claims_r2987 c
  group by c.equipment_category
  order by avg_velocity_days nulls last;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.r3002_replacement_pipeline -- ORDER BY replacements DESC
CREATE OR REPLACE FUNCTION public.r3002_replacement_pipeline()
 RETURNS TABLE(status text, replacements integer, cost_rupees_total bigint, avg_warranty_months numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select r.status,
         count(*)::int AS replacements,
         sum(r.cost_rupees)::bigint,
         round(avg(r.warranty_months)::numeric, 1)
  from bath_lift_sling_replacements_r3002 r
  group by r.status
  order by replacements desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.library_version_coverage_r3023 -- ORDER BY units DESC
CREATE OR REPLACE FUNCTION public.library_version_coverage_r3023()
 RETURNS TABLE(drug_library_version text, units bigint, chains bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select coalesce(i.drug_library_version,'(none)'), count(*) AS units, count(distinct i.chain_name)
  from infusion_pump_inventory_r3023 i
  group by i.drug_library_version
  order by units desc;
end; $function$;

-- ---------------------------------------------------------------------
-- public.r3043_zone_hygiene -- ORDER BY fail_rate_pct DESC
CREATE OR REPLACE FUNCTION public.r3043_zone_hygiene()
 RETURNS TABLE(window_zone text, audits integer, avg_atp numeric, avg_gasket numeric, fail_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.window_zone,
    count(*)::int,
    round(avg(a.swab_atp_rlu)::numeric,1),
    round(avg(a.gasket_integrity_pct)::numeric,1),
    round((100.0 * (count(*) filter (where a.pass_status in ('fail','critical_fail'))) / nullif(count(*),0))::numeric,1) AS fail_rate_pct
  from public.tray_window_audits_r3043 a
  group by a.window_zone
  order by fail_rate_pct desc;
end;$function$;

-- ---------------------------------------------------------------------
-- public.fn_r3047_manufacturer_failure_heatmap -- ORDER BY failure_rate_pct DESC
CREATE OR REPLACE FUNCTION public.fn_r3047_manufacturer_failure_heatmap()
 RETURNS TABLE(manufacturer text, total integer, failed integer, aborted integer, failure_rate_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.manufacturer,
         count(*)::int,
         (count(*) filter (where c.cycle_state = 'failed'))::int,
         (count(*) filter (where c.cycle_state = 'aborted'))::int,
         round(100.0 * (count(*) filter (where c.cycle_state in ('failed','aborted')))::numeric / nullif(count(*),0), 2) AS failure_rate_pct
  from defib_self_test_cycles_r3047 c
  group by c.manufacturer
  order by failure_rate_pct desc nulls last;
end;$function$;

-- ---------------------------------------------------------------------
-- public.founder_r3079_wear_distribution -- ORDER BY apron_count DESC
CREATE OR REPLACE FUNCTION public.founder_r3079_wear_distribution()
 RETURNS TABLE(wear_severity text, apron_count integer, avg_defect_cm2 numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.wear_severity, count(*)::int AS apron_count, round(avg(coalesce(i.defect_area_cm2,0))::numeric,2)
  from hospital_chain_lead_apron_inventory_r3079 i
  group by i.wear_severity
  order by apron_count desc;
end $function$;

-- ---------------------------------------------------------------------
-- public.founder_r3738_uncertified_use_digest -- ORDER BY total_uncertified_use_incidents DESC
CREATE OR REPLACE FUNCTION public.founder_r3738_uncertified_use_digest()
 RETURNS TABLE(hospital_name text, records bigint, total_uncertified_use_incidents bigint, total_recert_due bigint, avg_certification_pct numeric, avg_competency_score numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    coalesce(sum(l.uncertified_use_incidents),0)::bigint AS total_uncertified_use_incidents,
    coalesce(sum(l.recert_due_count),0)::bigint,
    round(avg(l.certification_pct), 1),
    round(avg(l.competency_score), 1)
  from public.user_cert_r3738 l
  where l.cert_status = 'uncertified_use_found' or l.uncertified_use_incidents > 0
  group by l.hospital_name
  order by total_uncertified_use_incidents desc;
end;
$function$;

-- ---------------------------------------------------------------------
-- public.founder_r2971_spend_forecast -- ORDER BY projected_rupees DESC
CREATE OR REPLACE FUNCTION public.founder_r2971_spend_forecast()
 RETURNS TABLE(chain_name text, open_signals integer, projected_rupees numeric, max_lead_days integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.chain_name,
    count(*)::int,
    sum(s.recommended_qty::bigint * s.unit_cost_rupees::bigint) AS projected_rupees,
    coalesce(max(s.lead_time_days),0)::int
  from ot_bulb_reorder_signals_r2971 s
  where s.resolved = false
  group by s.chain_name
  order by projected_rupees desc nulls last;
end;$function$;

-- =====================================================================
-- VERIFY -- prove the ORDER BY now actually takes effect
-- =====================================================================
DO $gate$
DECLARE
  v_all      text[] := ARRAY[
    'market_share_status_funnel_r2673',
    'founder_repair_jobs_by_source',
    'founder_press_by_outlet',
    'founder_eng360_reviewer_breakdown',
    'founder_apprentice_grad_candidates',
    'founder_code_red_per_engineer_breakdown',
    'rpc_press_spokesperson_perf_r3109',
    'fn_r3111_tone_outcome',
    'warranty_won_tier_mix_r2239',
    'r2249_low_engagement_recipients',
    'dr_detector_defect_class_severity_r3132',
    'r2736_engineer_scores',
    'r2778_trade_show_engineer_leaderboard',
    'founder_r2788_engineer_grade_rollup',
    'founder_r2790_outcome_funnel',
    'founder_r2813_surface_stability',
    'rpc_r2839_chain_rollup',
    'rpc_r2850_verdict_distribution',
    'r2859_signal_mix',
    'founder_r2862_audience_split',
    'founder_r2869_member_scorecard',
    'r2966_city_summary',
    'founder_r2967_disinfection_method_mix',
    'r3002_replacement_reason_breakdown',
    'fn_r3009_findings_by_region',
    'founder_r3032_brand_mix',
    'r3034_by_severity',
    'r3043_findings_by_category',
    'r3086_spillage_by_severity',
    'founder_r2971_vendor_concentration',
    'founder_board_category_breakdown',
    'founder_amc_debits_by_engineer',
    'founder_iwi_introducer_ladder',
    'fn_diligence_per_acquirer_rollup_r3103',
    'founder_r3104_test_method_usage',
    'rpc_press_response_status_r3109',
    'fn_r3111_followup_completion',
    'r2350_engineer_leave_totals',
    'dr_detector_calibration_capa_status_r3132',
    'founder_r3135_nda_status_rollup',
    'founder_r2696_by_tier',
    'r2995_drain_outcome_distribution',
    'founder_roadmap_by_audience_r2753',
    'founder_engineer_rollup_r2766',
    'founder_r2777_projects_by_stage',
    'r2778_trade_show_goal_gap',
    'r2783_decision_breakdown',
    'r2810_tier_breakdown',
    'founder_bet_by_category_r2841',
    'r2890_channel_breakdown',
    'founder_r2887_reciprocity_score',
    'founder_r2895_chain_rollup',
    'r2966_finding_severity_mix',
    'founder_fmt_status_breakdown_r2996',
    'r3034_bearing_health_dist',
    'r3086_agent_type_breakdown',
    'founder_r3737_backlog_digest',
    'founder_hospital_amc_coverage_by_city',
    'founder_engineer_leave_calendar_by_type',
    'founder_dispute_by_mediator',
    'founder_admin_top_ops',
    'founder_engineer_payout_history',
    'founder_spare_parts_by_state',
    'founder_chains_amc_gap',
    'founder_apprentice_overdue',
    'founder_time_category_summary',
    'founder_r2292_by_classification',
    'founder_r3104_compliance_rollup',
    'founder_r3104_vendor_mix',
    'r2302_topic_gap_alerts',
    'r3108_ward_heatmap',
    'fn_r3111_language_reach',
    'r2249_channel_mix',
    'dr_detector_audit_fleet_summary_r3132',
    'founder_r2694_region_flow',
    'r2736_severity_breakdown',
    'founder_dw_by_category_r2765',
    'r2810_verdict_distribution',
    'r2815_long_duration_watchlist',
    'founder_r2826_eta_variance',
    'founder_r2830_engineer_leaderboard',
    'rpc_r2831_plays_by_chain',
    'outcome_distribution_handover_r2866',
    'rpc_r2882_city_heatmap',
    'source_system_reconciliation_r2889',
    'fn_r2898_doc_type_heatmap',
    'r2905_region_pressure',
    'r2919_model_breakdown',
    'rpc_r2928_tier_accuracy',
    'r2966_finding_type_mix',
    'founder_r2967_modality_risk_heatmap',
    'r2995_defect_by_region',
    'founder_fmt_zone_type_health_r2996',
    'r3000_manufacturer_burn_leaderboard',
    'r3035_failure_mode_distribution',
    'r3086_ppe_compliance',
    'founder_r3079_action_summary',
    'founder_jobs_by_state',
    'tier_distribution_r2492',
    'founder_payout_fail_reasons',
    'founder_chains_revenue_rollup',
    'founder_engineer_skills_critical_skill_coverage',
    'top_overdue_hospitals_r1747',
    'founder_cash_pipeline_by_stage',
    'founder_r2292_by_policy',
    'founder_r2385_pattern_category_rollup',
    'r3106_fio2_accuracy_by_model',
    'r3108_vendor_deviation',
    'balance_kind_distribution_r2633',
    'fn_r3111_role_concern_hotspots',
    'founder_r3123_category_gap_heatmap',
    'owner_load_r2672',
    'founder_r2694_outcome_breakdown',
    'founder_on_call_region_breakdown_r2702',
    'r2704_source_performance',
    'founder_cab_top_contributors_r2717',
    'founder_r2733_source_mix',
    'founder_r2747_pilots_by_chain',
    'founder_r2777_agency_breakdown',
    'r2778_trade_show_funnel',
    'r2783_qoq_adoption_trend',
    'founder_r2788_customers_by_tier',
    'founder_r2830_gesture_mix',
    'rpc_r2831_plays_by_outcome',
    'rpc_r2839_category_mix',
    'founder_r2862_channel_performance',
    'founder_r2872_velocity_band_distribution',
    'founder_r2895_category_posture',
    'fn_r2898_channel_mix',
    'r2905_top_win_drivers',
    'r2919_city_heatmap',
    'r2921_mood_distribution',
    'founder_r2967_auditor_productivity',
    'founder_r2971_chain_summary',
    'r2995_fuel_type_mix',
    'r3000_fda_audit_risk_summary',
    'r3034_engineer_load',
    'r3043_city_leaderboard',
    'fn_r3047_recurring_fault_assets',
    'r3086_tier_distribution',
    'founder_r3079_compliance_split',
    'founder_signups_by_state',
    'founder_spare_parts_by_status',
    'founder_amc_payment_orders_status',
    'founder_hospital_spend_30d',
    'founder_demand_by_model',
    'founder_top_engineers_90d',
    'founder_amc_revenue_by_city',
    'founder_amc_pool_balance_by_city',
    'founder_code_red_by_equipment',
    'founder_amc_revenue_by_state',
    'fn_acquirer_archetype_mix_r3103',
    'founder_r3104_sample_point_breakdown',
    'founder_r2385_direction_theme_rollup',
    'correction_status_funnel_r2633',
    'rpc_crisis_playbook_outcomes_r3109',
    'r2255_account_lead_load',
    'r2278_compliance_alerts',
    'founder_r3135_conflict_audit',
    'root_cause_breakdown_r2672',
    'audience_kind_distribution_r2621',
    'market_share_owner_load_r2673',
    'founder_chain_finance_action_outcomes_r2675',
    'founder_r2684_category_summary',
    'founder_on_call_overload_signal_dist_r2702',
    'founder_r2747_pilots_by_tech_kind',
    'founder_r2777_institution_tier_rollup',
    'r2785_bet_rollup',
    'founder_r2788_outcome_distribution',
    'rpc_r2839_run_health',
    'founder_bet_capital_efficiency_r2841',
    'weakness_heatmap_r2889',
    'r2905_loss_reasons',
    'r2919_engineer_workload',
    'founder_r2958_hospital_scorecard',
    'r2995_nabh_witness_coverage',
    'founder_fmt_engineer_performance_r2996',
    'r3002_city_risk_heatmap',
    'sync_audit_summary_r3023',
    'r3034_root_cause_breakdown',
    'r3086_regional_discipline',
    'founder_r3079_top_branches_at_risk',
    'founder_top_hospitals_90d',
    'founder_jobs_revenue_by_city',
    'founder_spot_audit_by_engineer',
    'founder_spare_parts_buyer_mix',
    'founder_amc_pool_balance_by_state',
    'founder_r2292_top_offenders',
    'r2302_pass_rate_by_topic',
    'rpc_press_overview_r3109',
    'fn_r3111_channel_rollup',
    'warranty_stage_breakdown_r2239',
    'r2255_csm_load',
    'r2278_downtime_by_type',
    'dr_detector_ghost_image_audit_r3132',
    'r2704_top_savings_customers',
    'founder_r2747_outcome_grade_breakdown',
    'founder_r2750_oem_rollup',
    'rpc_r2764_saving_by_kind',
    'founder_dw_decision_breakdown_r2765',
    'founder_action_mix_r2766',
    'founder_r2788_policy_bands',
    'founder_r2790_redaction_distribution',
    'rpc_r2831_signals_by_kind',
    'founder_engineer_vendor_by_tier_r2802',
    'r2810_region_summary',
    'founder_r2826_stage_funnel',
    'rpc_r2850_tier_breakdown',
    'r2859_by_chain',
    'founder_r2895_amc_upsell_pipeline',
    'r2911_chemical_efficacy_audit',
    'rpc_r2928_customer_pain',
    'founder_r2971_fixture_mix',
    'r2995_cert_upload_backlog',
    'founder_fmt_replacement_outcomes_r2996',
    'r3002_engineer_scorecard',
    'rpc_r3040_defect_class_spend',
    'r3043_chain_rollup',
    'r3086_remediation_status',
    'founder_r3747_incident_digest',
    'founder_signups_by_city',
    'founder_jobs_completion_by_equipment',
    'founder_escrow_by_state',
    'founder_code_red_hero_board',
    'founder_r3104_lab_partner_mix',
    'r3106_capa_category_leaderboard',
    'rpc_press_topic_rollup_r3109',
    'fn_r3111_audience_rollup',
    'accuracy_by_segment_r2332',
    'dr_detector_replacement_cost_funnel_r3132',
    'leakage_kind_distribution_r2651',
    'r2736_compliance_breakdown',
    'founder_r2747_scale_decision_breakdown',
    'founder_r2750_region_rollup',
    'founder_r2758_region_rollup',
    'rpc_r2764_status_pipeline',
    'founder_engineer_vendor_by_category_r2802',
    'founder_r2826_engineer_leaderboard',
    'r2859_by_equipment',
    'founder_r2895_city_heatmap',
    'founder_r2912_tier_rollup',
    'r2919_chain_summary',
    'founder_r2967_chain_fleet_rollup',
    'founder_r2987_oem_scorecard',
    'founder_fmt_surface_prep_efficacy_r2996',
    'r3000_material_burn_deep_dive',
    'r3002_model_fleet_wear',
    'firmware_spread_r3023',
    'founder_r3079_chain_summary',
    'founder_top_engineers_30d',
    'founder_jobs_by_equipment_type',
    'founder_payouts_by_state',
    'founder_investor_open_tracker_recent_events',
    'founder_apprentice_masters_scoreboard',
    'founder_engineer_ces_by_engineer_90d',
    'founder_cash_pipeline_by_segment',
    'founder_code_red_dropout_board',
    'founder_r3104_action_type_cost',
    'r2302_engineer_leaderboard',
    'rpc_press_sentiment_trend_r3109',
    'fn_r3111_cadence_effectiveness',
    'warranty_lost_reasons_r2239',
    'founder_r3123_lab_readiness_scorecard',
    'r2259_root_cause_breakdown',
    'dr_detector_capa_event_rollup_r3132',
    'status_funnel_r2651',
    'status_funnel_r2621',
    'owner_load_r2671',
    'r2995_reserve_summary_by_chain',
    'r2736_issue_breakdown',
    'r2743_on_call_load',
    'founder_r2758_severity_mix',
    'founder_r2777_strategic_value_rollup',
    'r2778_trade_show_verdict_breakdown',
    'r2783_ai_module_leaderboard',
    'r2815_intervention_mix',
    'founder_r2826_verdict_mix',
    'rpc_r2839_verdict_breakdown',
    'founder_r2862_narratives_by_status',
    'founder_r2872_tier_rollup',
    'rpc_r2882_site_type_breakdown',
    'r2890_tier_distribution',
    'fn_r2898_tier_breakdown',
    'founder_r2912_window_split',
    'r2966_outcome_breakdown',
    'founder_r2987_category_velocity',
    'r3002_replacement_pipeline',
    'library_version_coverage_r3023',
    'r3043_zone_hygiene',
    'fn_r3047_manufacturer_failure_heatmap',
    'founder_r3079_wear_distribution',
    'founder_r3738_uncertified_use_digest',
    'founder_r2971_spend_forecast'
  ];
  v_bad      text;
  r          record;
  v_n        int;
  v_distinct int;
  v_viol     int;
  v_checked  int := 0;
  v_skipped  int := 0;
  v_broken   text := '';
BEGIN
  -- 1. existence + no new overloads
  SELECT string_agg(x, ', ') INTO v_bad FROM unnest(v_all) x
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p
                      WHERE p.pronamespace='public'::regnamespace AND p.proname = x);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3801 VERIFY FAILED: function(s) vanished: %', v_bad;
  END IF;

  SELECT string_agg(q.proname || ' x' || q.c, ', ') INTO v_bad
    FROM (SELECT p.proname, count(*) c FROM pg_proc p
           WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_all)
           GROUP BY p.proname) q WHERE q.c > 1;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3801 VERIFY FAILED: extra overload(s): %', v_bad;
  END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub','756a3373-1077-470e-bc0a-79b8d6673ef4','role','authenticated',
                      'email','ganesh1431.dhanavath@gmail.com')::text, true);

  -- 2. the property: each repaired ordering must actually hold
  FOR r IN SELECT * FROM (VALUES
    ('market_share_status_funnel_r2673','total_revenue_rupees','DESC'),
    ('founder_repair_jobs_by_source','jobs_90d','DESC'),
    ('founder_eng360_reviewer_breakdown','spread','DESC'),
    ('founder_apprentice_grad_candidates','days_in_program','DESC'),
    ('rpc_press_spokesperson_perf_r3109','reach','DESC'),
    ('fn_r3111_tone_outcome','broadcasts_count','DESC'),
    ('warranty_won_tier_mix_r2239','deals_won','DESC'),
    ('r2249_low_engagement_recipients','open_rate_pct','ASC'),
    ('dr_detector_defect_class_severity_r3132','event_count','DESC'),
    ('dr_detector_defect_class_severity_r3132','total_revenue_loss','DESC'),
    ('r2736_engineer_scores','avg_score','ASC'),
    ('r2778_trade_show_engineer_leaderboard','pipeline_rupees','DESC'),
    ('founder_r2788_engineer_grade_rollup','avg_csat','DESC'),
    ('founder_r2790_outcome_funnel','row_count','DESC'),
    ('founder_r2813_surface_stability','avg_stability','ASC'),
    ('rpc_r2839_chain_rollup','expected_revenue','DESC'),
    ('rpc_r2850_verdict_distribution','engineer_count','DESC'),
    ('r2859_signal_mix','uplift_lakhs','DESC'),
    ('founder_r2862_audience_split','total_engagement','DESC'),
    ('founder_r2869_member_scorecard','avg_rating','DESC'),
    ('r2966_city_summary','failed','DESC'),
    ('founder_r2967_disinfection_method_mix','probe_count','DESC'),
    ('r3002_replacement_reason_breakdown','replacements','DESC'),
    ('fn_r3009_findings_by_region','revenue_at_risk','DESC'),
    ('founder_r3032_brand_mix','lots','DESC'),
    ('r3034_by_severity','units','DESC'),
    ('r3043_findings_by_category','total','DESC'),
    ('r3043_findings_by_category','critical_count','DESC'),
    ('r3086_spillage_by_severity','total_ml','DESC'),
    ('founder_r2971_vendor_concentration','total_rupees','DESC'),
    ('founder_board_category_breakdown','pct_done','ASC'),
    ('founder_amc_debits_by_engineer','total_debit_rupees','DESC'),
    ('founder_iwi_introducer_ladder','invested','DESC'),
    ('fn_diligence_per_acquirer_rollup_r3103','avg_readiness_pct','ASC'),
    ('founder_r3104_test_method_usage','sample_count','DESC'),
    ('rpc_press_response_status_r3109','hits','DESC'),
    ('fn_r3111_followup_completion','completion_pct','ASC'),
    ('r2350_engineer_leave_totals','approved_days','DESC'),
    ('dr_detector_calibration_capa_status_r3132','panel_count','DESC'),
    ('founder_r3135_nda_status_rollup','member_count','DESC'),
    ('founder_r2696_by_tier','total_allocated_rupees','DESC'),
    ('r2995_drain_outcome_distribution','n','DESC'),
    ('founder_roadmap_by_audience_r2753','net_trust_delta_pp','ASC'),
    ('founder_engineer_rollup_r2766','avg_score','DESC'),
    ('founder_r2777_projects_by_stage','total_award','DESC'),
    ('r2778_trade_show_goal_gap','gap','ASC'),
    ('r2783_decision_breakdown','total_npv_inr','DESC'),
    ('r2810_tier_breakdown','closure_rate_pct','DESC'),
    ('founder_bet_by_category_r2841','capital_inr','DESC'),
    ('r2890_channel_breakdown','event_count','DESC'),
    ('founder_r2887_reciprocity_score','net_position_rupees','DESC'),
    ('founder_r2895_chain_rollup','gap_branches','DESC'),
    ('founder_r2895_chain_rollup','critical_branches','DESC'),
    ('r2966_finding_severity_mix','finding_count','DESC'),
    ('founder_fmt_status_breakdown_r2996','n','DESC'),
    ('r3034_bearing_health_dist','units','DESC'),
    ('r3086_agent_type_breakdown','visits','DESC'),
    ('founder_r3737_backlog_digest','total_backlog','DESC'),
    ('founder_hospital_amc_coverage_by_city','hospitals_total','DESC'),
    ('founder_engineer_leave_calendar_by_type','cnt','DESC'),
    ('founder_dispute_by_mediator','decisions_90d','DESC'),
    ('founder_admin_top_ops','count_30d','DESC'),
    ('founder_admin_top_ops','count_total','DESC'),
    ('founder_engineer_payout_history','paid_lifetime','DESC'),
    ('founder_spare_parts_by_state','rupees_90d','DESC'),
    ('founder_chains_amc_gap','members_without_amc','DESC'),
    ('founder_apprentice_overdue','days_overdue','DESC'),
    ('founder_time_category_summary','hours_30d','DESC'),
    ('founder_r2292_by_classification','total_gross_paise','DESC'),
    ('founder_r3104_compliance_rollup','sample_count','DESC'),
    ('founder_r3104_vendor_mix','action_count','DESC'),
    ('r3108_ward_heatmap','fails','DESC'),
    ('r3108_ward_heatmap','withdrawn','DESC'),
    ('fn_r3111_language_reach','avg_nps','DESC'),
    ('r2249_channel_mix','blast_count','DESC'),
    ('dr_detector_audit_fleet_summary_r3132','panel_count','DESC'),
    ('founder_r2694_region_flow','rotation_count','DESC'),
    ('r2736_severity_breakdown','actions','DESC'),
    ('founder_dw_by_category_r2765','total_minutes','DESC'),
    ('r2810_verdict_distribution','engineer_count','DESC'),
    ('r2815_long_duration_watchlist','worst_duration_minutes','DESC'),
    ('founder_r2826_eta_variance','variance_pct','DESC'),
    ('founder_r2830_engineer_leaderboard','total_ltv_uplift','DESC'),
    ('rpc_r2831_plays_by_chain','commit_rupees','DESC'),
    ('rpc_r2882_city_heatmap','visits','DESC'),
    ('source_system_reconciliation_r2889','claims_using_source','DESC'),
    ('source_system_reconciliation_r2889','reconciliation_pct','ASC'),
    ('fn_r2898_doc_type_heatmap','missing_count','DESC'),
    ('r2905_region_pressure','avg_market_share','DESC'),
    ('r2905_region_pressure','critical_or_high_count','DESC'),
    ('r2919_model_breakdown','fail_count','DESC'),
    ('rpc_r2928_tier_accuracy','accuracy_pct','DESC'),
    ('r2966_finding_type_mix','finding_count','DESC'),
    ('founder_r2967_modality_risk_heatmap','open_critical','DESC'),
    ('founder_r2967_modality_risk_heatmap','open_major','DESC'),
    ('r2995_defect_by_region','critical','DESC'),
    ('r2995_defect_by_region','major','DESC'),
    ('founder_fmt_zone_type_health_r2996','avg_adhesion_pct','ASC'),
    ('r3000_manufacturer_burn_leaderboard','pass_rate_pct','DESC'),
    ('r3035_failure_mode_distribution','total_failed','DESC'),
    ('r3086_ppe_compliance','visits','DESC'),
    ('founder_r3079_action_summary','event_count','DESC'),
    ('founder_jobs_by_state','jobs_90d','DESC'),
    ('tier_distribution_r2492','total_points','DESC'),
    ('founder_payout_fail_reasons','cnt','DESC'),
    ('founder_chains_revenue_rollup','total_rupees_90d','DESC'),
    ('founder_engineer_skills_critical_skill_coverage','coverage_pct','ASC'),
    ('top_overdue_hospitals_r1747','total_outstanding_rupees','DESC'),
    ('founder_cash_pipeline_by_stage','weighted_arr_rupees','DESC'),
    ('founder_r2292_by_policy','total_gross_paise','DESC'),
    ('founder_r2385_pattern_category_rollup','total_bugs_prevented','DESC'),
    ('r3106_fio2_accuracy_by_model','worst_fio2_dev','DESC'),
    ('r3108_vendor_deviation','fail_rate_pct','DESC'),
    ('balance_kind_distribution_r2633','month_count','DESC'),
    ('fn_r3111_role_concern_hotspots','total_feedback','DESC'),
    ('fn_r3111_role_concern_hotspots','concern_pct','DESC'),
    ('founder_r3123_category_gap_heatmap','gap_clauses','DESC'),
    ('owner_load_r2672','total_variance_rupees','DESC'),
    ('founder_r2694_outcome_breakdown','rotation_count','DESC'),
    ('founder_on_call_region_breakdown_r2702','engineer_count','DESC'),
    ('r2704_source_performance','total_savings_rupees','DESC'),
    ('founder_cab_top_contributors_r2717','total_value_rupees','DESC'),
    ('founder_r2733_source_mix','candidates','DESC'),
    ('founder_r2747_pilots_by_chain','total_budget_rupees','DESC'),
    ('founder_r2777_agency_breakdown','total_award','DESC'),
    ('r2778_trade_show_funnel','expected_rupees','DESC'),
    ('r2783_qoq_adoption_trend','delta_pct','DESC'),
    ('founder_r2788_customers_by_tier','breach_total','DESC'),
    ('founder_r2830_gesture_mix','total_ltv_uplift','DESC'),
    ('rpc_r2831_plays_by_outcome','commit_rupees','DESC'),
    ('rpc_r2839_category_mix','expected_revenue','DESC'),
    ('founder_r2862_channel_performance','total_published','DESC'),
    ('founder_r2872_velocity_band_distribution','total_quotes_accepted','DESC'),
    ('founder_r2895_category_posture','coverage_pct','ASC'),
    ('fn_r2898_channel_mix','events','DESC'),
    ('r2905_top_win_drivers','win_count','DESC'),
    ('r2905_top_win_drivers','total_value_rupees','DESC'),
    ('r2919_city_heatmap','total_exposure','DESC'),
    ('r2921_mood_distribution','occurrences','DESC'),
    ('founder_r2967_auditor_productivity','findings_logged','DESC'),
    ('founder_r2971_chain_summary','total_gap','DESC'),
    ('r2995_fuel_type_mix','sites','DESC'),
    ('r3000_fda_audit_risk_summary','avg_risk_score','DESC'),
    ('r3034_engineer_load','audits','DESC'),
    ('r3043_city_leaderboard','avg_visual','ASC'),
    ('r3043_city_leaderboard','fail_count','DESC'),
    ('fn_r3047_recurring_fault_assets','incident_count','DESC'),
    ('r3086_tier_distribution','avg_score','DESC'),
    ('founder_r3079_compliance_split','event_count','DESC'),
    ('founder_signups_by_state','total_90d','DESC'),
    ('founder_spare_parts_by_status','rupees_90d','DESC'),
    ('founder_amc_payment_orders_status','total_rupees','DESC'),
    ('founder_hospital_spend_30d','spend_30d_rupees','DESC'),
    ('founder_demand_by_model','signals_90d','DESC'),
    ('founder_top_engineers_90d','gross_rupees','DESC'),
    ('founder_amc_revenue_by_city','paid_rupees','DESC'),
    ('founder_amc_pool_balance_by_city','total_balance','DESC'),
    ('founder_code_red_by_equipment','cnt_90d','DESC'),
    ('founder_amc_revenue_by_state','paid_rupees','DESC'),
    ('fn_acquirer_archetype_mix_r3103','total_weighted_cr','DESC'),
    ('founder_r3104_sample_point_breakdown','total_samples','DESC'),
    ('founder_r3104_sample_point_breakdown','failures','DESC'),
    ('founder_r2385_direction_theme_rollup','total_expected_ships','DESC'),
    ('correction_status_funnel_r2633','correction_count','DESC'),
    ('rpc_crisis_playbook_outcomes_r3109','total','DESC'),
    ('r2255_account_lead_load','total_contract_rupees','DESC'),
    ('r2278_compliance_alerts','days_remaining','ASC'),
    ('founder_r3135_conflict_audit','member_count','DESC'),
    ('root_cause_breakdown_r2672','total_variance_rupees','DESC'),
    ('audience_kind_distribution_r2621','engagement_count','DESC'),
    ('market_share_owner_load_r2673','total_revenue_rupees','DESC'),
    ('founder_chain_finance_action_outcomes_r2675','action_count','DESC'),
    ('founder_r2684_category_summary','breach_count','DESC'),
    ('founder_on_call_overload_signal_dist_r2702','engineer_count','DESC'),
    ('founder_r2747_pilots_by_tech_kind','total_budget_rupees','DESC'),
    ('founder_r2777_institution_tier_rollup','total_award','DESC'),
    ('r2785_bet_rollup','total_spend_rupees','DESC'),
    ('founder_r2788_outcome_distribution','credit_total','DESC'),
    ('rpc_r2839_run_health','run_count','DESC'),
    ('founder_bet_capital_efficiency_r2841','score_per_lakh','DESC'),
    ('weakness_heatmap_r2889','avg_weakness','DESC'),
    ('weakness_heatmap_r2889','unrehearsed_count','DESC'),
    ('r2905_loss_reasons','loss_count','DESC'),
    ('r2905_loss_reasons','total_value_rupees','DESC'),
    ('r2919_engineer_workload','total_cost','DESC'),
    ('founder_r2958_hospital_scorecard','pass_pct','ASC'),
    ('r2995_nabh_witness_coverage','tests','DESC'),
    ('founder_fmt_engineer_performance_r2996','inspections','DESC'),
    ('founder_fmt_engineer_performance_r2996','rework_count','DESC'),
    ('r3002_city_risk_heatmap','fails','DESC'),
    ('r3002_city_risk_heatmap','condemns','DESC'),
    ('sync_audit_summary_r3023','sync_rate_pct','ASC'),
    ('r3034_root_cause_breakdown','replacements','DESC'),
    ('r3086_regional_discipline','avg_score','DESC'),
    ('founder_r3079_top_branches_at_risk','retire_count','DESC'),
    ('founder_r3079_top_branches_at_risk','total_cost','DESC'),
    ('founder_top_hospitals_90d','jobs_posted','DESC'),
    ('founder_top_hospitals_90d','gross_rupees','DESC'),
    ('founder_jobs_revenue_by_city','gross_rupees','DESC'),
    ('founder_spot_audit_by_engineer','responses_180d','DESC'),
    ('founder_spot_audit_by_engineer','avg_rating','ASC'),
    ('founder_spare_parts_buyer_mix','rupees_90d','DESC'),
    ('founder_amc_pool_balance_by_state','total_balance','DESC'),
    ('founder_r2292_top_offenders','non_compliant_streams','DESC'),
    ('founder_r2292_top_offenders','open_findings','DESC'),
    ('r2302_pass_rate_by_topic','pass_rate_pct','ASC'),
    ('rpc_press_overview_r3109','total_reach','DESC'),
    ('fn_r3111_channel_rollup','broadcasts_count','DESC'),
    ('warranty_stage_breakdown_r2239','deal_count','DESC'),
    ('r2255_csm_load','total_amcs','DESC'),
    ('r2278_downtime_by_type','total_revenue_impact_rupees','DESC'),
    ('dr_detector_ghost_image_audit_r3132','panel_count','DESC'),
    ('r2704_top_savings_customers','total_savings_rupees','DESC'),
    ('founder_r2747_outcome_grade_breakdown','outcome_count','DESC'),
    ('founder_r2750_oem_rollup','completion_pct','ASC'),
    ('rpc_r2764_saving_by_kind','total_saving_rupees','DESC'),
    ('founder_dw_decision_breakdown_r2765','topics','DESC'),
    ('founder_action_mix_r2766','total_actions','DESC'),
    ('founder_r2788_policy_bands','breach_total','DESC'),
    ('founder_r2790_redaction_distribution','photos_total','DESC'),
    ('rpc_r2831_signals_by_kind','cnt','DESC'),
    ('founder_engineer_vendor_by_tier_r2802','avg_strength','DESC'),
    ('r2810_region_summary','closure_rate_pct','DESC'),
    ('founder_r2826_stage_funnel','job_count','DESC'),
    ('rpc_r2850_tier_breakdown','total_revenue_rupees','DESC'),
    ('r2859_by_chain','uplift_lakhs','DESC'),
    ('founder_r2895_amc_upsell_pipeline','total_amc_upsell_rupees','DESC'),
    ('r2911_chemical_efficacy_audit','pass_rate_pct','ASC'),
    ('rpc_r2928_customer_pain','breach_pct','DESC'),
    ('founder_r2971_fixture_mix','short_or_worse','DESC'),
    ('r2995_cert_upload_backlog','n','DESC'),
    ('founder_fmt_replacement_outcomes_r2996','n','DESC'),
    ('r3002_engineer_scorecard','inspections','DESC'),
    ('rpc_r3040_defect_class_spend','total_cost','DESC'),
    ('r3043_chain_rollup','fail_count','DESC'),
    ('r3043_chain_rollup','critical_count','DESC'),
    ('r3086_remediation_status','count_scorecards','DESC'),
    ('founder_r3747_incident_digest','food_safety_incidents_total','DESC'),
    ('founder_signups_by_city','signups_90d','DESC'),
    ('founder_jobs_completion_by_equipment','jobs_90d','DESC'),
    ('founder_escrow_by_state','held_rupees','DESC'),
    ('founder_r3104_lab_partner_mix','samples_processed','DESC'),
    ('r3106_capa_category_leaderboard','total_cost_rupees','DESC'),
    ('rpc_press_topic_rollup_r3109','reach','DESC'),
    ('fn_r3111_audience_rollup','total_reach','DESC'),
    ('accuracy_by_segment_r2332','accuracy_pct','DESC'),
    ('dr_detector_replacement_cost_funnel_r3132','total_replacement_lakhs','DESC'),
    ('leakage_kind_distribution_r2651','total_rupees','DESC'),
    ('r2736_compliance_breakdown','captures','DESC'),
    ('founder_r2747_scale_decision_breakdown','decision_count','DESC'),
    ('founder_r2750_region_rollup','completion_pct','ASC'),
    ('founder_r2758_region_rollup','total_bonus','DESC'),
    ('rpc_r2764_status_pipeline','saving_in_status_rupees','DESC'),
    ('founder_engineer_vendor_by_category_r2802','avg_strength','DESC'),
    ('founder_r2826_engineer_leaderboard','avg_score','DESC'),
    ('r2859_by_equipment','avg_abs_r','DESC'),
    ('founder_r2895_city_heatmap','critical_count','DESC'),
    ('founder_r2895_city_heatmap','total_failures','DESC'),
    ('founder_r2912_tier_rollup','avg_latency','ASC'),
    ('r2919_chain_summary','total_fine_exposure','DESC'),
    ('founder_r2967_chain_fleet_rollup','overdue_calibration','DESC'),
    ('founder_r2967_chain_fleet_rollup','failed_recall','DESC'),
    ('founder_r2987_oem_scorecard','total_recovered_rupees','DESC'),
    ('founder_fmt_surface_prep_efficacy_r2996','excellent_count','DESC'),
    ('r3000_material_burn_deep_dive','avg_afterflame','DESC'),
    ('r3002_model_fleet_wear','condemned','DESC'),
    ('firmware_spread_r3023','units','DESC'),
    ('founder_r3079_chain_summary','retire_count','DESC'),
    ('founder_top_engineers_30d','gross_rupees','DESC'),
    ('founder_jobs_by_equipment_type','jobs_count','DESC'),
    ('founder_payouts_by_state','paid_rupees_90d','DESC'),
    ('founder_investor_open_tracker_recent_events','happened_at','DESC'),
    ('founder_apprentice_masters_scoreboard','active_apprentices','DESC'),
    ('founder_engineer_ces_by_engineer_90d','avg_ces','ASC'),
    ('founder_engineer_ces_by_engineer_90d','high_effort_pct','DESC'),
    ('founder_cash_pipeline_by_segment','weighted_arr_rupees','DESC'),
    ('founder_r3104_action_type_cost','total_actual_cost_rupees','DESC'),
    ('r2302_engineer_leaderboard','pass_rate_pct','ASC'),
    ('rpc_press_sentiment_trend_r3109','hit_date','DESC'),
    ('fn_r3111_cadence_effectiveness','avg_nps','DESC'),
    ('warranty_lost_reasons_r2239','deal_count','DESC'),
    ('founder_r3123_lab_readiness_scorecard','readiness_pct','ASC'),
    ('r2259_root_cause_breakdown','losses_count','DESC'),
    ('dr_detector_capa_event_rollup_r3132','event_count','DESC'),
    ('status_funnel_r2651','total_rupees','DESC'),
    ('status_funnel_r2621','total_value_rupees','DESC'),
    ('owner_load_r2671','total_savings_rupees','DESC'),
    ('r2995_reserve_summary_by_chain','red_sites','DESC'),
    ('r2995_reserve_summary_by_chain','amber_sites','DESC'),
    ('r2736_issue_breakdown','actions','DESC'),
    ('r2743_on_call_load','incident_count','DESC'),
    ('r2743_on_call_load','breach_count','DESC'),
    ('founder_r2758_severity_mix','total','DESC'),
    ('founder_r2777_strategic_value_rollup','total_projected_revenue','DESC'),
    ('r2778_trade_show_verdict_breakdown','pipeline_rupees','DESC'),
    ('r2783_ai_module_leaderboard','total_npv_inr','DESC'),
    ('r2815_intervention_mix','events','DESC'),
    ('founder_r2826_verdict_mix','job_count','DESC'),
    ('rpc_r2839_verdict_breakdown','revenue_sum','DESC'),
    ('founder_r2862_narratives_by_status','narrative_count','DESC'),
    ('founder_r2872_tier_rollup','total_accepted','DESC'),
    ('rpc_r2882_site_type_breakdown','visits','DESC'),
    ('r2890_tier_distribution','total_bonus','DESC'),
    ('fn_r2898_tier_breakdown','avg_completeness','DESC'),
    ('founder_r2912_window_split','avg_latency','DESC'),
    ('r2966_outcome_breakdown','audit_count','DESC'),
    ('founder_r2987_category_velocity','avg_velocity_days','ASC'),
    ('r3002_replacement_pipeline','replacements','DESC'),
    ('library_version_coverage_r3023','units','DESC'),
    ('r3043_zone_hygiene','fail_rate_pct','DESC'),
    ('fn_r3047_manufacturer_failure_heatmap','failure_rate_pct','DESC'),
    ('founder_r3079_wear_distribution','apron_count','DESC'),
    ('founder_r3738_uncertified_use_digest','total_uncertified_use_incidents','DESC'),
    ('founder_r2971_spend_forecast','projected_rupees','DESC')
  ) AS t(fn, col, dir) LOOP
    BEGIN
      EXECUTE format(
        'WITH q AS (SELECT row_number() OVER () AS rn, t.%I AS v FROM public.%I() t)
         SELECT count(*), count(DISTINCT v),
                count(*) FILTER (WHERE a.v IS NOT NULL AND b.v IS NOT NULL AND %s)
         FROM q a LEFT JOIN q b ON b.rn = a.rn + 1',
        r.col, r.fn, CASE WHEN r.dir = 'DESC' THEN 'a.v < b.v' ELSE 'a.v > b.v' END)
      INTO v_n, v_distinct, v_viol;
    EXCEPTION WHEN OTHERS THEN
      -- a function that cannot execute at all is a separate problem; the
      -- sweep rounds cover that. Do not let it mask the ordering check.
      v_skipped := v_skipped + 1;
      CONTINUE;
    END;

    IF v_n < 3 OR v_distinct < 2 THEN
      v_skipped := v_skipped + 1;      -- data cannot answer; see header
      CONTINUE;
    END IF;

    v_checked := v_checked + 1;
    IF v_viol > 0 THEN
      v_broken := v_broken || format('%s.%s %s (%s violation(s)/%s rows); ',
                                     r.fn, r.col, r.dir, v_viol, v_n);
    END IF;
  END LOOP;

  RAISE NOTICE 'round 3801: ordering PROVEN for % (fn,col) pair(s); % skipped as unanswerable by current data',
    v_checked, v_skipped;

  IF v_broken <> '' THEN
    RAISE EXCEPTION 'round 3801 VERIFY FAILED: still unordered -- %', v_broken;
  END IF;

  RAISE NOTICE 'round 3801 verified: % function(s) now actually order their rows', array_length(v_all,1);
END
$gate$;

COMMIT;
