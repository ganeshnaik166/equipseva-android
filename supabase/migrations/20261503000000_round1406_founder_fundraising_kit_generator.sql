BEGIN;
-- r1406 — founder fundraising kit generator
-- one-click investor pack auto-generator with share tokens



-- =========================================================================
-- TABLES
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_fundraising_kits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kit_label text NOT NULL UNIQUE,
  kit_kind text NOT NULL CHECK (kit_kind IN ('preseed','seed','seriesA','seriesB','bridge','strategic')),
  target_raise_rupees numeric(14,2),
  current_status text NOT NULL DEFAULT 'draft' CHECK (current_status IN ('draft','final','published','sent','retired')),
  pitch_deck_url text,
  financial_model_url text,
  traction_summary_url text,
  cap_table_url text,
  term_sheet_url text,
  references_url text,
  generated_at timestamptz,
  published_at timestamptz,
  retired_at timestamptz,
  generated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  kpis_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_fundraising_kits_status
  ON public.founder_fundraising_kits(current_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_fundraising_kits_kind
  ON public.founder_fundraising_kits(kit_kind, created_at DESC);

CREATE TABLE IF NOT EXISTS public.founder_fundraising_kit_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kit_id uuid NOT NULL REFERENCES public.founder_fundraising_kits(id) ON DELETE CASCADE,
  investor_firm_name text NOT NULL,
  investor_partner_email text,
  share_token text NOT NULL UNIQUE,
  max_views integer NOT NULL DEFAULT 50,
  view_count integer NOT NULL DEFAULT 0,
  sent_at timestamptz,
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','exhausted','revoked')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_fundraising_shares_kit
  ON public.founder_fundraising_kit_shares(kit_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_fundraising_shares_status
  ON public.founder_fundraising_kit_shares(status, expires_at DESC);

ALTER TABLE public.founder_fundraising_kits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_fundraising_kit_shares ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.founder_fundraising_kits FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.founder_fundraising_kit_shares FROM PUBLIC, anon, authenticated;

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS public.founder_fundraising_kit_summary();
CREATE OR REPLACE FUNCTION public.founder_fundraising_kit_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_draft int;
  v_final int;
  v_published int;
  v_sent int;
  v_retired int;
  v_target_raise numeric;
  v_shares_total int;
  v_shares_active int;
  v_shares_expired int;
  v_shares_revoked int;
  v_views_total int;
  v_kits_30d int;
  v_shares_30d int;
  v_latest_kit text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_total FROM public.founder_fundraising_kits;
  SELECT count(*) INTO v_draft FROM public.founder_fundraising_kits WHERE current_status = 'draft';
  SELECT count(*) INTO v_final FROM public.founder_fundraising_kits WHERE current_status = 'final';
  SELECT count(*) INTO v_published FROM public.founder_fundraising_kits WHERE current_status = 'published';
  SELECT count(*) INTO v_sent FROM public.founder_fundraising_kits WHERE current_status = 'sent';
  SELECT count(*) INTO v_retired FROM public.founder_fundraising_kits WHERE current_status = 'retired';
  SELECT COALESCE(sum(target_raise_rupees), 0) INTO v_target_raise
    FROM public.founder_fundraising_kits
    WHERE current_status IN ('final','published','sent');

  SELECT count(*) INTO v_shares_total FROM public.founder_fundraising_kit_shares;
  SELECT count(*) INTO v_shares_active FROM public.founder_fundraising_kit_shares WHERE status = 'active';
  SELECT count(*) INTO v_shares_expired FROM public.founder_fundraising_kit_shares WHERE status = 'expired';
  SELECT count(*) INTO v_shares_revoked FROM public.founder_fundraising_kit_shares WHERE status = 'revoked';
  SELECT COALESCE(sum(view_count), 0) INTO v_views_total FROM public.founder_fundraising_kit_shares;

  SELECT count(*) INTO v_kits_30d
    FROM public.founder_fundraising_kits
    WHERE created_at >= now() - interval '30 days';
  SELECT count(*) INTO v_shares_30d
    FROM public.founder_fundraising_kit_shares
    WHERE created_at >= now() - interval '30 days';

  SELECT kit_label INTO v_latest_kit
    FROM public.founder_fundraising_kits
    ORDER BY created_at DESC LIMIT 1;

  RETURN jsonb_build_object(
    'total_kits', v_total,
    'draft_kits', v_draft,
    'final_kits', v_final,
    'published_kits', v_published,
    'sent_kits', v_sent,
    'retired_kits', v_retired,
    'target_raise_rupees', v_target_raise,
    'total_shares', v_shares_total,
    'active_shares', v_shares_active,
    'expired_shares', v_shares_expired,
    'revoked_shares', v_shares_revoked,
    'total_views', v_views_total,
    'kits_last_30d', v_kits_30d,
    'shares_last_30d', v_shares_30d,
    'latest_kit_label', COALESCE(v_latest_kit, '—')
  );
END;
$$;

DROP FUNCTION IF EXISTS public.founder_fundraising_kits_recent(integer);
CREATE OR REPLACE FUNCTION public.founder_fundraising_kits_recent(p_limit integer DEFAULT 20)
RETURNS TABLE (
  id uuid,
  kit_label text,
  kit_kind text,
  target_raise_rupees numeric,
  current_status text,
  generated_at timestamptz,
  published_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT k.id, k.kit_label, k.kit_kind, k.target_raise_rupees, k.current_status,
           k.generated_at, k.published_at, k.created_at
    FROM public.founder_fundraising_kits k
    ORDER BY k.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 200));
END;
$$;

DROP FUNCTION IF EXISTS public.founder_fundraising_kit_shares_recent(integer);
CREATE OR REPLACE FUNCTION public.founder_fundraising_kit_shares_recent(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  kit_id uuid,
  kit_label text,
  investor_firm_name text,
  investor_partner_email text,
  view_count integer,
  max_views integer,
  status text,
  sent_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT s.id, s.kit_id, k.kit_label, s.investor_firm_name, s.investor_partner_email,
           s.view_count, s.max_views, s.status, s.sent_at, s.expires_at, s.created_at
    FROM public.founder_fundraising_kit_shares s
    LEFT JOIN public.founder_fundraising_kits k ON k.id = s.kit_id
    ORDER BY s.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 500));
