BEGIN;
-- r1308 — CRITICAL audit-fix sweep for the 2 heavy ships from this session.
-- Workflow wlrll9mbp surfaced 2 CRITICAL bugs + 1 MEDIUM.
--
-- 1. CRITICAL r1307 investor_share_v2: v_outcome='served' violates the existing
--    r558 CHECK constraint on investor_share_view_log.outcome which only allows
--    ('ok','expired','exhausted','revoked','not_found'). Every successful share
--    view ABORTS with 23514 check_violation. Investor share v2 is completely
--    broken in prod — no investor would ever see a single KPI.
--
-- 2. CRITICAL r1306 founder_action_center post-r1306 silenced-filter rewrite:
--    `coalesce(e.verification_status, 'pending') = 'pending'` on public.engineers
--    fails with 42804 because verification_status is enum, not text. The KYC
--    bucket of /founder-action-center aborts on every load. Founder home page is
--    broken until fixed.
--
-- 3. MEDIUM r1307 unknown_token: early-returns before logging — regression vs
--    r558 which logs 'not_found' for security telemetry (brute-force detection).
--    Founder loses visibility into token-guessing attacks.
--
-- Fix strategy:
--   - r1307: log 'ok' on success (match r558 vocabulary), keep emitting 'served'
--     to the outward-facing RETURN tuple so the public page contract doesn't change.
--     Also log 'not_found' on unknown_token before early return.
--   - r1306: cast e.verification_status::text in the founder_action_center.

-- ============================================================================
-- 1. r1307 investor_share_v2 — fix CHECK constraint violation + unknown_token logging
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
  v_log_outcome text;       -- vocabulary that matches r558 CHECK constraint
  v_public_outcome text;    -- vocabulary that the public page expects
  v_top_cats  text;
  v_trust     numeric;
BEGIN
  v_hash := encode(digest(p_token, 'sha256'), 'hex');
  SELECT * INTO v_token_row FROM public.investor_share_tokens WHERE token_hash = v_hash;
  IF v_token_row IS NULL THEN
    -- Log brute-force attempts using r558 'not_found' vocabulary; token_id NULL is permitted by r558 schema.
    INSERT INTO public.investor_share_view_log (token_id, outcome) VALUES (NULL, 'not_found');
    RETURN QUERY SELECT 'unknown_token'::text, NULL::text, 0::numeric, 0::bigint, 0::bigint, 0::numeric, 0::numeric, 0::bigint, 0::bigint, 0::bigint, 0::bigint, NULL::text, 0::numeric, 0::int;
    RETURN;
  END IF;

  -- Map status to BOTH log vocabulary (r558 CHECK) and public vocabulary (outward RETURN)
  IF v_token_row.status = 'revoked' OR v_token_row.revoked_at IS NOT NULL THEN
    v_log_outcome := 'revoked';     v_public_outcome := 'revoked';
  ELSIF v_token_row.expires_at < now() THEN
    v_log_outcome := 'expired';     v_public_outcome := 'expired';
  ELSIF v_token_row.view_count >= v_token_row.max_views THEN
    v_log_outcome := 'exhausted';   v_public_outcome := 'exhausted';
  ELSE
    v_log_outcome := 'ok';          v_public_outcome := 'served';
  END IF;

  -- Log attempt (uses CHECK-compliant vocabulary)
  INSERT INTO public.investor_share_view_log (token_id, outcome) VALUES (v_token_row.id, v_log_outcome);

  -- Increment view count on success
  IF v_log_outcome = 'ok' THEN
    UPDATE public.investor_share_tokens SET view_count = view_count + 1 WHERE id = v_token_row.id;
  END IF;

  IF v_public_outcome <> 'served' THEN
    RETURN QUERY SELECT v_public_outcome, v_token_row.label::text, 0::numeric, 0::bigint, 0::bigint, 0::numeric, 0::numeric, 0::bigint, 0::bigint, 0::bigint, 0::bigint, NULL::text, 0::numeric, 0::int;
    RETURN;
  END IF;

  SELECT string_agg(cat, ', ' ORDER BY n DESC) INTO v_top_cats FROM (
    SELECT coalesce(nullif(trim(equipment_type), ''), '(other)') AS cat, count(*) AS n
    FROM public.repair_jobs
    WHERE created_at >= now() - interval '90 days'
    GROUP BY coalesce(nullif(trim(equipment_type), ''), '(other)')
    ORDER BY n DESC
    LIMIT 5
  ) t;

  BEGIN
    SELECT round(coalesce((SELECT overall_trust_score FROM public.founder_trust_pulse_summary() LIMIT 1), 0), 1) INTO v_trust;
  EXCEPTION WHEN OTHERS THEN
    v_trust := 0;
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

