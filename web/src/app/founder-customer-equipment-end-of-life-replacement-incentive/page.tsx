import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [incentives, closeLog, focus, kindDist, arrSummary, trend, funnel] = await Promise.all([
    supabase.rpc('list_incentives_r2608'),
    supabase.rpc('list_close_log_r2608'),
    supabase.rpc('top_close_prob_focus_r2608'),
    supabase.rpc('incentive_kind_distribution_r2608'),
    supabase.rpc('total_realized_arr_summary_r2608'),
    supabase.rpc('monthly_close_trend_r2608'),
    supabase.rpc('status_funnel_r2608'),
  ]);

  const incentiveCols: Column<any>[] = [
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
    { key: 'old_equipment_label', header: 'Old Equipment', render: (r: any) => r.old_equipment_label },
    { key: 'incentive_kind', header: 'Incentive', render: (r: any) => r.incentive_kind },
    { key: 'trade_in_value_rupees', header: 'Trade-In Rs', render: (r: any) => r.trade_in_value_rupees },
    { key: 'replacement_upgrade_value_rupees', header: 'Upgrade Rs', render: (r: any) => r.replacement_upgrade_value_rupees },
    { key: 'close_probability_pct', header: 'Close Prob %', render: (r: any) => r.close_probability_pct },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const closeLogCols: Column<any>[] = [
    { key: 'old_equipment_label', header: 'Equipment', render: (r: any) => r.old_equipment_label ?? '-' },
    { key: 'closed_at', header: 'Closed At', render: (r: any) => r.closed_at ? new Date(r.closed_at).toLocaleString() : '-' },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'realized_arr_rupees', header: 'Realized ARR Rs', render: (r: any) => r.realized_arr_rupees },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'old_equipment_label', header: 'Equipment', render: (r: any) => r.old_equipment_label },
    { key: 'incentive_kind', header: 'Incentive', render: (r: any) => r.incentive_kind },
    { key: 'close_probability_pct', header: 'Close Prob %', render: (r: any) => r.close_probability_pct },
    { key: 'replacement_upgrade_value_rupees', header: 'Upgrade Rs', render: (r: any) => r.replacement_upgrade_value_rupees },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'incentive_kind', header: 'Kind', render: (r: any) => r.incentive_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'accepted_count', header: 'Accepted', render: (r: any) => r.accepted_count },
    { key: 'total_upgrade_value_rupees', header: 'Upgrade Rs', render: (r: any) => r.total_upgrade_value_rupees },
  ];

  const arrCols: Column<any>[] = [
    { key: 'total_closed', header: 'Total Closed', render: (r: any) => r.total_closed },
    { key: 'won_count', header: 'Won', render: (r: any) => r.won_count },
    { key: 'lost_count', header: 'Lost', render: (r: any) => r.lost_count },
    { key: 'postponed_count', header: 'Postponed', render: (r: any) => r.postponed_count },
    { key: 'total_realized_arr_rupees', header: 'Realized ARR Rs', render: (r: any) => r.total_realized_arr_rupees },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total_closed', header: 'Total Closed', render: (r: any) => r.total_closed },
    { key: 'won_count', header: 'Won', render: (r: any) => r.won_count },
    { key: 'total_realized_arr_rupees', header: 'Realized ARR Rs', render: (r: any) => r.total_realized_arr_rupees },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'total_upgrade_value_rupees', header: 'Upgrade Rs', render: (r: any) => r.total_upgrade_value_rupees },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Customer Equipment End-of-Life Replacement Incentive</h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Old equipment trade-in & replacement upgrade incentives =&gt; close probability & realized ARR. Round r2608.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Close-Probability Focus</h2>
        <DataTable
          rows={(focus.data ?? []) as any[]}
          columns={focusCols}
          emptyMessage="No active incentives."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Realized ARR Summary</h2>
        <DataTable
          rows={(arrSummary.data ?? []) as any[]}
          columns={arrCols}
          emptyMessage="No close data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Incentive Kind Distribution</h2>
        <DataTable
          rows={(kindDist.data ?? []) as any[]}
          columns={kindCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.incentive_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={(funnel.data ?? []) as any[]}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Close Trend</h2>
        <DataTable
          rows={(trend.data ?? []) as any[]}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All Incentives</h2>
        <DataTable
          rows={(incentives.data ?? []) as any[]}
          columns={incentiveCols}
          emptyMessage="No incentives logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Close Log</h2>
        <DataTable
          rows={(closeLog.data ?? []) as any[]}
          columns={closeLogCols}
          emptyMessage="No close events logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
