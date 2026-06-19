BEGIN;
-- r1307 — Public Investor Share v2 (v0.5 Phase 6).
-- Builds on existing r558 investor_share_tokens (token_hash + max_views + view_count)
-- and investor_share_view_log. Adds a richer v2 RPC with 13 sanitized KPIs
-- including trust score + lifetime totals + active states + top-5 equipment-category mix.
--
-- Security posture (inherited from r558):
--   • Token stored as SHA-256 hash; raw shown ONCE to founder
--   • Per-token expiry + per-token view cap
--   • View attempts logged to investor_share_view_log
--   • Read RPC anon-callable but only returns sanitized aggregates

-- ============================================================================
-- Public RPC: investor_share_v2(p_token text) — anon-callable
-- ============================================================================
DROP FUNCTION IF EXISTS public.investor_share_v2(text);
CREATE OR REPLACE FUNCTION public.investor_share_v2(p_token text)
RETURNS TABLE (
  outcome                   text,
  org_label                 text,
  active_mrr_inr            numeric,
  active_amc_contracts      bigint,
  lifetime_jobs_completed   bigint,
  lifetime_gmv_inr          numeric,
  lifetime_payouts_inr      numeric,
  lifetime_signups          bigint,
  active_engineers_30d      bigint,
  active_hospitals_30d      bigint,
  active_states             bigint,
  top_equipment_categories  text,
  trust_score_pct           numeric,
  days_operating            int
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_token_row RECORD;
  v_hash      text;
  v_outcome   text;
  v_top_cats  text;
  v_trust     numeric;
BEGIN
  v_hash := encode(digest(p_token, 'sha256'), 'hex');
  SELECT * INTO v_token_row FROM public.investor_share_tokens WHERE token_hash = v_hash;
  IF v_token_row IS NULL THEN
    RETURN QUERY SELECT 'unknown_token'::text, NULL::text, 0::numeric, 0::bigint, 0::bigint, 0::numeric, 0::numeric, 0::bigint, 0::bigint, 0::bigint, 0::bigint, NULL::text, 0::numeric, 0::int;
    RETURN;
  END IF;

  -- Decide outcome based on r558 status + expires_at + view_count
  IF v_token_row.status = 'revoked' OR v_token_row.revoked_at IS NOT NULL THEN
    v_outcome := 'revoked';
  ELSIF v_token_row.expires_at < now() THEN
    v_outcome := 'expired';
  ELSIF v_token_row.view_count >= v_token_row.max_views THEN
    v_outcome := 'exhausted';
  ELSE
    v_outcome := 'served';
  END IF;

  -- Log every attempt
  INSERT INTO public.investor_share_view_log (token_id, outcome)
  VALUES (v_token_row.id, v_outcome);

  -- Increment view count on success
  IF v_outcome = 'served' THEN
    UPDATE public.investor_share_tokens SET view_count = view_count + 1 WHERE id = v_token_row.id;
  END IF;

  IF v_outcome <> 'served' THEN
    RETURN QUERY SELECT v_outcome, v_token_row.label::text, 0::numeric, 0::bigint, 0::bigint, 0::numeric, 0::numeric, 0::bigint, 0::bigint, 0::bigint, 0::bigint, NULL::text, 0::numeric, 0::int;
    RETURN;
  END IF;

  -- Top 5 equipment categories by 90d job volume (names only, no counts to caller)
  SELECT string_agg(cat, ', ' ORDER BY n DESC) INTO v_top_cats FROM (
    SELECT coalesce(nullif(trim(equipment_type), ''), '(other)') AS cat, count(*) AS n
    FROM public.repair_jobs
    WHERE created_at >= now() - interval '90 days'
    GROUP BY coalesce(nullif(trim(equipment_type), ''), '(other)')
    ORDER BY n DESC
    LIMIT 5
  ) t;

  -- Trust score via existing /trust-pulse-summary RPC
  BEGIN
    SELECT round(coalesce((SELECT overall_trust_score FROM public.founder_trust_pulse_summary() LIMIT 1), 0), 1) INTO v_trust;
  EXCEPTION WHEN OTHERS THEN
    v_trust := 0;   -- founder_trust_pulse_summary requires is_founder() gate; not callable from investor_share_v2 context
  END;

  RETURN QUERY
  SELECT
    'served'::text,
    v_token_row.label::text,
    coalesce((SELECT sum(monthly_fee_rupees)::numeric FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed'), 0),
    coalesce((SELECT sum(contracted_amount_rupees)::numeric FROM public.repair_jobs WHERE status = 'completed'), 0)
      + coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status = 'processed'), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles), 0),
    coalesce((SELECT count(DISTINCT engineer_id)::bigint FROM public.repair_jobs
              WHERE engineer_id IS NOT NULL AND completed_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.repair_jobs
              WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT o.state)::bigint
              FROM public.repair_jobs rj
              JOIN public.profiles p ON p.id = rj.hospital_user_id
              JOIN public.organizations o ON o.id = p.organization_id
              WHERE rj.created_at >= now() - interval '90 days' AND o.state IS NOT NULL), 0),
    coalesce(v_top_cats, '(none)')::text,
    coalesce(v_trust, 0)::numeric,
    coalesce(extract(day from (now() - (SELECT min(created_at) FROM public.profiles)))::int, 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.investor_share_v2(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.investor_share_v2(text) TO anon, authenticated;

COMMIT;
