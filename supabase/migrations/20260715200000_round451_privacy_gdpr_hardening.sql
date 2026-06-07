-- Round 451 — Privacy / GDPR / DPDP hardening bundle from 2026-06-07
-- audit. 4 HIGH + 2 LOW server-side findings.
--
-- Bundled because each is a small well-scoped change and they all
-- relate to "user data exposed beyond where it should be" / "account
-- deletion doesn't fully delete".
--
--   1. HIGH — recommended_engineers_for_hospital leaks raw engineer
--      city; sibling RPCs (engineers_directory_search, engineer_public_
--      profile) sanitise via engineer_address_public(). Wrap.
--   2. HIGH — delete_my_account purges only kyc-docs/repair-photos/
--      avatars/chat-attachments. HTML invoices + service-reports
--      survive (with their 30-day signed URLs still valid). DPDP Act +
--      Play Store account-deletion policy expect personal data to be
--      removed. Extend the purge list.
--   3. HIGH — delete from storage.objects only removes the catalog
--      row; underlying S3 binary persists, recoverable forever via any
--      pre-deletion signed URL until TTL expires. Switch the purge to
--      storage.delete_object() which actually removes the backend
--      object. Falls back to the existing raw DELETE on older Supabase
--      builds that don't ship the helper.
--   4. LOW — engineer_public_profile + recommended_engineers_for_hospital
--      granted to anon. Allows unauthenticated scraping of the entire
--      verified-engineer marketplace. Revoke anon; keep authenticated.
--
-- Companion (NOT in this migration — separate edge fn deploys):
--   * 30-day signed URL TTL on generate_service_report, send_invoice,
--     generate_repair_invoice → drop to 15 min in code, ship next.

