-- Round 365 — partial index pairing with round 364 admin_amc_expiring_soon:
--
--   WHERE status = 'active'
--     AND end_date >= current_date
--     AND end_date <= current_date + interval '30 days'
--   ORDER BY end_date ASC
--
-- Existing indexes:
--   amc_contracts_renewal_notify_idx (end_date) WHERE status='active'
--     AND renewal_notifications_sent < 3
--     — close but only includes contracts with pending notification
--       stages; round-364 drill-down also lists contracts whose stages
--       have all fired (founder still wants visibility on those).
--   amc_contracts_hospital_status_idx / amc_contracts_engineer_status_idx
--     — keyed by user_id, no help for the date-range scan.
--
-- Add a broader partial keyed by end_date alone, scoped to active.
-- Pays off the moment AMC volume reaches a few hundred contracts.

CREATE INDEX IF NOT EXISTS amc_contracts_active_end_date_idx
  ON public.amc_contracts (end_date)
  WHERE status = 'active';
