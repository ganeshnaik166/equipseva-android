BEGIN;
-- r1419 founder_investor_quarterly_update_publisher


CREATE TABLE IF NOT EXISTS public.founder_investor_quarterly_updates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL UNIQUE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','reviewed','published','sent')),
  headline text,
  key_wins_summary text,
  key_misses_summary text,
  asks_for_help text,
  kpis_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  mrr_eop_rupees numeric,
  mrr_delta_qoq_pct numeric,
  active_amcs int,
  active_engineers int,
  total_gmv_quarter_rupees numeric,
  total_payouts_quarter_rupees numeric,
  code_red_count_quarter int,
  dispute_count_quarter int,
  drafted_at timestamptz,
  reviewed_at timestamptz,
  published_at timestamptz,
  sent_at timestamptz,
  sent_to text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fiqu_status ON public.founder_investor_quarterly_updates(status);
CREATE INDEX IF NOT EXISTS idx_fiqu_period ON public.founder_investor_quarterly_updates(period_start DESC);

CREATE TABLE IF NOT EXISTS public.founder_investor_quarterly_update_recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  update_id uuid NOT NULL REFERENCES public.founder_investor_quarterly_updates(id) ON DELETE CASCADE,
  investor_firm_name text NOT NULL,
  investor_partner_email text NOT NULL,
  sent_at timestamptz,
  opened_at timestamptz,
  replied_at timestamptz,
  opt_out_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fiqur_update ON public.founder_investor_quarterly_update_recipients(update_id);
CREATE INDEX IF NOT EXISTS idx_fiqur_email ON public.founder_investor_quarterly_update_recipients(investor_partner_email);

