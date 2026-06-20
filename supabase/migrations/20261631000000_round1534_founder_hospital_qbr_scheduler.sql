BEGIN;
-- Round 1534: Founder Hospital QBR Scheduler
-- Quarterly Business Review scheduler for top-50 hospitals by revenue.
-- Founder/CS owner, agenda template, outcome tracker.


-- =====================================================================
-- Table 1: founder_hospital_qbr_schedule
-- One row per (hospital_org_id, quarter_label) scheduled QBR.
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.founder_hospital_qbr_schedule_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,  -- e.g. 'FY27-Q1'
  scheduled_at timestamptz NOT NULL,
  cs_owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  cs_owner_email text,
  meeting_mode text NOT NULL DEFAULT 'video' CHECK (meeting_mode IN ('video','onsite','phone')),
  meeting_link text,
  agenda_template text NOT NULL DEFAULT 'standard' CHECK (agenda_template IN ('standard','renewal','escalation','expansion')),
  agenda_notes text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','rescheduled','completed','cancelled','no_show')),
  hospital_revenue_rupees_snapshot bigint NOT NULL DEFAULT 0,
  hospital_rank_snapshot integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT founder_hospital_qbr_schedule_v2_uq UNIQUE (hospital_org_id, quarter_label)
);

CREATE INDEX IF NOT EXISTS founder_hospital_qbr_schedule_v2_scheduled_at_idx
  ON public.founder_hospital_qbr_schedule_v2 (scheduled_at);
CREATE INDEX IF NOT EXISTS founder_hospital_qbr_schedule_v2_status_idx
  ON public.founder_hospital_qbr_schedule_v2 (status);
CREATE INDEX IF NOT EXISTS founder_hospital_qbr_schedule_v2_hospital_idx
  ON public.founder_hospital_qbr_schedule_v2 (hospital_org_id);

ALTER TABLE public.founder_hospital_qbr_schedule_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_hospital_qbr_schedule_v2_founder_only
  ON public.founder_hospital_qbr_schedule_v2;
CREATE POLICY founder_hospital_qbr_schedule_v2_founder_only
  ON public.founder_hospital_qbr_schedule_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- Table 2: founder_hospital_qbr_outcomes
-- Outcome tracker per QBR — captured after meeting completes.
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.founder_hospital_qbr_outcomes_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  qbr_id uuid NOT NULL REFERENCES public.founder_hospital_qbr_schedule_v2(id) ON DELETE CASCADE,
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  csat_score integer CHECK (csat_score BETWEEN 1 AND 10),
  nps_score integer CHECK (nps_score BETWEEN -100 AND 100),
  renewal_intent text CHECK (renewal_intent IN ('high','medium','low','churn_risk','expansion')),
  expansion_rupees_pipeline bigint NOT NULL DEFAULT 0,
  open_action_items_count integer NOT NULL DEFAULT 0,
  blockers text,
  outcome_summary text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  CONSTRAINT founder_hospital_qbr_outcomes_v2_uq UNIQUE (qbr_id)
);

CREATE INDEX IF NOT EXISTS founder_hospital_qbr_outcomes_v2_hospital_idx
  ON public.founder_hospital_qbr_outcomes_v2 (hospital_org_id);
CREATE INDEX IF NOT EXISTS founder_hospital_qbr_outcomes_v2_recorded_at_idx
  ON public.founder_hospital_qbr_outcomes_v2 (recorded_at);

ALTER TABLE public.founder_hospital_qbr_outcomes_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_hospital_qbr_outcomes_v2_founder_only
  ON public.founder_hospital_qbr_outcomes_v2;
CREATE POLICY founder_hospital_qbr_outcomes_v2_founder_only
  ON public.founder_hospital_qbr_outcomes_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- READ RPCs (STABLE)
-- =====================================================================

