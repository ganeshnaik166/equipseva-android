BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_photo_walkthrough_submissions_r2226 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  repair_job_id uuid,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  walkthrough_kind text NOT NULL CHECK (walkthrough_kind IN ('pre_service','post_service','damage_evidence','spare_part_install','calibration_readout')),
  photo_count int NOT NULL DEFAULT 0,
  expected_photo_count int NOT NULL DEFAULT 6,
  customer_org_id uuid,
  equipment_label text,
  notes text,
  clarity_score int CHECK (clarity_score BETWEEN 1 AND 5),
  completeness_score int CHECK (completeness_score BETWEEN 1 AND 5),
  accuracy_score int CHECK (accuracy_score BETWEEN 1 AND 5),
  overall_band text CHECK (overall_band IN ('excellent','acceptable','needs_coaching','reject')),
  audit_status text NOT NULL DEFAULT 'pending' CHECK (audit_status IN ('pending','in_review','rated','escalated')),
  rated_at timestamptz,
  rated_by_email text
);

CREATE TABLE IF NOT EXISTS public.engineer_photo_walkthrough_coaching_log_r2226 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.engineer_photo_walkthrough_submissions_r2226(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  logged_at timestamptz NOT NULL DEFAULT now(),
  coach_email text NOT NULL,
  coaching_theme text NOT NULL CHECK (coaching_theme IN ('focus_blur','lighting','angle_coverage','serial_number_capture','before_after_pairing','meter_reading_legibility','identity_proof')),
  coaching_note text NOT NULL,
  required_followup boolean NOT NULL DEFAULT false,
  followup_deadline date,
  resolved_at timestamptz
);

