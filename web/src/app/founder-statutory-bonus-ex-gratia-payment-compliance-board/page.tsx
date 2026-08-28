import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; records: number; pct: number };
type CategoryRow = {
  employee_category: string;
  records: number;
  eligible_employees_total: number;
  paid_on_time: number;
  paid_late: number;
  underpaid_risk: number;
  pending: number;
  disputed: number;
  bonus_amount_total: number | null;
  avg_bonus_pct_applied: number | null;
};
type MatrixRow = {
  bonus_class: string;
  compliance_status: string;
  records: number;
  avg_bonus_amount_rupees: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  bonus_amount_total: number | null;
  avg_days_late: number | null;
  paid_on_time: number;
  paid_late: number;
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
  employee_category: string;
  records: number;
  underpaid_risk_records: number;
  avg_bonus_pct_applied: number | null;
  avg_statutory_min_pct: number | null;
  bonus_amount_total: number | null;
};
type RiskRow = {
  employee_category: string;
  location: string;
  period_month: string;
  bonus_class: string;
  compliance_status: string;
  payment_due_date: string | null;
  days_late: number | null;
  bonus_amount_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3746_compliance_status_rollup'),
    supabase.rpc('founder_r3746_employee_category_scorecard'),
    supabase.rpc('founder_r3746_bonus_class_status_matrix'),
    supabase.rpc('founder_r3746_monthly_payment_trend'),
    supabase.rpc('founder_r3746_capa_status_board'),
    supabase.rpc('founder_r3746_root_cause_pareto'),
    supabase.rpc('founder_r3746_underpayment_digest'),
    supabase.rpc('founder_r3746_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'employee_category', header: 'Employee Category' },
    { key: 'records', header: 'Records' },
    { key: 'eligible_employees_total', header: 'Eligible Employees' },
    { key: 'paid_on_time', header: 'Paid On Time' },
    { key: 'paid_late', header: 'Paid Late' },
    { key: 'underpaid_risk', header: 'Underpaid Risk' },
    { key: 'pending', header: 'Pending' },
    { key: 'disputed', header: 'Disputed' },
    { key: 'bonus_amount_total', header: 'Bonus Amount Total (Rs)' },
    { key: 'avg_bonus_pct_applied', header: 'Avg Bonus % Applied' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'bonus_class', header: 'Bonus Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_bonus_amount_rupees', header: 'Avg Bonus Amount (Rs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'bonus_amount_total', header: 'Bonus Amount Total (Rs)' },
    { key: 'avg_days_late', header: 'Avg Days Late' },
    { key: 'paid_on_time', header: 'Paid On Time' },
    { key: 'paid_late', header: 'Paid Late' },
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
    { key: 'employee_category', header: 'Employee Category' },
    { key: 'records', header: 'Records' },
    { key: 'underpaid_risk_records', header: 'Underpaid Risk Records' },
    { key: 'avg_bonus_pct_applied', header: 'Avg Bonus % Applied' },
    { key: 'avg_statutory_min_pct', header: 'Avg Statutory Min %' },
    { key: 'bonus_amount_total', header: 'Bonus Amount Total (Rs)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_category', header: 'Employee Category' },
    { key: 'location', header: 'Location' },
    { key: 'period_month', header: 'Month' },
    { key: 'bonus_class', header: 'Bonus Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'payment_due_date', header: 'Payment Due Date' },
    { key: 'days_late', header: 'Days Late' },
    { key: 'bonus_amount_rupees', header: 'Bonus Amount (Rs)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Statutory Bonus &amp; Ex-Gratia Payment Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Statutory bonus (Payment of Bonus Act) and ex-gratia payment compliance per eligible
        employee category &mdash; eligibility, bonus % vs statutory min/max, payment
        timeliness, and allocable-surplus basis. Distinct from any general payroll-run board,
        any PF/ESI compliance board, and any incentive/commission-payout board, which are
        separate schemes. Founder-gated view: compliance-status distribution, employee-category
        scorecards, bonus-class &times; status matrix, monthly payment trend, CAPA status
        board, root-cause pareto, an underpayment-risk digest, and a high-risk queue of
        underpaid, disputed &amp; pending payments.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No statutory bonus rows logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Employee-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No employee-category rollups."
          rowKey={(r, i) => String(r.employee_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Bonus class &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No bonuses by class."
          rowKey={(r, i) => `${r.bonus_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly payment trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Underpayment-risk digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No underpayment-risk records."
          rowKey={(r, i) => String(r.employee_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk payment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk payments."
          rowKey={(r, i) => `${r.employee_category}-${r.location}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
