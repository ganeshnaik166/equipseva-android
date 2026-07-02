import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerQuarterly360ReviewPage() {
  const supabase = await getSupabaseServerClient();

  const [reviewsRes, actionsRes, topRes, trackRes, completionRes, trendRes, loadRes] = await Promise.all([
    supabase.rpc('list_reviews_r2530'),
    supabase.rpc('list_action_items_r2530'),
    supabase.rpc('top_composite_engineers_r2530'),
    supabase.rpc('growth_track_distribution_r2530'),
    supabase.rpc('action_completion_rate_r2530'),
    supabase.rpc('quarterly_score_trend_r2530'),
    supabase.rpc('manager_load_r2530'),
  ]);

  const reviews = reviewsRes.data ?? [];
  const actions = actionsRes.data ?? [];
  const top = topRes.data ?? [];
  const track = trackRes.data ?? [];
  const completion = completionRes.data ?? [];
  const trend = trendRes.data ?? [];
  const load = loadRes.data ?? [];

  const reviewCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'growth_track', header: 'Track', render: (r: any) => r.growth_track },
    { key: 'composite_score', header: 'Composite', render: (r: any) => r.composite_score ?? '-' },
    { key: 'peer_score', header: 'Peer', render: (r: any) => r.peer_score ?? '-' },
    { key: 'hospital_score', header: 'Hospital', render: (r: any) => r.hospital_score ?? '-' },
    { key: 'self_score', header: 'Self', render: (r: any) => r.self_score ?? '-' },
    { key: 'manager_score', header: 'Manager', render: (r: any) => r.manager_score ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'growth_track', header: 'Track', render: (r: any) => r.growth_track },
    { key: 'composite_score', header: 'Composite', render: (r: any) => r.composite_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const trackCols: Column<any>[] = [
    { key: 'growth_track', header: 'Growth Track', render: (r: any) => r.growth_track },
    { key: 'review_count', header: 'Reviews', render: (r: any) => r.review_count },
    { key: 'avg_composite', header: 'Avg Composite', render: (r: any) => r.avg_composite ?? '-' },
  ];

  const completionCols: Column<any>[] = [
    { key: 'total_actions', header: 'Total', render: (r: any) => r.total_actions },
    { key: 'done_actions', header: 'Done', render: (r: any) => r.done_actions },
    { key: 'open_actions', header: 'Open', render: (r: any) => r.open_actions },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => `${r.completion_pct}%` },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'review_count', header: 'Reviews', render: (r: any) => r.review_count },
    { key: 'avg_composite', header: 'Composite', render: (r: any) => r.avg_composite ?? '-' },
    { key: 'avg_peer', header: 'Peer', render: (r: any) => r.avg_peer ?? '-' },
    { key: 'avg_hospital', header: 'Hospital', render: (r: any) => r.avg_hospital ?? '-' },
    { key: 'avg_self', header: 'Self', render: (r: any) => r.avg_self ?? '-' },
    { key: 'avg_manager', header: 'Manager', render: (r: any) => r.avg_manager ?? '-' },
  ];

  const loadCols: Column<any>[] = [
    { key: 'owner_email', header: 'Manager', render: (r: any) => r.owner_email },
    { key: 'review_count', header: 'Reviews', render: (r: any) => r.review_count },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
    { key: 'avg_composite', header: 'Avg Composite', render: (r: any) => r.avg_composite ?? '-' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Quarterly 360 Review</h1>
        <p className="text-sm text-gray-600">Peer & hospital & self & manager scores => composite => growth track => actionable feedback.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reviews</h2>
        <DataTable
          rows={reviews}
          columns={reviewCols}
          emptyMessage="No reviews yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Composite Engineers</h2>
        <DataTable
          rows={top}
          columns={topCols}
          emptyMessage="No top engineers yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Growth Track Distribution</h2>
        <DataTable
          rows={track}
          columns={trackCols}
          emptyMessage="No track data."
          rowKey={(r: any, i: number) => String(r.growth_track ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Score Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No quarters tracked."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Completion Rate</h2>
        <DataTable
          rows={completion}
          columns={completionCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Items</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No action items."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Manager Load</h2>
        <DataTable
          rows={load}
          columns={loadCols}
          emptyMessage="No managers tracked."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
