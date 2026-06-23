import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyEnergyAllocationAuditPage() {
  const supabase = await getSupabaseServerClient();

  const [
    allocationRes,
    correctionsRes,
    trendRes,
    distRes,
    drainRes,
    funnelRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_allocation_r2549'),
    supabase.rpc('list_corrections_r2549'),
    supabase.rpc('weekly_leverage_trend_r2549'),
    supabase.rpc('alignment_kind_distribution_r2549'),
    supabase.rpc('top_drain_focus_r2549'),
    supabase.rpc('correction_status_funnel_r2549'),
    supabase.rpc('monthly_pulse_summary_r2549'),
  ]);

  const allocationRows = allocationRes.data ?? [];
  const correctionRows = correctionsRes.data ?? [];
  const trendRows = trendRes.data ?? [];
  const distRows = distRes.data ?? [];
  const drainRows = drainRes.data ?? [];
  const funnelRows = funnelRes.data ?? [];
  const pulseRows = pulseRes.data ?? [];

  const allocationCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'strategic_hours', header: 'Strategic h', render: (r: any) => String(r.strategic_hours ?? 0) },
    { key: 'tactical_hours', header: 'Tactical h', render: (r: any) => String(r.tactical_hours ?? 0) },
    { key: 'firefighting_hours', header: 'Firefighting h', render: (r: any) => String(r.firefighting_hours ?? 0) },
    { key: 'learning_hours', header: 'Learning h', render: (r: any) => String(r.learning_hours ?? 0) },
    { key: 'total_hours', header: 'Total h', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'alignment_kind', header: 'Alignment', render: (r: any) => String(r.alignment_kind ?? '') },
    { key: 'leverage_score', header: 'Leverage', render: (r: any) => String(r.leverage_score ?? 0) },
    { key: 'top_drain_md', header: 'Top drain', render: (r: any) => String(r.top_drain_md ?? '') },
    { key: 'top_high_leverage_md', header: 'Top high-leverage', render: (r: any) => String(r.top_high_leverage_md ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const correctionCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'correction_kind', header: 'Kind', render: (r: any) => String(r.correction_kind ?? '') },
    { key: 'action_md', header: 'Action', render: (r: any) => String(r.action_md ?? '') },
    { key: 'expected_impact_md', header: 'Expected impact', render: (r: any) => String(r.expected_impact_md ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'leverage_score', header: 'Leverage', render: (r: any) => String(r.leverage_score ?? 0) },
    { key: 'strategic_hours', header: 'Strategic h', render: (r: any) => String(r.strategic_hours ?? 0) },
    { key: 'firefighting_hours', header: 'Firefighting h', render: (r: any) => String(r.firefighting_hours ?? 0) },
    { key: 'alignment_kind', header: 'Alignment', render: (r: any) => String(r.alignment_kind ?? '') },
  ];

  const distCols: Column<any>[] = [
    { key: 'alignment_kind', header: 'Alignment', render: (r: any) => String(r.alignment_kind ?? '') },
    { key: 'week_count', header: 'Weeks', render: (r: any) => String(r.week_count ?? 0) },
    { key: 'avg_leverage', header: 'Avg leverage', render: (r: any) => String(r.avg_leverage ?? 0) },
  ];

  const drainCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'firefighting_hours', header: 'Firefighting h', render: (r: any) => String(r.firefighting_hours ?? 0) },
    { key: 'top_drain_md', header: 'Top drain', render: (r: any) => String(r.top_drain_md ?? '') },
    { key: 'leverage_score', header: 'Leverage', render: (r: any) => String(r.leverage_score ?? 0) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'correction_count', header: 'Count', render: (r: any) => String(r.correction_count ?? 0) },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => String(r.positive_outcomes ?? 0) },
    { key: 'pending_outcomes', header: 'Pending', render: (r: any) => String(r.pending_outcomes ?? 0) },
  ];

  const pulseCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '') },
    { key: 'weeks_logged', header: 'Weeks logged', render: (r: any) => String(r.weeks_logged ?? 0) },
    { key: 'avg_strategic_hours', header: 'Avg strategic h', render: (r: any) => String(r.avg_strategic_hours ?? 0) },
    { key: 'avg_firefighting_hours', header: 'Avg firefighting h', render: (r: any) => String(r.avg_firefighting_hours ?? 0) },
    { key: 'avg_leverage', header: 'Avg leverage', render: (r: any) => String(r.avg_leverage ?? 0) },
    { key: 'corrections_done', header: 'Corrections done', render: (r: any) => String(r.corrections_done ?? 0) },
  ];

  return (
    <main style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '32px' }}>
      <header>
        <h1 style={{ fontSize: '24px', fontWeight: 700 }}>Founder Weekly Energy Allocation Audit</h1>
        <p style={{ color: '#666', marginTop: '4px' }}>
          Where founder hours flow each week & whether they align with leverage.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Weekly allocation log</h2>
        <DataTable
          rows={allocationRows}
          columns={allocationCols}
          emptyMessage="No allocations logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Corrective actions</h2>
        <DataTable
          rows={correctionRows}
          columns={correctionCols}
          emptyMessage="No corrections logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Leverage trend by week</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Alignment kind distribution</h2>
        <DataTable
          rows={distRows}
          columns={distCols}
          emptyMessage="No alignment data"
          rowKey={(r: any, i: number) => String(r.alignment_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Top drain focus</h2>
        <DataTable
          rows={drainRows}
          columns={drainCols}
          emptyMessage="No drains identified"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Correction status funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No corrections"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Monthly pulse summary</h2>
        <DataTable
          rows={pulseRows}
          columns={pulseCols}
          emptyMessage="No monthly data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </main>
  );
}
