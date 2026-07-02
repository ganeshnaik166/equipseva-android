BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_anniversaries_r2394 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  relationship_started_on date NOT NULL,
  milestone_years int NOT NULL CHECK (milestone_years IN (1,3,5,7,10)),
  milestone_date date NOT NULL,
  status text NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming','celebrated','skipped','lapsed')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_customer_anniversary_gifts_r2394 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anniversary_id uuid NOT NULL REFERENCES public.engineer_customer_anniversaries_r2394(id) ON DELETE CASCADE,
  gift_label text NOT NULL,
  gift_cost_rupees int NOT NULL DEFAULT 0 CHECK (gift_cost_rupees >= 0),
  delivered_on date,
  retention_impact text NOT NULL DEFAULT 'unknown' CHECK (retention_impact IN ('unknown','renewed','referral','no_impact','churned')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_anniversaries_r2394 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_customer_anniversary_gifts_r2394 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_anniv_r2394 ON public.engineer_customer_anniversaries_r2394;
CREATE POLICY founder_all_anniv_r2394 ON public.engineer_customer_anniversaries_r2394
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_gifts_r2394 ON public.engineer_customer_anniversary_gifts_r2394;
CREATE POLICY founder_all_gifts_r2394 ON public.engineer_customer_anniversary_gifts_r2394
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_anniversaries
CREATE OR REPLACE FUNCTION public.list_anniversaries_r2394()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  relationship_started_on date,
  milestone_years int,
  milestone_date date,
  status text,
  days_until int,
  gift_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, a.hospital_user_id, a.relationship_started_on,
    a.milestone_years, a.milestone_date, a.status,
    (a.milestone_date - CURRENT_DATE)::int AS days_until,
    (SELECT (COUNT(*))::int FROM public.engineer_customer_anniversary_gifts_r2394 g WHERE g.anniversary_id = a.id) AS gift_count
  FROM public.engineer_customer_anniversaries_r2394 a
  ORDER BY a.milestone_date ASC;
END;
$$;

-- RPC 2: add_anniversary
CREATE OR REPLACE FUNCTION public.add_anniversary_r2394(
  p_engineer_user_id uuid,
  p_hospital_user_id uuid,
  p_relationship_started_on date,
  p_milestone_years int,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_milestone_date date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_milestone_date := p_relationship_started_on + (p_milestone_years || ' years')::interval;
  INSERT INTO public.engineer_customer_anniversaries_r2394 (engineer_user_id, hospital_user_id, relationship_started_on, milestone_years, milestone_date, notes)
  VALUES (p_engineer_user_id, p_hospital_user_id, p_relationship_started_on, p_milestone_years, v_milestone_date, COALESCE(p_notes,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_anniversary_r2394', jsonb_build_object('anniversary_id', v_id, 'engineer_user_id', p_engineer_user_id, 'hospital_user_id', p_hospital_user_id, 'milestone_years', p_milestone_years));
  RETURN v_id;
END;
$$;

-- RPC 3: list_gifts
CREATE OR REPLACE FUNCTION public.list_gifts_r2394(p_anniversary_id uuid)
RETURNS TABLE (
  id uuid,
  anniversary_id uuid,
  gift_label text,
  gift_cost_rupees int,
  delivered_on date,
  retention_impact text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.anniversary_id, g.gift_label, g.gift_cost_rupees, g.delivered_on, g.retention_impact
  FROM public.engineer_customer_anniversary_gifts_r2394 g
  WHERE g.anniversary_id = p_anniversary_id
  ORDER BY COALESCE(g.delivered_on, '9999-12-31'::date) DESC;
END;
$$;

-- RPC 4: add_gift
CREATE OR REPLACE FUNCTION public.add_gift_r2394(
  p_anniversary_id uuid,
  p_gift_label text,
  p_gift_cost_rupees int,
  p_delivered_on date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_customer_anniversary_gifts_r2394 (anniversary_id, gift_label, gift_cost_rupees, delivered_on)
  VALUES (p_anniversary_id, p_gift_label, COALESCE(p_gift_cost_rupees,0), p_delivered_on)
  RETURNING id INTO v_id;
  IF p_delivered_on IS NOT NULL THEN
    UPDATE public.engineer_customer_anniversaries_r2394 SET status='celebrated', updated_at=now() WHERE id = p_anniversary_id AND status='upcoming';
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_gift_r2394', jsonb_build_object('gift_id', v_id, 'anniversary_id', p_anniversary_id, 'cost_rupees', p_gift_cost_rupees));
  RETURN v_id;
END;
$$;

-- RPC 5: set_retention_impact
CREATE OR REPLACE FUNCTION public.set_retention_impact_r2394(
  p_gift_id uuid,
  p_retention_impact text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_retention_impact NOT IN ('unknown','renewed','referral','no_impact','churned') THEN
    RAISE EXCEPTION 'invalid retention_impact';
  END IF;
  UPDATE public.engineer_customer_anniversary_gifts_r2394
  SET retention_impact = p_retention_impact, updated_at = now()
  WHERE id = p_gift_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_retention_impact_r2394', jsonb_build_object('gift_id', p_gift_id, 'impact', p_retention_impact));
END;
$$;

-- RPC 6: upcoming_anniversaries (next 60 days)
CREATE OR REPLACE FUNCTION public.upcoming_anniversaries_r2394()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  milestone_years int,
  milestone_date date,
  days_until int,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, a.hospital_user_id, a.milestone_years, a.milestone_date,
    (a.milestone_date - CURRENT_DATE)::int AS days_until,
    a.status
  FROM public.engineer_customer_anniversaries_r2394 a
  WHERE a.milestone_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '60 days')
    AND a.status = 'upcoming'
  ORDER BY a.milestone_date ASC;
END;
$$;

-- RPC 7: retention_summary_per_engineer
CREATE OR REPLACE FUNCTION public.retention_summary_per_engineer_r2394()
RETURNS TABLE (
  engineer_user_id uuid,
  total_anniversaries int,
  celebrated int,
  lapsed int,
  total_gift_spend_rupees bigint,
  renewed_count int,
  referral_count int,
  churned_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.engineer_user_id,
    (COUNT(*))::int AS total_anniversaries,
    (COUNT(*) FILTER (WHERE a.status='celebrated'))::int AS celebrated,
    (COUNT(*) FILTER (WHERE a.status='lapsed'))::int AS lapsed,
    COALESCE((SELECT SUM(g.gift_cost_rupees)::bigint
              FROM public.engineer_customer_anniversary_gifts_r2394 g
              WHERE g.anniversary_id IN (SELECT id FROM public.engineer_customer_anniversaries_r2394 WHERE engineer_user_id = a.engineer_user_id)), 0) AS total_gift_spend_rupees,
    (SELECT (COUNT(*))::int FROM public.engineer_customer_anniversary_gifts_r2394 g
      WHERE g.anniversary_id IN (SELECT id FROM public.engineer_customer_anniversaries_r2394 WHERE engineer_user_id = a.engineer_user_id)
        AND g.retention_impact = 'renewed') AS renewed_count,
    (SELECT (COUNT(*))::int FROM public.engineer_customer_anniversary_gifts_r2394 g
      WHERE g.anniversary_id IN (SELECT id FROM public.engineer_customer_anniversaries_r2394 WHERE engineer_user_id = a.engineer_user_id)
        AND g.retention_impact = 'referral') AS referral_count,
    (SELECT (COUNT(*))::int FROM public.engineer_customer_anniversary_gifts_r2394 g
      WHERE g.anniversary_id IN (SELECT id FROM public.engineer_customer_anniversaries_r2394 WHERE engineer_user_id = a.engineer_user_id)
        AND g.retention_impact = 'churned') AS churned_count
  FROM public.engineer_customer_anniversaries_r2394 a
  GROUP BY a.engineer_user_id
  ORDER BY a.engineer_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_anniversaries_r2394() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_anniversary_r2394(uuid, uuid, date, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_gifts_r2394(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_gift_r2394(uuid, text, int, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_retention_impact_r2394(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_anniversaries_r2394() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.retention_summary_per_engineer_r2394() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_anniversaries_r2394() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_anniversary_r2394(uuid, uuid, date, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_gifts_r2394(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_gift_r2394(uuid, text, int, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_retention_impact_r2394(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_anniversaries_r2394() TO authenticated;
GRANT EXECUTE ON FUNCTION public.retention_summary_per_engineer_r2394() TO authenticated;

COMMIT;
