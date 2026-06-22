BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_drift_r1929 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  expected_total_shares bigint NOT NULL,
  actual_total_shares bigint NOT NULL,
  drift_pct numeric NOT NULL,
  drift_root_cause_md text,
  status text NOT NULL CHECK (status IN ('detected','investigating','reconciled','escalated')),
  detected_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_cap_table_reconciliation_log_r1929 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drift_id uuid NOT NULL REFERENCES public.investor_cap_table_drift_r1929(id) ON DELETE CASCADE,
  reconciliation_action text NOT NULL CHECK (reconciliation_action IN ('share_count_adjusted','issuance_logged','grant_corrected','option_exercise_logged','escalation')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_drift_r1929 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_cap_table_reconciliation_log_r1929 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_drift_r1929 ON public.investor_cap_table_drift_r1929;
CREATE POLICY founder_all_drift_r1929 ON public.investor_cap_table_drift_r1929
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_recon_r1929 ON public.investor_cap_table_reconciliation_log_r1929;
CREATE POLICY founder_all_recon_r1929 ON public.investor_cap_table_reconciliation_log_r1929
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_drifts_r1929()
RETURNS SETOF public.investor_cap_table_drift_r1929
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_drift_r1929 ORDER BY detected_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_drift_r1929(
  p_period_label text,
  p_expected bigint,
  p_actual bigint,
  p_root_cause_md text,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_pct numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_expected = 0 THEN
    v_pct := 0;
  ELSE
    v_pct := ROUND(((p_actual - p_expected)::numeric / p_expected::numeric) * 100, 4);
  END IF;
  INSERT INTO public.investor_cap_table_drift_r1929(period_label, expected_total_shares, actual_total_shares, drift_pct, drift_root_cause_md, status)
  VALUES (p_period_label, p_expected, p_actual, v_pct, p_root_cause_md, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_drift_r1929', jsonb_build_object('id', v_id, 'period', p_period_label, 'pct', v_pct));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_reconciliations_r1929(p_drift_id uuid)
RETURNS SETOF public.investor_cap_table_reconciliation_log_r1929
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_reconciliation_log_r1929 WHERE drift_id = p_drift_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_reconciliation_r1929(
  p_drift_id uuid,
  p_action text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_reconciliation_log_r1929(drift_id, reconciliation_action, by_email, notes_md)
  VALUES (p_drift_id, p_action, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reconciliation_r1929', jsonb_build_object('id', v_id, 'drift_id', p_drift_id, 'action', p_action));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_reconciled_r1929(p_drift_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_drift_r1929 SET status = 'reconciled', updated_at = now() WHERE id = p_drift_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_reconciled_r1929', jsonb_build_object('drift_id', p_drift_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.significant_drifts_r1929()
RETURNS SETOF public.investor_cap_table_drift_r1929
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_drift_r1929
    WHERE ABS(drift_pct) >= 1.0 AND status <> 'reconciled'
    ORDER BY ABS(drift_pct) DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_reconciliations_r1929()
RETURNS SETOF public.investor_cap_table_reconciliation_log_r1929
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_reconciliation_log_r1929
    ORDER BY taken_at DESC LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_drifts_r1929() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_drift_r1929(text, bigint, bigint, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reconciliations_r1929(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reconciliation_r1929(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_reconciled_r1929(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.significant_drifts_r1929() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reconciliations_r1929() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_drifts_r1929() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_drift_r1929(text, bigint, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reconciliations_r1929(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reconciliation_r1929(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_reconciled_r1929(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.significant_drifts_r1929() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reconciliations_r1929() TO authenticated;

COMMIT;
