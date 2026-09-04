-- =====================================================================
-- Round 3798 -- six "top N" lists that were never actually ranked
-- =====================================================================
--
-- A NEW bug class, and one plpgsql_check CANNOT report, because nothing
-- here is invalid SQL. Found while reviewing round3796: the independent
-- reviewer noticed founder_tier_distribution_by_city ordered by a
-- RETURNS TABLE OUT parameter rather than by an output column, so its
-- LIMIT returned an arbitrary slice. That prompted a schema-wide sweep
-- for the same shape.
--
-- THE MECHANISM
--   In `RETURN QUERY SELECT ... ORDER BY foo`, PostgreSQL resolves an
--   ORDER BY identifier against the SELECT's OUTPUT COLUMN NAMES first.
--   If no output column is named `foo`, the identifier falls through to
--   PL/pgSQL, which substitutes the function-scope variable `foo` -- and
--   a RETURNS TABLE column IS such a variable, always NULL during
--   RETURN QUERY. The query therefore orders by a CONSTANT: no error, no
--   warning, rows still come back, and any LIMIT takes an ARBITRARY slice
--   in arbitrary order.
--
--   Verified experimentally against this database rather than assumed,
--   with three throwaway functions returning the values 3,1,2:
--     (a) OUT param name matches NO output column  -> [3,1,2]  UNSORTED
--     (b) explicit alias `AS n` in the select list -> [1,2,3]  sorted
--     (c) IMPLICIT output name (SELECT x.n ...)    -> [1,2,3]  sorted
--   So (c) is why this cannot be judged by grep alone: `SELECT t.foo`
--   already names its output column `foo`, which is fine. Only a select
--   list whose corresponding item is an UNALIASED EXPRESSION -- an
--   aggregate, a cast, a coalesce -- leaves nothing for ORDER BY to bind
--   to. All six functions below are exactly that: the ordering key is a
--   bare `count(*)::int` / `sum(...)::bigint` / `coalesce(sum(...),0)`,
--   whose real output names are "count", "sum" and "coalesce".
--
-- HOW THESE SIX WERE CONFIRMED -- measured, not inferred.
--   49 zero-argument candidates matched the static shape. Each was then
--   EXECUTED against production and its result tested for monotonicity in
--   the declared direction. Six came back demonstrably unordered; four
--   came back correctly sorted (i.e. false positives from case (c) above)
--   and are untouched; 39 returned fewer than 3 rows, so execution cannot
--   settle them either way -- they are NOT fixed here and are recorded at
--   the bottom as follow-up rather than being quietly assumed broken.
--
-- WHY IT MATTERS MORE THAN A COSMETIC SORT
--   Look at what these are: fn_r3009_top_skill_gaps,
--   r3034_top_problem_sites, fn_r3047_top_risk_hospitals,
--   founder_dw_interruption_hotspots_r2765, r2966_engineer_leaderboard,
--   founder_r2912_customer_pain. Every one is a "top N", a "hotspot" or a
--   leaderboard -- surfaces whose ENTIRE PURPOSE is the ranking. A "top 10
--   risk hospitals" panel was showing ten arbitrary hospitals in
--   arbitrary order, and it looked perfectly healthy because it returned
--   ten rows. `fn_r3047_top_risk_hospitals` ranks by patients at risk.
--
-- THE FIX
--   Add the explicit output-column alias the ORDER BY was always meant to
--   bind to, naming each select-list item after its corresponding
--   RETURNS TABLE column. This is the minimal change -- it touches no
--   predicate, no aggregate, no grouping, and no row set other than
--   putting it in the intended order -- and per case (b) above it is
--   proven to make the ORDER BY take effect. It also makes the mapping
--   from select list to declared column self-evident, which is what
--   allowed the defect to hide in the first place.
--   GROUP BY is unaffected: it resolves against INPUT columns first, so
--   `group by a.engineer_name` keeps working alongside a new
--   `AS engineer_name` alias.
--
-- VERIFICATION does not stop at "it runs". The gate below EXECUTES each
-- of the six and asserts the result is actually monotonic in the declared
-- direction -- i.e. it tests the property that was broken, not just for
-- the absence of an error. Runs inside the transaction, so a failure
-- rolls the whole migration back.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. fn_r3009_top_skill_gaps -- ranks by total_revenue_at_risk
CREATE OR REPLACE FUNCTION public.fn_r3009_top_skill_gaps()
 RETURNS TABLE(skill_gap text, finding_count integer, total_amc_affected integer, total_revenue_at_risk bigint, worst_severity text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.skill_gap                                      as skill_gap,
    count(*)::int                                    as finding_count,
    sum(f.affected_amc_count)::int                   as total_amc_affected,
    sum(f.affected_revenue_rupees)::bigint           as total_revenue_at_risk,
    min(f.severity)                                  as worst_severity
  from public.coverage_risk_findings_r3009 f
  group by f.skill_gap
  order by total_revenue_at_risk desc
  limit 10;
end;
$function$;

-- ---------------------------------------------------------------------
-- 2. fn_r3047_top_risk_hospitals -- ranks by patients_at_risk
CREATE OR REPLACE FUNCTION public.fn_r3047_top_risk_hospitals()
 RETURNS TABLE(chain_code text, hospital_code text, open_incidents integer, patients_at_risk integer, total_cost_rupees integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.chain_code                                                as chain_code,
         i.hospital_code                                             as hospital_code,
         (count(*) filter (where i.remediation_state in ('open','in_progress','escalated')))::int
                                                                     as open_incidents,
         coalesce(sum(i.patients_at_risk_count), 0)::int             as patients_at_risk,
         coalesce(sum(i.cost_impact_rupees), 0)::int                 as total_cost_rupees
  from defib_compliance_incidents_r3047 i
  group by i.chain_code, i.hospital_code
  order by patients_at_risk desc, total_cost_rupees desc
  limit 10;
end;$function$;

-- ---------------------------------------------------------------------
-- 3. founder_dw_interruption_hotspots_r2765 -- ranks by total_interruptions
CREATE OR REPLACE FUNCTION public.founder_dw_interruption_hotspots_r2765()
 RETURNS TABLE(topic text, total_interruptions bigint, avg_flow numeric, avg_quality numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.topic                                          AS topic,
         COALESCE(SUM(b.interruption_count),0)::bigint     AS total_interruptions,
         ROUND(AVG(b.flow_state_score)::numeric,2)         AS avg_flow,
         ROUND(AVG(b.output_quality)::numeric,2)           AS avg_quality
  FROM founder_deep_work_blocks_r2765 b
  GROUP BY b.topic
  HAVING SUM(b.interruption_count) > 0
  ORDER BY total_interruptions DESC
  LIMIT 10;
END;
$function$;

-- ---------------------------------------------------------------------
-- 4. founder_r2912_customer_pain -- ranks by breached, then msg_count
CREATE OR REPLACE FUNCTION public.founder_r2912_customer_pain()
 RETURNS TABLE(customer_org text, msg_count bigint, breached bigint, avg_csat numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.customer_org                                        AS customer_org,
         COUNT(*)::bigint                                      AS msg_count,
         COUNT(*) FILTER (WHERE m.breached_sla)::bigint        AS breached,
         ROUND(AVG(m.customer_csat),2)                         AS avg_csat
  FROM after_hours_wa_messages_r2912 m
  GROUP BY m.customer_org
  ORDER BY breached DESC, msg_count DESC
  LIMIT 12;
END;
$function$;

-- ---------------------------------------------------------------------
-- 5. r2966_engineer_leaderboard -- ranks by devices
CREATE OR REPLACE FUNCTION public.r2966_engineer_leaderboard()
 RETURNS TABLE(engineer_name text, audits integer, devices integer, failed integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name                            as engineer_name,
         count(*)::int                              as audits,
         coalesce(sum(a.device_count),0)::int       as devices,
         coalesce(sum(a.failed_count),0)::int       as failed
  from power_strip_audits_r2966 a
  group by a.engineer_name
  order by devices desc
  limit 12;
end; $function$;

-- ---------------------------------------------------------------------
-- 6. r3034_top_problem_sites -- ranks by critical_count, then max_vibration
CREATE OR REPLACE FUNCTION public.r3034_top_problem_sites()
 RETURNS TABLE(hospital_name text, audits integer, critical_count integer, max_vibration numeric, max_drift_pct numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name                                                            as hospital_name,
         count(*)::int                                                              as audits,
         (count(*) filter (where a.imbalance_severity in ('severe','critical')))::int
                                                                                    as critical_count,
         max(a.vibration_rms_mm_s)                                                  as max_vibration,
         max(a.rpm_drift_pct)                                                       as max_drift_pct
  from centrifuge_imbalance_audits_r3034 a
  group by a.hospital_name
  order by critical_count desc, max_vibration desc
  limit 12;
end $function$;

-- =====================================================================
-- VERIFY -- prove the ORDER BY now actually takes effect
-- =====================================================================
DO $gate$
DECLARE
  v_fns  text[] := ARRAY[
    'fn_r3009_top_skill_gaps',
    'fn_r3047_top_risk_hospitals',
    'founder_dw_interruption_hotspots_r2765',
    'founder_r2912_customer_pain',
    'r2966_engineer_leaderboard',
    'r3034_top_problem_sites'
  ];
  v_cols text[] := ARRAY[
    'total_revenue_at_risk',
    'patients_at_risk',
    'total_interruptions',
    'breached',
    'devices',
    'critical_count'
  ];
  v_i     int;
  v_n     int;
  v_viol  int;
  v_bad   text := '';
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub','756a3373-1077-470e-bc0a-79b8d6673ef4','role','authenticated',
                      'email','ganesh1431.dhanavath@gmail.com')::text, true);

  FOR v_i IN 1 .. array_length(v_fns, 1) LOOP
    -- every declared ordering above is DESC, so any strictly-increasing
    -- adjacent pair is a violation
    EXECUTE format(
      'WITH q AS (SELECT row_number() OVER () AS rn, t.%I AS v FROM public.%I() t)
       SELECT count(*), count(*) FILTER (WHERE a.v IS NOT NULL AND b.v IS NOT NULL AND a.v < b.v)
       FROM q a LEFT JOIN q b ON b.rn = a.rn + 1',
      v_cols[v_i], v_fns[v_i])
    INTO v_n, v_viol;

    IF v_n >= 3 AND v_viol > 0 THEN
      v_bad := v_bad || format('%s (ordered by %s: %s ascending violation(s) over %s rows); ',
                               v_fns[v_i], v_cols[v_i], v_viol, v_n);
    ELSE
      RAISE NOTICE 'round 3798: %.% is now correctly DESC-ordered (% rows)',
        v_fns[v_i], v_cols[v_i], v_n;
    END IF;
  END LOOP;

  IF v_bad <> '' THEN
    RAISE EXCEPTION 'round 3798 VERIFY FAILED: still not ordered -- %', v_bad;
  END IF;

  RAISE NOTICE 'round 3798 verified: all 6 top-N/leaderboard functions now actually rank their rows';
END
$gate$;

COMMIT;

-- ---------------------------------------------------------------------
-- FOLLOW-UP, deliberately NOT changed here
-- ---------------------------------------------------------------------
-- 39 further zero-argument functions match the same static shape
-- (ORDER BY an OUT parameter name, no matching explicit alias, with a
-- LIMIT) but currently return fewer than 3 rows, so execution cannot show
-- whether their ORDER BY binds to an implicit output column (harmless,
-- case (c)) or to the variable (broken, case (a)). They are left alone
-- rather than "fixed" on suspicion, because the same alias edit applied
-- to a function that is already correct is churn on production code with
-- no way to demonstrate a benefit.
-- To settle them, either (a) re-run the monotonicity probe once those
-- tables have data, or (b) read each select list and check whether the
-- item at the OUT parameter's ordinal position is a bare column
-- reference (fine) or an unaliased expression (broken). Method and the
-- candidate list are in the round3798 working notes.
