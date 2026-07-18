import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerTeamPairingEffectivenessPage() {
  const supabase = await getSupabaseServerClient();

  const [pairings, swaps, topLift, decisionDist, satSummary, monthlyTrend, swapReasons] = await Promise.all([
    supabase.rpc('list_pairings_r2590'),
    supabase.rpc('list_swap_outcomes_r2590'),
    supabase.rpc('top_lift_pairings_r2590'),
    supabase.rpc('decision_kind_distribution_r2590'),
    supabase.rpc('satisfaction_summary_r2590'),
    supabase.rpc('monthly_pairing_trend_r2590'),
    supabase.rpc('swap_reason_summary_r2590'),
  ]);

  const pairingsRows: any[] = pairings.data ?? [];
  const swapsRows: any[] = swaps.data ?? [];
  const topLiftRows: any[] = topLift.data ?? [];
  const decisionRows: any[] = decisionDist.data ?? [];
  const satRows: any[] = satSummary.data ?? [];
  const monthlyRows: any[] = monthlyTrend.data ?? [];
  const swapReasonRows: any[] = swapReasons.data ?? [];

  const pairingsCols: Column<any>[] = [
    { key: 'pairing_start_at', header: 'Start', render: (r: any) => r.pairing_start_at ? new Date(r.pairing_start_at).toLocaleDateString() : '-' },
    { key: 'duration_days', header: 'Days', render: (r: any) => String(r.duration_days ?? 0) },
    { key: 'cases_worked_count', header: 'Cases', render: (r: any) => String(r.cases_worked_count ?? 0) },
    { key: 'csat_lift_pct', header: 'CSAT Lift %', render: (r: any) => `${r.csat_lift_pct ?? 0}%` },
    { key: 'productivity_lift_pct', header: 'Prod Lift %', render: (r: any) => `${r.productivity_lift_pct ?? 0}%` },
    { key: 'satisfaction_score', header: 'Sat', render: (r: any) => `${r.satisfaction_score ?? 0}/10` },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => String(r.decision_kind ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const swapsCols: Column<any>[] = [
    { key: 'swap_at', header: 'Swap At', render: (r: any) => r.swap_at ? new Date(r.swap_at).toLocaleDateString() : '-' },
    { key: 'reason_md', header: 'Reason', render: (r: any) => String(r.reason_md ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
  ];

  const topLiftCols: Column<any>[] = [
    { key: 'combined_lift', header: 'Combined Lift', render: (r: any) => `${r.combined_lift ?? 0}%` },
    { key: 'csat_lift_pct', header: 'CSAT %', render: (r: any) => `${r.csat_lift_pct ?? 0}%` },
    { key: 'productivity_lift_pct', header: 'Prod %', render: (r: any) => `${r.productivity_lift_pct ?? 0}%` },
    { key: 'cases_worked_count', header: 'Cases', render: (r: any) => String(r.cases_worked_count ?? 0) },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'decision_kind', header: 'Decision', render: (r: any) => String(r.decision_kind ?? '') },
    { key: 'pair_count', header: 'Pairs', render: (r: any) => String(r.pair_count ?? 0) },
    { key: 'avg_csat_lift', header: 'Avg CSAT Lift', render: (r: any) => `${r.avg_csat_lift ?? 0}%` },
    { key: 'avg_prod_lift', header: 'Avg Prod Lift', render: (r: any) => `${r.avg_prod_lift ?? 0}%` },
  ];

  const satCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => String(r.bucket ?? '') },
    { key: 'pair_count', header: 'Pairs', render: (r: any) => String(r.pair_count ?? 0) },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => String(r.avg_score ?? 0) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '-' },
    { key: 'pair_count', header: 'Pairs', render: (r: any) => String(r.pair_count ?? 0) },
    { key: 'avg_csat_lift', header: 'Avg CSAT Lift', render: (r: any) => `${r.avg_csat_lift ?? 0}%` },
    { key: 'avg_prod_lift', header: 'Avg Prod Lift', render: (r: any) => `${r.avg_prod_lift ?? 0}%` },
    { key: 'avg_satisfaction', header: 'Avg Sat', render: (r: any) => String(r.avg_satisfaction ?? 0) },
  ];

  const swapReasonCols: Column<any>[] = [
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'swap_count', header: 'Swaps', render: (r: any) => String(r.swap_count ?? 0) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count ?? 0) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Team Pairing Effectiveness
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Pairing &gt; duration &gt; cases worked &gt; lift vs solo &gt; engineer satisfaction &gt; continue/swap.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Active & Recent Pairings</h2>
        <DataTable
          rows={pairingsRows}
          columns={pairingsCols}
          emptyMessage="No pairings yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Lift Pairings</h2>
        <DataTable
          rows={topLiftRows}
          columns={topLiftCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Decision Distribution</h2>
        <DataTable
          rows={decisionRows}
          columns={decisionCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.decision_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Satisfaction Summary</h2>
        <DataTable
          rows={satRows}
          columns={satCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly Trend</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Swap Outcomes</h2>
        <DataTable
          rows={swapsRows}
          columns={swapsCols}
          emptyMessage="No swaps recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Swap Reason Summary</h2>
        <DataTable
          rows={swapReasonRows}
          columns={swapReasonCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.outcome ?? i)}
        />
      </section>
    </main>
  );
}
