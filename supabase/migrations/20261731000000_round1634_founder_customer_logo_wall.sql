BEGIN;

-- =========================================================================
-- r1634 — Founder Customer Logo Wall
-- Showcase customer logos with permission ledger; per-logo display status;
-- founder approval before public use.
-- =========================================================================

-- ---- Table 1: customer logos ----
CREATE TABLE IF NOT EXISTS public.founder_customer_logos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  customer_name text NOT NULL,
  logo_url text NOT NULL,
  display_status text NOT NULL DEFAULT 'pending'
    CHECK (display_status IN ('pending','approved','rejected','retired')),
  tier text NOT NULL DEFAULT 'standard'
    CHECK (tier IN ('marquee','featured','standard')),
  approved_by_founder boolean NOT NULL DEFAULT false,
  approved_at timestamptz,
  rejected_reason text,
  display_order int NOT NULL DEFAULT 100,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_customer_logos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_customer_logos_founder_only ON public.founder_customer_logos;
CREATE POLICY founder_customer_logos_founder_only ON public.founder_customer_logos
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_fcl_status ON public.founder_customer_logos(display_status);
CREATE INDEX IF NOT EXISTS idx_fcl_tier ON public.founder_customer_logos(tier);
CREATE INDEX IF NOT EXISTS idx_fcl_created ON public.founder_customer_logos(created_at DESC);

-- ---- Table 2: permission ledger ----
CREATE TABLE IF NOT EXISTS public.founder_customer_logo_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  logo_id uuid NOT NULL REFERENCES public.founder_customer_logos(id) ON DELETE CASCADE,
  permission_type text NOT NULL
    CHECK (permission_type IN ('verbal','email','contract','public_pr','revoked')),
  granted_by_contact text NOT NULL,
  granted_by_email text,
  granted_at timestamptz NOT NULL DEFAULT now(),
  evidence_url text,
  expires_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  recorded_by uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_customer_logo_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fclp_founder_only ON public.founder_customer_logo_permissions;
CREATE POLICY fclp_founder_only ON public.founder_customer_logo_permissions
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_fclp_logo ON public.founder_customer_logo_permissions(logo_id);
CREATE INDEX IF NOT EXISTS idx_fclp_active ON public.founder_customer_logo_permissions(is_active);

