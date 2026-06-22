BEGIN;

-- Valuations table
CREATE TABLE IF NOT EXISTS public.investor_409a_valuations_r1949 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  valuation_date date NOT NULL,
  valuation_provider text NOT NULL,
  fair_market_value_per_share_rupees bigint NOT NULL CHECK (fair_market_value_per_share_rupees >= 0),
  methodology text NOT NULL CHECK (methodology IN ('market_approach','income_approach','asset_approach','option_pricing')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','finalized','superseded','expired')),
  finalized_at timestamptz,
  expires_on date,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investor_409a_valuations_r1949_date
  ON public.investor_409a_valuations_r1949 (valuation_date DESC);

CREATE INDEX IF NOT EXISTS idx_investor_409a_valuations_r1949_status
  ON public.investor_409a_valuations_r1949 (status);

ALTER TABLE public.investor_409a_valuations_r1949 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS investor_409a_valuations_r1949_founder_all
  ON public.investor_409a_valuations_r1949;

CREATE POLICY investor_409a_valuations_r1949_founder_all
  ON public.investor_409a_valuations_r1949
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Grant log table
CREATE TABLE IF NOT EXISTS public.investor_409a_grant_log_r1949 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  valuation_id uuid NOT NULL REFERENCES public.investor_409a_valuations_r1949(id) ON DELETE CASCADE,
  grant_type text NOT NULL CHECK (grant_type IN ('ISO','NSO','RSU','RSA','common_stock')),
  grantee_email text NOT NULL,
  grant_count int NOT NULL CHECK (grant_count > 0),
  grant_at timestamptz NOT NULL DEFAULT now(),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investor_409a_grant_log_r1949_valuation
  ON public.investor_409a_grant_log_r1949 (valuation_id);

CREATE INDEX IF NOT EXISTS idx_investor_409a_grant_log_r1949_grantee
  ON public.investor_409a_grant_log_r1949 (grantee_email);

CREATE INDEX IF NOT EXISTS idx_investor_409a_grant_log_r1949_at
  ON public.investor_409a_grant_log_r1949 (grant_at DESC);

ALTER TABLE public.investor_409a_grant_log_r1949 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS investor_409a_grant_log_r1949_founder_all
  ON public.investor_409a_grant_log_r1949;

CREATE POLICY investor_409a_grant_log_r1949_founder_all
  ON public.investor_409a_grant_log_r1949
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_valuations
DROP FUNCTION IF EXISTS public.list_valuations_r1949(int);
CREATE OR REPLACE FUNCTION public.list_valuations_r1949(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  valuation_date date,
  valuation_provider text,
  fair_market_value_per_share_rupees bigint,
  methodology text,
  status text,
  finalized_at timestamptz,
  expires_on date,
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
  SELECT v.id, v.valuation_date, v.valuation_provider, v.fair_market_value_per_share_rupees,
         v.methodology, v.status, v.finalized_at, v.expires_on, v.created_at
    FROM public.investor_409a_valuations_r1949 v
    ORDER BY v.valuation_date DESC, v.created_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- RPC 2: log_valuation
DROP FUNCTION IF EXISTS public.log_valuation_r1949(date, text, bigint, text, text, date, text);
CREATE OR REPLACE FUNCTION public.log_valuation_r1949(
  p_valuation_date date,
  p_provider text,
  p_fmv_rupees bigint,
  p_methodology text,
  p_status text DEFAULT 'draft',
  p_expires_on date DEFAULT NULL,
  p_notes_md text DEFAULT NULL
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

  INSERT INTO public.investor_409a_valuations_r1949
    (valuation_date, valuation_provider, fair_market_value_per_share_rupees, methodology, status, finalized_at, expires_on, notes_md)
  VALUES
    (p_valuation_date, p_provider, p_fmv_rupees, p_methodology, p_status,
     CASE WHEN p_status = 'finalized' THEN now() ELSE NULL END,
     p_expires_on, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_valuation_r1949',
    jsonb_build_object('valuation_id', v_id, 'valuation_date', p_valuation_date, 'provider', p_provider, 'fmv_rupees', p_fmv_rupees, 'methodology', p_methodology, 'status', p_status)
  );

  RETURN v_id;
END;
$$;

-- RPC 3: list_grants
DROP FUNCTION IF EXISTS public.list_grants_r1949(uuid, int);
CREATE OR REPLACE FUNCTION public.list_grants_r1949(p_valuation_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  valuation_id uuid,
  grant_type text,
  grantee_email text,
  grant_count int,
  grant_at timestamptz,
  notes_md text
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
  SELECT g.id, g.valuation_id, g.grant_type, g.grantee_email, g.grant_count, g.grant_at, g.notes_md
    FROM public.investor_409a_grant_log_r1949 g
    WHERE p_valuation_id IS NULL OR g.valuation_id = p_valuation_id
    ORDER BY g.grant_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- RPC 4: log_grant
DROP FUNCTION IF EXISTS public.log_grant_r1949(uuid, text, text, int, text);
CREATE OR REPLACE FUNCTION public.log_grant_r1949(
  p_valuation_id uuid,
  p_grant_type text,
  p_grantee_email text,
  p_grant_count int,
  p_notes_md text DEFAULT NULL
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

  INSERT INTO public.investor_409a_grant_log_r1949
    (valuation_id, grant_type, grantee_email, grant_count, notes_md)
  VALUES
    (p_valuation_id, p_grant_type, p_grantee_email, p_grant_count, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_grant_r1949',
    jsonb_build_object('grant_id', v_id, 'valuation_id', p_valuation_id, 'grant_type', p_grant_type, 'grantee_email', p_grantee_email, 'grant_count', p_grant_count)
  );

  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
DROP FUNCTION IF EXISTS public.mark_status_r1949(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r1949(p_valuation_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('draft','finalized','superseded','expired') THEN
    RAISE EXCEPTION 'invalid status: %', p_status;
  END IF;

  UPDATE public.investor_409a_valuations_r1949
     SET status = p_status,
         finalized_at = CASE WHEN p_status = 'finalized' AND finalized_at IS NULL THEN now() ELSE finalized_at END,
         updated_at = now()
   WHERE id = p_valuation_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r1949',
    jsonb_build_object('valuation_id', p_valuation_id, 'status', p_status)
  );
END;
$$;

-- RPC 6: current_valuation
DROP FUNCTION IF EXISTS public.current_valuation_r1949();
CREATE OR REPLACE FUNCTION public.current_valuation_r1949()
RETURNS TABLE (
  id uuid,
  valuation_date date,
  valuation_provider text,
  fair_market_value_per_share_rupees bigint,
  methodology text,
  status text,
  finalized_at timestamptz,
  expires_on date
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
  SELECT v.id, v.valuation_date, v.valuation_provider, v.fair_market_value_per_share_rupees,
         v.methodology, v.status, v.finalized_at, v.expires_on
    FROM public.investor_409a_valuations_r1949 v
    WHERE v.status = 'finalized'
      AND (v.expires_on IS NULL OR v.expires_on >= CURRENT_DATE)
    ORDER BY v.valuation_date DESC
    LIMIT 1;
END;
$$;

-- RPC 7: recent_grants
DROP FUNCTION IF EXISTS public.recent_grants_r1949(int);
CREATE OR REPLACE FUNCTION public.recent_grants_r1949(p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  valuation_id uuid,
  grant_type text,
  grantee_email text,
  grant_count int,
  grant_at timestamptz,
  fmv_per_share_rupees bigint
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
  SELECT g.id, g.valuation_id, g.grant_type, g.grantee_email, g.grant_count, g.grant_at,
         v.fair_market_value_per_share_rupees
    FROM public.investor_409a_grant_log_r1949 g
    LEFT JOIN public.investor_409a_valuations_r1949 v ON v.id = g.valuation_id
    ORDER BY g.grant_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

-- Lock down execute privs
REVOKE EXECUTE ON FUNCTION public.list_valuations_r1949(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_valuation_r1949(date, text, bigint, text, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_grants_r1949(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_grant_r1949(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1949(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_valuation_r1949() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_grants_r1949(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_valuations_r1949(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_valuation_r1949(date, text, bigint, text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_grants_r1949(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_grant_r1949(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1949(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_valuation_r1949() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_grants_r1949(int) TO authenticated;

COMMIT;
