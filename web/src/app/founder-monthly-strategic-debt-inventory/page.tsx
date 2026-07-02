import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type DebtRow = {
  id: string;
  debt_title: string;
  debt_kind: string;
  opened_at: string;
  age_days: number;
  cost_to_fix_rupees: number;
  cost_of_carry_per_month_rupees: number;
  pay_off_priority: number;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type PlanRow = {
  id: string;
  debt_id: string;
  debt_title: string;
  planned_at: string;
  target_completion_at: string | null;
  status: string;
  realized_savings_rupees: number;
  owner_email: string | null;
  notes: string | null;
};

type TopRow = {
  id: string;
  debt_title: string;
  debt_kind: string;
  pay_off_priority: number;
  cost_to_fix_rupees: number;
  cost_of_carry_per_month_rupees: number;
  age_days: number;
  status: string;
  owner_email: string | null;
};

type KindRow = {
  debt_kind: string;
  open_count: number;
  total_count: number;
  total_cost_to_fix: number;
  total_carry_per_month: number;
};

type CarryRow = {
  open_debt_count: number;
  total_cost_to_fix: number;
  monthly_carry: number;
  annualized_carry: number;
  realized_savings_to_date: number;
};

type TrendRow = {
  month_bucket: string;
  plans_planned: number;
  plans_done: number;
  realized_savings: number;
};

type OwnerRow = {
  owner_email: string;
  open_debts: number;
  in_progress_plans: number;
  monthly_carry: number;
  realized_savings: number;
};

const fmtRupees = (n: number | null | undefined) =>
  n == null ? '—' : '₹' + Number(n).toLocaleString('en-IN');

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [debtRes, planRes, topRes, kindRes, carryRes, trendRes, ownerRes] = await Promise.all([
    sb.rpc('list_debt_inventory_r2521'),
    sb.rpc('list_pay_off_plans_r2521'),
    sb.rpc('top_priority_debt_r2521'),
    sb.rpc('kind_breakdown_r2521'),
    sb.rpc('cost_of_carry_summary_r2521'),
    sb.rpc('monthly_pay_off_trend_r2521'),
    sb.rpc('owner_load_r2521'),
  ]);

  const debts: DebtRow[] = (debtRes.data as DebtRow[] | null) ?? [];
  const plans: PlanRow[] = (planRes.data as PlanRow[] | null) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const kinds: KindRow[] = (kindRes.data as KindRow[] | null) ?? [];
  const carry: CarryRow[] = (carryRes.data as CarryRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];
  const owners: OwnerRow[] = (ownerRes.data as OwnerRow[] | null) ?? [];

  const debtCols: Column<any>[] = [
    { key: 'debt_title', header: 'Debt', render: (r: any) => r.debt_title },
    { key: 'debt_kind', header: 'Kind', render: (r: any) => r.debt_kind },
    { key: 'pay_off_priority', header: 'Priority', render: (r: any) => 'P' + r.pay_off_priority },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => r.age_days },
    { key: 'cost_to_fix_rupees', header: 'Cost to fix', render: (r: any) => fmtRupees(r.cost_to_fix_rupees) },
    { key: 'cost_of_carry_per_month_rupees', header: 'Carry/mo', render: (r: any) => fmtRupees(r.cost_of_carry_per_month_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const planCols: Column<any>[] = [
    { key: 'debt_title', header: 'Debt', render: (r: any) => r.debt_title },
    { key: 'planned_at', header: 'Planned', render: (r: any) => r.planned_at ? String(r.planned_at).slice(0, 10) : '—' },
    { key: 'target_completion_at', header: 'Target', render: (r: any) => r.target_completion_at ? String(r.target_completion_at).slice(0, 10) : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'realized_savings_rupees', header: 'Realized savings', render: (r: any) => fmtRupees(r.realized_savings_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'debt_title', header: 'Debt', render: (r: any) => r.debt_title },
    { key: 'debt_kind', header: 'Kind', render: (r: any) => r.debt_kind },
    { key: 'pay_off_priority', header: 'Priority', render: (r: any) => 'P' + r.pay_off_priority },
    { key: 'cost_to_fix_rupees', header: 'Cost to fix', render: (r: any) => fmtRupees(r.cost_to_fix_rupees) },
    { key: 'cost_of_carry_per_month_rupees', header: 'Carry/mo', render: (r: any) => fmtRupees(r.cost_of_carry_per_month_rupees) },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => r.age_days },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'debt_kind', header: 'Kind', render: (r: any) => r.debt_kind },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'total_cost_to_fix', header: 'Total cost to fix', render: (r: any) => fmtRupees(r.total_cost_to_fix) },
    { key: 'total_carry_per_month', header: 'Carry/mo', render: (r: any) => fmtRupees(r.total_carry_per_month) },
  ];

  const carryCols: Column<any>[] = [
    { key: 'open_debt_count', header: 'Open debts', render: (r: any) => r.open_debt_count },
    { key: 'total_cost_to_fix', header: 'Total cost to fix', render: (r: any) => fmtRupees(r.total_cost_to_fix) },
    { key: 'monthly_carry', header: 'Monthly carry', render: (r: any) => fmtRupees(r.monthly_carry) },
    { key: 'annualized_carry', header: 'Annualized carry', render: (r: any) => fmtRupees(r.annualized_carry) },
    { key: 'realized_savings_to_date', header: 'Realized savings', render: (r: any) => fmtRupees(r.realized_savings_to_date) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_bucket', header: 'Month', render: (r: any) => r.month_bucket },
    { key: 'plans_planned', header: 'Planned', render: (r: any) => r.plans_planned },
    { key: 'plans_done', header: 'Done', render: (r: any) => r.plans_done },
    { key: 'realized_savings', header: 'Savings', render: (r: any) => fmtRupees(r.realized_savings) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_debts', header: 'Open debts', render: (r: any) => r.open_debts },
    { key: 'in_progress_plans', header: 'In-progress plans', render: (r: any) => r.in_progress_plans },
    { key: 'monthly_carry', header: 'Carry/mo', render: (r: any) => fmtRupees(r.monthly_carry) },
    { key: 'realized_savings', header: 'Realized savings', render: (r: any) => fmtRupees(r.realized_savings) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>
        Founder — Monthly Strategic Debt Inventory
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Round r2521 · tech & process & people & legal & financial & customer debt —
        age, cost to fix, cost of carry, pay-off priority.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Cost-of-carry summary</h2>
        <DataTable
          rows={carry}
          columns={carryCols}
          emptyMessage="No summary yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top priority open debt</h2>
        <DataTable
          rows={top}
          columns={topCols}
          emptyMessage="No open priority debt"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Full debt inventory</h2>
        <DataTable
          rows={debts}
          columns={debtCols}
          emptyMessage="No debt logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pay-off plans</h2>
        <DataTable
          rows={plans}
          columns={planCols}
          emptyMessage="No pay-off plans"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Breakdown by kind</h2>
        <DataTable
          rows={kinds}
          columns={kindCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.debt_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly pay-off trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend yet"
          rowKey={(r: any, i: number) => String(r.month_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner load</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owner load"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
