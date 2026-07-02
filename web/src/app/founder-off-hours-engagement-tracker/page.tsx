import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderOffHoursEngagementTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [periodsRes, heavyRes, recentRes] = await Promise.all([
    sb.rpc('list_off_hours_periods_r2150'),
    sb.rpc('heavy_off_hours_periods_r2150'),
    sb.rpc('recent_off_hours_actions_r2150'),
  ]);

  const periods: any[] = Array.isArray(periodsRes.data) ? periodsRes.data : [];
  const heavy: any[] = Array.isArray(heavyRes.data) ? heavyRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const periodColumns: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'off_hour_calls', header: 'Calls', render: (r: any) => String(r.off_hour_calls ?? 0) },
    { key: 'off_hour_emails', header: 'Emails', render: (r: any) => String(r.off_hour_emails ?? 0) },
    { key: 'off_hour_emergencies', header: 'Emergencies', render: (r: any) => String(r.off_hour_emergencies ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const heavyColumns: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'off_hour_calls', header: 'Calls', render: (r: any) => String(r.off_hour_calls ?? 0) },
    { key: 'off_hour_emails', header: 'Emails', render: (r: any) => String(r.off_hour_emails ?? 0) },
    { key: 'off_hour_emergencies', header: 'Emergencies', render: (r: any) => String(r.off_hour_emergencies ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Off-Hours Engagement Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track founder engagement during weekends and vacation windows. Watch for heavy and concerning periods that signal lack of recovery.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All periods</h2>
        <DataTable
          rows={periods}
          columns={periodColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Heavy and concerning periods</h2>
        <p style={{ color: '#666', marginBottom: '8px' }}>
          Periods flagged heavy or concerning need policy review and recovery time.
        </p>
        <DataTable
          rows={heavy}
          columns={heavyColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent actions</h2>
        <DataTable
          rows={recent}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
