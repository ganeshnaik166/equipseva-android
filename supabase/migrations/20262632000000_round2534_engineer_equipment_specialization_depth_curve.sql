-- Round 2534: engineer equipment specialization depth curve
-- Tracks engineer × equipment-model depth, certification, plateau detection
-- and post-assessment recommendations.

BEGIN;

-- ---------------------------------------------------------------------------
-- Table: engineer_specialization_depth_r2534
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_specialization_depth_r2534 (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
    equipment_model text NOT NULL,
    equipment_kind text NOT NULL,
    jobs_done int NOT NULL DEFAULT 0,
    depth_score int NOT NULL DEFAULT 0,
    certification_status text NOT NULL DEFAULT 'none',
    last_assessed_at timestamptz,
    diminishing_returns_pct numeric(5,2) NOT NULL DEFAULT 0,
    owner_email text,
    status text NOT NULL DEFAULT 'growing',
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT depth_r2534_score_range CHECK (depth_score BETWEEN 0 AND 100),
    CONSTRAINT depth_r2534_cert_chk CHECK (certification_status IN ('none','pending','certified','expired')),
    CONSTRAINT depth_r2534_status_chk CHECK (status IN ('growing','peak','plateau','decay'))
);

CREATE INDEX IF NOT EXISTS depth_r2534_eng_idx
    ON public.engineer_specialization_depth_r2534 (engineer_user_id);
CREATE INDEX IF NOT EXISTS depth_r2534_status_idx
    ON public.engineer_specialization_depth_r2534 (status);
CREATE INDEX IF NOT EXISTS depth_r2534_kind_idx
    ON public.engineer_specialization_depth_r2534 (equipment_kind);

ALTER TABLE public.engineer_specialization_depth_r2534 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_specialization_depth_r2534;
CREATE POLICY founder_all ON public.engineer_specialization_depth_r2534
    FOR ALL TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- Table: depth_curve_assessments_r2534
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.depth_curve_assessments_r2534 (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    specialization_id uuid REFERENCES public.engineer_specialization_depth_r2534(id) ON DELETE CASCADE,
    assessed_at timestamptz NOT NULL DEFAULT now(),
    pre_score int NOT NULL DEFAULT 0,
    post_score int NOT NULL DEFAULT 0,
    gain_delta int NOT NULL DEFAULT 0,
    assessor_email text,
    recommendation text NOT NULL DEFAULT 'continue',
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT assess_r2534_pre_chk CHECK (pre_score BETWEEN 0 AND 100),
    CONSTRAINT assess_r2534_post_chk CHECK (post_score BETWEEN 0 AND 100),
    CONSTRAINT assess_r2534_rec_chk CHECK (recommendation IN ('continue','diversify','refresh','cross_train'))
);

CREATE INDEX IF NOT EXISTS assess_r2534_spec_idx
    ON public.depth_curve_assessments_r2534 (specialization_id);
CREATE INDEX IF NOT EXISTS assess_r2534_time_idx
    ON public.depth_curve_assessments_r2534 (assessed_at DESC);

ALTER TABLE public.depth_curve_assessments_r2534 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.depth_curve_assessments_r2534;
CREATE POLICY founder_all ON public.depth_curve_assessments_r2534
    FOR ALL TO authenticated
    USING (public.is_founder())
    WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- Seeds
-- ---------------------------------------------------------------------------
DO $seed$
DECLARE
    s1 uuid;
    s2 uuid;
    s3 uuid;
    s4 uuid;
    s5 uuid;
