-- Round 419 — profile state + district columns for the v0.2.0 onboarding gate.
--
-- The v0.2.0 hospital admin flow (and a follow-up engineer onboarding step)
-- captures the user's state + district mandatorily right after sign-up so
-- the directory / matching can sort + filter on geography from day one.
-- Today's `organizations.{city,state}` only fires for hospital-org admins,
-- and the engineer side keeps geography on the lat/lng-only engineer row.
-- Both make the directory sort harder than it needs to be and force two
-- different code paths.
--
-- This migration adds two nullable text columns directly on `profiles`:
--   * state    — picked from IndiaLocations.STATES on the client (closed list)
--   * district — picked from IndiaLocations.DISTRICTS_BY_STATE on the client
--                (Telangana fully covered; other states fall back to text)
--
-- Length capped at 64 chars (server-side defence; the longest Indian
-- district name is ~40 chars). Existing self-update RLS already permits
-- the user to write these columns — no new policy needed.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS state    text,
  ADD COLUMN IF NOT EXISTS district text;

-- Length caps — match the IndiaLocations bundled-data ceiling.
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_state_len_chk
    CHECK (state    IS NULL OR length(state)    BETWEEN 1 AND 64),
  ADD CONSTRAINT profiles_district_len_chk
    CHECK (district IS NULL OR length(district) BETWEEN 1 AND 64);

COMMENT ON COLUMN public.profiles.state    IS
  'Indian state / UT (free text, client picks from IndiaLocations.STATES). '
  'v0.2.0 mandatory at hospital onboarding; nullable for legacy rows.';
COMMENT ON COLUMN public.profiles.district IS
  'District within state (free text, client picks from IndiaLocations '
  'cascade when available, falls back to text input). v0.2.0 mandatory '
  'at hospital onboarding; nullable for legacy rows.';
