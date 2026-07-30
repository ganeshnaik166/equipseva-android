import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { cer_status: string; cers: number; pct: number };
type ClassRow = {
  device_class: string;
  total_cers: number;
  sufficient: number;
  update_due: number;
  evidence_gap: number;
  insufficient: number;
  equivalence_cers: number;
  avg_evidence_sufficiency_pct: number;
};
type MatrixRow = {
  evidence_route: string;
  cer_status: string;
  cers: number;
  avg_evidence_sufficiency_pct: number;
  total_residual_risks: number;
};
type TrendRow = {
  period_month: string;
  cers: number;
  sufficient: number;
  gap_or_insufficient: number;
  avg_evidence_sufficiency_pct: number;
  total_residual_risks: number;
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
type GapRow = {
  evidence_route: string;
  cers: number;
  gap_or_insufficient: number;
  avg_evidence_sufficiency_pct: number;
  total_residual_risks_open: number;
};
type RiskRow = {
  device_name: string;
  cer_ref: string;
  device_class: string;
  period_month: string;
  cer_status: string;
  evidence_route: string;
  evidence_sufficiency_pct: number | null;
  residual_risks_open: number | null;
  cer_update_due: string | null;
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
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3648_cer_status_rollup'),
    supabase.rpc('founder_r3648_device_class_scorecard'),
    supabase.rpc('founder_r3648_route_status_matrix'),
    supabase.rpc('founder_r3648_monthly_cer_trend'),
    supabase.rpc('founder_r3648_capa_status_board'),
    supabase.rpc('founder_r3648_root_cause_pareto'),
    supabase.rpc('founder_r3648_evidence_gap_digest'),
    supabase.rpc('founder_r3648_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cer_status', header: 'CER Status' },
    { key: 'cers', header: 'CERs' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'total_cers', header: 'CERs' },
    { key: 'sufficient', header: 'Sufficient' },
    { key: 'update_due', header: 'Update Due' },
    { key: 'evidence_gap', header: 'Evidence Gap' },
    { key: 'insufficient', header: 'Insufficient' },
    { key: 'equivalence_cers', header: 'Equivalence' },
    { key: 'avg_evidence_sufficiency_pct', header: 'Avg Suffic. %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'evidence_route', header: 'Evidence Route' },
    { key: 'cer_status', header: 'CER Status' },
    { key: 'cers', header: 'CERs' },
    { key: 'avg_evidence_sufficiency_pct', header: 'Avg Suffic. %' },
    { key: 'total_residual_risks', header: 'Residual Risks' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'cers', header: 'CERs' },
    { key: 'sufficient', header: 'Sufficient' },
    { key: 'gap_or_insufficient', header: 'Gap / Insufficient' },
    { key: 'avg_evidence_sufficiency_pct', header: 'Avg Suffic. %' },
    { key: 'total_residual_risks', header: 'Residual Risks' },
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

  const gapCols: Column<GapRow>[] = [
    { key: 'evidence_route', header: 'Evidence Route' },
    { key: 'cers', header: 'CERs' },
    { key: 'gap_or_insufficient', header: 'Gap / Insufficient' },
    { key: 'avg_evidence_sufficiency_pct', header: 'Avg Suffic. %' },
    { key: 'total_residual_risks_open', header: 'Residual Risks Open' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'cer_ref', header: 'CER Ref' },
    { key: 'device_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'cer_status', header: 'Status' },
    { key: 'evidence_route', header: 'Route' },
    { key: 'evidence_sufficiency_pct', header: 'Suffic. %' },
    { key: 'residual_risks_open', header: 'Residual Risks' },
    { key: 'cer_update_due', header: 'Update Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Clinical-Evaluation-Report (CER) Evidence Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Clinical-Evaluation-Report clinical-evidence sufficiency tracker &mdash; device class
        &times; evidence route (own clinical, literature, equivalence, PMCF, clinical
        investigation) &times; clinical data sources &times; literature refs &times; PMCF studies
        &times; evidence-sufficiency % &times; residual risks open &times; equivalence claim
        &times; CER update-due &amp; CAPA closure. Founder-gated view: CER-status distribution,
        device-class scorecards, root-cause pareto, and evidence-gap digest across CDSCO &amp;
        notified-body surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. CER status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No CER records logged yet."
          rowKey={(r, i) => String(r.cer_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-class scorecard</h2>
        <DataTable
          rows={classRows}
          columns={classCols}
          emptyMessage="No device-class rollups."
          rowKey={(r, i) => String(r.device_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Evidence route &times; CER status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No CERs by evidence route."
          rowKey={(r, i) => `${r.evidence_route}-${r.cer_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly CER trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Evidence-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No evidence-gap rollups."
          rowKey={(r, i) => String(r.evidence_route ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk CER queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk CERs."
          rowKey={(r, i) => `${r.cer_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
