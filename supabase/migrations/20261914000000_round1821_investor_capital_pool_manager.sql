BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_capital_pool_entries_r1821 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id),
  instrument_type text NOT NULL CHECK (instrument_type IN ('safe','convertible_note','warrant','loan')),
  principal_amount_rupees bigint NOT NULL CHECK (principal_amount_rupees > 0),
  interest_rate_pct numeric(6,3) NOT NULL DEFAULT 0,
  signed_at timestamptz NOT NULL DEFAULT now(),
  maturity_date date,
  conversion_trigger text NOT NULL CHECK (conversion_trigger IN ('next_round','specific_valuation','timeline','manual')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','converted','matured','cancelled')),
  accrued_interest_rupees bigint NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_capital_pool_events_r1821 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL REFERENCES public.investor_capital_pool_entries_r1821(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('interest_accrual','conversion','maturity_extension','cancellation')),
  event_date timestamptz NOT NULL DEFAULT now(),
  amount_delta_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_capital_pool_entries_r1821 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_capital_pool_events_r1821 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_entries_r1821 ON public.investor_capital_pool_entries_r1821;
CREATE POLICY founder_all_entries_r1821 ON public.investor_capital_pool_entries_r1821
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_events_r1821 ON public.investor_capital_pool_events_r1821;
CREATE POLICY founder_all_events_r1821 ON public.investor_capital_pool_events_r1821
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_pool_entries
CREATE OR REPLACE FUNCTION public.list_pool_entries_r1821()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  instrument_type text,
  principal_amount_rupees bigint,
  interest_rate_pct numeric,
  signed_at timestamptz,
  maturity_date date,
  conversion_trigger text,
  status text,
  accrued_interest_rupees bigint,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.investor_id, p.email::text, e.instrument_type, e.principal_amount_rupees,
           e.interest_rate_pct, e.signed_at, e.maturity_date, e.conversion_trigger,
           e.status, e.accrued_interest_rupees, e.recorded_at
    FROM public.investor_capital_pool_entries_r1821 e
    LEFT JOIN public.profiles p ON p.id = e.investor_id
    ORDER BY e.signed_at DESC
    LIMIT 200;
END;
$$;

-- 2. add_entry
CREATE OR REPLACE FUNCTION public.add_pool_entry_r1821(
  p_investor_id uuid,
  p_instrument_type text,
  p_principal_amount_rupees bigint,
  p_interest_rate_pct numeric,
  p_maturity_date date,
  p_conversion_trigger text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_capital_pool_entries_r1821
    (investor_id, instrument_type, principal_amount_rupees, interest_rate_pct, maturity_date, conversion_trigger)
  VALUES
    (p_investor_id, p_instrument_type, p_principal_amount_rupees, COALESCE(p_interest_rate_pct, 0), p_maturity_date, p_conversion_trigger)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_pool_entry_r1821',
          jsonb_build_object('entry_id', v_id, 'investor_id', p_investor_id, 'principal', p_principal_amount_rupees));
  RETURN v_id;
END;
$$;

-- 3. list_events
CREATE OR REPLACE FUNCTION public.list_pool_events_r1821(p_entry_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  entry_id uuid,
  event_type text,
  event_date timestamptz,
  amount_delta_rupees bigint,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT ev.id, ev.entry_id, ev.event_type, ev.event_date, ev.amount_delta_rupees, ev.notes
    FROM public.investor_capital_pool_events_r1821 ev
    WHERE p_entry_id IS NULL OR ev.entry_id = p_entry_id
    ORDER BY ev.event_date DESC
    LIMIT 300;
END;
$$;

-- 4. log_event
CREATE OR REPLACE FUNCTION public.log_pool_event_r1821(
  p_entry_id uuid,
  p_event_type text,
  p_amount_delta_rupees bigint,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_capital_pool_events_r1821 (entry_id, event_type, amount_delta_rupees, notes)
  VALUES (p_entry_id, p_event_type, COALESCE(p_amount_delta_rupees, 0), p_notes)
  RETURNING id INTO v_id;

  IF p_event_type = 'conversion' THEN
    UPDATE public.investor_capital_pool_entries_r1821 SET status = 'converted', updated_at = now() WHERE id = p_entry_id;
  ELSIF p_event_type = 'cancellation' THEN
    UPDATE public.investor_capital_pool_entries_r1821 SET status = 'cancelled', updated_at = now() WHERE id = p_entry_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pool_event_r1821',
          jsonb_build_object('event_id', v_id, 'entry_id', p_entry_id, 'event_type', p_event_type));
  RETURN v_id;
END;
$$;

-- 5. accrue_interest
CREATE OR REPLACE FUNCTION public.accrue_pool_interest_r1821()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
  v_delta bigint;
  v_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  FOR v_row IN
    SELECT id, principal_amount_rupees, interest_rate_pct
    FROM public.investor_capital_pool_entries_r1821
    WHERE status = 'active' AND interest_rate_pct > 0
  LOOP
    v_delta := floor(v_row.principal_amount_rupees * v_row.interest_rate_pct / 100.0 / 12.0)::bigint;
    UPDATE public.investor_capital_pool_entries_r1821
      SET accrued_interest_rupees = accrued_interest_rupees + v_delta, updated_at = now()
      WHERE id = v_row.id;
    INSERT INTO public.investor_capital_pool_events_r1821 (entry_id, event_type, amount_delta_rupees, notes)
    VALUES (v_row.id, 'interest_accrual', v_delta, 'monthly accrual');
    v_count := v_count + 1;
  END LOOP;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'accrue_pool_interest_r1821',
          jsonb_build_object('updated', v_count));
  RETURN v_count;
END;
$$;

-- 6. total_pool_summary
CREATE OR REPLACE FUNCTION public.total_pool_summary_r1821()
RETURNS TABLE (
  instrument_type text,
  status text,
  entry_count int,
  total_principal_rupees bigint,
  total_accrued_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.instrument_type, e.status,
           COUNT(*)::int,
           COALESCE(SUM(e.principal_amount_rupees), 0)::bigint,
           COALESCE(SUM(e.accrued_interest_rupees), 0)::bigint
    FROM public.investor_capital_pool_entries_r1821 e
    GROUP BY e.instrument_type, e.status
    ORDER BY e.instrument_type, e.status;
END;
$$;

-- 7. conversion_outlook
CREATE OR REPLACE FUNCTION public.conversion_outlook_r1821()
RETURNS TABLE (
  conversion_trigger text,
  active_entries int,
  pending_principal_rupees bigint,
  pending_accrued_rupees bigint,
  next_maturity date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.conversion_trigger,
           (COUNT(*) FILTER (WHERE e.status = 'active'))::int,
           COALESCE(SUM(e.principal_amount_rupees) FILTER (WHERE e.status = 'active'), 0)::bigint,
           COALESCE(SUM(e.accrued_interest_rupees) FILTER (WHERE e.status = 'active'), 0)::bigint,
           MIN(e.maturity_date) FILTER (WHERE e.status = 'active')
    FROM public.investor_capital_pool_entries_r1821 e
    GROUP BY e.conversion_trigger
    ORDER BY e.conversion_trigger;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pool_entries_r1821() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_pool_entry_r1821(uuid, text, bigint, numeric, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_pool_events_r1821(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pool_event_r1821(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.accrue_pool_interest_r1821() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_pool_summary_r1821() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.conversion_outlook_r1821() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pool_entries_r1821() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_pool_entry_r1821(uuid, text, bigint, numeric, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pool_events_r1821(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pool_event_r1821(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accrue_pool_interest_r1821() TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_pool_summary_r1821() TO authenticated;
GRANT EXECUTE ON FUNCTION public.conversion_outlook_r1821() TO authenticated;

COMMIT;