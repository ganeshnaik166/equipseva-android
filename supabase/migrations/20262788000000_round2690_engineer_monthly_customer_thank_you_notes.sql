BEGIN;

-- ============================================================
-- Round 2690: Engineer Monthly Customer Thank You Notes
-- HEAVY ★★★★ — engineer × customer × note kind × theme × public share × business impact
-- ============================================================

-- ---------- Table 1: thank_you_notes_r2690 ----------
CREATE TABLE IF NOT EXISTS thank_you_notes_r2690 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_month date NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  customer_name text NOT NULL,
  customer_org text NOT NULL,
  note_kind text NOT NULL CHECK (note_kind IN ('handwritten','video','voice','printed_card','digital_letter')),
  theme text NOT NULL CHECK (theme IN ('gratitude','milestone','festival','referral_thanks','renewal_thanks','first_service')),
  body_excerpt text NOT NULL,
  is_public boolean NOT NULL DEFAULT false,
  share_token text,
  view_count integer NOT NULL DEFAULT 0 CHECK (view_count >= 0),
  business_impact_score integer NOT NULL CHECK (business_impact_score >= 0 AND business_impact_score <= 100),
  estimated_arr_lift_rupees integer NOT NULL DEFAULT 0 CHECK (estimated_arr_lift_rupees >= 0),
  delivered_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE thank_you_notes_r2690 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON thank_you_notes_r2690;
CREATE POLICY founder_all ON thank_you_notes_r2690 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO thank_you_notes_r2690 (note_month, engineer_name, engineer_tier, customer_name, customer_org, note_kind, theme, body_excerpt, is_public, share_token, view_count, business_impact_score, estimated_arr_lift_rupees, delivered_at) VALUES
('2026-06-01','Ravi Kumar','platinum','Dr Anitha','Sunrise Diagnostics','handwritten','renewal_thanks','Thank you for trusting us with the CT scanner for 3 years running.',true,'tok_ravi_jun_001',142,92,180000,now() - interval '6 days'),
('2026-06-01','Suresh Naidu','gold','Dr Mehta','Mehta Multispecialty','video','referral_thanks','Your referral brought us 4 new hospitals — sending heartfelt thanks.',true,'tok_suresh_jun_002',98,88,240000,now() - interval '4 days'),
('2026-06-01','Priya Shetty','silver','Sr Lakshmi','Govt Maternity Hospital','voice','first_service','My first ventilator service with you was unforgettable. Thank you ma''am.',false,NULL,0,71,45000,now() - interval '3 days'),
('2026-06-01','Arjun Reddy','platinum','Dr Krishnan','Apollo Cradle','printed_card','milestone','100th visit milestone — grateful for your faith in EquipSeva.',true,'tok_arjun_jun_003',76,85,120000,now() - interval '2 days'),
('2026-06-01','Meena Iyer','gold','Sr Janaki','Rainbow Children','digital_letter','festival','Wishing you a joyful Bonalu — thanks for the continued partnership.',true,'tok_meena_jun_004',54,79,60000,now() - interval '1 day'),
('2026-06-01','Vikram Joshi','bronze','Dr Patel','Patel Clinic','handwritten','gratitude','Your encouragement on day one keeps me going.',false,NULL,0,62,15000,now() - interval '12 days');

-- ---------- Table 2: thank_you_outcomes_r2690 ----------
CREATE TABLE IF NOT EXISTS thank_you_outcomes_r2690 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES thank_you_notes_r2690(id) ON DELETE CASCADE,
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('renewal','referral','testimonial','upsell','tier_upgrade','no_response')),
  outcome_value_rupees integer NOT NULL DEFAULT 0 CHECK (outcome_value_rupees >= 0),
  customer_reply_excerpt text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE thank_you_outcomes_r2690 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON thank_you_outcomes_r2690;
CREATE POLICY founder_all ON thank_you_outcomes_r2690 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO thank_you_outcomes_r2690 (note_id, outcome_kind, outcome_value_rupees, customer_reply_excerpt, occurred_at, verified) VALUES
((SELECT id FROM thank_you_notes_r2690 WHERE engineer_name='Ravi Kumar' LIMIT 1),'renewal',180000,'Renewing for 2 more years — your team is gold.',now() - interval '3 days',true),
((SELECT id FROM thank_you_notes_r2690 WHERE engineer_name='Suresh Naidu' LIMIT 1),'referral',240000,'Referring Yashoda group — expect a call.',now() - interval '2 days',true),
((SELECT id FROM thank_you_notes_r2690 WHERE engineer_name='Arjun Reddy' LIMIT 1),'testimonial',0,'Posting a LinkedIn shout — Arjun is family now.',now() - interval '1 day',true),
((SELECT id FROM thank_you_notes_r2690 WHERE engineer_name='Meena Iyer' LIMIT 1),'upsell',60000,'Add AMC tier upgrade — Diwali gift to us.',now() - interval '6 hours',false),
((SELECT id FROM thank_you_notes_r2690 WHERE engineer_name='Priya Shetty' LIMIT 1),'no_response',0,NULL,now() - interval '1 day',false),
((SELECT id FROM thank_you_notes_r2690 WHERE engineer_name='Vikram Joshi' LIMIT 1),'tier_upgrade',15000,'Promote Vikram — he earned it.',now() - interval '9 days',true);

