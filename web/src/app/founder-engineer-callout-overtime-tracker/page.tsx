import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerCalloutOvertimeTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    calloutsRes,
    metricsRes,
    topRes,
    fatigueRes,
    trendRes,
    restRes,
    kindRes,
  ] = await Promise.all([
    supabase.rpc('list_callouts_r2467'),
    supabase.rpc('list_fatigue_metrics_r2467'),
    supabase.rpc('top_overtime_engineers_r2467'),
    supabase.rpc('fatigue_severity_breakdown_r2467'),
    supabase.rpc('weekly_premium_trend_r2467'),
    supabase.rpc('rest_compliance_summary_r2467'),
    supabase.rpc('kind_breakdown_r2467'),
  ]);

  const callouts = (calloutsRes.data as any[]) ?? [];
  const metrics = (metricsRes.data as any[]) ?? [];
  const top = (topRes.data as any[]) ?? [];
  const fatigue = (fatigueRes.data as any[]) ?? [];
  const trend = (trendRes.data as any[]) ?? [];
  const rest = (restRes.data as any[]) ?? [];
  const kind = (kindRes.data as any[]) ?? [];

  const calloutCols: Column<any>[] = [
    { key: 'callout_at', header: 'When', render: (r: any) => new Date(r.callout_at).toLocaleString() },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'callout_kind', header: 'Kind', render: (r: any) => r.callout_kind },
    { key: 'overtime_hours', header: 'OT hrs', render: (r: any) => r.overtime_hours },
    { key: 'premium_rupees', header: 'Premium ₹', render: (r: any) => `₹${r.premium_rupees}` },
    { key: 'consent_given', header: 'Consent', render: (r: any) => (r.consent_given ? 'Yes' : 'No') },
    { key: 'fatigue_impact_kind', header: 'Fatigue', render: (r: any) => r.fatigue_impact_kind },
    { key: 'next_day_rest_taken', header: 'Rest', render: (r: any) => (r.next_day_rest_taken ? 'Yes' : 'No') },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const metricCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'total_callouts', header: 'Callouts', render: (r: any) => r.total_callouts },
    { key: 'total_overtime_hours', header: 'OT hrs', render: (r: any) => r.total_overtime_hours },
    { key: 'total_premium_rupees', header: 'Premium', render: (r: any) => `₹${r.total_premium_rupees}` },
    { key: 'severe_fatigue_count', header: 'Severe', render: (r: any) => r.severe_fatigue_count },
    { key: 'rest_compliance_pct', header: 'Rest %', render: (r: any) => `${r.rest_compliance_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'total_overtime', header: 'Total OT hrs', render: (r: any) => r.total_overtime },
    { key: 'total_premium', header: 'Total Premium', render: (r: any) => `₹${r.total_premium}` },
    { key: 'callout_count', header: 'Callouts', render: (r: any) => r.callout_count },
  ];

  const fatigueCols: Column<any>[] = [
    { key: 'fatigue_impact_kind', header: 'Fatigue', render: (r: any) => r.fatigue_impact_kind },
    { key: 'callout_count', header: 'Count', render: (r: any) => r.callout_count },
    { key: 'avg_overtime', header: 'Avg OT', render: (r: any) => r.avg_overtime },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'total_premium', header: 'Premium', render: (r: any) => `₹${r.total_premium}` },
    { key: 'total_callouts', header: 'Callouts', render: (r: any) => r.total_callouts },
  ];

  const restCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'avg_compliance', header: 'Avg Compliance %', render: (r: any) => `${r.avg_compliance}%` },
  ];

  const kindCols: Column<any>[] = [
    { key: 'callout_kind', header: 'Kind', render: (r: any) => r.callout_kind },
    { key: 'callout_count', header: 'Count', render: (r: any) => r.callout_count },
    { key: 'total_overtime', header: 'OT hrs', render: (r: any) => r.total_overtime },
    { key: 'total_premium', header: 'Premium', render: (r: any) => `₹${r.total_premium}` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Callout & Overtime Tracker</h1>
        <p className="text-sm text-gray-600">
          Track engineer callouts, overtime premium, consent & fatigue impact. Watch for burnout
          when rest compliance < 50% & severe fatigue > 1/week.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Callouts</h2>
        <DataTable
          rows={callouts}
          columns={calloutCols}
          emptyMessage="No callouts logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Fatigue Metrics</h2>
        <DataTable
          rows={metrics}
          columns={metricCols}
          emptyMessage="No metrics yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Overtime Engineers</h2>
        <DataTable
          rows={top}
          columns={topCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fatigue Severity Breakdown</h2>
        <DataTable
          rows={fatigue}
          columns={fatigueCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.fatigue_impact_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Premium Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rest Compliance Summary</h2>
        <DataTable
          rows={rest}
          columns={restCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Callout Kind Breakdown</h2>
        <DataTable
          rows={kind}
          columns={kindCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.callout_kind ?? i)}
        />
      </section>
    </main>
  );
}
