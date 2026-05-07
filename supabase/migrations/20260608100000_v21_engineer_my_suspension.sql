-- v2.1 PR-D30: engineer self-suspension visibility.
--
-- PR-D11 auto-suspends an engineer after 3+ cash-flag responses /
-- 90 days (sets engineers.cash_auto_suspended_at + reason). PR-D22's
-- engineer_auto_suspended push deeplink routes to Routes.PROFILE,
-- but Profile has no surface for the column today — engineer lands
-- on a normal profile and is confused why their availability flipped
-- off.
--
-- This RPC returns the engineer's own suspension state (filtered to
-- the caller via auth.uid -> engineers.user_id), or NULL when not
-- suspended. UI uses this to render a banner explaining why + the
-- 90-day flag count + a "contact support" pointer.
--
-- Why a SECDEF RPC vs direct table SELECT: engineer_id and user_id
-- are both readable from the engineers row, but cash_survey_responses
-- has its own RLS that blocks engineers from reading their own flag
-- count. The RPC bridges the two with a single round-trip.

CREATE OR REPLACE FUNCTION public.engineer_my_suspension()
RETURNS TABLE (
  is_suspended         boolean,
  suspended_at         timestamptz,
  reason               text,
  flag_count_90d       int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_engineer record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT id, cash_auto_suspended_at, cash_auto_suspension_reason
    INTO v_engineer
    FROM public.engineers
   WHERE user_id = v_caller
   LIMIT 1;

  -- Not an engineer or no row yet -> empty result. UI hides the banner.
  IF v_engineer IS NULL THEN RETURN; END IF;

  IF v_engineer.cash_auto_suspended_at IS NULL THEN
    RETURN QUERY SELECT false, NULL::timestamptz, NULL::text, 0;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    true                                          AS is_suspended,
    v_engineer.cash_auto_suspended_at             AS suspended_at,
    v_engineer.cash_auto_suspension_reason        AS reason,
    coalesce((
      SELECT count(*)::int FROM public.cash_survey_responses csr
       WHERE csr.engineer_id = v_engineer.id
         AND csr.response = 'asked_cash'
         AND csr.responded_at >= now() - interval '90 days'
    ), 0)                                         AS flag_count_90d;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_my_suspension() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_my_suspension() TO authenticated;
