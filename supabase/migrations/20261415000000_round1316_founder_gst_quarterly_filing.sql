BEGIN;

-- r1316 founder GST quarterly filing prep (GSTR-1 + GSTR-3B)

CREATE TABLE IF NOT EXISTS public.founder_gst_filings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  gstr1_payload jsonb,
  gstr3b_payload jsonb,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','reviewed','filed','rejected')),
  arn text,
  filed_at timestamptz,
  total_outward_taxable_rupees numeric DEFAULT 0,
  total_igst_rupees numeric DEFAULT 0,
  total_cgst_rupees numeric DEFAULT 0,
  total_sgst_rupees numeric DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(quarter_label)
);

ALTER TABLE public.founder_gst_filings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_gst_filings_no_direct ON public.founder_gst_filings;
CREATE POLICY founder_gst_filings_no_direct ON public.founder_gst_filings FOR ALL TO authenticated USING (false) WITH CHECK (false);

DROP FUNCTION IF EXISTS public.founder_gst_quarterly_prep(date);
CREATE OR REPLACE FUNCTION public.founder_gst_quarterly_prep(p_quarter_start date)
RETURNS TABLE (
  quarter_label text, period_start date, period_end date,
  b2b_invoice_count bigint, b2b_taxable_value_rupees numeric, b2b_igst_rupees numeric, b2b_cgst_rupees numeric, b2b_sgst_rupees numeric,
  b2c_invoice_count bigint, b2c_taxable_value_rupees numeric, b2c_igst_rupees numeric, b2c_cgst_rupees numeric, b2c_sgst_rupees numeric,
  nil_rated_count bigint, hsn_distinct_count bigint,
  total_outward_taxable_rupees numeric, total_igst_rupees numeric, total_cgst_rupees numeric, total_sgst_rupees numeric,
  itc_eligible_rupees numeric, net_tax_payable_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_period_end date := (p_quarter_start + interval '3 months' - interval '1 day')::date;
  v_q_label text := 'Q' || to_char(p_quarter_start, 'Q') || '-FY' || to_char(p_quarter_start, 'YY') || '-' || to_char(p_quarter_start + interval '1 year', 'YY');
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH inv AS (
    SELECT g.* FROM public.gst_invoices g
    WHERE g.invoice_date >= p_quarter_start
      AND g.invoice_date <= v_period_end
      AND COALESCE(g.status, '') <> 'cancelled'
  ),
  b2b AS (
    SELECT
      COUNT(*)::bigint AS cnt,
      COALESCE(SUM(COALESCE(taxable_value_rupees,0)),0)::numeric AS tax_val,
      COALESCE(SUM(COALESCE(igst_rupees,0)),0)::numeric AS igst,
      COALESCE(SUM(COALESCE(cgst_rupees,0)),0)::numeric AS cgst,
      COALESCE(SUM(COALESCE(sgst_rupees,0)),0)::numeric AS sgst
    FROM inv WHERE buyer_gstin IS NOT NULL
  ),
  b2c AS (
    SELECT
      COUNT(*)::bigint AS cnt,
      COALESCE(SUM(COALESCE(taxable_value_rupees,0)),0)::numeric AS tax_val,
      COALESCE(SUM(COALESCE(igst_rupees,0)),0)::numeric AS igst,
      COALESCE(SUM(COALESCE(cgst_rupees,0)),0)::numeric AS cgst,
      COALESCE(SUM(COALESCE(sgst_rupees,0)),0)::numeric AS sgst
    FROM inv WHERE buyer_gstin IS NULL
  ),
  meta AS (
    SELECT
      COUNT(*) FILTER (WHERE COALESCE(taxable_value_rupees,0) = 0)::bigint AS nil_cnt,
      COUNT(DISTINCT hsn_code)::bigint AS hsn_cnt
    FROM inv
  )
  SELECT
    v_q_label, p_quarter_start, v_period_end,
    b2b.cnt, b2b.tax_val, b2b.igst, b2b.cgst, b2b.sgst,
    b2c.cnt, b2c.tax_val, b2c.igst, b2c.cgst, b2c.sgst,
    meta.nil_cnt, meta.hsn_cnt,
    (b2b.tax_val + b2c.tax_val)::numeric,
    (b2b.igst + b2c.igst)::numeric,
    (b2b.cgst + b2c.cgst)::numeric,
    (b2b.sgst + b2c.sgst)::numeric,
    0::numeric,
    (b2b.igst + b2c.igst + b2b.cgst + b2c.cgst + b2b.sgst + b2c.sgst)::numeric
  FROM b2b, b2c, meta;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_gst_quarterly_prep(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gst_quarterly_prep(date) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_gst_quarterly_filings_recent(int);
CREATE OR REPLACE FUNCTION public.founder_gst_quarterly_filings_recent(p_limit int DEFAULT 8)
RETURNS TABLE (
  id uuid, quarter_label text, period_start date, period_end date,
  status text, arn text, filed_at timestamptz,
  total_outward_taxable_rupees numeric, total_igst_rupees numeric,
  total_cgst_rupees numeric, total_sgst_rupees numeric,
  created_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT f.id, f.quarter_label, f.period_start, f.period_end,
         f.status::text, f.arn, f.filed_at,
         COALESCE(f.total_outward_taxable_rupees,0), COALESCE(f.total_igst_rupees,0),
         COALESCE(f.total_cgst_rupees,0), COALESCE(f.total_sgst_rupees,0),
         f.created_at, f.updated_at
  FROM public.founder_gst_filings f
  ORDER BY f.period_start DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 8), 24));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_gst_quarterly_filings_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gst_quarterly_filings_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_gst_filing_draft(text, date);
