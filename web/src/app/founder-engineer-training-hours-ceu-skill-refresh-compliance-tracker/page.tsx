import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; records: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_records: number;
  compliant: number;
  expiring_soon: number;
  expired: number;
  ceu_shortfall: number;
  total_training_hours: number;
  avg_score_pct: number;
  compliance_pct: number;
};
type MatrixRow = {
  training_type: string;
  skill_area: string;
  records: number;
  total_hours: number;
  total_ceu_earned: number;
  ceu_gap: number;
};
type TrendRow = {
  completion_month: string;
  records: number;
  total_hours: number;
  total_ceu: number;
  compliant: number;
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
  training_type: string;
  skill_area: string;
  compliance_status: string;
  ceu_earned: number;
  required_ceu: number;
  certificate_expiry_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3180_compliance_status_rollup'),
    supabase.rpc('founder_r3180_hospital_scorecard'),
    supabase.rpc('founder_r3180_type_skill_matrix'),
    supabase.rpc('founder_r3180_monthly_completion_trend'),
    supabase.rpc('founder_r3180_capa_status_board'),
    supabase.rpc('founder_r3180_root_cause_pareto'),
    supabase.rpc('founder_r3180_regulatory_impact_digest'),
    supabase.rpc('founder_r3180_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'expiring_soon', header: 'Expiring Soon' },
    { key: 'expired', header: 'Expired' },
    { key: 'ceu_shortfall', header: 'CEU Shortfall' },
    { key: 'total_training_hours', header: 'Hours' },
    { key: 'avg_score_pct', header: 'Avg Score %' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'training_type', header: 'Training Type' },
    { key: 'skill_area', header: 'Skill Area' },
    { key: 'records', header: 'Records' },
    { key: 'total_hours', header: 'Hours' },
    { key: 'total_ceu_earned', header: 'CEU Earned' },
    { key: 'ceu_gap', header: 'CEU Gap' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'completion_month', header: 'Month' },
    { key: 'records', header: 'Completions' },
    { key: 'total_hours', header: 'Hours' },
    { key: 'total_ceu', header: 'CEU' },
    { key: 'compliant', header: 'Compliant' },
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
    { key: 'training_type', header: 'Training Type' },
    { key: 'skill_area', header: 'Skill Area' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'ceu_earned', header: 'CEU Earned' },
    { key: 'required_ceu', header: 'CEU Required' },
    { key: 'certificate_expiry_date', header: 'Cert Expiry' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Training-Hours, Certification-CEU &amp; Skill-Refresh Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Training compliance log &mdash; training type &times; skill area &times; hours &times;
        CEU earned/required &times; completion &amp; expiry dates &amp; CAPA closure. Founder-gated view:
        compliance rollups, hospital scorecards, type &times; skill matrix, root-cause pareto, and
        regulatory-impact digest across NABH, AERB &amp; ISO 13485 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No training records yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital training scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Training type &times; skill area matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by type."
          rowKey={(r, i) => `${r.training_type}-${r.skill_area}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly completion trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.completion_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk training queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk records."
          rowKey={(r, i) => `${r.engineer_name}-${r.training_type}-${i}`}
        />
      </section>
    </main>
  );
}
