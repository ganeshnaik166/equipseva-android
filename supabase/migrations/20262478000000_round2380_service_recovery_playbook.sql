BEGIN;

CREATE TABLE IF NOT EXISTS public.service_recovery_playbooks_r2380 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playbook_title text NOT NULL,
  failure_category text NOT NULL CHECK (failure_category IN ('late_sla','wrong_diagnosis','rude_engineer','part_unavailable','repeat_visit','billing_dispute','no_show','other')),
  recommended_steps_md text NOT NULL DEFAULT '',
  version int NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.service_recovery_events_r2380 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playbook_id uuid REFERENCES public.service_recovery_playbooks_r2380(id) ON DELETE SET NULL,
  engineer_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  customer_org_id uuid,
  repair_job_id uuid,
  failure_category text NOT NULL CHECK (failure_category IN ('late_sla','wrong_diagnosis','rude_engineer','part_unavailable','repeat_visit','billing_dispute','no_show','other')),
  failure_description text NOT NULL DEFAULT '',
  playbook_used boolean NOT NULL DEFAULT false,
  steps_followed_md text NOT NULL DEFAULT '',
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','customer_saved','customer_lost','partial_recovery')),
  customer_csat int CHECK (customer_csat IS NULL OR (customer_csat BETWEEN 1 AND 5)),
  playbook_update_suggestion text NOT NULL DEFAULT '',
  occurred_on date NOT NULL DEFAULT CURRENT_DATE,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.service_recovery_playbooks_r2380 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_recovery_events_r2380 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_playbooks_r2380 ON public.service_recovery_playbooks_r2380;
