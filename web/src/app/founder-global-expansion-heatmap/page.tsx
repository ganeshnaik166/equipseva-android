import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  const v = Number(n ?? 0);
  return v.toLocaleString('en-IN');
}
function fmtRupees(n: any): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
  if (v >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
  return `Rs ${v.toLocaleString('en-IN')}`;
}
function fmtPct(n: any): string {
  const v = Number(n ?? 0);
  return `${v.toFixed(2)}%`;
}

export default async function FounderGlobalExpansionHeatmapPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let stateRows: any[] = [];
  let cityRows: any[] = [];
  let priorityRows: any[] = [];
  let decisionRows: any[] = [];
  let regionRows: any[] = [];
  let gapRows: any[] = [];

  try {
    const r = await sb.rpc('founder_expansion_kpis');
    kpis = (r.data as any) ?? {};
  } catch (_e) { kpis = {}; }

  try {
    const r = await sb.rpc('founder_expansion_state_heatmap');
    stateRows = (r.data as any[]) ?? [];
  } catch (_e) { stateRows = []; }

  try {
    const r = await sb.rpc('founder_expansion_city_breakdown');
    cityRows = (r.data as any[]) ?? [];
  } catch (_e) { cityRows = []; }

  try {
    const r = await sb.rpc('founder_expansion_top_priorities');
    priorityRows = (r.data as any[]) ?? [];
  } catch (_e) { priorityRows = []; }

  try {
    const r = await sb.rpc('founder_expansion_decision_queue');
    decisionRows = (r.data as any[]) ?? [];
  } catch (_e) { decisionRows = []; }

  try {
    const r = await sb.rpc('founder_expansion_region_rollup');
    regionRows = (r.data as any[]) ?? [];
  } catch (_e) { regionRows = []; }

  try {
    const r = await sb.rpc('founder_expansion_penetration_gap');
    gapRows = (r.data as any[]) ?? [];
  } catch (_e) { gapRows = []; }

  const cards: Kpi[] = [
    { label: 'Total States', value: fmtInt(kpis.total_states) },
    { label: 'Total Cities', value: fmtInt(kpis.total_cities) },
    { label: 'Tier-1 Cities', value: fmtInt(kpis.tier_1) },
    { label: 'Tier-2 Cities', value: fmtInt(kpis.tier_2) },
    { label: 'Tier-3 Cities', value: fmtInt(kpis.tier_3) },
    { label: 'Live Cities', value: fmtInt(kpis.live_cities) },
    { label: 'Planning', value: fmtInt(kpis.planning_cities) },
    { label: 'Paused', value: fmtInt(kpis.paused_cities) },
    { label: 'Hospitals Target', value: fmtInt(kpis.target_hospitals) },
    { label: 'Hospitals Live', value: fmtInt(kpis.live_hospitals) },
    { label: 'Engineers Target', value: fmtInt(kpis.target_engineers) },
    { label: 'Engineers Live', value: fmtInt(kpis.live_engineers) },
    { label: 'Monthly GMV', value: fmtRupees(kpis.monthly_gmv_rupees) },
    { label: 'Avg Penetration', value: fmtPct(kpis.avg_penetration_pct) },
    { label: 'Pending Decisions', value: fmtInt(kpis.pending_decisions) },
    { label: 'Executed Decisions', value: fmtInt(kpis.executed_decisions) },
  ];

  const stateCols: Column<any>[] = [
    { key: 'state', header: 'State', render: (r: any) => r.state ?? "—" },
    { key: 'cities', header: 'Cities', render: (r: any) => fmtInt(r.cities) },
    { key: 'live_cities', header: 'Live', render: (r: any) => fmtInt(r.live_cities) },
    { key: 'hospitals_live', header: 'Hospitals Live', render: (r: any) => `${fmtInt(r.hospitals_live)} / ${fmtInt(r.hospitals_target)}` },
    { key: 'engineers_live', header: 'Engineers Live', render: (r: any) => `${fmtInt(r.engineers_live)} / ${fmtInt(r.engineers_target)}` },
    { key: 'monthly_gmv_rupees', header: 'Monthly GMV', render: (r: any) => fmtRupees(r.monthly_gmv_rupees) },
    { key: 'avg_penetration_pct', header: 'Penetration', render: (r: any) => fmtPct(r.avg_penetration_pct) },
  ];

  const cityCols: Column<any>[] = [
    { key: 'state', header: 'State', render: (r: any) => r.state ?? "—" },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "—" },
    { key: 'city_tier', header: 'Tier', render: (r: any) => `T${r.city_tier ?? "—"}` },
    { key: 'region', header: 'Region', render: (r: any) => r.region ?? "—" },
    { key: 'launch_status', header: 'Status', render: (r: any) => r.launch_status ?? "—" },
    { key: 'hospitals_live', header: 'Hosp', render: (r: any) => fmtInt(r.hospitals_live) },
    { key: 'engineers_live', header: 'Eng', render: (r: any) => fmtInt(r.engineers_live) },
    { key: 'monthly_gmv_rupees', header: 'GMV', render: (r: any) => fmtRupees(r.monthly_gmv_rupees) },
    { key: 'penetration_pct', header: 'Pen', render: (r: any) => fmtPct(r.penetration_pct) },
    { key: 'priority_rank', header: 'Rank', render: (r: any) => fmtInt(r.priority_rank) },
  ];

  const priorityCols: Column<any>[] = [
    { key: 'priority_rank', header: 'Rank', render: (r: any) => fmtInt(r.priority_rank) },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? "—" },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "—" },
    { key: 'city_tier', header: 'Tier', render: (r: any) => `T${r.city_tier ?? "—"}` },
    { key: 'target_launch_month', header: 'Target Launch', render: (r: any) => r.target_launch_month ?? "—" },
    { key: 'hospital_count_target', header: 'Hosp Target', render: (r: any) => fmtInt(r.hospital_count_target) },
    { key: 'engineer_count_target', header: 'Eng Target', render: (r: any) => fmtInt(r.engineer_count_target) },
    { key: 'launch_status', header: 'Status', render: (r: any) => r.launch_status ?? "—" },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'state', header: 'State', render: (r: any) => r.state ?? "—" },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "—" },
    { key: 'decision_type', header: 'Type', render: (r: any) => r.decision_type ?? "—" },
    { key: 'rationale', header: 'Rationale', render: (r: any) => r.rationale ?? "—" },
    { key: 'estimated_gmv_uplift_rupees', header: 'GMV Uplift', render: (r: any) => fmtRupees(r.estimated_gmv_uplift_rupees) },
    { key: 'estimated_cost_rupees', header: 'Cost', render: (r: any) => fmtRupees(r.estimated_cost_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
  ];

  const regionCols: Column<any>[] = [
    { key: 'region', header: 'Region', render: (r: any) => r.region ?? "—" },
    { key: 'cities', header: 'Cities', render: (r: any) => fmtInt(r.cities) },
    { key: 'live_cities', header: 'Live', render: (r: any) => fmtInt(r.live_cities) },
    { key: 'hospitals_live', header: 'Hospitals', render: (r: any) => fmtInt(r.hospitals_live) },
    { key: 'monthly_gmv_rupees', header: 'GMV', render: (r: any) => fmtRupees(r.monthly_gmv_rupees) },
    { key: 'avg_penetration_pct', header: 'Avg Pen', render: (r: any) => fmtPct(r.avg_penetration_pct) },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Founder Global Expansion Heatmap</h1>
        <p className="text-sm text-gray-500">India market penetration by state and city tier · 12-month expansion priorities · founder decision queue.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((k) => (
          <div key={k.label} className="border rounded-lg p-3 bg-white">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">State Heatmap</h2>
        <DataTable columns={stateCols} rows={stateRows} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Breakdown (Top 100)</h2>
        <DataTable columns={cityCols} rows={cityRows} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Expansion Priorities (Next 12 Months)</h2>
        <DataTable columns={priorityCols} rows={priorityRows} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Founder Decision Queue</h2>
        <DataTable columns={decisionCols} rows={decisionRows} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Region Rollup</h2>
        <DataTable columns={regionCols} rows={regionRows} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Penetration Gap (Target vs Live)</h2>
        <DataTable
          columns={[
            { key: 'state', header: 'State', render: (r: any) => r.state ?? "—" },
            { key: 'city', header: 'City', render: (r: any) => r.city ?? "—" },
            { key: 'city_tier', header: 'Tier', render: (r: any) => `T${r.city_tier ?? "—"}` },
            { key: 'hospital_gap', header: 'Hospital Gap', render: (r: any) => fmtInt(r.hospital_gap) },
            { key: 'engineer_gap', header: 'Engineer Gap', render: (r: any) => fmtInt(r.engineer_gap) },
            { key: 'gmv_potential_rupees', header: 'GMV Potential', render: (r: any) => fmtRupees(r.gmv_potential_rupees) },
          ]}
          rows={gapRows}
          rowKey={(r: any) => r.id}
        />
      </section>
    </div>
  );
}
