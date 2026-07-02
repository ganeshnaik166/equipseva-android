-- Round 3133: Founder Quarterly Strategic Engineer-Founder Founder Family Office Estate Will + Living Trust + Beneficiary Audit
-- Scope: will, living trust, beneficiary, insurance nominee, guardianship, digital-asset access, trustee, review cadence

BEGIN;

-- =========================================================================
-- TABLE 1: estate_instruments_r3133
-- Legal instruments: will, living trust, codicil, POA, healthcare directive, nominee form
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.estate_instruments_r3133 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  instrument_code text NOT NULL UNIQUE,
  instrument_title text NOT NULL,
  instrument_type text NOT NULL CHECK (instrument_type IN ('last_will','living_trust','codicil','power_of_attorney','healthcare_directive','nominee_form','letter_of_wishes','digital_asset_directive','guardianship_appointment','memorandum_of_chattels')),
  governing_law text NOT NULL CHECK (governing_law IN ('india_succession_act','indian_trusts_act','hindu_succession_act','muslim_personal_law','indian_christian_succession','indian_parsi_succession','singapore','uk_england_wales','dubai_difc','us_delaware')),
  drafted_by text NOT NULL CHECK (drafted_by IN ('inhouse_counsel','khaitan_co','az_partners','cyril_amarchand','shardul_amarchand','trilegal','jsa','dsk_legal','external_solo_counsel','self_draft')),
  execution_status text NOT NULL CHECK (execution_status IN ('drafting','review_pending','witnessed','registered','probated','revoked','superseded','escrowed','notarised','apostilled')),
  signed_on date,
  registered_on date,
  next_review_due date NOT NULL,
  review_cadence text NOT NULL CHECK (review_cadence IN ('quarterly','semi_annual','annual','biennial','triennial','event_triggered')),
  custodian_location text NOT NULL CHECK (custodian_location IN ('home_safe','bank_locker_sbi','bank_locker_hdfc','bank_locker_icici','registrar_office','counsel_vault','digital_escrow_warpwire','digital_escrow_trustegg','family_office_safe','offshore_trustee_vault')),
  digital_copy_hash text,
  liquid_value_inr numeric(14,2) DEFAULT 0,
  illiquid_value_inr numeric(14,2) DEFAULT 0,
  contingent_value_inr numeric(14,2) DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.estate_instruments_r3133 ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_estate_instruments_r3133_review_due ON public.estate_instruments_r3133 (next_review_due);
CREATE INDEX IF NOT EXISTS idx_estate_instruments_r3133_type ON public.estate_instruments_r3133 (instrument_type, execution_status);

-- =========================================================================
-- TABLE 2: estate_beneficiary_designations_r3133
-- Beneficiaries, nominees, guardians, trustees, digital-asset agents tied to each instrument
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.estate_beneficiary_designations_r3133 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instrument_id uuid NOT NULL REFERENCES public.estate_instruments_r3133(id) ON DELETE CASCADE,
  beneficiary_alias text NOT NULL,
  relationship text NOT NULL CHECK (relationship IN ('spouse','child_minor','child_adult','parent','sibling','grandchild','charitable_trust','employee_trust','engineer_loyalty_pool','founder_holdco')),
  designation_role text NOT NULL CHECK (designation_role IN ('primary_beneficiary','contingent_beneficiary','residuary_beneficiary','specific_legatee','nominee_only','guardian_minor','trustee','protector','executor','digital_asset_agent')),
  asset_class text NOT NULL CHECK (asset_class IN ('listed_equity','unlisted_equity_equipseva','pf_epf','ppf','nps','mutual_funds','bank_deposits','real_estate','jewellery_chattels','digital_keys','crypto_cold_wallet','life_insurance','term_insurance','founder_iou','engineer_equity_pool')),
  share_basis text NOT NULL CHECK (share_basis IN ('percentage','absolute_inr','per_stirpes','per_capita','specific_item','residue_share','floating_charge','discretionary_pool')),
  share_value_inr numeric(14,2) DEFAULT 0,
  share_percentage numeric(5,2) DEFAULT 0,
  conflict_flag text NOT NULL CHECK (conflict_flag IN ('none','sibling_dispute_risk','nominee_vs_will_mismatch','minor_no_guardian','foreign_resident_fema','spouse_consent_pending','tax_drag_high','illiquidity_risk','crypto_custody_unclear','ip_assignment_gap')),
  status text NOT NULL CHECK (status IN ('active','contingent','superseded','disclaimed','died_v_pre','renounced','under_review','escrow_locked')),
  age_at_record int,
  last_communicated_on date,
  next_communication_due date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.estate_beneficiary_designations_r3133 ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_estate_benef_r3133_instrument ON public.estate_beneficiary_designations_r3133 (instrument_id);
