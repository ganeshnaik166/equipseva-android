-- Round 2489: founder-monthly-mental-model-refresh
-- Tables: founder_mental_models_r2489, mental_model_application_log_r2489

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_mental_models_r2489 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_name text NOT NULL,
  source_kind text NOT NULL CHECK (source_kind IN ('book','podcast','blog','conversation','observation','experience')),
  source_label text,
  applicability_md text,
  first_principles_md text,
  last_used_at timestamptz,
  stale_threshold_days int NOT NULL DEFAULT 60,
  stale_status text NOT NULL DEFAULT 'fresh' CHECK (stale_status IN ('fresh','aging','stale','archived')),
  revisit_due_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.mental_model_application_log_r2489 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid NOT NULL REFERENCES public.founder_mental_models_r2489(id) ON DELETE CASCADE,
  applied_at timestamptz NOT NULL DEFAULT now(),
  situation_md text,
  insight_md text,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  revisit_required boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_mental_models_r2489 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mental_model_application_log_r2489 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_mental_models_r2489;
CREATE POLICY founder_all ON public.founder_mental_models_r2489
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.mental_model_application_log_r2489;
CREATE POLICY founder_all ON public.mental_model_application_log_r2489
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed models
INSERT INTO public.founder_mental_models_r2489
  (id, model_name, source_kind, source_label, applicability_md, first_principles_md, last_used_at, stale_threshold_days, stale_status, revisit_due_at, notes)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, 'Inversion', 'book', 'Poor Charlies Almanack — Munger', 'When stuck on a strategic problem, invert: ask what would guarantee failure, then avoid that.', 'Most problems easier solved backwards. Start from failure modes, work back to actions to avoid.', '2026-06-15T10:00:00Z'::timestamptz, 45, 'fresh', '2026-07-30T10:00:00Z'::timestamptz, 'Used for engineer attrition diagnosis'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'::uuid, 'Second-Order Thinking', 'book', 'The Most Important Thing — Howard Marks', 'Before any pricing or contract change, ask: and then what?', 'First-order consequences obvious; second/third-order ones decide outcomes. Always extend the chain.', '2026-04-10T09:00:00Z'::timestamptz, 60, 'aging', '2026-06-09T09:00:00Z'::timestamptz, 'Used for AMC tier pricing'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa03'::uuid, 'Hamming Question', 'podcast', 'You and Your Research — Richard Hamming', 'Weekly: what is the most important problem in EquipSeva right now, and am I working on it?', 'Important problems compound. Working on small problems is the default; force the discipline to ask.', '2026-02-20T11:00:00Z'::timestamptz, 30, 'stale', '2026-03-22T11:00:00Z'::timestamptz, 'Forgotten — needs revival'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa04'::uuid, 'Pre-mortem', 'blog', 'Farnam Street', 'Before every major launch or hire, imagine it failed 12 months later — write the obituary.', 'Prospective hindsight beats retrospective. Surfaces risks ahead of commitment.', '2026-06-01T14:00:00Z'::timestamptz, 90, 'fresh', '2026-08-30T14:00:00Z'::timestamptz, 'Used pre-Tier1 launch'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa05'::uuid, 'Bayesian Updating', 'experience', 'Personal trading lessons', 'When new evidence on hospital-chain ICP arrives, update prior probability of thesis; do not anchor.', 'Beliefs are probabilities, not certainties. Evidence shifts weight; refusing to update is identity defense.', '2026-05-25T12:00:00Z'::timestamptz, 60, 'fresh', '2026-07-24T12:00:00Z'::timestamptz, 'Used for ICP narrowing decision'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa06'::uuid, 'Lindy Effect', 'conversation', 'Chat with mentor', 'Practices/products surviving N years likely survive N more. Use to evaluate which biz playbooks to copy.', 'Non-perishable things have life expectancy proportional to age. Old is robust evidence.', NULL, 60, 'archived', NULL, 'Archived — superseded by Bayesian'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa07'::uuid, 'Circle of Competence', 'observation', 'Own deal failures', 'Only commit aggressive capital where I genuinely understand the unit economics. Otherwise probe.', 'Edge comes from knowing where edge ends. Honest boundaries beat ambitious overreach.', '2026-03-15T09:00:00Z'::timestamptz, 45, 'aging', '2026-04-29T09:00:00Z'::timestamptz, 'Used to reject manufacturer OEM bet');

