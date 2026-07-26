import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StageStatusRow = { stage_status: string; units: number; pct: number };
type StageRow = {
  refurb_stage: string;
  total_units: number;
  passed: number;
  failed: number;
  rework: number;
  electrical_fail: number;
  functional_fail: number;
  avg_cost_rupees: number;
};
type MatrixRow = {
  refurb_stage: string;
  recert_grade: string;
  units: number;
  passed: number;
  failed: number;
  avg_cost_rupees: number;
};
type TrendRow = {
  intake_month: string;
  intake_units: number;
  certified_units: number;
  rejected_units: number;
  avg_cost_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type CostRow = {
  device_category: string;
  units: number;
  rejected_units: number;
  total_cost_rupees: number;
  avg_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  asset_tag: string;
  device_model: string;
  device_category: string;
  refurb_stage: string;
  stage_status: string;
  recert_grade: string;
  electrical_safety_ok: string | null;
  functional_test_ok: string | null;
  intake_date: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    stageRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    costRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3468_stage_status_rollup'),
    supabase.rpc('founder_r3468_refurb_stage_scorecard'),
    supabase.rpc('founder_r3468_stage_grade_matrix'),
    supabase.rpc('founder_r3468_monthly_throughput_trend'),
    supabase.rpc('founder_r3468_capa_status_board'),
    supabase.rpc('founder_r3468_root_cause_pareto'),
    supabase.rpc('founder_r3468_refurb_cost_impact_digest'),
    supabase.rpc('founder_r3468_high_risk_queue'),
  ]);

  const statusRows: StageStatusRow[] = (statusRes.data as StageStatusRow[]) ?? [];
  const stageRows: StageRow[] = (stageRes.data as StageRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const costRows: CostRow[] = (costRes.data as CostRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StageStatusRow>[] = [
    { key: 'stage_status', header: 'Stage Status' },
    { key: 'units', header: 'Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const stageCols: Column<StageRow>[] = [
    { key: 'refurb_stage', header: 'Refurb Stage' },
    { key: 'total_units', header: 'Units' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'rework', header: 'Rework' },
    { key: 'electrical_fail', header: 'Elec Fail' },
    { key: 'functional_fail', header: 'Func Fail' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'refurb_stage', header: 'Refurb Stage' },
    { key: 'recert_grade', header: 'Recert Grade' },
    { key: 'units', header: 'Units' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed / Rework' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'intake_month', header: 'Intake Month' },
    { key: 'intake_units', header: 'Intake Units' },
    { key: 'certified_units', header: 'Certified' },
    { key: 'rejected_units', header: 'Rejected' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const costCols: Column<CostRow>[] = [
    { key: 'device_category', header: 'Device Category' },
    { key: 'units', header: 'Units' },
    { key: 'rejected_units', header: 'Rejected' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'device_model', header: 'Model' },
    { key: 'device_category', header: 'Category' },
    { key: 'refurb_stage', header: 'Stage' },
    { key: 'stage_status', header: 'Status' },
    { key: 'recert_grade', header: 'Grade' },
    { key: 'electrical_safety_ok', header: 'Elec Safe' },
    { key: 'functional_test_ok', header: 'Func OK' },
    { key: 'intake_date', header: 'Intake' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Refurbishment / Recertification (Used-Equipment) QC Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Used &amp; pre-owned biomedical equipment refurbishment and recertification QC log &mdash;
        device category &times; refurb stage (intake, teardown, parts replacement, calibration,
        safety test, cosmetic, final QC, certified) &times; stage status &times; electrical-safety
        &amp; functional-test outcomes &times; recert grade (A/B/C/rejected) &times; intake &amp;
        certified dates &times; refurb cost &amp; CAPA closure. Founder-gated view: stage-status
        distribution, refurb-stage scorecards, stage &times; grade matrix, monthly throughput,
        root-cause pareto, and refurb-cost impact across the used-equipment pipeline.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Stage-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No refurb QC records yet."
          rowKey={(r, i) => String(r.stage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Refurb-stage scorecard</h2>
        <DataTable
          rows={stageRows}
          columns={stageCols}
          emptyMessage="No stage rollups."
          rowKey={(r, i) => String(r.refurb_stage ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Refurb stage &times; recert grade matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No stage-grade breakdown."
          rowKey={(r, i) => `${r.refurb_stage}-${r.recert_grade}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly throughput trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No throughput data."
          rowKey={(r, i) => String(r.intake_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Refurb-cost impact digest</h2>
        <DataTable
          rows={costRows}
          columns={costCols}
          emptyMessage="No cost-impact rollups."
          rowKey={(r, i) => String(r.device_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk refurb queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk assets."
          rowKey={(r, i) => `${r.asset_tag}-${r.intake_date}-${i}`}
        />
      </section>
    </main>
  );
}
