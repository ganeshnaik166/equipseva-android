BEGIN;

-- ============================================================================
-- Round 2882 — Engineer Monthly Customer Handover Shoes Removal Protocol
-- HEAVY ★★★★ founder console
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: engineer monthly handover shoes-off protocol observations
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS engineer_handover_shoes_protocol_r2882 CASCADE;

CREATE TABLE engineer_handover_shoes_protocol_r2882 (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    engineer_code   text NOT NULL,
    engineer_name   text NOT NULL,
    city            text NOT NULL,
    month_label     text NOT NULL,
    visit_date      date NOT NULL,
    customer_name   text NOT NULL,
    site_type       text NOT NULL CHECK (site_type IN ('home','clinic','hospital','diagnostic','dental','vet')),
    shoes_removed   boolean NOT NULL DEFAULT false,
    shoe_cover_used boolean NOT NULL DEFAULT false,
    cleanliness_score smallint NOT NULL CHECK (cleanliness_score BETWEEN 1 AND 10),
    customer_impression text NOT NULL CHECK (customer_impression IN ('delighted','positive','neutral','negative','complaint')),
    verdict         text NOT NULL CHECK (verdict IN ('exemplary','pass','warn','fail','critical')),
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handover_shoes_protocol_r2882 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handover_shoes_protocol_r2882;
CREATE POLICY founder_all ON engineer_handover_shoes_protocol_r2882
    FOR ALL TO authenticated
    USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_handover_shoes_protocol_r2882
    (engineer_code, engineer_name, city, month_label, visit_date, customer_name, site_type, shoes_removed, shoe_cover_used, cleanliness_score, customer_impression, verdict, notes)
VALUES
    ('ENG-014','Ramesh Kulkarni','Pune','2026-06','2026-06-03'::date,'Dr Asha Pediatrics','clinic',true,true,9,'delighted','exemplary','Shoes removed at door, cover used inside sterile zone'),
    ('ENG-022','Vikram Naidu','Hyderabad','2026-06','2026-06-07'::date,'Sunrise Dental','dental',true,true,10,'delighted','exemplary','Customer photographed neat shoe rack on Insta story'),
    ('ENG-031','Suresh Pillai','Kochi','2026-06','2026-06-11'::date,'Mathai Home Care','home',true,false,7,'positive','pass','No cover but socks clean, customer satisfied'),
    ('ENG-045','Mohit Sharma','Delhi','2026-06','2026-06-14'::date,'Apollo Diagnostic Lajpat','diagnostic',false,true,6,'neutral','warn','Skipped removal — only cover used; lab manager flagged'),
    ('ENG-058','Joseph Tharakan','Bengaluru','2026-06','2026-06-18'::date,'Vetcare Indiranagar','vet',false,false,4,'negative','fail','Walked in with muddy shoes; vet receptionist complaint'),
    ('ENG-067','Anil Patil','Mumbai','2026-06','2026-06-21'::date,'Lilavati Cathlab','hospital',true,true,9,'delighted','exemplary','OT-grade protocol followed flawlessly'),
    ('ENG-072','Karthik Iyer','Chennai','2026-06','2026-06-24'::date,'Sankara Nethralaya OPD','clinic',false,false,3,'complaint','critical','Customer escalated to founder hotline');

-- ---------------------------------------------------------------------------
-- Table 2: monthly verdict rollup per engineer
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS engineer_handover_monthly_rollup_r2882 CASCADE;

CREATE TABLE engineer_handover_monthly_rollup_r2882 (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    engineer_code            text NOT NULL,
    engineer_name            text NOT NULL,
    month_label              text NOT NULL,
    total_visits             integer NOT NULL DEFAULT 0,
    shoes_removed_count      integer NOT NULL DEFAULT 0,
    shoe_cover_count         integer NOT NULL DEFAULT 0,
    avg_cleanliness          numeric(4,2) NOT NULL DEFAULT 0,
    delighted_count          integer NOT NULL DEFAULT 0,
    complaint_count          integer NOT NULL DEFAULT 0,
    final_verdict            text NOT NULL CHECK (final_verdict IN ('exemplary','pass','warn','fail','critical')),
    bonus_rupees             integer NOT NULL DEFAULT 0,
    penalty_rupees           integer NOT NULL DEFAULT 0,
    coaching_recommended     boolean NOT NULL DEFAULT false,
    created_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (engineer_code, month_label)
);

ALTER TABLE engineer_handover_monthly_rollup_r2882 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handover_monthly_rollup_r2882;
CREATE POLICY founder_all ON engineer_handover_monthly_rollup_r2882
    FOR ALL TO authenticated
    USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_handover_monthly_rollup_r2882
    (engineer_code, engineer_name, month_label, total_visits, shoes_removed_count, shoe_cover_count, avg_cleanliness, delighted_count, complaint_count, final_verdict, bonus_rupees, penalty_rupees, coaching_recommended)
VALUES
    ('ENG-014','Ramesh Kulkarni','2026-06',24,24,22,9.10,18,0,'exemplary',2500,0,false),
    ('ENG-022','Vikram Naidu','2026-06',28,27,26,9.40,22,0,'exemplary',3000,0,false),
    ('ENG-031','Suresh Pillai','2026-06',19,17,9,7.20,8,1,'pass',500,0,false),
    ('ENG-045','Mohit Sharma','2026-06',22,12,15,6.10,5,3,'warn',0,750,true),
    ('ENG-058','Joseph Tharakan','2026-06',20,8,5,4.40,2,6,'fail',0,2000,true),
    ('ENG-067','Anil Patil','2026-06',26,26,24,9.20,20,0,'exemplary',2750,0,false),
    ('ENG-072','Karthik Iyer','2026-06',18,4,3,3.10,1,9,'critical',0,5000,true);

-- ============================================================================
-- RPCs (7+) — all SECURITY DEFINER, plpgsql, founder-gated
-- ============================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS rpc_r2882_handover_kpis();
CREATE OR REPLACE FUNCTION rpc_r2882_handover_kpis()
RETURNS TABLE (
    total_visits bigint,
    shoes_removed_visits bigint,
    shoes_removed_pct numeric,
    avg_cleanliness numeric,
    complaint_visits bigint,
    exemplary_engineers bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT
        (SELECT count(*) FROM engineer_handover_shoes_protocol_r2882),
        (SELECT count(*) FROM engineer_handover_shoes_protocol_r2882 WHERE shoes_removed),
        ROUND(100.0 * (SELECT count(*) FROM engineer_handover_shoes_protocol_r2882 WHERE shoes_removed)::numeric / NULLIF((SELECT count(*) FROM engineer_handover_shoes_protocol_r2882),0), 1),
        ROUND((SELECT avg(cleanliness_score) FROM engineer_handover_shoes_protocol_r2882)::numeric, 2),
        (SELECT count(*) FROM engineer_handover_shoes_protocol_r2882 WHERE customer_impression = 'complaint'),
        (SELECT count(*) FROM engineer_handover_monthly_rollup_r2882 WHERE final_verdict = 'exemplary');
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2882_handover_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2882_handover_kpis() TO authenticated;

-- RPC 2: recent observations
DROP FUNCTION IF EXISTS rpc_r2882_recent_observations();
CREATE OR REPLACE FUNCTION rpc_r2882_recent_observations()
RETURNS TABLE (
    id uuid,
    engineer_code text,
    engineer_name text,
    city text,
    visit_date date,
    customer_name text,
    site_type text,
    shoes_removed boolean,
    shoe_cover_used boolean,
    cleanliness_score smallint,
    customer_impression text,
    verdict text,
    notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT t.id, t.engineer_code, t.engineer_name, t.city, t.visit_date, t.customer_name, t.site_type,
           t.shoes_removed, t.shoe_cover_used, t.cleanliness_score, t.customer_impression, t.verdict, t.notes
    FROM engineer_handover_shoes_protocol_r2882 t
    ORDER BY t.visit_date DESC, t.created_at DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2882_recent_observations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2882_recent_observations() TO authenticated;

-- RPC 3: monthly rollup table
DROP FUNCTION IF EXISTS rpc_r2882_monthly_rollup();
CREATE OR REPLACE FUNCTION rpc_r2882_monthly_rollup()
RETURNS TABLE (
    id uuid,
    engineer_code text,
    engineer_name text,
    month_label text,
    total_visits integer,
    shoes_removed_count integer,
    shoe_cover_count integer,
    avg_cleanliness numeric,
    delighted_count integer,
    complaint_count integer,
    final_verdict text,
    bonus_rupees integer,
    penalty_rupees integer,
    coaching_recommended boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT r.id, r.engineer_code, r.engineer_name, r.month_label, r.total_visits, r.shoes_removed_count,
           r.shoe_cover_count, r.avg_cleanliness, r.delighted_count, r.complaint_count, r.final_verdict,
           r.bonus_rupees, r.penalty_rupees, r.coaching_recommended
    FROM engineer_handover_monthly_rollup_r2882 r
    ORDER BY r.final_verdict, r.engineer_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2882_monthly_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2882_monthly_rollup() TO authenticated;

-- RPC 4: verdict distribution
DROP FUNCTION IF EXISTS rpc_r2882_verdict_distribution();
CREATE OR REPLACE FUNCTION rpc_r2882_verdict_distribution()
RETURNS TABLE (verdict text, visit_count bigint, pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    total bigint;
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    SELECT count(*) INTO total FROM engineer_handover_shoes_protocol_r2882;
    RETURN QUERY
    SELECT t.verdict, count(*)::bigint AS visit_count,
           ROUND(100.0 * count(*)::numeric / NULLIF(total,0), 1) AS pct
    FROM engineer_handover_shoes_protocol_r2882 t
    GROUP BY t.verdict
    ORDER BY visit_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2882_verdict_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2882_verdict_distribution() TO authenticated;

-- RPC 5: site-type breakdown
DROP FUNCTION IF EXISTS rpc_r2882_site_type_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2882_site_type_breakdown()
RETURNS TABLE (site_type text, visits bigint, shoes_removed_pct numeric, avg_clean numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT t.site_type,
           count(*)::bigint,
           ROUND(100.0 * sum(CASE WHEN t.shoes_removed THEN 1 ELSE 0 END)::numeric / NULLIF(count(*),0), 1),
           ROUND(avg(t.cleanliness_score)::numeric, 2)
    FROM engineer_handover_shoes_protocol_r2882 t
    GROUP BY t.site_type
    ORDER BY visits DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2882_site_type_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2882_site_type_breakdown() TO authenticated;

-- RPC 6: coaching list
DROP FUNCTION IF EXISTS rpc_r2882_coaching_list();
CREATE OR REPLACE FUNCTION rpc_r2882_coaching_list()
RETURNS TABLE (engineer_code text, engineer_name text, final_verdict text, penalty_rupees integer, complaint_count integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT r.engineer_code, r.engineer_name, r.final_verdict, r.penalty_rupees, r.complaint_count
    FROM engineer_handover_monthly_rollup_r2882 r
    WHERE r.coaching_recommended
    ORDER BY r.penalty_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2882_coaching_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2882_coaching_list() TO authenticated;

-- RPC 7: bonus payout summary
DROP FUNCTION IF EXISTS rpc_r2882_bonus_payouts();
CREATE OR REPLACE FUNCTION rpc_r2882_bonus_payouts()
RETURNS TABLE (engineer_code text, engineer_name text, bonus_rupees integer, penalty_rupees integer, net_rupees integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT r.engineer_code, r.engineer_name, r.bonus_rupees, r.penalty_rupees,
           (r.bonus_rupees - r.penalty_rupees) AS net_rupees
    FROM engineer_handover_monthly_rollup_r2882 r
    ORDER BY net_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2882_bonus_payouts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2882_bonus_payouts() TO authenticated;

-- RPC 8: city heatmap
DROP FUNCTION IF EXISTS rpc_r2882_city_heatmap();
CREATE OR REPLACE FUNCTION rpc_r2882_city_heatmap()
RETURNS TABLE (city text, visits bigint, shoes_removed_pct numeric, avg_clean numeric, complaints bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
    RETURN QUERY
    SELECT t.city,
           count(*)::bigint,
           ROUND(100.0 * sum(CASE WHEN t.shoes_removed THEN 1 ELSE 0 END)::numeric / NULLIF(count(*),0), 1),
           ROUND(avg(t.cleanliness_score)::numeric, 2),
           sum(CASE WHEN t.customer_impression = 'complaint' THEN 1 ELSE 0 END)::bigint
    FROM engineer_handover_shoes_protocol_r2882 t
    GROUP BY t.city
    ORDER BY visits DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2882_city_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2882_city_heatmap() TO authenticated;

COMMIT;
