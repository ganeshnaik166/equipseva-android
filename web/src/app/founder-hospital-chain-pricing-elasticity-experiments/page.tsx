import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    experimentsRes,
    observationsRes,
    topArpuRes,
    variantBreakdownRes,
    decisionFunnelRes,
    weeklyTrendRes,
    chainSummaryRes,
  ] = await Promise.all([
    supabase.rpc('list_experiments_r2479'),
    supabase.rpc('list_observations_r2479'),
    supabase.rpc('top_arpu_lift_r2479'),
    supabase.rpc('variant_kind_breakdown_r2479'),
    supabase.rpc('decision_funnel_r2479'),
    supabase.rpc('weekly_observation_trend_r2479'),
    supabase.rpc('chain_summary_r2479'),
  ]);

  const experiments = (experimentsRes.data ?? []) as any[];
  const observations = (observationsRes.data ?? []) as any[];
  const topArpu = (topArpuRes.data ?? []) as any[];
  const variantBreakdown = (variantBreakdownRes.data ?? []) as any[];
  const decisionFunnel = (decisionFunnelRes.data ?? []) as any[];
  const weeklyTrend = (weeklyTrendRes.data ?? []) as any[];
  const chainSummary = (chainSummaryRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '-');
  const fmtWeek = (v: any) => (v ? new Date(v).toLocaleDateString() : '-');
  const fmtRupees = (v: any) =>
    v === null || v === undefined ? '-' : `Rs ${Number(v).toLocaleString('en-IN')}`;
  const fmtPct = (v: any) =>
    v === null || v === undefined ? '-' : `${Number(v).toFixed(2)}%`;

  const experimentCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'experiment_name', header: 'Experiment', render: (r: any) => r.experiment_name ?? '-' },
    { key: 'variant_kind', header: 'Variant', render: (r: any) => r.variant_kind ?? '-' },
    { key: 'price_increase_pct', header: 'Price +%', render: (r: any) => fmtPct(r.price_increase_pct) },
    { key: 'conversion_pct', header: 'Conversion', render: (r: any) => fmtPct(r.conversion_pct) },
    { key: 'arpu_lift_rupees', header: 'ARPU Lift', render: (r: any) => fmtRupees(r.arpu_lift_rupees) },
    { key: 'churn_impact_pct', header: 'Churn Impact', render: (r: any) => fmtPct(r.churn_impact_pct) },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '-' },
    { key: 'started_at', header: 'Started', render: (r: any) => fmtDate(r.started_at) },
    { key: 'ended_at', header: 'Ended', render: (r: any) => fmtDate(r.ended_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const observationCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'experiment_name', header: 'Experiment', render: (r: any) => r.experiment_name ?? '-' },
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'observation_kind', header: 'Kind', render: (r: any) => r.observation_kind ?? '-' },
    { key: 'observation_value', header: 'Value', render: (r: any) => (r.observation_value ?? '-') },
    { key: 'observation_summary', header: 'Summary', render: (r: any) => r.observation_summary ?? '-' },
  ];

  const topArpuCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'experiment_name', header: 'Experiment', render: (r: any) => r.experiment_name ?? '-' },
    { key: 'variant_kind', header: 'Variant', render: (r: any) => r.variant_kind ?? '-' },
    { key: 'arpu_lift_rupees', header: 'ARPU Lift', render: (r: any) => fmtRupees(r.arpu_lift_rupees) },
    { key: 'conversion_pct', header: 'Conversion', render: (r: any) => fmtPct(r.conversion_pct) },
    { key: 'churn_impact_pct', header: 'Churn Impact', render: (r: any) => fmtPct(r.churn_impact_pct) },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '-' },
  ];

  const variantCols: Column<any>[] = [
    { key: 'variant_kind', header: 'Variant', render: (r: any) => r.variant_kind ?? '-' },
    { key: 'experiments_count', header: 'Experiments', render: (r: any) => r.experiments_count ?? 0 },
    { key: 'avg_conversion_pct', header: 'Avg Conversion', render: (r: any) => fmtPct(r.avg_conversion_pct) },
    { key: 'avg_arpu_lift_rupees', header: 'Avg ARPU Lift', render: (r: any) => fmtRupees(r.avg_arpu_lift_rupees) },
    { key: 'avg_churn_impact_pct', header: 'Avg Churn', render: (r: any) => fmtPct(r.avg_churn_impact_pct) },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '-' },
    { key: 'experiments_count', header: 'Count', render: (r: any) => r.experiments_count ?? 0 },
    { key: 'avg_arpu_lift_rupees', header: 'Avg ARPU Lift', render: (r: any) => fmtRupees(r.avg_arpu_lift_rupees) },
    { key: 'avg_churn_impact_pct', header: 'Avg Churn', render: (r: any) => fmtPct(r.avg_churn_impact_pct) },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtWeek(r.week_start) },
    { key: 'observations_count', header: 'Observations', render: (r: any) => r.observations_count ?? 0 },
    { key: 'avg_observation_value', header: 'Avg Value', render: (r: any) => r.avg_observation_value ?? '-' },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'experiments_count', header: 'Experiments', render: (r: any) => r.experiments_count ?? 0 },
    { key: 'total_arpu_lift_rupees', header: 'Total ARPU Lift', render: (r: any) => fmtRupees(r.total_arpu_lift_rupees) },
    { key: 'avg_conversion_pct', header: 'Avg Conversion', render: (r: any) => fmtPct(r.avg_conversion_pct) },
    { key: 'avg_churn_impact_pct', header: 'Avg Churn', render: (r: any) => fmtPct(r.avg_churn_impact_pct) },
    { key: 'adopt_count', header: 'Adopted', render: (r: any) => r.adopt_count ?? 0 },
    { key: 'reject_count', header: 'Rejected', render: (r: any) => r.reject_count ?? 0 },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 600 }}>
          Hospital Chain Pricing Elasticity Experiments — r2479
        </h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Chain × price test × variant × conversion × ARPU lift × churn impact × decision.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Experiments</h2>
        <DataTable
          rows={experiments}
          columns={experimentCols}
          emptyMessage="No experiments yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top ARPU Lift</h2>
        <DataTable
          rows={topArpu}
          columns={topArpuCols}
          emptyMessage="No ARPU lift recorded"
          rowKey={(r: any, i: number) => String(r.experiment_id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Variant Kind Breakdown</h2>
        <DataTable
          rows={variantBreakdown}
          columns={variantCols}
          emptyMessage="No variant data"
          rowKey={(r: any, i: number) => String(r.variant_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Decision Funnel</h2>
        <DataTable
          rows={decisionFunnel}
          columns={decisionCols}
          emptyMessage="No decisions recorded"
          rowKey={(r: any, i: number) => String(r.decision ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain Summary</h2>
        <DataTable
          rows={chainSummary}
          columns={chainCols}
          emptyMessage="No chains tracked"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly Observation Trend</h2>
        <DataTable
          rows={weeklyTrend}
          columns={weeklyCols}
          emptyMessage="No weekly trend"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Observations</h2>
        <DataTable
          rows={observations}
          columns={observationCols}
          emptyMessage="No observations logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
