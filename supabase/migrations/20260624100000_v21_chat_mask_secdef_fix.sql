-- v2.1 PR-D50 — fix on-device-found bug in chat_messages_mask_pii.
--
-- The PR-D46 trigger function inserts into chat_message_moderation_events
-- whenever a message contains a masked phone/email. PR-D46 also revoked
-- INSERT on chat_message_moderation_events from authenticated/anon/public
-- so users can't pollute the audit log directly.
--
-- The trigger is NOT SECURITY DEFINER, which means it runs as the calling
-- role (authenticated). The trigger's INSERT into the locked-down audit
-- table therefore raises 42501, which rolls back the parent
-- chat_messages INSERT — meaning any message containing a phone or email
-- silently disappears (queued in app outbox forever).
--
-- Fix: ALTER FUNCTION ... SECURITY DEFINER + OWNER TO postgres so the
-- audit insert runs with elevated privileges and bypasses the RLS on
-- chat_message_moderation_events. Function body is the post-PR-D49
-- version verbatim — only auth scope changes.

CREATE OR REPLACE FUNCTION public.chat_messages_mask_pii()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_phone_re constant text := '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}';
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
