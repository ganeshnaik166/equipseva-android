BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_insurance_welfare_r1960 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  coverage_type text NOT NULL CHECK (coverage_type IN ('health','life','accident','family','disability','pension')),
  premium_rupees bigint NOT NULL DEFAULT 0,
  coverage_start_date date NOT NULL,
  coverage_end_date date NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','lapsed','cancelled','upgraded')),
  last_premium_paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_insurance_action_log_r1960 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coverage_id uuid NOT NULL REFERENCES public.engineer_insurance_welfare_r1960(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('premium_paid','renewal_initiated','claim_submitted','claim_approved','coverage_upgraded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_insurance_welfare_r1960 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_insurance_action_log_r1960 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eiw_r1960 ON public.engineer_insurance_welfare_r1960;
CREATE POLICY founder_all_eiw_r1960 ON public.engineer_insurance_welfare_r1960
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eial_r1960 ON public.engineer_insurance_action_log_r1960;
CREATE POLICY founder_all_eial_r1960 ON public.engineer_insurance_action_log_r1960
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_coverages_r1960()
RETURNS SETOF public.engineer_insurance_welfare_r1960
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.engineer_insurance_welfare_r1960 ORDER BY coverage_end_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_coverage_r1960(
  p_engineer_user_id uuid,
  p_coverage_type text,
  p_premium_rupees bigint,
  p_coverage_start_date date,
  p_coverage_end_date date,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_insurance_welfare_r1960(engineer_user_id, coverage_type, premium_rupees, coverage_start_date, coverage_end_date, status)
  VALUES (p_engineer_user_id, p_coverage_type, p_premium_rupees, p_coverage_start_date, p_coverage_end_date, COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_coverage_r1960', jsonb_build_object('coverage_id', v_id, 'engineer_user_id', p_engineer_user_id, 'coverage_type', p_coverage_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1960(p_coverage_id uuid)
RETURNS SETOF public.engineer_insurance_action_log_r1960
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.engineer_insurance_action_log_r1960 WHERE coverage_id = p_coverage_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1960(
  p_coverage_id uuid,
  p_action_type text,
  p_amount_rupees bigint,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_insurance_action_log_r1960(coverage_id, action_type, by_email, amount_rupees, notes_md)
  VALUES (p_coverage_id, p_action_type, (auth.jwt()->>'email'), p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;

  IF p_action_type = 'premium_paid' THEN
    UPDATE public.engineer_insurance_welfare_r1960
      SET last_premium_paid_at = now(), updated_at = now()
      WHERE id = p_coverage_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1960', jsonb_build_object('action_id', v_id, 'coverage_id', p_coverage_id, 'action_type', p_action_type, 'amount_rupees', p_amount_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1960(
  p_coverage_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_insurance_welfare_r1960
    SET status = p_status, updated_at = now()
    WHERE id = p_coverage_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1960', jsonb_build_object('coverage_id', p_coverage_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.expiring_coverage_r1960(p_days int)
RETURNS SETOF public.engineer_insurance_welfare_r1960
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_insurance_welfare_r1960
    WHERE status = 'active'
      AND coverage_end_date <= (current_date + COALESCE(p_days, 30))
    ORDER BY coverage_end_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1960(p_limit int)
RETURNS SETOF public.engineer_insurance_action_log_r1960
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_insurance_action_log_r1960
    ORDER BY taken_at DESC
    LIMIT COALESCE(p_limit, 50);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_coverages_r1960() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_coverage_r1960(uuid, text, bigint, date, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1960(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1960(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1960(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_coverage_r1960(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1960(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_coverages_r1960() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_coverage_r1960(uuid, text, bigint, date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1960(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1960(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1960(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_coverage_r1960(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1960(int) TO authenticated;

COMMIT;
