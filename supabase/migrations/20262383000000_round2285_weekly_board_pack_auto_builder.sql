BEGIN;

CREATE TABLE IF NOT EXISTS public.board_pack_metrics_r2285 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_code text NOT NULL UNIQUE,
  metric_label text NOT NULL,
  metric_section text NOT NULL CHECK (metric_section IN ('financials','operations','customers','engineers','growth','risk','milestones')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  draft_day_of_week int NOT NULL CHECK (draft_day_of_week BETWEEN 0 AND 6),
  draft_due_hour int NOT NULL DEFAULT 17 CHECK (draft_due_hour BETWEEN 0 AND 23),
  target_value_text text,
  current_value_text text,
  trend_arrow text CHECK (trend_arrow IN ('up','flat','down')),
  is_critical boolean NOT NULL DEFAULT false,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.board_pack_finalize_log_r2285 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_week_start date NOT NULL,
  metric_id uuid REFERENCES public.board_pack_metrics_r2285(id) ON DELETE CASCADE,
  draft_submitted_at timestamptz,
  draft_submitted_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  finalized_at timestamptz,
  finalized_value_text text,
  finalized_commentary text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','draft_submitted','finalized','skipped')),
  delay_hours numeric(6,2),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.board_pack_metrics_r2285 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_pack_finalize_log_r2285 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.board_pack_metrics_r2285;
CREATE POLICY founder_all ON public.board_pack_metrics_r2285 FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.board_pack_finalize_log_r2285;
CREATE POLICY founder_all ON public.board_pack_finalize_log_r2285 FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

INSERT INTO public.board_pack_metrics_r2285 (metric_code, metric_label, metric_section, draft_day_of_week, draft_due_hour, target_value_text, current_value_text, trend_arrow, is_critical, sort_order)
VALUES
  ('mrr_inr','Monthly Recurring Revenue (INR)','financials',5,17,'25L','18.4L','up',true,1),
  ('cash_runway_months','Cash Runway (months)','financials',5,17,'18','14.2','down',true,2),
  ('gross_margin_pct','Gross Margin %','financials',5,18,'45%','38.6%','up',false,3),
  ('amc_active_count','AMC Active Contracts','customers',5,17,'500','412','up',false,4),
  ('amc_churn_pct','AMC Churn %','customers',5,17,'<3%','4.1%','flat',true,5),
  ('repair_jobs_completed','Repair Jobs Completed (week)','operations',5,16,'350','318','up',false,6),
  ('sla_breach_pct','SLA Breach %','operations',5,16,'<5%','7.2%','down',true,7),
  ('engineer_active_count','Active Engineers','engineers',5,16,'120','108','up',false,8),
  ('engineer_payout_inr','Engineer Payouts (week INR)','engineers',5,16,'12L','9.8L','up',false,9),
  ('new_hospital_signups','New Hospital Signups','growth',5,15,'15','11','up',false,10),
  ('p0_incidents_count','P0 Incidents (week)','risk',5,15,'0','1','flat',true,11),
  ('dpdp_grievances_open','DPDP Open Grievances','risk',5,15,'0','2','down',true,12),
  ('roadmap_milestones_hit','Roadmap Milestones Hit','milestones',5,18,'4/4','3/4','flat',false,13)
ON CONFLICT (metric_code) DO NOTHING;

INSERT INTO public.board_pack_finalize_log_r2285 (pack_week_start, metric_id, status, delay_hours)
SELECT date_trunc('week', now())::date, id, 'pending', 0 FROM public.board_pack_metrics_r2285 LIMIT 13
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.board_pack_overview_r2285()
RETURNS TABLE(metric_section text, metric_count int, critical_count int, finalized_this_week int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.metric_section,
    (COUNT(*))::int AS metric_count,
    (COUNT(*) FILTER (WHERE m.is_critical))::int AS critical_count,
    (SELECT (COUNT(*) FILTER (WHERE l.status = 'finalized'))::int
       FROM public.board_pack_finalize_log_r2285 l
       JOIN public.board_pack_metrics_r2285 m2 ON m2.id = l.metric_id
      WHERE m2.metric_section = m.metric_section
        AND l.pack_week_start = date_trunc('week', now())::date) AS finalized_this_week
  FROM public.board_pack_metrics_r2285 m
  GROUP BY m.metric_section
  ORDER BY m.metric_section;
END;$$;

CREATE OR REPLACE FUNCTION public.board_pack_metrics_list_r2285()
RETURNS TABLE(metric_code text, metric_label text, metric_section text, owner_email text, draft_day text, target_value_text text, current_value_text text, trend_arrow text, is_critical boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.metric_code, m.metric_label, m.metric_section,
    COALESCE(p.email,'unassigned') AS owner_email,
    CASE m.draft_day_of_week WHEN 0 THEN 'Sun' WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue' WHEN 3 THEN 'Wed' WHEN 4 THEN 'Thu' WHEN 5 THEN 'Fri' WHEN 6 THEN 'Sat' END || ' ' || lpad(m.draft_due_hour::text,2,'0') || ':00' AS draft_day,
    m.target_value_text, m.current_value_text, m.trend_arrow, m.is_critical
  FROM public.board_pack_metrics_r2285 m
  LEFT JOIN public.profiles p ON p.id = m.owner_user_id
  ORDER BY m.sort_order;
END;$$;

CREATE OR REPLACE FUNCTION public.board_pack_owner_load_r2285()
RETURNS TABLE(owner_email text, metric_count int, critical_count int, pending_this_week int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(p.email,'unassigned') AS owner_email,
    (COUNT(*))::int AS metric_count,
    (COUNT(*) FILTER (WHERE m.is_critical))::int AS critical_count,
    (SELECT (COUNT(*) FILTER (WHERE l.status = 'pending'))::int
       FROM public.board_pack_finalize_log_r2285 l
       JOIN public.board_pack_metrics_r2285 m2 ON m2.id = l.metric_id
      WHERE m2.owner_user_id IS NOT DISTINCT FROM m.owner_user_id
        AND l.pack_week_start = date_trunc('week', now())::date) AS pending_this_week
  FROM public.board_pack_metrics_r2285 m
  LEFT JOIN public.profiles p ON p.id = m.owner_user_id
  GROUP BY p.email, m.owner_user_id
  ORDER BY metric_count DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.board_pack_due_today_r2285()
RETURNS TABLE(metric_code text, metric_label text, owner_email text, draft_due_hour int, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.metric_code, m.metric_label, COALESCE(p.email,'unassigned') AS owner_email, m.draft_due_hour,
    COALESCE(l.status, 'pending') AS status
  FROM public.board_pack_metrics_r2285 m
  LEFT JOIN public.profiles p ON p.id = m.owner_user_id
  LEFT JOIN public.board_pack_finalize_log_r2285 l
    ON l.metric_id = m.id AND l.pack_week_start = date_trunc('week', now())::date
  WHERE m.draft_day_of_week = extract(dow from now())::int
  ORDER BY m.draft_due_hour;
END;$$;

CREATE OR REPLACE FUNCTION public.board_pack_finalize_log_r2285()
RETURNS TABLE(pack_week_start date, metric_label text, status text, finalized_at timestamptz, delay_hours numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.pack_week_start, m.metric_label, l.status, l.finalized_at, l.delay_hours
  FROM public.board_pack_finalize_log_r2285 l
  JOIN public.board_pack_metrics_r2285 m ON m.id = l.metric_id
  ORDER BY l.pack_week_start DESC, m.sort_order
  LIMIT 50;
END;$$;

CREATE OR REPLACE FUNCTION public.board_pack_critical_status_r2285()
RETURNS TABLE(metric_label text, current_value_text text, target_value_text text, trend_arrow text, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.metric_label, m.current_value_text, m.target_value_text, m.trend_arrow,
    COALESCE(l.status, 'pending') AS status
  FROM public.board_pack_metrics_r2285 m
  LEFT JOIN public.board_pack_finalize_log_r2285 l
    ON l.metric_id = m.id AND l.pack_week_start = date_trunc('week', now())::date
  WHERE m.is_critical
  ORDER BY m.sort_order;
END;$$;

CREATE OR REPLACE FUNCTION public.board_pack_kpis_r2285()
RETURNS TABLE(total_metrics int, critical_metrics int, finalized_this_week int, pending_this_week int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT (COUNT(*))::int FROM public.board_pack_metrics_r2285) AS total_metrics,
    (SELECT (COUNT(*) FILTER (WHERE is_critical))::int FROM public.board_pack_metrics_r2285) AS critical_metrics,
    (SELECT (COUNT(*) FILTER (WHERE status = 'finalized'))::int FROM public.board_pack_finalize_log_r2285 WHERE pack_week_start = date_trunc('week', now())::date) AS finalized_this_week,
    (SELECT (COUNT(*) FILTER (WHERE status = 'pending'))::int FROM public.board_pack_finalize_log_r2285 WHERE pack_week_start = date_trunc('week', now())::date) AS pending_this_week;
END;$$;

REVOKE ALL ON FUNCTION public.board_pack_overview_r2285() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.board_pack_metrics_list_r2285() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.board_pack_owner_load_r2285() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.board_pack_due_today_r2285() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.board_pack_finalize_log_r2285() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.board_pack_critical_status_r2285() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.board_pack_kpis_r2285() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.board_pack_overview_r2285() TO authenticated;
GRANT EXECUTE ON FUNCTION public.board_pack_metrics_list_r2285() TO authenticated;
GRANT EXECUTE ON FUNCTION public.board_pack_owner_load_r2285() TO authenticated;
GRANT EXECUTE ON FUNCTION public.board_pack_due_today_r2285() TO authenticated;
GRANT EXECUTE ON FUNCTION public.board_pack_finalize_log_r2285() TO authenticated;
GRANT EXECUTE ON FUNCTION public.board_pack_critical_status_r2285() TO authenticated;
GRANT EXECUTE ON FUNCTION public.board_pack_kpis_r2285() TO authenticated;

COMMIT;
