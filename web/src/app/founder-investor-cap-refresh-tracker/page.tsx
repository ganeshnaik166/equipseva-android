import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorCapRefreshTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [schedulesRes, upcomingRes, recentRes, documentsRes] = await Promise.all([
    sb.rpc('list_cap_refresh_schedules_r1777'),
    sb.rpc('upcoming_cap_refreshes_r1777'),
    sb.rpc('recent_cap_refreshes_r1777'),
    sb.rpc('list_cap_refresh_documents_r1777', { p_schedule_id: null }),
  ]);

  const schedules: any[] = Array.isArray(schedulesRes.data) ? schedulesRes.data : [];
  const upcoming: any[] = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const documents: any[] = Array.isArray(documentsRes.data) ? documentsRes.data : [];

  const totalSchedules = schedules.length;
  const scheduledCount = schedules.filter((s) => s.status === 'scheduled').length;
  const inProgressCount = schedules.filter((s) => s.status === 'in_progress').length;
  const completedCount = schedules.filter((s) => s.status === 'completed').length;
  const docCount = documents.length;

  const scheduleColumns: Column<any>[] = [
    { key: 'refresh_type', header: 'Type', render: (r: any) => String(r.refresh_type ?? '') },
    { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => String(r.scheduled_date ?? '') },
    { key: 'completed_date', header: 'Completed', render: (r: any) => String(r.completed_date ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'doc_count', header: 'Docs', render: (r: any) => String(r.doc_count ?? 0) },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const upcomingColumns: Column<any>[] = [
    { key: 'refresh_type', header: 'Type', render: (r: any) => String(r.refresh_type ?? '') },
    { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => String(r.scheduled_date ?? '') },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'refresh_type', header: 'Type', render: (r: any) => String(r.refresh_type ?? '') },
    { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => String(r.scheduled_date ?? '') },
    { key: 'completed_date', header: 'Completed', render: (r: any) => String(r.completed_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'doc_count', header: 'Docs', render: (r: any) => String(r.doc_count ?? 0) },
  ];

  const documentColumns: Column<any>[] = [
    { key: 'refresh_type', header: 'Refresh Type', render: (r: any) => String(r.refresh_type ?? '') },
    { key: 'document_type', header: 'Document', render: (r: any) => String(r.document_type ?? '') },
    { key: 'document_url', header: 'URL', render: (r: any) => String(r.document_url ?? '') },
    { key: 'uploaded_at', header: 'Uploaded', render: (r: any) => String(r.uploaded_at ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  return (
    <main style={{ padding: '24px', fontFamily: 'system-ui, sans-serif', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: 0 }}>Investor Cap Refresh Tracker</h1>
        <p style={{ color: '#555', marginTop: '6px' }}>
          Track upcoming cap table refreshes (annual review, new round, secondary sale, employee grants & buybacks) and attach supporting documents.
        </p>
      </header>

      <section style={{ marginBottom: '24px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
          <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Total Schedules</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{totalSchedules}</div>
          </div>
          <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Scheduled</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{scheduledCount}</div>
          </div>
          <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>In Progress</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{inProgressCount}</div>
          </div>
          <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Completed</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{completedCount}</div>
          </div>
          <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Documents Attached</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{docCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Upcoming Refreshes</h2>
        <p style={{ color: '#6b7280', fontSize: '13px', marginBottom: '8px' }}>
          Scheduled refreshes with countdown — next 25 only.
        </p>
        <DataTable
          rows={upcoming}
          columns={upcomingColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>All Schedules</h2>
        <p style={{ color: '#6b7280', fontSize: '13px', marginBottom: '8px' }}>
          Every cap refresh record (most recent first).
        </p>
        <DataTable
          rows={schedules}
          columns={scheduleColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Recent Completions</h2>
        <p style={{ color: '#6b7280', fontSize: '13px', marginBottom: '8px' }}>
          Last 25 refreshes marked completed.
        </p>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Attached Documents</h2>
        <p style={{ color: '#6b7280', fontSize: '13px', marginBottom: '8px' }}>
          409A valuations, board resolutions, secretary certificates & term sheet amendments.
        </p>
        <DataTable
          rows={documents}
          columns={documentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
