import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    { data: kpi },
    { data: tierRows },
    { data: regionRows },
    { data: amcRows },
    { data: equipRows },
    { data: detractorRows },
    { data: reasonRows },
  ] = await Promise.all([
    sb.rpc('nps_headline_kpi_r2272'),
    sb.rpc('nps_by_tier_overview_r2272'),
    sb.rpc('nps_by_region_overview_r2272'),
    sb.rpc('nps_by_amc_plan_overview_r2272'),
    sb.rpc('nps_by_equipment_class_overview_r2272'),
    sb.rpc('nps_detractor_drilldown_r2272'),
    sb.rpc('nps_detractor_reason_rollup_r2272'),
  ]);

  const k = (kpi && kpi[0]) || {
    total_responses: 0, promoters: 0, passives: 0, detractors: 0,
    overall_nps: 0, segments_tracked: 0, worst_segment: 'none', worst_segment_score: 0,
  };

  const tierCols: Column<any>[] = [
    { key: 'hospital_tier', header: 'Tier',       render: (r) => <span className="font-mono uppercase">{r.hospital_tier}</span> },
    { key: 'responses',     header: 'Responses',  render: (r) => <span>{r.responses}</span> },
    { key: 'promoters',     header: 'Promoters',  render: (r) => <span className="text-emerald-700">{r.promoters}</span> },
    { key: 'passives',      header: 'Passives',   render: (r) => <span className="text-amber-700">{r.passives}</span> },
    { key: 'detractors',    header: 'Detractors', render: (r) => <span className="text-rose-700">{r.detractors}</span> },
    { key: 'nps_score',     header: 'NPS',        render: (r) => <span className="font-semibold">{r.nps_score}</span> },
    { key: 'prior_score',   header: 'Prior',      render: (r) => <span className="text-slate-500">{r.prior_score}</span> },
    { key: 'trend',         header: 'Trend',      render: (r) => <span>{r.trend === 'up' ? 'up' : r.trend === 'down' ? 'down' : 'flat'}</span> },
  ];

  const regionCols: Column<any>[] = [
    { key: 'region',      header: 'Region',     render: (r) => <span className="font-mono">{r.region}</span> },
    { key: 'responses',   header: 'Responses',  render: (r) => <span>{r.responses}</span> },
    { key: 'promoters',   header: 'Promoters',  render: (r) => <span className="text-emerald-700">{r.promoters}</span> },
    { key: 'passives',    header: 'Passives',   render: (r) => <span className="text-amber-700">{r.passives}</span> },
    { key: 'detractors',  header: 'Detractors', render: (r) => <span className="text-rose-700">{r.detractors}</span> },
    { key: 'nps_score',   header: 'NPS',        render: (r) => <span className="font-semibold">{r.nps_score}</span> },
    { key: 'prior_score', header: 'Prior',      render: (r) => <span className="text-slate-500">{r.prior_score}</span> },
    { key: 'trend',       header: 'Trend',      render: (r) => <span>{r.trend}</span> },
  ];

  const amcCols: Column<any>[] = [
    { key: 'amc_plan',    header: 'AMC plan',   render: (r) => <span className="font-mono uppercase">{r.amc_plan}</span> },
    { key: 'responses',   header: 'Responses',  render: (r) => <span>{r.responses}</span> },
    { key: 'promoters',   header: 'Promoters',  render: (r) => <span className="text-emerald-700">{r.promoters}</span> },
    { key: 'passives',    header: 'Passives',   render: (r) => <span className="text-amber-700">{r.passives}</span> },
    { key: 'detractors',  header: 'Detractors', render: (r) => <span className="text-rose-700">{r.detractors}</span> },
    { key: 'nps_score',   header: 'NPS',        render: (r) => <span className="font-semibold">{r.nps_score}</span> },
    { key: 'prior_score', header: 'Prior',      render: (r) => <span className="text-slate-500">{r.prior_score}</span> },
    { key: 'trend',       header: 'Trend',      render: (r) => <span>{r.trend}</span> },
  ];

  const equipCols: Column<any>[] = [
    { key: 'equipment_class', header: 'Equipment class', render: (r) => <span className="font-mono">{r.equipment_class}</span> },
    { key: 'responses',       header: 'Responses',       render: (r) => <span>{r.responses}</span> },
    { key: 'promoters',       header: 'Promoters',       render: (r) => <span className="text-emerald-700">{r.promoters}</span> },
    { key: 'passives',        header: 'Passives',        render: (r) => <span className="text-amber-700">{r.passives}</span> },
    { key: 'detractors',      header: 'Detractors',      render: (r) => <span className="text-rose-700">{r.detractors}</span> },
    { key: 'nps_score',       header: 'NPS',             render: (r) => <span className="font-semibold">{r.nps_score}</span> },
    { key: 'prior_score',     header: 'Prior',           render: (r) => <span className="text-slate-500">{r.prior_score}</span> },
    { key: 'trend',           header: 'Trend',           render: (r) => <span>{r.trend}</span> },
  ];

  const detractorCols: Column<any>[] = [
    { key: 'hospital_org_name', header: 'Hospital',       render: (r) => <span className="font-medium">{r.hospital_org_name}</span> },
    { key: 'hospital_tier',     header: 'Tier',           render: (r) => <span className="font-mono">{r.hospital_tier}</span> },
    { key: 'region',            header: 'Region',         render: (r) => <span>{r.region}</span> },
    { key: 'amc_plan',          header: 'AMC',            render: (r) => <span className="font-mono uppercase">{r.amc_plan}</span> },
    { key: 'equipment_class',   header: 'Equipment',      render: (r) => <span>{r.equipment_class}</span> },
    { key: 'nps_score',         header: 'Score',          render: (r) => <span className="text-rose-700 font-semibold">{r.nps_score}</span> },
    { key: 'primary_reason',    header: 'Primary reason', render: (r) => <span>{r.primary_reason}</span> },
    { key: 'verbatim_quote',    header: 'Verbatim',       render: (r) => <span className="italic text-slate-700">{r.verbatim_quote ?? '—'}</span> },
    { key: 'follow_up_status',  header: 'Follow-up',      render: (r) => <span className="font-mono">{r.follow_up_status}</span> },
    { key: 'surveyed_at',       header: 'Surveyed',       render: (r) => <span className="text-slate-500">{new Date(r.surveyed_at).toLocaleDateString()}</span> },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'primary_reason',  header: 'Primary reason',   render: (r) => <span className="font-medium">{r.primary_reason}</span> },
    { key: 'detractor_count', header: 'Detractors',       render: (r) => <span className="text-rose-700">{r.detractor_count}</span> },
    { key: 'escalated_count', header: 'Escalated',        render: (r) => <span>{r.escalated_count}</span> },
    { key: 'resolved_count',  header: 'Resolved',         render: (r) => <span className="text-emerald-700">{r.resolved_count}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold tracking-tight">Customer NPS by segment slice</h1>
        <p className="text-sm text-slate-600">
          NPS broken by hospital tier, region, AMC plan, equipment class. Detractor drill-down for follow-up.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="Total responses"   value={String(k.total_responses)} />
        <Kpi label="Overall NPS"       value={String(k.overall_nps)} accent="emerald" />
        <Kpi label="Detractors"        value={String(k.detractors)} accent="rose" />
        <Kpi label="Segments tracked"  value={String(k.segments_tracked)} />
        <Kpi label="Promoters"         value={String(k.promoters)} accent="emerald" />
        <Kpi label="Passives"          value={String(k.passives)} accent="amber" />
        <Kpi label="Worst segment"     value={String(k.worst_segment)} />
        <Kpi label="Worst NPS"         value={String(k.worst_segment_score)} accent="rose" />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">NPS by hospital tier</h2>
        <DataTable columns={tierCols} rows={tierRows ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">NPS by region</h2>
        <DataTable columns={regionCols} rows={regionRows ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">NPS by AMC plan</h2>
        <DataTable columns={amcCols} rows={amcRows ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">NPS by equipment class</h2>
        <DataTable columns={equipCols} rows={equipRows ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Detractor reason rollup</h2>
        <DataTable columns={reasonCols} rows={reasonRows ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Detractor drill-down</h2>
        <p className="text-xs text-slate-500">Score &lt;= 6. Acts as the founder follow-up queue.</p>
        <DataTable columns={detractorCols} rows={detractorRows ?? []} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}

function Kpi({ label, value, accent }: { label: string; value: string; accent?: 'emerald' | 'rose' | 'amber' }) {
  const color =
    accent === 'emerald' ? 'text-emerald-700' :
    accent === 'rose'    ? 'text-rose-700'    :
    accent === 'amber'   ? 'text-amber-700'   : 'text-slate-900';
  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className={`mt-1 text-2xl font-semibold ${color}`}>{value}</div>
    </div>
  );
}