CREATE INDEX IF NOT EXISTS idx_estate_benef_r3133_conflict ON public.estate_beneficiary_designations_r3133 (conflict_flag, status);

-- =========================================================================
-- SEED DATA
-- =========================================================================
WITH org AS (
  SELECT id FROM public.organizations ORDER BY created_at ASC LIMIT 1
), ins_seed AS (
  INSERT INTO public.estate_instruments_r3133 (
    organization_id, instrument_code, instrument_title, instrument_type, governing_law,
    drafted_by, execution_status, signed_on, registered_on, next_review_due, review_cadence,
    custodian_location, digital_copy_hash, liquid_value_inr, illiquid_value_inr, contingent_value_inr, notes
  )
  SELECT org.id, q.code, q.title, q.itype, q.glaw, q.drafted, q.estatus,
         q.signed_on::date, q.reg_on::date, q.review_due::date, q.cadence, q.custodian, q.hash,
         q.liq, q.illiq, q.contg, q.notes
  FROM org, (VALUES
    ('WILL-2025-FOUNDER-MAIN','Last Will and Testament — Founder Primary','last_will','india_succession_act','khaitan_co','registered','2025-03-12','2025-03-18','2026-09-12','annual','registrar_office','sha256:8a91ce2e',45000000,180000000,60000000,'Primary will registered at Sub-Registrar Banjara Hills; covers Indian-situs assets; specifies engineer loyalty pool carve-out 2%'),
    ('TRUST-EQSV-FAMILY-2024','Equipseva Founder Family Living Trust','living_trust','indian_trusts_act','cyril_amarchand','witnessed','2024-11-08','2024-11-22','2026-08-08','semi_annual','counsel_vault','sha256:b21f7d44',25000000,420000000,90000000,'Revocable living trust; founder + spouse co-trustees; corpus = unlisted Equipseva equity pledge + Hyderabad real estate'),
    ('POA-FIN-2025','Financial Power of Attorney — Spouse Holder','power_of_attorney','india_succession_act','az_partners','notarised','2025-01-15',NULL,'2027-01-15','biennial','bank_locker_hdfc','sha256:cc01ea58',0,0,0,'Springing POA activates on founder incapacity certified by 2 doctors; covers all Indian bank accounts + MF folios'),
    ('HCDIR-2025','Healthcare Advance Directive','healthcare_directive','india_succession_act','inhouse_counsel','witnessed','2025-02-20',NULL,'2026-08-20','annual','home_safe','sha256:d4f2aa19',0,0,0,'Living will under Common Cause judgement framework; DNR clause; spouse + sibling co-decision makers'),
    ('NOMINEE-LIC-TERM','Term Insurance Nominee Form — LIC ₹15Cr Cover','nominee_form','india_succession_act','self_draft','registered','2023-06-10',NULL,'2026-07-15','annual','home_safe','sha256:e7821bb3',150000000,0,0,'CRITICAL: nominee = spouse 100% but will splits 60/40 spouse/children — MISMATCH flagged'),
    ('LOW-2025','Letter of Wishes — Trustee Guidance','letter_of_wishes','indian_trusts_act','shardul_amarchand','notarised','2025-04-02',NULL,'2026-10-02','annual','counsel_vault','sha256:f9a3c702',0,0,30000000,'Non-binding guidance to trustees on engineer loyalty pool vesting + charitable arm allocation 5%'),
    ('DIGI-2025','Digital Asset Directive — Crypto + Cloud','digital_asset_directive','indian_trusts_act','external_solo_counsel','escrowed','2025-05-18',NULL,'2026-07-18','semi_annual','digital_escrow_warpwire','sha256:11ab2204',8500000,0,0,'2-of-3 multisig: spouse + sibling + counsel; covers cold wallet seed + iCloud + AWS root + GitHub org owner'),
    ('GUARD-MINOR-2024','Guardianship Appointment — Minor Child','guardianship_appointment','hindu_succession_act','jsa','registered','2024-09-05','2024-09-19','2026-09-05','annual','registrar_office','sha256:22cd5677',0,0,0,'Primary guardian = spouse; contingent = founder''s sister + her husband jointly; testamentary guardianship'),
    ('CODICIL-2026-Q1','Codicil 1 — Engineer Equity Pool Update','codicil','india_succession_act','khaitan_co','review_pending','2026-02-14',NULL,'2026-08-14','semi_annual','counsel_vault','sha256:33ef8819',0,0,15000000,'Adds 0.5% additional to Tier-4 engineer loyalty pool reflecting 414+ engineer roster expansion'),
    ('TRUST-SG-OFFSHORE-2024','Singapore Offshore Family Trust','living_trust','singapore','external_solo_counsel','apostilled','2024-07-22','2024-08-04','2026-07-22','semi_annual','offshore_trustee_vault','sha256:447aab12',12000000,75000000,0,'FEMA-compliant LRS-funded; trustee = Heritage Trust Singapore; for future international expansion equity ringfence'),
    ('NOMINEE-PPF-EPF','Statutory Nominee — PPF + EPF + NPS','nominee_form','india_succession_act','self_draft','registered','2022-04-01',NULL,'2026-07-01','annual','bank_locker_sbi','sha256:5588cc34',6500000,0,0,'Spouse 100%; PPF and EPF nominee forms refiled 2024-Q4; NPS Tier-1 nominee aligned with will'),
    ('MEM-CHATTELS-2025','Memorandum of Personal Chattels','memorandum_of_chattels','india_succession_act','inhouse_counsel','witnessed','2025-08-30',NULL,'2027-08-30','triennial','home_safe','sha256:66ddee45',0,18000000,0,'Jewellery + art + watches inventory with photos; specific bequests to children + sister + engineer mentor')
  ) AS q(code,title,itype,glaw,drafted,estatus,signed_on,reg_on,review_due,cadence,custodian,hash,liq,illiq,contg,notes)
  RETURNING id, instrument_code
)
INSERT INTO public.estate_beneficiary_designations_r3133 (
  instrument_id, beneficiary_alias, relationship, designation_role, asset_class, share_basis,
  share_value_inr, share_percentage, conflict_flag, status, age_at_record, last_communicated_on, next_communication_due, notes
)
SELECT s.id, q.alias, q.rel, q.role, q.aclass, q.sbasis, q.svalue, q.spct, q.conflict, q.bstatus,
       q.age, q.last_comm::date, q.next_comm::date, q.notes
