BEGIN;

-- =====================================================================
-- Round 2753: Founder Monthly Product Roadmap Promise Tracker
-- promise x audience x commit date x actual x variance x communicate x trust delta
-- =====================================================================

CREATE TABLE IF NOT EXISTS roadmap_promises_r2753 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promise_code text NOT NULL UNIQUE,
  promise_title text NOT NULL,
  audience text NOT NULL CHECK (audience IN ('investors','customers','engineers','team','public')),
  commit_month date NOT NULL,
  committed_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz,
  variance_days integer,
  status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','delivered','missed','descoped','reslipped')),
  trust_delta_pp numeric(6,2) NOT NULL DEFAULT 0,
  severity text NOT NULL DEFAULT 'p2' CHECK (severity IN ('p0','p1','p2','p3')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE roadmap_promises_r2753 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON roadmap_promises_r2753;
CREATE POLICY founder_all ON roadmap_promises_r2753 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS roadmap_promise_communications_r2753 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promise_id uuid NOT NULL REFERENCES roadmap_promises_r2753(id) ON DELETE CASCADE,
  comm_channel text NOT NULL CHECK (comm_channel IN ('email','wa','call','board','slack','public_post')),
  comm_kind text NOT NULL CHECK (comm_kind IN ('initial_promise','status_update','slip_notice','delivered_notice','descope_notice')),
  audience text NOT NULL CHECK (audience IN ('investors','customers','engineers','team','public')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  recipient_count integer NOT NULL DEFAULT 1,
  honest_tone_score numeric(4,2) NOT NULL DEFAULT 0.8 CHECK (honest_tone_score BETWEEN 0 AND 1),
  trust_impact_pp numeric(6,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE roadmap_promise_communications_r2753 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON roadmap_promise_communications_r2753;
CREATE POLICY founder_all ON roadmap_promise_communications_r2753 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- SEED PROMISES ----------
INSERT INTO roadmap_promises_r2753 (promise_code, promise_title, audience, commit_month, committed_at, delivered_at, variance_days, status, trust_delta_pp, severity) VALUES
('PROM-JUN-AMC-V2','AMC tier v2 with bonded parts','customers','2026-06-01'::date, '2026-05-15 10:00+05:30'::timestamptz, '2026-06-12 18:00+05:30'::timestamptz, 11, 'delivered', 3.20, 'p1'),
('PROM-JUN-INV-DR','Investor data room v2 public share','investors','2026-06-15'::date, '2026-05-20 11:00+05:30'::timestamptz, '2026-06-18 17:00+05:30'::timestamptz, 3, 'delivered', 4.50, 'p0'),
('PROM-JUN-ENG-LIVE','Engineer live KPI dashboard','engineers','2026-06-20'::date, '2026-05-22 09:00+05:30'::timestamptz, NULL, NULL, 'in_progress', 0.00, 'p2'),
('PROM-JUN-AI-TRIAGE','AI triage v1 on incoming jobs','team','2026-06-30'::date, '2026-05-25 14:00+05:30'::timestamptz, NULL, 8, 'reslipped', -2.10, 'p1'),
('PROM-JUN-INTL-SL','Sri Lanka pilot launch','public','2026-06-28'::date, '2026-05-30 16:00+05:30'::timestamptz, NULL, NULL, 'descoped', -5.40, 'p0'),
('PROM-JUL-HOSP-V2','Hospital portal v2 chains','customers','2026-07-15'::date, '2026-06-05 10:30+05:30'::timestamptz, NULL, NULL, 'in_progress', 0.00, 'p1'),
('PROM-JUL-FRANCH','Franchise pilot Bangalore','public','2026-07-30'::date, '2026-06-10 12:00+05:30'::timestamptz, NULL, NULL, 'in_progress', 0.00, 'p2');

-- ---------- SEED COMMUNICATIONS ----------
INSERT INTO roadmap_promise_communications_r2753 (promise_id, comm_channel, comm_kind, audience, sent_at, recipient_count, honest_tone_score, trust_impact_pp, notes)
SELECT id, 'email','initial_promise','customers','2026-05-15 10:30+05:30'::timestamptz, 142, 0.90, 1.20, 'AMC v2 rollout announce' FROM roadmap_promises_r2753 WHERE promise_code='PROM-JUN-AMC-V2'
UNION ALL
SELECT id, 'email','delivered_notice','customers','2026-06-12 19:00+05:30'::timestamptz, 142, 0.95, 2.00, 'AMC v2 shipped, 11d slip noted' FROM roadmap_promises_r2753 WHERE promise_code='PROM-JUN-AMC-V2'
UNION ALL
SELECT id, 'board','initial_promise','investors','2026-05-20 12:00+05:30'::timestamptz, 8, 0.92, 0.80, 'Data room v2 promised at board' FROM roadmap_promises_r2753 WHERE promise_code='PROM-JUN-INV-DR'
UNION ALL
SELECT id, 'email','delivered_notice','investors','2026-06-18 18:00+05:30'::timestamptz, 8, 0.94, 3.70, 'Data room live with public share link' FROM roadmap_promises_r2753 WHERE promise_code='PROM-JUN-INV-DR'
UNION ALL
SELECT id, 'slack','status_update','engineers','2026-06-15 10:00+05:30'::timestamptz, 24, 0.85, 0.30, 'KPI dash 60 pct done' FROM roadmap_promises_r2753 WHERE promise_code='PROM-JUN-ENG-LIVE'
UNION ALL
SELECT id, 'email','slip_notice','team','2026-06-28 17:00+05:30'::timestamptz, 12, 0.88, -2.10, 'AI triage slipping 1 week, here is why' FROM roadmap_promises_r2753 WHERE promise_code='PROM-JUN-AI-TRIAGE'
UNION ALL
SELECT id, 'public_post','descope_notice','public','2026-06-29 11:00+05:30'::timestamptz, 1200, 0.75, -5.40, 'SL pilot postponed to Q3' FROM roadmap_promises_r2753 WHERE promise_code='PROM-JUN-INTL-SL';

-- ---------- RPCs ----------

DROP FUNCTION IF EXISTS founder_roadmap_kpi_r2753();
CREATE FUNCTION founder_roadmap_kpi_r2753()
RETURNS TABLE (
  total_promises bigint,
  delivered bigint,
  missed bigint,
  in_progress bigint,
  descoped bigint,
  reslipped bigint,
  on_time_rate_pct numeric,
  avg_variance_days numeric,
  net_trust_delta_pp numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE status='delivered')::bigint,
    count(*) FILTER (WHERE status='missed')::bigint,
    count(*) FILTER (WHERE status='in_progress')::bigint,
    count(*) FILTER (WHERE status='descoped')::bigint,
    count(*) FILTER (WHERE status='reslipped')::bigint,
    ROUND(100.0 * count(*) FILTER (WHERE status='delivered' AND coalesce(variance_days,99) <= 7)::numeric
          / NULLIF(count(*) FILTER (WHERE status IN ('delivered','missed','descoped')),0), 2),
    ROUND(avg(variance_days)::numeric, 2),
    ROUND(sum(trust_delta_pp)::numeric, 2)
  FROM roadmap_promises_r2753;
END $$;
REVOKE EXECUTE ON FUNCTION founder_roadmap_kpi_r2753() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_roadmap_kpi_r2753() TO authenticated;

DROP FUNCTION IF EXISTS founder_roadmap_promises_r2753();
CREATE FUNCTION founder_roadmap_promises_r2753()
RETURNS TABLE (
  promise_code text,
  promise_title text,
  audience text,
  commit_month date,
  delivered_at timestamptz,
  variance_days integer,
  status text,
  severity text,
  trust_delta_pp numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.promise_code, p.promise_title, p.audience, p.commit_month, p.delivered_at,
         p.variance_days, p.status, p.severity, p.trust_delta_pp
  FROM roadmap_promises_r2753 p
  ORDER BY p.commit_month ASC, p.severity ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_roadmap_promises_r2753() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_roadmap_promises_r2753() TO authenticated;

DROP FUNCTION IF EXISTS founder_roadmap_by_audience_r2753();
CREATE FUNCTION founder_roadmap_by_audience_r2753()
RETURNS TABLE (
  audience text,
  total bigint,
  delivered bigint,
  missed_or_slipped bigint,
  net_trust_delta_pp numeric,
  on_time_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.audience,
         count(*)::bigint,
         count(*) FILTER (WHERE p.status='delivered')::bigint,
         count(*) FILTER (WHERE p.status IN ('missed','reslipped','descoped'))::bigint,
         ROUND(sum(p.trust_delta_pp)::numeric, 2),
         ROUND(100.0 * count(*) FILTER (WHERE p.status='delivered' AND coalesce(p.variance_days,99) <= 7)::numeric
               / NULLIF(count(*),0), 2)
  FROM roadmap_promises_r2753 p
  GROUP BY p.audience
  ORDER BY net_trust_delta_pp ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_roadmap_by_audience_r2753() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_roadmap_by_audience_r2753() TO authenticated;

DROP FUNCTION IF EXISTS founder_roadmap_variance_buckets_r2753();
CREATE FUNCTION founder_roadmap_variance_buckets_r2753()
RETURNS TABLE (
  bucket text,
  promise_count bigint,
  pct_of_delivered numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  total_delivered bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total_delivered FROM roadmap_promises_r2753 WHERE status='delivered';
  RETURN QUERY
  SELECT b.bucket, b.promise_count,
         ROUND(100.0 * b.promise_count::numeric / NULLIF(total_delivered,0), 2)
  FROM (
    SELECT 'on_time_0_to_3d'::text AS bucket,
           count(*)::bigint AS promise_count
    FROM roadmap_promises_r2753 WHERE status='delivered' AND variance_days BETWEEN 0 AND 3
    UNION ALL
    SELECT 'slipped_4_to_14d', count(*)::bigint
    FROM roadmap_promises_r2753 WHERE status='delivered' AND variance_days BETWEEN 4 AND 14
    UNION ALL
    SELECT 'slipped_over_14d', count(*)::bigint
    FROM roadmap_promises_r2753 WHERE status='delivered' AND variance_days > 14
  ) b;
END $$;
REVOKE EXECUTE ON FUNCTION founder_roadmap_variance_buckets_r2753() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_roadmap_variance_buckets_r2753() TO authenticated;

DROP FUNCTION IF EXISTS founder_roadmap_communications_r2753();
CREATE FUNCTION founder_roadmap_communications_r2753()
RETURNS TABLE (
  promise_code text,
  comm_channel text,
  comm_kind text,
  audience text,
  sent_at timestamptz,
  recipient_count integer,
  honest_tone_score numeric,
  trust_impact_pp numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.promise_code, c.comm_channel, c.comm_kind, c.audience, c.sent_at,
         c.recipient_count, c.honest_tone_score, c.trust_impact_pp
  FROM roadmap_promise_communications_r2753 c
  JOIN roadmap_promises_r2753 p ON p.id = c.promise_id
  ORDER BY c.sent_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_roadmap_communications_r2753() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_roadmap_communications_r2753() TO authenticated;

DROP FUNCTION IF EXISTS founder_roadmap_trust_leaders_r2753();
CREATE FUNCTION founder_roadmap_trust_leaders_r2753()
RETURNS TABLE (
  promise_code text,
  promise_title text,
  audience text,
  trust_delta_pp numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.promise_code, p.promise_title, p.audience, p.trust_delta_pp, p.status
  FROM roadmap_promises_r2753 p
  WHERE p.trust_delta_pp <> 0
  ORDER BY p.trust_delta_pp DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION founder_roadmap_trust_leaders_r2753() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_roadmap_trust_leaders_r2753() TO authenticated;

DROP FUNCTION IF EXISTS founder_roadmap_at_risk_r2753();
CREATE FUNCTION founder_roadmap_at_risk_r2753()
RETURNS TABLE (
  promise_code text,
  promise_title text,
  audience text,
  commit_month date,
  days_to_commit integer,
  status text,
  severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.promise_code, p.promise_title, p.audience, p.commit_month,
         (p.commit_month - CURRENT_DATE)::integer AS days_to_commit,
         p.status, p.severity
  FROM roadmap_promises_r2753 p
  WHERE p.status IN ('in_progress','reslipped')
    AND p.commit_month <= CURRENT_DATE + INTERVAL '30 days'
  ORDER BY p.commit_month ASC, p.severity ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_roadmap_at_risk_r2753() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_roadmap_at_risk_r2753() TO authenticated;

DROP FUNCTION IF EXISTS founder_roadmap_mark_delivered_r2753(text, timestamptz, numeric);
CREATE FUNCTION founder_roadmap_mark_delivered_r2753(p_code text, p_at timestamptz, p_trust numeric)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE roadmap_promises_r2753
  SET delivered_at = p_at,
      variance_days = (p_at::date - commit_month),
      status = 'delivered',
      trust_delta_pp = coalesce(p_trust, trust_delta_pp)
  WHERE promise_code = p_code
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'promise_not_found'; END IF;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_roadmap_mark_delivered_r2753(text, timestamptz, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_roadmap_mark_delivered_r2753(text, timestamptz, numeric) TO authenticated;

COMMIT;
