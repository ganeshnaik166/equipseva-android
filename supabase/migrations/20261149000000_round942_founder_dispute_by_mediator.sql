BEGIN;
DROP FUNCTION IF EXISTS public.founder_dispute_by_mediator();
CREATE OR REPLACE FUNCTION public.founder_dispute_by_mediator()
RETURNS TABLE (
  mediator_user_id  uuid,
  mediator_name     text,
  decisions_90d     bigint,
  accepted          bigint,
  rejected          bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    d.mediator_user_id,
    coalesce(p.full_name, '(mediator)'),
    count(*)::bigint,
    count(*) FILTER (WHERE d.status = 'accepted')::bigint,
    count(*) FILTER (WHERE d.status = 'rejected')::bigint
  FROM public.dispute_evidence_packs d
  LEFT JOIN public.profiles p ON p.id = d.mediator_user_id
  WHERE d.mediator_decision_at >= now() - interval '90 days'
    AND d.mediator_user_id IS NOT NULL
  GROUP BY d.mediator_user_id, p.full_name
  ORDER BY decisions_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_dispute_by_mediator() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dispute_by_mediator() TO authenticated;
COMMIT;
