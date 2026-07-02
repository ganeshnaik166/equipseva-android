import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [drifts, significant, recent] = await Promise.all([
    sb.rpc('list_drifts_r1929'),
    sb.rpc('significant_drifts_r1929'),
    sb.rpc('recent_reconciliations_r1929'),
  ]);

  const driftRows: any[] = Array.isArray(drifts.data) ? drifts.data : [];
  const sigRows: any[] = Array.isArray(significant.data) ? significant.data : [];
  const reconRows: any[] = Array.isArray(recent.data) ? recent.data : [];

  const driftCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'expected_total_shares', header: 'Expected', render: (r: any) => String(r.expected_total_shares ?? '') },
    { key: 'actual_total_shares', header: 'Actual', render: (r: any) => String(r.actual_total_shares ?? '') },
    { key: 'drift_pct', header: 'Drift %', render: (r: any) => String(r.drift_pct ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'detected_at', header: 'Detected', render: (r: any) => r.detected_at ? new Date(r.detected_at).toLocaleString() : '' },
    { key: 'drift_root_cause_md', header: 'Root cause', render: (r: any) => String(r.drift_root_cause_md ?? '') },
  ];

  const sigCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'drift_pct', header: 'Drift %', render: (r: any) => String(r.drift_pct ?? '') },
    { key: 'expected_total_shares', header: 'Expected', render: (r: any) => String(r.expected_total_shares ?? '') },
    { key: 'actual_total_shares', header: 'Actual', render: (r: any) => String(r.actual_total_shares ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'detected_at', header: 'Detected', render: (r: any) => r.detected_at ? new Date(r.detected_at).toLocaleString() : '' },
  ];

  const reconCols: Column<any>[] = [
    { key: 'drift_id', header: 'Drift ID', render: (r: any) => String(r.drift_id ?? '') },
    { key: 'reconciliation_action', header: 'Action', render: (r: any) => String(r.reconciliation_action ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Cap Table Drift Detector</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Detect drift between modeled cap table and actual share counts. Flags variance of 1 percent or more
        and tracks reconciliation actions until resolved.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Significant unreconciled drifts</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Absolute drift of 1 percent or greater, status not yet reconciled.
        </p>
        <DataTable rows={sigRows} columns={sigCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All drifts</h2>
        <DataTable rows={driftRows} columns={driftCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent reconciliations</h2>
        <DataTable rows={reconRows} columns={reconCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
