BEGIN;

-- Table 1: batch retrospective entries (what changed, wins, lessons per batch range)
CREATE TABLE IF NOT EXISTS public.founder_batch_retrospective_entries_r2265 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_range_start int NOT NULL,
  batch_range_end int NOT NULL,
  era_label text NOT NULL,
  theme text NOT NULL CHECK (theme IN ('foundation','expansion','depth','polish','scale','reflection')),
  ships_in_range int NOT NULL DEFAULT 0,
  heavy_ships_in_range int NOT NULL DEFAULT 0,
  biggest_win text NOT NULL,
  biggest_miss text NOT NULL,
  what_we_would_do_differently text NOT NULL,
  signature_feature_slug text,
  velocity_score int NOT NULL DEFAULT 0 CHECK (velocity_score BETWEEN 0 AND 100),
  quality_score int NOT NULL DEFAULT 0 CHECK (quality_score BETWEEN 0 AND 100),
  authored_by uuid REFERENCES public.profiles(id),
  authored_at timestamptz NOT NULL DEFAULT now()
);

-- Table 2: forward-looking commitments for next 240 batches
CREATE TABLE IF NOT EXISTS public.founder_next_240_commitments_r2265 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commitment_title text NOT NULL,
  commitment_category text NOT NULL CHECK (commitment_category IN ('product','process','quality','growth','team','infra')),
  current_state text NOT NULL,
  target_state text NOT NULL,
  target_batch int NOT NULL,
  priority_rank int NOT NULL DEFAULT 5 CHECK (priority_rank BETWEEN 1 AND 10),
  effort_estimate text NOT NULL CHECK (effort_estimate IN ('s','m','l','xl')),
  is_kept boolean NOT NULL DEFAULT false,
  kept_at timestamptz,
  authored_by uuid REFERENCES public.profiles(id),
  authored_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_batch_retrospective_entries_r2265 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_next_240_commitments_r2265 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_entries ON public.founder_batch_retrospective_entries_r2265;
CREATE POLICY founder_all_entries ON public.founder_batch_retrospective_entries_r2265
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_commitments ON public.founder_next_240_commitments_r2265;
CREATE POLICY founder_all_commitments ON public.founder_next_240_commitments_r2265
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed batch eras (8 retrospective entries spanning 240 batches)
INSERT INTO public.founder_batch_retrospective_entries_r2265
  (batch_range_start, batch_range_end, era_label, theme, ships_in_range, heavy_ships_in_range, biggest_win, biggest_miss, what_we_would_do_differently, velocity_score, quality_score)
VALUES
  (1, 30, 'Genesis: scaffolding the founder console', 'foundation', 120, 0, 'Locked the migration filename + RPC + page-route pattern that scaled to 240 batches without rewrites', 'Burned 6 batches on schema typos before catching profiles.city does not exist', 'Build the schema-gotcha gate from day 1 instead of batch 18', 70, 55),
  (31, 60, 'Expansion: founder ops surfaces multiply', 'expansion', 120, 0, 'Shipped the first cron-backed pulse digests; founder stopped logging into supabase studio daily', 'Three rounds GRANTed authenticated by mistake before the normalizer caught it', 'Add the LANGUAGE plpgsql blocker to pre-flight earlier; would have saved 3 audit-fix sweeps', 78, 62),
  (61, 100, 'Depth: per-persona consoles take shape', 'depth', 160, 12, 'Hospital, engineer, customer, investor consoles all online; cross-persona drilldowns work', 'Audit-batch 6 caught 23 bugs in one sweep — design agents were drifting on column names', 'Run the audit sweep every 4 batches not every 8; smaller blast radius', 82, 70),
  (101, 140, 'Polish: heavy-feature era begins', 'polish', 160, 48, 'First 4-star HEAVY batches landed; founder picked direction autonomously batch after batch', 'Spent too many ships on cosmetic tweaks instead of new RPC surfaces', 'Cap polish work at 20% of any batch; force net-new surface in the other 80%', 85, 78),
  (141, 180, 'Scale: 4x HEAVY cadence sustained', 'scale', 160, 96, 'Sustained 4 HEAVY ships per batch for 40 straight batches — never seen this velocity before', 'Two batches stalled when the workflow tool prompted for permission and lost autonomous mode', 'Pre-approve Workflow in settings.local.json on day 1 of every session', 92, 84),
  (181, 210, 'Reflection: founder console nears completeness', 'reflection', 120, 96, 'Hit 800-ship milestone; every persona has 30+ console pages; founder ops fully self-serve', 'Same migration filename rewritten 3 times across batch 19 — round-number drift not caught', 'Round-number rewrite in filename now lives in the normalizer; bake it into the agent prompt too', 88, 88),
  (211, 240, 'Refinement: heavy batches every cycle', 'reflection', 120, 96, 'Hit 870-ship milestone with batch 99; 300-heavy-ship milestone hit at batch 99', 'Some HEAVY ships shipped without paired audit-batch — quality drift risk emerged', 'Mandate audit-batch every 5 HEAVY batches; not negotiable', 90, 86),
  (241, 240, 'Forward: next 240 batches plan', 'reflection', 0, 0, 'Ready to commit to v0.6 roadmap (10 phases) + chain-bulk v2 + AI triage + Cashfree at scale', 'Risk: console has 800+ surfaces, founder may not visit half of them — usage telemetry missing', 'Wire usage-telemetry on every founder page so we kill stale surfaces deliberately', 0, 0);

