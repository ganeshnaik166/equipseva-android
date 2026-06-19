BEGIN;
-- r1306 — founder_priority_actions: write-transition layer for /founder-action-center.
-- Phase 5 of v0.5 roadmap (originally planned for weeks 1-2; landing now).
--
-- Founder loads /founder-action-center → reviews top items → marks each:
--   • acked      — "I've seen this, not yet acting" (silences for 24h)
--   • resolved   — "Done; the underlying issue is fixed" (silences forever)
--   • escalated  — "Routing to a teammate / external party" (silences with timer)
--   • ignored    — "Not worth my time" (silences forever, but logged)
--
-- The action_center RPC filters out items already terminally-actioned. So once
-- the founder works through the queue, /founder-action-center inbox-zeros.

CREATE TABLE IF NOT EXISTS public.founder_priority_actions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_user_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_domain     text NOT NULL,
  item_kind         text NOT NULL,
  source_item_id    uuid NOT NULL,
  action_taken      text NOT NULL CHECK (action_taken IN ('acked','resolved','escalated','ignored')),
  note              text,
  ack_expires_at    timestamptz,   -- when 'acked' silences expire (24h default)
  created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_priority_actions IS
  'Write-transition layer for /founder-action-center. Founder marks items acked/resolved/escalated/ignored to silence them from the priority queue.';

CREATE INDEX IF NOT EXISTS idx_founder_priority_actions_lookup
  ON public.founder_priority_actions (source_domain, source_item_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_priority_actions_recent
  ON public.founder_priority_actions (created_at DESC);

-- RLS — founder-only via is_founder() gate inside RPC; table itself locked down.
ALTER TABLE public.founder_priority_actions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_priority_actions_no_direct ON public.founder_priority_actions;
CREATE POLICY founder_priority_actions_no_direct ON public.founder_priority_actions FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_priority_actions FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- RPC: log_founder_priority_action
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_priority_action(text, text, uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_priority_action(
  p_source_domain  text,
  p_item_kind      text,
  p_source_item_id uuid,
  p_action_taken   text,
  p_note           text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_log_id uuid;
  v_expires timestamptz;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_action_taken NOT IN ('acked','resolved','escalated','ignored') THEN
    RAISE EXCEPTION 'invalid action_taken: %', p_action_taken USING ERRCODE = '22023';
  END IF;
  IF p_action_taken = 'acked' THEN
    v_expires := now() + interval '24 hours';
  ELSIF p_action_taken = 'escalated' THEN
    v_expires := now() + interval '7 days';
  ELSE
    v_expires := NULL;   -- resolved / ignored = silence forever
  END IF;
  INSERT INTO public.founder_priority_actions
    (founder_user_id, source_domain, item_kind, source_item_id, action_taken, note, ack_expires_at)
  VALUES
    (auth.uid(), p_source_domain, p_item_kind, p_source_item_id, p_action_taken, p_note, v_expires)
  RETURNING id INTO v_log_id;
  RETURN v_log_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_priority_action(text, text, uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_priority_action(text, text, uuid, text, text) TO authenticated;

-- ============================================================================
-- Updated founder_action_center — filters out items with active silencing
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
    SELECT 'kyc', 'engineer_kyc_pending', e.id,
      ('Engineer KYC pending ' || extract(day from (now() - e.created_at))::int || 'd · ' ||
        coalesce((SELECT full_name FROM public.profiles WHERE id = e.user_id), 'unknown'))::text,
      CASE WHEN e.created_at < now() - interval '30 days' THEN 1 ELSE 3 END,
      extract(hour from (now() - e.created_at))::int, 0::numeric, e.created_at
    FROM public.engineers e
    WHERE coalesce(e.verification_status,'pending') = 'pending' AND e.created_at < now() - interval '7 days'
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
  -- Latest action per (source_domain, item_id) — used to filter out silenced items
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

-- ============================================================================
-- RPC: founder_priority_actions_summary — view recent actions taken
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_priority_actions_summary();
CREATE OR REPLACE FUNCTION public.founder_priority_actions_summary()
RETURNS TABLE (
  total_actions_all_time   bigint,
  actions_today            bigint,
  actions_7d               bigint,
  acked_count              bigint,
  resolved_count           bigint,
  escalated_count          bigint,
  ignored_count            bigint,
  acked_active_now         bigint,
  escalated_active_now     bigint,
  most_recent_action_at    timestamptz,
  distinct_domains_acted   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE created_at >= v_today_start)::bigint,
    count(*) FILTER (WHERE created_at >= now() - interval '7 days')::bigint,
    count(*) FILTER (WHERE action_taken = 'acked')::bigint,
    count(*) FILTER (WHERE action_taken = 'resolved')::bigint,
    count(*) FILTER (WHERE action_taken = 'escalated')::bigint,
    count(*) FILTER (WHERE action_taken = 'ignored')::bigint,
    count(*) FILTER (WHERE action_taken = 'acked' AND ack_expires_at > now())::bigint,
    count(*) FILTER (WHERE action_taken = 'escalated' AND ack_expires_at > now())::bigint,
    max(created_at),
    count(DISTINCT source_domain)::bigint
  FROM public.founder_priority_actions;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_priority_actions_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_priority_actions_summary() TO authenticated;

-- ============================================================================
-- RPC: founder_priority_actions_recent — recent action history feed
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_priority_actions_recent(int);
CREATE OR REPLACE FUNCTION public.founder_priority_actions_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id              uuid,
  source_domain   text,
  item_kind       text,
  source_item_id  uuid,
  action_taken    text,
  note            text,
  ack_expires_at  timestamptz,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT l.id, l.source_domain, l.item_kind, l.source_item_id, l.action_taken, l.note, l.ack_expires_at, l.created_at
  FROM public.founder_priority_actions l
  ORDER BY l.created_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_priority_actions_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_priority_actions_recent(int) TO authenticated;

COMMIT;
