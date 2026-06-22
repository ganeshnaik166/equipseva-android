BEGIN;

-- ============================================================================
-- r2287: Hospital chain compliance checklist tracker
-- For each hospital chain, track Equipseva's compliance status against
-- their vendor terms (NABH, ISO 9001/13485, HIPAA-equivalent DPDP, etc.)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_chain_compliance_checklists_r2287 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_code text NOT NULL UNIQUE,
  total_hospitals int NOT NULL DEFAULT 0 CHECK (total_hospitals >= 0),
  annual_contract_value_rupees bigint NOT NULL DEFAULT 0 CHECK (annual_contract_value_rupees >= 0),
  vendor_tier text NOT NULL DEFAULT 'tier_2' CHECK (vendor_tier IN ('preferred','tier_1','tier_2','probation')),
  primary_contact_email text,
  vendor_terms_url text,
  compliance_review_cadence_months int NOT NULL DEFAULT 12 CHECK (compliance_review_cadence_months > 0),
  last_review_at timestamptz,
  next_review_due_at timestamptz,
  overall_status text NOT NULL DEFAULT 'in_progress' CHECK (overall_status IN ('compliant','in_progress','at_risk','non_compliant','suspended')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_hcc_checklists_r2287_status
  ON public.hospital_chain_compliance_checklists_r2287(overall_status, next_review_due_at);
CREATE INDEX IF NOT EXISTS idx_hcc_checklists_r2287_tier
  ON public.hospital_chain_compliance_checklists_r2287(vendor_tier, annual_contract_value_rupees DESC);

CREATE TABLE IF NOT EXISTS public.hospital_chain_compliance_items_r2287 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  checklist_id uuid NOT NULL REFERENCES public.hospital_chain_compliance_checklists_r2287(id) ON DELETE CASCADE,
  requirement_code text NOT NULL,
  requirement_label text NOT NULL,
  standard_family text NOT NULL CHECK (standard_family IN ('nabh','iso_9001','iso_13485','dpdp','hipaa_equivalent','cdsco','gst','msme','custom')),
  weight int NOT NULL DEFAULT 1 CHECK (weight BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('compliant','partial','non_compliant','pending','not_applicable','waived')),
  evidence_url text,
  evidence_summary text,
  blocker_reason text,
  remediation_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  remediation_due_at timestamptz,
  verified_at timestamptz,
  verified_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (checklist_id, requirement_code)
);

CREATE INDEX IF NOT EXISTS idx_hcc_items_r2287_checklist
  ON public.hospital_chain_compliance_items_r2287(checklist_id, status);
CREATE INDEX IF NOT EXISTS idx_hcc_items_r2287_due
  ON public.hospital_chain_compliance_items_r2287(remediation_due_at)
  WHERE status IN ('partial','non_compliant','pending');

ALTER TABLE public.hospital_chain_compliance_checklists_r2287 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_compliance_items_r2287 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_compliance_checklists_r2287;
CREATE POLICY founder_all ON public.hospital_chain_compliance_checklists_r2287
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_compliance_items_r2287;
CREATE POLICY founder_all ON public.hospital_chain_compliance_items_r2287
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list checklists with rollup stats
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2287_list_chain_checklists()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_code text,
  vendor_tier text,
  total_hospitals int,
  annual_contract_value_rupees bigint,
  overall_status text,
  last_review_at timestamptz,
  next_review_due_at timestamptz,
  items_total int,
  items_compliant int,
  items_blocker int,
  compliance_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.chain_code,
    c.vendor_tier,
    c.total_hospitals,
    c.annual_contract_value_rupees,
    c.overall_status,
    c.last_review_at,
    c.next_review_due_at,
    COALESCE((SELECT COUNT(*)::int FROM public.hospital_chain_compliance_items_r2287 i WHERE i.checklist_id = c.id), 0) AS items_total,
    COALESCE((SELECT COUNT(*)::int FROM public.hospital_chain_compliance_items_r2287 i WHERE i.checklist_id = c.id AND i.status = 'compliant'), 0) AS items_compliant,
    COALESCE((SELECT COUNT(*)::int FROM public.hospital_chain_compliance_items_r2287 i WHERE i.checklist_id = c.id AND i.status IN ('non_compliant','partial')), 0) AS items_blocker,
    CASE
      WHEN (SELECT COUNT(*) FROM public.hospital_chain_compliance_items_r2287 i WHERE i.checklist_id = c.id AND i.status <> 'not_applicable') = 0 THEN 0::numeric
      ELSE ROUND(
        (SELECT COUNT(*)::numeric FROM public.hospital_chain_compliance_items_r2287 i WHERE i.checklist_id = c.id AND i.status = 'compliant')
        * 100.0
        / NULLIF((SELECT COUNT(*) FROM public.hospital_chain_compliance_items_r2287 i WHERE i.checklist_id = c.id AND i.status <> 'not_applicable'), 0)
      , 1)
    END AS compliance_pct
  FROM public.hospital_chain_compliance_checklists_r2287 c
  ORDER BY c.annual_contract_value_rupees DESC, c.chain_name ASC;
