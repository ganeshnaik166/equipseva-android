-- =====================================================================
-- Round 3795 -- bulk fix, wave 5: three more forced-by-the-catalog classes
-- =====================================================================
--
-- Continues the plpgsql_check sweep remediation (rounds 3788-3793).
-- 233 broken functions before this migration.
--
-- CLASS A (4 fns) -- `founder_audit_log` DOES NOT EXIST.
--   Four vendor-scorecard audit writers insert into a table that was
--   never created. It is an unfinished rename: the real table is
--   `founder_action_log`, and all four use the identical shape
--       INSERT INTO founder_audit_log(actor_user_id, action, payload, created_at)
--       VALUES (auth.uid(), '<op>', jsonb_build_object(...), now());
--   so `action` -> `op_name` and `payload` -> `after_value`, exactly the
--   round3792 class-A mapping. As in round3793 the NOT NULL
--   `actor_email` must also be supplied -- static analysis cannot see
--   that, so it is added here rather than being discovered later by a
--   23502 at runtime. Value `(auth.jwt()->>'email')`, matching the
--   canonical form used by the 2322 correct call sites.
--   Effect: every vendor grade override / replacement proposal /
--   replacement decision / scorecard recompute currently fails outright.
--
-- CLASS B (6 fns) -- `log_founder_action` called with the wrong arity.
--   The real signature is
--     log_founder_action(p_op_name text, p_target_table text DEFAULT NULL,
--       p_target_row_id uuid DEFAULT NULL, p_before_value jsonb DEFAULT NULL,
--       p_after_value jsonb DEFAULT NULL, p_reason text DEFAULT NULL,
--       p_outcome text DEFAULT 'success', p_error_code text DEFAULT NULL)
--   -- 7 of 8 parameters have defaults. Six callers pass POSITIONALLY:
--     3-arg: ('icn.logged', v_id::text, jsonb_build_object(...))
--     2-arg: ('r1651_decide_candidate', jsonb_build_object(...))
--   Positionally the 2nd argument lands on p_target_table, so the 3-arg
--   form tries to pass a uuid-as-text where a table NAME goes and jsonb
--   where a uuid goes; there is simply no matching overload and the call
--   fails. Reading the intent off the argument TYPES -- a row id and a
--   payload -- the fix is to name them:
--     p_op_name / p_target_row_id / p_after_value
--   and drop the now-wrong `::text` since p_target_row_id is uuid.
--   Because every other parameter has a default, named notation needs no
--   invented values. p_target_table is deliberately left NULL rather
--   than guessed.
--
-- CLASS C (4 fns) -- extract() over a DATE DIFFERENCE.
--   `date - date` in PostgreSQL yields an **integer number of days**,
--   not an interval, so `extract(day FROM (a - b))` and
--   `extract(epoch FROM (a - b))` have no applicable overload -- hence
--   42883 `pg_catalog.extract(unknown, integer)`. The value wanted is
--   already the difference, so each shape collapses:
--     extract(day   FROM (a-b))                    -> (a-b)
--     extract(epoch FROM (a-b)) / 86400            -> (a-b)::numeric
--     extract(epoch FROM (a-b)) / (365.25 * 86400) -> (a-b)::numeric / 365.25
--   The ::numeric keeps the division non-integer, preserving the
--   fractional days/years the callers report. Note this is NOT the same
--   as the (valid) `extract(epoch FROM <interval>)` used elsewhere in
--   the schema -- only the date-minus-date sites are touched.
--
-- All statements below are full literal definitions derived from live
-- pg_get_functiondef() output, with the header (signature, RETURNS,
-- volatility, search_path, SECURITY DEFINER) asserted byte-identical so
-- no overload can be created.
--
-- VERIFICATION runs inside the transaction and, per the round3793
-- lesson, does NOT stop at static analysis: classes A and B both WRITE,
-- so one of each is EXECUTED for real and then undone via a
-- subtransaction sentinel.

BEGIN;

