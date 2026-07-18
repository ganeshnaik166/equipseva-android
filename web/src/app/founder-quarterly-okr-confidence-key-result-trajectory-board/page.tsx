import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  verdict: string;
  key_results: number;
  avg_confidence: number;
  pct: number;
};
type EntityRow = {
  entity_name: string;
  key_results: number;
  ahead: number;
  on_track: number;
  at_risk: number;
  off_track: number;
  blockers: number;
  avg_confidence: number;
  avg_progress_pct: number;
};
type MatrixRow = {
  objective_code: string;
  quarter_label: string;
  key_results: number;
  avg_progress_pct: number;
  avg_confidence: number;
  off_track: number;
};
type TrendRow = {
  review_date: string;
  key_results: number;
  avg_confidence: number;
  avg_progress_pct: number;
  blockers: number;
  at_risk_or_off: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  escalated_or_overdue: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type QueueRow = {
  entity_name: string;
  quarter_label: string;
  key_result_code: string;
  key_result_desc: string;
  owner_name: string;
  trajectory: string;
  confidence_score: number;
  progress_pct: number;
  verdict: string;
  blocker_summary: string | null;
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
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3233_verdict_trajectory_rollup'),
    supabase.rpc('founder_r3233_entity_scorecard'),
    supabase.rpc('founder_r3233_objective_quarter_matrix'),
    supabase.rpc('founder_r3233_review_confidence_trend'),
    supabase.rpc('founder_r3233_capa_status_board'),
    supabase.rpc('founder_r3233_root_cause_pareto'),
    supabase.rpc('founder_r3233_regulatory_impact_digest'),
    supabase.rpc('founder_r3233_low_confidence_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'verdict', header: 'Verdict' },
    { key: 'key_results', header: 'Key Results' },
    { key: 'avg_confidence', header: 'Avg Confidence' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity / Account' },
    { key: 'key_results', header: 'KRs' },
    { key: 'ahead', header: 'Ahead' },
    { key: 'on_track', header: 'On Track' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'off_track', header: 'Off Track' },
    { key: 'blockers', header: 'Blockers' },
    { key: 'avg_confidence', header: 'Avg Confidence' },
    { key: 'avg_progress_pct', header: 'Avg Progress %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'objective_code', header: 'Objective' },
    { key: 'quarter_label', header: 'Quarter' },
    { key: 'key_results', header: 'KRs' },
    { key: 'avg_progress_pct', header: 'Avg Progress %' },
    { key: 'avg_confidence', header: 'Avg Confidence' },
    { key: 'off_track', header: 'Off Track' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'review_date', header: 'Review Date' },
    { key: 'key_results', header: 'KRs Reviewed' },
    { key: 'avg_confidence', header: 'Avg Confidence' },
    { key: 'avg_progress_pct', header: 'Avg Progress %' },
    { key: 'blockers', header: 'Blockers' },
    { key: 'at_risk_or_off', header: 'At Risk / Off Track' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'escalated_or_overdue', header: 'Escalated / Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Governance Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'quarter_label', header: 'Quarter' },
    { key: 'key_result_code', header: 'KR Code' },
    { key: 'key_result_desc', header: 'Key Result' },
    { key: 'owner_name', header: 'Owner' },
    { key: 'trajectory', header: 'Trajectory' },
    { key: 'confidence_score', header: 'Confidence' },
    { key: 'progress_pct', header: 'Progress %' },
    { key: 'verdict', header: 'Verdict' },
    { key: 'blocker_summary', header: 'Blocker' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Quarterly OKR Confidence &amp; Key-Result Trajectory Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Quarterly OKR board &times; objective &times; key result &times; owner &times;
        target vs current &times; progress % &times; confidence 1-10 &times; trajectory &amp;
        course-correct CAPA. Founder-gated view: verdict rollups, entity scorecards,
        objective-by-quarter matrix, root-cause pareto, and governance-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Verdict &amp; trajectory rollup</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No key results logged yet."
          rowKey={(r, i) => String(r.verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity / account scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Objective &times; quarter matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No objectives by quarter."
          rowKey={(r, i) => `${r.objective_code}-${r.quarter_label}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Review-date confidence trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.review_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Governance impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No governance-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Low-confidence key-result queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No low-confidence key results."
          rowKey={(r, i) => `${r.key_result_code}-${i}`}
        />
      </section>
    </main>
  );
}
