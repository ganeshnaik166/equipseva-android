import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { file_status: string; files: number; pct: number };
type ClassRow = {
  device_class: string;
  total_files: number;
  files_current: number;
  minor_update: number;
  major_gap: number;
  outdated_files: number;
  change_controls_open: number;
  avg_completeness_pct: number;
};
type MatrixRow = {
  file_section: string;
  file_status: string;
  files: number;
  avg_completeness_pct: number;
  total_outdated: number;
};
type TrendRow = {
  period_month: string;
  files: number;
  avg_completeness_pct: number;
  major_gap: number;
  outdated_files: number;
  worsening: number;
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
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  device_name: string;
  file_ref: string;
  device_class: string;
  file_section: string;
  period_month: string;
  file_status: string;
  completeness_pct: number | null;
  change_controls_open: number | null;
  next_review_due: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    classRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3644_file_status_rollup'),
    supabase.rpc('founder_r3644_device_class_scorecard'),
    supabase.rpc('founder_r3644_section_status_matrix'),
    supabase.rpc('founder_r3644_monthly_completeness_trend'),
    supabase.rpc('founder_r3644_capa_status_board'),
    supabase.rpc('founder_r3644_root_cause_pareto'),
    supabase.rpc('founder_r3644_gap_impact_digest'),
    supabase.rpc('founder_r3644_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'file_status', header: 'File Status' },
    { key: 'files', header: 'Files' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'total_files', header: 'Files' },
    { key: 'files_current', header: 'Current' },
    { key: 'minor_update', header: 'Minor Update' },
    { key: 'major_gap', header: 'Major Gap' },
    { key: 'outdated_files', header: 'Outdated / Not Started' },
    { key: 'change_controls_open', header: 'CRs Open' },
    { key: 'avg_completeness_pct', header: 'Avg Completeness %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'file_section', header: 'File Section' },
    { key: 'file_status', header: 'File Status' },
    { key: 'files', header: 'Files' },
    { key: 'avg_completeness_pct', header: 'Avg Completeness %' },
    { key: 'total_outdated', header: 'Outdated Sections' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'files', header: 'Files' },
    { key: 'avg_completeness_pct', header: 'Avg Completeness %' },
    { key: 'major_gap', header: 'Major Gap' },
    { key: 'outdated_files', header: 'Outdated / Not Started' },
    { key: 'worsening', header: 'Worsening' },
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
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'file_ref', header: 'File Ref' },
    { key: 'device_class', header: 'Class' },
    { key: 'file_section', header: 'Section' },
    { key: 'period_month', header: 'Month' },
    { key: 'file_status', header: 'Status' },
    { key: 'completeness_pct', header: 'Completeness %' },
    { key: 'change_controls_open', header: 'CRs Open' },
    { key: 'next_review_due', header: 'Next Review Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Device Master File / Technical File Completeness Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Device Master File / Technical File (design dossier) section-completeness per device &mdash; device
        &amp; class &times; file section (design inputs, risk management, VV testing, sterilization, clinical,
        labeling, post-market) &times; sections total / complete / outdated &times; completeness %
        &times; review cadence &times; open change controls &times; version &times; file status &amp; trend
        &amp; CAPA closure. Founder-gated view: file-status distribution, device-class scorecards, root-cause
        pareto, and gap-impact digest across CDSCO, MDR 2017, ISO 13485 &amp; ISO 14971 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. File status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No technical files logged yet."
          rowKey={(r, i) => String(r.file_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-class completeness scorecard</h2>
        <DataTable
          rows={classRows}
          columns={classCols}
          emptyMessage="No device-class rollups."
          rowKey={(r, i) => String(r.device_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. File section &times; file status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No files by section."
          rowKey={(r, i) => `${r.file_section}-${r.file_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly completeness trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Gap regulatory-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk file queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk files."
          rowKey={(r, i) => `${r.file_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
