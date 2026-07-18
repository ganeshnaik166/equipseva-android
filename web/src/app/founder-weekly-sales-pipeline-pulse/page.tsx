import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '-';
  return String(d).slice(0, 10);
}

export default async function FounderWeeklySalesPipelinePulsePage() {
  const supabase = await getSupabaseServerClient();

  const [
    pulseRes,
    commitmentsRes,
    trendRes,
    stageRes,
    stalledRes,
    forecastRes,
    ownerRes,
  ] = await Promise.all([
    supabase.rpc('list_pulse_r2513'),
    supabase.rpc('list_commitments_r2513'),
    supabase.rpc('weekly_pulse_trend_r2513'),
    supabase.rpc('stage_breakdown_r2513'),
    supabase.rpc('top_stalled_deals_r2513'),
    supabase.rpc('forecast_accuracy_summary_r2513'),
    supabase.rpc('owner_load_r2513'),
  ]);

  const pulse = (pulseRes.data ?? []) as any[];
  const commitments = (commitmentsRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const stages = (stageRes.data ?? []) as any[];
  const stalled = (stalledRes.data ?? []) as any[];
  const forecast = (forecastRes.data ?? []) as any[];
  const owners = (ownerRes.data ?? []) as any[];

  const pulseCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'stage_kind', header: 'Stage', render: (r: any) => r.stage_kind },
    { key: 'dollars_added_rupees', header: 'Added', render: (r: any) => rupees(r.dollars_added_rupees) },
    { key: 'dollars_closed_rupees', header: 'Closed', render: (r: any) => rupees(r.dollars_closed_rupees) },
    { key: 'stalled_count', header: 'Stalled', render: (r: any) => String(r.stalled_count ?? 0) },
    { key: 'forecast_accuracy_pct', header: 'Forecast %', render: (r: any) => String(r.forecast_accuracy_pct ?? 0) + '%' },
    { key: 'commitment_rupees', header: 'Commitment', render: (r: any) => rupees(r.commitment_rupees) },
    { key: 'top_stalled_deal', header: 'Top stalled', render: (r: any) => r.top_stalled_deal ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const commitmentCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'deal_name', header: 'Deal', render: (r: any) => r.deal_name },
    { key: 'stage_kind', header: 'Stage', render: (r: any) => r.stage_kind },
    { key: 'commitment_amount_rupees', header: 'Commit', render: (r: any) => rupees(r.commitment_amount_rupees) },
    { key: 'expected_close_at', header: 'Expected close', render: (r: any) => fmtDate(r.expected_close_at) },
    { key: 'actual_close_at', header: 'Actual close', render: (r: any) => fmtDate(r.actual_close_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'total_added_rupees', header: 'Added', render: (r: any) => rupees(r.total_added_rupees) },
    { key: 'total_closed_rupees', header: 'Closed', render: (r: any) => rupees(r.total_closed_rupees) },
    { key: 'total_stalled', header: 'Stalled', render: (r: any) => String(r.total_stalled ?? 0) },
    { key: 'total_commitment_rupees', header: 'Commitment', render: (r: any) => rupees(r.total_commitment_rupees) },
    { key: 'avg_forecast_accuracy_pct', header: 'Avg forecast %', render: (r: any) => String(r.avg_forecast_accuracy_pct ?? 0) + '%' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage_kind', header: 'Stage', render: (r: any) => r.stage_kind },
    { key: 'rows_count', header: 'Rows', render: (r: any) => String(r.rows_count ?? 0) },
    { key: 'added_rupees', header: 'Added', render: (r: any) => rupees(r.added_rupees) },
    { key: 'closed_rupees', header: 'Closed', render: (r: any) => rupees(r.closed_rupees) },
    { key: 'stalled_total', header: 'Stalled', render: (r: any) => String(r.stalled_total ?? 0) },
    { key: 'commitment_total_rupees', header: 'Commitment', render: (r: any) => rupees(r.commitment_total_rupees) },
  ];

  const stalledCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'stage_kind', header: 'Stage', render: (r: any) => r.stage_kind },
    { key: 'top_stalled_deal', header: 'Deal', render: (r: any) => r.top_stalled_deal ?? '-' },
    { key: 'stalled_count', header: 'Stalled', render: (r: any) => String(r.stalled_count ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const forecastCols: Column<any>[] = [
    { key: 'rows_count', header: 'Rows', render: (r: any) => String(r.rows_count ?? 0) },
    { key: 'avg_accuracy_pct', header: 'Avg %', render: (r: any) => String(r.avg_accuracy_pct ?? 0) + '%' },
    { key: 'min_accuracy_pct', header: 'Min %', render: (r: any) => String(r.min_accuracy_pct ?? 0) + '%' },
    { key: 'max_accuracy_pct', header: 'Max %', render: (r: any) => String(r.max_accuracy_pct ?? 0) + '%' },
    { key: 'red_rows', header: 'Red', render: (r: any) => String(r.red_rows ?? 0) },
    { key: 'amber_rows', header: 'Amber', render: (r: any) => String(r.amber_rows ?? 0) },
    { key: 'green_rows', header: 'Green', render: (r: any) => String(r.green_rows ?? 0) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'open_deals', header: 'Open deals', render: (r: any) => String(r.open_deals ?? 0) },
    { key: 'total_commitment_rupees', header: 'Commitment', render: (r: any) => rupees(r.total_commitment_rupees) },
    { key: 'won_rupees', header: 'Won', render: (r: any) => rupees(r.won_rupees) },
    { key: 'lost_rupees', header: 'Lost', render: (r: any) => rupees(r.lost_rupees) },
    { key: 'pushed_count', header: 'Pushed', render: (r: any) => String(r.pushed_count ?? 0) },
  ];

  return (
    <div style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      <header>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 600 }}>Founder &gt; Weekly Sales Pipeline Pulse</h1>
        <p style={{ color: '#666', marginTop: '0.25rem' }}>
          Stage-level weekly movement & deal commitments — r2513
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Weekly Pulse by Stage</h2>
        <DataTable
          rows={pulse}
          columns={pulseCols}
          emptyMessage="No pulse rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Deal Commitments</h2>
        <DataTable
          rows={commitments}
          columns={commitmentCols}
          emptyMessage="No commitments yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Weekly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Stage Breakdown</h2>
        <DataTable
          rows={stages}
          columns={stageCols}
          emptyMessage="No stages."
          rowKey={(r: any, i: number) => String(r.stage_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Top Stalled Deals</h2>
        <DataTable
          rows={stalled}
          columns={stalledCols}
          emptyMessage="No stalled deals."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Forecast Accuracy Summary</h2>
        <DataTable
          rows={forecast}
          columns={forecastCols}
          emptyMessage="No forecast data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Owner Load</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owners."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
