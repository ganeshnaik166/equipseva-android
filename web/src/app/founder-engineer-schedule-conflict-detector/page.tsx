import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerScheduleConflictDetectorPage() {
  const sb = await getSupabaseServerClient();

  const [conflictsRes, resolutionsRes, blockingRes, recentRes] = await Promise.all([
    sb.rpc('list_conflicts_r1920'),
    sb.rpc('list_resolutions_r1920'),
    sb.rpc('blocking_conflicts_r1920'),
    sb.rpc('recent_resolutions_r1920'),
  ]);

  const conflicts: any[] = Array.isArray(conflictsRes.data) ? conflictsRes.data : [];
  const resolutions: any[] = Array.isArray(resolutionsRes.data) ? resolutionsRes.data : [];
  const blocking: any[] = Array.isArray(blockingRes.data) ? blockingRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const conflictsCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'conflict_type', header: 'Type', render: (r: any) => String(r.conflict_type ?? '') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'conflict_window_start', header: 'Window Start', render: (r: any) => r.conflict_window_start ? new Date(r.conflict_window_start).toLocaleString() : '' },
    { key: 'conflict_window_end', header: 'Window End', render: (r: any) => r.conflict_window_end ? new Date(r.conflict_window_end).toLocaleString() : '' },
    { key: 'detected_at', header: 'Detected', render: (r: any) => r.detected_at ? new Date(r.detected_at).toLocaleString() : '' },
  ];

  const blockingCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'conflict_type', header: 'Type', render: (r: any) => String(r.conflict_type ?? '') },
    { key: 'conflict_window_start', header: 'Window Start', render: (r: any) => r.conflict_window_start ? new Date(r.conflict_window_start).toLocaleString() : '' },
    { key: 'conflict_window_end', header: 'Window End', render: (r: any) => r.conflict_window_end ? new Date(r.conflict_window_end).toLocaleString() : '' },
    { key: 'detected_at', header: 'Detected', render: (r: any) => r.detected_at ? new Date(r.detected_at).toLocaleString() : '' },
  ];

  const resolutionsCols: Column<any>[] = [
    { key: 'conflict_id', header: 'Conflict', render: (r: any) => String(r.conflict_id ?? '').slice(0, 8) },
    { key: 'resolution_type', header: 'Resolution', render: (r: any) => String(r.resolution_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => String(r.outcome_md ?? '').slice(0, 80) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'conflict_id', header: 'Conflict', render: (r: any) => String(r.conflict_id ?? '').slice(0, 8) },
    { key: 'resolution_type', header: 'Resolution', render: (r: any) => String(r.resolution_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  const blockingCount = blocking.length;
  const totalConflicts = conflicts.length;
  const totalResolutions = resolutions.length;
  const recentCount = recent.length;

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer Schedule Conflict Detector</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Detect and triage engineer schedule conflicts including double-bookings, travel infeasibility, insufficient rest, and holiday violations.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Blocking conflicts</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: blockingCount > 0 ? '#dc2626' : '#111' }}>{blockingCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total conflicts</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalConflicts}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total resolutions</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalResolutions}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Recent resolutions (14d)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{recentCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Blocking conflicts (severity blocking, open)</h2>
        <DataTable rows={blocking} columns={blockingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All conflicts (latest 200)</h2>
        <DataTable rows={conflicts} columns={conflictsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent resolutions (last 14 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Resolution log (latest 200)</h2>
        <DataTable rows={resolutions} columns={resolutionsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
