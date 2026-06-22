import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [failuresRes, protocolsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_failures_r2055'),
    sb.rpc('list_protocols_r2055'),
    sb.rpc('top_failure_modes_r2055'),
    sb.rpc('recent_protocols_r2055'),
  ]);

  const failures: any[] = Array.isArray(failuresRes.data) ? failuresRes.data : [];
  const protocols: any[] = Array.isArray(protocolsRes.data) ? protocolsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const failureCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'label', header: 'Failure Mode', render: (r: any) => String(r.failure_mode_label ?? '') },
    { key: 'root', header: 'Root Cause', render: (r: any) => String(r.root_cause_category ?? '') },
    { key: 'freq', header: 'Freq', render: (r: any) => String(r.frequency_score ?? '') },
    { key: 'sev', header: 'Sev', render: (r: any) => String(r.severity_score ?? '') },
    { key: 'risk', header: 'Risk', render: (r: any) => String((Number(r.frequency_score ?? 0) * Number(r.severity_score ?? 0))) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const protocolCols: Column<any>[] = [
    { key: 'label', header: 'Failure Mode', render: (r: any) => String(r.failure_mode_label ?? '') },
    { key: 'md', header: 'Protocol', render: (r: any) => {
        const s = String(r.protocol_md ?? '');
        return s.length > 120 ? s.slice(0, 120) + '...' : s;
      } },
    { key: 'by', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'updated', header: 'Updated', render: (r: any) => r.last_updated_at ? new Date(r.last_updated_at).toLocaleString() : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'count', header: 'Failure Count', render: (r: any) => String(r.failure_count ?? '') },
    { key: 'avgF', header: 'Avg Frequency', render: (r: any) => String(r.avg_frequency ?? '') },
    { key: 'avgS', header: 'Avg Severity', render: (r: any) => String(r.avg_severity ?? '') },
    { key: 'maxR', header: 'Max Risk', render: (r: any) => String(r.max_risk ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'label', header: 'Failure Mode', render: (r: any) => String(r.failure_mode_label ?? '') },
    { key: 'by', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'updated', header: 'Updated', render: (r: any) => r.last_updated_at ? new Date(r.last_updated_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Equipment Failure Mode Cataloging</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Catalog of failure modes with frequency, severity, root cause, and response protocols.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Failure Modes by Category</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.equipment_category ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active Failure Modes</h2>
        <DataTable rows={failures} columns={failureCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Response Protocols</h2>
        <DataTable rows={protocols} columns={protocolCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Protocol Updates</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
