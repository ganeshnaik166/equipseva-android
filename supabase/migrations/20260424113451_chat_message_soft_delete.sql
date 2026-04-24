-- Chat message soft delete.
--
-- Adds a nullable deleted_at column to public.chat_messages and exposes a
-- SECURITY DEFINER RPC that lets the sender tombstone their own message.
-- The row is preserved (so message ordering / realtime cursors remain
-- stable), but the body is blanked and attachments cleared so clients can
-- render a "Message deleted" placeholder.
--
-- Why an RPC instead of a straight UPDATE RLS policy: Postgres RLS has no
-- built-in way to restrict *which columns* an UPDATE may touch. Routing
-- deletion through a definer function lets us pin the exact column set
-- (deleted_at, message, attachments) and the exact ownership check
-- (sender_user_id = auth.uid()) in one place.

alter table public.chat_messages
    add column if not exists deleted_at timestamptz;

create or replace function public.delete_my_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    v_uid uuid := auth.uid();
    v_updated int;
begin
    if v_uid is null then
        raise exception 'not_authenticated' using errcode = '42501';
    end if;

    update public.chat_messages
       set deleted_at = now(),
           message = '',
           attachments = null
     where id = p_message_id
       and sender_user_id = v_uid
       and deleted_at is null;

    get diagnostics v_updated = row_count;

    if v_updated = 0 then
        raise exception 'delete_not_allowed_or_already_deleted'
            using errcode = '42501';
    end if;
end;
$$;

revoke all on function public.delete_my_chat_message(uuid) from public;
grant execute on function public.delete_my_chat_message(uuid) to authenticated;
