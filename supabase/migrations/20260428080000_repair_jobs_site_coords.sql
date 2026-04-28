-- Hospital-side site coordinates so engineer's Navigate button can open
-- Google Maps directly to the lat/lng instead of asking Maps to geocode the
-- free-text address. Both nullable so existing rows stay valid.

ALTER TABLE public.repair_jobs
    ADD COLUMN IF NOT EXISTS site_latitude  double precision,
    ADD COLUMN IF NOT EXISTS site_longitude double precision;
