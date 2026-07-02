import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Category = {
  id: number;
  category: string;
  month_label: string;
  budget_rupees: number;
  spent_rupees: number;
  burn_rate_pct: number;
  runway_months: number;
  severity: string;
  action_required: string;
  notes: string | null;
};

type Action = {
  id: number;
  category: string;
  action_title: string;
  expected_saving_rupees: number;
  due_date: string;
  priority: string;
  status: string;
  owner: string;
};

type Summary = {
  total_budget_rupees: number;
  total_spent_rupees: number;
  overall_burn_pct: number;
  weighted_runway_months: number;
  category_count: number;
  critical_count: number;
};

type SeverityRow = {
  severity: string;
  category_count: number;
  total_spent: number;
  avg_burn_pct: number;
};

type Overspend = {
  category: string;
  budget_rupees: number;
  spent_rupees: number;
  overspend_rupees: number;
  burn_rate_pct: number;
};

type ActionStatusRow = {
  status: string;
  action_count: number;
  expected_savings: number;
};

type RunwayAlert = {
  category: string;
  runway_months: number;
  burn_rate_pct: number;
  action_required: string;
  severity: string;
};

type PotentialSavings = {
  open_action_count: number;
  potential_savings: number;
  urgent_count: number;
  due_within_7_days: number;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

function pct(n: number | null | undefined): string {
  return (Number(n ?? 0)).toFixed(2) + '%';
}

function sevBadge(sev: string): string {
  const m: Record<string, string> = {
    critical: 'bg-red-200 text-red-900',
    red: 'bg-red-100 text-red-800',
    amber: 'bg-amber-100 text-amber-800',
    green: 'bg-emerald-100 text-emerald-800',
  };
  return m[sev] ?? 'bg-slate-100 text-slate-800';
}

function priBadge(p: string): string {
  const m: Record<string, string> = {
    urgent: 'bg-red-100 text-red-800',
    high: 'bg-orange-100 text-orange-800',
    medium: 'bg-blue-100 text-blue-800',
    low: 'bg-slate-100 text-slate-700',
  };
  return m[p] ?? 'bg-slate-100 text-slate-700';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    catsRes,
    actionsRes,
    summaryRes,
    severityRes,
    overspendRes,
    actionStatusRes,
    runwayRes,
    potentialRes,
  ] = await Promise.all([
    supabase.rpc('founder_personal_cashflow_categories_r2685'),
    supabase.rpc('founder_personal_cashflow_actions_r2685'),
    supabase.rpc('founder_personal_cashflow_summary_r2685'),
    supabase.rpc('founder_personal_cashflow_by_severity_r2685'),
    supabase.rpc('founder_personal_cashflow_top_overspend_r2685', { p_limit: 5 }),
    supabase.rpc('founder_personal_cashflow_actions_by_status_r2685'),
    supabase.rpc('founder_personal_cashflow_runway_alert_r2685', { p_threshold_months: 6.0 }),
    supabase.rpc('founder_personal_cashflow_potential_savings_r2685'),
  ]);

  const categories: Category[] = (catsRes.data as Category[]) ?? [];
  const actions: Action[] = (actionsRes.data as Action[]) ?? [];
  const summary: Summary | null = ((summaryRes.data as Summary[]) ?? [])[0] ?? null;
  const severity: SeverityRow[] = (severityRes.data as SeverityRow[]) ?? [];
  const overspend: Overspend[] = (overspendRes.data as Overspend[]) ?? [];
  const actionStatus: ActionStatusRow[] = (actionStatusRes.data as ActionStatusRow[]) ?? [];
  const runwayAlerts: RunwayAlert[] = (runwayRes.data as RunwayAlert[]) ?? [];
  const potential: PotentialSavings | null = ((potentialRes.data as PotentialSavings[]) ?? [])[0] ?? null;

  const catColumns = [
    { key: 'category', header: 'Category', render: (r: Category) => <span className="font-medium">{r.category}</span> },
    { key: 'month_label', header: 'Month', render: (r: Category) => <span className="text-slate-600">{r.month_label}</span> },
    { key: 'budget', header: 'Budget', render: (r: Category) => <span>{rupees(r.budget_rupees)}</span> },
    { key: 'spent', header: 'Spent', render: (r: Category) => <span>{rupees(r.spent_rupees)}</span> },
    { key: 'burn', header: 'Burn %', render: (r: Category) => <span className={Number(r.burn_rate_pct) > 100 ? 'text-red-700 font-semibold' : 'text-emerald-700'}>{pct(r.burn_rate_pct)}</span> },
    { key: 'runway', header: 'Runway (mo)', render: (r: Category) => <span>{Number(r.runway_months).toFixed(2)}</span> },
    { key: 'severity', header: 'Severity', render: (r: Category) => <span className={'px-2 py-1 rounded text-xs ' + sevBadge(r.severity)}>{r.severity}</span> },
    { key: 'action', header: 'Action', render: (r: Category) => <span className="text-slate-700">{r.action_required}</span> },
  ];

  const actionColumns = [
    { key: 'title', header: 'Action', render: (r: Action) => <span className="font-medium">{r.action_title}</span> },
    { key: 'cat', header: 'Category', render: (r: Action) => <span className="text-slate-600">{r.category}</span> },
    { key: 'save', header: 'Expected Saving', render: (r: Action) => <span className="text-emerald-700">{rupees(r.expected_saving_rupees)}</span> },
    { key: 'due', header: 'Due', render: (r: Action) => <span>{r.due_date}</span> },
    { key: 'pri', header: 'Priority', render: (r: Action) => <span className={'px-2 py-1 rounded text-xs ' + priBadge(r.priority)}>{r.priority}</span> },
    { key: 'status', header: 'Status', render: (r: Action) => <span className="text-slate-700">{r.status}</span> },
    { key: 'owner', header: 'Owner', render: (r: Action) => <span>{r.owner}</span> },
  ];

  const sevColumns = [
    { key: 'sev', header: 'Severity', render: (r: SeverityRow) => <span className={'px-2 py-1 rounded text-xs ' + sevBadge(r.severity)}>{r.severity}</span> },
    { key: 'count', header: 'Categories', render: (r: SeverityRow) => <span>{r.category_count}</span> },
    { key: 'spent', header: 'Total Spent', render: (r: SeverityRow) => <span>{rupees(r.total_spent)}</span> },
    { key: 'avg', header: 'Avg Burn %', render: (r: SeverityRow) => <span>{pct(r.avg_burn_pct)}</span> },
  ];

  const overspendColumns = [
    { key: 'cat', header: 'Category', render: (r: Overspend) => <span className="font-medium">{r.category}</span> },
    { key: 'bud', header: 'Budget', render: (r: Overspend) => <span>{rupees(r.budget_rupees)}</span> },
    { key: 'spent', header: 'Spent', render: (r: Overspend) => <span>{rupees(r.spent_rupees)}</span> },
    { key: 'over', header: 'Overspend', render: (r: Overspend) => <span className="text-red-700 font-semibold">{rupees(r.overspend_rupees)}</span> },
    { key: 'burn', header: 'Burn %', render: (r: Overspend) => <span>{pct(r.burn_rate_pct)}</span> },
  ];

  const actionStatusColumns = [
    { key: 'status', header: 'Status', render: (r: ActionStatusRow) => <span className="font-medium">{r.status}</span> },
    { key: 'count', header: 'Actions', render: (r: ActionStatusRow) => <span>{r.action_count}</span> },
    { key: 'save', header: 'Expected Savings', render: (r: ActionStatusRow) => <span className="text-emerald-700">{rupees(r.expected_savings)}</span> },
  ];

  const runwayColumns = [
    { key: 'cat', header: 'Category', render: (r: RunwayAlert) => <span className="font-medium">{r.category}</span> },
    { key: 'runway', header: 'Runway (mo)', render: (r: RunwayAlert) => <span className="text-red-700 font-semibold">{Number(r.runway_months).toFixed(2)}</span> },
    { key: 'burn', header: 'Burn %', render: (r: RunwayAlert) => <span>{pct(r.burn_rate_pct)}</span> },
    { key: 'sev', header: 'Severity', render: (r: RunwayAlert) => <span className={'px-2 py-1 rounded text-xs ' + sevBadge(r.severity)}>{r.severity}</span> },
    { key: 'action', header: 'Action Required', render: (r: RunwayAlert) => <span className="text-slate-700">{r.action_required}</span> },
  ];

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      <header>
        <h1 className="text-3xl font-bold text-slate-900">Monthly Personal Cashflow Burn</h1>
        <p className="text-slate-600 mt-1">Founder personal budget vs spent · burn rate · runway · actions. Runway &lt;= 6 months flagged. Burn &gt;= 100% = overspend.</p>
      </header>

      {/* KPI cards */}
      <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white border border-slate-200 rounded-lg p-4">
          <div className="text-xs text-slate-500 uppercase">Total Budget</div>
          <div className="text-2xl font-bold mt-1">{rupees(summary?.total_budget_rupees)}</div>
        </div>
        <div className="bg-white border border-slate-200 rounded-lg p-4">
          <div className="text-xs text-slate-500 uppercase">Total Spent</div>
          <div className="text-2xl font-bold mt-1">{rupees(summary?.total_spent_rupees)}</div>
        </div>
        <div className="bg-white border border-slate-200 rounded-lg p-4">
          <div className="text-xs text-slate-500 uppercase">Overall Burn</div>
          <div className={'text-2xl font-bold mt-1 ' + (Number(summary?.overall_burn_pct ?? 0) > 100 ? 'text-red-700' : 'text-emerald-700')}>{pct(summary?.overall_burn_pct)}</div>
        </div>
        <div className="bg-white border border-slate-200 rounded-lg p-4">
          <div className="text-xs text-slate-500 uppercase">Weighted Runway</div>
          <div className="text-2xl font-bold mt-1">{Number(summary?.weighted_runway_months ?? 0).toFixed(2)} mo</div>
        </div>
        <div className="bg-white border border-slate-200 rounded-lg p-4">
          <div className="text-xs text-slate-500 uppercase">Categories</div>
          <div className="text-2xl font-bold mt-1">{summary?.category_count ?? 0}</div>
        </div>
        <div className="bg-white border border-slate-200 rounded-lg p-4">
          <div className="text-xs text-slate-500 uppercase">Critical</div>
          <div className="text-2xl font-bold mt-1 text-red-700">{summary?.critical_count ?? 0}</div>
        </div>
        <div className="bg-white border border-slate-200 rounded-lg p-4">
          <div className="text-xs text-slate-500 uppercase">Potential Savings</div>
          <div className="text-2xl font-bold mt-1 text-emerald-700">{rupees(potential?.potential_savings)}</div>
          <div className="text-xs text-slate-500 mt-1">{potential?.open_action_count ?? 0} open actions</div>
        </div>
        <div className="bg-white border border-slate-200 rounded-lg p-4">
          <div className="text-xs text-slate-500 uppercase">Urgent / 7-day</div>
          <div className="text-2xl font-bold mt-1">{potential?.urgent_count ?? 0} / {potential?.due_within_7_days ?? 0}</div>
        </div>
      </section>

      {/* Runway alerts */}
      <section>
        <h2 className="text-xl font-semibold text-slate-900 mb-2">Runway Alerts (&lt;= 6 months)</h2>
        <DataTable
          rows={runwayAlerts}
          columns={runwayColumns}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as RunwayAlert).category ?? i)}
        />
      </section>

      {/* Categories */}
      <section>
        <h2 className="text-xl font-semibold text-slate-900 mb-2">Category Burn Detail</h2>
        <DataTable
          rows={categories}
          columns={catColumns}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Category).id ?? i)}
        />
      </section>

      {/* Top overspend + Severity side-by-side */}
      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <h2 className="text-xl font-semibold text-slate-900 mb-2">Top Overspend</h2>
          <DataTable
            rows={overspend}
            columns={overspendColumns}
            emptyMessage="No data"
            rowKey={(r, i) => String((r as Overspend).category ?? i)}
          />
        </div>
        <div>
          <h2 className="text-xl font-semibold text-slate-900 mb-2">Severity Breakdown</h2>
          <DataTable
            rows={severity}
            columns={sevColumns}
            emptyMessage="No data"
            rowKey={(r, i) => String((r as SeverityRow).severity ?? i)}
          />
        </div>
      </section>

      {/* Actions */}
      <section>
        <h2 className="text-xl font-semibold text-slate-900 mb-2">Action Items</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Action).id ?? i)}
        />
      </section>

      {/* Action status rollup */}
      <section>
        <h2 className="text-xl font-semibold text-slate-900 mb-2">Actions by Status</h2>
        <DataTable
          rows={actionStatus}
          columns={actionStatusColumns}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as ActionStatusRow).status ?? i)}
        />
      </section>
    </div>
  );
}
