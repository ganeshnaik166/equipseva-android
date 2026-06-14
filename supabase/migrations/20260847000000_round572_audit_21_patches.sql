-- Round 572 — Audit-21 patches (2 MEDIUM confirmed, 3 rejected)
--
-- Audit-21 ran a lean adversarial pass on r571 spare_part_demand_signals.
-- Two real issues confirmed; both MEDIUM (audit-trail integrity, no
-- money/auth bypass).
--
-- MEDIUM #1 — manual_founder source spoofing
--   record_spare_part_demand_signal accepted p_source='manual_founder'
--   from any authenticated caller. Downstream UI/reports filter by
--   source='manual_founder' to see founder-curated demand; attackers
--   could pollute that channel by claiming the founder origin
--   themselves.
--   FIX: gate p_source='manual_founder' on is_founder().
--
-- MEDIUM #2 — bulk priority blast radius for query-only signals
--   founder_set_demand_signal_priority bulk-updates every row sharing
--   (brand, model, part_number) keys after lowering. But query-only
--   signals (where all three are NULL) collapse to a single '?|?|?'
--   group key. A founder click on that apparent group flips priority
--   on EVERY unresolved query-only row in the table, including rows
--   from other reporters that the founder did not intend to touch.
--   FIX: when seed row has brand+model+part all NULL, restrict the
--   UPDATE to the seed row id only — refuse to fan out by NULL group.
--
-- Rejected (documented for record):
-- - "cross-tenant data poisoning via hospital_org_id/job_id" —
--   dashboard never returns those columns; no read surface; false
--   positive.
-- - "no rate limit → DoS" — authenticated-only, reporter_user_id
--   logged, founder-only dashboard with LIMIT 25 — hygiene gap not
--   security. Defer to r575+.
-- - "no length cap → storage exhaustion" — PostgREST upstream
--   bounds + auth required + attributable. Defer.

BEGIN;

-- ----------------------------------------------------------------
-- Patch #1: gate manual_founder source on is_founder()
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.record_spare_part_demand_signal(text,text,text,text,text,text,uuid,uuid);
CREATE OR REPLACE FUNCTION public.record_spare_part_demand_signal(
  p_part_number      text,
  p_brand            text,
  p_model            text,
  p_query            text,
  p_source           text,
  p_urgency          text DEFAULT 'standard',
  p_job_id           uuid DEFAULT NULL,
  p_hospital_org_id  uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_role  text;
  v_id    uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required'
      USING ERRCODE = '42501';
  END IF;

  IF p_source NOT IN ('search_no_results','rfq_no_supplier','low_stock_match','manual_founder','engineer_report') THEN
    RAISE EXCEPTION 'unknown source: %', p_source
      USING ERRCODE = '22023';
  END IF;

  -- r572 audit-21 MEDIUM #1: manual_founder is a founder-only channel.
  -- Without this gate, any authenticated caller could pollute the
  -- founder-curated audit trail.
  IF p_source = 'manual_founder' AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'source=manual_founder restricted to founder callers'
      USING ERRCODE = '42501';
  END IF;

  IF p_urgency NOT IN ('standard','urgent','critical') THEN
    RAISE EXCEPTION 'unknown urgency: %', p_urgency
      USING ERRCODE = '22023';
  END IF;

  -- Subject sanity — must have something to group on.
  IF coalesce(nullif(trim(p_part_number),''), nullif(trim(p_model),''), nullif(trim(p_brand),''), nullif(trim(p_query),'')) IS NULL THEN
    RAISE EXCEPTION 'demand signal must include part_number, brand/model, or a non-empty query'
      USING ERRCODE = '22023';
  END IF;

  BEGIN
    SELECT lower(coalesce(p.role::text,'system')) INTO v_role
      FROM public.profiles p
     WHERE p.id = v_uid
     LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v_role := 'system';
  END;
  IF v_role NOT IN ('engineer','hospital','founder','system') THEN
    v_role := 'system';
  END IF;

  INSERT INTO public.spare_part_demand_signals (
    reporter_user_id, reporter_role,
    equipment_brand, equipment_model, part_number, part_description, search_query_norm,
    source, hospital_org_id, job_id, urgency
  ) VALUES (
    v_uid, v_role,
    nullif(trim(p_brand),''), nullif(trim(p_model),''), nullif(trim(p_part_number),''),
    NULL, nullif(trim(p_query),''),
    p_source, p_hospital_org_id, p_job_id, p_urgency
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_spare_part_demand_signal(text,text,text,text,text,text,uuid,uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.record_spare_part_demand_signal(text,text,text,text,text,text,uuid,uuid) TO authenticated;

-- ----------------------------------------------------------------
-- Patch #2: refuse NULL-group bulk priority blast
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_set_demand_signal_priority(uuid,text);
CREATE OR REPLACE FUNCTION public.founder_set_demand_signal_priority(
  p_any_signal_id uuid,
  p_priority      text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_email  text;
  v_brand  text;
  v_model  text;
  v_part   text;
  v_count  bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF p_priority NOT IN ('low','med','high') AND p_priority IS NOT NULL THEN
    RAISE EXCEPTION 'unknown priority: %', p_priority USING ERRCODE = '22023';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  SELECT lower(equipment_brand), lower(equipment_model), lower(part_number)
    INTO v_brand, v_model, v_part
    FROM public.spare_part_demand_signals
   WHERE id = p_any_signal_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demand signal not found: %', p_any_signal_id USING ERRCODE = 'P0002';
  END IF;

  -- r572 audit-21 MEDIUM #2: NULL group blast radius. If seed row has
  -- brand+model+part_number all NULL (a query-only signal), the
  -- coalesce(...,'?') trick collapses every other query-only row in
  -- the table into the same group. Founder click would bulk-priority
  -- unrelated rows. Restrict to the seed row id only in that case.
  IF v_brand IS NULL AND v_model IS NULL AND v_part IS NULL THEN
    UPDATE public.spare_part_demand_signals
       SET founder_priority = p_priority
     WHERE id = p_any_signal_id
       AND resolved_at IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSE
    UPDATE public.spare_part_demand_signals
       SET founder_priority = p_priority
     WHERE resolved_at IS NULL
       AND coalesce(lower(equipment_brand),'?') = coalesce(v_brand,'?')
       AND coalesce(lower(equipment_model),'?') = coalesce(v_model,'?')
       AND coalesce(lower(part_number),'?')     = coalesce(v_part,'?');
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;

  INSERT INTO public.founder_action_log (
    actor_user_id, actor_email, op_name, target_table, target_row_id,
    after_value, reason, outcome
  ) VALUES (
    v_uid, coalesce(v_email,'?'), 'set_demand_signal_priority',
    'spare_part_demand_signals', p_any_signal_id,
    jsonb_build_object(
      'priority', p_priority,
      'affected_rows', v_count,
      'group_brand', v_brand,
      'group_model', v_model,
      'group_part', v_part,
      'null_group_restricted', (v_brand IS NULL AND v_model IS NULL AND v_part IS NULL)
    ),
    p_priority,
    'success'
  );

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_set_demand_signal_priority(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_set_demand_signal_priority(uuid,text) TO authenticated;

COMMIT;
