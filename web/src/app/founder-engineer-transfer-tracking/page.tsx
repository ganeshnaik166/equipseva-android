import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const x = Number(n);
  if (!isFinite(x)) return '—';
  return x.toLocaleString('en-IN');
}

export default async function FounderEngineerTransferTrackingPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let queue: any[] = [];
  let coverage: any[] = [];
  let reasons: any[] = [];
  let decisions: any[] = [];

  try {
    const r = await sb.rpc('founder_transfer_kpis');
    kpis = (r.data && r.data[0]) || null;
  } catch { kpis = null; }

  try {
    const r = await sb.rpc('founder_transfer_pending_queue');
    queue = r.data || [];
  } catch { queue = []; }

  try {
    const r = await sb.rpc('founder_transfer_city_coverage_impact');
    coverage = r.data || [];
  } catch { coverage = []; }

  try {
    const r = await sb.rpc('founder_transfer_reason_breakdown');
    reasons = r.data || [];
  } catch { reasons = []; }

  try {
    const r = await sb.rpc('founder_transfer_recent_decisions');
    decisions = r.data || [];
  } catch { decisions = []; }

  const cards: Kpi[] = [
    { label: 'Total Requests', value: fmtNum(kpis?.total_requests) },
    { label: 'Pending', value: fmtNum(kpis?.pending_count) },
    { label: 'Under Review', value: fmtNum(kpis?.under_review_count) },
    { label: 'Approved', value: fmtNum(kpis?.approved_count) },
    { label: 'Rejected', value: fmtNum(kpis?.rejected_count) },
    { label: 'Withdrawn', value: fmtNum(kpis?.withdrawn_count) },
    { label: 'Completed', value: fmtNum(kpis?.completed_count) },
    { label: 'Avg Days to Decision', value: fmtNum(kpis?.avg_days_to_decision) },
    { label: 'Avg Days Waiting', value: fmtNum(kpis?.avg_days_waiting) },
    { label: 'Cities at Risk', value: fmtNum(kpis?.cities_at_risk) },
    { label: 'Top Outbound City', value: String(kpis?.top_outbound_city ?? '—') },
    { label: 'Top Inbound City', value: String(kpis?.top_inbound_city ?? '—') },
    { label: 'Queue Rows', value: fmtNum(queue.length) },
    { label: 'Cities Tracked', value: fmtNum(coverage.length) },
    { label: 'Reason Buckets', value: fmtNum(reasons.length) },
    { label: 'Recent Decisions', value: fmtNum(decisions.length) },
  ];

  const queueCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'from_city', header: 'From', render: (r: any) => r.from_city ?? '—' },
    { key: 'to_city', header: 'To', render: (r: any) => r.to_city ?? '—' },
    { key: 'reason_category', header: 'Reason', render: (r: any) => r.reason_category ?? '—' },
    { key: 'desired_effective_date', header: 'Desired Date', render: (r: any) => r.desired_effective_date ?? '—' },
    { key: 'days_waiting', header: 'Days Waiting', render: (r: any) => fmtNum(r.days_waiting) },
    { key: 'coverage_risk_score', header: 'Risk Score', render: (r: any) => fmtNum(r.coverage_risk_score) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const coverageCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'current_engineers', header: 'Engineers', render: (r: any) => fmtNum(r.current_engineers) },
    { key: 'outbound_pending', header: 'Outbound', render: (r: any) => fmtNum(r.outbound_pending) },
    { key: 'inbound_pending', header: 'Inbound', render: (r: any) => fmtNum(r.inbound_pending) },
    { key: 'net_change', header: 'Net', render: (r: any) => fmtNum(r.net_change) },
    { key: 'active_jobs', header: 'Active Jobs', render: (r: any) => fmtNum(r.active_jobs) },
    { key: 'risk_label', header: 'Risk', render: (r: any) => r.risk_label ?? '—' },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'reason_category', header: 'Reason', render: (r: any) => r.reason_category ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => fmtNum(r.total) },
    { key: 'approved', header: 'Approved', render: (r: any) => fmtNum(r.approved) },
    { key: 'rejected', header: 'Rejected', render: (r: any) => fmtNum(r.rejected) },
    { key: 'pending', header: 'Pending', render: (r: any) => fmtNum(r.pending) },
    { key: 'approval_rate_pct', header: 'Approval %', render: (r: any) => fmtNum(r.approval_rate_pct) },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'from_city', header: 'From', render: (r: any) => r.from_city ?? '—' },
    { key: 'to_city', header: 'To', render: (r: any) => r.to_city ?? '—' },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '—' },
    { key: 'reviewed_at', header: 'Reviewed At', render: (r: any) => r.reviewed_at ?? '—' },
    { key: 'days_to_decision', header: 'Days to Decision', render: (r: any) => fmtNum(r.days_to_decision) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Transfer / Relocation Tracking</h1>
        <p className="text-sm text-gray-600">Pending approvals, coverage impact, decision velocity.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((k) => (
          <div key={k.label} className="border rounded-lg p-3 bg-white">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Pending Review Queue</h2>
        <DataTable columns={queueCols} rows={queue} rowKey={(r: any) => r.request_id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">City Coverage Impact</h2>
        <DataTable columns={coverageCols} rows={coverage} rowKey={(r: any) => r.city} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Reason Breakdown</h2>
        <DataTable columns={reasonCols} rows={reasons} rowKey={(r: any) => r.reason_category} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Decisions</h2>
        <DataTable columns={decisionCols} rows={decisions} rowKey={(r: any) => r.request_id} />
      </section>
    </div>
  );
}
