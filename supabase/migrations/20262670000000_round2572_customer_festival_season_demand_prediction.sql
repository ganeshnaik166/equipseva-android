-- Round 2572: customer-festival-season-demand-prediction
-- Hospital × festival × prior demand × predicted demand × inventory readiness × engineer prep

CREATE TABLE IF NOT EXISTS public.customer_festival_demand_r2572 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  festival_label text NOT NULL,
  prior_year_demand_count int NOT NULL DEFAULT 0,
  predicted_demand_count int NOT NULL DEFAULT 0,
  demand_lift_pct numeric NOT NULL DEFAULT 0,
  inventory_readiness_pct int NOT NULL DEFAULT 0 CHECK (inventory_readiness_pct BETWEEN 0 AND 100),
  engineer_prep_count int NOT NULL DEFAULT 0,
  prep_status text NOT NULL DEFAULT 'not_started' CHECK (prep_status IN ('not_started','in_progress','ready','missed')),
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','closed')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.festival_engineer_prep_actions_r2572 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  festival_id uuid NOT NULL REFERENCES public.customer_festival_demand_r2572(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('extra_inventory','cross_train','shift_plan','courier_priority','communication')),
  owner_email text,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.customer_festival_demand_r2572 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.festival_engineer_prep_actions_r2572 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_festival_demand_r2572;
CREATE POLICY founder_all ON public.customer_festival_demand_r2572
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.festival_engineer_prep_actions_r2572;
CREATE POLICY founder_all ON public.festival_engineer_prep_actions_r2572
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.customer_festival_demand_r2572
  (festival_label, prior_year_demand_count, predicted_demand_count, demand_lift_pct, inventory_readiness_pct, engineer_prep_count, prep_status, owner_email, status, notes)
VALUES
  ('Diwali 2026', 142, 196, 38.0, 72, 6, 'in_progress', 'ops@equipseva.in', 'in_progress', 'Surge in dental + ortho consumables; ortho clinics holiday-pack'),
  ('Pongal 2027', 58, 64, 10.3, 95, 3, 'ready', 'ops@equipseva.in', 'planned', 'Tamil Nadu clinics; mostly preventive AMC visits'),
  ('Eid al-Fitr 2027', 73, 91, 24.6, 60, 4, 'in_progress', 'ops@equipseva.in', 'in_progress', 'Hyderabad cluster; ENT + cath-lab demand spike'),
  ('Ganesh Chaturthi 2026', 89, 80, -10.1, 88, 2, 'ready', 'ops@equipseva.in', 'closed', 'Maharashtra; flat demand vs prior year'),
  ('Christmas 2026', 64, 78, 21.9, 40, 2, 'not_started', 'ops@equipseva.in', 'planned', 'Kerala + Goa diocese hospitals; need cross-training');

INSERT INTO public.festival_engineer_prep_actions_r2572
  (festival_id, action_at, action_kind, owner_email, outcome, status, notes)
VALUES
  ((SELECT id FROM public.customer_festival_demand_r2572 WHERE festival_label='Diwali 2026' LIMIT 1),
   '2026-09-15T10:00:00+05:30'::timestamptz, 'extra_inventory',
   'ops@equipseva.in', 'positive', 'done',
   'Pre-stocked dental drills + ortho cement at Hyderabad hub'),
  ((SELECT id FROM public.customer_festival_demand_r2572 WHERE festival_label='Diwali 2026' LIMIT 1),
   '2026-09-20T11:00:00+05:30'::timestamptz, 'cross_train',
   'ops@equipseva.in', 'pending', 'open',
   '4 Tier-2 engineers cross-trained on ortho-emergencies'),
  ((SELECT id FROM public.customer_festival_demand_r2572 WHERE festival_label='Eid al-Fitr 2027' LIMIT 1),
   '2027-02-10T09:30:00+05:30'::timestamptz, 'shift_plan',
   'ops@equipseva.in', 'pending', 'open',
   '24x7 rotation for Hyderabad cath-lab cluster'),
  ((SELECT id FROM public.customer_festival_demand_r2572 WHERE festival_label='Christmas 2026' LIMIT 1),
   '2026-11-05T14:00:00+05:30'::timestamptz, 'courier_priority',
   'ops@equipseva.in', 'pending', 'open',
   'Pre-booked Bluedart same-day Kerala lane'),
  ((SELECT id FROM public.customer_festival_demand_r2572 WHERE festival_label='Pongal 2027' LIMIT 1),
   '2027-01-08T08:30:00+05:30'::timestamptz, 'communication',
   'ops@equipseva.in', 'positive', 'done',
   'Sent SMS reminder to all TN AMC customers');

-- RPCs

