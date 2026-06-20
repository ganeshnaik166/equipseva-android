BEGIN;

-- =====================================================================
-- r1465 hospital lost-deal post-mortem
-- Capture every lost AMC/sales deal with reason, competitor, gap analysis
-- Surface top-5 lose-reasons + founder action ladder
-- =====================================================================

CREATE TABLE IF NOT EXISTS hospital_lost_deals_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations(id) ON DELETE SET NULL,
  hospital_name text NOT NULL,
  hospital_city text,
  deal_type text NOT NULL CHECK (deal_type IN ('amc','one_off_repair','spare_parts','bundle','enterprise')),
  deal_value_rupees bigint NOT NULL DEFAULT 0 CHECK (deal_value_rupees >= 0),
  expected_close_at timestamptz,
  lost_at timestamptz NOT NULL DEFAULT now(),
  lose_reason text NOT NULL CHECK (lose_reason IN ('price','feature_gap','trust','speed','competitor_lockin','no_budget','timing','relationship','compliance','quality','no_decision','other')),
  lose_reason_detail text,
  competitor_won text,
  competitor_price_rupees bigint,
  gap_analysis text,
  could_we_have_won boolean DEFAULT false,
  fix_category text CHECK (fix_category IN ('product','pricing','sales_process','brand','partnership','none')),
  recovery_attempt_made boolean DEFAULT false,
  recovered boolean DEFAULT false,
  owner_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  source text DEFAULT 'manual',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_lost_deals_v2_lost_at ON hospital_lost_deals_v2(lost_at DESC);
CREATE INDEX IF NOT EXISTS idx_hospital_lost_deals_v2_reason ON hospital_lost_deals_v2(lose_reason);
CREATE INDEX IF NOT EXISTS idx_hospital_lost_deals_v2_competitor ON hospital_lost_deals_v2(competitor_won);
CREATE INDEX IF NOT EXISTS idx_hospital_lost_deals_v2_org ON hospital_lost_deals_v2(organization_id);

ALTER TABLE hospital_lost_deals_v2 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS hospital_lost_deal_actions_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lost_deal_id uuid NOT NULL REFERENCES hospital_lost_deals_v2(id) ON DELETE CASCADE,
  action_rung int NOT NULL CHECK (action_rung BETWEEN 1 AND 5),
  action_label text NOT NULL,
  action_owner text,
  action_status text NOT NULL DEFAULT 'open' CHECK (action_status IN ('open','in_progress','done','dropped')),
  due_date date,
  completed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_lost_deal_actions_v2_deal ON hospital_lost_deal_actions_v2(lost_deal_id);
CREATE INDEX IF NOT EXISTS idx_hospital_lost_deal_actions_v2_status ON hospital_lost_deal_actions_v2(action_status);

