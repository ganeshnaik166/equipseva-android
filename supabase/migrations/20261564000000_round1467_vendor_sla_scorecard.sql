BEGIN;

-- =====================================================================
-- r1467 — Vendor SLA Scorecard
-- Track vendor delivery/quality/payment SLAs; auto-grade A/B/C/D quarterly
-- Bottom-5 replacement queue with founder approval gate
-- =====================================================================

-- ---------- TABLE 1: vendor_sla_scorecards_v2 ----------
CREATE TABLE IF NOT EXISTS public.vendor_sla_scorecards_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,  -- e.g. '2026-Q2'
  quarter_start date NOT NULL,
  quarter_end date NOT NULL,
  total_orders int NOT NULL DEFAULT 0,
  delivered_on_time int NOT NULL DEFAULT 0,
  delivered_late int NOT NULL DEFAULT 0,
  rejected_quality int NOT NULL DEFAULT 0,
  payment_disputes int NOT NULL DEFAULT 0,
  total_value_rupees bigint NOT NULL DEFAULT 0,
  delivery_score numeric(5,2) NOT NULL DEFAULT 0,  -- 0..100
  quality_score numeric(5,2) NOT NULL DEFAULT 0,
  payment_score numeric(5,2) NOT NULL DEFAULT 0,
  overall_score numeric(5,2) NOT NULL DEFAULT 0,
  grade text NOT NULL DEFAULT 'C' CHECK (grade IN ('A','B','C','D')),
  notes text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(vendor_org_id, quarter_label)
);

CREATE INDEX IF NOT EXISTS idx_vssv2_quarter ON public.vendor_sla_scorecards_v2(quarter_label);
CREATE INDEX IF NOT EXISTS idx_vssv2_grade ON public.vendor_sla_scorecards_v2(grade);
CREATE INDEX IF NOT EXISTS idx_vssv2_vendor ON public.vendor_sla_scorecards_v2(vendor_org_id);
CREATE INDEX IF NOT EXISTS idx_vssv2_overall ON public.vendor_sla_scorecards_v2(overall_score);

ALTER TABLE public.vendor_sla_scorecards_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vssv2_founder_all ON public.vendor_sla_scorecards_v2;
CREATE POLICY vssv2_founder_all ON public.vendor_sla_scorecards_v2
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------- TABLE 2: vendor_replacement_queue_v2 ----------
CREATE TABLE IF NOT EXISTS public.vendor_replacement_queue_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  reason text NOT NULL,
  bottom_rank int NOT NULL,  -- 1..5
  proposed_replacement_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','executed')),
  founder_decision_at timestamptz,
  founder_decision_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(vendor_org_id, quarter_label)
);

CREATE INDEX IF NOT EXISTS idx_vrqv2_status ON public.vendor_replacement_queue_v2(status);
CREATE INDEX IF NOT EXISTS idx_vrqv2_quarter ON public.vendor_replacement_queue_v2(quarter_label);

