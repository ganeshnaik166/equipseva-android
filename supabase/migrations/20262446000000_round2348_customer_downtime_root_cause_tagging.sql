BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_downtime_episodes_r2348 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_org_name text NOT NULL,
  equipment_label text NOT NULL,
  equipment_serial text,
  episode_started_at timestamptz NOT NULL,
  episode_ended_at timestamptz,
  downtime_hours numeric(10,2),
  root_cause_category text NOT NULL CHECK (root_cause_category IN (
    'spare_part_delay','engineer_unavailable','misdiagnosis','user_error',
    'environmental','manufacturer_defect','amc_gap','logistics_delay','unknown'
  )),
  root_cause_detail text NOT NULL,
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  revenue_impact_rupees numeric(12,2) NOT NULL DEFAULT 0,
  resolution_status text NOT NULL DEFAULT 'open' CHECK (resolution_status IN ('open','investigating','resolved','closed')),
  tagged_by_email text NOT NULL,
  tagged_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS customer_downtime_episodes_r2348_customer_idx
  ON public.customer_downtime_episodes_r2348(customer_user_id, episode_started_at DESC);
CREATE INDEX IF NOT EXISTS customer_downtime_episodes_r2348_cause_idx
  ON public.customer_downtime_episodes_r2348(root_cause_category, severity);
CREATE INDEX IF NOT EXISTS customer_downtime_episodes_r2348_status_idx
  ON public.customer_downtime_episodes_r2348(resolution_status, episode_started_at DESC);

ALTER TABLE public.customer_downtime_episodes_r2348 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS customer_downtime_episodes_r2348_founder_all ON public.customer_downtime_episodes_r2348;
CREATE POLICY customer_downtime_episodes_r2348_founder_all
  ON public.customer_downtime_episodes_r2348
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_downtime_prevention_learnings_r2348 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  episode_id uuid REFERENCES public.customer_downtime_episodes_r2348(id) ON DELETE SET NULL,
  root_cause_category text NOT NULL,
  learning_title text NOT NULL,
  learning_detail text NOT NULL,
  prevention_action text NOT NULL,
  action_owner_email text NOT NULL,
  action_status text NOT NULL DEFAULT 'pending' CHECK (action_status IN ('pending','in_progress','done','dropped')),
  estimated_episodes_prevented integer NOT NULL DEFAULT 0,
  logged_by_email text NOT NULL,
  logged_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS customer_downtime_prevention_learnings_r2348_episode_idx
  ON public.customer_downtime_prevention_learnings_r2348(episode_id);
CREATE INDEX IF NOT EXISTS customer_downtime_prevention_learnings_r2348_cause_idx
  ON public.customer_downtime_prevention_learnings_r2348(root_cause_category, action_status);

