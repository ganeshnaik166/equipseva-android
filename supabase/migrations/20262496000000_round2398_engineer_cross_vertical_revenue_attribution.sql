BEGIN;

-- =====================================================================
-- Round 2398: Engineer Cross-Vertical Revenue Attribution
-- Engineers serving multiple medical verticals — track revenue by
-- vertical, identify tilt (over-concentration), spot generalists vs
-- specialists, surface under-served verticals.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.engineer_vertical_revenue_r2398 (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vertical               text NOT NULL CHECK (vertical IN (
                            'cardiology','oncology','radiology','pathology',
                            'orthopedics','neurology','dental','ophthalmology',
                            'general_surgery','icu_critical_care','pediatrics',
                            'obstetrics_gynecology','dermatology'
                          )),
  period_start           date NOT NULL,
  period_end             date NOT NULL,
  jobs_completed         integer NOT NULL DEFAULT 0,
  gross_revenue_rupees   bigint  NOT NULL DEFAULT 0,
  engineer_payout_rupees bigint  NOT NULL DEFAULT 0,
  platform_take_rupees   bigint  NOT NULL DEFAULT 0,
  avg_csat_score         numeric(3,2),
  is_primary_vertical    boolean NOT NULL DEFAULT false,
  computed_at            timestamptz NOT NULL DEFAULT now(),
  notes                  text,
  UNIQUE (engineer_user_id, vertical, period_start, period_end)
);

