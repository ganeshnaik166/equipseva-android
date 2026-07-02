BEGIN;

-- ============================================================================
-- r1889 — Investor Confidential Information Memorandum
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_cim_distributions_r1889 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  cim_version_label text NOT NULL,
  cim_url text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  watermark_text text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','revoked')),
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cim_dist_r1889_investor ON public.investor_cim_distributions_r1889(investor_id);
CREATE INDEX IF NOT EXISTS idx_cim_dist_r1889_status ON public.investor_cim_distributions_r1889(status);
CREATE INDEX IF NOT EXISTS idx_cim_dist_r1889_sent ON public.investor_cim_distributions_r1889(sent_at DESC);

CREATE TABLE IF NOT EXISTS public.investor_cim_view_metrics_r1889 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  distribution_id uuid NOT NULL REFERENCES public.investor_cim_distributions_r1889(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  ip_address text,
  viewer_email text,
  view_duration_sec int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cim_views_r1889_dist ON public.investor_cim_view_metrics_r1889(distribution_id);
CREATE INDEX IF NOT EXISTS idx_cim_views_r1889_viewed ON public.investor_cim_view_metrics_r1889(viewed_at DESC);

ALTER TABLE public.investor_cim_distributions_r1889 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_cim_view_metrics_r1889 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_cim_dist_r1889 ON public.investor_cim_distributions_r1889;
CREATE POLICY p_founder_all_cim_dist_r1889 ON public.investor_cim_distributions_r1889
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_all_cim_views_r1889 ON public.investor_cim_view_metrics_r1889;
CREATE POLICY p_founder_all_cim_views_r1889 ON public.investor_cim_view_metrics_r1889
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_distributions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_distributions_r1889();
CREATE OR REPLACE FUNCTION public.list_distributions_r1889()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  cim_version_label text,
  cim_url text,
  sent_at timestamptz,
  status text,
  expires_at timestamptz,
  watermark_text text,
  view_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.investor_id,
    p.email::text,
    d.cim_version_label,
    d.cim_url,
    d.sent_at,
    d.status,
    d.expires_at,
    d.watermark_text,
    (SELECT COUNT(*) FROM public.investor_cim_view_metrics_r1889 v WHERE v.distribution_id = d.id)::int
  FROM public.investor_cim_distributions_r1889 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  ORDER BY d.sent_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_distributions_r1889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_distributions_r1889() TO authenticated;

-- ============================================================================
-- RPC 2: send_cim
-- ============================================================================
DROP FUNCTION IF EXISTS public.send_cim_r1889(uuid, text, text, text, timestamptz);
CREATE OR REPLACE FUNCTION public.send_cim_r1889(
  p_investor_id uuid,
  p_version_label text,
  p_cim_url text,
  p_watermark text,
  p_expires_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cim_distributions_r1889(
    investor_id, cim_version_label, cim_url, watermark_text, expires_at, status
  ) VALUES (
    p_investor_id, p_version_label, p_cim_url, p_watermark, p_expires_at, 'active'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'send_cim_r1889',
    jsonb_build_object('distribution_id', v_id, 'investor_id', p_investor_id, 'version', p_version_label));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_cim_r1889(uuid, text, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_cim_r1889(uuid, text, text, text, timestamptz) TO authenticated;

-- ============================================================================
-- RPC 3: list_view_metrics
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_view_metrics_r1889(uuid);
CREATE OR REPLACE FUNCTION public.list_view_metrics_r1889(p_distribution_id uuid)
RETURNS TABLE (
  id uuid,
  viewed_at timestamptz,
  ip_address text,
  viewer_email text,
  view_duration_sec int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.viewed_at, v.ip_address, v.viewer_email, v.view_duration_sec
  FROM public.investor_cim_view_metrics_r1889 v
  WHERE v.distribution_id = p_distribution_id
  ORDER BY v.viewed_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_view_metrics_r1889(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_view_metrics_r1889(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_view
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_view_r1889(uuid, text, text, int);
CREATE OR REPLACE FUNCTION public.log_view_r1889(
  p_distribution_id uuid,
  p_ip text,
  p_email text,
  p_duration_sec int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cim_view_metrics_r1889(
    distribution_id, ip_address, viewer_email, view_duration_sec
  ) VALUES (
    p_distribution_id, p_ip, p_email, p_duration_sec
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_view_r1889',
    jsonb_build_object('distribution_id', p_distribution_id, 'view_id', v_id));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_view_r1889(uuid, text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_view_r1889(uuid, text, text, int) TO authenticated;

-- ============================================================================
-- RPC 5: revoke_cim
-- ============================================================================
DROP FUNCTION IF EXISTS public.revoke_cim_r1889(uuid);
CREATE OR REPLACE FUNCTION public.revoke_cim_r1889(p_distribution_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cim_distributions_r1889
  SET status = 'revoked', updated_at = now()
  WHERE id = p_distribution_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'revoke_cim_r1889',
    jsonb_build_object('distribution_id', p_distribution_id));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.revoke_cim_r1889(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_cim_r1889(uuid) TO authenticated;

-- ============================================================================
-- RPC 6: top_viewed_cims
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_viewed_cims_r1889();
CREATE OR REPLACE FUNCTION public.top_viewed_cims_r1889()
RETURNS TABLE (
  distribution_id uuid,
  cim_version_label text,
  investor_email text,
  view_count int,
  total_duration_sec int,
  last_viewed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.cim_version_label,
    p.email::text,
    (COUNT(v.id))::int,
    (COALESCE(SUM(v.view_duration_sec),0))::int,
    MAX(v.viewed_at)
  FROM public.investor_cim_distributions_r1889 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  LEFT JOIN public.investor_cim_view_metrics_r1889 v ON v.distribution_id = d.id
  GROUP BY d.id, d.cim_version_label, p.email
  ORDER BY COUNT(v.id) DESC NULLS LAST
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_viewed_cims_r1889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_viewed_cims_r1889() TO authenticated;

-- ============================================================================
-- RPC 7: recent_views
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_views_r1889();
CREATE OR REPLACE FUNCTION public.recent_views_r1889()
RETURNS TABLE (
  view_id uuid,
  distribution_id uuid,
  cim_version_label text,
  investor_email text,
  viewer_email text,
  ip_address text,
  view_duration_sec int,
  viewed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.id,
    v.distribution_id,
    d.cim_version_label,
    p.email::text,
    v.viewer_email,
    v.ip_address,
    v.view_duration_sec,
    v.viewed_at
  FROM public.investor_cim_view_metrics_r1889 v
  JOIN public.investor_cim_distributions_r1889 d ON d.id = v.distribution_id
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  ORDER BY v.viewed_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_views_r1889() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_views_r1889() TO authenticated;

COMMIT;