END;
$$;

DROP FUNCTION IF EXISTS public.log_founder_fundraising_create_kit(text, text, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_fundraising_create_kit(
  p_kit_label text,
  p_kit_kind text,
  p_target_raise_rupees numeric,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_snapshot jsonb;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- snapshot current KPIs at create-time
  v_snapshot := jsonb_build_object(
    'snapshot_at', now(),
    'amc_contracts_active', (SELECT count(*) FROM public.amc_contracts WHERE status = 'active'),
    'engineers_verified', (SELECT count(*) FROM public.engineers WHERE verification_status::text = 'verified'),
    'repair_jobs_total', (SELECT count(*) FROM public.repair_jobs),
    'code_red_total', (SELECT count(*) FROM public.code_red_requests)
  );

  INSERT INTO public.founder_fundraising_kits
    (kit_label, kit_kind, target_raise_rupees, current_status, generated_at, generated_by, kpis_snapshot, notes)
  VALUES
    (p_kit_label, p_kit_kind, p_target_raise_rupees, 'draft', now(), auth.uid(), v_snapshot, p_notes)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.log_founder_fundraising_publish_kit(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_fundraising_publish_kit(p_kit_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_fundraising_kits
     SET current_status = 'published', published_at = now(), updated_at = now()
   WHERE id = p_kit_id;
END;
$$;

DROP FUNCTION IF EXISTS public.log_founder_fundraising_grant_share(uuid, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.log_founder_fundraising_grant_share(
  p_kit_id uuid,
  p_investor_firm_name text,
  p_investor_partner_email text,
  p_max_views integer DEFAULT 50,
  p_expires_in_days integer DEFAULT 30
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_token text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  v_token := encode(gen_random_bytes(24), 'hex');

  INSERT INTO public.founder_fundraising_kit_shares
    (kit_id, investor_firm_name, investor_partner_email, share_token, max_views, sent_at, expires_at, status)
  VALUES
    (p_kit_id, p_investor_firm_name, p_investor_partner_email, v_token,
     COALESCE(p_max_views, 50), now(), now() + (COALESCE(p_expires_in_days, 30) || ' days')::interval, 'active')
  RETURNING id INTO v_id;

  UPDATE public.founder_fundraising_kits
     SET current_status = 'sent', updated_at = now()
   WHERE id = p_kit_id AND current_status IN ('published','final');

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.log_founder_fundraising_revoke_share(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_fundraising_revoke_share(p_share_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_fundraising_kit_shares
     SET status = 'revoked'
   WHERE id = p_share_id AND status = 'active';
END;
$$;

DROP FUNCTION IF EXISTS public.log_founder_fundraising_kit_status(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_fundraising_kit_status(p_kit_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_status NOT IN ('draft','final','published','sent','retired') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE = '22023';
  END IF;

  UPDATE public.founder_fundraising_kits
     SET current_status = p_status,
         retired_at = CASE WHEN p_status = 'retired' THEN now() ELSE retired_at END,
         updated_at = now()
   WHERE id = p_kit_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fundraising_kit_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_fundraising_kits_recent(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_fundraising_kit_shares_recent(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_fundraising_create_kit(text, text, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_fundraising_publish_kit(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_fundraising_grant_share(uuid, text, text, integer, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_fundraising_revoke_share(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_fundraising_kit_status(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_fundraising_kit_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_fundraising_kits_recent(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_fundraising_kit_shares_recent(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_fundraising_create_kit(text, text, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_fundraising_publish_kit(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_fundraising_grant_share(uuid, text, text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_fundraising_revoke_share(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_fundraising_kit_status(uuid, text) TO authenticated;

COMMIT;