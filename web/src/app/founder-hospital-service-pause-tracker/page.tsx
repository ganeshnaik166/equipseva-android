import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalServicePauseTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [pausesRes, summaryRes, churnRes] = await Promise.all([
    sb.rpc('list_pauses_r1795', { p_status: null, p_limit: 200 }),
    sb.rpc('active_pauses_summary_r1795'),
    sb.rpc('churn_risk_pauses_r1795'),
  ]);

  const pauses: any[] = (pausesRes.data as any[]) ?? [];
  const summary: any[] = (summaryRes.data as any[]) ?? [];
  const churn: any[] = (churnRes.data as any[]) ?? [];

  const activeTotal = pauses.filter((p) => p.status === 'active').length;
  const extendedTotal = pauses.filter((p) => p.status === 'extended').length;
  const resumedTotal = pauses.filter((p) => p.status === 'resumed').length;
  const churnTotal = pauses.filter((p) => p.status === 'converted_to_churn').length;

  const pauseCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'organization_name', header: 'Org', render: (r: any) => r.organization_name ?? '—' },
    { key: 'pause_reason', header: 'Reason', render: (r: any) => r.pause_reason },
    { key: 'pause_start', header: 'Start', render: (r: any) => r.pause_start ? new Date(r.pause_start).toLocaleDateString() : '—' },
    { key: 'expected_resume_at', header: 'Expected Resume', render: (r: any) => r.expected_resume_at ? new Date(r.expected_resume_at).toLocaleDateString() : '—' },
    { key: 'days_paused', header: 'Days Paused', render: (r: any) => String(r.days_paused ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'action_count', header: 'Actions', render: (r: any) => String(r.action_count ?? 0) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'pause_reason', header: 'Reason', render: (r: any) => r.pause_reason },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'avg_days_paused', header: 'Avg Days', render: (r: any) => r.avg_days_paused != null ? String(r.avg_days_paused) : '—' },
    { key: 'longest_days', header: 'Longest', render: (r: any) => String(r.longest_days ?? 0) },
  ];

  const churnCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'organization_name', header: 'Org', render: (r: any) => r.organization_name ?? '—' },
    { key: 'pause_reason', header: 'Reason', render: (r: any) => r.pause_reason },
    { key: 'pause_start', header: 'Started', render: (r: any) => r.pause_start ? new Date(r.pause_start).toLocaleDateString() : '—' },
    { key: 'days_paused', header: 'Days Paused', render: (r: any) => String(r.days_paused ?? 0) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Hospital Service Pause Tracker</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track when hospitals pause service (vacation, equipment offline, financial hold). Flags overdue resumes and churn-risk pauses.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Active Pauses</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{activeTotal}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Extended</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{extendedTotal}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Resumed</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{resumedTotal}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Converted to Churn</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{churnTotal}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #fecaca', borderRadius: '8px', background: '#fef2f2' }}>
          <div style={{ fontSize: '12px', color: '#991b1b' }}>Churn-Risk Open</div>
          <div style={{ fontSize: '24px', fontWeight: 700, color: '#991b1b' }}>{churn.length}</div>
        </div>
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Active Pauses Summary by Reason</h2>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.pause_reason ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Churn-Risk Pauses (overdue resume OR &gt;30 days OR financial/dispute)
        </h2>
        <DataTable rows={churn} columns={churnCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Pauses (latest 200)</h2>
        <DataTable rows={pauses} columns={pauseCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
