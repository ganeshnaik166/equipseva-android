-- Round 2638: Engineer Customer Care Package Program
-- Tracks care packages engineers send to hospital customers + structured follow-up actions

-- =========================================================
-- Table 1: engineer_care_packages_r2638
-- =========================================================
CREATE TABLE IF NOT EXISTS public.engineer_care_packages_r2638 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sent_at timestamptz NOT NULL DEFAULT now(),
  package_kind text NOT NULL CHECK (package_kind IN ('festival_kit','health_kit','holiday_gift','anniversary','new_baby')),
  value_rupees int NOT NULL DEFAULT 0,
  received_signoff boolean NOT NULL DEFAULT false,
  customer_reaction_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','shipped','delivered','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_care_packages_r2638 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_care_packages_r2638;
CREATE POLICY founder_all ON public.engineer_care_packages_r2638
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================
-- Table 2: care_package_followup_actions_r2638
-- =========================================================
CREATE TABLE IF NOT EXISTS public.care_package_followup_actions_r2638 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id uuid NOT NULL REFERENCES public.engineer_care_packages_r2638(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('thank_you_call','site_visit','referral_ask','loyalty_program')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.care_package_followup_actions_r2638 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.care_package_followup_actions_r2638;
CREATE POLICY founder_all ON public.care_package_followup_actions_r2638
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================
-- Seed data
-- =========================================================
DO $seed$
DECLARE
  v_eng_a uuid;
  v_eng_b uuid;
  v_hosp_a uuid;
  v_hosp_b uuid;
  v_pkg_1 uuid;
  v_pkg_2 uuid;
  v_pkg_3 uuid;
  v_pkg_4 uuid;
BEGIN
  SELECT id INTO v_eng_a FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng_b FROM public.engineers ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_hosp_a FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp_b FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;

  IF v_eng_a IS NULL OR v_hosp_a IS NULL THEN
    RETURN;
  END IF;

  IF v_eng_b IS NULL THEN v_eng_b := v_eng_a; END IF;
  IF v_hosp_b IS NULL THEN v_hosp_b := v_hosp_a; END IF;

  INSERT INTO public.engineer_care_packages_r2638
    (engineer_user_id, hospital_user_id, sent_at, package_kind, value_rupees, received_signoff, customer_reaction_md, owner_email, status, notes)
  VALUES
    (v_eng_a, v_hosp_a, (now() - interval '20 days')::timestamptz, 'festival_kit', 2500, true,
     'Hospital staff loved the diwali sweets and lamps', 'cx@equipseva.in', 'delivered',
     'Diwali festival kit dispatched on schedule')
  RETURNING id INTO v_pkg_1;

  INSERT INTO public.engineer_care_packages_r2638
    (engineer_user_id, hospital_user_id, sent_at, package_kind, value_rupees, received_signoff, customer_reaction_md, owner_email, status, notes)
  VALUES
    (v_eng_b, v_hosp_b, (now() - interval '12 days')::timestamptz, 'health_kit', 1800, true,
     'Front desk team enjoyed wellness items', 'ops@equipseva.in', 'delivered',
     'Health kit included vitamin pack and tea sampler')
  RETURNING id INTO v_pkg_2;

  INSERT INTO public.engineer_care_packages_r2638
    (engineer_user_id, hospital_user_id, sent_at, package_kind, value_rupees, received_signoff, customer_reaction_md, owner_email, status, notes)
  VALUES
    (v_eng_a, v_hosp_b, (now() - interval '6 days')::timestamptz, 'anniversary', 3500, false,
     NULL, 'cx@equipseva.in', 'shipped',
     'Two year service anniversary marker')
  RETURNING id INTO v_pkg_3;

  INSERT INTO public.engineer_care_packages_r2638
    (engineer_user_id, hospital_user_id, sent_at, package_kind, value_rupees, received_signoff, customer_reaction_md, owner_email, status, notes)
  VALUES
    (v_eng_b, v_hosp_a, (now() - interval '2 days')::timestamptz, 'new_baby', 1200, false,
     NULL, 'cx@equipseva.in', 'planned',
     'Lead biomed staff welcomed newborn last week')
  RETURNING id INTO v_pkg_4;

  INSERT INTO public.care_package_followup_actions_r2638
    (package_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES
    (v_pkg_1, (now() - interval '18 days')::timestamptz, 'thank_you_call', 'positive', 'cx@equipseva.in', 'done',
     'Founder called and got warm reception'),
    (v_pkg_2, (now() - interval '10 days')::timestamptz, 'site_visit', 'positive', 'ops@equipseva.in', 'done',
     'Coffee and tour with biomed lead'),
    (v_pkg_2, (now() - interval '8 days')::timestamptz, 'referral_ask', 'neutral', 'sales@equipseva.in', 'open',
     'Asked for intro to sister hospital'),
    (v_pkg_3, (now() - interval '4 days')::timestamptz, 'loyalty_program', 'pending', 'cx@equipseva.in', 'open',
     'Pitched gold tier loyalty enrolment');
END
$seed$;

-- =========================================================
-- RPC 1: list_care_packages_r2638
-- =========================================================
CREATE OR REPLACE FUNCTION public.list_care_packages_r2638()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  sent_at timestamptz,
  package_kind text,
  value_rupees int,
  received_signoff boolean,
  customer_reaction_md text,
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
  SELECT p.id, p.engineer_user_id, p.hospital_user_id, p.sent_at, p.package_kind, p.value_rupees,
         p.received_signoff, p.customer_reaction_md, p.owner_email, p.status, p.notes, p.created_at
  FROM public.engineer_care_packages_r2638 p
  ORDER BY p.sent_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_care_packages_r2638() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_care_packages_r2638() TO authenticated;

-- =========================================================
-- RPC 2: list_followup_actions_r2638
-- =========================================================
CREATE OR REPLACE FUNCTION public.list_followup_actions_r2638()
RETURNS TABLE (
  id uuid,
  package_id uuid,
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
  SELECT a.id, a.package_id, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes, a.created_at
  FROM public.care_package_followup_actions_r2638 a
  ORDER BY a.action_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_followup_actions_r2638() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followup_actions_r2638() TO authenticated;

-- =========================================================
-- RPC 3: top_value_focus_r2638
-- =========================================================
CREATE OR REPLACE FUNCTION public.top_value_focus_r2638()
RETURNS TABLE (
  hospital_user_id uuid,
  packages bigint,
  total_value_rupees bigint,
  avg_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.hospital_user_id,
         COUNT(*)::bigint AS packages,
         COALESCE(SUM(p.value_rupees),0)::bigint AS total_value_rupees,
         ROUND(AVG(p.value_rupees)::numeric, 2) AS avg_value_rupees
  FROM public.engineer_care_packages_r2638 p
  GROUP BY p.hospital_user_id
  ORDER BY total_value_rupees DESC, packages DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_value_focus_r2638() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_focus_r2638() TO authenticated;

-- =========================================================
-- RPC 4: package_kind_distribution_r2638
-- =========================================================
CREATE OR REPLACE FUNCTION public.package_kind_distribution_r2638()
RETURNS TABLE (
  package_kind text,
  packages bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.package_kind,
         COUNT(*)::bigint AS packages,
         COALESCE(SUM(p.value_rupees),0)::bigint AS total_value_rupees
  FROM public.engineer_care_packages_r2638 p
  GROUP BY p.package_kind
  ORDER BY packages DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.package_kind_distribution_r2638() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.package_kind_distribution_r2638() TO authenticated;

-- =========================================================
-- RPC 5: status_funnel_r2638
-- =========================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2638()
RETURNS TABLE (
  status text,
  packages bigint,
  signed_off bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.status,
         COUNT(*)::bigint AS packages,
         COUNT(*) FILTER (WHERE p.received_signoff = true)::bigint AS signed_off
  FROM public.engineer_care_packages_r2638 p
  GROUP BY p.status
  ORDER BY packages DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2638() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2638() TO authenticated;

-- =========================================================
-- RPC 6: monthly_package_trend_r2638
-- =========================================================
CREATE OR REPLACE FUNCTION public.monthly_package_trend_r2638()
RETURNS TABLE (
  month_start timestamptz,
  packages bigint,
  total_value_rupees bigint,
  avg_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', p.sent_at) AS month_start,
         COUNT(*)::bigint AS packages,
         COALESCE(SUM(p.value_rupees),0)::bigint AS total_value_rupees,
         ROUND(AVG(p.value_rupees)::numeric, 2) AS avg_value_rupees
  FROM public.engineer_care_packages_r2638 p
  GROUP BY date_trunc('month', p.sent_at)
  ORDER BY month_start DESC
  LIMIT 24;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_package_trend_r2638() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_package_trend_r2638() TO authenticated;

-- =========================================================
-- RPC 7: owner_load_r2638
-- =========================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2638()
RETURNS TABLE (
  owner_email text,
  open_actions bigint,
  done_actions bigint,
  dropped_actions bigint,
  total_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(a.owner_email, 'unassigned') AS owner_email,
         COUNT(*) FILTER (WHERE a.status = 'open')::bigint AS open_actions,
         COUNT(*) FILTER (WHERE a.status = 'done')::bigint AS done_actions,
         COUNT(*) FILTER (WHERE a.status = 'dropped')::bigint AS dropped_actions,
         COUNT(*)::bigint AS total_actions
  FROM public.care_package_followup_actions_r2638 a
  GROUP BY COALESCE(a.owner_email, 'unassigned')
  ORDER BY open_actions DESC, total_actions DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2638() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2638() TO authenticated;
