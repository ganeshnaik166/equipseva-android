import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  chains_tracked: number;
  total_uplift_beds: number;
  total_units_won: number;
  total_amc_rupees: number;
  total_repair_rupees: number;
  avg_uplift_pct: number;
};

type ChainRow = {
  id: string;
  chain_name: string;
  region: string;
  quarter_label: string;
  fiscal_year: number;
  beds_start: number;
  beds_end: number;
  uplift_beds: number;
  uplift_pct: number;
  our_role: string;
  equipment_units: number;
  amc_rev_rupees: number;
  repair_rev_rupees: number;
  story_snippet: string;
};

type ByChain = {
  chain_name: string;
  quarters_count: number;
  total_uplift_beds: number;
  total_units: number;
  total_amc: number;
  total_repair: number;
};

type ByRegion = {
  region: string;
  chains_count: number;
  total_uplift_beds: number;
  total_amc: number;
};

type ByRole = {
  our_role: string;
  rows_count: number;
  total_units: number;
  total_amc: number;
};

type StoryRow = {
  id: string;
  chain_name: string;
  pitch_audience: string;
  headline: string;
  body: string;
  proof_metric: string;
  status: string;
  approved_by: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  return Number(n ?? 0).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, listRes, byChainRes, byRegionRes, byRoleRes, storyRes] = await Promise.all([
    supabase.rpc('founder_chain_uplift_kpi_r2723'),
    supabase.rpc('founder_chain_uplift_list_r2723'),
    supabase.rpc('founder_chain_uplift_by_chain_r2723'),
    supabase.rpc('founder_chain_uplift_by_region_r2723'),
    supabase.rpc('founder_chain_uplift_by_role_r2723'),
    supabase.rpc('founder_chain_uplift_storyboard_r2723'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    chains_tracked: 0,
    total_uplift_beds: 0,
    total_units_won: 0,
    total_amc_rupees: 0,
    total_repair_rupees: 0,
    avg_uplift_pct: 0,
  };
  const rows: ChainRow[] = (listRes.data as ChainRow[]) ?? [];
  const byChain: ByChain[] = (byChainRes.data as ByChain[]) ?? [];
  const byRegion: ByRegion[] = (byRegionRes.data as ByRegion[]) ?? [];
  const byRole: ByRole[] = (byRoleRes.data as ByRole[]) ?? [];
  const story: StoryRow[] = (storyRes.data as StoryRow[]) ?? [];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">
          Hospital Chain Quarterly Bed Capacity Uplift Impact
        </h1>
        <p className="text-sm text-gray-600">
          For every chain &amp; every quarter: how many beds they added, how much of
          that new capacity we won as AMC or repair, and the story we tell board
          &amp; investors. Threshold for headline: uplift &gt;= 5% beds in a quarter.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <div className="rounded-lg border p-4 bg-white">
          <div className="text-xs text-gray-500">Chains tracked</div>
          <div className="text-xl font-semibold">{kpi.chains_tracked}</div>
        </div>
        <div className="rounded-lg border p-4 bg-white">
          <div className="text-xs text-gray-500">Uplift beds (total)</div>
          <div className="text-xl font-semibold">{kpi.total_uplift_beds}</div>
        </div>
        <div className="rounded-lg border p-4 bg-white">
          <div className="text-xs text-gray-500">Units won</div>
          <div className="text-xl font-semibold">{kpi.total_units_won}</div>
        </div>
        <div className="rounded-lg border p-4 bg-white">
          <div className="text-xs text-gray-500">AMC revenue</div>
          <div className="text-xl font-semibold">{fmtRupees(kpi.total_amc_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4 bg-white">
          <div className="text-xs text-gray-500">Repair revenue</div>
          <div className="text-xl font-semibold">{fmtRupees(kpi.total_repair_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4 bg-white">
          <div className="text-xs text-gray-500">Avg uplift %</div>
          <div className="text-xl font-semibold">{fmtPct(kpi.avg_uplift_pct)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain × Quarter detail</h2>
        <DataTable
          rows={rows}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'region', header: 'Region', render: (r: ChainRow) => r.region },
            {
              key: 'qfy',
              header: 'Quarter',
              render: (r: ChainRow) => r.quarter_label + ' FY' + r.fiscal_year,
            },
            {
              key: 'beds',
              header: 'Beds (start → end)',
              render: (r: ChainRow) => r.beds_start + ' → ' + r.beds_end,
            },
            {
              key: 'uplift',
              header: 'Uplift',
              render: (r: ChainRow) => '+' + r.uplift_beds + ' (' + fmtPct(r.uplift_pct) + ')',
            },
            { key: 'our_role', header: 'Our role', render: (r: ChainRow) => r.our_role },
            {
              key: 'units',
              header: 'Units won',
              render: (r: ChainRow) => String(r.equipment_units),
            },
            {
              key: 'amc',
              header: 'AMC revenue',
              render: (r: ChainRow) => fmtRupees(r.amc_rev_rupees),
            },
            {
              key: 'repair',
              header: 'Repair revenue',
              render: (r: ChainRow) => fmtRupees(r.repair_rev_rupees),
            },
            {
              key: 'story',
              header: 'Story',
              render: (r: ChainRow) => (
                <span className="text-xs text-gray-700">{r.story_snippet}</span>
              ),
            },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By chain (cumulative)</h2>
        <DataTable
          rows={byChain}
          rowKey={(r, i) => String(r.chain_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ByChain) => r.chain_name },
            {
              key: 'quarters_count',
              header: 'Quarters',
              render: (r: ByChain) => String(r.quarters_count),
            },
            {
              key: 'total_uplift_beds',
              header: 'Uplift beds',
              render: (r: ByChain) => String(r.total_uplift_beds),
            },
            {
              key: 'total_units',
              header: 'Units',
              render: (r: ByChain) => String(r.total_units),
            },
            {
              key: 'total_amc',
              header: 'AMC',
              render: (r: ByChain) => fmtRupees(r.total_amc),
            },
            {
              key: 'total_repair',
              header: 'Repair',
              render: (r: ByChain) => fmtRupees(r.total_repair),
            },
          ]}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">By region</h2>
          <DataTable
            rows={byRegion}
            rowKey={(r, i) => String(r.region ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'region', header: 'Region', render: (r: ByRegion) => r.region },
              {
                key: 'chains_count',
                header: 'Chains',
                render: (r: ByRegion) => String(r.chains_count),
              },
              {
                key: 'total_uplift_beds',
                header: 'Uplift beds',
                render: (r: ByRegion) => String(r.total_uplift_beds),
              },
              {
                key: 'total_amc',
                header: 'AMC',
                render: (r: ByRegion) => fmtRupees(r.total_amc),
              },
            ]}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">By our role</h2>
          <DataTable
            rows={byRole}
            rowKey={(r, i) => String(r.our_role ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'our_role', header: 'Role', render: (r: ByRole) => r.our_role },
              {
                key: 'rows_count',
                header: 'Quarters',
                render: (r: ByRole) => String(r.rows_count),
              },
              {
                key: 'total_units',
                header: 'Units',
                render: (r: ByRole) => String(r.total_units),
              },
              {
                key: 'total_amc',
                header: 'AMC',
                render: (r: ByRole) => fmtRupees(r.total_amc),
              },
            ]}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Storyboard</h2>
        <p className="text-xs text-gray-500 mb-2">
          Narrative spine for board & investor decks — one line per chain
          & audience.
        </p>
        <DataTable
          rows={story}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: StoryRow) => r.chain_name },
            {
              key: 'pitch_audience',
              header: 'Audience',
              render: (r: StoryRow) => r.pitch_audience,
            },
            { key: 'headline', header: 'Headline', render: (r: StoryRow) => r.headline },
            {
              key: 'body',
              header: 'Body',
              render: (r: StoryRow) => (
                <span className="text-xs text-gray-700">{r.body}</span>
              ),
            },
            {
              key: 'proof_metric',
              header: 'Proof',
              render: (r: StoryRow) => r.proof_metric,
            },
            { key: 'status', header: 'Status', render: (r: StoryRow) => r.status },
            {
              key: 'approved_by',
              header: 'Approved by',
              render: (r: StoryRow) => r.approved_by ?? '—',
            },
          ]}
        />
      </section>
    </main>
  );
}
