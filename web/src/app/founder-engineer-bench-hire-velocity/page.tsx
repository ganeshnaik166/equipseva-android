import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerBenchHireVelocityPage() {
  const sb = await getSupabaseServerClient();

  const [velocitiesRes, behindRes, recentRes] = await Promise.all([
    sb.rpc('list_velocities_r2132'),
    sb.rpc('behind_regions_r2132'),
    sb.rpc('recent_actions_r2132'),
  ]);

  const velocities: any[] = Array.isArray(velocitiesRes.data) ? velocitiesRes.data : [];
  const behind: any[] = Array.isArray(behindRes.data) ? behindRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const velocityCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hires_planned', header: 'Planned', render: (r: any) => String(r.hires_planned ?? 0) },
    { key: 'hires_actual', header: 'Actual', render: (r: any) => String(r.hires_actual ?? 0) },
    { key: 'hire_pace_pct', header: 'Pace pct', render: (r: any) => String(r.hire_pace_pct ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const behindCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hires_planned', header: 'Planned', render: (r: any) => String(r.hires_planned ?? 0) },
    { key: 'hires_actual', header: 'Actual', render: (r: any) => String(r.hires_actual ?? 0) },
    { key: 'hire_pace_pct', header: 'Pace pct', render: (r: any) => String(r.hire_pace_pct ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'velocity_id', header: 'Velocity', render: (r: any) => String(r.velocity_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Engineer Bench Hire Velocity
      </h1>
      <p style={{ color: '#555', marginBottom: '1.5rem' }}>
        Track hire pace per region. Spot regions falling behind plan and log corrective actions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          All velocity snapshots
        </h2>
        <DataTable
          rows={velocities}
          columns={velocityCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Regions behind or critical
        </h2>
        <DataTable
          rows={behind}
          columns={behindCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Recent actions
        </h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
