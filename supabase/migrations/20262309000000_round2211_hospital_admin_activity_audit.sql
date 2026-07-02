BEGIN;

-- ============================================================
-- r2211: Hospital admin user activity audit
-- Two tables suffixed _r2211 to track admin actions across the
-- hospital portal (logins, exports, role changes, settings edits)
-- so the founder can review security posture per hospital.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_admin_activity_events_r2211 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  hospital_name text,
  admin_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  admin_email text,
  admin_role text,
  event_kind text NOT NULL CHECK (event_kind IN (
    'login_success','login_failure','logout',
    'data_export','report_download','bulk_action',
    'role_change','user_invite','user_revoke',
    'settings_edit','password_reset','mfa_change',
    'api_token_issue','api_token_revoke','impersonation'
  )),
  severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info','low','medium','high','critical')),
  ip_address text,
  user_agent text,
  geo_country text,
  geo_city text,
  target_entity text,
  target_id text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_suspicious boolean NOT NULL DEFAULT false,
  reviewed_by_founder boolean NOT NULL DEFAULT false,
  reviewed_at timestamptz,
  review_notes text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_haae_r2211_hospital ON public.hospital_admin_activity_events_r2211(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_haae_r2211_admin ON public.hospital_admin_activity_events_r2211(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_haae_r2211_kind ON public.hospital_admin_activity_events_r2211(event_kind);
CREATE INDEX IF NOT EXISTS idx_haae_r2211_severity ON public.hospital_admin_activity_events_r2211(severity);
CREATE INDEX IF NOT EXISTS idx_haae_r2211_occurred ON public.hospital_admin_activity_events_r2211(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_haae_r2211_suspicious ON public.hospital_admin_activity_events_r2211(is_suspicious) WHERE is_suspicious = true;

CREATE TABLE IF NOT EXISTS public.hospital_admin_audit_reviews_r2211 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  hospital_name text,
  review_window_start timestamptz NOT NULL,
  review_window_end timestamptz NOT NULL,
  total_events int NOT NULL DEFAULT 0,
  suspicious_count int NOT NULL DEFAULT 0,
  high_severity_count int NOT NULL DEFAULT 0,
  verdict text NOT NULL CHECK (verdict IN ('clean','watch','investigate','breach_suspected','breach_confirmed')),
  follow_up_action text,
  reviewer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewer_email text,
  notes text,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_haar_r2211_hospital ON public.hospital_admin_audit_reviews_r2211(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_haar_r2211_verdict ON public.hospital_admin_audit_reviews_r2211(verdict);
CREATE INDEX IF NOT EXISTS idx_haar_r2211_reviewed ON public.hospital_admin_audit_reviews_r2211(reviewed_at DESC);

ALTER TABLE public.hospital_admin_activity_events_r2211 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_admin_audit_reviews_r2211 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_admin_activity_events_r2211;
CREATE POLICY founder_all ON public.hospital_admin_activity_events_r2211
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_admin_audit_reviews_r2211;
CREATE POLICY founder_all ON public.hospital_admin_audit_reviews_r2211
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_activity_events_r2211
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_activity_events_r2211()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  admin_email text,
  admin_role text,
  event_kind text,
  severity text,
  ip_address text,
  geo_country text,
  target_entity text,
  is_suspicious boolean,
  reviewed_by_founder boolean,
  occurred_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_name, e.admin_email, e.admin_role, e.event_kind,
         e.severity, e.ip_address, e.geo_country, e.target_entity,
         e.is_suspicious, e.reviewed_by_founder, e.occurred_at
  FROM public.hospital_admin_activity_events_r2211 e
  ORDER BY e.occurred_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================
-- RPC 2: recent_actions_r2211
-- ============================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r2211()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  verdict text,
  total_events int,
  suspicious_count int,
  follow_up_action text,
  reviewer_email text,
  reviewed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_name, r.verdict, r.total_events, r.suspicious_count,
         r.follow_up_action, r.reviewer_email, r.reviewed_at
  FROM public.hospital_admin_audit_reviews_r2211 r
  ORDER BY r.reviewed_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================
-- RPC 3: top_hospital_r2211
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_hospital_r2211()
RETURNS TABLE(
  hospital_name text,
  total_events int,
  suspicious_events int,
  high_severity_events int,
  unique_admins int,
  last_event_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(e.hospital_name, 'unknown') AS hospital_name,
    COUNT(*)::int AS total_events,
    (COUNT(*) FILTER (WHERE e.is_suspicious))::int AS suspicious_events,
    (COUNT(*) FILTER (WHERE e.severity IN ('high','critical')))::int AS high_severity_events,
    COUNT(DISTINCT e.admin_user_id)::int AS unique_admins,
    MAX(e.occurred_at) AS last_event_at
  FROM public.hospital_admin_activity_events_r2211 e
  GROUP BY COALESCE(e.hospital_name, 'unknown')
  ORDER BY total_events DESC
  LIMIT 25;
END;
$$;

-- ============================================================
-- RPC 4: log_activity_event_r2211
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_activity_event_r2211(
  p_hospital_org_id uuid,
  p_hospital_name text,
  p_admin_user_id uuid,
  p_admin_email text,
  p_admin_role text,
  p_event_kind text,
  p_severity text,
  p_ip_address text,
  p_user_agent text,
  p_geo_country text,
  p_geo_city text,
  p_target_entity text,
  p_target_id text,
  p_payload jsonb,
  p_is_suspicious boolean
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
  INSERT INTO public.hospital_admin_activity_events_r2211(
    hospital_org_id, hospital_name, admin_user_id, admin_email, admin_role,
    event_kind, severity, ip_address, user_agent, geo_country, geo_city,
    target_entity, target_id, payload, is_suspicious
  ) VALUES (
    p_hospital_org_id, p_hospital_name, p_admin_user_id, p_admin_email, p_admin_role,
    p_event_kind, COALESCE(p_severity, 'info'), p_ip_address, p_user_agent, p_geo_country, p_geo_city,
    p_target_entity, p_target_id, COALESCE(p_payload, '{}'::jsonb), COALESCE(p_is_suspicious, false)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2211_log_event',
    jsonb_build_object('event_id', v_id, 'kind', p_event_kind, 'hospital', p_hospital_name));

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: log_action_r2211 (review/verdict entry)
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_action_r2211(
  p_hospital_org_id uuid,
  p_hospital_name text,
  p_window_start timestamptz,
  p_window_end timestamptz,
  p_total_events int,
  p_suspicious_count int,
  p_high_severity_count int,
  p_verdict text,
  p_follow_up_action text,
  p_notes text
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
  INSERT INTO public.hospital_admin_audit_reviews_r2211(
    hospital_org_id, hospital_name, review_window_start, review_window_end,
    total_events, suspicious_count, high_severity_count, verdict,
    follow_up_action, reviewer_user_id, reviewer_email, notes
  ) VALUES (
    p_hospital_org_id, p_hospital_name, p_window_start, p_window_end,
    COALESCE(p_total_events, 0), COALESCE(p_suspicious_count, 0),
    COALESCE(p_high_severity_count, 0), p_verdict,
    p_follow_up_action, auth.uid(), (auth.jwt()->>'email'), p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2211_log_review',
    jsonb_build_object('review_id', v_id, 'verdict', p_verdict, 'hospital', p_hospital_name));

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 6: mark_status_r2211 (mark event reviewed)
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2211(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_status = 'reviewed' THEN
    UPDATE public.hospital_admin_activity_events_r2211
       SET reviewed_by_founder = true,
           reviewed_at = now()
     WHERE id = p_id;
  ELSIF p_status = 'suspicious' THEN
    UPDATE public.hospital_admin_activity_events_r2211
       SET is_suspicious = true
     WHERE id = p_id;
  ELSIF p_status = 'cleared' THEN
    UPDATE public.hospital_admin_activity_events_r2211
       SET is_suspicious = false,
           reviewed_by_founder = true,
           reviewed_at = now()
     WHERE id = p_id;
  ELSE
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2211_mark_status',
    jsonb_build_object('event_id', p_id, 'status', p_status));
END;
$$;

-- ============================================================
-- RPC 7: aggregate_or_search_r2211
-- ============================================================
CREATE OR REPLACE FUNCTION public.aggregate_or_search_r2211()
RETURNS TABLE(
  metric text,
  value_int int,
  value_text text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'total_events_30d'::text,
         (COUNT(*) FILTER (WHERE e.occurred_at > now() - interval '30 days'))::int,
         NULL::text
  FROM public.hospital_admin_activity_events_r2211 e
  UNION ALL
  SELECT 'suspicious_7d'::text,
         (COUNT(*) FILTER (WHERE e.is_suspicious AND e.occurred_at > now() - interval '7 days'))::int,
         NULL::text
  FROM public.hospital_admin_activity_events_r2211 e
  UNION ALL
  SELECT 'high_severity_7d'::text,
         (COUNT(*) FILTER (WHERE e.severity IN ('high','critical') AND e.occurred_at > now() - interval '7 days'))::int,
         NULL::text
  FROM public.hospital_admin_activity_events_r2211 e
  UNION ALL
  SELECT 'unreviewed_count'::text,
         (COUNT(*) FILTER (WHERE NOT e.reviewed_by_founder AND e.is_suspicious))::int,
         NULL::text
  FROM public.hospital_admin_activity_events_r2211 e
  UNION ALL
  SELECT 'top_event_kind'::text,
         NULL::int,
         (SELECT event_kind FROM public.hospital_admin_activity_events_r2211
           GROUP BY event_kind ORDER BY COUNT(*) DESC LIMIT 1)
  UNION ALL
  SELECT 'reviews_logged'::text,
         (SELECT COUNT(*)::int FROM public.hospital_admin_audit_reviews_r2211),
         NULL::text
  UNION ALL
  SELECT 'breach_suspected_count'::text,
         (SELECT (COUNT(*) FILTER (WHERE verdict IN ('breach_suspected','breach_confirmed')))::int
            FROM public.hospital_admin_audit_reviews_r2211),
         NULL::text;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE ALL ON FUNCTION public.list_activity_events_r2211() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2211() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_hospital_r2211() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_activity_event_r2211(uuid, text, uuid, text, text, text, text, text, text, text, text, text, text, jsonb, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2211(uuid, text, timestamptz, timestamptz, int, int, int, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2211(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_or_search_r2211() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_activity_events_r2211() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2211() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_hospital_r2211() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_activity_event_r2211(uuid, text, uuid, text, text, text, text, text, text, text, text, text, text, jsonb, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2211(uuid, text, timestamptz, timestamptz, int, int, int, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2211(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_or_search_r2211() TO authenticated;

COMMIT;
