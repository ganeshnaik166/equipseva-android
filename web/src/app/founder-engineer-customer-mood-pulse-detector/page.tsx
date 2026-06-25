import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [moods, actions, topConcerned, distribution, statusFunnel, monthlyTrend, ownerLoad] = await Promise.all([
    supabase.rpc('list_moods_r2658'),
    supabase.rpc('list_intervention_actions_r2658'),
    supabase.rpc('top_concerned_focus_r2658'),
    supabase.rpc('mood_distribution_r2658'),
    supabase.rpc('status_funnel_r2658'),
    supabase.rpc('monthly_mood_trend_r2658'),
    supabase.rpc('owner_load_r2658'),
  ]);

  const moodRows = (moods.data as any[]) ?? [];
  const actionRows = (actions.data as any[]) ?? [];
  const topRows = (topConcerned.data as any[]) ?? [];
  const distRows = (distribution.data as any[]) ?? [];
  const funnelRows = (statusFunnel.data as any[]) ?? [];
  const trendRows = (monthlyTrend.data as any[]) ?? [];
  const ownerRows = (ownerLoad.data as any[]) ?? [];

  const moodCols: Column<any>[] = [
    { key: 'detected_at', header: 'Detected', render: (r: any) => new Date(r.detected_at).toLocaleString('en-IN') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id).slice(0, 8) },
    { key: 'mood_kind', header: 'Mood', render: (r: any) => r.mood_kind },
    { key: 'signal_kind', header: 'Signal', render: (r: any) => r.signal_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString('en-IN') },
    { key: 'mood_id', header: 'Mood', render: (r: any) => String(r.mood_id).slice(0, 8) },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id).slice(0, 8) },
    { key: 'concerned_count', header: 'Concerned Count', render: (r: any) => r.concerned_count },
    { key: 'latest_detected', header: 'Latest', render: (r: any) => new Date(r.latest_detected).toLocaleString('en-IN') },
  ];

  const distCols: Column<any>[] = [
    { key: 'mood_kind', header: 'Mood', render: (r: any) => r.mood_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString('en-IN', { year: 'numeric', month: 'short' }) },
    { key: 'delighted', header: 'Delighted', render: (r: any) => r.delighted },
    { key: 'satisfied', header: 'Satisfied', render: (r: any) => r.satisfied },
    { key: 'neutral', header: 'Neutral', render: (r: any) => r.neutral },
    { key: 'concerned', header: 'Concerned', render: (r: any) => r.concerned },
    { key: 'angry', header: 'Angry', render: (r: any) => r.angry },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_moods', header: 'Open Moods', render: (r: any) => r.open_moods },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: '1200px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>Engineer Customer Mood Pulse Detector</h1>
        <p style={{ color: '#555', marginTop: '0.5rem' }}>
          Track engineer-detected hospital mood signals & intervention actions. Spot concerned accounts early
          & route owners to recover them.
        </p>
      </header>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Mood distribution</h2>
        <DataTable
          rows={distRows}
          columns={distCols}
          emptyMessage="No mood signals yet"
          rowKey={(r: any, i: number) => String(r.mood_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Status funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Monthly mood trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend rows"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top concerned hospitals</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No concerned hospitals"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Owner load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owners assigned"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Recent mood signals</h2>
        <DataTable
          rows={moodRows}
          columns={moodCols}
          emptyMessage="No mood signals logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Intervention actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No intervention actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
