BEGIN;

-- =========================================================================
-- Round 1693 — Investor Vesting Schedule
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.investor_vesting_schedules_r1693 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  instrument_type text NOT NULL CHECK (instrument_type IN ('option','warrant','safe')),
  total_shares bigint NOT NULL CHECK (total_shares > 0),
  vest_start date NOT NULL,
  cliff_months int NOT NULL DEFAULT 12 CHECK (cliff_months >= 0),
  total_months int NOT NULL DEFAULT 48 CHECK (total_months > 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','completed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ivs_r1693_investor
  ON public.investor_vesting_schedules_r1693(investor_id);
CREATE INDEX IF NOT EXISTS idx_ivs_r1693_status
  ON public.investor_vesting_schedules_r1693(status);

ALTER TABLE public.investor_vesting_schedules_r1693 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ivs_r1693_founder_all ON public.investor_vesting_schedules_r1693;
CREATE POLICY ivs_r1693_founder_all
  ON public.investor_vesting_schedules_r1693
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.investor_vesting_tranches_r1693 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid NOT NULL REFERENCES public.investor_vesting_schedules_r1693(id) ON DELETE CASCADE,
  tranche_month date NOT NULL,
  shares_vested bigint NOT NULL DEFAULT 0,
  cumulative_vested bigint NOT NULL DEFAULT 0,
  exercised boolean NOT NULL DEFAULT false,
  exercised_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (schedule_id, tranche_month)
);

CREATE INDEX IF NOT EXISTS idx_ivt_r1693_schedule
  ON public.investor_vesting_tranches_r1693(schedule_id);
CREATE INDEX IF NOT EXISTS idx_ivt_r1693_month
  ON public.investor_vesting_tranches_r1693(tranche_month);

ALTER TABLE public.investor_vesting_tranches_r1693 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ivt_r1693_founder_all ON public.investor_vesting_tranches_r1693;
CREATE POLICY ivt_r1693_founder_all
  ON public.investor_vesting_tranches_r1693
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_schedules
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1693_list_schedules();
CREATE OR REPLACE FUNCTION public.r1693_list_schedules()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  instrument_type text,
  total_shares bigint,
  vest_start date,
  cliff_months int,
  total_months int,
  status text,
  tranche_count int,
  cumulative_vested bigint,
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
  SELECT
    s.id,
    s.investor_id,
    p.email::text AS investor_email,
    s.instrument_type,
    s.total_shares,
    s.vest_start,
    s.cliff_months,
    s.total_months,
    s.status,
    (SELECT (COUNT(*))::int FROM public.investor_vesting_tranches_r1693 t WHERE t.schedule_id = s.id) AS tranche_count,
    COALESCE((SELECT MAX(t.cumulative_vested) FROM public.investor_vesting_tranches_r1693 t WHERE t.schedule_id = s.id), 0) AS cumulative_vested,
    s.created_at
  FROM public.investor_vesting_schedules_r1693 s
  LEFT JOIN public.profiles p ON p.id = s.investor_id
  ORDER BY s.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1693_list_schedules() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1693_list_schedules() TO authenticated;

