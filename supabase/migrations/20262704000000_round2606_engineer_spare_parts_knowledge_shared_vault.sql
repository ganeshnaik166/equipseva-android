-- Round 2606: Engineer spare-parts knowledge shared vault
-- Two tables + 7 RPCs, founder-only RLS

BEGIN;

-- ============================================================
-- TABLE: engineer_part_knowledge_r2606
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_part_knowledge_r2606 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  part_sku text NOT NULL,
  part_name text NOT NULL,
  failure_modes_md text,
  fix_tips_md text,
  reuse_count integer NOT NULL DEFAULT 0,
  last_used_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','featured','retired')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_epk_r2606_status ON public.engineer_part_knowledge_r2606(status);
CREATE INDEX IF NOT EXISTS idx_epk_r2606_engineer ON public.engineer_part_knowledge_r2606(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_epk_r2606_last_used ON public.engineer_part_knowledge_r2606(last_used_at DESC NULLS LAST);

ALTER TABLE public.engineer_part_knowledge_r2606 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_part_knowledge_r2606;
CREATE POLICY founder_all ON public.engineer_part_knowledge_r2606
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE: part_knowledge_reuse_events_r2606
-- ============================================================
CREATE TABLE IF NOT EXISTS public.part_knowledge_reuse_events_r2606 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  knowledge_id uuid REFERENCES public.engineer_part_knowledge_r2606(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  reuser_engineer_user_id uuid,
  outcome_kind text NOT NULL DEFAULT 'pending' CHECK (outcome_kind IN ('positive','neutral','negative','pending')),
  saved_hours numeric(8,2) NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pkre_r2606_knowledge ON public.part_knowledge_reuse_events_r2606(knowledge_id);
CREATE INDEX IF NOT EXISTS idx_pkre_r2606_observed ON public.part_knowledge_reuse_events_r2606(observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_pkre_r2606_status ON public.part_knowledge_reuse_events_r2606(status);

ALTER TABLE public.part_knowledge_reuse_events_r2606 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.part_knowledge_reuse_events_r2606;
CREATE POLICY founder_all ON public.part_knowledge_reuse_events_r2606
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.engineer_part_knowledge_r2606 (part_sku, part_name, failure_modes_md, fix_tips_md, reuse_count, last_used_at, owner_email, status, notes)
VALUES
  ('SKU-X103', 'Defib Battery Pack', '- Swells after 2 yrs\n- Capacity drop below 60%', '- Always check swelling first\n- Use OEM only, do not field-rebuild', 14, now() - interval '3 days', 'eng1@equipseva.in', 'featured', 'High-reuse vault entry'),
  ('SKU-V221', 'Ventilator O2 Sensor', '- Reads low in humid wards\n- Drift after 18 months', '- Recalibrate quarterly\n- Replace if drift > 8%', 9, now() - interval '7 days', 'eng2@equipseva.in', 'published', 'Common dental + ICU usage'),
  ('SKU-M044', 'X-ray Tube Anode Bearing', '- Buzzing noise at >100kV\n- Image streaking', '- Listen during warmup\n- Replace tube head as assembly', 4, now() - interval '21 days', 'eng3@equipseva.in', 'published', 'Critical Class B finding'),
  ('SKU-S087', 'Suction Pump Motor Brush', '- Brush wear after 800 hrs\n- Sparking visible', '- Carry spare set\n- Pair-replace both sides', 2, now() - interval '40 days', 'eng4@equipseva.in', 'draft', 'New entry pending review');

INSERT INTO public.part_knowledge_reuse_events_r2606 (knowledge_id, observed_at, outcome_kind, saved_hours, owner_email, status, notes)
SELECT id, now() - interval '2 days', 'positive', 3.5, 'eng5@equipseva.in', 'done', 'Reused tip on field repair'
FROM public.engineer_part_knowledge_r2606 WHERE part_sku = 'SKU-X103' LIMIT 1;

INSERT INTO public.part_knowledge_reuse_events_r2606 (knowledge_id, observed_at, outcome_kind, saved_hours, owner_email, status, notes)
SELECT id, now() - interval '5 days', 'positive', 2.0, 'eng6@equipseva.in', 'done', 'Saved second site visit'
FROM public.engineer_part_knowledge_r2606 WHERE part_sku = 'SKU-V221' LIMIT 1;

INSERT INTO public.part_knowledge_reuse_events_r2606 (knowledge_id, observed_at, outcome_kind, saved_hours, owner_email, status, notes)
SELECT id, now() - interval '10 days', 'neutral', 0.5, 'eng7@equipseva.in', 'open', 'Tip partially applied'
FROM public.engineer_part_knowledge_r2606 WHERE part_sku = 'SKU-M044' LIMIT 1;

INSERT INTO public.part_knowledge_reuse_events_r2606 (knowledge_id, observed_at, outcome_kind, saved_hours, owner_email, status, notes)
SELECT id, now() - interval '14 days', 'negative', 0, 'eng8@equipseva.in', 'dropped', 'Tip did not apply to this model'
FROM public.engineer_part_knowledge_r2606 WHERE part_sku = 'SKU-S087' LIMIT 1;

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS public.list_knowledge_r2606();
CREATE FUNCTION public.list_knowledge_r2606()
RETURNS TABLE (
  id uuid,
  part_sku text,
  part_name text,
  reuse_count integer,
  last_used_at timestamptz,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.part_sku, k.part_name, k.reuse_count, k.last_used_at,
         k.owner_email, k.status, k.notes, k.created_at
  FROM public.engineer_part_knowledge_r2606 k
  ORDER BY k.reuse_count DESC NULLS LAST, k.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_knowledge_r2606() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_knowledge_r2606() TO authenticated;


DROP FUNCTION IF EXISTS public.list_reuse_events_r2606();
CREATE FUNCTION public.list_reuse_events_r2606()
RETURNS TABLE (
  id uuid,
  knowledge_id uuid,
  part_sku text,
  observed_at timestamptz,
  outcome_kind text,
  saved_hours numeric,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.knowledge_id, k.part_sku, e.observed_at, e.outcome_kind,
         e.saved_hours, e.owner_email, e.status, e.notes
  FROM public.part_knowledge_reuse_events_r2606 e
  LEFT JOIN public.engineer_part_knowledge_r2606 k ON k.id = e.knowledge_id
  ORDER BY e.observed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_reuse_events_r2606() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reuse_events_r2606() TO authenticated;


DROP FUNCTION IF EXISTS public.top_reuse_parts_r2606();
CREATE FUNCTION public.top_reuse_parts_r2606()
RETURNS TABLE (
  part_sku text,
  part_name text,
  reuse_count integer,
  events_logged bigint,
  saved_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.part_sku, k.part_name, k.reuse_count,
         COUNT(e.id) AS events_logged,
         COALESCE(SUM(e.saved_hours), 0)::numeric AS saved_hours
  FROM public.engineer_part_knowledge_r2606 k
  LEFT JOIN public.part_knowledge_reuse_events_r2606 e ON e.knowledge_id = k.id
  GROUP BY k.part_sku, k.part_name, k.reuse_count
  ORDER BY k.reuse_count DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_reuse_parts_r2606() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_reuse_parts_r2606() TO authenticated;


DROP FUNCTION IF EXISTS public.status_distribution_r2606();
CREATE FUNCTION public.status_distribution_r2606()
RETURNS TABLE (
  status text,
  cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.status, COUNT(*)::bigint AS cnt
  FROM public.engineer_part_knowledge_r2606 k
  GROUP BY k.status
  ORDER BY cnt DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_distribution_r2606() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_distribution_r2606() TO authenticated;


DROP FUNCTION IF EXISTS public.top_contributor_engineers_r2606();
CREATE FUNCTION public.top_contributor_engineers_r2606()
RETURNS TABLE (
  engineer_user_id uuid,
  owner_email text,
  entries bigint,
  total_reuse bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.engineer_user_id, k.owner_email,
         COUNT(*)::bigint AS entries,
         COALESCE(SUM(k.reuse_count), 0)::bigint AS total_reuse
  FROM public.engineer_part_knowledge_r2606 k
  GROUP BY k.engineer_user_id, k.owner_email
  ORDER BY total_reuse DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_contributor_engineers_r2606() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_contributor_engineers_r2606() TO authenticated;


DROP FUNCTION IF EXISTS public.monthly_reuse_trend_r2606();
CREATE FUNCTION public.monthly_reuse_trend_r2606()
RETURNS TABLE (
  month_start timestamptz,
  events_logged bigint,
  saved_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', e.observed_at)::timestamptz AS month_start,
         COUNT(*)::bigint AS events_logged,
         COALESCE(SUM(e.saved_hours), 0)::numeric AS saved_hours
  FROM public.part_knowledge_reuse_events_r2606 e
  GROUP BY date_trunc('month', e.observed_at)
  ORDER BY month_start DESC NULLS LAST
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_reuse_trend_r2606() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_reuse_trend_r2606() TO authenticated;


DROP FUNCTION IF EXISTS public.saved_hours_summary_r2606();
CREATE FUNCTION public.saved_hours_summary_r2606()
RETURNS TABLE (
  outcome_kind text,
  events_cnt bigint,
  saved_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.outcome_kind,
         COUNT(*)::bigint AS events_cnt,
         COALESCE(SUM(e.saved_hours), 0)::numeric AS saved_hours
  FROM public.part_knowledge_reuse_events_r2606 e
  GROUP BY e.outcome_kind
  ORDER BY saved_hours DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.saved_hours_summary_r2606() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.saved_hours_summary_r2606() TO authenticated;

