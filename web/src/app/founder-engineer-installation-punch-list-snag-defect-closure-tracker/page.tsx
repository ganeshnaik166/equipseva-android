import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { snag_status: string; snags: number; pct: number };
type DisciplineRow = {
  discipline: string;
  total_snags: number;
  open_snags: number;
  critical: number;
  blocks_handover: number;
  closed: number;
  avg_aging_days: number;
  closure_pct: number;
};
type MatrixRow = {
  discipline: string;
  severity: string;
  snags: number;
  open_snags: number;
  closed: number;
  avg_aging_days: number;
};
type TrendRow = {
  snag_month: string;
  snags: number;
  closed: number;
  open_snags: number;
  critical: number;
  blocks_handover: number;
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
type HandoverRow = {
  handover_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  snag_ref: string;
  project_code: string;
  discipline: string;
  severity: string;
  snag_status: string;
  raised_date: string;
  aging_days: number | null;
  blocks_handover: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    disciplineRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    handoverRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3448_snag_status_rollup'),
    supabase.rpc('founder_r3448_discipline_scorecard'),
    supabase.rpc('founder_r3448_discipline_severity_matrix'),
    supabase.rpc('founder_r3448_monthly_snag_trend'),
    supabase.rpc('founder_r3448_capa_status_board'),
    supabase.rpc('founder_r3448_root_cause_pareto'),
    supabase.rpc('founder_r3448_handover_impact_digest'),
    supabase.rpc('founder_r3448_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const disciplineRows: DisciplineRow[] = (disciplineRes.data as DisciplineRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const handoverRows: HandoverRow[] = (handoverRes.data as HandoverRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'snag_status', header: 'Status' },
    { key: 'snags', header: 'Snags' },
    { key: 'pct', header: 'Share %' },
  ];

  const disciplineCols: Column<DisciplineRow>[] = [
    { key: 'discipline', header: 'Discipline' },
    { key: 'total_snags', header: 'Total Snags' },
    { key: 'open_snags', header: 'Open' },
    { key: 'critical', header: 'Critical' },
    { key: 'blocks_handover', header: 'Blocks Handover' },
    { key: 'closed', header: 'Closed' },
    { key: 'avg_aging_days', header: 'Avg Aging Days' },
    { key: 'closure_pct', header: 'Closure %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'discipline', header: 'Discipline' },
    { key: 'severity', header: 'Severity' },
    { key: 'snags', header: 'Snags' },
    { key: 'open_snags', header: 'Open' },
    { key: 'closed', header: 'Closed' },
    { key: 'avg_aging_days', header: 'Avg Aging Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'snag_month', header: 'Month' },
    { key: 'snags', header: 'Snags' },
    { key: 'closed', header: 'Closed' },
    { key: 'open_snags', header: 'Open' },
    { key: 'critical', header: 'Critical' },
    { key: 'blocks_handover', header: 'Blocks Handover' },
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

  const handoverCols: Column<HandoverRow>[] = [
    { key: 'handover_impact', header: 'Handover Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'snag_ref', header: 'Snag Ref' },
    { key: 'project_code', header: 'Project' },
    { key: 'discipline', header: 'Discipline' },
    { key: 'severity', header: 'Severity' },
    { key: 'snag_status', header: 'Status' },
    { key: 'raised_date', header: 'Raised' },
    { key: 'aging_days', header: 'Aging Days' },
    { key: 'blocks_handover', header: 'Blocks Handover' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Installation Punch-List / Snag Defect-Closure Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Post-installation punch-list &amp; snag defect-closure log across hospital projects &mdash;
        discipline (mechanical, electrical, civil, plumbing, network, calibration, documentation,
        cosmetic) &times; severity &times; snag status &times; aging days &times; handover-blocking
        flag &times; CAPA root-cause &amp; closure. Founder-gated view: snag-status distribution,
        discipline scorecards, discipline &times; severity matrix, monthly trend, root-cause pareto,
        and handover-impact digest across NABH commissioning handovers.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Snag status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No snags logged yet."
          rowKey={(r, i) => String(r.snag_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Discipline scorecard</h2>
        <DataTable
          rows={disciplineRows}
          columns={disciplineCols}
          emptyMessage="No discipline rollups."
          rowKey={(r, i) => String(r.discipline ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Discipline &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No snags by discipline."
          rowKey={(r, i) => `${r.discipline}-${r.severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly snag trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.snag_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Handover-impact digest</h2>
        <DataTable
          rows={handoverRows}
          columns={handoverCols}
          emptyMessage="No handover-impact rollups."
          rowKey={(r, i) => String(r.handover_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk snag queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk snags."
          rowKey={(r, i) => `${r.snag_ref}-${i}`}
        />
      </section>
    </main>
  );
}
