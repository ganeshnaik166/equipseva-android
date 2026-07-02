import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = {
  id?: string;
  issuance_month: string;
  total_issued: number;
  total_value_rupees: number;
  on_time_returns: number;
  late_returns: number;
  overdue_open: number;
  on_time_pct: number | null;
};

type TierBreakdown = {
  id?: string;
  discipline_tier: string;
  customer_count: number;
  total_penalty_rupees: number;
  unresolved_count: number;
};

type OverdueDetail = {
  id?: string;
  customer_org_name: string;
  engineer_code: string;
  equipment_model: string;
  expected_return_at: string;
  loaner_value_rupees: number;
  return_status: string;
  city: string;
};

type EngineerPerf = {
  id?: string;
  engineer_code: string;
  loaners_issued: number;
  on_time_count: number;
  late_count: number;
  problem_count: number;
  on_time_pct: number | null;
};

type CustomerPerf = {
  id?: string;
  customer_org_name: string;
  loaners_received: number;
  total_value_rupees: number;
  on_time_count: number;
  problem_count: number;
  on_time_pct: number | null;
};

type CategoryRisk = {
  id?: string;
  equipment_category: string;
  loaner_count: number;
  total_value_at_risk_rupees: number;
  problem_pct: number | null;
};

type RecoveryRow = {
  id?: string;
  founder_flag: string;
  recovery_action: string;
  customer_org_name: string;
  engineer_code: string;
  days_overdue: number;
  penalty_rupees: number;
  discipline_tier: string;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + n.toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return '-';
  return `${n}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    monthlyRes,
    tierRes,
    overdueRes,
    engPerfRes,
    custPerfRes,
    catRiskRes,
    recoveryRes,
  ] = await Promise.all([
    supabase.rpc('r2940_monthly_issuance_summary'),
    supabase.rpc('r2940_discipline_tier_breakdown'),
    supabase.rpc('r2940_overdue_loaners_detail'),
    supabase.rpc('r2940_engineer_return_performance'),
    supabase.rpc('r2940_customer_return_performance'),
    supabase.rpc('r2940_category_risk'),
    supabase.rpc('r2940_recovery_action_queue'),
  ]);

  const monthly: MonthlySummary[] = (monthlyRes.data ?? []) as MonthlySummary[];
  const tiers: TierBreakdown[] = (tierRes.data ?? []) as TierBreakdown[];
  const overdue: OverdueDetail[] = (overdueRes.data ?? []) as OverdueDetail[];
  const engPerf: EngineerPerf[] = (engPerfRes.data ?? []) as EngineerPerf[];
  const custPerf: CustomerPerf[] = (custPerfRes.data ?? []) as CustomerPerf[];
  const catRisk: CategoryRisk[] = (catRiskRes.data ?? []) as CategoryRisk[];
  const recovery: RecoveryRow[] = (recoveryRes.data ?? []) as RecoveryRow[];

  const monthlyCols: Column<MonthlySummary>[] = [
    { key: 'issuance_month', header: 'Month', render: (r) => r.issuance_month },
    { key: 'total_issued', header: 'Issued', render: (r) => r.total_issued },
    { key: 'total_value_rupees', header: 'Total Value', render: (r) => fmtRupees(r.total_value_rupees) },
    { key: 'on_time_returns', header: 'On-time', render: (r) => r.on_time_returns },
    { key: 'late_returns', header: 'Late', render: (r) => r.late_returns },
    { key: 'overdue_open', header: 'Overdue/Open', render: (r) => r.overdue_open },
    { key: 'on_time_pct', header: 'On-time %', render: (r) => fmtPct(r.on_time_pct) },
  ];

  const tierCols: Column<TierBreakdown>[] = [
    { key: 'discipline_tier', header: 'Tier', render: (r) => r.discipline_tier },
    { key: 'customer_count', header: 'Customers', render: (r) => r.customer_count },
    { key: 'total_penalty_rupees', header: 'Penalty', render: (r) => fmtRupees(r.total_penalty_rupees) },
    { key: 'unresolved_count', header: 'Unresolved', render: (r) => r.unresolved_count },
  ];

  const overdueCols: Column<OverdueDetail>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r) => r.customer_org_name },
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'equipment_model', header: 'Equipment', render: (r) => r.equipment_model },
    { key: 'expected_return_at', header: 'Expected Return', render: (r) => new Date(r.expected_return_at).toLocaleDateString('en-IN') },
    { key: 'loaner_value_rupees', header: 'Value', render: (r) => fmtRupees(r.loaner_value_rupees) },
    { key: 'return_status', header: 'Status', render: (r) => r.return_status },
    { key: 'city', header: 'City', render: (r) => r.city },
  ];

  const engCols: Column<EngineerPerf>[] = [
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'loaners_issued', header: 'Issued', render: (r) => r.loaners_issued },
    { key: 'on_time_count', header: 'On-time', render: (r) => r.on_time_count },
    { key: 'late_count', header: 'Late', render: (r) => r.late_count },
    { key: 'problem_count', header: 'Problem', render: (r) => r.problem_count },
    { key: 'on_time_pct', header: 'On-time %', render: (r) => fmtPct(r.on_time_pct) },
  ];

  const custCols: Column<CustomerPerf>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r) => r.customer_org_name },
    { key: 'loaners_received', header: 'Received', render: (r) => r.loaners_received },
    { key: 'total_value_rupees', header: 'Total Value', render: (r) => fmtRupees(r.total_value_rupees) },
    { key: 'on_time_count', header: 'On-time', render: (r) => r.on_time_count },
    { key: 'problem_count', header: 'Problem', render: (r) => r.problem_count },
    { key: 'on_time_pct', header: 'On-time %', render: (r) => fmtPct(r.on_time_pct) },
  ];

  const catCols: Column<CategoryRisk>[] = [
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'loaner_count', header: 'Loaners', render: (r) => r.loaner_count },
    { key: 'total_value_at_risk_rupees', header: 'Value At Risk', render: (r) => fmtRupees(r.total_value_at_risk_rupees) },
    { key: 'problem_pct', header: 'Problem %', render: (r) => fmtPct(r.problem_pct) },
  ];

  const recoveryCols: Column<RecoveryRow>[] = [
    { key: 'founder_flag', header: 'Flag', render: (r) => r.founder_flag },
    { key: 'recovery_action', header: 'Action', render: (r) => r.recovery_action },
    { key: 'customer_org_name', header: 'Customer', render: (r) => r.customer_org_name },
    { key: 'engineer_code', header: 'Engineer', render: (r) => r.engineer_code },
    { key: 'discipline_tier', header: 'Tier', render: (r) => r.discipline_tier },
    { key: 'days_overdue', header: 'Days Overdue', render: (r) => r.days_overdue },
    { key: 'penalty_rupees', header: 'Penalty', render: (r) => fmtRupees(r.penalty_rupees) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '28px' }}>
        <h1 style={{ fontSize: '26px', fontWeight: 700, marginBottom: '6px' }}>
          Customer Monthly Engineer Bilateral-Loaner Equipment Tracking & Return Discipline
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Round r2940 · Founder console · Loaner equipment issued between customers & engineers, scored monthly on return discipline.
        </p>
      </header>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>Monthly issuance summary</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No issuance data."
          rowKey={(r, i) => String(r.id ?? `${r.issuance_month}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>Discipline tier breakdown</h2>
        <DataTable
          rows={tiers}
          columns={tierCols}
          emptyMessage="No tier data."
          rowKey={(r, i) => String(r.id ?? `${r.discipline_tier}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>Overdue & open loaners</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue loaners — clean."
          rowKey={(r, i) => String(r.id ?? `${r.engineer_code}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>Engineer return performance</h2>
        <DataTable
          rows={engPerf}
          columns={engCols}
          emptyMessage="No engineer data."
          rowKey={(r, i) => String(r.id ?? `${r.engineer_code}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>Customer return performance</h2>
        <DataTable
          rows={custPerf}
          columns={custCols}
          emptyMessage="No customer data."
          rowKey={(r, i) => String(r.id ?? `${r.customer_org_name}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>Category risk</h2>
        <DataTable
          rows={catRisk}
          columns={catCols}
          emptyMessage="No category data."
          rowKey={(r, i) => String(r.id ?? `${r.equipment_category}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>Recovery action queue</h2>
        <DataTable
          rows={recovery}
          columns={recoveryCols}
          emptyMessage="No open recovery actions."
          rowKey={(r, i) => String(r.id ?? `${r.engineer_code}-${i}`)}
        />
      </section>
    </main>
  );
}
