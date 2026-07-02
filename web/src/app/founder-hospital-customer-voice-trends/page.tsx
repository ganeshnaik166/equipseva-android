import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Trend = {
  id: string;
  trend_label: string;
  trend_category: string;
  signal_count: number;
  sentiment_avg: number | null;
  status: string;
  captured_at: string;
};

type Action = {
  id: string;
  trend_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [trendsRes, persistentRes, actionsRes] = await Promise.all([
    sb.rpc('list_trends_r2067'),
    sb.rpc('persistent_trends_r2067'),
    sb.rpc('recent_actions_r2067'),
  ]);

  const trends: Trend[] = (trendsRes.data as Trend[]) ?? [];
  const persistent: Trend[] = (persistentRes.data as Trend[]) ?? [];
  const actions: Action[] = (actionsRes.data as Action[]) ?? [];

  const trendCols: Column<Trend>[] = [
    { key: 'trend_label', header: 'Trend', render: (r: any) => r.trend_label },
    { key: 'trend_category', header: 'Category', render: (r: any) => r.trend_category },
    { key: 'signal_count', header: 'Signals', render: (r: any) => String(r.signal_count ?? 0) },
    { key: 'sentiment_avg', header: 'Sentiment', render: (r: any) => (r.sentiment_avg == null ? '-' : String(r.sentiment_avg)) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const actionCols: Column<Action>[] = [
    { key: 'trend_id', header: 'Trend', render: (r: any) => String(r.trend_id).slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Customer Voice Trends</h1>
        <p className="text-sm text-gray-600 mt-1">
          Aggregate customer voice signals into trends. Categories span service quality, pricing,
          engineer quality, billing, feature requests, and competitive intel.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">All Trends</h2>
        <DataTable rows={trends} columns={trendCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Persistent Trends</h2>
        <p className="text-sm text-gray-600 mb-2">Signals that keep recurring and need founder attention.</p>
        <DataTable rows={persistent} columns={trendCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
