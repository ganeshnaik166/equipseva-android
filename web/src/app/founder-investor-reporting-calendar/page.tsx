import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorReportingCalendarPage() {
  const sb = await getSupabaseServerClient();

  const [calendarRes, upcomingRes, lateRes] = await Promise.all([
    sb.rpc('list_calendar_r1781'),
    sb.rpc('upcoming_reports_r1781'),
    sb.rpc('late_reports_r1781'),
  ]);

  const calendar = (calendarRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const late = (lateRes.data ?? []) as any[];

  const totalReports = calendar.length;
  const sentCount = calendar.filter((r: any) => r.status === 'sent').length;
  const lateCount = late.length;
  const upcomingCount = upcoming.length;

  const calendarCols: Column<any>[] = [
    { key: 'report_type', header: 'Type', render: (r: any) => String(r.report_type ?? '') },
    { key: 'fiscal_year', header: 'FY', render: (r: any) => String(r.fiscal_year ?? '') },
    { key: 'due_date', header: 'Due Date', render: (r: any) => String(r.due_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '-') },
    { key: 'distribution_count', header: 'Recipients', render: (r: any) => String(r.distribution_count ?? 0) },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until ?? 0) },
    { key: 'sent_at', header: 'Sent At', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '-' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'report_type', header: 'Type', render: (r: any) => String(r.report_type ?? '') },
    { key: 'due_date', header: 'Due Date', render: (r: any) => String(r.due_date ?? '') },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const lateCols: Column<any>[] = [
    { key: 'report_type', header: 'Type', render: (r: any) => String(r.report_type ?? '') },
    { key: 'due_date', header: 'Due Date', render: (r: any) => String(r.due_date ?? '') },
    { key: 'days_late', header: 'Days Late', render: (r: any) => String(r.days_late ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Reporting Calendar</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track monthly updates, quarterly reports, annual filings, board packs and special asks.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total reports</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalReports}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Sent</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#16a34a' }}>{sentCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Upcoming</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#2563eb' }}>{upcomingCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Late</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#dc2626' }}>{lateCount}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Late reports</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>
          Reports past due that have not been sent or cancelled.
        </p>
        <DataTable rows={late} columns={lateCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Upcoming reports</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>
          Next 50 deadlines in upcoming or in-progress status.
        </p>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Full calendar</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>
          All scheduled investor reports across every fiscal year.
        </p>
        <DataTable rows={calendar} columns={calendarCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