-- =========================================================================
-- RPC 2: add_schedule
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1693_add_schedule(uuid, text, bigint, date, int, int, text);
CREATE OR REPLACE FUNCTION public.r1693_add_schedule(
  p_investor_id uuid,
  p_instrument_type text,
  p_total_shares bigint,
  p_vest_start date,
  p_cliff_months int,
  p_total_months int,
  p_notes text DEFAULT NULL
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

  INSERT INTO public.investor_vesting_schedules_r1693(
    investor_id, instrument_type, total_shares, vest_start, cliff_months, total_months, notes
  ) VALUES (
    p_investor_id, p_instrument_type, p_total_shares, p_vest_start, p_cliff_months, p_total_months, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1693_add_schedule',
    jsonb_build_object(
      'schedule_id', v_id,
      'investor_id', p_investor_id,
      'instrument_type', p_instrument_type,
      'total_shares', p_total_shares
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1693_add_schedule(uuid, text, bigint, date, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1693_add_schedule(uuid, text, bigint, date, int, int, text) TO authenticated;

-- =========================================================================
-- RPC 3: list_tranches
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1693_list_tranches(uuid);
CREATE OR REPLACE FUNCTION public.r1693_list_tranches(p_schedule_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  schedule_id uuid,
  investor_email text,
  instrument_type text,
  tranche_month date,
  shares_vested bigint,
  cumulative_vested bigint,
  exercised boolean,
  exercised_at timestamptz
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
  SELECT
    t.id,
    t.schedule_id,
    p.email::text AS investor_email,
    s.instrument_type,
    t.tranche_month,
    t.shares_vested,
    t.cumulative_vested,
    t.exercised,
    t.exercised_at
  FROM public.investor_vesting_tranches_r1693 t
  JOIN public.investor_vesting_schedules_r1693 s ON s.id = t.schedule_id
  LEFT JOIN public.profiles p ON p.id = s.investor_id
  WHERE (p_schedule_id IS NULL OR t.schedule_id = p_schedule_id)
  ORDER BY t.tranche_month ASC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1693_list_tranches(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1693_list_tranches(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: generate_tranches
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1693_generate_tranches(uuid);
CREATE OR REPLACE FUNCTION public.r1693_generate_tranches(p_schedule_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_schedule public.investor_vesting_schedules_r1693%ROWTYPE;
  v_month int;
  v_per_month bigint;
  v_remainder bigint;
  v_cum bigint := 0;
  v_count int := 0;
  v_tranche_date date;
  v_shares bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_schedule FROM public.investor_vesting_schedules_r1693 WHERE id = p_schedule_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'schedule not found';
  END IF;

  DELETE FROM public.investor_vesting_tranches_r1693 WHERE schedule_id = p_schedule_id;

  v_per_month := v_schedule.total_shares / v_schedule.total_months;
  v_remainder := v_schedule.total_shares - (v_per_month * v_schedule.total_months);

  FOR v_month IN 1..v_schedule.total_months LOOP
    v_tranche_date := (v_schedule.vest_start + (v_month || ' months')::interval)::date;

    IF v_month < v_schedule.cliff_months THEN
      v_shares := 0;
    ELSIF v_month = v_schedule.cliff_months THEN
      v_shares := v_per_month * v_schedule.cliff_months;
    ELSE
      v_shares := v_per_month;
    END IF;

    IF v_month = v_schedule.total_months THEN
      v_shares := v_shares + v_remainder;
    END IF;

    v_cum := v_cum + v_shares;

    INSERT INTO public.investor_vesting_tranches_r1693(
      schedule_id, tranche_month, shares_vested, cumulative_vested
    ) VALUES (
      p_schedule_id, v_tranche_date, v_shares, v_cum
    );

    v_count := v_count + 1;
  END LOOP;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1693_generate_tranches',
    jsonb_build_object('schedule_id', p_schedule_id, 'tranches_created', v_count)
  );

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1693_generate_tranches(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1693_generate_tranches(uuid) TO authenticated;

-- =========================================================================
-- RPC 5: mark_exercised
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1693_mark_exercised(uuid);
CREATE OR REPLACE FUNCTION public.r1693_mark_exercised(p_tranche_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.investor_vesting_tranches_r1693
  SET exercised = true,
      exercised_at = now(),
      updated_at = now()
  WHERE id = p_tranche_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'tranche not found';
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1693_mark_exercised',
    jsonb_build_object('tranche_id', p_tranche_id)
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1693_mark_exercised(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1693_mark_exercised(uuid) TO authenticated;

-- =========================================================================
-- RPC 6: vesting_summary
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1693_vesting_summary();
CREATE OR REPLACE FUNCTION public.r1693_vesting_summary()
RETURNS TABLE (
  total_schedules int,
  active_schedules int,
  paused_schedules int,
  completed_schedules int,
  total_shares_committed bigint,
  total_shares_vested bigint,
  total_shares_exercised bigint,
  total_tranches int,
  exercised_tranches int
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
  SELECT
    (SELECT (COUNT(*))::int FROM public.investor_vesting_schedules_r1693) AS total_schedules,
    (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.investor_vesting_schedules_r1693) AS active_schedules,
    (SELECT (COUNT(*) FILTER (WHERE status = 'paused'))::int FROM public.investor_vesting_schedules_r1693) AS paused_schedules,
    (SELECT (COUNT(*) FILTER (WHERE status = 'completed'))::int FROM public.investor_vesting_schedules_r1693) AS completed_schedules,
    COALESCE((SELECT SUM(total_shares) FROM public.investor_vesting_schedules_r1693), 0) AS total_shares_committed,
    COALESCE((SELECT SUM(shares_vested) FROM public.investor_vesting_tranches_r1693 WHERE tranche_month <= CURRENT_DATE), 0) AS total_shares_vested,
    COALESCE((SELECT SUM(shares_vested) FROM public.investor_vesting_tranches_r1693 WHERE exercised = true), 0) AS total_shares_exercised,
    (SELECT (COUNT(*))::int FROM public.investor_vesting_tranches_r1693) AS total_tranches,
    (SELECT (COUNT(*) FILTER (WHERE exercised = true))::int FROM public.investor_vesting_tranches_r1693) AS exercised_tranches;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1693_vesting_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1693_vesting_summary() TO authenticated;

-- =========================================================================
-- RPC 7: upcoming_vests
-- =========================================================================
DROP FUNCTION IF EXISTS public.r1693_upcoming_vests(int);
CREATE OR REPLACE FUNCTION public.r1693_upcoming_vests(p_days int DEFAULT 90)
RETURNS TABLE (
  tranche_id uuid,
  schedule_id uuid,
  investor_email text,
  instrument_type text,
  tranche_month date,
  shares_vested bigint,
  cumulative_vested bigint,
  days_until int
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
  SELECT
    t.id AS tranche_id,
    t.schedule_id,
    p.email::text AS investor_email,
    s.instrument_type,
    t.tranche_month,
    t.shares_vested,
    t.cumulative_vested,
    (t.tranche_month - CURRENT_DATE)::int AS days_until
  FROM public.investor_vesting_tranches_r1693 t
  JOIN public.investor_vesting_schedules_r1693 s ON s.id = t.schedule_id
  LEFT JOIN public.profiles p ON p.id = s.investor_id
  WHERE t.tranche_month >= CURRENT_DATE
    AND t.tranche_month <= (CURRENT_DATE + (p_days || ' days')::interval)::date
    AND t.shares_vested > 0
    AND t.exercised = false
  ORDER BY t.tranche_month ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1693_upcoming_vests(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1693_upcoming_vests(int) TO authenticated;

COMMIT;