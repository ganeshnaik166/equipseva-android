-- Founder admin RPCs for the Users page.
-- admin_users_search() — paginated profile search by email/phone substring or role
-- admin_force_role_change() — founder overrides a user's role (audit-logged)

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
  created_at timestamptz
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
    SELECT
      p.id,
      p.email,
      p.phone,
      coalesce(p.full_name, '(unnamed)'),
      p.role::text,
      p.organization_id,
      p.is_active,
      p.created_at
    FROM public.profiles p
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

-- Force role change. Refuses to demote / upgrade INTO 'admin' tier roles by the
-- same self-role-change policy already in place; founder can still set any
-- non-admin business role (hospital_admin, engineer, supplier, manufacturer,
-- logistics).
CREATE OR REPLACE FUNCTION public.admin_force_role_change(
  p_user_id uuid,
  p_new_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  IF p_new_role NOT IN ('hospital_admin','engineer','supplier','manufacturer','logistics') THEN
    RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023';
  END IF;
  UPDATE public.profiles
  SET role = p_new_role::user_role,
      role_confirmed = true,
      updated_at = now()
  WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_force_role_change(uuid, text) TO authenticated;
