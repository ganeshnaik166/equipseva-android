import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [renewalsRes, atRiskRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_renewals_r1939'),
    sb.rpc('at_risk_renewals_r1939'),
    sb.rpc('recent_actions_r1939'),
  ]);

  const renewals: any[] = renewalsRes.data ?? [];
  const atRisk: any[] = atRiskRes.data ?? [];
  const recentActions: any[] = recentActionsRes.data ?? [];

  const renewalCols: Column<any>[] = [
    { key: 'contract_label', header: 'Contract', render: (r: any) => r.contract_label ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'current_value_rupees', header: 'Current Rs', render: (r: any) => String(r.current_value_rupees ?? 0) },
    { key: 'renewal_value_rupees', header: 'Renewal Rs', render: (r: any) => String(r.renewal_value_rupees ?? 0) },
    { key: 'renewal_date', header: 'Renewal Date', render: (r: any) => r.renewal_date ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'risk_score', header: 'Risk', render: (r: any) => String(r.risk_score ?? 0) },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'contract_label', header: 'Contract', render: (r: any) => r.contract_label ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'risk_score', header: 'Risk Score', render: (r: any) => String(r.risk_score ?? 0) },
    { key: 'renewal_date', header: 'Renewal Date', render: (r: any) => r.renewal_date ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'current_value_rupees', header: 'Current Rs', render: (r: any) => String(r.current_value_rupees ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'contract_label', header: 'Contract', render: (r: any) => r.contract_label ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 600, marginBottom: '8px' }}>
        Hospital Service Contract Renewals
      </h1>
      <p style={{ color: '#6b7280', marginBottom: '24px' }}>
        Track contract renewal pipeline. Risk score of 7 or higher flags at-risk renewals needing founder attention.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          At-Risk Renewals (risk score 7 plus)
        </h2>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          All Renewals Pipeline
        </h2>
        <DataTable
          rows={renewals}
          columns={renewalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Recent Renewal Actions
        </h2>
        <DataTable
          rows={recentActions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
