import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerRepeatCustomerBuilderPage() {
  const sb = await getSupabaseServerClient();

  const { data: records } = await sb.rpc('list_repeat_customer_records_r2120', { p_limit: 100 });
  const { data: atRisk } = await sb.rpc('list_repeat_customer_at_risk_r2120');
  const { data: recentActions } = await sb.rpc('list_repeat_customer_recent_actions_r2120', { p_limit: 50 });

  const rows = (records ?? []) as any[];
  const atRiskRows = (atRisk ?? []) as any[];
  const actionRows = (recentActions ?? []) as any[];

  const recordCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'repeat_count', header: 'Repeats', render: (r: any) => String(r.repeat_count ?? 0) },
    { key: 'target_repeat_count', header: 'Target', render: (r: any) => String(r.target_repeat_count ?? 0) },
    { key: 'last_repeat_at', header: 'Last Repeat', render: (r: any) => r.last_repeat_at ? new Date(r.last_repeat_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '-' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'repeat_count', header: 'Repeats', render: (r: any) => String(r.repeat_count ?? 0) },
    { key: 'target_repeat_count', header: 'Target', render: (r: any) => String(r.target_repeat_count ?? 0) },
    { key: 'last_repeat_at', header: 'Last Repeat', render: (r: any) => r.last_repeat_at ? new Date(r.last_repeat_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'record_id', header: 'Record', render: (r: any) => String(r.record_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Repeat Customer Builder</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Help engineers build repeat customers. Track status across building, established, at risk, lost and exceptional.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Records ({rows.length})</h2>
        <DataTable rows={rows} columns={recordCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>At Risk ({atRiskRows.length})</h2>
        <DataTable rows={atRiskRows} columns={atRiskCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions ({actionRows.length})</h2>
        <DataTable rows={actionRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
