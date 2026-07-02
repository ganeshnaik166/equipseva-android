BEGIN;

-- ============================================================================
-- Round 1833: Investor Communication Channel Preference
-- ============================================================================

-- Preferences table
CREATE TABLE IF NOT EXISTS public.investor_comm_preferences_r1833 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  preferred_channel text NOT NULL CHECK (preferred_channel IN ('email','whatsapp','sms','phone','in_person')),
  preferred_frequency text NOT NULL CHECK (preferred_frequency IN ('weekly','biweekly','monthly','quarterly','annual_only')),
  do_not_contact_days_of_week int[] NOT NULL DEFAULT '{}',
  time_zone text NOT NULL DEFAULT 'Asia/Kolkata',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','opted_out')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icp_r1833_investor ON public.investor_comm_preferences_r1833(investor_id);
CREATE INDEX IF NOT EXISTS idx_icp_r1833_status ON public.investor_comm_preferences_r1833(status);
CREATE INDEX IF NOT EXISTS idx_icp_r1833_channel ON public.investor_comm_preferences_r1833(preferred_channel);

ALTER TABLE public.investor_comm_preferences_r1833 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS icp_r1833_founder_all ON public.investor_comm_preferences_r1833;
CREATE POLICY icp_r1833_founder_all ON public.investor_comm_preferences_r1833
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.investor_comm_preferences_r1833 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.investor_comm_preferences_r1833 TO authenticated;

-- Consent log table
CREATE TABLE IF NOT EXISTS public.investor_comm_consent_log_r1833 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  preference_id uuid NOT NULL REFERENCES public.investor_comm_preferences_r1833(id) ON DELETE CASCADE,
  consent_type text NOT NULL CHECK (consent_type IN ('marketing','transactional','legal_notice','event_invite')),
  granted boolean NOT NULL,
  granted_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  source text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iccl_r1833_pref ON public.investor_comm_consent_log_r1833(preference_id);
CREATE INDEX IF NOT EXISTS idx_iccl_r1833_type ON public.investor_comm_consent_log_r1833(consent_type);
CREATE INDEX IF NOT EXISTS idx_iccl_r1833_expires ON public.investor_comm_consent_log_r1833(expires_at);

ALTER TABLE public.investor_comm_consent_log_r1833 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iccl_r1833_founder_all ON public.investor_comm_consent_log_r1833;
CREATE POLICY iccl_r1833_founder_all ON public.investor_comm_consent_log_r1833
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.investor_comm_consent_log_r1833 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.investor_comm_consent_log_r1833 TO authenticated;