FROM ins_seed s
JOIN (VALUES
  ('WILL-2025-FOUNDER-MAIN','Spouse','spouse','primary_beneficiary','unlisted_equity_equipseva','percentage',108000000,60.00,'nominee_vs_will_mismatch','active',38,'2026-04-12','2026-10-12','60% of unlisted Equipseva equity per will vs 100% per LIC nominee — reconciliation pending'),
  ('WILL-2025-FOUNDER-MAIN','Child-Minor-A','child_minor','contingent_beneficiary','unlisted_equity_equipseva','percentage',54000000,30.00,'minor_no_guardian','contingent',8,'2026-04-12','2026-10-12','Held in trust until age 25; trustee = spouse + counsel jointly'),
  ('WILL-2025-FOUNDER-MAIN','Child-Minor-B','child_minor','contingent_beneficiary','unlisted_equity_equipseva','percentage',18000000,10.00,'minor_no_guardian','contingent',5,'2026-04-12','2026-10-12','Held in trust until age 25; equal voting via trustee'),
  ('WILL-2025-FOUNDER-MAIN','Engineer-Loyalty-Pool','engineer_loyalty_pool','specific_legatee','engineer_equity_pool','percentage',6000000,2.00,'ip_assignment_gap','active',NULL,'2026-03-01','2026-09-01','2% reserved for top-tier engineers; cap table mechanics need vesting schedule attached'),
  ('TRUST-EQSV-FAMILY-2024','Spouse','spouse','trustee','unlisted_equity_equipseva','discretionary_pool',0,0.00,'spouse_consent_pending','active',38,'2026-05-10','2026-08-10','Co-trustee with founder; trust deed requires spouse re-affirmation post-Singapore-trust funding'),
  ('TRUST-EQSV-FAMILY-2024','Founder-Sister','sibling','protector','unlisted_equity_equipseva','discretionary_pool',0,0.00,'none','active',42,'2026-04-25','2026-10-25','Trust protector with power to remove trustee; non-beneficiary'),
  ('TRUST-EQSV-FAMILY-2024','Charitable-Arm-Equipseva-Foundation','charitable_trust','residuary_beneficiary','unlisted_equity_equipseva','residue_share',0,5.00,'tax_drag_high','active',NULL,'2026-02-15','2026-08-15','5% residue to charitable arm focused on rural medical-equipment access; 12A/80G registration pending'),
  ('POA-FIN-2025','Spouse','spouse','digital_asset_agent','bank_deposits','specific_item',0,0.00,'none','active',38,'2026-05-20','2026-11-20','POA holder for all Indian bank + MF accounts; activates only on certified incapacity'),
  ('HCDIR-2025','Spouse','spouse','executor','bank_deposits','specific_item',0,0.00,'none','active',38,'2026-02-20','2026-08-20','Primary healthcare proxy; co-signatory with founder''s sibling'),
  ('NOMINEE-LIC-TERM','Spouse','spouse','nominee_only','term_insurance','absolute_inr',150000000,100.00,'nominee_vs_will_mismatch','active',38,'2026-04-12','2026-07-12','URGENT: nominee form says 100% spouse but will splits 60/40 — must align in next review cycle'),
  ('LOW-2025','Engineer-Loyalty-Pool','engineer_loyalty_pool','contingent_beneficiary','engineer_equity_pool','discretionary_pool',30000000,0.00,'ip_assignment_gap','contingent',NULL,'2026-03-01','2026-09-01','Letter of wishes guides trustees on engineer pool vesting tied to tier achievements'),
  ('DIGI-2025','Spouse','spouse','digital_asset_agent','crypto_cold_wallet','specific_item',8500000,100.00,'crypto_custody_unclear','active',38,'2026-05-18','2026-08-18','One of three multisig keyholders; covers cold wallet + AWS root + GitHub org'),
  ('DIGI-2025','Founder-Sister','sibling','digital_asset_agent','digital_keys','specific_item',0,0.00,'foreign_resident_fema','active',42,'2026-05-18','2026-08-18','Second multisig key; resides in Singapore — FEMA review on digital asset transmittal'),
  ('GUARD-MINOR-2024','Spouse','spouse','guardian_minor','bank_deposits','specific_item',0,0.00,'none','active',38,'2026-04-12','2026-10-12','Primary guardian for both minor children'),
  ('GUARD-MINOR-2024','Founder-Sister','sibling','guardian_minor','bank_deposits','specific_item',0,0.00,'foreign_resident_fema','contingent',42,'2026-04-12','2026-10-12','Contingent guardian; Singapore resident — must obtain Indian court approval if invoked'),
  ('CODICIL-2026-Q1','Engineer-Loyalty-Pool','engineer_loyalty_pool','specific_legatee','engineer_equity_pool','floating_charge',15000000,0.50,'ip_assignment_gap','under_review',NULL,'2026-02-14','2026-08-14','Adds 0.5% on top of original 2% reflecting 414+ engineer roster; vesting schedule under counsel review'),
  ('TRUST-SG-OFFSHORE-2024','Founder-Holdco-SG','founder_holdco','primary_beneficiary','unlisted_equity_equipseva','percentage',75000000,100.00,'foreign_resident_fema','active',NULL,'2026-04-22','2026-07-22','Singapore holdco; FEMA LRS reporting current to Mar-2026'),
  ('NOMINEE-PPF-EPF','Spouse','spouse','nominee_only','pf_epf','percentage',6500000,100.00,'none','active',38,'2026-04-01','2026-10-01','PPF + EPF + NPS Tier-1 nominee aligned; refiled Oct-2024'),
  ('MEM-CHATTELS-2025','Child-Minor-A','child_minor','specific_legatee','jewellery_chattels','specific_item',9000000,0.00,'minor_no_guardian','contingent',8,'2026-04-12','2027-04-12','Heirloom jewellery set + grandmother''s necklace'),
  ('MEM-CHATTELS-2025','Child-Minor-B','child_minor','specific_legatee','jewellery_chattels','specific_item',6000000,0.00,'minor_no_guardian','contingent',5,'2026-04-12','2027-04-12','Specific watches collection + art piece'),
  ('MEM-CHATTELS-2025','Engineer-Mentor-Alias','engineer_loyalty_pool','specific_legatee','jewellery_chattels','specific_item',3000000,0.00,'none','active',NULL,'2026-03-01','2027-03-01','Vintage tool set bequest to founding engineer mentor as legacy gesture')
) AS q(code,alias,rel,role,aclass,sbasis,svalue,spct,conflict,bstatus,age,last_comm,next_comm,notes)
  ON s.instrument_code = q.code;

