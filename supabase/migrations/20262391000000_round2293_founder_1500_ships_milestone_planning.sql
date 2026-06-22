BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_1500_milestone_plans_r2293 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_title text NOT NULL,
  signifies text NOT NULL,
  target_ship_count int NOT NULL DEFAULT 1500,
  target_date date,
  ship_to_celebrate text NOT NULL,
  celebration_category text NOT NULL CHECK (celebration_category IN ('product','team','customer','investor','public','retro','other')),
  effort_estimate_hours int,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','planned','in_progress','shipped','cancelled')),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_f1500_plans_status_r2293
  ON public.founder_1500_milestone_plans_r2293 (status);
CREATE INDEX IF NOT EXISTS idx_f1500_plans_category_r2293
  ON public.founder_1500_milestone_plans_r2293 (celebration_category);

ALTER TABLE public.founder_1500_milestone_plans_r2293 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_1500_milestone_plans_r2293;
CREATE POLICY founder_all ON public.founder_1500_milestone_plans_r2293
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_1500_gift_commitments_r2293 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_name text NOT NULL,
  recipient_type text NOT NULL CHECK (recipient_type IN ('engineer','hospital_admin','supplier','manufacturer','logistics','investor','team','advisor','founder_self','other')),
  recipient_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  gift_description text NOT NULL,
  gift_category text NOT NULL CHECK (gift_category IN ('cash_bonus','equity','swag','dinner','experience','public_recognition','letter','other')),
  estimated_value_rupees int,
  reason text NOT NULL,
  promised_at timestamptz NOT NULL DEFAULT now(),
  promised_deadline date,
  fulfilled boolean NOT NULL DEFAULT false,
  fulfilled_at timestamptz,
  fulfillment_proof_url text,
  is_public_commitment boolean NOT NULL DEFAULT false,
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_f1500_gifts_fulfilled_r2293
  ON public.founder_1500_gift_commitments_r2293 (fulfilled);
CREATE INDEX IF NOT EXISTS idx_f1500_gifts_recipient_type_r2293
  ON public.founder_1500_gift_commitments_r2293 (recipient_type);

