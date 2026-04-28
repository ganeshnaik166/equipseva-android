-- engineers_public view was created with security_invoker=false (Postgres
-- default for views), which means it bypasses the caller's RLS on the
-- underlying `engineers` table. Flip to security_invoker=true so the
-- caller's RLS applies.

ALTER VIEW public.engineers_public SET (security_invoker = true);
