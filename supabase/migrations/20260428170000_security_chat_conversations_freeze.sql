-- Privacy hole found in chat RLS audit: any existing participant of a
-- chat_conversations row can UPDATE participant_user_ids to add a
-- third user. The SELECT policy gates on auth.uid() = ANY(...), so the
-- newly-added user immediately reads the entire prior message history.
--
-- Two parts to the fix:
--
-- 1. CHECK constraint enforcing peer chats only — exactly two distinct
--    participants. The current UI never produces anything else, but
--    REST clients could. chat_conversations is empty today so adding
--    the constraint is safe.
--
-- 2. BEFORE UPDATE trigger that freezes the identity columns
--    (participant_user_ids, related_entity_type, related_entity_id,
--    created_at). The mutable columns (last_message, last_message_at)
--    are still updateable so the message-insert trigger keeps working.

ALTER TABLE public.chat_conversations
  ADD CONSTRAINT chat_conversations_two_distinct_participants
  CHECK (
    array_length(participant_user_ids, 1) = 2
    AND participant_user_ids[1] <> participant_user_ids[2]
  );

CREATE OR REPLACE FUNCTION public.chat_conversations_freeze_identity()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.participant_user_ids IS DISTINCT FROM OLD.participant_user_ids THEN
    RAISE EXCEPTION 'participant_user_ids is immutable on chat_conversations';
  END IF;
  IF NEW.related_entity_type IS DISTINCT FROM OLD.related_entity_type THEN
    RAISE EXCEPTION 'related_entity_type is immutable on chat_conversations';
  END IF;
  IF NEW.related_entity_id IS DISTINCT FROM OLD.related_entity_id THEN
    RAISE EXCEPTION 'related_entity_id is immutable on chat_conversations';
  END IF;
  IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'created_at is immutable on chat_conversations';
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'id is immutable on chat_conversations';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_conversations_freeze_identity_trg ON public.chat_conversations;
CREATE TRIGGER chat_conversations_freeze_identity_trg
  BEFORE UPDATE ON public.chat_conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_conversations_freeze_identity();

REVOKE ALL ON FUNCTION public.chat_conversations_freeze_identity() FROM PUBLIC;
