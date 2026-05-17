-- Round 313 — v1 AMC renewal notifier.
--
-- Context: auto_renew_expiring_amc_contracts() enqueues renewal
-- attempts but no worker drains them (would need Razorpay
-- subscriptions / saved mandates — out of scope for v1, since v1
-- is free / no take rate and hospitals pay each contract once).
--
-- For v1: instead of auto-charging, notify the hospital that their
-- AMC is about to expire so they can manually renew through the
-- existing create_amc_contract flow. Hospital-acceptable, no Razorpay
-- subscriptions API needed.
--
-- Idempotency: a new column `last_renewal_notification_at` on
-- amc_contracts gates the scan — only notify once per 7-day window.
-- A contract entering the 7-day pre-expiry window gets one alert.
-- (If they ignore it we let it expire; subsequent windows for the
-- same contract are blocked by the column staying set.)

ALTER TABLE public.amc_contracts
  ADD COLUMN IF NOT EXISTS last_renewal_notification_at timestamptz;

-- Index supports the scan: contracts expiring in next 7d that haven't
-- been notified yet.
CREATE INDEX IF NOT EXISTS amc_contracts_renewal_notify_idx
  ON public.amc_contracts (end_date)
  WHERE status = 'active'
    AND last_renewal_notification_at IS NULL;

-- ---------------------------------------------------------------
-- notify_expiring_amc_contracts — scheduled daily by cron-tick.
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_expiring_amc_contracts()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract record;
  v_count int := 0;
BEGIN
  FOR v_contract IN
    SELECT id, hospital_user_id, end_date, monthly_fee_rupees, renewal_term_months
      FROM public.amc_contracts
     WHERE status = 'active'
       AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
       AND last_renewal_notification_at IS NULL
     FOR UPDATE SKIP LOCKED
  LOOP
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
  'Scans active AMC contracts expiring in the next 7 days that haven''t '
  'been alerted yet, inserts an amc_renewal_due notification per row, '
  'and sets last_renewal_notification_at so the same contract isn''t '
  'notified twice. v1: hospital manually renews via create_amc_contract; '
  'v2 will swap this for an auto-charge worker once Razorpay subscriptions '
  'and saved mandates are wired.';
