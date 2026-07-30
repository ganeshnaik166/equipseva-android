import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { audit_status: string; audits: number; pct: number };
type AreaRow = {
  process_area: string;
  audits: number;
  findings_raised: number;
  major_nc: number;
  minor_nc: number;
  observations: number;
  avg_closure_pct: number;
  avg_closure_days: number;
};
type MatrixRow = {
  process_area: string;
  nc_severity: string;
  audits: number;
  findings_raised: number;
  avg_closure_pct: number;
};
type TrendRow = {
  period_month: string;
  audits: number;
  findings_raised: number;
  major_nc: number;
  minor_nc: number;
  observations: number;
  avg_closure_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
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
  regulatory_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  audit_ref: string;
  clause_ref: string;
  process_area: string;
  period_month: string;
  audit_date: string;
  nc_severity: string;
  audit_status: string;
  major_nc: number;
  minor_nc: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    areaRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3645_audit_status_rollup'),
    supabase.rpc('founder_r3645_process_area_scorecard'),
    supabase.rpc('founder_r3645_process_area_severity_matrix'),
    supabase.rpc('founder_r3645_monthly_finding_trend'),
    supabase.rpc('founder_r3645_capa_status_board'),
    supabase.rpc('founder_r3645_root_cause_pareto'),
    supabase.rpc('founder_r3645_nc_impact_digest'),
    supabase.rpc('founder_r3645_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const areaRows: AreaRow[] = (areaRes.data as AreaRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'audit_status', header: 'Audit Status' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const areaCols: Column<AreaRow>[] = [
    { key: 'process_area', header: 'Process Area' },
    { key: 'audits', header: 'Audits' },
    { key: 'findings_raised', header: 'Findings' },
    { key: 'major_nc', header: 'Major NC' },
    { key: 'minor_nc', header: 'Minor NC' },
    { key: 'observations', header: 'Observations' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
    { key: 'avg_closure_days', header: 'Avg Closure Days' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'process_area', header: 'Process Area' },
    { key: 'nc_severity', header: 'NC Severity' },
    { key: 'audits', header: 'Audits' },
    { key: 'findings_raised', header: 'Findings' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'audits', header: 'Audits' },
    { key: 'findings_raised', header: 'Findings' },
    { key: 'major_nc', header: 'Major NC' },
    { key: 'minor_nc', header: 'Minor NC' },
    { key: 'observations', header: 'Observations' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
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
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'audit_ref', header: 'Audit Ref' },
    { key: 'clause_ref', header: 'Clause' },
    { key: 'process_area', header: 'Process Area' },
    { key: 'period_month', header: 'Month' },
    { key: 'audit_date', header: 'Audit Date' },
    { key: 'nc_severity', header: 'Severity' },
    { key: 'audit_status', header: 'Status' },
    { key: 'major_nc', header: 'Major NC' },
    { key: 'minor_nc', header: 'Minor NC' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        ISO-13485 QMS Internal-Audit / Nonconformity Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Device-manufacturing QMS internal-audit log — clause reference &times; process area
        (document &amp; records control, purchasing &amp; supplier control, design &amp; development,
        production &amp; sterilization validation, calibration/metrology, complaint handling, risk
        management, CAPA, traceability) &times; audits done &times; findings raised &times; major
        &amp; minor NC &times; observations &times; closure % &times; avg closure days &times; NC
        severity &times; audit status &times; trend &amp; CAPA closure. Founder-gated view: audit
        status rollups, process-area scorecards, root-cause pareto, and NC regulatory-impact digest
        across ISO-13485 &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No internal audits logged yet."
          rowKey={(r, i) => String(r.audit_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Process-area scorecard</h2>
        <DataTable
          rows={areaRows}
          columns={areaCols}
          emptyMessage="No process-area rollups."
          rowKey={(r, i) => String(r.process_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Process area &times; NC severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No findings by process area."
          rowKey={(r, i) => `${r.process_area}-${r.nc_severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly finding trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. NC regulatory-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk audit queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.audit_ref}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
