BEGIN;

-- =====================================================================
-- Round 1233 — /promo-redemptions-summary
-- founder_promo_redemptions_summary
-- CAC visibility: which promo codes firing, ₹ given away, abuse signals.
-- Backed by public.promo_redemptions (round 504).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.founder_promo_redemptions_summary()
RETURNS TABLE(
  promo_code                       text,
  total_redemptions                bigint,
  redeemed_count                   bigint,
  reserved_count                   bigint,
  revoked_count                    bigint,
  expired_count                    bigint,
  unique_hospitals                 bigint,
  total_subsidy_rupees             numeric,
  avg_subsidy_rupees               numeric,
  max_subsidy_rupees               numeric,
  redemptions_last_7d              bigint,
  redemptions_last_30d             bigint,
  subsidy_last_30d_rupees          numeric,
  first_redeemed_at                timestamptz,
  last_redeemed_at                 timestamptz,
  pct_revoked                      numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    pr.promo_code,
    count(*)::bigint                                                 AS total_redemptions,
    count(*) FILTER (WHERE pr.status = 'redeemed')::bigint           AS redeemed_count,
    count(*) FILTER (WHERE pr.status = 'reserved')::bigint           AS reserved_count,
    count(*) FILTER (WHERE pr.status = 'revoked')::bigint            AS revoked_count,
    count(*) FILTER (WHERE pr.status = 'expired')::bigint            AS expired_count,
    count(DISTINCT pr.hospital_user_id)::bigint                      AS unique_hospitals,
    coalesce(sum(pr.amount_subsidized_rupees)
             FILTER (WHERE pr.status = 'redeemed'), 0)::numeric      AS total_subsidy_rupees,
    coalesce(round(avg(pr.amount_subsidized_rupees)
             FILTER (WHERE pr.status = 'redeemed'), 2), 0)::numeric  AS avg_subsidy_rupees,
    coalesce(max(pr.amount_subsidized_rupees)
             FILTER (WHERE pr.status = 'redeemed'), 0)::numeric      AS max_subsidy_rupees,
    count(*) FILTER (WHERE pr.redeemed_at >= now() - interval '7 days')::bigint   AS redemptions_last_7d,
    count(*) FILTER (WHERE pr.redeemed_at >= now() - interval '30 days')::bigint  AS redemptions_last_30d,
    coalesce(sum(pr.amount_subsidized_rupees)
             FILTER (WHERE pr.status = 'redeemed'
                     AND pr.redeemed_at >= now() - interval '30 days'), 0)::numeric AS subsidy_last_30d_rupees,
    min(pr.redeemed_at)                                              AS first_redeemed_at,
    max(pr.redeemed_at)                                              AS last_redeemed_at,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round((count(*) FILTER (WHERE pr.status = 'revoked')::numeric
                     / count(*)::numeric) * 100, 2)
    END                                                              AS pct_revoked
  FROM public.promo_redemptions pr
  GROUP BY pr.promo_code
  ORDER BY total_subsidy_rupees DESC, total_redemptions DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_promo_redemptions_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_promo_redemptions_summary()
  TO authenticated;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'founder_promo_redemptions_summary'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'round 1233: founder_promo_redemptions_summary not created';
  END IF;
  RAISE NOTICE 'round 1233 founder_promo_redemptions_summary verified';
END;
$$;
