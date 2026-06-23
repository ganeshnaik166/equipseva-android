-- r2329: Founder 1500 SHIPS milestone memo
-- Reflection on hitting 1500 ships, top distinct lessons across phases, next-1500 vision
BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_1500_ships_milestone_memo_r2329 (
  id bigserial PRIMARY KEY,
  memo_title text NOT NULL,
  ships_total integer NOT NULL DEFAULT 1500,
  written_at timestamptz NOT NULL DEFAULT now(),
  phase_label text NOT NULL,
  reflection_body text NOT NULL,
  vision_next_1500 text NOT NULL,
  author_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  pinned boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_1500_ships_milestone_lessons_r2329 (
  id bigserial PRIMARY KEY,
  memo_id bigint NOT NULL REFERENCES public.founder_1500_ships_milestone_memo_r2329(id) ON DELETE CASCADE,
  lesson_rank integer NOT NULL,
  lesson_category text NOT NULL CHECK (lesson_category IN ('schema','workflow','design','audit','release','founder_ops','culture')),
  lesson_title text NOT NULL,
  lesson_body text NOT NULL,
  ships_range text,
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_1500_ships_milestone_memo_r2329 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_1500_ships_milestone_lessons_r2329 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2329_memo ON public.founder_1500_ships_milestone_memo_r2329;
CREATE POLICY founder_all_r2329_memo ON public.founder_1500_ships_milestone_memo_r2329
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2329_lessons ON public.founder_1500_ships_milestone_lessons_r2329;
CREATE POLICY founder_all_r2329_lessons ON public.founder_1500_ships_milestone_lessons_r2329
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

INSERT INTO public.founder_1500_ships_milestone_memo_r2329
  (memo_title, ships_total, phase_label, reflection_body, vision_next_1500, pinned)
VALUES
  ('1500 Ships Milestone Memo',
   1500,
   'v0.7 / Day 12',
   'Hitting 1500 ships means we have crossed from "MVP scramble" to "production muscle memory". The shape of the company is no longer a question of whether we can ship; it is a question of which 4 things we ship every batch and whether the audit-fix sweep stays clean. The Equipseva founder console has become the single source of truth for ops, money, escalations, and investor narrative.',
   'Next 1500 ships sequence: (1) compress audit-fix sweep to zero confirmed bugs for 50 consecutive batches; (2) graduate from founder-only console to internal-ops-team console with role-scoped views; (3) ship Cashfree at scale + GST e-invoice phase 2; (4) international pilot (SL/BD/NP) reaches paid revenue; (5) Engineer app v0.7 closes loop on supervised training graduation; (6) hospital portal v2 reaches 50 paying hospital chains; (7) AI triage drives 40% of first-touch repair calls; (8) founder memo cadence: weekly digest + monthly board pack + quarterly investor letter, all auto-generated from console state.',
   true);

INSERT INTO public.founder_1500_ships_milestone_lessons_r2329
  (memo_id, lesson_rank, lesson_category, lesson_title, lesson_body, ships_range, severity)
VALUES
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   1, 'schema', 'CREATE TABLE IF NOT EXISTS silently keeps old schema',
   'Most painful single recurring class. If the table already exists from an earlier round, the new column list is ignored without warning. Mitigation: always grep CREATE TABLE first; if the table exists, use ALTER TABLE ADD COLUMN IF NOT EXISTS for every new column.',
   'r797 to r2329', 'critical'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   2, 'workflow', 'LANGUAGE plpgsql skips the founder gate',
   'Design agents repeatedly emitted LANGUAGE plpgsql functions that GRANT EXECUTE TO authenticated without is_founder() because sql functions do not support RAISE EXCEPTION control flow. Normalizer now rewrites every SECDEF to plpgsql and injects the gate.',
   'r1269 to r2329', 'critical'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   3, 'schema', 'profiles.role enum is closed and does not include customer',
   'Patient/customer concept lives in hospital_admin and downstream surfaces; never in profiles.role. Several design batches assumed customer existed and broke RLS.',
   'r801 to r2200', 'high'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   4, 'audit', 'Audit-fix sweep catches more bugs than CI ever will',
   'Across 12+ audit batches we caught 80+ confirmed prod bugs that CI green-lit. CI verifies syntax; the audit sweep verifies semantics against the live schema.',
   'r1163 to r2329', 'high'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   5, 'design', 'JSX text must escape > < & or build fails',
   'Repeated React build failures from raw comparison operators. Pre-flight scrubber now rewrites all six tokens.',
   'r900 to r2329', 'high'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   6, 'workflow', 'pg_cron has no JWT so SECDEF + is_founder() fails',
   'Any cron-invoked function that calls is_founder() raises. Inline the founder check or split into an internal helper that bypasses the gate but verifies an alternative claim.',
   'r1313 to r2329', 'high'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   7, 'founder_ops', 'Chain batches with no pause',
   'User explicitly called out the pause habit at r1503. Fire next design batch immediately after committing prior; never wait for ok between batches in autonomous mode.',
   'r1503 to r2329', 'medium'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   8, 'release', 'Deploy verification not equal to CI green',
   'supabase db push can return zero exit while the migration silently no-ops. Always verify function list + table column list after every push.',
   'r463 to r2329', 'high'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   9, 'schema', 'Round-numbered tables protect us from collisions',
   'Suffixing every new table with _r<round> means two design agents can never clobber each other. The cost is index sprawl; the benefit is zero ambiguity in audit-fix.',
   'r797 to r2329', 'medium'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   10, 'culture', 'Caveman mode keeps signal high',
   'Compressed grammar in user feedback forced sharper specs and faster iteration. Verbose memos came back as founder reflections, not as workflow input.',
   'r600 to r2329', 'low'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   11, 'audit', 'False positives are still useful',
   'Audit-9 had 8 false positives out of 40 raw findings because the auditor did not have the latest schema cache. The exercise still surfaced 12 real bugs and tightened the schema brief.',
   'r1230 to r2329', 'low'),
  ((SELECT id FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY id DESC LIMIT 1),
   12, 'founder_ops', 'Never ask tell next',
   'Decide autonomously. End of turn equals ship report plus next round picked, not soliciting input. Single biggest velocity unlock.',
   'r700 to r2329', 'high');

CREATE OR REPLACE FUNCTION public.founder_1500_ships_milestone_memo_r2329_latest()
RETURNS TABLE (
  id bigint, memo_title text, ships_total integer, written_at timestamptz,
  phase_label text, reflection_body text, vision_next_1500 text, pinned boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.memo_title, m.ships_total, m.written_at, m.phase_label,
           m.reflection_body, m.vision_next_1500, m.pinned
    FROM public.founder_1500_ships_milestone_memo_r2329 m
    ORDER BY m.pinned DESC, m.written_at DESC
    LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_1500_ships_milestone_memo_r2329_list_memos(p_limit integer DEFAULT 20)
RETURNS TABLE (
  id bigint, memo_title text, ships_total integer, written_at timestamptz,
  phase_label text, pinned boolean, lesson_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.memo_title, m.ships_total, m.written_at, m.phase_label, m.pinned,
           (SELECT count(*) FROM public.founder_1500_ships_milestone_lessons_r2329 l WHERE l.memo_id = m.id)
    FROM public.founder_1500_ships_milestone_memo_r2329 m
    ORDER BY m.pinned DESC, m.written_at DESC
    LIMIT GREATEST(coalesce(p_limit, 20), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_1500_ships_milestone_memo_r2329_list_lessons(p_memo_id bigint)
RETURNS TABLE (
  id bigint, lesson_rank integer, lesson_category text, lesson_title text,
  lesson_body text, ships_range text, severity text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.lesson_rank, l.lesson_category, l.lesson_title, l.lesson_body, l.ships_range, l.severity
    FROM public.founder_1500_ships_milestone_lessons_r2329 l
    WHERE l.memo_id = p_memo_id
    ORDER BY l.lesson_rank ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_1500_ships_milestone_memo_r2329_lessons_by_category()
RETURNS TABLE (
  lesson_category text, lesson_count bigint, critical_count bigint, high_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.lesson_category,
           count(*),
           count(*) FILTER (WHERE l.severity = 'critical'),
           count(*) FILTER (WHERE l.severity = 'high')
    FROM public.founder_1500_ships_milestone_lessons_r2329 l
    GROUP BY l.lesson_category
    ORDER BY count(*) DESC, l.lesson_category ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_1500_ships_milestone_memo_r2329_top_lessons(p_limit integer DEFAULT 10)
RETURNS TABLE (
  lesson_rank integer, lesson_category text, lesson_title text, severity text, ships_range text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.lesson_rank, l.lesson_category, l.lesson_title, l.severity, l.ships_range
    FROM public.founder_1500_ships_milestone_lessons_r2329 l
    JOIN public.founder_1500_ships_milestone_memo_r2329 m ON m.id = l.memo_id
    WHERE m.pinned = true
    ORDER BY
      CASE l.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
      l.lesson_rank ASC
    LIMIT GREATEST(coalesce(p_limit, 10), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_1500_ships_milestone_memo_r2329_severity_mix()
RETURNS TABLE (severity text, lesson_count bigint, pct_of_total numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM public.founder_1500_ships_milestone_lessons_r2329;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
    SELECT l.severity,
           count(*),
           round((count(*)::numeric / v_total::numeric) * 100, 1)
    FROM public.founder_1500_ships_milestone_lessons_r2329 l
    GROUP BY l.severity
    ORDER BY CASE l.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_1500_ships_milestone_memo_r2329_summary()
RETURNS TABLE (
  total_memos bigint, total_lessons bigint, critical_lessons bigint,
  high_lessons bigint, latest_phase text, latest_ships_total integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*) FROM public.founder_1500_ships_milestone_memo_r2329),
      (SELECT count(*) FROM public.founder_1500_ships_milestone_lessons_r2329),
      (SELECT count(*) FROM public.founder_1500_ships_milestone_lessons_r2329 WHERE severity = 'critical'),
      (SELECT count(*) FROM public.founder_1500_ships_milestone_lessons_r2329 WHERE severity = 'high'),
      (SELECT phase_label FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY pinned DESC, written_at DESC LIMIT 1),
      (SELECT ships_total FROM public.founder_1500_ships_milestone_memo_r2329 ORDER BY pinned DESC, written_at DESC LIMIT 1);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_latest() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_list_memos(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_list_lessons(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_lessons_by_category() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_top_lessons(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_severity_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_latest() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_list_memos(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_list_lessons(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_lessons_by_category() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_top_lessons(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_severity_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_1500_ships_milestone_memo_r2329_summary() TO authenticated;

COMMIT;
