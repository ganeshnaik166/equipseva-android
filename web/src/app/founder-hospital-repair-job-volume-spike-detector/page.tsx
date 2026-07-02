import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [spikesRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_spikes_r2107'),
    sb.rpc('active_spikes_r2107'),
    sb.rpc('recent_actions_r2107'),
  ]);

  const spikes = (spikesRes.data ?? []) as any[];
  const active = (activeRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const spikeCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'baseline_jobs', header: 'Baseline', render: (r: any) => String(r.baseline_jobs ?? 0) },
    { key: 'current_jobs', header: 'Current', render: (r: any) => String(r.current_jobs ?? 0) },
    { key: 'spike_pct', header: 'Spike pct', render: (r: any) => `${Number(r.spike_pct ?? 0).toFixed(1)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'spike_pct', header: 'Spike pct', render: (r: any) => `${Number(r.spike_pct ?? 0).toFixed(1)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'spike_id', header: 'Spike', render: (r: any) => String(r.spike_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Repair Job Volume Spike Detector</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Detect volume spikes per hospital and track actions taken to resolve them.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active spikes</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All spikes</h2>
        <DataTable rows={spikes} columns={spikeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
