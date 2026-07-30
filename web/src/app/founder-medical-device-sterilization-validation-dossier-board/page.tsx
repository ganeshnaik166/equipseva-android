import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { validation_status: string; dossiers: number; pct: number };
type MethodRow = {
  method_type: string;
  total_dossiers: number;
  validated: number;
  revalidation_due: number;
  out_of_spec: number;
  expired: number;
  within_limits_count: number;
  validated_pct: number;
};
type MatrixRow = {
  method_type: string;
  validation_status: string;
  dossiers: number;
  avg_bioburden_cfu: number | null;
  avg_eo_residual_ppm: number | null;
};
type TrendRow = {
  period_month: string;
  dossiers: number;
  validated: number;
  out_of_spec: number;
  expired: number;
  revalidation_due: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type OosRow = {
  method_type: string;
  out_of_spec_dossiers: number;
  eo_over_limit: number;
  avg_eo_residual_ppm: number | null;
  avg_bioburden_cfu: number | null;
  worsening_trend: number;
};
type RiskRow = {
  device_name: string;
  dossier_code: string;
  method_type: string;
  period_month: string;
  validation_status: string;
  sal_achieved: string | null;
  eo_residual_ppm: number | null;
  eo_limit_ppm: number | null;
  bioburden_cfu: number | null;
  revalidation_due: string | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    methodRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    oosRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3646_validation_status_rollup'),
    supabase.rpc('founder_r3646_method_type_scorecard'),
    supabase.rpc('founder_r3646_method_status_matrix'),
    supabase.rpc('founder_r3646_monthly_validation_trend'),
    supabase.rpc('founder_r3646_capa_status_board'),
    supabase.rpc('founder_r3646_root_cause_pareto'),
    supabase.rpc('founder_r3646_out_of_spec_digest'),
    supabase.rpc('founder_r3646_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const methodRows: MethodRow[] = (methodRes.data as MethodRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const oosRows: OosRow[] = (oosRes.data as OosRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'validation_status', header: 'Validation Status' },
    { key: 'dossiers', header: 'Dossiers' },
    { key: 'pct', header: 'Share %' },
  ];

  const methodCols: Column<MethodRow>[] = [
    { key: 'method_type', header: 'Method' },
    { key: 'total_dossiers', header: 'Dossiers' },
    { key: 'validated', header: 'Validated' },
    { key: 'revalidation_due', header: 'Reval Due' },
    { key: 'out_of_spec', header: 'Out of Spec' },
    { key: 'expired', header: 'Expired' },
    { key: 'within_limits_count', header: 'Within Limits' },
    { key: 'validated_pct', header: 'Validated %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'method_type', header: 'Method' },
    { key: 'validation_status', header: 'Status' },
    { key: 'dossiers', header: 'Dossiers' },
    { key: 'avg_bioburden_cfu', header: 'Avg Bioburden CFU' },
    { key: 'avg_eo_residual_ppm', header: 'Avg EO Residual ppm' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'dossiers', header: 'Dossiers' },
    { key: 'validated', header: 'Validated' },
    { key: 'out_of_spec', header: 'Out of Spec' },
    { key: 'expired', header: 'Expired' },
    { key: 'revalidation_due', header: 'Reval Due' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const oosCols: Column<OosRow>[] = [
    { key: 'method_type', header: 'Method' },
    { key: 'out_of_spec_dossiers', header: 'Out-of-Spec / Expired' },
    { key: 'eo_over_limit', header: 'EO Over Limit' },
    { key: 'avg_eo_residual_ppm', header: 'Avg EO Residual ppm' },
    { key: 'avg_bioburden_cfu', header: 'Avg Bioburden CFU' },
    { key: 'worsening_trend', header: 'Worsening Trend' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'dossier_code', header: 'Dossier' },
    { key: 'method_type', header: 'Method' },
    { key: 'period_month', header: 'Month' },
    { key: 'validation_status', header: 'Status' },
    { key: 'sal_achieved', header: 'SAL' },
    { key: 'eo_residual_ppm', header: 'EO Residual ppm' },
    { key: 'eo_limit_ppm', header: 'EO Limit ppm' },
    { key: 'bioburden_cfu', header: 'Bioburden CFU' },
    { key: 'revalidation_due', header: 'Reval Due' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Sterilization Validation Dossier Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Sterilization validation dossier &mdash; sterility assurance level (SAL), bioburden CFU, EO
        residual vs limit and radiation dose per device &amp; method (ethylene oxide, gamma, e-beam,
        steam &amp; VH2O2) &times; validation status &times; revalidation due &times; within-limits
        flag &times; residual/bioburden trend &amp; CAPA closure. Founder-gated view: validation-status
        distribution, method-type scorecards, root-cause pareto, out-of-spec digest and a high-risk
        queue across CDSCO, ISO&nbsp;11135 &amp; ISO&nbsp;11137 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Validation status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No validation dossiers logged yet."
          rowKey={(r, i) => String(r.validation_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Method-type scorecard</h2>
        <DataTable
          rows={methodRows}
          columns={methodCols}
          emptyMessage="No method-type rollups."
          rowKey={(r, i) => String(r.method_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Method &times; validation-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No dossiers by method."
          rowKey={(r, i) => `${r.method_type}-${r.validation_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly validation trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Out-of-spec digest</h2>
        <DataTable
          rows={oosRows}
          columns={oosCols}
          emptyMessage="No out-of-spec dossiers."
          rowKey={(r, i) => String(r.method_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk dossiers."
          rowKey={(r, i) => `${r.dossier_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