CREATE INDEX IF NOT EXISTS idx_evr_r2398_engineer
  ON public.engineer_vertical_revenue_r2398 (engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_evr_r2398_vertical
  ON public.engineer_vertical_revenue_r2398 (vertical, period_start DESC);
CREATE INDEX IF NOT EXISTS idx_evr_r2398_period
  ON public.engineer_vertical_revenue_r2398 (period_start DESC, period_end DESC);

ALTER TABLE public.engineer_vertical_revenue_r2398 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS evr_r2398_founder_all ON public.engineer_vertical_revenue_r2398;
CREATE POLICY evr_r2398_founder_all
  ON public.engineer_vertical_revenue_r2398
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- Tilt analysis snapshots — engineers with > 70% revenue from single vertical
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.engineer_vertical_tilt_r2398 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  snapshot_date            date NOT NULL DEFAULT current_date,
  total_verticals_served   integer NOT NULL DEFAULT 0,
  top_vertical             text,
  top_vertical_share_pct   numeric(5,2),
  tilt_classification      text NOT NULL DEFAULT 'balanced' CHECK (tilt_classification IN (
                              'highly_specialized','specialized','balanced','generalist'
                           )),
  total_revenue_rupees     bigint NOT NULL DEFAULT 0,
  herfindahl_index         numeric(6,4),
  reviewed_by_user_id      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at              timestamptz,
  founder_notes            text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_evt_r2398_engineer
  ON public.engineer_vertical_tilt_r2398 (engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_evt_r2398_classification
  ON public.engineer_vertical_tilt_r2398 (tilt_classification, snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_evt_r2398_top_vertical
  ON public.engineer_vertical_tilt_r2398 (top_vertical, snapshot_date DESC);

ALTER TABLE public.engineer_vertical_tilt_r2398 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS evt_r2398_founder_all ON public.engineer_vertical_tilt_r2398;
CREATE POLICY evt_r2398_founder_all
  ON public.engineer_vertical_tilt_r2398
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: Revenue summary by vertical
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_r2398_revenue_by_vertical()
RETURNS TABLE (
  vertical               text,
  engineer_count         bigint,
  total_jobs             bigint,
  gross_revenue_rupees   bigint,
  platform_take_rupees   bigint,
  avg_csat               numeric
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
    e.vertical,
    COUNT(DISTINCT e.engineer_user_id)::bigint,
    COALESCE(SUM(e.jobs_completed),0)::bigint,
    COALESCE(SUM(e.gross_revenue_rupees),0)::bigint,
    COALESCE(SUM(e.platform_take_rupees),0)::bigint,
    ROUND(AVG(e.avg_csat_score)::numeric, 2)
  FROM public.engineer_vertical_revenue_r2398 e
  GROUP BY e.vertical
  ORDER BY 4 DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2398_revenue_by_vertical() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2398_revenue_by_vertical() TO authenticated;

-- =====================================================================
-- RPC 2: Per-engineer multi-vertical breakdown
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_r2398_engineer_breakdown()
RETURNS TABLE (
  engineer_user_id        uuid,
  engineer_email          text,
  verticals_served        bigint,
  primary_vertical        text,
  total_revenue_rupees    bigint,
  total_jobs              bigint,
  vertical_list           text
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
    e.engineer_user_id,
    p.email,
    COUNT(DISTINCT e.vertical)::bigint,
    MAX(CASE WHEN e.is_primary_vertical THEN e.vertical END),
    COALESCE(SUM(e.gross_revenue_rupees),0)::bigint,
    COALESCE(SUM(e.jobs_completed),0)::bigint,
    string_agg(DISTINCT e.vertical, ', ' ORDER BY e.vertical)
  FROM public.engineer_vertical_revenue_r2398 e
  JOIN public.profiles p ON p.id = e.engineer_user_id
  GROUP BY e.engineer_user_id, p.email
  ORDER BY 5 DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2398_engineer_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2398_engineer_breakdown() TO authenticated;

-- =====================================================================
-- RPC 3: Tilt classification roster
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_r2398_tilt_roster()
RETURNS TABLE (
  engineer_user_id         uuid,
  engineer_email           text,
  snapshot_date            date,
  total_verticals_served   integer,
  top_vertical             text,
  top_vertical_share_pct   numeric,
  tilt_classification      text,
  total_revenue_rupees     bigint,
  herfindahl_index         numeric
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
    t.engineer_user_id,
    p.email,
    t.snapshot_date,
    t.total_verticals_served,
    t.top_vertical,
    t.top_vertical_share_pct,
    t.tilt_classification,
    t.total_revenue_rupees,
    t.herfindahl_index
  FROM public.engineer_vertical_tilt_r2398 t
  JOIN public.profiles p ON p.id = t.engineer_user_id
  ORDER BY t.snapshot_date DESC, t.total_revenue_rupees DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2398_tilt_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2398_tilt_roster() TO authenticated;

-- =====================================================================
-- RPC 4: Tilt classification distribution
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_r2398_tilt_distribution()
RETURNS TABLE (
  tilt_classification     text,
  engineer_count          bigint,
  avg_top_share_pct       numeric,
  avg_revenue_rupees      numeric
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
    t.tilt_classification,
    COUNT(*)::bigint,
    ROUND(AVG(t.top_vertical_share_pct)::numeric, 2),
    ROUND(AVG(t.total_revenue_rupees)::numeric, 0)
  FROM public.engineer_vertical_tilt_r2398 t
  WHERE t.snapshot_date = (
    SELECT MAX(snapshot_date) FROM public.engineer_vertical_tilt_r2398
  )
  GROUP BY t.tilt_classification
  ORDER BY 2 DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2398_tilt_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2398_tilt_distribution() TO authenticated;

-- =====================================================================
-- RPC 5: Generalists — engineers spanning 3+ verticals
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_r2398_top_generalists()
RETURNS TABLE (
  engineer_user_id        uuid,
  engineer_email          text,
  verticals_count         bigint,
  total_revenue_rupees    bigint,
  avg_csat                numeric
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
    e.engineer_user_id,
    p.email,
    COUNT(DISTINCT e.vertical)::bigint,
    COALESCE(SUM(e.gross_revenue_rupees),0)::bigint,
    ROUND(AVG(e.avg_csat_score)::numeric, 2)
  FROM public.engineer_vertical_revenue_r2398 e
  JOIN public.profiles p ON p.id = e.engineer_user_id
  GROUP BY e.engineer_user_id, p.email
  HAVING COUNT(DISTINCT e.vertical) >= 3
  ORDER BY 3 DESC, 4 DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2398_top_generalists() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2398_top_generalists() TO authenticated;

-- =====================================================================
-- RPC 6: Highly-specialized engineers — > 80% from one vertical
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_r2398_highly_specialized()
RETURNS TABLE (
  engineer_user_id         uuid,
  engineer_email           text,
  top_vertical             text,
  top_vertical_share_pct   numeric,
  total_revenue_rupees     bigint,
  snapshot_date            date
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
    t.engineer_user_id,
    p.email,
    t.top_vertical,
    t.top_vertical_share_pct,
    t.total_revenue_rupees,
    t.snapshot_date
  FROM public.engineer_vertical_tilt_r2398 t
  JOIN public.profiles p ON p.id = t.engineer_user_id
  WHERE t.tilt_classification = 'highly_specialized'
    AND t.snapshot_date = (
      SELECT MAX(snapshot_date) FROM public.engineer_vertical_tilt_r2398
    )
  ORDER BY t.top_vertical_share_pct DESC, t.total_revenue_rupees DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2398_highly_specialized() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2398_highly_specialized() TO authenticated;

-- =====================================================================
-- RPC 7: Founder review tilt snapshot
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_r2398_review_tilt(
  p_tilt_id uuid,
  p_notes   text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid;
  v_email    text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := auth.jwt()->>'email';

  SELECT id INTO v_actor_id
  FROM public.profiles
  WHERE email = v_email
  LIMIT 1;

  UPDATE public.engineer_vertical_tilt_r2398
     SET reviewed_by_user_id = v_actor_id,
         reviewed_at         = now(),
         founder_notes       = p_notes
   WHERE id = p_tilt_id;

  RETURN p_tilt_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2398_review_tilt(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2398_review_tilt(uuid, text) TO authenticated;

COMMIT;
