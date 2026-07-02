BEGIN;
-- r1421 founder_vip_hospital_account_manager

CREATE TABLE IF NOT EXISTS public.founder_vip_hospital_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  tier_band text NOT NULL DEFAULT 'priority' CHECK (tier_band IN ('strategic','enterprise','growth','priority','watch')),
  assigned_csm_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  quarterly_check_in_cadence_days int NOT NULL DEFAULT 90,
  last_check_in_at timestamptz,
  next_check_in_due_at date,
  account_health_band text NOT NULL DEFAULT 'green' CHECK (account_health_band IN ('green','yellow','orange','red')),
  executive_sponsor_at_hospital text,
  annual_revenue_rupees numeric,
  escalation_path text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fvha_tier ON public.founder_vip_hospital_accounts(tier_band);
CREATE INDEX IF NOT EXISTS idx_fvha_health ON public.founder_vip_hospital_accounts(account_health_band);
CREATE INDEX IF NOT EXISTS idx_fvha_due ON public.founder_vip_hospital_accounts(next_check_in_due_at);
CREATE INDEX IF NOT EXISTS idx_fvha_csm ON public.founder_vip_hospital_accounts(assigned_csm_user_id);

CREATE TABLE IF NOT EXISTS public.founder_vip_hospital_touchpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES public.founder_vip_hospital_accounts(id) ON DELETE CASCADE,
  touchpoint_kind text NOT NULL CHECK (touchpoint_kind IN ('quarterly_review','adhoc_check_in','escalation_resolved','executive_meeting','renewal_discussion','complaint_received','feedback_session')),
  description text,
  sentiment text CHECK (sentiment IN ('very_positive','positive','neutral','cool','negative')),
  happened_at timestamptz NOT NULL DEFAULT now(),
  performed_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fvht_account ON public.founder_vip_hospital_touchpoints(account_id);
CREATE INDEX IF NOT EXISTS idx_fvht_kind ON public.founder_vip_hospital_touchpoints(touchpoint_kind);
CREATE INDEX IF NOT EXISTS idx_fvht_when ON public.founder_vip_hospital_touchpoints(happened_at DESC);

