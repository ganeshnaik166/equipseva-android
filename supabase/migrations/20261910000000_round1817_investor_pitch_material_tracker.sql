BEGIN;

-- =========================================================
-- Round 1817: Investor Confidential Pitch Material Tracker
-- =========================================================

CREATE TABLE IF NOT EXISTS public.investor_pitch_material_distributions_r1817 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  material_type text NOT NULL CHECK (material_type IN ('pitch_deck','financial_model','cap_table','data_room','roadmap','customer_list')),
  version_label text NOT NULL,
  shared_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  watermark text,
  accessed boolean NOT NULL DEFAULT false,
  accessed_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','revoked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_pitch_material_view_log_r1817 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  distribution_id uuid NOT NULL REFERENCES public.investor_pitch_material_distributions_r1817(id) ON DELETE CASCADE,
  viewer_email text,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  ip_address text,
  geo_location text,
  view_duration_sec int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ipmd_r1817_investor ON public.investor_pitch_material_distributions_r1817(investor_id);
CREATE INDEX IF NOT EXISTS idx_ipmd_r1817_status ON public.investor_pitch_material_distributions_r1817(status);
CREATE INDEX IF NOT EXISTS idx_ipmd_r1817_expires ON public.investor_pitch_material_distributions_r1817(expires_at);
CREATE INDEX IF NOT EXISTS idx_ipmvl_r1817_distribution ON public.investor_pitch_material_view_log_r1817(distribution_id);
CREATE INDEX IF NOT EXISTS idx_ipmvl_r1817_viewed_at ON public.investor_pitch_material_view_log_r1817(viewed_at DESC);

ALTER TABLE public.investor_pitch_material_distributions_r1817 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_pitch_material_view_log_r1817 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ipmd_r1817_founder_all ON public.investor_pitch_material_distributions_r1817;
CREATE POLICY ipmd_r1817_founder_all ON public.investor_pitch_material_distributions_r1817
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS ipmvl_r1817_founder_all ON public.investor_pitch_material_view_log_r1817;
CREATE POLICY ipmvl_r1817_founder_all ON public.investor_pitch_material_view_log_r1817
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================
-- RPC: list_distributions
-- =========================================================
DROP FUNCTION IF EXISTS public.list_distributions_r1817();
CREATE OR REPLACE FUNCTION public.list_distributions_r1817()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  material_type text,
  version_label text,
  shared_at timestamptz,
  expires_at timestamptz,
  watermark text,
  accessed boolean,
  accessed_at timestamptz,
  status text,
  view_count int
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
  SELECT d.id, d.investor_id, d.material_type, d.version_label, d.shared_at, d.expires_at,
         d.watermark, d.accessed, d.accessed_at, d.status,
         (SELECT COUNT(*) FROM public.investor_pitch_material_view_log_r1817 v WHERE v.distribution_id = d.id)::int AS view_count
  FROM public.investor_pitch_material_distributions_r1817 d
  ORDER BY d.shared_at DESC
  LIMIT 500;
END;
$$;

-- =========================================================
-- RPC: share_material
-- =========================================================
DROP FUNCTION IF EXISTS public.share_material_r1817(uuid, text, text, timestamptz, text);
CREATE OR REPLACE FUNCTION public.share_material_r1817(
  p_investor_id uuid,
  p_material_type text,
  p_version_label text,
  p_expires_at timestamptz,
  p_watermark text
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

  INSERT INTO public.investor_pitch_material_distributions_r1817 (investor_id, material_type, version_label, expires_at, watermark)
  VALUES (p_investor_id, p_material_type, p_version_label, p_expires_at, p_watermark)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'share_material_r1817',
          jsonb_build_object('distribution_id', v_id, 'investor_id', p_investor_id, 'material_type', p_material_type, 'version_label', p_version_label));

  RETURN v_id;
END;
$$;

