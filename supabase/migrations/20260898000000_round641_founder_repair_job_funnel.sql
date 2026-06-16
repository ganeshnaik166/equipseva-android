BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_job_funnel();
CREATE OR REPLACE FUNCTION public.founder_repair_job_funnel()
RETURNS TABLE (
  stage      text,
  cnt        bigint,
  pct_posted numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_cutoff timestamptz := now() - interval '30 days';
  v_posted bigint;
  v_bidded bigint;
  v_accepted bigint;
  v_in_progress bigint;
  v_completed bigint;
  v_cancelled bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_posted
    FROM public.repair_jobs rj WHERE rj.created_at >= v_cutoff;

  SELECT count(DISTINCT rj.id)::bigint INTO v_bidded
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id
    WHERE rj.created_at >= v_cutoff;

  SELECT count(DISTINCT rj.id)::bigint INTO v_accepted
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE rj.created_at >= v_cutoff;

  SELECT count(*)::bigint INTO v_in_progress
    FROM public.repair_jobs rj
    WHERE rj.created_at >= v_cutoff AND rj.status = 'in_progress';

  SELECT count(*)::bigint INTO v_completed
    FROM public.repair_jobs rj
    WHERE rj.created_at >= v_cutoff AND rj.status = 'completed';

  SELECT count(*)::bigint INTO v_cancelled
    FROM public.repair_jobs rj
    WHERE rj.created_at >= v_cutoff AND rj.status = 'cancelled';

  RETURN QUERY
  SELECT t.stage, t.c::bigint,
    CASE WHEN v_posted = 0 THEN 0::numeric
         ELSE round((t.c::numeric / v_posted::numeric) * 100.0, 1)
    END
  FROM (VALUES
    ('1. posted'::text,        v_posted,      1),
    ('2. received a bid'::text, v_bidded,     2),
    ('3. bid accepted'::text,   v_accepted,   3),
    ('4. in progress'::text,    v_in_progress, 4),
    ('5. completed'::text,      v_completed,  5),
    ('X. cancelled'::text,      v_cancelled,  6)
  ) AS t(stage, c, ord)
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_job_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_job_funnel() TO authenticated;
COMMIT;
