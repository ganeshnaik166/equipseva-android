BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_contact_rotation_log_r2295 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('strategic','growth','watch','dormant')),
  region text NOT NULL,
  former_contact_name text NOT NULL,
  former_contact_title text NOT NULL,
  former_contact_email text,
  new_contact_name text,
  new_contact_title text,
  new_contact_email text,
  rotation_detected_at timestamptz NOT NULL DEFAULT now(),
  rotation_source text NOT NULL CHECK (rotation_source IN ('linkedin','press','email_bounce','referral','direct_notice','field_intel')),
  relationship_depth_score int NOT NULL DEFAULT 0 CHECK (relationship_depth_score BETWEEN 0 AND 100),
  arr_at_risk_rupees bigint NOT NULL DEFAULT 0,
  bridge_status text NOT NULL DEFAULT 'pending' CHECK (bridge_status IN ('pending','intro_sent','meeting_booked','rapport_built','bridge_secured','bridge_lost')),
  bridge_owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  bridge_secured_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcc_rot_log_r2295_chain ON public.hospital_chain_contact_rotation_log_r2295(chain_name);
CREATE INDEX IF NOT EXISTS idx_hcc_rot_log_r2295_status ON public.hospital_chain_contact_rotation_log_r2295(bridge_status);
CREATE INDEX IF NOT EXISTS idx_hcc_rot_log_r2295_detected ON public.hospital_chain_contact_rotation_log_r2295(rotation_detected_at DESC);

ALTER TABLE public.hospital_chain_contact_rotation_log_r2295 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_contact_rotation_log_r2295;
CREATE POLICY founder_all ON public.hospital_chain_contact_rotation_log_r2295
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_chain_contact_reengagement_plays_r2295 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rotation_id uuid NOT NULL REFERENCES public.hospital_chain_contact_rotation_log_r2295(id) ON DELETE CASCADE,
  play_type text NOT NULL CHECK (play_type IN ('warm_intro','case_study_send','executive_brief','site_visit','referral_path','social_engage','founder_letter')),
  play_status text NOT NULL DEFAULT 'planned' CHECK (play_status IN ('planned','executed','responded','no_response','escalated')),
  executed_at timestamptz,
  outcome_score int CHECK (outcome_score BETWEEN 0 AND 10),
  outcome_notes text,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcc_reeng_plays_r2295_rotation ON public.hospital_chain_contact_reengagement_plays_r2295(rotation_id);
CREATE INDEX IF NOT EXISTS idx_hcc_reeng_plays_r2295_status ON public.hospital_chain_contact_reengagement_plays_r2295(play_status);

ALTER TABLE public.hospital_chain_contact_reengagement_plays_r2295 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_contact_reengagement_plays_r2295;
CREATE POLICY founder_all ON public.hospital_chain_contact_reengagement_plays_r2295
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.fn_hcc_rotation_overview_r2295()
RETURNS TABLE (
  open_rotations int,
  bridges_secured int,
  bridges_lost int,
  arr_at_risk_total_rupees bigint,
  arr_secured_rupees bigint,
  bridge_success_pct numeric,
  avg_days_to_bridge numeric,
  strategic_chains_open int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE bridge_status NOT IN ('bridge_secured','bridge_lost')))::int,
    (COUNT(*) FILTER (WHERE bridge_status = 'bridge_secured'))::int,
    (COUNT(*) FILTER (WHERE bridge_status = 'bridge_lost'))::int,
    COALESCE(SUM(arr_at_risk_rupees) FILTER (WHERE bridge_status NOT IN ('bridge_secured','bridge_lost')), 0)::bigint,
    COALESCE(SUM(arr_at_risk_rupees) FILTER (WHERE bridge_status = 'bridge_secured'), 0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE bridge_status IN ('bridge_secured','bridge_lost')) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE bridge_status = 'bridge_secured')
                    / NULLIF(COUNT(*) FILTER (WHERE bridge_status IN ('bridge_secured','bridge_lost')), 0), 1)
    END,
    COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (bridge_secured_at - rotation_detected_at)) / 86400.0) FILTER (WHERE bridge_secured_at IS NOT NULL), 1), 0),
    (COUNT(*) FILTER (WHERE chain_tier = 'strategic' AND bridge_status NOT IN ('bridge_secured','bridge_lost')))::int
  FROM public.hospital_chain_contact_rotation_log_r2295;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_hcc_rotation_overview_r2295() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_hcc_rotation_overview_r2295() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_hcc_rotation_open_r2295()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  region text,
  former_contact text,
  new_contact text,
  rotation_detected_at timestamptz,
  arr_at_risk_rupees bigint,
  bridge_status text,
  days_open numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.chain_name,
    r.chain_tier,
    r.region,
    (r.former_contact_name || ' (' || r.former_contact_title || ')')::text,
    COALESCE(r.new_contact_name || ' (' || COALESCE(r.new_contact_title,'TBD') || ')', 'unknown')::text,
    r.rotation_detected_at,
    r.arr_at_risk_rupees,
    r.bridge_status,
    ROUND(EXTRACT(EPOCH FROM (now() - r.rotation_detected_at)) / 86400.0, 1)
  FROM public.hospital_chain_contact_rotation_log_r2295 r
  WHERE r.bridge_status NOT IN ('bridge_secured','bridge_lost')
  ORDER BY r.arr_at_risk_rupees DESC, r.rotation_detected_at ASC
  LIMIT 100;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_hcc_rotation_open_r2295() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_hcc_rotation_open_r2295() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_hcc_rotation_by_tier_r2295()
