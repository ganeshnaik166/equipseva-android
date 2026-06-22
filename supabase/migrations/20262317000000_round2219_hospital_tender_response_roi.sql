BEGIN;

CREATE TABLE IF NOT EXISTS public.tender_response_roi_r2219 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_code text NOT NULL,
  hospital_name text NOT NULL,
  city text,
  won_at date NOT NULL,
  bid_effort_hours numeric(8,2) NOT NULL DEFAULT 0,
  bid_cost_rupees bigint NOT NULL DEFAULT 0,
  contract_value_rupees bigint NOT NULL DEFAULT 0,
  realized_revenue_rupees bigint NOT NULL DEFAULT 0,
  first_revenue_at date,
  status text NOT NULL DEFAULT 'won',
  notes text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tender_roi_milestones_r2219 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_id uuid NOT NULL REFERENCES public.tender_response_roi_r2219(id) ON DELETE CASCADE,
  milestone_at date NOT NULL,
  milestone_kind text NOT NULL,
  amount_rupees bigint NOT NULL DEFAULT 0,
  note text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.tender_response_roi_r2219 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tender_roi_milestones_r2219 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.tender_response_roi_r2219;
CREATE POLICY founder_all ON public.tender_response_roi_r2219
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.tender_roi_milestones_r2219;
CREATE POLICY founder_all ON public.tender_roi_milestones_r2219
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_tender_roi_r2219()
RETURNS TABLE (
  id uuid,
  tender_code text,
  hospital_name text,
  city text,
  won_at date,
  bid_effort_hours numeric,
  bid_cost_rupees bigint,
  contract_value_rupees bigint,
  realized_revenue_rupees bigint,
  roi_ratio numeric,
  payback_months numeric,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.tender_code,
    t.hospital_name,
    t.city,
    t.won_at,
    t.bid_effort_hours,
    t.bid_cost_rupees,
    t.contract_value_rupees,
    t.realized_revenue_rupees,
    CASE WHEN t.bid_cost_rupees > 0
      THEN ROUND(t.realized_revenue_rupees::numeric / t.bid_cost_rupees::numeric, 2)
      ELSE NULL END AS roi_ratio,
    CASE WHEN t.first_revenue_at IS NOT NULL AND t.realized_revenue_rupees > 0
      THEN ROUND(((t.first_revenue_at - t.won_at)::numeric / 30.0), 1)
      ELSE NULL END AS payback_months,
    t.status
  FROM public.tender_response_roi_r2219 t
  ORDER BY t.won_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_tender_roi_r2219()
RETURNS TABLE (
  op_name text,
  actor_email text,
  after_value jsonb,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.op_name, f.actor_email, f.after_value, f.created_at
  FROM public.founder_action_log f
  WHERE f.op_name LIKE 'op_r2219%'
  ORDER BY f.created_at DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_tender_roi_r2219()
RETURNS TABLE (
  tender_code text,
  hospital_name text,
  roi_ratio numeric,
  realized_revenue_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.tender_code,
    t.hospital_name,
    CASE WHEN t.bid_cost_rupees > 0
      THEN ROUND(t.realized_revenue_rupees::numeric / t.bid_cost_rupees::numeric, 2)
      ELSE NULL END AS roi_ratio,
    t.realized_revenue_rupees
  FROM public.tender_response_roi_r2219 t
  WHERE t.bid_cost_rupees > 0
  ORDER BY (t.realized_revenue_rupees::numeric / NULLIF(t.bid_cost_rupees,0)::numeric) DESC NULLS LAST
  LIMIT 10;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_tender_roi_r2219(
  p_tender_code text,
  p_hospital_name text,
  p_city text,
  p_won_at date,
  p_bid_effort_hours numeric,
  p_bid_cost_rupees bigint,
  p_contract_value_rupees bigint
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.tender_response_roi_r2219(
    tender_code, hospital_name, city, won_at,
    bid_effort_hours, bid_cost_rupees, contract_value_rupees, created_by
  ) VALUES (
    p_tender_code, p_hospital_name, p_city, p_won_at,
    p_bid_effort_hours, p_bid_cost_rupees, p_contract_value_rupees, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2219_log',
    jsonb_build_object('tender_id', v_id, 'tender_code', p_tender_code, 'hospital', p_hospital_name));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_tender_roi_r2219(
  p_tender_id uuid,
  p_milestone_kind text,
  p_amount_rupees bigint,
  p_note text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.tender_roi_milestones_r2219(
    tender_id, milestone_at, milestone_kind, amount_rupees, note, created_by
  ) VALUES (
    p_tender_id, CURRENT_DATE, p_milestone_kind, p_amount_rupees, p_note, auth.uid()
  ) RETURNING id INTO v_id;

  IF p_milestone_kind = 'revenue' THEN
    UPDATE public.tender_response_roi_r2219
    SET realized_revenue_rupees = realized_revenue_rupees + p_amount_rupees,
        first_revenue_at = COALESCE(first_revenue_at, CURRENT_DATE)
    WHERE id = p_tender_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2219_log_action',
    jsonb_build_object('tender_id', p_tender_id, 'kind', p_milestone_kind, 'amount', p_amount_rupees));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_tender_roi_r2219(
  p_tender_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.tender_response_roi_r2219
  SET status = p_status
  WHERE id = p_tender_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2219_mark_status',
    jsonb_build_object('tender_id', p_tender_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_tender_roi_r2219()
RETURNS TABLE (
  total_tenders int,
  total_bid_cost_rupees bigint,
  total_realized_rupees bigint,
  blended_roi numeric,
  payback_lt_6mo int,
  payback_gt_12mo int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_tenders,
    COALESCE(SUM(t.bid_cost_rupees), 0)::bigint AS total_bid_cost_rupees,
    COALESCE(SUM(t.realized_revenue_rupees), 0)::bigint AS total_realized_rupees,
    CASE WHEN COALESCE(SUM(t.bid_cost_rupees),0) > 0
      THEN ROUND(SUM(t.realized_revenue_rupees)::numeric / SUM(t.bid_cost_rupees)::numeric, 2)
      ELSE NULL END AS blended_roi,
    (COUNT(*) FILTER (
      WHERE t.first_revenue_at IS NOT NULL
        AND ((t.first_revenue_at - t.won_at)::numeric / 30.0) < 6
    ))::int AS payback_lt_6mo,
    (COUNT(*) FILTER (
      WHERE t.first_revenue_at IS NOT NULL
        AND ((t.first_revenue_at - t.won_at)::numeric / 30.0) > 12
    ))::int AS payback_gt_12mo
  FROM public.tender_response_roi_r2219 t;
END;
$$;

REVOKE ALL ON FUNCTION public.list_tender_roi_r2219() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_tender_roi_r2219() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_tender_roi_r2219() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_tender_roi_r2219(text, text, text, date, numeric, bigint, bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_tender_roi_r2219(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_tender_roi_r2219(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_tender_roi_r2219() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tender_roi_r2219() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_tender_roi_r2219() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_tender_roi_r2219() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tender_roi_r2219(text, text, text, date, numeric, bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_tender_roi_r2219(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_tender_roi_r2219(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_tender_roi_r2219() TO authenticated;

COMMIT;
