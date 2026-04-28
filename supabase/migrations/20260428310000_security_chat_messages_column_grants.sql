-- chat_messages UPDATE policy "recipient can mark read" intends only
-- to let the receiver flip is_read from false → true on inbound
-- messages. But the policy doesn't restrict columns and the default
-- table-level UPDATE grant on authenticated covers every column —
-- including `message` and `attachments`. So a recipient could direct-
-- REST `UPDATE chat_messages SET message='hijacked' WHERE id=...
-- AND auth.uid() <> sender_user_id` and silently rewrite the
-- sender's content; the SELECT side then renders the spoofed text.
--
-- Edit + delete legitimately go through edit_my_chat_message /
-- delete_my_chat_message — both SECURITY DEFINER so they run as the
-- function owner and bypass column-level grants. Lock the column-
-- grant to is_read only; recipients still mark read, senders still
-- edit/delete via the DEFINER RPCs.

REVOKE UPDATE ON public.chat_messages FROM anon, authenticated;
GRANT  UPDATE (is_read) ON public.chat_messages TO authenticated;