-- ============================================================================
-- 2. r1306 founder_action_center — fix enum-vs-text coalesce on engineers.verification_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_action_center(int);
CREATE OR REPLACE FUNCTION public.founder_action_center(p_limit int DEFAULT 50)
RETURNS TABLE (
  priority_rank        int,
  source_domain        text,
  item_kind            text,
  item_id              uuid,
  label                text,
  severity             int,
  severity_label       text,
  age_hours            int,
  money_at_stake_inr   numeric,
  created_at           timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH actions AS (
    SELECT 'payouts'::text AS source_domain, 'stuck_payout'::text AS item_kind, p.id AS item_id,
      ('Payout queued ' || extract(day from (now() - p.queued_at))::int || 'd to ' ||
        coalesce((SELECT full_name FROM public.profiles WHERE id = p.engineer_user_id), '(unknown)'))::text AS label,
      CASE WHEN p.queued_at < now() - interval '14 days' THEN 1 ELSE 2 END AS severity,
      extract(hour from (now() - p.queued_at))::int AS age_hours,
      p.amount_rupees::numeric AS money_at_stake_inr, p.queued_at AS created_at
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued', 'processing') AND p.queued_at < now() - interval '7 days'
    UNION ALL
    SELECT 'code_red', 'unresolved_code_red', r.id,
      ('Code Red unresolved ' || extract(hour from (now() - r.created_at))::int || 'h · ' ||
        coalesce(r.equipment_type, '(equipment)'))::text,
      CASE WHEN r.created_at < now() - interval '24 hours' THEN 1 ELSE 2 END,
      extract(hour from (now() - r.created_at))::int,
      r.emergency_fee_ceiling_rupees::numeric, r.created_at
    FROM public.code_red_requests r
    WHERE r.status NOT IN ('resolved', 'timed_out') AND r.created_at < now() - interval '4 hours'
    UNION ALL
    SELECT 'disputes', 'open_dispute', d.id,
      ('Dispute open ' || extract(day from (now() - d.submitted_at))::int || 'd · filed by ' || d.filer_role)::text,
      CASE WHEN d.submitted_at < now() - interval '14 days' THEN 1 ELSE 2 END,
      extract(hour from (now() - d.submitted_at))::int,
      d.total_money_at_stake_rupees::numeric, d.submitted_at
    FROM public.dispute_evidence_packs d
    WHERE d.status = 'submitted' AND d.mediator_decision_at IS NULL AND d.submitted_at < now() - interval '7 days'
    UNION ALL
    SELECT 'escrow', 'stuck_escrow', e.id,
      ('Escrow held ' || extract(day from (now() - e.created_at))::int || 'd · job ' || e.repair_job_id::text)::text,
      CASE WHEN e.status = 'in_dispute' THEN 1 WHEN e.created_at < now() - interval '30 days' THEN 1 ELSE 2 END,
      extract(hour from (now() - e.created_at))::int, e.amount_rupees::numeric, e.created_at
    FROM public.repair_job_escrow e
    WHERE (e.status = 'held' AND e.created_at < now() - interval '14 days') OR e.status = 'in_dispute'
    UNION ALL
    SELECT 'spare_parts', 'unshipped_paid_order', o.id,
      ('Order ' || coalesce(o.order_number, o.id::text) || ' paid, not shipped ' || extract(day from (now() - o.created_at))::int || 'd')::text,
      CASE WHEN o.created_at < now() - interval '14 days' THEN 1 ELSE 2 END,
      extract(hour from (now() - o.created_at))::int, o.total_amount::numeric, o.created_at
    FROM public.spare_part_orders o
    WHERE coalesce(o.payment_status,'') = 'paid' AND coalesce(o.order_status,'') NOT IN ('shipped','delivered','cancelled','refunded')
      AND o.created_at < now() - interval '7 days'
    UNION ALL
    SELECT 'amc', 'amc_renewal_due', c.id,
      ('AMC ' || c.amc_tier || ' renewing in ' || (c.end_date - (now() AT TIME ZONE 'Asia/Kolkata')::date)::int || 'd')::text,
      CASE WHEN c.end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 7 THEN 1 ELSE 3 END,
      0, c.monthly_fee_rupees::numeric, c.created_at
    FROM public.amc_contracts c
    WHERE c.status IN ('active','paused') AND c.end_date IS NOT NULL
      AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date
      AND c.end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 30
    UNION ALL
    -- 7. Engineer KYC pending — CAST enum verification_status to text per r625 fix pattern
    SELECT 'kyc', 'engineer_kyc_pending', e.id,
      ('Engineer KYC pending ' || extract(day from (now() - e.created_at))::int || 'd · ' ||
        coalesce((SELECT full_name FROM public.profiles WHERE id = e.user_id), 'unknown'))::text,
      CASE WHEN e.created_at < now() - interval '30 days' THEN 1 ELSE 3 END,
      extract(hour from (now() - e.created_at))::int, 0::numeric, e.created_at
    FROM public.engineers e
    WHERE coalesce(e.verification_status::text, 'pending') = 'pending'
      AND e.created_at < now() - interval '7 days'
    UNION ALL
    SELECT 'refunds', 'refund_pending', r.id,
      ('Refund authorization pending ' || extract(day from (now() - r.created_at))::int || 'd')::text,
      CASE WHEN r.created_at < now() - interval '7 days' THEN 1 ELSE 2 END,
      extract(hour from (now() - r.created_at))::int, coalesce(r.amount_rupees, 0)::numeric, r.created_at
    FROM public.refund_authorization_requests r
    WHERE coalesce(r.status,'pending') = 'pending' AND r.created_at < now() - interval '3 days'
    UNION ALL
    SELECT 'collusion', 'collusion_flag', f.id,
      ('Collusion flag · ' || f.signal_kind || ' · status=' || f.status)::text,
      1, extract(hour from (now() - f.created_at))::int,
      coalesce(f.total_value_rupees_30d, 0)::numeric, f.created_at
    FROM public.collusion_flags f
    WHERE f.status IN ('open','investigating')
    UNION ALL
    SELECT 'dpdp', 'dpdp_grievance_overdue', g.id,
      ('DPDP grievance ' || extract(day from (now() - g.created_at))::int || 'd old · ' || coalesce(g.grievance_type, 'unknown'))::text,
      1, extract(hour from (now() - g.created_at))::int, 0::numeric, g.created_at
    FROM public.dpdp_grievances g
    WHERE coalesce(g.status,'open') IN ('open','in_review') AND g.created_at < now() - interval '30 days'
    UNION ALL
    SELECT 'amc_sla', 'amc_sla_breach_today', b.id,
      ('AMC SLA breach today · ' || coalesce(b.breach_type, 'unknown'))::text,
      2, extract(hour from (now() - b.detected_at))::int,
      coalesce(b.credit_issued_rupees, 0)::numeric, b.detected_at
    FROM public.amc_sla_breaches b
    WHERE b.detected_at >= (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata'
    UNION ALL
    SELECT * FROM (
      SELECT DISTINCT ON (rss.user_id)
        'risk_score'::text, 'critical_risk_actor'::text, rss.id,
        ('Risk score ' || rss.score || ' critical · ' || rss.role || ' · action_taken=' || rss.action_taken)::text,
        1, extract(hour from (now() - rss.computed_at))::int, 0::numeric, rss.computed_at
      FROM public.risk_score_snapshots rss
      WHERE rss.band = 'critical' AND rss.action_taken = 'alert_only'
      ORDER BY rss.user_id, rss.computed_at DESC
    ) risk_sub
    UNION ALL
    SELECT 'spot_audit', 'spot_audit_invite_unresponded', i.id,
      ('Spot audit pending response ' || extract(day from (now() - i.created_at))::int || 'd')::text,
      3, extract(hour from (now() - i.created_at))::int, 0::numeric, i.created_at
    FROM public.spot_audit_invitations i
    WHERE NOT EXISTS (SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = i.id)
      AND i.created_at < now() - interval '7 days' AND i.expires_at > now()
  ),
  silenced AS (
    SELECT DISTINCT ON (l.source_domain, l.source_item_id)
      l.source_domain, l.source_item_id, l.action_taken, l.ack_expires_at
    FROM public.founder_priority_actions l
    ORDER BY l.source_domain, l.source_item_id, l.created_at DESC
  )
  SELECT
    row_number() OVER (ORDER BY a.severity ASC, a.created_at ASC)::int AS priority_rank,
    a.source_domain, a.item_kind, a.item_id, a.label, a.severity,
    CASE a.severity WHEN 1 THEN 'critical' WHEN 2 THEN 'high' WHEN 3 THEN 'medium' ELSE 'low' END::text AS severity_label,
    a.age_hours, coalesce(a.money_at_stake_inr, 0)::numeric AS money_at_stake_inr, a.created_at
  FROM actions a
  LEFT JOIN silenced s ON s.source_domain = a.source_domain AND s.source_item_id = a.item_id
  WHERE s.action_taken IS NULL
     OR (s.action_taken = 'acked'    AND s.ack_expires_at < now())
     OR (s.action_taken = 'escalated' AND s.ack_expires_at < now())
  ORDER BY a.severity ASC, a.created_at ASC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_action_center(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_action_center(int) TO authenticated;

COMMIT;
