BEGIN;
-- r1426: Engineer skills & competency matrix
-- 2 tables (taxonomy + proficiency) + 7 RPCs
-- founder-gated · auth-scoped helper for engineers · critical-skill coverage



-- =====================================================================
-- TABLE 1 · engineer_skills_taxonomy
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_skills_taxonomy (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_label     text NOT NULL UNIQUE,
  skill_kind      text NOT NULL CHECK (skill_kind IN (
    'equipment_specific','technical_repair','calibration',
    'soft_skill','language','certification','tool_proficiency','safety'
  )),
  is_active       boolean NOT NULL DEFAULT true,
  importance_band text NOT NULL DEFAULT 'medium' CHECK (importance_band IN (
    'critical','high','medium','low'
  )),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_skills_taxonomy_kind_idx
  ON public.engineer_skills_taxonomy (skill_kind) WHERE is_active;
CREATE INDEX IF NOT EXISTS engineer_skills_taxonomy_critical_idx
  ON public.engineer_skills_taxonomy (importance_band) WHERE is_active;

ALTER TABLE public.engineer_skills_taxonomy ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- TABLE 2 · engineer_skills_proficiency
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_skills_proficiency (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  skill_id            uuid NOT NULL REFERENCES public.engineer_skills_taxonomy(id) ON DELETE CASCADE,
  proficiency_level   text NOT NULL CHECK (proficiency_level IN (
    'none','aware','familiar','proficient','expert','trainer'
  )),
  self_assessed_at    timestamptz,
  founder_assessed_at timestamptz,
  evidence_uris       text[] NOT NULL DEFAULT ARRAY[]::text[],
  notes               text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, skill_id)
);

CREATE INDEX IF NOT EXISTS engineer_skills_proficiency_eng_idx
  ON public.engineer_skills_proficiency (engineer_user_id);
CREATE INDEX IF NOT EXISTS engineer_skills_proficiency_skill_idx
  ON public.engineer_skills_proficiency (skill_id);
CREATE INDEX IF NOT EXISTS engineer_skills_proficiency_level_idx
  ON public.engineer_skills_proficiency (proficiency_level);

