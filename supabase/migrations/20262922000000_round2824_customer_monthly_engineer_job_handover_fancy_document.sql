BEGIN;

-- =========================================================================
-- Round 2824 — Customer Monthly Engineer Job Handover Fancy Document
-- HEAVY ★★★★ — fancy handover documents bundled per customer per month
-- =========================================================================

-- ---------- Table 1: handover documents ----------
DROP TABLE IF EXISTS public.customer_monthly_handover_documents_r2824 CASCADE;
CREATE TABLE public.customer_monthly_handover_documents_r2824 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_code   text NOT NULL UNIQUE,
  customer_name   text NOT NULL,
  hospital_tier   text NOT NULL CHECK (hospital_tier IN ('tier1','tier2','tier3','tier4','tier5')),
  cycle_month     date NOT NULL,
  engineer_name   text NOT NULL,
  jobs_completed  int  NOT NULL CHECK (jobs_completed >= 0),
  fancy_score     numeric(5,2) NOT NULL CHECK (fancy_score >= 0 AND fancy_score <= 100),
  content_sections jsonb NOT NULL DEFAULT '[]'::jsonb,
  design_template text NOT NULL CHECK (design_template IN ('classic','glossy','executive','playful','minimal')),
  customer_impact text NOT NULL CHECK (customer_impact IN ('low','medium','high','flagship')),
  verdict         text NOT NULL CHECK (verdict IN ('approved','revisions','escalate','rejected','pending')),
  amount_rupees   bigint NOT NULL CHECK (amount_rupees >= 0),
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_monthly_handover_documents_r2824 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_monthly_handover_documents_r2824;
CREATE POLICY founder_all ON public.customer_monthly_handover_documents_r2824
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.customer_monthly_handover_documents_r2824
  (document_code, customer_name, hospital_tier, cycle_month, engineer_name, jobs_completed, fancy_score, content_sections, design_template, customer_impact, verdict, amount_rupees)
VALUES
  ('HD-2824-01','Apollo Jubilee Hills','tier1','2026-05-01'::date,'Ravi Kumar',18,92.50,'[{"section":"summary"},{"section":"jobs"},{"section":"photos"},{"section":"compliance"}]'::jsonb,'executive','flagship','approved',285000),
  ('HD-2824-02','KIMS Secunderabad','tier1','2026-05-01'::date,'Priya Nair',14,88.25,'[{"section":"summary"},{"section":"jobs"},{"section":"parts"}]'::jsonb,'glossy','high','approved',196000),
  ('HD-2824-03','Yashoda Somajiguda','tier2','2026-05-01'::date,'Arjun Reddy',11,74.10,'[{"section":"summary"},{"section":"jobs"},{"section":"sla-breach-note"}]'::jsonb,'classic','medium','revisions',128500),
  ('HD-2824-04','Care Banjara','tier2','2026-04-01'::date,'Meera Joshi',9,67.80,'[{"section":"summary"},{"section":"jobs"}]'::jsonb,'minimal','medium','approved',98750),
  ('HD-2824-05','Sunshine Begumpet','tier3','2026-04-01'::date,'Vinod Sharma',6,55.40,'[{"section":"summary"},{"section":"complaints"}]'::jsonb,'playful','low','escalate',64200),
  ('HD-2824-06','Continental Gachibowli','tier1','2026-05-01'::date,'Suresh Iyer',16,90.75,'[{"section":"summary"},{"section":"jobs"},{"section":"photos"},{"section":"feedback"}]'::jsonb,'executive','flagship','approved',242000);

-- ---------- Table 2: handover content blocks ----------
DROP TABLE IF EXISTS public.handover_content_blocks_r2824 CASCADE;
CREATE TABLE public.handover_content_blocks_r2824 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_code   text NOT NULL REFERENCES public.customer_monthly_handover_documents_r2824(document_code) ON DELETE CASCADE,
  block_name      text NOT NULL,
  block_type      text NOT NULL CHECK (block_type IN ('cover','summary','job_table','photo_grid','compliance','feedback','signature')),
  word_count      int  NOT NULL CHECK (word_count >= 0),
  design_score    numeric(5,2) NOT NULL CHECK (design_score >= 0 AND design_score <= 100),
  impact_rating   text NOT NULL CHECK (impact_rating IN ('low','medium','high','flagship')),
  verdict         text NOT NULL CHECK (verdict IN ('approved','revisions','escalate','rejected','pending')),
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.handover_content_blocks_r2824 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.handover_content_blocks_r2824;
CREATE POLICY founder_all ON public.handover_content_blocks_r2824
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.handover_content_blocks_r2824
  (document_code, block_name, block_type, word_count, design_score, impact_rating, verdict)
VALUES
  ('HD-2824-01','Cover Page','cover',45,95.00,'flagship','approved'),
  ('HD-2824-01','Executive Summary','summary',320,93.50,'flagship','approved'),
  ('HD-2824-02','Job Ledger','job_table',180,89.00,'high','approved'),
  ('HD-2824-03','SLA Breach Note','summary',210,72.50,'medium','revisions'),
  ('HD-2824-04','Photo Grid','photo_grid',60,80.00,'medium','approved'),
  ('HD-2824-05','Complaint Log','feedback',410,58.20,'low','escalate'),
  ('HD-2824-06','Signature Block','signature',25,91.00,'flagship','approved');

