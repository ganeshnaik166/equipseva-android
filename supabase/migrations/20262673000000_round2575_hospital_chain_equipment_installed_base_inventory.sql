-- Round 2575 — Hospital chain equipment installed-base inventory
-- Founder-only surface tracking chain x equipment x install date x age x value x warranty x upsell pipeline

CREATE TABLE IF NOT EXISTS public.chain_installed_base_r2575 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL,
  install_date date,
  age_years numeric NOT NULL DEFAULT 0,
  value_rupees bigint NOT NULL DEFAULT 0,
  under_warranty boolean NOT NULL DEFAULT false,
  upsell_kind text NOT NULL CHECK (upsell_kind IN ('amc_attach','training','parts_pack','replacement','consumables','none')),
  upsell_pipeline_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL CHECK (status IN ('active','decommissioning','replaced','sold')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.installed_base_upsell_actions_r2575 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  install_id uuid NOT NULL REFERENCES public.chain_installed_base_r2575(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('amc_quote','training_quote','parts_proposal','replacement_quote','refresh_consumables')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_installed_base_r2575 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installed_base_upsell_actions_r2575 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_installed_base_r2575;
CREATE POLICY founder_all ON public.chain_installed_base_r2575
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.installed_base_upsell_actions_r2575;
CREATE POLICY founder_all ON public.installed_base_upsell_actions_r2575
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_installed_base_r2575
  (chain_name, equipment_label, equipment_kind, install_date, age_years, value_rupees, under_warranty, upsell_kind, upsell_pipeline_rupees, owner_email, status, notes)
VALUES
  ('Apollo Chain','CT-Scanner Unit-08','ct_scanner','2022-03-15', 4.3, 12500000, false, 'amc_attach', 480000, 'ops1@equipseva.com', 'active', 'Warranty lapsed — AMC quote pending'),
  ('Fortis Chain','MRI Unit-02','mri','2024-07-10', 1.9, 28000000, true, 'training', 120000, 'ops2@equipseva.com', 'active', 'Radiology team training pitch'),
  ('Manipal Chain','Dental Chair-22','dental_chair','2021-09-01', 4.8, 220000, false, 'replacement', 450000, 'ops1@equipseva.com', 'decommissioning', 'End-of-life, replacement quote in motion'),
  ('Max Chain','Defibrillator-09','defibrillator','2023-01-20', 3.4, 350000, false, 'parts_pack', 65000, 'ops3@equipseva.com', 'active', 'Battery + pads kit'),
  ('Yashoda Chain','Ventilator-17','ventilator','2025-02-12', 1.4, 1800000, true, 'consumables', 90000, 'ops2@equipseva.com', 'active', 'Quarterly consumables refresh');

INSERT INTO public.installed_base_upsell_actions_r2575
  (install_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-10T10:00:00+05:30'::timestamptz,'amc_quote','positive','ops1@equipseva.com','in_progress','Apollo bio-med team aligned'
  FROM public.chain_installed_base_r2575 WHERE equipment_label='CT-Scanner Unit-08' LIMIT 1;

INSERT INTO public.installed_base_upsell_actions_r2575
  (install_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-12T11:00:00+05:30'::timestamptz,'training_quote','neutral','ops2@equipseva.com','open','Fortis evaluating internal trainers'
  FROM public.chain_installed_base_r2575 WHERE equipment_label='MRI Unit-02' LIMIT 1;

INSERT INTO public.installed_base_upsell_actions_r2575
  (install_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-14T15:00:00+05:30'::timestamptz,'replacement_quote','pending','ops1@equipseva.com','in_progress','Manipal CFO review next week'
  FROM public.chain_installed_base_r2575 WHERE equipment_label='Dental Chair-22' LIMIT 1;

INSERT INTO public.installed_base_upsell_actions_r2575
  (install_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-08T09:30:00+05:30'::timestamptz,'parts_proposal','positive','ops3@equipseva.com','done','Max approved parts pack'
  FROM public.chain_installed_base_r2575 WHERE equipment_label='Defibrillator-09' LIMIT 1;

INSERT INTO public.installed_base_upsell_actions_r2575
  (install_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-18T14:00:00+05:30'::timestamptz,'refresh_consumables','positive','ops2@equipseva.com','in_progress','Yashoda quarterly cycle'
  FROM public.chain_installed_base_r2575 WHERE equipment_label='Ventilator-17' LIMIT 1;

INSERT INTO public.installed_base_upsell_actions_r2575
  (install_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id,'2026-05-22T10:00:00+05:30'::timestamptz,'amc_quote','negative','ops1@equipseva.com','dropped','First quote rejected — too high'
  FROM public.chain_installed_base_r2575 WHERE equipment_label='CT-Scanner Unit-08' LIMIT 1;

-- RPCs

DROP FUNCTION IF EXISTS public.list_installed_base_r2575();
CREATE OR REPLACE FUNCTION public.list_installed_base_r2575()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_label text,
  equipment_kind text,
  install_date date,
  age_years numeric,
  value_rupees bigint,
  under_warranty boolean,
  upsell_kind text,
  upsell_pipeline_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.chain_name, b.equipment_label, b.equipment_kind, b.install_date, b.age_years,
           b.value_rupees, b.under_warranty, b.upsell_kind, b.upsell_pipeline_rupees,
           b.owner_email, b.status, b.notes
    FROM public.chain_installed_base_r2575 b
    ORDER BY b.upsell_pipeline_rupees DESC NULLS LAST, b.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_installed_base_r2575() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_installed_base_r2575() TO authenticated;

DROP FUNCTION IF EXISTS public.list_upsell_actions_r2575();
CREATE OR REPLACE FUNCTION public.list_upsell_actions_r2575()
RETURNS TABLE (
  id uuid,
  install_id uuid,
  chain_name text,
  equipment_label text,
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
    SELECT a.id, a.install_id, b.chain_name, b.equipment_label, a.action_at, a.action_kind, a.outcome,
           a.owner_email, a.status, a.notes
    FROM public.installed_base_upsell_actions_r2575 a
    JOIN public.chain_installed_base_r2575 b ON b.id = a.install_id
    ORDER BY a.action_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_upsell_actions_r2575() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_upsell_actions_r2575() TO authenticated;

DROP FUNCTION IF EXISTS public.top_upsell_pipeline_r2575();
CREATE OR REPLACE FUNCTION public.top_upsell_pipeline_r2575()
RETURNS TABLE (
  chain_name text,
  total_pipeline_rupees bigint,
  install_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.chain_name,
           COALESCE(SUM(b.upsell_pipeline_rupees),0)::bigint AS total_pipeline_rupees,
           COUNT(*)::bigint AS install_count
    FROM public.chain_installed_base_r2575 b
    GROUP BY b.chain_name
    ORDER BY total_pipeline_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_upsell_pipeline_r2575() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_upsell_pipeline_r2575() TO authenticated;

DROP FUNCTION IF EXISTS public.equipment_kind_breakdown_r2575();
CREATE OR REPLACE FUNCTION public.equipment_kind_breakdown_r2575()
RETURNS TABLE (
  equipment_kind text,
  install_count bigint,
  total_value_rupees bigint,
  total_pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.equipment_kind,
           COUNT(*)::bigint AS install_count,
           COALESCE(SUM(b.value_rupees),0)::bigint AS total_value_rupees,
           COALESCE(SUM(b.upsell_pipeline_rupees),0)::bigint AS total_pipeline_rupees
    FROM public.chain_installed_base_r2575 b
    GROUP BY b.equipment_kind
    ORDER BY install_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_breakdown_r2575() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_breakdown_r2575() TO authenticated;

DROP FUNCTION IF EXISTS public.under_warranty_summary_r2575();
CREATE OR REPLACE FUNCTION public.under_warranty_summary_r2575()
RETURNS TABLE (
  warranty_state text,
  install_count bigint,
  total_value_rupees bigint,
  total_pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT CASE WHEN b.under_warranty THEN 'under_warranty' ELSE 'out_of_warranty' END AS warranty_state,
           COUNT(*)::bigint AS install_count,
           COALESCE(SUM(b.value_rupees),0)::bigint AS total_value_rupees,
           COALESCE(SUM(b.upsell_pipeline_rupees),0)::bigint AS total_pipeline_rupees
    FROM public.chain_installed_base_r2575 b
    GROUP BY 1
    ORDER BY install_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.under_warranty_summary_r2575() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.under_warranty_summary_r2575() TO authenticated;

DROP FUNCTION IF EXISTS public.monthly_action_trend_r2575();
CREATE OR REPLACE FUNCTION public.monthly_action_trend_r2575()
RETURNS TABLE (
  month_label text,
  action_count bigint,
  positive_count bigint,
  negative_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', a.action_at),'YYYY-MM') AS month_label,
           COUNT(*)::bigint AS action_count,
           COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_count,
           COUNT(*) FILTER (WHERE a.outcome = 'negative')::bigint AS negative_count
    FROM public.installed_base_upsell_actions_r2575 a
    GROUP BY 1
    ORDER BY month_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_action_trend_r2575() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_action_trend_r2575() TO authenticated;

DROP FUNCTION IF EXISTS public.age_distribution_r2575();
CREATE OR REPLACE FUNCTION public.age_distribution_r2575()
RETURNS TABLE (
  age_bucket text,
  install_count bigint,
  total_value_rupees bigint,
  total_pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT CASE
             WHEN b.age_years < 2 THEN '0-2y'
             WHEN b.age_years < 4 THEN '2-4y'
             WHEN b.age_years < 6 THEN '4-6y'
             ELSE '6y+'
           END AS age_bucket,
           COUNT(*)::bigint AS install_count,
           COALESCE(SUM(b.value_rupees),0)::bigint AS total_value_rupees,
           COALESCE(SUM(b.upsell_pipeline_rupees),0)::bigint AS total_pipeline_rupees
    FROM public.chain_installed_base_r2575 b
    GROUP BY 1
    ORDER BY age_bucket ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.age_distribution_r2575() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.age_distribution_r2575() TO authenticated;
