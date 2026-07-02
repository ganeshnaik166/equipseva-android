BEGIN;

-- ============================================================================
-- r1543 — Founder Hospital Satisfaction Drilldown
-- Per-hospital NPS history, recurrence, escalations, dispute count, action ladder
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABLE 1: founder_hospital_satisfaction_snapshots
-- Rolled-up satisfaction posture per hospital org per snapshot day
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_hospital_satisfaction_snapshots_v2 (
  id              uuid primary key default gen_random_uuid(),
  hospital_org_id uuid not null references public.organizations(id) on delete cascade,
  snapshot_date   date not null default current_date,
  nps_score       numeric(6,2),
  promoters       integer not null default 0,
  passives        integer not null default 0,
  detractors      integer not null default 0,
  response_count  integer not null default 0,
  avg_rating      numeric(4,2),
  recurrence_rate numeric(6,2),
  escalation_count integer not null default 0,
  dispute_count   integer not null default 0,
  health_band     text not null default 'unknown' check (health_band in ('green','amber','red','unknown')),
  notes           text,
  created_at      timestamptz not null default now(),
  unique (hospital_org_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_fhss_v2_org_date ON public.founder_hospital_satisfaction_snapshots_v2 (hospital_org_id, snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_fhss_v2_band ON public.founder_hospital_satisfaction_snapshots_v2 (health_band, snapshot_date DESC);

ALTER TABLE public.founder_hospital_satisfaction_snapshots_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_fhss_v2" ON public.founder_hospital_satisfaction_snapshots_v2;
CREATE POLICY "founder_only_fhss_v2"
  ON public.founder_hospital_satisfaction_snapshots_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ----------------------------------------------------------------------------
-- TABLE 2: founder_hospital_action_ladder
-- Founder-curated escalation ladder rungs taken per hospital
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_hospital_action_ladder_v2 (
  id              uuid primary key default gen_random_uuid(),
  hospital_org_id uuid not null references public.organizations(id) on delete cascade,
  rung            text not null check (rung in ('observe','outreach','exec_call','onsite_visit','credit_offer','contract_review','offboard_review')),
  taken_at        timestamptz not null default now(),
  taken_by        uuid references auth.users(id) on delete set null,
  outcome         text,
  notes           text,
  created_at      timestamptz not null default now()
);

CREATE INDEX IF NOT EXISTS idx_fhal_v2_org ON public.founder_hospital_action_ladder_v2 (hospital_org_id, taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhal_v2_rung ON public.founder_hospital_action_ladder_v2 (rung, taken_at DESC);

ALTER TABLE public.founder_hospital_action_ladder_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_fhal_v2" ON public.founder_hospital_action_ladder_v2;
CREATE POLICY "founder_only_fhal_v2"
  ON public.founder_hospital_action_ladder_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- READ RPCs (STABLE SECURITY DEFINER)
-- ============================================================================

-- RPC 1: overview KPIs across all hospitals
CREATE OR REPLACE FUNCTION public.founder_hospital_satisfaction_overview_v2()
RETURNS TABLE (
  total_hospitals     bigint,
  green_band          bigint,
  amber_band          bigint,
  red_band            bigint,
  avg_nps             numeric,
  avg_rating          numeric,
  total_responses_30d bigint,
  total_escalations   bigint,
  total_disputes      bigint,
  recurrence_rate_avg numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_org_id) *
    FROM founder_hospital_satisfaction_snapshots_v2
    ORDER BY hospital_org_id, snapshot_date DESC
  )
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE health_band = 'green')::bigint,
    count(*) FILTER (WHERE health_band = 'amber')::bigint,
    count(*) FILTER (WHERE health_band = 'red')::bigint,
    round(avg(nps_score)::numeric, 2),
    round(avg(avg_rating)::numeric, 2),
    coalesce(sum(response_count), 0)::bigint,
    coalesce(sum(escalation_count), 0)::bigint,
    coalesce(sum(dispute_count), 0)::bigint,
    round(avg(recurrence_rate)::numeric, 2)
  FROM latest;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_satisfaction_overview_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_satisfaction_overview_v2() TO authenticated;

-- RPC 2: per-hospital latest posture list
CREATE OR REPLACE FUNCTION public.founder_hospital_satisfaction_list_v2()
RETURNS TABLE (
  id              uuid,
  hospital_org_id uuid,
  hospital_name   text,
  city            text,
  state           text,
  snapshot_date   date,
  nps_score       numeric,
  avg_rating      numeric,
  response_count  integer,
  recurrence_rate numeric,
  escalation_count integer,
  dispute_count   integer,
  health_band     text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.hospital_org_id) s.*
    FROM founder_hospital_satisfaction_snapshots_v2 s
    ORDER BY s.hospital_org_id, s.snapshot_date DESC
  )
  SELECT
    l.id,
    l.hospital_org_id,
    o.name,
    o.city,
    o.state,
    l.snapshot_date,
    l.nps_score,
    l.avg_rating,
    l.response_count,
    l.recurrence_rate,
    l.escalation_count,
    l.dispute_count,
    l.health_band
  FROM latest l
  JOIN organizations o ON o.id = l.hospital_org_id
  ORDER BY (CASE l.health_band WHEN 'red' THEN 0 WHEN 'amber' THEN 1 WHEN 'green' THEN 2 ELSE 3 END), l.nps_score NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_satisfaction_list_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_satisfaction_list_v2() TO authenticated;

-- RPC 3: trend timeline for one hospital (90d)
CREATE OR REPLACE FUNCTION public.founder_hospital_satisfaction_trend_v2(p_hospital_org_id uuid)
RETURNS TABLE (
  snapshot_date   date,
  nps_score       numeric,
  avg_rating      numeric,
  response_count  integer,
  recurrence_rate numeric,
  escalation_count integer,
  dispute_count   integer,
  health_band     text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.snapshot_date,
    s.nps_score,
    s.avg_rating,
    s.response_count,
    s.recurrence_rate,
    s.escalation_count,
    s.dispute_count,
    s.health_band
  FROM founder_hospital_satisfaction_snapshots_v2 s
  WHERE s.hospital_org_id = p_hospital_org_id
    AND s.snapshot_date >= current_date - 90
  ORDER BY s.snapshot_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_satisfaction_trend_v2(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_satisfaction_trend_v2(uuid) TO authenticated;

-- RPC 4: NPS responses recent (live data from repair_jobs.hospital_rating)
CREATE OR REPLACE FUNCTION public.founder_hospital_nps_responses_v2()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name   text,
  job_id          uuid,
  rating          integer,
  rated_at        timestamptz,
  job_kind        text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.hospital_org_id,
    o.name,
    r.id,
    r.hospital_rating,
    r.updated_at,
    r.kind::text
  FROM repair_jobs r
  JOIN organizations o ON o.id = r.hospital_org_id
  WHERE r.hospital_rating IS NOT NULL
    AND r.updated_at >= now() - interval '30 days'
  ORDER BY r.updated_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_nps_responses_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_nps_responses_v2() TO authenticated;

-- RPC 5: action ladder log
CREATE OR REPLACE FUNCTION public.founder_hospital_action_ladder_list_v2()
RETURNS TABLE (
  id              uuid,
  hospital_org_id uuid,
  hospital_name   text,
  rung            text,
  taken_at        timestamptz,
  taken_by        uuid,
  outcome         text,
  notes           text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.hospital_org_id,
    o.name,
    a.rung,
    a.taken_at,
    a.taken_by,
    a.outcome,
    a.notes
  FROM founder_hospital_action_ladder_v2 a
  JOIN organizations o ON o.id = a.hospital_org_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_action_ladder_list_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_action_ladder_list_v2() TO authenticated;

-- RPC 6: comments / qualitative — uses repair_job_disputes if exists fallback to notes; we use repair_job_escrow status
CREATE OR REPLACE FUNCTION public.founder_hospital_escalation_signals_v2()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name   text,
  open_disputes   bigint,
  red_jobs_30d    bigint,
  low_rating_30d  bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.hospital_org_id,
    o.name,
    count(*) FILTER (WHERE e.status = 'in_dispute')::bigint,
    count(*) FILTER (WHERE r.created_at >= now() - interval '30 days' AND r.hospital_rating IS NOT NULL AND r.hospital_rating <= 2)::bigint,
    count(*) FILTER (WHERE r.created_at >= now() - interval '30 days' AND r.hospital_rating IS NOT NULL AND r.hospital_rating <= 3)::bigint
  FROM repair_jobs r
  JOIN organizations o ON o.id = r.hospital_org_id
  LEFT JOIN repair_job_escrow e ON e.repair_job_id = r.id
  GROUP BY r.hospital_org_id, o.name
  HAVING count(*) FILTER (WHERE e.status = 'in_dispute') > 0
      OR count(*) FILTER (WHERE r.created_at >= now() - interval '30 days' AND r.hospital_rating IS NOT NULL AND r.hospital_rating <= 3) > 0
  ORDER BY 3 DESC NULLS LAST, 5 DESC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_escalation_signals_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_escalation_signals_v2() TO authenticated;

-- RPC 7: WRITE — record an action ladder rung
CREATE OR REPLACE FUNCTION public.founder_hospital_action_ladder_record_v2(
  p_hospital_org_id uuid,
  p_rung            text,
  p_outcome         text,
  p_notes           text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_hospital_action_ladder_v2 (hospital_org_id, rung, taken_by, outcome, notes)
  VALUES (p_hospital_org_id, p_rung, auth.uid(), p_outcome, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_hospital_action_ladder_record_v2',
    jsonb_build_object('hospital_org_id', p_hospital_org_id, 'rung', p_rung, 'outcome', p_outcome, 'id', v_id)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_action_ladder_record_v2(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_action_ladder_record_v2(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- log_founder_* helpers (VOLATILE SECDEF, all founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.log_founder_hospital_satisfaction_view_v2(p_hospital_org_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_hospital_satisfaction_view_v2',
    jsonb_build_object('hospital_org_id', p_hospital_org_id, 'at', now())
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_satisfaction_view_v2(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_satisfaction_view_v2(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_hospital_satisfaction_export_v2(p_filter text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_hospital_satisfaction_export_v2',
    jsonb_build_object('filter', p_filter, 'at', now())
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_satisfaction_export_v2(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_satisfaction_export_v2(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_hospital_satisfaction_escalation_review_v2(p_hospital_org_id uuid, p_note text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_hospital_satisfaction_escalation_review_v2',
    jsonb_build_object('hospital_org_id', p_hospital_org_id, 'note', p_note, 'at', now())
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_satisfaction_escalation_review_v2(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_satisfaction_escalation_review_v2(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_hospital_satisfaction_ladder_review_v2(p_rung text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_hospital_satisfaction_ladder_review_v2',
    jsonb_build_object('rung', p_rung, 'at', now())
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_satisfaction_ladder_review_v2(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_satisfaction_ladder_review_v2(text) TO authenticated;

COMMIT;