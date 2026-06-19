BEGIN;
-- round1369 — Founder vendor contract vault
-- Supplier contracts + renewal alerts. Every MSA / SOW / monthly subscription
-- / annual bond ships through here with signed-at · effective-at · expires-at
-- · renewal-reminder window · storage URI. Founder-only. STABLE SECURITY
-- DEFINER plpgsql. Renewal discipline: every expiring contract surfaces 60d
-- ahead — founder either renews, terminates, or migrates supplier.

-- 1. Vendor contracts ledger
CREATE TABLE IF NOT EXISTS public.founder_vendor_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_company_name text NOT NULL,
  vendor_kind text CHECK (vendor_kind IN (
    'parts_supplier','calibration_service','training_partner','logistics',
    'payment_gateway','cloud_infra','legal_compliance','accounting',
    'insurance','other'
  )),
  contract_label text NOT NULL UNIQUE,
  contract_value_rupees numeric,
  contract_kind text CHECK (contract_kind IN (
    'one_time','monthly','annual','msa','sow','bond'
  )),
  payment_terms_days int DEFAULT 30,
  status text DEFAULT 'active' CHECK (status IN (
    'draft','active','expiring','expired','renewed','terminated'
  )),
  signed_at date,
  effective_at date,
  expires_at date,
  renewal_reminder_days int DEFAULT 60,
  owner_user_id uuid REFERENCES auth.users(id),
  storage_uri text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_vendor_contracts_status_idx
  ON public.founder_vendor_contracts (status, created_at DESC);
CREATE INDEX IF NOT EXISTS founder_vendor_contracts_kind_idx
  ON public.founder_vendor_contracts (vendor_kind);
CREATE INDEX IF NOT EXISTS founder_vendor_contracts_expires_idx
  ON public.founder_vendor_contracts (expires_at)
  WHERE status IN ('active','expiring');

ALTER TABLE public.founder_vendor_contracts ENABLE ROW LEVEL SECURITY;

