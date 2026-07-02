BEGIN;

-- Catalog table
CREATE TABLE IF NOT EXISTS public.hospital_customer_pain_point_catalog_r2087 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pain_label text NOT NULL,
  pain_category text NOT NULL CHECK (pain_category IN ('service_quality','pricing','communication','billing','feature_request','competitive_loss')),
  severity text NOT NULL CHECK (severity IN ('minor','moderate','major','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','escalated','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcppc_r2087_hospital ON public.hospital_customer_pain_point_catalog_r2087(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hcppc_r2087_status ON public.hospital_customer_pain_point_catalog_r2087(status);
CREATE INDEX IF NOT EXISTS idx_hcppc_r2087_severity ON public.hospital_customer_pain_point_catalog_r2087(severity);
CREATE INDEX IF NOT EXISTS idx_hcppc_r2087_captured ON public.hospital_customer_pain_point_catalog_r2087(captured_at DESC);

-- Resolution log table
CREATE TABLE IF NOT EXISTS public.hospital_pain_resolution_log_r2087 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pain_id uuid NOT NULL REFERENCES public.hospital_customer_pain_point_catalog_r2087(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('acknowledged','investigated','resolved','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hprl_r2087_pain ON public.hospital_pain_resolution_log_r2087(pain_id);
CREATE INDEX IF NOT EXISTS idx_hprl_r2087_taken ON public.hospital_pain_resolution_log_r2087(taken_at DESC);

-- RLS
ALTER TABLE public.hospital_customer_pain_point_catalog_r2087 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_pain_resolution_log_r2087 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hcppc_r2087 ON public.hospital_customer_pain_point_catalog_r2087;
CREATE POLICY founder_all_hcppc_r2087 ON public.hospital_customer_pain_point_catalog_r2087
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hprl_r2087 ON public.hospital_pain_resolution_log_r2087;
CREATE POLICY founder_all_hprl_r2087 ON public.hospital_pain_resolution_log_r2087
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_pains
CREATE OR REPLACE FUNCTION public.list_pains_r2087()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  pain_label text,
  pain_category text,
  severity text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.hospital_id,
           COALESCE(o.name, pr.full_name, 'Unknown')::text AS hospital_name,
           p.pain_label, p.pain_category, p.severity, p.status, p.captured_at
    FROM public.hospital_customer_pain_point_catalog_r2087 p
    LEFT JOIN public.profiles pr ON pr.id = p.hospital_id
    LEFT JOIN public.organizations o ON o.id = pr.organization_id
    ORDER BY p.captured_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: log_pain (write)
CREATE OR REPLACE FUNCTION public.log_pain_r2087(
  p_hospital_id uuid,
  p_pain_label text,
  p_pain_category text,
  p_severity text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_pain_point_catalog_r2087(hospital_id, pain_label, pain_category, severity)
  VALUES (p_hospital_id, p_pain_label, p_pain_category, p_severity)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pain_r2087',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'pain_label', p_pain_label, 'severity', p_severity));
  RETURN v_id;
END;
$$;

-- RPC 3: list_resolutions
CREATE OR REPLACE FUNCTION public.list_resolutions_r2087(p_pain_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  pain_id uuid,
  pain_label text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.pain_id, p.pain_label, r.action_type, r.taken_at, r.by_email, r.notes_md
    FROM public.hospital_pain_resolution_log_r2087 r
    LEFT JOIN public.hospital_customer_pain_point_catalog_r2087 p ON p.id = r.pain_id
    WHERE (p_pain_id IS NULL OR r.pain_id = p_pain_id)
    ORDER BY r.taken_at DESC
    LIMIT 200;
END;
$$;

-- RPC 4: log_resolution (write)
CREATE OR REPLACE FUNCTION public.log_resolution_r2087(
  p_pain_id uuid,
  p_action_type text,
  p_notes_md text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_pain_resolution_log_r2087(pain_id, action_type, by_email, notes_md)
  VALUES (p_pain_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_resolution_r2087',
          jsonb_build_object('id', v_id, 'pain_id', p_pain_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status (write)
CREATE OR REPLACE FUNCTION public.mark_status_r2087(
  p_pain_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_pain_point_catalog_r2087
  SET status = p_status, updated_at = now()
  WHERE id = p_pain_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2087',
          jsonb_build_object('pain_id', p_pain_id, 'status', p_status));
END;
$$;

-- RPC 6: critical_pains
CREATE OR REPLACE FUNCTION public.critical_pains_r2087()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  pain_label text,
  pain_category text,
  severity text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id,
           COALESCE(o.name, pr.full_name, 'Unknown')::text AS hospital_name,
           p.pain_label, p.pain_category, p.severity, p.status, p.captured_at
    FROM public.hospital_customer_pain_point_catalog_r2087 p
    LEFT JOIN public.profiles pr ON pr.id = p.hospital_id
    LEFT JOIN public.organizations o ON o.id = pr.organization_id
    WHERE p.severity IN ('major','critical')
      AND p.status NOT IN ('resolved','closed')
    ORDER BY
      CASE p.severity WHEN 'critical' THEN 0 ELSE 1 END,
      p.captured_at DESC
    LIMIT 100;
END;
$$;

-- RPC 7: recent_resolutions
CREATE OR REPLACE FUNCTION public.recent_resolutions_r2087()
RETURNS TABLE (
  id uuid,
  pain_label text,
  hospital_name text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, p.pain_label,
           COALESCE(o.name, pr.full_name, 'Unknown')::text AS hospital_name,
           r.action_type, r.taken_at, r.by_email
    FROM public.hospital_pain_resolution_log_r2087 r
    LEFT JOIN public.hospital_customer_pain_point_catalog_r2087 p ON p.id = r.pain_id
    LEFT JOIN public.profiles pr ON pr.id = p.hospital_id
    LEFT JOIN public.organizations o ON o.id = pr.organization_id
    WHERE r.taken_at >= now() - interval '30 days'
    ORDER BY r.taken_at DESC
    LIMIT 100;
END;
$$;

-- Lockdown
REVOKE EXECUTE ON FUNCTION public.list_pains_r2087() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pain_r2087(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_resolutions_r2087(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_resolution_r2087(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2087(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_pains_r2087() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_resolutions_r2087() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pains_r2087() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pain_r2087(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_resolutions_r2087(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_resolution_r2087(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2087(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_pains_r2087() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_resolutions_r2087() TO authenticated;

COMMIT;
