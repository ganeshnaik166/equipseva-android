BEGIN;
-- r1361 — Founder acquisition attribution.
--
-- Every hospital that signs an AMC arrived through some sequence of touches:
-- a referral from a friendly chain, a cold outreach call, a trade event, a
-- partner referral, a website form. Without a recorded touch log the founder
-- is flying blind on which channel actually moves the needle — they will
-- over-invest in whatever channel they remember loudest and under-invest in
-- the silent compounders (e.g. content marketing, partner referrals).
--
-- This module is the multi-touch ledger:
--   * one row per touch (kind + label + recorded_by)
--   * 16-KPI summary at the top
--   * per-kind breakdown table (first-touch + last-touch attribution)
--
-- Attribution model is deliberately dual:
--   - first_touch_attribution: which channel SOURCED the lead
--   - last_touch_attribution:  which channel CLOSED the lead
-- Most SaaS dashboards pick one and lie. We show both side-by-side so the
-- founder sees the gap between "got their attention" and "got their signature."

-- ============================================================================
-- Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_acquisition_touchpoints (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  touch_kind      text NOT NULL
                    CHECK (touch_kind IN (
                      'referral','cold_outreach','event','website_form',
                      'phone_inbound','referred_by_chain','partner_referral',
                      'google_ads','linkedin_ads','content_marketing','other'
                    )),
  touched_at      timestamptz NOT NULL DEFAULT now(),
  source_label    text,
  recorded_by     uuid REFERENCES auth.users(id),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_acquisition_touchpoints IS
  'Per-touch acquisition ledger. First-touch + last-touch attribution model. The forcing function against attribution amnesia.';

CREATE INDEX IF NOT EXISTS founder_acquisition_touchpoints_hosp_time_idx
  ON public.founder_acquisition_touchpoints (hospital_org_id, touched_at);
CREATE INDEX IF NOT EXISTS founder_acquisition_touchpoints_kind_idx
  ON public.founder_acquisition_touchpoints (touch_kind);
CREATE INDEX IF NOT EXISTS founder_acquisition_touchpoints_touched_at_idx
  ON public.founder_acquisition_touchpoints (touched_at);

ALTER TABLE public.founder_acquisition_touchpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_acquisition_touchpoints_founder_all
  ON public.founder_acquisition_touchpoints;
CREATE POLICY founder_acquisition_touchpoints_founder_all
  ON public.founder_acquisition_touchpoints
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1 — summary (16 KPIs)
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_acquisition_attribution_summary();
CREATE OR REPLACE FUNCTION public.founder_acquisition_attribution_summary()
RETURNS TABLE (
  total_touchpoints                  bigint,
  total_hospitals_touched            bigint,
  total_hospitals_converted          bigint,
  conversion_pct                     numeric,
  avg_touches_per_conversion         numeric,
  first_touch_top_kind               text,
  last_touch_top_kind                text,
  referral_attributed_count          bigint,
  cold_outreach_attributed_count     bigint,
  event_attributed_count             bigint,
  website_form_attributed_count      bigint,
  partner_referral_attributed_count  bigint,
  other_kinds_attributed_count       bigint,
  first_touch_to_signed_median_days  numeric,
  touchpoints_last_30d               bigint,
  hospitals_with_zero_touchpoints    bigint
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
  WITH tp AS (
    SELECT * FROM public.founder_acquisition_touchpoints
  ),
  hosp_first AS (
    SELECT hospital_org_id,
           (array_agg(touch_kind ORDER BY touched_at ASC))[1]  AS first_kind,
           (array_agg(touched_at ORDER BY touched_at ASC))[1]  AS first_at,
           (array_agg(touch_kind ORDER BY touched_at DESC))[1] AS last_kind,
           count(*)                                            AS touch_count
      FROM tp
     GROUP BY hospital_org_id
  ),
  converted AS (
    SELECT DISTINCT hospital_org_id
      FROM public.amc_contracts
     WHERE status = 'active'
  ),
  hf_conv AS (
    SELECT hf.*,
           EXISTS (SELECT 1 FROM converted c WHERE c.hospital_org_id = hf.hospital_org_id) AS is_converted,
           (SELECT min(start_date)::timestamptz FROM public.amc_contracts a
             WHERE a.hospital_org_id = hf.hospital_org_id AND a.status = 'active') AS first_signed_at
      FROM hosp_first hf
  ),
  first_kind_rank AS (
    SELECT first_kind, count(*) AS n
      FROM hf_conv WHERE is_converted
     GROUP BY first_kind
     ORDER BY n DESC NULLS LAST
     LIMIT 1
  ),
  last_kind_rank AS (
    SELECT last_kind, count(*) AS n
      FROM hf_conv WHERE is_converted
     GROUP BY last_kind
     ORDER BY n DESC NULLS LAST
     LIMIT 1
  ),
  attributed AS (
    SELECT first_kind FROM hf_conv WHERE is_converted
  ),
  med_days AS (
    SELECT percentile_cont(0.5) WITHIN GROUP (
             ORDER BY EXTRACT(EPOCH FROM (first_signed_at - first_at)) / 86400.0
           ) AS m
      FROM hf_conv
     WHERE is_converted AND first_signed_at IS NOT NULL AND first_at IS NOT NULL
  ),
  hospitals_total AS (
    SELECT count(*) AS n FROM public.organizations WHERE kind = 'hospital'
  ),
  hospitals_with AS (
    SELECT count(DISTINCT hospital_org_id) AS n FROM tp
  )
  SELECT
    (SELECT count(*) FROM tp)::bigint                                                AS total_touchpoints,
    (SELECT count(DISTINCT hospital_org_id) FROM tp)::bigint                         AS total_hospitals_touched,
    (SELECT count(*) FROM hf_conv WHERE is_converted)::bigint                        AS total_hospitals_converted,
    CASE WHEN (SELECT count(DISTINCT hospital_org_id) FROM tp) > 0
         THEN round(
           (SELECT count(*) FROM hf_conv WHERE is_converted)::numeric * 100.0
           / NULLIF((SELECT count(DISTINCT hospital_org_id) FROM tp), 0), 2)
         ELSE 0 END                                                                  AS conversion_pct,
    CASE WHEN (SELECT count(*) FROM hf_conv WHERE is_converted) > 0
         THEN round(
           (SELECT count(*) FROM tp t
             WHERE t.hospital_org_id IN (SELECT hospital_org_id FROM hf_conv WHERE is_converted)
           )::numeric
           / NULLIF((SELECT count(*) FROM hf_conv WHERE is_converted), 0), 2)
         ELSE 0 END                                                                  AS avg_touches_per_conversion,
    (SELECT first_kind FROM first_kind_rank)                                         AS first_touch_top_kind,
    (SELECT last_kind  FROM last_kind_rank)                                          AS last_touch_top_kind,
    (SELECT count(*) FROM attributed WHERE first_kind = 'referral')::bigint          AS referral_attributed_count,
    (SELECT count(*) FROM attributed WHERE first_kind = 'cold_outreach')::bigint     AS cold_outreach_attributed_count,
    (SELECT count(*) FROM attributed WHERE first_kind = 'event')::bigint             AS event_attributed_count,
    (SELECT count(*) FROM attributed WHERE first_kind = 'website_form')::bigint      AS website_form_attributed_count,
    (SELECT count(*) FROM attributed WHERE first_kind = 'partner_referral')::bigint  AS partner_referral_attributed_count,
    (SELECT count(*) FROM attributed
      WHERE first_kind NOT IN ('referral','cold_outreach','event','website_form','partner_referral')
    )::bigint                                                                        AS other_kinds_attributed_count,
    COALESCE(round((SELECT m FROM med_days)::numeric, 1), 0)                         AS first_touch_to_signed_median_days,
    (SELECT count(*) FROM tp WHERE touched_at >= now() - interval '30 days')::bigint AS touchpoints_last_30d,
    GREATEST(
      (SELECT n FROM hospitals_total) - (SELECT n FROM hospitals_with), 0
    )::bigint                                                                        AS hospitals_with_zero_touchpoints;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_acquisition_attribution_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_acquisition_attribution_summary() TO authenticated;

-- ============================================================================
-- RPC 2 — per-kind breakdown
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_acquisition_attribution_by_kind();
CREATE OR REPLACE FUNCTION public.founder_acquisition_attribution_by_kind()
RETURNS TABLE (
  kind                          text,
  touchpoint_count              bigint,
  hospitals_touched             bigint,
  hospitals_converted           bigint,
  conversion_pct                numeric,
  first_touch_attribution_count bigint,
  last_touch_attribution_count  bigint
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
  WITH tp AS (
    SELECT * FROM public.founder_acquisition_touchpoints
  ),
  hosp_first AS (
    SELECT hospital_org_id,
           (array_agg(touch_kind ORDER BY touched_at ASC))[1]  AS first_kind,
           (array_agg(touch_kind ORDER BY touched_at DESC))[1] AS last_kind
      FROM tp
     GROUP BY hospital_org_id
  ),
  converted AS (
    SELECT DISTINCT hospital_org_id FROM public.amc_contracts WHERE status = 'active'
  ),
  hf_conv AS (
    SELECT hf.*, EXISTS (SELECT 1 FROM converted c WHERE c.hospital_org_id = hf.hospital_org_id) AS is_converted
      FROM hosp_first hf
  ),
  per_kind AS (
    SELECT touch_kind AS k,
           count(*)                          AS tp_count,
           count(DISTINCT hospital_org_id)   AS h_touched,
           count(DISTINCT hospital_org_id) FILTER (
             WHERE hospital_org_id IN (SELECT hospital_org_id FROM converted)
           )                                 AS h_converted
      FROM tp
     GROUP BY touch_kind
  ),
  first_attr AS (
    SELECT first_kind AS k, count(*) AS n FROM hf_conv WHERE is_converted GROUP BY first_kind
  ),
  last_attr AS (
    SELECT last_kind AS k, count(*) AS n FROM hf_conv WHERE is_converted GROUP BY last_kind
  ),
  kinds AS (
    SELECT unnest(ARRAY[
      'referral','cold_outreach','event','website_form',
      'phone_inbound','referred_by_chain','partner_referral',
      'google_ads','linkedin_ads','content_marketing','other'
    ]) AS k
  )
  SELECT
    k.k::text                                                       AS kind,
    COALESCE(pk.tp_count, 0)::bigint                                AS touchpoint_count,
    COALESCE(pk.h_touched, 0)::bigint                               AS hospitals_touched,
    COALESCE(pk.h_converted, 0)::bigint                             AS hospitals_converted,
    CASE WHEN COALESCE(pk.h_touched, 0) > 0
         THEN round(COALESCE(pk.h_converted, 0)::numeric * 100.0
                    / NULLIF(pk.h_touched, 0), 2)
         ELSE 0 END                                                 AS conversion_pct,
    COALESCE(fa.n, 0)::bigint                                       AS first_touch_attribution_count,
    COALESCE(la.n, 0)::bigint                                       AS last_touch_attribution_count
  FROM kinds k
  LEFT JOIN per_kind pk ON pk.k = k.k
  LEFT JOIN first_attr fa ON fa.k = k.k
  LEFT JOIN last_attr la ON la.k = k.k
  ORDER BY COALESCE(pk.tp_count, 0) DESC, k.k ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_acquisition_attribution_by_kind() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_acquisition_attribution_by_kind() TO authenticated;

-- ============================================================================
-- RPC 3 — record a touch
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_acquisition_record_touch(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_acquisition_record_touch(
  p_hospital_org_id uuid,
  p_kind            text,
  p_source_label    text,
  p_notes           text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_hospital_org_id IS NULL THEN
    RAISE EXCEPTION 'p_hospital_org_id required' USING ERRCODE = '22023';
  END IF;
  IF p_kind IS NULL OR p_kind NOT IN (
    'referral','cold_outreach','event','website_form',
    'phone_inbound','referred_by_chain','partner_referral',
    'google_ads','linkedin_ads','content_marketing','other'
  ) THEN
    RAISE EXCEPTION 'invalid touch_kind: %', p_kind USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.founder_acquisition_touchpoints
    (hospital_org_id, touch_kind, source_label, notes, recorded_by, touched_at)
  VALUES
    (p_hospital_org_id, p_kind, p_source_label, p_notes, auth.uid(), now())
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_acquisition_record_touch(uuid, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_acquisition_record_touch(uuid, text, text, text) TO authenticated;

COMMIT;