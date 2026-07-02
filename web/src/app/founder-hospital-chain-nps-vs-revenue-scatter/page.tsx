import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    { data: kpi },
    { data: scatterRows },
    { data: expandRows },
    { data: protectRows },
    { data: quadrantRows },
    { data: regionRows },
    { data: actionRows },
  ] = await Promise.all([
    sb.rpc('chain_nps_rev_headline_kpi_r2315'),
    sb.rpc('chain_nps_rev_scatter_r2315'),
    sb.rpc('chain_nps_rev_expand_candidates_r2315'),
    sb.rpc('chain_nps_rev_protect_candidates_r2315'),
    sb.rpc('chain_nps_rev_quadrant_rollup_r2315'),
    sb.rpc('chain_nps_rev_region_rollup_r2315'),
    sb.rpc('chain_nps_rev_open_actions_r2315'),
  ]);

  const k = (kpi && kpi[0]) || {
    chains_tracked: 0, star_count: 0, expand_count: 0, protect_count: 0, fix_count: 0,
    total_revenue_rupees: 0, protect_revenue_rupees: 0, weighted_nps: 0, open_actions: 0,
  };

  const fmtINR = (v: number) => '₹' + Number(v ?? 0).toLocaleString('en-IN');

  const scatterCols: Column<any>[] = [
    { key: 'chain_name',     header: 'Chain',          render: (r) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'region',         header: 'Region',         render: (r) => <span className="font-mono text-xs">{r.region}</span> },
    { key: 'hospital_count', header: 'Hospitals',      render: (r) => <span>{r.hospital_count}</span> },
    { key: 'nps_score',      header: 'NPS',            render: (r) => <span className="font-semibold">{Number(r.nps_score).toFixed(1)}</span> },
    { key: 'revenue_rupees', header: 'Revenue',        render: (r) => <span>{fmtINR(r.revenue_rupees)}</span> },
    { key: 'quadrant',       header: 'Quadrant',       render: (r) => <QuadBadge q={r.quadrant} /> },
    { key: 'snapshot_date',  header: 'Snapshot',       render: (r) => <span className="text-slate-500">{new Date(r.snapshot_date).toLocaleDateString()}</span> },
  ];

  const expandCols: Column<any>[] = [
    { key: 'chain_name',     header: 'Chain',          render: (r) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'region',         header: 'Region',         render: (r) => <span className="font-mono text-xs">{r.region}</span> },
    { key: 'hospital_count', header: 'Hospitals',      render: (r) => <span>{r.hospital_count}</span> },
    { key: 'nps_score',      header: 'NPS',            render: (r) => <span className="text-emerald-700 font-semibold">{Number(r.nps_score).toFixed(1)}</span> },
    { key: 'revenue_rupees', header: 'Revenue',        render: (r) => <span>{fmtINR(r.revenue_rupees)}</span> },
    { key: 'prior_revenue_rupees', header: 'Prior rev', render: (r) => <span className="text-slate-500">{fmtINR(r.prior_revenue_rupees ?? 0)}</span> },
    { key: 'amc_revenue_rupees', header: 'AMC rev',    render: (r) => <span>{fmtINR(r.amc_revenue_rupees)}</span> },
    { key: 'notes',          header: 'Notes',          render: (r) => <span className="text-slate-700">{r.notes ?? '—'}</span> },
  ];

  const protectCols: Column<any>[] = [
    { key: 'chain_name',     header: 'Chain',          render: (r) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'region',         header: 'Region',         render: (r) => <span className="font-mono text-xs">{r.region}</span> },
    { key: 'hospital_count', header: 'Hospitals',      render: (r) => <span>{r.hospital_count}</span> },
    { key: 'nps_score',      header: 'NPS',            render: (r) => <span className="text-rose-700 font-semibold">{Number(r.nps_score).toFixed(1)}</span> },
    { key: 'prior_nps_score', header: 'Prior NPS',     render: (r) => <span className="text-slate-500">{r.prior_nps_score != null ? Number(r.prior_nps_score).toFixed(1) : '—'}</span> },
    { key: 'revenue_rupees', header: 'Revenue',        render: (r) => <span className="font-semibold">{fmtINR(r.revenue_rupees)}</span> },
    { key: 'amc_revenue_rupees', header: 'AMC',        render: (r) => <span>{fmtINR(r.amc_revenue_rupees)}</span> },
    { key: 'job_revenue_rupees', header: 'Jobs',       render: (r) => <span>{fmtINR(r.job_revenue_rupees)}</span> },
    { key: 'notes',          header: 'Notes',          render: (r) => <span className="text-slate-700">{r.notes ?? '—'}</span> },
  ];

  const quadrantCols: Column<any>[] = [
    { key: 'quadrant',       header: 'Quadrant',       render: (r) => <QuadBadge q={r.quadrant} /> },
    { key: 'chain_count',    header: 'Chains',         render: (r) => <span>{r.chain_count}</span> },
    { key: 'total_revenue_rupees', header: 'Total rev', render: (r) => <span className="font-semibold">{fmtINR(r.total_revenue_rupees)}</span> },
    { key: 'avg_nps_score',  header: 'Avg NPS',        render: (r) => <span>{Number(r.avg_nps_score).toFixed(1)}</span> },
    { key: 'avg_revenue_rupees', header: 'Avg rev',    render: (r) => <span>{fmtINR(r.avg_revenue_rupees)}</span> },
    { key: 'playbook',       header: 'Playbook',       render: (r) => <span className="text-slate-700">{r.playbook}</span> },
  ];

  const regionCols: Column<any>[] = [
    { key: 'region',         header: 'Region',         render: (r) => <span className="font-mono">{r.region}</span> },
    { key: 'chain_count',    header: 'Chains',         render: (r) => <span>{r.chain_count}</span> },
    { key: 'weighted_nps',   header: 'Wtd NPS',        render: (r) => <span className="font-semibold">{Number(r.weighted_nps).toFixed(1)}</span> },
    { key: 'total_revenue_rupees', header: 'Revenue',  render: (r) => <span>{fmtINR(r.total_revenue_rupees)}</span> },
    { key: 'protect_count',  header: 'Protect',        render: (r) => <span className="text-rose-700">{r.protect_count}</span> },
    { key: 'expand_count',   header: 'Expand',         render: (r) => <span className="text-emerald-700">{r.expand_count}</span> },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name',     header: 'Chain',          render: (r) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'quadrant',       header: 'Quadrant',       render: (r) => <QuadBadge q={r.quadrant} /> },
    { key: 'action_type',    header: 'Action',         render: (r) => <span className="font-mono text-xs">{r.action_type}</span> },
    { key: 'action_owner_email', header: 'Owner',      render: (r) => <span>{r.action_owner_email ?? '—'}</span> },
    { key: 'due_date',       header: 'Due',            render: (r) => <span>{r.due_date ? new Date(r.due_date).toLocaleDateString() : '—'}</span> },
    { key: 'status',         header: 'Status',         render: (r) => <span className="font-mono">{r.status}</span> },
    { key: 'notes',          header: 'Notes',          render: (r) => <span className="text-slate-700">{r.notes ?? '—'}</span> },
    { key: 'created_at',     header: 'Created',        render: (r) => <span className="text-slate-500">{new Date(r.created_at).toLocaleDateString()}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold tracking-tight">Hospital chain NPS vs revenue scatter</h1>
        <p className="text-sm text-slate-600">
          Each chain plotted on NPS against revenue. High-NPS & low-rev = expand. Low-NPS & high-rev = protect (at-risk whales).
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="Chains tracked"      value={String(k.chains_tracked)} />
        <Kpi label="Weighted NPS"        value={Number(k.weighted_nps).toFixed(1)} accent="emerald" />
        <Kpi label="Total revenue"       value={fmtINR(k.total_revenue_rupees)} />
        <Kpi label="Protect revenue"     value={fmtINR(k.protect_revenue_rupees)} accent="rose" />
        <Kpi label="Star chains"         value={String(k.star_count)} accent="emerald" />
        <Kpi label="Expand candidates"   value={String(k.expand_count)} accent="emerald" />
        <Kpi label="Protect candidates"  value={String(k.protect_count)} accent="rose" />
        <Kpi label="Open actions"        value={String(k.open_actions)} accent="amber" />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Quadrant roll-up</h2>
        <p className="text-xs text-slate-500">Star = high NPS & high rev. Expand = high NPS & low rev. Protect = low NPS & high rev. Fix = low NPS & low rev.</p>
        <DataTable columns={quadrantCols} rows={quadrantRows ?? []} rowKey={(_, i) => String(i)} emptyMessage="No snapshots yet." />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Expand candidates (high NPS, low revenue)</h2>
        <p className="text-xs text-slate-500">Delighted chains with headroom. Push AMC upsell & multi-site rollout.</p>
        <DataTable columns={expandCols} rows={expandRows ?? []} rowKey={(_, i) => String(i)} emptyMessage="No expand candidates." />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Protect candidates (low NPS, high revenue)</h2>
        <p className="text-xs text-slate-500">At-risk whales. Exec visit & retention save before churn lands.</p>
        <DataTable columns={protectCols} rows={protectRows ?? []} rowKey={(_, i) => String(i)} emptyMessage="No protect candidates." />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All chains (scatter feed)</h2>
        <DataTable columns={scatterCols} rows={scatterRows ?? []} rowKey={(_, i) => String(i)} emptyMessage="No chain snapshots." />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Region roll-up</h2>
        <DataTable columns={regionCols} rows={regionRows ?? []} rowKey={(_, i) => String(i)} emptyMessage="No regions." />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Open actions</h2>
        <DataTable columns={actionCols} rows={actionRows ?? []} rowKey={(_, i) => String(i)} emptyMessage="No open actions." />
      </section>
    </main>
  );
}

function QuadBadge({ q }: { q: string }) {
  const color =
    q === 'star'    ? 'bg-emerald-100 text-emerald-800' :
    q === 'expand'  ? 'bg-sky-100 text-sky-800' :
    q === 'protect' ? 'bg-rose-100 text-rose-800' :
                      'bg-slate-100 text-slate-700';
  return <span className={`inline-block rounded px-2 py-0.5 text-xs font-mono uppercase ${color}`}>{q}</span>;
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
