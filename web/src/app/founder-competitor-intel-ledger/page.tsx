import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_competitors: number; top_tier: number; watch_tier: number; minor_tier: number;
  intel_30d: number; intel_90d: number; intel_total: number;
  pricing_30d: number; win_30d: number; loss_30d: number; win_rate_pct: number;
  swot_total: number; threats_open: number;
  avg_competitor_price_rupees: number; avg_sentiment_30d: number; hospitals_lost_90d: number;
};

export default async function FounderCompetitorIntelLedgerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, rosterRes, winLossRes, pricingRes, swotRes, sentimentRes, watchlistRes] = await Promise.all([
    supabase.rpc('rpc_founder_competitor_kpis'),
    supabase.rpc('rpc_founder_competitor_roster'),
    supabase.rpc('rpc_founder_competitor_win_loss'),
    supabase.rpc('rpc_founder_competitor_pricing'),
    supabase.rpc('rpc_founder_competitor_swot'),
    supabase.rpc('rpc_founder_competitor_sentiment_weekly'),
    supabase.rpc('rpc_founder_competitor_watchlist'),
  ]);

  const k: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_competitors: 0, top_tier: 0, watch_tier: 0, minor_tier: 0,
    intel_30d: 0, intel_90d: 0, intel_total: 0,
    pricing_30d: 0, win_30d: 0, loss_30d: 0, win_rate_pct: 0,
    swot_total: 0, threats_open: 0,
    avg_competitor_price_rupees: 0, avg_sentiment_30d: 0, hospitals_lost_90d: 0,
  };

  const roster = (rosterRes.data ?? []) as Array<{ id: string; name: string; hq_city: string | null; est_size: string | null; watchlist_tier: string; intel_count: number; last_intel_at: string | null }>;
  const winLoss = (winLossRes.data ?? []) as Array<{ id: string; competitor_name: string; hospital_name: string | null; outcome: string | null; observed_price_rupees: number | null; body: string; observed_at: string }>;
  const pricing = (pricingRes.data ?? []) as Array<{ id: string; competitor_name: string; hospital_name: string | null; observed_price_rupees: number | null; body: string; source: string | null; observed_at: string }>;
  const swot = (swotRes.data ?? []) as Array<{ id: string; competitor_name: string; swot_bucket: string | null; body: string; observed_at: string }>;
  const sentiment = (sentimentRes.data ?? []) as Array<{ week_start: string; competitor_name: string; avg_sentiment: number; samples: number }>;
  const watchlist = (watchlistRes.data ?? []) as Array<{ id: string; name: string; hq_city: string | null; watchlist_tier: string; intel_30d: number; last_intel_at: string | null; latest_note: string | null }>;

  const sentimentRows = sentiment.map((r, i) => ({ ...r, id: `${r.week_start}-${r.competitor_name}-${i}` }));

  const cards: Array<{ label: string; value: string; hint?: string }> = [
    { label: 'Competitors tracked', value: String(k.total_competitors) },
    { label: 'Top-tier rivals', value: String(k.top_tier) },
    { label: 'Watch-tier', value: String(k.watch_tier) },
    { label: 'Minor-tier', value: String(k.minor_tier) },
    { label: 'Intel — last 30d', value: String(k.intel_30d) },
    { label: 'Intel — last 90d', value: String(k.intel_90d) },
    { label: 'Intel — total', value: String(k.intel_total) },
    { label: 'Pricing obs — 30d', value: String(k.pricing_30d) },
    { label: 'Wins — 30d', value: String(k.win_30d) },
    { label: 'Losses — 30d', value: String(k.loss_30d) },
    { label: 'Win rate — 90d', value: `${k.win_rate_pct}%` },
    { label: 'SWOT entries', value: String(k.swot_total) },
    { label: 'Open threats', value: String(k.threats_open) },
    { label: 'Avg rival price (90d)', value: formatRupees(k.avg_competitor_price_rupees ?? 0) },
    { label: 'Avg sentiment (30d)', value: String(k.avg_sentiment_30d) },
    { label: 'Hospitals lost (90d)', value: String(k.hospitals_lost_90d) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder Competitor Intel Ledger</h1>
        <p className="text-sm text-gray-600">
          Rival biomedical AMC firms — pricing observed, win/loss vs us, watchlist tiers, SWOT entries, sentiment over time. Founder-only.
        </p>
      </header>

      <section aria-label="kpis" className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-gray-200 bg-white p-3 shadow-sm">
            <div className="text-[11px] uppercase tracking-wide text-gray-500">{c.label}</div>
            <div className="mt-1 text-xl font-semibold tabular-nums">{c.value}</div>
            {c.hint ? <div className="text-xs text-gray-500">{c.hint}</div> : null}
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Watchlist (top + watch tiers)</h2>
        <DataTable
          rowKey={(r) => r.id}
          rows={watchlist}
          columns={[
            { key: 'name', header: 'Competitor', render: (r: any) => r.name ?? '—' },
            { key: 'hq_city', header: 'HQ city', render: (r: any) => r.hq_city ?? '—' },
            { key: 'watchlist_tier', header: 'Tier', render: (r: any) => r.watchlist_tier ?? '—' },
            { key: 'intel_30d', header: 'Intel 30d', render: (r: any) => r.intel_30d ?? '—' },
            { key: 'last_intel_at', header: 'Last intel', render: (r: any) => r.last_intel_at ?? '—' },
            { key: 'latest_note', header: 'Latest note', render: (r: any) => r.latest_note ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Competitor roster</h2>
        <DataTable
          rowKey={(r) => r.id}
          rows={roster}
          columns={[
            { key: 'name', header: 'Competitor', render: (r: any) => r.name ?? '—' },
            { key: 'hq_city', header: 'HQ city', render: (r: any) => r.hq_city ?? '—' },
            { key: 'est_size', header: 'Est. size', render: (r: any) => r.est_size ?? '—' },
            { key: 'watchlist_tier', header: 'Tier', render: (r: any) => r.watchlist_tier ?? '—' },
            { key: 'intel_count', header: 'Intel total', render: (r: any) => r.intel_count ?? '—' },
            { key: 'last_intel_at', header: 'Last intel', render: (r: any) => r.last_intel_at ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Win / loss ledger (vs us)</h2>
        <p className="text-xs text-gray-500">Outcomes vs Equipseva. {"<"} 200 most recent entries.</p>
        <DataTable
          rowKey={(r) => r.id}
          rows={winLoss}
          columns={[
            { key: 'observed_at', header: 'When', render: (r: any) => r.observed_at ?? '—' },
            { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name ?? '—' },
            { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
            { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
            { key: 'observed_price_rupees', header: 'Their price',
              render: (r) => r.observed_price_rupees != null ? formatRupees(r.observed_price_rupees) : '—' },
            { key: 'body', header: 'Notes', render: (r: any) => r.body ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Pricing observations</h2>
        <DataTable
          rowKey={(r) => r.id}
          rows={pricing}
          columns={[
            { key: 'observed_at', header: 'When', render: (r: any) => r.observed_at ?? '—' },
            { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name ?? '—' },
            { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
            { key: 'observed_price_rupees', header: 'Price',
              render: (r) => r.observed_price_rupees != null ? formatRupees(r.observed_price_rupees) : '—' },
            { key: 'source', header: 'Source', render: (r: any) => r.source ?? '—' },
            { key: 'body', header: 'Notes', render: (r: any) => r.body ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">SWOT entries</h2>
        <DataTable
          rowKey={(r) => r.id}
          rows={swot}
          columns={[
            { key: 'observed_at', header: 'When', render: (r: any) => r.observed_at ?? '—' },
            { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name ?? '—' },
            { key: 'swot_bucket', header: 'Bucket', render: (r: any) => r.swot_bucket ?? '—' },
            { key: 'body', header: 'Entry', render: (r: any) => r.body ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Sentiment over time (weekly, 180d)</h2>
        <p className="text-xs text-gray-500">Scale {"-"}5 (very negative) to +5 (very positive).</p>
        <DataTable
          rowKey={(r) => r.id}
          rows={sentimentRows}
          columns={[
            { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ?? '—' },
            { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name ?? '—' },
            { key: 'avg_sentiment', header: 'Avg sentiment', render: (r: any) => r.avg_sentiment ?? '—' },
            { key: 'samples', header: 'Samples', render: (r: any) => r.samples ?? '—' },
          ]}
        />
      </section>
    </main>
  );
}