-- ============================================================================
-- RPC 1: list_preferences
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_preferences_r1833(int);
CREATE OR REPLACE FUNCTION public.list_preferences_r1833(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  preferred_channel text,
  preferred_frequency text,
  do_not_contact_days_of_week int[],
  time_zone text,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.investor_id, pr.email::text, p.preferred_channel, p.preferred_frequency,
           p.do_not_contact_days_of_week, p.time_zone, p.status, p.created_at
    FROM public.investor_comm_preferences_r1833 p
    LEFT JOIN public.profiles pr ON pr.id = p.investor_id
    ORDER BY p.created_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 1000));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_preferences_r1833(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_preferences_r1833(int) TO authenticated;

-- ============================================================================
-- RPC 2: set_preference
-- ============================================================================
DROP FUNCTION IF EXISTS public.set_preference_r1833(uuid, text, text, int[], text, text);
CREATE OR REPLACE FUNCTION public.set_preference_r1833(
  p_investor_id uuid,
  p_channel text,
  p_frequency text,
  p_dnd_days int[] DEFAULT '{}',
  p_time_zone text DEFAULT 'Asia/Kolkata',
  p_status text DEFAULT 'active'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_comm_preferences_r1833
    (investor_id, preferred_channel, preferred_frequency, do_not_contact_days_of_week, time_zone, status)
  VALUES
    (p_investor_id, p_channel, p_frequency, COALESCE(p_dnd_days, '{}'), p_time_zone, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1833.set_preference',
    jsonb_build_object(
      'preference_id', v_id,
      'investor_id', p_investor_id,
      'channel', p_channel,
      'frequency', p_frequency,
      'status', p_status
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_preference_r1833(uuid, text, text, int[], text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_preference_r1833(uuid, text, text, int[], text, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_consents
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_consents_r1833(uuid, int);
CREATE OR REPLACE FUNCTION public.list_consents_r1833(p_preference_id uuid DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  preference_id uuid,
  investor_id uuid,
  consent_type text,
  granted boolean,
  granted_at timestamptz,
  expires_at timestamptz,
  source text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.preference_id, p.investor_id, c.consent_type, c.granted,
           c.granted_at, c.expires_at, c.source
    FROM public.investor_comm_consent_log_r1833 c
    JOIN public.investor_comm_preferences_r1833 p ON p.id = c.preference_id
    WHERE p_preference_id IS NULL OR c.preference_id = p_preference_id
    ORDER BY c.granted_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 1000));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_consents_r1833(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_consents_r1833(uuid, int) TO authenticated;

-- ============================================================================
-- RPC 4: log_consent
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_consent_r1833(uuid, text, boolean, timestamptz, text);
CREATE OR REPLACE FUNCTION public.log_consent_r1833(
  p_preference_id uuid,
  p_consent_type text,
  p_granted boolean,
  p_expires_at timestamptz DEFAULT NULL,
  p_source text DEFAULT 'founder_console'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_comm_consent_log_r1833
    (preference_id, consent_type, granted, expires_at, source)
  VALUES
    (p_preference_id, p_consent_type, p_granted, p_expires_at, p_source)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1833.log_consent',
    jsonb_build_object(
      'consent_id', v_id,
      'preference_id', p_preference_id,
      'consent_type', p_consent_type,
      'granted', p_granted
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_consent_r1833(uuid, text, boolean, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_consent_r1833(uuid, text, boolean, timestamptz, text) TO authenticated;

-- ============================================================================
-- RPC 5: top_channels
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_channels_r1833();
CREATE OR REPLACE FUNCTION public.top_channels_r1833()
RETURNS TABLE(
  preferred_channel text,
  investor_count int,
  active_count int,
  opted_out_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.preferred_channel,
      COUNT(*)::int AS investor_count,
      (COUNT(*) FILTER (WHERE p.status = 'active'))::int AS active_count,
      (COUNT(*) FILTER (WHERE p.status = 'opted_out'))::int AS opted_out_count
    FROM public.investor_comm_preferences_r1833 p
    GROUP BY p.preferred_channel
    ORDER BY investor_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_channels_r1833() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_channels_r1833() TO authenticated;

-- ============================================================================
-- RPC 6: opt_out_investors
-- ============================================================================
DROP FUNCTION IF EXISTS public.opt_out_investors_r1833(int);
CREATE OR REPLACE FUNCTION public.opt_out_investors_r1833(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  preferred_channel text,
  status text,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.investor_id, pr.email::text, p.preferred_channel, p.status, p.updated_at
    FROM public.investor_comm_preferences_r1833 p
    LEFT JOIN public.profiles pr ON pr.id = p.investor_id
    WHERE p.status = 'opted_out'
    ORDER BY p.updated_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 1000));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.opt_out_investors_r1833(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.opt_out_investors_r1833(int) TO authenticated;

-- ============================================================================
-- RPC 7: expiring_consents
-- ============================================================================
DROP FUNCTION IF EXISTS public.expiring_consents_r1833(int);
CREATE OR REPLACE FUNCTION public.expiring_consents_r1833(p_days int DEFAULT 30)
RETURNS TABLE(
  id uuid,
  preference_id uuid,
  investor_id uuid,
  investor_email text,
  consent_type text,
  granted boolean,
  expires_at timestamptz,
  days_remaining int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      c.id,
      c.preference_id,
      p.investor_id,
      pr.email::text,
      c.consent_type,
      c.granted,
      c.expires_at,
      EXTRACT(DAY FROM (c.expires_at - now()))::int AS days_remaining
    FROM public.investor_comm_consent_log_r1833 c
    JOIN public.investor_comm_preferences_r1833 p ON p.id = c.preference_id
    LEFT JOIN public.profiles pr ON pr.id = p.investor_id
    WHERE c.expires_at IS NOT NULL
      AND c.expires_at > now()
      AND c.expires_at <= now() + (p_days || ' days')::interval
    ORDER BY c.expires_at ASC
    LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.expiring_consents_r1833(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_consents_r1833(int) TO authenticated;

COMMIT;