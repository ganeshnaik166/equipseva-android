BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_offsite_visits_r1696 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  visit_date date NOT NULL,
  distance_km int NOT NULL DEFAULT 0,
  travel_cost_rupees int NOT NULL DEFAULT 0,
  reason text NOT NULL DEFAULT '',
  billable boolean NOT NULL DEFAULT false,
  billed_amount_rupees int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_offsite_visit_outcomes_r1696 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id uuid NOT NULL REFERENCES public.engineer_offsite_visits_r1696(id) ON DELETE CASCADE,
  outcome text NOT NULL DEFAULT '',
  follow_up_required boolean NOT NULL DEFAULT false,
  follow_up_at date,
  founder_review text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_offsite_visits_r1696 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_offsite_visit_outcomes_r1696 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_visits_r1696 ON public.engineer_offsite_visits_r1696;
CREATE POLICY founder_all_visits_r1696 ON public.engineer_offsite_visits_r1696
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_outcomes_r1696 ON public.engineer_offsite_visit_outcomes_r1696;
CREATE POLICY founder_all_outcomes_r1696 ON public.engineer_offsite_visit_outcomes_r1696
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_visits
CREATE OR REPLACE FUNCTION public.list_offsite_visits_r1696()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  visit_date date,
  distance_km int,
  travel_cost_rupees int,
  reason text,
  billable boolean,
  billed_amount_rupees int,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.engineer_user_id, p.email::text, v.hospital_id, o.name::text,
         v.visit_date, v.distance_km, v.travel_cost_rupees, v.reason,
         v.billable, v.billed_amount_rupees, v.status, v.created_at
  FROM public.engineer_offsite_visits_r1696 v
  LEFT JOIN public.profiles p ON p.id = v.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = v.hospital_id
  ORDER BY v.visit_date DESC NULLS LAST
  LIMIT 200;
END;
$$;

-- RPC 2: schedule_visit
CREATE OR REPLACE FUNCTION public.schedule_offsite_visit_r1696(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_visit_date date,
  p_distance_km int,
  p_travel_cost_rupees int,
  p_reason text,
  p_billable boolean,
  p_billed_amount_rupees int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_offsite_visits_r1696(
    engineer_user_id, hospital_id, visit_date, distance_km,
    travel_cost_rupees, reason, billable, billed_amount_rupees, status
  ) VALUES (
    p_engineer_user_id, p_hospital_id, p_visit_date, COALESCE(p_distance_km,0),
    COALESCE(p_travel_cost_rupees,0), COALESCE(p_reason,''),
    COALESCE(p_billable,false), COALESCE(p_billed_amount_rupees,0), 'planned'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'schedule_offsite_visit_r1696',
          jsonb_build_object('visit_id', v_id, 'engineer_user_id', p_engineer_user_id, 'visit_date', p_visit_date));
  RETURN v_id;
END;
$$;

-- RPC 3: list_outcomes
CREATE OR REPLACE FUNCTION public.list_offsite_visit_outcomes_r1696()
RETURNS TABLE(
  id uuid,
  visit_id uuid,
  visit_date date,
  engineer_email text,
  outcome text,
  follow_up_required boolean,
  follow_up_at date,
  founder_review text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT oc.id, oc.visit_id, v.visit_date, p.email::text,
         oc.outcome, oc.follow_up_required, oc.follow_up_at,
         oc.founder_review, oc.created_at
  FROM public.engineer_offsite_visit_outcomes_r1696 oc
  LEFT JOIN public.engineer_offsite_visits_r1696 v ON v.id = oc.visit_id
  LEFT JOIN public.profiles p ON p.id = v.engineer_user_id
  ORDER BY oc.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: record_outcome
CREATE OR REPLACE FUNCTION public.record_offsite_visit_outcome_r1696(
  p_visit_id uuid,
  p_outcome text,
  p_follow_up_required boolean,
  p_follow_up_at date,
  p_founder_review text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_offsite_visit_outcomes_r1696(
    visit_id, outcome, follow_up_required, follow_up_at, founder_review
  ) VALUES (
    p_visit_id, COALESCE(p_outcome,''), COALESCE(p_follow_up_required,false),
    p_follow_up_at, p_founder_review
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_offsite_visit_outcome_r1696',
          jsonb_build_object('outcome_id', v_id, 'visit_id', p_visit_id));
  RETURN v_id;
END;
$$;

-- RPC 5: complete_visit
CREATE OR REPLACE FUNCTION public.complete_offsite_visit_r1696(p_visit_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_offsite_visits_r1696
     SET status = 'completed', updated_at = now()
   WHERE id = p_visit_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_offsite_visit_r1696',
          jsonb_build_object('visit_id', p_visit_id));
  RETURN true;
END;
$$;

-- RPC 6: monthly_roi_summary
CREATE OR REPLACE FUNCTION public.monthly_offsite_roi_summary_r1696()
RETURNS TABLE(
  month_start date,
  visits_count int,
  total_travel_cost int,
  total_billed int,
  net_roi int,
  completed_count int,
  cancelled_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', v.visit_date)::date AS month_start,
         (COUNT(*))::int AS visits_count,
         (COALESCE(SUM(v.travel_cost_rupees),0))::int AS total_travel_cost,
         (COALESCE(SUM(v.billed_amount_rupees),0))::int AS total_billed,
         (COALESCE(SUM(v.billed_amount_rupees),0) - COALESCE(SUM(v.travel_cost_rupees),0))::int AS net_roi,
         (COUNT(*) FILTER (WHERE v.status = 'completed'))::int AS completed_count,
         (COUNT(*) FILTER (WHERE v.status = 'cancelled'))::int AS cancelled_count
  FROM public.engineer_offsite_visits_r1696 v
  GROUP BY date_trunc('month', v.visit_date)
  ORDER BY month_start DESC
  LIMIT 24;
END;
$$;

-- RPC 7: follow_up_due
CREATE OR REPLACE FUNCTION public.offsite_follow_up_due_r1696()
RETURNS TABLE(
  outcome_id uuid,
  visit_id uuid,
  engineer_email text,
  hospital_name text,
  follow_up_at date,
  days_overdue int,
  outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT oc.id, oc.visit_id, p.email::text, o.name::text,
         oc.follow_up_at,
         GREATEST(0, (CURRENT_DATE - oc.follow_up_at))::int AS days_overdue,
         oc.outcome
  FROM public.engineer_offsite_visit_outcomes_r1696 oc
  LEFT JOIN public.engineer_offsite_visits_r1696 v ON v.id = oc.visit_id
  LEFT JOIN public.profiles p ON p.id = v.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = v.hospital_id
  WHERE oc.follow_up_required = true
    AND oc.follow_up_at IS NOT NULL
    AND oc.follow_up_at <= CURRENT_DATE + INTERVAL '7 day'
  ORDER BY oc.follow_up_at ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_offsite_visits_r1696() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.schedule_offsite_visit_r1696(uuid, uuid, date, int, int, text, boolean, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_offsite_visit_outcomes_r1696() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_offsite_visit_outcome_r1696(uuid, text, boolean, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_offsite_visit_r1696(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.monthly_offsite_roi_summary_r1696() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.offsite_follow_up_due_r1696() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_offsite_visits_r1696() TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_offsite_visit_r1696(uuid, uuid, date, int, int, text, boolean, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_offsite_visit_outcomes_r1696() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_offsite_visit_outcome_r1696(uuid, text, boolean, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_offsite_visit_r1696(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.monthly_offsite_roi_summary_r1696() TO authenticated;
GRANT EXECUTE ON FUNCTION public.offsite_follow_up_due_r1696() TO authenticated;

COMMIT;