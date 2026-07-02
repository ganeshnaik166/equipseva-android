import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyPersonalDevelopmentInvestmentPage() {
  const supabase = await getSupabaseServerClient();

  const [
    devListRes,
    appLogRes,
    topHoursRes,
    kindDistRes,
    statusFunnelRes,
    monthlyTrendRes,
    outcomeSummaryRes,
  ] = await Promise.all([
    supabase.rpc('list_dev_r2625'),
    supabase.rpc('list_application_log_r2625'),
    supabase.rpc('top_hours_focus_r2625'),
    supabase.rpc('dev_kind_distribution_r2625'),
    supabase.rpc('status_funnel_r2625'),
    supabase.rpc('monthly_dev_trend_r2625'),
    supabase.rpc('application_outcome_summary_r2625'),
  ]);

  const devList = (devListRes.data ?? []) as any[];
  const appLog = (appLogRes.data ?? []) as any[];
  const topHours = (topHoursRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const outcomeSummary = (outcomeSummaryRes.data ?? []) as any[];

  const errors = [
    devListRes.error,
    appLogRes.error,
    topHoursRes.error,
    kindDistRes.error,
    statusFunnelRes.error,
    monthlyTrendRes.error,
    outcomeSummaryRes.error,
  ].filter(Boolean);

  const devCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '' },
    { key: 'dev_kind', header: 'Kind', render: (r: any) => r.dev_kind ?? '' },
    { key: 'hours_invested', header: 'Hours', render: (r: any) => Number(r.hours_invested ?? 0).toFixed(1) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'top_insight_md', header: 'Top Insight', render: (r: any) => r.top_insight_md ?? '' },
    { key: 'application_md', header: 'Application', render: (r: any) => r.application_md ?? '' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
  ];

  const appLogCols: Column<any>[] = [
    { key: 'applied_at', header: 'Applied At', render: (r: any) => r.applied_at ? new Date(r.applied_at).toLocaleDateString() : '' },
    { key: 'month_label', header: 'Source Month', render: (r: any) => r.month_label ?? '' },
    { key: 'dev_kind', header: 'Source Kind', render: (r: any) => r.dev_kind ?? '' },
    { key: 'application_kind', header: 'Application', render: (r: any) => r.application_kind ?? '' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const topHoursCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '' },
    { key: 'total_hours', header: 'Total Hours', render: (r: any) => Number(r.total_hours ?? 0).toFixed(1) },
    { key: 'top_kind', header: 'Top Kind', render: (r: any) => r.top_kind ?? '' },
    { key: 'entry_count', header: 'Entries', render: (r: any) => String(r.entry_count ?? 0) },
  ];

  const kindDistCols: Column<any>[] = [
    { key: 'dev_kind', header: 'Kind', render: (r: any) => r.dev_kind ?? '' },
    { key: 'entry_count', header: 'Entries', render: (r: any) => String(r.entry_count ?? 0) },
    { key: 'total_hours', header: 'Total Hours', render: (r: any) => Number(r.total_hours ?? 0).toFixed(1) },
    { key: 'avg_hours', header: 'Avg Hours', render: (r: any) => Number(r.avg_hours ?? 0).toFixed(1) },
  ];

  const statusFunnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'entry_count', header: 'Entries', render: (r: any) => String(r.entry_count ?? 0) },
    { key: 'total_hours', header: 'Total Hours', render: (r: any) => Number(r.total_hours ?? 0).toFixed(1) },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '' },
    { key: 'hours_invested', header: 'Hours', render: (r: any) => Number(r.hours_invested ?? 0).toFixed(1) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count ?? 0) },
    { key: 'planned_count', header: 'Planned', render: (r: any) => String(r.planned_count ?? 0) },
  ];

  const outcomeSummaryCols: Column<any>[] = [
    { key: 'application_kind', header: 'Application Kind', render: (r: any) => r.application_kind ?? '' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '' },
    { key: 'entry_count', header: 'Entries', render: (r: any) => String(r.entry_count ?? 0) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Founder Monthly Personal Development Investment
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track monthly hours invested in personal development & how insights get applied to the business.
      </p>

      {errors.length > 0 ? (
        <div style={{ background: '#fee', border: '1px solid #fcc', padding: 12, borderRadius: 6, marginBottom: 16 }}>
          <strong>Errors:</strong>
          <ul>
            {errors.map((e: any, i: number) => (
              <li key={i}>{e?.message ?? String(e)}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Dev Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendCols}
          emptyMessage="No monthly trend data yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Hours Focus</h2>
        <DataTable
          rows={topHours}
          columns={topHoursCols}
          emptyMessage="No hours focus data yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Dev Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindDistCols}
          emptyMessage="No kind distribution yet"
          rowKey={(r: any, i: number) => String(r.dev_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusFunnelCols}
          emptyMessage="No status data yet"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Application Outcome Summary</h2>
        <DataTable
          rows={outcomeSummary}
          columns={outcomeSummaryCols}
          emptyMessage="No outcome data yet"
          rowKey={(r: any, i: number) => String((r.application_kind ?? '') + '-' + (r.outcome ?? '') + '-' + i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Personal Development Entries</h2>
        <DataTable
          rows={devList}
          columns={devCols}
          emptyMessage="No personal dev entries yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Application Log</h2>
        <DataTable
          rows={appLog}
          columns={appLogCols}
          emptyMessage="No application log entries yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
