import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RadarRow = {
  id: string;
  customer_email: string;
  opportunity_type: string;
  product_sku: string | null;
  estimated_value_rupees: number;
  ripeness_score: number;
  ripeness_tier: string;
  status: string;
  detected_at: string;
};

type TypeRow = {
  opportunity_type: string;
  open_count: number;
  pipeline_value_rupees: number;
  avg_ripeness: number;
};

type PlayRow = {
  id: string;
  customer_email: string;
  opportunity_type: string;
  play_channel: string;
  outcome: string | null;
  next_step: string | null;
  next_step_due: string | null;
  played_at: string;
};

type HotRow = {
  id: string;
  customer_email: string;
  opportunity_type: string;
  ripeness_score: number;
  estimated_value_rupees: number;
  recommended_play: string | null;
  detected_at: string;
};

type SummaryRow = {
  total_open: number;
  hot_count: number;
  pipeline_value_rupees: number;
  won_count: number;
  lost_count: number;
  plays_logged: number;
};

export default async function CustomerCrossSellOpportunityRadarPage() {
  const supabase = await getSupabaseServerClient();

  const [radarRes, typeRes, playRes, hotRes, summaryRes] = await Promise.all([
    supabase.rpc('ccsor_r2312_radar', { p_limit: 50 }),
    supabase.rpc('ccsor_r2312_type_breakdown'),
    supabase.rpc('ccsor_r2312_recent_plays', { p_limit: 50 }),
    supabase.rpc('ccsor_r2312_hot_list', { p_limit: 20 }),
    supabase.rpc('ccsor_r2312_summary'),
  ]);

  const radarRows = (radarRes.data as RadarRow[] | null) ?? [];
  const typeRows = (typeRes.data as TypeRow[] | null) ?? [];
  const playRows = (playRes.data as PlayRow[] | null) ?? [];
  const hotRows = (hotRes.data as HotRow[] | null) ?? [];
  const summary = ((summaryRes.data as SummaryRow[] | null) ?? [])[0] ?? {
    total_open: 0,
    hot_count: 0,
    pipeline_value_rupees: 0,
    won_count: 0,
    lost_count: 0,
    plays_logged: 0,
  };

  const radarCols: Column<RadarRow>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: RadarRow) => r.customer_email },
    { key: 'opportunity_type', header: 'Type', render: (r: RadarRow) => r.opportunity_type },
    { key: 'product_sku', header: 'SKU', render: (r: RadarRow) => r.product_sku ?? '-' },
    { key: 'estimated_value_rupees', header: 'Est. value', render: (r: RadarRow) => `Rs ${Number(r.estimated_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'ripeness_score', header: 'Ripeness', render: (r: RadarRow) => Number(r.ripeness_score ?? 0).toFixed(1) },
    { key: 'ripeness_tier', header: 'Tier', render: (r: RadarRow) => r.ripeness_tier },
    { key: 'status', header: 'Status', render: (r: RadarRow) => r.status },
    { key: 'detected_at', header: 'Detected', render: (r: RadarRow) => new Date(r.detected_at).toLocaleDateString() },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'opportunity_type', header: 'Type', render: (r: TypeRow) => r.opportunity_type },
    { key: 'open_count', header: 'Open', render: (r: TypeRow) => String(r.open_count ?? 0) },
    { key: 'pipeline_value_rupees', header: 'Pipeline', render: (r: TypeRow) => `Rs ${Number(r.pipeline_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'avg_ripeness', header: 'Avg ripeness', render: (r: TypeRow) => Number(r.avg_ripeness ?? 0).toFixed(1) },
  ];

  const playCols: Column<PlayRow>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: PlayRow) => r.customer_email },
    { key: 'opportunity_type', header: 'Type', render: (r: PlayRow) => r.opportunity_type },
    { key: 'play_channel', header: 'Channel', render: (r: PlayRow) => r.play_channel },
    { key: 'outcome', header: 'Outcome', render: (r: PlayRow) => r.outcome ?? '-' },
    { key: 'next_step', header: 'Next step', render: (r: PlayRow) => r.next_step ?? '-' },
    { key: 'next_step_due', header: 'Due', render: (r: PlayRow) => r.next_step_due ?? '-' },
    { key: 'played_at', header: 'Played', render: (r: PlayRow) => new Date(r.played_at).toLocaleDateString() },
  ];

  const hotCols: Column<HotRow>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: HotRow) => r.customer_email },
    { key: 'opportunity_type', header: 'Type', render: (r: HotRow) => r.opportunity_type },
    { key: 'ripeness_score', header: 'Ripeness', render: (r: HotRow) => Number(r.ripeness_score ?? 0).toFixed(1) },
    { key: 'estimated_value_rupees', header: 'Est. value', render: (r: HotRow) => `Rs ${Number(r.estimated_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'recommended_play', header: 'Play', render: (r: HotRow) => r.recommended_play ?? '-' },
    { key: 'detected_at', header: 'Detected', render: (r: HotRow) => new Date(r.detected_at).toLocaleDateString() },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer cross-sell opportunity radar</h1>
        <p className="text-sm text-gray-600">Accounts ripe for AMC tier-up, new equipment, training packs &amp; more. Tier ranks ripeness &gt;= 75 as hot.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Open</div>
          <div className="text-xl font-semibold">{summary.total_open}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Hot</div>
          <div className="text-xl font-semibold">{summary.hot_count}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Pipeline</div>
          <div className="text-xl font-semibold">Rs {Number(summary.pipeline_value_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Won</div>
          <div className="text-xl font-semibold">{summary.won_count}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Lost</div>
          <div className="text-xl font-semibold">{summary.lost_count}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Plays logged</div>
          <div className="text-xl font-semibold">{summary.plays_logged}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hot list (ripeness &gt;= 75)</h2>
        <DataTable<HotRow>
          columns={hotCols}
          rows={hotRows}
          rowKey={(r: HotRow, i: number) => r.id ?? String(i)}
          emptyMessage="No hot opportunities."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Radar (open & playing)</h2>
        <DataTable<RadarRow>
          columns={radarCols}
          rows={radarRows}
          rowKey={(r: RadarRow, i: number) => r.id ?? String(i)}
          emptyMessage="No open opportunities."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Type breakdown</h2>
        <DataTable<TypeRow>
          columns={typeCols}
          rows={typeRows}
          rowKey={(r: TypeRow, i: number) => `${r.opportunity_type}-${i}`}
          emptyMessage="No types tracked yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent play log</h2>
        <DataTable<PlayRow>
          columns={playCols}
          rows={playRows}
          rowKey={(r: PlayRow, i: number) => r.id ?? String(i)}
          emptyMessage="No plays logged yet."
        />
      </section>
    </main>
  );
}
