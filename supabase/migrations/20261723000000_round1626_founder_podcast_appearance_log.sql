BEGIN;

CREATE TABLE IF NOT EXISTS founder_podcast_appearances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  podcast_name text NOT NULL,
  host_name text,
  episode_title text,
  episode_url text,
  transcript_url text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  audience_size int NOT NULL DEFAULT 0,
  topic text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS founder_podcast_followup_leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appearance_id uuid NOT NULL REFERENCES founder_podcast_appearances(id) ON DELETE CASCADE,
  lead_name text NOT NULL,
  lead_org text,
  lead_email text,
  lead_phone text,
  status text NOT NULL DEFAULT 'new',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_podcast_appearances ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_podcast_followup_leads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_podcast_appearances ON founder_podcast_appearances;
CREATE POLICY founder_only_podcast_appearances ON founder_podcast_appearances
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_podcast_leads ON founder_podcast_followup_leads;
CREATE POLICY founder_only_podcast_leads ON founder_podcast_followup_leads
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_podcast_appearances_recorded ON founder_podcast_appearances(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_podcast_leads_appearance ON founder_podcast_followup_leads(appearance_id);

-- READ RPCs (STABLE)
CREATE OR REPLACE FUNCTION founder_list_podcast_appearances()
RETURNS TABLE(id uuid, podcast_name text, host_name text, episode_title text, episode_url text, transcript_url text, recorded_at timestamptz, published_at timestamptz, audience_size int, topic text, lead_count bigint, total_audience bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.podcast_name, a.host_name, a.episode_title, a.episode_url, a.transcript_url, a.recorded_at, a.published_at, a.audience_size, a.topic,
    (SELECT count(*) FROM founder_podcast_followup_leads l WHERE l.appearance_id = a.id),
    a.audience_size::bigint
  FROM founder_podcast_appearances a
  ORDER BY a.recorded_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_list_podcast_appearances() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_list_podcast_appearances() TO authenticated;

CREATE OR REPLACE FUNCTION founder_list_podcast_leads()
RETURNS TABLE(id uuid, appearance_id uuid, podcast_name text, lead_name text, lead_org text, lead_email text, lead_phone text, status text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.appearance_id, a.podcast_name, l.lead_name, l.lead_org, l.lead_email, l.lead_phone, l.status, l.created_at
  FROM founder_podcast_followup_leads l
  JOIN founder_podcast_appearances a ON a.id = l.appearance_id
  ORDER BY l.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_list_podcast_leads() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_list_podcast_leads() TO authenticated;

CREATE OR REPLACE FUNCTION founder_podcast_summary()
RETURNS TABLE(total_appearances bigint, total_audience bigint, total_leads bigint, converted_leads bigint, last_recorded_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM founder_podcast_appearances),
    (SELECT COALESCE(sum(audience_size),0)::bigint FROM founder_podcast_appearances),
    (SELECT count(*) FROM founder_podcast_followup_leads),
    (SELECT count(*) FROM founder_podcast_followup_leads WHERE status = 'converted'),
    (SELECT max(recorded_at) FROM founder_podcast_appearances);
END $$;
REVOKE EXECUTE ON FUNCTION founder_podcast_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_podcast_summary() TO authenticated;

-- WRITE RPCs (VOLATILE)
CREATE OR REPLACE FUNCTION log_founder_podcast_appearance(
  p_podcast_name text, p_host_name text, p_episode_title text, p_episode_url text,
  p_transcript_url text, p_recorded_at timestamptz, p_published_at timestamptz,
  p_audience_size int, p_topic text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_podcast_appearances(podcast_name, host_name, episode_title, episode_url, transcript_url, recorded_at, published_at, audience_size, topic, notes)
  VALUES (p_podcast_name, p_host_name, p_episode_title, p_episode_url, p_transcript_url, COALESCE(p_recorded_at, now()), p_published_at, COALESCE(p_audience_size,0), p_topic, p_notes)
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_podcast_appearance', jsonb_build_object('id', v_id, 'podcast_name', p_podcast_name, 'audience_size', p_audience_size), now());
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_podcast_appearance(text,text,text,text,text,timestamptz,timestamptz,int,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_podcast_appearance(text,text,text,text,text,timestamptz,timestamptz,int,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_podcast_lead(
  p_appearance_id uuid, p_lead_name text, p_lead_org text, p_lead_email text, p_lead_phone text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_podcast_followup_leads(appearance_id, lead_name, lead_org, lead_email, lead_phone, notes)
  VALUES (p_appearance_id, p_lead_name, p_lead_org, p_lead_email, p_lead_phone, p_notes)
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_podcast_lead', jsonb_build_object('id', v_id, 'appearance_id', p_appearance_id, 'lead_name', p_lead_name), now());
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_podcast_lead(uuid,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_podcast_lead(uuid,text,text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_podcast_lead_status(p_lead_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_podcast_followup_leads SET status = p_status WHERE id = p_lead_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_podcast_lead_status', jsonb_build_object('lead_id', p_lead_id, 'status', p_status), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_podcast_lead_status(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_podcast_lead_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_podcast_audience(p_appearance_id uuid, p_audience_size int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_podcast_appearances SET audience_size = p_audience_size WHERE id = p_appearance_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_podcast_audience', jsonb_build_object('appearance_id', p_appearance_id, 'audience_size', p_audience_size), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_podcast_audience(uuid,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_podcast_audience(uuid,int) TO authenticated;

COMMIT;