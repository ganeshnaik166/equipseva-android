-- Round 264 — extend chat-PII mask to cover Aadhaar + PAN.
--
-- Existing chat_messages_mask_pii (PR-D46/D50, separator-aware
-- update in PR #688) handled Indian mobile numbers + email. Two
-- equally-sensitive DPDP categories slipped past:
--
--   • Aadhaar — 12 digits. Most commonly typed in spaced groups
--     of 4 ("1234 5678 9012") on support chats where users paste
--     it from their physical card or e-Aadhaar PDF.
--
--   • PAN — fixed format `[A-Z]{5}[0-9]{4}[A-Z]` (5 letters, 4
--     digits, 1 letter). Highly distinctive — minimal false-positive
--     surface vs the 12-digit Aadhaar pattern.
--
-- Both are added to the same regex pipeline (run after the phone +
-- email passes) so a single message can carry all four kinds and
-- get scrubbed correctly. Backfill UPDATEs scrub historical rows
-- the older mask missed.
--
-- Same patterns applied to chat_conversations_mask_last_message
-- so the inbox preview stays in sync with the message body.

CREATE OR REPLACE FUNCTION public.chat_messages_mask_pii()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_phone_re constant text := '(?:\+?\s?91[\s.\-]?|0)?[6-9](?:[\s.\-]?\d){9}';
  v_email_re constant text := '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
  -- Aadhaar: 12 digits in groups of 4 with optional space/hyphen.
  -- Anchored on a non-digit boundary to avoid eating the leading
  -- digit of a longer number into the match.
  v_aadhaar_re constant text := '\m\d{4}[\s.\-]?\d{4}[\s.\-]?\d{4}\M';
  -- PAN: fixed [A-Z]{5}[0-9]{4}[A-Z]. Word boundaries keep it
  -- from matching inside random alphanumeric blobs.
  v_pan_re constant text := '\m[A-Z]{5}[0-9]{4}[A-Z]\M';
  v_replacement constant text := '[contact removed — keep on EquipSeva]';

  v_orig text;
  v_masked text;
  v_kinds text[] := ARRAY[]::text[];
  v_count int := 0;
  v_phone_hits int := 0;
  v_email_hits int := 0;
  v_aadhaar_hits int := 0;
  v_pan_hits int := 0;
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

  SELECT count(*) INTO v_aadhaar_hits
    FROM regexp_matches(v_masked, v_aadhaar_re, 'g');
  IF v_aadhaar_hits > 0 THEN
    v_masked := regexp_replace(v_masked, v_aadhaar_re, v_replacement, 'g');
    v_kinds := array_append(v_kinds, 'aadhaar');
    v_count := v_count + v_aadhaar_hits;
  END IF;

  SELECT count(*) INTO v_pan_hits
    FROM regexp_matches(v_masked, v_pan_re, 'g');
  IF v_pan_hits > 0 THEN
    v_masked := regexp_replace(v_masked, v_pan_re, v_replacement, 'g');
    v_kinds := array_append(v_kinds, 'pan');
    v_count := v_count + v_pan_hits;
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

-- Same patterns on the conversation-preview trigger.
CREATE OR REPLACE FUNCTION public.chat_conversations_mask_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_phone_re constant text := '(?:\+?\s?91[\s.\-]?|0)?[6-9](?:[\s.\-]?\d){9}';
  v_email_re constant text := '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
  v_aadhaar_re constant text := '\m\d{4}[\s.\-]?\d{4}[\s.\-]?\d{4}\M';
  v_pan_re constant text := '\m[A-Z]{5}[0-9]{4}[A-Z]\M';
  v_replacement constant text := '[contact removed — keep on EquipSeva]';
BEGIN
  IF NEW.last_message IS NULL OR NEW.last_message = '' THEN
    RETURN NEW;
  END IF;
  NEW.last_message := regexp_replace(NEW.last_message, v_phone_re,   v_replacement, 'g');
  NEW.last_message := regexp_replace(NEW.last_message, v_email_re,   v_replacement, 'g');
  NEW.last_message := regexp_replace(NEW.last_message, v_aadhaar_re, v_replacement, 'g');
  NEW.last_message := regexp_replace(NEW.last_message, v_pan_re,     v_replacement, 'g');
  RETURN NEW;
END;
$$;

-- Backfill: scrub Aadhaar/PAN in existing rows the older mask missed.
UPDATE public.chat_messages
SET message = regexp_replace(
  regexp_replace(
    message,
    '\m\d{4}[\s.\-]?\d{4}[\s.\-]?\d{4}\M',
    '[contact removed — keep on EquipSeva]',
    'g'
  ),
  '\m[A-Z]{5}[0-9]{4}[A-Z]\M',
  '[contact removed — keep on EquipSeva]',
  'g'
)
WHERE message ~ '\m\d{4}[\s.\-]?\d{4}[\s.\-]?\d{4}\M'
   OR message ~ '\m[A-Z]{5}[0-9]{4}[A-Z]\M';

UPDATE public.chat_conversations
SET last_message = regexp_replace(
  regexp_replace(
    last_message,
    '\m\d{4}[\s.\-]?\d{4}[\s.\-]?\d{4}\M',
    '[contact removed — keep on EquipSeva]',
    'g'
  ),
  '\m[A-Z]{5}[0-9]{4}[A-Z]\M',
  '[contact removed — keep on EquipSeva]',
  'g'
)
WHERE last_message ~ '\m\d{4}[\s.\-]?\d{4}[\s.\-]?\d{4}\M'
   OR last_message ~ '\m[A-Z]{5}[0-9]{4}[A-Z]\M';
