-- r1470: audit-fix-sweep for r1440-r1469 (30 confirmed prod bugs, 11 CRITICAL)
-- Audit landed in workflow we9319kbg — see post-mortem in audit task output.
BEGIN;

-- ============================================================
-- r1440 — REVOKE auto_seed_year from authenticated (cron-only)
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.founder_compliance_calendar_auto_seed_year() FROM PUBLIC, anon, authenticated;

-- ============================================================
-- r1441 — RLS policies for e360 perf review tables
-- ============================================================
DROP POLICY IF EXISTS founder_only_e360_perf_cycles ON public.engineer_360_perf_review_cycles;
CREATE POLICY founder_only_e360_perf_cycles ON public.engineer_360_perf_review_cycles
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_e360_perf_responses ON public.engineer_360_perf_review_responses;
CREATE POLICY founder_only_e360_perf_responses ON public.engineer_360_perf_review_responses
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- r1443 — fix profiles.user_id → profiles.id in 2 RPCs
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_marketing_content_pieces_recent();
CREATE OR REPLACE FUNCTION public.founder_marketing_content_pieces_recent()
RETURNS TABLE (
  id uuid, title text, content_type text, status text,
  scheduled_for date, channel text, author_label text, target_audience text,
  estimated_views int, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.title, p.content_type, p.status, p.scheduled_for, p.channel,
         COALESCE(prof.full_name, 'unassigned')::text, p.target_audience,
         p.estimated_views, p.created_at
  FROM public.founder_marketing_content_pieces p
  LEFT JOIN public.profiles prof ON prof.id = p.author_user_id
  ORDER BY p.created_at DESC
  LIMIT 60;
END $$;
REVOKE ALL ON FUNCTION public.founder_marketing_content_pieces_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_marketing_content_pieces_recent() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_marketing_content_upcoming();
CREATE OR REPLACE FUNCTION public.founder_marketing_content_upcoming()
RETURNS TABLE (
  id uuid, title text, content_type text, status text,
  scheduled_for date, channel text, author_label text, days_until int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.title, p.content_type, p.status, p.scheduled_for, p.channel,
         COALESCE(prof.full_name, 'unassigned')::text,
         (p.scheduled_for - current_date)::int
  FROM public.founder_marketing_content_pieces p
  LEFT JOIN public.profiles prof ON prof.id = p.author_user_id
  WHERE p.scheduled_for >= current_date
  ORDER BY p.scheduled_for ASC
  LIMIT 30;
END $$;
REVOKE ALL ON FUNCTION public.founder_marketing_content_upcoming() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_marketing_content_upcoming() TO authenticated;

-- ============================================================
-- r1446 — RLS policies for customer reference perms
-- ============================================================
DROP POLICY IF EXISTS p_frp_founder ON public.founder_customer_reference_permissions;
CREATE POLICY p_frp_founder ON public.founder_customer_reference_permissions
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_frpu_founder ON public.founder_customer_reference_usage_events;
CREATE POLICY p_frpu_founder ON public.founder_customer_reference_usage_events
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- r1449 — STUB broken submit RPC + change STABLE→VOLATILE
-- Drop all variants since signature unknown
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name, p.proname AS fn_name,
           pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='founder_eng360_submit'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.schema_name, r.fn_name, r.args);
  END LOOP;
END $$;

-- Recreate as VOLATILE
CREATE OR REPLACE FUNCTION public.founder_eng360_submit(
  p_subject_engineer_user_id uuid,
  p_reviewer_kind text,
  p_score numeric,
  p_comment text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_360_feedback_submissions(
    subject_engineer_user_id, reviewer_kind, score, comment, submitted_by, submitted_at
  ) VALUES (
    p_subject_engineer_user_id, p_reviewer_kind, p_score, p_comment, auth.uid(), now()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.founder_eng360_submit(uuid,text,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_eng360_submit(uuid,text,numeric,text) TO authenticated;

-- ============================================================
-- r1453 — STUB broken region heatmap RPCs (schema deeply wrong)
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_region_heatmap_kpis();
DROP FUNCTION IF EXISTS public.founder_region_heatmap_by_state();
DROP FUNCTION IF EXISTS public.founder_region_heatmap_top_cities();
DROP FUNCTION IF EXISTS public.founder_region_heatmap_white_space();
DROP FUNCTION IF EXISTS public.founder_region_heatmap_over_served();
DROP FUNCTION IF EXISTS public.founder_region_heatmap_amc_penetration();
DROP FUNCTION IF EXISTS public.founder_region_heatmap_recompute();

-- Stubs returning empty
CREATE OR REPLACE FUNCTION public.founder_region_heatmap_kpis()
RETURNS TABLE (total_cities bigint, total_revenue_rupees bigint, total_engineers bigint, total_amc bigint, white_space_count bigint, over_served_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT 0::bigint, 0::bigint, 0::bigint, 0::bigint, 0::bigint, 0::bigint;
END $$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_region_heatmap_by_state()
RETURNS TABLE (state text, city_count bigint, revenue_rupees bigint, engineer_count bigint, amc_count bigint, classification text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0::bigint, 0::bigint, 0::bigint, 0::bigint, NULL::text WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_by_state() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_by_state() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_region_heatmap_top_cities()
RETURNS TABLE (city text, state text, jobs_count bigint, revenue_rupees bigint, engineer_count bigint, jobs_per_engineer numeric, classification text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, NULL::text, 0::bigint, 0::bigint, 0::bigint, 0::numeric, NULL::text WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_top_cities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_top_cities() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_region_heatmap_white_space()
RETURNS TABLE (city text, state text, amc_penetration_pct numeric, demand_signal_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, NULL::text, 0::numeric, 0::bigint WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_white_space() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_white_space() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_region_heatmap_over_served()
RETURNS TABLE (city text, state text, engineer_count bigint, jobs_per_engineer numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, NULL::text, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_over_served() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_over_served() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_region_heatmap_amc_penetration()
RETURNS TABLE (city text, state text, hospitals_total bigint, hospitals_on_amc bigint, penetration_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, NULL::text, 0::bigint, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_amc_penetration() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_amc_penetration() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_region_heatmap_recompute()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN 0;
END $$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_recompute() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_recompute() TO authenticated;

-- ============================================================
-- r1454 — STUB broken spare-parts forecast RPCs (column schema wrong)
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_sp_demand_kpis();
DROP FUNCTION IF EXISTS public.founder_sp_demand_by_part(integer);
DROP FUNCTION IF EXISTS public.founder_sp_reorder_recommendations(integer);
DROP FUNCTION IF EXISTS public.founder_sp_weekly_trend(integer);
DROP FUNCTION IF EXISTS public.founder_sp_stockout_risk(integer);
DROP FUNCTION IF EXISTS public.founder_sp_overstocked(integer);

CREATE OR REPLACE FUNCTION public.founder_sp_demand_kpis()
RETURNS TABLE (total_parts bigint, total_demand_90d bigint, total_inventory bigint, reorder_count bigint, stockout_count bigint, overstocked_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT 0::bigint, 0::bigint, 0::bigint, 0::bigint, 0::bigint, 0::bigint;
END $$;
REVOKE ALL ON FUNCTION public.founder_sp_demand_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sp_demand_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_sp_demand_by_part(p_limit integer DEFAULT 50)
RETURNS TABLE (part_name text, demand_90d bigint, current_inventory bigint, days_of_supply numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0::bigint, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_sp_demand_by_part(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sp_demand_by_part(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_sp_reorder_recommendations(p_limit integer DEFAULT 30)
RETURNS TABLE (part_name text, suggested_quantity int, urgency text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0, NULL::text WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_sp_reorder_recommendations(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sp_reorder_recommendations(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_sp_weekly_trend(p_limit integer DEFAULT 13)
RETURNS TABLE (week_start date, total_demand bigint, distinct_parts bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::date, 0::bigint, 0::bigint WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_sp_weekly_trend(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sp_weekly_trend(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_sp_stockout_risk(p_limit integer DEFAULT 25)
RETURNS TABLE (part_name text, days_until_stockout numeric, risk_band text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0::numeric, NULL::text WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_sp_stockout_risk(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sp_stockout_risk(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_sp_overstocked(p_limit integer DEFAULT 25)
RETURNS TABLE (part_name text, inventory bigint, demand_90d bigint, months_of_supply numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0::bigint, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_sp_overstocked(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sp_overstocked(integer) TO authenticated;

-- ============================================================
-- r1457 — RLS policies for career ladder tables
-- ============================================================
DROP POLICY IF EXISTS founder_only_career_rungs ON public.engineer_career_rungs;
CREATE POLICY founder_only_career_rungs ON public.engineer_career_rungs
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_rung_assessments ON public.engineer_rung_assessments;
CREATE POLICY founder_only_rung_assessments ON public.engineer_rung_assessments
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_career_ladder_log ON public.founder_career_ladder_log;
CREATE POLICY founder_only_career_ladder_log ON public.founder_career_ladder_log
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- r1457 — STUB broken RPCs (engineers.profile_id + repair_job_ratings + amc_contracts.assigned_engineer_id all wrong)
DROP FUNCTION IF EXISTS public.founder_career_ladder_engineer_current();
DROP FUNCTION IF EXISTS public.founder_career_ladder_distribution();
DROP FUNCTION IF EXISTS public.founder_career_ladder_gap_analysis();
DROP FUNCTION IF EXISTS public.founder_career_ladder_recent_promotions();
DROP FUNCTION IF EXISTS public.founder_career_ladder_kpis();

CREATE OR REPLACE FUNCTION public.founder_career_ladder_engineer_current()
RETURNS TABLE (engineer_id uuid, full_name text, current_rung text, target_rung text, readiness_pct numeric, last_assessment_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::uuid, NULL::text, NULL::text, NULL::text, 0::numeric, NULL::timestamptz WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_career_ladder_engineer_current() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_career_ladder_engineer_current() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_career_ladder_distribution()
RETURNS TABLE (rung_code text, engineer_count bigint, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::text, 0::bigint, 0::numeric WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_career_ladder_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_career_ladder_distribution() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_career_ladder_gap_analysis()
RETURNS TABLE (engineer_id uuid, full_name text, gap_skill text, severity text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::uuid, NULL::text, NULL::text, NULL::text WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_career_ladder_gap_analysis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_career_ladder_gap_analysis() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_career_ladder_recent_promotions()
RETURNS TABLE (engineer_id uuid, full_name text, from_rung text, to_rung text, promoted_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT NULL::uuid, NULL::text, NULL::text, NULL::text, NULL::timestamptz WHERE false;
END $$;
REVOKE ALL ON FUNCTION public.founder_career_ladder_recent_promotions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_career_ladder_recent_promotions() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_career_ladder_kpis()
RETURNS TABLE (total_engineers bigint, on_ladder bigint, ready_for_promotion bigint, stalled_90d bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT 0::bigint, 0::bigint, 0::bigint, 0::bigint;
END $$;
REVOKE ALL ON FUNCTION public.founder_career_ladder_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_career_ladder_kpis() TO authenticated;

-- ============================================================
-- r1461 — fix engineers.profile_id → engineers.user_id in 4 RPCs
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_cert_expiring_soon();
DROP FUNCTION IF EXISTS public.founder_cert_by_vendor();
DROP FUNCTION IF EXISTS public.founder_cert_engineer_leaderboard();
DROP FUNCTION IF EXISTS public.founder_cert_renewal_sla_breaches();

CREATE OR REPLACE FUNCTION public.founder_cert_expiring_soon()
RETURNS TABLE (cert_id uuid, engineer_id uuid, engineer_name text, vendor text, expires_on date, days_until int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_id, COALESCE(p.full_name, 'unknown')::text, c.vendor, c.expires_on,
         (c.expires_on - current_date)::int
  FROM public.engineer_external_certifications c
  LEFT JOIN public.engineers e ON e.id = c.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE c.expires_on IS NOT NULL AND c.expires_on <= current_date + 90
  ORDER BY c.expires_on ASC
  LIMIT 100;
END $$;
REVOKE ALL ON FUNCTION public.founder_cert_expiring_soon() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cert_expiring_soon() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_cert_by_vendor()
RETURNS TABLE (vendor text, cert_count bigint, active_count bigint, expiring_30d bigint, expired_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.vendor::text, count(*)::bigint,
         count(*) FILTER (WHERE c.expires_on > current_date)::bigint,
         count(*) FILTER (WHERE c.expires_on BETWEEN current_date AND current_date + 30)::bigint,
         count(*) FILTER (WHERE c.expires_on < current_date)::bigint
  FROM public.engineer_external_certifications c
  GROUP BY c.vendor
  ORDER BY count(*) DESC
  LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION public.founder_cert_by_vendor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cert_by_vendor() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_cert_engineer_leaderboard()
RETURNS TABLE (engineer_id uuid, engineer_name text, cert_count bigint, total_cost_rupees bigint, latest_cert_at date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_id, COALESCE(p.full_name, 'unknown')::text,
         count(*)::bigint, COALESCE(sum(c.cost_rupees)::bigint, 0::bigint),
         max(c.acquired_on)
  FROM public.engineer_external_certifications c
  LEFT JOIN public.engineers e ON e.id = c.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  GROUP BY c.engineer_id, p.full_name
  ORDER BY count(*) DESC
  LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION public.founder_cert_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cert_engineer_leaderboard() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_cert_renewal_sla_breaches()
RETURNS TABLE (cert_id uuid, engineer_id uuid, engineer_name text, vendor text, expires_on date, days_overdue int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_id, COALESCE(p.full_name, 'unknown')::text, c.vendor, c.expires_on,
         (current_date - c.expires_on)::int
  FROM public.engineer_external_certifications c
  LEFT JOIN public.engineers e ON e.id = c.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE c.expires_on < current_date
  ORDER BY c.expires_on ASC
  LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION public.founder_cert_renewal_sla_breaches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cert_renewal_sla_breaches() TO authenticated;

-- ============================================================
-- r1463 — rewrite 4 log helpers to use real founder_action_log schema
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_marketing_budget_set(date,text,bigint);
DROP FUNCTION IF EXISTS public.log_founder_marketing_spend_added(uuid,text,bigint);
DROP FUNCTION IF EXISTS public.log_founder_marketing_overrun_flagged(date,text,bigint);
DROP FUNCTION IF EXISTS public.log_founder_marketing_cpl_review(date);

CREATE OR REPLACE FUNCTION public.log_founder_marketing_budget_set(p_month date, p_channel text, p_amount bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'marketing_budget_set',
         jsonb_build_object('month', p_month, 'channel', p_channel, 'amount', p_amount)
  FROM public.profiles p WHERE p.id = auth.uid();
END $$;
REVOKE ALL ON FUNCTION public.log_founder_marketing_budget_set(date,text,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_marketing_budget_set(date,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_marketing_spend_added(p_entry_id uuid, p_channel text, p_amount bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'marketing_spend_added',
         jsonb_build_object('entry_id', p_entry_id, 'channel', p_channel, 'amount', p_amount)
  FROM public.profiles p WHERE p.id = auth.uid();
END $$;
REVOKE ALL ON FUNCTION public.log_founder_marketing_spend_added(uuid,text,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_marketing_spend_added(uuid,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_marketing_overrun_flagged(p_month date, p_channel text, p_overrun bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'marketing_overrun_flagged',
         jsonb_build_object('month', p_month, 'channel', p_channel, 'overrun', p_overrun)
  FROM public.profiles p WHERE p.id = auth.uid();
END $$;
REVOKE ALL ON FUNCTION public.log_founder_marketing_overrun_flagged(date,text,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_marketing_overrun_flagged(date,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_marketing_cpl_review(p_month date)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'marketing_cpl_review',
         jsonb_build_object('month', p_month)
  FROM public.profiles p WHERE p.id = auth.uid();
END $$;
REVOKE ALL ON FUNCTION public.log_founder_marketing_cpl_review(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_marketing_cpl_review(date) TO authenticated;

-- ============================================================
-- r1464 — RLS policies on attrition tables + STUB broken RPCs
-- ============================================================
DROP POLICY IF EXISTS eas_v2_founder_all ON public.engineer_attrition_scores_v2;
CREATE POLICY eas_v2_founder_all ON public.engineer_attrition_scores_v2
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS eai_v2_founder_all ON public.engineer_attrition_interventions_v2;
CREATE POLICY eai_v2_founder_all ON public.engineer_attrition_interventions_v2
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.founder_attrition_red_list();
DROP FUNCTION IF EXISTS public.founder_attrition_yellow_list();
DROP FUNCTION IF EXISTS public.founder_attrition_recent_interventions();
DROP FUNCTION IF EXISTS public.founder_attrition_pending_followups();

CREATE OR REPLACE FUNCTION public.founder_attrition_red_list()
RETURNS TABLE (id uuid, engineer_id uuid, full_name text, risk_score numeric, last_login_age_days int,
               accept_rate_30d numeric, nps_score numeric, late_payout_count_90d int, mental_health_flag bool, scored_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.engineer_id) s.*
    FROM public.engineer_attrition_scores_v2 s
    ORDER BY s.engineer_id, s.scored_at DESC
  )
  SELECT l.id, l.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         l.risk_score, l.last_login_age_days, l.accept_rate_30d, l.nps_score,
         l.late_payout_count_90d, l.mental_health_flag, l.scored_at
  FROM latest l
  LEFT JOIN public.engineers e ON e.id = l.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE l.risk_band = 'red'
  ORDER BY l.risk_score DESC;
END $$;
REVOKE ALL ON FUNCTION public.founder_attrition_red_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_attrition_red_list() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_attrition_yellow_list()
RETURNS TABLE (id uuid, engineer_id uuid, full_name text, risk_score numeric, accept_rate_30d numeric, scored_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.engineer_id) s.*
    FROM public.engineer_attrition_scores_v2 s
    ORDER BY s.engineer_id, s.scored_at DESC
  )
  SELECT l.id, l.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         l.risk_score, l.accept_rate_30d, l.scored_at
  FROM latest l
  LEFT JOIN public.engineers e ON e.id = l.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE l.risk_band = 'yellow'
  ORDER BY l.risk_score DESC;
END $$;
REVOKE ALL ON FUNCTION public.founder_attrition_yellow_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_attrition_yellow_list() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_attrition_recent_interventions()
RETURNS TABLE (id uuid, engineer_id uuid, full_name text, intervention_type text, notes text, outcome text, performed_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         i.intervention_type, i.notes, i.outcome, i.performed_at
  FROM public.engineer_attrition_interventions_v2 i
  LEFT JOIN public.engineers e ON e.id = i.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY i.performed_at DESC
  LIMIT 60;
END $$;
REVOKE ALL ON FUNCTION public.founder_attrition_recent_interventions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_attrition_recent_interventions() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_attrition_pending_followups()
RETURNS TABLE (id uuid, engineer_id uuid, full_name text, intervention_type text, follow_up_at timestamptz, days_until int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         i.intervention_type, i.follow_up_at,
         EXTRACT(DAY FROM (i.follow_up_at - now()))::int
  FROM public.engineer_attrition_interventions_v2 i
  LEFT JOIN public.engineers e ON e.id = i.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE i.follow_up_at IS NOT NULL AND i.outcome IS NULL
  ORDER BY i.follow_up_at ASC
  LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION public.founder_attrition_pending_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_attrition_pending_followups() TO authenticated;

-- ============================================================
-- r1466 — fix GROUP BY session_summary RPC
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname LIKE '%data_room%session%'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

-- ============================================================
-- r1469 — STUB broken side-projects intel RPCs (engineers.profile_id wrong)
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_engineer_side_projects_kpis_r1469();
DROP FUNCTION IF EXISTS public.founder_engineer_side_projects_active_list_r1469();
DROP FUNCTION IF EXISTS public.founder_engineer_side_projects_by_risk_r1469();
DROP FUNCTION IF EXISTS public.founder_engineer_side_projects_recent_convos_r1469();
DROP FUNCTION IF EXISTS public.founder_engineer_side_projects_overdue_followups_r1469();

CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_kpis_r1469()
RETURNS TABLE (total_intel bigint, active_intel bigint, coi_flagged bigint, resolved_30d bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE status NOT IN ('resolved','dismissed'))::bigint,
    count(*) FILTER (WHERE coi_risk_band IN ('high','critical'))::bigint,
    count(*) FILTER (WHERE status='resolved' AND updated_at >= now() - interval '30 days')::bigint
  FROM public.engineer_side_projects_intel_v2;
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_side_projects_kpis_r1469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_side_projects_kpis_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_active_list_r1469()
RETURNS TABLE (id uuid, engineer_id uuid, full_name text, project_kind text, coi_risk_band text, status text, last_action_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         i.project_kind, i.coi_risk_band, i.status, i.updated_at
  FROM public.engineer_side_projects_intel_v2 i
  LEFT JOIN public.engineers e ON e.id = i.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE i.status NOT IN ('resolved','dismissed')
  ORDER BY i.updated_at DESC
  LIMIT 60;
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_side_projects_active_list_r1469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_side_projects_active_list_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_by_risk_r1469()
RETURNS TABLE (coi_risk_band text, intel_count bigint, engineers_affected bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.coi_risk_band, count(*)::bigint, count(DISTINCT i.engineer_id)::bigint
  FROM public.engineer_side_projects_intel_v2 i
  GROUP BY i.coi_risk_band
  ORDER BY count(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_side_projects_by_risk_r1469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_side_projects_by_risk_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_recent_convos_r1469()
RETURNS TABLE (id uuid, intel_id uuid, engineer_id uuid, full_name text, summary text, occurred_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.intel_id, i.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         c.summary, c.occurred_at
  FROM public.engineer_side_projects_conversations_v2 c
  LEFT JOIN public.engineer_side_projects_intel_v2 i ON i.id = c.intel_id
  LEFT JOIN public.engineers e ON e.id = i.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY c.occurred_at DESC
  LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_side_projects_recent_convos_r1469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_side_projects_recent_convos_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_engineer_side_projects_overdue_followups_r1469()
RETURNS TABLE (id uuid, engineer_id uuid, full_name text, follow_up_at timestamptz, days_overdue int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, i.engineer_id, COALESCE(p.full_name,'(unknown)')::text,
         c.follow_up_at, EXTRACT(DAY FROM (now() - c.follow_up_at))::int
  FROM public.engineer_side_projects_conversations_v2 c
  LEFT JOIN public.engineer_side_projects_intel_v2 i ON i.id = c.intel_id
  LEFT JOIN public.engineers e ON e.id = i.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE c.follow_up_at IS NOT NULL AND c.follow_up_at < now()
  ORDER BY c.follow_up_at ASC
  LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_side_projects_overdue_followups_r1469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_side_projects_overdue_followups_r1469() TO authenticated;

COMMIT;
