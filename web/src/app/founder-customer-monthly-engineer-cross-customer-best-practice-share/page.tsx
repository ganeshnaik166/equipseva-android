import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_shares: number;
  adopted_shares: number;
  fleetwide_count: number;
  avg_lift: number | null;
  top_engineer: string | null;
};

type ShareRow = {
  month_label: string;
  engineer_name: string;
  insight_title: string;
  insight_category: string;
  from_customer: string;
  to_customer: string;
  adoption_status: string;
  lift_percent: number;
  verdict: string;
  notes: string | null;
};

type LeaderRow = {
  engineer_name: string;
  shares_attempted: number;
  shares_adopted: number;
  adoption_rate: number | null;
  avg_lift: number | null;
  fleetwide_replications: number;
};

type CategoryRow = {
  insight_category: string;
  total: number;
  adopted: number;
  avg_lift: number | null;
};

type VerdictRow = {
  verdict: string;
  total: number;
  pct: number | null;
};

type TopLiftRow = {
  engineer_name: string;
  insight_title: string;
  from_customer: string;
  to_customer: string;
  lift_percent: number;
  verdict: string;
};

type RejectedRow = {
  engineer_name: string;
  insight_title: string;
  from_customer: string;
  to_customer: string;
  lift_percent: number;
  verdict: string;
  notes: string | null;
};

