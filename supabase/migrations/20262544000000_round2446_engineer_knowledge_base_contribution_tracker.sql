-- Round 2446: Engineer Knowledge Base Contribution Tracker
-- KB articles authored x views x thumbs x peer-reuse x recognition

CREATE TABLE IF NOT EXISTS public.engineer_kb_articles_r2446 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  title text NOT NULL,
  equipment_kind text NOT NULL,
  article_kind text NOT NULL CHECK (article_kind IN ('troubleshooting','calibration','install_guide','safety_protocol','parts_swap')),
  published_at timestamptz,
  view_count int NOT NULL DEFAULT 0 CHECK (view_count >= 0),
  thumbs_up_count int NOT NULL DEFAULT 0 CHECK (thumbs_up_count >= 0),
  thumbs_down_count int NOT NULL DEFAULT 0 CHECK (thumbs_down_count >= 0),
  peer_reuse_count int NOT NULL DEFAULT 0 CHECK (peer_reuse_count >= 0),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','featured','retired')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kba_r2446_engineer ON public.engineer_kb_articles_r2446(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_kba_r2446_status ON public.engineer_kb_articles_r2446(status);
CREATE INDEX IF NOT EXISTS idx_kba_r2446_kind ON public.engineer_kb_articles_r2446(article_kind);
CREATE INDEX IF NOT EXISTS idx_kba_r2446_published ON public.engineer_kb_articles_r2446(published_at DESC);

CREATE TABLE IF NOT EXISTS public.kb_contribution_recognition_r2446 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  period_start date NOT NULL,
  period_end date NOT NULL,
  articles_published int NOT NULL DEFAULT 0 CHECK (articles_published >= 0),
  total_views int NOT NULL DEFAULT 0 CHECK (total_views >= 0),
  total_thumbs_up int NOT NULL DEFAULT 0 CHECK (total_thumbs_up >= 0),
  total_peer_reuse int NOT NULL DEFAULT 0 CHECK (total_peer_reuse >= 0),
  recognition_kind text NOT NULL DEFAULT 'none' CHECK (recognition_kind IN ('none','spot_bonus','monthly_award','quarterly_award')),
  bonus_rupees int NOT NULL DEFAULT 0 CHECK (bonus_rupees >= 0),
  awarded_at timestamptz,
  awarded_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (period_end >= period_start)
);

