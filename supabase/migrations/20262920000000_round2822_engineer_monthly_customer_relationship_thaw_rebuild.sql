BEGIN;

-- ============================================================================
-- Round 2822: Engineer Monthly Customer Relationship Thaw Rebuild
-- Cold-customer reactivation playbook: engineer x customer x thaw step x outcome
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_thaw_attempts_r2822 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_handle text NOT NULL,
  engineer_city text NOT NULL,
  customer_handle text NOT NULL,
  customer_segment text NOT NULL CHECK (customer_segment IN ('hospital','clinic','diagnostic','dental','veterinary')),
  cold_since_days int NOT NULL CHECK (cold_since_days >= 0),
  prior_lifetime_revenue_rupees numeric(14,2) NOT NULL CHECK (prior_lifetime_revenue_rupees >= 0),
  thaw_step text NOT NULL CHECK (thaw_step IN ('discovery_call','site_visit','free_audit','demo_install','quote_followup','escalation')),
  re_engage_channel text NOT NULL CHECK (re_engage_channel IN ('phone','whatsapp','onsite','email','referral')),
  attempted_at timestamptz NOT NULL DEFAULT now(),
  outcome text NOT NULL CHECK (outcome IN ('booked_job','warm_lead','no_response','declined','escalated_to_founder')),
  revenue_recovered_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (revenue_recovered_rupees >= 0),
  tier_verdict text NOT NULL CHECK (tier_verdict IN ('platinum_save','gold_save','silver_save','bronze_save','lost_cause')),
  notes text
);

ALTER TABLE engineer_thaw_attempts_r2822 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_thaw_attempts_r2822;
CREATE POLICY founder_all ON engineer_thaw_attempts_r2822 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_thaw_attempts_r2822 (engineer_handle, engineer_city, customer_handle, customer_segment, cold_since_days, prior_lifetime_revenue_rupees, thaw_step, re_engage_channel, attempted_at, outcome, revenue_recovered_rupees, tier_verdict, notes) VALUES
  ('eng_ravi_hyd','Hyderabad','apollo_jubilee','hospital',182,485000.00,'site_visit','onsite','2026-06-18 09:30:00+05:30','booked_job',128000.00,'platinum_save','BiPAP AMC renewed plus 2 new repair jobs'),
  ('eng_priya_blr','Bengaluru','manipal_whitefield','hospital',96,312000.00,'discovery_call','phone','2026-06-19 11:15:00+05:30','warm_lead',0.00,'gold_save','Quote shared, decision next week'),
  ('eng_kumar_che','Chennai','dr_smile_dental','dental',204,42000.00,'free_audit','whatsapp','2026-06-17 16:00:00+05:30','booked_job',18500.00,'silver_save','Autoclave service plus chair compressor'),
  ('eng_anita_pun','Pune','sanjeevani_clinic','clinic',311,28000.00,'quote_followup','whatsapp','2026-06-20 10:00:00+05:30','no_response',0.00,'bronze_save','Owner travelling, retry mid July'),
  ('eng_vikas_del','Delhi','max_saket','hospital',128,275000.00,'demo_install','onsite','2026-06-19 14:45:00+05:30','booked_job',95000.00,'platinum_save','Ventilator pilot accepted, AMC quote follows'),
  ('eng_meera_mum','Mumbai','pet_paws_vet','veterinary',420,9500.00,'escalation','referral','2026-06-16 12:30:00+05:30','declined',0.00,'lost_cause','Switched to in-house tech'),
  ('eng_arjun_kol','Kolkata','peerless_diag','diagnostic',88,156000.00,'discovery_call','email','2026-06-20 09:00:00+05:30','escalated_to_founder',0.00,'gold_save','Asked for founder call on pricing');

CREATE TABLE IF NOT EXISTS engineer_thaw_rebuild_verdicts_r2822 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_handle text NOT NULL,
  month_label text NOT NULL,
  customers_targeted int NOT NULL CHECK (customers_targeted >= 0),
  customers_thawed int NOT NULL CHECK (customers_thawed >= 0),
  revenue_recovered_rupees numeric(14,2) NOT NULL CHECK (revenue_recovered_rupees >= 0),
  founder_verdict text NOT NULL CHECK (founder_verdict IN ('promote_relationship_lead','retain_with_coaching','retain_with_warning','probation','offboard')),
  coaching_focus text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_thaw_rebuild_verdicts_r2822 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_thaw_rebuild_verdicts_r2822;
CREATE POLICY founder_all ON engineer_thaw_rebuild_verdicts_r2822 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_thaw_rebuild_verdicts_r2822 (engineer_handle, month_label, customers_targeted, customers_thawed, revenue_recovered_rupees, founder_verdict, coaching_focus, recorded_at) VALUES
  ('eng_ravi_hyd','2026-06',12,9,485000.00,'promote_relationship_lead','share playbook with 3 juniors','2026-06-20 18:00:00+05:30'),
  ('eng_priya_blr','2026-06',10,5,212000.00,'retain_with_coaching','close warm leads faster, follow-up cadence','2026-06-20 18:05:00+05:30'),
  ('eng_kumar_che','2026-06',8,4,72500.00,'retain_with_coaching','upsell AMC after first save','2026-06-20 18:10:00+05:30'),
  ('eng_anita_pun','2026-06',9,1,15000.00,'retain_with_warning','quote followup discipline','2026-06-20 18:15:00+05:30'),
  ('eng_vikas_del','2026-06',7,5,395000.00,'promote_relationship_lead','model demo-to-AMC funnel','2026-06-20 18:20:00+05:30'),
  ('eng_meera_mum','2026-06',6,0,0.00,'probation','reassign segment, drop vet focus','2026-06-20 18:25:00+05:30'),
  ('eng_arjun_kol','2026-06',8,2,68000.00,'retain_with_warning','escalation hygiene, do not founder-dump','2026-06-20 18:30:00+05:30');

