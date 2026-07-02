import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [handoffs, outcomes, topEng, funnel, trend, intro, revenue] = await Promise.all([
    sb.rpc('list_handoffs_r2610'),
    sb.rpc('list_outcomes_r2610'),
    sb.rpc('top_retention_engineers_r2610'),
    sb.rpc('status_funnel_r2610'),
    sb.rpc('monthly_handoff_trend_r2610'),
    sb.rpc('intro_done_rate_r2610'),
    sb.rpc('revenue_impact_summary_r2610'),
  ]);

  const handoffRows = (handoffs.data ?? []) as any[];
  const outcomeRows = (outcomes.data ?? []) as any[];
  const topEngRows = (topEng.data ?? []) as any[];
  const funnelRows = (funnel.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const introRows = (intro.data ?? []) as any[];
  const revenueRows = (revenue.data ?? []) as any[];

  const handoffCols: Column<any>[] = [
    { key: 'handoff_at', header: 'Handoff at', render: (r: any) => new Date(r.handoff_at).toLocaleDateString() },
    { key: 'intro_meeting_done', header: 'Intro done', render: (r: any) => (r.intro_meeting_done ? 'yes' : 'no') },
    { key: 'csat_after', header: 'CSAT after', render: (r: any) => r.csat_after ?? '—' },
    { key: 'retention_status', header: 'Retention', render: (r: any) => r.retention_status },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => new Date(r.observed_at).toLocaleDateString() },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'revenue_impact_rupees', header: 'Revenue impact (Rs)', render: (r: any) => r.revenue_impact_rupees },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const topEngCols: Column<any>[] = [
    { key: 'engineer_label', header: 'Engineer', render: (r: any) => r.engineer_label },
    { key: 'total_handoffs', header: 'Total', render: (r: any) => r.total_handoffs },
    { key: 'retained_count', header: 'Retained', render: (r: any) => r.retained_count },
    { key: 'lost_count', header: 'Lost', render: (r: any) => r.lost_count },
    { key: 'retention_pct', header: 'Retention %', render: (r: any) => r.retention_pct ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status_label', header: 'Status', render: (r: any) => r.status_label },
    { key: 'handoff_count', header: 'Count', render: (r: any) => r.handoff_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total_handoffs', header: 'Total', render: (r: any) => r.total_handoffs },
    { key: 'done_handoffs', header: 'Done', render: (r: any) => r.done_handoffs },
    { key: 'retained_handoffs', header: 'Retained', render: (r: any) => r.retained_handoffs },
    { key: 'lost_handoffs', header: 'Lost', render: (r: any) => r.lost_handoffs },
  ];

  const introCols: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r: any) => r.metric_label },
    { key: 'metric_value', header: 'Value', render: (r: any) => r.metric_value ?? '—' },
  ];

  const revenueCols: Column<any>[] = [
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'outcome_count', header: 'Count', render: (r: any) => r.outcome_count },
    { key: 'total_revenue_impact_rupees', header: 'Total impact (Rs)', render: (r: any) => r.total_revenue_impact_rupees },
    { key: 'avg_revenue_impact_rupees', header: 'Avg impact (Rs)', render: (r: any) => r.avg_revenue_impact_rupees ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer > Customer Relationship Handoff</h1>
        <p className="text-sm text-gray-600">Track engineer-to-engineer handoffs & downstream retention impact.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Handoffs</h2>
        <DataTable
          rows={handoffRows}
          columns={handoffCols}
          emptyMessage="No handoffs logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Retention outcomes</h2>
        <DataTable
          rows={outcomeRows}
          columns={outcomeCols}
          emptyMessage="No outcomes recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top retention engineers</h2>
        <DataTable
          rows={topEngRows}
          columns={topEngCols}
          emptyMessage="No engineers yet."
          rowKey={(r: any, i: number) => String(r.engineer_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Status funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly handoff trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Intro done rate</h2>
        <DataTable
          rows={introRows}
          columns={introCols}
          emptyMessage="No metrics."
          rowKey={(r: any, i: number) => String(r.metric_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Revenue impact summary</h2>
        <DataTable
          rows={revenueRows}
          columns={revenueCols}
          emptyMessage="No outcomes."
          rowKey={(r: any, i: number) => String(r.outcome_kind ?? i)}
        />
      </section>
    </div>
  );
}
