BEGIN;

-- =========================================================================
-- Round 1680: Engineer Equipment Certifications
-- Per-engineer cert per equipment category + expiry watch.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_equipment_certs_r1680 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_category text NOT NULL,
  cert_level text NOT NULL CHECK (cert_level IN ('basic','intermediate','advanced','master')),
  issued_on date NOT NULL,
  expires_on date,
  issuer text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eec_r1680_engineer ON public.engineer_equipment_certs_r1680(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eec_r1680_category ON public.engineer_equipment_certs_r1680(equipment_category);
CREATE INDEX IF NOT EXISTS idx_eec_r1680_expires ON public.engineer_equipment_certs_r1680(expires_on);

CREATE TABLE IF NOT EXISTS public.engineer_cert_renewal_queue_r1680 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cert_id uuid NOT NULL REFERENCES public.engineer_equipment_certs_r1680(id) ON DELETE CASCADE,
  queued_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','scheduled','renewed','lapsed')),
  scheduled_for date,
  renewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecrq_r1680_cert ON public.engineer_cert_renewal_queue_r1680(cert_id);
CREATE INDEX IF NOT EXISTS idx_ecrq_r1680_status ON public.engineer_cert_renewal_queue_r1680(status);

ALTER TABLE public.engineer_equipment_certs_r1680 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_cert_renewal_queue_r1680 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eec_r1680_founder_all ON public.engineer_equipment_certs_r1680;
CREATE POLICY eec_r1680_founder_all ON public.engineer_equipment_certs_r1680
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS ecrq_r1680_founder_all ON public.engineer_cert_renewal_queue_r1680;
CREATE POLICY ecrq_r1680_founder_all ON public.engineer_cert_renewal_queue_r1680
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_certs
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1680_list_certs();
CREATE OR REPLACE FUNCTION public.r1680_list_certs()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  equipment_category text,
  cert_level text,
  issued_on date,
  expires_on date,
  issuer text,
  days_to_expiry int,
  is_lapsed boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.engineer_user_id,
    COALESCE(p.full_name, p.email, '—')::text AS engineer_name,
    c.equipment_category,
    c.cert_level,
    c.issued_on,
    c.expires_on,
    c.issuer,
    CASE WHEN c.expires_on IS NULL THEN NULL
         ELSE (c.expires_on - CURRENT_DATE)::int
    END AS days_to_expiry,
    (c.expires_on IS NOT NULL AND c.expires_on < CURRENT_DATE) AS is_lapsed,
    c.created_at
  FROM public.engineer_equipment_certs_r1680 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  ORDER BY c.expires_on NULLS LAST, c.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1680_list_certs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1680_list_certs() TO authenticated;

-- =========================================================================
-- RPC 2: add_cert
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1680_add_cert(uuid, text, text, date, date, text);
CREATE OR REPLACE FUNCTION public.r1680_add_cert(
  p_engineer_user_id uuid,
  p_equipment_category text,
  p_cert_level text,
  p_issued_on date,
  p_expires_on date,
  p_issuer text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_equipment_certs_r1680(
    engineer_user_id, equipment_category, cert_level, issued_on, expires_on, issuer
  ) VALUES (
    p_engineer_user_id, p_equipment_category, p_cert_level, p_issued_on, p_expires_on, p_issuer
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1680_add_cert',
    jsonb_build_object(
      'cert_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'equipment_category', p_equipment_category,
      'cert_level', p_cert_level
    )
  );
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1680_add_cert(uuid, text, text, date, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1680_add_cert(uuid, text, text, date, date, text) TO authenticated;

-- =========================================================================
-- RPC 3: expiring_soon
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1680_expiring_soon(int);
CREATE OR REPLACE FUNCTION public.r1680_expiring_soon(p_days int DEFAULT 90)
RETURNS TABLE (
  id uuid,
  engineer_name text,
  equipment_category text,
  cert_level text,
  expires_on date,
  days_to_expiry int,
  issuer text,
  window_bucket text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    COALESCE(p.full_name, p.email, '—')::text AS engineer_name,
    c.equipment_category,
    c.cert_level,
    c.expires_on,
    (c.expires_on - CURRENT_DATE)::int AS days_to_expiry,
    c.issuer,
    CASE
      WHEN c.expires_on - CURRENT_DATE <= 30 THEN '30d'
      WHEN c.expires_on - CURRENT_DATE <= 60 THEN '60d'
      ELSE '90d'
    END::text AS window_bucket
  FROM public.engineer_equipment_certs_r1680 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.expires_on IS NOT NULL
    AND c.expires_on >= CURRENT_DATE
    AND c.expires_on <= CURRENT_DATE + (p_days || ' days')::interval
  ORDER BY c.expires_on ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1680_expiring_soon(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1680_expiring_soon(int) TO authenticated;

-- =========================================================================
-- RPC 4: queue_renewal
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1680_queue_renewal(uuid, date);
CREATE OR REPLACE FUNCTION public.r1680_queue_renewal(
  p_cert_id uuid,
  p_scheduled_for date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_cert_renewal_queue_r1680(
    cert_id, status, scheduled_for
  ) VALUES (
    p_cert_id, 'scheduled', p_scheduled_for
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1680_queue_renewal',
    jsonb_build_object(
      'queue_id', v_id,
      'cert_id', p_cert_id,
      'scheduled_for', p_scheduled_for
    )
  );
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1680_queue_renewal(uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1680_queue_renewal(uuid, date) TO authenticated;

-- =========================================================================
-- RPC 5: mark_renewed
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1680_mark_renewed(uuid, date);
CREATE OR REPLACE FUNCTION public.r1680_mark_renewed(
  p_queue_id uuid,
  p_new_expires_on date
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cert_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_cert_renewal_queue_r1680
     SET status = 'renewed',
         renewed_at = now(),
         updated_at = now()
   WHERE id = p_queue_id
   RETURNING cert_id INTO v_cert_id;

  IF v_cert_id IS NULL THEN
    RAISE EXCEPTION 'queue_id not found';
  END IF;

  UPDATE public.engineer_equipment_certs_r1680
     SET expires_on = p_new_expires_on,
         updated_at = now()
   WHERE id = v_cert_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1680_mark_renewed',
    jsonb_build_object(
      'queue_id', p_queue_id,
      'cert_id', v_cert_id,
      'new_expires_on', p_new_expires_on
    )
  );
  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1680_mark_renewed(uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1680_mark_renewed(uuid, date) TO authenticated;

-- =========================================================================
-- RPC 6: cert_coverage_by_category
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1680_cert_coverage_by_category();
CREATE OR REPLACE FUNCTION public.r1680_cert_coverage_by_category()
RETURNS TABLE (
  equipment_category text,
  total_certs int,
  basic_count int,
  intermediate_count int,
  advanced_count int,
  master_count int,
  active_count int,
  lapsed_count int,
  unique_engineers int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.equipment_category,
    COUNT(*)::int AS total_certs,
    (COUNT(*) FILTER (WHERE c.cert_level = 'basic'))::int AS basic_count,
    (COUNT(*) FILTER (WHERE c.cert_level = 'intermediate'))::int AS intermediate_count,
    (COUNT(*) FILTER (WHERE c.cert_level = 'advanced'))::int AS advanced_count,
    (COUNT(*) FILTER (WHERE c.cert_level = 'master'))::int AS master_count,
    (COUNT(*) FILTER (WHERE c.expires_on IS NULL OR c.expires_on >= CURRENT_DATE))::int AS active_count,
    (COUNT(*) FILTER (WHERE c.expires_on IS NOT NULL AND c.expires_on < CURRENT_DATE))::int AS lapsed_count,
    COUNT(DISTINCT c.engineer_user_id)::int AS unique_engineers
  FROM public.engineer_equipment_certs_r1680 c
  GROUP BY c.equipment_category
  ORDER BY total_certs DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1680_cert_coverage_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1680_cert_coverage_by_category() TO authenticated;

-- =========================================================================
-- RPC 7: lapsed_certs
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1680_lapsed_certs();
CREATE OR REPLACE FUNCTION public.r1680_lapsed_certs()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  equipment_category text,
  cert_level text,
  expires_on date,
  days_lapsed int,
  issuer text,
  queue_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    COALESCE(p.full_name, p.email, '—')::text AS engineer_name,
    c.equipment_category,
    c.cert_level,
    c.expires_on,
    (CURRENT_DATE - c.expires_on)::int AS days_lapsed,
    c.issuer,
    COALESCE(q.status, 'none')::text AS queue_status
  FROM public.engineer_equipment_certs_r1680 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  LEFT JOIN LATERAL (
    SELECT status
    FROM public.engineer_cert_renewal_queue_r1680
    WHERE cert_id = c.id
    ORDER BY created_at DESC
    LIMIT 1
  ) q ON true
  WHERE c.expires_on IS NOT NULL
    AND c.expires_on < CURRENT_DATE
  ORDER BY c.expires_on ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1680_lapsed_certs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1680_lapsed_certs() TO authenticated;

COMMIT;