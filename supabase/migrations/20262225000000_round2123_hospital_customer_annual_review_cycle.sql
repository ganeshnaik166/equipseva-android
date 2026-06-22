BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_annual_review_cycle_r2123 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  review_year int NOT NULL,
  review_date date NOT NULL,
  satisfaction_score int CHECK (satisfaction_score BETWEEN 0 AND 100),
  key_themes_md text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','escalated','cancelled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcarcr2123_hospital ON public.hospital_customer_annual_review_cycle_r2123(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hcarcr2123_year ON public.hospital_customer_annual_review_cycle_r2123(review_year);
CREATE INDEX IF NOT EXISTS idx_hcarcr2123_status ON public.hospital_customer_annual_review_cycle_r2123(status);

ALTER TABLE public.hospital_customer_annual_review_cycle_r2123 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcarcr2123_founder_all ON public.hospital_customer_annual_review_cycle_r2123;
CREATE POLICY hcarcr2123_founder_all ON public.hospital_customer_annual_review_cycle_r2123
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_review_action_log_r2123 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.hospital_customer_annual_review_cycle_r2123(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('scheduled','completed','escalated','closed','cancelled')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hralr2123_review ON public.hospital_review_action_log_r2123(review_id);
CREATE INDEX IF NOT EXISTS idx_hralr2123_type ON public.hospital_review_action_log_r2123(action_type);

ALTER TABLE public.hospital_review_action_log_r2123 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hralr2123_founder_all ON public.hospital_review_action_log_r2123;
CREATE POLICY hralr2123_founder_all ON public.hospital_review_action_log_r2123
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_reviews
CREATE OR REPLACE FUNCTION public.list_reviews_r2123()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  review_year int,
  review_date date,
  satisfaction_score int,
  key_themes_md text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_id, p.email, r.review_year, r.review_date,
         r.satisfaction_score, r.key_themes_md, r.status, r.captured_at
  FROM public.hospital_customer_annual_review_cycle_r2123 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_id
  ORDER BY r.review_date DESC NULLS LAST, r.captured_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log_review
CREATE OR REPLACE FUNCTION public.log_review_r2123(
  p_hospital_id uuid,
  p_review_year int,
  p_review_date date,
  p_satisfaction_score int,
  p_key_themes_md text,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_annual_review_cycle_r2123(
    hospital_id, review_year, review_date, satisfaction_score, key_themes_md, status
  ) VALUES (p_hospital_id, p_review_year, p_review_date, p_satisfaction_score, p_key_themes_md, COALESCE(p_status,'scheduled'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_review_r2123',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'review_year', p_review_year), now());
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2123(p_review_id uuid)
RETURNS TABLE (
  id uuid,
  review_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.review_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_review_action_log_r2123 a
  WHERE a.review_id = p_review_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r2123(
  p_review_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_review_action_log_r2123(review_id, action_type, by_email, notes_md)
  VALUES (p_review_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2123',
          jsonb_build_object('id', v_id, 'review_id', p_review_id, 'action_type', p_action_type), now());
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2123(p_review_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_annual_review_cycle_r2123
  SET status = p_status, updated_at = now()
  WHERE id = p_review_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2123',
          jsonb_build_object('review_id', p_review_id, 'status', p_status), now());
END;
$$;

-- RPC 6: upcoming
CREATE OR REPLACE FUNCTION public.upcoming_r2123()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  review_year int,
  review_date date,
  status text,
  days_until int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_id, p.email, r.review_year, r.review_date, r.status,
         (r.review_date - CURRENT_DATE)::int AS days_until
  FROM public.hospital_customer_annual_review_cycle_r2123 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_id
  WHERE r.status IN ('scheduled','in_progress')
    AND r.review_date >= CURRENT_DATE
  ORDER BY r.review_date ASC
  LIMIT 100;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2123()
RETURNS TABLE (
  id uuid,
  review_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.review_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_review_action_log_r2123 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reviews_r2123() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_review_r2123(uuid, int, date, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2123(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2123(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2123(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_r2123() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2123() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reviews_r2123() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_review_r2123(uuid, int, date, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2123(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2123(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2123(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_r2123() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2123() TO authenticated;

COMMIT;
