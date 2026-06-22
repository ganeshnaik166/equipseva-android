import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorAnnualReportSchedulePage() {
  const sb = await getSupabaseServerClient();

  const [schedulesRes, dueSoonRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_investor_annual_report_schedules_r2081'),
    sb.rpc('due_soon_investor_annual_reports_r2081'),
    sb.rpc('recent_investor_annual_report_actions_r2081'),
  ]);

  const schedules: any[] = Array.isArray(schedulesRes.data) ? schedulesRes.data : [];
  const dueSoon: any[] = Array.isArray(dueSoonRes.data) ? dueSoonRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const scheduleCols: Column<any>[] = [
    { key: 'fy_year', header: 'FY year', render: (r: any) => String(r.fy_year ?? '') },
    { key: 'scheduled_send_date', header: 'Scheduled send', render: (r: any) => String(r.scheduled_send_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'sent_at', header: 'Sent at', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : 'pending' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const dueSoonCols: Column<any>[] = [
    { key: 'fy_year', header: 'FY year', render: (r: any) => String(r.fy_year ?? '') },
    { key: 'scheduled_send_date', header: 'Scheduled send', render: (r: any) => String(r.scheduled_send_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'days_remaining', header: 'Days remaining', render: (r: any) => {
        if (!r.scheduled_send_date) return '';
        const ms = new Date(r.scheduled_send_date).getTime() - Date.now();
        const days = Math.ceil(ms / 86400000);
        return String(days);
      } },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'report_id', header: 'Report', render: (r: any) => String(r.report_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  const totalCount = schedules.length;
  const sentCount = schedules.filter((s: any) => s.status === 'sent').length;
  const dueSoonCount = dueSoon.length;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Annual Report Schedule</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track planned and completed annual investor reports across fiscal years. Status transitions logged for audit.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total schedules</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalCount}</div>
          </div>
          <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Sent</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{sentCount}</div>
          </div>
          <div style={{ padding: 16, background: '#fef3c7', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Due within 30 days</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{dueSoonCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Due soon (next 30 days)</h2>
        <DataTable rows={dueSoon} columns={dueSoonCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All scheduled reports</h2>
        <DataTable rows={schedules} columns={scheduleCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent action log</h2>
        <DataTable rows={recentActions} columns={actionsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
