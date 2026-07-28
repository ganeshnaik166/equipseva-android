import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type EffRow = { efficiency_status: string; assets: number; pct: number };
type ClassRow = {
  asset_class: string;
  records: number;
  high: number;
  on_target: number;
  underutilized: number;
  idle: number;
  avg_turnover: number;
  avg_utilization_pct: number;
  total_net_block_rupees: number;
};
type MatrixRow = {
  asset_class: string;
  efficiency_status: string;
  records: number;
  avg_turnover: number;
  avg_utilization_pct: number;
  total_revenue_rupees: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  avg_turnover: number;
  avg_utilization_pct: number;
  total_gross_block_rupees: number;
  total_net_block_rupees: number;
  total_revenue_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  efficiency_status: string;
  records: number;
  avg_utilization_pct: number;
  total_revenue_rupees: number;
  total_net_block_rupees: number;
  revenue_per_net_block_rupee: number;
};
type RiskRow = {
  asset_class: string;
  business_unit: string;
  asset_ref: string;
  period_month: string;
  efficiency_status: string;
  asset_turnover_ratio: number;
  target_turnover_ratio: number;
  utilization_pct: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    effRes,
    classRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3573_efficiency_status_rollup'),
    supabase.rpc('founder_r3573_asset_class_scorecard'),
    supabase.rpc('founder_r3573_asset_class_efficiency_matrix'),
    supabase.rpc('founder_r3573_monthly_turnover_trend'),
    supabase.rpc('founder_r3573_capa_status_board'),
    supabase.rpc('founder_r3573_root_cause_pareto'),
    supabase.rpc('founder_r3573_utilization_impact_digest'),
    supabase.rpc('founder_r3573_high_risk_queue'),
  ]);

  const effRows: EffRow[] = (effRes.data as EffRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const effCols: Column<EffRow>[] = [
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'assets', header: 'Assets' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'records', header: 'Records' },
    { key: 'high', header: 'High' },
    { key: 'on_target', header: 'On Target' },
    { key: 'underutilized', header: 'Underutilized' },
    { key: 'idle', header: 'Idle' },
    { key: 'avg_turnover', header: 'Avg Turnover' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_net_block_rupees', header: 'Net Block (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_turnover', header: 'Avg Turnover' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'avg_turnover', header: 'Avg Turnover' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_gross_block_rupees', header: 'Gross Block (INR)' },
    { key: 'total_net_block_rupees', header: 'Net Block (INR)' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_net_block_rupees', header: 'Net Block (INR)' },
    { key: 'revenue_per_net_block_rupee', header: 'Revenue / Net-Block Rupee' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'asset_ref', header: 'Asset Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'asset_turnover_ratio', header: 'Turnover' },
    { key: 'target_turnover_ratio', header: 'Target' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Asset-Turnover / Gross-Block-Net-Block Utilization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated fixed-asset turnover analytics &mdash; asset class &times; business unit &times;
        gross-block vs net-block &times; revenue generated &times; asset-turnover ratio vs target
        &times; utilization % &times; efficiency status (high, on-target, underutilized, idle)
        &times; trend direction &amp; CAPA closure. Surfaces revenue per net-block rupee, monthly
        turnover trend, root-cause pareto, and a high-risk queue of idle &amp; underutilized assets
        dragging on capital efficiency.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Efficiency-status distribution</h2>
        <DataTable
          rows={effRows}
          columns={effCols}
          emptyMessage="No asset records logged yet."
          rowKey={(r, i) => String(r.efficiency_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Asset-class scorecard</h2>
        <DataTable
          rows={classRows}
          columns={classCols}
          emptyMessage="No asset-class rollups."
          rowKey={(r, i) => String(r.asset_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset-class &times; efficiency-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.asset_class}-${r.efficiency_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly turnover trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Utilization-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No utilization-impact rollups."
          rowKey={(r, i) => String(r.efficiency_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk asset queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk assets."
          rowKey={(r, i) => `${r.asset_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