CREATE POLICY founder_all_playbooks_r2380 ON public.service_recovery_playbooks_r2380
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_events_r2380 ON public.service_recovery_events_r2380;
CREATE POLICY founder_all_events_r2380 ON public.service_recovery_events_r2380
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_playbooks
CREATE OR REPLACE FUNCTION public.list_playbooks_r2380()
RETURNS TABLE (
  id uuid,
  playbook_title text,
  failure_category text,
  version int,
  is_active boolean,
  event_count int,
  saved_count int,
  lost_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.playbook_title, p.failure_category, p.version, p.is_active,
    (SELECT (COUNT(*))::int FROM public.service_recovery_events_r2380 e WHERE e.playbook_id = p.id) AS event_count,
    (SELECT (COUNT(*))::int FROM public.service_recovery_events_r2380 e WHERE e.playbook_id = p.id AND e.outcome = 'customer_saved') AS saved_count,
    (SELECT (COUNT(*))::int FROM public.service_recovery_events_r2380 e WHERE e.playbook_id = p.id AND e.outcome = 'customer_lost') AS lost_count
  FROM public.service_recovery_playbooks_r2380 p
  ORDER BY p.is_active DESC, p.failure_category, p.version DESC;
END;
$$;

-- RPC 2: add_playbook
CREATE OR REPLACE FUNCTION public.add_playbook_r2380(
  p_playbook_title text,
  p_failure_category text,
  p_recommended_steps_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.service_recovery_playbooks_r2380 (playbook_title, failure_category, recommended_steps_md)
  VALUES (p_playbook_title, p_failure_category, p_recommended_steps_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_playbook_r2380', jsonb_build_object('playbook_id', v_id, 'title', p_playbook_title, 'category', p_failure_category));
  RETURN v_id;
END;
$$;

-- RPC 3: list_events
CREATE OR REPLACE FUNCTION public.list_events_r2380()
RETURNS TABLE (
  id uuid,
  occurred_on date,
  failure_category text,
  engineer_id uuid,
  customer_org_id uuid,
  playbook_id uuid,
  playbook_title text,
  playbook_used boolean,
  outcome text,
  customer_csat int,
  resolved_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.occurred_on, e.failure_category, e.engineer_id, e.customer_org_id,
    e.playbook_id,
    (SELECT p.playbook_title FROM public.service_recovery_playbooks_r2380 p WHERE p.id = e.playbook_id) AS playbook_title,
    e.playbook_used, e.outcome, e.customer_csat, e.resolved_at
  FROM public.service_recovery_events_r2380 e
  ORDER BY e.occurred_on DESC, e.created_at DESC;
END;
$$;

-- RPC 4: log_event
CREATE OR REPLACE FUNCTION public.log_event_r2380(
  p_playbook_id uuid,
  p_engineer_id uuid,
  p_customer_org_id uuid,
  p_repair_job_id uuid,
  p_failure_category text,
  p_failure_description text,
  p_playbook_used boolean,
  p_steps_followed_md text,
  p_occurred_on date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.service_recovery_events_r2380 (
    playbook_id, engineer_id, customer_org_id, repair_job_id,
    failure_category, failure_description, playbook_used, steps_followed_md, occurred_on
  )
  VALUES (
    p_playbook_id, p_engineer_id, p_customer_org_id, p_repair_job_id,
    p_failure_category, p_failure_description, p_playbook_used, p_steps_followed_md,
    COALESCE(p_occurred_on, CURRENT_DATE)
  )
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_event_r2380', jsonb_build_object('event_id', v_id, 'category', p_failure_category, 'playbook_used', p_playbook_used));
  RETURN v_id;
END;
$$;

-- RPC 5: set_outcome
CREATE OR REPLACE FUNCTION public.set_outcome_r2380(
  p_event_id uuid,
  p_outcome text,
  p_customer_csat int,
  p_playbook_update_suggestion text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.service_recovery_events_r2380
  SET outcome = p_outcome,
      customer_csat = p_customer_csat,
      playbook_update_suggestion = COALESCE(p_playbook_update_suggestion, ''),
      resolved_at = now(),
      updated_at = now()
  WHERE id = p_event_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_outcome_r2380', jsonb_build_object('event_id', p_event_id, 'outcome', p_outcome, 'csat', p_customer_csat));
END;
$$;

-- RPC 6: category_recovery_stats
CREATE OR REPLACE FUNCTION public.category_recovery_stats_r2380()
RETURNS TABLE (
  failure_category text,
  total_events int,
  playbook_used_count int,
  playbook_skipped_count int,
  saved_count int,
  lost_count int,
  partial_count int,
  save_rate_with_playbook numeric,
  save_rate_without_playbook numeric,
  avg_csat numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.failure_category,
    (COUNT(*))::int AS total_events,
    (COUNT(*) FILTER (WHERE e.playbook_used))::int AS playbook_used_count,
    (COUNT(*) FILTER (WHERE NOT e.playbook_used))::int AS playbook_skipped_count,
    (COUNT(*) FILTER (WHERE e.outcome = 'customer_saved'))::int AS saved_count,
    (COUNT(*) FILTER (WHERE e.outcome = 'customer_lost'))::int AS lost_count,
    (COUNT(*) FILTER (WHERE e.outcome = 'partial_recovery'))::int AS partial_count,
    ROUND(
      (COUNT(*) FILTER (WHERE e.playbook_used AND e.outcome = 'customer_saved'))::numeric
      / NULLIF((COUNT(*) FILTER (WHERE e.playbook_used AND e.outcome IN ('customer_saved','customer_lost','partial_recovery'))), 0)
      * 100, 2
    ) AS save_rate_with_playbook,
    ROUND(
      (COUNT(*) FILTER (WHERE NOT e.playbook_used AND e.outcome = 'customer_saved'))::numeric
      / NULLIF((COUNT(*) FILTER (WHERE NOT e.playbook_used AND e.outcome IN ('customer_saved','customer_lost','partial_recovery'))), 0)
      * 100, 2
    ) AS save_rate_without_playbook,
    ROUND(AVG(e.customer_csat)::numeric, 2) AS avg_csat
  FROM public.service_recovery_events_r2380 e
  GROUP BY e.failure_category
  ORDER BY total_events DESC;
END;
$$;

-- RPC 7: pending_update_suggestions
CREATE OR REPLACE FUNCTION public.pending_update_suggestions_r2380()
RETURNS TABLE (
  event_id uuid,
  occurred_on date,
  failure_category text,
  playbook_id uuid,
  playbook_title text,
  outcome text,
  customer_csat int,
  playbook_update_suggestion text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id AS event_id, e.occurred_on, e.failure_category,
    e.playbook_id,
    (SELECT p.playbook_title FROM public.service_recovery_playbooks_r2380 p WHERE p.id = e.playbook_id) AS playbook_title,
    e.outcome, e.customer_csat, e.playbook_update_suggestion
  FROM public.service_recovery_events_r2380 e
  WHERE COALESCE(NULLIF(TRIM(e.playbook_update_suggestion), ''), NULL) IS NOT NULL
  ORDER BY e.occurred_on DESC, e.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_playbooks_r2380() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_playbook_r2380(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_events_r2380() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_event_r2380(uuid, uuid, uuid, uuid, text, text, boolean, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_outcome_r2380(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.category_recovery_stats_r2380() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pending_update_suggestions_r2380() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_playbooks_r2380() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_playbook_r2380(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_events_r2380() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_event_r2380(uuid, uuid, uuid, uuid, text, text, boolean, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_outcome_r2380(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.category_recovery_stats_r2380() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pending_update_suggestions_r2380() TO authenticated;

COMMIT;
