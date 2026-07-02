import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerRetentionRiskPage() {
  const sb = await getSupabaseServerClient();

  const [risksRes, highRiskRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_risks_r1700'),
    sb.rpc('high_risk_engineers_r1700'),
    sb.rpc('recent_retention_actions_r1700'),
  ]);

  const risks: any[] = Array.isArray(risksRes.data) ? risksRes.data : [];
  const highRisk: any[] = Array.isArray(highRiskRes.data) ? highRiskRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const risksCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'tenure_months', header: 'Tenure (mo)', render: (r: any) => String(r.tenure_months ?? 0) },
    { key: 'months_since_raise', header: 'Since Raise', render: (r: any) => String(r.months_since_raise ?? 0) },
    { key: 'complaint_count', header: 'Complaints', render: (r: any) => String(r.complaint_count ?? 0) },
    { key: 'recent_market_offer_count', header: 'Mkt Offers', render: (r: any) => String(r.recent_market_offer_count ?? 0) },
    { key: 'risk_score', header: 'Score', render: (r: any) => String(r.risk_score ?? 0) },
    { key: 'risk_band', header: 'Band', render: (r: any) => String(r.risk_band ?? '') },
    { key: 'computed_at', header: 'Computed', render: (r: any) => r.computed_at ? new Date(r.computed_at).toLocaleString() : '—' },
  ];

  const highRiskCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'risk_score', header: 'Score', render: (r: any) => String(r.risk_score ?? 0) },
    { key: 'risk_band', header: 'Band', render: (r: any) => String(r.risk_band ?? '') },
    { key: 'computed_at', header: 'Computed', render: (r: any) => r.computed_at ? new Date(r.computed_at).toLocaleString() : '—' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'action_at', header: 'At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Retention Risk Score</h1>
        <p className="text-sm text-gray-600">
          Composite risk = tenure + months since raise + complaints + market offers. Band: low (&lt;30), med (30-59), high (&gt;=60).
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">High Risk Engineers (band = high)</h2>
        <DataTable
          rows={highRisk}
          columns={highRiskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Risk Computations</h2>
        <DataTable
          rows={risks}
          columns={risksCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Retention Actions</h2>
        <DataTable
          rows={recentActions}
          columns={actionsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
