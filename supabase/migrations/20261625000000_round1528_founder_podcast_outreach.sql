BEGIN;

-- Round 1528 — Founder Podcast Outreach Console
-- Target list of podcasts to pitch founder for; per-podcast fit-score, contact,
-- outreach status, recorded date; ROI per appearance.

-- =========================================================================
-- TABLES
-- =========================================================================

CREATE TABLE IF NOT EXISTS founder_podcast_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  podcast_name text NOT NULL,
  host_name text,
  category text NOT NULL DEFAULT 'business',
  audience_size_estimate int NOT NULL DEFAULT 0,
  audience_match_pct numeric(5,2) NOT NULL DEFAULT 0,
  domain_authority int NOT NULL DEFAULT 0,
  contact_email text,
  contact_handle text,
  pitch_url text,
  fit_score numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'identified'
    CHECK (status IN ('identified','researching','pitched','responded','scheduled','recorded','published','rejected','ghosted')),
  pitched_at timestamptz,
  responded_at timestamptz,
  scheduled_at timestamptz,
  recorded_at timestamptz,
  published_at timestamptz,
  episode_url text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpt_status ON founder_podcast_targets(status);
CREATE INDEX IF NOT EXISTS idx_fpt_fit_score ON founder_podcast_targets(fit_score DESC);
CREATE INDEX IF NOT EXISTS idx_fpt_recorded_at ON founder_podcast_targets(recorded_at DESC);

CREATE TABLE IF NOT EXISTS founder_podcast_appearance_roi (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  podcast_id uuid NOT NULL REFERENCES founder_podcast_targets(id) ON DELETE CASCADE,
  measured_at timestamptz NOT NULL DEFAULT now(),
  signups_attributed int NOT NULL DEFAULT 0,
  hospital_leads_attributed int NOT NULL DEFAULT 0,
  inbound_messages int NOT NULL DEFAULT 0,
  pipeline_value_rupees bigint NOT NULL DEFAULT 0,
  closed_revenue_rupees bigint NOT NULL DEFAULT 0,
  brand_lift_score numeric(5,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpar_podcast ON founder_podcast_appearance_roi(podcast_id);
CREATE INDEX IF NOT EXISTS idx_fpar_measured ON founder_podcast_appearance_roi(measured_at DESC);

ALTER TABLE founder_podcast_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_podcast_appearance_roi ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fpt_founder_all ON founder_podcast_targets;
CREATE POLICY fpt_founder_all ON founder_podcast_targets
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS fpar_founder_all ON founder_podcast_appearance_roi;
CREATE POLICY fpar_founder_all ON founder_podcast_appearance_roi
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================================
-- LOG HELPERS (4)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_podcast_target_add(p_target uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'podcast_target_add',
          jsonb_build_object('target_id', p_target, 'payload', p_payload));
END $$;

CREATE OR REPLACE FUNCTION log_founder_podcast_status_change(p_target uuid, p_old text, p_new text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'podcast_status_change',
          jsonb_build_object('target_id', p_target, 'old', p_old, 'new', p_new));
END $$;

CREATE OR REPLACE FUNCTION log_founder_podcast_roi_record(p_target uuid, p_roi jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'podcast_roi_record',
          jsonb_build_object('target_id', p_target, 'roi', p_roi));
END $$;

CREATE OR REPLACE FUNCTION log_founder_podcast_fit_recompute(p_target uuid, p_score numeric)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'podcast_fit_recompute',
          jsonb_build_object('target_id', p_target, 'fit_score', p_score));
END $$;

-- =========================================================================
-- READ RPCs (5 STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_podcast_pipeline_summary()
RETURNS TABLE(
  total_targets bigint,
  identified bigint,
  pitched bigint,
  responded bigint,
  scheduled bigint,
  recorded bigint,
  published bigint,
  rejected bigint,
  ghosted bigint,
  avg_fit_score numeric,
  total_audience bigint,
  recorded_audience bigint,
  response_rate_pct numeric,
  recorded_rate_pct numeric,
  pipeline_value_rupees bigint,
  closed_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH t AS (SELECT * FROM founder_podcast_targets),
       r AS (SELECT COALESCE(SUM(pipeline_value_rupees),0) AS pv,
                    COALESCE(SUM(closed_revenue_rupees),0) AS cv
             FROM founder_podcast_appearance_roi)
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status='identified')::bigint,
    COUNT(*) FILTER (WHERE status='pitched')::bigint,
    COUNT(*) FILTER (WHERE status='responded')::bigint,
    COUNT(*) FILTER (WHERE status='scheduled')::bigint,
    COUNT(*) FILTER (WHERE status='recorded')::bigint,
    COUNT(*) FILTER (WHERE status='published')::bigint,
    COUNT(*) FILTER (WHERE status='rejected')::bigint,
    COUNT(*) FILTER (WHERE status='ghosted')::bigint,
    ROUND(COALESCE(AVG(fit_score),0)::numeric, 2),
    COALESCE(SUM(audience_size_estimate),0)::bigint,
    COALESCE(SUM(audience_size_estimate) FILTER (WHERE status IN ('recorded','published')),0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE status IN ('pitched','responded','scheduled','recorded','published','rejected','ghosted'))=0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE status IN ('responded','scheduled','recorded','published'))
              / NULLIF(COUNT(*) FILTER (WHERE status IN ('pitched','responded','scheduled','recorded','published','rejected','ghosted')),0), 2) END,
    CASE WHEN COUNT(*)=0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE status IN ('recorded','published')) / NULLIF(COUNT(*),0), 2) END,
    (SELECT pv FROM r),
    (SELECT cv FROM r)
  FROM t;