ALTER TABLE public.founder_investor_quarterly_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_investor_quarterly_update_recipients ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.founder_investor_quarterly_update_summary()
RETURNS TABLE (
  total_updates int,
  draft_count int,
  reviewed_count int,
  published_count int,
  sent_count int,
  latest_quarter text,
  latest_status text,
  latest_mrr_eop_rupees numeric,
  total_recipients int,
  unique_firms int,
  opened_count int,
  replied_count int,
  opt_out_count int,
  open_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH u AS (SELECT * FROM public.founder_investor_quarterly_updates),
  r AS (SELECT * FROM public.founder_investor_quarterly_update_recipients),
  latest AS (SELECT quarter_label, status, mrr_eop_rupees FROM u ORDER BY period_start DESC NULLS LAST LIMIT 1)
  SELECT
    (SELECT count(*)::int FROM u),
    (SELECT count(*)::int FROM u WHERE status='draft'),
    (SELECT count(*)::int FROM u WHERE status='reviewed'),
    (SELECT count(*)::int FROM u WHERE status='published'),
    (SELECT count(*)::int FROM u WHERE status='sent'),
    (SELECT quarter_label FROM latest),
    (SELECT status FROM latest),
    (SELECT mrr_eop_rupees FROM latest),
    (SELECT count(*)::int FROM r),
    (SELECT count(DISTINCT investor_firm_name)::int FROM r),
    (SELECT count(*)::int FROM r WHERE opened_at IS NOT NULL),
    (SELECT count(*)::int FROM r WHERE replied_at IS NOT NULL),
    (SELECT count(*)::int FROM r WHERE opt_out_at IS NOT NULL),
    (SELECT CASE WHEN count(*) FILTER (WHERE sent_at IS NOT NULL) > 0
       THEN round(100.0 * count(*) FILTER (WHERE opened_at IS NOT NULL) / count(*) FILTER (WHERE sent_at IS NOT NULL), 2)
       ELSE 0 END FROM r);
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_investor_quarterly_updates_recent()
RETURNS SETOF public.founder_investor_quarterly_updates
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT * FROM public.founder_investor_quarterly_updates ORDER BY period_start DESC NULLS LAST, created_at DESC LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_investor_quarterly_recipients_recent(p_update_id uuid DEFAULT NULL)
RETURNS SETOF public.founder_investor_quarterly_update_recipients
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
    SELECT * FROM public.founder_investor_quarterly_update_recipients
    WHERE p_update_id IS NULL OR update_id = p_update_id
    ORDER BY created_at DESC LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_iqu_create_update(
  p_quarter_label text,
  p_period_start date,
  p_period_end date,
  p_headline text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_mrr numeric;
  v_amcs int;
  v_engs int;
  v_gmv numeric;
  v_payouts numeric;
  v_code_red int;
  v_disputes int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0) INTO v_mrr
    FROM public.amc_contracts WHERE status = 'active';
  SELECT count(*) INTO v_amcs FROM public.amc_contracts WHERE status = 'active';
  SELECT count(*) INTO v_engs FROM public.engineers WHERE verification_status::text = 'verified';
  SELECT COALESCE(SUM(total_amount),0) INTO v_gmv
    FROM public.spare_part_orders
    WHERE created_at >= p_period_start AND created_at < p_period_end + 1;
  SELECT COALESCE(SUM(amount_rupees),0) INTO v_payouts
    FROM public.engineer_payouts
    WHERE created_at >= p_period_start AND created_at < p_period_end + 1;
  v_code_red := 0;
  v_disputes := 0;

  INSERT INTO public.founder_investor_quarterly_updates(
    quarter_label, period_start, period_end, status, headline,
    kpis_snapshot, mrr_eop_rupees, active_amcs, active_engineers,
    total_gmv_quarter_rupees, total_payouts_quarter_rupees,
    code_red_count_quarter, dispute_count_quarter, drafted_at
  ) VALUES (
    p_quarter_label, p_period_start, p_period_end, 'draft', p_headline,
    jsonb_build_object('mrr',v_mrr,'amcs',v_amcs,'engineers',v_engs,'gmv',v_gmv,'payouts',v_payouts),
    v_mrr, v_amcs, v_engs, v_gmv, v_payouts, v_code_red, v_disputes, now()
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_iqu_add_recipient(
  p_update_id uuid,
  p_firm_name text,
  p_partner_email text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_investor_quarterly_update_recipients(update_id, investor_firm_name, investor_partner_email)
  VALUES (p_update_id, p_firm_name, p_partner_email)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_iqu_status(
  p_update_id uuid,
  p_new_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_new_status NOT IN ('draft','reviewed','published','sent') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE='22023';
  END IF;
  UPDATE public.founder_investor_quarterly_updates
    SET status = p_new_status,
        reviewed_at = CASE WHEN p_new_status='reviewed' THEN now() ELSE reviewed_at END,
        published_at = CASE WHEN p_new_status='published' THEN now() ELSE published_at END,
        sent_at = CASE WHEN p_new_status='sent' THEN now() ELSE sent_at END,
        updated_at = now()
  WHERE id = p_update_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_iqu_record_sent(
  p_recipient_id uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.founder_investor_quarterly_update_recipients
    SET sent_at = COALESCE(sent_at, now())
  WHERE id = p_recipient_id;
END;
$$;

-- anon-callable tracking pixel hit; no founder gate
CREATE OR REPLACE FUNCTION public.log_founder_iqu_record_opened(
  p_recipient_id uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE public.founder_investor_quarterly_update_recipients
    SET opened_at = COALESCE(opened_at, now())
  WHERE id = p_recipient_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_investor_quarterly_update_summary() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_investor_quarterly_updates_recent() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_investor_quarterly_recipients_recent(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_iqu_create_update(text,date,date,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_iqu_add_recipient(uuid,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_iqu_status(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_iqu_record_sent(uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.founder_investor_quarterly_update_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_investor_quarterly_updates_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_investor_quarterly_recipients_recent(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iqu_create_update(text,date,date,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iqu_add_recipient(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iqu_status(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iqu_record_sent(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iqu_record_opened(uuid) TO anon, authenticated;

COMMIT;