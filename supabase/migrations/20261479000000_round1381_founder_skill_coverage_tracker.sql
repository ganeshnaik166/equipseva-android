BEGIN;
-- r1381 — founder_skill_coverage_tracker
-- Track founder's mental coverage / familiarity with every founder-console surface.
-- Confidence ladder: unknown -> aware -> familiar -> expert -> obsessed.
-- Importance ladder: p0 (must review weekly) -> p1 (monthly) -> p2/p3 (ad-hoc).



-- ============================================================================
-- TABLE founder_skill_coverage
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_skill_coverage (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  surface_href        text NOT NULL UNIQUE,
  surface_label       text NOT NULL,
  surface_kind        text CHECK (surface_kind IN (
                        'cockpit','snapshot','drilldown','tracker',
                        'log','ledger','catalog','retro','roadmap',
                        'public_share','other')),
  confidence_level    text DEFAULT 'unknown' CHECK (confidence_level IN (
                        'unknown','aware','familiar','expert','obsessed')),
  last_reviewed_at    timestamptz,
  reviewed_by         uuid REFERENCES auth.users(id),
  notes               text,
  importance          text DEFAULT 'medium' CHECK (importance IN ('p0','p1','p2','p3')),
  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsc_confidence ON public.founder_skill_coverage(confidence_level);
CREATE INDEX IF NOT EXISTS idx_fsc_importance ON public.founder_skill_coverage(importance);
CREATE INDEX IF NOT EXISTS idx_fsc_reviewed   ON public.founder_skill_coverage(last_reviewed_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_fsc_kind       ON public.founder_skill_coverage(surface_kind);

ALTER TABLE public.founder_skill_coverage ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.founder_skill_coverage FROM PUBLIC, anon;

DROP POLICY IF EXISTS fsc_founder_select ON public.founder_skill_coverage;
CREATE POLICY fsc_founder_select ON public.founder_skill_coverage
  FOR SELECT TO authenticated
  USING (public.is_founder());

-- ============================================================================
-- RPC founder_skill_coverage_summary — 14 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_skill_coverage_summary();
CREATE OR REPLACE FUNCTION public.founder_skill_coverage_summary()
RETURNS TABLE (
  total_surfaces                  bigint,
  unknown_count                   bigint,
  aware_count                     bigint,
  familiar_count                  bigint,
  expert_count                    bigint,
  obsessed_count                  bigint,
  p0_surfaces_count               bigint,
  p0_unknown_count                bigint,
  p0_unfamiliar_count             bigint,
  reviewed_last_7d                bigint,
  reviewed_last_30d               bigint,
  oldest_unreviewed_age_days      int,
  surfaces_with_no_review_lifetime bigint,
  generated_at                    timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_skill_coverage),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE confidence_level = 'unknown'),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE confidence_level = 'aware'),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE confidence_level = 'familiar'),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE confidence_level = 'expert'),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE confidence_level = 'obsessed'),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE importance = 'p0'),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE importance = 'p0' AND confidence_level = 'unknown'),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE importance = 'p0' AND confidence_level IN ('unknown','aware')),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE last_reviewed_at >= now() - interval '7 days'),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE last_reviewed_at >= now() - interval '30 days'),
    (SELECT COALESCE(EXTRACT(DAY FROM now() - MIN(last_reviewed_at))::int, 0)
       FROM public.founder_skill_coverage WHERE last_reviewed_at IS NOT NULL),
    (SELECT count(*) FROM public.founder_skill_coverage WHERE last_reviewed_at IS NULL),
    now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_skill_coverage_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_skill_coverage_summary() TO authenticated;

-- ============================================================================
-- RPC founder_skill_coverage_recent — filtered list
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_skill_coverage_recent(text, text, int);
CREATE OR REPLACE FUNCTION public.founder_skill_coverage_recent(
  p_confidence text DEFAULT NULL,
  p_importance text DEFAULT NULL,
  p_limit      int  DEFAULT 100
)
RETURNS TABLE (
  id                uuid,
  surface_href      text,
  surface_label     text,
  surface_kind      text,
  confidence_level  text,
  importance        text,
  last_reviewed_at  timestamptz,
  days_since_review int,
  notes             text,
  created_at        timestamptz,
  updated_at        timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.surface_href,
    s.surface_label,
    s.surface_kind,
    s.confidence_level,
    s.importance,
    s.last_reviewed_at,
    CASE WHEN s.last_reviewed_at IS NULL
         THEN NULL
         ELSE EXTRACT(DAY FROM now() - s.last_reviewed_at)::int
    END AS days_since_review,
    s.notes,
    s.created_at,
    s.updated_at
  FROM public.founder_skill_coverage s
  WHERE (p_confidence IS NULL OR s.confidence_level = p_confidence)
    AND (p_importance IS NULL OR s.importance       = p_importance)
  ORDER BY
    CASE s.importance WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    CASE s.confidence_level WHEN 'unknown' THEN 0 WHEN 'aware' THEN 1
         WHEN 'familiar' THEN 2 WHEN 'expert' THEN 3 ELSE 4 END,
    s.last_reviewed_at ASC NULLS FIRST,
    s.updated_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_skill_coverage_recent(text, text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_skill_coverage_recent(text, text, int) TO authenticated;

-- ============================================================================
-- RPC log_founder_skill_coverage_register — register a surface
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_skill_coverage_register(text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_skill_coverage_register(
  p_href       text,
  p_label      text,
  p_kind       text,
  p_importance text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_href IS NULL OR p_label IS NULL THEN
    RAISE EXCEPTION 'href and label required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.founder_skill_coverage (surface_href, surface_label, surface_kind, importance)
  VALUES (p_href, p_label, COALESCE(p_kind, 'other'), COALESCE(p_importance, 'medium'))
  ON CONFLICT (surface_href) DO UPDATE
    SET surface_label = EXCLUDED.surface_label,
        surface_kind  = EXCLUDED.surface_kind,
        importance    = EXCLUDED.importance,
        updated_at    = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_skill_coverage_register(text, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_skill_coverage_register(text, text, text, text) TO authenticated;

-- ============================================================================
-- RPC log_founder_skill_coverage_review — record a review event
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_skill_coverage_review(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_skill_coverage_review(
  p_id            uuid,
  p_new_confidence text,
  p_notes         text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_new_confidence NOT IN ('unknown','aware','familiar','expert','obsessed') THEN
    RAISE EXCEPTION 'invalid confidence_level: %', p_new_confidence USING ERRCODE = '22023';
  END IF;

  UPDATE public.founder_skill_coverage
     SET confidence_level = p_new_confidence,
         last_reviewed_at = now(),
         reviewed_by      = auth.uid(),
         notes            = COALESCE(p_notes, notes),
         updated_at       = now()
   WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'surface % not found', p_id USING ERRCODE = 'P0002';
  END IF;

  RETURN p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_skill_coverage_review(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_skill_coverage_review(uuid, text, text) TO authenticated;

COMMIT;