-- Round 392 — partial index for r373 admin_amc_paused.
--
-- The RPC scans amc_contracts WHERE status='paused' ORDER BY updated_at DESC.
-- Existing indexes:
--   amc_contracts_hospital_status_idx (hospital_user_id, status)
--   amc_contracts_engineer_status_idx (primary_engineer_id, status)
--   amc_contracts_renewal_notify_idx  (end_date) WHERE status='active' AND...
--   amc_contracts_active_end_date_idx (end_date) WHERE status='active' [r365]
-- None lead with status='paused' or order by updated_at, so the
-- founder paused drilldown seq-scans the whole table.
--
-- Pair r373 with a partial index following the r358/r359/r365 pattern.

CREATE INDEX IF NOT EXISTS amc_contracts_paused_updated_at_idx
  ON public.amc_contracts (updated_at DESC)
  WHERE status = 'paused';
