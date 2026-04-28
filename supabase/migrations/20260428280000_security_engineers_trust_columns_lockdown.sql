-- engineers had the default "all columns" INSERT/UPDATE grant for
-- authenticated. Same forgery surface as the organizations bug just
-- closed:
--   - verification_status: engineer self-flips to 'verified' and shows
--     up on the engineer directory + can take jobs without ever doing
--     KYC docs
--   - aadhaar_verified: engineer marks their own Aadhaar verified
--   - rating_avg / total_jobs / completion_rate / total_earnings:
--     engineer boosts their own stats to look more attractive on the
--     directory listing
--   - background_check_status / verification_notes / rejected_doc_types:
--     audit columns the admin uses; engineer could overwrite a real
--     rejection with "all clear"
--
-- Lock down: revoke table-level INSERT/UPDATE from authenticated, then
-- re-grant only the user-controllable columns. Trust + computed
-- columns stay admin / service_role / SECURITY DEFINER writeable.
-- admin_set_engineer_verification RPC already covers the verify path.
-- Trigger-driven aggregates (rating_avg etc) write via service_role,
-- so they're unaffected.

REVOKE INSERT, UPDATE ON public.engineers FROM anon, authenticated;

-- INSERT allow-list. user_id is included only here so the row's
-- identity gets written on creation; the policy WITH CHECK
-- (auth.uid() = user_id) keeps it scoped.
GRANT INSERT (
    user_id,
    aadhaar_number, pan_number,
    qualifications, certificates, specializations, brands_serviced,
    oem_training_badges,
    experience_years, years_experience,
    service_radius_km, service_areas,
    latitude, longitude, city, state,
    is_available, available_from, available_to,
    hourly_rate, bio,
    bank_account_number, bank_ifsc, upi_id
) ON public.engineers TO authenticated;

-- UPDATE allow-list. user_id intentionally omitted — row identity is
-- immutable post-creation. Same with id / created_at / updated_at.
GRANT UPDATE (
    aadhaar_number, pan_number,
    qualifications, certificates, specializations, brands_serviced,
    oem_training_badges,
    experience_years, years_experience,
    service_radius_km, service_areas,
    latitude, longitude, city, state,
    is_available, available_from, available_to,
    hourly_rate, bio,
    bank_account_number, bank_ifsc, upi_id
) ON public.engineers TO authenticated;
