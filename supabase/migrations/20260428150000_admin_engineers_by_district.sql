-- Founder zone-density view: returns one row per self-reported area
-- (engineers.city, overloaded as a free-text "service address" since the
-- KYC v2 redesign) with the count of currently-available verified
-- engineers and a representative pin so the founder map can render a
-- single marker per zone.
--
-- Founder-gated via is_founder() so only the pinned admin email can
-- read this. Hospitals don't see zone counts.

CREATE OR REPLACE FUNCTION public.admin_engineers_by_district()
RETURNS TABLE (
  district text,
  engineer_count integer,
  sample_lat double precision,
  sample_lng double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(NULLIF(TRIM(e.city), ''), 'Unspecified') AS district,
    COUNT(*)::int AS engineer_count,
    AVG(e.latitude)  AS sample_lat,
    AVG(e.longitude) AS sample_lng
  FROM public.engineers e
  WHERE e.verification_status = 'verified'
    AND e.is_available = TRUE
  GROUP BY 1
  ORDER BY engineer_count DESC, district ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_engineers_by_district() FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.admin_engineers_by_district() TO authenticated;
