BEGIN;
-- r1442 ★★★★ — Founder hospital power mapping.
--
-- Who-decides-what at each hospital. Founder-visible stakeholder graph mapping
-- contract signers, budget holders, technical evaluators, daily users, blockers,
-- sponsors, and referrers per hospital — plus the relationships between them
-- (reports_to, peer_of, influenced_by, blocks, reports_above). Helps founder
-- spot the real decision-makers, identify champions to nurture and blockers
-- to flank, and avoid wasted demo cycles with people who don't move the deal.
--
-- 2 tables:
--   founder_hospital_power_map_stakeholders
--   founder_hospital_power_map_relationships
--
-- 7 RPCs:
--   founder_hospital_power_mapping_summary             — 14 KPIs
--   founder_hospital_power_map_stakeholders_recent     — stakeholder rows (40)
--   founder_hospital_power_map_relationships_recent    — relationship feed (40)
--   founder_hospital_power_map_champions               — sentiment=champion list
--   log_founder_power_map_register_stakeholder         — create stakeholder
--   log_founder_power_map_register_relationship        — create edge
--   log_founder_power_map_update_sentiment             — update sentiment band

-- ============================================================================
-- 1. TABLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_hospital_power_map_stakeholders (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_name        text NOT NULL,
  contact_role        text,
  contact_email       text,
  contact_phone       text,
  decision_authority  text NOT NULL DEFAULT 'daily_user' CHECK (decision_authority IN (
    'signs_contract','holds_budget','technical_decision','daily_user',
    'blocker','sponsor','referrer'
  )),
  influence_band      text NOT NULL DEFAULT 'medium' CHECK (influence_band IN ('high','medium','low')),
  sentiment           text NOT NULL DEFAULT 'neutral' CHECK (sentiment IN (
    'champion','supportive','neutral','skeptical','opposed'
  )),
  last_engaged_at     timestamptz,
  notes               text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhpm_stakeholders_hospital
  ON public.founder_hospital_power_map_stakeholders (hospital_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhpm_stakeholders_authority
  ON public.founder_hospital_power_map_stakeholders (decision_authority, influence_band);
CREATE INDEX IF NOT EXISTS idx_fhpm_stakeholders_sentiment
  ON public.founder_hospital_power_map_stakeholders (sentiment, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhpm_stakeholders_last_engaged
  ON public.founder_hospital_power_map_stakeholders (last_engaged_at DESC NULLS LAST);

ALTER TABLE public.founder_hospital_power_map_stakeholders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_fhpm_stakeholders
  ON public.founder_hospital_power_map_stakeholders;
CREATE POLICY founder_only_fhpm_stakeholders
  ON public.founder_hospital_power_map_stakeholders
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_hospital_power_map_relationships (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_stakeholder_id  uuid NOT NULL REFERENCES public.founder_hospital_power_map_stakeholders(id) ON DELETE CASCADE,
  target_stakeholder_id  uuid NOT NULL REFERENCES public.founder_hospital_power_map_stakeholders(id) ON DELETE CASCADE,
  relationship_kind      text NOT NULL CHECK (relationship_kind IN (
    'reports_to','peer_of','influenced_by','blocks','reports_above'
  )),
  strength_band          text NOT NULL DEFAULT 'moderate' CHECK (strength_band IN ('strong','moderate','weak')),
  notes                  text,
  created_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (source_stakeholder_id <> target_stakeholder_id)
);

CREATE INDEX IF NOT EXISTS idx_fhpm_relationships_source
  ON public.founder_hospital_power_map_relationships (source_stakeholder_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhpm_relationships_target
  ON public.founder_hospital_power_map_relationships (target_stakeholder_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhpm_relationships_kind
  ON public.founder_hospital_power_map_relationships (relationship_kind, created_at DESC);

ALTER TABLE public.founder_hospital_power_map_relationships ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_fhpm_relationships
  ON public.founder_hospital_power_map_relationships;
CREATE POLICY founder_only_fhpm_relationships
  ON public.founder_hospital_power_map_relationships
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- 2. RPCs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_power_mapping_summary();
CREATE OR REPLACE FUNCTION public.founder_hospital_power_mapping_summary()
RETURNS TABLE (
  total_stakeholders          bigint,
  total_hospitals_mapped      bigint,
  total_relationships         bigint,
  champions_count             bigint,
  supportive_count            bigint,
  neutral_count               bigint,
  skeptical_count             bigint,
  opposed_count               bigint,
  signs_contract_count        bigint,
  holds_budget_count          bigint,
  blockers_count              bigint,
  high_influence_count        bigint,
  stale_engagement_60d_count  bigint,
  avg_stakeholders_per_hospital numeric,
  generated_at                timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  WITH s AS (SELECT * FROM public.founder_hospital_power_map_stakeholders),
       r AS (SELECT * FROM public.founder_hospital_power_map_relationships)
  SELECT
    (SELECT count(*) FROM s)::bigint,
    (SELECT count(DISTINCT hospital_user_id) FROM s)::bigint,
    (SELECT count(*) FROM r)::bigint,
    (SELECT count(*) FROM s WHERE sentiment='champion')::bigint,
    (SELECT count(*) FROM s WHERE sentiment='supportive')::bigint,
    (SELECT count(*) FROM s WHERE sentiment='neutral')::bigint,
    (SELECT count(*) FROM s WHERE sentiment='skeptical')::bigint,
    (SELECT count(*) FROM s WHERE sentiment='opposed')::bigint,
    (SELECT count(*) FROM s WHERE decision_authority='signs_contract')::bigint,
    (SELECT count(*) FROM s WHERE decision_authority='holds_budget')::bigint,
    (SELECT count(*) FROM s WHERE decision_authority='blocker')::bigint,
    (SELECT count(*) FROM s WHERE influence_band='high')::bigint,
    (SELECT count(*) FROM s WHERE last_engaged_at IS NULL OR last_engaged_at < now() - interval '60 days')::bigint,
    COALESCE(ROUND((SELECT count(*)::numeric FROM s) /
      NULLIF((SELECT count(DISTINCT hospital_user_id) FROM s), 0), 2), 0)::numeric,
    now();
END;
$$;
REVOKE ALL ON FUNCTION public.founder_hospital_power_mapping_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_hospital_power_mapping_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_hospital_power_map_stakeholders_recent();
CREATE OR REPLACE FUNCTION public.founder_hospital_power_map_stakeholders_recent()
RETURNS TABLE (
  id uuid, hospital_user_id uuid, contact_name text, contact_role text,
  contact_email text, contact_phone text, decision_authority text,
  influence_band text, sentiment text, last_engaged_at timestamptz,
  notes text, created_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id, s.contact_name, s.contact_role,
         s.contact_email, s.contact_phone, s.decision_authority,
         s.influence_band, s.sentiment, s.last_engaged_at,
         s.notes, s.created_at, s.updated_at
    FROM public.founder_hospital_power_map_stakeholders s
   ORDER BY s.updated_at DESC
   LIMIT 40;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_hospital_power_map_stakeholders_recent() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_hospital_power_map_stakeholders_recent() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_hospital_power_map_relationships_recent();
CREATE OR REPLACE FUNCTION public.founder_hospital_power_map_relationships_recent()
RETURNS TABLE (
  id uuid, source_stakeholder_id uuid, source_name text, source_role text,
  target_stakeholder_id uuid, target_name text, target_role text,
  relationship_kind text, strength_band text, notes text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT r.id, r.source_stakeholder_id, ss.contact_name, ss.contact_role,
         r.target_stakeholder_id, ts.contact_name, ts.contact_role,
         r.relationship_kind, r.strength_band, r.notes, r.created_at
    FROM public.founder_hospital_power_map_relationships r
    LEFT JOIN public.founder_hospital_power_map_stakeholders ss
      ON ss.id = r.source_stakeholder_id
    LEFT JOIN public.founder_hospital_power_map_stakeholders ts
      ON ts.id = r.target_stakeholder_id
   ORDER BY r.created_at DESC
   LIMIT 40;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_hospital_power_map_relationships_recent() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_hospital_power_map_relationships_recent() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_hospital_power_map_champions();
CREATE OR REPLACE FUNCTION public.founder_hospital_power_map_champions()
RETURNS TABLE (
  id uuid, hospital_user_id uuid, contact_name text, contact_role text,
  decision_authority text, influence_band text, last_engaged_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id, s.contact_name, s.contact_role,
         s.decision_authority, s.influence_band, s.last_engaged_at, s.updated_at
    FROM public.founder_hospital_power_map_stakeholders s
   WHERE s.sentiment = 'champion'
   ORDER BY (s.influence_band='high') DESC, s.updated_at DESC
   LIMIT 30;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_hospital_power_map_champions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_hospital_power_map_champions() TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_power_map_register_stakeholder(uuid, text, text, text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_power_map_register_stakeholder(
  p_hospital_user_id uuid,
  p_contact_name text,
  p_contact_role text,
  p_contact_email text,
  p_contact_phone text,
  p_decision_authority text,
  p_influence_band text,
  p_sentiment text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  INSERT INTO public.founder_hospital_power_map_stakeholders (
    hospital_user_id, contact_name, contact_role, contact_email, contact_phone,
    decision_authority, influence_band, sentiment, notes, last_engaged_at
  ) VALUES (
    p_hospital_user_id, p_contact_name, p_contact_role, p_contact_email, p_contact_phone,
    COALESCE(p_decision_authority,'daily_user'),
    COALESCE(p_influence_band,'medium'),
    COALESCE(p_sentiment,'neutral'),
    p_notes, now()
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_power_map_register_stakeholder(uuid, text, text, text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_power_map_register_stakeholder(uuid, text, text, text, text, text, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_power_map_register_relationship(uuid, uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_power_map_register_relationship(
  p_source uuid, p_target uuid, p_relationship_kind text,
  p_strength_band text, p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  IF p_source = p_target THEN
    RAISE EXCEPTION 'source and target stakeholder must differ';
  END IF;
  INSERT INTO public.founder_hospital_power_map_relationships (
    source_stakeholder_id, target_stakeholder_id, relationship_kind, strength_band, notes
  ) VALUES (
    p_source, p_target, p_relationship_kind, COALESCE(p_strength_band,'moderate'), p_notes
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_power_map_register_relationship(uuid, uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_power_map_register_relationship(uuid, uuid, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_power_map_update_sentiment(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_power_map_update_sentiment(
  p_stakeholder_id uuid, p_sentiment text, p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  UPDATE public.founder_hospital_power_map_stakeholders
     SET sentiment       = COALESCE(p_sentiment, sentiment),
         notes           = COALESCE(p_notes, notes),
         last_engaged_at = now(),
         updated_at      = now()
   WHERE id = p_stakeholder_id;
  RETURN p_stakeholder_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_power_map_update_sentiment(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_power_map_update_sentiment(uuid, text, text) TO authenticated;

COMMIT;