BEGIN;
-- r1332 — Founder incident postmortem ledger.
--
-- Every resolved founder_incidents row should get a structured postmortem:
-- timeline, root-cause classification, customer impact, action items.
-- This is the institutional memory layer — the "we learned this lesson"
-- record that compounds into a runbook over time.
--
-- Writing-discipline rules (enforced by founder norms, not constraint):
--   1. Every p0/p1 incident MUST have a postmortem within 48h of resolution.
--   2. Every postmortem MUST list >=1 action item (otherwise we didn't learn).
--   3. Action items have owners + due dates; closure tracked separately.

-- ============================================================================
-- Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_incident_postmortems (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id                   uuid NOT NULL REFERENCES public.founder_incidents(id) ON DELETE CASCADE,
  title                         text NOT NULL,
  timeline_summary              text,
  root_cause_classification     text CHECK (root_cause_classification IN
    ('process_gap','code_bug','data_inconsistency','vendor_failure','external_event','people_error','design_gap','other')),
  severity_at_resolution        text CHECK (severity_at_resolution IN ('p0','p1','p2','p3')),
  customer_impact_summary       text,
  revenue_impact_rupees         numeric NOT NULL DEFAULT 0,
  affected_user_count           int NOT NULL DEFAULT 0,
  detection_lag_minutes         int,
  resolution_duration_minutes   int,
  action_items_count            int NOT NULL DEFAULT 0,
  action_items_closed_count     int NOT NULL DEFAULT 0,
  written_at                    timestamptz NOT NULL DEFAULT now(),
  written_by                    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT founder_postmortem_one_per_incident UNIQUE (incident_id)
);
COMMENT ON TABLE public.founder_incident_postmortems IS
  'Structured postmortem record linked 1:1 to a founder_incidents row. Institutional memory.';

CREATE INDEX IF NOT EXISTS idx_founder_postmortems_written_at  ON public.founder_incident_postmortems (written_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_postmortems_class      ON public.founder_incident_postmortems (root_cause_classification);
CREATE INDEX IF NOT EXISTS idx_founder_postmortems_sev        ON public.founder_incident_postmortems (severity_at_resolution);

ALTER TABLE public.founder_incident_postmortems ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_postmortems_no_direct ON public.founder_incident_postmortems;
CREATE POLICY founder_postmortems_no_direct ON public.founder_incident_postmortems FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_incident_postmortems FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.founder_incident_postmortem_action_items (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  postmortem_id       uuid NOT NULL REFERENCES public.founder_incident_postmortems(id) ON DELETE CASCADE,
  description         text NOT NULL,
  owner_user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  due_date            date,
  status              text NOT NULL DEFAULT 'open'
                        CHECK (status IN ('open','in_progress','closed','wont_do')),
  closed_at           timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_incident_postmortem_action_items IS
  'Concrete action items emerging from each postmortem. Each item has an owner + due date + status.';

CREATE INDEX IF NOT EXISTS idx_postmortem_action_postmortem ON public.founder_incident_postmortem_action_items (postmortem_id);
CREATE INDEX IF NOT EXISTS idx_postmortem_action_status     ON public.founder_incident_postmortem_action_items (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_postmortem_action_owner      ON public.founder_incident_postmortem_action_items (owner_user_id);

ALTER TABLE public.founder_incident_postmortem_action_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_postmortem_actions_no_direct ON public.founder_incident_postmortem_action_items;
CREATE POLICY founder_postmortem_actions_no_direct ON public.founder_incident_postmortem_action_items FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_incident_postmortem_action_items FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Write-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_postmortem_create(uuid, text, text, text, text, text, numeric, int, int, int);
CREATE OR REPLACE FUNCTION public.log_founder_postmortem_create(
  p_incident_id    uuid,
  p_title          text,
  p_classification text DEFAULT NULL,
  p_severity       text DEFAULT NULL,
  p_timeline       text DEFAULT NULL,
  p_customer_impact text DEFAULT NULL,
  p_revenue_impact numeric DEFAULT 0,
  p_affected_users int DEFAULT 0,
  p_detection_lag_min int DEFAULT NULL,
  p_resolution_min int DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  INSERT INTO public.founder_incident_postmortems
    (incident_id, title, root_cause_classification, severity_at_resolution,
     timeline_summary, customer_impact_summary, revenue_impact_rupees,
     affected_user_count, detection_lag_minutes, resolution_duration_minutes, written_by)
  VALUES
    (p_incident_id, p_title, p_classification, p_severity,
     p_timeline, p_customer_impact, coalesce(p_revenue_impact, 0),
     coalesce(p_affected_users, 0), p_detection_lag_min, p_resolution_min, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_postmortem_create(uuid, text, text, text, text, text, numeric, int, int, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_postmortem_create(uuid, text, text, text, text, text, numeric, int, int, int) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_postmortem_add_action_item(uuid, text, uuid, date);
CREATE OR REPLACE FUNCTION public.log_founder_postmortem_add_action_item(
  p_postmortem_id uuid,
  p_desc          text,
  p_owner_user_id uuid DEFAULT NULL,
  p_due_date      date DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  INSERT INTO public.founder_incident_postmortem_action_items
    (postmortem_id, description, owner_user_id, due_date)
  VALUES (p_postmortem_id, p_desc, p_owner_user_id, p_due_date)
  RETURNING id INTO v_id;
  UPDATE public.founder_incident_postmortems
    SET action_items_count = action_items_count + 1
    WHERE id = p_postmortem_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_postmortem_add_action_item(uuid, text, uuid, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_postmortem_add_action_item(uuid, text, uuid, date) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_postmortem_close_action_item(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_postmortem_close_action_item(p_item_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pm uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  UPDATE public.founder_incident_postmortem_action_items
    SET status = 'closed', closed_at = now()
    WHERE id = p_item_id AND status != 'closed'
    RETURNING postmortem_id INTO v_pm;
  IF v_pm IS NOT NULL THEN
    UPDATE public.founder_incident_postmortems
      SET action_items_closed_count = action_items_closed_count + 1
      WHERE id = v_pm;
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_postmortem_close_action_item(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_postmortem_close_action_item(uuid) TO authenticated;

-- ============================================================================
-- Read-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_postmortem_ledger_summary();
CREATE OR REPLACE FUNCTION public.founder_postmortem_ledger_summary()
RETURNS TABLE (
  total_postmortems              bigint,
  class_process_gap              bigint,
  class_code_bug                 bigint,
  class_data_inconsistency       bigint,
  class_vendor_failure           bigint,
  class_external_event           bigint,
  class_people_error             bigint,
  class_design_gap               bigint,
  class_other                    bigint,
  total_revenue_impact_rupees    numeric,
  total_affected_users           bigint,
  median_detection_lag_minutes   numeric,
  median_resolution_minutes      numeric,
  postmortems_30d                bigint,
  action_items_open              bigint,
  action_items_closed_pct        numeric,
  oldest_open_action_age_days    int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
  v_total_actions bigint;
  v_closed_actions bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.founder_incident_postmortems;
  SELECT count(*)::bigint INTO v_total_actions FROM public.founder_incident_postmortem_action_items;
  SELECT count(*)::bigint INTO v_closed_actions FROM public.founder_incident_postmortem_action_items WHERE status = 'closed';
  RETURN QUERY
  SELECT
    v_total,
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE root_cause_classification = 'process_gap'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE root_cause_classification = 'code_bug'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE root_cause_classification = 'data_inconsistency'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE root_cause_classification = 'vendor_failure'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE root_cause_classification = 'external_event'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE root_cause_classification = 'people_error'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE root_cause_classification = 'design_gap'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE root_cause_classification = 'other' OR root_cause_classification IS NULL), 0),
    coalesce((SELECT sum(revenue_impact_rupees) FROM public.founder_incident_postmortems), 0)::numeric,
    coalesce((SELECT sum(affected_user_count)::bigint FROM public.founder_incident_postmortems), 0),
    coalesce((SELECT round((percentile_cont(0.5) WITHIN GROUP (ORDER BY detection_lag_minutes))::numeric, 1)
              FROM public.founder_incident_postmortems WHERE detection_lag_minutes IS NOT NULL), 0)::numeric,
    coalesce((SELECT round((percentile_cont(0.5) WITHIN GROUP (ORDER BY resolution_duration_minutes))::numeric, 1)
              FROM public.founder_incident_postmortems WHERE resolution_duration_minutes IS NOT NULL), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems WHERE written_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortem_action_items WHERE status IN ('open','in_progress')), 0),
    CASE WHEN v_total_actions = 0 THEN 0::numeric
         ELSE round(100.0 * v_closed_actions / v_total_actions, 1) END,
    coalesce((SELECT extract(day from (now() - min(created_at)))::int
              FROM public.founder_incident_postmortem_action_items WHERE status IN ('open','in_progress')), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_postmortem_ledger_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_postmortem_ledger_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_postmortems_recent(int);
CREATE OR REPLACE FUNCTION public.founder_postmortems_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  id                            uuid,
  incident_id                   uuid,
  incident_title                text,
  incident_severity             text,
  incident_status               text,
  title                         text,
  root_cause_classification     text,
  severity_at_resolution        text,
  revenue_impact_rupees         numeric,
  affected_user_count           int,
  detection_lag_minutes         int,
  resolution_duration_minutes   int,
  action_items_count            int,
  action_items_closed_count     int,
  written_at                    timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    pm.id, pm.incident_id, fi.title AS incident_title,
    fi.severity AS incident_severity, fi.status AS incident_status,
    pm.title, pm.root_cause_classification, pm.severity_at_resolution,
    pm.revenue_impact_rupees, pm.affected_user_count,
    pm.detection_lag_minutes, pm.resolution_duration_minutes,
    pm.action_items_count, pm.action_items_closed_count, pm.written_at
  FROM public.founder_incident_postmortems pm
  LEFT JOIN public.founder_incidents fi ON fi.id = pm.incident_id
  ORDER BY pm.written_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_postmortems_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_postmortems_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_postmortem_action_items_open(int);
CREATE OR REPLACE FUNCTION public.founder_postmortem_action_items_open(p_limit int DEFAULT 50)
RETURNS TABLE (
  id              uuid,
  postmortem_id   uuid,
  postmortem_title text,
  description     text,
  owner_user_id   uuid,
  owner_email     text,
  due_date        date,
  status          text,
  age_days        int,
  is_overdue      boolean,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    ai.id, ai.postmortem_id, pm.title AS postmortem_title,
    ai.description, ai.owner_user_id, u.email::text AS owner_email,
    ai.due_date, ai.status,
    extract(day from (now() - ai.created_at))::int AS age_days,
    (ai.due_date IS NOT NULL AND ai.due_date < CURRENT_DATE AND ai.status IN ('open','in_progress')) AS is_overdue,
    ai.created_at
  FROM public.founder_incident_postmortem_action_items ai
  LEFT JOIN public.founder_incident_postmortems pm ON pm.id = ai.postmortem_id
  LEFT JOIN auth.users u ON u.id = ai.owner_user_id
  WHERE ai.status IN ('open','in_progress')
  ORDER BY ai.created_at ASC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_postmortem_action_items_open(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_postmortem_action_items_open(int) TO authenticated;

COMMIT;