ALTER TABLE public.founder_vip_hospital_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_vip_hospital_touchpoints ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.founder_vip_hospital_summary()
RETURNS TABLE (
  total_accounts int,
  strategic_count int,
  enterprise_count int,
  growth_count int,
  priority_count int,
  watch_count int,
  green_count int,
  yellow_count int,
  orange_count int,
  red_count int,
  overdue_check_in_count int,
  due_within_14d_count int,
  total_touchpoints_90d int,
  unique_accounts_touched_90d int,
  total_annual_revenue_rupees numeric,
  accounts_with_csm_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH a AS (SELECT * FROM public.founder_vip_hospital_accounts),
  t AS (SELECT * FROM public.founder_vip_hospital_touchpoints WHERE happened_at >= now() - interval '90 days')
  SELECT
    (SELECT count(*)::int FROM a),
    (SELECT count(*)::int FROM a WHERE tier_band='strategic'),
    (SELECT count(*)::int FROM a WHERE tier_band='enterprise'),
    (SELECT count(*)::int FROM a WHERE tier_band='growth'),
    (SELECT count(*)::int FROM a WHERE tier_band='priority'),
    (SELECT count(*)::int FROM a WHERE tier_band='watch'),
    (SELECT count(*)::int FROM a WHERE account_health_band='green'),
    (SELECT count(*)::int FROM a WHERE account_health_band='yellow'),
    (SELECT count(*)::int FROM a WHERE account_health_band='orange'),
    (SELECT count(*)::int FROM a WHERE account_health_band='red'),
    (SELECT count(*)::int FROM a WHERE next_check_in_due_at IS NOT NULL AND next_check_in_due_at < current_date),
    (SELECT count(*)::int FROM a WHERE next_check_in_due_at IS NOT NULL AND next_check_in_due_at BETWEEN current_date AND current_date + 14),
    (SELECT count(*)::int FROM t),
    (SELECT count(DISTINCT account_id)::int FROM t),
    (SELECT COALESCE(SUM(annual_revenue_rupees),0) FROM a),
    (SELECT count(*)::int FROM a WHERE assigned_csm_user_id IS NOT NULL);
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_vip_hospital_accounts_recent()
RETURNS SETOF public.founder_vip_hospital_accounts
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT * FROM public.founder_vip_hospital_accounts
    ORDER BY
      CASE tier_band WHEN 'strategic' THEN 1 WHEN 'enterprise' THEN 2 WHEN 'growth' THEN 3 WHEN 'priority' THEN 4 WHEN 'watch' THEN 5 ELSE 9 END,
      created_at DESC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_vip_hospital_touchpoints_recent(p_account_id uuid DEFAULT NULL)
RETURNS SETOF public.founder_vip_hospital_touchpoints
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT * FROM public.founder_vip_hospital_touchpoints
    WHERE p_account_id IS NULL OR account_id = p_account_id
    ORDER BY happened_at DESC LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_vip_hospital_overdue_check_ins()
RETURNS SETOF public.founder_vip_hospital_accounts
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT * FROM public.founder_vip_hospital_accounts
    WHERE next_check_in_due_at IS NOT NULL AND next_check_in_due_at < current_date
    ORDER BY next_check_in_due_at ASC LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_vip_register_account(
  p_hospital_user_id uuid,
  p_tier_band text,
  p_assigned_csm_user_id uuid DEFAULT NULL,
  p_cadence_days int DEFAULT 90,
  p_executive_sponsor text DEFAULT NULL,
  p_annual_revenue_rupees numeric DEFAULT NULL,
  p_escalation_path text DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_tier_band NOT IN ('strategic','enterprise','growth','priority','watch') THEN
    RAISE EXCEPTION 'invalid tier_band' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.founder_vip_hospital_accounts(
    hospital_user_id, tier_band, assigned_csm_user_id, quarterly_check_in_cadence_days,
    next_check_in_due_at, executive_sponsor_at_hospital, annual_revenue_rupees,
    escalation_path, notes
  ) VALUES (
    p_hospital_user_id, p_tier_band, p_assigned_csm_user_id, COALESCE(p_cadence_days,90),
    current_date + COALESCE(p_cadence_days,90), p_executive_sponsor, p_annual_revenue_rupees,
    p_escalation_path, p_notes
  )
  ON CONFLICT (hospital_user_id) DO UPDATE SET
    tier_band = EXCLUDED.tier_band,
    assigned_csm_user_id = EXCLUDED.assigned_csm_user_id,
    quarterly_check_in_cadence_days = EXCLUDED.quarterly_check_in_cadence_days,
    executive_sponsor_at_hospital = EXCLUDED.executive_sponsor_at_hospital,
    annual_revenue_rupees = EXCLUDED.annual_revenue_rupees,
    escalation_path = EXCLUDED.escalation_path,
    notes = EXCLUDED.notes,
    updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_vip_record_touchpoint(
  p_account_id uuid,
  p_touchpoint_kind text,
  p_description text DEFAULT NULL,
  p_sentiment text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_cadence int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_touchpoint_kind NOT IN ('quarterly_review','adhoc_check_in','escalation_resolved','executive_meeting','renewal_discussion','complaint_received','feedback_session') THEN
    RAISE EXCEPTION 'invalid touchpoint_kind' USING ERRCODE='22023';
  END IF;
  IF p_sentiment IS NOT NULL AND p_sentiment NOT IN ('very_positive','positive','neutral','cool','negative') THEN
    RAISE EXCEPTION 'invalid sentiment' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_vip_hospital_touchpoints(
    account_id, touchpoint_kind, description, sentiment, performed_by
  ) VALUES (
    p_account_id, p_touchpoint_kind, p_description, p_sentiment, auth.uid()
  ) RETURNING id INTO v_id;

  SELECT quarterly_check_in_cadence_days INTO v_cadence
    FROM public.founder_vip_hospital_accounts WHERE id = p_account_id;

  UPDATE public.founder_vip_hospital_accounts
    SET last_check_in_at = now(),
        next_check_in_due_at = current_date + COALESCE(v_cadence,90),
        updated_at = now()
  WHERE id = p_account_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_vip_update_health_band(
  p_account_id uuid,
  p_health_band text,
  p_notes text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_health_band NOT IN ('green','yellow','orange','red') THEN
    RAISE EXCEPTION 'invalid health band' USING ERRCODE='22023';
  END IF;
  UPDATE public.founder_vip_hospital_accounts
    SET account_health_band = p_health_band,
        notes = COALESCE(p_notes, notes),
        updated_at = now()
  WHERE id = p_account_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_vip_hospital_summary() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_vip_hospital_accounts_recent() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_vip_hospital_touchpoints_recent(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_vip_hospital_overdue_check_ins() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_vip_register_account(uuid,text,uuid,int,text,numeric,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_vip_record_touchpoint(uuid,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_vip_update_health_band(uuid,text,text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.founder_vip_hospital_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vip_hospital_accounts_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vip_hospital_touchpoints_recent(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_vip_hospital_overdue_check_ins() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_register_account(uuid,text,uuid,int,text,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_record_touchpoint(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_update_health_band(uuid,text,text) TO authenticated;

COMMIT;