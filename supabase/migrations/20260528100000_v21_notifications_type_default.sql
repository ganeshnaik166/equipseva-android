-- v2.1 P0 hotfix: notifications.notification_type DEFAULT.
--
-- Discovered while smoking PR-D15 on-device 2026-05-06: notifications
-- table sat at zero rows even though PR #250 (rate prompts), PR #251
-- (cost-revision lifecycle), PR-D1 (cash_survey), PR-D8
-- (amc_loyal_pair_nudge), PR-D9 (warranty_covered), PR-D11
-- (engineer_auto_suspended), PR-D12 (warranty_fee_waived) all ship
-- AFTER UPDATE triggers that INSERT into the table.
--
-- Root cause: every trigger inserts (user_id, kind, title, body, data)
-- without setting notification_type, but notification_type is NOT NULL
-- with no default. Each insert raises 23502, the trigger's
-- EXCEPTION WHEN OTHERS clause swallows it as a NOTICE, and the row is
-- silently dropped. App reads from public.notifications → empty inbox.
-- Every push trigger has been a no-op since PR #250 landed.
--
-- Fix path chosen: add a DEFAULT 'push' to notification_type. Two
-- alternatives considered:
--   A) Add notification_type='push' to every trigger function INSERT
--      → touches ~15 trigger functions across multiple PRs. Surgical
--      but high-risk, and any future trigger PR forgetting the column
--      goes silent again.
--   B) Drop the NOT NULL → makes the column meaningless; some readers
--      key off it.
--   C) DEFAULT 'push' (chosen) → triggers + future code keep working
--      unchanged; admin / direct inserts that DO supply a value still
--      win. Minimal blast radius.
--
-- No backfill — historical "notifications that should have fired" are
-- gone (the triggers are AFTER UPDATE, not idempotent on re-run for
-- arbitrary rows). Going forward only. Users will see new
-- notifications start landing after this migration ships.

ALTER TABLE public.notifications
  ALTER COLUMN notification_type SET DEFAULT 'push';

-- Backfill (defensive): if any future trigger forgot to set it, our
-- DEFAULT covers them. Existing rows are already non-null by definition
-- of the NOT NULL constraint — nothing to fix there.

COMMENT ON COLUMN public.notifications.notification_type IS
  'Channel-shape tag (push/email/in_app). DEFAULT push so trigger inserts that supply only kind+title+body+data succeed without 23502.';
