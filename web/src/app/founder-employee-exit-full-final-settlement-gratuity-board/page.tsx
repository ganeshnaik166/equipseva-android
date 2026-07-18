import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { settlement_verdict: string; exits: number; pct: number };
type DeptRow = {
  department: string;
  total_exits: number;
  settled_on_time: number;
  settled_late: number;
  pending: number;
  disputed: number;
  gratuity_paid_rupees: number;
  recovery_rupees: number;
  on_time_pct: number;
};
type MatrixRow = {
  exit_type: string;
  department: string;
  exits: number;
  settled_on_time: number;
  avg_tenure_years: number;
  avg_net_settlement_rupees: number;
};
type TrendRow = {
  exit_date: string;
  exits: number;
  settled_on_time: number;
  settled_late: number;
  pending: number;
  disputed: number;
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
  employee_code: string;
  employee_name: string;
  department: string;
  exit_type: string;
  last_working_date: string;
  settlement_verdict: string;
  notice_period_served: string;
  net_settlement_rupees: number | null;
  pending_dues_recovery_rupees: number | null;
  asset_return_complete: boolean | null;
  exit_interview_done: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3277_settlement_verdict_rollup'),
    supabase.rpc('founder_r3277_department_scorecard'),
    supabase.rpc('founder_r3277_exit_type_department_matrix'),
    supabase.rpc('founder_r3277_daily_fnf_trend'),
    supabase.rpc('founder_r3277_capa_status_board'),
    supabase.rpc('founder_r3277_root_cause_pareto'),
    supabase.rpc('founder_r3277_regulatory_impact_digest'),
    supabase.rpc('founder_r3277_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'settlement_verdict', header: 'Settlement Verdict' },
    { key: 'exits', header: 'Exits' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_exits', header: 'Exits' },
    { key: 'settled_on_time', header: 'On Time' },
    { key: 'settled_late', header: 'Late' },
    { key: 'pending', header: 'Pending' },
    { key: 'disputed', header: 'Disputed / Withheld' },
    { key: 'gratuity_paid_rupees', header: 'Gratuity Paid (INR)' },
    { key: 'recovery_rupees', header: 'Recovery (INR)' },
    { key: 'on_time_pct', header: 'On-Time %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'exit_type', header: 'Exit Type' },
    { key: 'department', header: 'Department' },
    { key: 'exits', header: 'Exits' },
    { key: 'settled_on_time', header: 'On Time' },
    { key: 'avg_tenure_years', header: 'Avg Tenure Yrs' },
    { key: 'avg_net_settlement_rupees', header: 'Avg Net Settlement (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'exit_date', header: 'Last Working Date' },
    { key: 'exits', header: 'Exits' },
    { key: 'settled_on_time', header: 'On Time' },
    { key: 'settled_late', header: 'Late' },
    { key: 'pending', header: 'Pending' },
    { key: 'disputed', header: 'Disputed / Withheld' },
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
    { key: 'regulatory_impact', header: 'Statutory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_code', header: 'Emp Code' },
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'exit_type', header: 'Exit Type' },
    { key: 'last_working_date', header: 'Last Working Date' },
    { key: 'settlement_verdict', header: 'Verdict' },
    { key: 'notice_period_served', header: 'Notice' },
    { key: 'net_settlement_rupees', header: 'Net (INR)' },
    { key: 'pending_dues_recovery_rupees', header: 'Dues Recovery (INR)' },
    { key: 'asset_return_complete', header: 'Assets Returned' },
    { key: 'exit_interview_done', header: 'Exit Interview' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Employee Exit &amp; Full-and-Final Settlement, Gratuity &amp; Leave-Encashment Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        HR-finance governance — department &times; exit-type &times; notice-period served &times;
        tenure &amp; gratuity eligibility &times; leave encashment &times; pending-dues recovery
        &times; net F&amp;F settlement verdict &amp; CAPA closure. Founder-gated view: settlement
        verdicts, department scorecards, root-cause pareto, and statutory-impact digest across
        Gratuity Act &amp; labour-law surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Settlement verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No employee exits logged yet."
          rowKey={(r, i) => String(r.settlement_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department F&amp;F scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Exit-type &times; department matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No exits by type."
          rowKey={(r, i) => `${r.exit_type}-${r.department}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily exit &amp; F&amp;F trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.exit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Statutory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No statutory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk F&amp;F queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk exits."
          rowKey={(r, i) => `${r.employee_code}-${r.last_working_date}-${i}`}
        />
      </section>
    </main>
  );
}