-- =========================================================================
-- RPC 1: KPI summary
-- =========================================================================
DROP FUNCTION IF EXISTS public.handover_doc_kpis_r2824();
CREATE OR REPLACE FUNCTION public.handover_doc_kpis_r2824()
RETURNS TABLE (
  total_docs      int,
  approved_docs   int,
  pending_docs    int,
  flagship_docs   int,
  total_amount    bigint,
  avg_fancy       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE verdict='approved')::int,
    COUNT(*) FILTER (WHERE verdict='pending')::int,
    COUNT(*) FILTER (WHERE customer_impact='flagship')::int,
    COALESCE(SUM(amount_rupees),0)::bigint,
    COALESCE(ROUND(AVG(fancy_score),2),0)
  FROM public.customer_monthly_handover_documents_r2824;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handover_doc_kpis_r2824() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_doc_kpis_r2824() TO authenticated;

-- =========================================================================
-- RPC 2: list documents
-- =========================================================================
DROP FUNCTION IF EXISTS public.handover_docs_list_r2824();
CREATE OR REPLACE FUNCTION public.handover_docs_list_r2824()
RETURNS TABLE (
  document_code text,
  customer_name text,
  hospital_tier text,
  cycle_month   date,
  engineer_name text,
  jobs_completed int,
  fancy_score    numeric,
  design_template text,
  customer_impact text,
  verdict        text,
  amount_rupees  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.document_code, d.customer_name, d.hospital_tier, d.cycle_month, d.engineer_name,
         d.jobs_completed, d.fancy_score, d.design_template, d.customer_impact, d.verdict, d.amount_rupees
  FROM public.customer_monthly_handover_documents_r2824 d
  ORDER BY d.cycle_month DESC, d.fancy_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handover_docs_list_r2824() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_docs_list_r2824() TO authenticated;

-- =========================================================================
-- RPC 3: by tier
-- =========================================================================
DROP FUNCTION IF EXISTS public.handover_by_tier_r2824();
CREATE OR REPLACE FUNCTION public.handover_by_tier_r2824()
RETURNS TABLE (
  hospital_tier text,
  doc_count     int,
  avg_fancy     numeric,
  total_amount  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.hospital_tier, COUNT(*)::int, COALESCE(ROUND(AVG(d.fancy_score),2),0), COALESCE(SUM(d.amount_rupees),0)::bigint
  FROM public.customer_monthly_handover_documents_r2824 d
  GROUP BY d.hospital_tier
  ORDER BY d.hospital_tier;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handover_by_tier_r2824() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_by_tier_r2824() TO authenticated;

-- =========================================================================
-- RPC 4: by template
-- =========================================================================
DROP FUNCTION IF EXISTS public.handover_by_template_r2824();
CREATE OR REPLACE FUNCTION public.handover_by_template_r2824()
RETURNS TABLE (
  design_template text,
  doc_count       int,
  avg_fancy       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.design_template, COUNT(*)::int, COALESCE(ROUND(AVG(d.fancy_score),2),0)
  FROM public.customer_monthly_handover_documents_r2824 d
  GROUP BY d.design_template
  ORDER BY d.design_template;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handover_by_template_r2824() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_by_template_r2824() TO authenticated;

-- =========================================================================
-- RPC 5: content blocks list
-- =========================================================================
DROP FUNCTION IF EXISTS public.handover_blocks_list_r2824();
CREATE OR REPLACE FUNCTION public.handover_blocks_list_r2824()
RETURNS TABLE (
  document_code text,
  block_name    text,
  block_type    text,
  word_count    int,
  design_score  numeric,
  impact_rating text,
  verdict       text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.document_code, b.block_name, b.block_type, b.word_count, b.design_score, b.impact_rating, b.verdict
  FROM public.handover_content_blocks_r2824 b
  ORDER BY b.document_code, b.design_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handover_blocks_list_r2824() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_blocks_list_r2824() TO authenticated;

-- =========================================================================
-- RPC 6: verdict mix
-- =========================================================================
DROP FUNCTION IF EXISTS public.handover_verdict_mix_r2824();
CREATE OR REPLACE FUNCTION public.handover_verdict_mix_r2824()
RETURNS TABLE (
  verdict   text,
  doc_count int,
  pct       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.customer_monthly_handover_documents_r2824;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT d.verdict, COUNT(*)::int, ROUND((COUNT(*)::numeric / v_total) * 100, 2)
  FROM public.customer_monthly_handover_documents_r2824 d
  GROUP BY d.verdict
  ORDER BY d.verdict;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handover_verdict_mix_r2824() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_verdict_mix_r2824() TO authenticated;

-- =========================================================================
-- RPC 7: top engineers by fancy score
-- =========================================================================
DROP FUNCTION IF EXISTS public.handover_top_engineers_r2824();
CREATE OR REPLACE FUNCTION public.handover_top_engineers_r2824()
RETURNS TABLE (
  engineer_name text,
  docs_count    int,
  avg_fancy     numeric,
  total_jobs    int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.engineer_name, COUNT(*)::int, COALESCE(ROUND(AVG(d.fancy_score),2),0), COALESCE(SUM(d.jobs_completed),0)::int
  FROM public.customer_monthly_handover_documents_r2824 d
  GROUP BY d.engineer_name
  ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handover_top_engineers_r2824() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_top_engineers_r2824() TO authenticated;

-- =========================================================================
-- RPC 8: impact distribution
-- =========================================================================
DROP FUNCTION IF EXISTS public.handover_impact_dist_r2824();
CREATE OR REPLACE FUNCTION public.handover_impact_dist_r2824()
RETURNS TABLE (
  customer_impact text,
  doc_count       int,
  total_amount    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.customer_impact, COUNT(*)::int, COALESCE(SUM(d.amount_rupees),0)::bigint
  FROM public.customer_monthly_handover_documents_r2824 d
  GROUP BY d.customer_impact
  ORDER BY d.customer_impact;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handover_impact_dist_r2824() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_impact_dist_r2824() TO authenticated;

COMMIT;
