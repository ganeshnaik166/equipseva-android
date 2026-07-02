import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_stories: number;
  legendary_count: number;
  at_risk_count: number;
  published_count: number;
  total_views: number;
  total_revenue_rupees: number;
  avg_csat: number;
};

type Story = {
  id: string;
  engineer_name: string;
  engineer_tier: string;
  story_month: string;
  jobs_completed: number;
  jobs_perfect: number;
  csat_avg: number;
  revenue_generated_rupees: number;
  verdict: string;
  share_status: string;
  share_view_count: number;
};

type HeroJob = {
  engineer_name: string;
  engineer_tier: string;
  hero_job_title: string;
  hero_job_summary: string;
  highlight_quote: string;
  verdict: string;
};

type TierRow = {
  engineer_tier: string;
  engineer_count: number;
  total_jobs: number;
  perfect_pct: number;
  total_revenue_rupees: number;
  avg_csat: number;
};

type Engagement = {
  engineer_name: string;
  event_kind: string;
  audience: string;
  audience_label: string;
  sentiment: string;
  remark: string;
  occurred_at: string;
};

type ShareHealth = {
  engineer_name: string;
  share_status: string;
  public_share_token: string | null;
  share_view_count: number;
  engagement_events: number;
  rave_count: number;
};

type VerdictRow = {
  verdict: string;
  engineer_count: number;
  share_of_revenue_pct: number;
  avg_jobs: number;
  avg_csat: number;
};

