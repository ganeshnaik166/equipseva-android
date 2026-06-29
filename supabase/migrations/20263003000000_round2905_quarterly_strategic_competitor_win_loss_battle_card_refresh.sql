-- Round r2905 — Founder Quarterly Strategic Competitor Win/Loss Battle-Card Refresh
-- Batch 400 milestone · HEAVY ★★★★

BEGIN;

-- ============================================================================
-- Table 1: competitor_battle_cards_r2905
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.competitor_battle_cards_r2905 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  competitor_name text NOT NULL,
  segment text NOT NULL,
  region text NOT NULL,
  positioning_strength text NOT NULL,
  positioning_weakness text NOT NULL,
  pricing_band_rupees int NOT NULL,
  estimated_market_share_pct numeric(5,2) NOT NULL,
  last_refreshed_at timestamptz NOT NULL DEFAULT now(),
  refresh_quarter text NOT NULL,
  threat_level text NOT NULL CHECK (threat_level IN ('low','medium','high','critical'))
);

ALTER TABLE public.competitor_battle_cards_r2905 ENABLE ROW LEVEL SECURITY;

INSERT INTO public.competitor_battle_cards_r2905
  (competitor_name, segment, region, positioning_strength, positioning_weakness, pricing_band_rupees, estimated_market_share_pct, refresh_quarter, threat_level)
VALUES
  ('MediTech Services','Tier-1 hospital','South','Strong OEM ties','Slow response SLA',45000,18.50,'Q3-2026','high'),
  ('CareEquip Pro','Multispecialty','West','Wide engineer base','Weak AMC retention',38000,14.20,'Q3-2026','high'),
  ('HospiCare AMC','Tier-2 hospital','North','Cheap entry pricing',	'No spare parts depth',22000,9.80,'Q3-2026','medium'),
  ('Sterling BioMed','Diagnostics','South','Lab specialization','High service cost',55000,6.40,'Q3-2026','medium'),
  ('Orion Medservice','Tier-1 hospital','East','24x7 helpline','No mobile app',41000,7.10,'Q3-2026','high'),
  ('LifelineEquip','Multispecialty','Pan-India','Pan-India footprint','Inconsistent quality',33000,12.30,'Q3-2026','critical'),
  ('PrecisionCare','Cath labs','South','Cath-lab depth','Narrow vertical',62000,4.20,'Q3-2026','low'),
  ('DentalServ India','Dental chains','West','Dental focus','Single vertical',18000,3.80,'Q3-2026','low'),
  ('SwiftMed Repairs','OEM-tied','Pan-India','OEM exclusive','High price floor',58000,11.10,'Q3-2026','high'),
  ('VitalCare BMC','Tier-3 hospital','Central','Low-cost rural','Thin engineer pool',16000,5.20,'Q3-2026','medium'),
  ('HealServe AMC','Tier-1 hospital','North','Brand recall','Legacy systems',47000,8.90,'Q3-2026','high'),
  ('AryaMed Solutions','Multispecialty','South','Hindi+Telugu support','Limited spare depth',29000,4.60,'Q3-2026','medium'),
  ('MedAxis Care','Tier-2 hospital','West','Quick onboarding','Weak escalation',24000,3.10,'Q3-2026','low'),
  ('Nucleus BioServ','Diagnostics','East','Cold-chain expertise','Niche only',51000,2.80,'Q3-2026','low'),
  ('PanaceaEquip','Pan-India','Pan-India','Bundled pricing','Hidden charges',31000,7.40,'Q3-2026','medium');

-- ============================================================================
-- Table 2: competitor_win_loss_events_r2905
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.competitor_win_loss_events_r2905 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  battle_card_id uuid NOT NULL REFERENCES public.competitor_battle_cards_r2905(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  deal_size_rupees int NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('won','lost','stalemate')),
  primary_driver text NOT NULL,
  deal_closed_at timestamptz NOT NULL DEFAULT now(),
  region text NOT NULL,
  notes text
);

