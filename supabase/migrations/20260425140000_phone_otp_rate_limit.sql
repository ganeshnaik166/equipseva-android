-- Phone OTP rate limiting.
-- Guards Twilio cost + abuse: 5 sends per phone-number per rolling hour.

CREATE TABLE IF NOT EXISTS public.phone_otp_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL,
  requested_at timestamptz NOT NULL DEFAULT now(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ip_hash text
);

CREATE INDEX IF NOT EXISTS idx_phone_otp_requests_phone_time
  ON public.phone_otp_requests(phone, requested_at DESC);

ALTER TABLE public.phone_otp_requests ENABLE ROW LEVEL SECURITY;
-- No SELECT/INSERT/UPDATE policies — only the SECURITY DEFINER RPC touches it.
REVOKE ALL ON TABLE public.phone_otp_requests FROM PUBLIC, authenticated, anon;

-- Returns null when caller may request, or the seconds-until-allowed if rate-limited.
-- Logging a successful "allowed" inside the same RPC means a caller can't probe
-- the rate-limit without consuming a slot — prevents enumeration.
CREATE OR REPLACE FUNCTION public.phone_otp_can_request(p_phone text)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  recent_count int;
  oldest_time timestamptz;
  WINDOW_HRS constant int := 1;
  MAX_PER_WINDOW constant int := 5;
BEGIN
  IF p_phone IS NULL OR length(trim(p_phone)) = 0 THEN
    RAISE EXCEPTION 'invalid_phone' USING ERRCODE='22023';
  END IF;

  SELECT count(*), min(requested_at)
    INTO recent_count, oldest_time
    FROM public.phone_otp_requests
   WHERE phone = p_phone
     AND requested_at > now() - (WINDOW_HRS || ' hour')::interval;

  IF recent_count >= MAX_PER_WINDOW THEN
    RETURN GREATEST(
      1,
      CEIL(EXTRACT(EPOCH FROM (oldest_time + (WINDOW_HRS || ' hour')::interval - now())))::int
    );
  END IF;

  INSERT INTO public.phone_otp_requests (phone, user_id)
  VALUES (p_phone, auth.uid());

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.phone_otp_can_request(text) TO authenticated, anon;
