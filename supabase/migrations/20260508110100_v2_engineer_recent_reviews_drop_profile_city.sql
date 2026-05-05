-- Hotfix on top of 20260508110000: profiles.city was removed in an
-- earlier schema/security sweep, but both the original 20260503110000
-- RPC and the just-shipped 20260508110000 RPC still reference it.
-- The original survived because it was never exercised in prod with a
-- hospital that had a NULL org. Calling the new RPC blows up at parse
-- time with 42703.
--
-- Recreate engineer_recent_reviews(uuid, int) without the p.city
-- fallback. Hospital city now resolves to org.city only (empty string
-- if hospital has no org). All other behaviour unchanged.

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