BEGIN
    INSERT INTO public.engineer_specialization_depth_r2534
        (equipment_model, equipment_kind, jobs_done, depth_score,
         certification_status, last_assessed_at, diminishing_returns_pct,
         owner_email, status, notes)
    VALUES ('GE Logiq P9', 'ultrasound', 142, 88,
            'certified', '2026-06-10 09:00'::timestamptz, 12.50,
            'priya@equipseva.com', 'peak',
            'Top ultrasound specialist; gains slowing.')
    RETURNING id INTO s1;

    INSERT INTO public.engineer_specialization_depth_r2534
        (equipment_model, equipment_kind, jobs_done, depth_score,
         certification_status, last_assessed_at, diminishing_returns_pct,
         owner_email, status, notes)
    VALUES ('Philips IntelliVue MX450', 'patient_monitor', 96, 72,
            'pending', '2026-06-12 11:00'::timestamptz, 6.00,
            'arjun@equipseva.com', 'growing',
            'Still climbing curve.')
    RETURNING id INTO s2;

    INSERT INTO public.engineer_specialization_depth_r2534
        (equipment_model, equipment_kind, jobs_done, depth_score,
         certification_status, last_assessed_at, diminishing_returns_pct,
         owner_email, status, notes)
    VALUES ('Siemens Acuson NX3', 'ultrasound', 210, 91,
            'certified', '2026-06-05 14:30'::timestamptz, 22.10,
            'meena@equipseva.com', 'plateau',
            'Plateaued — diversify to MRI.')
    RETURNING id INTO s3;

    INSERT INTO public.engineer_specialization_depth_r2534
        (equipment_model, equipment_kind, jobs_done, depth_score,
         certification_status, last_assessed_at, diminishing_returns_pct,
         owner_email, status, notes)
    VALUES ('Mindray BeneHeart D3', 'defibrillator', 35, 41,
            'none', '2026-06-15 10:00'::timestamptz, 2.00,
            'rohit@equipseva.com', 'growing',
            'Early ramp.')
    RETURNING id INTO s4;

    INSERT INTO public.engineer_specialization_depth_r2534
        (equipment_model, equipment_kind, jobs_done, depth_score,
         certification_status, last_assessed_at, diminishing_returns_pct,
         owner_email, status, notes)
    VALUES ('Drager Fabius Tiro', 'anesthesia', 168, 64,
            'expired', '2026-05-20 08:00'::timestamptz, 18.50,
            'karthik@equipseva.com', 'decay',
            'Skill decaying; refresh cert.')
    RETURNING id INTO s5;

    INSERT INTO public.depth_curve_assessments_r2534
        (specialization_id, assessed_at, pre_score, post_score, gain_delta,
         assessor_email, recommendation, notes)
    VALUES
        (s1, '2026-04-10 09:00'::timestamptz, 80, 88, 8,
         'founder@equipseva.com', 'diversify', 'Move to cross-train CT.'),
        (s2, '2026-05-12 11:00'::timestamptz, 62, 72, 10,
         'founder@equipseva.com', 'continue', 'Strong gain — keep going.'),
        (s3, '2026-04-05 14:30'::timestamptz, 90, 91, 1,
         'founder@equipseva.com', 'diversify', 'Plateau confirmed.'),
        (s4, '2026-05-15 10:00'::timestamptz, 28, 41, 13,
         'founder@equipseva.com', 'continue', 'Excellent first quarter ramp.'),
        (s5, '2026-03-20 08:00'::timestamptz, 78, 64, -14,
         'founder@equipseva.com', 'refresh', 'Decay — schedule re-cert.');
END
$seed$;

