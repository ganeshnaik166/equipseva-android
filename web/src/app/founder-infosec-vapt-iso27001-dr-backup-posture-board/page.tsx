import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  posture_verdict: string;
  controls: number;
  total_open_findings: number;
  pct: number;
};
type SystemRow = {
  system_or_control: string;
  total_controls: number;
  strong: number;
  adequate: number;
  at_risk: number;
  total_open_findings: number;
  total_critical_findings: number;
  mfa_enforced_controls: number;
  sla_met_pct: number;
};
type MatrixRow = {
  domain: string;
  assessment_type: string;
  assessments: number;
  open_findings: number;
  critical_findings: number;
  avg_rto_hours: number;
  avg_rpo_hours: number;
};
type TrendRow = {
  last_assessment_date: string;
  assessments: number;
  open_findings: number;
  critical_findings: number;
  sla_met: number;
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
  system_or_control: string;
  domain: string;
  last_assessment_date: string;
  assessment_type: string;
  open_findings: number;
  critical_findings: number;
  sla_status: string;
  mfa_status: string;
  control_maturity: string;
  posture_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    systemRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3305_posture_verdict_rollup'),
    supabase.rpc('founder_r3305_system_scorecard'),
    supabase.rpc('founder_r3305_domain_assessment_matrix'),
    supabase.rpc('founder_r3305_assessment_date_trend'),
    supabase.rpc('founder_r3305_capa_status_board'),
    supabase.rpc('founder_r3305_root_cause_pareto'),
    supabase.rpc('founder_r3305_regulatory_impact_digest'),
    supabase.rpc('founder_r3305_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const systemRows: SystemRow[] = (systemRes.data as SystemRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'posture_verdict', header: 'Posture Verdict' },
    { key: 'controls', header: 'Controls' },
    { key: 'total_open_findings', header: 'Open Findings' },
    { key: 'pct', header: 'Share %' },
  ];

  const systemCols: Column<SystemRow>[] = [
    { key: 'system_or_control', header: 'System / Control' },
    { key: 'total_controls', header: 'Controls' },
    { key: 'strong', header: 'Strong' },
    { key: 'adequate', header: 'Adequate' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'total_open_findings', header: 'Open Findings' },
    { key: 'total_critical_findings', header: 'Critical Findings' },
    { key: 'mfa_enforced_controls', header: 'MFA Enforced' },
    { key: 'sla_met_pct', header: 'SLA Met %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'domain', header: 'Domain' },
    { key: 'assessment_type', header: 'Assessment Type' },
    { key: 'assessments', header: 'Assessments' },
    { key: 'open_findings', header: 'Open Findings' },
    { key: 'critical_findings', header: 'Critical Findings' },
    { key: 'avg_rto_hours', header: 'Avg RTO (h)' },
    { key: 'avg_rpo_hours', header: 'Avg RPO (h)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'last_assessment_date', header: 'Assessment Date' },
    { key: 'assessments', header: 'Assessments' },
    { key: 'open_findings', header: 'Open Findings' },
    { key: 'critical_findings', header: 'Critical Findings' },
    { key: 'sla_met', header: 'SLA Met' },
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
    { key: 'system_or_control', header: 'System / Control' },
    { key: 'domain', header: 'Domain' },
    { key: 'last_assessment_date', header: 'Date' },
    { key: 'assessment_type', header: 'Assessment' },
    { key: 'open_findings', header: 'Open' },
    { key: 'critical_findings', header: 'Critical' },
    { key: 'sla_status', header: 'SLA' },
    { key: 'mfa_status', header: 'MFA' },
    { key: 'control_maturity', header: 'Maturity' },
    { key: 'posture_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder InfoSec, VAPT, ISO 27001 &amp; DR/Backup Posture Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Security posture log — system/control &times; domain &times; assessment type (VAPT,
        ISO 27001 audit, DR drill, backup-restore test) &times; open &amp; critical findings
        &times; remediation SLA &times; RTO/RPO hours &times; backup-restore verification &times;
        MFA enforcement &times; control maturity &amp; CAPA closure. Founder-gated view: posture
        verdicts, system scorecards, root-cause pareto, and regulatory-impact digest across
        DPDP, CERT-In, PCI-DSS &amp; ISO 27001 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Posture verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No posture assessments logged yet."
          rowKey={(r, i) => String(r.posture_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. System / control scorecard</h2>
        <DataTable
          rows={systemRows}
          columns={systemCols}
          emptyMessage="No system rollups."
          rowKey={(r, i) => String(r.system_or_control ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Domain &times; assessment-type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No assessments by domain."
          rowKey={(r, i) => `${r.domain}-${r.assessment_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Assessment-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.last_assessment_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk posture queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk posture rows."
          rowKey={(r, i) => `${r.system_or_control}-${r.domain}-${i}`}
        />
      </section>
    </main>
  );
}
