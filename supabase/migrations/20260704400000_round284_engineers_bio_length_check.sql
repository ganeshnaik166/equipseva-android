-- Round 284 — cap engineers.bio length server-side.
--
-- engineers.bio is the long-form "About me" blurb the engineer writes
-- in their public profile (rendered on engineer-directory cards + the
-- hospital's engineer detail screen). The column is `text` with no
-- length bound. EngineerProfileViewModel.onBioChange clamps the
-- TextField at 1500 chars but the repository forwards `bio = bio`
-- verbatim — a non-UI caller (Postman, third-party script, mis-typed
-- direct postgrest) can ship a multi-MB blob and persist it. The
-- engineer-directory card then either renders the blob inline or
-- silently truncates client-side.
--
-- Bound at 1500 chars to match the existing UI clamp + give a hard
-- server backstop. Same row-boundary cap pattern as rounds 268 /
-- 276 / 281 / 283.
--
-- The engineers table is managed in Supabase but ALTER TABLE on it
-- is exercised elsewhere in this migration directory
-- (e.g. 20260428070000_engineers_pan_number.sql), so the column is
-- guaranteed present in every environment where these migrations
-- apply.

ALTER TABLE public.engineers
  DROP CONSTRAINT IF EXISTS engineers_bio_length_chk;

ALTER TABLE public.engineers
  ADD CONSTRAINT engineers_bio_length_chk
    CHECK (bio IS NULL OR char_length(bio) <= 1500);
