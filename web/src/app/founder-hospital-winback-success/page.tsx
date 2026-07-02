import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(1) + '%';
}

function dateStr(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return '-'; }
}

export default async function FounderHospitalWinbackSuccessPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let recent: any[] = [];
  let byChannel: any[] = [];
  let trend: any[] = [];
  let topSaves: any[] = [];
  let stories: any[] = [];
  let tierMove: any[] = [];

  try {
    const r = await sb.rpc('founder_winback_kpis');
    if (r.data && Array.isArray(r.data) && r.data.length > 0) kpis = r.data[0];
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_winback_recent', { p_limit: 50 });
    recent = (r.data as any[]) ?? [];
  } catch { recent = []; }

  try {
    const r = await sb.rpc('founder_winback_by_channel');
    byChannel = (r.data as any[]) ?? [];
  } catch { byChannel = []; }

  try {
    const r = await sb.rpc('founder_winback_monthly_trend');
    trend = (r.data as any[]) ?? [];
  } catch { trend = []; }

  try {
    const r = await sb.rpc('founder_winback_top_saves', { p_limit: 10 });
    topSaves = (r.data as any[]) ?? [];
  } catch { topSaves = []; }

  try {
    const r = await sb.rpc('founder_winback_stories', { p_limit: 20 });
    stories = (r.data as any[]) ?? [];
  } catch { stories = []; }

  try {
    const r = await sb.rpc('founder_winback_tier_movement');
    tierMove = (r.data as any[]) ?? [];
  } catch { tierMove = []; }

  const k: Kpi[] = [
    { label: 'Total winbacks', value: String(kpis.total_winbacks ?? 0) },
    { label: 'Winbacks 30d', value: String(kpis.winbacks_30d ?? 0) },
    { label: 'Winbacks 90d', value: String(kpis.winbacks_90d ?? 0) },
    { label: 'Winbacks YTD', value: String(kpis.winbacks_ytd ?? 0) },
    { label: 'Hospitals recovered', value: String(kpis.hospitals_recovered ?? 0) },
    { label: 'Cost to save', value: rupees(kpis.total_cost_to_save_rupees) },
    { label: 'Revenue regained', value: rupees(kpis.total_revenue_regained_rupees) },
    { label: 'Net revenue', value: rupees(kpis.net_revenue_rupees) },
    { label: 'ROI', value: pct(kpis.roi_pct) },
    { label: 'Avg days churned', value: String(kpis.avg_days_churned ?? '-') },
    { label: 'Median cost/save', value: rupees(kpis.median_cost_per_save_rupees) },
    { label: 'Cost 30d', value: rupees(kpis.cost_30d_rupees) },
    { label: 'Revenue 30d', value: rupees(kpis.revenue_30d_rupees) },
    { label: 'Best channel', value: String(kpis.best_channel ?? '-') },
    { label: 'Top tier recovered', value: String(kpis.top_tier_recovered ?? '-') },
    { label: 'Shareable stories', value: String(kpis.shareable_stories ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'reactivated_at', header: 'Reactivated', render: (r: any) => dateStr(r.reactivated_at) },
    { key: 'days_churned', header: 'Days churned', render: (r: any) => String(r.days_churned ?? '-') },
    { key: 'prior_amc_tier', header: 'Prior tier', render: (r: any) => r.prior_amc_tier ?? '-' },
    { key: 'new_amc_tier', header: 'New tier', render: (r: any) => r.new_amc_tier ?? '-' },
    { key: 'cost_to_save_rupees', header: 'Cost', render: (r: any) => rupees(r.cost_to_save_rupees) },
    { key: 'revenue_regained_rupees', header: 'Revenue', render: (r: any) => rupees(r.revenue_regained_rupees) },
    { key: 'net_rupees', header: 'Net', render: (r: any) => rupees(r.net_rupees) },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '-' },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '-' },
    { key: 'winbacks', header: 'Winbacks', render: (r: any) => String(r.winbacks ?? 0) },
    { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.total_cost_rupees) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => rupees(r.total_revenue_rupees) },
    { key: 'net_rupees', header: 'Net', render: (r: any) => rupees(r.net_rupees) },
    { key: 'roi_pct', header: 'ROI', render: (r: any) => pct(r.roi_pct) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => dateStr(r.month_start) },
    { key: 'winbacks', header: 'Winbacks', render: (r: any) => String(r.winbacks ?? 0) },
    { key: 'cost_rupees', header: 'Cost', render: (r: any) => rupees(r.cost_rupees) },
    { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => rupees(r.revenue_rupees) },
    { key: 'net_rupees', header: 'Net', render: (r: any) => rupees(r.net_rupees) },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'reactivated_at', header: 'Reactivated', render: (r: any) => dateStr(r.reactivated_at) },
    { key: 'net_rupees', header: 'Net', render: (r: any) => rupees(r.net_rupees) },
    { key: 'roi_pct', header: 'ROI', render: (r: any) => pct(r.roi_pct) },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '-' },
    { key: 'has_story', header: 'Story?', render: (r: any) => r.has_story ? 'yes' : 'no' },
  ];

  const storyCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'headline', header: 'Headline', render: (r: any) => r.headline ?? '-' },
    { key: 'shareable', header: 'Shareable', render: (r: any) => r.shareable ? 'yes' : 'no' },
    { key: 'shared_at', header: 'Shared', render: (r: any) => dateStr(r.shared_at) },
    { key: 'created_at', header: 'Created', render: (r: any) => dateStr(r.created_at) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Hospital Winback Success Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Every churned hospital we brought back. Cost vs revenue, by channel, with founder stories. r1604.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        {k.map((kpi) => (
          <div key={kpi.label} style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{kpi.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{kpi.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent winbacks</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By channel</h2>
        <DataTable columns={channelCols} rows={byChannel} rowKey={(r: any) => r.channel} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly trend (12mo)</h2>
        <DataTable columns={trendCols} rows={trend} rowKey={(r: any) => String(r.month_start)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top saves</h2>
        <DataTable columns={topCols} rows={topSaves} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Founder stories</h2>
        <DataTable columns={storyCols} rows={stories} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tier movement</h2>
        <DataTable
          columns={[
            { key: 'prior_tier', header: 'Prior', render: (r: any) => r.prior_tier ?? '-' },
            { key: 'new_tier', header: 'New', render: (r: any) => r.new_tier ?? '-' },
            { key: 'moves', header: 'Moves', render: (r: any) => String(r.moves ?? 0) },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => rupees(r.revenue_rupees) },
          ]}
          rows={tierMove}
          rowKey={(r: any) => String(r.prior_tier) + '|' + String(r.new_tier)}
        />
      </section>
    </div>
  );
}
