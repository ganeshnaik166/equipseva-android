-- Round 849 — Fix r510 (analytics event ledger) founder RPC grants.
--
-- Same pattern as r847/r848: r510 created three founder ops RPCs and
-- granted EXECUTE only to service_role, but /funnel and /health pages
-- call them via the founder's SSR session (authenticated role).
-- Result: permission_denied on every load.
--
-- Affected:
--   /funnel  → founder_funnel_conversion
--   /health  → founder_top_events
--   (founder_event_volume_daily isn't called from web yet — granted
--    proactively in case a future page wires it in.)
BEGIN;

GRANT EXECUTE ON FUNCTION public.founder_funnel_conversion(text, integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_event_volume_daily(text, integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_top_events(integer, integer)
  TO authenticated;

COMMIT;