-- ---------------------------------------------------------------------------
-- RPC: list_specializations_r2534
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.list_specializations_r2534();
CREATE FUNCTION public.list_specializations_r2534()
RETURNS TABLE (
    id uuid,
    equipment_model text,
    equipment_kind text,
    jobs_done int,
    depth_score int,
    certification_status text,
    last_assessed_at timestamptz,
    diminishing_returns_pct numeric,
    owner_email text,
    status text,
    notes text,
    created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
        SELECT s.id, s.equipment_model, s.equipment_kind, s.jobs_done,
               s.depth_score, s.certification_status, s.last_assessed_at,
               s.diminishing_returns_pct, s.owner_email, s.status, s.notes,
               s.created_at
        FROM public.engineer_specialization_depth_r2534 s
        ORDER BY s.depth_score DESC, s.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_specializations_r2534() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_specializations_r2534() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: list_assessments_r2534
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.list_assessments_r2534();
CREATE FUNCTION public.list_assessments_r2534()
RETURNS TABLE (
    id uuid,
    specialization_id uuid,
    equipment_model text,
    assessed_at timestamptz,
    pre_score int,
    post_score int,
    gain_delta int,
    assessor_email text,
    recommendation text,
    notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
        SELECT a.id, a.specialization_id, s.equipment_model, a.assessed_at,
               a.pre_score, a.post_score, a.gain_delta, a.assessor_email,
               a.recommendation, a.notes
        FROM public.depth_curve_assessments_r2534 a
        LEFT JOIN public.engineer_specialization_depth_r2534 s
            ON s.id = a.specialization_id
        ORDER BY a.assessed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_assessments_r2534() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_assessments_r2534() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: top_depth_engineers_r2534
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.top_depth_engineers_r2534();
CREATE FUNCTION public.top_depth_engineers_r2534()
RETURNS TABLE (
    owner_email text,
    specializations int,
    avg_depth numeric,
    total_jobs int,
    top_model text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
        WITH base AS (
            SELECT s.owner_email,
                   COUNT(*)::int AS specializations,
                   ROUND(AVG(s.depth_score)::numeric, 2) AS avg_depth,
                   SUM(s.jobs_done)::int AS total_jobs
            FROM public.engineer_specialization_depth_r2534 s
            WHERE s.owner_email IS NOT NULL
            GROUP BY s.owner_email
        ),
        top_m AS (
            SELECT DISTINCT ON (s.owner_email)
                   s.owner_email, s.equipment_model
            FROM public.engineer_specialization_depth_r2534 s
            WHERE s.owner_email IS NOT NULL
            ORDER BY s.owner_email, s.depth_score DESC
        )
        SELECT b.owner_email, b.specializations, b.avg_depth, b.total_jobs, t.equipment_model
        FROM base b
        LEFT JOIN top_m t ON t.owner_email = b.owner_email
        ORDER BY b.avg_depth DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_depth_engineers_r2534() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_depth_engineers_r2534() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: plateau_focus_r2534
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.plateau_focus_r2534();
CREATE FUNCTION public.plateau_focus_r2534()
RETURNS TABLE (
    id uuid,
    owner_email text,
    equipment_model text,
    equipment_kind text,
    depth_score int,
    diminishing_returns_pct numeric,
    status text,
    last_assessed_at timestamptz,
    suggested_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
        SELECT s.id, s.owner_email, s.equipment_model, s.equipment_kind,
               s.depth_score, s.diminishing_returns_pct, s.status, s.last_assessed_at,
               CASE
                   WHEN s.status = 'decay' THEN 'refresh cert'
                   WHEN s.status = 'plateau' THEN 'diversify'
                   WHEN s.diminishing_returns_pct >= 15 THEN 'cross-train'
                   ELSE 'continue'
               END::text AS suggested_action
        FROM public.engineer_specialization_depth_r2534 s
        WHERE s.status IN ('plateau','decay')
           OR s.diminishing_returns_pct >= 15
        ORDER BY s.diminishing_returns_pct DESC, s.depth_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.plateau_focus_r2534() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plateau_focus_r2534() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: equipment_kind_summary_r2534
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.equipment_kind_summary_r2534();
CREATE FUNCTION public.equipment_kind_summary_r2534()
RETURNS TABLE (
    equipment_kind text,
    specialists int,
    avg_depth numeric,
    total_jobs int,
    certified_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
        SELECT s.equipment_kind,
               COUNT(*)::int AS specialists,
               ROUND(AVG(s.depth_score)::numeric, 2) AS avg_depth,
               SUM(s.jobs_done)::int AS total_jobs,
               SUM(CASE WHEN s.certification_status = 'certified' THEN 1 ELSE 0 END)::int AS certified_count
        FROM public.engineer_specialization_depth_r2534 s
        GROUP BY s.equipment_kind
        ORDER BY avg_depth DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_summary_r2534() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_summary_r2534() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: monthly_depth_trend_r2534
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.monthly_depth_trend_r2534();
CREATE FUNCTION public.monthly_depth_trend_r2534()
RETURNS TABLE (
    month_start timestamptz,
    assessments int,
    avg_pre numeric,
    avg_post numeric,
    avg_gain numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
        SELECT date_trunc('month', a.assessed_at)::timestamptz AS month_start,
               COUNT(*)::int AS assessments,
               ROUND(AVG(a.pre_score)::numeric, 2) AS avg_pre,
               ROUND(AVG(a.post_score)::numeric, 2) AS avg_post,
               ROUND(AVG(a.gain_delta)::numeric, 2) AS avg_gain
        FROM public.depth_curve_assessments_r2534 a
        GROUP BY date_trunc('month', a.assessed_at)
        ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_depth_trend_r2534() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_depth_trend_r2534() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: recommendation_distribution_r2534
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.recommendation_distribution_r2534();
CREATE FUNCTION public.recommendation_distribution_r2534()
RETURNS TABLE (
    recommendation text,
    n int,
    avg_gain numeric,
    last_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
    IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
        SELECT a.recommendation,
               COUNT(*)::int AS n,
               ROUND(AVG(a.gain_delta)::numeric, 2) AS avg_gain,
               MAX(a.assessed_at) AS last_at
        FROM public.depth_curve_assessments_r2534 a
        GROUP BY a.recommendation
        ORDER BY n DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recommendation_distribution_r2534() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recommendation_distribution_r2534() TO authenticated;

