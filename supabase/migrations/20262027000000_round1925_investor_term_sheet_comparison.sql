BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_term_sheets_r1925 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  term_sheet_label text NOT NULL,
  raise_amount_rupees bigint NOT NULL DEFAULT 0,
  valuation_pre_money_rupees bigint NOT NULL DEFAULT 0,
  valuation_post_money_rupees bigint NOT NULL DEFAULT 0,
  liquidation_preference text NOT NULL CHECK (liquidation_preference IN ('1x_non_participating','1x_participating','2x','none')),
  anti_dilution text NOT NULL CHECK (anti_dilution IN ('none','weighted_avg','full_ratchet')),
  status text NOT NULL CHECK (status IN ('draft','under_review','accepted','rejected')),
  received_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_term_sheet_clause_r1925 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ts_id uuid NOT NULL REFERENCES public.investor_term_sheets_r1925(id) ON DELETE CASCADE,
  clause_type text NOT NULL CHECK (clause_type IN ('board_seat','protective_provision','pro_rata','info_rights','founder_vesting','option_pool')),
  clause_md text NOT NULL,
  flagged boolean NOT NULL DEFAULT false,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_term_sheets_r1925 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_term_sheet_clause_r1925 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_terms_r1925 ON public.investor_term_sheets_r1925;
CREATE POLICY founder_all_terms_r1925 ON public.investor_term_sheets_r1925
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_clauses_r1925 ON public.investor_term_sheet_clause_r1925;
CREATE POLICY founder_all_clauses_r1925 ON public.investor_term_sheet_clause_r1925
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_terms_r1925()
RETURNS TABLE(id uuid, investor_id uuid, term_sheet_label text, raise_amount_rupees bigint, valuation_pre_money_rupees bigint, valuation_post_money_rupees bigint, liquidation_preference text, anti_dilution text, status text, received_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.investor_id, t.term_sheet_label, t.raise_amount_rupees, t.valuation_pre_money_rupees, t.valuation_post_money_rupees, t.liquidation_preference, t.anti_dilution, t.status, t.received_at
    FROM public.investor_term_sheets_r1925 t
    ORDER BY t.received_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_term_r1925(
  p_investor_id uuid,
  p_term_sheet_label text,
  p_raise_amount_rupees bigint,
  p_valuation_pre_money_rupees bigint,
  p_valuation_post_money_rupees bigint,
  p_liquidation_preference text,
  p_anti_dilution text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_term_sheets_r1925(investor_id, term_sheet_label, raise_amount_rupees, valuation_pre_money_rupees, valuation_post_money_rupees, liquidation_preference, anti_dilution, status)
  VALUES (p_investor_id, p_term_sheet_label, p_raise_amount_rupees, p_valuation_pre_money_rupees, p_valuation_post_money_rupees, p_liquidation_preference, p_anti_dilution, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_term_r1925', jsonb_build_object('id', v_id, 'label', p_term_sheet_label, 'raise', p_raise_amount_rupees));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_clauses_r1925(p_ts_id uuid)
RETURNS TABLE(id uuid, ts_id uuid, clause_type text, clause_md text, flagged boolean, recorded_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.ts_id, c.clause_type, c.clause_md, c.flagged, c.recorded_at
    FROM public.investor_term_sheet_clause_r1925 c
    WHERE c.ts_id = p_ts_id
    ORDER BY c.recorded_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_clause_r1925(
  p_ts_id uuid,
  p_clause_type text,
  p_clause_md text,
  p_flagged boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_term_sheet_clause_r1925(ts_id, clause_type, clause_md, flagged)
  VALUES (p_ts_id, p_clause_type, p_clause_md, COALESCE(p_flagged, false))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_clause_r1925', jsonb_build_object('id', v_id, 'ts_id', p_ts_id, 'clause_type', p_clause_type, 'flagged', p_flagged));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1925(p_ts_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_term_sheets_r1925 SET status = p_status, updated_at = now() WHERE id = p_ts_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1925', jsonb_build_object('ts_id', p_ts_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_terms_r1925()
RETURNS TABLE(id uuid, term_sheet_label text, raise_amount_rupees bigint, valuation_pre_money_rupees bigint, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.term_sheet_label, t.raise_amount_rupees, t.valuation_pre_money_rupees, t.status
    FROM public.investor_term_sheets_r1925 t
    ORDER BY t.valuation_pre_money_rupees DESC NULLS LAST, t.raise_amount_rupees DESC
    LIMIT 10;
END;
$$;

CREATE OR REPLACE FUNCTION public.flagged_clauses_r1925()
RETURNS TABLE(id uuid, ts_id uuid, term_sheet_label text, clause_type text, clause_md text, recorded_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.ts_id, t.term_sheet_label, c.clause_type, c.clause_md, c.recorded_at
    FROM public.investor_term_sheet_clause_r1925 c
    JOIN public.investor_term_sheets_r1925 t ON t.id = c.ts_id
    WHERE c.flagged = true
    ORDER BY c.recorded_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_terms_r1925() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_term_r1925(uuid, text, bigint, bigint, bigint, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_clauses_r1925(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_clause_r1925(uuid, text, text, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1925(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_terms_r1925() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.flagged_clauses_r1925() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_terms_r1925() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_term_r1925(uuid, text, bigint, bigint, bigint, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_clauses_r1925(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_clause_r1925(uuid, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1925(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_terms_r1925() TO authenticated;
GRANT EXECUTE ON FUNCTION public.flagged_clauses_r1925() TO authenticated;

COMMIT;
