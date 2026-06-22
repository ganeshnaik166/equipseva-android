BEGIN;

-- =====================================================================
-- Round 2277: Founder Governance Docs Status
-- Board minutes, share resolutions, statutory filings, due-date tracker
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.governance_docs_r2277 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_code text NOT NULL UNIQUE,
  doc_title text NOT NULL,
  doc_category text NOT NULL CHECK (doc_category IN ('board_minutes','share_resolution','statutory_filing','policy','register','agreement','licence')),
  regulator text NOT NULL CHECK (regulator IN ('mca','income_tax','gst','rbi','sebi','internal','dpdp','labour')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  owner_role text NOT NULL CHECK (owner_role IN ('founder','cs','ca','legal_counsel','cfo','coo')),
  frequency text NOT NULL CHECK (frequency IN ('one_time','monthly','quarterly','half_yearly','annually','event_driven')),
  next_due_on date,
  last_filed_on date,
  current_status text NOT NULL CHECK (current_status IN ('not_started','drafting','review','signed','filed','overdue','waived')),
  penalty_if_overdue_rupees integer DEFAULT 0 CHECK (penalty_if_overdue_rupees >= 0),
  storage_url text,
  notes text,
  is_critical boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gov_docs_r2277_due ON public.governance_docs_r2277 (next_due_on) WHERE current_status NOT IN ('filed','waived');
CREATE INDEX IF NOT EXISTS idx_gov_docs_r2277_status ON public.governance_docs_r2277 (current_status);
CREATE INDEX IF NOT EXISTS idx_gov_docs_r2277_owner ON public.governance_docs_r2277 (owner_user_id);

ALTER TABLE public.governance_docs_r2277 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gov_docs_r2277_founder_all ON public.governance_docs_r2277;
CREATE POLICY gov_docs_r2277_founder_all ON public.governance_docs_r2277
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Doc events history
CREATE TABLE IF NOT EXISTS public.governance_doc_events_r2277 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_id uuid NOT NULL REFERENCES public.governance_docs_r2277(id) ON DELETE CASCADE,
  event_kind text NOT NULL CHECK (event_kind IN ('status_change','reminder_sent','filed','reassigned','escalated','penalty_paid','note_added')),
  from_status text,
  to_status text,
  actor_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_email text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gov_events_r2277_doc ON public.governance_doc_events_r2277 (doc_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gov_events_r2277_kind ON public.governance_doc_events_r2277 (event_kind);

ALTER TABLE public.governance_doc_events_r2277 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gov_events_r2277_founder_all ON public.governance_doc_events_r2277;
CREATE POLICY gov_events_r2277_founder_all ON public.governance_doc_events_r2277
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============== SEED ==============
DO $seed$
DECLARE
  v_founder_id uuid;
  v_cs_id uuid;
  v_ca_id uuid;
  v_doc_id uuid;
BEGIN
  SELECT id INTO v_founder_id FROM public.profiles WHERE role = 'engineer' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_cs_id FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_ca_id FROM public.profiles WHERE role = 'supplier' ORDER BY created_at LIMIT 1;

  INSERT INTO public.governance_docs_r2277
    (doc_code, doc_title, doc_category, regulator, owner_user_id, owner_role, frequency, next_due_on, last_filed_on, current_status, penalty_if_overdue_rupees, is_critical, notes)
  VALUES
    ('AOC4_FY26','AOC-4 Annual Financial Statements','statutory_filing','mca', v_ca_id, 'ca','annually','2026-10-30','2025-10-28','drafting',10000, true,'Filed within 30 days of AGM'),
    ('MGT7_FY26','MGT-7 Annual Return','statutory_filing','mca', v_cs_id, 'cs','annually','2026-11-29','2025-11-27','not_started',10000, true,'Filed within 60 days of AGM'),
    ('DIR3_KYC','DIR-3 KYC for Directors','statutory_filing','mca', v_cs_id, 'cs','annually','2026-09-30',NULL,'not_started',5000, true,'Per director'),
    ('GSTR3B_JUN26','GSTR-3B June 2026','statutory_filing','gst', v_ca_id, 'ca','monthly','2026-07-20','2026-06-18','signed',500, true,'Monthly summary return'),
    ('GSTR1_JUN26','GSTR-1 June 2026','statutory_filing','gst', v_ca_id, 'ca','monthly','2026-07-11','2026-06-10','review',500, false,'Outward supplies'),
    ('TDS_Q1_FY27','TDS 26Q Q1 FY27','statutory_filing','income_tax', v_ca_id, 'ca','quarterly','2026-07-31',NULL,'drafting',10000, true,'Quarterly TDS return'),
    ('ITR6_FY26','ITR-6 Corporate Income Tax','statutory_filing','income_tax', v_ca_id, 'ca','annually','2026-10-31','2025-10-29','not_started',10000, true,'With tax audit'),
    ('BOARD_JUN26','Board Meeting Minutes June 2026','board_minutes','internal', v_cs_id, 'cs','quarterly','2026-06-30',NULL,'review',0, false,'Q1 FY27 board meeting'),
    ('BOARD_MAR26','Board Meeting Minutes March 2026','board_minutes','internal', v_cs_id, 'cs','quarterly','2026-03-31','2026-03-28','filed',0, false,NULL),
    ('SH7_FY26','SH-7 Share Allotment Resolution','share_resolution','mca', v_cs_id, 'cs','event_driven','2026-07-15',NULL,'drafting',1000, true,'Series A allotment'),
    ('PAS3_FY26','PAS-3 Return of Allotment','share_resolution','mca', v_cs_id, 'cs','event_driven','2026-08-14',NULL,'not_started',1000, true,'Within 30 days of allotment'),
    ('CSR2_FY26','CSR-2 Report','statutory_filing','mca', v_ca_id, 'ca','annually','2026-12-31',NULL,'not_started',5000, false,'If applicable'),
    ('DPDP_POLICY','DPDP Privacy Policy v2','policy','dpdp', v_cs_id, 'legal_counsel','annually','2026-08-01','2025-07-30','overdue',0, true,'DPDP Act compliance'),
    ('IT_ACT_POLICY','IT Act Reasonable Security Practices','policy','dpdp', v_cs_id, 'legal_counsel','annually','2026-09-15',NULL,'drafting',0, false,NULL),
    ('CASHFREE_AGREEMENT','Cashfree Payment Aggregator Agreement','agreement','rbi', v_founder_id, 'founder','one_time',NULL,'2026-06-10','filed',0, true,'Signed and active'),
    ('UDYAM_CERT','Udyam MSME Registration','licence','mca', v_founder_id, 'founder','one_time',NULL,'2026-06-10','filed',0, true,'UDYAM-TS-07-0099805'),
    ('MEMBER_REG','Register of Members','register','mca', v_cs_id, 'cs','annually','2026-09-30','2025-09-29','signed',0, true,'Annual update'),
    ('CHARGE_REG','Register of Charges','register','mca', v_cs_id, 'cs','annually','2026-09-30','2025-09-29','signed',0, false,NULL),
    ('SHOP_ESTAB','Shops & Establishment Renewal','licence','labour', v_ca_id, 'ca','annually','2026-12-31','2025-12-28','not_started',2000, false,'Telangana renewal'),
    ('PF_ECR_JUN26','PF ECR June 2026','statutory_filing','labour', v_ca_id, 'ca','monthly','2026-07-15','2026-06-15','filed',1000, true,'PF monthly return');

  -- Sample events
  SELECT id INTO v_doc_id FROM public.governance_docs_r2277 WHERE doc_code = 'GSTR3B_JUN26';
  INSERT INTO public.governance_doc_events_r2277 (doc_id, event_kind, from_status, to_status, actor_user_id, actor_email, note)
  VALUES
    (v_doc_id, 'status_change', 'drafting', 'review', v_ca_id, 'ca@equipseva.com', 'Review by CA'),
    (v_doc_id, 'status_change', 'review', 'signed', v_founder_id, 'founder@equipseva.com', 'Signed by founder');

  SELECT id INTO v_doc_id FROM public.governance_docs_r2277 WHERE doc_code = 'DPDP_POLICY';
  INSERT INTO public.governance_doc_events_r2277 (doc_id, event_kind, actor_user_id, actor_email, note)
  VALUES
    (v_doc_id, 'reminder_sent', v_cs_id, 'cs@equipseva.com', '14 days before due'),
    (v_doc_id, 'escalated', v_cs_id, 'cs@equipseva.com', 'Past due - escalated to founder');
END;
$seed$;

-- ============== RPCs (7) ==============

-- 1) Summary
CREATE OR REPLACE FUNCTION public.gov_docs_r2277_summary()
RETURNS TABLE (
  total_docs int,
  overdue int,
  due_in_7d int,
  due_in_30d int,
  filed int,
  drafting int,
  review int,
  critical_pending int,
  total_penalty_exposure_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_docs,
    (COUNT(*) FILTER (WHERE current_status = 'overdue' OR (next_due_on IS NOT NULL AND next_due_on < CURRENT_DATE AND current_status NOT IN ('filed','waived'))))::int AS overdue,
    (COUNT(*) FILTER (WHERE next_due_on BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days' AND current_status NOT IN ('filed','waived')))::int AS due_in_7d,
    (COUNT(*) FILTER (WHERE next_due_on BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days' AND current_status NOT IN ('filed','waived')))::int AS due_in_30d,
    (COUNT(*) FILTER (WHERE current_status = 'filed'))::int AS filed,
    (COUNT(*) FILTER (WHERE current_status = 'drafting'))::int AS drafting,
    (COUNT(*) FILTER (WHERE current_status = 'review'))::int AS review,
    (COUNT(*) FILTER (WHERE is_critical = true AND current_status NOT IN ('filed','waived')))::int AS critical_pending,
    (COALESCE(SUM(penalty_if_overdue_rupees) FILTER (WHERE next_due_on IS NOT NULL AND next_due_on < CURRENT_DATE AND current_status NOT IN ('filed','waived')), 0))::bigint AS total_penalty_exposure_rupees
  FROM public.governance_docs_r2277;
END;
$$;

-- 2) List with computed days_until_due
CREATE OR REPLACE FUNCTION public.gov_docs_r2277_list()
RETURNS TABLE (
  doc_code text,
  doc_title text,
  doc_category text,
  regulator text,
  owner_role text,
  owner_email text,
  frequency text,
  next_due_on date,
  days_until_due int,
  last_filed_on date,
  current_status text,
  penalty_if_overdue_rupees integer,
  is_critical boolean,
  is_overdue boolean
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.doc_code,
    d.doc_title,
    d.doc_category,
    d.regulator,
    d.owner_role,
    p.email AS owner_email,
    d.frequency,
    d.next_due_on,
    CASE WHEN d.next_due_on IS NULL THEN NULL ELSE (d.next_due_on - CURRENT_DATE)::int END AS days_until_due,
    d.last_filed_on,
    d.current_status,
    d.penalty_if_overdue_rupees,
    d.is_critical,
    (d.next_due_on IS NOT NULL AND d.next_due_on < CURRENT_DATE AND d.current_status NOT IN ('filed','waived')) AS is_overdue
  FROM public.governance_docs_r2277 d
  LEFT JOIN public.profiles p ON p.id = d.owner_user_id
  ORDER BY
    (d.next_due_on IS NOT NULL AND d.next_due_on < CURRENT_DATE AND d.current_status NOT IN ('filed','waived')) DESC,
    d.is_critical DESC,
    d.next_due_on NULLS LAST;
END;
$$;

-- 3) By regulator
CREATE OR REPLACE FUNCTION public.gov_docs_r2277_by_regulator()
RETURNS TABLE (
  regulator text,
  total int,
  filed int,
  pending int,
  overdue int,
  next_due_on date
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.regulator,
    (COUNT(*))::int AS total,
    (COUNT(*) FILTER (WHERE d.current_status = 'filed'))::int AS filed,
    (COUNT(*) FILTER (WHERE d.current_status NOT IN ('filed','waived')))::int AS pending,
    (COUNT(*) FILTER (WHERE d.next_due_on IS NOT NULL AND d.next_due_on < CURRENT_DATE AND d.current_status NOT IN ('filed','waived')))::int AS overdue,
    MIN(d.next_due_on) FILTER (WHERE d.current_status NOT IN ('filed','waived')) AS next_due_on
  FROM public.governance_docs_r2277 d
  GROUP BY d.regulator
  ORDER BY overdue DESC, pending DESC;
END;
$$;

-- 4) By owner
CREATE OR REPLACE FUNCTION public.gov_docs_r2277_by_owner()
RETURNS TABLE (
  owner_role text,
  owner_email text,
  total int,
  pending int,
  overdue int,
  critical_pending int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.owner_role,
    p.email AS owner_email,
    (COUNT(*))::int AS total,
    (COUNT(*) FILTER (WHERE d.current_status NOT IN ('filed','waived')))::int AS pending,
    (COUNT(*) FILTER (WHERE d.next_due_on IS NOT NULL AND d.next_due_on < CURRENT_DATE AND d.current_status NOT IN ('filed','waived')))::int AS overdue,
    (COUNT(*) FILTER (WHERE d.is_critical AND d.current_status NOT IN ('filed','waived')))::int AS critical_pending
  FROM public.governance_docs_r2277 d
  LEFT JOIN public.profiles p ON p.id = d.owner_user_id
  GROUP BY d.owner_role, p.email
  ORDER BY overdue DESC, critical_pending DESC;
END;
$$;

-- 5) Upcoming 30 days timeline
CREATE OR REPLACE FUNCTION public.gov_docs_r2277_upcoming_30d()
RETURNS TABLE (
  doc_code text,
  doc_title text,
  regulator text,
  next_due_on date,
  days_until_due int,
  owner_role text,
  current_status text,
  penalty_if_overdue_rupees integer,
  is_critical boolean
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.doc_code,
    d.doc_title,
    d.regulator,
    d.next_due_on,
    (d.next_due_on - CURRENT_DATE)::int AS days_until_due,
    d.owner_role,
    d.current_status,
    d.penalty_if_overdue_rupees,
    d.is_critical
  FROM public.governance_docs_r2277 d
  WHERE d.next_due_on IS NOT NULL
    AND d.next_due_on <= CURRENT_DATE + INTERVAL '30 days'
    AND d.current_status NOT IN ('filed','waived')
  ORDER BY d.next_due_on;
END;
$$;

-- 6) Recent events feed
CREATE OR REPLACE FUNCTION public.gov_docs_r2277_recent_events(p_limit int DEFAULT 30)
RETURNS TABLE (
  created_at timestamptz,
  doc_code text,
  doc_title text,
  event_kind text,
  from_status text,
  to_status text,
  actor_email text,
  note text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.created_at,
    d.doc_code,
    d.doc_title,
    e.event_kind,
    e.from_status,
    e.to_status,
    COALESCE(e.actor_email, p.email) AS actor_email,
    e.note
  FROM public.governance_doc_events_r2277 e
  JOIN public.governance_docs_r2277 d ON d.id = e.doc_id
  LEFT JOIN public.profiles p ON p.id = e.actor_user_id
  ORDER BY e.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

-- 7) Status mix
CREATE OR REPLACE FUNCTION public.gov_docs_r2277_status_mix()
RETURNS TABLE (
  current_status text,
  doc_count int,
  pct_of_total numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.governance_docs_r2277;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT
    d.current_status,
    (COUNT(*))::int AS doc_count,
    ROUND((COUNT(*)::numeric / v_total) * 100, 1) AS pct_of_total
  FROM public.governance_docs_r2277 d
  GROUP BY d.current_status
  ORDER BY doc_count DESC;
END;
$$;

-- ============== GRANTS ==============
REVOKE ALL ON FUNCTION public.gov_docs_r2277_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gov_docs_r2277_list() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gov_docs_r2277_by_regulator() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gov_docs_r2277_by_owner() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gov_docs_r2277_upcoming_30d() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gov_docs_r2277_recent_events(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gov_docs_r2277_status_mix() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.gov_docs_r2277_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gov_docs_r2277_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gov_docs_r2277_by_regulator() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gov_docs_r2277_by_owner() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gov_docs_r2277_upcoming_30d() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gov_docs_r2277_recent_events(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gov_docs_r2277_status_mix() TO authenticated;

COMMIT;
