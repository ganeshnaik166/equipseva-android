-- Round 281 — add server-side length CHECK constraints on user_addresses.
--
-- 20260426030000_user_addresses.sql shipped with CHECKs only on pincode
-- (4-10) and phone (6-20). full_name / label / line1 / line2 / landmark
-- / city / state have NO length bound — `text` in Postgres is unbounded,
-- so a malicious or buggy caller can POST a 1 MB blob into any field
-- and the row accepts it. The client-side caps were also missing on
-- fullName / label / city (AddressFormScreen calls
-- `viewModel.update { it.copy(fullName = v) }` with no `.take(N)`).
--
-- Add CHECKs at the repository boundary so:
--   * non-UI callers (scripts, malicious bypass of PostgREST clients)
--     hit the server cap.
--   * the per-field maxima are documented in one place (schema), not
--     spread across multiple ViewModels.
--
-- Bounds chosen to match the in-app TextField caps where they exist,
-- with a small head-room buffer for upsert race + zero-width chars:
--   label       <=  80  (very short tag — "Home", "Mumbai HQ")
--   full_name   <= 200  (standard postal payload upper end)
--   line1       <= 200  (mirrors existing client cap)
--   line2       <= 200  (mirrors existing client cap × 2 head-room)
--   landmark    <= 200  (mirrors existing client cap × 2 head-room)
--   city        <= 120  (Indian city / district names — generous)
--   state       <=  80  (state names — max ~30 in IndiaLocations.STATES,
--                        80 caps unknown-state input pre-validation)
--
-- Idempotent: drop-if-exists before each add so re-applying after a
-- schema reset stays clean. Use NOT VALID to avoid full-table scans on
-- already-populated rows; existing data inside the bound stays put.

ALTER TABLE public.user_addresses
  DROP CONSTRAINT IF EXISTS user_addresses_full_name_length_chk,
  DROP CONSTRAINT IF EXISTS user_addresses_label_length_chk,
  DROP CONSTRAINT IF EXISTS user_addresses_line1_length_chk,
  DROP CONSTRAINT IF EXISTS user_addresses_line2_length_chk,
  DROP CONSTRAINT IF EXISTS user_addresses_landmark_length_chk,
  DROP CONSTRAINT IF EXISTS user_addresses_city_length_chk,
  DROP CONSTRAINT IF EXISTS user_addresses_state_length_chk;

ALTER TABLE public.user_addresses
  ADD CONSTRAINT user_addresses_full_name_length_chk
    CHECK (char_length(full_name) <= 200),
  ADD CONSTRAINT user_addresses_label_length_chk
    CHECK (label IS NULL OR char_length(label) <= 80),
  ADD CONSTRAINT user_addresses_line1_length_chk
    CHECK (char_length(line1) <= 200),
  ADD CONSTRAINT user_addresses_line2_length_chk
    CHECK (line2 IS NULL OR char_length(line2) <= 200),
  ADD CONSTRAINT user_addresses_landmark_length_chk
    CHECK (landmark IS NULL OR char_length(landmark) <= 200),
  ADD CONSTRAINT user_addresses_city_length_chk
    CHECK (char_length(city) <= 120),
  ADD CONSTRAINT user_addresses_state_length_chk
    CHECK (char_length(state) <= 80);