-- ============================================================================
-- RPCs (7+)
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2822_thaw_summary();
CREATE OR REPLACE FUNCTION founder_r2822_thaw_summary()
RETURNS TABLE (
  total_attempts int,
  booked_jobs int,
  warm_leads int,
  no_response int,
  total_revenue_recovered_rupees numeric,
  platinum_saves int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::int,
      COUNT(*) FILTER (WHERE outcome='booked_job')::int,
      COUNT(*) FILTER (WHERE outcome='warm_lead')::int,
      COUNT(*) FILTER (WHERE outcome='no_response')::int,
      COALESCE(SUM(revenue_recovered_rupees),0)::numeric,
      COUNT(*) FILTER (WHERE tier_verdict='platinum_save')::int
    FROM engineer_thaw_attempts_r2822;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2822_thaw_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2822_thaw_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2822_attempts_list();
CREATE OR REPLACE FUNCTION founder_r2822_attempts_list()
RETURNS TABLE (
  id uuid,
  engineer_handle text,
  engineer_city text,
  customer_handle text,
  customer_segment text,
  cold_since_days int,
  thaw_step text,
  outcome text,
  revenue_recovered_rupees numeric,
  tier_verdict text,
  attempted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.engineer_handle, a.engineer_city, a.customer_handle, a.customer_segment,
           a.cold_since_days, a.thaw_step, a.outcome, a.revenue_recovered_rupees, a.tier_verdict, a.attempted_at
    FROM engineer_thaw_attempts_r2822 a
    ORDER BY a.attempted_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2822_attempts_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2822_attempts_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2822_verdicts_list();
CREATE OR REPLACE FUNCTION founder_r2822_verdicts_list()
RETURNS TABLE (
  id uuid,
  engineer_handle text,
  month_label text,
  customers_targeted int,
  customers_thawed int,
  revenue_recovered_rupees numeric,
  founder_verdict text,
  coaching_focus text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.engineer_handle, v.month_label, v.customers_targeted, v.customers_thawed,
           v.revenue_recovered_rupees, v.founder_verdict, v.coaching_focus
    FROM engineer_thaw_rebuild_verdicts_r2822 v
    ORDER BY v.revenue_recovered_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2822_verdicts_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2822_verdicts_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2822_by_step();
CREATE OR REPLACE FUNCTION founder_r2822_by_step()
RETURNS TABLE (
  thaw_step text,
  attempts int,
  bookings int,
  revenue_rupees numeric,
  conversion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.thaw_step,
           COUNT(*)::int,
           COUNT(*) FILTER (WHERE a.outcome='booked_job')::int,
           COALESCE(SUM(a.revenue_recovered_rupees),0)::numeric,
           ROUND(100.0 * COUNT(*) FILTER (WHERE a.outcome='booked_job') / NULLIF(COUNT(*),0), 1)::numeric
    FROM engineer_thaw_attempts_r2822 a
    GROUP BY a.thaw_step
    ORDER BY 4 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2822_by_step() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2822_by_step() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2822_by_segment();
CREATE OR REPLACE FUNCTION founder_r2822_by_segment()
RETURNS TABLE (
  customer_segment text,
  attempts int,
  saves int,
  revenue_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.customer_segment,
           COUNT(*)::int,
           COUNT(*) FILTER (WHERE a.outcome='booked_job')::int,
           COALESCE(SUM(a.revenue_recovered_rupees),0)::numeric
    FROM engineer_thaw_attempts_r2822 a
    GROUP BY a.customer_segment
    ORDER BY 4 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2822_by_segment() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2822_by_segment() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2822_engineer_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2822_engineer_leaderboard()
RETURNS TABLE (
  engineer_handle text,
  engineer_city text,
  attempts int,
  bookings int,
  revenue_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.engineer_handle, MAX(a.engineer_city),
           COUNT(*)::int,
           COUNT(*) FILTER (WHERE a.outcome='booked_job')::int,
           COALESCE(SUM(a.revenue_recovered_rupees),0)::numeric
    FROM engineer_thaw_attempts_r2822 a
    GROUP BY a.engineer_handle
    ORDER BY 5 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2822_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2822_engineer_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2822_tier_breakdown();
CREATE OR REPLACE FUNCTION founder_r2822_tier_breakdown()
RETURNS TABLE (
  tier_verdict text,
  count_attempts int,
  revenue_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.tier_verdict,
           COUNT(*)::int,
           COALESCE(SUM(a.revenue_recovered_rupees),0)::numeric
    FROM engineer_thaw_attempts_r2822 a
    GROUP BY a.tier_verdict
    ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2822_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2822_tier_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2822_verdict_distribution();
CREATE OR REPLACE FUNCTION founder_r2822_verdict_distribution()
RETURNS TABLE (
  founder_verdict text,
  engineers int,
  total_thawed int,
  total_revenue_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.founder_verdict,
           COUNT(*)::int,
           COALESCE(SUM(v.customers_thawed),0)::int,
           COALESCE(SUM(v.revenue_recovered_rupees),0)::numeric
    FROM engineer_thaw_rebuild_verdicts_r2822 v
    GROUP BY v.founder_verdict
    ORDER BY 4 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2822_verdict_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2822_verdict_distribution() TO authenticated;

COMMIT;
