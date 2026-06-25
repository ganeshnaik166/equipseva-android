-- r2618 engineer-customer-second-visit-prevention
BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_second_visit_root_cause_r2618 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  first_visit_at timestamptz NOT NULL,
  second_visit_at timestamptz NOT NULL,
  root_cause_kind text NOT NULL CHECK (root_cause_kind IN ('wrong_spare','diagnosis_miss','equipment_dependent','customer_change','training_gap')),
  preventable boolean NOT NULL DEFAULT false,
  cost_rupees integer NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','escalated')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.second_visit_prevention_actions_r2618 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  root_cause_id uuid REFERENCES public.engineer_second_visit_root_cause_r2618(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('training','spare_kit_change','sop_update','equipment_check','customer_brief')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_second_visit_root_cause_r2618 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.second_visit_prevention_actions_r2618 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_second_visit_root_cause_r2618;
CREATE POLICY founder_all ON public.engineer_second_visit_root_cause_r2618
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.second_visit_prevention_actions_r2618;
CREATE POLICY founder_all ON public.second_visit_prevention_actions_r2618
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.engineer_second_visit_root_cause_r2618 (first_visit_at, second_visit_at, root_cause_kind, preventable, cost_rupees, owner_email, status, notes) VALUES
  ('2026-06-01 09:00:00'::timestamptz, '2026-06-03 10:00:00'::timestamptz, 'wrong_spare', true, 2400, 'ops@equipseva.com', 'open', 'wrong belt size carried'),
  ('2026-06-05 11:00:00'::timestamptz, '2026-06-07 09:30:00'::timestamptz, 'diagnosis_miss', true, 3100, 'qa@equipseva.com', 'closed', 'missed sensor fault on first pass'),
  ('2026-06-08 14:00:00'::timestamptz, '2026-06-10 15:00:00'::timestamptz, 'training_gap', true, 1800, 'training@equipseva.com', 'escalated', 'engineer new to vendor model'),
  ('2026-06-11 10:00:00'::timestamptz, '2026-06-13 12:00:00'::timestamptz, 'equipment_dependent', false, 4200, 'ops@equipseva.com', 'open', 'awaiting vendor part shipment'),
  ('2026-06-15 09:00:00'::timestamptz, '2026-06-17 11:00:00'::timestamptz, 'customer_change', false, 900, 'cx@equipseva.com', 'closed', 'customer added new device mid-visit');

INSERT INTO public.second_visit_prevention_actions_r2618 (root_cause_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, second_visit_at + interval '1 day', 'training', 'positive', 'training@equipseva.com', 'done', 'refresher module assigned'
FROM public.engineer_second_visit_root_cause_r2618 WHERE root_cause_kind='training_gap' LIMIT 1;

INSERT INTO public.second_visit_prevention_actions_r2618 (root_cause_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, second_visit_at + interval '2 day', 'spare_kit_change', 'pending', 'ops@equipseva.com', 'open', 'kit SKU revised'
FROM public.engineer_second_visit_root_cause_r2618 WHERE root_cause_kind='wrong_spare' LIMIT 1;

INSERT INTO public.second_visit_prevention_actions_r2618 (root_cause_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, second_visit_at + interval '1 day', 'sop_update', 'neutral', 'qa@equipseva.com', 'done', 'diagnostic checklist updated'
FROM public.engineer_second_visit_root_cause_r2618 WHERE root_cause_kind='diagnosis_miss' LIMIT 1;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_root_causes_r2618()
RETURNS TABLE (id uuid, first_visit_at timestamptz, second_visit_at timestamptz, root_cause_kind text, preventable boolean, cost_rupees integer, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.first_visit_at, r.second_visit_at, r.root_cause_kind, r.preventable, r.cost_rupees, r.owner_email, r.status, r.notes
    FROM public.engineer_second_visit_root_cause_r2618 r ORDER BY r.second_visit_at DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.list_root_causes_r2618() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_root_causes_r2618() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_prevention_actions_r2618()
RETURNS TABLE (id uuid, root_cause_id uuid, action_at timestamptz, action_kind text, outcome text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.root_cause_id, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
    FROM public.second_visit_prevention_actions_r2618 a ORDER BY a.action_at DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.list_prevention_actions_r2618() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_prevention_actions_r2618() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_preventable_focus_r2618()
RETURNS TABLE (root_cause_kind text, preventable_count bigint, total_cost_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.root_cause_kind, count(*)::bigint, coalesce(sum(r.cost_rupees),0)::bigint
    FROM public.engineer_second_visit_root_cause_r2618 r
    WHERE r.preventable = true
    GROUP BY r.root_cause_kind ORDER BY count(*) DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.top_preventable_focus_r2618() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_preventable_focus_r2618() TO authenticated;

CREATE OR REPLACE FUNCTION public.root_cause_kind_distribution_r2618()
RETURNS TABLE (root_cause_kind text, cnt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.root_cause_kind, count(*)::bigint
    FROM public.engineer_second_visit_root_cause_r2618 r
    GROUP BY r.root_cause_kind ORDER BY count(*) DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.root_cause_kind_distribution_r2618() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_cause_kind_distribution_r2618() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_second_visit_trend_r2618()
RETURNS TABLE (month_start timestamptz, cnt bigint, total_cost bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT date_trunc('month', r.second_visit_at)::timestamptz, count(*)::bigint, coalesce(sum(r.cost_rupees),0)::bigint
    FROM public.engineer_second_visit_root_cause_r2618 r
    GROUP BY 1 ORDER BY 1 DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.monthly_second_visit_trend_r2618() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_second_visit_trend_r2618() TO authenticated;

CREATE OR REPLACE FUNCTION public.cost_summary_r2618()
RETURNS TABLE (total_cost bigint, preventable_cost bigint, open_count bigint, closed_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    coalesce(sum(r.cost_rupees),0)::bigint,
    coalesce(sum(CASE WHEN r.preventable THEN r.cost_rupees ELSE 0 END),0)::bigint,
    count(*) FILTER (WHERE r.status='open')::bigint,
    count(*) FILTER (WHERE r.status='closed')::bigint
    FROM public.engineer_second_visit_root_cause_r2618 r;
END$$;
REVOKE EXECUTE ON FUNCTION public.cost_summary_r2618() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cost_summary_r2618() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2618()
RETURNS TABLE (owner_email text, open_root_causes bigint, open_actions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH rc AS (
    SELECT r.owner_email, count(*)::bigint AS c
    FROM public.engineer_second_visit_root_cause_r2618 r
    WHERE r.status='open' AND r.owner_email IS NOT NULL
    GROUP BY r.owner_email
  ),
  ac AS (
    SELECT a.owner_email, count(*)::bigint AS c
    FROM public.second_visit_prevention_actions_r2618 a
    WHERE a.status='open' AND a.owner_email IS NOT NULL
    GROUP BY a.owner_email
  )
  SELECT coalesce(rc.owner_email, ac.owner_email),
         coalesce(rc.c,0),
         coalesce(ac.c,0)
  FROM rc FULL OUTER JOIN ac ON rc.owner_email = ac.owner_email
  ORDER BY 2 DESC NULLS LAST, 3 DESC NULLS LAST;
END$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2618() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2618() TO authenticated;

COMMIT;
