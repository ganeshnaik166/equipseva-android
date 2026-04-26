-- S6: Mass catalog seed (catalog_devices + catalog_brands).
--
-- Backs the marketplace's "Request a quote" rail. Real device + brand names
-- come from public APIs (primarily OpenFDA via the ingest_openfda edge
-- function). Listings here are NOT yet for sale — they ship with no price
-- and a "Request quote" CTA that auto-creates an RFQ routed to verified
-- suppliers.

CREATE TABLE IF NOT EXISTS public.catalog_brands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL,
  country text,
  logo_url text,
  manufacturer_count int NOT NULL DEFAULT 0,
  source text NOT NULL DEFAULT 'openfda',
  ingested_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT catalog_brands_slug_unique UNIQUE (slug)
);

CREATE INDEX IF NOT EXISTS catalog_brands_name_lower_idx
  ON public.catalog_brands (lower(name));

ALTER TABLE public.catalog_brands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS catalog_brands_public_read ON public.catalog_brands;
CREATE POLICY catalog_brands_public_read
  ON public.catalog_brands FOR SELECT TO authenticated, anon
  USING (true);
-- Writes happen only via service-role / SECURITY DEFINER RPCs below.

CREATE TABLE IF NOT EXISTS public.catalog_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  openfda_id text UNIQUE,
  generic_name text NOT NULL,
  brand_name text,
  brand_id uuid REFERENCES public.catalog_brands(id) ON DELETE SET NULL,
  manufacturer text,
  product_code text,
  gmdn_code text,
  risk_class text,
  category_key text REFERENCES public.equipment_categories(key) ON DELETE SET NULL,
  description text,
  image_url text,
  source text NOT NULL DEFAULT 'openfda',
  source_url text,
  ingested_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS catalog_devices_brand_idx
  ON public.catalog_devices (brand_id);

CREATE INDEX IF NOT EXISTS catalog_devices_category_idx
  ON public.catalog_devices (category_key);

CREATE INDEX IF NOT EXISTS catalog_devices_search_idx
  ON public.catalog_devices USING gin (
    to_tsvector('simple', coalesce(generic_name, '') || ' ' || coalesce(brand_name, '') || ' ' || coalesce(manufacturer, ''))
  );

ALTER TABLE public.catalog_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS catalog_devices_public_read ON public.catalog_devices;
CREATE POLICY catalog_devices_public_read
  ON public.catalog_devices FOR SELECT TO authenticated, anon
  USING (true);
-- Writes via service role only (ingest edge function uses service-role key).

-- Founder admin RPCs.

CREATE OR REPLACE FUNCTION public.admin_recent_catalog_imports(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  generic_name text,
  brand_name text,
  manufacturer text,
  category_key text,
  source text,
  ingested_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT d.id, d.generic_name, d.brand_name, d.manufacturer,
           d.category_key, d.source, d.ingested_at
      FROM public.catalog_devices d
     ORDER BY d.ingested_at DESC
     LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_recent_catalog_imports(int) TO authenticated;

-- Public-facing search RPC. Returns paginated catalog rows. The marketplace
-- merges this with real `spare_parts` listings to render the mixed feed.
CREATE OR REPLACE FUNCTION public.catalog_devices_search(
  p_query text DEFAULT NULL,
  p_category_key text DEFAULT NULL,
  p_brand_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  generic_name text,
  brand_name text,
  brand_id uuid,
  manufacturer text,
  category_key text,
  image_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT d.id, d.generic_name, d.brand_name, d.brand_id, d.manufacturer,
         d.category_key, d.image_url
    FROM public.catalog_devices d
   WHERE (p_query IS NULL
          OR p_query = ''
          OR d.generic_name ILIKE '%' || p_query || '%'
          OR d.brand_name ILIKE '%' || p_query || '%'
          OR d.manufacturer ILIKE '%' || p_query || '%')
     AND (p_category_key IS NULL OR d.category_key = p_category_key)
     AND (p_brand_id IS NULL OR d.brand_id = p_brand_id)
   ORDER BY d.ingested_at DESC
   LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
   OFFSET greatest(0, coalesce(p_offset, 0));
$$;
GRANT EXECUTE ON FUNCTION public.catalog_devices_search(text, text, uuid, int, int) TO authenticated, anon;

-- Brand list for the filter chip / dropdown.
CREATE OR REPLACE FUNCTION public.catalog_brands_list()
RETURNS TABLE (
  id uuid,
  name text,
  slug text,
  country text,
  logo_url text,
  manufacturer_count int
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT id, name, slug, country, logo_url, manufacturer_count
    FROM public.catalog_brands
   WHERE manufacturer_count > 0
   ORDER BY manufacturer_count DESC, name;
$$;
GRANT EXECUTE ON FUNCTION public.catalog_brands_list() TO authenticated, anon;
