-- Round 2658: Engineer Customer Mood Pulse Detector
-- Track engineer-facing customer mood signals plus intervention actions to recover concerned accounts.

BEGIN;

-- =========================================================================
-- TABLE 1: engineer_customer_mood_r2658
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_customer_mood_r2658 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  detected_at timestamptz NOT NULL DEFAULT now(),
  mood_kind text NOT NULL CHECK (mood_kind IN ('delighted','satisfied','neutral','concerned','angry')),
  signal_kind text NOT NULL CHECK (signal_kind IN ('verbal','email_tone','csat_drop','escalation','silence')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','intervened','recovered','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecm_r2658_engineer ON public.engineer_customer_mood_r2658(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecm_r2658_hospital ON public.engineer_customer_mood_r2658(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_ecm_r2658_detected_at ON public.engineer_customer_mood_r2658(detected_at);
CREATE INDEX IF NOT EXISTS idx_ecm_r2658_mood ON public.engineer_customer_mood_r2658(mood_kind);
CREATE INDEX IF NOT EXISTS idx_ecm_r2658_status ON public.engineer_customer_mood_r2658(status);

ALTER TABLE public.engineer_customer_mood_r2658 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_customer_mood_r2658;
CREATE POLICY founder_all ON public.engineer_customer_mood_r2658
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- TABLE 2: mood_intervention_actions_r2658
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.mood_intervention_actions_r2658 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mood_id uuid NOT NULL REFERENCES public.engineer_customer_mood_r2658(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('check_in_call','visit','apology','discount','exec_meet')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mia_r2658_mood ON public.mood_intervention_actions_r2658(mood_id);
CREATE INDEX IF NOT EXISTS idx_mia_r2658_action_at ON public.mood_intervention_actions_r2658(action_at);
CREATE INDEX IF NOT EXISTS idx_mia_r2658_status ON public.mood_intervention_actions_r2658(status);

ALTER TABLE public.mood_intervention_actions_r2658 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.mood_intervention_actions_r2658;
CREATE POLICY founder_all ON public.mood_intervention_actions_r2658
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_moods_r2658
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_moods_r2658();
CREATE OR REPLACE FUNCTION public.list_moods_r2658()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  detected_at timestamptz,
  mood_kind text,
  signal_kind text,
  severity text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.engineer_user_id, m.hospital_user_id, m.detected_at,
           m.mood_kind, m.signal_kind, m.severity, m.owner_email, m.status, m.notes
    FROM public.engineer_customer_mood_r2658 m
    ORDER BY m.detected_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_moods_r2658() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_moods_r2658() TO authenticated;

-- =========================================================================
-- RPC 2: list_intervention_actions_r2658
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_intervention_actions_r2658();
CREATE OR REPLACE FUNCTION public.list_intervention_actions_r2658()
RETURNS TABLE (
  id uuid,
  mood_id uuid,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.mood_id, a.action_at, a.action_kind, a.outcome,
           a.owner_email, a.status, a.notes
    FROM public.mood_intervention_actions_r2658 a
    ORDER BY a.action_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_intervention_actions_r2658() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_intervention_actions_r2658() TO authenticated;

-- =========================================================================
-- RPC 3: top_concerned_focus_r2658
-- =========================================================================
DROP FUNCTION IF EXISTS public.top_concerned_focus_r2658();
CREATE OR REPLACE FUNCTION public.top_concerned_focus_r2658()
RETURNS TABLE (
  hospital_user_id uuid,
  concerned_count bigint,
  latest_detected timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.hospital_user_id,
           COUNT(*)::bigint AS concerned_count,
           MAX(m.detected_at) AS latest_detected
    FROM public.engineer_customer_mood_r2658 m
    WHERE m.mood_kind IN ('concerned','angry')
    GROUP BY m.hospital_user_id
    ORDER BY concerned_count DESC, latest_detected DESC
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_concerned_focus_r2658() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_concerned_focus_r2658() TO authenticated;

-- =========================================================================
-- RPC 4: mood_distribution_r2658
-- =========================================================================
DROP FUNCTION IF EXISTS public.mood_distribution_r2658();
CREATE OR REPLACE FUNCTION public.mood_distribution_r2658()
RETURNS TABLE (
  mood_kind text,
  total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.mood_kind, COUNT(*)::bigint AS total
    FROM public.engineer_customer_mood_r2658 m
    GROUP BY m.mood_kind
    ORDER BY total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mood_distribution_r2658() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mood_distribution_r2658() TO authenticated;

-- =========================================================================
-- RPC 5: status_funnel_r2658
-- =========================================================================
DROP FUNCTION IF EXISTS public.status_funnel_r2658();
CREATE OR REPLACE FUNCTION public.status_funnel_r2658()
RETURNS TABLE (
  status text,
  total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.status, COUNT(*)::bigint AS total
    FROM public.engineer_customer_mood_r2658 m
    GROUP BY m.status
    ORDER BY total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2658() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2658() TO authenticated;

-- =========================================================================
-- RPC 6: monthly_mood_trend_r2658
-- =========================================================================
DROP FUNCTION IF EXISTS public.monthly_mood_trend_r2658();
CREATE OR REPLACE FUNCTION public.monthly_mood_trend_r2658()
RETURNS TABLE (
  month_start timestamptz,
  delighted bigint,
  satisfied bigint,
  neutral bigint,
  concerned bigint,
  angry bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', m.detected_at) AS month_start,
           COUNT(*) FILTER (WHERE m.mood_kind = 'delighted')::bigint AS delighted,
           COUNT(*) FILTER (WHERE m.mood_kind = 'satisfied')::bigint AS satisfied,
           COUNT(*) FILTER (WHERE m.mood_kind = 'neutral')::bigint AS neutral,
           COUNT(*) FILTER (WHERE m.mood_kind = 'concerned')::bigint AS concerned,
           COUNT(*) FILTER (WHERE m.mood_kind = 'angry')::bigint AS angry
    FROM public.engineer_customer_mood_r2658 m
    GROUP BY month_start
    ORDER BY month_start DESC
    LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_mood_trend_r2658() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_mood_trend_r2658() TO authenticated;

-- =========================================================================
-- RPC 7: owner_load_r2658
-- =========================================================================
DROP FUNCTION IF EXISTS public.owner_load_r2658();
CREATE OR REPLACE FUNCTION public.owner_load_r2658()
RETURNS TABLE (
  owner_email text,
  open_moods bigint,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(m.owner_email, 'unassigned') AS owner_email,
           COUNT(*) FILTER (WHERE m.status IN ('monitoring','intervened'))::bigint AS open_moods,
           COALESCE((SELECT COUNT(*)::bigint
                     FROM public.mood_intervention_actions_r2658 a
                     WHERE a.owner_email = m.owner_email
                       AND a.status = 'open'), 0) AS open_actions
    FROM public.engineer_customer_mood_r2658 m
    GROUP BY m.owner_email
    ORDER BY open_moods DESC, open_actions DESC
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2658() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2658() TO authenticated;

-- =========================================================================
-- SEED DATA
-- =========================================================================
DO $$
DECLARE
  v_eng_a uuid;
  v_eng_b uuid;
  v_hos_a uuid;
  v_hos_b uuid;
  v_hos_c uuid;
  v_mood_1 uuid;
  v_mood_2 uuid;
  v_mood_3 uuid;
BEGIN
  SELECT id INTO v_eng_a FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng_b FROM public.engineers ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_hos_a FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hos_b FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_hos_c FROM public.profiles WHERE role = 'hospital_admin' OFFSET 1 LIMIT 1;

  IF v_eng_a IS NOT NULL AND v_hos_a IS NOT NULL THEN
    INSERT INTO public.engineer_customer_mood_r2658
      (engineer_user_id, hospital_user_id, detected_at, mood_kind, signal_kind, severity, owner_email, status, notes)
    VALUES
      (v_eng_a, v_hos_a, '2026-06-18 10:00:00+05:30'::timestamptz, 'concerned', 'csat_drop', 'high', 'cx@equipseva.in', 'monitoring', 'CSAT dropped two points after delayed visit')
    RETURNING id INTO v_mood_1;

    INSERT INTO public.engineer_customer_mood_r2658
      (engineer_user_id, hospital_user_id, detected_at, mood_kind, signal_kind, severity, owner_email, status, notes)
    VALUES
      (COALESCE(v_eng_b, v_eng_a), COALESCE(v_hos_b, v_hos_a), '2026-06-20 14:30:00+05:30'::timestamptz, 'angry', 'escalation', 'critical', 'founder@equipseva.in', 'intervened', 'Escalated to founder line over repeated downtime')
    RETURNING id INTO v_mood_2;

    INSERT INTO public.engineer_customer_mood_r2658
      (engineer_user_id, hospital_user_id, detected_at, mood_kind, signal_kind, severity, owner_email, status, notes)
    VALUES
      (v_eng_a, COALESCE(v_hos_c, v_hos_a), '2026-06-22 09:15:00+05:30'::timestamptz, 'delighted', 'verbal', 'low', 'cx@equipseva.in', 'monitoring', 'Verbal praise after rapid SLA recovery')
    RETURNING id INTO v_mood_3;

    INSERT INTO public.mood_intervention_actions_r2658
      (mood_id, action_at, action_kind, outcome, owner_email, status, notes)
    VALUES
      (v_mood_1, '2026-06-19 11:00:00+05:30'::timestamptz, 'check_in_call', 'neutral', 'cx@equipseva.in', 'done', 'Call placed, hospital still cautious'),
      (v_mood_2, '2026-06-20 18:00:00+05:30'::timestamptz, 'exec_meet', 'positive', 'founder@equipseva.in', 'done', 'Founder visit; goodwill credit offered'),
      (v_mood_3, '2026-06-23 12:00:00+05:30'::timestamptz, 'visit', 'positive', 'cx@equipseva.in', 'open', 'Schedule onsite thank-you visit');
  END IF;
END $$;

COMMIT;
