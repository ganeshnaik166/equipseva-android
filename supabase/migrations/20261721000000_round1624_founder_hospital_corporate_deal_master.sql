BEGIN;

-- =====================================================================
-- r1624 — Founder Hospital Corporate-Deal Master
-- Enterprise multi-hospital corporate agreements (HCG, Apollo, etc.)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: hospital_corporate_deals
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hospital_corporate_deals_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_code text UNIQUE NOT NULL,
  corporate_name text NOT NULL,
  parent_group text,
  deal_tier text NOT NULL CHECK (deal_tier IN ('platinum','gold','silver','bronze')),
  deal_status text NOT NULL DEFAULT 'active' CHECK (deal_status IN ('draft','active','paused','expired','terminated')),
  hospital_count int NOT NULL DEFAULT 0,
  amc_value_rupees bigint NOT NULL DEFAULT 0,
  monthly_recurring_rupees bigint NOT NULL DEFAULT 0,
  contract_start date,
  contract_end date,
  discount_pct numeric(5,2) DEFAULT 0,
  sla_response_hours int DEFAULT 4,
  sla_resolution_hours int DEFAULT 24,
  payment_terms_days int DEFAULT 30,
  key_contact_name text,
  key_contact_email text,
  key_contact_phone text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_corporate_deals_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcd_v2_founder_only ON hospital_corporate_deals_v2;
CREATE POLICY hcd_v2_founder_only ON hospital_corporate_deals_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_hcd_v2_status ON hospital_corporate_deals_v2(deal_status);
CREATE INDEX IF NOT EXISTS idx_hcd_v2_tier ON hospital_corporate_deals_v2(deal_tier);

-- ---------------------------------------------------------------------
-- Table 2: hospital_corporate_deal_members
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hospital_corporate_deal_members_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id uuid NOT NULL REFERENCES hospital_corporate_deals_v2(id) ON DELETE CASCADE,
  hospital_org_id uuid REFERENCES organizations(id) ON DELETE SET NULL,
  hospital_name_snapshot text NOT NULL,
  city text,
  state text,
  beds_count int,
  joined_at timestamptz NOT NULL DEFAULT now(),
  active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_corporate_deal_members_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcdm_v2_founder_only ON hospital_corporate_deal_members_v2;
CREATE POLICY hcdm_v2_founder_only ON hospital_corporate_deal_members_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_hcdm_v2_deal ON hospital_corporate_deal_members_v2(deal_id);
CREATE INDEX IF NOT EXISTS idx_hcdm_v2_org ON hospital_corporate_deal_members_v2(hospital_org_id);

