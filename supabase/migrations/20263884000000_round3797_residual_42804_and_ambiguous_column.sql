-- =====================================================================
-- Round 3797 -- the three defects round3796 left behind
-- =====================================================================
--
-- round3796 repaired 108 functions and its gate reported 4 still
-- statically broken. Those 4 are resolved here (3 real, 1 false
-- positive), and how they were found matters more than the fixes.
--
-- THE 42804 SUBTLETY: a return-type mismatch does NOT raise until the
-- query actually YIELDS A ROW. `engineer_sla_board` executed
-- successfully in the post-migration sweep purely because it currently
-- returns zero rows. So "it executes" is NOT evidence for a
-- RETURNS TABLE contract -- only the static check catches an empty-result
-- function, and only execution catches what the static check cannot
-- (round3793's NOT NULL class). Both passes are necessary; neither is
-- sufficient. That is why this migration exists at all.
--
-- 1. engineer_sla_board -- 42804, "Returned type character varying does
--    not match expected type text in column 2". `auth.users.email` is
--    varchar(255) but the function declares `engineer_email text`.
--    PostgreSQL will not silently widen varchar to text in a
--    RETURN QUERY row. Cast at the source and alias the table so the
--    reference is unambiguous.
--
-- 2. founder_bonded_intake_cumulative -- 42804, "Returned type numeric
--    does not match expected type bigint in column 3". The cause is a
--    genuinely easy one to miss: `sum()` over a **bigint** returns
--    **numeric**, not bigint (PostgreSQL widens to avoid overflow on the
--    accumulator). So the running totals
--    `sum(monthly.n) OVER (ORDER BY ...)` and `sum(monthly.q) OVER (...)`
--    are numeric while the declaration says bigint. Both are cast to
--    bigint. Only column 3 was reported because plpgsql_check stops at
--    the first mismatching column -- column 5 was the identical defect
--    masked behind it, which is the "one bug masks the next" pattern this
--    sweep has hit repeatedly. `sum(monthly.c)` is left alone: c is
--    already numeric and the column is declared numeric.
--
-- 3. founder_runway_history -- 42702, "column reference snapshot_date is
--    ambiguous". `snapshot_date` is both a RETURNS TABLE OUT parameter
--    and a real column of founder_cash_position_snapshots, and the
--    `snaps` CTE referenced it unqualified five times (twice inside
--    DISTINCT ON, once in the select list, twice in ORDER BY). Fixed the
--    way rounds 3781/3785 did -- alias the table (`cps`) and qualify
--    every reference -- because plpgsql only substitutes UNQUALIFIED
--    identifiers. Not fixed with round3789's
--    `#variable_conflict use_column` pragma: this function has an INTO
--    clause, which is exactly the exclusion criterion that kept 21
--    functions out of that wave.
--
-- 4. founder_live_ops_cockpit_v2_heartbeat -- 42P01, NOT FIXED, and that
--    is deliberate: it is a FALSE POSITIVE. The relation it cannot
--    resolve is `cron.job`, and pg_cron is not installed on this project
--    (see docs/CRON_SCHEDULING_GAP.md). But the function is the ops
--    heartbeat and is written defensively -- 16 separate EXCEPTION
--    handlers, one per metric -- so the unresolvable reference is caught
--    and the metric degrades to 0. Verified by execution: it returns 1
--    row. Editing it would remove working defensive code, which is the
--    same mistake round3785 avoided with `delete_my_account`. Same shape
--    as `founder_cron_status`. Recorded in the calibration notes.
--
-- VERIFICATION runs inside the transaction and, given lesson (1) above,
-- does not rely on execution alone: it asserts plpgsql_check reports ZERO
-- errors for the three repaired functions, plus the usual
-- existence/overload/signature checks.

BEGIN;

-- ---------------------------------------------------------------------
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
    coalesce((SELECT u.email::text FROM auth.users u WHERE u.id = pe.engineer_user_id), 'unknown'),
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
    sum(monthly.n) OVER (ORDER BY monthly.month_ist)::bigint,
    monthly.q,
    sum(monthly.q) OVER (ORDER BY monthly.month_ist)::bigint,
    sum(monthly.c) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$function$;

-- ---------------------------------------------------------------------
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
    SELECT DISTINCT ON (date_trunc('month', cps.snapshot_date))
           date_trunc('month', cps.snapshot_date)::date AS m_start,
           cps.snapshot_date,
           cps.cash_balance_rupees,
           cps.snapshot_note
      FROM public.founder_cash_position_snapshots cps
     ORDER BY date_trunc('month', cps.snapshot_date), cps.snapshot_date DESC
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

-- =====================================================================
-- VERIFY
-- =====================================================================
DO $gate$
DECLARE
  v_names text[] := ARRAY[
    'engineer_sla_board',
    'founder_bonded_intake_cumulative',
    'founder_runway_history'
  ];
  v_bad   text;
BEGIN
  SELECT string_agg(x, ', ') INTO v_bad FROM unnest(v_names) x
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p
                      WHERE p.pronamespace='public'::regnamespace AND p.proname = x);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3797 VERIFY FAILED: function(s) vanished: %', v_bad;
  END IF;

  SELECT string_agg(q.proname || ' x' || q.c, ', ') INTO v_bad
    FROM (SELECT p.proname, count(*) c FROM pg_proc p
           WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
           GROUP BY p.proname) q WHERE q.c > 1;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3797 VERIFY FAILED: extra overload(s): %', v_bad;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='plpgsql_check') THEN
    SELECT string_agg(DISTINCT p.proname || ' [' || e.sqlstate || '] ' ||
                      replace(coalesce(e.detail, e.message), chr(10), ' '), '; ') INTO v_bad
      FROM pg_proc p CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.prolang=(SELECT oid FROM pg_language WHERE lanname='plpgsql')
       AND p.prorettype <> 'trigger'::regtype
       AND p.proname = ANY(v_names) AND e.level='error';
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'round 3797 VERIFY FAILED: still broken: %', v_bad;
    END IF;
    RAISE NOTICE 'round 3797: all % function(s) now statically clean', array_length(v_names,1);
  END IF;

  RAISE NOTICE 'round 3797 verified: 3 residual defects repaired; heartbeat 42P01 left as a documented false positive';
END
$gate$;

COMMIT;
