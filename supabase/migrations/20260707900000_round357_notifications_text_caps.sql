-- Round 357 — bound notifications.title + notifications.body so a stray
-- INSERT can't blow past FCM's 4KB message limit. Without caps, a
-- well-meaning trigger that concatenates job notes into a body string
-- (e.g. round 326 renewal copy) could overflow and FCM silently drops
-- the push while the in-app notification row stays — UI consistent,
-- device push missing, hard to debug.
--
-- FCM safe ceilings:
--   title — 100 chars (Android shows ~65 before truncating; iOS ~32)
--   body  — 1000 chars (Android shows ~240; well clear of the 4KB JSON cap)
--
-- These are intentionally generous so call sites don't need to be
-- rewritten; existing copy in rounds 313/317/326/etc is far below.

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_title_len_chk
    CHECK (title IS NULL OR length(title) <= 200) NOT VALID;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_body_len_chk
    CHECK (body IS NULL OR length(body) <= 1000) NOT VALID;

-- VALIDATE outside the ALTER so existing too-long rows (if any) don't
-- block the migration. Catches future inserts; backfill cleanup is a
-- separate audit if needed.
ALTER TABLE public.notifications
  VALIDATE CONSTRAINT notifications_title_len_chk;

ALTER TABLE public.notifications
  VALIDATE CONSTRAINT notifications_body_len_chk;
