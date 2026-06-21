BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_replacement_quotes_r1735 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  old_equipment_name text NOT NULL,
  replacement_equipment_name text NOT NULL,
  quoted_amount_rupees bigint NOT NULL CHECK (quoted_amount_rupees >= 0),
  discount_offered_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (discount_offered_pct >= 0 AND discount_offered_pct <= 100),
  valid_until date NOT NULL,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','in_negotiation','accepted','declined','expired')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrq_r1735_hospital ON public.hospital_replacement_quotes_r1735(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hrq_r1735_status ON public.hospital_replacement_quotes_r1735(status);
CREATE INDEX IF NOT EXISTS idx_hrq_r1735_valid_until ON public.hospital_replacement_quotes_r1735(valid_until);

CREATE TABLE IF NOT EXISTS public.hospital_quote_revisions_r1735 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_id uuid NOT NULL REFERENCES public.hospital_replacement_quotes_r1735(id) ON DELETE CASCADE,
  revision_amount_rupees bigint NOT NULL CHECK (revision_amount_rupees >= 0),
  revision_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hqr_r1735_quote ON public.hospital_quote_revisions_r1735(quote_id);

-- RLS
ALTER TABLE public.hospital_replacement_quotes_r1735 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_quote_revisions_r1735 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hrq_r1735_founder ON public.hospital_replacement_quotes_r1735;
CREATE POLICY hrq_r1735_founder ON public.hospital_replacement_quotes_r1735
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hqr_r1735_founder ON public.hospital_quote_revisions_r1735;
CREATE POLICY hqr_r1735_founder ON public.hospital_quote_revisions_r1735
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_quotes
CREATE OR REPLACE FUNCTION public.list_quotes_r1735(p_status text DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  old_equipment_name text,
  replacement_equipment_name text,
  quoted_amount_rupees bigint,
  discount_offered_pct numeric,
  valid_until date,
  status text,
  decided_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT q.id, q.hospital_user_id, p.email::text AS hospital_email,
         q.old_equipment_name, q.replacement_equipment_name,
         q.quoted_amount_rupees, q.discount_offered_pct, q.valid_until,
         q.status, q.decided_at, q.created_at
  FROM public.hospital_replacement_quotes_r1735 q
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  WHERE (p_status IS NULL OR q.status = p_status)
  ORDER BY q.created_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_quotes_r1735(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_quotes_r1735(text, int) TO authenticated;

-- RPC 2: send_quote
CREATE OR REPLACE FUNCTION public.send_quote_r1735(
  p_hospital_user_id uuid,
  p_old_equipment text,
  p_replacement_equipment text,
  p_amount_rupees bigint,
  p_discount_pct numeric,
  p_valid_until date
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
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_replacement_quotes_r1735(
    hospital_user_id, old_equipment_name, replacement_equipment_name,
    quoted_amount_rupees, discount_offered_pct, valid_until, status
  ) VALUES (
    p_hospital_user_id, p_old_equipment, p_replacement_equipment,
    p_amount_rupees, COALESCE(p_discount_pct,0), p_valid_until, 'sent'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'send_quote_r1735',
          jsonb_build_object('quote_id', v_id, 'hospital_user_id', p_hospital_user_id,
                             'amount_rupees', p_amount_rupees, 'discount_pct', p_discount_pct));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_quote_r1735(uuid, text, text, bigint, numeric, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_quote_r1735(uuid, text, text, bigint, numeric, date) TO authenticated;

-- RPC 3: list_revisions
CREATE OR REPLACE FUNCTION public.list_revisions_r1735(p_quote_id uuid)
RETURNS TABLE (
  id uuid,
  quote_id uuid,
  revision_amount_rupees bigint,
  revision_at timestamptz,
  by_email text,
  reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.quote_id, r.revision_amount_rupees, r.revision_at, r.by_email, r.reason
  FROM public.hospital_quote_revisions_r1735 r
  WHERE r.quote_id = p_quote_id
  ORDER BY r.revision_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_revisions_r1735(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_revisions_r1735(uuid) TO authenticated;

-- RPC 4: log_revision
CREATE OR REPLACE FUNCTION public.log_revision_r1735(
  p_quote_id uuid,
  p_revision_amount bigint,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := COALESCE((auth.jwt()->>'email'), 'founder');
  INSERT INTO public.hospital_quote_revisions_r1735(quote_id, revision_amount_rupees, by_email, reason)
  VALUES (p_quote_id, p_revision_amount, v_email, p_reason)
  RETURNING id INTO v_id;

  UPDATE public.hospital_replacement_quotes_r1735
  SET quoted_amount_rupees = p_revision_amount,
      status = CASE WHEN status = 'sent' THEN 'in_negotiation' ELSE status END,
      updated_at = now()
  WHERE id = p_quote_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_revision_r1735',
          jsonb_build_object('quote_id', p_quote_id, 'revision_amount', p_revision_amount, 'reason', p_reason));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_revision_r1735(uuid, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_revision_r1735(uuid, bigint, text) TO authenticated;

-- RPC 5: update_status
CREATE OR REPLACE FUNCTION public.update_status_r1735(p_quote_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('sent','in_negotiation','accepted','declined','expired') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE public.hospital_replacement_quotes_r1735
  SET status = p_status,
      decided_at = CASE WHEN p_status IN ('accepted','declined','expired') THEN now() ELSE decided_at END,
      updated_at = now()
  WHERE id = p_quote_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_status_r1735',
          jsonb_build_object('quote_id', p_quote_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_status_r1735(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_status_r1735(uuid, text) TO authenticated;

-- RPC 6: total_pipeline_value
CREATE OR REPLACE FUNCTION public.total_pipeline_value_r1735()
RETURNS TABLE (
  status text,
  quote_count int,
  total_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT q.status,
         (COUNT(*))::int AS quote_count,
         COALESCE(SUM(q.quoted_amount_rupees),0)::bigint AS total_rupees
  FROM public.hospital_replacement_quotes_r1735 q
  GROUP BY q.status
  ORDER BY q.status;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.total_pipeline_value_r1735() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_pipeline_value_r1735() TO authenticated;

-- RPC 7: expiring_quotes
CREATE OR REPLACE FUNCTION public.expiring_quotes_r1735(p_days int DEFAULT 14)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  replacement_equipment_name text,
  quoted_amount_rupees bigint,
  valid_until date,
  days_remaining int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT q.id, q.hospital_user_id, p.email::text AS hospital_email,
         q.replacement_equipment_name, q.quoted_amount_rupees, q.valid_until,
         (q.valid_until - CURRENT_DATE)::int AS days_remaining,
         q.status
  FROM public.hospital_replacement_quotes_r1735 q
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  WHERE q.status IN ('sent','in_negotiation')
    AND q.valid_until >= CURRENT_DATE
    AND q.valid_until <= CURRENT_DATE + (COALESCE(p_days,14) || ' days')::interval
  ORDER BY q.valid_until ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.expiring_quotes_r1735(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_quotes_r1735(int) TO authenticated;

COMMIT;