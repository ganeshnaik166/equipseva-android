-- Device-token register / revoke as SECURITY DEFINER RPCs.
--
-- Migration 20260428320000_security_revoke_delete_grants.sql revoked the
-- DELETE grant on public.device_tokens from the `authenticated` role to
-- prevent a compromised client from purging another user's tokens via crafted
-- filters. That made DeviceTokenRegistrar's client-side delete silently 401
-- (swallowed by runCatching), so on a shared device:
--   * the previous user's row was never stripped → they kept receiving FCM
--     pushes after sign-out until their token rotated;
--   * the new user's upsert hit the PK on `token` and rolled back.
--
-- These two RPCs reinstate the necessary writes server-side, gated by
-- auth.uid() and the call's possession of the FCM token (only the device
-- holding the token can produce its exact value). The client `runCatching`
-- still wraps them so a flaky network on sign-out doesn't block the user
-- experience — it just doesn't silently 401 anymore.

-- ---------------------------------------------------------------------------
-- register_device_token — claim a token for the calling user, evicting any
-- prior claim on the same token. Returns the number of rows displaced (0 or
-- 1) so the client can log shared-device transitions.
-- ---------------------------------------------------------------------------
create or replace function public.register_device_token(
    p_token text,
    p_platform text
) returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_displaced int := 0;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  if p_token is null or char_length(p_token) = 0 or char_length(p_token) > 4096 then
    raise exception 'token must be 1..4096 chars' using errcode = '22023';
  end if;
  if p_platform is null or p_platform not in ('android', 'ios', 'web') then
    raise exception 'platform must be one of android/ios/web' using errcode = '22023';
  end if;

  -- Strip every existing row that holds this token — including the caller's
  -- own — so we end up with exactly one row per device. Safe because the
  -- caller proved physical possession of the token by passing it (FCM doesn't
  -- share tokens across devices). delete-then-insert also sidesteps any
  -- assumptions about which column the table's unique constraints sit on.
  with gone as (
    delete from public.device_tokens
     where token = p_token
       and user_id is distinct from v_user_id
    returning 1
  )
  select count(*) into v_displaced from gone;

  delete from public.device_tokens
   where token = p_token
     and user_id = v_user_id;

  insert into public.device_tokens (user_id, platform, token, updated_at)
  values (v_user_id, p_platform, p_token, now());

  return v_displaced;
end;
$$;

alter function public.register_device_token(text, text) owner to postgres;
revoke all on function public.register_device_token(text, text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- revoke_device_token — drop the caller's claim on the supplied token. Used on
-- sign-out so the outgoing user stops receiving FCM pushes immediately. Other
-- users' rows are left alone.
-- ---------------------------------------------------------------------------
create or replace function public.revoke_device_token(p_token text)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_count int := 0;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  if p_token is null or char_length(p_token) = 0 then
    raise exception 'token required' using errcode = '22023';
  end if;

  with gone as (
    delete from public.device_tokens
     where user_id = v_user_id
       and token = p_token
    returning 1
  )
  select count(*) into v_count from gone;
  return v_count;
end;
$$;

alter function public.revoke_device_token(text) owner to postgres;
revoke all on function public.revoke_device_token(text) from public, anon;
grant execute on function public.revoke_device_token(text) to authenticated;

comment on function public.register_device_token(text, text) is
    'SECURITY DEFINER replacement for the client-side device_tokens upsert. Strips prior claim on the token and binds it to auth.uid().';
comment on function public.revoke_device_token(text) is
    'SECURITY DEFINER sign-out helper that removes the caller''s device_tokens row for the supplied FCM token.';
