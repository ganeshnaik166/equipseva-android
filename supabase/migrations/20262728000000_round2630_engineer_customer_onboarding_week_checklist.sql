-- Round 2630: Engineer Customer Onboarding Week Checklist
-- 7-day onboarding checklist per engineer-hospital pair plus per-item outcome logs

BEGIN;

-- ============================================================
-- TABLE: engineer_customer_onboarding_r2630
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_customer_onboarding_r2630 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  onboarding_start_at timestamptz NOT NULL DEFAULT now(),
  day_offset int NOT NULL DEFAULT 0 CHECK (day_offset BETWEEN 0 AND 7),
  checklist_kind text NOT NULL CHECK (checklist_kind IN ('equipment_audit','intro_call','training','photo_walkthrough','signoff')),
  completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','done','skipped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_onboarding_r2630_engineer ON public.engineer_customer_onboarding_r2630(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_r2630_hospital ON public.engineer_customer_onboarding_r2630(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_r2630_day ON public.engineer_customer_onboarding_r2630(day_offset);
CREATE INDEX IF NOT EXISTS idx_onboarding_r2630_kind ON public.engineer_customer_onboarding_r2630(checklist_kind);
CREATE INDEX IF NOT EXISTS idx_onboarding_r2630_status ON public.engineer_customer_onboarding_r2630(status);

ALTER TABLE public.engineer_customer_onboarding_r2630 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_customer_onboarding_r2630;
CREATE POLICY founder_all ON public.engineer_customer_onboarding_r2630
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE: onboarding_checklist_outcomes_r2630
-- ============================================================
CREATE TABLE IF NOT EXISTS public.onboarding_checklist_outcomes_r2630 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.engineer_customer_onboarding_r2630(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('positive','concern','skipped')),
  customer_feedback_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_onboarding_outcomes_r2630_item ON public.onboarding_checklist_outcomes_r2630(item_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_outcomes_r2630_kind ON public.onboarding_checklist_outcomes_r2630(outcome_kind);
CREATE INDEX IF NOT EXISTS idx_onboarding_outcomes_r2630_status ON public.onboarding_checklist_outcomes_r2630(status);

ALTER TABLE public.onboarding_checklist_outcomes_r2630 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.onboarding_checklist_outcomes_r2630;
CREATE POLICY founder_all ON public.onboarding_checklist_outcomes_r2630
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.engineer_customer_onboarding_r2630 (engineer_user_id, hospital_user_id, onboarding_start_at, day_offset, checklist_kind, completed, completed_at, owner_email, status, notes)
SELECT e.id, p.id, '2026-06-15'::timestamptz, 0, 'equipment_audit', true, '2026-06-15'::timestamptz, 'ops@equipseva.com', 'done', 'Inventory of 12 devices captured'
FROM public.engineers e CROSS JOIN public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.engineer_customer_onboarding_r2630 (engineer_user_id, hospital_user_id, onboarding_start_at, day_offset, checklist_kind, completed, completed_at, owner_email, status, notes)
SELECT e.id, p.id, '2026-06-15'::timestamptz, 1, 'intro_call', true, '2026-06-16'::timestamptz, 'ops@equipseva.com', 'done', 'Biomed lead intro complete'
FROM public.engineers e CROSS JOIN public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.engineer_customer_onboarding_r2630 (engineer_user_id, hospital_user_id, onboarding_start_at, day_offset, checklist_kind, completed, completed_at, owner_email, status, notes)
SELECT e.id, p.id, '2026-06-15'::timestamptz, 3, 'training', false, NULL, 'ops@equipseva.com', 'in_progress', 'Day 3 scheduling slipped to day 4'
FROM public.engineers e CROSS JOIN public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.engineer_customer_onboarding_r2630 (engineer_user_id, hospital_user_id, onboarding_start_at, day_offset, checklist_kind, completed, completed_at, owner_email, status, notes)
SELECT e.id, p.id, '2026-06-15'::timestamptz, 5, 'photo_walkthrough', false, NULL, 'ops@equipseva.com', 'pending', 'Awaiting site visit'
FROM public.engineers e CROSS JOIN public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.engineer_customer_onboarding_r2630 (engineer_user_id, hospital_user_id, onboarding_start_at, day_offset, checklist_kind, completed, completed_at, owner_email, status, notes)
SELECT e.id, p.id, '2026-06-15'::timestamptz, 7, 'signoff', false, NULL, 'ops@equipseva.com', 'pending', 'Signoff pending training'
FROM public.engineers e CROSS JOIN public.profiles p
WHERE p.role = 'hospital_admin'
LIMIT 1;

INSERT INTO public.onboarding_checklist_outcomes_r2630 (item_id, observed_at, outcome_kind, customer_feedback_md, owner_email, status, notes)
SELECT id, '2026-06-15'::timestamptz, 'positive', 'Audit thorough and clear', 'ops@equipseva.com', 'done', 'Customer pleased with detail'
FROM public.engineer_customer_onboarding_r2630 WHERE checklist_kind = 'equipment_audit' LIMIT 1;

INSERT INTO public.onboarding_checklist_outcomes_r2630 (item_id, observed_at, outcome_kind, customer_feedback_md, owner_email, status, notes)
SELECT id, '2026-06-16'::timestamptz, 'positive', 'Biomed lead happy with engineer rapport', 'ops@equipseva.com', 'done', 'Strong start'
FROM public.engineer_customer_onboarding_r2630 WHERE checklist_kind = 'intro_call' LIMIT 1;

INSERT INTO public.onboarding_checklist_outcomes_r2630 (item_id, observed_at, outcome_kind, customer_feedback_md, owner_email, status, notes)
SELECT id, '2026-06-18'::timestamptz, 'concern', 'Training rescheduling caused friction', 'ops@equipseva.com', 'open', 'Need backup engineer on standby'
FROM public.engineer_customer_onboarding_r2630 WHERE checklist_kind = 'training' LIMIT 1;

INSERT INTO public.onboarding_checklist_outcomes_r2630 (item_id, observed_at, outcome_kind, customer_feedback_md, owner_email, status, notes)
SELECT id, '2026-06-19'::timestamptz, 'skipped', 'Photo walkthrough deferred at customer request', 'ops@equipseva.com', 'dropped', 'Customer cited bandwidth'
FROM public.engineer_customer_onboarding_r2630 WHERE checklist_kind = 'photo_walkthrough' LIMIT 1;

-- ============================================================
-- RPCs (7)
-- ============================================================

-- 1. list_onboarding_r2630
CREATE OR REPLACE FUNCTION public.list_onboarding_r2630()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  onboarding_start_at timestamptz,
  day_offset int,
  checklist_kind text,
  completed boolean,
  completed_at timestamptz,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.engineer_user_id, o.hospital_user_id, o.onboarding_start_at,
         o.day_offset, o.checklist_kind, o.completed, o.completed_at,
         o.owner_email, o.status, o.notes, o.created_at
  FROM public.engineer_customer_onboarding_r2630 o
  ORDER BY o.onboarding_start_at DESC, o.day_offset ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_onboarding_r2630() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_onboarding_r2630() TO authenticated;

-- 2. list_outcomes_r2630
CREATE OR REPLACE FUNCTION public.list_outcomes_r2630()
RETURNS TABLE (
  id uuid,
  item_id uuid,
  checklist_kind text,
  observed_at timestamptz,
  outcome_kind text,
  customer_feedback_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT oc.id, oc.item_id, o.checklist_kind,
         oc.observed_at, oc.outcome_kind, oc.customer_feedback_md,
         oc.owner_email, oc.status, oc.notes
  FROM public.onboarding_checklist_outcomes_r2630 oc
  LEFT JOIN public.engineer_customer_onboarding_r2630 o ON o.id = oc.item_id
  ORDER BY oc.observed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2630() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2630() TO authenticated;

-- 3. top_skipped_focus_r2630
CREATE OR REPLACE FUNCTION public.top_skipped_focus_r2630()
RETURNS TABLE (
  checklist_kind text,
  skipped_count bigint,
  total_count bigint,
  skip_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.checklist_kind,
         COUNT(*) FILTER (WHERE o.status = 'skipped')::bigint AS skipped_count,
         COUNT(*)::bigint AS total_count,
         (COUNT(*) FILTER (WHERE o.status = 'skipped')::numeric
           / NULLIF(COUNT(*),0)::numeric * 100)::numeric AS skip_rate
  FROM public.engineer_customer_onboarding_r2630 o
  GROUP BY o.checklist_kind
  ORDER BY skipped_count DESC, total_count DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_skipped_focus_r2630() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_skipped_focus_r2630() TO authenticated;

-- 4. checklist_kind_distribution_r2630
CREATE OR REPLACE FUNCTION public.checklist_kind_distribution_r2630()
RETURNS TABLE (
  checklist_kind text,
  total_count bigint,
  done_count bigint,
  done_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.checklist_kind,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE o.status = 'done')::bigint AS done_count,
         (COUNT(*) FILTER (WHERE o.status = 'done')::numeric
           / NULLIF(COUNT(*),0)::numeric * 100)::numeric AS done_rate
  FROM public.engineer_customer_onboarding_r2630 o
  GROUP BY o.checklist_kind
  ORDER BY total_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.checklist_kind_distribution_r2630() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.checklist_kind_distribution_r2630() TO authenticated;

-- 5. status_funnel_r2630
CREATE OR REPLACE FUNCTION public.status_funnel_r2630()
RETURNS TABLE (
  status text,
  entry_count bigint,
  avg_day_offset numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.status,
         COUNT(*)::bigint AS entry_count,
         COALESCE(AVG(o.day_offset),0)::numeric AS avg_day_offset
  FROM public.engineer_customer_onboarding_r2630 o
  GROUP BY o.status
  ORDER BY entry_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2630() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2630() TO authenticated;

-- 6. daily_completion_trend_r2630
CREATE OR REPLACE FUNCTION public.daily_completion_trend_r2630()
RETURNS TABLE (
  day_offset int,
  total_count bigint,
  done_count bigint,
  done_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.day_offset,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE o.status = 'done')::bigint AS done_count,
         (COUNT(*) FILTER (WHERE o.status = 'done')::numeric
           / NULLIF(COUNT(*),0)::numeric * 100)::numeric AS done_rate
  FROM public.engineer_customer_onboarding_r2630 o
  GROUP BY o.day_offset
  ORDER BY o.day_offset ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.daily_completion_trend_r2630() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.daily_completion_trend_r2630() TO authenticated;

-- 7. owner_load_r2630
CREATE OR REPLACE FUNCTION public.owner_load_r2630()
RETURNS TABLE (
  owner_email text,
  item_count bigint,
  done_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(o.owner_email,'unassigned') AS owner_email,
         COUNT(*)::bigint AS item_count,
         COUNT(*) FILTER (WHERE o.status = 'done')::bigint AS done_count,
         COUNT(*) FILTER (WHERE o.status IN ('pending','in_progress'))::bigint AS pending_count
  FROM public.engineer_customer_onboarding_r2630 o
  GROUP BY COALESCE(o.owner_email,'unassigned')
  ORDER BY item_count DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2630() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2630() TO authenticated;

COMMIT;
