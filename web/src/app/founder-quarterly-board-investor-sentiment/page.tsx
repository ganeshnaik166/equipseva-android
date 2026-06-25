import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyBoardInvestorSentimentPage() {
  const supabase = await getSupabaseServerClient();

  const [sentimentRes, actionsRes, focusRes, distRes, funnelRes, trendRes, pulseRes] = await Promise.all([
    supabase.rpc('list_sentiment_r2657'),
    supabase.rpc('list_recovery_actions_r2657'),
    supabase.rpc('top_concerned_focus_r2657'),
    supabase.rpc('sentiment_distribution_r2657'),
    supabase.rpc('status_funnel_r2657'),
    supabase.rpc('quarterly_sentiment_trend_r2657'),
    supabase.rpc('founder_pulse_summary_r2657'),
  ]);

  const sentiment = (sentimentRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const distribution = (distRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const pulse = ((pulseRes.data ?? [])[0] ?? {}) as any;

  const sentimentColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'sentiment_kind', header: 'Sentiment', render: (r: any) => r.sentiment_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'top_concern_md', header: 'Top Concern', render: (r: any) => r.top_concern_md ?? '—' },
    { key: 'top_endorsement_md', header: 'Top Endorsement', render: (r: any) => r.top_endorsement_md ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const focusColumns: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'sentiment_kind', header: 'Sentiment', render: (r: any) => r.sentiment_kind },
    { key: 'top_concern_md', header: 'Top Concern', render: (r: any) => r.top_concern_md ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const distributionColumns: Column<any>[] = [
    { key: 'sentiment_kind', header: 'Sentiment', render: (r: any) => r.sentiment_kind },
    { key: 'investor_count', header: 'Investors', render: (r: any) => r.investor_count },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'investor_count', header: 'Investors', render: (r: any) => r.investor_count },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'total_investors', header: 'Total', render: (r: any) => r.total_investors },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'concerned_count', header: 'Concerned', render: (r: any) => r.concerned_count },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Quarterly Board Investor Sentiment</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track per-quarter investor pulse & recovery actions for concerned LPs.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Total investors</div>
          <div className="text-2xl font-semibold mt-1">{pulse.total_investors ?? 0}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Positive %</div>
          <div className="text-2xl font-semibold mt-1">{pulse.positive_pct ?? 0}%</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Concerned %</div>
          <div className="text-2xl font-semibold mt-1">{pulse.concerned_pct ?? 0}%</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Open recovery actions</div>
          <div className="text-2xl font-semibold mt-1">{pulse.open_recovery_actions ?? 0}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Recovered</div>
          <div className="text-2xl font-semibold mt-1">{pulse.recovered_count ?? 0}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top concerned investors — focus list</h2>
        <DataTable
          rows={focus}
          columns={focusColumns}
          emptyMessage="No concerned investors right now."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-3">Sentiment distribution</h2>
          <DataTable
            rows={distribution}
            columns={distributionColumns}
            emptyMessage="No sentiment recorded."
            rowKey={(r: any, i: number) => String(r.sentiment_kind ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-3">Status funnel</h2>
          <DataTable
            rows={funnel}
            columns={funnelColumns}
            emptyMessage="No status data."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Quarterly trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No quarterly trend data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All sentiment entries</h2>
        <DataTable
          rows={sentiment}
          columns={sentimentColumns}
          emptyMessage="No investor sentiment yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recovery actions log</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          emptyMessage="No recovery actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
