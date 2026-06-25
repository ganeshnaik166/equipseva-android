import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Cycle = {
  id: string;
  customer_org_name: string;
  customer_tier: string;
  fiscal_quarter: string;
  allocated_budget_rupees: number;
  spent_to_date_rupees: number;
  variance_pct: number;
  cycle_status: string;
  refill_requested: boolean;
  last_spend_at: string | null;
};

type Kpi = {
  total_cycles: number;
  total_allocated_rupees: number;
  total_spent_rupees: number;
  over_budget_count: number;
  exhausted_count: number;
  pending_refill_count: number;
  total_projected_overrun_rupees: number;
};

type TierRow = {
  customer_tier: string;
  cycle_count: number;
  total_allocated_rupees: number;
  total_spent_rupees: number;
  avg_variance_pct: number;
};

type RefillAction = {
  id: string;
  customer_org_name: string;
  action_type: string;
  action_status: string;
  requested_amount_rupees: number;
  approved_amount_rupees: number;
  justification: string;
  decided_by: string | null;
  requested_at: string;
};

type OverBudget = {
  id: string;
  customer_org_name: string;
  customer_tier: string;
  allocated_budget_rupees: number;
  spent_to_date_rupees: number;
  variance_rupees: number;
  variance_pct: number;
  projected_overrun_rupees: number;
};

type BurnRow = {
  id: string;
  customer_org_name: string;
  burn_rate_per_day_rupees: number;
  spent_to_date_rupees: number;
  allocated_budget_rupees: number;
  days_remaining: number;
  projected_total_spend_rupees: number;
};

