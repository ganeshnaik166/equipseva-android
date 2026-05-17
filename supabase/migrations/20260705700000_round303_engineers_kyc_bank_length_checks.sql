-- Round 303 — length CHECK on engineers KYC + bank text fields.
--
-- The trust-columns lockdown (20260428280000) grants engineers
-- INSERT/UPDATE on these columns within their own row:
--   aadhaar_number, pan_number, bank_account_number, bank_ifsc, upi_id
--
-- None have a length bound. Aadhaar is 12 digits, PAN is 10 ASCII
-- chars, IFSC is 11 chars, UPI ID is roughly <local>@<provider>
-- (RFC-ish, ~50 chars upper). Bank account number varies 9-18 digits
-- across Indian banks.
--
-- Add generous server-side length caps so a non-UI caller (Postman,
-- scripts) can't smuggle a multi-MB string into the engineer row.
-- Bounds chosen to comfortably fit real values + buffer:
--   aadhaar_number       <= 16   (12-digit max + 2 separators + buffer)
--   pan_number           <= 12   (10 chars + buffer)
--   bank_account_number  <= 30   (18-digit max + buffer)
--   bank_ifsc            <= 16   (11 chars + buffer)
--   upi_id               <= 100  (generous for VPA <local@provider>)
--
-- Same row-boundary capping pattern as rounds 268 / 281 / 283 / 284 /
-- 286 / 289 / 297. Format CHECK regexes (PAN ^[A-Z]{5}\d{4}[A-Z]$,
-- IFSC ^[A-Z]{4}0\d{6}$, Aadhaar Verhoeff) are deliberately not added
-- — client-side validators already enforce them and a server format
-- CHECK risks rejecting legacy / dashboard-created rows.

ALTER TABLE public.engineers
  DROP CONSTRAINT IF EXISTS engineers_aadhaar_number_length_chk,
  DROP CONSTRAINT IF EXISTS engineers_pan_number_length_chk,
  DROP CONSTRAINT IF EXISTS engineers_bank_account_number_length_chk,
  DROP CONSTRAINT IF EXISTS engineers_bank_ifsc_length_chk,
  DROP CONSTRAINT IF EXISTS engineers_upi_id_length_chk;

ALTER TABLE public.engineers
  ADD CONSTRAINT engineers_aadhaar_number_length_chk
    CHECK (aadhaar_number IS NULL OR char_length(aadhaar_number) <= 16),
  ADD CONSTRAINT engineers_pan_number_length_chk
    CHECK (pan_number IS NULL OR char_length(pan_number) <= 12),
  ADD CONSTRAINT engineers_bank_account_number_length_chk
    CHECK (bank_account_number IS NULL OR char_length(bank_account_number) <= 30),
  ADD CONSTRAINT engineers_bank_ifsc_length_chk
    CHECK (bank_ifsc IS NULL OR char_length(bank_ifsc) <= 16),
  ADD CONSTRAINT engineers_upi_id_length_chk
    CHECK (upi_id IS NULL OR char_length(upi_id) <= 100);
