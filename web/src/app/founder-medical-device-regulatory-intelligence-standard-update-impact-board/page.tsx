import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { assessment_status: string; updates: number; pct: number };
type BodyRow = {
  source_body: string;
  total_updates: number;
  closed_cnt: number;
  in_action: number;
  deadline_risk_cnt: number;
  devices_affected_total: number;
  gap_items_total: number;
  avg_action_plan_pct: number;
  assessed_pct: number;
};
type MatrixRow = {
  impact_level: string;
  assessment_status: string;
  updates: number;
  devices_affected_total: number;
  avg_days_to_deadline: number;
};
type TrendRow = {
  period_month: string;
  updates: number;
  critical_major: number;
  closed_cnt: number;
  deadline_risk_cnt: number;
  avg_action_plan_pct: number;
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
type DeadlineRow = {
  deadline_band: string;
  updates: number;
  devices_affected_total: number;
  gap_items_total: number;
  avg_action_plan_pct: number;
};
type RiskRow = {
  update_ref: string;
  standard_name: string;
  source_body: string;
  impact_level: string;
  assessment_status: string;
  transition_deadline: string;
  days_to_deadline: number;
  devices_affected: number;
  gap_items: number;
  action_plan_pct: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    bodyRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    deadlineRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3654_assessment_status_rollup'),
    supabase.rpc('founder_r3654_source_body_scorecard'),
    supabase.rpc('founder_r3654_impact_status_matrix'),
    supabase.rpc('founder_r3654_monthly_update_trend'),
    supabase.rpc('founder_r3654_capa_status_board'),
    supabase.rpc('founder_r3654_root_cause_pareto'),
    supabase.rpc('founder_r3654_deadline_exposure_digest'),
    supabase.rpc('founder_r3654_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const bodyRows: BodyRow[] = (bodyRes.data as BodyRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const deadlineRows: DeadlineRow[] = (deadlineRes.data as DeadlineRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'assessment_status', header: 'Assessment Status' },
    { key: 'updates', header: 'Updates' },
    { key: 'pct', header: 'Share %' },
  ];

  const bodyCols: Column<BodyRow>[] = [
    { key: 'source_body', header: 'Source Body' },
    { key: 'total_updates', header: 'Updates' },
    { key: 'closed_cnt', header: 'Closed' },
    { key: 'in_action', header: 'In Action' },
    { key: 'deadline_risk_cnt', header: 'Deadline Risk' },
    { key: 'devices_affected_total', header: 'Devices Affected' },
    { key: 'gap_items_total', header: 'Gap Items' },
    { key: 'avg_action_plan_pct', header: 'Avg Plan %' },
    { key: 'assessed_pct', header: 'Assessed %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'impact_level', header: 'Impact Level' },
    { key: 'assessment_status', header: 'Assessment Status' },
    { key: 'updates', header: 'Updates' },
    { key: 'devices_affected_total', header: 'Devices Affected' },
    { key: 'avg_days_to_deadline', header: 'Avg Days to Deadline' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'updates', header: 'Updates' },
    { key: 'critical_major', header: 'Critical / Major' },
    { key: 'closed_cnt', header: 'Closed' },
    { key: 'deadline_risk_cnt', header: 'Deadline Risk' },
    { key: 'avg_action_plan_pct', header: 'Avg Plan %' },
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

  const deadlineCols: Column<DeadlineRow>[] = [
    { key: 'deadline_band', header: 'Deadline Band' },
    { key: 'updates', header: 'Updates' },
    { key: 'devices_affected_total', header: 'Devices Affected' },
    { key: 'gap_items_total', header: 'Gap Items' },
    { key: 'avg_action_plan_pct', header: 'Avg Plan %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'update_ref', header: 'Update Ref' },
    { key: 'standard_name', header: 'Standard' },
    { key: 'source_body', header: 'Body' },
    { key: 'impact_level', header: 'Impact' },
    { key: 'assessment_status', header: 'Status' },
    { key: 'transition_deadline', header: 'Deadline' },
    { key: 'days_to_deadline', header: 'Days Left' },
    { key: 'devices_affected', header: 'Devices' },
    { key: 'gap_items', header: 'Gaps' },
    { key: 'action_plan_pct', header: 'Plan %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Regulatory-Intelligence / Standard-Update Impact Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Regulatory-intelligence log — standard &amp; regulation updates (IEC, ISO, CDSCO, BIS, EU MDR
        amendments, AERB) &times; published date &times; transition deadline &times; devices affected
        &times; gap items &times; impact-assessment status &times; action-plan progress &amp; CAPA
        closure. Founder-gated view: assessment-status rollups, source-body scorecards, impact
        &times; status matrix, deadline-exposure digest, root-cause pareto, and the high-risk queue
        of updates with deadline risk or no assessment.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Assessment-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No regulatory updates logged yet."
          rowKey={(r, i) => String(r.assessment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Source-body scorecard</h2>
        <DataTable
          rows={bodyRows}
          columns={bodyCols}
          emptyMessage="No source-body rollups."
          rowKey={(r, i) => String(r.source_body ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Impact level &times; assessment status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No updates by impact level."
          rowKey={(r, i) => `${r.impact_level}-${r.assessment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly update trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Deadline-exposure digest</h2>
        <DataTable
          rows={deadlineRows}
          columns={deadlineCols}
          emptyMessage="No deadline-exposure rollups."
          rowKey={(r, i) => String(r.deadline_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk update queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk updates."
          rowKey={(r, i) => `${r.update_ref}-${i}`}
        />
      </section>
    </main>
  );
}
