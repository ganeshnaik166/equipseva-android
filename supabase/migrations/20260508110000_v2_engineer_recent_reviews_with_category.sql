-- v2.1 PR-B: surface equipment category alongside engineer reviews + add
-- a per-category review summary so the public profile can render
-- "5 reviews on Patient Monitoring · 4.9★" pills.
--
-- Two changes:
--   1. DROP + recreate engineer_recent_reviews(uuid, int) to add an
--      equipment_category column (sourced from repair_jobs.equipment_type
--      cast to text — repair_jobs has equipment_type, not "category";
--      it's the equipment_category enum and is the right source).
--   2. NEW engineer_review_summary_by_category(uuid) returning per-
--      category review_count + rating_avg for the same engineer scope.
--
-- Privacy guard from the original RPC is preserved: hospital city only,
-- never hospital_user_id / org_id / contact info. Both functions stay
-- SECURITY DEFINER w/ search_path locked + EXECUTE granted to
-- authenticated + anon (directory is publicly browsable).

DROP FUNCTION IF EXISTS public.engineer_recent_reviews(uuid, int);

CREATE OR REPLACE FUNCTION public.engineer_recent_reviews(
  p_engineer_id uuid,
  p_limit int DEFAULT 10
)
RETURNS TABLE (
  rating int,
  review text,
  completed_at timestamptz,
  hospital_city text,
  equipment_category text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit int := GREATEST(1, LEAST(COALESCE(p_limit, 10), 50));
BEGIN
  -- profiles.city was removed in an earlier security/schema sweep
  -- (the original RPC at 20260503110000 referenced p.city but that
  -- column no longer exists in prod). Fall back to org.city only.
  RETURN QUERY
  SELECT
    rj.hospital_rating::int            AS rating,
    rj.hospital_review                 AS review,
    rj.completed_at                    AS completed_at,
    COALESCE(o.city, '')               AS hospital_city,
    rj.equipment_type::text            AS equipment_category
  FROM public.repair_jobs rj
  LEFT JOIN public.organizations o ON o.id = rj.hospital_org_id
  WHERE rj.engineer_id = p_engineer_id
    AND rj.status::text = 'completed'
    AND rj.hospital_review IS NOT NULL
    AND char_length(trim(rj.hospital_review)) > 0
  ORDER BY rj.completed_at DESC NULLS LAST
  LIMIT v_limit;
END;
$$;

ALTER FUNCTION public.engineer_recent_reviews(uuid, int) OWNER TO postgres;

REVOKE EXECUTE ON FUNCTION public.engineer_recent_reviews(uuid, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_recent_reviews(uuid, int) TO authenticated, anon;


-- Per-category review summary. Used by the public profile to show
-- specialization-anchored social proof: "5 reviews on Patient
-- Monitoring · 4.9★". Aggregates over completed jobs with a non-null
-- hospital_rating.

CREATE OR REPLACE FUNCTION public.engineer_review_summary_by_category(
  p_engineer_id uuid
)
RETURNS TABLE (
  equipment_category text,
  review_count int,
  rating_avg numeric
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT
    rj.equipment_type::text                       AS equipment_category,
    count(*)::int                                 AS review_count,
    round(avg(rj.hospital_rating)::numeric, 2)    AS rating_avg
  FROM public.repair_jobs rj
  WHERE rj.engineer_id = p_engineer_id
    AND rj.status::text = 'completed'
    AND rj.hospital_rating IS NOT NULL
    AND rj.equipment_type IS NOT NULL
  GROUP BY rj.equipment_type
  ORDER BY review_count DESC, rating_avg DESC;
$$;

ALTER FUNCTION public.engineer_review_summary_by_category(uuid) OWNER TO postgres;

REVOKE EXECUTE ON FUNCTION public.engineer_review_summary_by_category(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_review_summary_by_category(uuid) TO authenticated, anon;
