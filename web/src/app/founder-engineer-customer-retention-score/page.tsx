import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCustomerRetentionScorePage() {
  const sb = await getSupabaseServerClient();

  const [retentionsRes, atRiskRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_retentions_r2040'),
    sb.rpc('at_risk_r2040'),
    sb.rpc('recent_actions_r2040'),
  ]);

  const retentions: any[] = Array.isArray(retentionsRes.data) ? retentionsRes.data : [];
  const atRisk: any[] = Array.isArray(atRiskRes.data) ? atRiskRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const retentionColumns: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'period_label', header: 'Period', render: (r: any) => <span>{r.period_label ?? '-'}</span> },
    { key: 'retained_customers_count', header: 'Retained', render: (r: any) => <span>{r.retained_customers_count ?? 0}</span> },
    { key: 'lost_customers_count', header: 'Lost', render: (r: any) => <span>{r.lost_customers_count ?? 0}</span> },
    { key: 'retention_pct', header: 'Retention pct', render: (r: any) => <span>{r.retention_pct ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status ?? '-'}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span className="text-xs">{r.captured_at ? new Date(r.captured_at).toLocaleString() : '-'}</span> },
  ];

  const atRiskColumns: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'period_label', header: 'Period', render: (r: any) => <span>{r.period_label ?? '-'}</span> },
    { key: 'retention_pct', header: 'Retention pct', render: (r: any) => <span>{r.retention_pct ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-rose-700 uppercase text-xs">{r.status ?? '-'}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span className="text-xs">{r.captured_at ? new Date(r.captured_at).toLocaleString() : '-'}</span> },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'retention_id', header: 'Retention', render: (r: any) => <span className="font-mono text-xs">{String(r.retention_id ?? '').slice(0, 8)}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span className="uppercase text-xs">{r.action_type ?? '-'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span className="text-xs">{r.by_email ?? '-'}</span> },
    { key: 'taken_at', header: 'Taken', render: (r: any) => <span className="text-xs">{r.taken_at ? new Date(r.taken_at).toLocaleString() : '-'}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs">{r.notes_md ?? '-'}</span> },
  ];

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Customer Retention Score</h1>
        <p className="text-sm text-neutral-600 mt-1">
          Per-engineer retention score across customers. Track retained versus lost counts, flag declining or at-risk engineers, and log coaching, recognition, escalation, retraining, or bonus actions.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">All retention scores</h2>
        <DataTable rows={retentions} columns={retentionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">At-risk and declining engineers</h2>
        <DataTable rows={atRisk} columns={atRiskColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent retention actions</h2>
        <DataTable rows={recentActions} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
