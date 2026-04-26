// ingest_openfda
//
// Pulls medical-device + 510k clearance rows from OpenFDA's public API
// (api.fda.gov, no key required) and upserts them into:
//   - public.catalog_devices (one row per unique generic_name + brand_name)
//   - public.catalog_brands  (one row per unique manufacturer name, slug-keyed)
//
// Designed to be idempotent — re-running picks up where it left off via the
// `skip` cursor. Pages of 100 at a time. Rate-limited at 1 req/250ms to stay
// well under the unauthenticated quota (240 req/min).
//
// Triggered manually via mcp__supabase__deploy_edge_function then invoked
// from the Founder admin or via curl. Pass ?max=N to cap the number of rows
// inserted in one run; default 5000.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const OPENFDA_BASE =
  'https://api.fda.gov/device/registrationlisting.json?limit=100&skip=';
const RATE_LIMIT_MS = 260;

interface FdaProduct {
  product_code?: string;
  openfda?: {
    device_name?: string;
    medical_specialty_description?: string;
    device_class?: string;
    regulation_number?: string;
    fei_number?: string[];
    registration_number?: string[];
  };
}

interface FdaRow {
  proprietary_name?: string;
  establishment_type?: string[];
  fei_number?: string;
  initial_importer_flag?: string;
  reg_expiration_date_year?: string;
  registration?: {
    name?: string;
    iso_country_code?: string;
    fei_number?: string;
  };
  products?: FdaProduct[];
}

interface FdaResponse {
  meta?: { results?: { skip?: number; limit?: number; total?: number } };
  results?: FdaRow[];
}

function slugify(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 96);
}

// Maps an OpenFDA medical_specialty_description to one of our
// equipment_categories.key values. Anything unmapped lands in `other`.
function categoryForSpecialty(s?: string): string | null {
  if (!s) return null;
  const t = s.toLowerCase();
  if (t.includes('radiolog') || t.includes('imaging')) return 'imaging_radiology';
  if (t.includes('cardiov')) return 'cardiology';
  if (t.includes('anesthe') || t.includes('respir')) return 'life_support';
  if (t.includes('neurol')) return 'patient_monitoring';
  if (t.includes('dental')) return 'dental';
  if (t.includes('ophthalm')) return 'ophthalmology';
  if (t.includes('physical') || t.includes('rehab')) return 'physiotherapy';
  if (t.includes('obstet') || t.includes('gyne') || t.includes('pediat')) return 'neonatal';
  if (t.includes('hospital') && t.includes('general')) return 'hospital_furniture';
  if (t.includes('renal') || t.includes('kidney')) return 'dialysis';
  if (t.includes('oncolog')) return 'oncology';
  if (t.includes('ear') || t.includes('nose') || t.includes('throat')) return 'ent';
  if (t.includes('clinical') || t.includes('lab') || t.includes('chemistry')) return 'laboratory';
  if (t.includes('surger') || t.includes('orthoped')) return 'surgical';
  if (t.includes('steril')) return 'sterilization';
  return 'other';
}

interface DeviceUpsert {
  openfda_id: string;
  generic_name: string;
  brand_name?: string | null;
  manufacturer?: string | null;
  product_code?: string | null;
  risk_class?: string | null;
  category_key?: string | null;
  description?: string | null;
  source: string;
  source_url: string;
}

