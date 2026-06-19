BEGIN;
-- r1356 — founder_partnerships_tracker
-- Strategic partnerships + JVs + integrations registry with activity log



CREATE TABLE IF NOT EXISTS public.founder_partnerships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_name text NOT NULL UNIQUE,
  partner_kind text CHECK (partner_kind IN (
    'oem_supplier','hospital_chain_strategic','technology_integration',
    'distribution_channel','training_institute','government',
    'industry_association','jv_partner','reseller'
  )),
  partnership_status text DEFAULT 'identified' CHECK (partnership_status IN (
    'identified','intro_call','nda_signed','term_negotiation',
    'active','dormant','dissolved'
  )),
  primary_contact_name text,
  primary_contact_email text,
  primary_contact_phone text,
  value_proposition text,
  integration_kind text CHECK (integration_kind IN (
    'api_inbound','api_outbound','data_sharing','co_marketing','co_selling',
    'referral_only','equity','jv','technical_partnership','none'
  )),
  revenue_share_pct numeric,
  total_revenue_attributed_rupees numeric DEFAULT 0,
  first_contact_at date,
  signed_at date,
  dissolved_at date,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_partnerships_status ON public.founder_partnerships(partnership_status);
CREATE INDEX IF NOT EXISTS idx_founder_partnerships_kind ON public.founder_partnerships(partner_kind);

CREATE TABLE IF NOT EXISTS public.founder_partnership_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partnership_id uuid REFERENCES public.founder_partnerships(id) ON DELETE CASCADE,
  activity_kind text CHECK (activity_kind IN (
    'meeting','email','document','milestone','revenue_event','status_change'
  )),
  description text NOT NULL,
  happened_at timestamptz DEFAULT now(),
  performed_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_partnership_activities_pid ON public.founder_partnership_activities(partnership_id);
CREATE INDEX IF NOT EXISTS idx_founder_partnership_activities_happened ON public.founder_partnership_activities(happened_at DESC);

