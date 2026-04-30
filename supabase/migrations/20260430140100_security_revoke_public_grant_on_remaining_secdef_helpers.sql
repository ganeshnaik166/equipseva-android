-- Six SECDEF trigger handlers were still callable by anon/authenticated
-- after the prior REVOKE migration (20260430140000). Cause: the GRANT was
-- on `PUBLIC` (Postgres default for new functions), and
-- `REVOKE EXECUTE ... FROM <role>` does NOT strip a `PUBLIC` grant — the
-- role-level revoke is overridden by the inherited PUBLIC grant.
--
-- Drop EXECUTE from PUBLIC so only the function owner (postgres) and
-- explicitly-granted roles can call them. Triggers still fire (Postgres
-- applies SECURITY DEFINER inside the trigger context regardless of
-- caller-role grants), so signup, profile-role sync, and buyer-KYC sync
-- continue to work end-to-end.

REVOKE EXECUTE ON FUNCTION public._link_catalog_devices_to_brands()    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public._sync_buyer_kyc_status()             FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public._sync_profile_roles()                FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()                    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.sync_profile_verified_from_auth()    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.sync_profile_verified_on_insert()    FROM PUBLIC;
