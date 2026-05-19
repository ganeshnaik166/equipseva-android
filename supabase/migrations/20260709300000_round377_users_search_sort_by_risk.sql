-- Round 377 — admin_users_search: sort risky users first.
--
-- r367 surfaced the failed_integrity_count per user inline (Danger
-- pill). r367 ordered by created_at DESC, which buried risky users
-- by recency rather than urgency. Match the r376 founder-ops sort
-- pattern: risk count first, recency as tie-break.

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
    -- Round 377 — risky users first, recency tie-break.
    ORDER BY coalesce(ic.failed_count, 0) DESC,
             p.created_at DESC NULLS LAST
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
    OFFSET greatest(0, coalesce(p_offset, 0));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_users_search(text, text, int, int) TO authenticated;