ALTER TABLE public.engineer_skills_proficiency ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- RPC 1 · founder_engineer_skills_matrix_summary  (16 KPIs)
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_skills_matrix_summary();
CREATE FUNCTION public.founder_engineer_skills_matrix_summary()
RETURNS TABLE (
  total_skills             bigint,
  active_skills            bigint,
  critical_skills          bigint,
  high_skills              bigint,
  medium_skills            bigint,
  low_skills               bigint,
  total_engineers_assessed bigint,
  total_proficiency_rows   bigint,
  expert_count             bigint,
  proficient_count         bigint,
  familiar_count           bigint,
  aware_count              bigint,
  trainer_count            bigint,
  founder_assessed_count   bigint,
  self_assessed_count      bigint,
  avg_skills_per_engineer  numeric,
  generated_at             timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder-only';
  END IF;

  RETURN QUERY
  WITH tax AS (
    SELECT
      COUNT(*)::bigint                                                          AS total_skills,
      COUNT(*) FILTER (WHERE is_active)::bigint                                 AS active_skills,
      COUNT(*) FILTER (WHERE importance_band = 'critical' AND is_active)::bigint AS critical_skills,
      COUNT(*) FILTER (WHERE importance_band = 'high'     AND is_active)::bigint AS high_skills,
      COUNT(*) FILTER (WHERE importance_band = 'medium'   AND is_active)::bigint AS medium_skills,
      COUNT(*) FILTER (WHERE importance_band = 'low'      AND is_active)::bigint AS low_skills
    FROM public.engineer_skills_taxonomy
  ),
  prof AS (
    SELECT
      COUNT(DISTINCT engineer_user_id)::bigint                       AS total_engineers_assessed,
      COUNT(*)::bigint                                               AS total_proficiency_rows,
      COUNT(*) FILTER (WHERE proficiency_level = 'expert')::bigint     AS expert_count,
      COUNT(*) FILTER (WHERE proficiency_level = 'proficient')::bigint AS proficient_count,
      COUNT(*) FILTER (WHERE proficiency_level = 'familiar')::bigint   AS familiar_count,
      COUNT(*) FILTER (WHERE proficiency_level = 'aware')::bigint      AS aware_count,
      COUNT(*) FILTER (WHERE proficiency_level = 'trainer')::bigint    AS trainer_count,
      COUNT(*) FILTER (WHERE founder_assessed_at IS NOT NULL)::bigint  AS founder_assessed_count,
      COUNT(*) FILTER (WHERE self_assessed_at IS NOT NULL)::bigint     AS self_assessed_count
    FROM public.engineer_skills_proficiency
  )
  SELECT
    tax.total_skills, tax.active_skills,
    tax.critical_skills, tax.high_skills, tax.medium_skills, tax.low_skills,
    prof.total_engineers_assessed, prof.total_proficiency_rows,
    prof.expert_count, prof.proficient_count, prof.familiar_count, prof.aware_count, prof.trainer_count,
    prof.founder_assessed_count, prof.self_assessed_count,
    CASE WHEN prof.total_engineers_assessed = 0 THEN 0::numeric
         ELSE ROUND(prof.total_proficiency_rows::numeric / prof.total_engineers_assessed::numeric, 2)
    END,
    now()
  FROM tax CROSS JOIN prof;
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_skills_matrix_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_skills_matrix_summary() TO authenticated;

-- =====================================================================
-- RPC 2 · founder_engineer_skills_taxonomy_recent
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_skills_taxonomy_recent(integer);
CREATE FUNCTION public.founder_engineer_skills_taxonomy_recent(p_limit integer DEFAULT 80)
RETURNS TABLE (
  id              uuid,
  skill_label     text,
  skill_kind      text,
  importance_band text,
  is_active       boolean,
  engineers_with_skill bigint,
  created_at      timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder-only';
  END IF;

  RETURN QUERY
  SELECT
    t.id, t.skill_label, t.skill_kind, t.importance_band, t.is_active,
    COALESCE((
      SELECT COUNT(DISTINCT p.engineer_user_id)
      FROM public.engineer_skills_proficiency p
      WHERE p.skill_id = t.id
        AND p.proficiency_level IN ('proficient','expert','trainer')
    ), 0)::bigint,
    t.created_at
  FROM public.engineer_skills_taxonomy t
  ORDER BY
    CASE t.importance_band
      WHEN 'critical' THEN 1
      WHEN 'high'     THEN 2
      WHEN 'medium'   THEN 3
      WHEN 'low'      THEN 4
    END,
    t.created_at DESC
  LIMIT COALESCE(p_limit, 80);
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_skills_taxonomy_recent(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_skills_taxonomy_recent(integer) TO authenticated;

-- =====================================================================
-- RPC 3 · founder_engineer_skills_proficiency_recent
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_skills_proficiency_recent(integer);
CREATE FUNCTION public.founder_engineer_skills_proficiency_recent(p_limit integer DEFAULT 80)
RETURNS TABLE (
  id                  uuid,
  engineer_user_id    uuid,
  engineer_name       text,
  skill_label         text,
  skill_kind          text,
  importance_band     text,
  proficiency_level   text,
  self_assessed_at    timestamptz,
  founder_assessed_at timestamptz,
  evidence_count      integer,
  updated_at          timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder-only';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.engineer_user_id,
    COALESCE(pr.full_name, 'engineer'),
    t.skill_label,
    t.skill_kind,
    t.importance_band,
    p.proficiency_level,
    p.self_assessed_at,
    p.founder_assessed_at,
    COALESCE(array_length(p.evidence_uris, 1), 0),
    p.updated_at
  FROM public.engineer_skills_proficiency p
  JOIN public.engineer_skills_taxonomy   t ON t.id = p.skill_id
  LEFT JOIN public.profiles              pr ON pr.user_id = p.engineer_user_id
  ORDER BY p.updated_at DESC
  LIMIT COALESCE(p_limit, 80);
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_skills_proficiency_recent(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_skills_proficiency_recent(integer) TO authenticated;

-- =====================================================================
-- RPC 4 · founder_engineer_skills_critical_skill_coverage
-- % engineers proficient/expert/trainer per critical skill
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_skills_critical_skill_coverage();
CREATE FUNCTION public.founder_engineer_skills_critical_skill_coverage()
RETURNS TABLE (
  skill_id           uuid,
  skill_label        text,
  skill_kind         text,
  importance_band    text,
  total_engineers    bigint,
  proficient_or_above bigint,
  coverage_pct       numeric,
  expert_count       bigint,
  trainer_count      bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total_engineers bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder-only';
  END IF;

  SELECT COUNT(*) INTO v_total_engineers FROM public.engineers
  WHERE COALESCE(verification_status::text, '') IN ('verified','approved','active','live');

  IF v_total_engineers IS NULL OR v_total_engineers = 0 THEN
    SELECT COUNT(*) INTO v_total_engineers FROM public.engineers;
  END IF;

  RETURN QUERY
  SELECT
    t.id, t.skill_label, t.skill_kind, t.importance_band,
    v_total_engineers,
    COUNT(DISTINCT p.engineer_user_id) FILTER (
      WHERE p.proficiency_level IN ('proficient','expert','trainer')
    )::bigint,
    CASE WHEN v_total_engineers = 0 THEN 0::numeric
         ELSE ROUND(
           (COUNT(DISTINCT p.engineer_user_id) FILTER (
             WHERE p.proficiency_level IN ('proficient','expert','trainer')
           ))::numeric * 100.0 / v_total_engineers::numeric, 1)
    END,
    COUNT(*) FILTER (WHERE p.proficiency_level = 'expert')::bigint,
    COUNT(*) FILTER (WHERE p.proficiency_level = 'trainer')::bigint
  FROM public.engineer_skills_taxonomy t
  LEFT JOIN public.engineer_skills_proficiency p ON p.skill_id = t.id
  WHERE t.is_active AND t.importance_band IN ('critical','high')
  GROUP BY t.id, t.skill_label, t.skill_kind, t.importance_band
  ORDER BY
    CASE t.importance_band WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
    coverage_pct ASC NULLS FIRST,
    t.skill_label ASC;
END $$;
REVOKE ALL ON FUNCTION public.founder_engineer_skills_critical_skill_coverage() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_engineer_skills_critical_skill_coverage() TO authenticated;

-- =====================================================================
-- RPC 5 · engineer_skills_my_proficiencies (auth-scoped, engineer self-view)
-- =====================================================================
DROP FUNCTION IF EXISTS public.engineer_skills_my_proficiencies();
CREATE FUNCTION public.engineer_skills_my_proficiencies()
RETURNS TABLE (
  skill_id            uuid,
  skill_label         text,
  skill_kind          text,
  importance_band     text,
  proficiency_level   text,
  self_assessed_at    timestamptz,
  founder_assessed_at timestamptz,
  evidence_count      integer,
  notes               text,
  updated_at          timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth-required';
  END IF;

  RETURN QUERY
  SELECT
    t.id, t.skill_label, t.skill_kind, t.importance_band,
    p.proficiency_level, p.self_assessed_at, p.founder_assessed_at,
    COALESCE(array_length(p.evidence_uris, 1), 0), p.notes, p.updated_at
  FROM public.engineer_skills_proficiency p
  JOIN public.engineer_skills_taxonomy   t ON t.id = p.skill_id
  WHERE p.engineer_user_id = v_uid
  ORDER BY
    CASE t.importance_band
      WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4
    END,
    p.updated_at DESC;
END $$;
REVOKE ALL ON FUNCTION public.engineer_skills_my_proficiencies() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.engineer_skills_my_proficiencies() TO authenticated;

-- =====================================================================
-- RPC 6 · log_founder_skills_register_skill (founder write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_founder_skills_register_skill(text, text, text);
CREATE FUNCTION public.log_founder_skills_register_skill(
  p_skill_label     text,
  p_skill_kind      text,
  p_importance_band text DEFAULT 'medium'
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder-only';
  END IF;

  INSERT INTO public.engineer_skills_taxonomy (skill_label, skill_kind, importance_band)
  VALUES (p_skill_label, p_skill_kind, COALESCE(p_importance_band, 'medium'))
  ON CONFLICT (skill_label) DO UPDATE
    SET skill_kind      = EXCLUDED.skill_kind,
        importance_band = EXCLUDED.importance_band,
        is_active       = true
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_skills_register_skill(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_skills_register_skill(text, text, text) TO authenticated;

-- =====================================================================
-- RPC 7 · log_founder_skills_assess_engineer (founder write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_founder_skills_assess_engineer(uuid, uuid, text, text[], text);
CREATE FUNCTION public.log_founder_skills_assess_engineer(
  p_engineer_user_id uuid,
  p_skill_id         uuid,
  p_proficiency_level text,
  p_evidence_uris    text[] DEFAULT NULL,
  p_notes            text   DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder-only';
  END IF;

  INSERT INTO public.engineer_skills_proficiency (
    engineer_user_id, skill_id, proficiency_level,
    founder_assessed_at, evidence_uris, notes
  ) VALUES (
    p_engineer_user_id, p_skill_id, p_proficiency_level,
    now(),
    COALESCE(p_evidence_uris, ARRAY[]::text[]),
    p_notes
  )
  ON CONFLICT (engineer_user_id, skill_id) DO UPDATE
    SET proficiency_level   = EXCLUDED.proficiency_level,
        founder_assessed_at = now(),
        evidence_uris       = COALESCE(EXCLUDED.evidence_uris, public.engineer_skills_proficiency.evidence_uris),
        notes               = COALESCE(EXCLUDED.notes, public.engineer_skills_proficiency.notes),
        updated_at          = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_skills_assess_engineer(uuid, uuid, text, text[], text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_skills_assess_engineer(uuid, uuid, text, text[], text) TO authenticated;

COMMIT;