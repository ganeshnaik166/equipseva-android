import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric: string; value: string };
type BattleCard = {
  id: string;
  competitor_name: string;
  segment: string;
  region: string;
  threat_level: string;
  market_share_pct: number;
  pricing_band_rupees: number;
  refresh_quarter: string;
};
type EventRow = {
  id: string;
  competitor_name: string;
  hospital_name: string;
  deal_size_rupees: number;
  outcome: string;
  primary_driver: string;
  region: string;
  deal_closed_at: string;
};
type WinRateRow = {
  competitor_name: string;
  wins: number;
  losses: number;
  stalemates: number;
  win_rate_pct: number;
};
type RegionRow = {
  region: string;
  competitor_count: number;
  avg_market_share: number;
  critical_or_high_count: number;
};
type DriverRow = {
  primary_driver: string;
  win_count?: number;
  loss_count?: number;
  total_value_rupees: number;
};
type StaleRow = {
  id: string;
  competitor_name: string;
  segment: string;
  last_refreshed_at: string;
  days_since_refresh: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    cardsRes,
    eventsRes,
    winRateRes,
    regionRes,
    winDriverRes,
    lossReasonRes,
    staleRes,
  ] = await Promise.all([
    supabase.rpc('r2905_kpi_summary'),
    supabase.rpc('r2905_battle_cards_by_threat'),
    supabase.rpc('r2905_recent_events'),
    supabase.rpc('r2905_win_rate_by_competitor'),
    supabase.rpc('r2905_region_pressure'),
    supabase.rpc('r2905_top_win_drivers'),
    supabase.rpc('r2905_loss_reasons'),
    supabase.rpc('r2905_stale_battle_cards'),
  ]);

  const kpis: KpiRow[] = (kpiRes.data as KpiRow[]) ?? [];
  const cards: BattleCard[] = (cardsRes.data as BattleCard[]) ?? [];
  const events: EventRow[] = (eventsRes.data as EventRow[]) ?? [];
  const winRates: WinRateRow[] = (winRateRes.data as WinRateRow[]) ?? [];
  const regions: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const winDrivers: DriverRow[] = (winDriverRes.data as DriverRow[]) ?? [];
  const lossReasons: DriverRow[] = (lossReasonRes.data as DriverRow[]) ?? [];
  const stale: StaleRow[] = (staleRes.data as StaleRow[]) ?? [];

  const kpiMap = Object.fromEntries(kpis.map((k) => [k.metric, k.value]));

  const cardCols: Column<BattleCard>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r) => r.competitor_name },
    { key: 'segment', header: 'Segment', render: (r) => r.segment },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'threat_level', header: 'Threat', render: (r) => r.threat_level.toUpperCase() },
    { key: 'market_share_pct', header: 'Share %', render: (r) => `${r.market_share_pct}%` },
    { key: 'pricing_band_rupees', header: 'Pricing', render: (r) => `₹${r.pricing_band_rupees.toLocaleString('en-IN')}` },
    { key: 'refresh_quarter', header: 'Quarter', render: (r) => r.refresh_quarter },
  ];

  const eventCols: Column<EventRow>[] = [
    { key: 'deal_closed_at', header: 'Closed', render: (r) => new Date(r.deal_closed_at).toLocaleDateString('en-IN') },
    { key: 'competitor_name', header: 'Competitor', render: (r) => r.competitor_name },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome.toUpperCase() },
    { key: 'deal_size_rupees', header: 'Deal ₹', render: (r) => `₹${r.deal_size_rupees.toLocaleString('en-IN')}` },
    { key: 'primary_driver', header: 'Driver', render: (r) => r.primary_driver },
    { key: 'region', header: 'Region', render: (r) => r.region },
  ];

  const winRateCols: Column<WinRateRow>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r) => r.competitor_name },
    { key: 'wins', header: 'Wins', render: (r) => String(r.wins) },
    { key: 'losses', header: 'Losses', render: (r) => String(r.losses) },
    { key: 'stalemates', header: 'Stale', render: (r) => String(r.stalemates) },
    { key: 'win_rate_pct', header: 'Win %', render: (r) => `${r.win_rate_pct}%` },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'competitor_count', header: 'Competitors', render: (r) => String(r.competitor_count) },
    { key: 'avg_market_share', header: 'Avg Share %', render: (r) => `${r.avg_market_share}%` },
    { key: 'critical_or_high_count', header: 'Crit+High', render: (r) => String(r.critical_or_high_count) },
  ];

  const winDriverCols: Column<DriverRow>[] = [
    { key: 'primary_driver', header: 'Driver', render: (r) => r.primary_driver },
    { key: 'win_count', header: 'Wins', render: (r) => String(r.win_count ?? 0) },
    { key: 'total_value_rupees', header: 'Value ₹', render: (r) => `₹${r.total_value_rupees.toLocaleString('en-IN')}` },
  ];

  const lossReasonCols: Column<DriverRow>[] = [
    { key: 'primary_driver', header: 'Reason', render: (r) => r.primary_driver },
    { key: 'loss_count', header: 'Losses', render: (r) => String(r.loss_count ?? 0) },
    { key: 'total_value_rupees', header: 'Value ₹', render: (r) => `₹${r.total_value_rupees.toLocaleString('en-IN')}` },
  ];

  const staleCols: Column<StaleRow>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r) => r.competitor_name },
    { key: 'segment', header: 'Segment', render: (r) => r.segment },
    { key: 'last_refreshed_at', header: 'Last Refresh', render: (r) => new Date(r.last_refreshed_at).toLocaleDateString('en-IN') },
    { key: 'days_since_refresh', header: 'Days Stale', render: (r) => String(r.days_since_refresh) },
  ];

  const kpiCards = [
    { label: 'Battle Cards', value: kpiMap['total_battle_cards'] ?? '0' },
    { label: 'Critical Threats', value: kpiMap['critical_threats'] ?? '0' },
    { label: 'High Threats', value: kpiMap['high_threats'] ?? '0' },
    { label: 'Wins (Q)', value: kpiMap['total_wins_q'] ?? '0' },
    { label: 'Losses (Q)', value: kpiMap['total_losses_q'] ?? '0' },
    { label: 'Win Value ₹', value: `₹${Number(kpiMap['win_value_rupees'] ?? 0).toLocaleString('en-IN')}` },
    { label: 'Loss Value ₹', value: `₹${Number(kpiMap['loss_value_rupees'] ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
          Quarterly Strategic Competitor Win/Loss Battle-Card Refresh
        </h1>
        <p style={{ color: '#555' }}>
          Round r2905 · Batch 400 milestone · founder console refresh of competitor
          battle cards & win/loss intel for the quarter.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 32 }}>
        {kpiCards.map((k) => (
          <div key={k.label} style={{ padding: 16, border: '1px solid #e2e2e2', borderRadius: 8, background: '#fafafa' }}>
            <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Battle Cards by Threat Level</h2>
        <DataTable
          rows={cards}
          columns={cardCols}
          emptyMessage="No battle cards yet."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Win/Loss Events</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          emptyMessage="No events recorded."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Win Rate by Competitor</h2>
        <DataTable
          rows={winRates}
          columns={winRateCols}
          emptyMessage="No win rate data."
          rowKey={(r, i) => String(r.competitor_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Regional Competitive Pressure</h2>
        <DataTable
          rows={regions}
          columns={regionCols}
          emptyMessage="No regional data."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Win Drivers</h2>
        <DataTable
          rows={winDrivers}
          columns={winDriverCols}
          emptyMessage="No win drivers."
          rowKey={(r, i) => String(r.primary_driver ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Loss Reasons</h2>
        <DataTable
          rows={lossReasons}
          columns={lossReasonCols}
          emptyMessage="No loss reasons."
          rowKey={(r, i) => String(r.primary_driver ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Stale Battle Cards (refresh queue)</h2>
        <DataTable
          rows={stale}
          columns={staleCols}
          emptyMessage="All cards fresh."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
