import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
      <div className="text-xs font-medium uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-2 text-2xl font-semibold text-slate-900">{value}</div>
    </div>
  );
}

function fmtR(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "₹" + n.toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return n.toLocaleString('en-IN');
}

function fmtHrs(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return n.toFixed(1) + " h";
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

function StatusPill({ status }: { status: string }) {
  const colors: Record<string, string> = {
    raised: 'bg-amber-100 text-amber-800',
    investigating: 'bg-blue-100 text-blue-800',
    resolved: 'bg-emerald-100 text-emerald-800',
    escalated: 'bg-red-100 text-red-800',
    closed: 'bg-slate-100 text-slate-700',
  };
  return <span className={"inline-block rounded-full px-2 py-0.5 text-xs font-medium " + (colors[status] ?? 'bg-slate-100 text-slate-700')}>{status}</span>;
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, openRes, byTypeRes, topEngRes, eventsRes] = await Promise.all([
    sb.rpc('founder_dispute_kpis'),
    sb.rpc('founder_dispute_open_feed'),
    sb.rpc('founder_dispute_by_type'),
    sb.rpc('founder_dispute_top_engineers'),
    sb.rpc('founder_dispute_recent_events'),
  ]);

  const k: any = (kpisRes.data && (kpisRes.data as any[])[0]) ?? {};
  const openRows: any[] = (openRes.data as any[]) ?? [];
  const byTypeRows: any[] = (byTypeRes.data as any[]) ?? [];
  const topEngRows: any[] = (topEngRes.data as any[]) ?? [];
  const eventRows: any[] = (eventsRes.data as any[]) ?? [];

  const openCols: Column<any>[] = [
    { key: 'raised_at', header: 'Raised', render: (r: any) => fmtDate(r.raised_at) },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? "—" },
    { key: 'dispute_type', header: 'Type', render: (r: any) => r.dispute_type ?? "—" },
    { key: 'status', header: 'Status', render: (r: any) => <StatusPill status={r.status} /> },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority ?? "—" },
    { key: 'claimed_amount_rupees', header: 'Claimed', render: (r: any) => fmtR(r.claimed_amount_rupees) },
    { key: 'current_amount_rupees', header: 'Current', render: (r: any) => fmtR(r.current_amount_rupees) },
    { key: 'delta_rupees', header: 'Delta', render: (r: any) => fmtR(r.delta_rupees) },
    { key: 'hours_to_sla', header: 'SLA (h)', render: (r: any) => fmtHrs(r.hours_to_sla) },
    { key: 'engineer_notes', header: 'Notes', render: (r: any) => <span className="line-clamp-2 text-xs text-slate-600">{r.engineer_notes ?? "—"}</span> },
  ];

  const byTypeCols: Column<any>[] = [
    { key: 'dispute_type', header: 'Type', render: (r: any) => r.dispute_type ?? "—" },
    { key: 'total', header: 'Total', render: (r: any) => fmtNum(r.total) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => fmtNum(r.resolved_count) },
    { key: 'avg_resolution_hours', header: 'Avg Resolution', render: (r: any) => fmtHrs(r.avg_resolution_hours) },
    { key: 'total_delta_rupees', header: 'Total Delta', render: (r: any) => fmtR(r.total_delta_rupees) },
  ];

  const topEngCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? "—" },
    { key: 'dispute_count', header: 'Total Disputes', render: (r: any) => fmtNum(r.dispute_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'total_delta_rupees', header: 'Total Delta', render: (r: any) => fmtR(r.total_delta_rupees) },
    { key: 'last_raised_at', header: 'Last Raised', render: (r: any) => fmtDate(r.last_raised_at) },
  ];

  const eventCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => fmtDate(r.created_at) },
    { key: 'dispute_id', header: 'Dispute', render: (r: any) => <span className="font-mono text-xs">{(r.dispute_id ?? "").slice(0, 8)}</span> },
    { key: 'from_status', header: 'From', render: (r: any) => r.from_status ? <StatusPill status={r.from_status} /> : <span className="text-slate-400">new</span> },
    { key: 'to_status', header: 'To', render: (r: any) => <StatusPill status={r.to_status} /> },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? "—" },
    { key: 'note', header: 'Note', render: (r: any) => <span className="line-clamp-2 text-xs text-slate-600">{r.note ?? "—"}</span> },
  ];

  return (
    <main className="min-h-screen bg-slate-50 px-6 py-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-6">
          <h1 className="text-2xl font-bold text-slate-900">Engineer Payouts Disputes Ledger</h1>
          <p className="mt-1 text-sm text-slate-600">5-state machine (raised → investigating → resolved → escalated → closed) with 48h founder-side SLA.</p>
        </header>

        <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Kpi label="Total Disputes" value={fmtNum(k.total_disputes)} />
          <Kpi label="Open" value={fmtNum(k.open_count)} />
          <Kpi label="Raised" value={fmtNum(k.raised_count)} />
          <Kpi label="Investigating" value={fmtNum(k.investigating_count)} />
          <Kpi label="Resolved" value={fmtNum(k.resolved_count)} />
          <Kpi label="Escalated" value={fmtNum(k.escalated_count)} />
          <Kpi label="Closed" value={fmtNum(k.closed_count)} />
          <Kpi label="SLA Breached" value={fmtNum(k.sla_breached)} />
          <Kpi label="SLA Within 4h" value={fmtNum(k.sla_within_4h)} />
          <Kpi label="Median Resolution" value={fmtHrs(k.median_resolution_hours)} />
          <Kpi label="Total Delta" value={fmtR(k.total_delta_rupees)} />
          <Kpi label="Paid Back" value={fmtR(k.paid_back_rupees)} />
          <Kpi label="Urgent Open" value={fmtNum(k.urgent_count)} />
          <Kpi label="Last 24h Raised" value={fmtNum(k.last_24h_raised)} />
          <Kpi label="Amount Disputes" value={fmtNum(k.amount_disputes)} />
          <Kpi label="Missing Disputes" value={fmtNum(k.missing_disputes)} />
        </section>

        <section className="mt-8">
          <h2 className="mb-3 text-lg font-semibold text-slate-900">Open Disputes Feed</h2>
          <DataTable columns={openCols} rows={openRows} rowKey={(r: any) => r.id} emptyMessage="No open disputes" />
        </section>

        <section className="mt-8">
          <h2 className="mb-3 text-lg font-semibold text-slate-900">By Dispute Type</h2>
          <DataTable columns={byTypeCols} rows={byTypeRows} rowKey={(r: any) => r.dispute_type} emptyMessage="No data" />
        </section>

        <section className="mt-8">
          <h2 className="mb-3 text-lg font-semibold text-slate-900">Top Disputing Engineers</h2>
          <DataTable columns={topEngCols} rows={topEngRows} rowKey={(r: any) => r.engineer_user_id} emptyMessage="No engineers with disputes" />
        </section>

        <section className="mt-8">
          <h2 className="mb-3 text-lg font-semibold text-slate-900">Recent State Transitions</h2>
          <DataTable columns={eventCols} rows={eventRows} rowKey={(r: any) => r.id} emptyMessage="No transitions yet" />
        </section>
      </div>
    </main>
  );
}
