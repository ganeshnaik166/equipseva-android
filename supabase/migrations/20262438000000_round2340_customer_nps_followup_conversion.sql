BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_nps_followup_conversion_r2340 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  initial_score int NOT NULL CHECK (initial_score BETWEEN 0 AND 10),
  initial_survey_at timestamptz NOT NULL DEFAULT now(),
  initial_reason text,
  intervention_type text NOT NULL CHECK (intervention_type IN ('founder_call','engineer_revisit','refund','credit_note','escalation','free_amc_month','spare_part_replacement','sla_compensation')),
  intervention_owner_email text,
  intervention_at timestamptz,
  intervention_notes text,
  followup_score int CHECK (followup_score BETWEEN 0 AND 10),
  followup_survey_at timestamptz,
  followup_reason text,
  converted_to_promoter boolean NOT NULL DEFAULT false,
  days_to_followup int,
  cost_rupees numeric(12,2) DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','intervened','followup_done','converted','lost')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_npsfu_r2340_status ON public.customer_nps_followup_conversion_r2340(status);
CREATE INDEX IF NOT EXISTS idx_npsfu_r2340_intervention ON public.customer_nps_followup_conversion_r2340(intervention_type);
CREATE INDEX IF NOT EXISTS idx_npsfu_r2340_converted ON public.customer_nps_followup_conversion_r2340(converted_to_promoter);
CREATE INDEX IF NOT EXISTS idx_npsfu_r2340_customer ON public.customer_nps_followup_conversion_r2340(customer_user_id);

ALTER TABLE public.customer_nps_followup_conversion_r2340 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS npsfu_r2340_founder_all ON public.customer_nps_followup_conversion_r2340;
CREATE POLICY npsfu_r2340_founder_all ON public.customer_nps_followup_conversion_r2340
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_nps_intervention_playbook_r2340 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intervention_type text NOT NULL UNIQUE,
  playbook_label text NOT NULL,
  description text,
  recommended_sla_hours int NOT NULL DEFAULT 48,
  avg_cost_rupees numeric(12,2) DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_nps_intervention_playbook_r2340 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS npsfu_pb_r2340_founder_all ON public.customer_nps_intervention_playbook_r2340;
CREATE POLICY npsfu_pb_r2340_founder_all ON public.customer_nps_intervention_playbook_r2340
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

INSERT INTO public.customer_nps_intervention_playbook_r2340 (intervention_type, playbook_label, description, recommended_sla_hours, avg_cost_rupees)
VALUES
  ('founder_call','Founder personal call','CEO calls detractor within 24h to listen + commit fix',24,0),
  ('engineer_revisit','Senior engineer revisit','Top-tier engineer redoes job at no charge',48,2500),
  ('refund','Refund issued','Full or partial refund of job amount',72,5000),
  ('credit_note','Credit note for next job','Apply credit toward next service call',72,1500),
  ('escalation','Internal escalation','Route to ops head + supplier + manufacturer',24,0),
  ('free_amc_month','Free AMC month','Comp one month of AMC contract',48,2000),
  ('spare_part_replacement','Spare part replacement','Replace faulty part at no cost',96,8000),
  ('sla_compensation','SLA breach compensation','Pay SLA penalty per contract',48,3000)
ON CONFLICT (intervention_type) DO NOTHING;

CREATE OR REPLACE FUNCTION public.npsfu_r2340_summary()
RETURNS TABLE(
  total_detractors int,
  intervened int,
  followup_done int,
  converted int,
  conversion_rate numeric,
  avg_days_to_followup numeric,
  total_cost_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status IN ('intervened','followup_done','converted','lost'))::int,
    COUNT(*) FILTER (WHERE status IN ('followup_done','converted','lost'))::int,
    COUNT(*) FILTER (WHERE converted_to_promoter)::int,
    CASE WHEN COUNT(*) FILTER (WHERE status IN ('followup_done','converted','lost')) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE converted_to_promoter)::numeric
              / NULLIF(COUNT(*) FILTER (WHERE status IN ('followup_done','converted','lost')),0), 2)
    END,
    ROUND(AVG(days_to_followup) FILTER (WHERE days_to_followup IS NOT NULL), 1),
    COALESCE(SUM(cost_rupees), 0)
  FROM public.customer_nps_followup_conversion_r2340;
END;
$$;

CREATE OR REPLACE FUNCTION public.npsfu_r2340_by_intervention()
RETURNS TABLE(
  intervention_type text,
  playbook_label text,
  attempts int,
  converted int,
  conversion_rate numeric,
  avg_cost_rupees numeric,
  avg_days_to_followup numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.intervention_type,
    COALESCE(p.playbook_label, f.intervention_type),
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE f.converted_to_promoter)::int,
    CASE WHEN COUNT(*) FILTER (WHERE f.status IN ('followup_done','converted','lost')) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE f.converted_to_promoter)::numeric
              / NULLIF(COUNT(*) FILTER (WHERE f.status IN ('followup_done','converted','lost')),0), 2)
    END,
    ROUND(AVG(f.cost_rupees), 0),
    ROUND(AVG(f.days_to_followup) FILTER (WHERE f.days_to_followup IS NOT NULL), 1)
  FROM public.customer_nps_followup_conversion_r2340 f
  LEFT JOIN public.customer_nps_intervention_playbook_r2340 p USING (intervention_type)
  GROUP BY f.intervention_type, p.playbook_label
  ORDER BY COUNT(*) FILTER (WHERE f.converted_to_promoter) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.npsfu_r2340_recent()
