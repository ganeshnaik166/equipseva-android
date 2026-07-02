BEGIN;

-- ============================================================================
-- r2258: Engineer mentor-mentee pairing tracker
-- Senior <-> junior pairs, monthly check-ins, mentee progression, effectiveness
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_mentor_pairs_r2258 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentee_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentor_tier text NOT NULL CHECK (mentor_tier IN ('senior','lead','principal')),
  mentee_tier text NOT NULL CHECK (mentee_tier IN ('junior','associate','mid')),
  pair_status text NOT NULL DEFAULT 'active' CHECK (pair_status IN ('active','paused','completed','dissolved')),
  pairing_goal text NOT NULL CHECK (pairing_goal IN ('skills_transfer','certification_prep','tier_promotion','specialty_deepening','general_growth')),
  paired_at timestamptz NOT NULL DEFAULT now(),
  expected_end_at timestamptz,
  actual_end_at timestamptz,
  effectiveness_rating int CHECK (effectiveness_rating BETWEEN 1 AND 5),
  effectiveness_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pair_no_self CHECK (mentor_profile_id <> mentee_profile_id)
);

CREATE TABLE IF NOT EXISTS public.engineer_mentor_checkins_r2258 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pair_id uuid NOT NULL REFERENCES public.engineer_mentor_pairs_r2258(id) ON DELETE CASCADE,
  checkin_month date NOT NULL,
  checkin_status text NOT NULL DEFAULT 'scheduled' CHECK (checkin_status IN ('scheduled','completed','missed','rescheduled')),
  mentee_progress_score int CHECK (mentee_progress_score BETWEEN 1 AND 10),
  topics_covered text,
  blockers_raised text,
  next_action text,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mentor_pairs_r2258_status ON public.engineer_mentor_pairs_r2258(pair_status);
CREATE INDEX IF NOT EXISTS idx_mentor_pairs_r2258_mentor ON public.engineer_mentor_pairs_r2258(mentor_profile_id);
CREATE INDEX IF NOT EXISTS idx_mentor_pairs_r2258_mentee ON public.engineer_mentor_pairs_r2258(mentee_profile_id);
CREATE INDEX IF NOT EXISTS idx_mentor_checkins_r2258_pair ON public.engineer_mentor_checkins_r2258(pair_id);
CREATE INDEX IF NOT EXISTS idx_mentor_checkins_r2258_month ON public.engineer_mentor_checkins_r2258(checkin_month);

ALTER TABLE public.engineer_mentor_pairs_r2258 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_mentor_checkins_r2258 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_mentor_pairs_r2258;
CREATE POLICY founder_all ON public.engineer_mentor_pairs_r2258 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_mentor_checkins_r2258;
CREATE POLICY founder_all ON public.engineer_mentor_checkins_r2258 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed pairs
INSERT INTO public.engineer_mentor_pairs_r2258
  (mentor_profile_id, mentee_profile_id, mentor_tier, mentee_tier, pair_status, pairing_goal, paired_at, expected_end_at, actual_end_at, effectiveness_rating, effectiveness_notes)
SELECT mentor.id, mentee.id,
  (ARRAY['senior','lead','principal'])[1 + (n % 3)],
  (ARRAY['junior','associate','mid'])[1 + (n % 3)],
  (ARRAY['active','active','active','active','paused','completed','active','active','dissolved','active','active','completed'])[1 + (n % 12)],
  (ARRAY['skills_transfer','certification_prep','tier_promotion','specialty_deepening','general_growth'])[1 + (n % 5)],
  now() - ((30 + n * 7) || ' days')::interval,
  now() + ((120 - n * 5) || ' days')::interval,
  CASE WHEN n % 4 = 3 THEN now() - ((n) || ' days')::interval ELSE NULL END,
  CASE WHEN n % 4 = 3 THEN 1 + (n % 5) ELSE NULL END,
  CASE WHEN n % 4 = 3 THEN 'Pair completed; mentee tier-up achieved.' ELSE NULL END
FROM (
  SELECT id, row_number() OVER (ORDER BY id) AS rn FROM public.profiles LIMIT 12
) mentor
JOIN (
  SELECT id, row_number() OVER (ORDER BY id DESC) AS rn FROM public.profiles LIMIT 12
) mentee ON mentor.rn = mentee.rn AND mentor.id <> mentee.id
CROSS JOIN LATERAL (SELECT (mentor.rn - 1)::int AS n) idx
ON CONFLICT DO NOTHING;

-- Seed check-ins
INSERT INTO public.engineer_mentor_checkins_r2258
  (pair_id, checkin_month, checkin_status, mentee_progress_score, topics_covered, blockers_raised, next_action, completed_at)
SELECT p.id,
  date_trunc('month', now() - ((m * 30) || ' days')::interval)::date,
  (ARRAY['completed','completed','completed','scheduled','missed','rescheduled'])[1 + (m % 6)],
  CASE WHEN m % 6 IN (0,1,2) THEN 5 + (m % 6) ELSE NULL END,
  'Diagnostic flow walkthrough; AMC SOP refresher.',
  CASE WHEN m % 3 = 0 THEN 'Mentee needs more bedside-manner reps with hospital staff.' ELSE NULL END,
  'Shadow 2 more AMC visits next month.',
  CASE WHEN m % 6 IN (0,1,2) THEN now() - ((m * 30 - 5) || ' days')::interval ELSE NULL END
FROM public.engineer_mentor_pairs_r2258 p
CROSS JOIN generate_series(0, 5) m
ON CONFLICT DO NOTHING;

