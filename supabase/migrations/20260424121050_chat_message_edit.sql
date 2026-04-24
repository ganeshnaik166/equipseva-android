-- Chat message edit.
--
-- Adds a nullable edited_at timestamp column to public.chat_messages and
-- exposes a SECURITY DEFINER RPC that lets the sender update their own
-- message body within 15 minutes of sending it. The UI renders an
-- "(edited)" tag whenever edited_at is non-null.
--
-- Same pattern as delete_my_chat_message: Postgres RLS cannot constrain
-- which columns an UPDATE touches, so we route edits through a definer
-- function that pins the column set (message, edited_at), the ownership
-- check (sender_user_id = auth.uid()), the body length guard, and the
-- 15-minute window.

alter table public.chat_messages
    add column if not exists edited_at timestamptz;

create or replace function public.edit_my_chat_message(
    p_message_id uuid,
    p_new_body text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    v_uid uuid := auth.uid();
    v_len int;
    v_updated int;
begin
    if v_uid is null then
        raise exception 'not_authenticated' using errcode = '42501';
    end if;

    v_len := char_length(coalesce(p_new_body, ''));
    if v_len < 1 or v_len > 4000 then
        raise exception 'invalid_body_length'
            using errcode = '22023',
                  message = 'Message body must be 1..4000 characters';
    end if;

    update public.chat_messages
       set message = p_new_body,
           edited_at = now()
     where id = p_message_id
       and sender_user_id = v_uid
       and deleted_at is null
       and created_at > now() - interval '15 minutes';

    get diagnostics v_updated = row_count;

    if v_updated = 0 then
        raise exception 'Cannot edit: too old or not your message'
            using errcode = '42501';
    end if;
end;
$$;

revoke all on function public.edit_my_chat_message(uuid, text) from public;
grant execute on function public.edit_my_chat_message(uuid, text) to authenticated;
