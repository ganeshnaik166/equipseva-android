import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = {
  id: string;
  chain_org_id: string;
  chain_name: string | null;
  site_count: number | null;
  total_active_amc: number | null;
  total_monthly_revenue_rupees: number | null;
  avg_satisfaction_score: number | null;
  aggregated_at: string | null;
};

type TopRow = {
  chain_org_id: string;
  chain_name: string | null;
  site_count: number | null;
  total_monthly_revenue_rupees: number | null;
  total_active_amc: number | null;
  aggregated_at: string | null;
};

type AtRiskRow = {
  chain_org_id: string;
  chain_name: string | null;
  at_risk_sites: number | null;
  churned_sites: number | null;
  total_sites: number | null;
  avg_satisfaction_score: number | null;
};

type RecentRow = {
  id: string;
  chain_org_id: string;
  chain_name: string | null;
  site_count: number | null;
  total_monthly_revenue_rupees: number | null;
  aggregated_at: string | null;
};

function fmtRupees(v: number | null | undefined) {
  if (v == null) return '—';
  return '₹' + Number(v).toLocaleString('en-IN');
}

function fmtDate(v: string | null | undefined) {
  if (!v) return '—';
  try {
    return new Date(v).toLocaleString('en-IN');
  } catch {
    return v;
  }
}

function fmtScore(v: number | null | undefined) {
  if (v == null) return '—';
  return Number(v).toFixed(2);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [chainsRes, topRes, atRiskRes, recentRes] = await Promise.all([
    sb.rpc('list_chains_r1755'),
    sb.rpc('top_chains_by_revenue_r1755'),
    sb.rpc('at_risk_chains_r1755'),
    sb.rpc('recent_aggregations_r1755'),
  ]);

  const chains: ChainRow[] = (chainsRes.data as ChainRow[] | null) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[] | null) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[] | null) ?? [];

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span>{r.chain_name ?? r.chain_org_id}</span> },
    { key: 'sites', header: 'Sites', render: (r: any) => <span>{r.site_count ?? 0}</span> },
    { key: 'amc', header: 'Active AMC', render: (r: any) => <span>{r.total_active_amc ?? 0}</span> },
    { key: 'rev', header: 'Monthly Revenue', render: (r: any) => <span>{fmtRupees(r.total_monthly_revenue_rupees)}</span> },
    { key: 'sat', header: 'Avg Satisfaction', render: (r: any) => <span>{fmtScore(r.avg_satisfaction_score)}</span> },
    { key: 'at', header: 'Aggregated', render: (r: any) => <span>{fmtDate(r.aggregated_at)}</span> },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span>{r.chain_name ?? r.chain_org_id}</span> },
    { key: 'sites', header: 'Sites', render: (r: any) => <span>{r.site_count ?? 0}</span> },
    { key: 'rev', header: 'Monthly Revenue', render: (r: any) => <strong>{fmtRupees(r.total_monthly_revenue_rupees)}</strong> },
    { key: 'amc', header: 'Active AMC', render: (r: any) => <span>{r.total_active_amc ?? 0}</span> },
    { key: 'at', header: 'Last Aggregated', render: (r: any) => <span>{fmtDate(r.aggregated_at)}</span> },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span>{r.chain_name ?? r.chain_org_id}</span> },
    { key: 'risk', header: 'At Risk Sites', render: (r: any) => <span style={{ color: '#b45309' }}>{r.at_risk_sites ?? 0}</span> },
    { key: 'churn', header: 'Churned Sites', render: (r: any) => <span style={{ color: '#b91c1c' }}>{r.churned_sites ?? 0}</span> },
    { key: 'total', header: 'Total Sites', render: (r: any) => <span>{r.total_sites ?? 0}</span> },
    { key: 'sat', header: 'Avg Satisfaction', render: (r: any) => <span>{fmtScore(r.avg_satisfaction_score)}</span> },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span>{r.chain_name ?? r.chain_org_id}</span> },
    { key: 'sites', header: 'Sites', render: (r: any) => <span>{r.site_count ?? 0}</span> },
    { key: 'rev', header: 'Monthly Revenue', render: (r: any) => <span>{fmtRupees(r.total_monthly_revenue_rupees)}</span> },
    { key: 'at', header: 'Aggregated', render: (r: any) => <span>{fmtDate(r.aggregated_at)}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Multi-Site Aggregator</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Roll up metrics across every site in a hospital chain. Track revenue, active AMC count, and satisfaction.
          Flag chains where one or more sites are at risk or churned.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top chains by monthly revenue</h2>
        <p className="text-sm text-[var(--color-muted)]">
          One row per chain, latest aggregate snapshot. Sorted by total monthly revenue.
        </p>
        <DataTable<TopRow>
          rows={top}
          columns={topCols}
          rowKey={(r: any, i) => String(r.chain_org_id ?? i)}
          emptyMessage="No chain aggregates yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">At-risk chains</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Chains with one or more sites in at_risk or churned status. Prioritize founder save calls here.
        </p>
        <DataTable<AtRiskRow>
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r: any, i) => String(r.chain_org_id ?? i)}
          emptyMessage="No at-risk chains."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All chain aggregates</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Most recent 200 chain-level aggregate snapshots across the network.
        </p>
        <DataTable<ChainRow>
          rows={chains}
          columns={chainCols}
          rowKey={(r: any, i) => String(r.id ?? i)}
          emptyMessage="No aggregates recorded."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent aggregations</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Last 50 aggregation events. Use to spot stale chains where aggregated_at is more than 7 days old.
        </p>
        <DataTable<RecentRow>
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i) => String(r.id ?? i)}
          emptyMessage="No recent aggregations."
        />
      </section>
    </div>
  );
}