ALTER TABLE public.founder_1500_gift_commitments_r2293 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_1500_gift_commitments_r2293;
CREATE POLICY founder_all ON public.founder_1500_gift_commitments_r2293
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.founder_1500_list_plans_r2293();
CREATE FUNCTION public.founder_1500_list_plans_r2293()
RETURNS TABLE (
  plan_title text,
  signifies text,
  ship_to_celebrate text,
  celebration_category text,
  status text,
  priority text,
  target_date date,
  effort_estimate_hours int,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      p.plan_title,
      p.signifies,
      p.ship_to_celebrate,
      p.celebration_category,
      p.status,
      p.priority,
      p.target_date,
      p.effort_estimate_hours,
      p.created_at
    FROM public.founder_1500_milestone_plans_r2293 p
    ORDER BY
      CASE p.priority
        WHEN 'critical' THEN 0
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
      END,
      p.created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_1500_list_plans_r2293() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_1500_list_gifts_r2293();
CREATE FUNCTION public.founder_1500_list_gifts_r2293()
RETURNS TABLE (
  recipient_name text,
  recipient_type text,
  gift_description text,
  gift_category text,
  estimated_value_rupees int,
  reason text,
  promised_deadline date,
  fulfilled boolean,
  fulfilled_at timestamptz,
  is_public_commitment boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      g.recipient_name,
      g.recipient_type,
      g.gift_description,
      g.gift_category,
      g.estimated_value_rupees,
      g.reason,
      g.promised_deadline,
      g.fulfilled,
      g.fulfilled_at,
      g.is_public_commitment
    FROM public.founder_1500_gift_commitments_r2293 g
    ORDER BY g.fulfilled ASC, g.promised_deadline ASC NULLS LAST, g.promised_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_1500_list_gifts_r2293() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_1500_summary_r2293();
CREATE FUNCTION public.founder_1500_summary_r2293()
RETURNS TABLE (
  total_plans int,
  draft_plans int,
  planned_plans int,
  shipped_plans int,
  high_priority_plans int,
  total_gifts int,
  fulfilled_gifts int,
  pending_gifts int,
  total_gift_value_rupees bigint,
  public_commitments int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*) FROM public.founder_1500_milestone_plans_r2293)::int,
      (SELECT COUNT(*) FILTER (WHERE status = 'draft') FROM public.founder_1500_milestone_plans_r2293)::int,
      (SELECT COUNT(*) FILTER (WHERE status = 'planned') FROM public.founder_1500_milestone_plans_r2293)::int,
      (SELECT COUNT(*) FILTER (WHERE status = 'shipped') FROM public.founder_1500_milestone_plans_r2293)::int,
      (SELECT COUNT(*) FILTER (WHERE priority IN ('high','critical')) FROM public.founder_1500_milestone_plans_r2293)::int,
      (SELECT COUNT(*) FROM public.founder_1500_gift_commitments_r2293)::int,
      (SELECT COUNT(*) FILTER (WHERE fulfilled) FROM public.founder_1500_gift_commitments_r2293)::int,
      (SELECT COUNT(*) FILTER (WHERE NOT fulfilled) FROM public.founder_1500_gift_commitments_r2293)::int,
      (SELECT COALESCE(SUM(estimated_value_rupees), 0) FROM public.founder_1500_gift_commitments_r2293)::bigint,
      (SELECT COUNT(*) FILTER (WHERE is_public_commitment) FROM public.founder_1500_gift_commitments_r2293)::int;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_1500_summary_r2293() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_1500_plans_by_category_r2293();
CREATE FUNCTION public.founder_1500_plans_by_category_r2293()
RETURNS TABLE (
  celebration_category text,
  total_count int,
  shipped_count int,
  planned_count int,
  draft_count int,
  total_effort_hours int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      p.celebration_category,
      (COUNT(*))::int,
      (COUNT(*) FILTER (WHERE p.status = 'shipped'))::int,
      (COUNT(*) FILTER (WHERE p.status = 'planned'))::int,
      (COUNT(*) FILTER (WHERE p.status = 'draft'))::int,
      (COALESCE(SUM(p.effort_estimate_hours), 0))::int
    FROM public.founder_1500_milestone_plans_r2293 p
    GROUP BY p.celebration_category
    ORDER BY (COUNT(*))::int DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_1500_plans_by_category_r2293() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_1500_gifts_by_type_r2293();
CREATE FUNCTION public.founder_1500_gifts_by_type_r2293()
RETURNS TABLE (
  recipient_type text,
  total_count int,
  fulfilled_count int,
  pending_count int,
  public_count int,
  total_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      g.recipient_type,
      (COUNT(*))::int,
      (COUNT(*) FILTER (WHERE g.fulfilled))::int,
      (COUNT(*) FILTER (WHERE NOT g.fulfilled))::int,
      (COUNT(*) FILTER (WHERE g.is_public_commitment))::int,
      (COALESCE(SUM(g.estimated_value_rupees), 0))::bigint
    FROM public.founder_1500_gift_commitments_r2293 g
    GROUP BY g.recipient_type
    ORDER BY (COUNT(*))::int DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_1500_gifts_by_type_r2293() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_1500_overdue_gifts_r2293();
CREATE FUNCTION public.founder_1500_overdue_gifts_r2293()
RETURNS TABLE (
  recipient_name text,
  recipient_type text,
  gift_description text,
  promised_deadline date,
  days_overdue int,
  estimated_value_rupees int,
  is_public_commitment boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      g.recipient_name,
      g.recipient_type,
      g.gift_description,
      g.promised_deadline,
      (CURRENT_DATE - g.promised_deadline)::int AS days_overdue,
      g.estimated_value_rupees,
      g.is_public_commitment
    FROM public.founder_1500_gift_commitments_r2293 g
    WHERE NOT g.fulfilled
      AND g.promised_deadline IS NOT NULL
      AND g.promised_deadline < CURRENT_DATE
    ORDER BY g.promised_deadline ASC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_1500_overdue_gifts_r2293() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_1500_top_priorities_r2293();
CREATE FUNCTION public.founder_1500_top_priorities_r2293()
RETURNS TABLE (
  plan_title text,
  signifies text,
  ship_to_celebrate text,
  celebration_category text,
  priority text,
  status text,
  target_date date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      p.plan_title,
      p.signifies,
      p.ship_to_celebrate,
      p.celebration_category,
      p.priority,
      p.status,
      p.target_date
    FROM public.founder_1500_milestone_plans_r2293 p
    WHERE p.priority IN ('high','critical')
      AND p.status IN ('draft','planned','in_progress')
    ORDER BY
      CASE p.priority WHEN 'critical' THEN 0 ELSE 1 END,
      p.target_date ASC NULLS LAST,
      p.created_at DESC
    LIMIT 25;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_1500_top_priorities_r2293() TO authenticated;

COMMIT;
