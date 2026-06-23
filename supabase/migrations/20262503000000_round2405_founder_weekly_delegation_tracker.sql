BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_delegation_items_r2405 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_starting date NOT NULL,
  delegated_to_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  delegated_to_role text NOT NULL CHECK (delegated_to_role IN ('engineer','hospital_admin','supplier','manufacturer','logistics')),
  task_title text NOT NULL,
  task_description text,
  category text NOT NULL CHECK (category IN ('operations','sales','support','finance','partnerships','people','product')),
  priority text NOT NULL CHECK (priority IN ('low','medium','high','urgent')),
  delegated_at timestamptz NOT NULL DEFAULT now(),
  due_date date,
  decision_authority text NOT NULL CHECK (decision_authority IN ('full','partial','recommend_only')),
  expected_outcome text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_delegation_outcomes_r2405 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delegation_id uuid NOT NULL REFERENCES public.founder_delegation_items_r2405(id) ON DELETE CASCADE,
  outcome_status text NOT NULL CHECK (outcome_status IN ('handled_independently','escalated_back','partially_done','dropped','in_progress')),
  delegate_handled boolean NOT NULL DEFAULT false,
  bounced_back_to_founder boolean NOT NULL DEFAULT false,
  bounce_reason text,
  gap_identified text,
  completed_at timestamptz,
  founder_hours_spent numeric(5,2) DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_delegation_items_r2405 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_delegation_outcomes_r2405 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_delegation_items_r2405;
CREATE POLICY founder_all ON public.founder_delegation_items_r2405 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_delegation_outcomes_r2405;
CREATE POLICY founder_all ON public.founder_delegation_outcomes_r2405 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_delegation_items_week_r2405 ON public.founder_delegation_items_r2405(week_starting DESC);
CREATE INDEX IF NOT EXISTS idx_delegation_outcomes_delegation_r2405 ON public.founder_delegation_outcomes_r2405(delegation_id);