-- RPC 1: KPIs summary
CREATE OR REPLACE FUNCTION public.founder_hospital_qbr_kpis()
RETURNS TABLE (
  total_scheduled bigint,
  total_completed bigint,
  total_no_show bigint,
  total_cancelled bigint,
  upcoming_7d bigint,
  upcoming_30d bigint,
  overdue_count bigint,
  avg_csat numeric,
  avg_nps numeric,
  churn_risk_count bigint,
  expansion_intent_count bigint,
  expansion_pipeline_rupees bigint,
  open_action_items bigint,
  completion_rate_pct numeric,
  hospitals_covered bigint,
  top50_covered_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_top50 bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(DISTINCT hospital_org_id)
  INTO v_top50
  FROM public.founder_hospital_qbr_schedule_v2
  WHERE hospital_rank_snapshot IS NOT NULL
    AND hospital_rank_snapshot <= 50;

  RETURN QUERY
  WITH s AS (
    SELECT * FROM public.founder_hospital_qbr_schedule_v2
  ),
  o AS (
    SELECT * FROM public.founder_hospital_qbr_outcomes_v2
  )
  SELECT
    (SELECT count(*) FROM s)::bigint,
    (SELECT count(*) FROM s WHERE status='completed')::bigint,
    (SELECT count(*) FROM s WHERE status='no_show')::bigint,
    (SELECT count(*) FROM s WHERE status='cancelled')::bigint,
    (SELECT count(*) FROM s WHERE status='scheduled' AND scheduled_at BETWEEN now() AND now() + interval '7 days')::bigint,
    (SELECT count(*) FROM s WHERE status='scheduled' AND scheduled_at BETWEEN now() AND now() + interval '30 days')::bigint,
    (SELECT count(*) FROM s WHERE status='scheduled' AND scheduled_at < now())::bigint,
    (SELECT round(avg(csat_score)::numeric, 2) FROM o WHERE csat_score IS NOT NULL),
    (SELECT round(avg(nps_score)::numeric, 2) FROM o WHERE nps_score IS NOT NULL),
    (SELECT count(*) FROM o WHERE renewal_intent='churn_risk')::bigint,
    (SELECT count(*) FROM o WHERE renewal_intent='expansion')::bigint,
    (SELECT coalesce(sum(expansion_rupees_pipeline),0) FROM o)::bigint,
    (SELECT coalesce(sum(open_action_items_count),0) FROM o)::bigint,
    CASE WHEN (SELECT count(*) FROM s)=0 THEN 0
         ELSE round(100.0 * (SELECT count(*) FROM s WHERE status='completed')::numeric / (SELECT count(*) FROM s)::numeric, 2)
    END,
    v_top50,
    round(100.0 * v_top50::numeric / 50.0, 2);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_qbr_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_qbr_kpis() TO authenticated;

-- RPC 2: Upcoming QBRs (next 60 days)
CREATE OR REPLACE FUNCTION public.founder_hospital_qbr_upcoming()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  quarter_label text,
  scheduled_at timestamptz,
  days_until numeric,
  cs_owner_email text,
  meeting_mode text,
  agenda_template text,
  status text,
  hospital_rank_snapshot integer,
  hospital_revenue_rupees_snapshot bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_org_id, o.name, s.quarter_label, s.scheduled_at,
         round(EXTRACT(EPOCH FROM (s.scheduled_at - now()))/86400.0, 2)::numeric AS days_until,
         s.cs_owner_email, s.meeting_mode, s.agenda_template, s.status,
         s.hospital_rank_snapshot, s.hospital_revenue_rupees_snapshot
  FROM public.founder_hospital_qbr_schedule_v2 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_org_id
  WHERE s.status='scheduled'
    AND s.scheduled_at <= now() + interval '60 days'
  ORDER BY s.scheduled_at ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_qbr_upcoming() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_qbr_upcoming() TO authenticated;

-- RPC 3: Top 50 hospitals by revenue coverage
CREATE OR REPLACE FUNCTION public.founder_hospital_qbr_top50_coverage()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  city text,
  revenue_rupees_90d bigint,
  rank_position bigint,
  last_qbr_at timestamptz,
  days_since_last_qbr numeric,
  next_qbr_at timestamptz,
  qbr_count_total bigint,
  has_outcome boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH rev AS (
    SELECT rj.hospital_org_id,
           sum(coalesce(rj.contracted_amount_rupees,0))::bigint AS rev_90d
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '90 days'
      AND rj.hospital_org_id IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  ranked AS (
    SELECT hospital_org_id, rev_90d,
           row_number() OVER (ORDER BY rev_90d DESC) AS rnk
    FROM rev
  )
  SELECT r.hospital_org_id,
         o.name,
         o.city,
         r.rev_90d,
         r.rnk,
         (SELECT max(s.scheduled_at) FROM public.founder_hospital_qbr_schedule_v2 s
            WHERE s.hospital_org_id = r.hospital_org_id AND s.status='completed'),
         round(EXTRACT(EPOCH FROM (now() - (SELECT max(s.scheduled_at) FROM public.founder_hospital_qbr_schedule_v2 s
            WHERE s.hospital_org_id = r.hospital_org_id AND s.status='completed')))/86400.0, 1)::numeric,
         (SELECT min(s.scheduled_at) FROM public.founder_hospital_qbr_schedule_v2 s
            WHERE s.hospital_org_id = r.hospital_org_id AND s.status='scheduled' AND s.scheduled_at >= now()),
         (SELECT count(*) FROM public.founder_hospital_qbr_schedule_v2 s
            WHERE s.hospital_org_id = r.hospital_org_id)::bigint,
         EXISTS (
           SELECT 1 FROM public.founder_hospital_qbr_outcomes_v2 ot
           WHERE ot.hospital_org_id = r.hospital_org_id
         )
  FROM ranked r
  LEFT JOIN public.organizations o ON o.id = r.hospital_org_id
  WHERE r.rnk <= 50
  ORDER BY r.rnk ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_qbr_top50_coverage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_qbr_top50_coverage() TO authenticated;

-- RPC 4: Outcomes feed
CREATE OR REPLACE FUNCTION public.founder_hospital_qbr_outcomes_feed()
RETURNS TABLE (
  outcome_id uuid,
  qbr_id uuid,
  hospital_org_id uuid,
  hospital_name text,
  quarter_label text,
  csat_score integer,
  nps_score integer,
  renewal_intent text,
  expansion_rupees_pipeline bigint,
  open_action_items_count integer,
  outcome_summary text,
  recorded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ot.id, ot.qbr_id, ot.hospital_org_id, org.name,
         s.quarter_label, ot.csat_score, ot.nps_score, ot.renewal_intent,
         ot.expansion_rupees_pipeline, ot.open_action_items_count,
         ot.outcome_summary, ot.recorded_at
  FROM public.founder_hospital_qbr_outcomes_v2 ot
  LEFT JOIN public.founder_hospital_qbr_schedule_v2 s ON s.id = ot.qbr_id
  LEFT JOIN public.organizations org ON org.id = ot.hospital_org_id
  ORDER BY ot.recorded_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_qbr_outcomes_feed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_qbr_outcomes_feed() TO authenticated;

-- RPC 5: Overdue / at-risk QBRs
CREATE OR REPLACE FUNCTION public.founder_hospital_qbr_overdue()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  quarter_label text,
  scheduled_at timestamptz,
  days_overdue numeric,
  cs_owner_email text,
  hospital_rank_snapshot integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_org_id, o.name, s.quarter_label, s.scheduled_at,
         round(EXTRACT(EPOCH FROM (now() - s.scheduled_at))/86400.0, 1)::numeric,
         s.cs_owner_email, s.hospital_rank_snapshot
  FROM public.founder_hospital_qbr_schedule_v2 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_org_id
  WHERE s.status='scheduled' AND s.scheduled_at < now()
  ORDER BY s.scheduled_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_qbr_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_qbr_overdue() TO authenticated;

-- RPC 6: CS owner load distribution
CREATE OR REPLACE FUNCTION public.founder_hospital_qbr_owner_load()
RETURNS TABLE (
  cs_owner_email text,
  total_assigned bigint,
  upcoming_count bigint,
  completed_count bigint,
  no_show_count bigint,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(s.cs_owner_email,'(unassigned)') AS cs_owner_email,
         count(*)::bigint,
         count(*) FILTER (WHERE s.status='scheduled' AND s.scheduled_at >= now())::bigint,
         count(*) FILTER (WHERE s.status='completed')::bigint,
         count(*) FILTER (WHERE s.status='no_show')::bigint,
         round(avg(ot.csat_score)::numeric, 2)
  FROM public.founder_hospital_qbr_schedule_v2 s
  LEFT JOIN public.founder_hospital_qbr_outcomes_v2 ot ON ot.qbr_id = s.id
  GROUP BY s.cs_owner_email
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_qbr_owner_load() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_qbr_owner_load() TO authenticated;

-- RPC 7: Agenda template breakdown
CREATE OR REPLACE FUNCTION public.founder_hospital_qbr_agenda_mix()
RETURNS TABLE (
  agenda_template text,
  scheduled_count bigint,
  completed_count bigint,
  avg_csat numeric,
  expansion_pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.agenda_template,
         count(*)::bigint,
         count(*) FILTER (WHERE s.status='completed')::bigint,
         round(avg(ot.csat_score)::numeric, 2),
         coalesce(sum(ot.expansion_rupees_pipeline),0)::bigint
  FROM public.founder_hospital_qbr_schedule_v2 s
  LEFT JOIN public.founder_hospital_qbr_outcomes_v2 ot ON ot.qbr_id = s.id
  GROUP BY s.agenda_template
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_qbr_agenda_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_qbr_agenda_mix() TO authenticated;

-- =====================================================================
-- WRITE RPCs (VOLATILE) — log to founder_action_log
-- =====================================================================

-- Helper 1: log scheduling action
CREATE OR REPLACE FUNCTION public.log_founder_qbr_scheduled(
  p_qbr_id uuid,
  p_hospital_org_id uuid,
  p_quarter_label text,
  p_scheduled_at timestamptz
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'qbr_scheduled',
    jsonb_build_object(
      'qbr_id', p_qbr_id,
      'hospital_org_id', p_hospital_org_id,
      'quarter_label', p_quarter_label,
      'scheduled_at', p_scheduled_at
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_qbr_scheduled(uuid,uuid,text,timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_qbr_scheduled(uuid,uuid,text,timestamptz) TO authenticated;

-- Helper 2: log outcome recording
CREATE OR REPLACE FUNCTION public.log_founder_qbr_outcome_recorded(
  p_qbr_id uuid,
  p_csat integer,
  p_renewal_intent text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'qbr_outcome_recorded',
    jsonb_build_object(
      'qbr_id', p_qbr_id,
      'csat_score', p_csat,
      'renewal_intent', p_renewal_intent
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_qbr_outcome_recorded(uuid,integer,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_qbr_outcome_recorded(uuid,integer,text) TO authenticated;

-- Helper 3: log reschedule action
CREATE OR REPLACE FUNCTION public.log_founder_qbr_rescheduled(
  p_qbr_id uuid,
  p_old_at timestamptz,
  p_new_at timestamptz,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'qbr_rescheduled',
    jsonb_build_object(
      'qbr_id', p_qbr_id,
      'old_at', p_old_at,
      'new_at', p_new_at,
      'reason', p_reason
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_qbr_rescheduled(uuid,timestamptz,timestamptz,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_qbr_rescheduled(uuid,timestamptz,timestamptz,text) TO authenticated;

-- Helper 4: log cancellation
CREATE OR REPLACE FUNCTION public.log_founder_qbr_cancelled(
  p_qbr_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'qbr_cancelled',
    jsonb_build_object(
      'qbr_id', p_qbr_id,
      'reason', p_reason
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_qbr_cancelled(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_qbr_cancelled(uuid,text) TO authenticated;

COMMIT;