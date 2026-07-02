BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_skill_gap_revenue_link_r2214 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  gap_type text NOT NULL,
  gap_category text NOT NULL,
  equipment_modality text,
  revenue_impact_rupees integer NOT NULL DEFAULT 0,
  lost_jobs_count integer NOT NULL DEFAULT 0,
  escalation_count integer NOT NULL DEFAULT 0,
  refund_count integer NOT NULL DEFAULT 0,
  refund_rupees integer NOT NULL DEFAULT 0,
  observed_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_skill_gap_revenue_link_actions_r2214 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id uuid REFERENCES public.engineer_skill_gap_revenue_link_r2214(id) ON DELETE CASCADE,
  action_taken text NOT NULL,
  remediation_plan text,
  status text NOT NULL DEFAULT 'open',
  acted_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  acted_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_skill_gap_revenue_link_r2214 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_skill_gap_revenue_link_actions_r2214 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_skill_gap_revenue_link_r2214;
CREATE POLICY founder_all ON public.engineer_skill_gap_revenue_link_r2214
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_skill_gap_revenue_link_actions_r2214;
CREATE POLICY founder_all ON public.engineer_skill_gap_revenue_link_actions_r2214
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_skill_gap_revenue_r2214()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  gap_type text,
  gap_category text,
  equipment_modality text,
  revenue_impact_rupees integer,
  lost_jobs_count integer,
  escalation_count integer,
  refund_count integer,
  refund_rupees integer,
  observed_at timestamptz,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, r.gap_type, r.gap_category, r.equipment_modality,
         r.revenue_impact_rupees, r.lost_jobs_count, r.escalation_count,
         r.refund_count, r.refund_rupees, r.observed_at, r.notes
  FROM public.engineer_skill_gap_revenue_link_r2214 r
  ORDER BY r.revenue_impact_rupees DESC, r.observed_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_skill_gap_revenue_r2214()
RETURNS TABLE (
  id uuid,
  link_id uuid,
  action_taken text,
  remediation_plan text,
  status text,
  acted_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.link_id, a.action_taken, a.remediation_plan, a.status, a.acted_at
  FROM public.engineer_skill_gap_revenue_link_actions_r2214 a
  ORDER BY a.acted_at DESC
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.top_skill_gap_revenue_r2214()
RETURNS TABLE (
  gap_type text,
  total_revenue_impact integer,
  total_lost_jobs integer,
  total_escalations integer,
  total_refunds integer,
  engineers_affected integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.gap_type,
         COALESCE(SUM(r.revenue_impact_rupees), 0)::int,
         COALESCE(SUM(r.lost_jobs_count), 0)::int,
         COALESCE(SUM(r.escalation_count), 0)::int,
         COALESCE(SUM(r.refund_count), 0)::int,
         (COUNT(DISTINCT r.engineer_user_id))::int
  FROM public.engineer_skill_gap_revenue_link_r2214 r
  GROUP BY r.gap_type
  ORDER BY 2 DESC
  LIMIT 25;
END $$;

CREATE OR REPLACE FUNCTION public.log_skill_gap_revenue_r2214(
  p_engineer_user_id uuid,
  p_gap_type text,
  p_gap_category text,
  p_equipment_modality text,
  p_revenue_impact_rupees integer,
  p_lost_jobs_count integer,
  p_escalation_count integer,
  p_refund_count integer,
  p_refund_rupees integer,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_skill_gap_revenue_link_r2214(
    engineer_user_id, gap_type, gap_category, equipment_modality,
    revenue_impact_rupees, lost_jobs_count, escalation_count,
    refund_count, refund_rupees, notes)
  VALUES (p_engineer_user_id, p_gap_type, p_gap_category, p_equipment_modality,
          COALESCE(p_revenue_impact_rupees, 0), COALESCE(p_lost_jobs_count, 0),
          COALESCE(p_escalation_count, 0), COALESCE(p_refund_count, 0),
          COALESCE(p_refund_rupees, 0), p_notes)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2214_log_skill_gap',
          jsonb_build_object('id', v_id, 'gap_type', p_gap_type, 'engineer', p_engineer_user_id));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_skill_gap_revenue_r2214(
  p_link_id uuid,
  p_action_taken text,
  p_remediation_plan text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_skill_gap_revenue_link_actions_r2214(
    link_id, action_taken, remediation_plan, acted_by)
  VALUES (p_link_id, p_action_taken, p_remediation_plan, auth.uid())
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2214_log_action_skill_gap',
          jsonb_build_object('action_id', v_id, 'link_id', p_link_id, 'action', p_action_taken));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_skill_gap_revenue_r2214(
  p_action_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_skill_gap_revenue_link_actions_r2214
  SET status = p_status
  WHERE id = p_action_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2214_mark_status_skill_gap',
          jsonb_build_object('action_id', p_action_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.aggregate_skill_gap_revenue_r2214()
RETURNS TABLE (
  total_links integer,
  total_revenue_impact integer,
  total_lost_jobs integer,
  total_escalations integer,
  total_refunds integer,
  total_refund_rupees integer,
  open_actions integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (COUNT(*) FILTER (WHERE TRUE))::int,
         COALESCE(SUM(r.revenue_impact_rupees), 0)::int,
         COALESCE(SUM(r.lost_jobs_count), 0)::int,
         COALESCE(SUM(r.escalation_count), 0)::int,
         COALESCE(SUM(r.refund_count), 0)::int,
         COALESCE(SUM(r.refund_rupees), 0)::int,
         (SELECT (COUNT(*) FILTER (WHERE a.status = 'open'))::int
          FROM public.engineer_skill_gap_revenue_link_actions_r2214 a)
  FROM public.engineer_skill_gap_revenue_link_r2214 r;
END $$;

REVOKE ALL ON FUNCTION public.list_skill_gap_revenue_r2214() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_skill_gap_revenue_r2214() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_skill_gap_revenue_r2214() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_skill_gap_revenue_r2214(uuid, text, text, text, integer, integer, integer, integer, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_skill_gap_revenue_r2214(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_skill_gap_revenue_r2214(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_skill_gap_revenue_r2214() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_skill_gap_revenue_r2214() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_skill_gap_revenue_r2214() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_skill_gap_revenue_r2214() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_skill_gap_revenue_r2214(uuid, text, text, text, integer, integer, integer, integer, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_skill_gap_revenue_r2214(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_skill_gap_revenue_r2214(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_skill_gap_revenue_r2214() TO authenticated;

COMMIT;
