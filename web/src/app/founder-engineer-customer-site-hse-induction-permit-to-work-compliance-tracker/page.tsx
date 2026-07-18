import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { compliance_verdict: string; visits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_visits: number;
  fully_compliant: number;
  minor_gap: number;
  permit_missing: number;
  stop_work: number;
  ppe_fail: number;
  induction_invalid: number;
  compliance_pct: number;
};
type MatrixRow = {
  work_category: string;
  engineer_name: string;
  visits: number;
  fully_compliant: number;
  near_miss_total: number;
  compliance_pct: number;
};
type TrendRow = {
  visit_date: string;
  visits: number;
  fully_compliant: number;
  permit_missing: number;
  stop_work: number;
  near_miss_total: number;
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
  hospital_name: string;
  engineer_name: string;
  job_code: string;
  visit_date: string;
  work_category: string;
  compliance_verdict: string;
  ptw_obtained: boolean;
  ppe_compliant: boolean;
  site_induction_valid: boolean;
  near_miss_reported: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3300_compliance_verdict_rollup'),
    supabase.rpc('founder_r3300_hospital_scorecard'),
    supabase.rpc('founder_r3300_category_engineer_matrix'),
    supabase.rpc('founder_r3300_daily_compliance_trend'),
    supabase.rpc('founder_r3300_capa_status_board'),
    supabase.rpc('founder_r3300_root_cause_pareto'),
    supabase.rpc('founder_r3300_regulatory_impact_digest'),
    supabase.rpc('founder_r3300_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'visits', header: 'Visits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_visits', header: 'Visits' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'minor_gap', header: 'Minor Gap' },
    { key: 'permit_missing', header: 'Permit Missing' },
    { key: 'stop_work', header: 'Stop-Work / Incident' },
    { key: 'ppe_fail', header: 'PPE Fail' },
    { key: 'induction_invalid', header: 'Induction Invalid' },
    { key: 'compliance_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'work_category', header: 'Work Category' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'visits', header: 'Visits' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'near_miss_total', header: 'Near-Misses' },
    { key: 'compliance_pct', header: 'Compliant %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'visit_date', header: 'Date' },
    { key: 'visits', header: 'Visits' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'permit_missing', header: 'Permit Missing' },
    { key: 'stop_work', header: 'Stop-Work / Incident' },
    { key: 'near_miss_total', header: 'Near-Misses' },
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
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'job_code', header: 'Job' },
    { key: 'visit_date', header: 'Date' },
    { key: 'work_category', header: 'Work Category' },
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'ptw_obtained', header: 'PTW Obtained' },
    { key: 'ppe_compliant', header: 'PPE OK' },
    { key: 'site_induction_valid', header: 'Induction Valid' },
    { key: 'near_miss_reported', header: 'Near-Miss' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Customer-Site HSE Induction &amp; Permit-to-Work Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-service safety log — work category &times; site-induction validity &times; PTW obtained
        &times; PPE compliance &times; method statement &times; hospital safety-officer signoff &times;
        area isolation &times; near-miss count &amp; CAPA closure. Founder-gated view: compliance
        verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across NABH,
        ISO 45001 &amp; Factories-Act surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No site visits logged yet."
          rowKey={(r, i) => String(r.compliance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital HSE scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Work-category &times; engineer matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No visits by category."
          rowKey={(r, i) => `${r.work_category}-${r.engineer_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily compliance trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.visit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk HSE queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk visits."
          rowKey={(r, i) => `${r.job_code}-${r.visit_date}-${i}`}
        />
      </section>
    </main>
  );
}
