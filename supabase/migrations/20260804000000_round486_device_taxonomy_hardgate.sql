-- =====================================================================
-- Round 486 — Device Taxonomy Hard-Gate (v0.4 Phase 1 #6)
-- =====================================================================
--
-- Skeptic-panel EXISTENTIAL risk #A: CDSCO advisory on Class C/D
-- medical-device servicing. One DCGI letter classifies non-OEM
-- servicing of notified Class C/D devices as "manufacture" under D&C
-- Act §3(f) → 60% of GMV dies overnight because hospital NABH
-- auditors refuse third-party service records.
--
-- Our defense: STAY OUT of Class C/D + AERB-regulated categories.
-- This migration adds a server-side hard-gate enforced via trigger
-- on repair_jobs.equipment_type. ToS lines don't enforce policy;
-- only the trigger does.
--
-- Class A/B (within v0.4 scope — ALLOWED):
--   dental, ophthalmology, sterilization, patient_monitoring (basic),
--   laboratory
--
-- Class C/D (outside v0.4 scope — BLOCKED at server):
--   life_support, surgical, dialysis, cardiology (ICU/cathlab),
--   imaging_radiology (AERB territory: CT, MRI, X-ray, fluoroscopy)
--
-- The taxonomy lives in a dedicated lookup table so future updates
-- don't require a code migration — founder/admin can change the
-- mapping via SQL alone (after evaluating regulatory risk).

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Lookup table — equipment_type → criticality class
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.equipment_taxonomy_class (
  equipment_type   text PRIMARY KEY,
  criticality      text NOT NULL CHECK (criticality IN ('A','B','C','D','AERB')),
  allowed_in_v04   boolean NOT NULL DEFAULT false,
  reason           text NOT NULL,
  updated_at       timestamptz NOT NULL DEFAULT now(),
  updated_by       uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.equipment_taxonomy_class IS
  'Round 486 — equipment_type to Medical Devices Rules 2017 criticality class mapping. Drives the v0.4 hard-gate that blocks repair_jobs + amc_contracts from being created on Class C/D devices. Founder can update via SQL after regulatory review.';

-- Seed the initial mapping. Phase 5 + future verticals can flip
-- allowed_in_v04 individually as we layer in the OEM partnership /
-- insurance coverage / engineer certification depth needed for each
-- higher class.
INSERT INTO public.equipment_taxonomy_class (equipment_type, criticality, allowed_in_v04, reason) VALUES
  -- Class A (lowest risk) — within scope
  ('dental',              'A',    true,
   'Class A per MDR-17. Dental chair, autoclave, suction, compressor. No life-support exposure. Our wedge for Phase 5.'),
  ('ophthalmology',       'A',    true,
   'Diagnostic ophthalmology (slit lamp, fundus camera, OCT, perimetry). NOT surgical phaco/YAG — those are Class C (separate equipment_type needed if shipped). Class A for diagnostic only.'),
  ('sterilization',       'A',    true,
   'Autoclaves, ultrasonic cleaners. Operating without function = inconvenience, not patient death. Class A.'),
  ('patient_monitoring',  'B',    true,
   'Basic vitals monitors, ECG, BP. NOT ICU multi-parameter monitors with arrhythmia detection (those are Class C). At our scope, treat as B with the understanding that ICU-grade is out via equipment_model context check in v0.5.'),
  ('laboratory',          'B',    true,
   'Basic lab equipment — centrifuges, microscopes, water baths, incubators. NOT IVD analyzers (those are Class C). Class B for non-IVD only.'),
  -- Class C/D + AERB (highest risk) — OUT OF SCOPE for v0.4
  ('imaging_radiology',   'AERB', false,
   'AERB-regulated (Atomic Energy Regulatory Board). CT, MRI, X-ray, fluoroscopy. Touching = seal-the-hospital risk. EXCLUDED from v0.4.'),
  ('life_support',        'D',    false,
   'Ventilators, defibrillators, anesthesia workstations, infant warmers. Class D per MDR-17. Patient-death liability if mis-repaired. EXCLUDED from v0.4 per skeptic-panel existential risk A.'),
  ('surgical',            'C',    false,
   'Phaco machines, electrosurgery units, surgical microscopes, OT lights. Class C per MDR-17. Bad repair = intra-op complication. EXCLUDED from v0.4.'),
  ('dialysis',            'C',    false,
   'Dialysis machines + water RO system. Class C/D per MDR-17. Wrong repair = patient death during dialysis. EXCLUDED from v0.4. (Phase 5+ may add non-machine equipment like patient chairs as a separate sub-type.)'),
  ('cardiology',          'C',    false,
   'ECG carts, defibrillators, holter monitors, cathlab equipment. Mostly Class C+. EXCLUDED from v0.4.')
ON CONFLICT (equipment_type) DO NOTHING;

-- Founder-only read of the mapping (also visible to authenticated
-- because the UI needs it to filter the picker — but only allowed
-- values are listed in client-side enums anyway, so leaking the
-- mapping is harmless).
ALTER TABLE public.equipment_taxonomy_class ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS equipment_taxonomy_class_read ON public.equipment_taxonomy_class;
CREATE POLICY equipment_taxonomy_class_read
  ON public.equipment_taxonomy_class
  FOR SELECT
  TO authenticated, service_role
  USING (true);

-- Only the founder can update the mapping (changing allowed_in_v04
-- means regulatory exposure).
DROP POLICY IF EXISTS equipment_taxonomy_class_admin ON public.equipment_taxonomy_class;
CREATE POLICY equipment_taxonomy_class_admin
  ON public.equipment_taxonomy_class
  FOR ALL
  TO authenticated, service_role
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE UPDATE, DELETE, INSERT ON public.equipment_taxonomy_class FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. Hard-gate trigger on repair_jobs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.repair_jobs_taxonomy_gate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_allowed boolean;
  v_reason  text;
BEGIN
  -- Service-role and founder bypass — internal admin paths can still
  -- create out-of-scope records for testing / migration purposes.
  IF auth.role() = 'service_role' OR public.is_founder() THEN
    RETURN NEW;
  END IF;
  -- If equipment_type is null/empty, let the existing NOT NULL or
  -- CHECK constraint handle it; we only gate known types.
  IF NEW.equipment_type IS NULL OR length(NEW.equipment_type) = 0 THEN
    RETURN NEW;
  END IF;

  SELECT allowed_in_v04, reason
    INTO v_allowed, v_reason
    FROM public.equipment_taxonomy_class
   WHERE equipment_type = NEW.equipment_type;

  -- Unknown equipment_type → block (forces taxonomy update via
  -- founder; prevents silently widening scope).
  IF v_allowed IS NULL THEN
    RAISE EXCEPTION 'equipment_type_unknown'
      USING ERRCODE = 'P0001',
            HINT = 'equipment_type "' || NEW.equipment_type ||
                   '" not in taxonomy. Founder must approve via equipment_taxonomy_class.';
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'equipment_type_out_of_scope'
      USING ERRCODE = 'P0001',
            HINT = NEW.equipment_type || ' is out of v0.4 scope. Reason: ' || coalesce(v_reason, 'unspecified') ||
                   ' Contact support if you believe this is wrong.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS repair_jobs_taxonomy_gate_trg ON public.repair_jobs;
CREATE TRIGGER repair_jobs_taxonomy_gate_trg
  BEFORE INSERT ON public.repair_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.repair_jobs_taxonomy_gate();

COMMENT ON FUNCTION public.repair_jobs_taxonomy_gate IS
  'Round 486 — server-side hard-gate. Blocks repair_job INSERT when equipment_type is unknown or marked allowed_in_v04=false. Service_role + founder bypass for admin / migration paths.';

-- ---------------------------------------------------------------------
-- 3. Hard-gate trigger on amc_contracts.equipment_categories
-- ---------------------------------------------------------------------
-- amc_contracts has equipment_categories text[] — array of types.
-- Reject if ANY element is out of scope.
CREATE OR REPLACE FUNCTION public.amc_contracts_taxonomy_gate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_blocked text;
BEGIN
  IF auth.role() = 'service_role' OR public.is_founder() THEN
    RETURN NEW;
  END IF;
  IF NEW.equipment_categories IS NULL OR array_length(NEW.equipment_categories, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  -- Find the first equipment_category in the array that's NOT
  -- allowed_in_v04 (or not in the taxonomy at all).
  SELECT cat
    INTO v_blocked
    FROM unnest(NEW.equipment_categories) AS cat
   WHERE NOT EXISTS (
     SELECT 1 FROM public.equipment_taxonomy_class
      WHERE equipment_type = cat AND allowed_in_v04 = true
   )
   LIMIT 1;

  IF v_blocked IS NOT NULL THEN
    RAISE EXCEPTION 'equipment_category_out_of_scope'
      USING ERRCODE = 'P0001',
            HINT = 'equipment_category "' || v_blocked ||
                   '" is out of v0.4 scope. Remove from the contract or contact support.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS amc_contracts_taxonomy_gate_trg ON public.amc_contracts;
CREATE TRIGGER amc_contracts_taxonomy_gate_trg
  BEFORE INSERT ON public.amc_contracts
  FOR EACH ROW
  EXECUTE FUNCTION public.amc_contracts_taxonomy_gate();

COMMENT ON FUNCTION public.amc_contracts_taxonomy_gate IS
  'Round 486 — block AMC contract creation if equipment_categories array contains any type not in scope.';

COMMIT;

-- Post-condition assertions
DO $$
DECLARE
  v_in_scope_count int;
  v_out_scope_count int;
BEGIN
  SELECT count(*) INTO v_in_scope_count
    FROM public.equipment_taxonomy_class WHERE allowed_in_v04 = true;
  SELECT count(*) INTO v_out_scope_count
    FROM public.equipment_taxonomy_class WHERE allowed_in_v04 = false;

  IF v_in_scope_count < 4 THEN
    RAISE EXCEPTION 'round 486: expected at least 4 in-scope types, got %', v_in_scope_count;
  END IF;
  IF v_out_scope_count < 4 THEN
    RAISE EXCEPTION 'round 486: expected at least 4 out-of-scope types, got %', v_out_scope_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'repair_jobs_taxonomy_gate_trg'
      AND tgrelid = 'public.repair_jobs'::regclass
  ) THEN
    RAISE EXCEPTION 'round 486: repair_jobs_taxonomy_gate_trg not installed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'amc_contracts_taxonomy_gate_trg'
      AND tgrelid = 'public.amc_contracts'::regclass
  ) THEN
    RAISE EXCEPTION 'round 486: amc_contracts_taxonomy_gate_trg not installed';
  END IF;

  RAISE NOTICE 'round 486 taxonomy hard-gate verified: % in-scope + % out-of-scope types, triggers installed', v_in_scope_count, v_out_scope_count;
END;
$$;
