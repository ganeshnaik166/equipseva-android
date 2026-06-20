BEGIN;
-- r1395 ★★★★ — Hospital Portal v2 infrastructure (v0.6 Phase 7 shipped early).
--
-- Self-service portal infrastructure for hospital_admin users:
-- 1. hospital_portal_self_service_requests — tier upgrade/downgrade/cancellation
-- 2. hospital_portal_dispute_requests — formal dispute submission
-- 3. hospital_portal_feature_flags — per-org feature visibility
-- 4. hospital_portal_session_log — anti-abuse session telemetry
--
-- 8 RPCs covering: tier change requests, dispute submission, feature flag
-- read, founder admin summary, per-hospital request list.
--
-- This is foundation for /hospital/self-service (hospital_admin facing) +
-- /founder-hospital-portal-v2 (founder admin facing).

-- ============================================================================
-- 1. hospital_portal_self_service_requests
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.hospital_portal_self_service_requests (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amc_contract_id       uuid REFERENCES public.amc_contracts(id) ON DELETE SET NULL,
  request_kind          text NOT NULL CHECK (request_kind IN (
    'tier_upgrade','tier_downgrade','contract_cancel','contract_pause',
    'contract_resume','payment_method_change','billing_address_update',
    'add_equipment','remove_equipment','transfer_ownership','other'
  )),
  request_payload       jsonb DEFAULT '{}'::jsonb,
  desired_tier          text,
  desired_effective_date date,
  status                text NOT NULL DEFAULT 'submitted' CHECK (status IN (
    'submitted','under_review','approved','rejected','cancelled_by_hospital','expired'
  )),
  founder_response      text,
  reviewed_by           uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at           timestamptz,
  approved_effective_date date,
  submitted_at          timestamptz NOT NULL DEFAULT now(),
  expires_at            timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hpssr_hospital_status ON public.hospital_portal_self_service_requests (hospital_user_id, status);
CREATE INDEX IF NOT EXISTS idx_hpssr_status_submitted ON public.hospital_portal_self_service_requests (status, submitted_at DESC);
ALTER TABLE public.hospital_portal_self_service_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hpssr_hospital_owns ON public.hospital_portal_self_service_requests;
CREATE POLICY hpssr_hospital_owns ON public.hospital_portal_self_service_requests
  FOR SELECT USING (auth.uid() = hospital_user_id OR public.is_founder());
DROP POLICY IF EXISTS hpssr_hospital_insert_own ON public.hospital_portal_self_service_requests;
CREATE POLICY hpssr_hospital_insert_own ON public.hospital_portal_self_service_requests
  FOR INSERT WITH CHECK (auth.uid() = hospital_user_id);
REVOKE ALL ON public.hospital_portal_self_service_requests FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.hospital_portal_self_service_requests TO authenticated;

-- ============================================================================
-- 2. hospital_portal_dispute_requests
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.hospital_portal_dispute_requests (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amc_contract_id   uuid REFERENCES public.amc_contracts(id) ON DELETE SET NULL,
  repair_job_id     uuid,
  invoice_id        uuid,
  dispute_kind      text NOT NULL CHECK (dispute_kind IN (
    'billing_dispute','service_quality','sla_breach','engineer_behavior',
    'spare_part_quality','warranty_claim','data_privacy','other'
  )),
  description       text NOT NULL,
  desired_remedy    text,
  amount_claimed_rupees numeric,
  evidence_uris     text[] DEFAULT ARRAY[]::text[],
  status            text NOT NULL DEFAULT 'submitted' CHECK (status IN (
    'submitted','under_review','mediation_requested','accepted','rejected','withdrawn','escalated'
  )),
  founder_response  text,
  resolution_outcome text,
  resolved_amount_rupees numeric,
  reviewed_by       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at       timestamptz,
  resolved_at       timestamptz,
  submitted_at      timestamptz NOT NULL DEFAULT now(),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hpdr_hospital_status ON public.hospital_portal_dispute_requests (hospital_user_id, status);
CREATE INDEX IF NOT EXISTS idx_hpdr_status_kind ON public.hospital_portal_dispute_requests (status, dispute_kind);
ALTER TABLE public.hospital_portal_dispute_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hpdr_hospital_owns ON public.hospital_portal_dispute_requests;
CREATE POLICY hpdr_hospital_owns ON public.hospital_portal_dispute_requests
  FOR SELECT USING (auth.uid() = hospital_user_id OR public.is_founder());
DROP POLICY IF EXISTS hpdr_hospital_insert_own ON public.hospital_portal_dispute_requests;
CREATE POLICY hpdr_hospital_insert_own ON public.hospital_portal_dispute_requests
  FOR INSERT WITH CHECK (auth.uid() = hospital_user_id);
REVOKE ALL ON public.hospital_portal_dispute_requests FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.hospital_portal_dispute_requests TO authenticated;

-- ============================================================================
-- 3. hospital_portal_feature_flags
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.hospital_portal_feature_flags (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  flag_key        text NOT NULL,
  is_enabled      boolean NOT NULL DEFAULT false,
  rollout_band    text DEFAULT 'pilot' CHECK (rollout_band IN ('alpha','beta','pilot','ga','dark_launch','sunset')),
  enabled_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  enabled_at      timestamptz,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(hospital_user_id, flag_key)
);
CREATE INDEX IF NOT EXISTS idx_hpff_hospital ON public.hospital_portal_feature_flags (hospital_user_id, is_enabled);
ALTER TABLE public.hospital_portal_feature_flags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hpff_hospital_owns ON public.hospital_portal_feature_flags;
CREATE POLICY hpff_hospital_owns ON public.hospital_portal_feature_flags
  FOR SELECT USING (auth.uid() = hospital_user_id OR public.is_founder());
REVOKE ALL ON public.hospital_portal_feature_flags FROM PUBLIC, anon;
GRANT SELECT ON public.hospital_portal_feature_flags TO authenticated;

-- ============================================================================
-- 4. hospital_portal_session_log
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.hospital_portal_session_log (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_kind       text NOT NULL CHECK (action_kind IN (
    'login','view_invoice','view_dispute','submit_request','submit_dispute',
    'view_visit_history','export_data','logout','session_timeout'
  )),
  surface_path      text,
  ip_hash           text,
  user_agent_hash   text,
  outcome           text DEFAULT 'ok' CHECK (outcome IN ('ok','denied','rate_limited','expired')),
  performed_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hpsl_hospital ON public.hospital_portal_session_log (hospital_user_id, performed_at DESC);
ALTER TABLE public.hospital_portal_session_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hpsl_hospital_owns ON public.hospital_portal_session_log;
CREATE POLICY hpsl_hospital_owns ON public.hospital_portal_session_log
  FOR SELECT USING (auth.uid() = hospital_user_id OR public.is_founder());
REVOKE ALL ON public.hospital_portal_session_log FROM PUBLIC, anon;
GRANT SELECT ON public.hospital_portal_session_log TO authenticated;

-- ============================================================================
-- FOUNDER ADMIN RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_hospital_portal_v2_summary();
CREATE OR REPLACE FUNCTION public.founder_hospital_portal_v2_summary()
RETURNS TABLE (
  total_self_service_requests         bigint,
  requests_submitted_count            bigint,
  requests_under_review_count         bigint,
  requests_approved_count             bigint,
  requests_rejected_count             bigint,
  requests_expired_count              bigint,
  requests_30d                        bigint,
  top_request_kind                    text,
  total_dispute_requests              bigint,
  disputes_submitted_count            bigint,
  disputes_resolved_count             bigint,
  disputes_escalated_count            bigint,
  disputes_30d                        bigint,
  top_dispute_kind                    text,
  active_feature_flags_total          bigint,
  hospitals_with_active_flags         bigint,
  session_logs_30d                    bigint,
  rate_limited_attempts_30d           bigint,
  generated_at                        timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.hospital_portal_self_service_requests)::bigint,
    (SELECT count(*) FROM public.hospital_portal_self_service_requests WHERE status = 'submitted')::bigint,
    (SELECT count(*) FROM public.hospital_portal_self_service_requests WHERE status = 'under_review')::bigint,
    (SELECT count(*) FROM public.hospital_portal_self_service_requests WHERE status = 'approved')::bigint,
    (SELECT count(*) FROM public.hospital_portal_self_service_requests WHERE status = 'rejected')::bigint,
    (SELECT count(*) FROM public.hospital_portal_self_service_requests WHERE status = 'expired')::bigint,
    (SELECT count(*) FROM public.hospital_portal_self_service_requests WHERE submitted_at >= now() - interval '30 days')::bigint,
    (SELECT request_kind FROM public.hospital_portal_self_service_requests
      GROUP BY request_kind ORDER BY count(*) DESC LIMIT 1),
    (SELECT count(*) FROM public.hospital_portal_dispute_requests)::bigint,
    (SELECT count(*) FROM public.hospital_portal_dispute_requests WHERE status = 'submitted')::bigint,
    (SELECT count(*) FROM public.hospital_portal_dispute_requests WHERE status IN ('accepted','rejected'))::bigint,
    (SELECT count(*) FROM public.hospital_portal_dispute_requests WHERE status = 'escalated')::bigint,
    (SELECT count(*) FROM public.hospital_portal_dispute_requests WHERE submitted_at >= now() - interval '30 days')::bigint,
    (SELECT dispute_kind FROM public.hospital_portal_dispute_requests
      GROUP BY dispute_kind ORDER BY count(*) DESC LIMIT 1),
    (SELECT count(*) FROM public.hospital_portal_feature_flags WHERE is_enabled)::bigint,
    (SELECT count(DISTINCT hospital_user_id) FROM public.hospital_portal_feature_flags WHERE is_enabled)::bigint,
    (SELECT count(*) FROM public.hospital_portal_session_log WHERE performed_at >= now() - interval '30 days')::bigint,
    (SELECT count(*) FROM public.hospital_portal_session_log WHERE outcome = 'rate_limited' AND performed_at >= now() - interval '30 days')::bigint,
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_portal_v2_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_portal_v2_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_hospital_portal_v2_requests_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_hospital_portal_v2_requests_recent(p_status text DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid, hospital_user_id uuid, amc_contract_id uuid,
  request_kind text, desired_tier text, status text,
  submitted_at timestamptz, expires_at timestamptz, age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_user_id, r.amc_contract_id, r.request_kind,
         r.desired_tier, r.status, r.submitted_at, r.expires_at,
         extract(day FROM (now() - r.submitted_at))::int
  FROM public.hospital_portal_self_service_requests r
  WHERE (p_status IS NULL OR r.status = p_status)
  ORDER BY r.submitted_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_portal_v2_requests_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_portal_v2_requests_recent(text, int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_hospital_portal_v2_disputes_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_hospital_portal_v2_disputes_recent(p_status text DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid, hospital_user_id uuid, dispute_kind text, status text,
  amount_claimed_rupees numeric, submitted_at timestamptz, age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT d.id, d.hospital_user_id, d.dispute_kind, d.status,
         d.amount_claimed_rupees, d.submitted_at,
         extract(day FROM (now() - d.submitted_at))::int
  FROM public.hospital_portal_dispute_requests d
  WHERE (p_status IS NULL OR d.status = p_status)
  ORDER BY d.submitted_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_portal_v2_disputes_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_portal_v2_disputes_recent(text, int) TO authenticated;

-- ============================================================================
-- HOSPITAL-CALLABLE RPCs (authenticated, RLS-scoped to caller)
-- ============================================================================

DROP FUNCTION IF EXISTS public.hospital_portal_submit_self_service_request(text, text, jsonb, date);
CREATE OR REPLACE FUNCTION public.hospital_portal_submit_self_service_request(
  p_request_kind text, p_desired_tier text DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb, p_desired_effective_date date DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;
  INSERT INTO public.hospital_portal_self_service_requests (
    hospital_user_id, request_kind, desired_tier, request_payload, desired_effective_date
  ) VALUES (v_caller, p_request_kind, p_desired_tier, coalesce(p_payload, '{}'::jsonb), p_desired_effective_date)
  RETURNING id INTO v_id;

  INSERT INTO public.hospital_portal_session_log (hospital_user_id, action_kind, outcome)
  VALUES (v_caller, 'submit_request', 'ok');

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_portal_submit_self_service_request(text, text, jsonb, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_portal_submit_self_service_request(text, text, jsonb, date) TO authenticated;

DROP FUNCTION IF EXISTS public.hospital_portal_submit_dispute(text, text, text, numeric, text[]);
CREATE OR REPLACE FUNCTION public.hospital_portal_submit_dispute(
  p_dispute_kind text, p_description text, p_desired_remedy text DEFAULT NULL,
  p_amount_claimed_rupees numeric DEFAULT NULL, p_evidence_uris text[] DEFAULT ARRAY[]::text[]
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;
  INSERT INTO public.hospital_portal_dispute_requests (
    hospital_user_id, dispute_kind, description, desired_remedy,
    amount_claimed_rupees, evidence_uris
  ) VALUES (
    v_caller, p_dispute_kind, p_description, p_desired_remedy,
    p_amount_claimed_rupees, coalesce(p_evidence_uris, ARRAY[]::text[])
  ) RETURNING id INTO v_id;

  INSERT INTO public.hospital_portal_session_log (hospital_user_id, action_kind, outcome)
  VALUES (v_caller, 'submit_dispute', 'ok');

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_portal_submit_dispute(text, text, text, numeric, text[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_portal_submit_dispute(text, text, text, numeric, text[]) TO authenticated;

DROP FUNCTION IF EXISTS public.hospital_portal_my_requests(int);
CREATE OR REPLACE FUNCTION public.hospital_portal_my_requests(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid, request_kind text, desired_tier text, status text,
  submitted_at timestamptz, expires_at timestamptz, founder_response text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT r.id, r.request_kind, r.desired_tier, r.status, r.submitted_at, r.expires_at, r.founder_response
  FROM public.hospital_portal_self_service_requests r
  WHERE r.hospital_user_id = v_caller
  ORDER BY r.submitted_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_portal_my_requests(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_portal_my_requests(int) TO authenticated;

DROP FUNCTION IF EXISTS public.hospital_portal_my_disputes(int);
CREATE OR REPLACE FUNCTION public.hospital_portal_my_disputes(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid, dispute_kind text, status text, amount_claimed_rupees numeric,
  resolved_amount_rupees numeric, submitted_at timestamptz, resolved_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'auth required' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT d.id, d.dispute_kind, d.status, d.amount_claimed_rupees,
         d.resolved_amount_rupees, d.submitted_at, d.resolved_at
  FROM public.hospital_portal_dispute_requests d
  WHERE d.hospital_user_id = v_caller
  ORDER BY d.submitted_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_portal_my_disputes(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_portal_my_disputes(int) TO authenticated;

-- ============================================================================
-- FOUNDER WRITE: approve/reject self-service request
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_hpv2_review_request(uuid, text, text, date);
CREATE OR REPLACE FUNCTION public.log_founder_hpv2_review_request(
  p_request_id uuid, p_new_status text, p_response text DEFAULT NULL, p_approved_effective_date date DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.hospital_portal_self_service_requests
  SET status = p_new_status,
      founder_response = p_response,
      approved_effective_date = p_approved_effective_date,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  WHERE id = p_request_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_hpv2_review_request(uuid, text, text, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_hpv2_review_request(uuid, text, text, date) TO authenticated;

-- ============================================================================
-- FOUNDER WRITE: review/resolve dispute
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_hpv2_review_dispute(uuid, text, text, text, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_hpv2_review_dispute(
  p_dispute_id uuid, p_new_status text, p_response text DEFAULT NULL,
  p_resolution_outcome text DEFAULT NULL, p_resolved_amount_rupees numeric DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.hospital_portal_dispute_requests
  SET status = p_new_status,
      founder_response = p_response,
      resolution_outcome = p_resolution_outcome,
      resolved_amount_rupees = p_resolved_amount_rupees,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      resolved_at = CASE WHEN p_new_status IN ('accepted','rejected') THEN now() ELSE resolved_at END,
      updated_at = now()
  WHERE id = p_dispute_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_hpv2_review_dispute(uuid, text, text, text, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_hpv2_review_dispute(uuid, text, text, text, numeric) TO authenticated;

-- ============================================================================
-- CRON: expire stale requests (>14d)
-- ============================================================================
DROP FUNCTION IF EXISTS public.hospital_portal_v2_expire_stale_requests();
CREATE OR REPLACE FUNCTION public.hospital_portal_v2_expire_stale_requests()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_count int := 0;
BEGIN
  UPDATE public.hospital_portal_self_service_requests
  SET status = 'expired', updated_at = now()
  WHERE status = 'submitted' AND expires_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_portal_v2_expire_stale_requests() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_portal_v2_expire_stale_requests() TO authenticated;

COMMIT;
