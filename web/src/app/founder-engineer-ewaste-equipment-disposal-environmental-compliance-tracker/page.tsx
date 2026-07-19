import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { compliance_verdict: string; cases: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_cases: number;
  compliant: number;
  doc_pending: number;
  noncompliant: number;
  data_sanitization_missing: number;
  unauthorized_recycler: number;
  epr_incomplete: number;
  compliant_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  hazardous_components: string;
  cases: number;
  compliant: number;
  total_weight_kg: number;
  avg_weight_kg: number;
};
type TrendRow = {
  decommission_date: string;
  cases: number;
  compliant: number;
  noncompliant: number;
  total_weight_kg: number;
  pickup_pending: number;
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
  disposal_code: string;
  engineer_name: string;
  decommission_date: string;
  compliance_verdict: string;
  equipment_type: string;
  hazardous_components: string;
  data_sanitization_done: boolean | null;
  authorized_recycler_used: boolean | null;
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
    supabase.rpc('founder_r3348_compliance_verdict_rollup'),
    supabase.rpc('founder_r3348_hospital_scorecard'),
    supabase.rpc('founder_r3348_equipment_hazard_matrix'),
    supabase.rpc('founder_r3348_daily_disposal_trend'),
    supabase.rpc('founder_r3348_capa_status_board'),
    supabase.rpc('founder_r3348_root_cause_pareto'),
    supabase.rpc('founder_r3348_regulatory_impact_digest'),
    supabase.rpc('founder_r3348_high_risk_queue'),
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
    { key: 'cases', header: 'Cases' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_cases', header: 'Cases' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'doc_pending', header: 'Doc Pending' },
    { key: 'noncompliant', header: 'Non-Compliant' },
    { key: 'data_sanitization_missing', header: 'Data-Wipe Missing' },
    { key: 'unauthorized_recycler', header: 'Unauth. Recycler' },
    { key: 'epr_incomplete', header: 'EPR Incomplete' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'hazardous_components', header: 'Hazardous Component' },
    { key: 'cases', header: 'Cases' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'total_weight_kg', header: 'Total Weight kg' },
    { key: 'avg_weight_kg', header: 'Avg Weight kg' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'decommission_date', header: 'Date' },
    { key: 'cases', header: 'Cases' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'noncompliant', header: 'Non-Compliant' },
    { key: 'total_weight_kg', header: 'Total Weight kg' },
    { key: 'pickup_pending', header: 'Pickup Pending' },
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
    { key: 'disposal_code', header: 'Disposal Code' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'decommission_date', header: 'Date' },
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'hazardous_components', header: 'Hazardous' },
    { key: 'data_sanitization_done', header: 'Data Wiped' },
    { key: 'authorized_recycler_used', header: 'Auth. Recycler' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer E-Waste &amp; End-of-Life Equipment Disposal Environmental-Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        E-Waste Management Rules disposal log — equipment type &times; hazardous components &times;
        data sanitization &times; authorized recycler &times; EPR documentation &times; manifest
        generation &times; disposal route &amp; CAPA closure. Founder-gated view: compliance
        verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across
        CPCB &amp; SPCB surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No disposal cases logged yet."
          rowKey={(r, i) => String(r.compliance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; hazardous-component matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cases by equipment type."
          rowKey={(r, i) => `${r.equipment_type}-${r.hazardous_components}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily disposal trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.decommission_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk disposal queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk disposal cases."
          rowKey={(r, i) => `${r.disposal_code}-${r.decommission_date}-${i}`}
        />
      </section>
    </main>
  );
}
