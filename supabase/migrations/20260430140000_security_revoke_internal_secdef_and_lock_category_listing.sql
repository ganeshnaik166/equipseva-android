-- Two unrelated-but-small security gaps surfaced by the Supabase advisor on
-- 2026-04-30, bundled into one migration because each is one-line scope:
--
-- 1) Anon and authenticated roles can `EXECUTE` 13 SECURITY DEFINER trigger
--    handlers via PostgREST. They are never meant to be REST-callable —
--    they fire from row-level triggers in the trigger context, where
--    Postgres applies SECURITY DEFINER regardless of grants. Exposing them
--    to roles only widens attack surface (e.g. a bug in a notify_* handler
--    becomes directly invokable from the client). Revoke EXECUTE.
--
--    Functions covered (all SECURITY DEFINER, all trigger handlers or
--    private `_*` helpers):
--      _link_catalog_devices_to_brands
--      _sync_buyer_kyc_status
--      _sync_profile_roles
--      handle_new_user
--      notify_on_chat_message
--      notify_on_engineer_kyc_status_change
--      notify_on_order_shipped
--      notify_on_repair_bid
--      notify_on_repair_bid_status_change
--      notify_on_repair_job_cancelled
--      notify_on_rfq_bid_accepted
--      sync_profile_verified_from_auth
--      sync_profile_verified_on_insert
--
--    Other SECURITY DEFINER functions in public (admin_*, accept_repair_bid,
--    delete_my_account, export_my_data, is_admin, is_founder, etc.) are
--    intentional public RPCs and remain callable.
--
-- 2) `category-images` storage bucket has a SELECT RLS policy
--    (`category_images_public_read`) that allows any role to enumerate
--    objects via the storage list API. The bucket itself is `public=true`
--    so files remain readable through the CDN public URL — only the
--    `/storage/v1/object/list/category-images/` enumeration path needs
--    blocking. App code only calls `publicUrl()` (StorageRepository.kt),
--    never `list()`, so dropping the SELECT policy is safe.

-- (1) Revoke EXECUTE on internal SECDEF trigger handlers
REVOKE EXECUTE ON FUNCTION public._link_catalog_devices_to_brands()       FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._sync_buyer_kyc_status()                FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._sync_profile_roles()                   FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()                       FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_chat_message()                FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_engineer_kyc_status_change()  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_order_shipped()               FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_repair_bid()                  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_repair_bid_status_change()    FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_repair_job_cancelled()        FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_rfq_bid_accepted()            FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_profile_verified_from_auth()       FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_profile_verified_on_insert()       FROM anon, authenticated;

-- (2) Drop public list-objects policy on category-images. Public reads via
-- CDN URL still work; only enumeration via storage API is blocked.
DROP POLICY IF EXISTS category_images_public_read ON storage.objects;