ALTER TABLE public.competitor_win_loss_events_r2905 ENABLE ROW LEVEL SECURITY;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Apollo Hyderabad', 480000, 'won', 'Faster SLA', (now() - interval '5 days')::timestamptz, 'South', 'Beat on response time'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'MediTech Services' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Fortis Mumbai', 620000, 'lost', 'Existing OEM lock-in', (now() - interval '12 days')::timestamptz, 'West', 'OEM exclusivity blocked'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'CareEquip Pro' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Manipal Bangalore', 540000, 'won', 'Bonded parts provenance', (now() - interval '8 days')::timestamptz, 'South', 'Counterfeit parts story landed'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'LifelineEquip' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'AIIMS Delhi', 880000, 'won', 'NABH ZIP audit ready', (now() - interval '3 days')::timestamptz, 'North', 'Compliance was decisive'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'HealServe AMC' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'KIMS Secunderabad', 310000, 'lost', 'Pricing too low', (now() - interval '20 days')::timestamptz, 'South', 'Lost on raw price'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'HospiCare AMC' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Yashoda Hyderabad', 410000, 'won', 'Engineer rotation enforcement', (now() - interval '15 days')::timestamptz, 'South', 'Audit trail beat them'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'Orion Medservice' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Aster Kochi', 290000, 'stalemate', 'Price parity', (now() - interval '25 days')::timestamptz, 'South', 'Both quoted same'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'PrecisionCare' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Narayana Bangalore', 720000, 'won', 'Cashfree split-payouts', (now() - interval '6 days')::timestamptz, 'South', 'Payout transparency won'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'SwiftMed Repairs' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Max Saket', 360000, 'lost', 'Brand recognition', (now() - interval '30 days')::timestamptz, 'North', 'Big brand inertia'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'HealServe AMC' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Wockhardt Mira Road', 240000, 'won', 'AMC tier ladder', (now() - interval '10 days')::timestamptz, 'West', 'Tier upgrade path closed deal'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'MedAxis Care' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Ruby Hall Pune', 460000, 'won', 'Hindi-Telugu engineer app', (now() - interval '4 days')::timestamptz, 'West', 'i18n was the differentiator'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'AryaMed Solutions' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Care Hyderabad', 580000, 'won', 'Code Red incident response', (now() - interval '7 days')::timestamptz, 'South', 'p0 response demo sealed it'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'MediTech Services' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Columbia Asia', 330000, 'lost', 'Existing AMC term left', (now() - interval '40 days')::timestamptz, 'South', 'Wait until renewal Q1'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'PanaceaEquip' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Kauvery Trichy', 220000, 'won', 'Rural Tier-3 outreach', (now() - interval '14 days')::timestamptz, 'South', 'They had no Tier-3 story'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'VitalCare BMC' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Lilavati Mumbai', 690000, 'stalemate', 'Procurement frozen', (now() - interval '50 days')::timestamptz, 'West', 'Reconvene Q4'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'CareEquip Pro' LIMIT 1;

INSERT INTO public.competitor_win_loss_events_r2905
  (battle_card_id, hospital_name, deal_size_rupees, outcome, primary_driver, deal_closed_at, region, notes)
SELECT id, 'Medanta Gurgaon', 950000, 'won', 'Investor data room confidence', (now() - interval '9 days')::timestamptz, 'North', 'Strategic supplier status'
FROM public.competitor_battle_cards_r2905 WHERE competitor_name = 'LifelineEquip' LIMIT 1;

-- ============================================================================
-- is_founder fallback
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'is_founder') THEN
    CREATE OR REPLACE FUNCTION public.is_founder() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $f$
    BEGIN
      RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'founder');
    END;
    $f$;
  END IF;
END $$;

