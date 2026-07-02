BEGIN;

-- =============================================================================
-- Round 2337: Founder Weekly Inspirational Quote Diary
-- Quote of the week (from books/talks), founder reflection, applied-this-week
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.founder_quote_diary_entries_r2337 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_starting date NOT NULL,
  quote_text text NOT NULL,
  quote_author text NOT NULL,
  source_type text NOT NULL CHECK (source_type IN ('book','talk','podcast','article','film','conversation','other')),
  source_title text NOT NULL,
  source_url text,
  theme_tag text NOT NULL CHECK (theme_tag IN ('leadership','resilience','focus','customers','craft','growth','team','vision','humility','discipline')),
  founder_reflection text NOT NULL,
  applied_this_week text,
  impact_score smallint CHECK (impact_score BETWEEN 1 AND 10),
  share_with_team boolean NOT NULL DEFAULT false,
  is_pinned boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (founder_id, week_starting)
);

CREATE INDEX IF NOT EXISTS idx_fqde_r2337_week ON public.founder_quote_diary_entries_r2337(week_starting DESC);
CREATE INDEX IF NOT EXISTS idx_fqde_r2337_theme ON public.founder_quote_diary_entries_r2337(theme_tag);
CREATE INDEX IF NOT EXISTS idx_fqde_r2337_pinned ON public.founder_quote_diary_entries_r2337(is_pinned) WHERE is_pinned;

ALTER TABLE public.founder_quote_diary_entries_r2337 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_quote_diary_entries_r2337;
CREATE POLICY founder_all ON public.founder_quote_diary_entries_r2337
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.founder_quote_diary_actions_r2337 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL REFERENCES public.founder_quote_diary_entries_r2337(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  action_status text NOT NULL DEFAULT 'planned' CHECK (action_status IN ('planned','in_progress','completed','dropped')),
  due_date date,
  completed_at timestamptz,
  outcome_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fqda_r2337_entry ON public.founder_quote_diary_actions_r2337(entry_id);
CREATE INDEX IF NOT EXISTS idx_fqda_r2337_status ON public.founder_quote_diary_actions_r2337(action_status);

ALTER TABLE public.founder_quote_diary_actions_r2337 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_quote_diary_actions_r2337;
CREATE POLICY founder_all ON public.founder_quote_diary_actions_r2337
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- =============================================================================
-- RPC 1: recent diary entries
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fqde_r2337_recent_entries(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  week_starting date,
  quote_text text,
  quote_author text,
  source_type text,
  source_title text,
  theme_tag text,
  impact_score smallint,
  is_pinned boolean,
  action_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.week_starting, e.quote_text, e.quote_author,
         e.source_type, e.source_title, e.theme_tag, e.impact_score, e.is_pinned,
         (SELECT count(*) FROM public.founder_quote_diary_actions_r2337 a WHERE a.entry_id = e.id) AS action_count
  FROM public.founder_quote_diary_entries_r2337 e
  ORDER BY e.week_starting DESC, e.created_at DESC
  LIMIT p_limit;
END;
$$;

-- =============================================================================
-- RPC 2: theme breakdown
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fqde_r2337_theme_breakdown()
RETURNS TABLE (
  theme_tag text,
  entry_count bigint,
  avg_impact numeric,
  pinned_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.theme_tag,
         count(*) AS entry_count,
         round(avg(e.impact_score)::numeric, 2) AS avg_impact,
         count(*) FILTER (WHERE e.is_pinned) AS pinned_count
  FROM public.founder_quote_diary_entries_r2337 e
  GROUP BY e.theme_tag
  ORDER BY entry_count DESC;
END;
$$;

-- =============================================================================
-- RPC 3: source-type breakdown
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fqde_r2337_source_breakdown()
RETURNS TABLE (
  source_type text,
  entry_count bigint,
  distinct_authors bigint,
  avg_impact numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.source_type,
         count(*) AS entry_count,
         count(DISTINCT e.quote_author) AS distinct_authors,
         round(avg(e.impact_score)::numeric, 2) AS avg_impact
  FROM public.founder_quote_diary_entries_r2337 e
  GROUP BY e.source_type
  ORDER BY entry_count DESC;
END;
$$;

-- =============================================================================
-- RPC 4: pinned entries
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fqde_r2337_pinned_entries()
RETURNS TABLE (
  id uuid,
  week_starting date,
  quote_text text,
  quote_author text,
  theme_tag text,
  impact_score smallint,
  founder_reflection text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.week_starting, e.quote_text, e.quote_author,
         e.theme_tag, e.impact_score, e.founder_reflection
  FROM public.founder_quote_diary_entries_r2337 e
  WHERE e.is_pinned
  ORDER BY e.impact_score DESC NULLS LAST, e.week_starting DESC;
END;
$$;

-- =============================================================================
-- RPC 5: top authors quoted
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fqde_r2337_top_authors(p_limit int DEFAULT 15)
RETURNS TABLE (
  quote_author text,
  quote_count bigint,
  avg_impact numeric,
  themes_touched bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.quote_author,
         count(*) AS quote_count,
         round(avg(e.impact_score)::numeric, 2) AS avg_impact,
         count(DISTINCT e.theme_tag) AS themes_touched
  FROM public.founder_quote_diary_entries_r2337 e
  GROUP BY e.quote_author
  ORDER BY quote_count DESC, avg_impact DESC NULLS LAST
  LIMIT p_limit;
END;
$$;

-- =============================================================================
-- RPC 6: open actions across diary
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fqde_r2337_open_actions()
RETURNS TABLE (
  action_id uuid,
  entry_id uuid,
  week_starting date,
  quote_author text,
  theme_tag text,
  action_text text,
  action_status text,
  due_date date,
  days_until_due int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, e.id, e.week_starting, e.quote_author, e.theme_tag,
         a.action_text, a.action_status, a.due_date,
         (a.due_date - current_date)::int AS days_until_due
  FROM public.founder_quote_diary_actions_r2337 a
  JOIN public.founder_quote_diary_entries_r2337 e ON e.id = a.entry_id
  WHERE a.action_status IN ('planned','in_progress')
  ORDER BY a.due_date NULLS LAST, e.week_starting DESC;
END;
$$;

-- =============================================================================
-- RPC 7: 12-week diary cadence
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fqde_r2337_cadence_12w()
RETURNS TABLE (
  week_starting date,
  entries_logged bigint,
  themes_explored bigint,
  avg_impact numeric,
  has_pinned boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.week_starting,
         count(*) AS entries_logged,
         count(DISTINCT e.theme_tag) AS themes_explored,
         round(avg(e.impact_score)::numeric, 2) AS avg_impact,
         bool_or(e.is_pinned) AS has_pinned
  FROM public.founder_quote_diary_entries_r2337 e
  WHERE e.week_starting >= current_date - interval '12 weeks'
  GROUP BY e.week_starting
  ORDER BY e.week_starting DESC;
END;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.fqde_r2337_recent_entries(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fqde_r2337_theme_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fqde_r2337_source_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fqde_r2337_pinned_entries() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fqde_r2337_top_authors(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fqde_r2337_open_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fqde_r2337_cadence_12w() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.fqde_r2337_recent_entries(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fqde_r2337_theme_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fqde_r2337_source_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fqde_r2337_pinned_entries() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fqde_r2337_top_authors(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fqde_r2337_open_actions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fqde_r2337_cadence_12w() FROM PUBLIC, anon;

COMMIT;