ALTER TABLE hospital_lost_deal_actions_v2 ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- SECDEF RPCs (founder only)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_lost_deal_kpis_v2()
RETURNS TABLE(
  total_lost_30d bigint,
  total_lost_value_30d_rupees bigint,
  total_lost_90d bigint,
  total_lost_value_90d_rupees bigint,
  avg_deal_value_rupees bigint,
  pct_could_have_won numeric,
  recovery_rate_pct numeric,
  competitor_count int,
  top_competitor text,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH d AS (SELECT * FROM hospital_lost_deals_v2),
  d30 AS (SELECT * FROM d WHERE lost_at >= now() - interval '30 days'),
  d90 AS (SELECT * FROM d WHERE lost_at >= now() - interval '90 days'),
  comp AS (
    SELECT competitor_won, count(*) c FROM d WHERE competitor_won IS NOT NULL
    GROUP BY competitor_won ORDER BY c DESC LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM d30),
    COALESCE((SELECT sum(deal_value_rupees) FROM d30),0),
    (SELECT count(*) FROM d90),
    COALESCE((SELECT sum(deal_value_rupees) FROM d90),0),
    COALESCE((SELECT avg(deal_value_rupees)::bigint FROM d90),0),
    COALESCE((SELECT round(100.0*sum(CASE WHEN could_we_have_won THEN 1 ELSE 0 END)/NULLIF(count(*),0),1) FROM d90),0),
    COALESCE((SELECT round(100.0*sum(CASE WHEN recovered THEN 1 ELSE 0 END)/NULLIF(count(*),0),1) FROM d WHERE recovery_attempt_made),0),
    (SELECT count(DISTINCT competitor_won)::int FROM d WHERE competitor_won IS NOT NULL),
    (SELECT competitor_won FROM comp),
    (SELECT count(*) FROM hospital_lost_deal_actions_v2 WHERE action_status IN ('open','in_progress'));
END $$;
REVOKE ALL ON FUNCTION founder_lost_deal_kpis_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_lost_deal_kpis_v2() TO authenticated;

CREATE OR REPLACE FUNCTION founder_lost_deal_top_reasons_v2()
RETURNS TABLE(lose_reason text, deals bigint, lost_value_rupees bigint, pct_of_total numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total FROM hospital_lost_deals_v2 WHERE lost_at >= now() - interval '180 days';
  RETURN QUERY
  SELECT d.lose_reason, count(*)::bigint, COALESCE(sum(d.deal_value_rupees),0)::bigint,
         ROUND(100.0*count(*)/NULLIF(total,0),1)
  FROM hospital_lost_deals_v2 d
  WHERE d.lost_at >= now() - interval '180 days'
  GROUP BY d.lose_reason
  ORDER BY count(*) DESC
  LIMIT 5;
END $$;
REVOKE ALL ON FUNCTION founder_lost_deal_top_reasons_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_lost_deal_top_reasons_v2() TO authenticated;

CREATE OR REPLACE FUNCTION founder_lost_deal_top_competitors_v2()
RETURNS TABLE(competitor_won text, deals_lost bigint, lost_value_rupees bigint, avg_competitor_price_rupees bigint, our_avg_price_rupees bigint, price_gap_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.competitor_won, count(*)::bigint, COALESCE(sum(d.deal_value_rupees),0)::bigint,
         COALESCE(avg(d.competitor_price_rupees)::bigint,0),
         COALESCE(avg(d.deal_value_rupees)::bigint,0),
         CASE WHEN avg(d.competitor_price_rupees) IS NULL OR avg(d.competitor_price_rupees)=0 THEN 0
              ELSE ROUND(100.0*(avg(d.deal_value_rupees)-avg(d.competitor_price_rupees))/avg(d.competitor_price_rupees),1)
         END
  FROM hospital_lost_deals_v2 d
  WHERE d.competitor_won IS NOT NULL
  GROUP BY d.competitor_won
  ORDER BY count(*) DESC
  LIMIT 10;
END $$;
REVOKE ALL ON FUNCTION founder_lost_deal_top_competitors_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_lost_deal_top_competitors_v2() TO authenticated;

CREATE OR REPLACE FUNCTION founder_lost_deal_recent_v2()
RETURNS TABLE(id uuid, hospital_name text, hospital_city text, deal_type text, deal_value_rupees bigint, lose_reason text, competitor_won text, lost_at timestamptz, could_we_have_won boolean, recovered boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.hospital_name, d.hospital_city, d.deal_type, d.deal_value_rupees,
         d.lose_reason, d.competitor_won, d.lost_at, d.could_we_have_won, d.recovered
  FROM hospital_lost_deals_v2 d
  ORDER BY d.lost_at DESC
  LIMIT 100;
END $$;
REVOKE ALL ON FUNCTION founder_lost_deal_recent_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_lost_deal_recent_v2() TO authenticated;

CREATE OR REPLACE FUNCTION founder_lost_deal_by_city_v2()
RETURNS TABLE(hospital_city text, deals bigint, lost_value_rupees bigint, top_reason text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT d.hospital_city, d.lose_reason, count(*) c, sum(d.deal_value_rupees) v
    FROM hospital_lost_deals_v2 d
    WHERE d.hospital_city IS NOT NULL
    GROUP BY d.hospital_city, d.lose_reason
  ),
  ranked AS (
    SELECT hospital_city, lose_reason, c, v,
           row_number() OVER (PARTITION BY hospital_city ORDER BY c DESC) rn
    FROM base
  )
  SELECT b.hospital_city,
         (SELECT sum(c) FROM base b2 WHERE b2.hospital_city=b.hospital_city)::bigint,
         (SELECT sum(v) FROM base b2 WHERE b2.hospital_city=b.hospital_city)::bigint,
         b.lose_reason
  FROM ranked b
  WHERE b.rn=1
  ORDER BY 2 DESC
  LIMIT 20;
END $$;
REVOKE ALL ON FUNCTION founder_lost_deal_by_city_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_lost_deal_by_city_v2() TO authenticated;

CREATE OR REPLACE FUNCTION founder_lost_deal_action_ladder_v2()
RETURNS TABLE(action_rung int, action_label text, deals_affected bigint, open_actions bigint, done_actions bigint, completion_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_rung, a.action_label,
         count(DISTINCT a.lost_deal_id)::bigint,
         sum(CASE WHEN a.action_status IN ('open','in_progress') THEN 1 ELSE 0 END)::bigint,
         sum(CASE WHEN a.action_status='done' THEN 1 ELSE 0 END)::bigint,
         ROUND(100.0*sum(CASE WHEN a.action_status='done' THEN 1 ELSE 0 END)/NULLIF(count(*),0),1)
  FROM hospital_lost_deal_actions_v2 a
  GROUP BY a.action_rung, a.action_label
  ORDER BY a.action_rung ASC, count(*) DESC;
END $$;
REVOKE ALL ON FUNCTION founder_lost_deal_action_ladder_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_lost_deal_action_ladder_v2() TO authenticated;

CREATE OR REPLACE FUNCTION founder_lost_deal_recoverable_v2()
RETURNS TABLE(id uuid, hospital_name text, deal_value_rupees bigint, lose_reason text, fix_category text, lost_days_ago int, gap_analysis text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.hospital_name, d.deal_value_rupees, d.lose_reason, d.fix_category,
         EXTRACT(day FROM now()-d.lost_at)::int,
         d.gap_analysis
  FROM hospital_lost_deals_v2 d
  WHERE d.could_we_have_won = true AND d.recovered = false
  ORDER BY d.deal_value_rupees DESC
  LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION founder_lost_deal_recoverable_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_lost_deal_recoverable_v2() TO authenticated;

-- =====================================================================
-- log_founder_* helpers (VOLATILE SECDEF, founder gated)
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_lost_deal_v2(
  p_hospital_name text, p_hospital_city text, p_deal_type text, p_deal_value_rupees bigint,
  p_lose_reason text, p_competitor_won text, p_gap_analysis text, p_could_we_have_won boolean, p_fix_category text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_lost_deals_v2(hospital_name, hospital_city, deal_type, deal_value_rupees,
    lose_reason, competitor_won, gap_analysis, could_we_have_won, fix_category)
  VALUES (p_hospital_name, p_hospital_city, p_deal_type, p_deal_value_rupees,
    p_lose_reason, p_competitor_won, p_gap_analysis, p_could_we_have_won, p_fix_category)
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_lost_deal_v2(text,text,text,bigint,text,text,text,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_lost_deal_v2(text,text,text,bigint,text,text,text,boolean,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_lost_deal_action_v2(
  p_lost_deal_id uuid, p_action_rung int, p_action_label text, p_action_owner text, p_due_date date
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_lost_deal_actions_v2(lost_deal_id, action_rung, action_label, action_owner, due_date)
  VALUES (p_lost_deal_id, p_action_rung, p_action_label, p_action_owner, p_due_date)
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_lost_deal_action_v2(uuid,int,text,text,date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_lost_deal_action_v2(uuid,int,text,text,date) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_lost_deal_recovery_v2(p_lost_deal_id uuid, p_recovered boolean, p_notes text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_lost_deals_v2
  SET recovery_attempt_made = true,
      recovered = p_recovered,
      notes = COALESCE(notes,'') || E'\n[' || now() || '] ' || COALESCE(p_notes,''),
      updated_at = now()
  WHERE id = p_lost_deal_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_lost_deal_recovery_v2(uuid,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_lost_deal_recovery_v2(uuid,boolean,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_lost_deal_action_status_v2(p_action_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','in_progress','done','dropped') THEN RAISE EXCEPTION 'bad status'; END IF;
  UPDATE hospital_lost_deal_actions_v2
  SET action_status = p_status,
      completed_at = CASE WHEN p_status='done' THEN now() ELSE completed_at END
  WHERE id = p_action_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_lost_deal_action_status_v2(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_lost_deal_action_status_v2(uuid,text) TO authenticated;

COMMIT;