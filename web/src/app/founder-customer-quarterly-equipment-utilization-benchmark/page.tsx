import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_customers: number;
  total_equipment_lines: number;
  avg_our_util_pct: number;
  avg_peer_benchmark_pct: number;
  total_gap_pct: number;
  total_revenue_lost_rupees: number;
  critical_lines: number;
  red_lines: number;
};

type CustomerRow = {
  customer_org_name: string;
  customer_tier: string;
  equipment_lines: number;
  avg_our_util_pct: number;
  avg_peer_pct: number;
  total_gap_pct: number;
  revenue_lost_rupees: number;
  worst_severity: string;
};

type CategoryRow = {
  equipment_category: string;
  lines: number;
  avg_our_util_pct: number;
  avg_peer_pct: number;
  avg_top_decile_pct: number;
  total_gap_pct: number;
  revenue_lost_rupees: number;
};

type LineRow = {
  id: string;
  quarter_label: string;
  customer_org_name: string;
  customer_tier: string;
  equipment_category: string;
  equipment_model: string;
  units_deployed: number;
  our_util_pct: number;
  peer_benchmark_pct: number;
  top_decile_pct: number;
  utilization_gap_pct: number;
  gap_severity: string;
  revenue_lost_rupees: number;
};

type ActionRow = {
  id: string;
  customer_org_name: string;
  equipment_model: string;
  root_cause_category: string;
  cause_summary: string;
  close_action: string;
  action_owner: string;
  action_owner_role: string;
  expected_uplift_pct: number;
  due_date: string;
  status: string;
  expected_revenue_recovered_rupees: number;
};

type CauseRow = {
  root_cause_category: string;
  actions: number;
  avg_expected_uplift_pct: number;
  expected_revenue_recovered_rupees: number;
  closed_actions: number;
  at_risk_actions: number;
};

type SeverityRow = {
  gap_severity: string;
  lines: number;
  avg_gap_pct: number;
  revenue_lost_rupees: number;
};

type RecoveryRow = {
  customer_org_name: string;
  equipment_model: string;
  utilization_gap_pct: number;
  revenue_lost_rupees: number;
  close_action: string;
  expected_uplift_pct: number;
  expected_revenue_recovered_rupees: number;
  due_date: string;
  status: string;
};

function fmtInr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  return (Number(n ?? 0)).toFixed(2) + '%';
}

function sevBadge(sev: string): string {
  switch (sev) {
    case 'critical': return 'bg-red-700 text-white';
    case 'red': return 'bg-red-500 text-white';
    case 'amber': return 'bg-amber-400 text-black';
    case 'green': return 'bg-emerald-500 text-white';
    default: return 'bg-gray-300 text-black';
  }
}

