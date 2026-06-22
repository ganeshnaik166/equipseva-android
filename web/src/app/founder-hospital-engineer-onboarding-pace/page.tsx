import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pacesRes, slowRes, recentRes] = await Promise.all([
    sb.rpc('list_paces_r1979'),
    sb.rpc('slow_ramps_r1979'),
    sb.rpc('recent_actions_r1979'),
  ]);

  const paces: any[] = Array.isArray(pacesRes.data) ? pacesRes.data : [];
  const slow: any[] = Array.isArray(slowRes.data) ? slowRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const paceCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'first_visit_at', header: 'First Visit', render: (r: any) => r.first_visit_at ? new Date(r.first_visit_at).toLocaleDateString() : '—' },
    { key: 'jobs_first_30d', header: 'Jobs 30d', render: (r: any) => String(r.jobs_first_30d ?? 0) },
    { key: 'jobs_first_60d', header: 'Jobs 60d', render: (r: any) => String(r.jobs_first_60d ?? 0) },
    { key: 'jobs_first_90d', header: 'Jobs 90d', render: (r: any) => String(r.jobs_first_90d ?? 0) },
    { key: 'ramp_status', header: 'Ramp', render: (r: any) => r.ramp_status ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const slowCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'jobs_first_30d', header: 'Jobs 30d', render: (r: any) => String(r.jobs_first_30d ?? 0) },
    { key: 'jobs_first_60d', header: 'Jobs 60d', render: (r: any) => String(r.jobs_first_60d ?? 0) },
    { key: 'jobs_first_90d', header: 'Jobs 90d', render: (r: any) => String(r.jobs_first_90d ?? 0) },
    { key: 'ramp_status', header: 'Ramp', render: (r: any) => r.ramp_status ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Engineer Onboarding Pace</h1>
        <p style={{ color: '#666' }}>
          Track how fast engineers ramp up at each hospital across the first 30, 60 and 90 days.
          Flag slow or blocked ramps and log support actions taken.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All onboarding paces</h2>
        <DataTable rows={paces} columns={paceCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Slow or blocked ramps</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Engineers flagged as slow or blocked. Needs support, shadow, training or rotation.
        </p>
        <DataTable rows={slow} columns={slowCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
