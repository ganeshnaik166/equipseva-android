import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { realization_status: string; lines: number; pct: number };
type BuRow = {
  business_unit: string;
  total_lines: number;
  strong: number;
  on_target: number;
  leaky: number;
  eroded: number;
  gross_revenue_rupees: number;
  net_revenue_rupees: number;
  avg_leakage_pct: number;
};
type MatrixRow = {
  business_unit: string;
  realization_status: string;
  lines: number;
  gross_revenue_rupees: number;
  net_revenue_rupees: number;
  avg_leakage_pct: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  gross_revenue_rupees: number;
  total_discounts_rupees: number;
  net_revenue_rupees: number;
  avg_leakage_pct: number;
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
  impact_band: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  bridge_code: string;
  period_month: string;
  gross_revenue_rupees: number;
  net_revenue_rupees: number;
  gross_to_net_leakage_pct: number;
  target_leakage_pct: number;
  realization_status: string;
  trend_dir: string | null;
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
    supabase.rpc('founder_r3601_realization_status_rollup'),
    supabase.rpc('founder_r3601_business_unit_scorecard'),
    supabase.rpc('founder_r3601_bu_realization_matrix'),
    supabase.rpc('founder_r3601_monthly_leakage_trend'),
    supabase.rpc('founder_r3601_capa_status_board'),
    supabase.rpc('founder_r3601_root_cause_pareto'),
    supabase.rpc('founder_r3601_leakage_impact_digest'),
    supabase.rpc('founder_r3601_high_risk_queue'),
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
    { key: 'realization_status', header: 'Realization Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const buCols: Column<BuRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'strong', header: 'Strong' },
    { key: 'on_target', header: 'On Target' },
    { key: 'leaky', header: 'Leaky' },
    { key: 'eroded', header: 'Eroded' },
    { key: 'gross_revenue_rupees', header: 'Gross Revenue (INR)' },
    { key: 'net_revenue_rupees', header: 'Net Revenue (INR)' },
    { key: 'avg_leakage_pct', header: 'Avg Leakage %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'realization_status', header: 'Realization Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'gross_revenue_rupees', header: 'Gross Revenue (INR)' },
    { key: 'net_revenue_rupees', header: 'Net Revenue (INR)' },
    { key: 'avg_leakage_pct', header: 'Avg Leakage %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'gross_revenue_rupees', header: 'Gross Revenue (INR)' },
    { key: 'total_discounts_rupees', header: 'Total Discounts (INR)' },
    { key: 'net_revenue_rupees', header: 'Net Revenue (INR)' },
    { key: 'avg_leakage_pct', header: 'Avg Leakage %' },
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
    { key: 'impact_band', header: 'Impact Band' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'bridge_code', header: 'Bridge' },
    { key: 'period_month', header: 'Month' },
    { key: 'gross_revenue_rupees', header: 'Gross Revenue (INR)' },
    { key: 'net_revenue_rupees', header: 'Net Revenue (INR)' },
    { key: 'gross_to_net_leakage_pct', header: 'Leakage %' },
    { key: 'target_leakage_pct', header: 'Target %' },
    { key: 'realization_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Gross-to-Net Revenue Bridge / Discount-Leakage Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated gross-to-net revenue bridge — list/gross revenue &rarr; volume &amp; promotional
        discounts &rarr; returns/credits &amp; rebates &rarr; price adjustments &rarr; net revenue,
        with gross-to-net leakage % measured against target across business units (AMC services, spare
        parts, projects, diagnostics, rentals, consumables, refurbished equipment &amp; training).
        Realization status (strong &lt; on-target &lt; leaky &lt; eroded) &times; trend &times;
        root-cause pareto &amp; discount-leakage CAPA closure. Where leakage &gt; target, the line
        surfaces in the high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Realization status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No gross-to-net lines logged yet."
          rowKey={(r, i) => String(r.realization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={buRows}
          columns={buCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; realization status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.realization_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly leakage trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Leakage-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No leakage-impact rollups."
          rowKey={(r, i) => String(r.impact_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk (eroded / leaky) queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.bridge_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