ALTER TABLE public.founder_partnerships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_partnership_activities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_partnerships_founder_only ON public.founder_partnerships;
CREATE POLICY founder_partnerships_founder_only ON public.founder_partnerships
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_partnership_activities_founder_only ON public.founder_partnership_activities;
CREATE POLICY founder_partnership_activities_founder_only ON public.founder_partnership_activities
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.founder_partnerships_summary();
CREATE OR REPLACE FUNCTION public.founder_partnerships_summary()
RETURNS TABLE(
  total_partnerships bigint,
  identified_count bigint,
  intro_count bigint,
  nda_count bigint,
  negotiation_count bigint,
  active_count bigint,
  dormant_count bigint,
  dissolved_count bigint,
  conversion_pct_to_active numeric,
  total_revenue_attributed_rupees numeric,
  top_partner_by_revenue text,
  top_kind text,
  top_kind_count bigint,
  recent_activities_30d_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_partnerships
  ),
  kind_rank AS (
    SELECT partner_kind, count(*)::bigint AS c
    FROM base
    WHERE partner_kind IS NOT NULL
    GROUP BY partner_kind
    ORDER BY c DESC
    LIMIT 1
  ),
  top_rev AS (
    SELECT partner_name
    FROM base
    WHERE total_revenue_attributed_rupees > 0
    ORDER BY total_revenue_attributed_rupees DESC
    LIMIT 1
  )
  SELECT
    (SELECT count(*)::bigint FROM base),
    (SELECT count(*)::bigint FROM base WHERE partnership_status='identified'),
    (SELECT count(*)::bigint FROM base WHERE partnership_status='intro_call'),
    (SELECT count(*)::bigint FROM base WHERE partnership_status='nda_signed'),
    (SELECT count(*)::bigint FROM base WHERE partnership_status='term_negotiation'),
    (SELECT count(*)::bigint FROM base WHERE partnership_status='active'),
    (SELECT count(*)::bigint FROM base WHERE partnership_status='dormant'),
    (SELECT count(*)::bigint FROM base WHERE partnership_status='dissolved'),
    CASE WHEN (SELECT count(*) FROM base) > 0
      THEN round(100.0 * (SELECT count(*) FROM base WHERE partnership_status='active')::numeric / (SELECT count(*) FROM base)::numeric, 2)
      ELSE 0 END,
    COALESCE((SELECT sum(total_revenue_attributed_rupees) FROM base), 0),
    (SELECT partner_name FROM top_rev),
    (SELECT partner_kind FROM kind_rank),
    COALESCE((SELECT c FROM kind_rank), 0),
    (SELECT count(*)::bigint FROM public.founder_partnership_activities WHERE happened_at >= now() - interval '30 days');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_partnerships_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_partnerships_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_partnerships_recent(p_status text DEFAULT NULL, p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  partner_name text,
  partner_kind text,
  partnership_status text,
  integration_kind text,
  primary_contact_name text,
  primary_contact_email text,
  revenue_share_pct numeric,
  total_revenue_attributed_rupees numeric,
  first_contact_at date,
  signed_at date,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT fp.id, fp.partner_name, fp.partner_kind, fp.partnership_status,
         fp.integration_kind, fp.primary_contact_name, fp.primary_contact_email,
         fp.revenue_share_pct, fp.total_revenue_attributed_rupees,
         fp.first_contact_at, fp.signed_at, fp.updated_at
  FROM public.founder_partnerships fp
  WHERE p_status IS NULL OR fp.partnership_status = p_status
  ORDER BY fp.updated_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_partnerships_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_recent(text, int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_partnership_activities_recent(uuid, int);
CREATE OR REPLACE FUNCTION public.founder_partnership_activities_recent(p_partnership_id uuid DEFAULT NULL, p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  partnership_id uuid,
  partner_name text,
  activity_kind text,
  description text,
  happened_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT a.id, a.partnership_id, fp.partner_name, a.activity_kind, a.description, a.happened_at
  FROM public.founder_partnership_activities a
  JOIN public.founder_partnerships fp ON fp.id = a.partnership_id
  WHERE p_partnership_id IS NULL OR a.partnership_id = p_partnership_id
  ORDER BY a.happened_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_partnership_activities_recent(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_partnership_activities_recent(uuid, int) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_partnership_register(text, text, text, text, text, text, text, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_partnership_register(
  p_partner_name text,
  p_partner_kind text,
  p_primary_contact_name text DEFAULT NULL,
  p_primary_contact_email text DEFAULT NULL,
  p_primary_contact_phone text DEFAULT NULL,
  p_value_proposition text DEFAULT NULL,
  p_integration_kind text DEFAULT NULL,
  p_revenue_share_pct numeric DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.founder_partnerships(
    partner_name, partner_kind, primary_contact_name, primary_contact_email,
    primary_contact_phone, value_proposition, integration_kind, revenue_share_pct,
    notes, first_contact_at
  ) VALUES (
    p_partner_name, p_partner_kind, p_primary_contact_name, p_primary_contact_email,
    p_primary_contact_phone, p_value_proposition, p_integration_kind, p_revenue_share_pct,
    p_notes, current_date
  )
  ON CONFLICT (partner_name) DO UPDATE SET
    partner_kind = COALESCE(EXCLUDED.partner_kind, public.founder_partnerships.partner_kind),
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_partnership_activities(partnership_id, activity_kind, description, performed_by)
  VALUES (v_id, 'milestone', 'Partnership registered: ' || p_partner_name, auth.uid());

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_partnership_register(text, text, text, text, text, text, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_partnership_register(text, text, text, text, text, text, text, numeric, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_partnership_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_partnership_status(p_id uuid, p_new_status text, p_note text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE public.founder_partnerships
    SET partnership_status = p_new_status,
        signed_at = CASE WHEN p_new_status='active' AND signed_at IS NULL THEN current_date ELSE signed_at END,
        dissolved_at = CASE WHEN p_new_status='dissolved' THEN current_date ELSE dissolved_at END,
        updated_at = now()
    WHERE id = p_id;

  INSERT INTO public.founder_partnership_activities(partnership_id, activity_kind, description, performed_by)
  VALUES (p_id, 'status_change', 'Status -> ' || p_new_status || COALESCE(' :: ' || p_note, ''), auth.uid());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_partnership_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_partnership_status(uuid, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_partnership_activity(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_partnership_activity(p_id uuid, p_kind text, p_desc text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.founder_partnership_activities(partnership_id, activity_kind, description, performed_by)
  VALUES (p_id, p_kind, p_desc, auth.uid())
  RETURNING id INTO v_id;

  UPDATE public.founder_partnerships SET updated_at = now() WHERE id = p_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_partnership_activity(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_partnership_activity(uuid, text, text) TO authenticated;

COMMIT;