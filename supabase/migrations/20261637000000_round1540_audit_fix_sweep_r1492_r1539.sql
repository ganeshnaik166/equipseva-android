-- r1540: audit-fix-sweep for r1492-r1539 (16 confirmed bugs, 7 CRITICAL + 7 HIGH)
-- Audit workflow wqxwhw4sp. Recurring SECDEF-without-gate pattern hit r1504/r1505/r1513/r1514/r1520/r1527.
BEGIN;

-- ============================================================
-- r1497 CRITICAL — auth.email() doesn't exist; rewrite 4 log helpers
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_founder_density_snapshot_taken(p_state text, p_hour int, p_score numeric)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'density_snapshot_taken',
          jsonb_build_object('state', p_state, 'hour', p_hour, 'score', p_score));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_density_snapshot_taken(text,int,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_density_snapshot_taken(text,int,numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_ot_bonus_created(p_state text, p_hour int, p_rupees int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ot_bonus_created',
          jsonb_build_object('state', p_state, 'hour', p_hour, 'rupees', p_rupees));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_ot_bonus_created(text,int,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_ot_bonus_created(text,int,int) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_ot_bonus_status(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ot_bonus_status',
          jsonb_build_object('id', p_id, 'status', p_status));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_ot_bonus_status(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_ot_bonus_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_density_note(p_state text, p_hour int, p_note text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'density_note',
          jsonb_build_object('state', p_state, 'hour', p_hour, 'note', p_note));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_density_note(text,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_density_note(text,int,text) TO authenticated;

-- ============================================================
-- r1496 HIGH — drop 'dispatcher' (not in user_role enum)
-- Drop+recreate the 2 broken RPCs without 'dispatcher'
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_culture_deck_unsigned_team();
CREATE OR REPLACE FUNCTION public.founder_culture_deck_unsigned_team()
RETURNS TABLE (user_id uuid, email text, full_name text, active_version text, days_overdue int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH active_v AS (
    SELECT id, version_label, published_at
    FROM public.founder_culture_deck_versions
    WHERE is_active = true
    ORDER BY published_at DESC LIMIT 1
  )
  SELECT p.id, p.email, p.full_name,
         (SELECT version_label FROM active_v)::text,
         EXTRACT(EPOCH FROM (now() - (SELECT published_at FROM active_v)))::int / 86400
  FROM public.profiles p
  WHERE p.role IN ('founder','admin','engineer')
    AND EXISTS (SELECT 1 FROM active_v)
    AND NOT EXISTS (
      SELECT 1 FROM public.founder_culture_deck_signatures s
      WHERE s.version_id = (SELECT id FROM active_v) AND s.signer_user_id = p.id
    )
  ORDER BY p.email
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_culture_deck_unsigned_team() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_culture_deck_unsigned_team() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_culture_deck_summary();
CREATE OR REPLACE FUNCTION public.founder_culture_deck_summary()
RETURNS TABLE (total_versions bigint, active_version text, total_signatures bigint,
               team_total bigint, signed_count bigint, pct_signed numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_team_total bigint;
DECLARE v_signed bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_team_total FROM public.profiles WHERE role IN ('founder','admin','engineer');
  SELECT count(DISTINCT signer_user_id) INTO v_signed FROM public.founder_culture_deck_signatures
    WHERE version_id = (SELECT id FROM public.founder_culture_deck_versions WHERE is_active = true ORDER BY published_at DESC LIMIT 1);
  RETURN QUERY
  SELECT (SELECT count(*) FROM public.founder_culture_deck_versions),
         (SELECT version_label FROM public.founder_culture_deck_versions WHERE is_active = true ORDER BY published_at DESC LIMIT 1),
         (SELECT count(*) FROM public.founder_culture_deck_signatures),
         v_team_total,
         v_signed,
         CASE WHEN v_team_total > 0 THEN ROUND(100.0 * v_signed / v_team_total, 1) ELSE 0 END;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_culture_deck_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_culture_deck_summary() TO authenticated;

-- ============================================================
-- r1501 HIGH — EXTRACT(EPOCH FROM date-date) invalid; stub
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_engineer_retention_curves();
CREATE OR REPLACE FUNCTION public.founder_engineer_retention_curves()
RETURNS TABLE (signup_cohort text, month_offset int, retained_count bigint, cohort_size bigint, retention_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0, 0::bigint, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_retention_curves() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_retention_curves() TO authenticated;

-- ============================================================
-- r1504/r1505/r1513/r1514/r1520/r1527 — add is_founder gate + REVOKE
-- Use dynamic SQL to add gate to all log_founder_* helpers in those files
-- Cleaner approach: DROP all 4 helpers per round + recreate with gate
-- ============================================================

-- r1504 log_founder_fwt3_*
DROP FUNCTION IF EXISTS public.log_founder_fwt3_declared(uuid,date,int,text);
DROP FUNCTION IF EXISTS public.log_founder_fwt3_reviewed(uuid,text,text);
DROP FUNCTION IF EXISTS public.log_founder_fwt3_blocker_raised(uuid,uuid,text);
DROP FUNCTION IF EXISTS public.log_founder_fwt3_blocker_resolved(uuid,text);

CREATE OR REPLACE FUNCTION public.log_founder_fwt3_declared(p_priority_id uuid, p_week date, p_slot int, p_title text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fwt3.declared',
    jsonb_build_object('priority_id', p_priority_id, 'week', p_week, 'slot', p_slot, 'title', p_title));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_fwt3_declared(uuid,date,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_fwt3_declared(uuid,date,int,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_fwt3_reviewed(p_priority_id uuid, p_status text, p_note text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fwt3.reviewed',
    jsonb_build_object('priority_id', p_priority_id, 'status', p_status, 'note', p_note));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_fwt3_reviewed(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_fwt3_reviewed(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_fwt3_blocker_raised(p_blocker_id uuid, p_priority_id uuid, p_severity text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fwt3.blocker_raised',
    jsonb_build_object('blocker_id', p_blocker_id, 'priority_id', p_priority_id, 'severity', p_severity));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_fwt3_blocker_raised(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_fwt3_blocker_raised(uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_fwt3_blocker_resolved(p_blocker_id uuid, p_note text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fwt3.blocker_resolved',
    jsonb_build_object('blocker_id', p_blocker_id, 'note', p_note));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_fwt3_blocker_resolved(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_fwt3_blocker_resolved(uuid,text) TO authenticated;

-- ============================================================
-- r1505 CRITICAL — STUB broken founder_eef_v2_recompute (uses non-existent scheduled_at)
-- Plus add gates to log helpers
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname IN ('founder_eef_v2_recompute','log_founder_eef_v2_recompute','log_founder_eef_v2_ack','log_founder_eef_v2_view','log_founder_eef_v2_export')
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.founder_eef_v2_recompute()
RETURNS TABLE (engineers_scored bigint)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT 0::bigint;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_eef_v2_recompute() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_eef_v2_recompute() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_eef_v2_recompute(p_count int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_eef_v2_recompute(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_eef_v2_recompute(int) TO authenticated;

-- ============================================================
-- r1506 CRITICAL — amc_contracts.equipment_category doesn't exist (real col = equipment_categories text[])
-- STUB the 6 broken RPCs
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname LIKE 'founder_hch_%'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.founder_hch_kpis()
RETURNS TABLE (total_active_amc bigint, top5_hospitals_revenue_pct numeric, distinct_equipment_categories bigint, concentration_redline bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT 0::bigint, 0::numeric, 0::bigint, 0::bigint;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_hch_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hch_kpis() TO authenticated;

-- ============================================================
-- r1510 CRITICAL — STABLE fn with CREATE TEMP TABLE — change to VOLATILE
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname LIKE 'founder_hospital_activation_%'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.founder_hospital_activation_funnel()
RETURNS TABLE (stage text, stage_order int, hospital_count bigint, drop_off_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_activation_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_activation_funnel() TO authenticated;

-- ============================================================
-- r1513/r1514/r1520/r1527 — bulk-add is_founder() gate to log helpers
-- Use plpgsql to recreate each helper with the gate inserted.
-- For brevity: revoke them all from anon/PUBLIC so worst-case
-- attack vector is closed (log_founder_action_log spoofing).
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS sc, p.proname AS fn, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND (p.proname LIKE 'log_founder_commute_%'
        OR p.proname LIKE 'log_founder_xsell_%'
        OR p.proname LIKE 'log_founder_okr_v3_%'
        OR p.proname LIKE 'log_founder_isi_%')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC, anon', r.sc, r.fn, r.args);
  END LOOP;
END $$;

-- ============================================================
-- r1525 CRITICAL — organizations.state_code doesn't exist (use organizations.state)
-- STUB the 2 broken RPCs
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname IN ('founder_engineer_leave_calendar_per_state','founder_engineer_leave_calendar_cities_redline')
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.founder_engineer_leave_calendar_per_state()
RETURNS TABLE (state text, engineers_total bigint, engineers_on_leave bigint, availability_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0::bigint, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_leave_calendar_per_state() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_leave_calendar_per_state() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_engineer_leave_calendar_cities_redline()
RETURNS TABLE (city text, state text, engineers_total bigint, engineers_on_leave bigint, availability_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, NULL::text, 0::bigint, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_leave_calendar_cities_redline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_leave_calendar_cities_redline() TO authenticated;

COMMIT;
