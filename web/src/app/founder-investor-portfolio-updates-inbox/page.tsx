import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white px-4 py-3 shadow-sm">
      <div className="text-[11px] uppercase tracking-wider text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return new Intl.NumberFormat('en-IN').format(Number(n));
}
function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return '₹' + new Intl.NumberFormat('en-IN').format(Number(n));
}
function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(1) + '%';
}
function fmtDate(v: string | null | undefined): string {
  if (!v) return "—";
  return new Date(v).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: '2-digit' });
}
function fmtTs(v: string | null | undefined): string {
  if (!v) return "—";
  return new Date(v).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, inboxRes, catRes, benchRes, actionsRes, stageRes, trendRes] = await Promise.all([
    sb.rpc('founder_ipu_kpis'),
    sb.rpc('founder_ipu_inbox'),
    sb.rpc('founder_ipu_by_category'),
    sb.rpc('founder_ipu_benchmark'),
    sb.rpc('founder_ipu_recent_actions'),
    sb.rpc('founder_ipu_stage_breakdown'),
    sb.rpc('founder_ipu_monthly_trend'),
  ]);

  const k: any = (kpisRes.data && (kpisRes.data as any[])[0]) || {};
  const inbox: any[] = (inboxRes.data as any[]) || [];
  const cats: any[] = (catRes.data as any[]) || [];
  const bench: any[] = (benchRes.data as any[]) || [];
  const actions: any[] = (actionsRes.data as any[]) || [];
  const stages: any[] = (stageRes.data as any[]) || [];
  const trend: any[] = (trendRes.data as any[]) || [];

  const inboxCols: Column<any>[] = [
    { key: 'received_at', header: 'Received', render: (r: any) => fmtTs(r.received_at) },
    { key: 'reporting_month', header: 'Month', render: (r: any) => fmtDate(r.reporting_month) },
    { key: 'sender_company', header: 'Company', render: (r: any) => r.sender_company ?? "—" },
    { key: 'sender_founder', header: 'Founder', render: (r: any) => r.sender_founder ?? "—" },
    { key: 'sender_stage', header: 'Stage', render: (r: any) => r.sender_stage ?? "—" },
    { key: 'sector', header: 'Sector', render: (r: any) => r.sector ?? "—" },
    { key: 'intel_category', header: 'Category', render: (r: any) => r.intel_category ?? "—" },
    { key: 'mrr_rupees', header: 'MRR', render: (r: any) => fmtRupees(r.mrr_rupees) },
    { key: 'growth_mom_pct', header: 'MoM', render: (r: any) => fmtPct(r.growth_mom_pct) },
    { key: 'read_state', header: 'State', render: (r: any) => r.read_state ?? "—" },
  ];

  const catCols: Column<any>[] = [
    { key: 'intel_category', header: 'Category', render: (r: any) => r.intel_category ?? "—" },
    { key: 'update_count', header: 'Updates', render: (r: any) => fmtInt(r.update_count) },
    { key: 'avg_growth_pct', header: 'Avg MoM growth', render: (r: any) => fmtPct(r.avg_growth_pct) },
    { key: 'avg_burn_rupees', header: 'Avg burn', render: (r: any) => fmtRupees(r.avg_burn_rupees) },
    { key: 'unread_count', header: 'Unread', render: (r: any) => fmtInt(r.unread_count) },
  ];

  const benchCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric ?? "—" },
    { key: 'our_value', header: 'Ours', render: (r: any) => fmtInt(r.our_value) },
    { key: 'peer_median', header: 'Peer median', render: (r: any) => fmtInt(r.peer_median) },
    { key: 'peer_p75', header: 'Peer P75', render: (r: any) => fmtInt(r.peer_p75) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'acted_at', header: 'When', render: (r: any) => fmtTs(r.acted_at) },
    { key: 'sender_company', header: 'Company', render: (r: any) => r.sender_company ?? "—" },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? "—" },
    { key: 'action_note', header: 'Note', render: (r: any) => r.action_note ?? "—" },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? "—" },
  ];

  const stageCols: Column<any>[] = [
    { key: 'sender_stage', header: 'Stage', render: (r: any) => r.sender_stage ?? "—" },
    { key: 'company_count', header: 'Companies', render: (r: any) => fmtInt(r.company_count) },
    { key: 'avg_mrr_rupees', header: 'Avg MRR', render: (r: any) => fmtRupees(r.avg_mrr_rupees) },
    { key: 'avg_runway_months', header: 'Avg runway (mo)', render: (r: any) => r.avg_runway_months != null ? Number(r.avg_runway_months).toFixed(1) : "—" },
    { key: 'avg_headcount', header: 'Avg HC', render: (r: any) => r.avg_headcount != null ? Number(r.avg_headcount).toFixed(1) : "—" },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-6">
      <div className="mb-4">
        <h1 className="text-2xl font-semibold text-neutral-900">Investor Portfolio Updates Inbox</h1>
        <p className="mt-1 text-sm text-neutral-600">Monthly updates received from other founders, founder-action log, benchmarks vs our metrics, intel categorization.</p>
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-4">
        <Kpi label="Total updates" value={fmtInt(k.total_updates)} />
        <Kpi label="Unread" value={fmtInt(k.unread_count)} />
        <Kpi label="Starred" value={fmtInt(k.starred_count)} />
        <Kpi label="Archived" value={fmtInt(k.archived_count)} />
        <Kpi label="This month" value={fmtInt(k.this_month_count)} />
        <Kpi label="Last month" value={fmtInt(k.last_month_count)} />
        <Kpi label="Unique senders" value={fmtInt(k.unique_senders)} />
        <Kpi label="Unique sectors" value={fmtInt(k.unique_sectors)} />
        <Kpi label="Avg MRR" value={fmtRupees(k.avg_mrr_rupees)} />
        <Kpi label="Median MoM growth" value={fmtPct(k.median_growth_mom_pct)} />
        <Kpi label="Avg runway (mo)" value={k.avg_runway_months != null ? Number(k.avg_runway_months).toFixed(1) : "—"} />
        <Kpi label="Highest growth" value={fmtPct(k.highest_growth_pct)} />
        <Kpi label="Lowest runway" value={k.lowest_runway_months != null ? Number(k.lowest_runway_months).toFixed(1) : "—"} />
        <Kpi label="Actions logged" value={fmtInt(k.actions_logged)} />
        <Kpi label="Follow-ups open" value={fmtInt(k.followups_open)} />
        <Kpi label="Meetings booked" value={fmtInt(k.meetings_booked)} />
      </div>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-neutral-900">Inbox</h2>
        <DataTable<any> columns={inboxCols} rows={inbox} rowKey={(r: any) => r.id} emptyMessage="No portfolio updates yet." />
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-neutral-900">By intel category</h2>
        <DataTable<any> columns={catCols} rows={cats} rowKey={(r: any) => r.id} emptyMessage="No categorized updates." />
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-neutral-900">Benchmark vs our metrics</h2>
        <DataTable<any> columns={benchCols} rows={bench} rowKey={(r: any) => r.id} emptyMessage="No benchmark data." />
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-neutral-900">Recent founder actions</h2>
        <DataTable<any> columns={actionCols} rows={actions} rowKey={(r: any) => r.id} emptyMessage="No actions logged." />
      </section>

      <section className="mt-8 mb-12">
        <h2 className="mb-3 text-lg font-semibold text-neutral-900">Stage breakdown</h2>
        <DataTable<any> columns={stageCols} rows={stages} rowKey={(r: any) => r.id} emptyMessage="No stage data." />
      </section>

      <div className="text-xs text-neutral-500">Monthly trend rows loaded: {fmtInt(trend.length)}</div>
    </div>
  );
}
