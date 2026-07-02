BEGIN;

-- ============================================================
-- r1681: Investor Comms Cadence Tracker
-- Tracks promised vs actual investor comms cadence.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_comms_commitments_r1681 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  commitment_type text NOT NULL CHECK (commitment_type IN ('monthly_update','quarterly_call','annual_letter','ad_hoc')),
  frequency_days int NOT NULL CHECK (frequency_days > 0),
  last_promised_at timestamptz,
  next_due_at timestamptz,
  notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_comms_deliveries_r1681 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commitment_id uuid NOT NULL REFERENCES public.investor_comms_commitments_r1681(id) ON DELETE CASCADE,
  delivered_at timestamptz NOT NULL DEFAULT now(),
  delivery_channel text NOT NULL CHECK (delivery_channel IN ('email','call','in_person','letter','portal','other')),
  summary text,
  on_time boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iccc_r1681_investor ON public.investor_comms_commitments_r1681(investor_id);
CREATE INDEX IF NOT EXISTS idx_iccc_r1681_next_due ON public.investor_comms_commitments_r1681(next_due_at);
CREATE INDEX IF NOT EXISTS idx_iccd_r1681_commitment ON public.investor_comms_deliveries_r1681(commitment_id);
CREATE INDEX IF NOT EXISTS idx_iccd_r1681_delivered ON public.investor_comms_deliveries_r1681(delivered_at DESC);

ALTER TABLE public.investor_comms_commitments_r1681 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_comms_deliveries_r1681 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_iccc_r1681_founder_all ON public.investor_comms_commitments_r1681;
CREATE POLICY p_iccc_r1681_founder_all ON public.investor_comms_commitments_r1681
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_iccd_r1681_founder_all ON public.investor_comms_deliveries_r1681;
CREATE POLICY p_iccd_r1681_founder_all ON public.investor_comms_deliveries_r1681
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

-- 1. list_commitments
CREATE OR REPLACE FUNCTION public.list_commitments_r1681()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  commitment_type text,
  frequency_days int,
  last_promised_at timestamptz,
  next_due_at timestamptz,
  active boolean,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.investor_id, p.email::text AS investor_email,
           c.commitment_type, c.frequency_days, c.last_promised_at,
           c.next_due_at, c.active, c.notes, c.created_at
    FROM public.investor_comms_commitments_r1681 c
    LEFT JOIN public.profiles p ON p.id = c.investor_id
    ORDER BY c.next_due_at NULLS LAST, c.created_at DESC;
END;
$$;

