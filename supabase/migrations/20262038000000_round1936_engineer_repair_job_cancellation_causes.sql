BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_job_cancellation_causes_r1936 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id uuid,
  hospital_id uuid REFERENCES public.profiles(id),
  engineer_user_id uuid REFERENCES public.profiles(id),
  cancellation_side text NOT NULL CHECK (cancellation_side IN ('hospital','engineer','founder','system')),
  cause_category text NOT NULL CHECK (cause_category IN ('duplicate_booking','equipment_unavailable','payment_dispute','scheduling_conflict','customer_no_show','engineer_unavailable','other')),
  cause_md text,
  cancelled_at timestamptz NOT NULL DEFAULT now(),
  financial_impact_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'logged' CHECK (status IN ('logged','refunded','escalated','disputed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_cancellation_remedy_log_r1936 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cancellation_id uuid NOT NULL REFERENCES public.engineer_job_cancellation_causes_r1936(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('refunded','credit_issued','rebooking_offered','dispute_opened','training_assigned')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_job_cancellation_causes_r1936 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_cancellation_remedy_log_r1936 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r1936_causes_founder ON public.engineer_job_cancellation_causes_r1936;
CREATE POLICY r1936_causes_founder ON public.engineer_job_cancellation_causes_r1936
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r1936_remedy_founder ON public.engineer_cancellation_remedy_log_r1936;
CREATE POLICY r1936_remedy_founder ON public.engineer_cancellation_remedy_log_r1936
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r1936_list_cancellations(p_limit int DEFAULT 200)
RETURNS SETOF public.engineer_job_cancellation_causes_r1936
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_job_cancellation_causes_r1936 ORDER BY cancelled_at DESC LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1936_log_cancellation(
  p_repair_job_id uuid,
  p_hospital_id uuid,
  p_engineer_user_id uuid,
  p_cancellation_side text,
  p_cause_category text,
  p_cause_md text,
  p_financial_impact_rupees bigint
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_job_cancellation_causes_r1936(repair_job_id, hospital_id, engineer_user_id, cancellation_side, cause_category, cause_md, financial_impact_rupees)
  VALUES (p_repair_job_id, p_hospital_id, p_engineer_user_id, p_cancellation_side, p_cause_category, p_cause_md, COALESCE(p_financial_impact_rupees,0))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1936_log_cancellation', jsonb_build_object('id', v_id, 'side', p_cancellation_side, 'category', p_cause_category));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1936_list_remedies(p_cancellation_id uuid)
RETURNS SETOF public.engineer_cancellation_remedy_log_r1936
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_cancellation_remedy_log_r1936 WHERE cancellation_id = p_cancellation_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1936_log_remedy(
  p_cancellation_id uuid,
  p_action_type text,
  p_outcome_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_cancellation_remedy_log_r1936(cancellation_id, action_type, by_email, outcome_md)
  VALUES (p_cancellation_id, p_action_type, (auth.jwt()->>'email'), p_outcome_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1936_log_remedy', jsonb_build_object('id', v_id, 'cancellation_id', p_cancellation_id, 'action', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1936_mark_status(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_job_cancellation_causes_r1936 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1936_mark_status', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.r1936_top_causes()
RETURNS TABLE(cause_category text, cnt bigint, total_impact_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT c.cause_category, count(*)::bigint, COALESCE(sum(c.financial_impact_rupees),0)::bigint
    FROM public.engineer_job_cancellation_causes_r1936 c
    GROUP BY c.cause_category
    ORDER BY count(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1936_recent_remedies(p_limit int DEFAULT 100)
RETURNS SETOF public.engineer_cancellation_remedy_log_r1936
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_cancellation_remedy_log_r1936 ORDER BY taken_at DESC LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1936_list_cancellations(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1936_log_cancellation(uuid, uuid, uuid, text, text, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1936_list_remedies(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1936_log_remedy(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1936_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1936_top_causes() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1936_recent_remedies(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1936_list_cancellations(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1936_log_cancellation(uuid, uuid, uuid, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1936_list_remedies(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1936_log_remedy(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1936_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1936_top_causes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1936_recent_remedies(int) TO authenticated;

COMMIT;
