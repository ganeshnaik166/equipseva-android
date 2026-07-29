import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { conversion_status: string; periods: number; pct: number };
type BuRow = {
  business_unit: string;
  periods: number;
  strong: number;
  on_target: number;
  weak: number;
  cash_burn: number;
  avg_conversion_pct: number;
  total_free_cash_flow_rupees: number;
};
type MatrixRow = {
  business_unit: string;
  conversion_status: string;
  periods: number;
  avg_conversion_pct: number;
  total_free_cash_flow_rupees: number;
};
type TrendRow = {
  period_month: string;
  periods: number;
  total_ebitda_rupees: number;
  total_operating_cash_flow_rupees: number;
  total_free_cash_flow_rupees: number;
  avg_conversion_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cash_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cash_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_cash_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  bridge_code: string;
  period_month: string;
  ebitda_rupees: number | null;
  free_cash_flow_rupees: number | null;
  fcf_conversion_pct: number | null;
  target_conversion_pct: number | null;
  conversion_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    buRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3585_conversion_status_rollup'),
    supabase.rpc('founder_r3585_business_unit_scorecard'),
    supabase.rpc('founder_r3585_bu_conversion_matrix'),
    supabase.rpc('founder_r3585_monthly_fcf_trend'),
    supabase.rpc('founder_r3585_capa_status_board'),
    supabase.rpc('founder_r3585_root_cause_pareto'),
    supabase.rpc('founder_r3585_cash_conversion_impact_digest'),
    supabase.rpc('founder_r3585_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const buRows: BuRow[] = (buRes.data as BuRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'conversion_status', header: 'Conversion Status' },
    { key: 'periods', header: 'Periods' },
    { key: 'pct', header: 'Share %' },
  ];

  const buCols: Column<BuRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'periods', header: 'Periods' },
    { key: 'strong', header: 'Strong' },
    { key: 'on_target', header: 'On Target' },
    { key: 'weak', header: 'Weak' },
    { key: 'cash_burn', header: 'Cash Burn' },
    { key: 'avg_conversion_pct', header: 'Avg Conversion %' },
    { key: 'total_free_cash_flow_rupees', header: 'Total FCF (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'conversion_status', header: 'Conversion Status' },
    { key: 'periods', header: 'Periods' },
    { key: 'avg_conversion_pct', header: 'Avg Conversion %' },
    { key: 'total_free_cash_flow_rupees', header: 'Total FCF (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'periods', header: 'Bridges' },
    { key: 'total_ebitda_rupees', header: 'EBITDA (INR)' },
    { key: 'total_operating_cash_flow_rupees', header: 'Operating Cash (INR)' },
    { key: 'total_free_cash_flow_rupees', header: 'FCF (INR)' },
    { key: 'avg_conversion_pct', header: 'Avg Conversion %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cash_impact_rupees', header: 'Avg Cash Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cash_impact_rupees', header: 'Total Cash Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cash_impact_rupees', header: 'Total Cash Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'bridge_code', header: 'Bridge' },
    { key: 'period_month', header: 'Month' },
    { key: 'ebitda_rupees', header: 'EBITDA (INR)' },
    { key: 'free_cash_flow_rupees', header: 'FCF (INR)' },
    { key: 'fcf_conversion_pct', header: 'Conversion %' },
    { key: 'target_conversion_pct', header: 'Target %' },
    { key: 'conversion_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Free-Cash-Flow (FCF) Bridge / Conversion Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated free-cash-flow bridge across business units &amp; months &mdash; EBITDA &rarr;
        working-capital change &amp; tax &rarr; operating cash flow &rarr; capex &rarr; free cash flow,
        with FCF conversion % measured against target per period. Business units span AMC services,
        spare parts, equipment rental, turnkey projects, consumables &amp; diagnostics. View: conversion
        distribution, business-unit scorecards, business-unit &times; status matrix, monthly FCF trend,
        CAPA status board, root-cause pareto, cash-conversion impact digest &amp; a high-risk queue for
        cash-burn / weak-conversion periods.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Conversion-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No FCF bridges logged yet."
          rowKey={(r, i) => String(r.conversion_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit FCF scorecard</h2>
        <DataTable
          rows={buRows}
          columns={buCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business-unit &times; conversion-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.business_unit}-${r.conversion_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly FCF trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cash-conversion impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact digest data."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk conversion queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk periods."
          rowKey={(r, i) => `${r.bridge_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