-- ============================================================================
-- RPCs (7) — all founder-gated
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r2258_summary()
RETURNS TABLE(
  active_pairs int,
  paused_pairs int,
  completed_pairs int,
  dissolved_pairs int,
  avg_effectiveness numeric,
  pairs_needing_review int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE pair_status='active'))::int,
    (COUNT(*) FILTER (WHERE pair_status='paused'))::int,
    (COUNT(*) FILTER (WHERE pair_status='completed'))::int,
    (COUNT(*) FILTER (WHERE pair_status='dissolved'))::int,
    ROUND(AVG(effectiveness_rating) FILTER (WHERE effectiveness_rating IS NOT NULL), 2),
    (COUNT(*) FILTER (WHERE pair_status='active' AND paired_at < now() - interval '180 days'))::int
  FROM public.engineer_mentor_pairs_r2258;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2258_active_pairs()
RETURNS TABLE(
  pair_id uuid,
  mentor_email text,
  mentee_email text,
  mentor_tier text,
  mentee_tier text,
  pairing_goal text,
  paired_at timestamptz,
  days_paired int,
  expected_end_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, mentor.email, mentee.email, p.mentor_tier, p.mentee_tier,
    p.pairing_goal, p.paired_at,
    EXTRACT(DAY FROM (now() - p.paired_at))::int,
    p.expected_end_at
  FROM public.engineer_mentor_pairs_r2258 p
  JOIN public.profiles mentor ON mentor.id = p.mentor_profile_id
  JOIN public.profiles mentee ON mentee.id = p.mentee_profile_id
  WHERE p.pair_status = 'active'
  ORDER BY p.paired_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2258_recent_checkins(limit_count int DEFAULT 50)
RETURNS TABLE(
  checkin_id uuid,
  pair_id uuid,
  mentor_email text,
  mentee_email text,
  checkin_month date,
  checkin_status text,
  mentee_progress_score int,
  topics_covered text,
  completed_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.pair_id, mentor.email, mentee.email,
    c.checkin_month, c.checkin_status, c.mentee_progress_score,
    c.topics_covered, c.completed_at
  FROM public.engineer_mentor_checkins_r2258 c
  JOIN public.engineer_mentor_pairs_r2258 p ON p.id = c.pair_id
  JOIN public.profiles mentor ON mentor.id = p.mentor_profile_id
  JOIN public.profiles mentee ON mentee.id = p.mentee_profile_id
  ORDER BY c.checkin_month DESC, c.created_at DESC
  LIMIT limit_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2258_effectiveness_by_goal()
RETURNS TABLE(
  pairing_goal text,
  pair_count int,
  avg_effectiveness numeric,
  completed_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.pairing_goal,
    (COUNT(*))::int,
    ROUND(AVG(p.effectiveness_rating) FILTER (WHERE p.effectiveness_rating IS NOT NULL), 2),
    (COUNT(*) FILTER (WHERE p.pair_status='completed'))::int
  FROM public.engineer_mentor_pairs_r2258 p
  GROUP BY p.pairing_goal
  ORDER BY 2 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2258_missed_checkins()
RETURNS TABLE(
  pair_id uuid,
  mentor_email text,
  mentee_email text,
  checkin_month date,
  checkin_status text,
  days_overdue int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, mentor.email, mentee.email,
    c.checkin_month, c.checkin_status,
    EXTRACT(DAY FROM (now() - c.checkin_month::timestamptz))::int
  FROM public.engineer_mentor_checkins_r2258 c
  JOIN public.engineer_mentor_pairs_r2258 p ON p.id = c.pair_id
  JOIN public.profiles mentor ON mentor.id = p.mentor_profile_id
  JOIN public.profiles mentee ON mentee.id = p.mentee_profile_id
  WHERE c.checkin_status IN ('missed','rescheduled')
  ORDER BY c.checkin_month DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2258_mentor_load()
RETURNS TABLE(
  mentor_email text,
  mentor_tier text,
  active_mentees int,
  completed_mentees int,
  avg_rating numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT mentor.email, p.mentor_tier,
    (COUNT(*) FILTER (WHERE p.pair_status='active'))::int,
    (COUNT(*) FILTER (WHERE p.pair_status='completed'))::int,
    ROUND(AVG(p.effectiveness_rating) FILTER (WHERE p.effectiveness_rating IS NOT NULL), 2)
  FROM public.engineer_mentor_pairs_r2258 p
  JOIN public.profiles mentor ON mentor.id = p.mentor_profile_id
  GROUP BY mentor.email, p.mentor_tier
  ORDER BY 3 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2258_progression_trend()
RETURNS TABLE(
  month_bucket date,
  checkins_completed int,
  avg_progress_score numeric,
  missed_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.checkin_month,
    (COUNT(*) FILTER (WHERE c.checkin_status='completed'))::int,
    ROUND(AVG(c.mentee_progress_score) FILTER (WHERE c.mentee_progress_score IS NOT NULL), 2),
    (COUNT(*) FILTER (WHERE c.checkin_status='missed'))::int
  FROM public.engineer_mentor_checkins_r2258 c
  GROUP BY c.checkin_month
  ORDER BY c.checkin_month DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2258_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2258_active_pairs() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2258_recent_checkins(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2258_effectiveness_by_goal() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2258_missed_checkins() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2258_mentor_load() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2258_progression_trend() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2258_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2258_active_pairs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2258_recent_checkins(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2258_effectiveness_by_goal() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2258_missed_checkins() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2258_mentor_load() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2258_progression_trend() TO authenticated;

COMMIT;
