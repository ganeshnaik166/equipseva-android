BEGIN;

-- =====================================================
-- Round 1791: Hospital Equipment Lifecycle Tracker
-- =====================================================

CREATE TABLE IF NOT EXISTS public.hospital_equipment_lifecycle_r1791 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_name text NOT NULL,
  manufacturer text,
  install_date date,
  current_stage text NOT NULL DEFAULT 'installed' CHECK (current_stage IN ('installed','operational','aging','end_of_life','decommissioned')),
  expected_end_of_life_date date,
  age_months int NOT NULL DEFAULT 0,
  total_repairs int NOT NULL DEFAULT 0,
  total_repair_cost_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hel_r1791_hosp ON public.hospital_equipment_lifecycle_r1791(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hel_r1791_stage ON public.hospital_equipment_lifecycle_r1791(current_stage);
CREATE INDEX IF NOT EXISTS idx_hel_r1791_eol ON public.hospital_equipment_lifecycle_r1791(expected_end_of_life_date);

CREATE TABLE IF NOT EXISTS public.hospital_equipment_replacement_planning_r1791 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lifecycle_id uuid NOT NULL REFERENCES public.hospital_equipment_lifecycle_r1791(id) ON DELETE CASCADE,
  replacement_quote_sent_at timestamptz,
  replacement_decision text CHECK (replacement_decision IN ('buy_us','buy_competitor','repair_again','decommission')),
  decided_at timestamptz,
  decided_by_email text,
  quote_amount_rupees bigint,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_herp_r1791_lc ON public.hospital_equipment_replacement_planning_r1791(lifecycle_id);
CREATE INDEX IF NOT EXISTS idx_herp_r1791_decision ON public.hospital_equipment_replacement_planning_r1791(replacement_decision);

ALTER TABLE public.hospital_equipment_lifecycle_r1791 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_equipment_replacement_planning_r1791 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hel_r1791_founder_all ON public.hospital_equipment_lifecycle_r1791;
CREATE POLICY hel_r1791_founder_all ON public.hospital_equipment_lifecycle_r1791
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS herp_r1791_founder_all ON public.hospital_equipment_replacement_planning_r1791;
CREATE POLICY herp_r1791_founder_all ON public.hospital_equipment_replacement_planning_r1791
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================
-- RPC 1: list_lifecycle
-- =====================================================
DROP FUNCTION IF EXISTS public.r1791_list_lifecycle();
CREATE OR REPLACE FUNCTION public.r1791_list_lifecycle()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_name text,
  manufacturer text,
  install_date date,
  current_stage text,
  expected_end_of_life_date date,
  age_months int,
  total_repairs int,
  total_repair_cost_rupees bigint,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT h.id, h.hospital_user_id, p.email, h.equipment_name, h.manufacturer,
         h.install_date, h.current_stage, h.expected_end_of_life_date,
         h.age_months, h.total_repairs, h.total_repair_cost_rupees, h.created_at
  FROM public.hospital_equipment_lifecycle_r1791 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  ORDER BY h.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1791_list_lifecycle() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1791_list_lifecycle() TO authenticated;

-- =====================================================
-- RPC 2: set_lifecycle
-- =====================================================
DROP FUNCTION IF EXISTS public.r1791_set_lifecycle(uuid, text, text, date, text, date, int, int, bigint);
CREATE OR REPLACE FUNCTION public.r1791_set_lifecycle(
  p_hospital_user_id uuid,
  p_equipment_name text,
  p_manufacturer text,
  p_install_date date,
  p_current_stage text,
  p_expected_eol date,
  p_age_months int,
  p_total_repairs int,
  p_total_repair_cost_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.hospital_equipment_lifecycle_r1791
    (hospital_user_id, equipment_name, manufacturer, install_date, current_stage,
     expected_end_of_life_date, age_months, total_repairs, total_repair_cost_rupees)
  VALUES
    (p_hospital_user_id, p_equipment_name, p_manufacturer, p_install_date,
     COALESCE(p_current_stage, 'installed'), p_expected_eol,
     COALESCE(p_age_months, 0), COALESCE(p_total_repairs, 0),
     COALESCE(p_total_repair_cost_rupees, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1791_set_lifecycle',
          jsonb_build_object('id', v_id, 'equipment', p_equipment_name, 'stage', p_current_stage));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1791_set_lifecycle(uuid, text, text, date, text, date, int, int, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1791_set_lifecycle(uuid, text, text, date, text, date, int, int, bigint) TO authenticated;

-- =====================================================
-- RPC 3: list_planning
-- =====================================================
DROP FUNCTION IF EXISTS public.r1791_list_planning();
CREATE OR REPLACE FUNCTION public.r1791_list_planning()
RETURNS TABLE (
  id uuid,
  lifecycle_id uuid,
  equipment_name text,
  hospital_email text,
  replacement_quote_sent_at timestamptz,
  replacement_decision text,
  decided_at timestamptz,
  decided_by_email text,
  quote_amount_rupees bigint,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT r.id, r.lifecycle_id, h.equipment_name, p.email,
         r.replacement_quote_sent_at, r.replacement_decision,
         r.decided_at, r.decided_by_email, r.quote_amount_rupees, r.created_at
  FROM public.hospital_equipment_replacement_planning_r1791 r
  LEFT JOIN public.hospital_equipment_lifecycle_r1791 h ON h.id = r.lifecycle_id
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  ORDER BY r.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1791_list_planning() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1791_list_planning() TO authenticated;

-- =====================================================
-- RPC 4: log_planning
-- =====================================================
DROP FUNCTION IF EXISTS public.r1791_log_planning(uuid, timestamptz, bigint, text);
CREATE OR REPLACE FUNCTION public.r1791_log_planning(
  p_lifecycle_id uuid,
  p_quote_sent_at timestamptz,
  p_quote_amount_rupees bigint,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.hospital_equipment_replacement_planning_r1791
    (lifecycle_id, replacement_quote_sent_at, quote_amount_rupees, notes)
  VALUES (p_lifecycle_id, COALESCE(p_quote_sent_at, now()), p_quote_amount_rupees, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1791_log_planning',
          jsonb_build_object('id', v_id, 'lifecycle_id', p_lifecycle_id, 'amount', p_quote_amount_rupees));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1791_log_planning(uuid, timestamptz, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1791_log_planning(uuid, timestamptz, bigint, text) TO authenticated;

-- =====================================================
-- RPC 5: mark_decision
-- =====================================================
DROP FUNCTION IF EXISTS public.r1791_mark_decision(uuid, text, text);
CREATE OR REPLACE FUNCTION public.r1791_mark_decision(
  p_planning_id uuid,
  p_decision text,
  p_decided_by_email text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_decision NOT IN ('buy_us','buy_competitor','repair_again','decommission') THEN
    RAISE EXCEPTION 'invalid decision';
  END IF;

  UPDATE public.hospital_equipment_replacement_planning_r1791
  SET replacement_decision = p_decision,
      decided_at = now(),
      decided_by_email = p_decided_by_email,
      updated_at = now()
  WHERE id = p_planning_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1791_mark_decision',
          jsonb_build_object('planning_id', p_planning_id, 'decision', p_decision, 'by', p_decided_by_email));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1791_mark_decision(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1791_mark_decision(uuid, text, text) TO authenticated;

-- =====================================================
-- RPC 6: aging_equipment_summary
-- =====================================================
DROP FUNCTION IF EXISTS public.r1791_aging_equipment_summary();
CREATE OR REPLACE FUNCTION public.r1791_aging_equipment_summary()
RETURNS TABLE (
  stage text,
  unit_count int,
  total_repairs_sum bigint,
  total_cost_rupees_sum bigint,
  avg_age_months numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT h.current_stage,
         (COUNT(*))::int AS unit_count,
         COALESCE(SUM(h.total_repairs), 0)::bigint AS total_repairs_sum,
         COALESCE(SUM(h.total_repair_cost_rupees), 0)::bigint AS total_cost_rupees_sum,
         COALESCE(AVG(h.age_months), 0)::numeric AS avg_age_months
  FROM public.hospital_equipment_lifecycle_r1791 h
  GROUP BY h.current_stage
  ORDER BY h.current_stage;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1791_aging_equipment_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1791_aging_equipment_summary() TO authenticated;

-- =====================================================
-- RPC 7: replacement_opportunities
-- =====================================================
DROP FUNCTION IF EXISTS public.r1791_replacement_opportunities();
CREATE OR REPLACE FUNCTION public.r1791_replacement_opportunities()
RETURNS TABLE (
  lifecycle_id uuid,
  equipment_name text,
  hospital_email text,
  current_stage text,
  age_months int,
  total_repairs int,
  total_repair_cost_rupees bigint,
  expected_end_of_life_date date,
  has_open_planning boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT h.id, h.equipment_name, p.email, h.current_stage,
         h.age_months, h.total_repairs, h.total_repair_cost_rupees,
         h.expected_end_of_life_date,
         EXISTS (
           SELECT 1 FROM public.hospital_equipment_replacement_planning_r1791 r
           WHERE r.lifecycle_id = h.id AND r.replacement_decision IS NULL
         ) AS has_open_planning
  FROM public.hospital_equipment_lifecycle_r1791 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  WHERE h.current_stage IN ('aging','end_of_life')
     OR (h.expected_end_of_life_date IS NOT NULL AND h.expected_end_of_life_date <= (now()::date + INTERVAL '180 days'))
  ORDER BY h.age_months DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1791_replacement_opportunities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1791_replacement_opportunities() TO authenticated;

COMMIT;