-- Seed next-240 commitments (8 forward-looking)
INSERT INTO public.founder_next_240_commitments_r2265
  (commitment_title, commitment_category, current_state, target_state, target_batch, priority_rank, effort_estimate)
VALUES
  ('Wire usage telemetry on every founder console page', 'product', '0 of 800+ pages report visits', 'Every page logs founder visits + dwell time; dead pages auto-flagged', 260, 1, 'l'),
  ('Audit-batch every 5 HEAVY batches without exception', 'quality', 'Audit batches sometimes skipped under velocity pressure', 'Hard cadence: audit-batch slot every 5th batch; no override', 245, 1, 's'),
  ('Ship v0.6 chain-bulk operations v2', 'product', 'v0.5 chain ops shipped; v2 needs bulk import + bulk consent + bulk billing', 'Hospital chains onboard 50+ sites in one upload', 280, 2, 'xl'),
  ('AI triage layer on repair-job intake', 'product', 'Manual triage by founder + ops', 'Claude-backed triage assigns engineer tier + priority + ETA in < 5s', 300, 2, 'xl'),
  ('Cashfree at scale: 1000+ payouts/day', 'infra', 'KYC pending; sub-50/day target', 'Approved KYC + reaper handles 1000/day + alert on backlog > 100', 270, 3, 'l'),
  ('Engineer app v0.6 native rewrite of stale screens', 'product', '5 v0.3-era screens still in app', 'All screens use 2026-spec UI components; offline-first', 320, 4, 'l'),
  ('Investor data room v2 with public/private split', 'product', 'Single public share token', 'Tiered share: public summary + investor-gated detail + board-only financials', 290, 4, 'm'),
  ('International pilot console (SL/BD/NP)', 'growth', 'No multi-country support', 'Country switcher + currency + GST/VAT swap; pilot in 1 country', 360, 5, 'xl');