-- Seed application log
INSERT INTO public.mental_model_application_log_r2489
  (model_id, applied_at, situation_md, insight_md, outcome, revisit_required, notes)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, '2026-06-15T10:00:00Z'::timestamptz, 'Engineer attrition spiking in Hyderabad pod', 'Inverted: what would guarantee attrition? Long callouts + no rest + late payouts. All three present.', 'positive', false, 'Led to overtime tracker round'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, '2026-05-10T11:00:00Z'::timestamptz, 'Stuck on Tier-2 expansion sequencing', 'Inverted: which Tier-2 cities would fail fastest? Cities with no chain presence. Defer them.', 'positive', false, 'Defer decision shipped'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'::uuid, '2026-04-10T09:00:00Z'::timestamptz, 'AMC tier pricing v2 design', 'First-order: tier-3 drives revenue. Second-order: tier-3 cannibalizes tier-2 if priced wrong.', 'positive', false, 'Used in pricing doc'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa03'::uuid, '2026-02-20T11:00:00Z'::timestamptz, 'Weekly priority review', 'Most important problem: founder bandwidth not hiring. Worked on hiring plan instead.', 'positive', true, 'Revisit cadence broken'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa04'::uuid, '2026-06-01T14:00:00Z'::timestamptz, 'Tier-1 launch pre-mortem', 'Failure mode: under-prepared engineer rotation. Built rotation buffer before launch.', 'positive', false, 'Saved launch'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa04'::uuid, '2026-05-15T10:00:00Z'::timestamptz, 'Pre-mortem on Cashfree dependency', 'Failure mode: KYC stuck and payouts blocked. Built escrow + auto-refund fallback.', 'positive', false, 'Validated by actual delay'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa05'::uuid, '2026-05-25T12:00:00Z'::timestamptz, 'Hospital-chain ICP review', 'New evidence: 200+ bed multispecialty wins on cycle time, not price. Updated prior.', 'positive', false, 'ICP narrowed to 200+ bed'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa05'::uuid, '2026-03-01T09:00:00Z'::timestamptz, 'Marketplace volume thesis', 'Evidence weak; refused to anchor on early enthusiasm.', 'neutral', false, 'Held position'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa07'::uuid, '2026-03-15T09:00:00Z'::timestamptz, 'Manufacturer OEM expansion offer', 'Outside circle of competence on manufacturing economics. Declined.', 'positive', false, 'Saved capital'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa07'::uuid, '2026-02-10T11:00:00Z'::timestamptz, 'International pilot SL/BD/NP', 'Edge limited; probe with single pilot rather than committed expansion.', 'pending', true, 'Pilot in flight');

