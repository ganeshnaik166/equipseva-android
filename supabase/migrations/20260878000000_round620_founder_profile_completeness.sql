BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_profile_completeness();
CREATE OR REPLACE FUNCTION public.founder_engineer_profile_completeness()
RETURNS TABLE (
  total_engineers  bigint,
  with_bio         bigint,
  with_rate        bigint,
  with_city        bigint,
  with_specs       bigint,
  with_phone       bigint,
  with_avatar      bigint,
  fully_complete   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint                                              AS total_engineers,
    count(*) FILTER (WHERE coalesce(trim(e.bio), '') <> '')::bigint AS with_bio,
    count(*) FILTER (WHERE e.hourly_rate IS NOT NULL AND e.hourly_rate > 0)::bigint AS with_rate,
    count(*) FILTER (WHERE coalesce(trim(e.city), '') <> '')::bigint AS with_city,
    count(*) FILTER (WHERE e.specializations IS NOT NULL AND array_length(e.specializations, 1) > 0)::bigint AS with_specs,
    count(*) FILTER (WHERE coalesce(trim(p.phone), '') <> '')::bigint AS with_phone,
    count(*) FILTER (WHERE coalesce(trim(p.avatar_url), '') <> '')::bigint AS with_avatar,
    count(*) FILTER (WHERE
      coalesce(trim(e.bio), '') <> '' AND e.hourly_rate > 0
      AND coalesce(trim(e.city), '') <> ''
      AND e.specializations IS NOT NULL AND array_length(e.specializations, 1) > 0
      AND coalesce(trim(p.phone), '') <> ''
      AND coalesce(trim(p.avatar_url), '') <> ''
    )::bigint                                                     AS fully_complete
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE coalesce(e.verification_status, 'pending') = 'verified';
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_profile_completeness() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_profile_completeness() TO authenticated;
COMMIT;
