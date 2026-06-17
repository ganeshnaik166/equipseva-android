-- Round 838 — Fix payout amount column references + ship /payouts-failed-list.
--
-- engineer_payouts stores amount in paise (amount_paise bigint), not rupees.
-- r809/r815/r833 mistakenly referenced p.amount_rupees which doesn't exist
-- on this table. Recreating those RPCs to use round(amount_paise/100.0,2)
-- matches the canonical pattern in r686/r726.
BEGIN;

------------------------------------------------------------------
-- r809 fix — pending payouts aging (sum/oldest using amount_paise)
------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_pending_payouts_aging();
CREATE OR REPLACE FUNCTION public.founder_pending_payouts_aging()
RETURNS TABLE (
  bucket         text,
  cnt            bigint,
  rupees_sum     numeric,
  oldest_hours   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      round(p.amount_paise::numeric / 100.0, 2) AS amount_rupees,
      p.queued_at,
      extract(epoch FROM (now() - p.queued_at)) / 3600.0 AS hours_old
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued','processing')
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('< 1h'::text,   1, 0::numeric,    1::numeric),
      ('1-6h',         2, 1::numeric,    6::numeric),
      ('6-24h',        3, 6::numeric,   24::numeric),
      ('1-3d',         4, 24::numeric,  72::numeric),
      ('3-7d',         5, 72::numeric, 168::numeric),
      ('>7d',          6, 168::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE base.hours_old >= b.lo AND base.hours_old < b.hi)::bigint,
    coalesce(sum(base.amount_rupees) FILTER (WHERE base.hours_old >= b.lo AND base.hours_old < b.hi), 0)::numeric,
    coalesce(max(base.hours_old) FILTER (WHERE base.hours_old >= b.lo AND base.hours_old < b.hi), 0)::numeric
  FROM buckets b LEFT JOIN base ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pending_payouts_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pending_payouts_aging() TO authenticated;

------------------------------------------------------------------
-- r815 fix — payouts by bank
------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payouts_by_bank();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_bank()
RETURNS TABLE (
  bank_name      text,
  processed      bigint,
  failed         bigint,
  paid_rupees    numeric,
  fail_pct       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(m.bank_name, ''), '(no bank / VPA)') AS bank_name,
      p.status,
      round(p.amount_paise::numeric / 100.0, 2) AS amount_rupees
    FROM public.engineer_payouts p
    LEFT JOIN public.engineer_payout_methods m ON m.id = p.payout_method_id
    WHERE p.queued_at >= now() - interval '90 days'
      AND p.status IN ('processed','failed')
  )
  SELECT
    b.bank_name,
    count(*) FILTER (WHERE b.status = 'processed')::bigint,
    count(*) FILTER (WHERE b.status = 'failed')::bigint,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status = 'processed'), 0)::numeric,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(count(*) FILTER (WHERE b.status = 'failed')::numeric
                    / count(*)::numeric * 100.0, 1)
    END
  FROM base b
  GROUP BY b.bank_name
  ORDER BY (count(*) FILTER (WHERE b.status = 'processed') + count(*) FILTER (WHERE b.status = 'failed')) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_bank() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_bank() TO authenticated;

------------------------------------------------------------------
-- r833 fix — payouts by engineer tier
------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payouts_by_engineer_tier();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_engineer_tier()
RETURNS TABLE (
  tier              text,
  payouts_90d       bigint,
  rupees_90d        numeric,
  engineers         bigint,
  avg_per_engineer  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers(tier, ord) AS (
    VALUES ('none'::text, 1), ('bronze'::text, 2), ('silver'::text, 3), ('gold'::text, 4)
  ),
  per_tier AS (
    SELECT
      coalesce(ecp.current_tier, 'none') AS tier,
      round(p.amount_paise::numeric / 100.0, 2) AS amount_rupees,
      p.engineer_user_id
    FROM public.engineer_payouts p
    LEFT JOIN public.engineer_certification_progress ecp ON ecp.user_id = p.engineer_user_id
    WHERE p.status = 'processed'
      AND p.queued_at >= now() - interval '90 days'
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM per_tier pt WHERE pt.tier = t.tier), 0)::bigint,
    coalesce((SELECT sum(pt.amount_rupees)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 0)::numeric,
    coalesce((SELECT count(DISTINCT pt.engineer_user_id)::bigint FROM per_tier pt WHERE pt.tier = t.tier), 0)::bigint,
    CASE WHEN coalesce((SELECT count(DISTINCT pt.engineer_user_id) FROM per_tier pt WHERE pt.tier = t.tier), 0) = 0 THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(pt.amount_rupees)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 0)
           / coalesce((SELECT count(DISTINCT pt.engineer_user_id)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 1)
         , 2)
    END
  FROM tiers t
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_engineer_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_engineer_tier() TO authenticated;

------------------------------------------------------------------
-- r837 fix — pending payouts list (amount_paise → rupees)
------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payouts_pending_list();
CREATE OR REPLACE FUNCTION public.founder_payouts_pending_list()
RETURNS TABLE (
  payout_id          uuid,
  engineer_user_id   uuid,
  display_name       text,
  amount_rupees      numeric,
  queued_at          timestamptz,
  hours_old          numeric,
  has_method         boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.engineer_user_id,
    coalesce(pr.full_name, '(engineer)'),
    round(p.amount_paise::numeric / 100.0, 2),
    p.queued_at,
    round(extract(epoch FROM (now() - p.queued_at)) / 3600.0, 1)::numeric,
    (p.payout_method_id IS NOT NULL)
  FROM public.engineer_payouts p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.status IN ('queued','processing')
  ORDER BY p.queued_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_pending_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_pending_list() TO authenticated;

------------------------------------------------------------------
-- r838 — /payouts-failed-list
------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payouts_failed_list();
CREATE OR REPLACE FUNCTION public.founder_payouts_failed_list()
RETURNS TABLE (
  payout_id          uuid,
  engineer_user_id   uuid,
  display_name       text,
  amount_rupees      numeric,
  queued_at          timestamptz,
  processed_at       timestamptz,
  failure_reason     text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.engineer_user_id,
    coalesce(pr.full_name, '(engineer)'),
    round(p.amount_paise::numeric / 100.0, 2),
    p.queued_at,
    p.processed_at,
    coalesce(p.failure_reason, p.razorpayx_status)
  FROM public.engineer_payouts p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.status = 'failed'
    AND p.queued_at >= now() - interval '30 days'
  ORDER BY p.queued_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_failed_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_failed_list() TO authenticated;

COMMIT;
