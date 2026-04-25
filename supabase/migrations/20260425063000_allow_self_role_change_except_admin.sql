-- Original guard (20260424021636) blocked any self-role-change so users who
-- picked the wrong role at signup were stuck. Loosened here: a user can
-- update their own profiles.role to any of the non-privileged roles, but
-- never to 'admin'. role_confirmed and organization_id locks remain.
--
-- Rationale: legitimate UX needs (hospital admin who realised they're
-- actually an engineer) shouldn't require an ops escalation. Self-promotion
-- to 'admin' is the only thing that meaningfully grants extra power.

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

  -- Self role-change permitted, except elevation to 'admin'.
  if new.role is distinct from old.role then
    if new.role = 'admin' then
      raise exception 'self-promotion to admin is forbidden'
        using errcode = '42501';
    end if;
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

comment on function public.guard_profile_self_escalation() is
  'Blocks self-promotion to admin and self-flip of role_confirmed (once true) '
  'or organization_id (once set). Self-change between non-admin roles is '
  'allowed so users who picked the wrong signup role can correct it. '
  'Service-role / admin bypass.';
