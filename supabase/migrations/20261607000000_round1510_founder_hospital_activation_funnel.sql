BEGIN;

-- =========================================================
-- Round 1510 — Founder Hospital Activation Funnel
-- First-touch → First-AMC funnel, per-stage drop-off,
-- cohort by acquisition source, founder action ladder.
-- =========================================================

-- Stage events log: every time a hospital crosses a funnel stage.
CREATE TABLE IF NOT EXISTS founder_hospital_funnel_events (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id    uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  stage              text NOT NULL CHECK (stage IN (
    'first_touch','demo_booked','demo_done','quote_sent',
    'first_job','first_job_paid','first_amc'
  )),
  acquisition_source text NOT NULL DEFAULT 'unknown' CHECK (acquisition_source IN (
    'unknown','referral','outbound','inbound','event','partner','founder_direct'
  )),
  reached_at         timestamptz NOT NULL DEFAULT now(),
  meta               jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fhfe_org_idx     ON founder_hospital_funnel_events(organization_id);
CREATE INDEX IF NOT EXISTS fhfe_stage_idx   ON founder_hospital_funnel_events(stage);
CREATE INDEX IF NOT EXISTS fhfe_src_idx     ON founder_hospital_funnel_events(acquisition_source);
CREATE INDEX IF NOT EXISTS fhfe_reached_idx ON founder_hospital_funnel_events(reached_at DESC);

ALTER TABLE founder_hospital_funnel_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fhfe_founder_only ON founder_hospital_funnel_events;
CREATE POLICY fhfe_founder_only ON founder_hospital_funnel_events
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Founder action ladder: prescriptive next-best-action per stuck stage.
CREATE TABLE IF NOT EXISTS founder_hospital_activation_actions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id    uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  stuck_stage        text NOT NULL CHECK (stuck_stage IN (
    'first_touch','demo_booked','demo_done','quote_sent',
    'first_job','first_job_paid','first_amc'
  )),
  action_rung        int  NOT NULL CHECK (action_rung BETWEEN 1 AND 5),
  action_label       text NOT NULL,
  status             text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','skipped')),
  taken_at           timestamptz,
  taken_by           uuid REFERENCES auth.users(id),
  notes              text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fhaa_org_idx    ON founder_hospital_activation_actions(organization_id);
CREATE INDEX IF NOT EXISTS fhaa_status_idx ON founder_hospital_activation_actions(status);
CREATE INDEX IF NOT EXISTS fhaa_stage_idx  ON founder_hospital_activation_actions(stuck_stage);

ALTER TABLE founder_hospital_activation_actions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fhaa_founder_only ON founder_hospital_activation_actions;
CREATE POLICY fhaa_founder_only ON founder_hospital_activation_actions
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================
-- Helpers — log founder writes
-- =========================================================

CREATE OR REPLACE FUNCTION log_founder_funnel_event_recorded(p_org uuid, p_stage text, p_src text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'funnel.event_recorded',
          jsonb_build_object('organization_id', p_org, 'stage', p_stage, 'source', p_src));
END $$;

CREATE OR REPLACE FUNCTION log_founder_funnel_action_created(p_org uuid, p_stage text, p_rung int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'funnel.action_created',
          jsonb_build_object('organization_id', p_org, 'stuck_stage', p_stage, 'rung', p_rung));
END $$;

CREATE OR REPLACE FUNCTION log_founder_funnel_action_completed(p_action uuid, p_status text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'funnel.action_completed',
          jsonb_build_object('action_id', p_action, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION log_founder_funnel_acquisition_tagged(p_org uuid, p_src text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'funnel.acquisition_tagged',
          jsonb_build_object('organization_id', p_org, 'source', p_src));
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_funnel_event_recorded(uuid, text, text)     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_funnel_action_created(uuid, text, int)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_funnel_action_completed(uuid, text)         FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_funnel_acquisition_tagged(uuid, text)       FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_funnel_event_recorded(uuid, text, text)      TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_funnel_action_created(uuid, text, int)       TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_funnel_action_completed(uuid, text)          TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_funnel_acquisition_tagged(uuid, text)        TO authenticated;

-- =========================================================
-- 7 SECDEF RPCs
-- =========================================================

-- 1) Funnel stage counts (overall)
CREATE OR REPLACE FUNCTION founder_funnel_stage_counts()
RETURNS TABLE (stage text, hospitals bigint, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(DISTINCT organization_id) INTO total
    FROM founder_hospital_funnel_events WHERE stage='first_touch';
  IF total IS NULL OR total=0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT s.stage,
         COUNT(DISTINCT e.organization_id)::bigint AS hospitals,
         ROUND(100.0 * COUNT(DISTINCT e.organization_id)::numeric / total, 2) AS share_pct
    FROM (VALUES ('first_touch'),('demo_booked'),('demo_done'),('quote_sent'),
                 ('first_job'),('first_job_paid'),('first_amc')) AS s(stage)
    LEFT JOIN founder_hospital_funnel_events e ON e.stage = s.stage
   GROUP BY s.stage
   ORDER BY CASE s.stage
     WHEN 'first_touch' THEN 1 WHEN 'demo_booked' THEN 2 WHEN 'demo_done' THEN 3
     WHEN 'quote_sent' THEN 4 WHEN 'first_job' THEN 5 WHEN 'first_job_paid' THEN 6
     WHEN 'first_amc' THEN 7 END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_funnel_stage_counts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_funnel_stage_counts() TO authenticated;

-- 2) Stage drop-off (between consecutive stages)
CREATE OR REPLACE FUNCTION founder_funnel_drop_off()
RETURNS TABLE (from_stage text, to_stage text, retained bigint, dropped bigint, drop_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r RECORD; prev_count bigint := 0; prev_stage text := NULL;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  CREATE TEMP TABLE _stages(stage text, cnt bigint) ON COMMIT DROP;
  INSERT INTO _stages
  SELECT s.stage, COUNT(DISTINCT e.organization_id)
    FROM (VALUES ('first_touch',1),('demo_booked',2),('demo_done',3),('quote_sent',4),
                 ('first_job',5),('first_job_paid',6),('first_amc',7)) AS s(stage, ord)
    LEFT JOIN founder_hospital_funnel_events e ON e.stage = s.stage
   GROUP BY s.stage, s.ord ORDER BY s.ord;

  FOR r IN SELECT * FROM _stages LOOP
    IF prev_stage IS NOT NULL THEN
      from_stage := prev_stage; to_stage := r.stage;
      retained := r.cnt; dropped := GREATEST(prev_count - r.cnt, 0);
      drop_pct := CASE WHEN prev_count=0 THEN 0
                       ELSE ROUND(100.0 * (prev_count - r.cnt)::numeric / prev_count, 2) END;
      RETURN NEXT;
    END IF;
    prev_count := r.cnt; prev_stage := r.stage;
  END LOOP;
END $$;
REVOKE EXECUTE ON FUNCTION founder_funnel_drop_off() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_funnel_drop_off() TO authenticated;

-- 3) Cohort by acquisition source
CREATE OR REPLACE FUNCTION founder_funnel_cohort_by_source()
RETURNS TABLE (acquisition_source text, hospitals bigint, reached_first_amc bigint, conversion_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH src AS (
    SELECT DISTINCT ON (organization_id) organization_id, acquisition_source
      FROM founder_hospital_funnel_events
     ORDER BY organization_id, reached_at ASC
  ),
  amc AS (
    SELECT DISTINCT organization_id FROM founder_hospital_funnel_events WHERE stage='first_amc'
  )
  SELECT s.acquisition_source,
         COUNT(*)::bigint AS hospitals,
         COUNT(a.organization_id)::bigint AS reached_first_amc,
         CASE WHEN COUNT(*)=0 THEN 0
              ELSE ROUND(100.0 * COUNT(a.organization_id)::numeric / COUNT(*), 2) END AS conversion_pct
    FROM src s
    LEFT JOIN amc a ON a.organization_id = s.organization_id
   GROUP BY s.acquisition_source
   ORDER BY hospitals DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_funnel_cohort_by_source() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_funnel_cohort_by_source() TO authenticated;

-- 4) Stuck hospitals (no advance in last 14d at a given stage)
CREATE OR REPLACE FUNCTION founder_funnel_stuck_hospitals()
RETURNS TABLE (
  id uuid, organization_id uuid, org_name text, stuck_stage text,
  stuck_since timestamptz, days_stuck numeric, acquisition_source text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (e.organization_id)
           e.organization_id, e.stage, e.reached_at, e.acquisition_source
      FROM founder_hospital_funnel_events e
     ORDER BY e.organization_id, e.reached_at DESC
  )
  SELECT l.organization_id AS id,
         l.organization_id,
         o.name,
         l.stage,
         l.reached_at,
         ROUND(EXTRACT(EPOCH FROM (now() - l.reached_at))/86400.0, 2) AS days_stuck,
         l.acquisition_source
    FROM latest l
    JOIN organizations o ON o.id = l.organization_id
   WHERE l.stage <> 'first_amc'
     AND l.reached_at < now() - interval '14 days'
   ORDER BY l.reached_at ASC
   LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_funnel_stuck_hospitals() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_funnel_stuck_hospitals() TO authenticated;

-- 5) Action ladder backlog
CREATE OR REPLACE FUNCTION founder_funnel_action_ladder()
RETURNS TABLE (
  id uuid, organization_id uuid, org_name text, stuck_stage text,
  action_rung int, action_label text, status text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.organization_id, o.name, a.stuck_stage,
         a.action_rung, a.action_label, a.status, a.created_at
    FROM founder_hospital_activation_actions a
    JOIN organizations o ON o.id = a.organization_id
   WHERE a.status = 'open'
   ORDER BY a.action_rung ASC, a.created_at ASC
   LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_funnel_action_ladder() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_funnel_action_ladder() TO authenticated;

-- 6) Median time-to-first-AMC
CREATE OR REPLACE FUNCTION founder_funnel_time_to_amc()
RETURNS TABLE (
  acquisition_source text, hospitals bigint,
  median_days numeric, p90_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH first_touch AS (
    SELECT DISTINCT ON (organization_id) organization_id, reached_at AS t0, acquisition_source
      FROM founder_hospital_funnel_events WHERE stage='first_touch'
     ORDER BY organization_id, reached_at ASC
  ),
  first_amc AS (
    SELECT DISTINCT ON (organization_id) organization_id, reached_at AS t1
      FROM founder_hospital_funnel_events WHERE stage='first_amc'
     ORDER BY organization_id, reached_at ASC
  ),
  d AS (
    SELECT f.acquisition_source,
           EXTRACT(EPOCH FROM (a.t1 - f.t0))/86400.0 AS days
      FROM first_touch f JOIN first_amc a USING (organization_id)
  )
  SELECT acquisition_source,
         COUNT(*)::bigint,
         ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY days)::numeric, 2),
         ROUND(percentile_cont(0.9) WITHIN GROUP (ORDER BY days)::numeric, 2)
    FROM d GROUP BY acquisition_source ORDER BY 2 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_funnel_time_to_amc() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_funnel_time_to_amc() TO authenticated;

-- 7) Record a funnel event (WRITE — VOLATILE)
CREATE OR REPLACE FUNCTION founder_funnel_record_event(
  p_org uuid, p_stage text, p_source text DEFAULT 'unknown'
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_hospital_funnel_events(organization_id, stage, acquisition_source)
  VALUES (p_org, p_stage, COALESCE(p_source,'unknown'))
  RETURNING id INTO new_id;
  PERFORM log_founder_funnel_event_recorded(p_org, p_stage, COALESCE(p_source,'unknown'));
  RETURN new_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_funnel_record_event(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_funnel_record_event(uuid, text, text) TO authenticated;

COMMIT;