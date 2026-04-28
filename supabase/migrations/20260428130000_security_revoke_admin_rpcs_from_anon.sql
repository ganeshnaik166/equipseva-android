-- Tighten EXECUTE on admin_* SECURITY DEFINER functions. Internal is_founder()
-- checks block actual privilege escalation, but unauthenticated callers
-- shouldn't even reach these. Revokes from anon + public; authenticated
-- keeps grant since the founder is authenticated.

REVOKE EXECUTE ON FUNCTION public.admin_categories_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_categories_upsert(text, text, text, int, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_categories_upsert(text, text, text, int, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_force_role_change(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_integrity_flags(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_pending_buyer_kyc() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_pending_engineers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_pending_reports() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_pending_seller_verifications() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_recent_catalog_imports(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_recent_payments(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_set_buyer_kyc_status(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_set_engineer_verification(uuid, text, text, text[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_set_org_verification(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_users_search(text, text, int, int) FROM PUBLIC, anon;
