-- Round 2542: engineer-customer-rapport-quality
-- Per-engineer × hospital × rapport score × small-talk topics × first-name basis × empathy moments × repeat-customer rate

BEGIN;

-- ============================================================================
-- TABLE: engineer_customer_rapport_r2542
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_customer_rapport_r2542 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rapport_score int NOT NULL DEFAULT 50 CHECK (rapport_score BETWEEN 0 AND 100),
  small_talk_topics_md text,
  first_name_basis boolean NOT NULL DEFAULT false,
  empathy_moments_count int NOT NULL DEFAULT 0 CHECK (empathy_moments_count >= 0),
  repeat_customer_rate_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (repeat_customer_rate_pct >= 0 AND repeat_customer_rate_pct <= 100),
  last_touch_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'building' CHECK (status IN ('building','strong','champion','strained')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecr_r2542_engineer ON public.engineer_customer_rapport_r2542(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecr_r2542_hospital ON public.engineer_customer_rapport_r2542(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_ecr_r2542_status ON public.engineer_customer_rapport_r2542(status);

ALTER TABLE public.engineer_customer_rapport_r2542 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_customer_rapport_r2542;
CREATE POLICY founder_all ON public.engineer_customer_rapport_r2542
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: rapport_growth_actions_r2542
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.rapport_growth_actions_r2542 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rapport_id uuid NOT NULL REFERENCES public.engineer_customer_rapport_r2542(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('remember_birthday','inquire_family','follow_up_call','handwritten_note','site_lunch')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rga_r2542_rapport ON public.rapport_growth_actions_r2542(rapport_id);
CREATE INDEX IF NOT EXISTS idx_rga_r2542_action_at ON public.rapport_growth_actions_r2542(action_at);
CREATE INDEX IF NOT EXISTS idx_rga_r2542_status ON public.rapport_growth_actions_r2542(status);

ALTER TABLE public.rapport_growth_actions_r2542 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.rapport_growth_actions_r2542;
CREATE POLICY founder_all ON public.rapport_growth_actions_r2542
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
  v_rap1 uuid;
  v_rap2 uuid;
  v_rap3 uuid;
  v_rap4 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at ASC OFFSET 2 LIMIT 1;

  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_hosp3 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC OFFSET 2 LIMIT 1;

  IF v_eng1 IS NULL OR v_hosp1 IS NULL THEN
    RETURN;
  END IF;

  v_eng2 := COALESCE(v_eng2, v_eng1);
  v_eng3 := COALESCE(v_eng3, v_eng1);
  v_hosp2 := COALESCE(v_hosp2, v_hosp1);
  v_hosp3 := COALESCE(v_hosp3, v_hosp1);

  INSERT INTO public.engineer_customer_rapport_r2542
    (engineer_user_id, hospital_user_id, rapport_score, small_talk_topics_md, first_name_basis, empathy_moments_count, repeat_customer_rate_pct, last_touch_at, owner_email, status, notes)
  VALUES (v_eng1, v_hosp1, 88, '- Cricket / IPL Hyderabad fan\n- Family: 2 kids in CBSE\n- Mango season talk', true, 14, 92.50, '2026-06-20T10:30:00+05:30'::timestamptz, 'founder@equipseva.com', 'champion', 'Strong rapport, asks for him by name')
  RETURNING id INTO v_rap1;

  INSERT INTO public.engineer_customer_rapport_r2542
    (engineer_user_id, hospital_user_id, rapport_score, small_talk_topics_md, first_name_basis, empathy_moments_count, repeat_customer_rate_pct, last_touch_at, owner_email, status, notes)
  VALUES (v_eng2, v_hosp2, 72, '- Telugu cinema discussions\n- Diabetes self-care tips shared', true, 8, 78.00, '2026-06-18T15:00:00+05:30'::timestamptz, 'founder@equipseva.com', 'strong', 'Good progression last quarter')
  RETURNING id INTO v_rap2;

  INSERT INTO public.engineer_customer_rapport_r2542
    (engineer_user_id, hospital_user_id, rapport_score, small_talk_topics_md, first_name_basis, empathy_moments_count, repeat_customer_rate_pct, last_touch_at, owner_email, status, notes)
  VALUES (v_eng3, v_hosp3, 45, '- Limited - mostly transactional\n- Mentioned son joining MBBS', false, 3, 40.00, '2026-06-15T11:00:00+05:30'::timestamptz, 'founder@equipseva.com', 'building', 'New engineer-hospital pairing')
  RETURNING id INTO v_rap3;

  INSERT INTO public.engineer_customer_rapport_r2542
    (engineer_user_id, hospital_user_id, rapport_score, small_talk_topics_md, first_name_basis, empathy_moments_count, repeat_customer_rate_pct, last_touch_at, owner_email, status, notes)
  VALUES (v_eng1, v_hosp2, 30, '- Strained after Mar incident\n- Trust rebuild in progress', false, 2, 22.50, '2026-06-10T09:00:00+05:30'::timestamptz, 'founder@equipseva.com', 'strained', 'Recovery plan in motion')
  RETURNING id INTO v_rap4;

  INSERT INTO public.rapport_growth_actions_r2542
    (rapport_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (v_rap1, '2026-06-19T10:00:00+05:30'::timestamptz, 'remember_birthday', 'positive', 'founder@equipseva.com', 'done', 'Hospital admin birthday card delivered');

  INSERT INTO public.rapport_growth_actions_r2542
    (rapport_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (v_rap1, '2026-06-22T13:00:00+05:30'::timestamptz, 'site_lunch', 'positive', 'founder@equipseva.com', 'done', 'Lunch at site after preventive maintenance');

  INSERT INTO public.rapport_growth_actions_r2542
    (rapport_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (v_rap2, '2026-06-21T11:00:00+05:30'::timestamptz, 'follow_up_call', 'positive', 'founder@equipseva.com', 'done', 'Post-service satisfaction check call');

  INSERT INTO public.rapport_growth_actions_r2542
    (rapport_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (v_rap3, '2026-06-24T10:00:00+05:30'::timestamptz, 'inquire_family', 'pending', 'founder@equipseva.com', 'planned', 'Ask about son MBBS admission progress');

  INSERT INTO public.rapport_growth_actions_r2542
    (rapport_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (v_rap4, '2026-06-25T14:00:00+05:30'::timestamptz, 'handwritten_note', 'pending', 'founder@equipseva.com', 'planned', 'Apology and recommitment note');
END;
$seed$;

-- ============================================================================
-- RPC: list_rapport_r2542
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_rapport_r2542()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  rapport_score int,
  small_talk_topics_md text,
  first_name_basis boolean,
  empathy_moments_count int,
  repeat_customer_rate_pct numeric,
  last_touch_at timestamptz,
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
  SELECT r.id, r.engineer_user_id, r.hospital_user_id, r.rapport_score, r.small_talk_topics_md,
         r.first_name_basis, r.empathy_moments_count, r.repeat_customer_rate_pct, r.last_touch_at,
         r.owner_email, r.status, r.notes, r.created_at
  FROM public.engineer_customer_rapport_r2542 r
  ORDER BY r.rapport_score DESC, r.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_rapport_r2542() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_rapport_r2542() TO authenticated;

-- ============================================================================
-- RPC: list_growth_actions_r2542
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_growth_actions_r2542()
RETURNS TABLE (
  id uuid,
  rapport_id uuid,
  action_at timestamptz,
  action_kind text,
  outcome text,
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
  SELECT a.id, a.rapport_id, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes, a.created_at
  FROM public.rapport_growth_actions_r2542 a
  ORDER BY a.action_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_growth_actions_r2542() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_growth_actions_r2542() TO authenticated;

-- ============================================================================
-- RPC: top_rapport_engineers_r2542
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_rapport_engineers_r2542()
RETURNS TABLE (
  engineer_user_id uuid,
  hospitals_covered bigint,
  avg_rapport_score numeric,
  total_empathy_moments bigint,
  avg_repeat_rate_pct numeric,
  champion_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_user_id,
         count(DISTINCT r.hospital_user_id)::bigint AS hospitals_covered,
         round(avg(r.rapport_score)::numeric, 2) AS avg_rapport_score,
         sum(r.empathy_moments_count)::bigint AS total_empathy_moments,
         round(avg(r.repeat_customer_rate_pct)::numeric, 2) AS avg_repeat_rate_pct,
         count(*) FILTER (WHERE r.status = 'champion')::bigint AS champion_count
  FROM public.engineer_customer_rapport_r2542 r
  GROUP BY r.engineer_user_id
  ORDER BY avg_rapport_score DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_rapport_engineers_r2542() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_rapport_engineers_r2542() TO authenticated;

-- ============================================================================
-- RPC: action_kind_summary_r2542
-- ============================================================================
CREATE OR REPLACE FUNCTION public.action_kind_summary_r2542()
RETURNS TABLE (
  action_kind text,
  total_actions bigint,
  positive_outcomes bigint,
  pending_actions bigint,
  positive_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         count(*)::bigint AS total_actions,
         count(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_outcomes,
         count(*) FILTER (WHERE a.outcome = 'pending')::bigint AS pending_actions,
         round(100.0 * count(*) FILTER (WHERE a.outcome = 'positive') / NULLIF(count(*), 0), 2) AS positive_rate_pct
  FROM public.rapport_growth_actions_r2542 a
  GROUP BY a.action_kind
  ORDER BY total_actions DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_summary_r2542() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_summary_r2542() TO authenticated;

-- ============================================================================
-- RPC: status_distribution_r2542
-- ============================================================================
CREATE OR REPLACE FUNCTION public.status_distribution_r2542()
RETURNS TABLE (
  status text,
  rapport_count bigint,
  avg_score numeric,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH t AS (SELECT count(*)::numeric AS tot FROM public.engineer_customer_rapport_r2542)
  SELECT r.status,
         count(*)::bigint AS rapport_count,
         round(avg(r.rapport_score)::numeric, 2) AS avg_score,
         round(100.0 * count(*) / NULLIF((SELECT tot FROM t), 0), 2) AS pct_of_total
  FROM public.engineer_customer_rapport_r2542 r
  GROUP BY r.status
  ORDER BY rapport_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_distribution_r2542() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_distribution_r2542() TO authenticated;

-- ============================================================================
-- RPC: monthly_rapport_trend_r2542
-- ============================================================================
CREATE OR REPLACE FUNCTION public.monthly_rapport_trend_r2542()
RETURNS TABLE (
  month_label text,
  rapport_added bigint,
  actions_taken bigint,
  positive_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH r AS (
    SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS m, count(*)::bigint AS rcount
    FROM public.engineer_customer_rapport_r2542
    GROUP BY 1
  ),
  a AS (
    SELECT to_char(date_trunc('month', action_at), 'YYYY-MM') AS m,
           count(*)::bigint AS acount,
           count(*) FILTER (WHERE outcome = 'positive')::bigint AS pos
    FROM public.rapport_growth_actions_r2542
    GROUP BY 1
  )
  SELECT COALESCE(r.m, a.m) AS month_label,
         COALESCE(r.rcount, 0) AS rapport_added,
         COALESCE(a.acount, 0) AS actions_taken,
         COALESCE(a.pos, 0) AS positive_actions
  FROM r FULL OUTER JOIN a ON r.m = a.m
  ORDER BY month_label;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_rapport_trend_r2542() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_rapport_trend_r2542() TO authenticated;

-- ============================================================================
-- RPC: top_hospitals_by_rapport_r2542
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_hospitals_by_rapport_r2542()
RETURNS TABLE (
  hospital_user_id uuid,
  engineers_assigned bigint,
  avg_rapport_score numeric,
  avg_repeat_rate_pct numeric,
  first_name_basis_count bigint,
  total_empathy_moments bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.hospital_user_id,
         count(DISTINCT r.engineer_user_id)::bigint AS engineers_assigned,
         round(avg(r.rapport_score)::numeric, 2) AS avg_rapport_score,
         round(avg(r.repeat_customer_rate_pct)::numeric, 2) AS avg_repeat_rate_pct,
         count(*) FILTER (WHERE r.first_name_basis IS TRUE)::bigint AS first_name_basis_count,
         sum(r.empathy_moments_count)::bigint AS total_empathy_moments
  FROM public.engineer_customer_rapport_r2542 r
  GROUP BY r.hospital_user_id
  ORDER BY avg_rapport_score DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_rapport_r2542() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_rapport_r2542() TO authenticated;

