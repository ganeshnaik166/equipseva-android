BEGIN;

-- r1199 — founder_compliance_evidence_snapshot_summary()
-- 15-KPI consolidated dashboard for the entire regulatory backbone:
--   * §65B evidence ledger writes (r492)        — public.evidence_ledger
--   * DPDP grievance pipeline (r485)            — public.dpdp_grievances
--   * Consent log activity (r485)               — public.consent_log
--   * DSR hospital sign-off queue (r494)        — public.dsr_reports
--   * NABH bundle exports (r522 audit ledger)   — public.nabh_export_audit
--   * Founder action audit volume (r482)        — public.founder_action_log
--
-- Column truth-table verified by Read against actual migrations:
--   evidence_ledger     : created_at
--   dpdp_grievances     : status, grievance_type, sla_hours, deadline_at, created_at
--                         status enum: open,in_review,resolved,escalated,rejected
--                         grievance_type 'data_breach_notification' uses 72h SLA
--   consent_log         : user_id, action ('granted'|'revoked'), created_at
--   dsr_reports         : status ('pending_hospital_sign'|'signed'|'disputed'|'invalidated'),
--                         engineer_signature_at, hospital_signature_at, created_at
--   nabh_export_audit   : user_id, occurred_at
--   founder_action_log  : created_at, outcome
--
-- IST-day boundary pattern for *_today KPIs.

DROP FUNCTION IF EXISTS public.founder_compliance_evidence_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_compliance_evidence_snapshot_summary()
RETURNS TABLE (
  evidence_rows_all_time            bigint,
  evidence_rows_24h                 bigint,
  evidence_rows_7d                  bigint,
  evidence_rows_30d                 bigint,
  dpdp_grievances_open              bigint,
  dpdp_grievances_breach_open       bigint,
  dpdp_grievances_within_72h        bigint,
  dpdp_grievances_overdue           bigint,
  consent_revocations_24h           bigint,
  consents_granted_24h              bigint,
  dsr_pending_hospital_sign         bigint,
  dsr_signed_30d                    bigint,
  nabh_exports_30d                  bigint,
  founder_actions_24h               bigint,
  founder_actions_7d                bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH
    ev_all AS (
      SELECT count(*)::bigint AS c FROM public.evidence_ledger
    ),
    ev_24h AS (
      SELECT count(*)::bigint AS c FROM public.evidence_ledger
      WHERE created_at >= now() - interval '24 hours'
    ),
    ev_7d AS (
      SELECT count(*)::bigint AS c FROM public.evidence_ledger
      WHERE created_at >= now() - interval '7 days'
    ),
    ev_30d AS (
      SELECT count(*)::bigint AS c FROM public.evidence_ledger
      WHERE created_at >= now() - interval '30 days'
    ),
    griev_open AS (
      SELECT count(*)::bigint AS c FROM public.dpdp_grievances
      WHERE status IN ('open','in_review')
    ),
    griev_breach_open AS (
      SELECT count(*)::bigint AS c FROM public.dpdp_grievances
      WHERE status IN ('open','in_review')
        AND grievance_type = 'data_breach_notification'
    ),
    griev_within_72h AS (
      SELECT count(*)::bigint AS c FROM public.dpdp_grievances
      WHERE status IN ('open','in_review')
        AND deadline_at > now()
        AND deadline_at <= now() + interval '72 hours'
    ),
    griev_overdue AS (
      SELECT count(*)::bigint AS c FROM public.dpdp_grievances
      WHERE status IN ('open','in_review')
        AND deadline_at < now()
    ),
    cons_rev_24h AS (
      SELECT count(*)::bigint AS c FROM public.consent_log
      WHERE action = 'revoked'
        AND created_at >= now() - interval '24 hours'
    ),
    cons_grant_24h AS (
      SELECT count(*)::bigint AS c FROM public.consent_log
      WHERE action = 'granted'
        AND created_at >= now() - interval '24 hours'
    ),
    dsr_pending AS (
      SELECT count(*)::bigint AS c FROM public.dsr_reports
      WHERE status = 'pending_hospital_sign'
    ),
    dsr_signed_30 AS (
      SELECT count(*)::bigint AS c FROM public.dsr_reports
      WHERE status = 'signed'
        AND hospital_signature_at IS NOT NULL
        AND hospital_signature_at >= now() - interval '30 days'
    ),
    nabh_30 AS (
      SELECT count(*)::bigint AS c FROM public.nabh_export_audit
      WHERE occurred_at >= now() - interval '30 days'
    ),
    fa_24h AS (
      SELECT count(*)::bigint AS c FROM public.founder_action_log
      WHERE created_at >= now() - interval '24 hours'
    ),
    fa_7d AS (
      SELECT count(*)::bigint AS c FROM public.founder_action_log
      WHERE created_at >= now() - interval '7 days'
    )
  SELECT
    (SELECT c FROM ev_all)              AS evidence_rows_all_time,
    (SELECT c FROM ev_24h)              AS evidence_rows_24h,
    (SELECT c FROM ev_7d)               AS evidence_rows_7d,
    (SELECT c FROM ev_30d)              AS evidence_rows_30d,
    (SELECT c FROM griev_open)          AS dpdp_grievances_open,
    (SELECT c FROM griev_breach_open)   AS dpdp_grievances_breach_open,
    (SELECT c FROM griev_within_72h)    AS dpdp_grievances_within_72h,
    (SELECT c FROM griev_overdue)       AS dpdp_grievances_overdue,
    (SELECT c FROM cons_rev_24h)        AS consent_revocations_24h,
    (SELECT c FROM cons_grant_24h)      AS consents_granted_24h,
    (SELECT c FROM dsr_pending)         AS dsr_pending_hospital_sign,
    (SELECT c FROM dsr_signed_30)       AS dsr_signed_30d,
    (SELECT c FROM nabh_30)             AS nabh_exports_30d,
    (SELECT c FROM fa_24h)              AS founder_actions_24h,
    (SELECT c FROM fa_7d)               AS founder_actions_7d;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_compliance_evidence_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_compliance_evidence_snapshot_summary() TO authenticated;

COMMIT;