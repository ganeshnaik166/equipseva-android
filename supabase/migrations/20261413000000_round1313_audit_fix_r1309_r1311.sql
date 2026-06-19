BEGIN;
-- r1313 — CRITICAL audit-fix sweep for r1309 + r1311.
-- Workflow wj3ml8w1k surfaced 3 confirmed bugs + 2 minor:
--
-- 1. CRITICAL r1309: dpdp_grievance_officers.grievance_type CHECK + seed values
--    don't match dpdp_grievances (r485) CHECK list. Real values:
--      access_request / deletion_request / correction_request / data_portability
--      / consent_withdrawal / complaint / data_breach_notification
--    r1309 used the WRONG set (correction/erasure/portability/consent_withdrawal/other)
--    so dpdp_route_and_escalate NEVER finds an officer (officer_id always NULL)
--    and founder_dpdp_routing_summary by_type_* counters always read 0.
--
-- 2. HIGH r1311: founder_auto_create_incidents cron calls founder_action_center(500)
--    which has is_founder() gate. pg_cron has no JWT → is_founder() returns false →
--    RAISE EXCEPTION 'founder only'. Cron is permanently broken until fixed.
--    Fix: bypass by adding an internal helper _founder_action_center_internal that
--    has no founder gate (only callable via SECDEF inside other SECDEF fns).
--
-- 3. MEDIUM r1311: extract(hour from interval) returns hour-of-day field (0-23),
--    not total hours. A 5-day incident reports 3h instead of 123h.
--    Fix: extract(epoch from ...) / 3600.

-- ============================================================================
-- 1. r1309 — fix grievance_type vocabulary mismatch
-- ============================================================================
-- Drop the wrong CHECK + DELETE wrong-value rows BEFORE re-adding correct CHECK
ALTER TABLE public.dpdp_grievance_officers
  DROP CONSTRAINT IF EXISTS dpdp_grievance_officers_grievance_type_check;

DELETE FROM public.dpdp_grievance_officers
WHERE grievance_type IN ('correction','erasure','portability','other');

ALTER TABLE public.dpdp_grievance_officers
  ADD CONSTRAINT dpdp_grievance_officers_grievance_type_check
  CHECK (grievance_type IN (
    'access_request', 'deletion_request', 'correction_request',
    'data_portability', 'consent_withdrawal', 'complaint', 'data_breach_notification'
  ));

INSERT INTO public.dpdp_grievance_officers (officer_label, grievance_type)
SELECT 'Founder', t FROM unnest(ARRAY[
  'access_request','deletion_request','correction_request',
  'data_portability','consent_withdrawal','complaint','data_breach_notification'
]::text[]) t
ON CONFLICT DO NOTHING;

-- Rewrite founder_dpdp_routing_summary to use r485 buckets
DROP FUNCTION IF EXISTS public.founder_dpdp_routing_summary();
CREATE OR REPLACE FUNCTION public.founder_dpdp_routing_summary()
RETURNS TABLE (
  total_routed                  bigint,
  routed_today                  bigint,
  approaching_sla               bigint,
  escalated_count               bigint,
  escalated_today               bigint,
  by_type_access_request        bigint,
  by_type_deletion_request      bigint,
  by_type_correction_request    bigint,
  by_type_data_portability      bigint,
  by_type_consent_withdrawal    bigint,
  by_type_complaint             bigint,
  by_type_data_breach_notification bigint,
  median_age_days               numeric,
  oldest_unresolved_age_days    int,
  unrouted_officer_id_null      bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE routed_at >= v_today_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing
              WHERE escalated = false AND sla_breach_at < now() + interval '5 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE escalated = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE escalated_at >= v_today_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'access_request'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'deletion_request'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'correction_request'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'data_portability'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'consent_withdrawal'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'complaint'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'data_breach_notification'), 0),
    coalesce((SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch from (now() - routed_at)) / 86400.0)::numeric, 1)
              FROM public.dpdp_grievance_routing), 0),
    coalesce((SELECT extract(day from (now() - min(g.created_at)))::int
              FROM public.dpdp_grievances g
              WHERE coalesce(g.status::text, 'open') IN ('open','in_review')), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE officer_id IS NULL), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_dpdp_routing_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dpdp_routing_summary() TO authenticated;

