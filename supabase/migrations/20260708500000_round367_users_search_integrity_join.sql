-- Round 367 — admin_users_search: include failed_integrity_count per
-- user so the Users queue can flag risky users with a Danger pill
-- next to the row (mirror of round 351 on the Payments page).
--
-- Same DROP + CREATE pattern as r351's admin_recent_payments update:
-- adding a RETURNS TABLE column changes the signature in a way
-- CREATE OR REPLACE can't do in place.

DROP FUNCTION IF EXISTS public.admin_users_search(text, text, int, int);

CREATE OR REPLACE FUNCTION public.admin_users_search(
  p_query text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  email text,
  phone text,
  full_name text,
  role text,
  organization_id uuid,
  is_active boolean,
  created_at timestamptz,
  failed_integrity_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_q text := nullif(trim(coalesce(p_query, '')), '');
  v_pat text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  v_pat := CASE WHEN v_q IS NULL THEN NULL ELSE '%' || lower(v_q) || '%' END;
  RETURN QUERY
    WITH integrity_counts AS (
      -- Round 359 index makes this lookup cheap.
      SELECT user_id, count(*)::int AS failed_count
        FROM public.device_integrity_checks
       WHERE pass = false
       GROUP BY user_id
    )
    SELECT
      p.id,
      p.email,
      p.phone,
      coalesce(p.full_name, '(unnamed)'),
      p.role::text,
      p.organization_id,
      p.is_active,
      p.created_at,
      coalesce(ic.failed_count, 0)
    FROM public.profiles p
    LEFT JOIN integrity_counts ic ON ic.user_id = p.id
    WHERE
      (v_pat IS NULL
        OR lower(coalesce(p.email, '')) LIKE v_pat
        OR lower(coalesce(p.phone, '')) LIKE v_pat
        OR lower(coalesce(p.full_name, '')) LIKE v_pat)
      AND (p_role IS NULL OR p.role::text = p_role)
    ORDER BY p.created_at DESC NULLS LAST
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
    OFFSET greatest(0, coalesce(p_offset, 0));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_users_search(text, text, int, int) TO authenticated;
