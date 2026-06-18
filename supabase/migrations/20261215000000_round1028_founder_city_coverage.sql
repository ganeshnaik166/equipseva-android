BEGIN;
DROP FUNCTION IF EXISTS public.founder_city_coverage();
CREATE OR REPLACE FUNCTION public.founder_city_coverage()
RETURNS TABLE (
  city                text,
  engineers_total     bigint,
  engineers_verified  bigint,
  hospitals_total     bigint,
  jobs_90d            bigint,
  amcs_active         bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH eng_cities AS (
    SELECT coalesce(nullif(trim(e.city), ''), '(unknown)')::text AS city,
           count(*)::bigint AS total,
           count(*) FILTER (WHERE e.verification_status = 'verified')::bigint AS verified
    FROM public.engineers e
    GROUP BY coalesce(nullif(trim(e.city), ''), '(unknown)')
  ),
  hosp_cities AS (
    SELECT coalesce(nullif(trim(p.city), ''), '(unknown)')::text AS city,
           count(*)::bigint AS total
    FROM public.profiles p
    WHERE p.role = 'hospital'
    GROUP BY coalesce(nullif(trim(p.city), ''), '(unknown)')
  ),
  job_cities AS (
    SELECT coalesce(nullif(trim(p.city), ''), '(unknown)')::text AS city,
           count(*)::bigint AS cnt
    FROM public.repair_jobs j
    JOIN public.profiles p ON p.id = j.hospital_user_id
    WHERE j.created_at >= now() - interval '90 days'
    GROUP BY coalesce(nullif(trim(p.city), ''), '(unknown)')
  ),
  all_cities AS (
    SELECT city FROM eng_cities
    UNION
    SELECT city FROM hosp_cities
    UNION
    SELECT city FROM job_cities
  )
  SELECT
    ac.city,
    coalesce(ec.total, 0)::bigint               AS engineers_total,
    coalesce(ec.verified, 0)::bigint            AS engineers_verified,
    coalesce(hc.total, 0)::bigint               AS hospitals_total,
    coalesce(jc.cnt, 0)::bigint                 AS jobs_90d,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              JOIN public.profiles p ON p.id = c.hospital_user_id
              WHERE c.status = 'active'
                AND coalesce(nullif(trim(p.city), ''), '(unknown)') = ac.city), 0)::bigint AS amcs_active
  FROM all_cities ac
  LEFT JOIN eng_cities ec ON ec.city = ac.city
  LEFT JOIN hosp_cities hc ON hc.city = ac.city
  LEFT JOIN job_cities jc ON jc.city = ac.city
  ORDER BY (coalesce(ec.total,0) + coalesce(hc.total,0) + coalesce(jc.cnt,0)) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_city_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_city_coverage() TO authenticated;
COMMIT;
