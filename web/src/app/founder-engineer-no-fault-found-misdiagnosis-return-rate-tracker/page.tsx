import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { nff_verdict: string; cases: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_cases: number;
  correct_calls: number;
  nff_wasteful: number;
  misdiagnosis: number;
  parts_replaced: number;
  parts_not_faulty: number;
  repeat_dispatches: number;
  wasted_cost_rupees: number;
  accuracy_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  workshop_finding: string;
  cases: number;
  nff_cases: number;
  avg_wasted_part_cost_rupees: number;
  avg_freight_cost_rupees: number;
};
type TrendRow = {
  case_date: string;
  cases: number;
  nff_cases: number;
  misdiagnosis_cases: number;
  repeat_dispatches: number;
  wasted_cost_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_recoverable_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  wasted_cost_rupees: number;
  pct: number;
};
type RegionRow = {
  region: string;
  cases: number;
  nff_cases: number;
  wasted_part_cost_rupees: number;
  freight_cost_rupees: number;
  total_waste_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  job_code: string;
  equipment_type: string;
  workshop_finding: string;
  part_replaced: boolean | null;
  part_actually_faulty: boolean | null;
  nff_verdict: string;
  wasted_part_cost_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regionRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3296_nff_verdict_rollup'),
    supabase.rpc('founder_r3296_engineer_scorecard'),
    supabase.rpc('founder_r3296_equipment_finding_matrix'),
    supabase.rpc('founder_r3296_daily_case_trend'),
    supabase.rpc('founder_r3296_capa_status_board'),
    supabase.rpc('founder_r3296_root_cause_pareto'),
    supabase.rpc('founder_r3296_region_waste_digest'),
    supabase.rpc('founder_r3296_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'nff_verdict', header: 'NFF Verdict' },
    { key: 'cases', header: 'Cases' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_cases', header: 'Cases' },
    { key: 'correct_calls', header: 'Correct Calls' },
    { key: 'nff_wasteful', header: 'NFF Wasteful' },
    { key: 'misdiagnosis', header: 'Misdiagnosis' },
    { key: 'parts_replaced', header: 'Parts Replaced' },
    { key: 'parts_not_faulty', header: 'Parts Not Faulty' },
    { key: 'repeat_dispatches', header: 'Repeat Dispatch' },
    { key: 'wasted_cost_rupees', header: 'Wasted Cost (INR)' },
    { key: 'accuracy_pct', header: 'Accuracy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'workshop_finding', header: 'Workshop Finding' },
    { key: 'cases', header: 'Cases' },
    { key: 'nff_cases', header: 'NFF / Misdiag' },
    { key: 'avg_wasted_part_cost_rupees', header: 'Avg Wasted Part (INR)' },
    { key: 'avg_freight_cost_rupees', header: 'Avg Freight (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'case_date', header: 'Date' },
    { key: 'cases', header: 'Cases' },
    { key: 'nff_cases', header: 'NFF Wasteful' },
    { key: 'misdiagnosis_cases', header: 'Misdiagnosis' },
    { key: 'repeat_dispatches', header: 'Repeat Dispatch' },
    { key: 'wasted_cost_rupees', header: 'Wasted Cost (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recoverable_rupees', header: 'Avg Recoverable (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'wasted_cost_rupees', header: 'Wasted Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'cases', header: 'Cases' },
    { key: 'nff_cases', header: 'NFF / Misdiag' },
    { key: 'wasted_part_cost_rupees', header: 'Wasted Part (INR)' },
    { key: 'freight_cost_rupees', header: 'Freight (INR)' },
    { key: 'total_waste_rupees', header: 'Total Waste (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'job_code', header: 'Job' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'workshop_finding', header: 'Workshop Finding' },
    { key: 'part_replaced', header: 'Part Replaced' },
    { key: 'part_actually_faulty', header: 'Part Faulty' },
    { key: 'nff_verdict', header: 'Verdict' },
    { key: 'wasted_part_cost_rupees', header: 'Wasted Part (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer No-Fault-Found &amp; Misdiagnosis Return-Rate Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Ops quality log — workshop finding &times; part-replaced vs actually-faulty &times; wasted
        part &amp; freight cost &times; repeat-dispatch &times; root cause &times; NFF verdict &amp;
        CAPA coaching. Founder-gated view: verdict mix, engineer scorecards, equipment/finding
        matrix, region waste-cost digest, and the high-risk case queue where units sent to workshop
        or parts swapped turned out to have no defect.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. NFF verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cases logged yet."
          rowKey={(r, i) => String(r.nff_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer NFF scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment &times; workshop-finding matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cases by equipment."
          rowKey={(r, i) => `${r.equipment_type}-${r.workshop_finding}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily case trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.case_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Region waste-cost digest</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk case queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cases."
          rowKey={(r, i) => `${r.job_code}-${i}`}
        />
      </section>
    </main>
  );
}
