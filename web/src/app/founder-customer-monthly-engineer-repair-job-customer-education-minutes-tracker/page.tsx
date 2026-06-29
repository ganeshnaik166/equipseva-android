import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TopCustomer = { customer_org_name: string; total_minutes: number; total_jobs: number };
type TopicRow = { topic: string; total_minutes: number; sessions: number };
type EngRow = { engineer_handle: string; total_minutes: number; customers_touched: number; avg_csat: number };
type ModeRow = { delivery_mode: string; sessions: number; minutes: number };
type StatusRow = { status: string; sessions: number; minutes: number };
type TierRow = { tier_band: string; customers: number; total_minutes: number; avg_csat: number };
type MomRow = { month_label: string; total_minutes: number; total_jobs: number; customers: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [a, b, c, d, e, f, g] = await Promise.all([
    supabase.rpc('r2936_top_customers_by_minutes'),
    supabase.rpc('r2936_minutes_by_topic'),
    supabase.rpc('r2936_engineer_leaderboard'),
    supabase.rpc('r2936_delivery_mode_breakdown'),
    supabase.rpc('r2936_status_funnel'),
    supabase.rpc('r2936_tier_band_rollup'),
    supabase.rpc('r2936_month_over_month'),
  ]);

  const topCustomers = (a.data ?? []) as TopCustomer[];
  const topics = (b.data ?? []) as TopicRow[];
  const engineers = (c.data ?? []) as EngRow[];
  const modes = (d.data ?? []) as ModeRow[];
  const statuses = (e.data ?? []) as StatusRow[];
  const tiers = (f.data ?? []) as TierRow[];
  const mom = (g.data ?? []) as MomRow[];

  const topCols: Column<TopCustomer>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r) => r.customer_org_name },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'total_jobs', header: 'Jobs', render: (r) => r.total_jobs },
  ];
  const topicCols: Column<TopicRow>[] = [
    { key: 'topic', header: 'Topic', render: (r) => r.topic },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'sessions', header: 'Sessions', render: (r) => r.sessions },
  ];
  const engCols: Column<EngRow>[] = [
    { key: 'engineer_handle', header: 'Engineer', render: (r) => r.engineer_handle },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'customers_touched', header: 'Customers', render: (r) => r.customers_touched },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r) => r.avg_csat },
  ];
  const modeCols: Column<ModeRow>[] = [
    { key: 'delivery_mode', header: 'Mode', render: (r) => r.delivery_mode },
    { key: 'sessions', header: 'Sessions', render: (r) => r.sessions },
    { key: 'minutes', header: 'Minutes', render: (r) => r.minutes },
  ];
  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'sessions', header: 'Sessions', render: (r) => r.sessions },
    { key: 'minutes', header: 'Minutes', render: (r) => r.minutes },
  ];
  const tierCols: Column<TierRow>[] = [
    { key: 'tier_band', header: 'Tier', render: (r) => r.tier_band },
    { key: 'customers', header: 'Customers', render: (r) => r.customers },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r) => r.avg_csat },
  ];
  const momCols: Column<MomRow>[] = [
    { key: 'month_label', header: 'Month', render: (r) => r.month_label },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'total_jobs', header: 'Jobs', render: (r) => r.total_jobs },
    { key: 'customers', header: 'Customers', render: (r) => r.customers },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Engineer Repair-Job Education Minutes Tracker</h1>
        <p className="text-sm text-gray-600">Engineer-led education minutes attached to repair jobs — rolled up per customer per month.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top customers by minutes (current month)</h2>
        <DataTable rows={topCustomers} columns={topCols} emptyMessage="No customers yet" rowKey={(r, i) => String(r.customer_org_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Minutes by topic</h2>
        <DataTable rows={topics} columns={topicCols} emptyMessage="No topics" rowKey={(r, i) => String(r.topic ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer leaderboard</h2>
        <DataTable rows={engineers} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_handle ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Delivery mode breakdown</h2>
        <DataTable rows={modes} columns={modeCols} emptyMessage="No data" rowKey={(r, i) => String(r.delivery_mode ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable rows={statuses} columns={statusCols} emptyMessage="No data" rowKey={(r, i) => String(r.status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier band rollup</h2>
        <DataTable rows={tiers} columns={tierCols} emptyMessage="No tiers" rowKey={(r, i) => String(r.tier_band ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Month over month</h2>
        <DataTable rows={mom} columns={momCols} emptyMessage="No history" rowKey={(r, i) => String(r.month_label ?? i)} />
      </section>
    </div>
  );
}
