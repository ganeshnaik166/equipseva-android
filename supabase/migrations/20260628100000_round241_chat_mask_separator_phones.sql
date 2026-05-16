-- Round 241 — tighten chat-PII regex to mask separator-style phones.
--
-- The PR-D46/D50 mask uses `(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}` which
-- requires 10 *consecutive* digits. Trivial bypass: type the number
-- with internal whitespace, dots, or dashes ("9876 543 210" /
-- "98-7654-3210" / "9.8.7.6.5.4.3.2.1.0"). On-device QA confirmed
-- the bypass surfaces both on chat_messages (sender's view) and on
-- chat_conversations.last_message (recipient's inbox preview).
--
-- Fix: allow zero-or-one whitespace / dot / dash between each digit
-- in the 10-digit run. Same regex pattern applied to both triggers
-- so the message body and the conversation preview stay in sync.
--
-- Tradeoff: a 13-digit account number now matches its first 10
-- digits. Acceptable — leaking the first 10 digits of a longer
-- bank number is not actionable, and legitimate account refs in
-- biomedical chat typically include words ("acct", "invoice") that
-- aren't disrupted.

CREATE OR REPLACE FUNCTION public.chat_messages_mask_pii()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_phone_re constant text := '(?:\+?\s?91[\s.\-]?|0)?[6-9](?:[\s.\-]?\d){9}';
  v_email_re constant text := '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
  v_replacement constant text := '[contact removed — keep on EquipSeva]';

  v_orig text;
  v_masked text;
  v_kinds text[] := ARRAY[]::text[];
  v_count int := 0;
  v_phone_hits int := 0;
  v_email_hits int := 0;
BEGIN
  v_orig := COALESCE(NEW.message, '');
  IF v_orig = '' THEN RETURN NEW; END IF;
  v_masked := v_orig;

  SELECT count(*) INTO v_phone_hits
    FROM regexp_matches(v_masked, v_phone_re, 'g');
  IF v_phone_hits > 0 THEN
    v_masked := regexp_replace(v_masked, v_phone_re, v_replacement, 'g');
    v_kinds := array_append(v_kinds, 'phone');
    v_count := v_count + v_phone_hits;
  END IF;

  SELECT count(*) INTO v_email_hits
    FROM regexp_matches(v_masked, v_email_re, 'g');
  IF v_email_hits > 0 THEN
    v_masked := regexp_replace(v_masked, v_email_re, v_replacement, 'g');
    v_kinds := array_append(v_kinds, 'email');
    v_count := v_count + v_email_hits;
  END IF;

  IF v_count > 0 THEN
    NEW.message := v_masked;
    INSERT INTO public.chat_message_moderation_events (
      conversation_id, sender_user_id, original_excerpt, matched_kinds, masked_count
    ) VALUES (
      NEW.conversation_id,
      NEW.sender_user_id,
      LEFT(v_orig, 200),
      v_kinds,
      v_count
    );
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.chat_messages_mask_pii() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.chat_messages_mask_pii() FROM PUBLIC;

-- Same separator-aware regex on the conversation-preview trigger.
CREATE OR REPLACE FUNCTION public.chat_conversations_mask_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_phone_re constant text := '(?:\+?\s?91[\s.\-]?|0)?[6-9](?:[\s.\-]?\d){9}';
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

-- Backfill: scrub existing rows the older regex missed. Triggers
-- on subsequent writes will re-mask on their own, but explicit
-- backfill closes the historical exposure window.
UPDATE public.chat_messages
SET message = regexp_replace(
  message,
  '(?:\+?\s?91[\s.\-]?|0)?[6-9](?:[\s.\-]?\d){9}',
  '[contact removed — keep on EquipSeva]',
  'g'
)
WHERE message ~ '[6-9](?:[\s.\-]?\d){9}'
  AND message !~ '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}';

UPDATE public.chat_conversations
SET last_message = regexp_replace(
  last_message,
  '(?:\+?\s?91[\s.\-]?|0)?[6-9](?:[\s.\-]?\d){9}',
  '[contact removed — keep on EquipSeva]',
  'g'
)
WHERE last_message ~ '[6-9](?:[\s.\-]?\d){9}'
  AND last_message !~ '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}';
