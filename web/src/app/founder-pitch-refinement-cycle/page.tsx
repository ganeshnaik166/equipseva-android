import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPitchRefinementCyclePage() {
  const sb = await getSupabaseServerClient();

  const [versionsRes, signalsRes, currentRes, recentRes] = await Promise.all([
    sb.rpc('founder_pitch_list_versions_r2054'),
    sb.rpc('founder_pitch_list_signals_r2054'),
    sb.rpc('founder_pitch_current_pitch_r2054'),
    sb.rpc('founder_pitch_recent_signals_r2054'),
  ]);

  const versions: any[] = Array.isArray(versionsRes.data) ? versionsRes.data : [];
  const signals: any[] = Array.isArray(signalsRes.data) ? signalsRes.data : [];
  const currentPitches: any[] = Array.isArray(currentRes.data) ? currentRes.data : [];
  const recentSignals: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const versionColumns: Column<any>[] = [
    { key: 'pitch_version_label', header: 'Version', render: (r: any) => String(r.pitch_version_label ?? '') },
    { key: 'audience_segment', header: 'Audience', render: (r: any) => String(r.audience_segment ?? '').replace('_', ' ') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'key_changes_md', header: 'Key Changes', render: (r: any) => {
      const s = String(r.key_changes_md ?? '');
      return s.length > 120 ? s.slice(0, 120) + '...' : s;
    }},
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const signalColumns: Column<any>[] = [
    { key: 'pitch_version_label', header: 'Version', render: (r: any) => String(r.pitch_version_label ?? '') },
    { key: 'signal_type', header: 'Signal', render: (r: any) => String(r.signal_type ?? '').replace('_', ' ') },
    { key: 'signal_md', header: 'Detail', render: (r: any) => {
      const s = String(r.signal_md ?? '');
      return s.length > 140 ? s.slice(0, 140) + '...' : s;
    }},
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const currentColumns: Column<any>[] = [
    { key: 'pitch_version_label', header: 'Version', render: (r: any) => String(r.pitch_version_label ?? '') },
    { key: 'audience_segment', header: 'Audience', render: (r: any) => String(r.audience_segment ?? '').replace('_', ' ') },
    { key: 'signal_count', header: 'Signals', render: (r: any) => String(r.signal_count ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'signal_type', header: 'Signal Type', render: (r: any) => String(r.signal_type ?? '').replace('_', ' ') },
    { key: 'signal_count', header: 'Count (90d)', render: (r: any) => String(r.signal_count ?? 0) },
    { key: 'latest_signal', header: 'Latest', render: (r: any) => r.latest_signal ? new Date(r.latest_signal).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Pitch Refinement Cycle
      </h1>
      <p style={{ color: '#6b7280', marginBottom: '24px' }}>
        Track every iteration of the pitch, capture qualitative signals from investor conversations,
        and learn which framing lands with which audience segment.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Active Pitch Versions</h2>
        <DataTable
          rows={currentPitches}
          columns={currentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Signal Mix (last 90 days)</h2>
        <DataTable
          rows={recentSignals}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.signal_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Pitch Versions</h2>
        <DataTable
          rows={versions}
          columns={versionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Signals</h2>
        <DataTable
          rows={signals}
          columns={signalColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
