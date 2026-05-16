-- Round 298 — close RLS bypass on v_amc_pool_balance view.
--
-- v_amc_pool_balance was created in 20260510100000_v21_amc_payment_pool
-- without `WITH (security_invoker = on)`. Postgres defaults views to
-- `security_invoker = false`, which means the view's underlying
-- SELECT runs with the OWNER's privileges, bypassing RLS on the
-- amc_payment_pool table.
--
-- Concrete leak: `get_amc_pool_balance(p_contract_id)` is a SECURITY
-- INVOKER RPC granted to authenticated. It SELECTs from
-- v_amc_pool_balance WHERE amc_contract_id = p_contract_id. Because
-- the view bypasses RLS, an authenticated user can pass ANY contract
-- id (their own, a friend's, a sibling competitor's) and get back
-- that contract's balance.
--
-- The sibling `engineers_public` view explicitly opts in to
-- `security_invoker = false` because its column projection IS the
-- security boundary (PII columns dropped). v_amc_pool_balance has no
-- such projection — it exposes balance directly, so its security
-- boundary MUST be RLS on the underlying table.
--
-- Fix: flip to `security_invoker = on`. The view now respects the
-- amc_payment_pool RLS policies (hospital_own / engineer_assigned /
-- admin_all). Existing legitimate callers continue to work because
-- those policies match every legitimate access pattern.

ALTER VIEW public.v_amc_pool_balance SET (security_invoker = on);

COMMENT ON VIEW public.v_amc_pool_balance IS
  'Per-contract AMC balance (sum of ledger). Round 298 — set '
  'security_invoker = on so the view respects amc_payment_pool RLS '
  'and an authenticated user can no longer probe arbitrary '
  'contract ids for their balance.';
