import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerMultiQuarterTrendComparisonPage() {
  const supabase = await getSupabaseServerClient();

  const [trendRes, alertsRes, topArrRes, tierMovRes, scoreboardRes, monthlyAlertRes, quarterlyRes] =
    await Promise.all([
      supabase.rpc('list_trend_r2592'),
      supabase.rpc('list_alert_actions_r2592'),
      supabase.rpc('top_arr_quarters_r2592'),
      supabase.rpc('tier_movement_distribution_r2592'),
      supabase.rpc('scoreboard_top_summary_r2592'),
      supabase.rpc('monthly_alert_trend_r2592'),
      supabase.rpc('quarterly_summary_r2592'),
    ]);

  const trends = (trendRes.data ?? []) as any[];
  const alerts = (alertsRes.data ?? []) as any[];
  const topArr = (topArrRes.data ?? []) as any[];
  const tierMov = (tierMovRes.data ?? []) as any[];
  const scoreboard = (scoreboardRes.data ?? []) as any[];
  const monthlyAlerts = (monthlyAlertRes.data ?? []) as any[];
  const quarterly = (quarterlyRes.data ?? []) as any[];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'nps', header: 'NPS', render: (r: any) => (r.nps ?? '-') },
    { key: 'csat', header: 'CSAT', render: (r: any) => (r.csat ?? '-') },
    { key: 'arr_rupees', header: 'ARR (Rs)', render: (r: any) => (r.arr_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'top_engineer_email', header: 'Top engineer', render: (r: any) => r.top_engineer_email ?? '-' },
    { key: 'scoreboard_position', header: 'Scoreboard', render: (r: any) => (r.scoreboard_position ?? '-') },
    { key: 'tier_kind', header: 'Tier', render: (r: any) => r.tier_kind },
    { key: 'tier_movement_kind', header: 'Movement', render: (r: any) => r.tier_movement_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const alertCols: Column<any>[] = [
    { key: 'alert_at', header: 'When', render: (r: any) => new Date(r.alert_at).toLocaleString() },
    { key: 'alert_kind', header: 'Alert', render: (r: any) => r.alert_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topArrCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'total_arr_rupees', header: 'Total ARR (Rs)', render: (r: any) => (r.total_arr_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => r.hospital_count },
  ];

  const tierMovCols: Column<any>[] = [
    { key: 'tier_movement_kind', header: 'Movement', render: (r: any) => r.tier_movement_kind },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
  ];

  const scoreboardCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'best_position', header: 'Best', render: (r: any) => r.best_position },
    { key: 'worst_position', header: 'Worst', render: (r: any) => r.worst_position },
    { key: 'avg_position', header: 'Avg', render: (r: any) => r.avg_position },
  ];

  const monthlyAlertCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'n', header: 'Alerts', render: (r: any) => r.n },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
  ];

  const quarterlyCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat },
    { key: 'total_arr_rupees', header: 'Total ARR (Rs)', render: (r: any) => (r.total_arr_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'hospitals', header: 'Hospitals', render: (r: any) => r.hospitals },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer multi-quarter trend comparison</h1>
        <p className="text-sm text-gray-600">
          Hospital & quarter trend & NPS & CSAT & ARR & engineer & scoreboard & tier movement.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly trends</h2>
        <DataTable
          rows={trends}
          columns={trendCols}
          emptyMessage="No trend rows yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Alert actions</h2>
        <DataTable
          rows={alerts}
          columns={alertCols}
          emptyMessage="No alert actions yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly summary</h2>
        <DataTable
          rows={quarterly}
          columns={quarterlyCols}
          emptyMessage="No quarters yet"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top ARR quarters</h2>
        <DataTable
          rows={topArr}
          columns={topArrCols}
          emptyMessage="No ARR data"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier movement distribution</h2>
        <DataTable
          rows={tierMov}
          columns={tierMovCols}
          emptyMessage="No tier movements"
          rowKey={(r: any, i: number) => String(r.tier_movement_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Scoreboard top summary</h2>
        <DataTable
          rows={scoreboard}
          columns={scoreboardCols}
          emptyMessage="No scoreboard data"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly alert trend</h2>
        <DataTable
          rows={monthlyAlerts}
          columns={monthlyAlertCols}
          emptyMessage="No alerts yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </div>
  );
}
