-- Round 289 — server-side length CHECK on profiles.full_name + phone.
--
-- profiles is the most-touched table in the schema. full_name and
-- phone are user-editable via ProfileRepository.updateBasicInfo (from
-- AddPhoneScreen, ProfileScreen, address-form auto-sync), but neither
-- column has a length bound:
--
--   * full_name is `text` with no CHECK. Display sites (header,
--     engineer directory cards, chat preview) render the raw value.
--   * phone is `text` with no CHECK. Format is validated client-side
--     (AddPhoneScreen.onSave requires E.164 starts-with-+ and length
--     >= 11) but the validator is purely client.
--
-- A non-UI caller (Postman, scripts) can persist multi-MB strings
-- into either field. The chat preview / directory cards then either
-- render the blob inline or get truncated by Compose mid-render —
-- the engineer directory cards have wedged in QA more than once
-- from a long-name account at row 0.
--
-- Bounds chosen:
--   full_name <= 200  (mirrors the user_addresses full_name cap added
--                       in round 281; standard postal payload upper)
--   phone     <= 20   (mirrors the user_addresses phone cap added
--                       in 20260426030000; E.164 max is 15 chars +
--                       buffer for "+" + odd formats)
--
-- Idempotent: drop-if-exists before each ADD so a re-apply after a
-- schema reset stays clean.

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_full_name_length_chk,
  DROP CONSTRAINT IF EXISTS profiles_phone_length_chk;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_full_name_length_chk
    CHECK (full_name IS NULL OR char_length(full_name) <= 200),
  ADD CONSTRAINT profiles_phone_length_chk
    CHECK (phone IS NULL OR char_length(phone) <= 20);
