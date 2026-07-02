import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainAmcRenewalFunnelAccelerationPage() {
  const supabase = await getSupabaseServerClient();

  const [
    funnelRes,
    outcomesRes,
    topArrRes,
    accelDistRes,
    winProbRes,
    monthlyTrendRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_funnel_r2587'),
    supabase.rpc('list_outcomes_r2587'),
    supabase.rpc('top_arr_focus_r2587'),
    supabase.rpc('acceleration_kind_distribution_r2587'),
    supabase.rpc('win_probability_summary_r2587'),
    supabase.rpc('monthly_funnel_trend_r2587'),
    supabase.rpc('owner_load_r2587'),
  ]);

  const funnel = (funnelRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const topArr = (topArrRes.data ?? []) as any[];
  const accelDist = (accelDistRes.data ?? []) as any[];
  const winProb = (winProbRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const inr = (v: any) =>
    v === null || v === undefined ? '-' : `Rs ${Number(v).toLocaleString('en-IN')}`;
  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '-');

  const funnelCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'ref', header: 'Contract Ref', render: (r: any) => r.contract_external_ref ?? '-' },
    { key: 'due', header: 'Renewal Due', render: (r: any) => fmtDate(r.renewal_due_at) },
    { key: 'win', header: 'Win %', render: (r: any) => `${r.win_probability_pct}%` },
    { key: 'arr', header: 'ARR At Stake', render: (r: any) => inr(r.arr_at_stake_rupees) },
    { key: 'accel', header: 'Acceleration', render: (r: any) => r.acceleration_action_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const outcomesCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'observed', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'days', header: 'Days To Decision', render: (r: any) => String(r.days_to_decision) },
    { key: 'rev', header: 'Revenue Realized', render: (r: any) => inr(r.revenue_realized_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topArrCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'ref', header: 'Contract Ref', render: (r: any) => r.contract_external_ref ?? '-' },
    { key: 'due', header: 'Renewal Due', render: (r: any) => fmtDate(r.renewal_due_at) },
    { key: 'win', header: 'Win %', render: (r: any) => `${r.win_probability_pct}%` },
    { key: 'arr', header: 'ARR At Stake', render: (r: any) => inr(r.arr_at_stake_rupees) },
    { key: 'accel', header: 'Acceleration', render: (r: any) => r.acceleration_action_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const accelDistCols: Column<any>[] = [
    { key: 'kind', header: 'Acceleration Kind', render: (r: any) => r.acceleration_action_kind },
    { key: 'count', header: 'Funnel Count', render: (r: any) => String(r.funnel_count) },
    { key: 'arr', header: 'Total ARR At Stake', render: (r: any) => inr(r.total_arr_at_stake) },
    { key: 'avg_win', header: 'Avg Win %', render: (r: any) => `${r.avg_win_pct}%` },
  ];

  const winProbCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'count', header: 'Funnel Count', render: (r: any) => String(r.funnel_count) },
    { key: 'arr', header: 'Total ARR At Stake', render: (r: any) => inr(r.total_arr_at_stake) },
    { key: 'expected', header: 'Expected ARR', render: (r: any) => inr(r.expected_arr_rupees) },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month', header: 'Due Month', render: (r: any) => r.due_month },
    { key: 'count', header: 'Funnel Count', render: (r: any) => String(r.funnel_count) },
    { key: 'arr', header: 'Total ARR At Stake', render: (r: any) => inr(r.total_arr_at_stake) },
    { key: 'avg_win', header: 'Avg Win %', render: (r: any) => `${r.avg_win_pct}%` },
  ];

  const ownerLoadCols: Column<any>[] = [
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'count', header: 'Funnels', render: (r: any) => String(r.funnel_count) },
    { key: 'open', header: 'Open', render: (r: any) => String(r.open_count) },
    { key: 'arr', header: 'Total ARR At Stake', render: (r: any) => inr(r.total_arr_at_stake) },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Hospital Chain AMC Renewal Funnel Acceleration
      </h1>
      <p style={{ color: '#555', marginBottom: '1.5rem' }}>
        Chain > AMC contracts > upcoming renewals > acceleration action > win probability > ARR at stake.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Renewal Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No funnel entries yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Acceleration Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomesCols}
          emptyMessage="No outcomes logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top ARR Focus (Open)</h2>
        <DataTable
          rows={topArr}
          columns={topArrCols}
          emptyMessage="No open chains."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Acceleration Kind Distribution</h2>
        <DataTable
          rows={accelDist}
          columns={accelDistCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.acceleration_action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Win Probability Summary</h2>
        <DataTable
          rows={winProb}
          columns={winProbCols}
          emptyMessage="No probability data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Monthly Funnel Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.due_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerLoadCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