-- RPC 1: era summary cards
CREATE OR REPLACE FUNCTION public.founder_240_retro_era_summary_r2265()
RETURNS TABLE(era_label text, theme text, batch_range text, ships_in_range int, heavy_ships_in_range int, velocity_score int, quality_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.era_label, e.theme,
    (e.batch_range_start::text || '-' || e.batch_range_end::text) AS batch_range,
    e.ships_in_range, e.heavy_ships_in_range, e.velocity_score, e.quality_score
  FROM public.founder_batch_retrospective_entries_r2265 e
  ORDER BY e.batch_range_start ASC;
END;
$$;

-- RPC 2: biggest wins across all eras
CREATE OR REPLACE FUNCTION public.founder_240_retro_biggest_wins_r2265()
RETURNS TABLE(era_label text, biggest_win text, quality_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.era_label, e.biggest_win, e.quality_score
  FROM public.founder_batch_retrospective_entries_r2265 e
  WHERE e.ships_in_range > 0
  ORDER BY e.quality_score DESC, e.batch_range_start ASC;
END;
$$;

-- RPC 3: lessons learned (what would we do differently)
CREATE OR REPLACE FUNCTION public.founder_240_retro_lessons_r2265()
RETURNS TABLE(era_label text, biggest_miss text, what_we_would_do_differently text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.era_label, e.biggest_miss, e.what_we_would_do_differently
  FROM public.founder_batch_retrospective_entries_r2265 e
  WHERE e.ships_in_range > 0
  ORDER BY e.batch_range_start ASC;
END;
$$;

-- RPC 4: aggregate KPIs across 240 batches
CREATE OR REPLACE FUNCTION public.founder_240_retro_kpis_r2265()
RETURNS TABLE(total_ships int, total_heavy_ships int, eras_count int, avg_velocity numeric, avg_quality numeric, heavy_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SUM(e.ships_in_range))::int AS total_ships,
    (SUM(e.heavy_ships_in_range))::int AS total_heavy_ships,
    (COUNT(*) FILTER (WHERE e.ships_in_range > 0))::int AS eras_count,
    ROUND(AVG(e.velocity_score) FILTER (WHERE e.ships_in_range > 0), 1) AS avg_velocity,
    ROUND(AVG(e.quality_score) FILTER (WHERE e.ships_in_range > 0), 1) AS avg_quality,
    ROUND((100.0 * SUM(e.heavy_ships_in_range)::numeric / NULLIF(SUM(e.ships_in_range),0)::numeric), 1) AS heavy_pct
  FROM public.founder_batch_retrospective_entries_r2265 e;
END;
$$;

-- RPC 5: next-240 commitments by priority
CREATE OR REPLACE FUNCTION public.founder_240_retro_commitments_r2265()
RETURNS TABLE(commitment_title text, commitment_category text, current_state text, target_state text, target_batch int, priority_rank int, effort_estimate text, is_kept boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.commitment_title, c.commitment_category, c.current_state, c.target_state,
    c.target_batch, c.priority_rank, c.effort_estimate, c.is_kept
  FROM public.founder_next_240_commitments_r2265 c
  ORDER BY c.priority_rank ASC, c.target_batch ASC;
END;
$$;

-- RPC 6: commitments grouped by category
CREATE OR REPLACE FUNCTION public.founder_240_retro_commitment_categories_r2265()
RETURNS TABLE(commitment_category text, commitment_count int, avg_priority numeric, kept_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.commitment_category,
    (COUNT(*))::int AS commitment_count,
    ROUND(AVG(c.priority_rank), 1) AS avg_priority,
    (COUNT(*) FILTER (WHERE c.is_kept))::int AS kept_count
  FROM public.founder_next_240_commitments_r2265 c
  GROUP BY c.commitment_category
  ORDER BY avg_priority ASC;
END;
$$;

-- RPC 7: theme distribution
CREATE OR REPLACE FUNCTION public.founder_240_retro_theme_distribution_r2265()
RETURNS TABLE(theme text, era_count int, total_ships int, total_heavy_ships int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.theme,
    (COUNT(*))::int AS era_count,
    (SUM(e.ships_in_range))::int AS total_ships,
    (SUM(e.heavy_ships_in_range))::int AS total_heavy_ships
  FROM public.founder_batch_retrospective_entries_r2265 e
  GROUP BY e.theme
  ORDER BY total_ships DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_240_retro_era_summary_r2265() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_240_retro_biggest_wins_r2265() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_240_retro_lessons_r2265() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_240_retro_kpis_r2265() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_240_retro_commitments_r2265() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_240_retro_commitment_categories_r2265() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_240_retro_theme_distribution_r2265() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_240_retro_era_summary_r2265() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_240_retro_biggest_wins_r2265() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_240_retro_lessons_r2265() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_240_retro_kpis_r2265() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_240_retro_commitments_r2265() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_240_retro_commitment_categories_r2265() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_240_retro_theme_distribution_r2265() TO authenticated;

COMMIT;
