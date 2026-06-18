BEGIN;
DROP FUNCTION IF EXISTS public.founder_state_coverage();
CREATE OR REPLACE FUNCTION public.founder_state_coverage()
RETURNS TABLE (
  state               text,
  engineers_total     bigint,
  engineers_verified  bigint,
  hospitals_total     bigint,
  amcs_active         bigint,
  amcs_active_mrr_inr numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH eng_states AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)')::text AS state,
           count(*)::bigint AS total,
           count(*) FILTER (WHERE e.verification_status = 'verified')::bigint AS verified
    FROM public.engineers e
    JOIN public.profiles p ON p.id = e.user_id
    GROUP BY coalesce(nullif(trim(p.state), ''), '(unknown)')
  ),
  hosp_states AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)')::text AS state,
           count(*)::bigint AS total
    FROM public.profiles p
    WHERE p.role = 'hospital'
    GROUP BY coalesce(nullif(trim(p.state), ''), '(unknown)')
  ),
  amc_states AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)')::text AS state,
           count(*)::bigint AS cnt,
           coalesce(sum(c.amount_inr), 0)::numeric AS mrr
    FROM public.amc_contracts c
    JOIN public.profiles p ON p.id = c.hospital_user_id
    WHERE c.status = 'active'
    GROUP BY coalesce(nullif(trim(p.state), ''), '(unknown)')
  ),
  all_states AS (
    SELECT state FROM eng_states
    UNION
    SELECT state FROM hosp_states
    UNION
    SELECT state FROM amc_states
  )
  SELECT
    a.state,
    coalesce(es.total, 0)::bigint               AS engineers_total,
    coalesce(es.verified, 0)::bigint            AS engineers_verified,
    coalesce(hs.total, 0)::bigint               AS hospitals_total,
    coalesce(amcs.cnt, 0)::bigint               AS amcs_active,
    coalesce(amcs.mrr, 0)::numeric              AS amcs_active_mrr_inr
  FROM all_states a
  LEFT JOIN eng_states es ON es.state = a.state
  LEFT JOIN hosp_states hs ON hs.state = a.state
  LEFT JOIN amc_states amcs ON amcs.state = a.state
  ORDER BY (coalesce(es.total,0) + coalesce(hs.total,0) + coalesce(amcs.cnt,0)) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_state_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_state_coverage() TO authenticated;
COMMIT;
