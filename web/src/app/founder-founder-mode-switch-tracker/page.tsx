import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderModeSwitchTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [switchesRes, distRes, recentRes] = await Promise.all([
    sb.rpc('list_switches_r2082'),
    sb.rpc('mode_distribution_r2082'),
    sb.rpc('recent_outcomes_r2082'),
  ]);

  const switches: any[] = Array.isArray(switchesRes.data) ? switchesRes.data : [];
  const distribution: any[] = Array.isArray(distRes.data) ? distRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const switchCols: Column<any>[] = [
    { key: 'mode_label', header: 'Mode', render: (r: any) => String(r.mode_label ?? '') },
    { key: 'triggered_by', header: 'Trigger', render: (r: any) => String(r.triggered_by ?? '') },
    { key: 'duration_minutes', header: 'Minutes', render: (r: any) => String(r.duration_minutes ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleString() : '' },
  ];

  const distCols: Column<any>[] = [
    { key: 'mode_label', header: 'Mode', render: (r: any) => String(r.mode_label ?? '') },
    { key: 'switch_count', header: 'Switches', render: (r: any) => String(r.switch_count ?? 0) },
    { key: 'total_minutes', header: 'Total minutes', render: (r: any) => String(r.total_minutes ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'mode_label', header: 'Mode', render: (r: any) => String(r.mode_label ?? '') },
    { key: 'outcome_type', header: 'Outcome', render: (r: any) => String(r.outcome_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder mode switch tracker</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Track when founder is in founder mode versus manager mode, strategic mode, execution mode, or recovery.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Mode distribution</h2>
        <DataTable rows={distribution} columns={distCols} rowKey={(r: any, i: number) => String(r.mode_label ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent switches</h2>
        <DataTable rows={switches} columns={switchCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent outcomes</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
