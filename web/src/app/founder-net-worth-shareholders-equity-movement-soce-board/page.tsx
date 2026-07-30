import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { equity_status: string; entries: number; pct: number };
type EntityRow = {
  entity_name: string;
  movements: number;
  total_net_profit_rupees: number;
  total_dividends_rupees: number;
  total_capital_raised_rupees: number;
  total_oci_rupees: number;
  avg_growth_pct: number;
  strengthening: number;
  eroding_or_worse: number;
};
type MatrixRow = {
  entity_name: string;
  equity_status: string;
  movements: number;
  avg_growth_pct: number;
  total_net_movement_rupees: number;
};
type TrendRow = {
  period_month: string;
  movements: number;
  total_opening_equity_rupees: number;
  total_closing_equity_rupees: number;
  total_net_profit_rupees: number;
  total_capital_raised_rupees: number;
  avg_growth_pct: number;
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
  equity_status: string;
  entities: number;
  total_opening_equity_rupees: number;
  total_net_profit_rupees: number;
  total_dividends_rupees: number;
  total_capital_raised_rupees: number;
  total_closing_equity_rupees: number;
  total_net_movement_rupees: number;
};
type RiskRow = {
  entity_name: string;
  entry_code: string;
  period_month: string;
  equity_status: string;
  trend_dir: string;
  closing_equity_rupees: number;
  net_worth_growth_pct: number;
  book_value_per_share_rupees: number;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3613_equity_status_rollup'),
    supabase.rpc('founder_r3613_entity_scorecard'),
    supabase.rpc('founder_r3613_entity_status_matrix'),
    supabase.rpc('founder_r3613_monthly_networth_trend'),
    supabase.rpc('founder_r3613_capa_status_board'),
    supabase.rpc('founder_r3613_root_cause_pareto'),
    supabase.rpc('founder_r3613_equity_movement_digest'),
    supabase.rpc('founder_r3613_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'equity_status', header: 'Equity Status' },
    { key: 'entries', header: 'Movements' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'movements', header: 'Movements' },
    { key: 'total_net_profit_rupees', header: 'Net Profit (INR)' },
    { key: 'total_dividends_rupees', header: 'Dividends (INR)' },
    { key: 'total_capital_raised_rupees', header: 'Capital Raised (INR)' },
    { key: 'total_oci_rupees', header: 'OCI (INR)' },
    { key: 'avg_growth_pct', header: 'Avg Growth %' },
    { key: 'strengthening', header: 'Strengthening' },
    { key: 'eroding_or_worse', header: 'Eroding+' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'equity_status', header: 'Equity Status' },
    { key: 'movements', header: 'Movements' },
    { key: 'avg_growth_pct', header: 'Avg Growth %' },
    { key: 'total_net_movement_rupees', header: 'Net Movement (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'movements', header: 'Movements' },
    { key: 'total_opening_equity_rupees', header: 'Opening Equity (INR)' },
    { key: 'total_closing_equity_rupees', header: 'Closing Equity (INR)' },
    { key: 'total_net_profit_rupees', header: 'Net Profit (INR)' },
    { key: 'total_capital_raised_rupees', header: 'Capital Raised (INR)' },
    { key: 'avg_growth_pct', header: 'Avg Growth %' },
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
    { key: 'equity_status', header: 'Equity Status' },
    { key: 'entities', header: 'Entities' },
    { key: 'total_opening_equity_rupees', header: 'Opening Equity (INR)' },
    { key: 'total_net_profit_rupees', header: 'Net Profit (INR)' },
    { key: 'total_dividends_rupees', header: 'Dividends (INR)' },
    { key: 'total_capital_raised_rupees', header: 'Capital Raised (INR)' },
    { key: 'total_closing_equity_rupees', header: 'Closing Equity (INR)' },
    { key: 'total_net_movement_rupees', header: 'Net Movement (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'entry_code', header: 'Entry' },
    { key: 'period_month', header: 'Month' },
    { key: 'equity_status', header: 'Equity Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'closing_equity_rupees', header: 'Closing Equity (INR)' },
    { key: 'net_worth_growth_pct', header: 'Growth %' },
    { key: 'book_value_per_share_rupees', header: 'BVPS (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Net-Worth / Shareholders-Equity Movement (SOCE) Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated statement of changes in equity per entity &amp; business unit (device sales,
        AMC services, spare parts, projects, diagnostics, rentals) &mdash; opening equity &times; net
        profit &times; dividends paid &times; capital raised &times; OCI movement &times; other
        adjustments &times; closing equity &times; net-worth growth % &times; book value/share, with
        equity-status &amp; trend classification and CAPA remediation for eroding, depleted &amp;
        negative-net-worth entities.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Equity-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No equity movements logged yet."
          rowKey={(r, i) => String(r.equity_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Entity &times; equity-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No movements by entity."
          rowKey={(r, i) => `${r.entity_name}-${r.equity_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly net-worth trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Equity-movement digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No equity-movement digest."
          rowKey={(r, i) => String(r.equity_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk equity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk entities."
          rowKey={(r, i) => `${r.entry_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
