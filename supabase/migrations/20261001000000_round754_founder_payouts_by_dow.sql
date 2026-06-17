BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_by_day_of_week();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_day_of_week()
RETURNS TABLE (
  dow_num   int,
  dow_label text,
  paid      bigint,
  failed    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days(num, label) AS (
    VALUES (0, 'Sun'::text), (1, 'Mon'), (2, 'Tue'), (3, 'Wed'),
           (4, 'Thu'), (5, 'Fri'), (6, 'Sat')
  )
  SELECT
    d.num,
    d.label,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_payouts p
       WHERE p.queued_at >= now() - interval '90 days' AND p.status = 'processed'
         AND extract(dow FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = d.num
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_payouts p
       WHERE p.queued_at >= now() - interval '90 days' AND p.status = 'failed'
         AND extract(dow FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = d.num
      ), 0)::bigint
  FROM days d
  ORDER BY d.num;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_day_of_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_day_of_week() TO authenticated;
COMMIT;
