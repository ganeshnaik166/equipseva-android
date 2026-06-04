-- Round 442 — fix the amc-create-visits cron slot that was failing
-- every hourly tick with SQLSTATE 42804 (datatype_mismatch).
--
-- Discovery: round 440 unblocked a stale Supabase gateway 401 that had
-- been silently masking every cron-tick failure for weeks. The first
-- tick after the gateway fix exposed `amc-create-visits` failing in
-- 230ms. Round 441 surfaced SQLSTATE in the response → 42804.
--
-- Root cause: `auto_create_due_amc_visits()` (shipped in
-- 20260511100000_v21_amc_cron_helpers.sql) declares
--     v_equipment_type text;
-- and inserts that variable into `public.repair_jobs.equipment_type`,
-- which is of enum type `public.equipment_category` (not text). Postgres
-- refuses implicit text → custom-enum coercion, so the INSERT plan
-- fails at execution before any row touches the table.
--
-- Why it worked at one point: either
--   * the column was text at the time the RPC was written and got
--     promoted to the enum type later, OR
--   * there were no due AMC contracts in prod until recently, so the
--     SELECT in the LOOP returned 0 rows and the INSERT plan never
--     compiled. Either way the symptom only surfaced once a contract
--     with next_visit_at <= now() existed.
--
-- Fix: cast the value to the enum type when inserting, with a defensive
-- EXCEPTION block so an unexpected text value in
-- `amc_contracts.equipment_categories[1]` (e.g. a free-text category
-- that isn't in the enum) downgrades to NULL equipment_type instead of
-- crashing the whole batch and stranding ALL due contracts. AMC visits
-- with NULL equipment_type are valid — the engineer-side UI shows the
-- AMC contract's category list in place of the per-visit value.
--
-- Idempotent: CREATE OR REPLACE. No data backfill required — failed
-- contracts simply pick up on the next hourly tick because
-- next_visit_at was never advanced (no UPDATE ran on the failed row).

CREATE OR REPLACE FUNCTION public.auto_create_due_amc_visits()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract       public.amc_contracts%ROWTYPE;
  v_advance        interval;
  v_months_elapsed int;
  v_years_elapsed  int;
  v_max_visits     int;
  v_equipment_type public.equipment_category;
  v_equipment_text text;
  v_job_number     text;
  v_created_count  int := 0;
BEGIN
  FOR v_contract IN
    SELECT *
      FROM public.amc_contracts
     WHERE status = 'active'
       AND next_visit_at IS NOT NULL
       AND next_visit_at <= now()
     ORDER BY next_visit_at ASC
     FOR UPDATE SKIP LOCKED
  LOOP
    v_months_elapsed := GREATEST(
      0,
      (EXTRACT(YEAR FROM age(now()::date, v_contract.start_date)) * 12
       + EXTRACT(MONTH FROM age(now()::date, v_contract.start_date)))::int
    );
    v_years_elapsed := (v_months_elapsed / 12) + 1;
    v_max_visits := v_contract.visits_per_year * v_years_elapsed;

    v_advance := CASE v_contract.visit_frequency
      WHEN 'weekly'    THEN interval '7 days'
      WHEN 'biweekly'  THEN interval '14 days'
      WHEN 'monthly'   THEN interval '1 month'
      WHEN 'quarterly' THEN interval '3 months'
      ELSE interval '1 month'
    END;

    IF v_contract.visits_completed + v_contract.visits_scheduled >= v_max_visits THEN
      UPDATE public.amc_contracts
         SET next_visit_at = next_visit_at + v_advance,
             updated_at = now()
       WHERE id = v_contract.id;
      CONTINUE;
    END IF;

    -- Round 442: cast the first equipment_categories[] element to the
    -- enum type, swallowing invalid_text_representation so a stale
    -- free-text value doesn't block the whole batch.
    v_equipment_text := CASE
      WHEN v_contract.equipment_categories IS NULL THEN NULL
      WHEN array_length(v_contract.equipment_categories, 1) IS NULL THEN NULL
      ELSE v_contract.equipment_categories[1]
    END;

    BEGIN
      v_equipment_type := v_equipment_text::public.equipment_category;
    EXCEPTION WHEN invalid_text_representation THEN
      v_equipment_type := NULL;
    END;

    v_job_number := 'AMC-'
                  || substring(v_contract.id::text, 1, 8)
                  || '-'
                  || lpad((v_contract.visits_completed
                         + v_contract.visits_scheduled + 1)::text, 3, '0');

    INSERT INTO public.repair_jobs (
      job_number,
      hospital_user_id,
      engineer_id,
      kind,
      amc_contract_id,
      amc_visit_number,
      status,
      equipment_type,
      issue_description,
      scheduled_date,
      site_latitude,
      site_longitude,
      contracted_amount_rupees,
      created_at,
      updated_at
    ) VALUES (
      v_job_number,
      v_contract.hospital_user_id,
      v_contract.primary_engineer_id,
      'maintenance',
      v_contract.id,
      v_contract.visits_completed + v_contract.visits_scheduled + 1,
      'requested',
      v_equipment_type,
      coalesce(
        nullif(trim(coalesce(v_contract.scope_text, '')), ''),
        'Scheduled AMC maintenance visit'
      ),
      v_contract.next_visit_at::date,
      NULL,
      NULL,
      0,
      now(),
      now()
    );

    UPDATE public.amc_contracts
       SET visits_scheduled = visits_scheduled + 1,
           next_visit_at = next_visit_at + v_advance,
           updated_at = now()
     WHERE id = v_contract.id;

    v_created_count := v_created_count + 1;
  END LOOP;

  RETURN v_created_count;
END;
$$;

ALTER FUNCTION public.auto_create_due_amc_visits() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.auto_create_due_amc_visits() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_create_due_amc_visits() TO service_role;