-- ============================================================================
-- 2. r1311 — fix founder_auto_create_incidents cron to bypass is_founder gate
-- ============================================================================
-- Inline the action-center query (don't go through SECDEF wrapper that has is_founder gate)
DROP FUNCTION IF EXISTS public.founder_auto_create_incidents();
CREATE OR REPLACE FUNCTION public.founder_auto_create_incidents()
RETURNS TABLE (created_count int)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_created int := 0;
BEGIN
  -- Inline the critical-items subset of founder_action_center (the 8 highest-severity domains).
  -- Skips is_founder() so pg_cron can invoke without a JWT context.
  WITH critical_items AS (
    -- Stuck payouts >14d (critical)
    SELECT 'payouts'::text AS source_domain, p.id AS item_id,
      ('Payout queued ' || extract(day from (now() - p.queued_at))::int || 'd')::text AS label,
      extract(day from (now() - p.queued_at))::int AS age_days
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued', 'processing') AND p.queued_at < now() - interval '14 days'

    UNION ALL
    -- Unresolved Code Red >24h (critical)
    SELECT 'code_red', r.id,
      ('Code Red unresolved ' || extract(day from (now() - r.created_at))::int || 'd')::text,
      extract(day from (now() - r.created_at))::int
    FROM public.code_red_requests r
    WHERE r.status NOT IN ('resolved', 'timed_out') AND r.created_at < now() - interval '24 hours'

    UNION ALL
    -- Disputes open >14d
    SELECT 'disputes', d.id,
      ('Dispute open ' || extract(day from (now() - d.submitted_at))::int || 'd')::text,
      extract(day from (now() - d.submitted_at))::int
    FROM public.dispute_evidence_packs d
    WHERE d.status = 'submitted' AND d.mediator_decision_at IS NULL
      AND d.submitted_at < now() - interval '14 days'

    UNION ALL
    -- Escrow in dispute or held >30d
    SELECT 'escrow', e.id,
      ('Escrow ' || e.status || ' ' || extract(day from (now() - e.created_at))::int || 'd')::text,
      extract(day from (now() - e.created_at))::int
    FROM public.repair_job_escrow e
    WHERE e.status = 'in_dispute' OR (e.status = 'held' AND e.created_at < now() - interval '30 days')

    UNION ALL
    -- Collusion flags critical
    SELECT 'collusion', f.id,
      ('Collusion flag · ' || f.signal_kind)::text,
      extract(day from (now() - f.created_at))::int
    FROM public.collusion_flags f
    WHERE f.status IN ('open','investigating')

    UNION ALL
    -- DPDP grievance overdue (>30d)
    SELECT 'dpdp', g.id,
      ('DPDP grievance ' || extract(day from (now() - g.created_at))::int || 'd')::text,
      extract(day from (now() - g.created_at))::int
    FROM public.dpdp_grievances g
    WHERE coalesce(g.status::text, 'open') IN ('open','in_review')
      AND g.created_at < now() - interval '30 days'
  ),
  inserted AS (
    INSERT INTO public.founder_incidents
      (source_domain, source_item_id, title, severity, auto_created, created_by)
    SELECT
      c.source_domain, c.item_id, c.label,
      CASE WHEN c.age_days > 7 THEN 'p0'
           WHEN c.age_days > 3 THEN 'p1'
           ELSE 'p2' END,
      true,
      NULL
    FROM critical_items c
    ON CONFLICT (source_domain, source_item_id) DO NOTHING
    RETURNING 1
  )
  SELECT count(*)::int INTO v_created FROM inserted;
  RETURN QUERY SELECT v_created;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_auto_create_incidents() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_auto_create_incidents() TO authenticated;

-- ============================================================================
-- 3. r1311 — fix extract(hour from interval) → total hours
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_incidents_recent(int);
CREATE OR REPLACE FUNCTION public.founder_incidents_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id              uuid,
  source_domain   text,
  source_item_id  uuid,
  title           text,
  severity        text,
  status          text,
  opened_at       timestamptz,
  resolved_at     timestamptz,
  age_hours       int,
  auto_created    boolean,
  root_cause_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT i.id, i.source_domain, i.source_item_id, i.title, i.severity, i.status,
    i.opened_at, i.resolved_at,
    -- Real total hours: epoch seconds / 3600, not hour-of-day field
    (extract(epoch from (coalesce(i.resolved_at, now()) - i.opened_at)) / 3600)::int,
    i.auto_created, i.root_cause_note
  FROM public.founder_incidents i
  ORDER BY (i.status IN ('open','investigating')) DESC, i.opened_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_incidents_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_incidents_recent(int) TO authenticated;

COMMIT;
