BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_loyalty_funnel();
CREATE OR REPLACE FUNCTION public.founder_engineer_loyalty_funnel()
RETURNS TABLE (
  stage      text,
  cnt        bigint,
  pct_signup numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_signed     bigint;
  v_verified   bigint;
  v_first_bid  bigint;
  v_first_done bigint;
  v_five_done  bigint;
  v_ten_done   bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_signed FROM public.engineers;

  SELECT count(*)::bigint INTO v_verified
    FROM public.engineers WHERE verification_status = 'verified';

  SELECT count(DISTINCT b.engineer_user_id)::bigint INTO v_first_bid
    FROM public.repair_job_bids b;

  WITH per_eng AS (
    SELECT b.engineer_user_id, count(*) AS jobs
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status='accepted'
    WHERE rj.status='completed'
    GROUP BY b.engineer_user_id
  )
  SELECT
    count(*) FILTER (WHERE jobs >= 1)::bigint,
    count(*) FILTER (WHERE jobs >= 5)::bigint,
    count(*) FILTER (WHERE jobs >= 10)::bigint
  INTO v_first_done, v_five_done, v_ten_done
  FROM per_eng;

  RETURN QUERY
  SELECT t.stage, t.c,
    CASE WHEN v_signed = 0 THEN 0::numeric
         ELSE round((t.c::numeric / v_signed::numeric) * 100.0, 1)
    END
  FROM (VALUES
    ('1. signed up'::text,           v_signed,     1),
    ('2. verified',                   v_verified,   2),
    ('3. placed first bid',           v_first_bid,  3),
    ('4. completed first job',        v_first_done, 4),
    ('5. completed 5+ jobs',          v_five_done,  5),
    ('6. completed 10+ jobs (loyal)', v_ten_done,   6)
  ) AS t(stage, c, ord)
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_loyalty_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_loyalty_funnel() TO authenticated;
COMMIT;