END;
$$;

-- ============================================================================
-- RPC 2: list items for one checklist
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2287_list_checklist_items(p_checklist_id uuid)
RETURNS TABLE (
  id uuid,
  requirement_code text,
  requirement_label text,
  standard_family text,
  weight int,
  status text,
  evidence_url text,
  evidence_summary text,
  blocker_reason text,
  remediation_due_at timestamptz,
  verified_at timestamptz,
  remediation_owner_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.requirement_code,
    i.requirement_label,
    i.standard_family,
    i.weight,
    i.status,
    i.evidence_url,
    i.evidence_summary,
    i.blocker_reason,
    i.remediation_due_at,
    i.verified_at,
    p.email AS remediation_owner_email
  FROM public.hospital_chain_compliance_items_r2287 i
  LEFT JOIN public.profiles p ON p.id = i.remediation_owner_id
  WHERE i.checklist_id = p_checklist_id
  ORDER BY i.standard_family ASC, i.weight DESC, i.requirement_code ASC;
END;
$$;

-- ============================================================================
-- RPC 3: upsert a chain checklist
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2287_upsert_chain_checklist(
  p_chain_name text,
  p_chain_code text,
  p_total_hospitals int,
  p_annual_contract_value_rupees bigint,
  p_vendor_tier text,
  p_primary_contact_email text,
  p_vendor_terms_url text,
  p_review_cadence_months int,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_caller uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_caller FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;

  INSERT INTO public.hospital_chain_compliance_checklists_r2287 (
    chain_name, chain_code, total_hospitals, annual_contract_value_rupees,
    vendor_tier, primary_contact_email, vendor_terms_url,
    compliance_review_cadence_months, notes, created_by,
    next_review_due_at
  ) VALUES (
    p_chain_name, p_chain_code, COALESCE(p_total_hospitals, 0),
    COALESCE(p_annual_contract_value_rupees, 0),
    COALESCE(p_vendor_tier, 'tier_2'),
    p_primary_contact_email, p_vendor_terms_url,
    COALESCE(p_review_cadence_months, 12), p_notes, v_caller,
    now() + (COALESCE(p_review_cadence_months, 12) || ' months')::interval
  )
  ON CONFLICT (chain_code) DO UPDATE SET
    chain_name = EXCLUDED.chain_name,
    total_hospitals = EXCLUDED.total_hospitals,
    annual_contract_value_rupees = EXCLUDED.annual_contract_value_rupees,
    vendor_tier = EXCLUDED.vendor_tier,
    primary_contact_email = EXCLUDED.primary_contact_email,
    vendor_terms_url = EXCLUDED.vendor_terms_url,
    compliance_review_cadence_months = EXCLUDED.compliance_review_cadence_months,
    notes = EXCLUDED.notes,
    updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 4: add or update a checklist item
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2287_upsert_checklist_item(
  p_checklist_id uuid,
  p_requirement_code text,
  p_requirement_label text,
  p_standard_family text,
  p_weight int,
  p_status text,
  p_evidence_url text,
  p_evidence_summary text,
  p_blocker_reason text,
  p_remediation_due_at timestamptz
) RETURNS uuid
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

  INSERT INTO public.hospital_chain_compliance_items_r2287 (
    checklist_id, requirement_code, requirement_label, standard_family,
    weight, status, evidence_url, evidence_summary, blocker_reason,
    remediation_due_at
  ) VALUES (
    p_checklist_id, p_requirement_code, p_requirement_label,
    COALESCE(p_standard_family, 'custom'),
    COALESCE(p_weight, 1),
    COALESCE(p_status, 'pending'),
    p_evidence_url, p_evidence_summary, p_blocker_reason,
    p_remediation_due_at
  )
  ON CONFLICT (checklist_id, requirement_code) DO UPDATE SET
    requirement_label = EXCLUDED.requirement_label,
    standard_family = EXCLUDED.standard_family,
    weight = EXCLUDED.weight,
    status = EXCLUDED.status,
    evidence_url = EXCLUDED.evidence_url,
    evidence_summary = EXCLUDED.evidence_summary,
    blocker_reason = EXCLUDED.blocker_reason,
    remediation_due_at = EXCLUDED.remediation_due_at,
    updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark an item verified
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2287_mark_item_verified(
  p_item_id uuid,
  p_evidence_summary text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_caller FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;

  UPDATE public.hospital_chain_compliance_items_r2287
  SET status = 'compliant',
      verified_at = now(),
      verified_by = v_caller,
      evidence_summary = COALESCE(p_evidence_summary, evidence_summary),
      updated_at = now()
  WHERE id = p_item_id;
END;
$$;

-- ============================================================================
-- RPC 6: recompute overall status on a checklist based on items
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2287_recompute_overall_status(p_checklist_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_compliant int;
  v_non_compliant int;
  v_partial int;
  v_pct numeric;
  v_new_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE status <> 'not_applicable'),
    COUNT(*) FILTER (WHERE status = 'compliant'),
    COUNT(*) FILTER (WHERE status = 'non_compliant'),
    COUNT(*) FILTER (WHERE status = 'partial')
  INTO v_total, v_compliant, v_non_compliant, v_partial
  FROM public.hospital_chain_compliance_items_r2287
  WHERE checklist_id = p_checklist_id;

  IF v_total = 0 THEN
    v_new_status := 'in_progress';
  ELSE
    v_pct := (v_compliant::numeric * 100.0) / NULLIF(v_total, 0);
    IF v_non_compliant >= 3 OR v_pct < 40 THEN
      v_new_status := 'non_compliant';
    ELSIF v_non_compliant >= 1 OR v_pct < 70 THEN
      v_new_status := 'at_risk';
    ELSIF v_pct >= 95 THEN
      v_new_status := 'compliant';
    ELSE
      v_new_status := 'in_progress';
    END IF;
  END IF;

  UPDATE public.hospital_chain_compliance_checklists_r2287
  SET overall_status = v_new_status,
      last_review_at = now(),
      updated_at = now()
  WHERE id = p_checklist_id;

  RETURN v_new_status;
END;
$$;

-- ============================================================================
-- RPC 7: dashboard KPI rollup across all chains
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2287_compliance_kpi_summary()
RETURNS TABLE (
  total_chains int,
  compliant_chains int,
  at_risk_chains int,
  non_compliant_chains int,
  overdue_reviews int,
  total_acv_at_risk_rupees bigint,
  open_blocker_items int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.hospital_chain_compliance_checklists_r2287),
    (SELECT COUNT(*)::int FROM public.hospital_chain_compliance_checklists_r2287 WHERE overall_status = 'compliant'),
    (SELECT COUNT(*)::int FROM public.hospital_chain_compliance_checklists_r2287 WHERE overall_status = 'at_risk'),
    (SELECT COUNT(*)::int FROM public.hospital_chain_compliance_checklists_r2287 WHERE overall_status IN ('non_compliant','suspended')),
    (SELECT COUNT(*)::int FROM public.hospital_chain_compliance_checklists_r2287 WHERE next_review_due_at IS NOT NULL AND next_review_due_at < now()),
    COALESCE((SELECT SUM(annual_contract_value_rupees)::bigint FROM public.hospital_chain_compliance_checklists_r2287 WHERE overall_status IN ('at_risk','non_compliant','suspended')), 0::bigint),
    COALESCE((SELECT COUNT(*)::int FROM public.hospital_chain_compliance_items_r2287 WHERE status IN ('non_compliant','partial')), 0);
END;
$$;

-- ============================================================================
-- Grants — strict authenticated-only with REVOKE FROM PUBLIC, anon first
-- ============================================================================
REVOKE ALL ON FUNCTION public.r2287_list_chain_checklists() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2287_list_checklist_items(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2287_upsert_chain_checklist(text, text, int, bigint, text, text, text, int, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2287_upsert_checklist_item(uuid, text, text, text, int, text, text, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2287_mark_item_verified(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2287_recompute_overall_status(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2287_compliance_kpi_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2287_list_chain_checklists() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2287_list_checklist_items(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2287_upsert_chain_checklist(text, text, int, bigint, text, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2287_upsert_checklist_item(uuid, text, text, text, int, text, text, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2287_mark_item_verified(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2287_recompute_overall_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2287_compliance_kpi_summary() TO authenticated;

COMMIT;
