BEGIN;

-- Engineer Hourly Rate Card
CREATE TABLE IF NOT EXISTS public.engineer_hourly_rate_card_r1852 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role_level text NOT NULL CHECK (role_level IN ('trainee','junior','senior','lead','principal')),
  billable_rate_rupees_per_hour int NOT NULL CHECK (billable_rate_rupees_per_hour >= 0),
  cost_rate_rupees_per_hour int NOT NULL CHECK (cost_rate_rupees_per_hour >= 0),
  effective_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_hourly_rate_card_r1852_engineer ON public.engineer_hourly_rate_card_r1852(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_hourly_rate_card_r1852_status ON public.engineer_hourly_rate_card_r1852(status);
CREATE INDEX IF NOT EXISTS idx_engineer_hourly_rate_card_r1852_effective ON public.engineer_hourly_rate_card_r1852(effective_date DESC);

ALTER TABLE public.engineer_hourly_rate_card_r1852 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_engineer_hourly_rate_card_r1852 ON public.engineer_hourly_rate_card_r1852;
CREATE POLICY founder_all_engineer_hourly_rate_card_r1852 ON public.engineer_hourly_rate_card_r1852
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_rate_card_change_log_r1852 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rate_id uuid NOT NULL REFERENCES public.engineer_hourly_rate_card_r1852(id) ON DELETE CASCADE,
  old_billable_rupees int,
  new_billable_rupees int,
  change_reason text,
  changed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_rate_card_change_log_r1852_rate ON public.engineer_rate_card_change_log_r1852(rate_id);
CREATE INDEX IF NOT EXISTS idx_engineer_rate_card_change_log_r1852_changed ON public.engineer_rate_card_change_log_r1852(changed_at DESC);

ALTER TABLE public.engineer_rate_card_change_log_r1852 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_engineer_rate_card_change_log_r1852 ON public.engineer_rate_card_change_log_r1852;
CREATE POLICY founder_all_engineer_rate_card_change_log_r1852 ON public.engineer_rate_card_change_log_r1852
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_rates
CREATE OR REPLACE FUNCTION public.list_rates_r1852(p_status text DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  role_level text,
  billable_rate_rupees_per_hour int,
  cost_rate_rupees_per_hour int,
  margin_rupees_per_hour int,
  effective_date date,
  status text,
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
  SELECT r.id,
         r.engineer_user_id,
         p.email::text,
         r.role_level,
         r.billable_rate_rupees_per_hour,
         r.cost_rate_rupees_per_hour,
         (r.billable_rate_rupees_per_hour - r.cost_rate_rupees_per_hour) AS margin_rupees_per_hour,
         r.effective_date,
         r.status,
         r.created_at
    FROM public.engineer_hourly_rate_card_r1852 r
    LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
   WHERE (p_status IS NULL OR r.status = p_status)
   ORDER BY r.effective_date DESC, r.created_at DESC
   LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_rates_r1852(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_rates_r1852(text) TO authenticated;

-- RPC 2: set_rate
CREATE OR REPLACE FUNCTION public.set_rate_r1852(
  p_engineer_user_id uuid,
  p_role_level text,
  p_billable_rate int,
  p_cost_rate int,
  p_effective_date date DEFAULT CURRENT_DATE
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_hourly_rate_card_r1852
     SET status = 'superseded', updated_at = now()
   WHERE engineer_user_id = p_engineer_user_id AND status = 'current';

  INSERT INTO public.engineer_hourly_rate_card_r1852(
    engineer_user_id, role_level, billable_rate_rupees_per_hour,
    cost_rate_rupees_per_hour, effective_date, status
  )
  VALUES (p_engineer_user_id, p_role_level, p_billable_rate, p_cost_rate, p_effective_date, 'current')
  RETURNING id INTO v_new_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_rate_r1852',
          jsonb_build_object('rate_id', v_new_id, 'engineer_user_id', p_engineer_user_id,
                             'billable', p_billable_rate, 'cost', p_cost_rate));

  RETURN v_new_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_rate_r1852(uuid, text, int, int, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_rate_r1852(uuid, text, int, int, date) TO authenticated;

-- RPC 3: list_changes
CREATE OR REPLACE FUNCTION public.list_changes_r1852(p_rate_id uuid DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  rate_id uuid,
  engineer_email text,
  old_billable_rupees int,
  new_billable_rupees int,
  delta_rupees int,
  change_reason text,
  changed_at timestamptz
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
  SELECT c.id,
         c.rate_id,
         p.email::text,
         c.old_billable_rupees,
         c.new_billable_rupees,
         (COALESCE(c.new_billable_rupees,0) - COALESCE(c.old_billable_rupees,0)) AS delta_rupees,
         c.change_reason,
         c.changed_at
    FROM public.engineer_rate_card_change_log_r1852 c
    LEFT JOIN public.engineer_hourly_rate_card_r1852 r ON r.id = c.rate_id
    LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
   WHERE (p_rate_id IS NULL OR c.rate_id = p_rate_id)
   ORDER BY c.changed_at DESC
   LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_changes_r1852(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_changes_r1852(uuid) TO authenticated;

-- RPC 4: log_change
CREATE OR REPLACE FUNCTION public.log_change_r1852(
  p_rate_id uuid,
  p_old_billable int,
  p_new_billable int,
  p_change_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_rate_card_change_log_r1852(
    rate_id, old_billable_rupees, new_billable_rupees, change_reason
  )
  VALUES (p_rate_id, p_old_billable, p_new_billable, p_change_reason)
  RETURNING id INTO v_new_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_change_r1852',
          jsonb_build_object('change_id', v_new_id, 'rate_id', p_rate_id,
                             'old', p_old_billable, 'new', p_new_billable));

  RETURN v_new_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_change_r1852(uuid, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_change_r1852(uuid, int, int, text) TO authenticated;

-- RPC 5: top_billable_engineers
CREATE OR REPLACE FUNCTION public.top_billable_engineers_r1852()
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  role_level text,
  billable_rate_rupees_per_hour int,
  cost_rate_rupees_per_hour int,
  margin_rupees_per_hour int
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
  SELECT r.engineer_user_id,
         p.email::text,
         r.role_level,
         r.billable_rate_rupees_per_hour,
         r.cost_rate_rupees_per_hour,
         (r.billable_rate_rupees_per_hour - r.cost_rate_rupees_per_hour) AS margin_rupees_per_hour
    FROM public.engineer_hourly_rate_card_r1852 r
    LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
   WHERE r.status = 'current'
   ORDER BY r.billable_rate_rupees_per_hour DESC
   LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_billable_engineers_r1852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_billable_engineers_r1852() TO authenticated;

-- RPC 6: rate_margin_summary
CREATE OR REPLACE FUNCTION public.rate_margin_summary_r1852()
RETURNS TABLE(
  role_level text,
  engineer_count int,
  avg_billable_rupees int,
  avg_cost_rupees int,
  avg_margin_rupees int,
  margin_pct numeric
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
  SELECT r.role_level,
         (COUNT(*))::int AS engineer_count,
         (AVG(r.billable_rate_rupees_per_hour))::int AS avg_billable_rupees,
         (AVG(r.cost_rate_rupees_per_hour))::int AS avg_cost_rupees,
         (AVG(r.billable_rate_rupees_per_hour - r.cost_rate_rupees_per_hour))::int AS avg_margin_rupees,
         CASE WHEN AVG(r.billable_rate_rupees_per_hour) > 0
              THEN ROUND((AVG(r.billable_rate_rupees_per_hour - r.cost_rate_rupees_per_hour) / AVG(r.billable_rate_rupees_per_hour) * 100)::numeric, 2)
              ELSE 0 END AS margin_pct
    FROM public.engineer_hourly_rate_card_r1852 r
   WHERE r.status = 'current'
   GROUP BY r.role_level
   ORDER BY avg_billable_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rate_margin_summary_r1852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rate_margin_summary_r1852() TO authenticated;

-- RPC 7: recent_rate_changes
CREATE OR REPLACE FUNCTION public.recent_rate_changes_r1852()
RETURNS TABLE(
  id uuid,
  engineer_email text,
  old_billable_rupees int,
  new_billable_rupees int,
  delta_rupees int,
  change_reason text,
  changed_at timestamptz
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
  SELECT c.id,
         p.email::text,
         c.old_billable_rupees,
         c.new_billable_rupees,
         (COALESCE(c.new_billable_rupees,0) - COALESCE(c.old_billable_rupees,0)) AS delta_rupees,
         c.change_reason,
         c.changed_at
    FROM public.engineer_rate_card_change_log_r1852 c
    LEFT JOIN public.engineer_hourly_rate_card_r1852 r ON r.id = c.rate_id
    LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
   WHERE c.changed_at >= now() - interval '30 days'
   ORDER BY c.changed_at DESC
   LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_rate_changes_r1852() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_rate_changes_r1852() TO authenticated;

COMMIT;