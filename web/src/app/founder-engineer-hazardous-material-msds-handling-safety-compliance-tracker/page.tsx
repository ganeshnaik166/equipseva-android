import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; records: number; pct: number };
type HazardRow = {
  hazard_class: string;
  total_records: number;
  compliant: number;
  minor_gap: number;
  major_gap: number;
  non_compliant: number;
  remediated: number;
  sds_missing: number;
  ppe_gap: number;
  storage_gap: number;
  compliant_pct: number;
};
type MatrixRow = {
  hazard_class: string;
  compliance_status: string;
  records: number;
  sds_missing: number;
  ppe_gap: number;
  storage_gap: number;
};
type TrendRow = {
  audit_month: string;
  records: number;
  compliant: number;
  non_compliant: number;
  sds_missing: number;
  ppe_gap: number;
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
type ImpactRow = {
  safety_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  location_name: string;
  material_name: string;
  un_number: string | null;
  hazard_class: string;
  compliance_status: string;
  sds_available: string | null;
  ppe_compliant: string | null;
  storage_compliant: string | null;
  last_audit: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hazardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3528_compliance_status_rollup'),
    supabase.rpc('founder_r3528_hazard_class_scorecard'),
    supabase.rpc('founder_r3528_hazard_compliance_matrix'),
    supabase.rpc('founder_r3528_monthly_compliance_trend'),
    supabase.rpc('founder_r3528_capa_status_board'),
    supabase.rpc('founder_r3528_root_cause_pareto'),
    supabase.rpc('founder_r3528_safety_impact_digest'),
    supabase.rpc('founder_r3528_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hazardRows: HazardRow[] = (hazardRes.data as HazardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const hazardCols: Column<HazardRow>[] = [
    { key: 'hazard_class', header: 'Hazard Class' },
    { key: 'total_records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'minor_gap', header: 'Minor Gap' },
    { key: 'major_gap', header: 'Major Gap' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'remediated', header: 'Remediated' },
    { key: 'sds_missing', header: 'SDS Missing' },
    { key: 'ppe_gap', header: 'PPE Gap' },
    { key: 'storage_gap', header: 'Storage Gap' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'hazard_class', header: 'Hazard Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'sds_missing', header: 'SDS Missing' },
    { key: 'ppe_gap', header: 'PPE Gap' },
    { key: 'storage_gap', header: 'Storage Gap' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'non_compliant', header: 'Non-Compliant / Major' },
    { key: 'sds_missing', header: 'SDS Missing' },
    { key: 'ppe_gap', header: 'PPE Gap' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'safety_impact', header: 'Safety Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'location_name', header: 'Location' },
    { key: 'material_name', header: 'Material' },
    { key: 'un_number', header: 'UN No.' },
    { key: 'hazard_class', header: 'Hazard Class' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'sds_available', header: 'SDS' },
    { key: 'ppe_compliant', header: 'PPE' },
    { key: 'storage_compliant', header: 'Storage' },
    { key: 'last_audit', header: 'Last Audit' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Hazardous-Material / MSDS Handling-Safety Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Hazardous-material (chemicals &amp; gases) SDS/MSDS handling-safety compliance log — hazard
        class (flammable, corrosive, toxic, compressed gas, oxidizer, cryogenic, biohazard) &times;
        location &times; SDS availability &times; PPE &times; storage segregation &times; labeling
        &times; spill-kit readiness &times; compliance verdict &amp; CAPA closure. Founder-gated view:
        compliance-status rollups, hazard-class scorecards, root-cause pareto, and safety-impact
        digest across PESO, Factories-Act &amp; worker-safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No compliance checks logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hazard-class scorecard</h2>
        <DataTable
          rows={hazardRows}
          columns={hazardCols}
          emptyMessage="No hazard-class rollups."
          rowKey={(r, i) => String(r.hazard_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Hazard class &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by hazard class."
          rowKey={(r, i) => `${r.hazard_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly compliance trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Safety-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No safety-impact rollups."
          rowKey={(r, i) => String(r.safety_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk compliance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk materials."
          rowKey={(r, i) => `${r.material_name}-${r.last_audit}-${i}`}
        />
      </section>
    </main>
  );
}
