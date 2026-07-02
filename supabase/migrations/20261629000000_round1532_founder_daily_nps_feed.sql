BEGIN;

-- ============================================================
-- r1532 — Founder Daily NPS Feed
-- Live feed of every NPS response across hospitals + engineers
-- in last 24h; founder triages detractors (<7) within 2h SLA.
-- ============================================================

-- ----- TABLES -----

CREATE TABLE IF NOT EXISTS founder_nps_feed_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_kind text NOT NULL CHECK (source_kind IN ('hospital','engineer')),
  responder_user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  responder_org_id uuid NULL REFERENCES organizations(id) ON DELETE SET NULL,
  related_job_id uuid NULL REFERENCES repair_jobs(id) ON DELETE SET NULL,
  related_engineer_id uuid NULL REFERENCES engineers(id) ON DELETE SET NULL,
  nps_score smallint NOT NULL CHECK (nps_score BETWEEN 0 AND 10),
  bucket text NOT NULL CHECK (bucket IN ('detractor','passive','promoter')),
  verbatim_text text NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  triage_due_at timestamptz NULL,
  triaged_at timestamptz NULL,
  triaged_by_user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  triage_notes text NULL,
  sla_breached boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fnpsf_v2_recorded ON founder_nps_feed_v2 (recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_fnpsf_v2_bucket ON founder_nps_feed_v2 (bucket, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_fnpsf_v2_triage ON founder_nps_feed_v2 (triage_due_at) WHERE triaged_at IS NULL AND bucket = 'detractor';

ALTER TABLE founder_nps_feed_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fnpsf_v2_founder_all ON founder_nps_feed_v2;
CREATE POLICY fnpsf_v2_founder_all ON founder_nps_feed_v2 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_nps_triage_log_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feed_id uuid NOT NULL REFERENCES founder_nps_feed_v2(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('viewed','contacted','resolved','escalated','snoozed')),
  actor_user_id uuid NOT NULL,
  actor_email text NULL,
  notes text NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fnps_triage_v2_feed ON founder_nps_triage_log_v2 (feed_id, created_at DESC);

ALTER TABLE founder_nps_triage_log_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fnps_triage_v2_founder_all ON founder_nps_triage_log_v2;
CREATE POLICY fnps_triage_v2_founder_all ON founder_nps_triage_log_v2 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ----- LOG HELPERS -----

CREATE OR REPLACE FUNCTION log_founder_nps_view(p_filter text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nps_feed.view', jsonb_build_object('filter', p_filter));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_nps_triage(p_feed_id uuid, p_action text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nps_feed.triage', jsonb_build_object('feed_id', p_feed_id, 'action', p_action));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_nps_sla_check(p_breached_count int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nps_feed.sla_check', jsonb_build_object('breached', p_breached_count));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_nps_export(p_window_hours int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nps_feed.export', jsonb_build_object('window_hours', p_window_hours));
END;
$$;

-- ----- READ RPCs (STABLE) -----

CREATE OR REPLACE FUNCTION rpc_founder_nps_feed_kpis()
RETURNS TABLE (
  total_24h bigint,
  hospital_count_24h bigint,
  engineer_count_24h bigint,
  detractor_24h bigint,
  passive_24h bigint,
  promoter_24h bigint,
  nps_score_24h numeric,
  detractor_pct_24h numeric,
  promoter_pct_24h numeric,
  detractor_open bigint,
  detractor_overdue bigint,
  detractor_resolved_24h bigint,
  median_triage_minutes numeric,
  sla_breached_24h bigint,
  total_7d bigint,
  nps_score_7d numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH w24 AS (SELECT * FROM founder_nps_feed_v2 WHERE recorded_at >= now() - interval '24 hours'),
       w7  AS (SELECT * FROM founder_nps_feed_v2 WHERE recorded_at >= now() - interval '7 days'),
       triage AS (
         SELECT EXTRACT(EPOCH FROM (triaged_at - recorded_at))/60.0 AS mins
         FROM founder_nps_feed_v2
         WHERE triaged_at IS NOT NULL AND recorded_at >= now() - interval '7 days'
       )
  SELECT
    (SELECT count(*) FROM w24),
    (SELECT count(*) FROM w24 WHERE source_kind='hospital'),
    (SELECT count(*) FROM w24 WHERE source_kind='engineer'),
    (SELECT count(*) FROM w24 WHERE bucket='detractor'),
    (SELECT count(*) FROM w24 WHERE bucket='passive'),
    (SELECT count(*) FROM w24 WHERE bucket='promoter'),
    COALESCE(ROUND( 100.0 * ((SELECT count(*) FROM w24 WHERE bucket='promoter') - (SELECT count(*) FROM w24 WHERE bucket='detractor'))::numeric / NULLIF((SELECT count(*) FROM w24),0), 1), 0),
    COALESCE(ROUND(100.0 * (SELECT count(*) FROM w24 WHERE bucket='detractor')::numeric / NULLIF((SELECT count(*) FROM w24),0), 1), 0),
    COALESCE(ROUND(100.0 * (SELECT count(*) FROM w24 WHERE bucket='promoter')::numeric / NULLIF((SELECT count(*) FROM w24),0), 1), 0),
    (SELECT count(*) FROM founder_nps_feed_v2 WHERE bucket='detractor' AND triaged_at IS NULL),
    (SELECT count(*) FROM founder_nps_feed_v2 WHERE bucket='detractor' AND triaged_at IS NULL AND triage_due_at < now()),
    (SELECT count(*) FROM w24 WHERE bucket='detractor' AND triaged_at IS NOT NULL),
    COALESCE((SELECT ROUND( (percentile_cont(0.5) WITHIN GROUP (ORDER BY mins))::numeric, 1) FROM triage), 0),
    (SELECT count(*) FROM w24 WHERE sla_breached),
    (SELECT count(*) FROM w7),
    COALESCE(ROUND( 100.0 * ((SELECT count(*) FROM w7 WHERE bucket='promoter') - (SELECT count(*) FROM w7 WHERE bucket='detractor'))::numeric / NULLIF((SELECT count(*) FROM w7),0), 1), 0);
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_nps_feed_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  source_kind text,
  bucket text,
  nps_score smallint,
  responder_email text,
  org_name text,
  verbatim_text text,
  recorded_at timestamptz,
  age_minutes numeric,
  triaged boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.source_kind, f.bucket, f.nps_score,
         u.email::text,
         o.name,
         f.verbatim_text,
         f.recorded_at,
         ROUND(EXTRACT(EPOCH FROM (now() - f.recorded_at))/60.0, 0)::numeric,
         (f.triaged_at IS NOT NULL)
  FROM founder_nps_feed_v2 f
  LEFT JOIN auth.users u ON u.id = f.responder_user_id
  LEFT JOIN organizations o ON o.id = f.responder_org_id
  WHERE f.recorded_at >= now() - interval '24 hours'
  ORDER BY f.recorded_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_nps_detractor_queue()
RETURNS TABLE (
  id uuid,
  source_kind text,
  nps_score smallint,
  responder_email text,
  org_name text,
  verbatim_text text,
  recorded_at timestamptz,
  triage_due_at timestamptz,
  minutes_to_due numeric,
  overdue boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.source_kind, f.nps_score,
         u.email::text, o.name, f.verbatim_text,
         f.recorded_at, f.triage_due_at,
         ROUND(EXTRACT(EPOCH FROM (f.triage_due_at - now()))/60.0, 0)::numeric,
         (f.triage_due_at < now())
  FROM founder_nps_feed_v2 f
  LEFT JOIN auth.users u ON u.id = f.responder_user_id
  LEFT JOIN organizations o ON o.id = f.responder_org_id
  WHERE f.bucket = 'detractor' AND f.triaged_at IS NULL
  ORDER BY f.triage_due_at ASC NULLS LAST
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_nps_by_source()
RETURNS TABLE (
  source_kind text,
  total_24h bigint,
  detractors bigint,
  passives bigint,
  promoters bigint,
  nps_score numeric,
  avg_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.source_kind,
         count(*)::bigint,
         count(*) FILTER (WHERE f.bucket='detractor')::bigint,
         count(*) FILTER (WHERE f.bucket='passive')::bigint,
         count(*) FILTER (WHERE f.bucket='promoter')::bigint,
         COALESCE(ROUND(100.0 * (count(*) FILTER (WHERE f.bucket='promoter') - count(*) FILTER (WHERE f.bucket='detractor'))::numeric / NULLIF(count(*),0), 1), 0),
         COALESCE(ROUND(AVG(f.nps_score)::numeric, 2), 0)
  FROM founder_nps_feed_v2 f
  WHERE f.recorded_at >= now() - interval '24 hours'
  GROUP BY f.source_kind
  ORDER BY f.source_kind;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_nps_recent_triage()
RETURNS TABLE (
  log_id uuid,
  feed_id uuid,
  action text,
  actor_email text,
  notes text,
  created_at timestamptz,
  source_kind text,
  nps_score smallint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.feed_id, t.action, t.actor_email, t.notes, t.created_at,
         f.source_kind, f.nps_score
  FROM founder_nps_triage_log_v2 t
  JOIN founder_nps_feed_v2 f ON f.id = t.feed_id
  ORDER BY t.created_at DESC
  LIMIT 50;
END;
$$;

-- ----- WRITE RPCs (VOLATILE) -----

CREATE OR REPLACE FUNCTION rpc_founder_nps_record(
  p_source_kind text,
  p_nps_score smallint,
  p_responder_user_id uuid,
  p_responder_org_id uuid,
  p_verbatim text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_bucket text;
  v_due timestamptz;
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_bucket := CASE
    WHEN p_nps_score < 7 THEN 'detractor'
    WHEN p_nps_score < 9 THEN 'passive'
    ELSE 'promoter'
  END;
  v_due := CASE WHEN v_bucket = 'detractor' THEN now() + interval '2 hours' ELSE NULL END;
  INSERT INTO founder_nps_feed_v2 (source_kind, nps_score, bucket, responder_user_id, responder_org_id, verbatim_text, triage_due_at)
  VALUES (p_source_kind, p_nps_score, v_bucket, p_responder_user_id, p_responder_org_id, p_verbatim, v_due)
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nps_feed.record', jsonb_build_object('id', v_id, 'bucket', v_bucket));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_nps_triage_action(
  p_feed_id uuid,
  p_action text,
  p_notes text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_action NOT IN ('viewed','contacted','resolved','escalated','snoozed') THEN
    RAISE EXCEPTION 'invalid action';
  END IF;
  INSERT INTO founder_nps_triage_log_v2 (feed_id, action, actor_user_id, actor_email, notes)
  VALUES (p_feed_id, p_action, auth.uid(), (auth.jwt()->>'email'), p_notes);
  IF p_action = 'resolved' THEN
    UPDATE founder_nps_feed_v2
    SET triaged_at = now(),
        triaged_by_user_id = auth.uid(),
        triage_notes = p_notes,
        sla_breached = (triage_due_at IS NOT NULL AND now() > triage_due_at)
    WHERE id = p_feed_id;
  END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nps_feed.triage_action', jsonb_build_object('feed_id', p_feed_id, 'action', p_action));
END;
$$;

-- ----- GRANTS -----

REVOKE EXECUTE ON FUNCTION log_founder_nps_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_nps_view(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_nps_triage(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_nps_triage(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_nps_sla_check(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_nps_sla_check(int) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_nps_export(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_nps_export(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION rpc_founder_nps_feed_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_nps_feed_kpis() TO authenticated;
REVOKE EXECUTE ON FUNCTION rpc_founder_nps_feed_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_nps_feed_recent(int) TO authenticated;
REVOKE EXECUTE ON FUNCTION rpc_founder_nps_detractor_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_nps_detractor_queue() TO authenticated;
REVOKE EXECUTE ON FUNCTION rpc_founder_nps_by_source() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_nps_by_source() TO authenticated;
REVOKE EXECUTE ON FUNCTION rpc_founder_nps_recent_triage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_nps_recent_triage() TO authenticated;
REVOKE EXECUTE ON FUNCTION rpc_founder_nps_record(text, smallint, uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_nps_record(text, smallint, uuid, uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION rpc_founder_nps_triage_action(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_nps_triage_action(uuid, text, text) TO authenticated;

COMMIT;