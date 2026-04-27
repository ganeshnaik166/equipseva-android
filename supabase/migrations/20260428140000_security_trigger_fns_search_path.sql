-- Two trigger functions were missing `SET search_path` — that means a hostile
-- schema in the search_path could shadow `public.profiles` or
-- `public.buyer_kyc_verifications` and intercept the trigger's writes.
-- Pin search_path to public + pg_temp on both. No behaviour change otherwise.

CREATE OR REPLACE FUNCTION public._sync_buyer_kyc_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_status text;
BEGIN
    SELECT status INTO v_status
        FROM public.buyer_kyc_verifications
       WHERE user_id = NEW.user_id
       ORDER BY
         CASE status WHEN 'verified' THEN 0 WHEN 'pending' THEN 1 WHEN 'rejected' THEN 2 ELSE 3 END,
         submitted_at DESC
       LIMIT 1;
    IF v_status IS NULL THEN v_status := 'unsubmitted'; END IF;
    UPDATE public.profiles SET buyer_kyc_status = v_status, updated_at = now()
       WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public._sync_profile_roles()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.role IS NOT NULL THEN
        IF NEW.roles IS NULL OR NOT (NEW.role::text = ANY(NEW.roles)) THEN
            NEW.roles := array_append(coalesce(NEW.roles, ARRAY[]::text[]), NEW.role::text);
        END IF;
        IF NEW.active_role IS NULL THEN
            NEW.active_role := NEW.role::text;
        END IF;
    ELSIF NEW.active_role IS NOT NULL AND (NEW.roles IS NULL OR cardinality(NEW.roles) = 0) THEN
        NEW.roles := ARRAY[NEW.active_role];
    END IF;
    RETURN NEW;
END;
$$;
