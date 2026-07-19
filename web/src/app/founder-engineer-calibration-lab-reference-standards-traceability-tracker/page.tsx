import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { standard_verdict: string; standards: number; pct: number };
type LabRow = {
  lab_location: string;
  total_standards: number;
  in_cal_valid: number;
  due_soon: number;
  overdue: number;
  uncertainty_fail: number;
  cert_invalid: number;
  valid_pct: number;
};
type MatrixRow = {
  standard_type: string;
  traceable_to: string;
  standards: number;
  in_cal_valid: number;
  avg_days_to_due: number;
  overdue: number;
};
type TrendRow = {
  cal_due_date: string;
  standards: number;
  in_cal_valid: number;
  overdue: number;
  due_soon: number;
  cert_invalid: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  lab_location: string;
  standard_code: string;
  standard_type: string;
  cal_due_date: string;
  days_to_due: number;
  standard_verdict: string;
  uncertainty_budget_ok: boolean | null;
  cal_certificate_valid: boolean | null;
  environmental_conditions_logged: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    labRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3360_verdict_rollup'),
    supabase.rpc('founder_r3360_lab_location_scorecard'),
    supabase.rpc('founder_r3360_type_traceability_matrix'),
    supabase.rpc('founder_r3360_cal_due_trend'),
    supabase.rpc('founder_r3360_capa_status_board'),
    supabase.rpc('founder_r3360_root_cause_pareto'),
    supabase.rpc('founder_r3360_regulatory_impact_digest'),
    supabase.rpc('founder_r3360_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const labRows: LabRow[] = (labRes.data as LabRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'standard_verdict', header: 'Verdict' },
    { key: 'standards', header: 'Standards' },
    { key: 'pct', header: 'Share %' },
  ];

  const labCols: Column<LabRow>[] = [
    { key: 'lab_location', header: 'Lab Location' },
    { key: 'total_standards', header: 'Standards' },
    { key: 'in_cal_valid', header: 'In-Cal Valid' },
    { key: 'due_soon', header: 'Due Soon' },
    { key: 'overdue', header: 'Overdue / Retired' },
    { key: 'uncertainty_fail', header: 'Uncertainty Fail' },
    { key: 'cert_invalid', header: 'Cert Invalid' },
    { key: 'valid_pct', header: 'Valid %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'standard_type', header: 'Standard Type' },
    { key: 'traceable_to', header: 'Traceable To' },
    { key: 'standards', header: 'Standards' },
    { key: 'in_cal_valid', header: 'In-Cal Valid' },
    { key: 'avg_days_to_due', header: 'Avg Days To Due' },
    { key: 'overdue', header: 'Overdue / Retired' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_due_date', header: 'Cal Due Date' },
    { key: 'standards', header: 'Standards' },
    { key: 'in_cal_valid', header: 'In-Cal Valid' },
    { key: 'overdue', header: 'Overdue / Retired' },
    { key: 'due_soon', header: 'Due Soon' },
    { key: 'cert_invalid', header: 'Cert Invalid' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'lab_location', header: 'Lab Location' },
    { key: 'standard_code', header: 'Standard' },
    { key: 'standard_type', header: 'Type' },
    { key: 'cal_due_date', header: 'Cal Due' },
    { key: 'days_to_due', header: 'Days To Due' },
    { key: 'standard_verdict', header: 'Verdict' },
    { key: 'uncertainty_budget_ok', header: 'Uncertainty OK' },
    { key: 'cal_certificate_valid', header: 'Cert Valid' },
    { key: 'environmental_conditions_logged', header: 'Env Logged' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Calibration-Lab Reference-Standards &amp; Measurement-Traceability Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ISO 17025 / NABL master-instrument register — lab location &times; standard type &times;
        traceability chain &times; cal validity &times; uncertainty budget &times; certificate
        status &times; environmental log &times; usage-since-cal &amp; CAPA closure. Founder-gated
        view: standard verdicts, lab scorecards, root-cause pareto, and regulatory-impact digest
        across NABL &amp; ISO 17025 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Standard verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No reference standards logged yet."
          rowKey={(r, i) => String(r.standard_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Lab-location scorecard</h2>
        <DataTable
          rows={labRows}
          columns={labCols}
          emptyMessage="No lab rollups."
          rowKey={(r, i) => String(r.lab_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Standard type &times; traceability matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No standards by type."
          rowKey={(r, i) => `${r.standard_type}-${r.traceable_to}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Calibration-due trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cal_due_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk standards queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk standards."
          rowKey={(r, i) => `${r.standard_code}-${r.cal_due_date}-${i}`}
        />
      </section>
    </main>
  );
}
