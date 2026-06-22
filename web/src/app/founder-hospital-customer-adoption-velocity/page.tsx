import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [velocitiesRes, acceleratingRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_velocities_r2167'),
    sb.rpc('accelerating_r2167'),
    sb.rpc('recent_actions_r2167'),
  ]);

  const velocities: any[] = Array.isArray(velocitiesRes.data) ? velocitiesRes.data : [];
  const accelerating: any[] = Array.isArray(acceleratingRes.data) ? acceleratingRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const velocityCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label ?? '' },
    { key: 'new_features_adopted', header: 'New', render: (r: any) => r.new_features_adopted ?? 0 },
    { key: 'total_features_used', header: 'Total', render: (r: any) => r.total_features_used ?? 0 },
    { key: 'adoption_velocity_pct', header: 'Velocity pct', render: (r: any) => `${r.adoption_velocity_pct ?? 0}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const accelCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label ?? '' },
    { key: 'adoption_velocity_pct', header: 'Velocity pct', render: (r: any) => `${r.adoption_velocity_pct ?? 0}%` },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'velocity_id', header: 'Velocity', render: (r: any) => String(r.velocity_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Customer Adoption Velocity</h1>
        <p className="text-sm text-gray-600">Track adoption velocity per hospital across periods.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All velocities</h2>
        <DataTable rows={velocities} columns={velocityCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Accelerating hospitals</h2>
        <DataTable rows={accelerating} columns={accelCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent actions</h2>
        <DataTable rows={recentActions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
