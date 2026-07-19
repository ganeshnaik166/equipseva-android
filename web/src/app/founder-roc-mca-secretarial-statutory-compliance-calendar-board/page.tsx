import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  compliance_verdict: string;
  obligations: number;
  total_late_fee_rupees: number;
  pct: number;
};
type EntityRow = {
  entity_name: string;
  total_obligations: number;
  filed: number;
  overdue: number;
  due_soon: number;
  dependency_pending: number;
  board_approval_pending: number;
  total_late_fee_rupees: number;
  on_track_pct: number;
};
type MatrixRow = {
  category: string;
  responsible: string;
  obligations: number;
  overdue: number;
  avg_days_to_due: number;
  total_late_fee_rupees: number;
};
type TrendRow = {
  due_date: string;
  obligations: number;
  overdue: number;
  due_soon: number;
  board_approval_needed: number;
  total_late_fee_rupees: number;
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
  entity_name: string;
  obligation: string;
  category: string;
  due_date: string;
  days_to_due: number;
  responsible: string;
  preparation_status: string;
  late_fee_exposure_rupees: number | null;
  compliance_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3369_compliance_verdict_rollup'),
    supabase.rpc('founder_r3369_entity_scorecard'),
    supabase.rpc('founder_r3369_category_responsible_matrix'),
    supabase.rpc('founder_r3369_due_date_trend'),
    supabase.rpc('founder_r3369_capa_status_board'),
    supabase.rpc('founder_r3369_root_cause_pareto'),
    supabase.rpc('founder_r3369_regulatory_impact_digest'),
    supabase.rpc('founder_r3369_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'obligations', header: 'Obligations' },
    { key: 'total_late_fee_rupees', header: 'Late-Fee Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'total_obligations', header: 'Obligations' },
    { key: 'filed', header: 'Filed' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'due_soon', header: 'Due Soon' },
    { key: 'dependency_pending', header: 'Dependency Pending' },
    { key: 'board_approval_pending', header: 'Board Approval Pending' },
    { key: 'total_late_fee_rupees', header: 'Late-Fee Exposure (INR)' },
    { key: 'on_track_pct', header: 'On-Track %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'responsible', header: 'Responsible' },
    { key: 'obligations', header: 'Obligations' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'avg_days_to_due', header: 'Avg Days to Due' },
    { key: 'total_late_fee_rupees', header: 'Late-Fee Exposure (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'due_date', header: 'Due Date' },
    { key: 'obligations', header: 'Obligations' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'due_soon', header: 'Due Soon' },
    { key: 'board_approval_needed', header: 'Board Approval Needed' },
    { key: 'total_late_fee_rupees', header: 'Late-Fee Exposure (INR)' },
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
    { key: 'entity_name', header: 'Entity' },
    { key: 'obligation', header: 'Obligation' },
    { key: 'category', header: 'Category' },
    { key: 'due_date', header: 'Due Date' },
    { key: 'days_to_due', header: 'Days to Due' },
    { key: 'responsible', header: 'Responsible' },
    { key: 'preparation_status', header: 'Prep Status' },
    { key: 'late_fee_exposure_rupees', header: 'Late-Fee (INR)' },
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder ROC/MCA Secretarial &amp; Statutory-Compliance Calendar Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Companies Act compliance calendar — obligation &times; category &times; due-date &amp;
        days-to-due &times; filing frequency &times; responsible officer &times; preparation status
        &times; late-fee exposure &times; board-approval &amp; CAPA closure. Founder-gated view:
        compliance verdicts, per-entity scorecards, root-cause pareto, and regulatory-impact digest
        across ROC filings (MGT-7, AOC-4, DPT-3, MSME-1), board/AGM governance, DIR-3 KYC, BEN-2 SBO
        &amp; statutory registers.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No compliance obligations logged yet."
          rowKey={(r, i) => String(r.compliance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity compliance scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; responsible matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No obligations by category."
          rowKey={(r, i) => `${r.category}-${r.responsible}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Due-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.due_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk compliance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk obligations."
          rowKey={(r, i) => `${r.entity_name}-${r.obligation}-${r.due_date}-${i}`}
        />
      </section>
    </main>
  );
}
