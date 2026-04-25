-- App admin config table — currently holds the founder's email so rotation
-- doesn't require a code redeploy. Same RLS-locked-singleton pattern as
-- _app_invoice_config: no policies, only SECURITY DEFINER functions read.

CREATE TABLE IF NOT EXISTS public._app_admin_config (
  id text PRIMARY KEY DEFAULT 'singleton',
  founder_email text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (id = 'singleton')
);

ALTER TABLE public._app_admin_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public._app_admin_config FROM PUBLIC, authenticated, anon;

INSERT INTO public._app_admin_config (id, founder_email)
VALUES ('singleton', 'ganesh1431.dhanavath@gmail.com')
ON CONFLICT (id) DO NOTHING;

-- is_founder() now reads from the config table; falls back to the literal so
-- a misconfigured deploy doesn't lock the founder out.
CREATE OR REPLACE FUNCTION public.is_founder()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text := lower(coalesce(nullif(auth.jwt() ->> 'email', ''), ''));
  v_configured text;
BEGIN
  SELECT lower(founder_email) INTO v_configured
    FROM public._app_admin_config WHERE id = 'singleton';
  IF v_configured IS NULL OR v_configured = '' THEN
    v_configured := 'ganesh1431.dhanavath@gmail.com';
  END IF;
  RETURN v_email = v_configured;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_founder() TO authenticated;

-- Lightweight RPC the client can call to check its own founder status.
CREATE OR REPLACE FUNCTION public.is_caller_founder()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.is_founder();
$$;

GRANT EXECUTE ON FUNCTION public.is_caller_founder() TO authenticated;
