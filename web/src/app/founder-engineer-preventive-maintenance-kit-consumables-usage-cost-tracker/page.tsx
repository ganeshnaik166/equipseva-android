import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { usage_status: string; records: number; pct: number };
type RegionRow = {
  region: string;
  total_records: number;
  efficient: number;
  over_consuming: number;
  wastage_risk: number;
  stockout_risk: number;
  avg_variance_pct: number;
  avg_cost_per_pm: number;
  efficient_pct: number;
};
type MatrixRow = {
  kit_type: string;
  usage_status: string;
  records: number;
  avg_variance_pct: number;
  avg_wastage_pct: number;
  total_cost_rupees: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_pm_visits: number;
  total_cost_rupees: number;
  avg_cost_per_pm: number;
  avg_wastage_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_cost_impact_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  device_model: string;
  period_month: string;
  kit_type: string;
  usage_status: string;
  consumable_variance_pct: number | null;
  wastage_pct: number | null;
  cost_per_pm_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3588_usage_status_rollup'),
    supabase.rpc('founder_r3588_region_scorecard'),
    supabase.rpc('founder_r3588_kit_type_status_matrix'),
    supabase.rpc('founder_r3588_monthly_cost_trend'),
    supabase.rpc('founder_r3588_capa_status_board'),
    supabase.rpc('founder_r3588_root_cause_pareto'),
    supabase.rpc('founder_r3588_cost_impact_digest'),
    supabase.rpc('founder_r3588_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'usage_status', header: 'Usage Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_records', header: 'Records' },
    { key: 'efficient', header: 'Efficient' },
    { key: 'over_consuming', header: 'Over-consuming' },
    { key: 'wastage_risk', header: 'Wastage Risk' },
    { key: 'stockout_risk', header: 'Stockout Risk' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'avg_cost_per_pm', header: 'Avg Cost / PM (INR)' },
    { key: 'efficient_pct', header: 'On-Standard %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'kit_type', header: 'Kit Type' },
    { key: 'usage_status', header: 'Usage Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'avg_wastage_pct', header: 'Avg Wastage %' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_pm_visits', header: 'PM Visits' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'avg_cost_per_pm', header: 'Avg Cost / PM (INR)' },
    { key: 'avg_wastage_pct', header: 'Avg Wastage %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_impact_rupees', header: 'Avg Cost Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_impact_rupees', header: 'Total Cost Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_impact_rupees', header: 'Total Cost Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'period_month', header: 'Month' },
    { key: 'kit_type', header: 'Kit Type' },
    { key: 'usage_status', header: 'Usage Status' },
    { key: 'consumable_variance_pct', header: 'Variance %' },
    { key: 'wastage_pct', header: 'Wastage %' },
    { key: 'cost_per_pm_rupees', header: 'Cost / PM (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Preventive-Maintenance Kit / Consumables Usage &amp; Cost Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        PM-kit consumables usage-vs-standard &amp; cost-per-PM tracker — engineer &times; region &times;
        device model &times; month &times; kit type (filter, lubricant, calibration, gasket/seal, battery,
        cleaning) &times; PM visits &times; kits consumed vs standard &times; consumable variance %
        &times; consumable cost &times; cost-per-PM vs target &times; wastage % &amp; CAPA closure.
        Founder-gated view: usage-status distribution, region scorecards, root-cause pareto, and
        cost-impact digest across over-consuming, wastage-risk &amp; stockout-risk surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Usage-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No usage records logged yet."
          rowKey={(r, i) => String(r.usage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Kit type &times; usage status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by kit type."
          rowKey={(r, i) => `${r.kit_type}-${r.usage_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly consumable-cost trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No cost-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk usage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk records."
          rowKey={(r, i) => `${r.engineer_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
