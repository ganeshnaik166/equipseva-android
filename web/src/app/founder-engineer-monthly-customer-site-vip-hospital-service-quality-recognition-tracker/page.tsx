import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { total_engineers: number; elite_count: number; watchlist_count: number; avg_quality: number; total_bonus_rupees: number };
type TopRow = { engineer_code: string; engineer_name: string; hospital_name: string; vip_tier: string; quality_score: number; bonus_rupees: number; recognition_band: string };
type BandRow = { recognition_band: string; n: number; avg_quality: number; total_bonus: number };
type TierRow = { vip_tier: string; engineers: number; avg_csat: number; avg_fvfr: number; avg_uptime: number };
type EventRow = { event_type: string; events: number; total_weight: number };
type WatchRow = { engineer_code: string; engineer_name: string; hospital_name: string; quality_score: number; complaints: number; escalations: number };
type PayoutRow = { status: string; n: number; total_bonus: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, top, band, tier, evs, watch, payout] = await Promise.all([
    supabase.rpc('vip_recognition_overview_r2946'),
    supabase.rpc('vip_recognition_top_engineers_r2946'),
    supabase.rpc('vip_recognition_band_breakdown_r2946'),
    supabase.rpc('vip_recognition_tier_breakdown_r2946'),
    supabase.rpc('vip_recognition_event_summary_r2946'),
    supabase.rpc('vip_recognition_watchlist_r2946'),
    supabase.rpc('vip_recognition_payout_status_r2946'),
  ]);

  const overview: Overview | null = (ov.data?.[0] ?? null) as Overview | null;
  const topRows: TopRow[] = (top.data ?? []) as TopRow[];
  const bandRows: BandRow[] = (band.data ?? []) as BandRow[];
  const tierRows: TierRow[] = (tier.data ?? []) as TierRow[];
  const evRows: EventRow[] = (evs.data ?? []) as EventRow[];
  const watchRows: WatchRow[] = (watch.data ?? []) as WatchRow[];
  const payoutRows: PayoutRow[] = (payout.data ?? []) as PayoutRow[];

  const topCols: Column<TopRow>[] = [
    { key: 'engineer_code', header: 'Code' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'VIP Hospital' },
    { key: 'vip_tier', header: 'Tier' },
    { key: 'quality_score', header: 'Quality' },
    { key: 'bonus_rupees', header: 'Bonus (Rs)' },
    { key: 'recognition_band', header: 'Band' },
  ];
  const bandCols: Column<BandRow>[] = [
    { key: 'recognition_band', header: 'Band' },
    { key: 'n', header: 'Engineers' },
    { key: 'avg_quality', header: 'Avg Quality' },
    { key: 'total_bonus', header: 'Total Bonus' },
  ];
  const tierCols: Column<TierRow>[] = [
    { key: 'vip_tier', header: 'VIP Tier' },
    { key: 'engineers', header: 'Engineers' },
    { key: 'avg_csat', header: 'Avg CSAT' },
    { key: 'avg_fvfr', header: 'Avg FVFR %' },
    { key: 'avg_uptime', header: 'Avg Uptime %' },
  ];
  const evCols: Column<EventRow>[] = [
    { key: 'event_type', header: 'Event' },
    { key: 'events', header: 'Count' },
    { key: 'total_weight', header: 'Weight' },
  ];
  const watchCols: Column<WatchRow>[] = [
    { key: 'engineer_code', header: 'Code' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Site' },
    { key: 'quality_score', header: 'Quality' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'escalations', header: 'Escalations' },
  ];
  const payoutCols: Column<PayoutRow>[] = [
    { key: 'status', header: 'Status' },
    { key: 'n', header: 'Records' },
    { key: 'total_bonus', header: 'Total Bonus (Rs)' },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly VIP-Hospital Service-Quality Recognition</h1>
        <p className="text-sm text-gray-600">Monthly recognition tracker for engineers at VIP customer sites — elite vs watchlist, bonuses & payout status.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="border p-3 rounded"><div className="text-xs text-gray-500">Engineers</div><div className="text-xl font-semibold">{overview?.total_engineers ?? 0}</div></div>
        <div className="border p-3 rounded"><div className="text-xs text-gray-500">Elite</div><div className="text-xl font-semibold">{overview?.elite_count ?? 0}</div></div>
        <div className="border p-3 rounded"><div className="text-xs text-gray-500">Watchlist</div><div className="text-xl font-semibold">{overview?.watchlist_count ?? 0}</div></div>
        <div className="border p-3 rounded"><div className="text-xs text-gray-500">Avg Quality</div><div className="text-xl font-semibold">{overview?.avg_quality ?? 0}</div></div>
        <div className="border p-3 rounded"><div className="text-xs text-gray-500">Total Bonus (Rs)</div><div className="text-xl font-semibold">{overview?.total_bonus_rupees ?? 0}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top engineers (quality &gt;= top 10)</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No top engineers" rowKey={(r,i)=>String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Band breakdown</h2>
        <DataTable rows={bandRows} columns={bandCols} emptyMessage="No bands" rowKey={(r,i)=>String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">VIP tier breakdown</h2>
        <DataTable rows={tierRows} columns={tierCols} emptyMessage="No tiers" rowKey={(r,i)=>String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recognition events</h2>
        <DataTable rows={evRows} columns={evCols} emptyMessage="No events" rowKey={(r,i)=>String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Watchlist (quality &lt;= good band)</h2>
        <DataTable rows={watchRows} columns={watchCols} emptyMessage="No watchlist" rowKey={(r,i)=>String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Payout status</h2>
        <DataTable rows={payoutRows} columns={payoutCols} emptyMessage="No payouts" rowKey={(r,i)=>String((r as { id?: string }).id ?? i)} />
      </section>
    </main>
  );
}
