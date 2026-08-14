-- Round 3754 — Fix missed founder RPC grants for the r523 bonded-supplier
-- registration form and its intake counterpart.
--
-- Same bug class as r847/r848/r849: these two SECDEF RPCs were shipped in
-- r500 (20260819000000_round500_bonded_parts_provenance.sql) with the
-- is_founder() body gate but GRANT TO service_role only. The r523 web form
-- (web/src/app/supply/SupplierForm.tsx -> actions/supply.ts) calls them via
-- the founder's authenticated SSR session, never the service-role key, so
-- every real submission has been hitting a 42501 permission-denied error
-- since r523 shipped — silently surfaced to the founder as a generic
-- "Could not register supplier. Check server logs." with no INSERT ever
-- reaching bonded_parts_suppliers / bonded_parts_intake.
--
-- The r848 sweep fixed founder_bonded_parts_dashboard (read-only) and
-- founder_force_release_escrow from the same r523 commit, but missed these
-- two write RPCs. Confirmed via grep across the full migrations tree: no
-- later migration ever added GRANT ... TO authenticated for either.
--
-- Adding GRANT TO authenticated only; the body's is_founder() check still
-- gates non-founders exactly as before. The service_role grant (for any
-- edge-function caller) stays in place, untouched.
BEGIN;

GRANT EXECUTE ON FUNCTION public.founder_register_bonded_supplier(
  text, text, text, text[], text, text
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.founder_record_bonded_intake(
  uuid, text, date, text, text, text, text, int, numeric, text[]
) TO authenticated;

COMMIT;
