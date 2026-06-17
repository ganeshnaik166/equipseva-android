BEGIN;
DROP FUNCTION IF EXISTS public.founder_bid_vs_contract_spread();
CREATE OR REPLACE FUNCTION public.founder_bid_vs_contract_spread()
RETURNS TABLE (
  window_label   text,
  jobs_count     bigint,
  avg_bid        numeric,
  avg_contracted numeric,
  avg_spread_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH paired AS (
    SELECT
      rj.completed_at,
      b.amount_rupees AS bid_amt,
      rj.contracted_amount_rupees AS final_amt
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE rj.status = 'completed'
      AND b.amount_rupees IS NOT NULL
      AND rj.contracted_amount_rupees IS NOT NULL
      AND b.amount_rupees > 0
  ),
  w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    count(*)::bigint,
    coalesce(round(avg(p.bid_amt)::numeric, 2), 0),
    coalesce(round(avg(p.final_amt)::numeric, 2), 0),
    coalesce(round(avg(((p.final_amt - p.bid_amt) / p.bid_amt) * 100)::numeric, 1), 0)
  FROM w
  LEFT JOIN paired p ON p.completed_at >= w.cutoff
  GROUP BY w.label, w.ord
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bid_vs_contract_spread() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bid_vs_contract_spread() TO authenticated;
COMMIT;