ALTER TABLE public.vendor_replacement_queue_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vrqv2_founder_all ON public.vendor_replacement_queue_v2;
CREATE POLICY vrqv2_founder_all ON public.vendor_replacement_queue_v2
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- LOG HELPERS (4)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.log_founder_vendor_scorecard_recompute(p_quarter text, p_rows int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_audit_log(actor_user_id, action, payload, created_at)
  VALUES (auth.uid(), 'vendor_scorecard_recompute', jsonb_build_object('quarter', p_quarter, 'rows', p_rows), now());
EXCEPTION WHEN undefined_table THEN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_vendor_replacement_proposed(p_vendor uuid, p_quarter text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_audit_log(actor_user_id, action, payload, created_at)
  VALUES (auth.uid(), 'vendor_replacement_proposed', jsonb_build_object('vendor', p_vendor, 'quarter', p_quarter), now());
EXCEPTION WHEN undefined_table THEN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_vendor_replacement_decision(p_queue_id uuid, p_decision text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_audit_log(actor_user_id, action, payload, created_at)
  VALUES (auth.uid(), 'vendor_replacement_decision', jsonb_build_object('queue_id', p_queue_id, 'decision', p_decision), now());
EXCEPTION WHEN undefined_table THEN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_vendor_grade_override(p_scorecard_id uuid, p_old text, p_new text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_audit_log(actor_user_id, action, payload, created_at)
  VALUES (auth.uid(), 'vendor_grade_override', jsonb_build_object('scorecard_id', p_scorecard_id, 'old', p_old, 'new', p_new), now());
EXCEPTION WHEN undefined_table THEN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_founder_vendor_scorecard_recompute(text,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_vendor_replacement_proposed(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_vendor_replacement_decision(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_vendor_grade_override(uuid,text,text) TO authenticated;

-- =====================================================================
-- 7 SECDEF RPCs
-- =====================================================================

-- 1. KPI summary
CREATE OR REPLACE FUNCTION public.founder_vendor_sla_kpis()
RETURNS TABLE(
  total_vendors int,
  scored_vendors int,
  grade_a int,
  grade_b int,
  grade_c int,
  grade_d int,
  avg_overall numeric,
  avg_delivery numeric,
  avg_quality numeric,
  avg_payment numeric,
  bottom5_count int,
  pending_replacements int,
  approved_replacements int,
  executed_replacements int,
  total_value_rupees bigint,
  current_quarter text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_q := to_char(now(), 'YYYY') || '-Q' || extract(quarter FROM now())::text;
  RETURN QUERY
  WITH cur AS (
    SELECT * FROM vendor_sla_scorecards_v2 WHERE quarter_label = v_q
  )
  SELECT
    (SELECT count(*)::int FROM organizations WHERE kind = 'vendor'),
    (SELECT count(*)::int FROM cur),
    (SELECT count(*)::int FROM cur WHERE grade = 'A'),
    (SELECT count(*)::int FROM cur WHERE grade = 'B'),
    (SELECT count(*)::int FROM cur WHERE grade = 'C'),
    (SELECT count(*)::int FROM cur WHERE grade = 'D'),
    COALESCE((SELECT round(avg(overall_score),2) FROM cur),0),
    COALESCE((SELECT round(avg(delivery_score),2) FROM cur),0),
    COALESCE((SELECT round(avg(quality_score),2) FROM cur),0),
    COALESCE((SELECT round(avg(payment_score),2) FROM cur),0),
    LEAST(5, (SELECT count(*)::int FROM cur))::int,
    (SELECT count(*)::int FROM vendor_replacement_queue_v2 WHERE status = 'pending'),
    (SELECT count(*)::int FROM vendor_replacement_queue_v2 WHERE status = 'approved'),
    (SELECT count(*)::int FROM vendor_replacement_queue_v2 WHERE status = 'executed'),
    COALESCE((SELECT sum(total_value_rupees) FROM cur),0)::bigint,
    v_q;
END;
$$;

-- 2. Scorecard list with vendor name
CREATE OR REPLACE FUNCTION public.founder_vendor_sla_scorecards(p_quarter text DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  vendor_org_id uuid,
  vendor_name text,
  quarter_label text,
  total_orders int,
  delivered_on_time int,
  delivered_late int,
  rejected_quality int,
  payment_disputes int,
  delivery_score numeric,
  quality_score numeric,
  payment_score numeric,
  overall_score numeric,
  grade text,
  total_value_rupees bigint,
  computed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_q := COALESCE(p_quarter, to_char(now(), 'YYYY') || '-Q' || extract(quarter FROM now())::text);
  RETURN QUERY
  SELECT s.id, s.vendor_org_id, o.name, s.quarter_label,
         s.total_orders, s.delivered_on_time, s.delivered_late,
         s.rejected_quality, s.payment_disputes,
         s.delivery_score, s.quality_score, s.payment_score, s.overall_score,
         s.grade, s.total_value_rupees, s.computed_at
  FROM vendor_sla_scorecards_v2 s
  JOIN organizations o ON o.id = s.vendor_org_id
  WHERE s.quarter_label = v_q
  ORDER BY s.overall_score DESC NULLS LAST;
END;
$$;

-- 3. Bottom-5 list
CREATE OR REPLACE FUNCTION public.founder_vendor_sla_bottom5(p_quarter text DEFAULT NULL)
RETURNS TABLE(
  rank int,
  vendor_org_id uuid,
  vendor_name text,
  overall_score numeric,
  grade text,
  delivery_score numeric,
  quality_score numeric,
  payment_score numeric,
  total_value_rupees bigint,
  already_queued boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_q := COALESCE(p_quarter, to_char(now(), 'YYYY') || '-Q' || extract(quarter FROM now())::text);
  RETURN QUERY
  WITH ranked AS (
    SELECT s.*, o.name AS vname,
           row_number() OVER (ORDER BY s.overall_score ASC) AS rnk
    FROM vendor_sla_scorecards_v2 s
    JOIN organizations o ON o.id = s.vendor_org_id
    WHERE s.quarter_label = v_q
  )
  SELECT r.rnk::int, r.vendor_org_id, r.vname, r.overall_score, r.grade,
         r.delivery_score, r.quality_score, r.payment_score, r.total_value_rupees,
         EXISTS(SELECT 1 FROM vendor_replacement_queue_v2 q
                WHERE q.vendor_org_id = r.vendor_org_id AND q.quarter_label = v_q)
  FROM ranked r
  WHERE r.rnk <= 5
  ORDER BY r.rnk;
END;
$$;

-- 4. Replacement queue
CREATE OR REPLACE FUNCTION public.founder_vendor_replacement_queue()
RETURNS TABLE(
  id uuid,
  vendor_org_id uuid,
  vendor_name text,
  quarter_label text,
  reason text,
  bottom_rank int,
  proposed_replacement_org_id uuid,
  proposed_replacement_name text,
  status text,
  founder_decision_at timestamptz,
  founder_decision_note text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.vendor_org_id, o1.name, q.quarter_label, q.reason, q.bottom_rank,
         q.proposed_replacement_org_id, o2.name,
         q.status, q.founder_decision_at, q.founder_decision_note, q.created_at
  FROM vendor_replacement_queue_v2 q
  JOIN organizations o1 ON o1.id = q.vendor_org_id
  LEFT JOIN organizations o2 ON o2.id = q.proposed_replacement_org_id
  ORDER BY q.created_at DESC
  LIMIT 200;
END;
$$;

-- 5. Grade distribution by quarter (last 6 quarters trend)
CREATE OR REPLACE FUNCTION public.founder_vendor_grade_trend()
RETURNS TABLE(
  quarter_label text,
  grade_a int,
  grade_b int,
  grade_c int,
  grade_d int,
  avg_score numeric,
  vendor_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label,
         count(*) FILTER (WHERE s.grade='A')::int,
         count(*) FILTER (WHERE s.grade='B')::int,
         count(*) FILTER (WHERE s.grade='C')::int,
         count(*) FILTER (WHERE s.grade='D')::int,
         round(avg(s.overall_score),2),
         count(*)::int
  FROM vendor_sla_scorecards_v2 s
  GROUP BY s.quarter_label
  ORDER BY s.quarter_label DESC
  LIMIT 6;
END;
$$;

-- 6. Top performers (grade A)
CREATE OR REPLACE FUNCTION public.founder_vendor_sla_top_performers(p_quarter text DEFAULT NULL)
RETURNS TABLE(
  vendor_org_id uuid,
  vendor_name text,
  overall_score numeric,
  grade text,
  total_orders int,
  total_value_rupees bigint,
  delivery_score numeric,
  quality_score numeric,
  payment_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_q := COALESCE(p_quarter, to_char(now(), 'YYYY') || '-Q' || extract(quarter FROM now())::text);
  RETURN QUERY
  SELECT s.vendor_org_id, o.name, s.overall_score, s.grade,
         s.total_orders, s.total_value_rupees,
         s.delivery_score, s.quality_score, s.payment_score
  FROM vendor_sla_scorecards_v2 s
  JOIN organizations o ON o.id = s.vendor_org_id
  WHERE s.quarter_label = v_q AND s.grade IN ('A','B')
  ORDER BY s.overall_score DESC
  LIMIT 20;
END;
$$;

-- 7. Score breakdown (per-dimension drill)
CREATE OR REPLACE FUNCTION public.founder_vendor_sla_breakdown(p_quarter text DEFAULT NULL)
RETURNS TABLE(
  vendor_org_id uuid,
  vendor_name text,
  total_orders int,
  on_time_pct numeric,
  late_pct numeric,
  quality_reject_pct numeric,
  dispute_pct numeric,
  grade text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_q text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_q := COALESCE(p_quarter, to_char(now(), 'YYYY') || '-Q' || extract(quarter FROM now())::text);
  RETURN QUERY
  SELECT s.vendor_org_id, o.name, s.total_orders,
         CASE WHEN s.total_orders > 0 THEN round(100.0 * s.delivered_on_time / s.total_orders, 2) ELSE 0 END,
         CASE WHEN s.total_orders > 0 THEN round(100.0 * s.delivered_late / s.total_orders, 2) ELSE 0 END,
         CASE WHEN s.total_orders > 0 THEN round(100.0 * s.rejected_quality / s.total_orders, 2) ELSE 0 END,
         CASE WHEN s.total_orders > 0 THEN round(100.0 * s.payment_disputes / s.total_orders, 2) ELSE 0 END,
         s.grade
  FROM vendor_sla_scorecards_v2 s
  JOIN organizations o ON o.id = s.vendor_org_id
  WHERE s.quarter_label = v_q
  ORDER BY s.overall_score ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_vendor_sla_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_sla_scorecards(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_sla_bottom5(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_replacement_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_grade_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_sla_top_performers(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vendor_sla_breakdown(text) TO authenticated;

COMMIT;