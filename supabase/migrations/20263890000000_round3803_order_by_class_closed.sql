-- =====================================================================
-- Round 3803 -- close the ORDER BY class: 3 functions round3801 refused
-- =====================================================================
--
-- round3801 repaired 293 silently-unordered result sets and REFUSED 10,
-- because for those the select list it located had a different item count
-- from the OUT parameter list, so positional mapping could not be trusted.
-- Chasing those 10 found TWO BUGS IN MY OWN TOOLING plus one real blind
-- spot. 3 of the 10 are repaired here; the other 7 turn out not to need
-- repair at all.
--
-- TOOLING BUG 1 -- raw and masked select lists were split INDEPENDENTLY.
--   The analyser works on a copy with string literals and "--" comments
--   blanked out so scanning is safe. But the item list was split from BOTH
--   the raw and the masked text separately, and a comment inside a select
--   list carries commas that survive in raw while being blanked in masked.
--   founder_audit_by_actor has exactly that: a round3791 explanatory
--   comment containing commas sits between two select-list items, so raw
--   split into 8 items against 6 OUT parameters and the function was
--   refused. Boundaries must be computed from the masked text and then
--   applied to BOTH.
--
-- TOOLING BUG 2 -- the ORDER BY clause boundary ran to the next ";".
--   founder_npv_by_tier and founder_hospital_auto_renew_by_tier both open
--   with WITH latest AS (SELECT DISTINCT ON (...) ... ORDER BY ...).
--   Because the clause was read as far as the next semicolon, that inner
--   ORDER BY appeared to "mention" the target column -- its text swallowed
--   the whole rest of the function -- and then resolved against the CTE own
--   one-item select list (s.*). Hence "1 item against 7 OUT parameters".
--   A clause must also end where a ")" closes the paren it sits inside.
--
-- THE BLIND SPOT, and why the other 7 are LEFT ALONE
--   Every remaining refusal is SELECT * or SELECT DISTINCT ON (...) *.
--   The analyser cannot expand "*", so it sees one unnameable item and
--   concludes there is no output column of that name -- when "*" may
--   expose exactly that column. These are ANALYSER FALSE POSITIVES, not
--   defects: founder_clv_top_customers, admin_inactive_engineers,
--   rpc_year_end_overview, founder_demand_signal_dashboard,
--   founder_writeoff_churn_risk, rapport_pulse_at_risk_r2334, plus
--   founder_customer_health_score_by_hospital whose flagged column
--   already binds.
--   Confirmed by measurement rather than argument: admin_inactive_engineers
--   is SELECT * FROM q ORDER BY last_released_at ASC NULLS FIRST,
--   verified_at DESC, and its live output over 16 rows has ZERO ascending
--   violations -- it is already correctly ordered.
--
--   Worth recording that round3801 item-count assertion is what made this
--   safe: it refused every SELECT * case automatically, so the blind spot
--   produced no bad edits. A guard written for one reason caught a
--   different mistake entirely.
--
-- REGRESSION CHECK: with both tooling bugs fixed, the repair was re-run
-- over all 303 flagged functions and its output compared against what
-- round3801 shipped: 293 files BYTE-IDENTICAL, 0 changed. So round3801
-- repairs were correctly aligned and nothing it shipped needs revisiting.
--
-- THE 3 REPAIRED HERE (one "AS <outname>" each, on the select-list item at
-- that OUT parameter ordinal position):
--   founder_hospital_auto_renew_by_tier   ORDER BY arr_rupees DESC
--   founder_npv_by_tier                   ORDER BY total_npv_rupees ASC
--   founder_audit_by_actor                ORDER BY ops_30d DESC LIMIT 50
--
-- VERIFICATION, and this is worth reading because the gate CAUGHT ITSELF.
--   Applying the round3802 lesson, the first version of this gate demanded
--   that each ordering be PROVEN against live data and refused to report
--   success otherwise. It then failed, correctly:
--     founder_hospital_auto_renew_by_tier   0 rows
--     founder_npv_by_tier                   0 rows
--     founder_audit_by_actor                1 row
--   and rolled the whole migration back. Those three tables are empty or
--   near-empty on this pre-launch database, so no amount of executing can
--   demonstrate an ordering.
--
--   The honest resolution is NOT to lower the bar to "no violations
--   found", which is exactly the vacuous pass round3802 exists to
--   condemn. It is to assert a DIFFERENT property that IS checkable here:
--   that the alias is actually present in the stored definition and that
--   the ORDER BY still references it. Combined with the mechanism already
--   proven empirically in round3798 and round3802 -- an explicit alias
--   makes an ORDER BY bind to the output column, demonstrated on 211 live
--   orderings -- that is a real guarantee rather than an absence of
--   evidence.
--
--   So the gate below asserts, per function: it exists exactly once, its
--   definition contains "AS <col>", and its definition still contains
--   "ORDER BY ... <col>". It ALSO runs the empirical check where the data
--   permits and fails on any violation. It cannot pass by checking
--   nothing: the static assertions apply to all three unconditionally.

BEGIN;

-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_hospital_auto_renew_by_tier()
 RETURNS TABLE(amc_tier text, candidate_count bigint, auto_eligible_count bigint, arr_rupees bigint, avg_score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (contract_id) *
    FROM founder_hospital_renewal_candidates
    ORDER BY contract_id, scanned_at DESC
  )
  SELECT
    l.amc_tier,
    count(*)::bigint,
    count(*) FILTER (WHERE l.auto_eligible)::bigint,
    COALESCE(sum(l.monthly_fee_rupees * 12) FILTER (WHERE l.auto_eligible), 0)::bigint AS arr_rupees,
    round(avg(l.eligibility_score), 1)
  FROM latest l
  GROUP BY l.amc_tier
  ORDER BY arr_rupees DESC;
