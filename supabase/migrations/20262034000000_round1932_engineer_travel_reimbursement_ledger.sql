BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_travel_reimbursements_r1932 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  repair_job_id uuid,
  expense_category text NOT NULL CHECK (expense_category IN ('fuel','toll','parking','lodging','food','mileage_allowance')),
  claimed_amount_rupees bigint NOT NULL DEFAULT 0,
  approved_amount_rupees bigint,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','paid')),
  claimed_at timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_reimbursement_action_log_r1932 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reimbursement_id uuid REFERENCES public.engineer_travel_reimbursements_r1932(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('submitted','approved','rejected','paid','queried')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_travel_reimbursements_r1932 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_reimbursement_action_log_r1932 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1932_reimb ON public.engineer_travel_reimbursements_r1932;
CREATE POLICY founder_all_r1932_reimb ON public.engineer_travel_reimbursements_r1932
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1932_actions ON public.engineer_reimbursement_action_log_r1932;
CREATE POLICY founder_all_r1932_actions ON public.engineer_reimbursement_action_log_r1932
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_reimbursements_r1932(p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, engineer_user_id uuid, repair_job_id uuid, expense_category text, claimed_amount_rupees bigint, approved_amount_rupees bigint, status text, claimed_at timestamptz, approved_at timestamptz, paid_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.engineer_user_id, r.repair_job_id, r.expense_category, r.claimed_amount_rupees, r.approved_amount_rupees, r.status, r.claimed_at, r.approved_at, r.paid_at
    FROM public.engineer_travel_reimbursements_r1932 r ORDER BY r.claimed_at DESC LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.log_reimbursement_r1932(p_engineer_user_id uuid, p_repair_job_id uuid, p_expense_category text, p_claimed_amount_rupees bigint)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_travel_reimbursements_r1932(engineer_user_id, repair_job_id, expense_category, claimed_amount_rupees)
    VALUES (p_engineer_user_id, p_repair_job_id, p_expense_category, p_claimed_amount_rupees) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reimbursement_r1932', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'category', p_expense_category, 'amount', p_claimed_amount_rupees));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r1932(p_reimbursement_id uuid)
RETURNS TABLE(id uuid, reimbursement_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.reimbursement_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_reimbursement_action_log_r1932 a WHERE a.reimbursement_id = p_reimbursement_id ORDER BY a.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r1932(p_reimbursement_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_reimbursement_action_log_r1932(reimbursement_id, action_type, by_email, notes_md)
    VALUES (p_reimbursement_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1932', jsonb_build_object('id', v_id, 'reimbursement_id', p_reimbursement_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1932(p_reimbursement_id uuid, p_status text, p_approved_amount_rupees bigint DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_travel_reimbursements_r1932
    SET status = p_status,
        approved_amount_rupees = COALESCE(p_approved_amount_rupees, approved_amount_rupees),
        approved_at = CASE WHEN p_status = 'approved' THEN now() ELSE approved_at END,
        paid_at = CASE WHEN p_status = 'paid' THEN now() ELSE paid_at END,
        updated_at = now()
    WHERE id = p_reimbursement_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1932', jsonb_build_object('id', p_reimbursement_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.top_engineers_by_amount_r1932(p_limit int DEFAULT 20)
RETURNS TABLE(engineer_user_id uuid, total_claimed bigint, total_approved bigint, claim_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.engineer_user_id,
    COALESCE(SUM(r.claimed_amount_rupees),0)::bigint AS total_claimed,
    COALESCE(SUM(r.approved_amount_rupees),0)::bigint AS total_approved,
    COUNT(*)::bigint AS claim_count
    FROM public.engineer_travel_reimbursements_r1932 r
    WHERE r.engineer_user_id IS NOT NULL
    GROUP BY r.engineer_user_id
    ORDER BY total_claimed DESC LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1932(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, reimbursement_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.reimbursement_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_reimbursement_action_log_r1932 a ORDER BY a.taken_at DESC LIMIT p_limit;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_reimbursements_r1932(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reimbursement_r1932(uuid, uuid, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1932(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1932(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1932(uuid, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_engineers_by_amount_r1932(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1932(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reimbursements_r1932(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reimbursement_r1932(uuid, uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1932(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1932(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1932(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engineers_by_amount_r1932(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1932(int) TO authenticated;

COMMIT;
