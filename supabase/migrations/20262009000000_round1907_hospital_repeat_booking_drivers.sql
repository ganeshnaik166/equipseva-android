BEGIN;

-- ============================================================
-- r1907 — Hospital Repeat Booking Drivers
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_repeat_booking_drivers_r1907 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  driver_category text NOT NULL CHECK (driver_category IN ('engineer_quality','price','turnaround','parts_availability','relationship','other')),
  weight int NOT NULL CHECK (weight BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','declining','strong')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrbd_r1907_hospital ON public.hospital_repeat_booking_drivers_r1907(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hrbd_r1907_status ON public.hospital_repeat_booking_drivers_r1907(status);

CREATE TABLE IF NOT EXISTS public.hospital_repeat_booking_log_r1907 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.hospital_repeat_booking_drivers_r1907(id) ON DELETE CASCADE,
  booking_id uuid,
  repeat_score int NOT NULL CHECK (repeat_score BETWEEN 0 AND 100),
  note_md text,
  logged_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrbl_r1907_driver ON public.hospital_repeat_booking_log_r1907(driver_id);
CREATE INDEX IF NOT EXISTS idx_hrbl_r1907_logged_at ON public.hospital_repeat_booking_log_r1907(logged_at DESC);

ALTER TABLE public.hospital_repeat_booking_drivers_r1907 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_repeat_booking_log_r1907 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hrbd_r1907_founder_all ON public.hospital_repeat_booking_drivers_r1907;
CREATE POLICY hrbd_r1907_founder_all ON public.hospital_repeat_booking_drivers_r1907
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hrbl_r1907_founder_all ON public.hospital_repeat_booking_log_r1907;
CREATE POLICY hrbl_r1907_founder_all ON public.hospital_repeat_booking_log_r1907
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_drivers_r1907()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  driver_category text,
  weight int,
  status text,
  captured_at timestamptz
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
    SELECT d.id, d.hospital_id, p.email::text, d.driver_category, d.weight, d.status, d.captured_at
    FROM public.hospital_repeat_booking_drivers_r1907 d
    LEFT JOIN public.profiles p ON p.id = d.hospital_id
    ORDER BY d.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_driver_r1907(
  p_hospital_id uuid,
  p_driver_category text,
  p_weight int,
  p_status text
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
  INSERT INTO public.hospital_repeat_booking_drivers_r1907(hospital_id, driver_category, weight, status)
  VALUES (p_hospital_id, p_driver_category, p_weight, COALESCE(p_status,'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_driver_r1907',
    jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'driver_category', p_driver_category, 'weight', p_weight, 'status', p_status));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_logs_r1907()
RETURNS TABLE (
  id uuid,
  driver_id uuid,
  driver_category text,
  booking_id uuid,
  repeat_score int,
  note_md text,
  logged_at timestamptz
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
    SELECT l.id, l.driver_id, d.driver_category, l.booking_id, l.repeat_score, l.note_md, l.logged_at
    FROM public.hospital_repeat_booking_log_r1907 l
    LEFT JOIN public.hospital_repeat_booking_drivers_r1907 d ON d.id = l.driver_id
    ORDER BY l.logged_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_booking_r1907(
  p_driver_id uuid,
  p_booking_id uuid,
  p_repeat_score int,
  p_note_md text
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
  INSERT INTO public.hospital_repeat_booking_log_r1907(driver_id, booking_id, repeat_score, note_md)
  VALUES (p_driver_id, p_booking_id, p_repeat_score, p_note_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_booking_r1907',
    jsonb_build_object('id', v_id, 'driver_id', p_driver_id, 'booking_id', p_booking_id, 'repeat_score', p_repeat_score));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_driver_status_r1907(
  p_driver_id uuid,
  p_status text
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
  UPDATE public.hospital_repeat_booking_drivers_r1907
    SET status = p_status, updated_at = now()
  WHERE id = p_driver_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_driver_status_r1907',
    jsonb_build_object('driver_id', p_driver_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_drivers_r1907()
RETURNS TABLE (
  driver_category text,
  total_count int,
  avg_weight numeric,
  strong_count int
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
    SELECT d.driver_category,
      (COUNT(*))::int AS total_count,
      ROUND(AVG(d.weight)::numeric, 2) AS avg_weight,
      (COUNT(*) FILTER (WHERE d.status = 'strong'))::int AS strong_count
    FROM public.hospital_repeat_booking_drivers_r1907 d
    GROUP BY d.driver_category
    ORDER BY total_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_logs_r1907()
RETURNS TABLE (
  id uuid,
  driver_id uuid,
  driver_category text,
  repeat_score int,
  note_md text,
  logged_at timestamptz
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
    SELECT l.id, l.driver_id, d.driver_category, l.repeat_score, l.note_md, l.logged_at
    FROM public.hospital_repeat_booking_log_r1907 l
    LEFT JOIN public.hospital_repeat_booking_drivers_r1907 d ON d.id = l.driver_id
    WHERE l.logged_at > now() - interval '30 days'
    ORDER BY l.logged_at DESC
    LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_drivers_r1907() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_driver_r1907(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_logs_r1907() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_booking_r1907(uuid, uuid, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_driver_status_r1907(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_drivers_r1907() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_logs_r1907() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_drivers_r1907() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_driver_r1907(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_logs_r1907() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_booking_r1907(uuid, uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_driver_status_r1907(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_drivers_r1907() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_logs_r1907() TO authenticated;

COMMIT;
