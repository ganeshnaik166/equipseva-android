BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_recognition_nominations_r2231 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  nominated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  cycle_month date NOT NULL,
  jobs_completed int NOT NULL DEFAULT 0,
  avg_rating numeric(3,2) NOT NULL DEFAULT 0,
  on_time_pct numeric(5,2) NOT NULL DEFAULT 0,
  nomination_reason text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','shortlisted','selected','rejected')),
  score numeric(6,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_recognition_selections_r2231 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month date NOT NULL UNIQUE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  nomination_id uuid REFERENCES public.engineer_recognition_nominations_r2231(id) ON DELETE SET NULL,
  bonus_rupees int NOT NULL DEFAULT 5000,
  shoutout_text text NOT NULL DEFAULT '',
  public_profile_url text,
  announced_at timestamptz,
  selected_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  selected_at timestamptz NOT NULL DEFAULT now(),
  notes text NOT NULL DEFAULT ''
);

ALTER TABLE public.engineer_recognition_nominations_r2231 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_recognition_selections_r2231 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_recognition_nominations_r2231;
CREATE POLICY founder_all ON public.engineer_recognition_nominations_r2231
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_recognition_selections_r2231;
CREATE POLICY founder_all ON public.engineer_recognition_selections_r2231
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_recog_nom_r2231_cycle ON public.engineer_recognition_nominations_r2231(cycle_month);
CREATE INDEX IF NOT EXISTS idx_recog_nom_r2231_eng ON public.engineer_recognition_nominations_r2231(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_recog_sel_r2231_eng ON public.engineer_recognition_selections_r2231(engineer_user_id);

CREATE OR REPLACE FUNCTION public.founder_recognition_overview_r2231()
RETURNS TABLE(
  total_nominations int,
  pending_nominations int,
  shortlisted_nominations int,
  selected_count int,
  current_cycle date,
  current_cycle_selected_engineer text,
  total_bonus_paid_rupees int,
  avg_score numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.engineer_recognition_nominations_r2231)::int,
    (SELECT COUNT(*) FILTER (WHERE status = 'pending') FROM public.engineer_recognition_nominations_r2231)::int,
    (SELECT COUNT(*) FILTER (WHERE status = 'shortlisted') FROM public.engineer_recognition_nominations_r2231)::int,
    (SELECT COUNT(*) FROM public.engineer_recognition_selections_r2231)::int,
    date_trunc('month', now())::date,
    (SELECT p.full_name FROM public.engineer_recognition_selections_r2231 s
       JOIN public.profiles p ON p.id = s.engineer_user_id
       WHERE s.cycle_month = date_trunc('month', now())::date
       LIMIT 1),
    COALESCE((SELECT SUM(bonus_rupees) FROM public.engineer_recognition_selections_r2231), 0)::int,
    COALESCE((SELECT AVG(score) FROM public.engineer_recognition_nominations_r2231), 0)::numeric;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_recognition_list_nominations_r2231()
RETURNS TABLE(
  id uuid,
  engineer_name text,
  engineer_email text,
  nominated_by_name text,
  cycle_month date,
  jobs_completed int,
  avg_rating numeric,
  on_time_pct numeric,
  nomination_reason text,
  status text,
  score numeric,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id,
         p.full_name,
         p.email,
         nb.full_name,
         n.cycle_month,
         n.jobs_completed,
         n.avg_rating,
         n.on_time_pct,
         n.nomination_reason,
         n.status,
         n.score,
         n.created_at
  FROM public.engineer_recognition_nominations_r2231 n
  LEFT JOIN public.profiles p ON p.id = n.engineer_user_id
  LEFT JOIN public.profiles nb ON nb.id = n.nominated_by
  ORDER BY n.cycle_month DESC, n.score DESC NULLS LAST
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_recognition_list_selections_r2231()
RETURNS TABLE(
  id uuid,
  cycle_month date,
  engineer_name text,
  engineer_email text,
  bonus_rupees int,
  shoutout_text text,
  public_profile_url text,
  announced_at timestamptz,
  selected_at timestamptz,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id,
         s.cycle_month,
         p.full_name,
         p.email,
         s.bonus_rupees,
         s.shoutout_text,
         s.public_profile_url,
         s.announced_at,
         s.selected_at,
         s.notes
  FROM public.engineer_recognition_selections_r2231 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.cycle_month DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_recognition_by_status_r2231()
RETURNS TABLE(status text, cnt int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.status, (COUNT(*))::int
  FROM public.engineer_recognition_nominations_r2231 n
  GROUP BY n.status
  ORDER BY 2 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_recognition_top_scored_r2231()
RETURNS TABLE(
  engineer_name text,
  cycle_month date,
  score numeric,
  status text,
  jobs_completed int,
  avg_rating numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.full_name, n.cycle_month, n.score, n.status, n.jobs_completed, n.avg_rating
  FROM public.engineer_recognition_nominations_r2231 n
  LEFT JOIN public.profiles p ON p.id = n.engineer_user_id
  ORDER BY n.score DESC NULLS LAST
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_recognition_monthly_trend_r2231()
RETURNS TABLE(cycle_month date, nominations int, selections int, total_bonus_rupees int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.cycle_month,
         (COUNT(*))::int,
         (SELECT COUNT(*) FROM public.engineer_recognition_selections_r2231 s WHERE s.cycle_month = n.cycle_month)::int,
         COALESCE((SELECT SUM(s.bonus_rupees) FROM public.engineer_recognition_selections_r2231 s WHERE s.cycle_month = n.cycle_month), 0)::int
  FROM public.engineer_recognition_nominations_r2231 n
  GROUP BY n.cycle_month
  ORDER BY n.cycle_month DESC
  LIMIT 24;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_recognition_repeat_winners_r2231()
RETURNS TABLE(engineer_name text, win_count int, total_bonus_rupees int, last_won date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.full_name,
         (COUNT(*))::int,
         (COALESCE(SUM(s.bonus_rupees), 0))::int,
         MAX(s.cycle_month)
  FROM public.engineer_recognition_selections_r2231 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  GROUP BY p.full_name
  HAVING COUNT(*) >= 1
  ORDER BY 2 DESC, 3 DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_recognition_overview_r2231() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_recognition_list_nominations_r2231() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_recognition_list_selections_r2231() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_recognition_by_status_r2231() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_recognition_top_scored_r2231() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_recognition_monthly_trend_r2231() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_recognition_repeat_winners_r2231() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_recognition_overview_r2231() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_recognition_list_nominations_r2231() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_recognition_list_selections_r2231() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_recognition_by_status_r2231() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_recognition_top_scored_r2231() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_recognition_monthly_trend_r2231() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_recognition_repeat_winners_r2231() TO authenticated;

COMMIT;
