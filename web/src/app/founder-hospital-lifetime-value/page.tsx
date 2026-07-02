import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInr(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Math.round(Number(n)).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return '-';
  return (Number(n) * 100).toFixed(1) + '%';
}

export default async function FounderHospitalLifetimeValuePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let headline: any = null;
  let ladder: any[] = [];
  let vipList: any[] = [];
  let buckets: any[] = [];
  let movers: any[] = [];

  try {
    const r = await sb.rpc('founder_ltv_headline');
    headline = (r.data && r.data[0]) ?? null;
  } catch { headline = null; }
  try {
    const r = await sb.rpc('founder_ltv_ladder');
    ladder = r.data ?? [];
  } catch { ladder = []; }
  try {
    const r = await sb.rpc('founder_ltv_vip_list');
    vipList = r.data ?? [];
  } catch { vipList = []; }
  try {
    const r = await sb.rpc('founder_ltv_retention_buckets');
    buckets = r.data ?? [];
  } catch { buckets = []; }
  try {
    const r = await sb.rpc('founder_ltv_top_movers');
    movers = r.data ?? [];
  } catch { movers = []; }

  const kpis: Kpi[] = [
    { label: 'Total Hospitals', value: String(headline?.total_hospitals ?? '-') },
    { label: 'Scored', value: String(headline?.scored_hospitals ?? '-') },
    { label: 'VIP Promoted', value: String(headline?.vip_count ?? '-') },
    { label: 'Total LTV', value: fmtInr(headline?.total_ltv_rupees) },
    { label: 'Median LTV', value: fmtInr(headline?.median_ltv_rupees) },
    { label: 'Top Decile LTV', value: fmtInr(headline?.top_decile_ltv_rupees) },
    { label: 'Avg Retention', value: fmtPct(headline?.avg_retention) },
    { label: 'Projected 12m', value: fmtInr(headline?.projected_12m_rupees) },
    { label: 'Cumulative Rev', value: fmtInr(headline?.cumulative_rev_rupees) },
    { label: 'Active 90d', value: String(headline?.active_hospitals_90d ?? '-') },
    { label: 'Churned', value: String(headline?.churned_hospitals ?? '-') },
    { label: 'P50 LTV', value: fmtInr(headline?.ladder_p50_rupees) },
    { label: 'P90 LTV', value: fmtInr(headline?.ladder_p90_rupees) },
    { label: 'P99 LTV', value: fmtInr(headline?.ladder_p99_rupees) },
    { label: 'AMC Hospitals', value: String(headline?.hospitals_with_amc ?? '-') },
    { label: 'Last Recompute', value: headline?.last_recompute_at ? new Date(headline.last_recompute_at).toLocaleString() : '-' },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'rank_position', header: 'Rank', render: (r: any) => r.rank_position ?? '-' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'cumulative_rev_rupees', header: 'Cum Rev', render: (r: any) => fmtInr(r.cumulative_rev_rupees) },
    { key: 'projected_next_12m_rupees', header: 'Proj 12m', render: (r: any) => fmtInr(r.projected_next_12m_rupees) },
    { key: 'retention_prob', header: 'Retention', render: (r: any) => fmtPct(r.retention_prob) },
    { key: 'ltv_rupees', header: 'LTV', render: (r: any) => fmtInr(r.ltv_rupees) },
  ];

  const vipCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'promoted_to_tier', header: 'Tier', render: (r: any) => r.promoted_to_tier ?? '-' },
    { key: 'promoted_at', header: 'Promoted At', render: (r: any) => r.promoted_at ? new Date(r.promoted_at).toLocaleString() : '-' },
    { key: 'rationale', header: 'Rationale', render: (r: any) => r.rationale ?? '-' },
  ];

  const bucketCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket ?? '-' },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => r.hospital_count ?? '-' },
    { key: 'avg_ltv_rupees', header: 'Avg LTV', render: (r: any) => fmtInr(r.avg_ltv_rupees) },
    { key: 'sum_ltv_rupees', header: 'Sum LTV', render: (r: any) => fmtInr(r.sum_ltv_rupees) },
  ];

  const moverCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'current_ltv', header: 'Current LTV', render: (r: any) => fmtInr(r.current_ltv) },
    { key: 'prior_ltv', header: 'Prior LTV', render: (r: any) => fmtInr(r.prior_ltv) },
    { key: 'delta_ltv', header: 'Delta', render: (r: any) => fmtInr(r.delta_ltv) },
    { key: 'delta_pct', header: 'Delta %', render: (r: any) => (r.delta_pct != null ? r.delta_pct + '%' : '-') },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Lifetime-Value Ladder</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>Cumulative + projected revenue x retention; rank for VIP-tier promotion.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>LTV Ladder (top 100)</h2>
        <DataTable columns={ladderCols} rows={ladder} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Movers</h2>
        <DataTable columns={moverCols} rows={movers} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Retention Buckets</h2>
        <DataTable columns={bucketCols} rows={buckets} rowKey={(r: any) => r.bucket} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>VIP Promotions</h2>
        <DataTable columns={vipCols} rows={vipList} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
