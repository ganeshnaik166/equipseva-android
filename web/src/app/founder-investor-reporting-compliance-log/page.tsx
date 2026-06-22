import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorReportingComplianceLogPage() {
  const sb = await getSupabaseServerClient();

  const [reportsRes, overdueRes, actionsRes] = await Promise.all([
    sb.rpc('list_investor_reports_r2125', { p_limit: 100 }),
    sb.rpc('overdue_investor_reports_r2125'),
    sb.rpc('recent_investor_compliance_actions_r2125', { p_limit: 50 }),
  ]);

  const reports: any[] = Array.isArray(reportsRes.data) ? reportsRes.data : [];
  const overdue: any[] = Array.isArray(overdueRes.data) ? overdueRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const reportCols: Column<any>[] = [
    { key: 'report_label', header: 'Report', render: (r: any) => String(r.report_label ?? '') },
    { key: 'report_type', header: 'Type', render: (r: any) => String(r.report_type ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'due_date', header: 'Due', render: (r: any) => String(r.due_date ?? '') },
    { key: 'sent_date', header: 'Sent', render: (r: any) => String(r.sent_date ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '-' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'report_label', header: 'Report', render: (r: any) => String(r.report_label ?? '') },
    { key: 'report_type', header: 'Type', render: (r: any) => String(r.report_type ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'due_date', header: 'Due', render: (r: any) => String(r.due_date ?? '') },
    { key: 'days_overdue', header: 'Days late', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'report_id', header: 'Report', render: (r: any) => String(r.report_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 120) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Reporting Compliance Log</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Track every monthly, quarterly, annual, audit, and incident report owed to each investor. Status moves
          from pending to sent or overdue. Exempted reports are flagged and never escalate. Round r2125.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Overdue reports ({overdue.length})</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Reports past due date, still pending or overdue status. Escalate or mark exempted to clear.
        </p>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All reports ({reports.length})</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Full compliance ledger across investors and report types.
        </p>
        <DataTable rows={reports} columns={reportCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent actions ({actions.length})</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Audit trail of drafts, sends, escalations, exemptions, and closures.
        </p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
