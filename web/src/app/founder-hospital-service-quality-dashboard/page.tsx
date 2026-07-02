import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [dashRes, atRiskRes, actionsRes] = await Promise.all([
    sb.rpc('list_dashboards_r1915'),
    sb.rpc('at_risk_hospitals_r1915'),
    sb.rpc('recent_actions_r1915'),
  ]);

  const dashboards: any[] = Array.isArray(dashRes.data) ? dashRes.data : [];
  const atRisk: any[] = Array.isArray(atRiskRes.data) ? atRiskRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const dashCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'period_start', header: 'Period', render: (r: any) => r.period_start ?? '—' },
    { key: 'avg_rating', header: 'Avg rating', render: (r: any) => r.avg_rating ?? '—' },
    { key: 'repeat_booking_rate', header: 'Repeat %', render: (r: any) => r.repeat_booking_rate ?? '—' },
    { key: 'escalation_rate', header: 'Escalation %', render: (r: any) => r.escalation_rate ?? '—' },
    { key: 'quality_score', header: 'Score', render: (r: any) => r.quality_score ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'computed_at', header: 'Computed', render: (r: any) => r.computed_at ? new Date(r.computed_at).toLocaleString() : '—' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'period_start', header: 'Period', render: (r: any) => r.period_start ?? '—' },
    { key: 'quality_score', header: 'Score', render: (r: any) => r.quality_score ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'computed_at', header: 'Computed', render: (r: any) => r.computed_at ? new Date(r.computed_at).toLocaleString() : '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => r.outcome_md ?? '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Service Quality Dashboard</h1>
        <p className="text-sm text-gray-600">
          Per-hospital quality scoring combining ratings, repeat-booking rate, and escalation rate.
          Flags hospitals in poor or at-risk tiers for save-the-account intervention.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">All dashboards</h2>
        <DataTable
          rows={dashboards}
          columns={dashCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">At-risk hospitals (poor and at_risk)</h2>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
