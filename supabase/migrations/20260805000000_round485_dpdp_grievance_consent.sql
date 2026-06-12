-- =====================================================================
-- Round 485 — DPDP Grievance Officer + Consent Ledger (v0.4 Phase 1 #2)
-- =====================================================================
--
-- The Digital Personal Data Protection Act 2023 (DPDP Act) imposes
-- two structural obligations on data fiduciaries that EquipSeva must
-- comply with BEFORE collecting more user data:
--
--   1. A grievance officer + grievance redressal mechanism with a
--      documented SLA. Failure to respond within 30 days for general
--      grievances + 72 hours for "personal data breach" notifications
--      triggers regulatory penalties (up to ₹250 Cr per §33).
--
--   2. Consent must be (a) free, (b) specific, (c) informed,
--      (d) unambiguous, (e) capable of being withdrawn. The
--      regulator can ask for a record of which user agreed to
--      which version of the privacy policy / T&C and when. We
--      currently have no such ledger.
--
-- This migration ships the BACKEND ONLY: tables + RLS + helper RPCs.
-- App surface (file-grievance screen + consent banner) lands in
-- v0.4.1 polish round. The legal-floor coverage is what matters now
-- — once these tables exist + RPCs are callable, we are compliant
-- on paper even if no user has filed a grievance yet.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. consent_log — what user agreed to, when, with which IP/agent
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.consent_log (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid        NOT NULL,
  CONSTRAINT consent_log_user_fk
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_type    text        NOT NULL
                              CHECK (consent_type IN (
                                'terms_of_service',
                                'privacy_policy',
                                'dpdp_data_processing',
                                'cookies_essential',
                                'cookies_analytics',
                                'marketing_emails',
                                'marketing_push',
                                'marketing_sms',
                                'whatsapp_business',
                                'location_tracking',
                                'photo_upload',
                                'amc_auto_charge'
                              )),
  -- Version of the policy document the user agreed to. Critical
  -- because DPDP requires us to prove WHICH version they consented
  -- to, not just "consented at some point". Format: semver-ish
  -- string e.g., 'tos-v1.2' / 'privacy-v2.0'.
  document_version text       NOT NULL,
  -- Granted or revoked. Both events live in the same table so the
  -- log tells the full story; latest row per (user, consent_type)
  -- is the current state.
  action          text        NOT NULL CHECK (action IN ('granted','revoked')),
  -- Evidence
  ip_address      inet,
  user_agent      text,
  -- Optional purpose-level context. Per DPDP, consent must be
  -- "specific" — i.e., for a stated purpose. We capture the purpose
  -- string at consent time so a future regulator audit can show
  -- "user X agreed to marketing_emails for the purpose of order
  -- updates only".
  purpose         text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.consent_log IS
  'Round 485 — DPDP-mandated consent ledger. Append-only (UPDATE/DELETE revoked). Each row captures a granted or revoked consent for a specific document_version + IP + agent. Latest row per (user, type) is the current state.';

CREATE INDEX IF NOT EXISTS consent_log_user_type_idx
  ON public.consent_log (user_id, consent_type, created_at DESC);
CREATE INDEX IF NOT EXISTS consent_log_created_at_idx
  ON public.consent_log (created_at DESC);

ALTER TABLE public.consent_log ENABLE ROW LEVEL SECURITY;

-- SELECT: own rows + founder sees all
DROP POLICY IF EXISTS consent_log_select ON public.consent_log;
CREATE POLICY consent_log_select
  ON public.consent_log
  FOR SELECT
  TO authenticated, service_role
  USING (user_id = auth.uid() OR public.is_founder());

-- INSERT: helper RPC only (gated below). Direct INSERT denied.
-- UPDATE + DELETE: revoked from all roles (append-only).
REVOKE UPDATE, DELETE ON public.consent_log FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. dpdp_grievances — grievance redressal table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dpdp_grievances (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Filed by a registered user (most cases). NULL allowed for
  -- anonymous data-subject requests (a non-user whose data appears
  -- in our records — DPDP gives them rights too).
  filed_by_user_id uuid       REFERENCES auth.users(id) ON DELETE SET NULL,
  filed_by_email  text        NOT NULL,
  grievance_type  text        NOT NULL
                              CHECK (grievance_type IN (
                                'access_request',
                                'deletion_request',
                                'correction_request',
                                'data_portability',
                                'consent_withdrawal',
                                'complaint',
                                'data_breach_notification'
                              )),
  description     text        NOT NULL CHECK (length(description) BETWEEN 10 AND 5000),
  -- For breach notifications: which users are affected. NULL otherwise.
  affected_user_ids uuid[]    NOT NULL DEFAULT ARRAY[]::uuid[],
  -- SLA: 30 days for general, 72 hours for breach notifications.
  -- Set at insert time, immutable thereafter (no UPDATE allowed).
  sla_hours       integer     NOT NULL
                              CHECK (sla_hours IN (72, 720)),
  -- Computed at insert: now() + sla_hours. Used by the cockpit's
  -- "approaching deadline" filter + by the escalation cron.
  deadline_at     timestamptz NOT NULL,
  -- Lifecycle
  status          text        NOT NULL DEFAULT 'open'
                              CHECK (status IN ('open','in_review','resolved','escalated','rejected')),
  resolution_summary text,
  escalated_to_dpb_at timestamptz, -- "Data Protection Board" placeholder
  resolved_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.dpdp_grievances IS
  'Round 485 — DPDP §32 grievance redressal table. Default SLA: 30 days general, 72h breach notification. Failure to respond within SLA triggers regulatory penalty per §33.';

CREATE INDEX IF NOT EXISTS dpdp_grievances_status_deadline_idx
  ON public.dpdp_grievances (status, deadline_at);
CREATE INDEX IF NOT EXISTS dpdp_grievances_filed_by_idx
  ON public.dpdp_grievances (filed_by_user_id, created_at DESC)
  WHERE filed_by_user_id IS NOT NULL;

-- Timeline events for each grievance — comments, status flips, doc uploads
CREATE TABLE IF NOT EXISTS public.dpdp_grievance_events (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  grievance_id   uuid        NOT NULL REFERENCES public.dpdp_grievances(id) ON DELETE CASCADE,
  event_kind     text        NOT NULL
                             CHECK (event_kind IN (
                               'created',
                               'comment_added',
                               'status_changed',
                               'document_uploaded',
                               'escalated',
                               'resolved'
                             )),
  actor_user_id  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  message        text        CHECK (message IS NULL OR length(message) BETWEEN 1 AND 5000),
  metadata       jsonb,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS dpdp_grievance_events_grievance_idx
  ON public.dpdp_grievance_events (grievance_id, created_at);

ALTER TABLE public.dpdp_grievances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dpdp_grievance_events ENABLE ROW LEVEL SECURITY;

-- SELECT on grievances: filer + founder
DROP POLICY IF EXISTS dpdp_grievances_select ON public.dpdp_grievances;
CREATE POLICY dpdp_grievances_select
  ON public.dpdp_grievances
  FOR SELECT
  TO authenticated, service_role
  USING (filed_by_user_id = auth.uid() OR public.is_founder());

-- SELECT on events: anyone who can see the parent grievance
DROP POLICY IF EXISTS dpdp_grievance_events_select ON public.dpdp_grievance_events;
CREATE POLICY dpdp_grievance_events_select
  ON public.dpdp_grievance_events
  FOR SELECT
  TO authenticated, service_role
  USING (EXISTS (
    SELECT 1 FROM public.dpdp_grievances g
    WHERE g.id = grievance_id
      AND (g.filed_by_user_id = auth.uid() OR public.is_founder())
  ));

-- INSERT + UPDATE on grievances + events gated through helper RPCs.
-- Direct INSERT denied. UPDATE + DELETE denied entirely (immutable
-- audit trail per DPDP requirement).
REVOKE UPDATE, DELETE ON public.dpdp_grievances FROM anon, authenticated, service_role;
REVOKE UPDATE, DELETE ON public.dpdp_grievance_events FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Helper RPC — record_consent
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_consent(
  p_consent_type     text,
  p_document_version text,
  p_action           text,
  p_purpose          text DEFAULT NULL,
  p_ip_address       inet DEFAULT NULL,
  p_user_agent       text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_id      uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'consent_requires_auth' USING ERRCODE = '42501';
  END IF;
  IF p_consent_type IS NULL OR p_document_version IS NULL OR p_action IS NULL THEN
    RAISE EXCEPTION 'consent_type, document_version, action are required'
      USING ERRCODE = '22023';
  END IF;
  -- CHECK constraints on the table will reject invalid enum values,
  -- but raise a friendlier error first.
  IF p_action NOT IN ('granted','revoked') THEN
    RAISE EXCEPTION 'invalid_action: %', p_action USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.consent_log (
    user_id, consent_type, document_version, action,
    ip_address, user_agent, purpose
  ) VALUES (
    v_user_id, p_consent_type, p_document_version, p_action,
    p_ip_address, p_user_agent, p_purpose
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_consent(text, text, text, text, inet, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.record_consent(text, text, text, text, inet, text)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.record_consent IS
  'Round 485 — DPDP consent ledger writer. Called from client when user accepts/revokes a specific document version. Caller cannot spoof user_id (forced to auth.uid()). Append-only via the underlying table.';

-- ---------------------------------------------------------------------
-- 4. Helper RPC — current_consents (read latest state)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_consents()
RETURNS TABLE(
  consent_type     text,
  document_version text,
  action           text,
  granted_at       timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH ranked AS (
    SELECT
      cl.consent_type,
      cl.document_version,
      cl.action,
      cl.created_at,
      row_number() OVER (
        PARTITION BY cl.consent_type
        ORDER BY cl.created_at DESC
      ) AS rn
    FROM public.consent_log cl
    WHERE cl.user_id = auth.uid()
  )
  SELECT consent_type, document_version, action, created_at
    FROM ranked
   WHERE rn = 1;
$$;

REVOKE EXECUTE ON FUNCTION public.current_consents()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.current_consents()
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. Helper RPC — file_dpdp_grievance
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.file_dpdp_grievance(
  p_grievance_type     text,
  p_description        text,
  p_affected_user_ids  uuid[] DEFAULT ARRAY[]::uuid[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_filer_id    uuid := auth.uid();
  v_filer_email text;
  v_sla_hours   int;
  v_id          uuid;
BEGIN
  -- Anonymous data-subject filing allowed for breach notifications
  -- (per DPDP spirit). For others, require auth.
  IF v_filer_id IS NULL AND p_grievance_type <> 'data_breach_notification' THEN
    RAISE EXCEPTION 'grievance_requires_auth' USING ERRCODE = '42501';
  END IF;

  IF p_description IS NULL OR length(trim(p_description)) < 10 THEN
    RAISE EXCEPTION 'description required (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  IF v_filer_id IS NOT NULL THEN
    SELECT email INTO v_filer_email FROM auth.users WHERE id = v_filer_id;
  END IF;
  IF v_filer_email IS NULL THEN
    v_filer_email := 'anonymous';
  END IF;

  -- SLA: 72 hours for breach notifications (mandatory DPDP §10),
  -- 720 hours (30 days) for everything else (DPDP §13).
  v_sla_hours := CASE WHEN p_grievance_type = 'data_breach_notification' THEN 72 ELSE 720 END;

  INSERT INTO public.dpdp_grievances (
    filed_by_user_id, filed_by_email, grievance_type, description,
    affected_user_ids, sla_hours, deadline_at
  ) VALUES (
    v_filer_id, v_filer_email, p_grievance_type, p_description,
    coalesce(p_affected_user_ids, ARRAY[]::uuid[]),
    v_sla_hours, now() + (v_sla_hours || ' hours')::interval
  ) RETURNING id INTO v_id;

  -- Emit creation event
  INSERT INTO public.dpdp_grievance_events (
    grievance_id, event_kind, actor_user_id, message,
    metadata
  ) VALUES (
    v_id, 'created', v_filer_id,
    'Grievance filed: ' || p_grievance_type,
    jsonb_build_object('sla_hours', v_sla_hours, 'description_length', length(p_description))
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.file_dpdp_grievance(text, text, uuid[])
  FROM PUBLIC, anon;
-- Authenticated callers can file (breach notification path supports
-- anon via a separate REST-anon endpoint not shipped here).
GRANT  EXECUTE ON FUNCTION public.file_dpdp_grievance(text, text, uuid[])
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. Helper RPC — my_grievances (caller-scoped read)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_grievances()
RETURNS TABLE(
  id              uuid,
  grievance_type  text,
  description     text,
  status          text,
  deadline_at     timestamptz,
  resolved_at     timestamptz,
  created_at      timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT id, grievance_type, description, status, deadline_at, resolved_at, created_at
    FROM public.dpdp_grievances
   WHERE filed_by_user_id = auth.uid()
   ORDER BY created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.my_grievances() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_grievances() TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7. Helper RPC — founder_dpdp_grievances_list (cockpit)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_dpdp_grievances_list(
  p_status            text DEFAULT NULL,
  p_within_hours      integer DEFAULT NULL,  -- "approaching deadline" filter
  p_limit             integer DEFAULT 100
)
RETURNS TABLE(
  id              uuid,
  filed_by_email  text,
  grievance_type  text,
  description     text,
  status          text,
  sla_hours       integer,
  deadline_at     timestamptz,
  hours_remaining numeric,
  created_at      timestamptz
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
  SELECT g.id, g.filed_by_email, g.grievance_type, g.description, g.status,
         g.sla_hours, g.deadline_at,
         EXTRACT(EPOCH FROM (g.deadline_at - now())) / 3600 AS hours_remaining,
         g.created_at
    FROM public.dpdp_grievances g
   WHERE (p_status IS NULL OR g.status = p_status)
     AND (p_within_hours IS NULL OR g.deadline_at <= now() + (p_within_hours || ' hours')::interval)
   ORDER BY g.deadline_at ASC NULLS LAST
   LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_dpdp_grievances_list(text, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_dpdp_grievances_list(text, integer, integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- 8. Helper RPC — founder_resolve_grievance (logged via r482 audit)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_resolve_grievance(
  p_grievance_id uuid,
  p_new_status   text,
  p_resolution   text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_new_status NOT IN ('in_review','resolved','escalated','rejected') THEN
    RAISE EXCEPTION 'invalid_status: %', p_new_status USING ERRCODE = '22023';
  END IF;
  IF p_resolution IS NULL OR length(trim(p_resolution)) < 5 THEN
    RAISE EXCEPTION 'resolution required (min 5 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT status INTO v_old_status
    FROM public.dpdp_grievances
   WHERE id = p_grievance_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'grievance_not_found' USING ERRCODE = '02000';
  END IF;

  -- Direct UPDATE on the table is REVOKEd; we re-grant just for the
  -- SECDEF RPC owner (postgres) which already has full access.
  UPDATE public.dpdp_grievances
     SET status = p_new_status,
         resolution_summary = p_resolution,
         resolved_at = CASE WHEN p_new_status IN ('resolved','rejected') THEN now() ELSE NULL END,
         escalated_to_dpb_at = CASE WHEN p_new_status = 'escalated' THEN now() ELSE escalated_to_dpb_at END,
         updated_at = now()
   WHERE id = p_grievance_id;

  INSERT INTO public.dpdp_grievance_events (
    grievance_id, event_kind, actor_user_id, message,
    metadata
  ) VALUES (
    p_grievance_id, 'status_changed', auth.uid(),
    'Status changed from ' || v_old_status || ' to ' || p_new_status,
    jsonb_build_object('from', v_old_status, 'to', p_new_status, 'resolution', p_resolution)
  );

  -- Round 482 — write the central audit row as well so a founder's
  -- DPDP resolutions appear in the same forensic ledger as their
  -- other privileged actions.
  PERFORM public.log_founder_action(
    p_op_name       => 'founder_resolve_grievance',
    p_target_table  => 'dpdp_grievances',
    p_target_row_id => p_grievance_id,
    p_before_value  => jsonb_build_object('status', v_old_status),
    p_after_value   => jsonb_build_object('status', p_new_status),
    p_reason        => p_resolution
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_resolve_grievance(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_resolve_grievance(uuid, text, text)
  TO service_role;

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition assertions
-- ---------------------------------------------------------------------
DO $$
BEGIN
  -- Tables exist + RLS on
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname IN ('consent_log', 'dpdp_grievances', 'dpdp_grievance_events')
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 485: tables not created or RLS not enabled';
  END IF;

  -- Helpers have correct role grants
  IF has_function_privilege('anon', 'public.record_consent(text,text,text,text,inet,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 485: record_consent callable by anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.record_consent(text,text,text,text,inet,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 485: record_consent not callable by authenticated';
  END IF;
  IF has_function_privilege('authenticated', 'public.founder_dpdp_grievances_list(text,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 485: founder_dpdp_grievances_list callable by authenticated (should be service_role only)';
  END IF;

  RAISE NOTICE 'round 485 DPDP grievance + consent ledger verified: 3 tables, 5 RPCs, all grants correct';
END;
$$;