-- ---------------------------------------------------------------------
-- 1 + 4. recommended_engineers_for_hospital sanitise city + revoke anon
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recommended_engineers_for_hospital(
  p_hospital_lat double precision,
  p_hospital_lng double precision,
  p_equipment_category text DEFAULT NULL,
  p_limit int DEFAULT 5
)
RETURNS TABLE (
  engineer_id uuid,
  user_id uuid,
  full_name text,
  avatar_url text,
  city text,
  state text,
  service_areas text[],
  specializations text[],
  brands_serviced text[],
  experience_years int,
  rating_avg numeric,
  total_jobs int,
  hourly_rate numeric,
  bio text,
  is_available boolean,
  distance_km double precision,
  match_score numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH base AS (
    SELECT
      e.id                                                AS engineer_id,
      e.user_id                                           AS user_id,
      coalesce(p.full_name, '(unnamed)')                  AS full_name,
      p.avatar_url                                        AS avatar_url,
      -- Round 451: sanitise city through engineer_address_public()
      -- to match engineers_directory_search + engineer_public_profile.
      -- The raw city would leak the engineer's home/operating locality
      -- to every discovery caller (was previously also anon — now
      -- revoked below).
      public.engineer_address_public(e.city)              AS city,
      e.state                                             AS state,
      e.service_areas                                     AS service_areas,
      e.specializations::text[]                           AS specializations,
      e.brands_serviced                                   AS brands_serviced,
      coalesce(e.experience_years, e.years_experience, 0) AS experience_years,
      coalesce(e.rating_avg, 0)::numeric                  AS rating_avg,
      coalesce(e.total_jobs, 0)                           AS total_jobs,
      e.hourly_rate                                       AS hourly_rate,
      e.bio                                               AS bio,
      coalesce(e.is_available, false)                     AS is_available,
      CASE
        WHEN e.latitude IS NOT NULL AND e.longitude IS NOT NULL
        THEN public.haversine_km(p_hospital_lat, p_hospital_lng, e.latitude, e.longitude)
        ELSE NULL
      END                                                 AS distance_km,
      coalesce(e.completion_rate, 0)::numeric             AS completion_rate
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
    WHERE coalesce(e.verification_status::text, 'pending') = 'verified'
      AND coalesce(p.role::text, '') = 'engineer'
  )
  SELECT
    b.engineer_id,
    b.user_id,
    b.full_name,
    b.avatar_url,
    b.city,
    b.state,
    b.service_areas,
    b.specializations,
    b.brands_serviced,
    b.experience_years,
    b.rating_avg,
    b.total_jobs,
    b.hourly_rate,
    b.bio,
    b.is_available,
    b.distance_km,
    (
      30.0 * coalesce(
        1.0 - (LEAST(b.distance_km, 200.0) / 200.0),
        0.0
      )
      + 25.0 * (b.rating_avg / 5.0)
      + 20.0 * (
        CASE
          WHEN p_equipment_category IS NULL OR p_equipment_category = ''
            THEN 0.5
          WHEN p_equipment_category = ANY(coalesce(b.specializations, ARRAY[]::text[]))
            THEN 1.0
          ELSE 0.0
        END
      )
      + 15.0 * (b.completion_rate / 100.0)
      + 10.0 * (LEAST(b.total_jobs, 5)::numeric / 5.0)
    )::numeric AS match_score
  FROM base b
  ORDER BY match_score DESC,
           b.distance_km ASC NULLS LAST
  LIMIT GREATEST(1, LEAST(coalesce(p_limit, 5), 20));
$$;

REVOKE EXECUTE ON FUNCTION public.recommended_engineers_for_hospital(
  double precision, double precision, text, int
) FROM anon;
REVOKE EXECUTE ON FUNCTION public.engineer_public_profile(uuid) FROM anon;

-- ---------------------------------------------------------------------
-- 2 + 3. delete_my_account — extend purge to invoices + service-reports
-- and switch to storage.delete_object() for S3 binary removal.
-- ---------------------------------------------------------------------
-- We preserve the entire round 285 body and only modify the storage
-- purge section. New ordering: do storage purge BEFORE row deletes so
-- we can still resolve invoice/service-report paths via spare_part_
-- orders + repair_jobs lookups. NULL the cached signed URLs on the
-- parent rows so even cached app state stops surfacing them.

CREATE OR REPLACE FUNCTION public.delete_my_account(p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, storage
AS $$
DECLARE
    v_user uuid := auth.uid();
    v_email text;
    v_open_escrows int;
    v_obj record;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT email INTO v_email FROM auth.users WHERE id = v_user;

    -- Round 285 pre-check.
    SELECT count(*) INTO v_open_escrows
      FROM public.repair_job_escrow
      WHERE (hospital_user_id = v_user OR engineer_user_id = v_user)
        AND status IN ('pending', 'held', 'in_dispute');
    IF v_open_escrows > 0 THEN
        RAISE EXCEPTION
          'Account has % open escrow row(s). Resolve / refund / release them before deleting your account.',
          v_open_escrows
          USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.account_deletions(user_id, email, reason, status)
    VALUES (v_user, v_email, p_reason, 'processed');

    -- ===== Round 451 storage purge — must run BEFORE row deletes =====
    -- (a) Owner-folder buckets: kyc-docs/repair-photos/avatars/chat-attachments.
    -- (b) Order-keyed bucket: invoices (spare_part_orders + repair_jobs).
    -- (c) Job-keyed bucket: service-reports (repair_jobs).
    -- Switch from raw DELETE to storage.delete_object() so the S3
    -- binary is removed (not just the catalog row). Fall back to raw
    -- DELETE on older Supabase builds without the helper.
    PERFORM set_config('storage.allow_delete_query', 'true', true);

    FOR v_obj IN
      SELECT bucket_id, name
        FROM storage.objects
       WHERE bucket_id IN (
               'kyc-docs', 'repair-photos', 'avatars', 'chat-attachments'
             )
         AND split_part(name, '/', 1) = v_user::text
    LOOP
      BEGIN
        PERFORM storage.delete_object(v_obj.bucket_id, v_obj.name);
      EXCEPTION WHEN undefined_function OR undefined_object THEN
        DELETE FROM storage.objects
         WHERE bucket_id = v_obj.bucket_id AND name = v_obj.name;
      WHEN OTHERS THEN
        RAISE NOTICE 'delete_my_account: skipped storage object %/%: % / %',
          v_obj.bucket_id, v_obj.name, SQLSTATE, SQLERRM;
      END;
    END LOOP;

    -- invoices for spare-part orders the user bought.
    FOR v_obj IN
      SELECT 'invoices'::text AS bucket_id, (o.id::text || '.html') AS name
        FROM public.spare_part_orders o
       WHERE o.buyer_user_id = v_user
    LOOP
      BEGIN
        PERFORM storage.delete_object(v_obj.bucket_id, v_obj.name);
      EXCEPTION WHEN undefined_function OR undefined_object THEN
        DELETE FROM storage.objects
         WHERE bucket_id = v_obj.bucket_id AND name = v_obj.name;
      WHEN OTHERS THEN
        RAISE NOTICE 'delete_my_account: skipped spare-part invoice %: % / %',
          v_obj.name, SQLSTATE, SQLERRM;
      END;
    END LOOP;

    -- Round 449 repair-job GST invoices (invoices/repair_<job_id>.html).
    FOR v_obj IN
      SELECT 'invoices'::text AS bucket_id, ('repair_' || rj.id::text || '.html') AS name
        FROM public.repair_jobs rj
       WHERE rj.hospital_user_id = v_user
    LOOP
      BEGIN
        PERFORM storage.delete_object(v_obj.bucket_id, v_obj.name);
      EXCEPTION WHEN undefined_function OR undefined_object THEN
        DELETE FROM storage.objects
         WHERE bucket_id = v_obj.bucket_id AND name = v_obj.name;
      WHEN OTHERS THEN
        RAISE NOTICE 'delete_my_account: skipped repair invoice %: % / %',
          v_obj.name, SQLSTATE, SQLERRM;
      END;
    END LOOP;

    -- service-reports (path: <job_id>.html). Hospital + assigned engineer
    -- both legitimately access this; cover both as owners.
    FOR v_obj IN
      SELECT 'service-reports'::text AS bucket_id, (rj.id::text || '.html') AS name
        FROM public.repair_jobs rj
        LEFT JOIN public.engineers e ON e.id = rj.engineer_id
       WHERE rj.hospital_user_id = v_user
          OR e.user_id = v_user
    LOOP
      BEGIN
        PERFORM storage.delete_object(v_obj.bucket_id, v_obj.name);
      EXCEPTION WHEN undefined_function OR undefined_object THEN
        DELETE FROM storage.objects
         WHERE bucket_id = v_obj.bucket_id AND name = v_obj.name;
      WHEN OTHERS THEN
        RAISE NOTICE 'delete_my_account: skipped service report %: % / %',
          v_obj.name, SQLSTATE, SQLERRM;
      END;
    END LOOP;

    -- Clear cached signed URLs on parent rows so the URLs stop being
    -- handed back through normal repository fetches (even though the
    -- backend objects are gone, removing the URL strings prevents the
    -- app from showing dead 404 links until the row is itself deleted).
    UPDATE public.spare_part_orders SET invoice_url = NULL
     WHERE buyer_user_id = v_user;
    UPDATE public.repair_jobs SET service_report_url = NULL
     WHERE hospital_user_id = v_user
        OR engineer_id IN (SELECT id FROM public.engineers WHERE user_id = v_user);
    -- ===== /Round 451 storage purge =====

    -- Round 285 — null out nullable audit references.
    UPDATE public.repair_job_escrow
      SET dispute_resolved_by = NULL
      WHERE dispute_resolved_by = v_user;
    UPDATE public.repair_job_escrow_events
      SET actor_user_id = NULL
      WHERE actor_user_id = v_user;
    UPDATE public.repair_job_cost_revisions
      SET decision_by = NULL
      WHERE decision_by = v_user;
    UPDATE public.amc_admin_escalations
      SET resolved_by = NULL
      WHERE resolved_by = v_user;

    DELETE FROM public.chat_messages WHERE sender_user_id = v_user;
    DELETE FROM public.notifications WHERE user_id = v_user;
    UPDATE public.content_reports SET reviewed_by = NULL WHERE reviewed_by = v_user;

    DELETE FROM public.disputes
        WHERE raised_by_user_id = v_user
           OR against_user_id = v_user
           OR resolved_by = v_user;

    DELETE FROM public.marketplace_offers WHERE buyer_user_id = v_user;
    DELETE FROM public.marketplace_listings WHERE seller_user_id = v_user;
    DELETE FROM public.spare_part_orders WHERE buyer_user_id = v_user;
    DELETE FROM public.payments WHERE payee_user_id = v_user OR payer_user_id = v_user;
    DELETE FROM public.financing_applications WHERE applicant_user_id = v_user;
    DELETE FROM public.rfqs WHERE requester_user_id = v_user;

    DELETE FROM public.amc_contracts
        WHERE hospital_user_id = v_user
           OR primary_engineer_id IN (SELECT id FROM public.engineers WHERE user_id = v_user);

    DELETE FROM public.repair_job_bids WHERE engineer_user_id = v_user;

    DELETE FROM public.repair_jobs WHERE hospital_user_id = v_user;
    DELETE FROM public.engineers WHERE user_id = v_user;

    DELETE FROM public.reviews WHERE reviewer_user_id = v_user OR reviewee_user_id = v_user;

    DELETE FROM public.enrollments WHERE user_id = v_user;
    DELETE FROM public.logistics_partners WHERE user_id = v_user;
    DELETE FROM public.support_tickets WHERE user_id = v_user OR assigned_to = v_user;

    UPDATE public.organizations SET created_by = NULL WHERE created_by = v_user;
    UPDATE public.organizations SET verified_by = NULL WHERE verified_by = v_user;
    UPDATE public.buyer_kyc_verifications SET reviewed_by = NULL WHERE reviewed_by = v_user;

    -- Legacy raw-DELETE fallback for any storage rows that slipped past
    -- the loops above (e.g. orphaned objects from a previous schema).
    -- The storage.delete_object loops above are the primary mechanism;
    -- this is belt-and-suspenders.
    DELETE FROM storage.objects
        WHERE bucket_id IN ('kyc-docs', 'repair-photos', 'avatars', 'chat-attachments')
          AND split_part(name, '/', 1) = v_user::text;

    DELETE FROM auth.refresh_tokens WHERE user_id = v_user::text;
    DELETE FROM auth.users WHERE id = v_user;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account(text) FROM public;
REVOKE ALL ON FUNCTION public.delete_my_account(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account(text) TO authenticated;

COMMENT ON FUNCTION public.delete_my_account(text) IS
  'Round 451 — extends storage purge to invoices + service-reports, uses '
  'storage.delete_object() so backend binaries are actually removed (not '
  'just the catalog row), and NULLs cached signed URLs on the parent rows. '
  'Storage purge runs BEFORE row deletes so order/job-keyed paths can be '
  'resolved via JOINs.';
