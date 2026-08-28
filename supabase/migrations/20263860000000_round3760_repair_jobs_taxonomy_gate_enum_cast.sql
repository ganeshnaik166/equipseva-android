-- Round 3760 — fix repair_jobs_taxonomy_gate() enum/text mismatch that
-- blocks ALL hospital job creation.
--
-- Discovered while auditing the round486 device-taxonomy hard-gate against
-- a historical fix batch that had found the identical bug class on a sibling
-- codebase (same monorepo error family as this session's round486 work
-- adding RepairEquipmentCategory.V04_ALLOWED). Confirmed live on THIS
-- database's actual schema, not assumed from the historical report:
-- round442 (20260714200000) states explicitly, in its own comment, that
-- `public.repair_jobs.equipment_type` is the enum `public.equipment_category`
-- (not text) — round442 exists specifically to fix a DIFFERENT function
-- (auto_create_due_amc_visits) that hit the same enum/text mismatch.
--
-- The round486 device-taxonomy hard-gate trigger (repair_jobs_taxonomy_gate,
-- BEFORE INSERT on repair_jobs) was written treating equipment_type as text:
--   * length(NEW.equipment_type)                -> length(equipment_category): no such function
--   * WHERE equipment_type = NEW.equipment_type  -> text (taxonomy PK) = enum : no such operator
--   * '...' || NEW.equipment_type || '...'       -> text || enum              : no such operator
-- The trigger fires BEFORE the row is written, so every client INSERT (the
-- app + web hospital console) with a non-null equipment_type has been
-- rejected since round486 with a raw Postgres error ("function
-- length(equipment_category) does not exist"), surfaced to hospitals as a
-- generic failure. Service-role / founder paths bypass the gate (line with
-- `IF auth.role() = 'service_role' OR public.is_founder()`), which is why
-- seed data and admin inserts still worked and masked the outage.
--
-- Fix: cast NEW.equipment_type to text once into a local var and use it for
-- the length check, the taxonomy lookup (equipment_taxonomy_class.equipment_type
-- is text PK), and the error-hint concatenations. Gate behaviour unchanged —
-- still blocks unknown / out-of-v0.4-scope types, still bypasses for
-- service_role/founder. Signature + trigger unchanged; plain
-- CREATE OR REPLACE. Transactional: a mistake rolls back and leaves the
-- live function intact.
--
-- The sibling amc_contracts_taxonomy_gate() trigger is NOT affected —
-- amc_contracts.equipment_categories is text[] (confirmed in round486's own
-- comment), so its unnest()/array_length() calls are already type-correct.
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
  'Round 486 (fixed round 3760) — server-side hard-gate. Blocks repair_job INSERT when equipment_type is unknown or marked allowed_in_v04=false. equipment_type (enum) cast to text for the length check, taxonomy lookup, and error hints. Service_role + founder bypass.';

COMMIT;