ALTER TABLE public.engineer_photo_walkthrough_submissions_r2226 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_photo_walkthrough_coaching_log_r2226 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_photo_walkthrough_submissions_r2226;
CREATE POLICY founder_all ON public.engineer_photo_walkthrough_submissions_r2226 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_photo_walkthrough_coaching_log_r2226;
CREATE POLICY founder_all ON public.engineer_photo_walkthrough_coaching_log_r2226 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_epwqa_subs_status_r2226 ON public.engineer_photo_walkthrough_submissions_r2226(audit_status, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_epwqa_subs_engineer_r2226 ON public.engineer_photo_walkthrough_submissions_r2226(engineer_user_id, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_epwqa_coach_engineer_r2226 ON public.engineer_photo_walkthrough_coaching_log_r2226(engineer_user_id, logged_at DESC);

-- RPC 1: pending audit queue
CREATE OR REPLACE FUNCTION public.epwqa_pending_queue_r2226()
RETURNS TABLE (
  submission_id uuid,
  engineer_user_id uuid,
  engineer_email text,
  submitted_at timestamptz,
  walkthrough_kind text,
  photo_count int,
  expected_photo_count int,
  coverage_pct int,
  equipment_label text,
  audit_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, p.email::text, s.submitted_at, s.walkthrough_kind,
    s.photo_count, s.expected_photo_count,
    CASE WHEN s.expected_photo_count > 0 THEN ((s.photo_count::numeric / s.expected_photo_count::numeric) * 100)::int ELSE 0 END,
    s.equipment_label, s.audit_status
  FROM public.engineer_photo_walkthrough_submissions_r2226 s
  JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.audit_status IN ('pending','in_review')
  ORDER BY s.submitted_at ASC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.epwqa_pending_queue_r2226() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.epwqa_pending_queue_r2226() TO authenticated;

-- RPC 2: engineer leaderboard
CREATE OR REPLACE FUNCTION public.epwqa_engineer_leaderboard_r2226()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  submissions_30d int,
  rated_30d int,
  avg_clarity numeric,
  avg_completeness numeric,
  avg_accuracy numeric,
  needs_coaching_count int,
  rejects_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_user_id, p.email::text,
    (COUNT(*) FILTER (WHERE s.submitted_at > now() - interval '30 days'))::int,
    (COUNT(*) FILTER (WHERE s.rated_at IS NOT NULL AND s.submitted_at > now() - interval '30 days'))::int,
    ROUND(AVG(s.clarity_score)::numeric, 2),
    ROUND(AVG(s.completeness_score)::numeric, 2),
    ROUND(AVG(s.accuracy_score)::numeric, 2),
    (COUNT(*) FILTER (WHERE s.overall_band = 'needs_coaching'))::int,
    (COUNT(*) FILTER (WHERE s.overall_band = 'reject'))::int
  FROM public.engineer_photo_walkthrough_submissions_r2226 s
  JOIN public.profiles p ON p.id = s.engineer_user_id
  GROUP BY s.engineer_user_id, p.email
  ORDER BY 4 DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.epwqa_engineer_leaderboard_r2226() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.epwqa_engineer_leaderboard_r2226() TO authenticated;

-- RPC 3: coaching log feed
CREATE OR REPLACE FUNCTION public.epwqa_coaching_feed_r2226()
RETURNS TABLE (
  coaching_id uuid,
  submission_id uuid,
  engineer_user_id uuid,
  engineer_email text,
  logged_at timestamptz,
  coach_email text,
  coaching_theme text,
  coaching_note text,
  required_followup boolean,
  followup_deadline date,
  resolved_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.submission_id, c.engineer_user_id, p.email::text,
    c.logged_at, c.coach_email, c.coaching_theme, c.coaching_note,
    c.required_followup, c.followup_deadline, c.resolved_at
  FROM public.engineer_photo_walkthrough_coaching_log_r2226 c
  JOIN public.profiles p ON p.id = c.engineer_user_id
  ORDER BY c.logged_at DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.epwqa_coaching_feed_r2226() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.epwqa_coaching_feed_r2226() TO authenticated;

-- RPC 4: kind distribution
CREATE OR REPLACE FUNCTION public.epwqa_kind_distribution_r2226()
RETURNS TABLE (
  walkthrough_kind text,
  total_submissions int,
  avg_photos numeric,
  pct_rejected numeric,
  pct_needs_coaching numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.walkthrough_kind,
    (COUNT(*))::int,
    ROUND(AVG(s.photo_count)::numeric, 1),
    ROUND((COUNT(*) FILTER (WHERE s.overall_band = 'reject'))::numeric * 100 / NULLIF(COUNT(*),0), 1),
    ROUND((COUNT(*) FILTER (WHERE s.overall_band = 'needs_coaching'))::numeric * 100 / NULLIF(COUNT(*),0), 1)
  FROM public.engineer_photo_walkthrough_submissions_r2226 s
  GROUP BY s.walkthrough_kind
  ORDER BY 2 DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.epwqa_kind_distribution_r2226() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.epwqa_kind_distribution_r2226() TO authenticated;

-- RPC 5: rate submission
CREATE OR REPLACE FUNCTION public.epwqa_rate_submission_r2226(
  p_submission_id uuid,
  p_clarity int,
  p_completeness int,
  p_accuracy int,
  p_band text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_band NOT IN ('excellent','acceptable','needs_coaching','reject') THEN
    RAISE EXCEPTION 'invalid band';
  END IF;
  v_email := auth.jwt()->>'email';
  UPDATE public.engineer_photo_walkthrough_submissions_r2226
    SET clarity_score = p_clarity,
        completeness_score = p_completeness,
        accuracy_score = p_accuracy,
        overall_band = p_band,
        audit_status = 'rated',
        rated_at = now(),
        rated_by_email = v_email
    WHERE id = p_submission_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'epwqa_rate_submission_r2226',
      jsonb_build_object('submission_id', p_submission_id, 'band', p_band,
        'clarity', p_clarity, 'completeness', p_completeness, 'accuracy', p_accuracy));
  RETURN p_submission_id;
END;
$$;

REVOKE ALL ON FUNCTION public.epwqa_rate_submission_r2226(uuid, int, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.epwqa_rate_submission_r2226(uuid, int, int, int, text) TO authenticated;

-- RPC 6: log coaching note
CREATE OR REPLACE FUNCTION public.epwqa_log_coaching_r2226(
  p_submission_id uuid,
  p_theme text,
  p_note text,
  p_required_followup boolean,
  p_followup_deadline date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_email text;
  v_engineer uuid;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_theme NOT IN ('focus_blur','lighting','angle_coverage','serial_number_capture','before_after_pairing','meter_reading_legibility','identity_proof') THEN
    RAISE EXCEPTION 'invalid theme';
  END IF;
  v_email := auth.jwt()->>'email';
  SELECT engineer_user_id INTO v_engineer
    FROM public.engineer_photo_walkthrough_submissions_r2226
    WHERE id = p_submission_id;
  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'submission not found';
  END IF;
  INSERT INTO public.engineer_photo_walkthrough_coaching_log_r2226
    (submission_id, engineer_user_id, coach_email, coaching_theme, coaching_note, required_followup, followup_deadline)
    VALUES (p_submission_id, v_engineer, v_email, p_theme, p_note, p_required_followup, p_followup_deadline)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'epwqa_log_coaching_r2226',
      jsonb_build_object('coaching_id', v_id, 'submission_id', p_submission_id, 'theme', p_theme));
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.epwqa_log_coaching_r2226(uuid, text, text, boolean, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.epwqa_log_coaching_r2226(uuid, text, text, boolean, date) TO authenticated;

-- RPC 7: escalate submission
CREATE OR REPLACE FUNCTION public.epwqa_escalate_submission_r2226(p_submission_id uuid, p_reason text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  UPDATE public.engineer_photo_walkthrough_submissions_r2226
    SET audit_status = 'escalated'
    WHERE id = p_submission_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'epwqa_escalate_submission_r2226',
      jsonb_build_object('submission_id', p_submission_id, 'reason', p_reason));
  RETURN p_submission_id;
END;
$$;

REVOKE ALL ON FUNCTION public.epwqa_escalate_submission_r2226(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.epwqa_escalate_submission_r2226(uuid, text) TO authenticated;

COMMIT;
