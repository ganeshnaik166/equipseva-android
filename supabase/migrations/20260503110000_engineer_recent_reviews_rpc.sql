-- Returns the most recent N completed jobs where a hospital left a
-- non-null review text for the given engineer. Used by the
-- EngineerPublicProfile screen to show a "Recent reviews" section
-- alongside the rating card. Privacy guard: we only return city — never
-- hospital_user_id, organization_id, organization name, or any contact
-- info. The hospital that left the review stays anonymous to other
-- hospitals browsing the directory.
--
-- Falls back to organizations.city when hospital_org_id is set, otherwise
-- pulls from the hospital's profile.city. SECURITY DEFINER because
-- profiles.city is RLS-restricted to self after the
-- 20260428110000_security_profiles_select_self_only sweep.

CREATE OR REPLACE FUNCTION public.engineer_recent_reviews(
  p_engineer_id uuid,
  p_limit int DEFAULT 10
)
RETURNS TABLE (
  rating int,
  review text,
  completed_at timestamptz,
  hospital_city text
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
    rj.hospital_review                  AS review,
    rj.completed_at                     AS completed_at,
    COALESCE(o.city, p.city, '')        AS hospital_city
  FROM public.repair_jobs rj
  LEFT JOIN public.organizations o ON o.id = rj.hospital_org_id
  LEFT JOIN public.profiles      p ON p.id = rj.hospital_user_id
  WHERE rj.engineer_id = p_engineer_id
    AND rj.status::text = 'completed'
    AND rj.hospital_review IS NOT NULL
    AND char_length(trim(rj.hospital_review)) > 0
  ORDER BY rj.completed_at DESC NULLS LAST
  LIMIT v_limit;
END;
$$;

ALTER FUNCTION public.engineer_recent_reviews(uuid, int) OWNER TO postgres;

REVOKE EXECUTE ON FUNCTION public.engineer_recent_reviews(uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.engineer_recent_reviews(uuid, int) TO authenticated;
