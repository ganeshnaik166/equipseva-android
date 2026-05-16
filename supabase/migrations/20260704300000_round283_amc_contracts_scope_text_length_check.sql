-- Round 283 — cap amc_contracts.scope_text length server-side.
--
-- 20260509100000_v21_amc_contracts_schema.sql declared scope_text as
-- `text` with no length bound. The create-AMC wizard
-- (CreateAmcWizardScreen.kt setScopeText) also forwards the typed
-- value into the create_amc_contract RPC with no UI cap. A hospital
-- (or a malicious caller bypassing the wizard) can ship a multi-MB
-- string into the column and it persists in full.
--
-- Bound at 4000 chars: large enough for a thorough "what's covered"
-- write-up (a few paragraphs); rejecting beyond that catches paste
-- bombs without blocking real customers.
--
-- Same row-boundary capping pattern as round 281 (user_addresses) and
-- rounds 268 (dispute reason / engineer response) / 276 (ContentReport
-- notes).
--
-- NOTE: the cancel_amc_contract RPC (line 392 of the original
-- migration) appends the cancellation reason onto scope_text via
-- `coalesce(scope_text, '') || ...`. Concatenated strings can blow
-- the cap mid-flight. The cap is generous enough (4000) that this
-- isn't a practical concern, but the cancellation reason is itself
-- already bounded by the RPC's `coalesce` + admin-only callers, so
-- a deliberate breach via cancel-loop would require admin access.

ALTER TABLE public.amc_contracts
  DROP CONSTRAINT IF EXISTS amc_contracts_scope_text_length_chk;

ALTER TABLE public.amc_contracts
  ADD CONSTRAINT amc_contracts_scope_text_length_chk
    CHECK (scope_text IS NULL OR char_length(scope_text) <= 4000);
