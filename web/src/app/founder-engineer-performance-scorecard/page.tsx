import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [scorecardsRes, atRiskRes, actionsRes] = await Promise.all([
    sb.rpc('list_scorecards_r2032'),
    sb.rpc('at_risk_r2032'),
    sb.rpc('recent_actions_r2032'),
  ]);

  const scorecards = (scorecardsRes.data as any[]) ?? [];
  const atRisk = (atRiskRes.data as any[]) ?? [];
  const actions = (actionsRes.data as any[]) ?? [];

  const scorecardCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'technical_score', header: 'Tech', render: (r: any) => String(r.technical_score ?? 0) },
    { key: 'customer_score', header: 'Customer', render: (r: any) => String(r.customer_score ?? 0) },
    { key: 'reliability_score', header: 'Reliability', render: (r: any) => String(r.reliability_score ?? 0) },
    { key: 'teamwork_score', header: 'Teamwork', render: (r: any) => String(r.teamwork_score ?? 0) },
    { key: 'composite_score', header: 'Composite', render: (r: any) => String(r.composite_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 16) },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'composite_score', header: 'Composite', render: (r: any) => String(r.composite_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 16) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'scorecard_id', header: 'Scorecard', render: (r: any) => String(r.scorecard_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => String(r.taken_at ?? '').slice(0, 16) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>Engineer Performance Scorecard</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Composite performance scorecard per engineer with action history.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All Scorecards</h2>
        <DataTable rows={scorecards} columns={scorecardCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>At Risk and Declining</h2>
        <DataTable rows={atRisk} columns={atRiskCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
