import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { compliance_verdict: string; audits: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_audits: number;
  fully_compliant: number;
  minor_gap: number;
  major_violation: number;
  damage_incident: number;
  wrist_strap_gaps: number;
  mat_ground_gaps: number;
  latent_failures: number;
  compliant_pct: number;
};
type MatrixRow = {
  location: string;
  component_type: string;
  audits: number;
  fully_compliant: number;
  mishandling_incidents: number;
  latent_failures: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  fully_compliant: number;
  violations: number;
  mishandling_incidents: number;
  latent_failures: number;
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
  engineer_name: string;
  location: string;
  job_code: string;
  component_type: string;
  audit_date: string;
  compliance_verdict: string;
  mishandling_incident: string;
  wrist_strap: string;
  latent_failure: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3372_verdict_rollup'),
    supabase.rpc('founder_r3372_engineer_scorecard'),
    supabase.rpc('founder_r3372_location_component_matrix'),
    supabase.rpc('founder_r3372_daily_compliance_trend'),
    supabase.rpc('founder_r3372_capa_status_board'),
    supabase.rpc('founder_r3372_root_cause_pareto'),
    supabase.rpc('founder_r3372_regulatory_impact_digest'),
    supabase.rpc('founder_r3372_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'minor_gap', header: 'Minor Gap' },
    { key: 'major_violation', header: 'Major / Retrain' },
    { key: 'damage_incident', header: 'Damage' },
    { key: 'wrist_strap_gaps', header: 'Strap Gaps' },
    { key: 'mat_ground_gaps', header: 'Mat Gaps' },
    { key: 'latent_failures', header: 'Latent Failures' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'location', header: 'Location' },
    { key: 'component_type', header: 'Component' },
    { key: 'audits', header: 'Audits' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'mishandling_incidents', header: 'Mishandling' },
    { key: 'latent_failures', header: 'Latent Failures' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'violations', header: 'Violations' },
    { key: 'mishandling_incidents', header: 'Mishandling' },
    { key: 'latent_failures', header: 'Latent Failures' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'location', header: 'Location' },
    { key: 'job_code', header: 'Job' },
    { key: 'component_type', header: 'Component' },
    { key: 'audit_date', header: 'Date' },
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'mishandling_incident', header: 'Mishandling' },
    { key: 'wrist_strap', header: 'Wrist Strap' },
    { key: 'latent_failure', header: 'Latent Failure' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer ESD &amp; Static-Control Sensitive-Component Handling Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ESD compliance log &mdash; engineer &times; location &times; component type &times; wrist-strap
        &amp; grounded-mat use &times; ionizer &times; ESD-bag packaging &times; humidity control &times;
        grounding-continuity test &times; training currency &times; mishandling incident &amp; latent-failure
        reporting &amp; CAPA closure. Founder-gated view: compliance verdicts, engineer scorecards,
        root-cause pareto, and warranty/ISO-13485 regulatory-impact digest across workshop &amp; field.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No ESD audits logged yet."
          rowKey={(r, i) => String(r.compliance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer ESD scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Location &times; component matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by location."
          rowKey={(r, i) => `${r.location}-${r.component_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily compliance trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk ESD queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.job_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
