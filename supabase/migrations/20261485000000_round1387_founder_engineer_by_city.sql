BEGIN;
-- r1387 — /founder-engineer-by-city — engineer productivity grouped by city.
-- City derivation: COALESCE(profile.org.city, last completed repair_job hospital_org.city).
-- Metros (case-insensitive): hyderabad, bangalore, chennai, mumbai, delhi, pune, kolkata, ahmedabad.

DROP FUNCTION IF EXISTS public.founder_engineer_by_city_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_by_city_summary()
RETURNS TABLE (
  total_active_engineers       bigint,
  total_cities_with_engineers  bigint,
  top_city_name                text,
  top_city_engineer_count      int,
  second_city_name             text,
  jobs_completed_30d_total     int,
  avg_jobs_per_engineer_30d    numeric,
  metro_engineer_count         bigint,
  non_metro_engineer_count     bigint,
  generated_at                 timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_city text;
  v_top_count int;
  v_second_city text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  WITH eng_city AS (
    SELECT
      e.id AS engineer_id,
      e.user_id,
      COALESCE(
        NULLIF(lower(trim(org_p.city)), ''),
        NULLIF(lower(trim((
          SELECT org_j.city
          FROM public.repair_jobs rj
          LEFT JOIN public.organizations org_j ON org_j.id = rj.hospital_org_id
          WHERE rj.engineer_id = e.id AND rj.status = 'completed'
          ORDER BY rj.completed_at DESC NULLS LAST
          LIMIT 1
        ))), '')
      ) AS city_key,
      COALESCE(
        NULLIF(trim(org_p.city), ''),
        NULLIF(trim((
          SELECT org_j.city
          FROM public.repair_jobs rj
          LEFT JOIN public.organizations org_j ON org_j.id = rj.hospital_org_id
          WHERE rj.engineer_id = e.id AND rj.status = 'completed'
          ORDER BY rj.completed_at DESC NULLS LAST
          LIMIT 1
        )), '')
      ) AS city_display,
      (SELECT count(*) FROM public.repair_jobs rj
        WHERE rj.engineer_id = e.id AND rj.status = 'completed'
          AND rj.completed_at >= now() - interval '30 days')::int AS jobs_30d
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
    LEFT JOIN public.organizations org_p ON org_p.id = p.organization_id
    WHERE e.verification_status::text = 'verified'
  ),
  city_agg AS (
    SELECT city_key, max(city_display) AS city_display, count(*)::int AS engineer_count
    FROM eng_city
    WHERE city_key IS NOT NULL
    GROUP BY city_key
  ),
  top_two AS (
    SELECT city_display, engineer_count,
           row_number() OVER (ORDER BY engineer_count DESC, city_display ASC) AS rk
    FROM city_agg
  )
  SELECT
    (SELECT count(*) FROM eng_city)::bigint,
    (SELECT count(*) FROM city_agg)::bigint,
    (SELECT city_display FROM top_two WHERE rk = 1),
    COALESCE((SELECT engineer_count FROM top_two WHERE rk = 1), 0),
    (SELECT city_display FROM top_two WHERE rk = 2),
    COALESCE((SELECT sum(jobs_30d)::int FROM eng_city), 0),
    COALESCE((SELECT round(avg(jobs_30d)::numeric, 2) FROM eng_city), 0)::numeric,
    (SELECT count(*) FROM eng_city
      WHERE city_key IN ('hyderabad','bangalore','chennai','mumbai','delhi','pune','kolkata','ahmedabad'))::bigint,
    (SELECT count(*) FROM eng_city
      WHERE city_key IS NULL
         OR city_key NOT IN ('hyderabad','bangalore','chennai','mumbai','delhi','pune','kolkata','ahmedabad'))::bigint,
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_by_city_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_by_city_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_by_city_breakdown(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_by_city_breakdown(p_limit int DEFAULT 50)
RETURNS TABLE (
  city                       text,
  state                      text,
  engineer_count             int,
  jobs_completed_30d         int,
  jobs_completed_90d         int,
  avg_jobs_per_engineer_30d  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH eng_city AS (
    SELECT
      e.id AS engineer_id,
      COALESCE(
        NULLIF(lower(trim(org_p.city)), ''),
        NULLIF(lower(trim((
          SELECT org_j.city
          FROM public.repair_jobs rj
          LEFT JOIN public.organizations org_j ON org_j.id = rj.hospital_org_id
          WHERE rj.engineer_id = e.id AND rj.status = 'completed'
          ORDER BY rj.completed_at DESC NULLS LAST
          LIMIT 1
        ))), '')
      ) AS city_key,
      COALESCE(
        NULLIF(trim(org_p.city), ''),
        NULLIF(trim((
          SELECT org_j.city
          FROM public.repair_jobs rj
          LEFT JOIN public.organizations org_j ON org_j.id = rj.hospital_org_id
          WHERE rj.engineer_id = e.id AND rj.status = 'completed'
          ORDER BY rj.completed_at DESC NULLS LAST
          LIMIT 1
        )), '')
      ) AS city_display,
      COALESCE(NULLIF(trim(org_p.state), ''), '') AS state_display,
      (SELECT count(*) FROM public.repair_jobs rj
        WHERE rj.engineer_id = e.id AND rj.status = 'completed'
          AND rj.completed_at >= now() - interval '30 days')::int AS jobs_30d,
      (SELECT count(*) FROM public.repair_jobs rj
        WHERE rj.engineer_id = e.id AND rj.status = 'completed'
          AND rj.completed_at >= now() - interval '90 days')::int AS jobs_90d
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
    LEFT JOIN public.organizations org_p ON org_p.id = p.organization_id
    WHERE e.verification_status::text = 'verified'
  )
  SELECT
    max(ec.city_display)::text,
    max(NULLIF(ec.state_display, ''))::text,
    count(*)::int,
    COALESCE(sum(ec.jobs_30d), 0)::int,
    COALESCE(sum(ec.jobs_90d), 0)::int,
    CASE WHEN count(*) > 0
         THEN round(sum(ec.jobs_30d)::numeric / count(*)::numeric, 2)
         ELSE 0 END
  FROM eng_city ec
  WHERE ec.city_key IS NOT NULL
  GROUP BY ec.city_key
  ORDER BY count(*) DESC, max(ec.city_display) ASC
  LIMIT greatest(1, least(COALESCE(p_limit, 50), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_by_city_breakdown(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_by_city_breakdown(int) TO authenticated;

COMMIT;