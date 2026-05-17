-- Round 317 — also notify the assigned engineer when an AMC contract
-- is heading into the renewal window.
--
-- Round 313 inserted a single notification keyed on hospital_user_id
-- and routed the hospital to the renew flow. The engineer was left
-- out — but they own the visit schedule that's about to pause, and
-- can proactively follow up with the hospital to keep the contract
-- active. Two-sided coordination beats a hospital-only nudge.
--
-- Engineer-facing notification reuses the same `amc_renewal_due`
-- kind so the existing deep-link routing (round 313) lands them on
-- contract detail — which already renders an engineer-side view via
-- AmcDetailViewModel.engineerView. No new client routing needed.
--
-- Idempotency: the same last_renewal_notification_at column on
-- amc_contracts continues to gate the scan. Both notifications fire
-- inside the same loop iteration so they're atomic per contract.

CREATE OR REPLACE FUNCTION public.notify_expiring_amc_contracts()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract record;
  v_engineer_user_id uuid;
  v_count int := 0;
BEGIN
  FOR v_contract IN
    SELECT id, hospital_user_id, primary_engineer_id, end_date,
           monthly_fee_rupees, renewal_term_months
      FROM public.amc_contracts
     WHERE status = 'active'
       AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
       AND last_renewal_notification_at IS NULL
     FOR UPDATE SKIP LOCKED
  LOOP
    -- Hospital side: "your contract is expiring, renew now".
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      v_contract.hospital_user_id,
      'amc_renewal_due',
      'AMC renewal due soon',
      'Your AMC contract expires on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Tap to renew before service pauses.',
      jsonb_build_object(
        'amc_contract_id', v_contract.id,
        'end_date',        v_contract.end_date,
        'amount_rupees',   (v_contract.monthly_fee_rupees
                              * v_contract.renewal_term_months)::numeric(10,2)
      )
    );

    -- Engineer side: "your hospital's contract is expiring, follow up".
    -- engineers.id != engineers.user_id; resolve user_id first.
    SELECT e.user_id
      INTO v_engineer_user_id
      FROM public.engineers e
     WHERE e.id = v_contract.primary_engineer_id;

    IF v_engineer_user_id IS NOT NULL THEN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_engineer_user_id,
        'amc_renewal_due',
        'Hospital AMC renewal due',
        'A hospital you serve has an AMC expiring on '
          || to_char(v_contract.end_date, 'DD Mon YYYY')
          || '. Follow up so the contract doesn''t lapse.',
        jsonb_build_object(
          'amc_contract_id', v_contract.id,
          'end_date',        v_contract.end_date
        )
      );
    END IF;

    UPDATE public.amc_contracts
       SET last_renewal_notification_at = now()
     WHERE id = v_contract.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

ALTER FUNCTION public.notify_expiring_amc_contracts() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_expiring_amc_contracts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_expiring_amc_contracts() TO service_role;

COMMENT ON FUNCTION public.notify_expiring_amc_contracts() IS
  'Scans active AMC contracts expiring in the next 7 days that '
  'haven''t been alerted yet, inserts amc_renewal_due notifications '
  'for BOTH the hospital and the primary engineer (round 317), and '
  'sets last_renewal_notification_at to gate re-fire. v1: hospital '
  'manually renews via create_amc_contract; v2 will swap for an '
  'auto-charge worker once Razorpay subscriptions land.';