CREATE INDEX IF NOT EXISTS idx_kbr_r2446_engineer ON public.kb_contribution_recognition_r2446(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_kbr_r2446_period ON public.kb_contribution_recognition_r2446(period_start DESC);
CREATE INDEX IF NOT EXISTS idx_kbr_r2446_kind ON public.kb_contribution_recognition_r2446(recognition_kind);

ALTER TABLE public.engineer_kb_articles_r2446 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kb_contribution_recognition_r2446 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_kb_articles_r2446;
CREATE POLICY founder_all ON public.engineer_kb_articles_r2446
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.kb_contribution_recognition_r2446;
CREATE POLICY founder_all ON public.kb_contribution_recognition_r2446
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data — pulled from real engineer profiles
DO $$
DECLARE
  v_e1 uuid;
  v_e2 uuid;
  v_e3 uuid;
  v_e4 uuid;
BEGIN
  SELECT id INTO v_e1 FROM public.profiles WHERE role='engineer' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_e2 FROM public.profiles WHERE role='engineer' AND id <> v_e1 ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_e3 FROM public.profiles WHERE role='engineer' AND id NOT IN (v_e1, v_e2) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_e4 FROM public.profiles WHERE role='engineer' AND id NOT IN (v_e1, v_e2, v_e3) ORDER BY created_at ASC LIMIT 1;

  IF v_e1 IS NULL THEN
    RETURN;
  END IF;
  IF v_e2 IS NULL THEN v_e2 := v_e1; END IF;
  IF v_e3 IS NULL THEN v_e3 := v_e1; END IF;
  IF v_e4 IS NULL THEN v_e4 := v_e1; END IF;

  INSERT INTO public.engineer_kb_articles_r2446
    (engineer_user_id, title, equipment_kind, article_kind, published_at, view_count, thumbs_up_count, thumbs_down_count, peer_reuse_count, status, notes)
  VALUES
    (v_e1, 'Ventilator PEEP valve calibration step-by-step', 'ventilator', 'calibration', '2026-06-01T10:00:00+05:30'::timestamptz, 412, 47, 2, 18, 'featured', 'Most-reused calibration guide of the month'),
    (v_e1, 'Dental chair compressor relay swap', 'dental_chair', 'parts_swap', '2026-06-05T11:00:00+05:30'::timestamptz, 188, 22, 1, 9, 'published', NULL),
    (v_e2, 'Ultrasound probe disinfection safety protocol', 'ultrasound', 'safety_protocol', '2026-06-08T09:30:00+05:30'::timestamptz, 267, 33, 0, 14, 'featured', 'Cited in NABH audit prep'),
    (v_e2, 'X-ray generator install checklist v2', 'xray', 'install_guide', '2026-06-12T15:00:00+05:30'::timestamptz, 121, 14, 3, 5, 'published', NULL),
    (v_e3, 'Defib pad sensor troubleshooting tree', 'defibrillator', 'troubleshooting', '2026-06-14T18:00:00+05:30'::timestamptz, 95, 11, 0, 4, 'published', NULL),
    (v_e3, 'Anesthesia machine vaporizer leak diagnosis', 'anesthesia', 'troubleshooting', NULL, 0, 0, 0, 0, 'draft', 'In review by senior engineer'),
    (v_e4, 'Patient monitor SpO2 sensor parts swap', 'patient_monitor', 'parts_swap', '2026-05-20T14:00:00+05:30'::timestamptz, 88, 9, 1, 3, 'retired', 'Superseded by OEM bulletin');

  INSERT INTO public.kb_contribution_recognition_r2446
    (engineer_user_id, period_start, period_end, articles_published, total_views, total_thumbs_up, total_peer_reuse, recognition_kind, bonus_rupees, awarded_at, awarded_by_email, notes)
  VALUES
    (v_e1, '2026-06-01'::date, '2026-06-30'::date, 2, 600, 69, 27, 'monthly_award', 5000, '2026-06-21T11:00:00+05:30'::timestamptz, 'founder@equipseva.in', 'Top contributor June'),
    (v_e2, '2026-06-01'::date, '2026-06-30'::date, 2, 388, 47, 19, 'spot_bonus', 2000, '2026-06-20T10:00:00+05:30'::timestamptz, 'founder@equipseva.in', 'Safety protocol cited in NABH'),
    (v_e3, '2026-06-01'::date, '2026-06-30'::date, 1, 95, 11, 4, 'none', 0, NULL, NULL, 'Below threshold this month'),
    (v_e1, '2026-04-01'::date, '2026-06-30'::date, 4, 980, 110, 41, 'quarterly_award', 15000, '2026-06-22T12:00:00+05:30'::timestamptz, 'founder@equipseva.in', 'Q2 KB champion'),
    (v_e4, '2026-05-01'::date, '2026-05-31'::date, 1, 88, 9, 3, 'none', 0, NULL, NULL, 'Article retired post-period');
END $$;

-- RPC 1: list_articles_r2446
CREATE OR REPLACE FUNCTION public.list_articles_r2446()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  title text,
  equipment_kind text,
  article_kind text,
  published_at timestamptz,
  view_count int,
  thumbs_up_count int,
  thumbs_down_count int,
  peer_reuse_count int,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, p.email, a.title, a.equipment_kind, a.article_kind,
         a.published_at, a.view_count, a.thumbs_up_count, a.thumbs_down_count,
         a.peer_reuse_count, a.status, a.notes
  FROM public.engineer_kb_articles_r2446 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
  ORDER BY COALESCE(a.published_at, a.created_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_articles_r2446() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_articles_r2446() TO authenticated;

-- RPC 2: list_recognition_r2446
CREATE OR REPLACE FUNCTION public.list_recognition_r2446()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  period_start date,
  period_end date,
  articles_published int,
  total_views int,
  total_thumbs_up int,
  total_peer_reuse int,
  recognition_kind text,
  bonus_rupees int,
  awarded_at timestamptz,
  awarded_by_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, p.email, r.period_start, r.period_end,
         r.articles_published, r.total_views, r.total_thumbs_up, r.total_peer_reuse,
         r.recognition_kind, r.bonus_rupees, r.awarded_at, r.awarded_by_email, r.notes
  FROM public.kb_contribution_recognition_r2446 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY r.period_start DESC, r.bonus_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recognition_r2446() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recognition_r2446() TO authenticated;

-- RPC 3: top_authors_r2446
CREATE OR REPLACE FUNCTION public.top_authors_r2446()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  articles_count bigint,
  published_count bigint,
  featured_count bigint,
  total_views bigint,
  total_thumbs_up bigint,
  total_peer_reuse bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_user_id,
         p.email,
         count(*)::bigint AS articles_count,
         count(*) FILTER (WHERE a.status IN ('published','featured'))::bigint AS published_count,
         count(*) FILTER (WHERE a.status = 'featured')::bigint AS featured_count,
         COALESCE(sum(a.view_count),0)::bigint AS total_views,
         COALESCE(sum(a.thumbs_up_count),0)::bigint AS total_thumbs_up,
         COALESCE(sum(a.peer_reuse_count),0)::bigint AS total_peer_reuse
  FROM public.engineer_kb_articles_r2446 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
  GROUP BY a.engineer_user_id, p.email
  ORDER BY total_peer_reuse DESC, total_views DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_authors_r2446() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_authors_r2446() TO authenticated;

-- RPC 4: monthly_publishing_trend_r2446
CREATE OR REPLACE FUNCTION public.monthly_publishing_trend_r2446()
RETURNS TABLE (
  month_start date,
  articles_published bigint,
  total_views bigint,
  total_thumbs_up bigint,
  total_peer_reuse bigint,
  featured_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', a.published_at)::date AS month_start,
         count(*)::bigint AS articles_published,
         COALESCE(sum(a.view_count),0)::bigint AS total_views,
         COALESCE(sum(a.thumbs_up_count),0)::bigint AS total_thumbs_up,
         COALESCE(sum(a.peer_reuse_count),0)::bigint AS total_peer_reuse,
         count(*) FILTER (WHERE a.status = 'featured')::bigint AS featured_count
  FROM public.engineer_kb_articles_r2446 a
  WHERE a.published_at IS NOT NULL
  GROUP BY date_trunc('month', a.published_at)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_publishing_trend_r2446() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_publishing_trend_r2446() TO authenticated;

-- RPC 5: article_kind_breakdown_r2446
CREATE OR REPLACE FUNCTION public.article_kind_breakdown_r2446()
RETURNS TABLE (
  article_kind text,
  articles_count bigint,
  total_views bigint,
  total_thumbs_up bigint,
  total_thumbs_down bigint,
  total_peer_reuse bigint,
  avg_views numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.article_kind,
         count(*)::bigint AS articles_count,
         COALESCE(sum(a.view_count),0)::bigint AS total_views,
         COALESCE(sum(a.thumbs_up_count),0)::bigint AS total_thumbs_up,
         COALESCE(sum(a.thumbs_down_count),0)::bigint AS total_thumbs_down,
         COALESCE(sum(a.peer_reuse_count),0)::bigint AS total_peer_reuse,
         ROUND(AVG(a.view_count)::numeric, 1) AS avg_views
  FROM public.engineer_kb_articles_r2446 a
  GROUP BY a.article_kind
  ORDER BY total_peer_reuse DESC, total_views DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.article_kind_breakdown_r2446() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.article_kind_breakdown_r2446() TO authenticated;

-- RPC 6: recognition_pipeline_r2446
CREATE OR REPLACE FUNCTION public.recognition_pipeline_r2446()
RETURNS TABLE (
  recognition_kind text,
  awards_count bigint,
  total_bonus_rupees bigint,
  total_articles bigint,
  total_views bigint,
  total_peer_reuse bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.recognition_kind,
         count(*)::bigint AS awards_count,
         COALESCE(sum(r.bonus_rupees),0)::bigint AS total_bonus_rupees,
         COALESCE(sum(r.articles_published),0)::bigint AS total_articles,
         COALESCE(sum(r.total_views),0)::bigint AS total_views,
         COALESCE(sum(r.total_peer_reuse),0)::bigint AS total_peer_reuse
  FROM public.kb_contribution_recognition_r2446 r
  GROUP BY r.recognition_kind
  ORDER BY total_bonus_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recognition_pipeline_r2446() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recognition_pipeline_r2446() TO authenticated;

-- RPC 7: top_viewed_articles_r2446
CREATE OR REPLACE FUNCTION public.top_viewed_articles_r2446()
RETURNS TABLE (
  id uuid,
  title text,
  engineer_email text,
  equipment_kind text,
  article_kind text,
  status text,
  view_count int,
  thumbs_up_count int,
  peer_reuse_count int,
  published_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.title, p.email, a.equipment_kind, a.article_kind, a.status,
         a.view_count, a.thumbs_up_count, a.peer_reuse_count, a.published_at
  FROM public.engineer_kb_articles_r2446 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
  WHERE a.status IN ('published','featured')
  ORDER BY a.view_count DESC, a.peer_reuse_count DESC
  LIMIT 15;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_viewed_articles_r2446() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_viewed_articles_r2446() TO authenticated;
