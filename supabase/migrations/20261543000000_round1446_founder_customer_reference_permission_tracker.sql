BEGIN;
-- r1446 — founder customer reference + testimonial permission tracker
-- Tables: founder_customer_reference_permissions, founder_customer_reference_usage_events
-- RPCs (7): summary, recent permissions, recent usage, expiring soon, register, record usage, status change



CREATE TABLE IF NOT EXISTS public.founder_customer_reference_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reference_kind text NOT NULL CHECK (reference_kind IN ('pitch_deck_logo','website_logo','case_study','press_quote','video_testimonial','reference_call','social_media','speaking_engagement')),
  permission_status text NOT NULL DEFAULT 'not_requested' CHECK (permission_status IN ('not_requested','requested','granted','denied','expired','revoked')),
  permission_signed_by text,
  permission_signed_at timestamptz,
  permission_expires_at timestamptz,
  scope_text text,
  can_use_name boolean NOT NULL DEFAULT true,
  can_use_logo boolean NOT NULL DEFAULT false,
  can_use_metrics boolean NOT NULL DEFAULT false,
  can_use_quote boolean NOT NULL DEFAULT false,
  can_use_executive_attribution boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_frp_status ON public.founder_customer_reference_permissions(permission_status);
CREATE INDEX IF NOT EXISTS idx_frp_kind ON public.founder_customer_reference_permissions(reference_kind);
CREATE INDEX IF NOT EXISTS idx_frp_expires ON public.founder_customer_reference_permissions(permission_expires_at);
CREATE INDEX IF NOT EXISTS idx_frp_hospital ON public.founder_customer_reference_permissions(hospital_user_id);

CREATE TABLE IF NOT EXISTS public.founder_customer_reference_usage_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  permission_id uuid NOT NULL REFERENCES public.founder_customer_reference_permissions(id) ON DELETE CASCADE,
  usage_kind text NOT NULL CHECK (usage_kind IN ('pitch_meeting','website_publish','press_release','social_share','sales_call','webinar','demo_day','newsletter')),
  used_at timestamptz NOT NULL DEFAULT now(),
  context_summary text,
  used_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_frue_perm ON public.founder_customer_reference_usage_events(permission_id);
CREATE INDEX IF NOT EXISTS idx_frue_used_at ON public.founder_customer_reference_usage_events(used_at DESC);
CREATE INDEX IF NOT EXISTS idx_frue_kind ON public.founder_customer_reference_usage_events(usage_kind);

ALTER TABLE public.founder_customer_reference_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_customer_reference_usage_events ENABLE ROW LEVEL SECURITY;

-- RPC 1: summary (16 KPIs)
CREATE OR REPLACE FUNCTION public.founder_reference_permission_summary()
RETURNS TABLE (
  total_permissions bigint,
  not_requested_count bigint,
  requested_count bigint,
  granted_count bigint,
  denied_count bigint,
  expired_count bigint,
  revoked_count bigint,
  expiring_30d_count bigint,
  total_usage_events bigint,
  usage_last_30d bigint,
  pitch_deck_logo_granted bigint,
  website_logo_granted bigint,
  case_study_granted bigint,
  press_quote_granted bigint,
  video_testimonial_granted bigint,
  reference_call_granted bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_customer_reference_permissions),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'not_requested'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'requested'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'granted'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'denied'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'expired'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'revoked'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'granted' AND permission_expires_at IS NOT NULL AND permission_expires_at <= now() + interval '30 days' AND permission_expires_at > now()),
    (SELECT count(*) FROM public.founder_customer_reference_usage_events),
    (SELECT count(*) FROM public.founder_customer_reference_usage_events WHERE used_at >= now() - interval '30 days'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'granted' AND reference_kind = 'pitch_deck_logo'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'granted' AND reference_kind = 'website_logo'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'granted' AND reference_kind = 'case_study'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'granted' AND reference_kind = 'press_quote'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'granted' AND reference_kind = 'video_testimonial'),
    (SELECT count(*) FROM public.founder_customer_reference_permissions WHERE permission_status = 'granted' AND reference_kind = 'reference_call');
END;
$$;

REVOKE ALL ON FUNCTION public.founder_reference_permission_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_reference_permission_summary() TO authenticated;

-- RPC 2: recent permissions
CREATE OR REPLACE FUNCTION public.founder_reference_permissions_recent()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  reference_kind text,
  permission_status text,
  permission_signed_by text,
  permission_signed_at timestamptz,
  permission_expires_at timestamptz,
  scope_text text,
  can_use_name boolean,
  can_use_logo boolean,
  can_use_metrics boolean,
  can_use_quote boolean,
  can_use_executive_attribution boolean,
  notes text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT p.id, p.hospital_user_id, p.reference_kind, p.permission_status,
         p.permission_signed_by, p.permission_signed_at, p.permission_expires_at,
         p.scope_text, p.can_use_name, p.can_use_logo, p.can_use_metrics,
         p.can_use_quote, p.can_use_executive_attribution, p.notes,
         p.created_at, p.updated_at
  FROM public.founder_customer_reference_permissions p
  ORDER BY p.updated_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_reference_permissions_recent() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_reference_permissions_recent() TO authenticated;

