BEGIN;

-- =========================================================
-- Round 2790: Engineer Monthly Customer Photo Share Consent
-- =========================================================

-- ---------------------------------------------------------
-- Table 1: photo share consent ledger
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_photo_share_consent_r2790 (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    month_label text NOT NULL,
    engineer_code text NOT NULL,
    engineer_name text NOT NULL,
    customer_org text NOT NULL,
    asset_label text NOT NULL,
    photo_kind text NOT NULL CHECK (photo_kind IN ('before','after','part','site','team','xray_room')),
    consent_status text NOT NULL CHECK (consent_status IN ('granted','pending','denied','expired','revoked')),
    consent_signed_at timestamptz,
    usage_intent text NOT NULL CHECK (usage_intent IN ('case_study','training','marketing','internal_qa','investor_share')),
    redaction_level text NOT NULL CHECK (redaction_level IN ('none','face_blur','plate_blur','full_blur','room_masked')),
    dispute_state text NOT NULL CHECK (dispute_state IN ('clear','flagged','under_review','escalated','resolved')),
    outcome text NOT NULL CHECK (outcome IN ('approved_published','pending_publish','withdrawn','rejected','quarantined')),
    photos_count integer NOT NULL DEFAULT 0,
    captured_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_photo_share_consent_r2790 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_photo_share_consent_r2790;
CREATE POLICY founder_all ON engineer_photo_share_consent_r2790
    FOR ALL TO authenticated
    USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_photo_share_consent_r2790
(month_label, engineer_code, engineer_name, customer_org, asset_label, photo_kind, consent_status, consent_signed_at, usage_intent, redaction_level, dispute_state, outcome, photos_count, captured_at)
VALUES
('2026-06','ENG-HYD-014','Ravi Kumar','Apollo Hospitals Jubilee','GE Ventilator R860','after','granted','2026-06-04 11:20+05:30','case_study','face_blur','clear','approved_published',6,'2026-06-04 10:00+05:30'),
('2026-06','ENG-MUM-021','Asha Patil','Fortis Mulund','Philips MRI Ingenia','before','pending',NULL,'investor_share','room_masked','flagged','pending_publish',4,'2026-06-09 14:00+05:30'),
('2026-06','ENG-BLR-009','Naveen Rao','Manipal Whitefield','Siemens CT Somatom','part','denied','2026-06-12 09:30+05:30','marketing','none','under_review','rejected',3,'2026-06-12 09:00+05:30'),
('2026-06','ENG-CHE-007','Priya Sundaram','MIOT International','Mindray Defibrillator D6','team','granted','2026-06-15 16:45+05:30','training','face_blur','clear','approved_published',8,'2026-06-15 15:30+05:30'),
('2026-06','ENG-DEL-031','Vikram Singh','Max Saket','Drager Anesthesia A300','site','expired','2026-05-20 12:00+05:30','case_study','plate_blur','escalated','quarantined',5,'2026-06-18 10:15+05:30'),
('2026-06','ENG-PUN-016','Sneha Joshi','Ruby Hall','GE Carestation 650','after','revoked','2026-06-19 08:00+05:30','internal_qa','full_blur','resolved','withdrawn',2,'2026-06-19 07:45+05:30');

-- ---------------------------------------------------------
-- Table 2: redaction + dispute audit trail
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_photo_redaction_audit_r2790 (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    consent_id uuid REFERENCES engineer_photo_share_consent_r2790(id) ON DELETE CASCADE,
    audit_step text NOT NULL CHECK (audit_step IN ('intake','auto_redact','founder_review','customer_confirm','final_release','dispute_open','dispute_close')),
    actor_role text NOT NULL CHECK (actor_role IN ('engineer','ops','founder','customer','auto_ml')),
    decision text NOT NULL CHECK (decision IN ('proceed','hold','reject','revise','escalate')),
    notes text,
    cost_paise integer NOT NULL DEFAULT 0,
    duration_seconds integer NOT NULL DEFAULT 0,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_photo_redaction_audit_r2790 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_photo_redaction_audit_r2790;
CREATE POLICY founder_all ON engineer_photo_redaction_audit_r2790
    FOR ALL TO authenticated
    USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_photo_redaction_audit_r2790
(consent_id, audit_step, actor_role, decision, notes, cost_paise, duration_seconds, occurred_at)
SELECT id,'intake','engineer','proceed','Photos uploaded from field tablet',0,45,captured_at FROM engineer_photo_share_consent_r2790 WHERE engineer_code='ENG-HYD-014'
UNION ALL
SELECT id,'auto_redact','auto_ml','proceed','Face blur applied 6/6 photos',1200,120,captured_at + interval '5 min' FROM engineer_photo_share_consent_r2790 WHERE engineer_code='ENG-HYD-014'
UNION ALL
SELECT id,'founder_review','founder','proceed','Case study approved for publish',0,300,captured_at + interval '1 hour' FROM engineer_photo_share_consent_r2790 WHERE engineer_code='ENG-HYD-014'
UNION ALL
SELECT id,'dispute_open','customer','escalate','Customer concerned about room visible',0,60,captured_at + interval '2 hour' FROM engineer_photo_share_consent_r2790 WHERE engineer_code='ENG-MUM-021'
UNION ALL
SELECT id,'final_release','ops','hold','Awaiting consent re-sign',0,30,captured_at + interval '30 min' FROM engineer_photo_share_consent_r2790 WHERE engineer_code='ENG-BLR-009'
UNION ALL
SELECT id,'customer_confirm','customer','proceed','Customer signed consent in app',0,180,captured_at + interval '2 hour' FROM engineer_photo_share_consent_r2790 WHERE engineer_code='ENG-CHE-007';

-- ---------------------------------------------------------
-- RPC 1: KPI summary
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2790_photo_consent_kpis();
CREATE OR REPLACE FUNCTION founder_r2790_photo_consent_kpis()
RETURNS TABLE(
    total_photos integer,
    granted_count integer,
    pending_count integer,
    denied_count integer,
    disputes_open integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT
        COALESCE(SUM(photos_count),0)::int,
        COUNT(*) FILTER (WHERE consent_status='granted')::int,
        COUNT(*) FILTER (WHERE consent_status='pending')::int,
        COUNT(*) FILTER (WHERE consent_status='denied')::int,
        COUNT(*) FILTER (WHERE dispute_state IN ('flagged','under_review','escalated'))::int
    FROM engineer_photo_share_consent_r2790;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2790_photo_consent_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2790_photo_consent_kpis() TO authenticated;

-- ---------------------------------------------------------
-- RPC 2: consent ledger listing
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2790_consent_ledger();
CREATE OR REPLACE FUNCTION founder_r2790_consent_ledger()
RETURNS TABLE(
    id uuid,
    engineer_code text,
    engineer_name text,
    customer_org text,
    asset_label text,
    photo_kind text,
    consent_status text,
    usage_intent text,
    redaction_level text,
    outcome text,
    photos_count integer,
    captured_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT c.id, c.engineer_code, c.engineer_name, c.customer_org, c.asset_label,
           c.photo_kind, c.consent_status, c.usage_intent, c.redaction_level,
           c.outcome, c.photos_count, c.captured_at
    FROM engineer_photo_share_consent_r2790 c
    ORDER BY c.captured_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2790_consent_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2790_consent_ledger() TO authenticated;

-- ---------------------------------------------------------
-- RPC 3: per-engineer rollup
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2790_engineer_rollup();
CREATE OR REPLACE FUNCTION founder_r2790_engineer_rollup()
RETURNS TABLE(
    engineer_code text,
    engineer_name text,
    total_rows integer,
    photos_count integer,
    granted_count integer,
    issues_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT
        c.engineer_code, c.engineer_name,
        COUNT(*)::int,
        COALESCE(SUM(c.photos_count),0)::int,
        COUNT(*) FILTER (WHERE c.consent_status='granted')::int,
        COUNT(*) FILTER (WHERE c.consent_status IN ('denied','expired','revoked') OR c.dispute_state IN ('flagged','escalated'))::int
    FROM engineer_photo_share_consent_r2790 c
    GROUP BY c.engineer_code, c.engineer_name
    ORDER BY c.engineer_code;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2790_engineer_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2790_engineer_rollup() TO authenticated;

-- ---------------------------------------------------------
-- RPC 4: usage intent breakdown
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2790_usage_intent_breakdown();
CREATE OR REPLACE FUNCTION founder_r2790_usage_intent_breakdown()
RETURNS TABLE(
    usage_intent text,
    row_count integer,
    photos_total integer,
    granted_share numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT
        c.usage_intent,
        COUNT(*)::int,
        COALESCE(SUM(c.photos_count),0)::int,
        ROUND(100.0 * COUNT(*) FILTER (WHERE c.consent_status='granted') / NULLIF(COUNT(*),0), 1)
    FROM engineer_photo_share_consent_r2790 c
    GROUP BY c.usage_intent
    ORDER BY c.usage_intent;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2790_usage_intent_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2790_usage_intent_breakdown() TO authenticated;

-- ---------------------------------------------------------
-- RPC 5: redaction level distribution
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2790_redaction_distribution();
CREATE OR REPLACE FUNCTION founder_r2790_redaction_distribution()
RETURNS TABLE(
    redaction_level text,
    row_count integer,
    photos_total integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT
        c.redaction_level,
        COUNT(*)::int,
        COALESCE(SUM(c.photos_count),0)::int
    FROM engineer_photo_share_consent_r2790 c
    GROUP BY c.redaction_level
    ORDER BY photos_total DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2790_redaction_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2790_redaction_distribution() TO authenticated;

-- ---------------------------------------------------------
-- RPC 6: dispute board
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2790_dispute_board();
CREATE OR REPLACE FUNCTION founder_r2790_dispute_board()
RETURNS TABLE(
    dispute_state text,
    outcome text,
    row_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT c.dispute_state, c.outcome, COUNT(*)::int
    FROM engineer_photo_share_consent_r2790 c
    GROUP BY c.dispute_state, c.outcome
    ORDER BY c.dispute_state, c.outcome;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2790_dispute_board() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2790_dispute_board() TO authenticated;

-- ---------------------------------------------------------
-- RPC 7: redaction audit log
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2790_audit_trail();
CREATE OR REPLACE FUNCTION founder_r2790_audit_trail()
RETURNS TABLE(
    id uuid,
    consent_id uuid,
    audit_step text,
    actor_role text,
    decision text,
    notes text,
    cost_paise integer,
    duration_seconds integer,
    occurred_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT a.id, a.consent_id, a.audit_step, a.actor_role, a.decision,
           a.notes, a.cost_paise, a.duration_seconds, a.occurred_at
    FROM engineer_photo_redaction_audit_r2790 a
    ORDER BY a.occurred_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2790_audit_trail() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2790_audit_trail() TO authenticated;

-- ---------------------------------------------------------
-- RPC 8: outcome funnel
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2790_outcome_funnel();
CREATE OR REPLACE FUNCTION founder_r2790_outcome_funnel()
RETURNS TABLE(
    outcome text,
    row_count integer,
    photos_total integer,
    share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    total integer;
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    SELECT COUNT(*) INTO total FROM engineer_photo_share_consent_r2790;
    RETURN QUERY
    SELECT
        c.outcome,
        COUNT(*)::int,
        COALESCE(SUM(c.photos_count),0)::int,
        ROUND(100.0 * COUNT(*) / NULLIF(total,0), 1)
    FROM engineer_photo_share_consent_r2790 c
    GROUP BY c.outcome
    ORDER BY row_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2790_outcome_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2790_outcome_funnel() TO authenticated;

COMMIT;