-- ---------------------------------------------------------------------
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_founder_hcd_create(p_deal_id uuid, p_payload jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hcd_create', jsonb_build_object('deal_id', p_deal_id, 'payload', p_payload), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_hcd_create(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hcd_create(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hcd_update(p_deal_id uuid, p_payload jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hcd_update', jsonb_build_object('deal_id', p_deal_id, 'payload', p_payload), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_hcd_update(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hcd_update(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hcd_member_add(p_deal_id uuid, p_member_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hcd_member_add', jsonb_build_object('deal_id', p_deal_id, 'member_id', p_member_id), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_hcd_member_add(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hcd_member_add(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hcd_terminate(p_deal_id uuid, p_reason text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hcd_terminate', jsonb_build_object('deal_id', p_deal_id, 'reason', p_reason), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_hcd_terminate(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hcd_terminate(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------
-- READ RPCs (STABLE SECDEF)
-- ---------------------------------------------------------------------

-- RPC 1: KPI roll-up
CREATE OR REPLACE FUNCTION founder_hcd_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total int;
  v_active int;
  v_platinum int;
  v_gold int;
  v_silver int;
  v_bronze int;
  v_draft int;
  v_paused int;
  v_expired int;
  v_terminated int;
  v_total_amc_value bigint;
  v_total_mrr bigint;
  v_total_hospitals int;
  v_avg_discount numeric;
  v_expiring_30 int;
  v_no_contact int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*), count(*) FILTER (WHERE deal_status='active'),
         count(*) FILTER (WHERE deal_tier='platinum'),
         count(*) FILTER (WHERE deal_tier='gold'),
         count(*) FILTER (WHERE deal_tier='silver'),
         count(*) FILTER (WHERE deal_tier='bronze'),
         count(*) FILTER (WHERE deal_status='draft'),
         count(*) FILTER (WHERE deal_status='paused'),
         count(*) FILTER (WHERE deal_status='expired'),
         count(*) FILTER (WHERE deal_status='terminated'),
         COALESCE(sum(amc_value_rupees),0),
         COALESCE(sum(monthly_recurring_rupees),0),
         COALESCE(sum(hospital_count),0),
         COALESCE(avg(discount_pct),0),
         count(*) FILTER (WHERE contract_end IS NOT NULL AND contract_end <= (CURRENT_DATE + 30) AND deal_status='active'),
         count(*) FILTER (WHERE key_contact_email IS NULL OR key_contact_email='')
  INTO v_total, v_active, v_platinum, v_gold, v_silver, v_bronze,
       v_draft, v_paused, v_expired, v_terminated,
       v_total_amc_value, v_total_mrr, v_total_hospitals, v_avg_discount,
       v_expiring_30, v_no_contact
  FROM hospital_corporate_deals_v2;

  RETURN jsonb_build_object(
    'total_deals', v_total,
    'active_deals', v_active,
    'platinum', v_platinum,
    'gold', v_gold,
    'silver', v_silver,
    'bronze', v_bronze,
    'draft', v_draft,
    'paused', v_paused,
    'expired', v_expired,
    'terminated', v_terminated,
    'total_amc_value_rupees', v_total_amc_value,
    'total_mrr_rupees', v_total_mrr,
    'total_hospitals', v_total_hospitals,
    'avg_discount_pct', v_avg_discount,
    'expiring_30d', v_expiring_30,
    'missing_contact', v_no_contact
  );
END; $$;
REVOKE EXECUTE ON FUNCTION founder_hcd_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcd_kpis() TO authenticated;

-- RPC 2: list deals
CREATE OR REPLACE FUNCTION founder_hcd_list_deals()
RETURNS TABLE (
  id uuid, deal_code text, corporate_name text, parent_group text,
  deal_tier text, deal_status text, hospital_count int,
  amc_value_rupees bigint, monthly_recurring_rupees bigint,
  contract_start date, contract_end date, discount_pct numeric,
  key_contact_name text, key_contact_email text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.deal_code, d.corporate_name, d.parent_group,
         d.deal_tier, d.deal_status, d.hospital_count,
         d.amc_value_rupees, d.monthly_recurring_rupees,
         d.contract_start, d.contract_end, d.discount_pct,
         d.key_contact_name, d.key_contact_email
  FROM hospital_corporate_deals_v2 d
  ORDER BY d.amc_value_rupees DESC NULLS LAST, d.created_at DESC
  LIMIT 200;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_hcd_list_deals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcd_list_deals() TO authenticated;

-- RPC 3: list member hospitals
CREATE OR REPLACE FUNCTION founder_hcd_list_members()
RETURNS TABLE (
  id uuid, deal_id uuid, deal_code text, corporate_name text,
  hospital_org_id uuid, hospital_name_snapshot text, city text, state text,
  beds_count int, joined_at timestamptz, active boolean
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.deal_id, d.deal_code, d.corporate_name,
         m.hospital_org_id, m.hospital_name_snapshot, m.city, m.state,
         m.beds_count, m.joined_at, m.active
  FROM hospital_corporate_deal_members_v2 m
  JOIN hospital_corporate_deals_v2 d ON d.id = m.deal_id
  ORDER BY m.joined_at DESC
  LIMIT 300;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_hcd_list_members() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcd_list_members() TO authenticated;

-- RPC 4: expiring soon
CREATE OR REPLACE FUNCTION founder_hcd_expiring_soon()
RETURNS TABLE (
  id uuid, deal_code text, corporate_name text, deal_tier text,
  contract_end date, days_remaining int, amc_value_rupees bigint,
  key_contact_name text, key_contact_email text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.deal_code, d.corporate_name, d.deal_tier,
         d.contract_end,
         GREATEST(0, (d.contract_end - CURRENT_DATE))::int AS days_remaining,
         d.amc_value_rupees, d.key_contact_name, d.key_contact_email
  FROM hospital_corporate_deals_v2 d
  WHERE d.deal_status='active'
    AND d.contract_end IS NOT NULL
    AND d.contract_end <= (CURRENT_DATE + 90)
  ORDER BY d.contract_end ASC
  LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_hcd_expiring_soon() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcd_expiring_soon() TO authenticated;

-- RPC 5: tier revenue breakdown
CREATE OR REPLACE FUNCTION founder_hcd_tier_breakdown()
RETURNS TABLE (
  deal_tier text, deal_count int, hospital_count_sum bigint,
  amc_value_sum bigint, mrr_sum bigint, avg_discount_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.deal_tier,
         count(*)::int AS deal_count,
         COALESCE(sum(d.hospital_count),0)::bigint,
         COALESCE(sum(d.amc_value_rupees),0)::bigint,
         COALESCE(sum(d.monthly_recurring_rupees),0)::bigint,
         COALESCE(avg(d.discount_pct),0)::numeric
  FROM hospital_corporate_deals_v2 d
  WHERE d.deal_status='active'
  GROUP BY d.deal_tier
  ORDER BY sum(d.amc_value_rupees) DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_hcd_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcd_tier_breakdown() TO authenticated;

-- RPC 6: missing-contact deals
CREATE OR REPLACE FUNCTION founder_hcd_missing_contacts()
RETURNS TABLE (
  id uuid, deal_code text, corporate_name text, deal_tier text,
  deal_status text, amc_value_rupees bigint,
  has_name boolean, has_email boolean, has_phone boolean
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.deal_code, d.corporate_name, d.deal_tier, d.deal_status,
         d.amc_value_rupees,
         (d.key_contact_name IS NOT NULL AND d.key_contact_name <> '')::boolean,
         (d.key_contact_email IS NOT NULL AND d.key_contact_email <> '')::boolean,
         (d.key_contact_phone IS NOT NULL AND d.key_contact_phone <> '')::boolean
  FROM hospital_corporate_deals_v2 d
  WHERE d.key_contact_name IS NULL OR d.key_contact_name=''
     OR d.key_contact_email IS NULL OR d.key_contact_email=''
     OR d.key_contact_phone IS NULL OR d.key_contact_phone=''
  ORDER BY d.amc_value_rupees DESC NULLS LAST
  LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_hcd_missing_contacts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcd_missing_contacts() TO authenticated;

-- RPC 7: recent audit log
CREATE OR REPLACE FUNCTION founder_hcd_recent_audit()
RETURNS TABLE (
  id uuid, actor_email text, op_name text, after_value jsonb, created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.actor_email, a.op_name, a.after_value, a.created_at
  FROM founder_action_log a
  WHERE a.op_name LIKE 'hcd_%'
  ORDER BY a.created_at DESC
  LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_hcd_recent_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcd_recent_audit() TO authenticated;

COMMIT;