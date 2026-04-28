-- public.equipment and public.rfqs are leftover marketplace tables
-- that the v1 Android client never reads or writes (the marketplace
-- surface was stripped during the v1 cleanup). Their RLS policies
-- still let any authenticated user INSERT/SELECT — equipment.INSERT
-- on org-membership, rfqs.INSERT on auth.uid() = requester_user_id —
-- so a malicious client could spam either table without affecting
-- v1 flows. Revoke all client access on both tables so they're cold
-- until a future marketplace re-introduction. service_role bypass
-- keeps backend / admin tooling functional.
--
-- We deliberately keep the tables themselves rather than DROP them so
-- existing rows (if any) and historical references stay queryable
-- from admin tooling on service_role.

REVOKE ALL ON public.equipment FROM authenticated, anon;
REVOKE ALL ON public.rfqs FROM authenticated, anon;
