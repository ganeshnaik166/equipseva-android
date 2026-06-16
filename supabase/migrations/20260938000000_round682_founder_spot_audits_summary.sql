BEGIN;
DROP FUNCTION IF EXISTS public.founder_spot_audits_summary();
CREATE OR REPLACE FUNCTION public.founder_spot_audits_summary()
RETURNS TABLE (
  window_label  text,
  invitations   bigint,
  responses     bigint,
  response_pct  numeric,
  avg_rating    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_invitations i WHERE i.created_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_responses r WHERE r.responded_at >= w.cutoff), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*)::bigint FROM public.spot_audit_invitations i WHERE i.created_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.spot_audit_responses r WHERE r.responded_at >= w.cutoff)
           / (SELECT count(*)::numeric FROM public.spot_audit_invitations i WHERE i.created_at >= w.cutoff) * 100.0,
         1)
    END,
    coalesce((SELECT round(avg(r.rating)::numeric, 2) FROM public.spot_audit_responses r WHERE r.responded_at >= w.cutoff), 0)
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spot_audits_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audits_summary() TO authenticated;
COMMIT;