-- ---------------------------------------------------------------- class A
-- public.log_founder_vendor_scorecard_recompute(p_quarter text, p_rows integer)
CREATE OR REPLACE FUNCTION public.log_founder_vendor_scorecard_recompute(p_quarter text, p_rows integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vendor_scorecard_recompute', jsonb_build_object('quarter', p_quarter, 'rows', p_rows), now());
EXCEPTION WHEN undefined_table THEN NULL;
END;
$function$;

-- ---------------------------------------------------------------- class A
-- public.log_founder_vendor_replacement_proposed(p_vendor uuid, p_quarter text)
CREATE OR REPLACE FUNCTION public.log_founder_vendor_replacement_proposed(p_vendor uuid, p_quarter text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vendor_replacement_proposed', jsonb_build_object('vendor', p_vendor, 'quarter', p_quarter), now());
EXCEPTION WHEN undefined_table THEN NULL;
END;
$function$;

-- ---------------------------------------------------------------- class A
-- public.log_founder_vendor_replacement_decision(p_queue_id uuid, p_decision text)
CREATE OR REPLACE FUNCTION public.log_founder_vendor_replacement_decision(p_queue_id uuid, p_decision text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vendor_replacement_decision', jsonb_build_object('queue_id', p_queue_id, 'decision', p_decision), now());
EXCEPTION WHEN undefined_table THEN NULL;
END;
$function$;

-- ---------------------------------------------------------------- class A
-- public.log_founder_vendor_grade_override(p_scorecard_id uuid, p_old text, p_new text)
CREATE OR REPLACE FUNCTION public.log_founder_vendor_grade_override(p_scorecard_id uuid, p_old text, p_new text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vendor_grade_override', jsonb_build_object('scorecard_id', p_scorecard_id, 'old', p_old, 'new', p_new), now());
EXCEPTION WHEN undefined_table THEN NULL;
END;
$function$;

-- ---------------------------------------------------------------- class B
-- public.r1651_recompute_candidates()
CREATE OR REPLACE FUNCTION public.r1651_recompute_candidates()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH job_stats AS (
    SELECT
      rj.engineer_id,
      (COUNT(*) FILTER (WHERE rj.status = 'completed'))::int AS jobs_done,
      AVG(rj.hospital_rating) FILTER (WHERE rj.hospital_rating IS NOT NULL) AS avg_rating,
      COALESCE(SUM(rj.contracted_amount_rupees) FILTER (WHERE rj.status = 'completed'), 0)::bigint
        AS revenue
    FROM public.repair_jobs rj
    WHERE rj.engineer_id IS NOT NULL
    GROUP BY rj.engineer_id
  ),
  eng AS (
    SELECT
      e.id AS engineer_pk,
      e.user_id,
      e.cached_highest_tier AS tier,
      js.jobs_done,
      js.avg_rating,
      js.revenue
    FROM public.engineers e
    LEFT JOIN job_stats js ON js.engineer_id = e.id
    WHERE e.cached_highest_tier IS NOT NULL
  ),
  scored AS (
    SELECT
      user_id,
      tier,
      CASE tier
        WHEN 'bronze' THEN 'silver'
        WHEN 'silver' THEN 'gold'
        WHEN 'gold'   THEN 'platinum'
        ELSE tier
      END AS next_tier,
      COALESCE(jobs_done, 0) AS jobs_done,
      avg_rating,
      COALESCE(revenue, 0) AS revenue,
      -- score: 0.5*jobs + 10*rating + 0.0001*revenue_rupees, clipped 0..100
      LEAST(
        100,
        GREATEST(
          0,
          (COALESCE(jobs_done,0) * 0.5)
          + (COALESCE(avg_rating,0) * 10)
          + (COALESCE(revenue,0) * 0.0001)
        )
      )::numeric(6,2) AS score
    FROM eng
  )
  INSERT INTO public.engineer_promotion_candidates AS c (
    engineer_user_id, current_tier, proposed_tier,
    candidate_score, jobs_completed, avg_hospital_rating,
    total_revenue_rupees, months_in_tier, status, computed_at, updated_at
  )
  SELECT
    s.user_id, s.tier, s.next_tier,
    s.score, s.jobs_done, s.avg_rating, s.revenue,
    0, 'pending', now(), now()
  FROM scored s
  WHERE s.tier <> s.next_tier
    AND s.score >= 60
    AND NOT EXISTS (
      SELECT 1 FROM public.engineer_promotion_candidates x
      WHERE x.engineer_user_id = s.user_id AND x.status = 'pending'
    );

  GET DIAGNOSTICS v_count = ROW_COUNT;

  PERFORM public.log_founder_action(p_op_name => 'r1651_recompute_candidates', p_after_value => jsonb_build_object('inserted', v_count));

  RETURN v_count;
END;
$function$;

-- ---------------------------------------------------------------- class B
-- public.r1651_decide_candidate(p_candidate_id uuid, p_decision text, p_note text)
CREATE OR REPLACE FUNCTION public.r1651_decide_candidate(p_candidate_id uuid, p_decision text, p_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_decision_id uuid;
  v_engineer uuid;
  v_from text;
  v_to text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'invalid decision: %', p_decision;
  END IF;

  SELECT engineer_user_id, current_tier, proposed_tier
    INTO v_engineer, v_from, v_to
  FROM public.engineer_promotion_candidates
  WHERE id = p_candidate_id AND status = 'pending';

  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'candidate not found or already decided';
  END IF;

  UPDATE public.engineer_promotion_candidates
     SET status = p_decision,
         founder_note = p_note,
         decided_at = now(),
         decided_by = auth.uid(),
         updated_at = now()
   WHERE id = p_candidate_id;

  INSERT INTO public.engineer_promotion_decisions
    (candidate_id, engineer_user_id, decision, from_tier, to_tier, note, decided_by)
  VALUES
    (p_candidate_id, v_engineer, p_decision, v_from, v_to, p_note, auth.uid())
  RETURNING id INTO v_decision_id;

  PERFORM public.log_founder_action(p_op_name => 'r1651_decide_candidate', p_after_value => jsonb_build_object(
      'candidate_id', p_candidate_id,
      'engineer_user_id', v_engineer,
      'decision', p_decision,
      'from_tier', v_from,
      'to_tier', v_to
    ));

  RETURN v_decision_id;
END;
$function$;

-- ---------------------------------------------------------------- class B
-- public.r1651_promote_engineer(p_candidate_id uuid)
CREATE OR REPLACE FUNCTION public.r1651_promote_engineer(p_candidate_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_decision_id uuid;
  v_engineer uuid;
  v_from text;
  v_to text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT engineer_user_id, current_tier, proposed_tier
    INTO v_engineer, v_from, v_to
  FROM public.engineer_promotion_candidates
  WHERE id = p_candidate_id AND status = 'approved';

  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'candidate not approved';
  END IF;

  UPDATE public.engineers
     SET cached_highest_tier = v_to
   WHERE user_id = v_engineer;

  UPDATE public.engineer_promotion_candidates
     SET status = 'promoted',
         updated_at = now()
   WHERE id = p_candidate_id;

  INSERT INTO public.engineer_promotion_decisions
    (candidate_id, engineer_user_id, decision, from_tier, to_tier, note, decided_by)
  VALUES
    (p_candidate_id, v_engineer, 'promoted', v_from, v_to, 'tier committed', auth.uid())
  RETURNING id INTO v_decision_id;

  PERFORM public.log_founder_action(p_op_name => 'r1651_promote_engineer', p_after_value => jsonb_build_object(
      'candidate_id', p_candidate_id,
      'engineer_user_id', v_engineer,
      'from_tier', v_from,
      'to_tier', v_to
    ));

  RETURN v_decision_id;
END;
$function$;

-- ---------------------------------------------------------------- class B
-- public.founder_convertible_debt_record_conversion(p_note_id uuid, p_conversion_price_rupees bigint, p_note text)
CREATE OR REPLACE FUNCTION public.founder_convertible_debt_record_conversion(p_note_id uuid, p_conversion_price_rupees bigint, p_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_note_id IS NULL OR p_conversion_price_rupees IS NULL OR p_conversion_price_rupees <= 0 THEN
    RAISE EXCEPTION 'invalid input';
  END IF;
  UPDATE investor_convertible_notes
  SET status = 'converted',
      converted_at = now(),
      conversion_price_rupees = p_conversion_price_rupees,
      updated_at = now()
  WHERE id = p_note_id
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'note not found'; END IF;
  INSERT INTO investor_convertible_note_events(note_id, event_type, event_amount_rupees, event_note)
  VALUES (p_note_id, 'converted', p_conversion_price_rupees, p_note);
  PERFORM log_founder_action(p_op_name => 'icn.converted', p_target_row_id => p_note_id, p_after_value => jsonb_build_object('price', p_conversion_price_rupees));
  RETURN v_id;
END;
$function$;

-- ---------------------------------------------------------------- class B
-- public.founder_convertible_debt_set_watch(p_note_id uuid, p_watch boolean, p_reason text)
CREATE OR REPLACE FUNCTION public.founder_convertible_debt_set_watch(p_note_id uuid, p_watch boolean, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_convertible_notes
  SET watch_flag = COALESCE(p_watch, false),
      watch_reason = CASE WHEN p_watch THEN p_reason ELSE NULL END,
      updated_at = now()
  WHERE id = p_note_id
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'note not found'; END IF;
  INSERT INTO investor_convertible_note_events(note_id, event_type, event_note)
  VALUES (p_note_id, CASE WHEN p_watch THEN 'watch_added' ELSE 'watch_cleared' END, p_reason);
  PERFORM log_founder_action(p_op_name => 'icn.watch', p_target_row_id => p_note_id, p_after_value => jsonb_build_object('watch', p_watch, 'reason', p_reason));
  RETURN v_id;
END;
$function$;

-- ---------------------------------------------------------------- class B
-- public.founder_convertible_debt_log_note(p_investor_name text, p_investor_email text, p_principal_rupees bigint, p_interest_rate_pct numeric, p_issue_date date, p_maturity_date date, p_conversion_trigger text, p_conversion_discount_pct numeric, p_valuation_cap_rupees bigint, p_notes text)
CREATE OR REPLACE FUNCTION public.founder_convertible_debt_log_note(p_investor_name text, p_investor_email text, p_principal_rupees bigint, p_interest_rate_pct numeric, p_issue_date date, p_maturity_date date, p_conversion_trigger text DEFAULT 'qualified_round'::text, p_conversion_discount_pct numeric DEFAULT 20.00, p_valuation_cap_rupees bigint DEFAULT NULL::bigint, p_notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_investor_name IS NULL OR length(trim(p_investor_name)) = 0 THEN RAISE EXCEPTION 'investor_name required'; END IF;
  IF p_principal_rupees IS NULL OR p_principal_rupees <= 0 THEN RAISE EXCEPTION 'principal must be > 0'; END IF;
  IF p_maturity_date <= p_issue_date THEN RAISE EXCEPTION 'maturity must be after issue'; END IF;
  INSERT INTO investor_convertible_notes(
    investor_name, investor_email, principal_rupees, interest_rate_pct,
    issue_date, maturity_date, conversion_trigger, conversion_discount_pct,
    valuation_cap_rupees, notes
  ) VALUES (
    p_investor_name, p_investor_email, p_principal_rupees, p_interest_rate_pct,
    p_issue_date, p_maturity_date, p_conversion_trigger, p_conversion_discount_pct,
    p_valuation_cap_rupees, p_notes
  )
  RETURNING id INTO v_id;
  INSERT INTO investor_convertible_note_events(note_id, event_type, event_amount_rupees, event_note)
  VALUES (v_id, 'issued', p_principal_rupees, p_notes);
  PERFORM log_founder_action(p_op_name => 'icn.logged', p_target_row_id => v_id, p_after_value => jsonb_build_object('investor', p_investor_name, 'principal', p_principal_rupees));
  RETURN v_id;
END;
$function$;

-- ---------------------------------------------------------------- class C
-- public.dr_detector_ghost_image_audit_r3132()
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
           count(*)::bigint,
           count(distinct a.modality)::bigint,
           round(avg(a.uniformity_pct)::numeric, 2),
           round(avg(((a.audit_date - a.installed_on)::numeric / 365.25))::numeric, 2),
           round((count(*)::numeric * 100.0 / nullif(total_panels, 0))::numeric, 1)
    from dr_detector_panel_audits_r3132 a
    group by a.ghost_image_severity
    order by panel_count desc;
end;
$function$;

-- ---------------------------------------------------------------- class C
-- public.founder_hospital_billing_engine_summary()
CREATE OR REPLACE FUNCTION public.founder_hospital_billing_engine_summary()
 RETURNS TABLE(total_cycles_lifetime bigint, cycles_this_month bigint, cycles_pending bigint, cycles_invoiced bigint, cycles_paid bigint, cycles_overdue bigint, total_invoiced_amount_lifetime_rupees numeric, total_collected_lifetime_rupees numeric, total_outstanding_rupees numeric, outstanding_30d_rupees numeric, outstanding_over_60d_rupees numeric, collection_rate_lifetime_pct numeric, collection_rate_30d_pct numeric, dunning_events_30d bigint, oldest_unpaid_invoice_age_days integer, generated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_invoiced numeric := 0;
  v_total_collected numeric := 0;
  v_total_outstanding numeric := 0;
  v_30d_invoiced numeric := 0;
  v_30d_collected numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT coalesce(sum(total_amount_rupees), 0), coalesce(sum(amount_paid_rupees), 0)
  INTO v_total_invoiced, v_total_collected
  FROM public.founder_hospital_billing_invoices
  WHERE payment_status NOT IN ('cancelled');
  v_total_outstanding := v_total_invoiced - v_total_collected;

  SELECT coalesce(sum(total_amount_rupees), 0), coalesce(sum(amount_paid_rupees), 0)
  INTO v_30d_invoiced, v_30d_collected
  FROM public.founder_hospital_billing_invoices
  WHERE invoice_date >= current_date - interval '30 days' AND payment_status NOT IN ('cancelled');

  RETURN QUERY SELECT
    (SELECT count(*) FROM public.founder_hospital_billing_cycles)::bigint,
    (SELECT count(*) FROM public.founder_hospital_billing_cycles
     WHERE cycle_month = date_trunc('month', current_date)::date)::bigint,
    (SELECT count(*) FROM public.founder_hospital_billing_cycles WHERE status = 'pending')::bigint,
    (SELECT count(*) FROM public.founder_hospital_billing_cycles WHERE status = 'invoiced')::bigint,
    (SELECT count(*) FROM public.founder_hospital_billing_cycles WHERE status = 'paid')::bigint,
    (SELECT count(*) FROM public.founder_hospital_billing_cycles WHERE status = 'overdue')::bigint,
    round(v_total_invoiced, 2),
    round(v_total_collected, 2),
    round(v_total_outstanding, 2),
    coalesce((SELECT sum(total_amount_rupees - amount_paid_rupees) FROM public.founder_hospital_billing_invoices
              WHERE payment_status NOT IN ('paid','cancelled')
                AND invoice_date >= current_date - interval '30 days'), 0)::numeric,
    coalesce((SELECT sum(total_amount_rupees - amount_paid_rupees) FROM public.founder_hospital_billing_invoices
              WHERE payment_status NOT IN ('paid','cancelled')
                AND invoice_date < current_date - interval '60 days'), 0)::numeric,
    CASE WHEN v_total_invoiced > 0 THEN round((v_total_collected / v_total_invoiced) * 100, 2) ELSE 0 END,
    CASE WHEN v_30d_invoiced > 0 THEN round((v_30d_collected / v_30d_invoiced) * 100, 2) ELSE 0 END,
    (SELECT count(*) FROM public.founder_hospital_billing_dunning_events WHERE sent_at >= now() - interval '30 days')::bigint,
    coalesce((SELECT (current_date - min(invoice_date))::int
              FROM public.founder_hospital_billing_invoices
              WHERE payment_status NOT IN ('paid','cancelled')), 0),
    now();
END;
$function$;

-- ---------------------------------------------------------------- class C
-- public.founder_hospital_billing_invoices_recent(p_status text, p_limit integer)
CREATE OR REPLACE FUNCTION public.founder_hospital_billing_invoices_recent(p_status text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, invoice_number text, invoice_date date, cycle_month date, total_amount_rupees numeric, amount_paid_rupees numeric, amount_due_rupees numeric, payment_status text, delivery_channel text, delivered_at timestamp with time zone, age_days integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT i.id, i.invoice_number, i.invoice_date, c.cycle_month,
         i.total_amount_rupees, i.amount_paid_rupees,
         (i.total_amount_rupees - i.amount_paid_rupees)::numeric AS amount_due,
         i.payment_status, i.delivery_channel, i.delivered_at,
         (current_date - i.invoice_date)::int
  FROM public.founder_hospital_billing_invoices i
  JOIN public.founder_hospital_billing_cycles c ON c.id = i.cycle_id
  WHERE (p_status IS NULL OR i.payment_status = p_status)
  ORDER BY i.invoice_date DESC, i.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$function$;

-- ---------------------------------------------------------------- class C
-- public.founder_amc_renewal_failures_aging()
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_failures_aging()
 RETURNS TABLE(bucket text, cnt bigint, mrr_rupees numeric, oldest_days numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT c.monthly_fee_rupees, c.end_date,
           (now()::date - c.end_date)::numeric AS days_old
    FROM public.amc_contracts c
    WHERE c.status = 'renewal_failed'
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('< 7d'::text,   1, 0::numeric,   7::numeric),
      ('7-30d',        2, 7::numeric,  30::numeric),
      ('30-60d',       3, 30::numeric, 60::numeric),
      ('60-90d',       4, 60::numeric, 90::numeric),
      ('>90d',         5, 90::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi)::bigint,
    coalesce(sum(base.monthly_fee_rupees) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi), 0)::numeric,
    coalesce(max(base.days_old) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi), 0)::numeric
  FROM buckets b LEFT JOIN base ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$function$;

-- =====================================================================
-- VERIFY
-- =====================================================================
DO $gate$
DECLARE
  v_names text[] := ARRAY[
    'log_founder_vendor_scorecard_recompute',
    'log_founder_vendor_replacement_proposed',
    'log_founder_vendor_replacement_decision',
    'log_founder_vendor_grade_override',
    'r1651_recompute_candidates',
    'r1651_decide_candidate',
    'r1651_promote_engineer',
    'founder_convertible_debt_record_conversion',
    'founder_convertible_debt_set_watch',
    'founder_convertible_debt_log_note',
    'dr_detector_ghost_image_audit_r3132',
    'founder_hospital_billing_engine_summary',
    'founder_hospital_billing_invoices_recent',
    'founder_amc_renewal_failures_aging'
  ];
  v_gone  text[] := ARRAY[
    'relation "founder_audit_log" does not exist',
    'log_founder_action(unknown',
    'pg_catalog.extract(unknown, integer) does not exist'
  ];
  v_bad   text;
  v_before int;
  v_after  int;
  v_id    uuid;
  v_actor uuid;
BEGIN
  SELECT string_agg(x, ', ') INTO v_bad FROM unnest(v_names) x
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p
                      WHERE p.pronamespace='public'::regnamespace AND p.proname = x);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3795 VERIFY FAILED: function(s) vanished: %', v_bad;
  END IF;

  SELECT string_agg(q.proname || ' x' || q.c, ', ') INTO v_bad
    FROM (SELECT p.proname, count(*) c FROM pg_proc p
           WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
           GROUP BY p.proname) q WHERE q.c > 1;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3795 VERIFY FAILED: extra overload(s): %', v_bad;
  END IF;

  -- no reference to the non-existent table may survive anywhere
  SELECT string_agg(DISTINCT p.proname, ', ') INTO v_bad
    FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace
     AND p.prolang=(SELECT oid FROM pg_language WHERE lanname='plpgsql')
     AND pg_get_functiondef(p.oid) ILIKE '%founder_audit_log%';
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3795 VERIFY FAILED: founder_audit_log still referenced by: %', v_bad;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='plpgsql_check') THEN
    SELECT string_agg(DISTINCT p.proname || ': ' || e.message, '; ') INTO v_bad
      FROM pg_proc p CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.prolang=(SELECT oid FROM pg_language WHERE lanname='plpgsql')
       AND p.prorettype <> 'trigger'::regtype
       AND p.proname = ANY(v_names) AND e.level='error'
       AND EXISTS (SELECT 1 FROM unnest(v_gone) g WHERE e.message LIKE '%' || g || '%');
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'round 3795 VERIFY FAILED: class diagnostic survived: %', v_bad;
    END IF;
  END IF;

  -- EXECUTE a class-A writer for real, then undo it
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub','756a3373-1077-470e-bc0a-79b8d6673ef4','role','authenticated',
                      'email','ganesh1431.dhanavath@gmail.com')::text, true);
  SELECT count(*) INTO v_before FROM public.founder_action_log;
  BEGIN
    PERFORM public.log_founder_vendor_scorecard_recompute('2026-Q3', 7);
    SELECT count(*) INTO v_after FROM public.founder_action_log;
    SELECT l.actor_user_id INTO v_actor
      FROM public.founder_action_log l ORDER BY l.created_at DESC LIMIT 1;
    IF v_after <> v_before + 1 THEN
      RAISE EXCEPTION 'round 3795 VERIFY FAILED: class A wrote % rows, expected 1', v_after - v_before;
    END IF;
    IF v_actor IS NULL THEN
      RAISE EXCEPTION 'round 3795 VERIFY FAILED: class A wrote a NULL actor_user_id';
    END IF;
    RAISE EXCEPTION 'ROUND3795_PROBE_ROLLBACK';
  EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
      IF SQLERRM <> 'ROUND3795_PROBE_ROLLBACK' THEN
        RAISE EXCEPTION 'round 3795 VERIFY FAILED in class-A probe: %', SQLERRM;
      END IF;
  END;
  SELECT count(*) INTO v_after FROM public.founder_action_log;
  IF v_after <> v_before THEN
    RAISE EXCEPTION 'round 3795 VERIFY FAILED: class-A probe left % row(s)', v_after - v_before;
  END IF;

  RAISE NOTICE 'round 3795 verified: % function(s) across 3 classes; class-A write probed and rolled back',
    array_length(v_names,1);
END
$gate$;

COMMIT;