-- 2. Summary RPC — 14 KPIs
DROP FUNCTION IF EXISTS public.founder_vendor_contract_vault_summary();
CREATE OR REPLACE FUNCTION public.founder_vendor_contract_vault_summary()
RETURNS TABLE (
  total_contracts                bigint,
  active_count                   bigint,
  expiring_60d_count             bigint,
  expiring_30d_count             bigint,
  expired_count                  bigint,
  renewed_count                  bigint,
  terminated_count               bigint,
  total_active_value_rupees      numeric,
  monthly_burn_estimate_rupees   numeric,
  top_kind                       text,
  top_kind_count                 bigint,
  oldest_active_age_days         int,
  newest_active_age_days         int,
  renewal_due_count              bigint
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

  SELECT COUNT(*) INTO total_contracts FROM public.founder_vendor_contracts;

  SELECT COUNT(*) FILTER (WHERE status = 'active'),
         COUNT(*) FILTER (WHERE status = 'expired'),
         COUNT(*) FILTER (WHERE status = 'renewed'),
         COUNT(*) FILTER (WHERE status = 'terminated')
    INTO active_count, expired_count, renewed_count, terminated_count
    FROM public.founder_vendor_contracts;

  SELECT COUNT(*) FILTER (
           WHERE status IN ('active','expiring')
             AND expires_at IS NOT NULL
             AND expires_at >= CURRENT_DATE
             AND expires_at <= CURRENT_DATE + INTERVAL '60 days'),
         COUNT(*) FILTER (
           WHERE status IN ('active','expiring')
             AND expires_at IS NOT NULL
             AND expires_at >= CURRENT_DATE
             AND expires_at <= CURRENT_DATE + INTERVAL '30 days')
    INTO expiring_60d_count, expiring_30d_count
    FROM public.founder_vendor_contracts;

  SELECT COALESCE(SUM(contract_value_rupees), 0)
    INTO total_active_value_rupees
    FROM public.founder_vendor_contracts
   WHERE status IN ('active','expiring');

  SELECT COALESCE(SUM(
           CASE
             WHEN contract_kind = 'monthly' THEN contract_value_rupees
             WHEN contract_kind = 'annual'  THEN contract_value_rupees / 12.0
             WHEN contract_kind = 'bond'    THEN contract_value_rupees / 12.0
             ELSE 0
           END
         ), 0)
    INTO monthly_burn_estimate_rupees
    FROM public.founder_vendor_contracts
   WHERE status IN ('active','expiring');

  SELECT vendor_kind, COUNT(*)
    INTO top_kind, top_kind_count
    FROM public.founder_vendor_contracts
   WHERE status IN ('active','expiring')
     AND vendor_kind IS NOT NULL
   GROUP BY vendor_kind
   ORDER BY COUNT(*) DESC, vendor_kind ASC
   LIMIT 1;

  SELECT GREATEST(EXTRACT(DAY FROM (now() - MIN(created_at)))::int, 0),
         GREATEST(EXTRACT(DAY FROM (now() - MAX(created_at)))::int, 0)
    INTO oldest_active_age_days, newest_active_age_days
    FROM public.founder_vendor_contracts
   WHERE status IN ('active','expiring');

  SELECT COUNT(*) FILTER (
           WHERE status IN ('active','expiring')
             AND expires_at IS NOT NULL
             AND expires_at <= CURRENT_DATE + (
               COALESCE(renewal_reminder_days, 60) || ' days'
             )::interval)
    INTO renewal_due_count
    FROM public.founder_vendor_contracts;

  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_vendor_contract_vault_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_vendor_contract_vault_summary() TO authenticated;

-- 3. Recent contracts RPC
DROP FUNCTION IF EXISTS public.founder_vendor_contracts_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_vendor_contracts_recent(
  p_status text DEFAULT NULL,
  p_limit  int  DEFAULT 100
)
RETURNS TABLE (
  id                    uuid,
  vendor_company_name   text,
  vendor_kind           text,
  contract_label        text,
  contract_value_rupees numeric,
  contract_kind         text,
  payment_terms_days    int,
  status                text,
  signed_at             date,
  effective_at          date,
  expires_at            date,
  days_until_expiry     int,
  renewal_reminder_days int,
  storage_uri           text,
  notes                 text,
  age_days              int,
  created_at            timestamptz
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
  SELECT
    c.id,
    c.vendor_company_name,
    c.vendor_kind,
    c.contract_label,
    c.contract_value_rupees,
    c.contract_kind,
    c.payment_terms_days,
    c.status,
    c.signed_at,
    c.effective_at,
    c.expires_at,
    CASE
      WHEN c.expires_at IS NOT NULL
      THEN (c.expires_at - CURRENT_DATE)::int
      ELSE NULL
    END,
    c.renewal_reminder_days,
    c.storage_uri,
    c.notes,
    GREATEST(EXTRACT(DAY FROM (now() - c.created_at))::int, 0),
    c.created_at
  FROM public.founder_vendor_contracts c
  WHERE (p_status IS NULL OR c.status = p_status)
  ORDER BY c.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_vendor_contracts_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_vendor_contracts_recent(text, int) TO authenticated;

-- 4. Renewal-due RPC
DROP FUNCTION IF EXISTS public.founder_vendor_contracts_renewal_due(int);
CREATE OR REPLACE FUNCTION public.founder_vendor_contracts_renewal_due(
  p_window_days int DEFAULT 90
)
RETURNS TABLE (
  id                    uuid,
  vendor_company_name   text,
  vendor_kind           text,
  contract_label        text,
  contract_kind         text,
  contract_value_rupees numeric,
  expires_at            date,
  days_until_expiry     int,
  status                text,
  renewal_reminder_days int
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
  SELECT
    c.id,
    c.vendor_company_name,
    c.vendor_kind,
    c.contract_label,
    c.contract_kind,
    c.contract_value_rupees,
    c.expires_at,
    (c.expires_at - CURRENT_DATE)::int,
    c.status,
    c.renewal_reminder_days
  FROM public.founder_vendor_contracts c
  WHERE c.status IN ('active','expiring')
    AND c.expires_at IS NOT NULL
    AND c.expires_at <= CURRENT_DATE + (GREATEST(p_window_days, 1) || ' days')::interval
  ORDER BY c.expires_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_vendor_contracts_renewal_due(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_vendor_contracts_renewal_due(int) TO authenticated;

-- 5. Register contract
DROP FUNCTION IF EXISTS public.log_founder_vendor_contract_register(text, text, text, text, numeric, int, date, date, date, int, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_vendor_contract_register(
  p_vendor_company_name   text,
  p_contract_label        text,
  p_vendor_kind           text    DEFAULT 'other',
  p_contract_kind         text    DEFAULT 'msa',
  p_contract_value_rupees numeric DEFAULT NULL,
  p_payment_terms_days    int     DEFAULT 30,
  p_signed_at             date    DEFAULT NULL,
  p_effective_at          date    DEFAULT NULL,
  p_expires_at            date    DEFAULT NULL,
  p_renewal_reminder_days int     DEFAULT 60,
  p_storage_uri           text    DEFAULT NULL,
  p_notes                 text    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_vendor_contracts (
    vendor_company_name, contract_label, vendor_kind, contract_kind,
    contract_value_rupees, payment_terms_days, signed_at, effective_at,
    expires_at, renewal_reminder_days, storage_uri, notes
  ) VALUES (
    p_vendor_company_name, p_contract_label, COALESCE(p_vendor_kind, 'other'),
    COALESCE(p_contract_kind, 'msa'), p_contract_value_rupees,
    COALESCE(p_payment_terms_days, 30), p_signed_at, p_effective_at,
    p_expires_at, COALESCE(p_renewal_reminder_days, 60), p_storage_uri, p_notes
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_vendor_contract_register(text, text, text, text, numeric, int, date, date, date, int, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_vendor_contract_register(text, text, text, text, numeric, int, date, date, date, int, text, text) TO authenticated;

-- 6. Status update
DROP FUNCTION IF EXISTS public.log_founder_vendor_contract_status(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_vendor_contract_status(
  p_id         uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_new_status NOT IN ('draft','active','expiring','expired','renewed','terminated') THEN
    RAISE EXCEPTION 'invalid status: %', p_new_status USING ERRCODE = '22023';
  END IF;

  UPDATE public.founder_vendor_contracts
     SET status     = p_new_status,
         updated_at = now()
   WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_vendor_contract_status(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_vendor_contract_status(uuid, text) TO authenticated;

COMMIT;