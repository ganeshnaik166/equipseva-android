BEGIN;

-- ============================================================================
-- Round 2370 — Engineer Customer-Relationship Strength Score
-- Derived from CSAT × repeat-request × name-recall × tenure with hospital
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_customer_relationship_scores_r2370 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_org_id uuid NOT NULL,
  hospital_name text NOT NULL,
  engineer_name text NOT NULL,
  csat_score numeric(4,2) NOT NULL DEFAULT 0,
  csat_response_count int NOT NULL DEFAULT 0,
  repeat_request_count int NOT NULL DEFAULT 0,
  repeat_request_ratio numeric(5,2) NOT NULL DEFAULT 0,
  name_recall_count int NOT NULL DEFAULT 0,
  name_recall_ratio numeric(5,2) NOT NULL DEFAULT 0,
  tenure_months int NOT NULL DEFAULT 0,
  composite_strength_score numeric(5,2) NOT NULL DEFAULT 0,
  strength_band text NOT NULL DEFAULT 'cold' CHECK (strength_band IN ('platinum','gold','silver','bronze','cold')),
  last_interaction_at timestamptz,
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_customer_strength_r2370_engineer
  ON public.engineer_customer_relationship_scores_r2370(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_customer_strength_r2370_hospital
  ON public.engineer_customer_relationship_scores_r2370(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_engineer_customer_strength_r2370_band
  ON public.engineer_customer_relationship_scores_r2370(strength_band);
CREATE INDEX IF NOT EXISTS idx_engineer_customer_strength_r2370_score
  ON public.engineer_customer_relationship_scores_r2370(composite_strength_score DESC);

ALTER TABLE public.engineer_customer_relationship_scores_r2370 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_engineer_customer_strength_r2370
  ON public.engineer_customer_relationship_scores_r2370;
CREATE POLICY founder_all_engineer_customer_strength_r2370
  ON public.engineer_customer_relationship_scores_r2370
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Audit log table
CREATE TABLE IF NOT EXISTS public.engineer_customer_relationship_audit_r2370 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid REFERENCES public.engineer_customer_relationship_scores_r2370(id) ON DELETE CASCADE,
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  hospital_org_id uuid,
  action text NOT NULL,
  notes text,
  performed_by_email text,
  performed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_customer_audit_r2370_score
  ON public.engineer_customer_relationship_audit_r2370(score_id);
CREATE INDEX IF NOT EXISTS idx_engineer_customer_audit_r2370_engineer
  ON public.engineer_customer_relationship_audit_r2370(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_customer_audit_r2370_when
  ON public.engineer_customer_relationship_audit_r2370(performed_at DESC);

ALTER TABLE public.engineer_customer_relationship_audit_r2370 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_engineer_customer_audit_r2370
  ON public.engineer_customer_relationship_audit_r2370;
CREATE POLICY founder_all_engineer_customer_audit_r2370
  ON public.engineer_customer_relationship_audit_r2370
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: Seed score row
-- ============================================================================
CREATE OR REPLACE FUNCTION public.seed_engineer_customer_strength_r2370(
  p_engineer_user_id uuid,
  p_hospital_org_id uuid,
  p_hospital_name text,
  p_engineer_name text,
  p_csat_score numeric DEFAULT 0,
  p_csat_response_count int DEFAULT 0,
  p_tenure_months int DEFAULT 0
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_customer_relationship_scores_r2370(
    engineer_user_id, hospital_org_id, hospital_name, engineer_name,
    csat_score, csat_response_count, tenure_months
  ) VALUES (
    p_engineer_user_id, p_hospital_org_id, p_hospital_name, p_engineer_name,
    p_csat_score, p_csat_response_count, p_tenure_months
  ) RETURNING id INTO v_id;

  INSERT INTO public.engineer_customer_relationship_audit_r2370(
    score_id, engineer_user_id, hospital_org_id, action, notes, performed_by_email
  ) VALUES (
    v_id, p_engineer_user_id, p_hospital_org_id, 'seeded',
    'Initial score row created',
    (auth.jwt()->>'email')
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 2: Update repeat-request stats
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_engineer_repeat_request_r2370(
  p_score_id uuid,
  p_repeat_count int,
  p_repeat_ratio numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_customer_relationship_scores_r2370
     SET repeat_request_count = p_repeat_count,
         repeat_request_ratio = p_repeat_ratio,
         computed_at = now()
   WHERE id = p_score_id;

  INSERT INTO public.engineer_customer_relationship_audit_r2370(
    score_id, action, notes, performed_by_email
  ) VALUES (
    p_score_id, 'repeat_request_updated',
    'count=' || p_repeat_count || ' ratio=' || p_repeat_ratio,
    (auth.jwt()->>'email')
  );
END;
$$;

-- ============================================================================
-- RPC 3: Update name-recall stats
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_engineer_name_recall_r2370(
  p_score_id uuid,
  p_recall_count int,
  p_recall_ratio numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_customer_relationship_scores_r2370
     SET name_recall_count = p_recall_count,
         name_recall_ratio = p_recall_ratio,
         computed_at = now()
   WHERE id = p_score_id;

  INSERT INTO public.engineer_customer_relationship_audit_r2370(
    score_id, action, notes, performed_by_email
  ) VALUES (
    p_score_id, 'name_recall_updated',
    'count=' || p_recall_count || ' ratio=' || p_recall_ratio,
    (auth.jwt()->>'email')
  );
END;
$$;

-- ============================================================================
-- RPC 4: Recompute composite strength score
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recompute_engineer_customer_strength_r2370(
  p_score_id uuid
) RETURNS numeric
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_csat numeric;
  v_repeat numeric;
  v_recall numeric;
  v_tenure int;
  v_score numeric;
  v_band text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT csat_score, repeat_request_ratio, name_recall_ratio, tenure_months
    INTO v_csat, v_repeat, v_recall, v_tenure
    FROM public.engineer_customer_relationship_scores_r2370
   WHERE id = p_score_id;

  v_score := round(
    ((COALESCE(v_csat,0) / 5.0) * 35.0) +
    ((COALESCE(v_repeat,0) / 100.0) * 30.0) +
    ((COALESCE(v_recall,0) / 100.0) * 20.0) +
    (LEAST(COALESCE(v_tenure,0), 24)::numeric / 24.0 * 15.0)
  , 2);

  v_band := CASE
    WHEN v_score >= 85 THEN 'platinum'
    WHEN v_score >= 70 THEN 'gold'
    WHEN v_score >= 55 THEN 'silver'
    WHEN v_score >= 35 THEN 'bronze'
    ELSE 'cold'
  END;

  UPDATE public.engineer_customer_relationship_scores_r2370
     SET composite_strength_score = v_score,
         strength_band = v_band,
         computed_at = now()
   WHERE id = p_score_id;

  INSERT INTO public.engineer_customer_relationship_audit_r2370(
    score_id, action, notes, performed_by_email
  ) VALUES (
    p_score_id, 'recomputed',
    'score=' || v_score || ' band=' || v_band,
    (auth.jwt()->>'email')
  );

  RETURN v_score;
END;
$$;

-- ============================================================================
-- RPC 5: Mark last interaction
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_engineer_customer_interaction_r2370(
  p_score_id uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_customer_relationship_scores_r2370
     SET last_interaction_at = now(),
         computed_at = now()
   WHERE id = p_score_id;

  INSERT INTO public.engineer_customer_relationship_audit_r2370(
    score_id, action, notes, performed_by_email
  ) VALUES (
    p_score_id, 'interaction_marked',
    'Last interaction stamped',
    (auth.jwt()->>'email')
  );
END;
$$;

-- ============================================================================
-- RPC 6: Top relationships
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_engineer_customer_relationships_r2370(
  p_limit int DEFAULT 10
) RETURNS TABLE(
  id uuid,
  engineer_name text,
  hospital_name text,
  composite_strength_score numeric,
  strength_band text,
  csat_score numeric,
  tenure_months int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
    SELECT s.id, s.engineer_name, s.hospital_name,
           s.composite_strength_score, s.strength_band,
           s.csat_score, s.tenure_months
      FROM public.engineer_customer_relationship_scores_r2370 s
     ORDER BY s.composite_strength_score DESC
     LIMIT p_limit;
END;
$$;

-- ============================================================================
-- RPC 7: Band summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.engineer_customer_strength_band_summary_r2370()
RETURNS TABLE(
  strength_band text,
  relationship_count bigint,
  avg_score numeric,
  avg_tenure_months numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
    SELECT s.strength_band,
           count(*)::bigint,
           round(avg(s.composite_strength_score), 2),
           round(avg(s.tenure_months), 2)
      FROM public.engineer_customer_relationship_scores_r2370 s
     GROUP BY s.strength_band
     ORDER BY s.strength_band;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE ALL ON FUNCTION public.seed_engineer_customer_strength_r2370(uuid, uuid, text, text, numeric, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.seed_engineer_customer_strength_r2370(uuid, uuid, text, text, numeric, int, int) TO authenticated;

REVOKE ALL ON FUNCTION public.update_engineer_repeat_request_r2370(uuid, int, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_engineer_repeat_request_r2370(uuid, int, numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.update_engineer_name_recall_r2370(uuid, int, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_engineer_name_recall_r2370(uuid, int, numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.recompute_engineer_customer_strength_r2370(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recompute_engineer_customer_strength_r2370(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.mark_engineer_customer_interaction_r2370(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_engineer_customer_interaction_r2370(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.top_engineer_customer_relationships_r2370(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_engineer_customer_relationships_r2370(int) TO authenticated;

REVOKE ALL ON FUNCTION public.engineer_customer_strength_band_summary_r2370() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_strength_band_summary_r2370() TO authenticated;

COMMIT;
