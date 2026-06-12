-- =====================================================================
-- Round 495 — Dispute Defense Vault + Mediation Console
-- v0.4 Phase 3 #5 + #6
-- =====================================================================
--
-- Existing repair_job_escrow has dispute_reason/resolution columns
-- but no STRUCTURED evidence pack alongside. When a dispute opens,
-- both sides scramble to remember what happened; founder triages
-- with WhatsApp screenshots. This is unscalable + indefensible in
-- court.
--
-- Two surfaces:
--
-- 1. DISPUTE DEFENSE VAULT (engineer-facing): the engineer's
--    side-of-story bundle. When a dispute opens, the engineer can
--    auto-collate every photo, chat message, geo-pin, signature,
--    DSR, and PVED tied to the disputed job. The vault produces a
--    structured payload (suitable for §65B certificate via r492)
--    that supports the engineer's defense.
--
-- 2. MEDIATION CONSOLE (founder-facing): the queue + evidence-pack
--    export. Founder sees disputes ranked by escalation severity,
--    can attach mediation findings, and writes the resolution
--    via existing admin_resolve_escrow_dispute (already gated +
--    audited by r482 + r487 triggers).
--
-- The dispute *resolution* RPC already exists. This migration adds
-- the supporting infrastructure that makes resolution defensible.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. dispute_evidence_packs
-- ---------------------------------------------------------------------
-- One pack per dispute side. Status moves draft → submitted →
-- (mediator) accepted/rejected. The pack itself is a structured
-- snapshot; the underlying evidence rows in evidence_ledger don't
-- change.
CREATE TABLE IF NOT EXISTS public.dispute_evidence_packs (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_escrow_id uuid       NOT NULL REFERENCES public.repair_job_escrow(id) ON DELETE CASCADE,
  repair_job_id       uuid        NOT NULL REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  -- Side filing the pack
  filed_by_user_id    uuid        NOT NULL,
  CONSTRAINT dispute_pack_filer_fk
    FOREIGN KEY (filed_by_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT,
  filer_role          text        NOT NULL CHECK (filer_role IN ('engineer','hospital')),
  -- Narrative
  position_statement  text        NOT NULL CHECK (length(position_statement) BETWEEN 20 AND 5000),
  -- Refs to evidence_ledger rows the filer is invoking
  evidence_ledger_ids uuid[]      NOT NULL DEFAULT ARRAY[]::uuid[],
  -- Linked DSR (if filer is engineer + DSR exists)
  dsr_id              uuid        REFERENCES public.dsr_reports(id) ON DELETE SET NULL,
  -- Linked PVED (engineer credential snapshot at job time)
  pved_id             uuid        REFERENCES public.pre_visit_engineer_dossiers(id) ON DELETE SET NULL,
  -- Computed counters for triage
  evidence_count      int         NOT NULL DEFAULT 0,
  total_money_at_stake_rupees numeric(12,2),
  status              text        NOT NULL DEFAULT 'draft'
                                  CHECK (status IN ('draft','submitted','accepted','rejected','withdrawn')),
  submitted_at        timestamptz,
  mediator_user_id    uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  mediator_decision_at timestamptz,
  mediator_note       text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  -- One submitted pack per (escrow, filer_role) at a time. Drafts
  -- can stack but submissions cannot.
  CONSTRAINT dispute_pack_one_per_side
    EXCLUDE USING btree (
      repair_job_escrow_id WITH =,
      filer_role WITH =
    ) WHERE (status = 'submitted')
);

CREATE INDEX IF NOT EXISTS dispute_packs_escrow_idx
  ON public.dispute_evidence_packs (repair_job_escrow_id, created_at DESC);
CREATE INDEX IF NOT EXISTS dispute_packs_filed_by_idx
  ON public.dispute_evidence_packs (filed_by_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS dispute_packs_open_idx
  ON public.dispute_evidence_packs (status, created_at)
  WHERE status IN ('submitted');

ALTER TABLE public.dispute_evidence_packs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dispute_evidence_packs_select ON public.dispute_evidence_packs;
CREATE POLICY dispute_evidence_packs_select
  ON public.dispute_evidence_packs
  FOR SELECT
  TO authenticated, service_role
  USING (
    filed_by_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.repair_jobs rj
      WHERE rj.id = repair_job_id
        AND (rj.hospital_user_id = auth.uid())
    )
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.dispute_evidence_packs
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. open_dispute_evidence_pack — start a draft pack
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.open_dispute_evidence_pack(
  p_repair_job_escrow_id uuid,
  p_filer_role           text,
  p_position_statement   text,
  p_evidence_ledger_ids  uuid[] DEFAULT ARRAY[]::uuid[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller       uuid := auth.uid();
  v_escrow       record;
  v_job          record;
  v_engineer     uuid;
  v_pack_id      uuid;
  v_dsr_id       uuid;
  v_pved_id      uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_filer_role NOT IN ('engineer','hospital') THEN
    RAISE EXCEPTION 'invalid_filer_role' USING ERRCODE = '22023';
  END IF;
  IF p_position_statement IS NULL OR length(trim(p_position_statement)) < 20 THEN
    RAISE EXCEPTION 'position_statement required (min 20 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_escrow FROM public.repair_job_escrow WHERE id = p_repair_job_escrow_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'escrow_not_found' USING ERRCODE = '02000';
  END IF;
  SELECT * INTO v_job FROM public.repair_jobs WHERE id = v_escrow.repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'job_not_found' USING ERRCODE = '02000';
  END IF;

  SELECT engineer_user_id INTO v_engineer
    FROM public.repair_job_bids
   WHERE repair_job_id = v_job.id AND status = 'accepted'
   LIMIT 1;

  -- Authorization: caller must be the side they're filing as.
  IF p_filer_role = 'engineer' AND v_caller <> v_engineer AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_accepted_engineer_can_file_engineer_pack' USING ERRCODE = '42501';
  END IF;
  IF p_filer_role = 'hospital' AND v_caller <> v_job.hospital_user_id AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_hospital_can_file_hospital_pack' USING ERRCODE = '42501';
  END IF;

  -- Auto-link any DSR + PVED for this job (engineer-side common case)
  SELECT id INTO v_dsr_id FROM public.dsr_reports WHERE repair_job_id = v_job.id LIMIT 1;
  IF p_filer_role = 'engineer' AND v_engineer IS NOT NULL THEN
    SELECT id INTO v_pved_id FROM public.pre_visit_engineer_dossiers
     WHERE repair_job_id = v_job.id AND engineer_user_id = v_engineer
       AND status IN ('issued','consumed')
     ORDER BY issued_at DESC LIMIT 1;
  END IF;

  INSERT INTO public.dispute_evidence_packs (
    repair_job_escrow_id, repair_job_id, filed_by_user_id, filer_role,
    position_statement, evidence_ledger_ids, dsr_id, pved_id,
    evidence_count, total_money_at_stake_rupees, status
  ) VALUES (
    p_repair_job_escrow_id, v_job.id, v_caller, p_filer_role,
    p_position_statement, coalesce(p_evidence_ledger_ids, ARRAY[]::uuid[]),
    v_dsr_id, v_pved_id,
    coalesce(array_length(p_evidence_ledger_ids, 1), 0),
    v_escrow.amount_rupees, 'draft'
  ) RETURNING id INTO v_pack_id;

  RETURN v_pack_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.open_dispute_evidence_pack(uuid, text, text, uuid[])
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.open_dispute_evidence_pack(uuid, text, text, uuid[])
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. add_evidence_to_pack — append more evidence_ledger refs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.add_evidence_to_pack(
  p_pack_id     uuid,
  p_evidence_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pack record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_evidence_ids IS NULL OR array_length(p_evidence_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'evidence_ids required' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_pack FROM public.dispute_evidence_packs WHERE id = p_pack_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pack_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_pack.filed_by_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_filer_can_add' USING ERRCODE = '42501';
  END IF;
  IF v_pack.status <> 'draft' THEN
    RAISE EXCEPTION 'pack_not_in_draft (status=%)', v_pack.status USING ERRCODE = '22023';
  END IF;

  -- Dedupe + merge
  UPDATE public.dispute_evidence_packs
     SET evidence_ledger_ids = (
           SELECT array_agg(DISTINCT eid) FROM unnest(evidence_ledger_ids || p_evidence_ids) eid
         ),
         updated_at = now()
   WHERE id = p_pack_id;

  -- Refresh counter
  UPDATE public.dispute_evidence_packs
     SET evidence_count = coalesce(array_length(evidence_ledger_ids, 1), 0)
   WHERE id = p_pack_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_evidence_to_pack(uuid, uuid[])
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.add_evidence_to_pack(uuid, uuid[])
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. submit_dispute_evidence_pack — finalize for mediation
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_dispute_evidence_pack(
  p_pack_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pack record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_pack FROM public.dispute_evidence_packs WHERE id = p_pack_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pack_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_pack.filed_by_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_filer_can_submit' USING ERRCODE = '42501';
  END IF;
  IF v_pack.status <> 'draft' THEN
    RAISE EXCEPTION 'pack_not_in_draft' USING ERRCODE = '22023';
  END IF;
  IF v_pack.evidence_count < 1 AND v_pack.dsr_id IS NULL THEN
    RAISE EXCEPTION 'pack_must_have_evidence_or_dsr_before_submit' USING ERRCODE = '22023';
  END IF;

  UPDATE public.dispute_evidence_packs
     SET status = 'submitted', submitted_at = now(), updated_at = now()
   WHERE id = p_pack_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_dispute_evidence_pack(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.submit_dispute_evidence_pack(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. founder_dispute_queue — mediation console
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_dispute_queue(
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  escrow_id           uuid,
  repair_job_id       uuid,
  amount_rupees       numeric,
  hospital_user_id    uuid,
  hospital_email      text,
  engineer_user_id    uuid,
  engineer_email      text,
  engineer_pack_id    uuid,
  hospital_pack_id    uuid,
  engineer_pack_evidence_count int,
  hospital_pack_evidence_count int,
  earliest_pack_at    timestamptz,
  hours_since_oldest_pack numeric
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
  WITH escrows_in_dispute AS (
    SELECT e.id, e.repair_job_id, e.amount_rupees, e.dispute_reason
      FROM public.repair_job_escrow e
     WHERE e.status = 'disputed'
        OR (e.dispute_reason IS NOT NULL AND e.dispute_resolved_at IS NULL)
  ),
  packs AS (
    SELECT
      p.repair_job_escrow_id,
      max(p.id) FILTER (WHERE p.filer_role = 'engineer' AND p.status = 'submitted') AS engineer_pack_id,
      max(p.id) FILTER (WHERE p.filer_role = 'hospital' AND p.status = 'submitted') AS hospital_pack_id,
      max(p.evidence_count) FILTER (WHERE p.filer_role = 'engineer' AND p.status = 'submitted') AS engineer_pack_evidence_count,
      max(p.evidence_count) FILTER (WHERE p.filer_role = 'hospital' AND p.status = 'submitted') AS hospital_pack_evidence_count,
      min(p.submitted_at) FILTER (WHERE p.status = 'submitted') AS earliest_pack_at
    FROM public.dispute_evidence_packs p
    GROUP BY p.repair_job_escrow_id
  ),
  bids AS (
    SELECT b.repair_job_id, b.engineer_user_id
      FROM public.repair_job_bids b
     WHERE b.status = 'accepted'
  )
  SELECT
    e.id AS escrow_id,
    e.repair_job_id,
    e.amount_rupees,
    rj.hospital_user_id,
    (SELECT email FROM auth.users WHERE id = rj.hospital_user_id) AS hospital_email,
    b.engineer_user_id,
    (SELECT email FROM auth.users WHERE id = b.engineer_user_id) AS engineer_email,
    p.engineer_pack_id,
    p.hospital_pack_id,
    coalesce(p.engineer_pack_evidence_count, 0)::int,
    coalesce(p.hospital_pack_evidence_count, 0)::int,
    p.earliest_pack_at,
    EXTRACT(EPOCH FROM (now() - p.earliest_pack_at)) / 3600
  FROM escrows_in_dispute e
  JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
  LEFT JOIN bids b ON b.repair_job_id = e.repair_job_id
  LEFT JOIN packs p ON p.repair_job_escrow_id = e.id
  ORDER BY coalesce(p.earliest_pack_at, e.repair_job_id::text::timestamptz) ASC NULLS LAST
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_dispute_queue(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_dispute_queue(integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- 6. founder_decide_dispute_pack — accept / reject a submitted pack
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_decide_dispute_pack(
  p_pack_id  uuid,
  p_decision text,    -- 'accepted' / 'rejected'
  p_note     text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pack record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_decision NOT IN ('accepted','rejected') THEN
    RAISE EXCEPTION 'invalid_decision' USING ERRCODE = '22023';
  END IF;
  IF p_note IS NULL OR length(trim(p_note)) < 5 THEN
    RAISE EXCEPTION 'note required (min 5 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_pack FROM public.dispute_evidence_packs WHERE id = p_pack_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pack_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_pack.status <> 'submitted' THEN
    RAISE EXCEPTION 'pack_not_submitted' USING ERRCODE = '22023';
  END IF;

  UPDATE public.dispute_evidence_packs
     SET status = p_decision,
         mediator_user_id = auth.uid(),
         mediator_decision_at = now(),
         mediator_note = p_note,
         updated_at = now()
   WHERE id = p_pack_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_decide_dispute_pack',
    p_target_table  => 'dispute_evidence_packs',
    p_target_row_id => p_pack_id,
    p_before_value  => jsonb_build_object('status', 'submitted', 'filer_role', v_pack.filer_role),
    p_after_value   => jsonb_build_object('status', p_decision),
    p_reason        => p_note
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_decide_dispute_pack(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_decide_dispute_pack(uuid, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 7. dispute_pack_evidence_for_mediator — full evidence row dump
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispute_pack_evidence_detail(
  p_pack_id uuid
)
RETURNS TABLE(
  evidence_id         uuid,
  evidence_kind       text,
  producer_kind       text,
  producer_user_id    uuid,
  captured_at         timestamptz,
  content_sha256      text,
  storage_url         text,
  metadata            jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pack record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_pack FROM public.dispute_evidence_packs WHERE id = p_pack_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pack_not_found' USING ERRCODE = '02000';
  END IF;
  -- Filer + counterparty + founder can read full evidence
  IF v_pack.filed_by_user_id <> auth.uid()
     AND auth.uid() <> (SELECT hospital_user_id FROM public.repair_jobs WHERE id = v_pack.repair_job_id)
     AND auth.uid() <> (SELECT engineer_user_id FROM public.repair_job_bids WHERE repair_job_id = v_pack.repair_job_id AND status = 'accepted' LIMIT 1)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT e.id, e.evidence_kind, e.producer_kind, e.producer_user_id,
         e.captured_at, e.content_sha256, e.storage_url, e.metadata
    FROM public.evidence_ledger e
   WHERE e.id = ANY(v_pack.evidence_ledger_ids)
   ORDER BY e.captured_at ASC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.dispute_pack_evidence_detail(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.dispute_pack_evidence_detail(uuid)
  TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'dispute_evidence_packs'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 495: dispute_evidence_packs RLS not enabled';
  END IF;
  RAISE NOTICE 'round 495 dispute vault + mediation verified: table + 6 RPCs, grants correct';
END;
$$;