RETURNS TABLE (
  chain_tier text,
  rotations int,
  bridges_secured int,
  bridges_lost int,
  success_pct numeric,
  arr_at_risk_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.chain_tier,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE r.bridge_status = 'bridge_secured'))::int,
    (COUNT(*) FILTER (WHERE r.bridge_status = 'bridge_lost'))::int,
    CASE WHEN COUNT(*) FILTER (WHERE r.bridge_status IN ('bridge_secured','bridge_lost')) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE r.bridge_status = 'bridge_secured')
                    / NULLIF(COUNT(*) FILTER (WHERE r.bridge_status IN ('bridge_secured','bridge_lost')), 0), 1)
    END,
    COALESCE(SUM(r.arr_at_risk_rupees), 0)::bigint
  FROM public.hospital_chain_contact_rotation_log_r2295 r
  GROUP BY r.chain_tier
  ORDER BY COALESCE(SUM(r.arr_at_risk_rupees), 0) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_hcc_rotation_by_tier_r2295() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_hcc_rotation_by_tier_r2295() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_hcc_rotation_source_mix_r2295()
RETURNS TABLE (
  rotation_source text,
  rotations int,
  bridges_secured int,
  success_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.rotation_source,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE r.bridge_status = 'bridge_secured'))::int,
    CASE WHEN COUNT(*) FILTER (WHERE r.bridge_status IN ('bridge_secured','bridge_lost')) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE r.bridge_status = 'bridge_secured')
                    / NULLIF(COUNT(*) FILTER (WHERE r.bridge_status IN ('bridge_secured','bridge_lost')), 0), 1)
    END
  FROM public.hospital_chain_contact_rotation_log_r2295 r
  GROUP BY r.rotation_source
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_hcc_rotation_source_mix_r2295() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_hcc_rotation_source_mix_r2295() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_hcc_play_effectiveness_r2295()
RETURNS TABLE (
  play_type text,
  plays_run int,
  plays_responded int,
  response_rate_pct numeric,
  avg_outcome_score numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.play_type,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE p.play_status = 'responded'))::int,
    CASE WHEN COUNT(*) FILTER (WHERE p.play_status IN ('responded','no_response')) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE p.play_status = 'responded')
                    / NULLIF(COUNT(*) FILTER (WHERE p.play_status IN ('responded','no_response')), 0), 1)
    END,
    COALESCE(ROUND(AVG(p.outcome_score), 1), 0)
  FROM public.hospital_chain_contact_reengagement_plays_r2295 p
  GROUP BY p.play_type
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_hcc_play_effectiveness_r2295() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_hcc_play_effectiveness_r2295() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_hcc_rotation_recent_r2295()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  rotation_detected_at timestamptz,
  rotation_source text,
  bridge_status text,
  arr_at_risk_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.chain_tier, r.rotation_detected_at, r.rotation_source, r.bridge_status, r.arr_at_risk_rupees
  FROM public.hospital_chain_contact_rotation_log_r2295 r
  ORDER BY r.rotation_detected_at DESC
  LIMIT 25;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_hcc_rotation_recent_r2295() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_hcc_rotation_recent_r2295() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_hcc_log_rotation_r2295(
  p_chain_name text,
  p_chain_tier text,
  p_region text,
  p_former_name text,
  p_former_title text,
  p_rotation_source text,
  p_arr_at_risk_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_chain_contact_rotation_log_r2295(
    chain_name, chain_tier, region, former_contact_name, former_contact_title,
    rotation_source, arr_at_risk_rupees
  ) VALUES (
    p_chain_name, p_chain_tier, p_region, p_former_name, p_former_title,
    p_rotation_source, p_arr_at_risk_rupees
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_hcc_log_rotation_r2295(text, text, text, text, text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_hcc_log_rotation_r2295(text, text, text, text, text, text, bigint) TO authenticated;

COMMIT;
