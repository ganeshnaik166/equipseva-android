-- v2.1 PR-D51 — close chat-list PII leak.
--
-- chat_messages_mask_pii (PR-D46/D50) masks phone+email in
-- chat_messages.message before insert. But the Android client
-- ALSO mirrors the raw message text into chat_conversations.last_message
-- right after insert (SupabaseChatRepository.sendMessage). The mask
-- trigger doesn't fire on chat_conversations, so the conversation list
-- preview shows raw "9876543210 / test@gmail.com" — verified on-device
-- 2026-05-08 e2e QA (hospital Messages tab, "Ravi Kumar" preview).
--
-- Fix: BEFORE INSERT/UPDATE trigger on chat_conversations that applies
-- the same regex mask to NEW.last_message. Defense in depth — even if
-- a future client (or REST caller) writes raw PII, server-side
-- enforcement guarantees the list preview never exposes it.
--
-- We don't re-emit a moderation audit row here because the matching
-- chat_messages INSERT already produced one via chat_messages_mask_pii.

CREATE OR REPLACE FUNCTION public.chat_conversations_mask_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_phone_re constant text := '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}';
  v_email_re constant text := '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
  v_replacement constant text := '[contact removed — keep on EquipSeva]';
BEGIN
  IF NEW.last_message IS NULL OR NEW.last_message = '' THEN
    RETURN NEW;
  END IF;
  NEW.last_message := regexp_replace(NEW.last_message, v_phone_re, v_replacement, 'g');
  NEW.last_message := regexp_replace(NEW.last_message, v_email_re, v_replacement, 'g');
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.chat_conversations_mask_last_message() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.chat_conversations_mask_last_message() FROM PUBLIC;

DROP TRIGGER IF EXISTS chat_conversations_mask_last_message_trg
  ON public.chat_conversations;
CREATE TRIGGER chat_conversations_mask_last_message_trg
  BEFORE INSERT OR UPDATE OF last_message ON public.chat_conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_conversations_mask_last_message();

-- Backfill: scrub any existing rows that already have raw PII in the
-- preview column. Same regex applied directly via UPDATE — the new
-- trigger will re-mask on its own write but the explicit update is
-- self-documenting and avoids a no-op churn pass.
UPDATE public.chat_conversations
SET last_message = regexp_replace(
  regexp_replace(
    last_message,
    '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}',
    '[contact removed — keep on EquipSeva]',
    'g'
  ),
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  '[contact removed — keep on EquipSeva]',
  'g'
)
WHERE last_message ~ '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}'
   OR last_message ~ '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
