-- Server-issued nonces for Play Integrity attestation requests.
--
-- Without a server-bound nonce a client-generated random value is meaningless:
-- an attacker who harvests a valid token from a clean device can replay it
-- against verify-play-integrity until the token's natural expiry. By rotating
-- the nonce server-side and pinning each token to a single-use challenge, a
-- replay is rejected at decode time because the nonce in the decoded token
-- payload won't match anything the server knows about.
--
-- Flow:
--   1. Client calls public.request_integrity_challenge('auth_change')
--   2. RPC writes a random 32-byte nonce keyed to (user_id, action) and
--      returns the base64url-encoded value to the client.
--   3. Client passes that nonce to IntegrityTokenRequest.setNonce(...) and
--      submits the resulting token to verify-play-integrity together with
--      the same `action` string.
--   4. Edge function looks up the nonce, marks it used, and rejects on
--      mismatch / already-used / expired.
--
-- Retention: rows are short-lived (60 s active TTL) and reaped by the
-- purge_old_play_integrity_challenges() helper added in the same file.
-- Even without that helper, the table stays small because every nonce is
-- consumed within ~10 s of issue (Play Integrity round-trip cap is 10 s).

create table if not exists public.play_integrity_challenges (
    nonce       text primary key,
    user_id     uuid not null references auth.users(id) on delete cascade,
    action      text not null,
    created_at  timestamptz not null default now(),
    used_at     timestamptz,

    constraint play_integrity_challenges_action_len
        check (char_length(action) between 1 and 64),
    -- 32 bytes -> 43 base64url chars without padding.
    constraint play_integrity_challenges_nonce_fmt
        check (nonce ~ '^[A-Za-z0-9_-]{40,128}$')
);

create index if not exists play_integrity_challenges_user_action_idx
    on public.play_integrity_challenges (user_id, action, created_at desc);

create index if not exists play_integrity_challenges_unused_idx
    on public.play_integrity_challenges (created_at desc)
    where used_at is null;

alter table public.play_integrity_challenges enable row level security;

-- No client-side select / insert / update / delete policies. The RPC below
-- (SECURITY DEFINER) is the only client-facing writer, and the edge function
-- consumes nonces with the service role.

-- ---------------------------------------------------------------------------
-- request_integrity_challenge — issue a fresh server-bound nonce.
-- ---------------------------------------------------------------------------
create or replace function public.request_integrity_challenge(p_action text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_nonce   text;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  if p_action is null or char_length(btrim(p_action)) = 0 or char_length(p_action) > 64 then
    raise exception 'action must be 1..64 chars' using errcode = '22023';
  end if;

  -- 32 random bytes -> 43-char base64url (no padding). Postgres' built-in
  -- encode() does not have a url-safe variant, so swap the +/= manually.
  v_nonce := translate(
    encode(gen_random_bytes(32), 'base64'),
    '+/=',
    '-_'
  );
  v_nonce := replace(v_nonce, e'\n', '');
  -- Strip any residual '_' coming from '=' padding.
  v_nonce := rtrim(v_nonce, '_');

  insert into public.play_integrity_challenges (nonce, user_id, action)
  values (v_nonce, v_user_id, p_action);

  -- Best-effort opportunistic cleanup so the table doesn't grow under cron-less
  -- environments. Bounded delete; index supports it.
  delete from public.play_integrity_challenges
   where created_at < now() - interval '5 minutes';

  return v_nonce;
end;
$$;

alter function public.request_integrity_challenge(text) owner to postgres;
revoke all on function public.request_integrity_challenge(text) from public, anon;
grant execute on function public.request_integrity_challenge(text) to authenticated;

-- ---------------------------------------------------------------------------
-- consume_integrity_challenge — service-role-only single-use validator.
-- The edge function calls this AFTER decoding the token; it both checks the
-- nonce belongs to the caller's user_id + action AND marks it used in the same
-- statement so two concurrent verify-play-integrity calls with the same token
-- can't both succeed.
-- ---------------------------------------------------------------------------
create or replace function public.consume_integrity_challenge(
    p_nonce text,
    p_user_id uuid,
    p_action text
) returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status text;
begin
  with target as (
    select nonce, user_id, action, created_at, used_at
      from public.play_integrity_challenges
     where nonce = p_nonce
     for update
  ),
  decision as (
    select
      case
        when t.nonce is null then 'missing'
        when t.user_id <> p_user_id then 'wrong_user'
        when t.action <> p_action then 'wrong_action'
        when t.used_at is not null then 'already_used'
        when t.created_at < now() - interval '60 seconds' then 'expired'
        else 'ok'
      end as status,
      t.nonce as nonce
    from (select * from public.play_integrity_challenges where nonce = p_nonce) t
  )
  select status into v_status from decision;

  if v_status is null then
    return 'missing';
  end if;

  if v_status = 'ok' then
    update public.play_integrity_challenges
       set used_at = now()
     where nonce = p_nonce
       and used_at is null;
  end if;

  return v_status;
end;
$$;

alter function public.consume_integrity_challenge(text, uuid, text) owner to postgres;
revoke all on function public.consume_integrity_challenge(text, uuid, text) from public, anon, authenticated;
-- Service-role only — edge function reaches in via the service key.

-- ---------------------------------------------------------------------------
-- TTL helper — same shape as purge_old_device_integrity_checks. Drops every
-- challenge older than 5 minutes; safe to wire to pg_cron / scheduled edge.
-- ---------------------------------------------------------------------------
create or replace function public.purge_old_play_integrity_challenges()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count int;
begin
  with gone as (
    delete from public.play_integrity_challenges
     where created_at < now() - interval '5 minutes'
    returning 1
  )
  select count(*) into v_count from gone;
  return v_count;
end;
$$;

alter function public.purge_old_play_integrity_challenges() owner to postgres;
revoke all on function public.purge_old_play_integrity_challenges() from public, anon, authenticated;

comment on table public.play_integrity_challenges is
    'Single-use nonces issued by request_integrity_challenge() and consumed by verify-play-integrity to prevent token replay.';