CREATE OR REPLACE FUNCTION public.list_demand_r2572()
RETURNS TABLE (
  id uuid, festival_label text, prior_year_demand_count int,
  predicted_demand_count int, demand_lift_pct numeric,
  inventory_readiness_pct int, engineer_prep_count int,
  prep_status text, owner_email text, status text,
  notes text, created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.festival_label, d.prior_year_demand_count,
         d.predicted_demand_count, d.demand_lift_pct,
         d.inventory_readiness_pct, d.engineer_prep_count,
         d.prep_status, d.owner_email, d.status,
         d.notes, d.created_at
  FROM public.customer_festival_demand_r2572 d
  ORDER BY d.demand_lift_pct DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_demand_r2572() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_demand_r2572() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_prep_actions_r2572()
RETURNS TABLE (
  id uuid, festival_id uuid, festival_label text,
  action_at timestamptz, action_kind text,
  owner_email text, outcome text, status text, notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.festival_id, d.festival_label,
         a.action_at, a.action_kind,
         a.owner_email, a.outcome, a.status, a.notes
  FROM public.festival_engineer_prep_actions_r2572 a
  JOIN public.customer_festival_demand_r2572 d ON d.id = a.festival_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_prep_actions_r2572() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_prep_actions_r2572() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_lift_festivals_r2572()
RETURNS TABLE (
  festival_label text, prior_year_demand_count int,
  predicted_demand_count int, demand_lift_pct numeric,
  inventory_readiness_pct int, prep_status text, status text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.festival_label, d.prior_year_demand_count,
         d.predicted_demand_count, d.demand_lift_pct,
         d.inventory_readiness_pct, d.prep_status, d.status
  FROM public.customer_festival_demand_r2572 d
  ORDER BY d.demand_lift_pct DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_lift_festivals_r2572() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_lift_festivals_r2572() TO authenticated;

CREATE OR REPLACE FUNCTION public.prep_status_funnel_r2572()
RETURNS TABLE (
  prep_status text, cnt bigint,
  avg_lift_pct numeric, avg_readiness numeric,
  total_engineer_prep int
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.prep_status, COUNT(*)::bigint,
         ROUND(AVG(d.demand_lift_pct)::numeric, 2),
         ROUND(AVG(d.inventory_readiness_pct)::numeric, 2),
         SUM(d.engineer_prep_count)::int
  FROM public.customer_festival_demand_r2572 d
  GROUP BY d.prep_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prep_status_funnel_r2572() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prep_status_funnel_r2572() TO authenticated;

CREATE OR REPLACE FUNCTION public.inventory_readiness_summary_r2572()
RETURNS TABLE (
  status text, cnt bigint,
  avg_readiness numeric, min_readiness int, max_readiness int,
  avg_lift_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.status, COUNT(*)::bigint,
         ROUND(AVG(d.inventory_readiness_pct)::numeric, 2),
         MIN(d.inventory_readiness_pct)::int,
         MAX(d.inventory_readiness_pct)::int,
         ROUND(AVG(d.demand_lift_pct)::numeric, 2)
  FROM public.customer_festival_demand_r2572 d
  GROUP BY d.status
  ORDER BY AVG(d.inventory_readiness_pct) ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.inventory_readiness_summary_r2572() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inventory_readiness_summary_r2572() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_action_trend_r2572()
RETURNS TABLE (
  month_label text, cnt bigint,
  done_count bigint, open_count bigint, dropped_count bigint,
  positive_count bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(a.action_at, 'YYYY-MM') AS month_label,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE a.status = 'done')::bigint,
         COUNT(*) FILTER (WHERE a.status = 'open')::bigint,
         COUNT(*) FILTER (WHERE a.status = 'dropped')::bigint,
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint
  FROM public.festival_engineer_prep_actions_r2572 a
  GROUP BY to_char(a.action_at, 'YYYY-MM')
  ORDER BY to_char(a.action_at, 'YYYY-MM') ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_action_trend_r2572() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_action_trend_r2572() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_hospitals_by_demand_r2572()
RETURNS TABLE (
  hospital_user_id uuid, hospital_email text,
  festival_count bigint, total_predicted int,
  total_prior int, avg_lift_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.hospital_user_id,
         p.email,
         COUNT(*)::bigint,
         SUM(d.predicted_demand_count)::int,
         SUM(d.prior_year_demand_count)::int,
         ROUND(AVG(d.demand_lift_pct)::numeric, 2)
  FROM public.customer_festival_demand_r2572 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  GROUP BY d.hospital_user_id, p.email
  ORDER BY SUM(d.predicted_demand_count) DESC NULLS LAST
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_demand_r2572() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_demand_r2572() TO authenticated;