interface BrandUpsert {
  name: string;
  slug: string;
  country?: string | null;
  source: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('method_not_allowed', { status: 405 });
  }

  const url = new URL(req.url);
  const maxRows = Number(url.searchParams.get('max') ?? '5000');
  const startSkip = Number(url.searchParams.get('skip') ?? '0');

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  let skip = startSkip;
  let pulled = 0;
  let upserted = 0;
  const brandCounts = new Map<string, { name: string; country?: string; count: number }>();

  while (pulled < maxRows) {
    const resp = await fetch(OPENFDA_BASE + skip);
    if (!resp.ok) {
      const text = await resp.text();
      return new Response(JSON.stringify({ error: 'openfda_failed', status: resp.status, body: text.slice(0, 400) }), {
        status: 502,
        headers: { 'content-type': 'application/json' },
      });
    }
    const json: FdaResponse = await resp.json();
    const rows = json.results ?? [];
    if (rows.length === 0) break;

    const deviceBatch: DeviceUpsert[] = [];

    for (const row of rows) {
      const products = row.products ?? [];
      const manufacturer = row.registration?.name?.trim();
      const country = row.registration?.iso_country_code;
      if (!manufacturer || products.length === 0) continue;

      // Track brand counts.
      const slug = slugify(manufacturer);
      if (slug.length === 0) continue;
      const prev = brandCounts.get(slug);
      brandCounts.set(slug, {
        name: prev?.name ?? manufacturer,
        country: prev?.country ?? country,
        count: (prev?.count ?? 0) + 1,
      });

      for (const p of products) {
        const generic = p.openfda?.device_name?.trim();
        const productCode = p.product_code?.trim();
        if (!generic || !productCode) continue;
        const openfdaId = `${slug}::${productCode}`;
        deviceBatch.push({
          openfda_id: openfdaId,
          generic_name: generic,
          brand_name: row.proprietary_name?.trim() || manufacturer,
          manufacturer,
          product_code: productCode,
          risk_class: p.openfda?.device_class ?? null,
          category_key: categoryForSpecialty(p.openfda?.medical_specialty_description),
          description: p.openfda?.medical_specialty_description ?? null,
          source: 'openfda',
          source_url: `https://api.fda.gov/device/registrationlisting.json?search=fei_number:${row.fei_number ?? ''}`,
        });
        if (deviceBatch.length + pulled >= maxRows) break;
      }
      if (deviceBatch.length + pulled >= maxRows) break;
    }

    if (deviceBatch.length > 0) {
      const { error } = await supabase
        .from('catalog_devices')
        .upsert(deviceBatch, { onConflict: 'openfda_id', ignoreDuplicates: false });
      if (error) {
        return new Response(JSON.stringify({ error: 'upsert_devices_failed', message: error.message }), {
          status: 500,
          headers: { 'content-type': 'application/json' },
        });
      }
      upserted += deviceBatch.length;
    }

    pulled += rows.length;
    skip += rows.length;
    if (rows.length < 100) break;
    await new Promise((r) => setTimeout(r, RATE_LIMIT_MS));
  }

  // Now upsert all brands accumulated.
  const brandUpserts: (BrandUpsert & { manufacturer_count: number })[] = [];
  for (const [slug, info] of brandCounts.entries()) {
    brandUpserts.push({
      name: info.name,
      slug,
      country: info.country,
      source: 'openfda',
      manufacturer_count: info.count,
    });
  }
  if (brandUpserts.length > 0) {
    const { error } = await supabase
      .from('catalog_brands')
      .upsert(brandUpserts, { onConflict: 'slug', ignoreDuplicates: false });
    if (error) {
      return new Response(
        JSON.stringify({ error: 'upsert_brands_failed', message: error.message, devices_upserted: upserted }),
        { status: 500, headers: { 'content-type': 'application/json' } },
      );
    }
  }

  // Backfill brand_id on devices we just inserted via the SECURITY DEFINER
  // helper. Returns the row count for diagnostics.
  let linked = 0;
  const { data: linkData, error: linkErr } = await supabase.rpc('_link_catalog_devices_to_brands');
  if (linkErr) {
    return new Response(
      JSON.stringify({ error: 'brand_link_failed', message: linkErr.message, devices_upserted: upserted }),
      { status: 500, headers: { 'content-type': 'application/json' } },
    );
  }
  linked = Number(linkData ?? 0);

  return new Response(
    JSON.stringify({
      ok: true,
      pulled,
      devices_upserted: upserted,
      brands_upserted: brandUpserts.length,
      brand_links_set: linked,
      next_skip: skip,
    }),
    { status: 200, headers: { 'content-type': 'application/json' } },
  );
});