function statusBadge(s: string): string {
  switch (s) {
    case 'closed': return 'bg-emerald-500 text-white';
    case 'in_progress': return 'bg-blue-500 text-white';
    case 'planned': return 'bg-gray-400 text-white';
    case 'at_risk': return 'bg-amber-500 text-white';
    case 'blocked': return 'bg-red-600 text-white';
    default: return 'bg-gray-300 text-black';
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, custRes, catRes, lineRes, actRes, causeRes, sevRes, recRes] = await Promise.all([
    supabase.rpc('founder_util_benchmark_kpis_r2700'),
    supabase.rpc('founder_util_by_customer_r2700'),
    supabase.rpc('founder_util_by_category_r2700'),
    supabase.rpc('founder_util_lines_r2700'),
    supabase.rpc('founder_util_actions_r2700'),
    supabase.rpc('founder_util_cause_rollup_r2700'),
    supabase.rpc('founder_util_severity_rollup_r2700'),
    supabase.rpc('founder_util_top_recovery_r2700'),
  ]);

  const kpi: Kpi = (Array.isArray(kpiRes.data) ? kpiRes.data[0] : kpiRes.data) ?? {
    total_customers: 0,
    total_equipment_lines: 0,
    avg_our_util_pct: 0,
    avg_peer_benchmark_pct: 0,
    total_gap_pct: 0,
    total_revenue_lost_rupees: 0,
    critical_lines: 0,
    red_lines: 0,
  };

  const customers: CustomerRow[] = (custRes.data as CustomerRow[]) ?? [];
  const categories: CategoryRow[] = (catRes.data as CategoryRow[]) ?? [];
  const lines: LineRow[] = (lineRes.data as LineRow[]) ?? [];
  const actions: ActionRow[] = (actRes.data as ActionRow[]) ?? [];
  const causes: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const severities: SeverityRow[] = (sevRes.data as SeverityRow[]) ?? [];
  const recoveries: RecoveryRow[] = (recRes.data as RecoveryRow[]) ?? [];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">Quarterly Equipment Utilization Benchmark</h1>
        <p className="text-sm text-gray-600">
          Per-customer per-equipment utilization vs peer benchmark and top-decile, with root cause and close action. Revenue lost = peer-gap × book rate.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Customers" value={String(kpi.total_customers)} />
        <KpiCard label="Equipment Lines" value={String(kpi.total_equipment_lines)} />
        <KpiCard label="Our Util Avg" value={fmtPct(kpi.avg_our_util_pct)} />
        <KpiCard label="Peer Benchmark Avg" value={fmtPct(kpi.avg_peer_benchmark_pct)} />
        <KpiCard label="Total Gap Avg" value={fmtPct(kpi.total_gap_pct)} tone="warn" />
        <KpiCard label="Revenue Lost" value={fmtInr(kpi.total_revenue_lost_rupees)} tone="bad" />
        <KpiCard label="Critical Lines" value={String(kpi.critical_lines)} tone="bad" />
        <KpiCard label="Red Lines" value={String(kpi.red_lines)} tone="warn" />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">By Customer (revenue lost desc)</h2>
        <DataTable
          rows={customers}
          rowKey={(r, i) => String((r as CustomerRow).customer_org_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r) => <span className="font-medium">{(r as CustomerRow).customer_org_name}</span> },
            { key: 'customer_tier', header: 'Tier', render: (r) => <span className="uppercase text-xs">{(r as CustomerRow).customer_tier}</span> },
            { key: 'equipment_lines', header: 'Lines', render: (r) => (r as CustomerRow).equipment_lines },
            { key: 'avg_our_util_pct', header: 'Our Util', render: (r) => fmtPct((r as CustomerRow).avg_our_util_pct) },
            { key: 'avg_peer_pct', header: 'Peer', render: (r) => fmtPct((r as CustomerRow).avg_peer_pct) },
            { key: 'total_gap_pct', header: 'Total Gap', render: (r) => fmtPct((r as CustomerRow).total_gap_pct) },
            { key: 'revenue_lost_rupees', header: 'Revenue Lost', render: (r) => fmtInr((r as CustomerRow).revenue_lost_rupees) },
            { key: 'worst_severity', header: 'Worst', render: (r) => <span className={'px-2 py-0.5 text-xs rounded ' + sevBadge((r as CustomerRow).worst_severity)}>{(r as CustomerRow).worst_severity}</span> },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">By Equipment Category</h2>
        <DataTable
          rows={categories}
          rowKey={(r, i) => String((r as CategoryRow).equipment_category ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r) => <span className="font-medium">{(r as CategoryRow).equipment_category}</span> },
            { key: 'lines', header: 'Lines', render: (r) => (r as CategoryRow).lines },
            { key: 'avg_our_util_pct', header: 'Our Util', render: (r) => fmtPct((r as CategoryRow).avg_our_util_pct) },
            { key: 'avg_peer_pct', header: 'Peer', render: (r) => fmtPct((r as CategoryRow).avg_peer_pct) },
            { key: 'avg_top_decile_pct', header: 'Top Decile', render: (r) => fmtPct((r as CategoryRow).avg_top_decile_pct) },
            { key: 'total_gap_pct', header: 'Gap', render: (r) => fmtPct((r as CategoryRow).total_gap_pct) },
            { key: 'revenue_lost_rupees', header: 'Revenue Lost', render: (r) => fmtInr((r as CategoryRow).revenue_lost_rupees) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Severity Breakdown</h2>
        <DataTable
          rows={severities}
          rowKey={(r, i) => String((r as SeverityRow).gap_severity ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'gap_severity', header: 'Severity', render: (r) => <span className={'px-2 py-0.5 text-xs rounded ' + sevBadge((r as SeverityRow).gap_severity)}>{(r as SeverityRow).gap_severity}</span> },
            { key: 'lines', header: 'Lines', render: (r) => (r as SeverityRow).lines },
            { key: 'avg_gap_pct', header: 'Avg Gap', render: (r) => fmtPct((r as SeverityRow).avg_gap_pct) },
            { key: 'revenue_lost_rupees', header: 'Revenue Lost', render: (r) => fmtInr((r as SeverityRow).revenue_lost_rupees) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Equipment Lines (gap ascending)</h2>
        <DataTable
          rows={lines}
          rowKey={(r, i) => String((r as LineRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'quarter_label', header: 'Qtr', render: (r) => (r as LineRow).quarter_label },
            { key: 'customer_org_name', header: 'Customer', render: (r) => (r as LineRow).customer_org_name },
            { key: 'equipment_model', header: 'Equipment', render: (r) => <span className="text-xs">{(r as LineRow).equipment_model}</span> },
            { key: 'units_deployed', header: 'Units', render: (r) => (r as LineRow).units_deployed },
            { key: 'our_util_pct', header: 'Ours', render: (r) => fmtPct((r as LineRow).our_util_pct) },
            { key: 'peer_benchmark_pct', header: 'Peer', render: (r) => fmtPct((r as LineRow).peer_benchmark_pct) },
            { key: 'top_decile_pct', header: 'Top10%', render: (r) => fmtPct((r as LineRow).top_decile_pct) },
            { key: 'utilization_gap_pct', header: 'Gap', render: (r) => fmtPct((r as LineRow).utilization_gap_pct) },
            { key: 'gap_severity', header: 'Sev', render: (r) => <span className={'px-2 py-0.5 text-xs rounded ' + sevBadge((r as LineRow).gap_severity)}>{(r as LineRow).gap_severity}</span> },
            { key: 'revenue_lost_rupees', header: 'Lost', render: (r) => fmtInr((r as LineRow).revenue_lost_rupees) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Root Cause Rollup</h2>
        <DataTable
          rows={causes}
          rowKey={(r, i) => String((r as CauseRow).root_cause_category ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'root_cause_category', header: 'Cause', render: (r) => <span className="font-medium">{(r as CauseRow).root_cause_category}</span> },
            { key: 'actions', header: 'Actions', render: (r) => (r as CauseRow).actions },
            { key: 'avg_expected_uplift_pct', header: 'Avg Uplift', render: (r) => fmtPct((r as CauseRow).avg_expected_uplift_pct) },
            { key: 'expected_revenue_recovered_rupees', header: 'Recoverable', render: (r) => fmtInr((r as CauseRow).expected_revenue_recovered_rupees) },
            { key: 'closed_actions', header: 'Closed', render: (r) => (r as CauseRow).closed_actions },
            { key: 'at_risk_actions', header: 'At Risk', render: (r) => (r as CauseRow).at_risk_actions },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Top Recovery Opportunities</h2>
        <DataTable
          rows={recoveries}
          rowKey={(r, i) => String(((r as RecoveryRow).customer_org_name ?? '') + '|' + ((r as RecoveryRow).equipment_model ?? i))}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r) => (r as RecoveryRow).customer_org_name },
            { key: 'equipment_model', header: 'Equipment', render: (r) => <span className="text-xs">{(r as RecoveryRow).equipment_model}</span> },
            { key: 'utilization_gap_pct', header: 'Gap', render: (r) => fmtPct((r as RecoveryRow).utilization_gap_pct) },
            { key: 'revenue_lost_rupees', header: 'Lost', render: (r) => fmtInr((r as RecoveryRow).revenue_lost_rupees) },
            { key: 'close_action', header: 'Close Action', render: (r) => <span className="text-xs">{(r as RecoveryRow).close_action}</span> },
            { key: 'expected_uplift_pct', header: 'Uplift', render: (r) => fmtPct((r as RecoveryRow).expected_uplift_pct) },
            { key: 'expected_revenue_recovered_rupees', header: 'Recoverable', render: (r) => fmtInr((r as RecoveryRow).expected_revenue_recovered_rupees) },
            { key: 'due_date', header: 'Due', render: (r) => (r as RecoveryRow).due_date },
            { key: 'status', header: 'Status', render: (r) => <span className={'px-2 py-0.5 text-xs rounded ' + statusBadge((r as RecoveryRow).status)}>{(r as RecoveryRow).status}</span> },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">All Actions (due date asc)</h2>
        <DataTable
          rows={actions}
          rowKey={(r, i) => String((r as ActionRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r) => (r as ActionRow).customer_org_name },
            { key: 'equipment_model', header: 'Equipment', render: (r) => <span className="text-xs">{(r as ActionRow).equipment_model}</span> },
            { key: 'root_cause_category', header: 'Cause', render: (r) => (r as ActionRow).root_cause_category },
            { key: 'cause_summary', header: 'Cause Detail', render: (r) => <span className="text-xs">{(r as ActionRow).cause_summary}</span> },
            { key: 'close_action', header: 'Action', render: (r) => <span className="text-xs">{(r as ActionRow).close_action}</span> },
            { key: 'action_owner', header: 'Owner', render: (r) => (r as ActionRow).action_owner },
            { key: 'action_owner_role', header: 'Role', render: (r) => <span className="uppercase text-xs">{(r as ActionRow).action_owner_role}</span> },
            { key: 'expected_uplift_pct', header: 'Uplift', render: (r) => fmtPct((r as ActionRow).expected_uplift_pct) },
            { key: 'expected_revenue_recovered_rupees', header: 'Recover', render: (r) => fmtInr((r as ActionRow).expected_revenue_recovered_rupees) },
            { key: 'due_date', header: 'Due', render: (r) => (r as ActionRow).due_date },
            { key: 'status', header: 'Status', render: (r) => <span className={'px-2 py-0.5 text-xs rounded ' + statusBadge((r as ActionRow).status)}>{(r as ActionRow).status}</span> },
          ]}
        />
      </section>

      <footer className="text-xs text-gray-500 pt-6 border-t">
        Round r2700 · Source: customer_equipment_util_benchmark_r2700 + util_gap_cause_action_r2700 · Gaps shown as our_util minus peer_benchmark. Negative gap means below peer.
      </footer>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'good' | 'warn' | 'bad' }) {
  const toneCls = tone === 'bad' ? 'border-red-300 bg-red-50' : tone === 'warn' ? 'border-amber-300 bg-amber-50' : tone === 'good' ? 'border-emerald-300 bg-emerald-50' : 'border-gray-200 bg-white';
  return (
    <div className={'rounded-xl border p-4 ' + toneCls}>
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}