type TrendRow = {
  month_label: string;
  total_shares: number;
  total_adopted: number;
  avg_lift: number | null;
  fleetwide: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, sharesRes, leaderRes, categoryRes, verdictRes, topLiftRes, rejectedRes, trendRes] = await Promise.all([
    supabase.rpc('r2832_summary_kpis'),
    supabase.rpc('r2832_shares_list'),
    supabase.rpc('r2832_engineer_leaderboard'),
    supabase.rpc('r2832_category_breakdown'),
    supabase.rpc('r2832_verdict_mix'),
    supabase.rpc('r2832_top_lifts', { p_limit: 5 }),
    supabase.rpc('r2832_rejected_or_killed'),
    supabase.rpc('r2832_monthly_trend'),
  ]);

  const kpi: Kpi | null = (kpisRes.data as Kpi[] | null)?.[0] ?? null;
  const shares: ShareRow[] = (sharesRes.data as ShareRow[] | null) ?? [];
  const leaders: LeaderRow[] = (leaderRes.data as LeaderRow[] | null) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[] | null) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[] | null) ?? [];
  const topLifts: TopLiftRow[] = (topLiftRes.data as TopLiftRow[] | null) ?? [];
  const rejected: RejectedRow[] = (rejectedRes.data as RejectedRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Cross-Customer Best Practice Share — Engineer Monthly
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Engineer × insight × from customer × to customer × adoption × lift × verdict.
        Replicate winners fleetwide; kill losers fast.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        <KpiCard label="Total shares" value={kpi?.total_shares ?? 0} />
        <KpiCard label="Adopted" value={kpi?.adopted_shares ?? 0} />
        <KpiCard label="Fleetwide verdicts" value={kpi?.fleetwide_count ?? 0} />
        <KpiCard label="Avg lift %" value={kpi?.avg_lift ?? 0} />
        <KpiCard label="Top engineer" value={kpi?.top_engineer ?? '-'} />
      </div>

      <Section title="All shares (most recent first)">
        <DataTable
          rows={shares}
          columns={[
            { key: 'month_label', header: 'Month', render: (r: ShareRow) => r.month_label },
            { key: 'engineer_name', header: 'Engineer', render: (r: ShareRow) => r.engineer_name },
            { key: 'insight_title', header: 'Insight', render: (r: ShareRow) => r.insight_title },
            { key: 'insight_category', header: 'Category', render: (r: ShareRow) => r.insight_category },
            { key: 'from_customer', header: 'From', render: (r: ShareRow) => r.from_customer },
            { key: 'to_customer', header: 'To', render: (r: ShareRow) => r.to_customer },
            { key: 'adoption_status', header: 'Adoption', render: (r: ShareRow) => r.adoption_status },
            { key: 'lift_percent', header: 'Lift %', render: (r: ShareRow) => String(r.lift_percent) },
            { key: 'verdict', header: 'Verdict', render: (r: ShareRow) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r: ShareRow) => r.notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: ShareRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Engineer leaderboard (sorted by fleetwide replications)">
        <DataTable
          rows={leaders}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: LeaderRow) => r.engineer_name },
            { key: 'shares_attempted', header: 'Attempted', render: (r: LeaderRow) => String(r.shares_attempted) },
            { key: 'shares_adopted', header: 'Adopted', render: (r: LeaderRow) => String(r.shares_adopted) },
            { key: 'adoption_rate', header: 'Adoption %', render: (r: LeaderRow) => String(r.adoption_rate ?? 0) },
            { key: 'avg_lift', header: 'Avg lift %', render: (r: LeaderRow) => String(r.avg_lift ?? 0) },
            { key: 'fleetwide_replications', header: 'Fleetwide', render: (r: LeaderRow) => String(r.fleetwide_replications) },
          ]}
          emptyMessage="No data"
          rowKey={(r: LeaderRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Category breakdown">
        <DataTable
          rows={categories}
          columns={[
            { key: 'insight_category', header: 'Category', render: (r: CategoryRow) => r.insight_category },
            { key: 'total', header: 'Total', render: (r: CategoryRow) => String(r.total) },
            { key: 'adopted', header: 'Adopted', render: (r: CategoryRow) => String(r.adopted) },
            { key: 'avg_lift', header: 'Avg lift %', render: (r: CategoryRow) => String(r.avg_lift ?? 0) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Verdict mix">
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'total', header: 'Count', render: (r: VerdictRow) => String(r.total) },
            { key: 'pct', header: 'Share %', render: (r: VerdictRow) => String(r.pct ?? 0) },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Top lifts (adopted only)">
        <DataTable
          rows={topLifts}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: TopLiftRow) => r.engineer_name },
            { key: 'insight_title', header: 'Insight', render: (r: TopLiftRow) => r.insight_title },
            { key: 'from_customer', header: 'From', render: (r: TopLiftRow) => r.from_customer },
            { key: 'to_customer', header: 'To', render: (r: TopLiftRow) => r.to_customer },
            { key: 'lift_percent', header: 'Lift %', render: (r: TopLiftRow) => String(r.lift_percent) },
            { key: 'verdict', header: 'Verdict', render: (r: TopLiftRow) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopLiftRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Rejected or killed (learn fast)">
        <DataTable
          rows={rejected}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: RejectedRow) => r.engineer_name },
            { key: 'insight_title', header: 'Insight', render: (r: RejectedRow) => r.insight_title },
            { key: 'from_customer', header: 'From', render: (r: RejectedRow) => r.from_customer },
            { key: 'to_customer', header: 'To', render: (r: RejectedRow) => r.to_customer },
            { key: 'lift_percent', header: 'Lift %', render: (r: RejectedRow) => String(r.lift_percent) },
            { key: 'verdict', header: 'Verdict', render: (r: RejectedRow) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r: RejectedRow) => r.notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: RejectedRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Monthly trend">
        <DataTable
          rows={trend}
          columns={[
            { key: 'month_label', header: 'Month', render: (r: TrendRow) => r.month_label },
            { key: 'total_shares', header: 'Attempted', render: (r: TrendRow) => String(r.total_shares) },
            { key: 'total_adopted', header: 'Adopted', render: (r: TrendRow) => String(r.total_adopted) },
            { key: 'avg_lift', header: 'Avg lift %', render: (r: TrendRow) => String(r.avg_lift ?? 0) },
            { key: 'fleetwide', header: 'Fleetwide', render: (r: TrendRow) => String(r.fleetwide) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TrendRow, i: number) => String(i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px' }}>
      <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{label}</div>
      <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '32px' }}>
      <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>{title}</h2>
      {children}
    </section>
  );
}