type AtRisk = {
  engineer_name: string;
  engineer_tier: string;
  jobs_completed: number;
  csat_avg: number;
  verdict: string;
  founder_notes: string | null;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, storiesRes, heroRes, tierRes, engRes, shareRes, verdictRes, atRiskRes] =
    await Promise.all([
      supabase.rpc('rpc_r2850_summary'),
      supabase.rpc('rpc_r2850_stories'),
      supabase.rpc('rpc_r2850_hero_jobs'),
      supabase.rpc('rpc_r2850_tier_breakdown'),
      supabase.rpc('rpc_r2850_engagement_feed'),
      supabase.rpc('rpc_r2850_public_share_health'),
      supabase.rpc('rpc_r2850_verdict_distribution'),
      supabase.rpc('rpc_r2850_at_risk_watchlist'),
    ]);

  const summary: Summary = (summaryRes.data?.[0] as Summary) ?? {
    total_stories: 0,
    legendary_count: 0,
    at_risk_count: 0,
    published_count: 0,
    total_views: 0,
    total_revenue_rupees: 0,
    avg_csat: 0,
  };
  const stories: Story[] = (storiesRes.data as Story[]) ?? [];
  const heroes: HeroJob[] = (heroRes.data as HeroJob[]) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const engagements: Engagement[] = (engRes.data as Engagement[]) ?? [];
  const shareHealth: ShareHealth[] = (shareRes.data as ShareHealth[]) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const atRisk: AtRisk[] = (atRiskRes.data as AtRisk[]) ?? [];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Monthly Job Completion Narrative Story</h1>
        <p className="text-sm text-gray-600">
          Round r2850 · engineer x job x narrative x highlight x public share x engagement x verdict.
          Founder-only console for the monthly storytelling layer that surfaces hero jobs, hospital reactions,
          investor-grade quotes, and at-risk watchlists in one place.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <KpiCard label="Total stories" value={String(summary.total_stories)} />
        <KpiCard label="Legendary" value={String(summary.legendary_count)} tone="good" />
        <KpiCard label="At risk" value={String(summary.at_risk_count)} tone="bad" />
        <KpiCard label="Published" value={String(summary.published_count)} />
        <KpiCard label="Total share views" value={summary.total_views.toLocaleString('en-IN')} />
        <KpiCard label="Revenue generated" value={rupees(summary.total_revenue_rupees)} />
        <KpiCard label="Avg CSAT" value={`${Number(summary.avg_csat).toFixed(2)} / 5`} />
        <KpiCard
          label="Legendary share"
          value={
            summary.total_stories > 0
              ? `${Math.round((summary.legendary_count / summary.total_stories) * 100)}%`
              : '0%'
          }
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Monthly stories — ranked by revenue</h2>
        <DataTable
          rows={stories}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Story) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: Story) => r.engineer_tier },
            { key: 'story_month', header: 'Month', render: (r: Story) => r.story_month },
            { key: 'jobs_completed', header: 'Jobs', render: (r: Story) => String(r.jobs_completed) },
            {
              key: 'jobs_perfect',
              header: 'Perfect',
              render: (r: Story) =>
                `${r.jobs_perfect} / ${r.jobs_completed}`,
            },
            { key: 'csat_avg', header: 'CSAT', render: (r: Story) => Number(r.csat_avg).toFixed(2) },
            {
              key: 'revenue_generated_rupees',
              header: 'Revenue',
              render: (r: Story) => rupees(r.revenue_generated_rupees),
            },
            { key: 'verdict', header: 'Verdict', render: (r: Story) => <VerdictBadge v={r.verdict} /> },
            { key: 'share_status', header: 'Share', render: (r: Story) => r.share_status },
            {
              key: 'share_view_count',
              header: 'Views',
              render: (r: Story) => r.share_view_count.toLocaleString('en-IN'),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: Story, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Hero jobs & pull-quotes</h2>
        <DataTable
          rows={heroes}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: HeroJob) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: HeroJob) => r.engineer_tier },
            { key: 'hero_job_title', header: 'Hero job', render: (r: HeroJob) => r.hero_job_title },
            {
              key: 'hero_job_summary',
              header: 'Summary',
              render: (r: HeroJob) => (
                <span className="text-sm text-gray-700">{r.hero_job_summary}</span>
              ),
            },
            {
              key: 'highlight_quote',
              header: 'Quote',
              render: (r: HeroJob) => (
                <em className="text-sm text-gray-600">“{r.highlight_quote}”</em>
              ),
            },
            { key: 'verdict', header: 'Verdict', render: (r: HeroJob) => <VerdictBadge v={r.verdict} /> },
          ]}
          emptyMessage="No data"
          rowKey={(r: HeroJob, i: number) => `${r.engineer_name}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Tier breakdown</h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'engineer_tier', header: 'Tier', render: (r: TierRow) => r.engineer_tier },
            {
              key: 'engineer_count',
              header: 'Engineers',
              render: (r: TierRow) => String(r.engineer_count),
            },
            { key: 'total_jobs', header: 'Jobs', render: (r: TierRow) => String(r.total_jobs) },
            {
              key: 'perfect_pct',
              header: 'Perfect %',
              render: (r: TierRow) => `${Number(r.perfect_pct).toFixed(1)}%`,
            },
            {
              key: 'total_revenue_rupees',
              header: 'Revenue',
              render: (r: TierRow) => rupees(r.total_revenue_rupees),
            },
            {
              key: 'avg_csat',
              header: 'Avg CSAT',
              render: (r: TierRow) => Number(r.avg_csat).toFixed(2),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => `${r.engineer_tier}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Verdict distribution</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => <VerdictBadge v={r.verdict} /> },
            {
              key: 'engineer_count',
              header: 'Engineers',
              render: (r: VerdictRow) => String(r.engineer_count),
            },
            {
              key: 'share_of_revenue_pct',
              header: 'Share of revenue',
              render: (r: VerdictRow) => `${Number(r.share_of_revenue_pct).toFixed(1)}%`,
            },
            {
              key: 'avg_jobs',
              header: 'Avg jobs',
              render: (r: VerdictRow) => Number(r.avg_jobs).toFixed(1),
            },
            {
              key: 'avg_csat',
              header: 'Avg CSAT',
              render: (r: VerdictRow) => Number(r.avg_csat).toFixed(2),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => `${r.verdict}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Public share health</h2>
        <DataTable
          rows={shareHealth}
          columns={[
            {
              key: 'engineer_name',
              header: 'Engineer',
              render: (r: ShareHealth) => r.engineer_name,
            },
            {
              key: 'share_status',
              header: 'Status',
              render: (r: ShareHealth) => r.share_status,
            },
            {
              key: 'public_share_token',
              header: 'Token',
              render: (r: ShareHealth) =>
                r.public_share_token ? (
                  <code className="text-xs text-gray-700">{r.public_share_token}</code>
                ) : (
                  <span className="text-xs text-gray-400">unpublished</span>
                ),
            },
            {
              key: 'share_view_count',
              header: 'Views',
              render: (r: ShareHealth) => r.share_view_count.toLocaleString('en-IN'),
            },
            {
              key: 'engagement_events',
              header: 'Events',
              render: (r: ShareHealth) => String(r.engagement_events),
            },
            {
              key: 'rave_count',
              header: 'Raves',
              render: (r: ShareHealth) => String(r.rave_count),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: ShareHealth, i: number) => `${r.engineer_name}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Engagement feed</h2>
        <DataTable
          rows={engagements}
          columns={[
            {
              key: 'engineer_name',
              header: 'Engineer',
              render: (r: Engagement) => r.engineer_name,
            },
            { key: 'event_kind', header: 'Event', render: (r: Engagement) => r.event_kind },
            { key: 'audience', header: 'Audience', render: (r: Engagement) => r.audience },
            {
              key: 'audience_label',
              header: 'Who',
              render: (r: Engagement) => r.audience_label,
            },
            {
              key: 'sentiment',
              header: 'Sentiment',
              render: (r: Engagement) => <SentimentBadge s={r.sentiment} />,
            },
            {
              key: 'remark',
              header: 'Remark',
              render: (r: Engagement) => (
                <span className="text-sm text-gray-700">{r.remark}</span>
              ),
            },
            {
              key: 'occurred_at',
              header: 'When',
              render: (r: Engagement) => new Date(r.occurred_at).toLocaleDateString('en-IN'),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: Engagement, i: number) => `${r.engineer_name}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">At-risk watchlist</h2>
        <p className="mb-2 text-sm text-gray-600">
          Engineers below CSAT 4.0 or flagged as needs_boost / at_risk — founder intervention queue.
        </p>
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: AtRisk) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: AtRisk) => r.engineer_tier },
            {
              key: 'jobs_completed',
              header: 'Jobs',
              render: (r: AtRisk) => String(r.jobs_completed),
            },
            {
              key: 'csat_avg',
              header: 'CSAT',
              render: (r: AtRisk) => Number(r.csat_avg).toFixed(2),
            },
            { key: 'verdict', header: 'Verdict', render: (r: AtRisk) => <VerdictBadge v={r.verdict} /> },
            {
              key: 'founder_notes',
              header: 'Founder notes',
              render: (r: AtRisk) => (
                <span className="text-sm text-gray-700">{r.founder_notes ?? '-'}</span>
              ),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRisk, i: number) => `${r.engineer_name}-${i}`}
        />
      </section>
    </div>
  );
}

function KpiCard({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone?: 'good' | 'bad';
}) {
  const toneClass =
    tone === 'good'
      ? 'border-emerald-200 bg-emerald-50'
      : tone === 'bad'
      ? 'border-rose-200 bg-rose-50'
      : 'border-gray-200 bg-white';
  return (
    <div className={`rounded-lg border p-4 ${toneClass}`}>
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}

function VerdictBadge({ v }: { v: string }) {
  const map: Record<string, string> = {
    legendary: 'bg-amber-100 text-amber-800',
    strong: 'bg-emerald-100 text-emerald-800',
    solid: 'bg-sky-100 text-sky-800',
    needs_boost: 'bg-orange-100 text-orange-800',
    at_risk: 'bg-rose-100 text-rose-800',
  };
  const cls = map[v] ?? 'bg-gray-100 text-gray-800';
  return (
    <span className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{v}</span>
  );
}

function SentimentBadge({ s }: { s: string }) {
  const map: Record<string, string> = {
    rave: 'bg-amber-100 text-amber-800',
    positive: 'bg-emerald-100 text-emerald-800',
    neutral: 'bg-gray-100 text-gray-800',
    critical: 'bg-rose-100 text-rose-800',
  };
  const cls = map[s] ?? 'bg-gray-100 text-gray-800';
  return (
    <span className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{s}</span>
  );
}
