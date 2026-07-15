-- Round 733 — fix repair_jobs_taxonomy_gate() enum/text mismatch that broke
-- ALL hospital job creation.
--
-- Live mobile test (hospital "Post new job") failed with:
--   function length(equipment_category) does not exist
-- captured from the PostgREST error on INSERT into repair_jobs.
--
-- Root cause: repair_jobs.equipment_type is the enum public.equipment_category
-- (since ~round442), but the round486 device-taxonomy hard-gate trigger
-- (repair_jobs_taxonomy_gate, BEFORE INSERT) still treats it as text:
--   * length(NEW.equipment_type)                 -> length(equipment_category) : no such function
--   * WHERE equipment_type = NEW.equipment_type  -> text (taxonomy PK) = enum  : no such operator
--   * '... ' || NEW.equipment_type || ' ...'     -> text || enum               : no such operator
-- The trigger fires before the row is written, so every client INSERT (the
-- app + web hospital console) has been rejected since round486. Service-role /
-- founder paths bypass the gate (line 114), which is why seed data and admin
-- inserts still worked and masked the outage.
--
-- Fix: cast NEW.equipment_type to text once into a local var and use it for the
-- length check, the taxonomy lookup (equipment_taxonomy_class.equipment_type is
-- text PK), and the error-hint concatenations. Behaviour is otherwise
-- identical — the gate still blocks unknown / out-of-v0.4-scope types.
-- Signature + trigger unchanged; plain CREATE OR REPLACE. Transactional:
-- a failure rolls back and leaves the current function intact.
--
-- NOTE: pairs with r1400 (client now sends status='requested', required by the
-- INSERT RLS WITH CHECK). Both are needed for job creation to succeed end to
-- end — the trigger fails first (BEFORE INSERT), the RLS check second.
BEGIN;

CREATE OR REPLACE FUNCTION public.repair_jobs_taxonomy_gate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_allowed boolean;
  v_reason  text;
  -- repair_jobs.equipment_type is the enum public.equipment_category; the
  -- taxonomy table keys on text. Normalise to text once.
  v_type    text := NEW.equipment_type::text;
BEGIN
  -- Service-role and founder bypass — internal admin paths can still
  -- create out-of-scope records for testing / migration purposes.
  IF auth.role() = 'service_role' OR public.is_founder() THEN
    RETURN NEW;
  END IF;
  -- If equipment_type is null/empty, let the existing NOT NULL or
  -- CHECK constraint handle it; we only gate known types.
  IF v_type IS NULL OR length(v_type) = 0 THEN
    RETURN NEW;
  END IF;

  SELECT allowed_in_v04, reason
    INTO v_allowed, v_reason
    FROM public.equipment_taxonomy_class
   WHERE equipment_type = v_type;

  -- Unknown equipment_type → block (forces taxonomy update via
  -- founder; prevents silently widening scope).
  IF v_allowed IS NULL THEN
    RAISE EXCEPTION 'equipment_type_unknown'
      USING ERRCODE = 'P0001',
            HINT = 'equipment_type "' || v_type ||
                   '" not in taxonomy. Founder must approve via equipment_taxonomy_class.';
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'equipment_type_out_of_scope'
      USING ERRCODE = 'P0001',
            HINT = v_type || ' is out of v0.4 scope. Reason: ' || coalesce(v_reason, 'unspecified') ||
                   ' Contact support if you believe this is wrong.';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.repair_jobs_taxonomy_gate IS
  'Round 486 (fixed r733) — server-side hard-gate. Blocks repair_job INSERT when equipment_type is unknown or marked allowed_in_v04=false. equipment_type (enum) cast to text for the length check, taxonomy lookup, and error hints. Service_role + founder bypass.';

COMMIT;
