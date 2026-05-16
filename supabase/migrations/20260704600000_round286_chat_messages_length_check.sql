-- Round 286 — cap chat_messages.message length server-side.
--
-- chat_messages is one of the older tables in the schema (predates
-- this migration directory's full coverage; ALTERs to it appear in
-- 20260424113451 / 20260424121050 / 20260428310000). The message
-- column is unbounded `text`. PR #710 (round 262) capped the chat
-- draft at 4000 chars in the ChatViewModel, but the constraint
-- lives only on the client. A non-UI caller (Postman, scripts) can
-- POST a multi-MB body into the column; the realtime channel then
-- broadcasts the whole blob to every participant.
--
-- Bound at 4000 chars to match the client clamp. Same row-boundary
-- capping pattern as rounds 268 / 276 / 281 / 283 / 284.
--
-- Idempotent: drop-if-exists before the add so a re-apply after a
-- schema reset stays clean. `message IS NULL` carve-out preserves
-- the soft-delete + attachments-only paths that store NULL.

ALTER TABLE public.chat_messages
  DROP CONSTRAINT IF EXISTS chat_messages_message_length_chk;

ALTER TABLE public.chat_messages
  ADD CONSTRAINT chat_messages_message_length_chk
    CHECK (message IS NULL OR char_length(message) <= 4000);
