-- Round 322 — auto-expire AMC contracts whose end_date has lapsed.
--
-- v21 amc_contracts.status was set up with 'expired' as a valid value
-- but NO transition function existed to move 'active' → 'expired' when
-- the end_date passes. Two latent consequences:
--   1. The contract sits 'active' in the hospital's list forever.
--   2. auto_create_due_amc_visits filters on `status='active'` only,
--      so it would keep creating visits past the contract term —
--      engineer keeps getting paged, hospital keeps getting billed
--      against an exhausted pool.
--
-- Worst-case window: ≤24h between end_date passing and the next daily
-- cron-tick run, during which auto_create_due_amc_visits MIGHT create
-- one extra visit. Acceptable trade-off vs. patching the complex
-- visit-creation function in place; that function is left as-is.
--
-- Idempotent: WHERE clause excludes already-expired rows.
-- Concurrent-safe: FOR UPDATE SKIP LOCKED.

CREATE OR REPLACE FUNCTION public.expire_lapsed_amc_contracts()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
  v_id    uuid;
BEGIN
  FOR v_id IN
    SELECT id
      FROM public.amc_contracts
     WHERE status = 'active'
       AND end_date < CURRENT_DATE
     FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.amc_contracts
       SET status     = 'expired',
           updated_at = now()
     WHERE id = v_id
       AND status = 'active'
       AND end_date < CURRENT_DATE;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

ALTER FUNCTION public.expire_lapsed_amc_contracts() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.expire_lapsed_amc_contracts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_lapsed_amc_contracts() TO service_role;

COMMENT ON FUNCTION public.expire_lapsed_amc_contracts() IS
  'Round 322 — flip status active->expired for AMC contracts whose '
  'end_date has lapsed. Daily cron via cron-tick. Idempotent. '
  'Concurrent-safe (FOR UPDATE SKIP LOCKED).';
