import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MetricRow = {
  id: string;
  period_label: string | null;
  retention_rate_pct: number | null;
  nps_score: number | null;
  csat_score: number | null;
  expansion_rate_pct: number | null;
  churn_rate_pct: number | null;
  composite_success_score: number | null;
  status: string | null;
  captured_at: string | null;
};

type ActionRow = {
  id: string;
  metric_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
};

type TrendRow = {
  period_label: string | null;
  composite_success_score: number | null;
  status: string | null;
  captured_at: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [metricsRes, actionsRes, trendRes] = await Promise.all([
    sb.rpc('list_customer_success_metrics_r1994'),
    sb.rpc('recent_customer_success_actions_r1994'),
    sb.rpc('customer_success_trend_r1994'),
  ]);

  const metrics: MetricRow[] = (metricsRes.data as MetricRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];

  const metricCols: Column<MetricRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label ?? '—' },
    { key: 'retention_rate_pct', header: 'Retention %', render: (r: any) => r.retention_rate_pct ?? '—' },
    { key: 'nps_score', header: 'NPS', render: (r: any) => r.nps_score ?? '—' },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => r.csat_score ?? '—' },
    { key: 'expansion_rate_pct', header: 'Expansion %', render: (r: any) => r.expansion_rate_pct ?? '—' },
    { key: 'churn_rate_pct', header: 'Churn %', render: (r: any) => r.churn_rate_pct ?? '—' },
    { key: 'composite_success_score', header: 'Composite', render: (r: any) => r.composite_success_score ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '—') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '—') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
    { key: 'metric_id', header: 'Metric', render: (r: any) => r.metric_id ?? '—' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label ?? '—' },
    { key: 'composite_success_score', header: 'Score', render: (r: any) => r.composite_success_score ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '—') },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Customer Success Metric</h1>
        <p className="text-sm text-gray-600">Composite success score from retention, NPS, CSAT, expansion and churn inputs.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">All Metrics</h2>
        <DataTable rows={metrics} columns={metricCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Trend (last 24 periods)</h2>
        <DataTable rows={trend} columns={trendCols} rowKey={(r: any, i: number) => String(r.period_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