-- =========================================================================
-- RPC 1: instrument rollup by type x execution status
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_estate_instrument_rollup_r3133()
RETURNS TABLE (
  instrument_type text,
  execution_status text,
  instrument_count bigint,
  total_liquid_inr numeric,
  total_illiquid_inr numeric,
  total_contingent_inr numeric,
  next_review_min date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  if not is_founder() then raise exception 'forbidden'; end if;
  RETURN QUERY
  SELECT i.instrument_type, i.execution_status,
         count(*)::bigint,
         coalesce(sum(i.liquid_value_inr),0)::numeric,
         coalesce(sum(i.illiquid_value_inr),0)::numeric,
         coalesce(sum(i.contingent_value_inr),0)::numeric,
         min(i.next_review_due)
  FROM public.estate_instruments_r3133 i
  GROUP BY i.instrument_type, i.execution_status
  ORDER BY i.instrument_type, i.execution_status;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_estate_instrument_rollup_r3133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_estate_instrument_rollup_r3133() TO authenticated;

-- =========================================================================
-- RPC 2: upcoming reviews due (next 180 days)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_estate_upcoming_reviews_r3133()
RETURNS TABLE (
  instrument_code text,
  instrument_title text,
  instrument_type text,
  next_review_due date,
  days_to_review int,
  review_cadence text,
  custodian_location text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  if not is_founder() then raise exception 'forbidden'; end if;
  RETURN QUERY
  SELECT i.instrument_code, i.instrument_title, i.instrument_type,
         i.next_review_due,
         (i.next_review_due - current_date)::int,
         i.review_cadence, i.custodian_location
  FROM public.estate_instruments_r3133 i
  WHERE i.next_review_due <= current_date + interval '180 days'
  ORDER BY i.next_review_due ASC;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_estate_upcoming_reviews_r3133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_estate_upcoming_reviews_r3133() TO authenticated;

-- =========================================================================
-- RPC 3: beneficiary conflict heatmap
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_estate_conflict_heatmap_r3133()
RETURNS TABLE (
  conflict_flag text,
  designation_count bigint,
  total_value_at_risk_inr numeric,
  active_count bigint,
  contingent_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  if not is_founder() then raise exception 'forbidden'; end if;
  RETURN QUERY
  SELECT b.conflict_flag,
         count(*)::bigint,
         coalesce(sum(b.share_value_inr),0)::numeric,
         count(*) FILTER (WHERE b.status = 'active')::bigint,
         count(*) FILTER (WHERE b.status = 'contingent')::bigint
  FROM public.estate_beneficiary_designations_r3133 b
  GROUP BY b.conflict_flag
  ORDER BY count(*) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_estate_conflict_heatmap_r3133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_estate_conflict_heatmap_r3133() TO authenticated;

-- =========================================================================
-- RPC 4: beneficiary share aggregate by relationship x asset class
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_estate_beneficiary_aggregate_r3133()
RETURNS TABLE (
  relationship text,
  asset_class text,
  designation_count bigint,
  total_share_inr numeric,
  weighted_share_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  if not is_founder() then raise exception 'forbidden'; end if;
  RETURN QUERY
  SELECT b.relationship, b.asset_class,
         count(*)::bigint,
         coalesce(sum(b.share_value_inr),0)::numeric,
         coalesce(round(avg(b.share_percentage)::numeric, 2),0)::numeric
  FROM public.estate_beneficiary_designations_r3133 b
  GROUP BY b.relationship, b.asset_class
  ORDER BY b.relationship, b.asset_class;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_estate_beneficiary_aggregate_r3133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_estate_beneficiary_aggregate_r3133() TO authenticated;

-- =========================================================================
-- RPC 5: nominee-vs-will mismatch finder
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_estate_nominee_will_mismatch_r3133()
RETURNS TABLE (
  instrument_code text,
  instrument_type text,
  beneficiary_alias text,
  asset_class text,
  share_percentage numeric,
  share_value_inr numeric,
  conflict_flag text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  if not is_founder() then raise exception 'forbidden'; end if;
  RETURN QUERY
  SELECT i.instrument_code, i.instrument_type,
         b.beneficiary_alias, b.asset_class,
         b.share_percentage, b.share_value_inr,
         b.conflict_flag, b.status
  FROM public.estate_beneficiary_designations_r3133 b
  JOIN public.estate_instruments_r3133 i ON i.id = b.instrument_id
  WHERE b.conflict_flag IN ('nominee_vs_will_mismatch','spouse_consent_pending','foreign_resident_fema','minor_no_guardian')
  ORDER BY b.share_value_inr DESC NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_estate_nominee_will_mismatch_r3133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_estate_nominee_will_mismatch_r3133() TO authenticated;

-- =========================================================================
-- RPC 6: custodian distribution snapshot
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_estate_custodian_distribution_r3133()
RETURNS TABLE (
  custodian_location text,
  instrument_count bigint,
  total_value_under_custody_inr numeric,
  oldest_signed_on date,
  governing_laws_covered text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  if not is_founder() then raise exception 'forbidden'; end if;
  RETURN QUERY
  SELECT i.custodian_location,
         count(*)::bigint,
         coalesce(sum(i.liquid_value_inr + i.illiquid_value_inr + i.contingent_value_inr),0)::numeric,
         min(i.signed_on),
         string_agg(DISTINCT i.governing_law, ', ' ORDER BY i.governing_law)
  FROM public.estate_instruments_r3133 i
  GROUP BY i.custodian_location
  ORDER BY count(*) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_estate_custodian_distribution_r3133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_estate_custodian_distribution_r3133() TO authenticated;

-- =========================================================================
-- RPC 7: digital-asset agent coverage
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_estate_digital_asset_coverage_r3133()
RETURNS TABLE (
  beneficiary_alias text,
  relationship text,
  asset_class text,
  designation_role text,
  share_value_inr numeric,
  conflict_flag text,
  status text,
  next_communication_due date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  if not is_founder() then raise exception 'forbidden'; end if;
  RETURN QUERY
  SELECT b.beneficiary_alias, b.relationship, b.asset_class,
         b.designation_role, b.share_value_inr,
         b.conflict_flag, b.status, b.next_communication_due
  FROM public.estate_beneficiary_designations_r3133 b
  WHERE b.designation_role IN ('digital_asset_agent','trustee','protector','executor')
     OR b.asset_class IN ('digital_keys','crypto_cold_wallet')
  ORDER BY b.share_value_inr DESC NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_estate_digital_asset_coverage_r3133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_estate_digital_asset_coverage_r3133() TO authenticated;

-- =========================================================================
-- RPC 8: communication cadence gaps (beneficiary outreach)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_estate_communication_gaps_r3133()
RETURNS TABLE (
  beneficiary_alias text,
  relationship text,
  designation_role text,
  last_communicated_on date,
  next_communication_due date,
  days_since_last int,
  days_to_next int,
  conflict_flag text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  if not is_founder() then raise exception 'forbidden'; end if;
  RETURN QUERY
  SELECT b.beneficiary_alias, b.relationship, b.designation_role,
         b.last_communicated_on, b.next_communication_due,
         CASE WHEN b.last_communicated_on IS NULL THEN NULL ELSE (current_date - b.last_communicated_on)::int END,
         CASE WHEN b.next_communication_due IS NULL THEN NULL ELSE (b.next_communication_due - current_date)::int END,
         b.conflict_flag
  FROM public.estate_beneficiary_designations_r3133 b
  ORDER BY b.next_communication_due ASC NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_estate_communication_gaps_r3133() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_estate_communication_gaps_r3133() TO authenticated;

COMMIT;