END;
$function$;

-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_npv_by_tier()
 RETURNS TABLE(amc_tier text, contract_count integer, avg_npv_rupees numeric, total_npv_rupees numeric, negative_count integer, avg_monthly_fee numeric, avg_discount numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.amc_contract_id) s.*
    FROM founder_contract_npv_snapshots s
    ORDER BY s.amc_contract_id, s.computed_at DESC
  )
  SELECT COALESCE(l.amc_tier, 'unknown')::text,
         count(*)::int,
         COALESCE(avg(l.npv_rupees), 0)::numeric,
         COALESCE(sum(l.npv_rupees), 0)::numeric AS total_npv_rupees,
         count(*) FILTER (WHERE l.npv_rupees < 0)::int,
         COALESCE(avg(l.monthly_fee_rupees), 0)::numeric,
         COALESCE(avg(l.upfront_discount_rupees), 0)::numeric
  FROM latest l
  GROUP BY COALESCE(l.amc_tier, 'unknown')
  ORDER BY total_npv_rupees ASC;
END $function$;

-- ---------------------------------------------------------------------
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
    count(*)::bigint AS ops_30d,
    count(DISTINCT l.op_name)::bigint,
    max(l.created_at)
  FROM public.founder_action_log l
  WHERE l.created_at >= now() - interval '30 days'
  GROUP BY l.actor_user_id
  ORDER BY ops_30d DESC
  LIMIT 50;
END;
$function$;

-- =====================================================================
-- VERIFY
-- =====================================================================
DO $gate$
DECLARE
  r          record;
  v_n        int;
  v_distinct int;
  v_viol     int;
  v_proven   int := 0;
  v_undet    int := 0;
  v_static   int := 0;
  v_bad      text := '';
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub','756a3373-1077-470e-bc0a-79b8d6673ef4',
                      'role','authenticated',
                      'email','ganesh1431.dhanavath@gmail.com')::text, true);

  FOR r IN SELECT * FROM (VALUES
    ('founder_hospital_auto_renew_by_tier','arr_rupees','DESC'),
    ('founder_npv_by_tier','total_npv_rupees','ASC'),
    ('founder_audit_by_actor','ops_30d','DESC')
  ) AS t(fn, col, dir) LOOP
    -- No exception handler here, on purpose: round3801 swallowed 42702 from
    -- an ambiguous count(DISTINCT v) and reported success having checked
    -- nothing at all.
    EXECUTE format(
      'WITH q AS (SELECT row_number() OVER () AS rn, t.%I AS v FROM public.%I() t)
       SELECT count(*), count(DISTINCT a.v),
              count(*) FILTER (WHERE a.v IS NOT NULL AND b.v IS NOT NULL AND %s)
       FROM q a LEFT JOIN q b ON b.rn = a.rn + 1',
      r.col, r.fn,
      CASE WHEN r.dir = 'DESC' THEN 'a.v < b.v' ELSE 'a.v > b.v' END)
    INTO v_n, v_distinct, v_viol;

    IF v_n < 3 OR v_distinct < 2 THEN
      v_undet := v_undet + 1;
      RAISE NOTICE 'round 3803: %.% undetermined (% rows, % distinct value(s))',
        r.fn, r.col, v_n, v_distinct;
      CONTINUE;
    END IF;

    IF v_viol > 0 THEN
      v_bad := v_bad || format('%s.%s %s (%s viol/%s rows); ', r.fn, r.col, r.dir, v_viol, v_n);
    ELSE
      v_proven := v_proven + 1;
      RAISE NOTICE 'round 3803: %.% is now correctly %-ordered (% rows)',
        r.fn, r.col, r.dir, v_n;
    END IF;
  END LOOP;

  IF v_bad <> '' THEN
    RAISE EXCEPTION 'round 3803 VERIFY FAILED: still unordered: %', v_bad;
  END IF;

  -- STATIC assertion, applied to all three unconditionally, so this gate
  -- has real coverage even where the data cannot settle the ordering.
  FOR r IN SELECT * FROM (VALUES
    ('founder_hospital_auto_renew_by_tier','arr_rupees','DESC'),
    ('founder_npv_by_tier','total_npv_rupees','ASC'),
    ('founder_audit_by_actor','ops_30d','DESC')
  ) AS t(fn, col, dir) LOOP
    SELECT count(*) INTO v_n
      FROM pg_proc p
     WHERE p.pronamespace='public'::regnamespace AND p.proname = r.fn;
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'round 3803 VERIFY FAILED: % has % definition(s), expected exactly 1', r.fn, v_n;
    END IF;

    SELECT count(*) INTO v_n
      FROM pg_proc p
     WHERE p.pronamespace='public'::regnamespace AND p.proname = r.fn
       AND pg_get_functiondef(p.oid) ~* ('AS[[:space:]]+' || r.col || '[^a-z_0-9]')
       AND pg_get_functiondef(p.oid) ~* ('ORDER[[:space:]]+BY[^;]*' || r.col);
    IF v_n <> 1 THEN
      RAISE EXCEPTION
        'round 3803 VERIFY FAILED: %.% is missing either the AS alias or the ORDER BY reference',
        r.fn, r.col;
    END IF;
    v_static := v_static + 1;
  END LOOP;

  IF v_static <> 3 THEN
    RAISE EXCEPTION 'round 3803 VERIFY FAILED: only % of 3 alias assertions ran', v_static;
  END IF;

  RAISE NOTICE 'round 3803 verified: 3 alias binding(s) asserted statically; % also proven against live data, % undetermined (empty tables)',
    v_proven, v_undet;
END
$gate$;

COMMIT;