CREATE OR REPLACE FUNCTION public.log_founder_gst_filing_draft(p_quarter_label text, p_quarter_start date)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_period_end date := (p_quarter_start + interval '3 months' - interval '1 day')::date;
  v_prep record;
  v_gstr1 jsonb;
  v_gstr3b jsonb;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT * INTO v_prep FROM public.founder_gst_quarterly_prep(p_quarter_start) LIMIT 1;

  v_gstr1 := jsonb_build_object(
    'quarter', p_quarter_label,
    'period_start', p_quarter_start,
    'period_end', v_period_end,
    'b2b', jsonb_build_object('count', v_prep.b2b_invoice_count, 'taxable', v_prep.b2b_taxable_value_rupees,
                               'igst', v_prep.b2b_igst_rupees, 'cgst', v_prep.b2b_cgst_rupees, 'sgst', v_prep.b2b_sgst_rupees),
    'b2c', jsonb_build_object('count', v_prep.b2c_invoice_count, 'taxable', v_prep.b2c_taxable_value_rupees,
                               'igst', v_prep.b2c_igst_rupees, 'cgst', v_prep.b2c_cgst_rupees, 'sgst', v_prep.b2c_sgst_rupees),
    'nil_rated', v_prep.nil_rated_count,
    'hsn_distinct', v_prep.hsn_distinct_count
  );
  v_gstr3b := jsonb_build_object(
    'quarter', p_quarter_label,
    'outward_taxable', v_prep.total_outward_taxable_rupees,
    'igst', v_prep.total_igst_rupees,
    'cgst', v_prep.total_cgst_rupees,
    'sgst', v_prep.total_sgst_rupees,
    'itc_eligible', v_prep.itc_eligible_rupees,
    'net_payable', v_prep.net_tax_payable_rupees
  );

  INSERT INTO public.founder_gst_filings (
    quarter_label, period_start, period_end, gstr1_payload, gstr3b_payload, status,
    total_outward_taxable_rupees, total_igst_rupees, total_cgst_rupees, total_sgst_rupees
  ) VALUES (
    p_quarter_label, p_quarter_start, v_period_end, v_gstr1, v_gstr3b, 'draft',
    v_prep.total_outward_taxable_rupees, v_prep.total_igst_rupees, v_prep.total_cgst_rupees, v_prep.total_sgst_rupees
  )
  ON CONFLICT (quarter_label) DO UPDATE
  SET gstr1_payload = EXCLUDED.gstr1_payload,
      gstr3b_payload = EXCLUDED.gstr3b_payload,
      total_outward_taxable_rupees = EXCLUDED.total_outward_taxable_rupees,
      total_igst_rupees = EXCLUDED.total_igst_rupees,
      total_cgst_rupees = EXCLUDED.total_cgst_rupees,
      total_sgst_rupees = EXCLUDED.total_sgst_rupees,
      updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_gst_filing_draft(text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_gst_filing_draft(text, date) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_gst_filing_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_gst_filing_status(p_filing_id uuid, p_status text, p_arn text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_status NOT IN ('draft','reviewed','filed','rejected') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE = '22023';
  END IF;
  UPDATE public.founder_gst_filings
  SET status = p_status,
      arn = COALESCE(p_arn, arn),
      filed_at = CASE WHEN p_status = 'filed' THEN now() ELSE filed_at END,
      updated_at = now()
  WHERE id = p_filing_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_gst_filing_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_gst_filing_status(uuid, text, text) TO authenticated;

COMMIT;