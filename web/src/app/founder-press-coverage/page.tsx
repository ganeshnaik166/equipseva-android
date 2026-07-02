import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function fmtNum(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return '0';
  return v.toLocaleString('en-IN');
}

function fmtDate(d: any): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }); } catch { return String(d); }
}

function sentimentBadge(s: string): string {
  switch (s) {
    case 'positive': return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    case 'negative': return 'bg-rose-50 text-rose-700 border-rose-200';
    case 'mixed':    return 'bg-amber-50 text-amber-700 border-amber-200';
    default:         return 'bg-neutral-50 text-neutral-700 border-neutral-200';
  }
}

export default async function FounderPressCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, recentRes, byTypeRes, byOutletRes, trendRes, upcomingRes, topReachRes] = await Promise.all([
    supabase.rpc('founder_press_kpis'),
    supabase.rpc('founder_press_recent', { p_limit: 50 }),
    supabase.rpc('founder_press_by_type'),
    supabase.rpc('founder_press_by_outlet', { p_limit: 20 }),
    supabase.rpc('founder_press_sentiment_trend_12mo'),
    supabase.rpc('founder_press_upcoming', { p_limit: 50 }),
    supabase.rpc('founder_press_top_reach', { p_limit: 20 }),
  ]);

  const k: any = Array.isArray(kpisRes.data) ? kpisRes.data[0] ?? {} : (kpisRes.data ?? {});
  const recent: any[] = recentRes.data ?? [];
  const byType: any[] = byTypeRes.data ?? [];
  const byOutlet: any[] = byOutletRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const upcoming: any[] = upcomingRes.data ?? [];
  const topReach: any[] = topReachRes.data ?? [];

  const recentCols = [
    { key: 'occurred_at', header: 'When', render: (r: any) => fmtDate(r.occurred_at) },
    { key: 'outlet', header: 'Outlet', render: (r: any) => <span className="font-medium">{r.outlet}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => (
        r.url
          ? <a className="text-blue-700 hover:underline" href={r.url} target="_blank" rel="noreferrer">{r.headline}</a>
          : <span>{r.headline}</span>
      ) },
    { key: 'mention_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase tracking-wide text-neutral-600">{r.mention_type}</span> },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => (
        <span className={`rounded border px-2 py-0.5 text-xs ${sentimentBadge(r.sentiment)}`}>{r.sentiment}</span>
      ) },
    { key: 'reach_audience', header: 'Reach', render: (r: any) => fmtNum(r.reach_audience) },
    { key: 'founder_quoted', header: 'Quoted', render: (r: any) => r.founder_quoted ? 'Yes' : '—' },
    { key: 'media_trained', header: 'Media-trained', render: (r: any) => r.media_trained ? 'Yes' : '—' },
    { key: 'estimated_value_rupees', header: 'Est. Value', render: (r: any) => formatRupees(r.estimated_value_rupees ?? 0) },
  ];

  const byTypeCols = [
    { key: 'mention_type', header: 'Type', render: (r: any) => <span className="font-medium uppercase tracking-wide text-xs">{r.mention_type}</span> },
    { key: 'total', header: 'Total', render: (r: any) => fmtNum(r.total) },
    { key: 'total_reach', header: 'Total Reach', render: (r: any) => fmtNum(r.total_reach) },
    { key: 'avg_reach', header: 'Avg Reach', render: (r: any) => fmtNum(r.avg_reach) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => <span className="text-emerald-700">{fmtNum(r.positive_count)}</span> },
    { key: 'negative_count', header: 'Negative', render: (r: any) => <span className="text-rose-700">{fmtNum(r.negative_count)}</span> },
  ];

  const byOutletCols = [
    { key: 'outlet', header: 'Outlet', render: (r: any) => <span className="font-medium">{r.outlet}</span> },
    { key: 'total', header: 'Mentions', render: (r: any) => fmtNum(r.total) },
    { key: 'total_reach', header: 'Reach', render: (r: any) => fmtNum(r.total_reach) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => fmtNum(r.positive_count) },
    { key: 'last_occurred_at', header: 'Last', render: (r: any) => fmtDate(r.last_occurred_at) },
  ];

  const trendCols = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start).split(',')[0] },
    { key: 'mentions', header: 'Mentions', render: (r: any) => fmtNum(r.mentions) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => <span className="text-emerald-700">{fmtNum(r.positive_count)}</span> },
    { key: 'neutral_count', header: 'Neutral', render: (r: any) => fmtNum(r.neutral_count) },
    { key: 'negative_count', header: 'Negative', render: (r: any) => <span className="text-rose-700">{fmtNum(r.negative_count)}</span> },
    { key: 'reach', header: 'Reach', render: (r: any) => fmtNum(r.reach) },
  ];

  const upcomingCols = [
    { key: 'scheduled_at', header: 'When', render: (r: any) => fmtDate(r.scheduled_at) },
    { key: 'outlet', header: 'Outlet', render: (r: any) => <span className="font-medium">{r.outlet}</span> },
    { key: 'topic', header: 'Topic', render: (r: any) => r.topic },
    { key: 'commitment_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase tracking-wide text-neutral-600">{r.commitment_type}</span> },
    { key: 'prep_required_hours', header: 'Prep (h)', render: (r: any) => fmtNum(r.prep_required_hours) },
    { key: 'prep_done', header: 'Prep Done', render: (r: any) => r.prep_done ? <span className="text-emerald-700">Yes</span> : <span className="text-amber-700">No</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs uppercase tracking-wide">{r.status}</span> },
    { key: 'expected_reach', header: 'Expected Reach', render: (r: any) => fmtNum(r.expected_reach) },
    { key: 'contact_name', header: 'Contact', render: (r: any) => r.contact_name ?? '—' },
  ];

  const topReachCols = [
    { key: 'occurred_at', header: 'When', render: (r: any) => fmtDate(r.occurred_at) },
    { key: 'outlet', header: 'Outlet', render: (r: any) => <span className="font-medium">{r.outlet}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => r.headline },
    { key: 'mention_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase tracking-wide text-neutral-600">{r.mention_type}</span> },
    { key: 'reach_audience', header: 'Reach', render: (r: any) => <span className="font-semibold">{fmtNum(r.reach_audience)}</span> },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => (
        <span className={`rounded border px-2 py-0.5 text-xs ${sentimentBadge(r.sentiment)}`}>{r.sentiment}</span>
      ) },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4 md:p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight text-neutral-900">Founder Press Coverage</h1>
        <p className="text-sm text-neutral-600">
          Mentions, interviews, podcasts, awards. Sentiment + reach + upcoming commitments. r1460.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total Mentions" value={fmtNum(k.total_mentions)} />
        <Kpi label="Mentions 30d" value={fmtNum(k.mentions_30d)} />
        <Kpi label="Mentions 90d" value={fmtNum(k.mentions_90d)} />
        <Kpi label="Mentions 365d" value={fmtNum(k.mentions_365d)} />
        <Kpi label="Interviews" value={fmtNum(k.interviews_total)} />
        <Kpi label="Podcasts" value={fmtNum(k.podcasts_total)} />
        <Kpi label="Awards" value={fmtNum(k.awards_total)} />
        <Kpi label="Op-Eds" value={fmtNum(k.op_eds_total)} />
        <Kpi label="Positive %" value={`${k.positive_share_pct ?? 0}%`} />
        <Kpi label="Negative %" value={`${k.negative_share_pct ?? 0}%`} />
        <Kpi label="Total Reach" value={fmtNum(k.total_reach)} />
        <Kpi label="Reach 30d" value={fmtNum(k.reach_30d)} />
        <Kpi label="Founder Quoted %" value={`${k.founder_quoted_share_pct ?? 0}%`} />
        <Kpi label="Media-Trained %" value={`${k.media_trained_share_pct ?? 0}%`} />
        <Kpi label="Upcoming" value={fmtNum(k.upcoming_commitments)} />
        <Kpi label="Prep Pending" value={fmtNum(k.prep_pending_commitments)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Upcoming Media Commitments</h2>
        <p className="text-xs text-neutral-500">Scheduled interviews, panels, keynotes. Status {"<"}= confirmed needs prep.</p>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Recent Mentions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">By Mention Type</h2>
        <DataTable rows={byType} columns={byTypeCols} rowKey={(r: any) => r.mention_type} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Top Outlets</h2>
        <DataTable rows={byOutlet} columns={byOutletCols} rowKey={(r: any) => r.outlet} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Sentiment Trend (12 months)</h2>
        <DataTable rows={trend} columns={trendCols} rowKey={(r: any) => String(r.month_start)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Top Reach</h2>
        <DataTable rows={topReach} columns={topReachCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
