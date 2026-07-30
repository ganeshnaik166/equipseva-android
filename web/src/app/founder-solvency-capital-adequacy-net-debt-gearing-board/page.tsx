import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { solvency_status: string; entities: number; pct: number };
type EntityRow = {
  entity_name: string;
  snapshots: number;
  robust: number;
  healthy: number;
  leveraged: number;
  stretched: number;
  distressed: number;
  avg_debt_to_equity: number;
  avg_net_debt_to_ebitda: number;
  avg_interest_coverage: number;
  avg_gearing_headroom_pct: number;
};
type MatrixRow = {
  entity_name: string;
  solvency_status: string;
  snapshots: number;
  avg_debt_to_equity: number;
  avg_net_debt_to_ebitda: number;
  avg_interest_coverage: number;
};
type TrendRow = {
  period_month: string;
  snapshots: number;
  avg_debt_to_equity: number;
  avg_net_debt_to_ebitda: number;
  avg_interest_coverage: number;
  stretched_distressed: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_ebitda_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_ebitda_impact_rupees: number;
  pct: number;
};
type ImpactRow = {
  impact_category: string;
  findings: number;
  open_findings: number;
  total_ebitda_impact_rupees: number;
};
type RiskRow = {
  entity_name: string;
  entity_code: string;
  business_unit: string;
  period_month: string;
  solvency_status: string;
  debt_to_equity_ratio: number | null;
  net_debt_to_ebitda_ratio: number | null;
  interest_coverage_ratio: number | null;
  gearing_headroom_pct: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3618_solvency_status_rollup'),
    supabase.rpc('founder_r3618_entity_scorecard'),
    supabase.rpc('founder_r3618_entity_status_matrix'),
    supabase.rpc('founder_r3618_monthly_gearing_trend'),
    supabase.rpc('founder_r3618_capa_status_board'),
    supabase.rpc('founder_r3618_root_cause_pareto'),
    supabase.rpc('founder_r3618_leverage_impact_digest'),
    supabase.rpc('founder_r3618_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'solvency_status', header: 'Solvency Status' },
    { key: 'entities', header: 'Snapshots' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'robust', header: 'Robust' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'leveraged', header: 'Leveraged' },
    { key: 'stretched', header: 'Stretched' },
    { key: 'distressed', header: 'Distressed' },
    { key: 'avg_debt_to_equity', header: 'Avg D/E' },
    { key: 'avg_net_debt_to_ebitda', header: 'Avg NetDebt/EBITDA' },
    { key: 'avg_interest_coverage', header: 'Avg Int Cover' },
    { key: 'avg_gearing_headroom_pct', header: 'Avg Headroom %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'solvency_status', header: 'Solvency Status' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'avg_debt_to_equity', header: 'Avg D/E' },
    { key: 'avg_net_debt_to_ebitda', header: 'Avg NetDebt/EBITDA' },
    { key: 'avg_interest_coverage', header: 'Avg Int Cover' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'avg_debt_to_equity', header: 'Avg D/E' },
    { key: 'avg_net_debt_to_ebitda', header: 'Avg NetDebt/EBITDA' },
    { key: 'avg_interest_coverage', header: 'Avg Int Cover' },
    { key: 'stretched_distressed', header: 'Stretched / Distressed' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_ebitda_impact_rupees', header: 'Avg EBITDA Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_ebitda_impact_rupees', header: 'Total EBITDA Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'impact_category', header: 'Impact Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_ebitda_impact_rupees', header: 'Total EBITDA Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'entity_code', header: 'Code' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'period_month', header: 'Month' },
    { key: 'solvency_status', header: 'Status' },
    { key: 'debt_to_equity_ratio', header: 'D/E' },
    { key: 'net_debt_to_ebitda_ratio', header: 'NetDebt/EBITDA' },
    { key: 'interest_coverage_ratio', header: 'Int Cover' },
    { key: 'gearing_headroom_pct', header: 'Headroom %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Solvency / Capital-Adequacy / Net-Debt Gearing Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder solvency &amp; capital-adequacy view — per-entity monthly gearing across AMC services,
        spare parts, projects, diagnostics, rentals &amp; the consolidated group. Tracks net-debt
        gearing, debt-to-equity, net-debt/EBITDA &amp; interest-cover against target-gearing headroom,
        with solvency status (robust &rarr; distressed) &amp; trend direction. Founder-gated: status
        distribution, entity scorecards, entity &times; status matrix, monthly gearing trend,
        root-cause pareto &amp; a high-risk (stretched &amp; distressed) queue with CAPA remediation.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Solvency status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No solvency snapshots logged yet."
          rowKey={(r, i) => String(r.solvency_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity solvency scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Entity &times; solvency-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No snapshots by entity and status."
          rowKey={(r, i) => `${r.entity_name}-${r.solvency_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly gearing trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Leverage-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No leverage-impact rollups."
          rowKey={(r, i) => String(r.impact_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk solvency queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk entities."
          rowKey={(r, i) => `${r.entity_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