-- RPC 1: list models
CREATE OR REPLACE FUNCTION public.list_models_r2489()
RETURNS TABLE (
  id uuid,
  model_name text,
  source_kind text,
  source_label text,
  applicability_md text,
  first_principles_md text,
  last_used_at timestamptz,
  stale_threshold_days int,
  stale_status text,
  revisit_due_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.model_name, m.source_kind, m.source_label, m.applicability_md,
         m.first_principles_md, m.last_used_at, m.stale_threshold_days, m.stale_status,
         m.revisit_due_at, m.notes
  FROM public.founder_mental_models_r2489 m
  ORDER BY m.last_used_at DESC NULLS LAST, m.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_models_r2489() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_models_r2489() TO authenticated;

-- RPC 2: list application log
CREATE OR REPLACE FUNCTION public.list_application_log_r2489()
RETURNS TABLE (
  id uuid,
  model_name text,
  applied_at timestamptz,
  situation_md text,
  insight_md text,
  outcome text,
  revisit_required boolean,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, m.model_name, l.applied_at, l.situation_md, l.insight_md,
         l.outcome, l.revisit_required, l.notes
  FROM public.mental_model_application_log_r2489 l
  JOIN public.founder_mental_models_r2489 m ON m.id = l.model_id
  ORDER BY l.applied_at DESC NULLS LAST, l.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_application_log_r2489() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_application_log_r2489() TO authenticated;

-- RPC 3: stale models focus
CREATE OR REPLACE FUNCTION public.stale_models_focus_r2489()
RETURNS TABLE (
  model_name text,
  source_kind text,
  stale_status text,
  last_used_at timestamptz,
  days_since_use int,
  revisit_due_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.model_name, m.source_kind, m.stale_status, m.last_used_at,
         CASE WHEN m.last_used_at IS NULL THEN NULL
              ELSE EXTRACT(DAY FROM (now() - m.last_used_at))::int END AS days_since_use,
         m.revisit_due_at
  FROM public.founder_mental_models_r2489 m
  WHERE m.stale_status IN ('aging','stale')
  ORDER BY m.last_used_at ASC NULLS FIRST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.stale_models_focus_r2489() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stale_models_focus_r2489() TO authenticated;

-- RPC 4: top applied models
CREATE OR REPLACE FUNCTION public.top_applied_models_r2489()
RETURNS TABLE (
  model_name text,
  source_kind text,
  application_count bigint,
  positive_count bigint,
  last_applied_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.model_name, m.source_kind,
         COUNT(l.id)::bigint AS application_count,
         COUNT(l.id) FILTER (WHERE l.outcome = 'positive')::bigint AS positive_count,
         MAX(l.applied_at) AS last_applied_at
  FROM public.founder_mental_models_r2489 m
  LEFT JOIN public.mental_model_application_log_r2489 l ON l.model_id = m.id
  GROUP BY m.model_name, m.source_kind
  ORDER BY application_count DESC, positive_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_applied_models_r2489() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_applied_models_r2489() TO authenticated;

-- RPC 5: source kind breakdown
CREATE OR REPLACE FUNCTION public.source_kind_breakdown_r2489()
RETURNS TABLE (
  source_kind text,
  model_count bigint,
  fresh_count bigint,
  aging_count bigint,
  stale_count bigint,
  archived_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.source_kind,
         COUNT(*)::bigint AS model_count,
         COUNT(*) FILTER (WHERE m.stale_status = 'fresh')::bigint AS fresh_count,
         COUNT(*) FILTER (WHERE m.stale_status = 'aging')::bigint AS aging_count,
         COUNT(*) FILTER (WHERE m.stale_status = 'stale')::bigint AS stale_count,
         COUNT(*) FILTER (WHERE m.stale_status = 'archived')::bigint AS archived_count
  FROM public.founder_mental_models_r2489 m
  GROUP BY m.source_kind
  ORDER BY model_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.source_kind_breakdown_r2489() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.source_kind_breakdown_r2489() TO authenticated;

-- RPC 6: monthly application trend
CREATE OR REPLACE FUNCTION public.monthly_application_trend_r2489()
RETURNS TABLE (
  month_label text,
  application_count bigint,
  positive_count bigint,
  negative_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', l.applied_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS application_count,
         COUNT(*) FILTER (WHERE l.outcome = 'positive')::bigint AS positive_count,
         COUNT(*) FILTER (WHERE l.outcome = 'negative')::bigint AS negative_count,
         COUNT(*) FILTER (WHERE l.outcome = 'pending')::bigint AS pending_count
  FROM public.mental_model_application_log_r2489 l
  WHERE l.applied_at IS NOT NULL
  GROUP BY date_trunc('month', l.applied_at)
  ORDER BY date_trunc('month', l.applied_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_application_trend_r2489() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_application_trend_r2489() TO authenticated;

-- RPC 7: revisit pipeline
CREATE OR REPLACE FUNCTION public.revisit_pipeline_r2489()
RETURNS TABLE (
  model_name text,
  source_kind text,
  stale_status text,
  revisit_due_at timestamptz,
  days_until_due int,
  revisit_required_logs bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.model_name, m.source_kind, m.stale_status, m.revisit_due_at,
         CASE WHEN m.revisit_due_at IS NULL THEN NULL
              ELSE EXTRACT(DAY FROM (m.revisit_due_at - now()))::int END AS days_until_due,
         (SELECT COUNT(*)::bigint FROM public.mental_model_application_log_r2489 l
          WHERE l.model_id = m.id AND l.revisit_required) AS revisit_required_logs
  FROM public.founder_mental_models_r2489 m
  WHERE m.stale_status <> 'archived'
  ORDER BY m.revisit_due_at ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.revisit_pipeline_r2489() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revisit_pipeline_r2489() TO authenticated;

