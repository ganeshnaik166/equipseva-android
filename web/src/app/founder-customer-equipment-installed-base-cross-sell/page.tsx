import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [pipelineRes, outcomesRes, focusRes, kindRes, funnelRes, trendRes, summaryRes] = await Promise.all([
    supabase.rpc('list_pipeline_r2624'),
    supabase.rpc('list_outcomes_r2624'),
    supabase.rpc('top_pipeline_focus_r2624'),
    supabase.rpc('cross_sell_kind_distribution_r2624'),
    supabase.rpc('status_funnel_r2624'),
    supabase.rpc('monthly_pipeline_trend_r2624'),
    supabase.rpc('total_realized_summary_r2624'),
  ]);

  const pipeline = (pipelineRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const kind = (kindRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

  const pipelineCols: Column<any>[] = [
    { key: 'installed_equipment_label', header: 'Installed Equipment', render: (r: any) => r.installed_equipment_label },
    { key: 'cross_sell_kind', header: 'Cross-Sell Kind', render: (r: any) => r.cross_sell_kind },
    { key: 'pipeline_value_rupees', header: 'Pipeline Value', render: (r: any) => fmtRupees(r.pipeline_value_rupees) },
    { key: 'win_probability_pct', header: 'Win Prob %', render: (r: any) => r.win_probability_pct + '%' },
    { key: 'weighted_value_rupees', header: 'Weighted Value', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => new Date(r.observed_at).toLocaleString() },
    { key: 'installed_equipment_label', header: 'Equipment', render: (r: any) => r.installed_equipment_label },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'revenue_realized_rupees', header: 'Revenue Realized', render: (r: any) => fmtRupees(r.revenue_realized_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'installed_equipment_label', header: 'Equipment', render: (r: any) => r.installed_equipment_label },
    { key: 'cross_sell_kind', header: 'Kind', render: (r: any) => r.cross_sell_kind },
    { key: 'pipeline_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.pipeline_value_rupees) },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => r.win_probability_pct + '%' },
    { key: 'weighted_value_rupees', header: 'Weighted', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'cross_sell_kind', header: 'Kind', render: (r: any) => r.cross_sell_kind },
    { key: 'opportunity_count', header: 'Opportunities', render: (r: any) => r.opportunity_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'weighted_value_rupees', header: 'Weighted Value', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
    { key: 'avg_win_probability_pct', header: 'Avg Win %', render: (r: any) => (r.avg_win_probability_pct ?? 0) + '%' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'opportunity_count', header: 'Opportunities', render: (r: any) => r.opportunity_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'avg_win_probability_pct', header: 'Avg Win %', render: (r: any) => (r.avg_win_probability_pct ?? 0) + '%' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'pipeline_added', header: 'Pipeline Added', render: (r: any) => r.pipeline_added },
    { key: 'pipeline_value_added_rupees', header: 'Value Added', render: (r: any) => fmtRupees(r.pipeline_value_added_rupees) },
    { key: 'outcomes_observed', header: 'Outcomes', render: (r: any) => r.outcomes_observed },
    { key: 'revenue_realized_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.revenue_realized_rupees) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r: any) => r.metric_label },
    { key: 'metric_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.metric_value_rupees) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Customer Equipment Installed-Base Cross-Sell
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Mine the installed base for AMC, training, consumables, add-on equipment & data-subscription plays. Round 2624.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Realized & Pipeline Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No summary yet."
          rowKey={(r: any, i: number) => String(r.metric_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Pipeline Focus (open only)</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No open pipeline."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Cross-Sell Kind Distribution</h2>
        <DataTable
          rows={kind}
          columns={kindCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.cross_sell_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly Pipeline & Revenue Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Pipeline Opportunities</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          emptyMessage="No pipeline yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Cross-Sell Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
