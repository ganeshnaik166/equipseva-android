import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { currency_status: string; documents: number; pct: number };
type TypeRow = {
  document_type: string;
  total_docs: number;
  current_docs: number;
  minor_behind: number;
  major_behind: number;
  obsolete_docs: number;
  missing_docs: number;
  controlled_copies: number;
  current_pct: number;
};
type MatrixRow = {
  document_type: string;
  currency_status: string;
  documents: number;
  avg_versions_behind: number;
  avg_distribution_pct: number;
};
type TrendRow = {
  month: string;
  documents: number;
  current_docs: number;
  obsolete_missing: number;
  avg_versions_behind: number;
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
  engineer_name: string;
  device_model: string;
  document_ref: string;
  document_type: string;
  currency_status: string;
  current_version: string | null;
  latest_version: string | null;
  versions_behind: number;
  last_updated: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    typeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3504_currency_status_rollup'),
    supabase.rpc('founder_r3504_document_type_scorecard'),
    supabase.rpc('founder_r3504_doc_type_currency_matrix'),
    supabase.rpc('founder_r3504_monthly_currency_trend'),
    supabase.rpc('founder_r3504_capa_status_board'),
    supabase.rpc('founder_r3504_root_cause_pareto'),
    supabase.rpc('founder_r3504_obsolescence_impact_digest'),
    supabase.rpc('founder_r3504_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'currency_status', header: 'Currency Status' },
    { key: 'documents', header: 'Documents' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'document_type', header: 'Document Type' },
    { key: 'total_docs', header: 'Total' },
    { key: 'current_docs', header: 'Current' },
    { key: 'minor_behind', header: 'Minor Behind' },
    { key: 'major_behind', header: 'Major Behind' },
    { key: 'obsolete_docs', header: 'Obsolete' },
    { key: 'missing_docs', header: 'Missing' },
    { key: 'controlled_copies', header: 'Controlled' },
    { key: 'current_pct', header: 'Current %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'document_type', header: 'Document Type' },
    { key: 'currency_status', header: 'Currency Status' },
    { key: 'documents', header: 'Documents' },
    { key: 'avg_versions_behind', header: 'Avg Versions Behind' },
    { key: 'avg_distribution_pct', header: 'Avg Distribution %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'documents', header: 'Documents' },
    { key: 'current_docs', header: 'Current' },
    { key: 'obsolete_missing', header: 'Obsolete / Missing' },
    { key: 'avg_versions_behind', header: 'Avg Versions Behind' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'document_ref', header: 'Document' },
    { key: 'document_type', header: 'Type' },
    { key: 'currency_status', header: 'Currency' },
    { key: 'current_version', header: 'Current Ver' },
    { key: 'latest_version', header: 'Latest Ver' },
    { key: 'versions_behind', header: 'Behind' },
    { key: 'last_updated', header: 'Last Updated' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Technical-Documentation / Manual-Firmware Version-Control Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer technical-documentation currency log — document type (service &amp; user
        manuals, wiring diagrams, firmware, SOPs, safety notices) &times; device model &times; current
        vs latest version &times; versions-behind &times; currency status &times; controlled-copy
        &times; distribution coverage &amp; obsolescence CAPA closure. Founder-gated view: currency
        distribution, document-type scorecards, root-cause pareto, and obsolescence-impact digest
        across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Currency status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No documents tracked yet."
          rowKey={(r, i) => String(r.currency_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Document type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No document-type rollups."
          rowKey={(r, i) => String(r.document_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Document type &times; currency status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No documents by type."
          rowKey={(r, i) => `${r.document_type}-${r.currency_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly currency trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Obsolescence impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk documentation queue</h2>
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