CREATE OR REPLACE FUNCTION public.delegation_weekly_summary_r2405()
RETURNS TABLE(week_starting date, total_delegated bigint, handled_independently bigint, bounced_back bigint, dropped bigint, bounce_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.week_starting,
         COUNT(*)::bigint AS total_delegated,
         COUNT(*) FILTER (WHERE o.outcome_status = 'handled_independently')::bigint AS handled_independently,
         COUNT(*) FILTER (WHERE o.bounced_back_to_founder)::bigint AS bounced_back,
         COUNT(*) FILTER (WHERE o.outcome_status = 'dropped')::bigint AS dropped,
         ROUND(100.0 * COUNT(*) FILTER (WHERE o.bounced_back_to_founder) / NULLIF(COUNT(*), 0), 1) AS bounce_rate
    FROM public.founder_delegation_items_r2405 i
    LEFT JOIN public.founder_delegation_outcomes_r2405 o ON o.delegation_id = i.id
   GROUP BY i.week_starting
   ORDER BY i.week_starting DESC
   LIMIT 12;
END;
$$;

CREATE OR REPLACE FUNCTION public.delegation_by_role_r2405()
RETURNS TABLE(delegated_to_role text, total_tasks bigint, handled bigint, bounced bigint, handle_rate numeric, avg_founder_hours numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.delegated_to_role,
         COUNT(*)::bigint AS total_tasks,
         COUNT(*) FILTER (WHERE o.delegate_handled)::bigint AS handled,
         COUNT(*) FILTER (WHERE o.bounced_back_to_founder)::bigint AS bounced,
         ROUND(100.0 * COUNT(*) FILTER (WHERE o.delegate_handled) / NULLIF(COUNT(*), 0), 1) AS handle_rate,
         ROUND(AVG(o.founder_hours_spent), 2) AS avg_founder_hours
    FROM public.founder_delegation_items_r2405 i
    LEFT JOIN public.founder_delegation_outcomes_r2405 o ON o.delegation_id = i.id
   GROUP BY i.delegated_to_role
   ORDER BY total_tasks DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.delegation_recent_bounces_r2405()
RETURNS TABLE(id uuid, week_starting date, task_title text, delegated_to_role text, bounce_reason text, gap_identified text, founder_hours_spent numeric, recorded_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.week_starting, i.task_title, i.delegated_to_role,
         o.bounce_reason, o.gap_identified, o.founder_hours_spent, o.recorded_at
    FROM public.founder_delegation_outcomes_r2405 o
    JOIN public.founder_delegation_items_r2405 i ON i.id = o.delegation_id
   WHERE o.bounced_back_to_founder
   ORDER BY o.recorded_at DESC
   LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.delegation_open_items_r2405()
RETURNS TABLE(id uuid, week_starting date, task_title text, category text, priority text, delegated_to_role text, due_date date, decision_authority text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.week_starting, i.task_title, i.category, i.priority,
         i.delegated_to_role, i.due_date, i.decision_authority
    FROM public.founder_delegation_items_r2405 i
    LEFT JOIN public.founder_delegation_outcomes_r2405 o ON o.delegation_id = i.id
   WHERE o.id IS NULL OR o.outcome_status = 'in_progress'
   ORDER BY i.priority DESC, i.due_date ASC NULLS LAST
   LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.delegation_category_gaps_r2405()
RETURNS TABLE(category text, total_tasks bigint, bounced bigint, dropped bigint, gap_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.category,
         COUNT(*)::bigint AS total_tasks,
         COUNT(*) FILTER (WHERE o.bounced_back_to_founder)::bigint AS bounced,
         COUNT(*) FILTER (WHERE o.outcome_status = 'dropped')::bigint AS dropped,
         ROUND(100.0 * COUNT(*) FILTER (WHERE o.bounced_back_to_founder OR o.outcome_status = 'dropped') / NULLIF(COUNT(*), 0), 1) AS gap_rate
    FROM public.founder_delegation_items_r2405 i
    LEFT JOIN public.founder_delegation_outcomes_r2405 o ON o.delegation_id = i.id
   GROUP BY i.category
   ORDER BY gap_rate DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION public.delegation_founder_load_r2405()
RETURNS TABLE(week_starting date, total_founder_hours numeric, hours_on_bounces numeric, hours_on_originally_owned numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.week_starting,
         COALESCE(SUM(o.founder_hours_spent), 0) AS total_founder_hours,
         COALESCE(SUM(o.founder_hours_spent) FILTER (WHERE o.bounced_back_to_founder), 0) AS hours_on_bounces,
         COALESCE(SUM(o.founder_hours_spent) FILTER (WHERE NOT o.bounced_back_to_founder), 0) AS hours_on_originally_owned
    FROM public.founder_delegation_items_r2405 i
    LEFT JOIN public.founder_delegation_outcomes_r2405 o ON o.delegation_id = i.id
   GROUP BY i.week_starting
   ORDER BY i.week_starting DESC
   LIMIT 12;
END;
$$;

CREATE OR REPLACE FUNCTION public.delegation_top_handlers_r2405()
RETURNS TABLE(delegated_to_user_id uuid, delegate_email text, role_text text, total_assigned bigint, handled_independently bigint, success_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.delegated_to_user_id,
         p.email AS delegate_email,
         i.delegated_to_role AS role_text,
         COUNT(*)::bigint AS total_assigned,
         COUNT(*) FILTER (WHERE o.outcome_status = 'handled_independently')::bigint AS handled_independently,
         ROUND(100.0 * COUNT(*) FILTER (WHERE o.outcome_status = 'handled_independently') / NULLIF(COUNT(*), 0), 1) AS success_rate
    FROM public.founder_delegation_items_r2405 i
    LEFT JOIN public.founder_delegation_outcomes_r2405 o ON o.delegation_id = i.id
    LEFT JOIN public.profiles p ON p.id = i.delegated_to_user_id
   WHERE i.delegated_to_user_id IS NOT NULL
   GROUP BY i.delegated_to_user_id, p.email, i.delegated_to_role
   HAVING COUNT(*) >= 2
   ORDER BY success_rate DESC NULLS LAST, total_assigned DESC
   LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.delegation_weekly_summary_r2405() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delegation_by_role_r2405() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delegation_recent_bounces_r2405() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delegation_open_items_r2405() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delegation_category_gaps_r2405() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delegation_founder_load_r2405() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delegation_top_handlers_r2405() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.delegation_weekly_summary_r2405() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delegation_by_role_r2405() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delegation_recent_bounces_r2405() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delegation_open_items_r2405() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delegation_category_gaps_r2405() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delegation_founder_load_r2405() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delegation_top_handlers_r2405() TO authenticated;

COMMIT;
