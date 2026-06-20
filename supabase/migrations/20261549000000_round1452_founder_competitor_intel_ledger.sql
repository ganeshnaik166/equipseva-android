BEGIN;

-- =========================================================================
-- r1452 — Founder Competitor Intel Ledger
-- Capture rival biomedical AMC firm intel: pricing, wins/losses, watchlist,
-- SWOT entries, sentiment over time. Founder-only.
-- =========================================================================

-- ---------- competitors registry ----------
CREATE TABLE IF NOT EXISTS founder_competitors (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  hq_city         text,
  est_size        text,
  watchlist_tier  text NOT NULL DEFAULT 'watch' CHECK (watchlist_tier IN ('top','watch','minor')),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_founder_competitors_tier ON founder_competitors(watchlist_tier);

ALTER TABLE founder_competitors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_founder_competitors_founder ON founder_competitors;
CREATE POLICY p_founder_competitors_founder ON founder_competitors
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- intel ledger ----------
CREATE TABLE IF NOT EXISTS founder_competitor_intel (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_id     uuid NOT NULL REFERENCES founder_competitors(id) ON DELETE CASCADE,
  intel_type        text NOT NULL CHECK (intel_type IN ('pricing','win_loss','swot','sentiment','note')),
  hospital_name     text,
  outcome           text CHECK (outcome IN ('won','lost','pending','na')),
  observed_price_rupees integer,
  swot_bucket       text CHECK (swot_bucket IN ('strength','weakness','opportunity','threat')),
  sentiment_score   smallint CHECK (sentiment_score BETWEEN -5 AND 5),
  body              text NOT NULL,
  source            text,
  observed_at       timestamptz NOT NULL DEFAULT now(),
  created_by        uuid REFERENCES auth.users(id),
  created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fci_competitor ON founder_competitor_intel(competitor_id);
CREATE INDEX IF NOT EXISTS idx_fci_type ON founder_competitor_intel(intel_type);
CREATE INDEX IF NOT EXISTS idx_fci_observed ON founder_competitor_intel(observed_at DESC);

ALTER TABLE founder_competitor_intel ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_fci_founder ON founder_competitor_intel;
CREATE POLICY p_fci_founder ON founder_competitor_intel
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================================
-- READ RPCs (STABLE SECDEF, founder-gated)
-- =========================================================================

-- 1) competitor roster
CREATE OR REPLACE FUNCTION rpc_founder_competitor_roster()
RETURNS TABLE (
  id uuid, name text, hq_city text, est_size text, watchlist_tier text,
  intel_count bigint, last_intel_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.name, c.hq_city, c.est_size, c.watchlist_tier,
         COUNT(i.id)::bigint, MAX(i.observed_at)
  FROM founder_competitors c
  LEFT JOIN founder_competitor_intel i ON i.competitor_id = c.id
  GROUP BY c.id
  ORDER BY c.watchlist_tier, c.name;
END $$;
REVOKE ALL ON FUNCTION rpc_founder_competitor_roster() FROM public;
GRANT EXECUTE ON FUNCTION rpc_founder_competitor_roster() TO authenticated;

-- 2) win/loss ledger
CREATE OR REPLACE FUNCTION rpc_founder_competitor_win_loss()
RETURNS TABLE (
  id uuid, competitor_name text, hospital_name text, outcome text,
  observed_price_rupees integer, body text, observed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, c.name, i.hospital_name, i.outcome,
         i.observed_price_rupees, i.body, i.observed_at
  FROM founder_competitor_intel i
  JOIN founder_competitors c ON c.id = i.competitor_id
  WHERE i.intel_type = 'win_loss'
  ORDER BY i.observed_at DESC
  LIMIT 200;
END $$;
REVOKE ALL ON FUNCTION rpc_founder_competitor_win_loss() FROM public;
GRANT EXECUTE ON FUNCTION rpc_founder_competitor_win_loss() TO authenticated;

-- 3) pricing observations
CREATE OR REPLACE FUNCTION rpc_founder_competitor_pricing()
RETURNS TABLE (
  id uuid, competitor_name text, hospital_name text,
  observed_price_rupees integer, body text, source text, observed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, c.name, i.hospital_name,
         i.observed_price_rupees, i.body, i.source, i.observed_at
  FROM founder_competitor_intel i
  JOIN founder_competitors c ON c.id = i.competitor_id
  WHERE i.intel_type = 'pricing' AND i.observed_price_rupees IS NOT NULL
  ORDER BY i.observed_at DESC
  LIMIT 200;
END $$;
REVOKE ALL ON FUNCTION rpc_founder_competitor_pricing() FROM public;
GRANT EXECUTE ON FUNCTION rpc_founder_competitor_pricing() TO authenticated;

-- 4) SWOT entries
CREATE OR REPLACE FUNCTION rpc_founder_competitor_swot()
RETURNS TABLE (
  id uuid, competitor_name text, swot_bucket text, body text, observed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, c.name, i.swot_bucket, i.body, i.observed_at
  FROM founder_competitor_intel i
  JOIN founder_competitors c ON c.id = i.competitor_id
  WHERE i.intel_type = 'swot' AND i.swot_bucket IS NOT NULL
  ORDER BY i.observed_at DESC
  LIMIT 200;
END $$;
REVOKE ALL ON FUNCTION rpc_founder_competitor_swot() FROM public;
GRANT EXECUTE ON FUNCTION rpc_founder_competitor_swot() TO authenticated;

-- 5) sentiment over time (weekly bucket per competitor)
CREATE OR REPLACE FUNCTION rpc_founder_competitor_sentiment_weekly()
RETURNS TABLE (
  week_start date, competitor_name text,
  avg_sentiment numeric, samples bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', i.observed_at)::date,
         c.name,
         ROUND(AVG(i.sentiment_score)::numeric, 2),
         COUNT(*)::bigint
  FROM founder_competitor_intel i
  JOIN founder_competitors c ON c.id = i.competitor_id
  WHERE i.intel_type = 'sentiment'
    AND i.sentiment_score IS NOT NULL
    AND i.observed_at > now() - interval '180 days'
  GROUP BY 1, c.name
  ORDER BY 1 DESC, c.name;
END $$;
REVOKE ALL ON FUNCTION rpc_founder_competitor_sentiment_weekly() FROM public;
GRANT EXECUTE ON FUNCTION rpc_founder_competitor_sentiment_weekly() TO authenticated;

-- 6) headline KPIs
CREATE OR REPLACE FUNCTION rpc_founder_competitor_kpis()
RETURNS TABLE (
  total_competitors bigint,
  top_tier bigint,
  watch_tier bigint,
  minor_tier bigint,
  intel_30d bigint,
  intel_90d bigint,
  intel_total bigint,
  pricing_30d bigint,
  win_30d bigint,
  loss_30d bigint,
  win_rate_pct numeric,
  swot_total bigint,
  threats_open bigint,
  avg_competitor_price_rupees numeric,
  avg_sentiment_30d numeric,
  hospitals_lost_90d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH c AS (SELECT * FROM founder_competitors),
       i AS (SELECT * FROM founder_competitor_intel)
  SELECT
    (SELECT COUNT(*) FROM c),
    (SELECT COUNT(*) FROM c WHERE watchlist_tier='top'),
    (SELECT COUNT(*) FROM c WHERE watchlist_tier='watch'),
    (SELECT COUNT(*) FROM c WHERE watchlist_tier='minor'),
    (SELECT COUNT(*) FROM i WHERE observed_at > now()-interval '30 days'),
    (SELECT COUNT(*) FROM i WHERE observed_at > now()-interval '90 days'),
    (SELECT COUNT(*) FROM i),
    (SELECT COUNT(*) FROM i WHERE intel_type='pricing' AND observed_at > now()-interval '30 days'),
    (SELECT COUNT(*) FROM i WHERE intel_type='win_loss' AND outcome='won' AND observed_at > now()-interval '30 days'),
    (SELECT COUNT(*) FROM i WHERE intel_type='win_loss' AND outcome='lost' AND observed_at > now()-interval '30 days'),
    COALESCE(ROUND(100.0 *
      (SELECT COUNT(*) FROM i WHERE intel_type='win_loss' AND outcome='won' AND observed_at > now()-interval '90 days')::numeric
      / NULLIF((SELECT COUNT(*) FROM i WHERE intel_type='win_loss' AND outcome IN ('won','lost') AND observed_at > now()-interval '90 days'),0),1),0),
    (SELECT COUNT(*) FROM i WHERE intel_type='swot'),
    (SELECT COUNT(*) FROM i WHERE intel_type='swot' AND swot_bucket='threat'),
    (SELECT COALESCE(ROUND(AVG(observed_price_rupees)::numeric,0),0) FROM i WHERE intel_type='pricing' AND observed_price_rupees IS NOT NULL AND observed_at > now()-interval '90 days'),
    (SELECT COALESCE(ROUND(AVG(sentiment_score)::numeric,2),0) FROM i WHERE intel_type='sentiment' AND observed_at > now()-interval '30 days'),
    (SELECT COUNT(DISTINCT hospital_name) FROM i WHERE intel_type='win_loss' AND outcome='lost' AND hospital_name IS NOT NULL AND observed_at > now()-interval '90 days');
END $$;
REVOKE ALL ON FUNCTION rpc_founder_competitor_kpis() FROM public;
GRANT EXECUTE ON FUNCTION rpc_founder_competitor_kpis() TO authenticated;

-- 7) watchlist top competitors with recent intel digest
CREATE OR REPLACE FUNCTION rpc_founder_competitor_watchlist()
RETURNS TABLE (
  id uuid, name text, hq_city text, watchlist_tier text,
  intel_30d bigint, last_intel_at timestamptz, latest_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.name, c.hq_city, c.watchlist_tier,
         COUNT(i.id) FILTER (WHERE i.observed_at > now()-interval '30 days')::bigint,
         MAX(i.observed_at),
         (SELECT body FROM founder_competitor_intel x WHERE x.competitor_id = c.id ORDER BY x.observed_at DESC LIMIT 1)
  FROM founder_competitors c
  LEFT JOIN founder_competitor_intel i ON i.competitor_id = c.id
  WHERE c.watchlist_tier IN ('top','watch')
  GROUP BY c.id
  ORDER BY c.watchlist_tier, MAX(i.observed_at) DESC NULLS LAST;
END $$;
REVOKE ALL ON FUNCTION rpc_founder_competitor_watchlist() FROM public;
GRANT EXECUTE ON FUNCTION rpc_founder_competitor_watchlist() TO authenticated;

-- =========================================================================
-- LOG helpers (VOLATILE SECDEF, founder-gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_competitor_upsert(
  p_name text, p_hq_city text, p_est_size text, p_watchlist_tier text, p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_competitors(name, hq_city, est_size, watchlist_tier, notes)
  VALUES (p_name, p_hq_city, p_est_size, COALESCE(p_watchlist_tier,'watch'), p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_competitor_upsert(text,text,text,text,text) FROM public;
GRANT EXECUTE ON FUNCTION log_founder_competitor_upsert(text,text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_competitor_intel(
  p_competitor_id uuid, p_intel_type text, p_body text,
  p_hospital_name text, p_outcome text, p_price_rupees integer,
  p_swot_bucket text, p_sentiment smallint, p_source text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_competitor_intel(
    competitor_id, intel_type, body, hospital_name, outcome,
    observed_price_rupees, swot_bucket, sentiment_score, source, created_by
  ) VALUES (
    p_competitor_id, p_intel_type, p_body, p_hospital_name, p_outcome,
    p_price_rupees, p_swot_bucket, p_sentiment, p_source, auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_competitor_intel(uuid,text,text,text,text,integer,text,smallint,text) FROM public;
GRANT EXECUTE ON FUNCTION log_founder_competitor_intel(uuid,text,text,text,text,integer,text,smallint,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_competitor_retier(
  p_competitor_id uuid, p_new_tier text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_competitors
     SET watchlist_tier = p_new_tier, updated_at = now()
   WHERE id = p_competitor_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_competitor_retier(uuid,text) FROM public;
GRANT EXECUTE ON FUNCTION log_founder_competitor_retier(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_competitor_intel_delete(
  p_intel_id uuid
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM founder_competitor_intel WHERE id = p_intel_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_competitor_intel_delete(uuid) FROM public;
GRANT EXECUTE ON FUNCTION log_founder_competitor_intel_delete(uuid) TO authenticated;

COMMIT;