-- 2. add_commitment
CREATE OR REPLACE FUNCTION public.add_commitment_r1681(
  p_investor_id uuid,
  p_commitment_type text,
  p_frequency_days int,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_next timestamptz;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_next := now() + (p_frequency_days || ' days')::interval;
  INSERT INTO public.investor_comms_commitments_r1681(
    investor_id, commitment_type, frequency_days, last_promised_at, next_due_at, notes
  ) VALUES (
    p_investor_id, p_commitment_type, p_frequency_days, now(), v_next, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1681_add_commitment',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'commitment_type', p_commitment_type, 'frequency_days', p_frequency_days));
  RETURN v_id;
END;
$$;

-- 3. list_deliveries
CREATE OR REPLACE FUNCTION public.list_deliveries_r1681(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  commitment_id uuid,
  investor_email text,
  commitment_type text,
  delivered_at timestamptz,
  delivery_channel text,
  summary text,
  on_time boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.commitment_id, p.email::text AS investor_email,
           c.commitment_type, d.delivered_at, d.delivery_channel, d.summary, d.on_time
    FROM public.investor_comms_deliveries_r1681 d
    JOIN public.investor_comms_commitments_r1681 c ON c.id = d.commitment_id
    LEFT JOIN public.profiles p ON p.id = c.investor_id
    ORDER BY d.delivered_at DESC
    LIMIT p_limit;
END;
$$;

-- 4. record_delivery
CREATE OR REPLACE FUNCTION public.record_delivery_r1681(
  p_commitment_id uuid,
  p_delivery_channel text,
  p_summary text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_next_due timestamptz;
  v_on_time boolean;
  v_freq int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT next_due_at, frequency_days INTO v_next_due, v_freq
  FROM public.investor_comms_commitments_r1681 WHERE id = p_commitment_id;

  v_on_time := (v_next_due IS NULL OR now() <= v_next_due);

  INSERT INTO public.investor_comms_deliveries_r1681(commitment_id, delivery_channel, summary, on_time)
  VALUES (p_commitment_id, p_delivery_channel, p_summary, v_on_time)
  RETURNING id INTO v_id;

  UPDATE public.investor_comms_commitments_r1681
  SET last_promised_at = now(),
      next_due_at = now() + (v_freq || ' days')::interval,
      updated_at = now()
  WHERE id = p_commitment_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1681_record_delivery',
    jsonb_build_object('id', v_id, 'commitment_id', p_commitment_id, 'on_time', v_on_time));
  RETURN v_id;
END;
$$;

-- 5. overdue_commitments
CREATE OR REPLACE FUNCTION public.overdue_commitments_r1681()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  commitment_type text,
  next_due_at timestamptz,
  days_overdue int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.investor_id, p.email::text AS investor_email,
           c.commitment_type, c.next_due_at,
           GREATEST(0, EXTRACT(DAY FROM (now() - c.next_due_at))::int) AS days_overdue
    FROM public.investor_comms_commitments_r1681 c
    LEFT JOIN public.profiles p ON p.id = c.investor_id
    WHERE c.active = true AND c.next_due_at IS NOT NULL AND c.next_due_at < now()
    ORDER BY c.next_due_at ASC;
END;
$$;

-- 6. on_time_pct
CREATE OR REPLACE FUNCTION public.on_time_pct_r1681()
RETURNS TABLE(
  total_deliveries int,
  on_time_count int,
  on_time_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::int AS total_deliveries,
           (COUNT(*) FILTER (WHERE d.on_time = true))::int AS on_time_count,
           CASE WHEN COUNT(*) = 0 THEN 0::numeric
                ELSE ROUND(100.0 * (COUNT(*) FILTER (WHERE d.on_time = true))::numeric / COUNT(*)::numeric, 2)
           END AS on_time_pct
    FROM public.investor_comms_deliveries_r1681 d;
END;
$$;

-- 7. per_investor_cadence_summary
CREATE OR REPLACE FUNCTION public.per_investor_cadence_summary_r1681()
RETURNS TABLE(
  investor_id uuid,
  investor_email text,
  commitments_count int,
  deliveries_count int,
  on_time_count int,
  on_time_pct numeric,
  overdue_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.investor_id,
           MAX(p.email)::text AS investor_email,
           COUNT(DISTINCT c.id)::int AS commitments_count,
           COUNT(d.id)::int AS deliveries_count,
           (COUNT(*) FILTER (WHERE d.on_time = true))::int AS on_time_count,
           CASE WHEN COUNT(d.id) = 0 THEN 0::numeric
                ELSE ROUND(100.0 * (COUNT(*) FILTER (WHERE d.on_time = true))::numeric / COUNT(d.id)::numeric, 2)
           END AS on_time_pct,
           (COUNT(DISTINCT c.id) FILTER (WHERE c.active = true AND c.next_due_at IS NOT NULL AND c.next_due_at < now()))::int AS overdue_count
    FROM public.investor_comms_commitments_r1681 c
    LEFT JOIN public.investor_comms_deliveries_r1681 d ON d.commitment_id = c.id
    LEFT JOIN public.profiles p ON p.id = c.investor_id
    GROUP BY c.investor_id
    ORDER BY overdue_count DESC, on_time_pct ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_commitments_r1681() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_commitment_r1681(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_deliveries_r1681(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_delivery_r1681(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_commitments_r1681() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.on_time_pct_r1681() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.per_investor_cadence_summary_r1681() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_commitments_r1681() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_commitment_r1681(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_deliveries_r1681(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_delivery_r1681(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_commitments_r1681() TO authenticated;
GRANT EXECUTE ON FUNCTION public.on_time_pct_r1681() TO authenticated;
GRANT EXECUTE ON FUNCTION public.per_investor_cadence_summary_r1681() TO authenticated;

COMMIT;