-- =========================================================
-- RPC: list_view_log
-- =========================================================
DROP FUNCTION IF EXISTS public.list_view_log_r1817(uuid);
CREATE OR REPLACE FUNCTION public.list_view_log_r1817(p_distribution_id uuid)
RETURNS TABLE (
  id uuid,
  distribution_id uuid,
  viewer_email text,
  viewed_at timestamptz,
  ip_address text,
  geo_location text,
  view_duration_sec int
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
  SELECT v.id, v.distribution_id, v.viewer_email, v.viewed_at, v.ip_address, v.geo_location, v.view_duration_sec
  FROM public.investor_pitch_material_view_log_r1817 v
  WHERE p_distribution_id IS NULL OR v.distribution_id = p_distribution_id
  ORDER BY v.viewed_at DESC
  LIMIT 500;
END;
$$;

-- =========================================================
-- RPC: log_view
-- =========================================================
DROP FUNCTION IF EXISTS public.log_view_r1817(uuid, text, text, text, int);
CREATE OR REPLACE FUNCTION public.log_view_r1817(
  p_distribution_id uuid,
  p_viewer_email text,
  p_ip_address text,
  p_geo_location text,
  p_view_duration_sec int
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

  INSERT INTO public.investor_pitch_material_view_log_r1817 (distribution_id, viewer_email, ip_address, geo_location, view_duration_sec)
  VALUES (p_distribution_id, p_viewer_email, p_ip_address, p_geo_location, p_view_duration_sec)
  RETURNING id INTO v_id;

  UPDATE public.investor_pitch_material_distributions_r1817
  SET accessed = true, accessed_at = COALESCE(accessed_at, now()), updated_at = now()
  WHERE id = p_distribution_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_view_r1817',
          jsonb_build_object('view_id', v_id, 'distribution_id', p_distribution_id, 'viewer_email', p_viewer_email));

  RETURN v_id;
END;
$$;

-- =========================================================
-- RPC: revoke_material
-- =========================================================
DROP FUNCTION IF EXISTS public.revoke_material_r1817(uuid);
CREATE OR REPLACE FUNCTION public.revoke_material_r1817(p_distribution_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.investor_pitch_material_distributions_r1817
  SET status = 'revoked', updated_at = now()
  WHERE id = p_distribution_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'revoke_material_r1817',
          jsonb_build_object('distribution_id', p_distribution_id));
END;
$$;

-- =========================================================
-- RPC: expiring_distributions
-- =========================================================
DROP FUNCTION IF EXISTS public.expiring_distributions_r1817();
CREATE OR REPLACE FUNCTION public.expiring_distributions_r1817()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  material_type text,
  version_label text,
  expires_at timestamptz,
  days_until_expiry int,
  status text
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
  SELECT d.id, d.investor_id, d.material_type, d.version_label, d.expires_at,
         EXTRACT(DAY FROM (d.expires_at - now()))::int AS days_until_expiry,
         d.status
  FROM public.investor_pitch_material_distributions_r1817 d
  WHERE d.expires_at IS NOT NULL
    AND d.expires_at > now()
    AND d.expires_at < now() + interval '14 days'
    AND d.status = 'active'
  ORDER BY d.expires_at ASC
  LIMIT 100;
END;
$$;

-- =========================================================
-- RPC: top_viewed_materials
-- =========================================================
DROP FUNCTION IF EXISTS public.top_viewed_materials_r1817();
CREATE OR REPLACE FUNCTION public.top_viewed_materials_r1817()
RETURNS TABLE (
  distribution_id uuid,
  material_type text,
  version_label text,
  view_count int,
  total_view_duration_sec int,
  last_viewed_at timestamptz
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
  SELECT d.id AS distribution_id,
         d.material_type,
         d.version_label,
         (COUNT(v.id))::int AS view_count,
         COALESCE(SUM(v.view_duration_sec), 0)::int AS total_view_duration_sec,
         MAX(v.viewed_at) AS last_viewed_at
  FROM public.investor_pitch_material_distributions_r1817 d
  LEFT JOIN public.investor_pitch_material_view_log_r1817 v ON v.distribution_id = d.id
  GROUP BY d.id, d.material_type, d.version_label
  ORDER BY view_count DESC, total_view_duration_sec DESC
  LIMIT 50;
END;
$$;

-- =========================================================
-- Grants
-- =========================================================
REVOKE EXECUTE ON FUNCTION public.list_distributions_r1817() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.share_material_r1817(uuid, text, text, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_view_log_r1817(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_view_r1817(uuid, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.revoke_material_r1817(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_distributions_r1817() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_viewed_materials_r1817() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_distributions_r1817() TO authenticated;
GRANT EXECUTE ON FUNCTION public.share_material_r1817(uuid, text, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_view_log_r1817(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_view_r1817(uuid, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_material_r1817(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_distributions_r1817() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_viewed_materials_r1817() TO authenticated;

COMMIT;