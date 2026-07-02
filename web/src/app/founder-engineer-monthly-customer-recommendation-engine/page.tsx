import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_recommendations: number;
  promote_count: number;
  hold_count: number;
  review_count: number;
  retire_count: number;
  avg_match_score: number;
  avg_satisfaction: number;
  total_expected_revenue: number;
  total_repeat_jobs: number;
};

type PromotionRow = {
  engineer_code: string;
  engineer_name: string;
  engineer_tier: string;
  customer_name: string;
  customer_segment: string;
  city: string;
  match_score: number;
  satisfaction_score: number;
  repeat_jobs_count: number;
  expected_revenue_rupees: number;
};

type QueueRow = {
  engineer_code: string;
  engineer_name: string;
  customer_name: string;
  promote_action: string;
  match_score: number;
  satisfaction_score: number;
  recommendation_reason: string;
};

type SegmentRow = {
  customer_segment: string;
  pair_count: number;
  avg_match: number;
  avg_csat: number;
  total_revenue: number;
};

type TierRow = {
  engineer_tier: string;
  engineer_count: number;
  avg_match: number;
  avg_csat: number;
  total_repeat_jobs: number;
};

type ActionRow = {
  engineer_code: string;
  customer_code: string;
  action_type: string;
  action_status: string;
  acted_by: string;
  acted_at: string;
  notes: string | null;
};

type CityRow = {
  city: string;
  pair_count: number;
  avg_match: number;
  avg_csat: number;
  total_revenue: number;
};

type TrendRow = {
  month_start: string;
  pair_count: number;
  promote_count: number;
  avg_match: number;
  total_revenue: number;
};

function formatRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, topRes, queueRes, segRes, tierRes, actionsRes, cityRes, trendRes] = await Promise.all([
    supabase.rpc('founder_engineer_recommendation_kpis_r2818'),
    supabase.rpc('founder_engineer_top_promotions_r2818'),
    supabase.rpc('founder_engineer_action_queue_r2818'),
    supabase.rpc('founder_engineer_segment_breakdown_r2818'),
    supabase.rpc('founder_engineer_tier_breakdown_r2818'),
    supabase.rpc('founder_engineer_recent_actions_r2818'),
    supabase.rpc('founder_engineer_city_performance_r2818'),
    supabase.rpc('founder_engineer_mom_trend_r2818'),
  ]);

  const kpi: KpiRow | null = (kpiRes.data?.[0] as KpiRow) ?? null;
  const top: PromotionRow[] = (topRes.data as PromotionRow[]) ?? [];
  const queue: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];
  const segments: SegmentRow[] = (segRes.data as SegmentRow[]) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const cities: CityRow[] = (cityRes.data as CityRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Monthly Customer Recommendation Engine</h1>
        <p className="text-sm text-neutral-600">
          Engineer × customer pairs ranked by match score, satisfaction, and repeat history. Promote, hold, review, or retire each pairing.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <KpiCard label="Total Pairs" value={kpi ? String(kpi.total_recommendations) : '-'} />
        <KpiCard label="Promote" value={kpi ? String(kpi.promote_count) : '-'} />
        <KpiCard label="Hold" value={kpi ? String(kpi.hold_count) : '-'} />
        <KpiCard label="Review" value={kpi ? String(kpi.review_count) : '-'} />
        <KpiCard label="Retire" value={kpi ? String(kpi.retire_count) : '-'} />
        <KpiCard label="Avg Match" value={kpi ? String(kpi.avg_match_score) : '-'} />
        <KpiCard label="Avg CSAT" value={kpi ? String(kpi.avg_satisfaction) : '-'} />
        <KpiCard label="Expected Revenue" value={kpi ? formatRupees(kpi.total_expected_revenue) : '-'} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Promotions (match score &gt;= 85)</h2>
        <DataTable
          rows={top}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: PromotionRow) => r.engineer_code + ' - ' + r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: PromotionRow) => r.engineer_tier },
            { key: 'customer_name', header: 'Customer', render: (r: PromotionRow) => r.customer_name },
            { key: 'customer_segment', header: 'Segment', render: (r: PromotionRow) => r.customer_segment },
            { key: 'city', header: 'City', render: (r: PromotionRow) => r.city },
            { key: 'match_score', header: 'Match', render: (r: PromotionRow) => String(r.match_score) },
            { key: 'satisfaction_score', header: 'CSAT', render: (r: PromotionRow) => String(r.satisfaction_score) },
            { key: 'repeat_jobs_count', header: 'Repeats', render: (r: PromotionRow) => String(r.repeat_jobs_count) },
            { key: 'expected_revenue_rupees', header: 'Expected Rev', render: (r: PromotionRow) => formatRupees(r.expected_revenue_rupees) },
          ]}
          emptyMessage="No promotions"
          rowKey={(r: PromotionRow, i: number) => String(r.engineer_code + '-' + r.customer_name + '-' + i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Action Queue (hold & review & retire)</h2>
        <DataTable
          rows={queue}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: QueueRow) => r.engineer_code + ' - ' + r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: QueueRow) => r.customer_name },
            { key: 'promote_action', header: 'Action', render: (r: QueueRow) => r.promote_action },
            { key: 'match_score', header: 'Match', render: (r: QueueRow) => String(r.match_score) },
            { key: 'satisfaction_score', header: 'CSAT', render: (r: QueueRow) => String(r.satisfaction_score) },
            { key: 'recommendation_reason', header: 'Reason', render: (r: QueueRow) => r.recommendation_reason },
          ]}
          emptyMessage="No queue items"
          rowKey={(r: QueueRow, i: number) => String(r.engineer_code + '-' + i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Segment Breakdown</h2>
          <DataTable
            rows={segments}
            columns={[
              { key: 'customer_segment', header: 'Segment', render: (r: SegmentRow) => r.customer_segment },
              { key: 'pair_count', header: 'Pairs', render: (r: SegmentRow) => String(r.pair_count) },
              { key: 'avg_match', header: 'Avg Match', render: (r: SegmentRow) => String(r.avg_match) },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: SegmentRow) => String(r.avg_csat) },
              { key: 'total_revenue', header: 'Revenue', render: (r: SegmentRow) => formatRupees(r.total_revenue) },
            ]}
            emptyMessage="No segments"
            rowKey={(r: SegmentRow, i: number) => String(r.customer_segment + '-' + i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Tier Breakdown</h2>
          <DataTable
            rows={tiers}
            columns={[
              { key: 'engineer_tier', header: 'Tier', render: (r: TierRow) => r.engineer_tier },
              { key: 'engineer_count', header: 'Engineers', render: (r: TierRow) => String(r.engineer_count) },
              { key: 'avg_match', header: 'Avg Match', render: (r: TierRow) => String(r.avg_match) },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: TierRow) => String(r.avg_csat) },
              { key: 'total_repeat_jobs', header: 'Repeats', render: (r: TierRow) => String(r.total_repeat_jobs) },
            ]}
            emptyMessage="No tiers"
            rowKey={(r: TierRow, i: number) => String(r.engineer_tier + '-' + i)}
          />
        </div>
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-semibold">City Performance</h2>
          <DataTable
            rows={cities}
            columns={[
              { key: 'city', header: 'City', render: (r: CityRow) => r.city },
              { key: 'pair_count', header: 'Pairs', render: (r: CityRow) => String(r.pair_count) },
              { key: 'avg_match', header: 'Avg Match', render: (r: CityRow) => String(r.avg_match) },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: CityRow) => String(r.avg_csat) },
              { key: 'total_revenue', header: 'Revenue', render: (r: CityRow) => formatRupees(r.total_revenue) },
            ]}
            emptyMessage="No cities"
            rowKey={(r: CityRow, i: number) => String(r.city + '-' + i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-semibold">Month-over-Month Trend</h2>
          <DataTable
            rows={trend}
            columns={[
              { key: 'month_start', header: 'Month', render: (r: TrendRow) => String(r.month_start) },
              { key: 'pair_count', header: 'Pairs', render: (r: TrendRow) => String(r.pair_count) },
              { key: 'promote_count', header: 'Promotes', render: (r: TrendRow) => String(r.promote_count) },
              { key: 'avg_match', header: 'Avg Match', render: (r: TrendRow) => String(r.avg_match) },
              { key: 'total_revenue', header: 'Revenue', render: (r: TrendRow) => formatRupees(r.total_revenue) },
            ]}
            emptyMessage="No trend data"
            rowKey={(r: TrendRow, i: number) => String(r.month_start + '-' + i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Promote Actions</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: ActionRow) => r.engineer_code },
            { key: 'customer_code', header: 'Customer', render: (r: ActionRow) => r.customer_code },
            { key: 'action_type', header: 'Action', render: (r: ActionRow) => r.action_type },
            { key: 'action_status', header: 'Status', render: (r: ActionRow) => r.action_status },
            { key: 'acted_by', header: 'By', render: (r: ActionRow) => r.acted_by },
            { key: 'acted_at', header: 'At', render: (r: ActionRow) => new Date(r.acted_at).toLocaleString('en-IN') },
            { key: 'notes', header: 'Notes', render: (r: ActionRow) => r.notes ?? '-' },
          ]}
          emptyMessage="No actions"
          rowKey={(r: ActionRow, i: number) => String(r.engineer_code + '-' + r.customer_code + '-' + i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-neutral-900">{value}</div>
    </div>
  );
}