function fmt(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [cyclesRes, kpisRes, tierRes, refillRes, overRes, burnRes, pendingRes] = await Promise.all([
    supabase.rpc('founder_r2696_list_cycles'),
    supabase.rpc('founder_r2696_kpis'),
    supabase.rpc('founder_r2696_by_tier'),
    supabase.rpc('founder_r2696_refill_actions'),
    supabase.rpc('founder_r2696_over_budget'),
    supabase.rpc('founder_r2696_burn_rate'),
    supabase.rpc('founder_r2696_pending_refills'),
  ]);

  const cycles = (cyclesRes.data ?? []) as Cycle[];
  const kpis = ((kpisRes.data ?? [])[0] ?? {
    total_cycles: 0,
    total_allocated_rupees: 0,
    total_spent_rupees: 0,
    over_budget_count: 0,
    exhausted_count: 0,
    pending_refill_count: 0,
    total_projected_overrun_rupees: 0,
  }) as Kpi;
  const tierRows = (tierRes.data ?? []) as TierRow[];
  const refillActions = (refillRes.data ?? []) as RefillAction[];
  const overBudget = (overRes.data ?? []) as OverBudget[];
  const burnRows = (burnRes.data ?? []) as BurnRow[];
  const pendingRefills = (pendingRes.data ?? []) as RefillAction[];

  return (
    <main className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer Quarterly Budget Cycle Tracker</h1>
        <p className="text-sm text-gray-600">
          Track allocation vs spend, variance, burn-rate & refill actions per customer per fiscal quarter.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Cycles</div>
          <div className="text-2xl font-semibold">{kpis.total_cycles}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Allocated</div>
          <div className="text-2xl font-semibold">{fmt(kpis.total_allocated_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Spent</div>
          <div className="text-2xl font-semibold">{fmt(kpis.total_spent_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Over Budget</div>
          <div className="text-2xl font-semibold">{kpis.over_budget_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Exhausted</div>
          <div className="text-2xl font-semibold">{kpis.exhausted_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Pending Refills</div>
          <div className="text-2xl font-semibold">{kpis.pending_refill_count}</div>
        </div>
        <div className="rounded-lg border p-4 col-span-2">
          <div className="text-xs text-gray-500">Projected Overrun</div>
          <div className="text-2xl font-semibold">{fmt(kpis.total_projected_overrun_rupees)}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Cycles</h2>
        <DataTable
          rows={cycles}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: Cycle) => <span>{r.customer_org_name}</span> },
            { key: 'customer_tier', header: 'Tier', render: (r: Cycle) => <span className="uppercase text-xs">{r.customer_tier}</span> },
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: Cycle) => <span>{r.fiscal_quarter}</span> },
            { key: 'allocated_budget_rupees', header: 'Allocated', render: (r: Cycle) => <span>{fmt(r.allocated_budget_rupees)}</span> },
            { key: 'spent_to_date_rupees', header: 'Spent', render: (r: Cycle) => <span>{fmt(r.spent_to_date_rupees)}</span> },
            { key: 'variance_pct', header: 'Variance %', render: (r: Cycle) => <span>{pct(r.variance_pct)}</span> },
            { key: 'cycle_status', header: 'Status', render: (r: Cycle) => <span>{r.cycle_status}</span> },
            { key: 'refill_requested', header: 'Refill?', render: (r: Cycle) => <span>{r.refill_requested ? 'YES' : 'no'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Cycle, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">By Customer Tier</h2>
        <DataTable
          rows={tierRows}
          columns={[
            { key: 'customer_tier', header: 'Tier', render: (r: TierRow) => <span className="uppercase">{r.customer_tier}</span> },
            { key: 'cycle_count', header: 'Cycles', render: (r: TierRow) => <span>{r.cycle_count}</span> },
            { key: 'total_allocated_rupees', header: 'Allocated', render: (r: TierRow) => <span>{fmt(r.total_allocated_rupees)}</span> },
            { key: 'total_spent_rupees', header: 'Spent', render: (r: TierRow) => <span>{fmt(r.total_spent_rupees)}</span> },
            { key: 'avg_variance_pct', header: 'Avg Variance', render: (r: TierRow) => <span>{pct(r.avg_variance_pct)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.customer_tier ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Over-Budget &amp; Exhausted</h2>
        <p className="text-xs text-gray-500">Cycles where spent &gt;= allocated or variance &gt; 0</p>
        <DataTable
          rows={overBudget}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: OverBudget) => <span>{r.customer_org_name}</span> },
            { key: 'customer_tier', header: 'Tier', render: (r: OverBudget) => <span className="uppercase text-xs">{r.customer_tier}</span> },
            { key: 'allocated_budget_rupees', header: 'Allocated', render: (r: OverBudget) => <span>{fmt(r.allocated_budget_rupees)}</span> },
            { key: 'spent_to_date_rupees', header: 'Spent', render: (r: OverBudget) => <span>{fmt(r.spent_to_date_rupees)}</span> },
            { key: 'variance_rupees', header: 'Variance', render: (r: OverBudget) => <span>{fmt(r.variance_rupees)}</span> },
            { key: 'variance_pct', header: 'Variance %', render: (r: OverBudget) => <span>{pct(r.variance_pct)}</span> },
            { key: 'projected_overrun_rupees', header: 'Projected Overrun', render: (r: OverBudget) => <span>{fmt(r.projected_overrun_rupees)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: OverBudget, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Burn Rate & Projection</h2>
        <DataTable
          rows={burnRows}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: BurnRow) => <span>{r.customer_org_name}</span> },
            { key: 'burn_rate_per_day_rupees', header: 'Burn / day', render: (r: BurnRow) => <span>{fmt(r.burn_rate_per_day_rupees)}</span> },
            { key: 'spent_to_date_rupees', header: 'Spent', render: (r: BurnRow) => <span>{fmt(r.spent_to_date_rupees)}</span> },
            { key: 'allocated_budget_rupees', header: 'Allocated', render: (r: BurnRow) => <span>{fmt(r.allocated_budget_rupees)}</span> },
            { key: 'days_remaining', header: 'Days Left', render: (r: BurnRow) => <span>{r.days_remaining}</span> },
            { key: 'projected_total_spend_rupees', header: 'Projected Total', render: (r: BurnRow) => <span>{fmt(r.projected_total_spend_rupees)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: BurnRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Pending Refills</h2>
        <DataTable
          rows={pendingRefills}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: RefillAction) => <span>{r.customer_org_name}</span> },
            { key: 'requested_amount_rupees', header: 'Requested', render: (r: RefillAction) => <span>{fmt(r.requested_amount_rupees)}</span> },
            { key: 'action_status', header: 'Status', render: (r: RefillAction) => <span>{r.action_status}</span> },
            { key: 'justification', header: 'Justification', render: (r: RefillAction) => <span>{r.justification}</span> },
            { key: 'requested_at', header: 'Requested At', render: (r: RefillAction) => <span>{new Date(r.requested_at).toLocaleString('en-IN')}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: RefillAction, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Refill Actions</h2>
        <DataTable
          rows={refillActions}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: RefillAction) => <span>{r.customer_org_name}</span> },
            { key: 'action_type', header: 'Type', render: (r: RefillAction) => <span>{r.action_type}</span> },
            { key: 'action_status', header: 'Status', render: (r: RefillAction) => <span>{r.action_status}</span> },
            { key: 'requested_amount_rupees', header: 'Requested', render: (r: RefillAction) => <span>{fmt(r.requested_amount_rupees)}</span> },
            { key: 'approved_amount_rupees', header: 'Approved', render: (r: RefillAction) => <span>{fmt(r.approved_amount_rupees)}</span> },
            { key: 'decided_by', header: 'Decided By', render: (r: RefillAction) => <span>{r.decided_by ?? '-'}</span> },
            { key: 'requested_at', header: 'Requested At', render: (r: RefillAction) => <span>{new Date(r.requested_at).toLocaleString('en-IN')}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: RefillAction, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