END $$;

CREATE OR REPLACE FUNCTION founder_podcast_target_list(p_status text DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  podcast_name text,
  host_name text,
  category text,
  audience_size_estimate int,
  audience_match_pct numeric,
  fit_score numeric,
  status text,
  pitched_at timestamptz,
  recorded_at timestamptz,
  days_in_stage numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.podcast_name, t.host_name, t.category,
         t.audience_size_estimate, t.audience_match_pct, t.fit_score, t.status,
         t.pitched_at, t.recorded_at,
         ROUND(EXTRACT(EPOCH FROM (now() - t.updated_at))/86400.0, 1)::numeric
  FROM founder_podcast_targets t
  WHERE p_status IS NULL OR t.status = p_status
  ORDER BY t.fit_score DESC, t.audience_size_estimate DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION founder_podcast_top_fit(p_limit int DEFAULT 20)
RETURNS TABLE(
  id uuid,
  podcast_name text,
  host_name text,
  fit_score numeric,
  audience_size_estimate int,
  status text,
  contact_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.podcast_name, t.host_name, t.fit_score,
         t.audience_size_estimate, t.status, t.contact_email
  FROM founder_podcast_targets t
  WHERE t.status IN ('identified','researching','pitched','responded')
  ORDER BY t.fit_score DESC
  LIMIT GREATEST(p_limit, 1);
END $$;

CREATE OR REPLACE FUNCTION founder_podcast_recorded_list()
RETURNS TABLE(
  id uuid,
  podcast_name text,
  recorded_at timestamptz,
  published_at timestamptz,
  episode_url text,
  audience_size_estimate int,
  signups_attributed int,
  closed_revenue_rupees bigint,
  roi_ratio numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.podcast_name, t.recorded_at, t.published_at, t.episode_url,
         t.audience_size_estimate,
         COALESCE(SUM(r.signups_attributed),0)::int,
         COALESCE(SUM(r.closed_revenue_rupees),0)::bigint,
         CASE WHEN COALESCE(SUM(r.pipeline_value_rupees),0) = 0 THEN 0
              ELSE ROUND(COALESCE(SUM(r.closed_revenue_rupees),0)::numeric
                   / NULLIF(SUM(r.pipeline_value_rupees),0)::numeric, 3) END
  FROM founder_podcast_targets t
  LEFT JOIN founder_podcast_appearance_roi r ON r.podcast_id = t.id
  WHERE t.status IN ('recorded','published')
  GROUP BY t.id
  ORDER BY t.recorded_at DESC NULLS LAST
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION founder_podcast_roi_breakdown()
RETURNS TABLE(
  podcast_id uuid,
  podcast_name text,
  recorded_at timestamptz,
  signups int,
  hospital_leads int,
  inbound int,
  pipeline_rupees bigint,
  closed_rupees bigint,
  cost_per_signup numeric,
  brand_lift numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.podcast_name, t.recorded_at,
         COALESCE(SUM(r.signups_attributed),0)::int,
         COALESCE(SUM(r.hospital_leads_attributed),0)::int,
         COALESCE(SUM(r.inbound_messages),0)::int,
         COALESCE(SUM(r.pipeline_value_rupees),0)::bigint,
         COALESCE(SUM(r.closed_revenue_rupees),0)::bigint,
         CASE WHEN COALESCE(SUM(r.signups_attributed),0) = 0 THEN 0
              ELSE ROUND(COALESCE(SUM(r.closed_revenue_rupees),0)::numeric
                   / NULLIF(SUM(r.signups_attributed),0)::numeric, 2) END,
         ROUND(COALESCE(AVG(r.brand_lift_score),0)::numeric, 2)
  FROM founder_podcast_targets t
  LEFT JOIN founder_podcast_appearance_roi r ON r.podcast_id = t.id
  WHERE t.status IN ('recorded','published')
  GROUP BY t.id
  ORDER BY COALESCE(SUM(r.closed_revenue_rupees),0) DESC
  LIMIT 100;
END $$;

-- =========================================================================
-- WRITE RPCs (2 VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_podcast_target_upsert(
  p_id uuid,
  p_podcast_name text,
  p_host_name text,
  p_category text,
  p_audience int,
  p_audience_match_pct numeric,
  p_domain_authority int,
  p_contact_email text,
  p_fit_score numeric,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_old text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO founder_podcast_targets(podcast_name, host_name, category,
      audience_size_estimate, audience_match_pct, domain_authority,
      contact_email, fit_score, status)
    VALUES (p_podcast_name, p_host_name, COALESCE(p_category,'business'),
      COALESCE(p_audience,0), COALESCE(p_audience_match_pct,0),
      COALESCE(p_domain_authority,0), p_contact_email,
      COALESCE(p_fit_score,0), COALESCE(p_status,'identified'))
    RETURNING id INTO v_id;
    PERFORM log_founder_podcast_target_add(v_id, jsonb_build_object('name', p_podcast_name));
  ELSE
    SELECT status INTO v_old FROM founder_podcast_targets WHERE id = p_id;
    UPDATE founder_podcast_targets
      SET podcast_name = p_podcast_name,
          host_name = p_host_name,
          category = COALESCE(p_category, category),
          audience_size_estimate = COALESCE(p_audience, audience_size_estimate),
          audience_match_pct = COALESCE(p_audience_match_pct, audience_match_pct),
          domain_authority = COALESCE(p_domain_authority, domain_authority),
          contact_email = p_contact_email,
          fit_score = COALESCE(p_fit_score, fit_score),
          status = COALESCE(p_status, status),
          updated_at = now()
      WHERE id = p_id;
    v_id := p_id;
    IF v_old IS DISTINCT FROM p_status AND p_status IS NOT NULL THEN
      PERFORM log_founder_podcast_status_change(v_id, v_old, p_status);
    END IF;
  END IF;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION founder_podcast_roi_record(
  p_podcast_id uuid,
  p_signups int,
  p_hospital_leads int,
  p_inbound int,
  p_pipeline_rupees bigint,
  p_closed_rupees bigint,
  p_brand_lift numeric,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_podcast_appearance_roi(podcast_id, signups_attributed,
    hospital_leads_attributed, inbound_messages, pipeline_value_rupees,
    closed_revenue_rupees, brand_lift_score, notes)
  VALUES (p_podcast_id, COALESCE(p_signups,0), COALESCE(p_hospital_leads,0),
    COALESCE(p_inbound,0), COALESCE(p_pipeline_rupees,0),
    COALESCE(p_closed_rupees,0), COALESCE(p_brand_lift,0), p_notes)
  RETURNING id INTO v_id;
  PERFORM log_founder_podcast_roi_record(p_podcast_id,
    jsonb_build_object('signups', p_signups, 'closed', p_closed_rupees));
  RETURN v_id;
END $$;

-- =========================================================================
-- GRANTS
-- =========================================================================

REVOKE EXECUTE ON FUNCTION founder_podcast_pipeline_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_podcast_target_list(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_podcast_top_fit(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_podcast_recorded_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_podcast_roi_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_podcast_target_upsert(uuid,text,text,text,int,numeric,int,text,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_podcast_roi_record(uuid,int,int,int,bigint,bigint,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_podcast_target_add(uuid,jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_podcast_status_change(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_podcast_roi_record(uuid,jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_podcast_fit_recompute(uuid,numeric) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_podcast_pipeline_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_podcast_target_list(text) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_podcast_top_fit(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_podcast_recorded_list() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_podcast_roi_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_podcast_target_upsert(uuid,text,text,text,int,numeric,int,text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_podcast_roi_record(uuid,int,int,int,bigint,bigint,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_podcast_target_add(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_podcast_status_change(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_podcast_roi_record(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_podcast_fit_recompute(uuid,numeric) TO authenticated;

COMMIT;