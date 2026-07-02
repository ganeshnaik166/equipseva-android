import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtRupees(n: number | null | undefined): string {
  if (!n && n !== 0) return '-';
  if (n >= 10000000) return `${(n / 10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `${(n / 100000).toFixed(2)} L`;
  return n.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, deptRes, gapsRes, surplusRes, eventsRes, levelRes, restructureRes] = await Promise.all([
    sb.rpc('r2281_org_summary'),
    sb.rpc('r2281_dept_breakdown'),
    sb.rpc('r2281_critical_gaps'),
    sb.rpc('r2281_surplus_roles'),
    sb.rpc('r2281_recent_drift_events'),
    sb.rpc('r2281_level_distribution'),
    sb.rpc('r2281_restructure_recommendations'),
  ]);

  const summary = (summaryRes.data?.[0] ?? {}) as Record<string, number>;
  const dept = (deptRes.data ?? []) as Array<Record<string, unknown>>;
  const gaps = (gapsRes.data ?? []) as Array<Record<string, unknown>>;
  const surplus = (surplusRes.data ?? []) as Array<Record<string, unknown>>;
  const events = (eventsRes.data ?? []) as Array<Record<string, unknown>>;
  const levels = (levelRes.data ?? []) as Array<Record<string, unknown>>;
  const restructure = (restructureRes.data ?? []) as Array<Record<string, unknown>>;

  const deptCols: Column<any>[] = [
    { key: 'department', header: 'Department', render: (r) => String(r.department ?? '') },
    { key: 'target_seats', header: 'Target', render: (r) => String(r.target_seats ?? 0) },
    { key: 'filled_seats', header: 'Filled', render: (r) => String(r.filled_seats ?? 0) },
    { key: 'gap_seats', header: 'Gaps', render: (r) => String(r.gap_seats ?? 0) },
    { key: 'surplus_seats', header: 'Surplus', render: (r) => String(r.surplus_seats ?? 0) },
    { key: 'monthly_cost_rupees', header: 'Monthly Cost (Rs)', render: (r) => fmtRupees(Number(r.monthly_cost_rupees)) },
  ];

  const gapsCols: Column<any>[] = [
    { key: 'role_title', header: 'Role', render: (r) => String(r.role_title ?? '') },
    { key: 'department', header: 'Dept', render: (r) => String(r.department ?? '') },
    { key: 'target_headcount', header: 'Target', render: (r) => String(r.target_headcount ?? 0) },
    { key: 'current_headcount', header: 'Current', render: (r) => String(r.current_headcount ?? 0) },
    { key: 'gap', header: 'Gap', render: (r) => String(r.gap ?? 0) },
    { key: 'hiring_priority', header: 'Priority', render: (r) => String(r.hiring_priority ?? '').toUpperCase() },
    { key: 'monthly_cost_rupees', header: 'Cost/mo (Rs)', render: (r) => fmtRupees(Number(r.monthly_cost_rupees)) },
    { key: 'notes', header: 'Notes', render: (r) => String(r.notes ?? '') },
  ];

  const surplusCols: Column<any>[] = [
    { key: 'role_title', header: 'Role', render: (r) => String(r.role_title ?? '') },
    { key: 'department', header: 'Dept', render: (r) => String(r.department ?? '') },
    { key: 'target_headcount', header: 'Target', render: (r) => String(r.target_headcount ?? 0) },
    { key: 'current_headcount', header: 'Current', render: (r) => String(r.current_headcount ?? 0) },
    { key: 'surplus', header: 'Surplus', render: (r) => String(r.surplus ?? 0) },
    { key: 'notes', header: 'Notes', render: (r) => String(r.notes ?? '') },
  ];

  const levelCols: Column<any>[] = [
    { key: 'level', header: 'Level', render: (r) => String(r.level ?? '').toUpperCase() },
    { key: 'target_count', header: 'Target', render: (r) => String(r.target_count ?? 0) },
    { key: 'current_count', header: 'Current', render: (r) => String(r.current_count ?? 0) },
    { key: 'drift', header: 'Drift', render: (r) => {
      const d = Number(r.drift ?? 0);
      const sign = d > 0 ? '+' : '';
      return `${sign}${d}`;
    } },
  ];

  const eventsCols: Column<any>[] = [
    { key: 'detected_at', header: 'Detected', render: (r) => fmtDate(String(r.detected_at ?? '')) },
    { key: 'role_title', header: 'Role', render: (r) => String(r.role_title ?? '') },
    { key: 'drift_type', header: 'Type', render: (r) => String(r.drift_type ?? '').toUpperCase() },
    { key: 'drift_delta', header: 'Delta', render: (r) => {
      const d = Number(r.drift_delta ?? 0);
      const sign = d > 0 ? '+' : '';
      return `${sign}${d}`;
    } },
    { key: 'recommendation', header: 'Recommendation', render: (r) => String(r.recommendation ?? '') },
    { key: 'acknowledged_at', header: 'Acked', render: (r) => r.acknowledged_at ? fmtDate(String(r.acknowledged_at)) : 'pending' },
  ];

  const restructureCols: Column<any>[] = [
    { key: 'role_title', header: 'Role', render: (r) => String(r.role_title ?? '') },
    { key: 'current_headcount', header: 'Current', render: (r) => String(r.current_headcount ?? 0) },
    { key: 'target_headcount', header: 'Target', render: (r) => String(r.target_headcount ?? 0) },
    { key: 'recommendation', header: 'Recommendation', render: (r) => String(r.recommendation ?? '') },
    { key: 'monthly_cost_rupees', header: 'Cost/mo (Rs)', render: (r) => fmtRupees(Number(r.monthly_cost_rupees)) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Org Chart Drift Detector</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Current vs target org chart — gaps (open roles), surplus (overstaffed), and restructure recommendations.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Target headcount</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.total_target ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Current headcount</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.total_current ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fee2e2', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total gaps</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b91c1c' }}>{summary.total_gaps ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fef3c7', borderRadius: 8, background: '#fffbeb' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total surplus</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#a16207' }}>{summary.total_surplus ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Gap cost/mo</div>
          <div style={{ fontSize: 20, fontWeight: 700 }}>Rs {fmtRupees(Number(summary.monthly_gap_cost_rupees ?? 0))}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fecaca', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Critical gaps</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#991b1b' }}>{summary.critical_gaps ?? 0}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Department breakdown</h2>
        <DataTable columns={deptCols} rows={dept} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Critical gaps (open roles)</h2>
        <DataTable columns={gapsCols} rows={gaps} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Surplus roles (overstaffed)</h2>
        <DataTable columns={surplusCols} rows={surplus} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Level distribution</h2>
        <DataTable columns={levelCols} rows={levels} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Restructure recommendations</h2>
        <DataTable columns={restructureCols} rows={restructure} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent drift events</h2>
        <DataTable columns={eventsCols} rows={events} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