-- ============================================================================
-- RPC 1: kpi summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2905_kpi_summary()
RETURNS TABLE(metric text, value text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT 'total_battle_cards'::text, COUNT(*)::text FROM public.competitor_battle_cards_r2905
    UNION ALL
    SELECT 'critical_threats', COUNT(*)::text FROM public.competitor_battle_cards_r2905 WHERE threat_level = 'critical'
    UNION ALL
    SELECT 'high_threats', COUNT(*)::text FROM public.competitor_battle_cards_r2905 WHERE threat_level = 'high'
    UNION ALL
    SELECT 'total_wins_q', COUNT(*)::text FROM public.competitor_win_loss_events_r2905 WHERE outcome = 'won'
    UNION ALL
    SELECT 'total_losses_q', COUNT(*)::text FROM public.competitor_win_loss_events_r2905 WHERE outcome = 'lost'
    UNION ALL
    SELECT 'win_value_rupees', COALESCE(SUM(deal_size_rupees),0)::text FROM public.competitor_win_loss_events_r2905 WHERE outcome = 'won'
    UNION ALL
    SELECT 'loss_value_rupees', COALESCE(SUM(deal_size_rupees),0)::text FROM public.competitor_win_loss_events_r2905 WHERE outcome = 'lost';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2905_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2905_kpi_summary() TO authenticated;

-- ============================================================================
-- RPC 2: battle cards by threat
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2905_battle_cards_by_threat()
RETURNS TABLE(id uuid, competitor_name text, segment text, region text, threat_level text, market_share_pct numeric, pricing_band_rupees int, refresh_quarter text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT c.id, c.competitor_name, c.segment, c.region, c.threat_level,
           c.estimated_market_share_pct, c.pricing_band_rupees, c.refresh_quarter
    FROM public.competitor_battle_cards_r2905 c
    ORDER BY CASE c.threat_level
      WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4
    END, c.estimated_market_share_pct DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2905_battle_cards_by_threat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2905_battle_cards_by_threat() TO authenticated;

-- ============================================================================
-- RPC 3: recent win/loss events
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2905_recent_events()
RETURNS TABLE(id uuid, competitor_name text, hospital_name text, deal_size_rupees int, outcome text, primary_driver text, region text, deal_closed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT e.id, c.competitor_name, e.hospital_name, e.deal_size_rupees,
           e.outcome, e.primary_driver, e.region, e.deal_closed_at
    FROM public.competitor_win_loss_events_r2905 e
    JOIN public.competitor_battle_cards_r2905 c ON c.id = e.battle_card_id
    ORDER BY e.deal_closed_at DESC
    LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2905_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2905_recent_events() TO authenticated;

-- ============================================================================
-- RPC 4: win rate by competitor
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2905_win_rate_by_competitor()
RETURNS TABLE(competitor_name text, wins bigint, losses bigint, stalemates bigint, win_rate_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT c.competitor_name,
           COUNT(*) FILTER (WHERE e.outcome = 'won')::bigint AS wins,
           COUNT(*) FILTER (WHERE e.outcome = 'lost')::bigint AS losses,
           COUNT(*) FILTER (WHERE e.outcome = 'stalemate')::bigint AS stalemates,
           CASE WHEN COUNT(*) > 0
             THEN ROUND(100.0 * COUNT(*) FILTER (WHERE e.outcome = 'won') / COUNT(*), 1)
             ELSE 0 END AS win_rate_pct
    FROM public.competitor_battle_cards_r2905 c
    LEFT JOIN public.competitor_win_loss_events_r2905 e ON e.battle_card_id = c.id
    GROUP BY c.competitor_name
    ORDER BY win_rate_pct DESC, wins DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2905_win_rate_by_competitor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2905_win_rate_by_competitor() TO authenticated;

-- ============================================================================
-- RPC 5: region pressure
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2905_region_pressure()
RETURNS TABLE(region text, competitor_count bigint, avg_market_share numeric, critical_or_high_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT c.region,
           COUNT(*)::bigint,
           ROUND(AVG(c.estimated_market_share_pct), 2),
           COUNT(*) FILTER (WHERE c.threat_level IN ('critical','high'))::bigint
    FROM public.competitor_battle_cards_r2905 c
    GROUP BY c.region
    ORDER BY critical_or_high_count DESC, avg_market_share DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2905_region_pressure() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2905_region_pressure() TO authenticated;

-- ============================================================================
-- RPC 6: top win drivers
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2905_top_win_drivers()
RETURNS TABLE(primary_driver text, win_count bigint, total_value_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT e.primary_driver,
           COUNT(*)::bigint,
           COALESCE(SUM(e.deal_size_rupees),0)::bigint
    FROM public.competitor_win_loss_events_r2905 e
    WHERE e.outcome = 'won'
    GROUP BY e.primary_driver
    ORDER BY win_count DESC, total_value_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2905_top_win_drivers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2905_top_win_drivers() TO authenticated;

-- ============================================================================
-- RPC 7: loss reasons
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2905_loss_reasons()
RETURNS TABLE(primary_driver text, loss_count bigint, total_value_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT e.primary_driver,
           COUNT(*)::bigint,
           COALESCE(SUM(e.deal_size_rupees),0)::bigint
    FROM public.competitor_win_loss_events_r2905 e
    WHERE e.outcome = 'lost'
    GROUP BY e.primary_driver
    ORDER BY loss_count DESC, total_value_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2905_loss_reasons() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2905_loss_reasons() TO authenticated;

-- ============================================================================
-- RPC 8: stale battle cards
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2905_stale_battle_cards()
RETURNS TABLE(id uuid, competitor_name text, segment text, last_refreshed_at timestamptz, days_since_refresh int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
    SELECT c.id, c.competitor_name, c.segment, c.last_refreshed_at,
           EXTRACT(DAY FROM (now() - c.last_refreshed_at))::int AS days_since_refresh
    FROM public.competitor_battle_cards_r2905 c
    ORDER BY c.last_refreshed_at ASC
    LIMIT 15;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2905_stale_battle_cards() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2905_stale_battle_cards() TO authenticated;

COMMIT;