RETURNS TABLE(
  id uuid,
  customer_email text,
  initial_score int,
  initial_reason text,
  intervention_type text,
  intervention_owner_email text,
  followup_score int,
  converted_to_promoter boolean,
  days_to_followup int,
  cost_rupees numeric,
  status text,
  intervention_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    p.email,
    f.initial_score,
    f.initial_reason,
    f.intervention_type,
    f.intervention_owner_email,
    f.followup_score,
    f.converted_to_promoter,
    f.days_to_followup,
    f.cost_rupees,
    f.status,
    f.intervention_at
  FROM public.customer_nps_followup_conversion_r2340 f
  LEFT JOIN public.profiles p ON p.id = f.customer_user_id
  ORDER BY f.created_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.npsfu_r2340_winners()
RETURNS TABLE(
  intervention_type text,
  playbook_label text,
  converted int,
  conversion_rate numeric,
  cost_per_conversion numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.intervention_type,
    COALESCE(p.playbook_label, f.intervention_type),
    COUNT(*) FILTER (WHERE f.converted_to_promoter)::int,
    CASE WHEN COUNT(*) FILTER (WHERE f.status IN ('followup_done','converted','lost')) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE f.converted_to_promoter)::numeric
              / NULLIF(COUNT(*) FILTER (WHERE f.status IN ('followup_done','converted','lost')),0), 2)
    END,
    CASE WHEN COUNT(*) FILTER (WHERE f.converted_to_promoter) = 0 THEN 0
         ELSE ROUND(SUM(f.cost_rupees)::numeric / NULLIF(COUNT(*) FILTER (WHERE f.converted_to_promoter),0), 0)
    END
  FROM public.customer_nps_followup_conversion_r2340 f
  LEFT JOIN public.customer_nps_intervention_playbook_r2340 p USING (intervention_type)
  GROUP BY f.intervention_type, p.playbook_label
  HAVING COUNT(*) FILTER (WHERE f.converted_to_promoter) > 0
  ORDER BY (COUNT(*) FILTER (WHERE f.converted_to_promoter))::numeric
           / NULLIF(COUNT(*) FILTER (WHERE f.status IN ('followup_done','converted','lost')),0) DESC NULLS LAST
  LIMIT 5;
END;
$$;

CREATE OR REPLACE FUNCTION public.npsfu_r2340_score_lift()
RETURNS TABLE(
  bucket text,
  cases int,
  avg_initial numeric,
  avg_followup numeric,
  avg_lift numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN f.initial_score <= 2 THEN 'severe_detractor_0_2'
      WHEN f.initial_score <= 4 THEN 'detractor_3_4'
      WHEN f.initial_score <= 6 THEN 'detractor_5_6'
      ELSE 'other'
    END,
    COUNT(*)::int,
    ROUND(AVG(f.initial_score)::numeric, 2),
    ROUND(AVG(f.followup_score) FILTER (WHERE f.followup_score IS NOT NULL)::numeric, 2),
    ROUND(AVG(f.followup_score - f.initial_score) FILTER (WHERE f.followup_score IS NOT NULL)::numeric, 2)
  FROM public.customer_nps_followup_conversion_r2340 f
  WHERE f.initial_score <= 6
  GROUP BY 1
  ORDER BY 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.npsfu_r2340_pending()
RETURNS TABLE(
  id uuid,
  customer_email text,
  initial_score int,
  initial_reason text,
  initial_survey_at timestamptz,
  days_open int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    p.email,
    f.initial_score,
    f.initial_reason,
    f.initial_survey_at,
    EXTRACT(DAY FROM (now() - f.initial_survey_at))::int
  FROM public.customer_nps_followup_conversion_r2340 f
  LEFT JOIN public.profiles p ON p.id = f.customer_user_id
  WHERE f.status = 'open'
  ORDER BY f.initial_survey_at ASC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.npsfu_r2340_playbook()
RETURNS TABLE(
  intervention_type text,
  playbook_label text,
  description text,
  recommended_sla_hours int,
  avg_cost_rupees numeric,
  is_active boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.intervention_type, p.playbook_label, p.description,
    p.recommended_sla_hours, p.avg_cost_rupees, p.is_active
  FROM public.customer_nps_intervention_playbook_r2340 p
  ORDER BY p.is_active DESC, p.playbook_label ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.npsfu_r2340_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.npsfu_r2340_by_intervention() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.npsfu_r2340_recent() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.npsfu_r2340_winners() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.npsfu_r2340_score_lift() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.npsfu_r2340_pending() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.npsfu_r2340_playbook() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.npsfu_r2340_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.npsfu_r2340_by_intervention() TO authenticated;
GRANT EXECUTE ON FUNCTION public.npsfu_r2340_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.npsfu_r2340_winners() TO authenticated;
GRANT EXECUTE ON FUNCTION public.npsfu_r2340_score_lift() TO authenticated;
GRANT EXECUTE ON FUNCTION public.npsfu_r2340_pending() TO authenticated;
GRANT EXECUTE ON FUNCTION public.npsfu_r2340_playbook() TO authenticated;

COMMIT;
