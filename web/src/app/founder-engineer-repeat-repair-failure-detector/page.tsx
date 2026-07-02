import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [detectorsRes, criticalRes, actionsRes] = await Promise.all([
    sb.rpc('list_detectors_r2168'),
    sb.rpc('critical_engineers_r2168'),
    sb.rpc('recent_actions_r2168'),
  ]);

  const detectors: any[] = Array.isArray(detectorsRes.data) ? detectorsRes.data : [];
  const critical: any[] = Array.isArray(criticalRes.data) ? criticalRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const detectorCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label ?? '' },
    { key: 'repeat_failure_count', header: 'Repeat Failures', render: (r: any) => r.repeat_failure_count ?? 0 },
    { key: 'total_repairs', header: 'Total Repairs', render: (r: any) => r.total_repairs ?? 0 },
    { key: 'repeat_failure_rate_pct', header: 'Rate %', render: (r: any) => `${r.repeat_failure_rate_pct ?? 0}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? 'normal' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const criticalCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label ?? '' },
    { key: 'repeat_failure_rate_pct', header: 'Failure Rate %', render: (r: any) => `${r.repeat_failure_rate_pct ?? 0}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'detector_id', header: 'Detector', render: (r: any) => String(r.detector_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ?? '').slice(0, 80) },
  ];

  const totalDetectors = detectors.length;
  const criticalCount = critical.length;
  const recentActionCount = actions.length;

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Repeat Repair Failure Detector
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Detect engineers with repeat repair failures and track corrective actions.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px' }}>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Total detector records</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{totalDetectors}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Concerning or critical engineers</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{criticalCount}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Recent actions logged</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{recentActionCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Critical Engineers (above normal threshold)
        </h2>
        <DataTable rows={critical} columns={criticalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Detector Records</h2>
        <DataTable rows={detectors} columns={detectorCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
