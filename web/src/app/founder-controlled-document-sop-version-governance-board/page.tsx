import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { control_status: string; documents: number; pct: number };
type ScoreRow = {
  owner_department: string;
  total_documents: number;
  current_docs: number;
  review_due_soon: number;
  review_overdue: number;
  obsolete_in_circulation: number;
  under_revision: number;
  avg_training_pct: number;
};
type MatrixRow = {
  doc_class: string;
  control_status: string;
  documents: number;
  avg_days_overdue: number;
  obsolete_copies: number;
};
type TrendRow = {
  period_month: string;
  documents: number;
  review_due_soon: number;
  review_overdue: number;
  avg_days_overdue: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  doc_class: string;
  docs_with_obsolete_copies: number;
  total_obsolete_copies: number;
  avg_training_pct: number;
};
type RiskRow = {
  document_ref: string;
  owner_department: string;
  doc_class: string;
  current_version: string;
  next_review_due: string | null;
  days_overdue: number | null;
  obsolete_copies_found: number | null;
  control_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3719_control_status_rollup'),
    supabase.rpc('founder_r3719_department_scorecard'),
    supabase.rpc('founder_r3719_doc_class_status_matrix'),
    supabase.rpc('founder_r3719_monthly_review_due_trend'),
    supabase.rpc('founder_r3719_capa_status_board'),
    supabase.rpc('founder_r3719_root_cause_pareto'),
    supabase.rpc('founder_r3719_obsolete_copy_digest'),
    supabase.rpc('founder_r3719_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'control_status', header: 'Control Status' },
    { key: 'documents', header: 'Documents' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'owner_department', header: 'Department' },
    { key: 'total_documents', header: 'Documents' },
    { key: 'current_docs', header: 'Current' },
    { key: 'review_due_soon', header: 'Review Due Soon' },
    { key: 'review_overdue', header: 'Review Overdue' },
    { key: 'obsolete_in_circulation', header: 'Obsolete in Circulation' },
    { key: 'under_revision', header: 'Under Revision' },
    { key: 'avg_training_pct', header: 'Avg Training %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'doc_class', header: 'Doc Class' },
    { key: 'control_status', header: 'Control Status' },
    { key: 'documents', header: 'Documents' },
    { key: 'avg_days_overdue', header: 'Avg Days Overdue' },
    { key: 'obsolete_copies', header: 'Obsolete Copies' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'documents', header: 'Documents' },
    { key: 'review_due_soon', header: 'Review Due Soon' },
    { key: 'review_overdue', header: 'Review Overdue' },
    { key: 'avg_days_overdue', header: 'Avg Days Overdue' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'doc_class', header: 'Doc Class' },
    { key: 'docs_with_obsolete_copies', header: 'Docs w/ Obsolete Copies' },
    { key: 'total_obsolete_copies', header: 'Total Obsolete Copies' },
    { key: 'avg_training_pct', header: 'Avg Training %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'document_ref', header: 'Document Ref' },
    { key: 'owner_department', header: 'Department' },
    { key: 'doc_class', header: 'Class' },
    { key: 'current_version', header: 'Version' },
    { key: 'next_review_due', header: 'Next Review Due' },
    { key: 'days_overdue', header: 'Days Overdue' },
    { key: 'obsolete_copies_found', header: 'Obsolete Copies' },
    { key: 'control_status', header: 'Status' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Controlled-Document / SOP Version-Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Controlled documents &mdash; SOPs, work instructions, form templates, policies &amp;
        adopted external standards &mdash; tracked by version currency, review-due dates,
        obsolete-copy control in the field, and staff training-on-revision closure. Distinct
        from any QMS management-review meeting board: this tracks individual document
        version-control state, not committee meetings or actions. Founder-gated view:
        control-status rollups, department scorecards, root-cause pareto, and the obsolete-copy
        &amp; high-risk queue across active controlled documents.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Control status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No controlled documents logged yet."
          rowKey={(r, i) => String(r.control_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.owner_department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Doc class &times; control status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No documents by class."
          rowKey={(r, i) => `${r.doc_class}-${r.control_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly review-due trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Obsolete-copy digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No obsolete copies reported."
          rowKey={(r, i) => String(r.doc_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk documents."
          rowKey={(r, i) => `${r.document_ref}-${i}`}
        />
      </section>
    </main>
  );
}