-- ============================================================
-- RPC 1: summary KPIs
-- ============================================================
DROP FUNCTION IF EXISTS rpc_r2690_summary();
CREATE OR REPLACE FUNCTION rpc_r2690_summary()
RETURNS TABLE(total_notes integer, public_notes integer, total_views integer, avg_impact numeric, total_arr_lift_rupees bigint, outcomes_verified integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM thank_you_notes_r2690),
    (SELECT count(*)::int FROM thank_you_notes_r2690 WHERE is_public),
    (SELECT coalesce(sum(view_count),0)::int FROM thank_you_notes_r2690),
    (SELECT round(avg(business_impact_score)::numeric, 1) FROM thank_you_notes_r2690),
    (SELECT coalesce(sum(estimated_arr_lift_rupees),0)::bigint FROM thank_you_notes_r2690),
    (SELECT count(*)::int FROM thank_you_outcomes_r2690 WHERE verified);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2690_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2690_summary() TO authenticated;

-- ============================================================
-- RPC 2: by engineer
-- ============================================================
DROP FUNCTION IF EXISTS rpc_r2690_by_engineer();
CREATE OR REPLACE FUNCTION rpc_r2690_by_engineer()
RETURNS TABLE(engineer_name text, engineer_tier text, notes_sent integer, avg_impact numeric, total_views integer, arr_lift_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.engineer_name, n.engineer_tier,
         count(*)::int,
         round(avg(n.business_impact_score)::numeric,1),
         sum(n.view_count)::int,
         sum(n.estimated_arr_lift_rupees)::bigint
  FROM thank_you_notes_r2690 n
  GROUP BY n.engineer_name, n.engineer_tier
  ORDER BY sum(n.estimated_arr_lift_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2690_by_engineer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2690_by_engineer() TO authenticated;

-- ============================================================
-- RPC 3: by note kind
-- ============================================================
DROP FUNCTION IF EXISTS rpc_r2690_by_kind();
CREATE OR REPLACE FUNCTION rpc_r2690_by_kind()
RETURNS TABLE(note_kind text, notes integer, avg_impact numeric, arr_lift_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.note_kind, count(*)::int,
         round(avg(n.business_impact_score)::numeric,1),
         sum(n.estimated_arr_lift_rupees)::bigint
  FROM thank_you_notes_r2690 n
  GROUP BY n.note_kind
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2690_by_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2690_by_kind() TO authenticated;

-- ============================================================
-- RPC 4: by theme
-- ============================================================
DROP FUNCTION IF EXISTS rpc_r2690_by_theme();
CREATE OR REPLACE FUNCTION rpc_r2690_by_theme()
RETURNS TABLE(theme text, notes integer, avg_impact numeric, arr_lift_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.theme, count(*)::int,
         round(avg(n.business_impact_score)::numeric,1),
         sum(n.estimated_arr_lift_rupees)::bigint
  FROM thank_you_notes_r2690 n
  GROUP BY n.theme
  ORDER BY sum(n.estimated_arr_lift_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2690_by_theme() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2690_by_theme() TO authenticated;

-- ============================================================
-- RPC 5: public share leaderboard
-- ============================================================
DROP FUNCTION IF EXISTS rpc_r2690_public_share();
CREATE OR REPLACE FUNCTION rpc_r2690_public_share()
RETURNS TABLE(engineer_name text, customer_name text, customer_org text, share_token text, view_count integer, business_impact_score integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.engineer_name, n.customer_name, n.customer_org, n.share_token, n.view_count, n.business_impact_score
  FROM thank_you_notes_r2690 n
  WHERE n.is_public AND n.share_token IS NOT NULL
  ORDER BY n.view_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2690_public_share() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2690_public_share() TO authenticated;

-- ============================================================
-- RPC 6: outcomes verified
-- ============================================================
DROP FUNCTION IF EXISTS rpc_r2690_outcomes();
CREATE OR REPLACE FUNCTION rpc_r2690_outcomes()
RETURNS TABLE(engineer_name text, customer_org text, outcome_kind text, outcome_value_rupees integer, verified boolean, reply_excerpt text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.engineer_name, n.customer_org, o.outcome_kind, o.outcome_value_rupees, o.verified, o.customer_reply_excerpt
  FROM thank_you_outcomes_r2690 o
  JOIN thank_you_notes_r2690 n ON n.id = o.note_id
  ORDER BY o.outcome_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2690_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2690_outcomes() TO authenticated;

-- ============================================================
-- RPC 7: business impact ranked notes
-- ============================================================
DROP FUNCTION IF EXISTS rpc_r2690_impact_ranked();
CREATE OR REPLACE FUNCTION rpc_r2690_impact_ranked()
RETURNS TABLE(engineer_name text, customer_name text, customer_org text, theme text, business_impact_score integer, estimated_arr_lift_rupees integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.engineer_name, n.customer_name, n.customer_org, n.theme, n.business_impact_score, n.estimated_arr_lift_rupees
  FROM thank_you_notes_r2690 n
  ORDER BY n.business_impact_score DESC, n.estimated_arr_lift_rupees DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2690_impact_ranked() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2690_impact_ranked() TO authenticated;

-- ============================================================
-- RPC 8: tier breakdown
-- ============================================================
DROP FUNCTION IF EXISTS rpc_r2690_tier_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2690_tier_breakdown()
RETURNS TABLE(engineer_tier text, notes integer, avg_impact numeric, arr_lift_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.engineer_tier, count(*)::int,
         round(avg(n.business_impact_score)::numeric,1),
         sum(n.estimated_arr_lift_rupees)::bigint
  FROM thank_you_notes_r2690 n
  GROUP BY n.engineer_tier
  ORDER BY sum(n.estimated_arr_lift_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2690_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2690_tier_breakdown() TO authenticated;

COMMIT;
