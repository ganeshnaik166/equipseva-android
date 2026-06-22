BEGIN;

CREATE TABLE IF NOT EXISTS public.contract_amendments_r2213 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid,
  contract_ref text NOT NULL,
  customer_org text NOT NULL,
  amendment_type text NOT NULL CHECK (amendment_type IN ('tier_change','price_adjust','scope_expand','scope_reduce','term_extend','term_shorten','sla_change','party_change','other')),
  before_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  after_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  diff_summary text NOT NULL,
  reason text,
  requested_by_email text,
  effective_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','legal_review','founder_review','approved','rejected','executed','reverted')),
  amount_delta_rupees numeric(12,2) DEFAULT 0,
  approval_chain jsonb NOT NULL DEFAULT '[]'::jsonb,
  approved_by_user_id uuid REFERENCES public.profiles(id),
  approved_at timestamptz,
  executed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_camend_r2213_status ON public.contract_amendments_r2213(status);
CREATE INDEX IF NOT EXISTS idx_camend_r2213_effective ON public.contract_amendments_r2213(effective_date DESC);
CREATE INDEX IF NOT EXISTS idx_camend_r2213_contract ON public.contract_amendments_r2213(contract_ref);

ALTER TABLE public.contract_amendments_r2213 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.contract_amendments_r2213;
CREATE POLICY founder_all ON public.contract_amendments_r2213 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.contract_amendment_approvals_r2213 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amendment_id uuid NOT NULL REFERENCES public.contract_amendments_r2213(id) ON DELETE CASCADE,
  step_order int NOT NULL,
  approver_role text NOT NULL CHECK (approver_role IN ('legal','finance','founder','customer_success','sales')),
  approver_email text,
  decision text NOT NULL CHECK (decision IN ('pending','approved','rejected','escalated')),
  decided_at timestamptz,
  comments text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_capprov_r2213_amend ON public.contract_amendment_approvals_r2213(amendment_id, step_order);
CREATE INDEX IF NOT EXISTS idx_capprov_r2213_decision ON public.contract_amendment_approvals_r2213(decision);

ALTER TABLE public.contract_amendment_approvals_r2213 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.contract_amendment_approvals_r2213;
CREATE POLICY founder_all ON public.contract_amendment_approvals_r2213 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_amendments_r2213()
RETURNS TABLE(id uuid, contract_ref text, customer_org text, amendment_type text, diff_summary text, effective_date date, status text, amount_delta_rupees numeric, requested_by_email text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.contract_ref, a.customer_org, a.amendment_type, a.diff_summary,
         a.effective_date, a.status, a.amount_delta_rupees, a.requested_by_email, a.created_at
  FROM public.contract_amendments_r2213 a
  ORDER BY a.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2213()
RETURNS TABLE(actor_email text, op_name text, after_value jsonb, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.actor_email, l.op_name, l.after_value, l.created_at
  FROM public.founder_action_log l
  WHERE l.op_name LIKE 'op_r2213%'
  ORDER BY l.created_at DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_amendment_types_r2213()
RETURNS TABLE(amendment_type text, n int, total_delta_rupees numeric, pending_n int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.amendment_type,
         (COUNT(*))::int AS n,
         COALESCE(SUM(a.amount_delta_rupees), 0) AS total_delta_rupees,
         (COUNT(*) FILTER (WHERE a.status IN ('pending','legal_review','founder_review')))::int AS pending_n
  FROM public.contract_amendments_r2213 a
  GROUP BY a.amendment_type
  ORDER BY n DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_amendment_r2213(
  p_contract_ref text,
  p_customer_org text,
  p_amendment_type text,
  p_before jsonb,
  p_after jsonb,
  p_diff_summary text,
  p_reason text,
  p_effective_date date,
  p_amount_delta numeric
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.contract_amendments_r2213(contract_ref, customer_org, amendment_type, before_value, after_value, diff_summary, reason, requested_by_email, effective_date, amount_delta_rupees)
  VALUES (p_contract_ref, p_customer_org, p_amendment_type, COALESCE(p_before,'{}'::jsonb), COALESCE(p_after,'{}'::jsonb), p_diff_summary, p_reason, (auth.jwt()->>'email'), p_effective_date, COALESCE(p_amount_delta,0))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2213_log_amendment', jsonb_build_object('id', v_id, 'contract_ref', p_contract_ref, 'type', p_amendment_type, 'delta', p_amount_delta));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2213(p_op text, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2213_' || p_op, COALESCE(p_payload,'{}'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2213(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('pending','legal_review','founder_review','approved','rejected','executed','reverted') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.contract_amendments_r2213
  SET status = p_status,
      updated_at = now(),
      approved_at = CASE WHEN p_status = 'approved' THEN now() ELSE approved_at END,
      executed_at = CASE WHEN p_status = 'executed' THEN now() ELSE executed_at END,
      approved_by_user_id = CASE WHEN p_status = 'approved' THEN auth.uid() ELSE approved_by_user_id END
  WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2213_mark_status', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_amendments_r2213()
RETURNS TABLE(total_n int, pending_n int, approved_n int, executed_n int, rejected_n int, total_delta_rupees numeric, upcoming_effective_n int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_n,
    (COUNT(*) FILTER (WHERE a.status IN ('pending','legal_review','founder_review')))::int AS pending_n,
    (COUNT(*) FILTER (WHERE a.status = 'approved'))::int AS approved_n,
    (COUNT(*) FILTER (WHERE a.status = 'executed'))::int AS executed_n,
    (COUNT(*) FILTER (WHERE a.status = 'rejected'))::int AS rejected_n,
    COALESCE(SUM(a.amount_delta_rupees), 0) AS total_delta_rupees,
    (COUNT(*) FILTER (WHERE a.effective_date >= CURRENT_DATE AND a.status IN ('approved','pending','legal_review','founder_review')))::int AS upcoming_effective_n
  FROM public.contract_amendments_r2213 a;
END;
$$;

REVOKE ALL ON FUNCTION public.list_amendments_r2213() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2213() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_amendment_types_r2213() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_amendment_r2213(text, text, text, jsonb, jsonb, text, text, date, numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2213(text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2213(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_amendments_r2213() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_amendments_r2213() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2213() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_amendment_types_r2213() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_amendment_r2213(text, text, text, jsonb, jsonb, text, text, date, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2213(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2213(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_amendments_r2213() TO authenticated;

COMMIT;
