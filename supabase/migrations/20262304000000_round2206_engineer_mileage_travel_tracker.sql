BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_mileage_logs_r2206 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  engineer_name text NOT NULL,
  job_ref text NOT NULL,
  trip_date date NOT NULL DEFAULT CURRENT_DATE,
  origin_label text NOT NULL,
  destination_label text NOT NULL,
  distance_km numeric(8,2) NOT NULL DEFAULT 0,
  travel_minutes int NOT NULL DEFAULT 0,
  billable_km numeric(8,2) NOT NULL DEFAULT 0,
  rate_per_km_rupees numeric(8,2) NOT NULL DEFAULT 12.00,
  reimbursement_rupees int NOT NULL DEFAULT 0,
  outlier_flag boolean NOT NULL DEFAULT false,
  outlier_reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','paid','flagged')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_mileage_actions_r2206 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  log_id uuid REFERENCES public.engineer_mileage_logs_r2206(id) ON DELETE SET NULL,
  action text NOT NULL,
  detail text,
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_mileage_logs_r2206 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_mileage_actions_r2206 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_mileage_logs_r2206;
CREATE POLICY founder_all ON public.engineer_mileage_logs_r2206
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_mileage_actions_r2206;
CREATE POLICY founder_all ON public.engineer_mileage_actions_r2206
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_mileage_logs_r2206()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  job_ref text,
  trip_date date,
  origin_label text,
  destination_label text,
  distance_km numeric,
  travel_minutes int,
  billable_km numeric,
  reimbursement_rupees int,
  outlier_flag boolean,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.engineer_name, l.job_ref, l.trip_date, l.origin_label, l.destination_label,
         l.distance_km, l.travel_minutes, l.billable_km, l.reimbursement_rupees,
         l.outlier_flag, l.status, l.created_at
  FROM public.engineer_mileage_logs_r2206 l
  ORDER BY l.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2206()
RETURNS TABLE (
  id uuid,
  log_id uuid,
  action text,
  detail text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.log_id, a.action, a.detail, a.actor_email, a.created_at
  FROM public.engineer_mileage_actions_r2206 a
  ORDER BY a.created_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_engineers_r2206()
RETURNS TABLE (
  engineer_name text,
  trip_count int,
  total_km numeric,
  total_reimbursement_rupees int,
  outlier_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.engineer_name,
         (COUNT(*))::int AS trip_count,
         COALESCE(SUM(l.distance_km), 0) AS total_km,
         COALESCE(SUM(l.reimbursement_rupees), 0)::int AS total_reimbursement_rupees,
         (COUNT(*) FILTER (WHERE l.outlier_flag))::int AS outlier_count
  FROM public.engineer_mileage_logs_r2206 l
  GROUP BY l.engineer_name
  ORDER BY total_reimbursement_rupees DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_mileage_r2206(
  p_engineer_name text,
  p_job_ref text,
  p_origin text,
  p_destination text,
  p_distance_km numeric,
  p_travel_minutes int,
  p_billable_km numeric,
  p_rate numeric,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_reimb int;
  v_outlier boolean := false;
  v_reason text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_reimb := ROUND(p_billable_km * p_rate)::int;
  IF p_distance_km > 150 THEN
    v_outlier := true;
    v_reason := 'distance over 150km';
  ELSIF p_travel_minutes > 300 THEN
    v_outlier := true;
    v_reason := 'travel time over 5 hours';
  ELSIF p_billable_km > p_distance_km THEN
    v_outlier := true;
    v_reason := 'billable km exceeds actual distance';
  END IF;
  INSERT INTO public.engineer_mileage_logs_r2206(
    engineer_name, job_ref, origin_label, destination_label, distance_km,
    travel_minutes, billable_km, rate_per_km_rupees, reimbursement_rupees,
    outlier_flag, outlier_reason, note
  )
  VALUES (
    p_engineer_name, p_job_ref, p_origin, p_destination, p_distance_km,
    p_travel_minutes, p_billable_km, p_rate, v_reimb,
    v_outlier, v_reason, p_note
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2206',
    jsonb_build_object('log_id', v_id, 'engineer', p_engineer_name, 'reimb', v_reimb, 'outlier', v_outlier));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2206(
  p_log_id uuid,
  p_action text,
  p_detail text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_mileage_actions_r2206(log_id, action, detail, actor_email)
  VALUES (p_log_id, p_action, p_detail, (auth.jwt()->>'email'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2206',
    jsonb_build_object('log_id', p_log_id, 'action', p_action));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2206(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('pending','approved','rejected','paid','flagged') THEN
    RAISE EXCEPTION 'bad status';
  END IF;
  UPDATE public.engineer_mileage_logs_r2206 SET status = p_status WHERE id = p_id;
  INSERT INTO public.engineer_mileage_actions_r2206(log_id, action, detail, actor_email)
  VALUES (p_id, 'status_change', p_status, (auth.jwt()->>'email'));
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2206',
    jsonb_build_object('log_id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_mileage_r2206()
RETURNS TABLE (
  total_trips int,
  total_km numeric,
  total_reimbursement_rupees int,
  pending_count int,
  outlier_count int,
  approved_count int,
  paid_count int,
  avg_km_per_trip numeric,
  avg_travel_minutes numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (COUNT(*))::int,
         COALESCE(SUM(l.distance_km), 0),
         COALESCE(SUM(l.reimbursement_rupees), 0)::int,
         (COUNT(*) FILTER (WHERE l.status = 'pending'))::int,
         (COUNT(*) FILTER (WHERE l.outlier_flag))::int,
         (COUNT(*) FILTER (WHERE l.status = 'approved'))::int,
         (COUNT(*) FILTER (WHERE l.status = 'paid'))::int,
         COALESCE(AVG(l.distance_km), 0),
         COALESCE(AVG(l.travel_minutes), 0)
  FROM public.engineer_mileage_logs_r2206 l;
END;
$$;

REVOKE ALL ON FUNCTION public.list_mileage_logs_r2206() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2206() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_engineers_r2206() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_mileage_r2206(text, text, text, text, numeric, int, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2206(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2206(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_mileage_r2206() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_mileage_logs_r2206() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2206() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engineers_r2206() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_mileage_r2206(text, text, text, text, numeric, int, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2206(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2206(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_mileage_r2206() TO authenticated;

COMMIT;
