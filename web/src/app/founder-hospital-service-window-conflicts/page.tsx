import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalServiceWindowConflictsPage() {
  const sb = await getSupabaseServerClient();

  const [conflictsRes, resolutionsRes, patternRes, recentRes] = await Promise.all([
    sb.rpc('list_hsw_conflicts_r1843'),
    sb.rpc('list_hsw_resolutions_r1843', { p_conflict_id: null }),
    sb.rpc('hsw_conflict_pattern_summary_r1843'),
    sb.rpc('hsw_recent_conflicts_r1843'),
  ]);

  const conflicts: any[] = Array.isArray(conflictsRes.data) ? conflictsRes.data : [];
  const resolutions: any[] = Array.isArray(resolutionsRes.data) ? resolutionsRes.data : [];
  const patterns: any[] = Array.isArray(patternRes.data) ? patternRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalConflicts = conflicts.length;
  const openConflicts = conflicts.filter((c) => !c.is_resolved).length;
  const resolvedConflicts = totalConflicts - openConflicts;
  const recentCount = recent.length;

  const conflictColumns: Column<any>[] = [
    { key: 'conflict_at', header: 'Conflict At', render: (r: any) => new Date(r.conflict_at).toLocaleString() },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? 0) },
    { key: 'resolution_path', header: 'Path', render: (r: any) => r.resolution_path ?? '—' },
    { key: 'is_resolved', header: 'Status', render: (r: any) => (r.is_resolved ? 'resolved' : 'open') },
    { key: 'resolved_at', header: 'Resolved At', render: (r: any) => (r.resolved_at ? new Date(r.resolved_at).toLocaleString() : '—') },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '—' },
  ];

  const resolutionColumns: Column<any>[] = [
    { key: 'action_taken_at', header: 'Action At', render: (r: any) => new Date(r.action_taken_at).toLocaleString() },
    { key: 'conflict_id', header: 'Conflict', render: (r: any) => String(r.conflict_id).slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '—' },
    { key: 'customer_response', header: 'Customer Response', render: (r: any) => r.customer_response ?? '—' },
  ];

  const patternColumns: Column<any>[] = [
    { key: 'resolution_path', header: 'Resolution Path', render: (r: any) => r.resolution_path ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
    { key: 'resolved', header: 'Resolved', render: (r: any) => String(r.resolved ?? 0) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'avg_hospitals', header: 'Avg Hospitals', render: (r: any) => String(r.avg_hospitals ?? 0) },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'conflict_at', header: 'Conflict At', render: (r: any) => new Date(r.conflict_at).toLocaleString() },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? 0) },
    { key: 'resolution_path', header: 'Path', render: (r: any) => r.resolution_path ?? '—' },
    { key: 'is_resolved', header: 'Status', render: (r: any) => (r.is_resolved ? 'resolved' : 'open') },
    { key: 'age_hours', header: 'Age (hours)', render: (r: any) => String(r.age_hours ?? 0) },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>Hospital Service Window Conflicts</h1>
        <p style={{ color: '#666', marginTop: '0.5rem' }}>
          Track simultaneous emergency-service capacity conflicts & resolution paths across hospitals.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
        <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Total conflicts</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 700 }}>{totalConflicts}</div>
        </div>
        <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Open</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 700, color: '#b91c1c' }}>{openConflicts}</div>
        </div>
        <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Resolved</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 700, color: '#047857' }}>{resolvedConflicts}</div>
        </div>
        <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Last 7 days</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 700 }}>{recentCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Recent conflicts (7d)</h2>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All conflicts</h2>
        <DataTable rows={conflicts} columns={conflictColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Resolution log</h2>
        <DataTable rows={resolutions} columns={resolutionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Pattern summary</h2>
        <DataTable rows={patterns} columns={patternColumns} rowKey={(r: any, i: number) => String(r.resolution_path ?? i)} />
      </section>
    </main>
  );
}
