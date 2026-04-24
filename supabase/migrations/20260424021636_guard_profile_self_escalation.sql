-- CRITICAL: profiles UPDATE policy is `using (auth.uid() = id)` with no
-- WITH_CHECK. A user can set role='admin' or organization_id=<another org>
-- on their own row and gain admin / horizontal access. The existing
-- is_admin() / is_org_member() helpers read straight from profiles, so the
-- escalation immediately grants every protected surface (admin tables,
-- supplier-only writes, hospital-only reads).
--
-- Fix: BEFORE UPDATE trigger that refuses non-admin / non-service-role
-- callers from changing `role`, `role_confirmed`, or `organization_id` to
-- a value different from the current row. Other column edits (avatar_url,
-- phone, full_name, onboarding_completed, etc.) remain free.
--
-- Pattern matches public.guard_order_state_transitions; service-role and
-- postgres bypass so admin RPCs and migrations can still backfill.
-- Already applied to the live database via the Supabase MCP.

create or replace function public.guard_profile_self_escalation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
begin
  if v_caller_role = 'service_role' or session_user = 'postgres' then
    return new;
  end if;

  -- Admins can flip anything (used by the admin console).
  if is_admin(auth.uid()) then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'changing profiles.role requires admin or service-role'
      using errcode = '42501';
  end if;

  if new.role_confirmed is distinct from old.role_confirmed and old.role_confirmed = true then
    raise exception 'flipping role_confirmed back to false requires admin'
      using errcode = '42501';
  end if;

  if new.organization_id is distinct from old.organization_id and old.organization_id is not null then
    raise exception 'changing profiles.organization_id requires admin or service-role'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_profile_self_escalation on public.profiles;
create trigger trg_guard_profile_self_escalation
  before update on public.profiles
  for each row execute function public.guard_profile_self_escalation();

comment on function public.guard_profile_self_escalation() is
  'Blocks self-escalation: non-admin callers cannot change role, '
  'role_confirmed (once true), or organization_id (once set). '
  'Service-role / admin bypass.';
