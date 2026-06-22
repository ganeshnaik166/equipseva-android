import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pacingsRes, slowRes, recentRes] = await Promise.all([
    sb.rpc('list_pacings_r2172'),
    sb.rpc('slow_onboardings_r2172'),
    sb.rpc('recent_actions_r2172'),
  ]);

  const pacings: any[] = Array.isArray(pacingsRes.data) ? pacingsRes.data : [];
  const slow: any[] = Array.isArray(slowRes.data) ? slowRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const pacingCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'days_to_first_job', header: 'Days to 1st Job', render: (r: any) => String(r.days_to_first_job ?? '-') },
    { key: 'days_to_first_solo', header: 'Days to Solo', render: (r: any) => String(r.days_to_first_solo ?? '-') },
    { key: 'days_to_certification', header: 'Days to Cert', render: (r: any) => String(r.days_to_certification ?? '-') },
    { key: 'onboarding_status', header: 'Status', render: (r: any) => String(r.onboarding_status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const slowCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'days_to_first_job', header: 'Days to 1st Job', render: (r: any) => String(r.days_to_first_job ?? '-') },
    { key: 'days_to_certification', header: 'Days to Cert', render: (r: any) => String(r.days_to_certification ?? '-') },
    { key: 'onboarding_status', header: 'Status', render: (r: any) => String(r.onboarding_status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'pacing_id', header: 'Pacing', render: (r: any) => String(r.pacing_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer Onboarding Pacing</h1>
      <p style={{ color: '#666' }}>Track new engineer onboarding pace, slow ramps, and recent milestone actions.</p>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Pacings</h2>
        <DataTable rows={pacings} columns={pacingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Slow or Blocked Onboardings</h2>
        <DataTable rows={slow} columns={slowCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
