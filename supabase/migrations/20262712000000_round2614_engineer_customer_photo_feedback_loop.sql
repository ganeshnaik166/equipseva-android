-- r2614 engineer-customer-photo-feedback-loop

CREATE TABLE IF NOT EXISTS public.engineer_photo_feedback_r2614 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  photo_at timestamptz NOT NULL DEFAULT now(),
  photo_url text NOT NULL,
  customer_feedback_kind text NOT NULL CHECK (customer_feedback_kind IN ('praise','concern','none','needs_redo')),
  engineer_response_md text,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','escalated')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.photo_redo_actions_r2614 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id uuid NOT NULL REFERENCES public.engineer_photo_feedback_r2614(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('reshoot','redact','retake_signoff')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_photo_feedback_r2614 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_redo_actions_r2614 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_photo_feedback_r2614;
CREATE POLICY founder_all ON public.engineer_photo_feedback_r2614
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.photo_redo_actions_r2614;
CREATE POLICY founder_all ON public.photo_redo_actions_r2614
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_fb1 uuid := gen_random_uuid();
  v_fb2 uuid := gen_random_uuid();
  v_fb3 uuid := gen_random_uuid();
  v_fb4 uuid := gen_random_uuid();
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at OFFSET 1 LIMIT 1;
  IF v_eng2 IS NULL THEN v_eng2 := v_eng1; END IF;

  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 1 LIMIT 1;
  IF v_hosp2 IS NULL THEN v_hosp2 := v_hosp1; END IF;

  IF v_eng1 IS NULL OR v_hosp1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.engineer_photo_feedback_r2614
    (id, engineer_user_id, hospital_user_id, photo_at, photo_url, customer_feedback_kind, engineer_response_md, owner_email, status, notes)
  VALUES
    (v_fb1, v_eng1, v_hosp1, '2026-06-18 10:00:00+05:30'::timestamptz, 'https://cdn.equipseva.in/photos/r2614/a.jpg', 'praise', 'Thank you for the kind note. Will keep documentation tight.', 'photo-loop@equipseva.in', 'closed', 'Hospital praised clean before-after shots'),
    (v_fb2, v_eng2, v_hosp2, '2026-06-19 14:30:00+05:30'::timestamptz, 'https://cdn.equipseva.in/photos/r2614/b.jpg', 'concern', 'Acknowledged. Will reshoot with floor context tomorrow.', 'photo-loop@equipseva.in', 'open', 'Customer wants wider angle to show drainage path'),
    (v_fb3, v_eng1, v_hosp2, '2026-06-20 09:15:00+05:30'::timestamptz, 'https://cdn.equipseva.in/photos/r2614/c.jpg', 'needs_redo', 'Reshoot scheduled for next visit.', 'photo-loop@equipseva.in', 'escalated', 'Blurry close-up of valve; customer needs proof for vendor claim'),
    (v_fb4, v_eng2, v_hosp1, '2026-06-21 16:45:00+05:30'::timestamptz, 'https://cdn.equipseva.in/photos/r2614/d.jpg', 'none', NULL, 'photo-loop@equipseva.in', 'closed', 'No customer reply within SLA; auto-closed');

  INSERT INTO public.photo_redo_actions_r2614
    (feedback_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES
    (v_fb2, '2026-06-20 11:00:00+05:30'::timestamptz, 'reshoot', 'positive', 'photo-loop@equipseva.in', 'done', 'Wide-angle reshoot accepted by hospital'),
    (v_fb3, '2026-06-21 10:00:00+05:30'::timestamptz, 'retake_signoff', 'pending', 'photo-loop@equipseva.in', 'open', 'Awaiting biomed head signoff'),
    (v_fb3, '2026-06-22 09:00:00+05:30'::timestamptz, 'redact', 'neutral', 'photo-loop@equipseva.in', 'done', 'Patient bedside cropped before vendor share'),
    (v_fb1, '2026-06-19 08:00:00+05:30'::timestamptz, 'reshoot', 'positive', 'photo-loop@equipseva.in', 'done', 'Optional re-take to standardize lighting');
END
$seed$;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_photo_feedback_r2614()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  photo_at timestamptz,
  photo_url text,
  customer_feedback_kind text,
  engineer_response_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.engineer_user_id, f.hospital_user_id, f.photo_at, f.photo_url,
         f.customer_feedback_kind, f.engineer_response_md, f.owner_email, f.status, f.notes
  FROM public.engineer_photo_feedback_r2614 f
  ORDER BY f.photo_at DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_photo_feedback_r2614() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_photo_feedback_r2614() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_redo_actions_r2614()
RETURNS TABLE (
  id uuid,
  feedback_id uuid,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.feedback_id, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
  FROM public.photo_redo_actions_r2614 a
  ORDER BY a.action_at DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_redo_actions_r2614() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_redo_actions_r2614() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_concern_focus_r2614()
RETURNS TABLE (
  engineer_user_id uuid,
  concern_count bigint,
  needs_redo_count bigint,
  open_count bigint,
  total_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.engineer_user_id,
         COUNT(*) FILTER (WHERE f.customer_feedback_kind = 'concern')::bigint AS concern_count,
         COUNT(*) FILTER (WHERE f.customer_feedback_kind = 'needs_redo')::bigint AS needs_redo_count,
         COUNT(*) FILTER (WHERE f.status = 'open')::bigint AS open_count,
         COUNT(*)::bigint AS total_count
  FROM public.engineer_photo_feedback_r2614 f
  GROUP BY f.engineer_user_id
  ORDER BY (COUNT(*) FILTER (WHERE f.customer_feedback_kind IN ('concern','needs_redo'))) DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.top_concern_focus_r2614() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_concern_focus_r2614() TO authenticated;

CREATE OR REPLACE FUNCTION public.feedback_kind_distribution_r2614()
RETURNS TABLE (
  customer_feedback_kind text,
  cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.customer_feedback_kind, COUNT(*)::bigint
  FROM public.engineer_photo_feedback_r2614 f
  GROUP BY f.customer_feedback_kind
  ORDER BY COUNT(*) DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.feedback_kind_distribution_r2614() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.feedback_kind_distribution_r2614() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2614()
RETURNS TABLE (
  status text,
  cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.status, COUNT(*)::bigint
  FROM public.engineer_photo_feedback_r2614 f
  GROUP BY f.status
  ORDER BY COUNT(*) DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2614() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2614() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_feedback_trend_r2614()
RETURNS TABLE (
  month_start timestamptz,
  total_count bigint,
  concern_count bigint,
  praise_count bigint,
  needs_redo_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', f.photo_at) AS month_start,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE f.customer_feedback_kind = 'concern')::bigint AS concern_count,
         COUNT(*) FILTER (WHERE f.customer_feedback_kind = 'praise')::bigint AS praise_count,
         COUNT(*) FILTER (WHERE f.customer_feedback_kind = 'needs_redo')::bigint AS needs_redo_count
  FROM public.engineer_photo_feedback_r2614 f
  GROUP BY date_trunc('month', f.photo_at)
  ORDER BY date_trunc('month', f.photo_at) DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_feedback_trend_r2614() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_feedback_trend_r2614() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2614()
RETURNS TABLE (
  owner_email text,
  feedback_total bigint,
  feedback_open bigint,
  action_total bigint,
  action_open bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH fb AS (
    SELECT f.owner_email,
           COUNT(*)::bigint AS feedback_total,
           COUNT(*) FILTER (WHERE f.status = 'open')::bigint AS feedback_open
    FROM public.engineer_photo_feedback_r2614 f
    GROUP BY f.owner_email
  ), ac AS (
    SELECT a.owner_email,
           COUNT(*)::bigint AS action_total,
           COUNT(*) FILTER (WHERE a.status = 'open')::bigint AS action_open
    FROM public.photo_redo_actions_r2614 a
    GROUP BY a.owner_email
  )
  SELECT COALESCE(fb.owner_email, ac.owner_email) AS owner_email,
         COALESCE(fb.feedback_total, 0) AS feedback_total,
         COALESCE(fb.feedback_open, 0) AS feedback_open,
         COALESCE(ac.action_total, 0) AS action_total,
         COALESCE(ac.action_open, 0) AS action_open
  FROM fb FULL OUTER JOIN ac ON fb.owner_email = ac.owner_email
  ORDER BY (COALESCE(fb.feedback_open, 0) + COALESCE(ac.action_open, 0)) DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2614() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2614() TO authenticated;
