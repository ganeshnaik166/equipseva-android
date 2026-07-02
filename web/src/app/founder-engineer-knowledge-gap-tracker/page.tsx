import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type GapRow = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  gap_topic: string;
  gap_source: string;
  severity: string;
  status: string;
  opened_at: string;
  closed_at: string | null;
};

type SeverityRow = {
  severity: string;
  open_count: number;
  in_training_count: number;
  closed_count: number;
  escalated_count: number;
  total_count: number;
};

type RemediationRow = {
  id: string;
  gap_id: string;
  gap_topic: string | null;
  action_type: string;
  taken_at: string;
  by_email: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [gapsRes, sevRes, remRes] = await Promise.all([
    sb.rpc('list_gaps_r1908'),
    sb.rpc('gaps_by_severity_r1908'),
    sb.rpc('recent_remediations_r1908'),
  ]);

  const gaps: GapRow[] = (gapsRes.data as GapRow[] | null) ?? [];
  const sevs: SeverityRow[] = (sevRes.data as SeverityRow[] | null) ?? [];
  const rems: RemediationRow[] = (remRes.data as RemediationRow[] | null) ?? [];

  const totalGaps = gaps.length;
  const openGaps = gaps.filter((g) => g.status === 'open').length;
  const criticalGaps = gaps.filter((g) => g.severity === 'critical').length;
  const escalatedGaps = gaps.filter((g) => g.status === 'escalated').length;

  const gapCols: Column<GapRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id?.slice(0, 8) },
    { key: 'gap_topic', header: 'Topic', render: (r: any) => r.gap_topic },
    { key: 'gap_source', header: 'Source', render: (r: any) => r.gap_source },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'opened_at', header: 'Opened', render: (r: any) => new Date(r.opened_at).toLocaleString() },
    { key: 'closed_at', header: 'Closed', render: (r: any) => (r.closed_at ? new Date(r.closed_at).toLocaleString() : '-') },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'in_training_count', header: 'In Training', render: (r: any) => r.in_training_count },
    { key: 'closed_count', header: 'Closed', render: (r: any) => r.closed_count },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => r.escalated_count },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
  ];

  const remCols: Column<RemediationRow>[] = [
    { key: 'gap_topic', header: 'Topic', render: (r: any) => r.gap_topic ?? r.gap_id?.slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email },
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Knowledge Gap Tracker</h1>
        <p className="text-sm text-gray-600">
          Track gaps engineers self-report &amp; supervisors flag. Severity &gt;= high needs escalation review.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Total Gaps</div>
          <div className="text-2xl font-semibold">{totalGaps}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Open</div>
          <div className="text-2xl font-semibold">{openGaps}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Critical Severity</div>
          <div className="text-2xl font-semibold">{criticalGaps}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Escalated</div>
          <div className="text-2xl font-semibold">{escalatedGaps}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity Breakdown</h2>
        <p className="text-xs text-gray-500 mb-2">Rows where open &gt; 0 &amp; severity &gt;= high deserve action.</p>
        <DataTable rows={sevs} columns={sevCols} rowKey={(r: any, i: number) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Gaps (latest 200)</h2>
        <DataTable rows={gaps} columns={gapCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Remediation Actions</h2>
        <DataTable rows={rems} columns={remCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
