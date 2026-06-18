BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_loyalty_funnel();
CREATE OR REPLACE FUNCTION public.founder_hospital_loyalty_funnel()
RETURNS TABLE (
  stage      text,
  cnt        bigint,
  pct_signup numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_signed     bigint;
  v_first_job  bigint;
  v_first_done bigint;
  v_amc        bigint;
  v_five_done  bigint;
  v_ten_done   bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_signed
    FROM public.profiles WHERE role = 'hospital';

  SELECT count(DISTINCT rj.hospital_user_id)::bigint INTO v_first_job
    FROM public.repair_jobs rj;

  SELECT count(DISTINCT rj.hospital_user_id)::bigint INTO v_first_done
    FROM public.repair_jobs rj WHERE rj.status = 'completed';

  SELECT count(DISTINCT c.hospital_user_id)::bigint INTO v_amc
    FROM public.amc_contracts c WHERE c.status = 'active';

  WITH per_hosp AS (
    SELECT rj.hospital_user_id, count(*) AS jobs
    FROM public.repair_jobs rj WHERE rj.status = 'completed'
    GROUP BY rj.hospital_user_id
  )
  SELECT
    count(*) FILTER (WHERE jobs >= 5)::bigint,
    count(*) FILTER (WHERE jobs >= 10)::bigint
  INTO v_five_done, v_ten_done
  FROM per_hosp;

  RETURN QUERY
  SELECT t.stage, t.c,
    CASE WHEN v_signed = 0 THEN 0::numeric
         ELSE round((t.c::numeric / v_signed::numeric) * 100.0, 1)
    END
  FROM (VALUES
    ('1. signed up'::text,            v_signed,     1),
    ('2. posted first job',           v_first_job,  2),
    ('3. completed first job',        v_first_done, 3),
    ('4. active AMC',                 v_amc,        4),
    ('5. completed 5+ jobs',          v_five_done,  5),
    ('6. completed 10+ jobs (loyal)', v_ten_done,   6)
  ) AS t(stage, c, ord)
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_loyalty_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_loyalty_funnel() TO authenticated;
COMMIT;
