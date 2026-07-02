import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "INR " + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(2) + "%";
}

export default async function FounderEngineerPayBandReviewPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let reviews: any[] = [];
  let bench: any[] = [];
  let grants: any[] = [];
  let pending: any[] = [];

  try {
    const r = await sb.rpc('founder_pay_band_kpis');
    kpis = r.data ?? {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_pay_band_current_reviews');
    reviews = (r.data as any[]) ?? [];
  } catch { reviews = []; }

  try {
    const r = await sb.rpc('founder_pay_band_tier_benchmark');
    bench = (r.data as any[]) ?? [];
  } catch { bench = []; }

  try {
    const r = await sb.rpc('founder_pay_band_recent_grants');
    grants = (r.data as any[]) ?? [];
  } catch { grants = []; }

  try {
    const r = await sb.rpc('founder_pay_band_pending_queue');
    pending = (r.data as any[]) ?? [];
  } catch { pending = []; }

  try { await sb.rpc('log_founder_pay_band_view', { p_view: 'pay_band_review' }); } catch {}

  const cards: Kpi[] = [
    { label: 'Total Reviews',         value: String(kpis.total_reviews ?? 0) },
    { label: 'Pending Reviews',       value: String(kpis.pending_reviews ?? 0) },
    { label: 'Approved Reviews',      value: String(kpis.approved_reviews ?? 0) },
    { label: 'Rejected Reviews',      value: String(kpis.rejected_reviews ?? 0) },
    { label: 'Deferred Reviews',      value: String(kpis.deferred_reviews ?? 0) },
    { label: 'Current Quarter',       value: String(kpis.current_quarter ?? "—") },
    { label: 'Tiers Under Review',    value: String(kpis.tiers_under_review ?? 0) },
    { label: 'Avg Variance vs Market',value: pct(kpis.avg_variance_pct) },
    { label: 'Max Variance',          value: pct(kpis.max_variance_pct) },
    { label: 'Min Variance',          value: pct(kpis.min_variance_pct) },
    { label: 'Total Raises Granted',  value: String(kpis.total_raises_granted ?? 0) },
    { label: 'Raises This Quarter',   value: String(kpis.raises_this_quarter ?? 0) },
    { label: 'Avg Raise',             value: rupees(kpis.avg_raise_rupees) },
    { label: 'Total Raise Spend',     value: rupees(kpis.total_raise_spend_rupees) },
    { label: 'Engineers w/ Raise',    value: String(kpis.engineers_with_raise ?? 0) },
    { label: 'Total Engineers',       value: String(kpis.total_engineers ?? 0) },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'review_quarter', header: 'Quarter', render: (r: any) => r.review_quarter ?? "—" },
    { key: 'tier',           header: 'Tier',    render: (r: any) => r.tier ?? "—" },
    { key: 'current_ceiling_rupees',  header: 'Our Ceiling',    render: (r: any) => rupees(r.current_ceiling_rupees) },
    { key: 'market_ceiling_rupees',   header: 'Market Ceiling', render: (r: any) => rupees(r.market_ceiling_rupees) },
    { key: 'recommended_ceiling_rupees', header: 'Recommended', render: (r: any) => rupees(r.recommended_ceiling_rupees) },
    { key: 'variance_pct',   header: 'Variance', render: (r: any) => pct(r.variance_pct) },
    { key: 'status',         header: 'Status',   render: (r: any) => r.status ?? "—" },
  ];

  const benchCols: Column<any>[] = [
    { key: 'tier',                  header: 'Tier',            render: (r: any) => r.tier ?? "—" },
    { key: 'engineers_count',       header: 'Engineers',       render: (r: any) => String(r.engineers_count ?? 0) },
    { key: 'current_floor_rupees',  header: 'Our Floor',       render: (r: any) => rupees(r.current_floor_rupees) },
    { key: 'current_ceiling_rupees',header: 'Our Ceiling',     render: (r: any) => rupees(r.current_ceiling_rupees) },
    { key: 'market_floor_rupees',   header: 'Market Floor',    render: (r: any) => rupees(r.market_floor_rupees) },
    { key: 'market_ceiling_rupees', header: 'Market Ceiling',  render: (r: any) => rupees(r.market_ceiling_rupees) },
    { key: 'variance_pct',          header: 'Variance',        render: (r: any) => pct(r.variance_pct) },
  ];

  const grantCols: Column<any>[] = [
    { key: 'engineer_id',     header: 'Engineer',       render: (r: any) => String(r.engineer_id ?? "—").slice(0, 8) },
    { key: 'tier',            header: 'Tier',           render: (r: any) => r.tier ?? "—" },
    { key: 'old_rate_rupees', header: 'Old Rate',       render: (r: any) => rupees(r.old_rate_rupees) },
    { key: 'new_rate_rupees', header: 'New Rate',       render: (r: any) => rupees(r.new_rate_rupees) },
    { key: 'delta_rupees',    header: 'Delta',          render: (r: any) => rupees(r.delta_rupees) },
    { key: 'effective_from',  header: 'Effective From', render: (r: any) => r.effective_from ?? "—" },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'review_quarter', header: 'Quarter',     render: (r: any) => r.review_quarter ?? "—" },
    { key: 'tier',           header: 'Tier',        render: (r: any) => r.tier ?? "—" },
    { key: 'variance_pct',   header: 'Variance',    render: (r: any) => pct(r.variance_pct) },
    { key: 'recommended_ceiling_rupees', header: 'Rec Ceiling', render: (r: any) => rupees(r.recommended_ceiling_rupees) },
    { key: 'age_days',       header: 'Age (days)',  render: (r: any) => Number(r.age_days ?? 0).toFixed(1) },
    { key: 'rationale',      header: 'Rationale',   render: (r: any) => r.rationale ?? "—" },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Engineer Pay-Band Review</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Quarterly per-tier pay-band review with market benchmarks and founder-approved raises.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', padding: 12, borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Current Quarter Reviews</h2>
        <DataTable columns={reviewCols} rows={reviews} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tier Benchmark Snapshot</h2>
        <DataTable columns={benchCols} rows={bench} rowKey={(r: any) => r.tier} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending Decisions</h2>
        <DataTable columns={pendingCols} rows={pending} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Raise Grants</h2>
        <DataTable columns={grantCols} rows={grants} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
