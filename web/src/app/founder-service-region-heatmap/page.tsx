import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Kpis = {
  total_regions: number;
  white_space_regions: number;
  under_served_regions: number;
  balanced_regions: number;
  over_served_regions: number;
  saturated_regions: number;
  total_revenue_rupees_90d: number;
  total_jobs_90d: number;
  total_active_engineers: number;
  total_active_orgs: number;
  total_amc_active: number;
  median_amc_penetration_pct: number;
  median_jobs_per_engineer: number;
  top_state_by_revenue: string;
  top_city_by_revenue: string;
  snapshot_date: string | null;
};

function Card({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3 shadow-sm">
      <div className="text-[11px] uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
      {hint ? <div className="mt-0.5 text-[11px] text-neutral-500">{hint}</div> : null}
    </div>
  );
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  await supabase.rpc('log_founder_region_view');

  const [kpisRes, byStateRes, topCitiesRes, whiteSpaceRes, overServedRes, amcPenRes] = await Promise.all([
    supabase.rpc('founder_region_heatmap_kpis'),
    supabase.rpc('founder_region_heatmap_by_state'),
    supabase.rpc('founder_region_heatmap_top_cities'),
    supabase.rpc('founder_region_heatmap_white_space'),
    supabase.rpc('founder_region_heatmap_over_served'),
    supabase.rpc('founder_region_heatmap_amc_penetration'),
  ]);

  const k: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_regions: 0,
    white_space_regions: 0,
    under_served_regions: 0,
    balanced_regions: 0,
    over_served_regions: 0,
    saturated_regions: 0,
    total_revenue_rupees_90d: 0,
    total_jobs_90d: 0,
    total_active_engineers: 0,
    total_active_orgs: 0,
    total_amc_active: 0,
    median_amc_penetration_pct: 0,
    median_jobs_per_engineer: 0,
    top_state_by_revenue: '—',
    top_city_by_revenue: '—',
    snapshot_date: null,
  };

  const byState = (byStateRes.data ?? []) as Array<Record<string, unknown> & { id: string }>;
  const topCities = (topCitiesRes.data ?? []) as Array<Record<string, unknown> & { id: string }>;
  const whiteSpace = (whiteSpaceRes.data ?? []) as Array<Record<string, unknown> & { id: string }>;
  const overServed = (overServedRes.data ?? []) as Array<Record<string, unknown> & { id: string }>;
  const amcPen = (amcPenRes.data ?? []) as Array<Record<string, unknown> & { id: string }>;

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4">
      <header className="space-y-1">
        <div className="text-xs uppercase tracking-wide text-neutral-500">Growth · r1453</div>
        <h1 className="text-2xl font-semibold text-neutral-900">Service Region Heatmap</h1>
        <p className="text-sm text-neutral-600">
          Per-region rollup of revenue, engineer density, and AMC penetration. Surfaces white-space
          regions {"<"} 0 engineers but 3+ orgs {">"} and over-served regions {"<"} 2 jobs/engineer {">"}.
        </p>
        <div className="text-xs text-neutral-500">
          Snapshot: {k.snapshot_date ?? 'not yet computed — call founder_region_heatmap_recompute()'}
        </div>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-neutral-700">Scoreboard</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <Card label="Total regions" value={String(k.total_regions)} />
          <Card label="White-space regions" value={String(k.white_space_regions)} hint="orgs but no engineers" />
          <Card label="Under-served" value={String(k.under_served_regions)} hint="orgs/engineer ≥ 5" />
          <Card label="Balanced" value={String(k.balanced_regions)} />
          <Card label="Over-served" value={String(k.over_served_regions)} hint="jobs/engineer < 2" />
          <Card label="Saturated" value={String(k.saturated_regions)} />
          <Card label="Revenue 90d" value={formatRupees(Number(k.total_revenue_rupees_90d))} />
          <Card label="Jobs 90d" value={String(k.total_jobs_90d)} />
          <Card label="Active engineers" value={String(k.total_active_engineers)} />
          <Card label="Active orgs" value={String(k.total_active_orgs)} />
          <Card label="Active AMCs" value={String(k.total_amc_active)} />
          <Card label="Median AMC pen %" value={`${Number(k.median_amc_penetration_pct).toFixed(1)}%`} />
          <Card label="Median jobs/engineer" value={Number(k.median_jobs_per_engineer).toFixed(2)} />
          <Card label="Top state" value={k.top_state_by_revenue} />
          <Card label="Top city" value={k.top_city_by_revenue} />
          <Card label="Refreshed" value={k.snapshot_date ?? '—'} />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700">By state — revenue ranked</h2>
        <DataTable
          rows={byState}
          rowKey={(r) => r.id}
          columns={[
            { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
            { key: 'city_count', header: 'Cities', render: (r: any) => r.city_count ?? '—' },
            { key: 'jobs_90d', header: 'Jobs 90d', render: (r: any) => r.jobs_90d ?? '—' },
            { key: 'revenue_rupees_90d', header: 'Revenue 90d', render: (r) => formatRupees(Number(r.revenue_rupees_90d ?? 0)) },
            { key: 'active_engineers', header: 'Engineers', render: (r: any) => r.active_engineers ?? '—' },
            { key: 'active_orgs', header: 'Orgs', render: (r: any) => r.active_orgs ?? '—' },
            { key: 'amc_active', header: 'AMCs', render: (r: any) => r.amc_active ?? '—' },
            { key: 'amc_penetration_pct', header: 'AMC pen %', render: (r) => `${Number(r.amc_penetration_pct ?? 0).toFixed(1)}%` },
            { key: 'classification_mix', header: 'Class mix', render: (r: any) => r.classification_mix ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700">Top cities — revenue 90d</h2>
        <DataTable
          rows={topCities}
          rowKey={(r) => r.id}
          columns={[
            { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
            { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
            { key: 'jobs_90d', header: 'Jobs', render: (r: any) => r.jobs_90d ?? '—' },
            { key: 'revenue_rupees_90d', header: 'Revenue', render: (r) => formatRupees(Number(r.revenue_rupees_90d ?? 0)) },
            { key: 'active_engineers', header: 'Engineers', render: (r: any) => r.active_engineers ?? '—' },
            { key: 'amc_active', header: 'AMCs', render: (r: any) => r.amc_active ?? '—' },
            { key: 'amc_penetration_pct', header: 'AMC %', render: (r) => `${Number(r.amc_penetration_pct ?? 0).toFixed(1)}%` },
            { key: 'jobs_per_engineer', header: 'Jobs/eng', render: (r) => Number(r.jobs_per_engineer ?? 0).toFixed(2) },
            { key: 'heat_score', header: 'Heat', render: (r: any) => r.heat_score ?? '—' },
            { key: 'classification', header: 'Class', render: (r: any) => r.classification ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700">White-space + under-served — expansion candidates</h2>
        <DataTable
          rows={whiteSpace}
          rowKey={(r) => r.id}
          columns={[
            { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
            { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
            { key: 'active_orgs', header: 'Orgs', render: (r: any) => r.active_orgs ?? '—' },
            { key: 'active_engineers', header: 'Engineers', render: (r: any) => r.active_engineers ?? '—' },
            { key: 'orgs_per_engineer', header: 'Orgs/eng', render: (r: any) => r.orgs_per_engineer ?? '—' },
            { key: 'jobs_90d', header: 'Jobs 90d', render: (r: any) => r.jobs_90d ?? '—' },
            { key: 'amc_penetration_pct', header: 'AMC %', render: (r) => `${Number(r.amc_penetration_pct ?? 0).toFixed(1)}%` },
            { key: 'opportunity_note', header: 'Opportunity', render: (r: any) => r.opportunity_note ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700">Over-served + saturated — rebalance candidates</h2>
        <DataTable
          rows={overServed}
          rowKey={(r) => r.id}
          columns={[
            { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
            { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
            { key: 'active_engineers', header: 'Engineers', render: (r: any) => r.active_engineers ?? '—' },
            { key: 'jobs_90d', header: 'Jobs 90d', render: (r: any) => r.jobs_90d ?? '—' },
            { key: 'jobs_per_engineer', header: 'Jobs/eng', render: (r) => Number(r.jobs_per_engineer ?? 0).toFixed(2) },
            { key: 'revenue_per_engineer_rupees', header: 'Rev/eng', render: (r) => formatRupees(Number(r.revenue_per_engineer_rupees ?? 0)) },
            { key: 'classification', header: 'Class', render: (r: any) => r.classification ?? '—' },
            { key: 'risk_note', header: 'Risk', render: (r: any) => r.risk_note ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700">AMC penetration — lowest first</h2>
        <DataTable
          rows={amcPen}
          rowKey={(r) => r.id}
          columns={[
            { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
            { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
            { key: 'active_orgs', header: 'Orgs', render: (r: any) => r.active_orgs ?? '—' },
            { key: 'amc_active', header: 'AMCs', render: (r: any) => r.amc_active ?? '—' },
            { key: 'amc_penetration_pct', header: 'Pen %', render: (r) => `${Number(r.amc_penetration_pct ?? 0).toFixed(1)}%` },
            { key: 'jobs_90d', header: 'Jobs 90d', render: (r: any) => r.jobs_90d ?? '—' },
            { key: 'revenue_rupees_90d', header: 'Revenue 90d', render: (r) => formatRupees(Number(r.revenue_rupees_90d ?? 0)) },
            { key: 'classification', header: 'Class', render: (r: any) => r.classification ?? '—' },
          ]}
        />
      </section>
    </div>
  );
}