-- RPC 3: recent usage events
CREATE OR REPLACE FUNCTION public.founder_reference_usage_events_recent()
RETURNS TABLE (
  id uuid,
  permission_id uuid,
  reference_kind text,
  permission_status text,
  usage_kind text,
  used_at timestamptz,
  context_summary text,
  used_by uuid,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT e.id, e.permission_id, p.reference_kind, p.permission_status,
         e.usage_kind, e.used_at, e.context_summary, e.used_by, e.created_at
  FROM public.founder_customer_reference_usage_events e
  LEFT JOIN public.founder_customer_reference_permissions p ON p.id = e.permission_id
  ORDER BY e.used_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_reference_usage_events_recent() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_reference_usage_events_recent() TO authenticated;

-- RPC 4: expiring soon (next 30d)
CREATE OR REPLACE FUNCTION public.founder_reference_permissions_expiring_soon()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  reference_kind text,
  permission_status text,
  permission_signed_by text,
  permission_expires_at timestamptz,
  days_until_expiry numeric,
  scope_text text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT p.id, p.hospital_user_id, p.reference_kind, p.permission_status,
         p.permission_signed_by, p.permission_expires_at,
         round(extract(epoch FROM (p.permission_expires_at - now())) / 86400.0, 1) AS days_until_expiry,
         p.scope_text
  FROM public.founder_customer_reference_permissions p
  WHERE p.permission_status = 'granted'
    AND p.permission_expires_at IS NOT NULL
    AND p.permission_expires_at > now()
    AND p.permission_expires_at <= now() + interval '30 days'
  ORDER BY p.permission_expires_at ASC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_reference_permissions_expiring_soon() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_reference_permissions_expiring_soon() TO authenticated;

-- RPC 5: register permission
CREATE OR REPLACE FUNCTION public.log_founder_reference_register_permission(
  p_hospital_user_id uuid,
  p_reference_kind text,
  p_scope_text text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  INSERT INTO public.founder_customer_reference_permissions (
    hospital_user_id, reference_kind, permission_status, scope_text, notes
  ) VALUES (
    p_hospital_user_id, p_reference_kind, 'requested', p_scope_text, p_notes
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_reference_register_permission(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_reference_register_permission(uuid, text, text, text) TO authenticated;

-- RPC 6: record usage
CREATE OR REPLACE FUNCTION public.log_founder_reference_record_usage(
  p_permission_id uuid,
  p_usage_kind text,
  p_context_summary text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  SELECT permission_status INTO v_status
  FROM public.founder_customer_reference_permissions
  WHERE id = p_permission_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'permission not found';
  END IF;

  IF v_status <> 'granted' THEN
    RAISE EXCEPTION 'cannot record usage: permission status is % (must be granted)', v_status;
  END IF;

  INSERT INTO public.founder_customer_reference_usage_events (
    permission_id, usage_kind, context_summary, used_by
  ) VALUES (
    p_permission_id, p_usage_kind, p_context_summary, auth.uid()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_reference_record_usage(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_reference_record_usage(uuid, text, text) TO authenticated;

-- RPC 7: status change
CREATE OR REPLACE FUNCTION public.log_founder_reference_status_change(
  p_permission_id uuid,
  p_new_status text,
  p_signed_by text DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_can_use_name boolean DEFAULT NULL,
  p_can_use_logo boolean DEFAULT NULL,
  p_can_use_metrics boolean DEFAULT NULL,
  p_can_use_quote boolean DEFAULT NULL,
  p_can_use_executive_attribution boolean DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  IF p_new_status NOT IN ('not_requested','requested','granted','denied','expired','revoked') THEN
    RAISE EXCEPTION 'invalid status: %', p_new_status;
  END IF;

  UPDATE public.founder_customer_reference_permissions
  SET permission_status = p_new_status,
      permission_signed_by = COALESCE(p_signed_by, permission_signed_by),
      permission_signed_at = CASE WHEN p_new_status = 'granted' AND permission_signed_at IS NULL THEN now() ELSE permission_signed_at END,
      permission_expires_at = COALESCE(p_expires_at, permission_expires_at),
      can_use_name = COALESCE(p_can_use_name, can_use_name),
      can_use_logo = COALESCE(p_can_use_logo, can_use_logo),
      can_use_metrics = COALESCE(p_can_use_metrics, can_use_metrics),
      can_use_quote = COALESCE(p_can_use_quote, can_use_quote),
      can_use_executive_attribution = COALESCE(p_can_use_executive_attribution, can_use_executive_attribution),
      updated_at = now()
  WHERE id = p_permission_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'permission not found';
  END IF;

  RETURN p_permission_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_reference_status_change(uuid, text, text, timestamptz, boolean, boolean, boolean, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_reference_status_change(uuid, text, text, timestamptz, boolean, boolean, boolean, boolean, boolean) TO authenticated;

COMMIT;