-- ---- helper: log to founder_action_log ----
CREATE OR REPLACE FUNCTION public.log_founder_logo_wall_action(
  p_op text,
  p_after jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after, now());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_logo_wall_action(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_logo_wall_action(text, jsonb) TO authenticated;

-- ---- RPC 1: list logos with permission counts ----
CREATE OR REPLACE FUNCTION public.founder_logo_wall_list()
RETURNS TABLE (
  id uuid,
  customer_name text,
  customer_org_id uuid,
  logo_url text,
  display_status text,
  tier text,
  approved_by_founder boolean,
  approved_at timestamptz,
  display_order int,
  permission_count bigint,
  active_permission_count bigint,
  latest_permission_type text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    l.id, l.customer_name, l.customer_org_id, l.logo_url,
    l.display_status, l.tier, l.approved_by_founder, l.approved_at, l.display_order,
    COALESCE((SELECT count(*) FROM public.founder_customer_logo_permissions p WHERE p.logo_id = l.id), 0) AS permission_count,
    COALESCE((SELECT count(*) FROM public.founder_customer_logo_permissions p WHERE p.logo_id = l.id AND p.is_active), 0) AS active_permission_count,
    (SELECT p.permission_type FROM public.founder_customer_logo_permissions p WHERE p.logo_id = l.id ORDER BY p.granted_at DESC LIMIT 1) AS latest_permission_type,
    l.created_at
  FROM public.founder_customer_logos l
  ORDER BY
    CASE l.display_status WHEN 'pending' THEN 1 WHEN 'approved' THEN 2 WHEN 'rejected' THEN 3 ELSE 4 END,
    l.display_order ASC,
    l.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_logo_wall_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_logo_wall_list() TO authenticated;

-- ---- RPC 2: counts by status + tier ----
CREATE OR REPLACE FUNCTION public.founder_logo_wall_summary()
RETURNS TABLE (
  total_logos bigint,
  pending_count bigint,
  approved_count bigint,
  rejected_count bigint,
  retired_count bigint,
  marquee_count bigint,
  with_active_permission bigint,
  without_any_permission bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_customer_logos),
    (SELECT count(*) FROM public.founder_customer_logos WHERE display_status='pending'),
    (SELECT count(*) FROM public.founder_customer_logos WHERE display_status='approved'),
    (SELECT count(*) FROM public.founder_customer_logos WHERE display_status='rejected'),
    (SELECT count(*) FROM public.founder_customer_logos WHERE display_status='retired'),
    (SELECT count(*) FROM public.founder_customer_logos WHERE tier='marquee'),
    (SELECT count(DISTINCT l.id) FROM public.founder_customer_logos l
       JOIN public.founder_customer_logo_permissions p ON p.logo_id=l.id AND p.is_active),
    (SELECT count(*) FROM public.founder_customer_logos l
       WHERE NOT EXISTS (SELECT 1 FROM public.founder_customer_logo_permissions p WHERE p.logo_id=l.id));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_logo_wall_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_logo_wall_summary() TO authenticated;

-- ---- RPC 3: permission ledger for a logo ----
CREATE OR REPLACE FUNCTION public.founder_logo_wall_permission_ledger(p_logo_id uuid)
RETURNS TABLE (
  id uuid,
  permission_type text,
  granted_by_contact text,
  granted_by_email text,
  granted_at timestamptz,
  evidence_url text,
  expires_at timestamptz,
  is_active boolean,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT p.id, p.permission_type, p.granted_by_contact, p.granted_by_email,
         p.granted_at, p.evidence_url, p.expires_at, p.is_active, p.notes
  FROM public.founder_customer_logo_permissions p
  WHERE p.logo_id = p_logo_id
  ORDER BY p.granted_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_logo_wall_permission_ledger(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_logo_wall_permission_ledger(uuid) TO authenticated;

-- ---- RPC 4: add logo entry ----
CREATE OR REPLACE FUNCTION public.founder_logo_wall_add(
  p_customer_name text,
  p_logo_url text,
  p_customer_org_id uuid DEFAULT NULL,
  p_tier text DEFAULT 'standard',
  p_display_order int DEFAULT 100,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_customer_logos
    (customer_name, logo_url, customer_org_id, tier, display_order, notes, display_status, approved_by_founder)
  VALUES
    (p_customer_name, p_logo_url, p_customer_org_id, COALESCE(p_tier,'standard'), COALESCE(p_display_order,100), p_notes, 'pending', false)
  RETURNING id INTO v_id;
  PERFORM public.log_founder_logo_wall_action('logo_wall_add', jsonb_build_object('id', v_id, 'customer_name', p_customer_name));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_logo_wall_add(text, text, uuid, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_logo_wall_add(text, text, uuid, text, int, text) TO authenticated;

-- ---- RPC 5: approve / reject / retire ----
CREATE OR REPLACE FUNCTION public.founder_logo_wall_set_status(
  p_logo_id uuid,
  p_new_status text,
  p_reject_reason text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_new_status NOT IN ('pending','approved','rejected','retired') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.founder_customer_logos
  SET display_status = p_new_status,
      approved_by_founder = (p_new_status = 'approved'),
      approved_at = CASE WHEN p_new_status='approved' THEN now() ELSE approved_at END,
      rejected_reason = CASE WHEN p_new_status='rejected' THEN p_reject_reason ELSE NULL END,
      updated_at = now()
  WHERE id = p_logo_id;
  PERFORM public.log_founder_logo_wall_action('logo_wall_set_status',
    jsonb_build_object('id', p_logo_id, 'status', p_new_status, 'reason', p_reject_reason));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_logo_wall_set_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_logo_wall_set_status(uuid, text, text) TO authenticated;

-- ---- RPC 6: record permission ----
CREATE OR REPLACE FUNCTION public.founder_logo_wall_record_permission(
  p_logo_id uuid,
  p_permission_type text,
  p_granted_by_contact text,
  p_granted_by_email text DEFAULT NULL,
  p_evidence_url text DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_permission_type NOT IN ('verbal','email','contract','public_pr','revoked') THEN
    RAISE EXCEPTION 'invalid_permission_type';
  END IF;
  INSERT INTO public.founder_customer_logo_permissions
    (logo_id, permission_type, granted_by_contact, granted_by_email, evidence_url, expires_at, notes, recorded_by, is_active)
  VALUES
    (p_logo_id, p_permission_type, p_granted_by_contact, p_granted_by_email, p_evidence_url, p_expires_at, p_notes, auth.uid(), (p_permission_type <> 'revoked'))
  RETURNING id INTO v_id;
  IF p_permission_type = 'revoked' THEN
    UPDATE public.founder_customer_logo_permissions SET is_active = false
      WHERE logo_id = p_logo_id AND id <> v_id;
  END IF;
  PERFORM public.log_founder_logo_wall_action('logo_wall_record_permission',
    jsonb_build_object('logo_id', p_logo_id, 'permission_type', p_permission_type));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_logo_wall_record_permission(uuid, text, text, text, text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_logo_wall_record_permission(uuid, text, text, text, text, timestamptz, text) TO authenticated;

-- ---- RPC 7: at-risk logos (approved but lost active permission, or expired) ----
CREATE OR REPLACE FUNCTION public.founder_logo_wall_at_risk()
RETURNS TABLE (
  id uuid,
  customer_name text,
  display_status text,
  tier text,
  reason text,
  latest_permission_type text,
  latest_permission_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (logo_id) logo_id, permission_type, granted_at, expires_at, is_active
    FROM public.founder_customer_logo_permissions
    ORDER BY logo_id, granted_at DESC
  )
  SELECT l.id, l.customer_name, l.display_status, l.tier,
    CASE
      WHEN lt.logo_id IS NULL THEN 'approved_no_permission_on_file'
      WHEN lt.permission_type = 'revoked' THEN 'permission_revoked'
      WHEN lt.expires_at IS NOT NULL AND lt.expires_at < now() THEN 'permission_expired'
      WHEN NOT lt.is_active THEN 'permission_inactive'
      ELSE 'unknown'
    END AS reason,
    lt.permission_type, lt.granted_at
  FROM public.founder_customer_logos l
  LEFT JOIN latest lt ON lt.logo_id = l.id
  WHERE l.display_status = 'approved'
    AND (
      lt.logo_id IS NULL
      OR lt.permission_type = 'revoked'
      OR (lt.expires_at IS NOT NULL AND lt.expires_at < now())
      OR NOT lt.is_active
    )
  ORDER BY l.customer_name;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_logo_wall_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_logo_wall_at_risk() TO authenticated;

COMMIT;