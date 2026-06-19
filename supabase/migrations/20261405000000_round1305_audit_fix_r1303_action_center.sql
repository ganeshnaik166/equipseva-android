BEGIN;
-- r1305 — CRITICAL audit-fix sweep for /founder-action-center (r1303).
-- Workflow wx41ohful caught 4 bugs that would 500-error EVERY founder call:
--
-- 1. collusion_flags.severity → column doesn't exist (real: signal_kind is the discriminator)
--    Two refs in label + WHERE. Drop severity gate; rely on status+signal_kind.
--
-- 2. amc_sla_breaches.credit_amount_rupees → column doesn't exist (real: credit_issued_rupees)
--    One ref. Trivial rename.
--
-- 3. amc_sla_breaches.created_at → column doesn't exist (real: detected_at)
--    Three refs (age calc + output + IST today predicate). Trivial rename.
--
-- 4. dpdp_grievances.status='in_progress' → not a valid CHECK value
--    (real values: open/in_review/resolved/escalated/rejected). Use 'in_review' instead.
--
-- This is the most critical fix in the sprint because /founder-action-center
-- is now the Tier-1 founder home page.

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
    -- 1. Stuck payouts (>7d)
    SELECT
      'payouts'::text                                    AS source_domain,
      'stuck_payout'::text                                AS item_kind,
      p.id                                                AS item_id,
      ('Payout queued ' || extract(day from (now() - p.queued_at))::int || 'd to ' ||
        coalesce((SELECT full_name FROM public.profiles WHERE id = p.engineer_user_id), '(unknown)'))::text AS label,
      CASE WHEN p.queued_at < now() - interval '14 days' THEN 1 ELSE 2 END AS severity,
      extract(hour from (now() - p.queued_at))::int       AS age_hours,
      p.amount_rupees::numeric                            AS money_at_stake_inr,
      p.queued_at                                         AS created_at
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued', 'processing')
      AND p.queued_at < now() - interval '7 days'

    UNION ALL

    -- 2. Code Red unresolved (>4h)
    SELECT
      'code_red',
      'unresolved_code_red',
      r.id,
      ('Code Red unresolved ' || extract(hour from (now() - r.created_at))::int || 'h · ' ||
        coalesce(r.equipment_type, '(equipment)'))::text,
      CASE WHEN r.created_at < now() - interval '24 hours' THEN 1 ELSE 2 END,
      extract(hour from (now() - r.created_at))::int,
      r.emergency_fee_ceiling_rupees::numeric,
      r.created_at
    FROM public.code_red_requests r
    WHERE r.status NOT IN ('resolved', 'timed_out')
      AND r.created_at < now() - interval '4 hours'

    UNION ALL

    -- 3. Disputes open >7d
    SELECT
      'disputes',
      'open_dispute',
      d.id,
      ('Dispute open ' || extract(day from (now() - d.submitted_at))::int || 'd · filed by ' || d.filer_role)::text,
      CASE WHEN d.submitted_at < now() - interval '14 days' THEN 1 ELSE 2 END,
      extract(hour from (now() - d.submitted_at))::int,
      d.total_money_at_stake_rupees::numeric,
      d.submitted_at
    FROM public.dispute_evidence_packs d
    WHERE d.status = 'submitted'
      AND d.mediator_decision_at IS NULL
      AND d.submitted_at < now() - interval '7 days'

    UNION ALL

    -- 4. Escrow held >14d
    SELECT
      'escrow',
      'stuck_escrow',
      e.id,
      ('Escrow held ' || extract(day from (now() - e.created_at))::int || 'd · job ' || e.repair_job_id::text)::text,
      CASE WHEN e.status = 'in_dispute' THEN 1
           WHEN e.created_at < now() - interval '30 days' THEN 1
           ELSE 2 END,
      extract(hour from (now() - e.created_at))::int,
      e.amount_rupees::numeric,
      e.created_at
    FROM public.repair_job_escrow e
    WHERE (e.status = 'held' AND e.created_at < now() - interval '14 days')
       OR e.status = 'in_dispute'

    UNION ALL

    -- 5. Spare parts paid-not-shipped >7d
    SELECT
      'spare_parts',
      'unshipped_paid_order',
      o.id,
      ('Order ' || coalesce(o.order_number, o.id::text) || ' paid, not shipped ' || extract(day from (now() - o.created_at))::int || 'd')::text,
      CASE WHEN o.created_at < now() - interval '14 days' THEN 1 ELSE 2 END,
      extract(hour from (now() - o.created_at))::int,
      o.total_amount::numeric,
      o.created_at
    FROM public.spare_part_orders o
    WHERE coalesce(o.payment_status, '') = 'paid'
      AND coalesce(o.order_status, '') NOT IN ('shipped', 'delivered', 'cancelled', 'refunded')
      AND o.created_at < now() - interval '7 days'

    UNION ALL

    -- 6. AMC renewals due in next 30d
    SELECT
      'amc',
      'amc_renewal_due',
      c.id,
      ('AMC ' || c.amc_tier || ' renewing in ' || (c.end_date - (now() AT TIME ZONE 'Asia/Kolkata')::date)::int || 'd')::text,
      CASE WHEN c.end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 7 THEN 1 ELSE 3 END,
      0,
      c.monthly_fee_rupees::numeric,
      c.created_at
    FROM public.amc_contracts c
    WHERE c.status IN ('active', 'paused')
      AND c.end_date IS NOT NULL
      AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date
      AND c.end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 30

    UNION ALL

    -- 7. Engineer KYC pending >7d
    SELECT
      'kyc',
      'engineer_kyc_pending',
      e.id,
      ('Engineer KYC pending ' || extract(day from (now() - e.created_at))::int || 'd · ' ||
        coalesce((SELECT full_name FROM public.profiles WHERE id = e.user_id), 'unknown'))::text,
      CASE WHEN e.created_at < now() - interval '30 days' THEN 1 ELSE 3 END,
      extract(hour from (now() - e.created_at))::int,
      0::numeric,
      e.created_at
    FROM public.engineers e
    WHERE coalesce(e.verification_status, 'pending') = 'pending'
      AND e.created_at < now() - interval '7 days'

    UNION ALL

    -- 8. Refund queue open >3d
    SELECT
      'refunds',
      'refund_pending',
      r.id,
      ('Refund authorization pending ' || extract(day from (now() - r.created_at))::int || 'd')::text,
      CASE WHEN r.created_at < now() - interval '7 days' THEN 1 ELSE 2 END,
      extract(hour from (now() - r.created_at))::int,
      coalesce(r.amount_rupees, 0)::numeric,
      r.created_at
    FROM public.refund_authorization_requests r
    WHERE coalesce(r.status, 'pending') = 'pending'
      AND r.created_at < now() - interval '3 days'

    UNION ALL

    -- 9. Collusion flags open/investigating (signal_kind is the discriminator; no severity column)
    SELECT
      'collusion',
      'collusion_flag',
      f.id,
      ('Collusion flag · ' || f.signal_kind || ' · status=' || f.status)::text,
      1,
      extract(hour from (now() - f.created_at))::int,
      coalesce(f.total_value_rupees_30d, 0)::numeric,
      f.created_at
    FROM public.collusion_flags f
    WHERE f.status IN ('open', 'investigating')

    UNION ALL

    -- 10. DPDP grievances over 30-day SLA (status: open / in_review — NOT 'in_progress')
    SELECT
      'dpdp',
      'dpdp_grievance_overdue',
      g.id,
      ('DPDP grievance ' || extract(day from (now() - g.created_at))::int || 'd old · ' || coalesce(g.grievance_type, 'unknown'))::text,
      1,
      extract(hour from (now() - g.created_at))::int,
      0::numeric,
      g.created_at
    FROM public.dpdp_grievances g
    WHERE coalesce(g.status, 'open') IN ('open', 'in_review')
      AND g.created_at < now() - interval '30 days'

    UNION ALL

    -- 11. AMC SLA breaches today (IST) — uses detected_at + credit_issued_rupees (NOT created_at + credit_amount_rupees)
    SELECT
      'amc_sla',
      'amc_sla_breach_today',
      b.id,
      ('AMC SLA breach today · ' || coalesce(b.breach_type, 'unknown'))::text,
      2,
      extract(hour from (now() - b.detected_at))::int,
      coalesce(b.credit_issued_rupees, 0)::numeric,
      b.detected_at
    FROM public.amc_sla_breaches b
    WHERE b.detected_at >= (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata'

    UNION ALL

    -- 12. Risk score critical band actors (alert_only, not yet reviewed)
    SELECT * FROM (
      SELECT DISTINCT ON (rss.user_id)
        'risk_score'::text                                 AS source_domain,
        'critical_risk_actor'::text                         AS item_kind,
        rss.id                                              AS item_id,
        ('Risk score ' || rss.score || ' critical · ' || rss.role || ' · action_taken=' || rss.action_taken)::text AS label,
        1                                                   AS severity,
        extract(hour from (now() - rss.computed_at))::int   AS age_hours,
        0::numeric                                          AS money_at_stake_inr,
        rss.computed_at                                     AS created_at
      FROM public.risk_score_snapshots rss
      WHERE rss.band = 'critical'
        AND rss.action_taken = 'alert_only'
      ORDER BY rss.user_id, rss.computed_at DESC
    ) risk_sub

    UNION ALL

    -- 13. Spot audit invitations pending response >7d
    SELECT
      'spot_audit',
      'spot_audit_invite_unresponded',
      i.id,
      ('Spot audit pending response ' || extract(day from (now() - i.created_at))::int || 'd')::text,
      3,
      extract(hour from (now() - i.created_at))::int,
      0::numeric,
      i.created_at
    FROM public.spot_audit_invitations i
    WHERE NOT EXISTS (SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = i.id)
      AND i.created_at < now() - interval '7 days'
      AND i.expires_at > now()
  )
  SELECT
    row_number() OVER (ORDER BY a.severity ASC, a.created_at ASC)::int AS priority_rank,
    a.source_domain,
    a.item_kind,
    a.item_id,
    a.label,
    a.severity,
    CASE a.severity
      WHEN 1 THEN 'critical'
      WHEN 2 THEN 'high'
      WHEN 3 THEN 'medium'
      ELSE 'low'
    END::text AS severity_label,
    a.age_hours,
    coalesce(a.money_at_stake_inr, 0)::numeric AS money_at_stake_inr,
    a.created_at
  FROM actions a
  ORDER BY a.severity ASC, a.created_at ASC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_action_center(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_action_center(int) TO authenticated;
COMMIT;