ALTER TABLE public.customer_downtime_prevention_learnings_r2348 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS customer_downtime_prevention_learnings_r2348_founder_all ON public.customer_downtime_prevention_learnings_r2348;
CREATE POLICY customer_downtime_prevention_learnings_r2348_founder_all
  ON public.customer_downtime_prevention_learnings_r2348
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2348_list_downtime_episodes()
RETURNS TABLE (
  id uuid,
  customer_org_name text,
  equipment_label text,
  equipment_serial text,
  episode_started_at timestamptz,
  episode_ended_at timestamptz,
  downtime_hours numeric,
  root_cause_category text,
  severity text,
  revenue_impact_rupees numeric,
  resolution_status text,
  tagged_by_email text,
  tagged_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.customer_org_name, e.equipment_label, e.equipment_serial,
           e.episode_started_at, e.episode_ended_at, e.downtime_hours,
           e.root_cause_category, e.severity, e.revenue_impact_rupees,
           e.resolution_status, e.tagged_by_email, e.tagged_at
      FROM public.customer_downtime_episodes_r2348 e
      ORDER BY e.episode_started_at DESC
      LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2348_root_cause_summary()
RETURNS TABLE (
  root_cause_category text,
  episode_count bigint,
  total_downtime_hours numeric,
  total_revenue_impact_rupees numeric,
  open_count bigint,
  critical_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.root_cause_category,
           COUNT(*)::bigint AS episode_count,
           COALESCE(SUM(e.downtime_hours), 0)::numeric AS total_downtime_hours,
           COALESCE(SUM(e.revenue_impact_rupees), 0)::numeric AS total_revenue_impact_rupees,
           SUM(CASE WHEN e.resolution_status = 'open' THEN 1 ELSE 0 END)::bigint AS open_count,
           SUM(CASE WHEN e.severity = 'critical' THEN 1 ELSE 0 END)::bigint AS critical_count
      FROM public.customer_downtime_episodes_r2348 e
      GROUP BY e.root_cause_category
      ORDER BY episode_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2348_top_affected_customers()
RETURNS TABLE (
  customer_org_name text,
  episode_count bigint,
  total_downtime_hours numeric,
  total_revenue_impact_rupees numeric,
  last_episode_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.customer_org_name,
           COUNT(*)::bigint,
           COALESCE(SUM(e.downtime_hours), 0)::numeric,
           COALESCE(SUM(e.revenue_impact_rupees), 0)::numeric,
           MAX(e.episode_started_at)
      FROM public.customer_downtime_episodes_r2348 e
      GROUP BY e.customer_org_name
      ORDER BY COUNT(*) DESC
      LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2348_list_prevention_learnings()
RETURNS TABLE (
  id uuid,
  episode_id uuid,
  root_cause_category text,
  learning_title text,
  prevention_action text,
  action_owner_email text,
  action_status text,
  estimated_episodes_prevented integer,
  logged_by_email text,
  logged_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.episode_id, l.root_cause_category, l.learning_title,
           l.prevention_action, l.action_owner_email, l.action_status,
           l.estimated_episodes_prevented, l.logged_by_email, l.logged_at
      FROM public.customer_downtime_prevention_learnings_r2348 l
      ORDER BY l.logged_at DESC
      LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2348_kpis()
RETURNS TABLE (
  total_episodes bigint,
  open_episodes bigint,
  critical_episodes bigint,
  total_downtime_hours numeric,
  total_revenue_impact_rupees numeric,
  total_learnings bigint,
  pending_actions bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::bigint FROM public.customer_downtime_episodes_r2348),
      (SELECT COUNT(*)::bigint FROM public.customer_downtime_episodes_r2348 WHERE resolution_status = 'open'),
      (SELECT COUNT(*)::bigint FROM public.customer_downtime_episodes_r2348 WHERE severity = 'critical'),
      (SELECT COALESCE(SUM(downtime_hours), 0)::numeric FROM public.customer_downtime_episodes_r2348),
      (SELECT COALESCE(SUM(revenue_impact_rupees), 0)::numeric FROM public.customer_downtime_episodes_r2348),
      (SELECT COUNT(*)::bigint FROM public.customer_downtime_prevention_learnings_r2348),
      (SELECT COUNT(*)::bigint FROM public.customer_downtime_prevention_learnings_r2348 WHERE action_status = 'pending');
END;
$$;

CREATE OR REPLACE FUNCTION public.r2348_tag_downtime_episode(
  p_customer_user_id uuid,
  p_customer_org_name text,
  p_equipment_label text,
  p_equipment_serial text,
  p_episode_started_at timestamptz,
  p_episode_ended_at timestamptz,
  p_downtime_hours numeric,
  p_root_cause_category text,
  p_root_cause_detail text,
  p_severity text,
  p_revenue_impact_rupees numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := COALESCE(auth.jwt()->>'email', 'founder@equipseva.com');
  INSERT INTO public.customer_downtime_episodes_r2348(
    customer_user_id, customer_org_name, equipment_label, equipment_serial,
    episode_started_at, episode_ended_at, downtime_hours,
    root_cause_category, root_cause_detail, severity, revenue_impact_rupees,
    tagged_by_email
  ) VALUES (
    p_customer_user_id, p_customer_org_name, p_equipment_label, p_equipment_serial,
    p_episode_started_at, p_episode_ended_at, p_downtime_hours,
    p_root_cause_category, p_root_cause_detail, p_severity, p_revenue_impact_rupees,
    v_email
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2348_log_prevention_learning(
  p_episode_id uuid,
  p_root_cause_category text,
  p_learning_title text,
  p_learning_detail text,
  p_prevention_action text,
  p_action_owner_email text,
  p_estimated_episodes_prevented integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := COALESCE(auth.jwt()->>'email', 'founder@equipseva.com');
  INSERT INTO public.customer_downtime_prevention_learnings_r2348(
    episode_id, root_cause_category, learning_title, learning_detail,
    prevention_action, action_owner_email, estimated_episodes_prevented, logged_by_email
  ) VALUES (
    p_episode_id, p_root_cause_category, p_learning_title, p_learning_detail,
    p_prevention_action, p_action_owner_email, p_estimated_episodes_prevented, v_email
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.r2348_list_downtime_episodes() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2348_root_cause_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2348_top_affected_customers() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2348_list_prevention_learnings() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2348_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2348_tag_downtime_episode(uuid, text, text, text, timestamptz, timestamptz, numeric, text, text, text, numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2348_log_prevention_learning(uuid, text, text, text, text, text, integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2348_list_downtime_episodes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2348_root_cause_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2348_top_affected_customers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2348_list_prevention_learnings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2348_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2348_tag_downtime_episode(uuid, text, text, text, timestamptz, timestamptz, numeric, text, text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2348_log_prevention_learning(uuid, text, text, text, text, text, integer) TO authenticated;

COMMIT;
