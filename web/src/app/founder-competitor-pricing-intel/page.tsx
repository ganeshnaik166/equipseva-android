import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtRupees(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return '₹' + Math.round(v).toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toFixed(2) + '%';
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try {
    return new Date(String(s)).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return String(s);
  }
}

export default async function FounderCompetitorPricingIntelPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, recentRes, ladderRes, competitorsRes] = await Promise.all([
    supabase.rpc('founder_competitor_pricing_kpis'),
    supabase.rpc('founder_competitor_pricing_recent_observations'),
    supabase.rpc('founder_competitor_pricing_segment_ladder'),
    supabase.rpc('founder_competitor_pricing_top_competitors'),
  ]);

  const k: any = Array.isArray(kpisRes.data) ? (kpisRes.data[0] ?? {}) : (kpisRes.data ?? {});
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const ladder: any[] = Array.isArray(ladderRes.data) ? ladderRes.data : [];
  const competitors: any[] = Array.isArray(competitorsRes.data) ? competitorsRes.data : [];

  const underPriced = ladder.filter((r: any) => r.verdict === 'under-priced');
  const overPriced = ladder.filter((r: any) => r.verdict === 'over-priced');

  const kpis: Kpi[] = [
    { label: 'Total observations', value: fmtInt(k.total_observations) },
    { label: 'Last 90 days', value: fmtInt(k.observations_90d) },
    { label: 'Last 30 days', value: fmtInt(k.observations_30d) },
    { label: 'Last 7 days', value: fmtInt(k.observations_7d) },
    { label: 'Distinct competitors', value: fmtInt(k.distinct_competitors) },
    { label: 'Categories tracked', value: fmtInt(k.distinct_categories) },
    { label: 'Tiers tracked', value: fmtInt(k.distinct_tiers) },
    { label: 'Segments defined', value: fmtInt(k.segments_defined) },
    { label: 'Aggressive posture', value: fmtInt(k.segments_aggressive) },
    { label: 'Premium posture', value: fmtInt(k.segments_premium) },
    { label: 'Avg competitor quote', value: fmtRupees(k.avg_competitor_quote_rupees) },
    { label: 'Avg our quote', value: fmtRupees(k.avg_our_quote_rupees) },
    { label: 'Avg spread vs market', value: fmtPct(k.avg_spread_pct) },
    { label: 'Under-priced segments', value: fmtInt(k.under_priced_segments) },
    { label: 'Over-priced segments', value: fmtInt(k.over_priced_segments) },
    { label: 'RFQ losses logged', value: fmtInt(k.rfq_loss_observations) },
  ];

  const ladderColumns: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '—') },
    { key: 'hospital_tier', header: 'Tier', render: (r: any) => String(r.hospital_tier ?? '—') },
    { key: 'observations', header: 'Obs', render: (r: any) => fmtInt(r.observations) },
    { key: 'avg_competitor_rupees', header: 'Avg comp', render: (r: any) => fmtRupees(r.avg_competitor_rupees) },
    { key: 'avg_our_rupees', header: 'Avg ours', render: (r: any) => fmtRupees(r.avg_our_rupees) },
    { key: 'spread_pct', header: 'Spread', render: (r: any) => fmtPct(r.spread_pct) },
    { key: 'target_spread_pct', header: 'Target', render: (r: any) => fmtPct(r.target_spread_pct) },
    { key: 'posture', header: 'Posture', render: (r: any) => String(r.posture ?? 'unset') },
    { key: 'verdict', header: 'Verdict', render: (r: any) => String(r.verdict ?? '—') },
  ];

  const underColumns: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '—') },
    { key: 'hospital_tier', header: 'Tier', render: (r: any) => String(r.hospital_tier ?? '—') },
    { key: 'avg_competitor_rupees', header: 'Market avg', render: (r: any) => fmtRupees(r.avg_competitor_rupees) },
    { key: 'avg_our_rupees', header: 'Our avg', render: (r: any) => fmtRupees(r.avg_our_rupees) },
    { key: 'spread_pct', header: 'Below market by', render: (r: any) => fmtPct(r.spread_pct) },
    { key: 'observations', header: 'Obs', render: (r: any) => fmtInt(r.observations) },
  ];

  const overColumns: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '—') },
    { key: 'hospital_tier', header: 'Tier', render: (r: any) => String(r.hospital_tier ?? '—') },
    { key: 'avg_competitor_rupees', header: 'Market avg', render: (r: any) => fmtRupees(r.avg_competitor_rupees) },
    { key: 'avg_our_rupees', header: 'Our avg', render: (r: any) => fmtRupees(r.avg_our_rupees) },
    { key: 'spread_pct', header: 'Above market by', render: (r: any) => fmtPct(r.spread_pct) },
    { key: 'observations', header: 'Obs', render: (r: any) => fmtInt(r.observations) },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => String(r.competitor_name ?? '—') },
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '—') },
    { key: 'hospital_tier', header: 'Tier', render: (r: any) => String(r.hospital_tier ?? '—') },
    { key: 'job_kind', header: 'Kind', render: (r: any) => String(r.job_kind ?? '—') },
    { key: 'competitor_quote_rupees', header: 'Comp quote', render: (r: any) => fmtRupees(r.competitor_quote_rupees) },
    { key: 'our_quote_rupees', header: 'Our quote', render: (r: any) => fmtRupees(r.our_quote_rupees) },
    { key: 'spread_pct', header: 'Spread', render: (r: any) => fmtPct(r.spread_pct) },
    { key: 'source', header: 'Source', render: (r: any) => String(r.source ?? '—') },
    { key: 'city', header: 'City', render: (r: any) => String(r.city ?? '—') },
  ];

  const competitorColumns: Column<any>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => String(r.competitor_name ?? '—') },
    { key: 'observations', header: 'Obs', render: (r: any) => fmtInt(r.observations) },
    { key: 'categories_seen', header: 'Categories', render: (r: any) => fmtInt(r.categories_seen) },
    { key: 'tiers_seen', header: 'Tiers', render: (r: any) => fmtInt(r.tiers_seen) },
    { key: 'avg_quote_rupees', header: 'Avg quote', render: (r: any) => fmtRupees(r.avg_quote_rupees) },
    { key: 'rfq_losses', header: 'RFQ losses', render: (r: any) => fmtInt(r.rfq_losses) },
    { key: 'last_seen_at', header: 'Last seen', render: (r: any) => fmtDate(r.last_seen_at) },
  ];

  return (
    <div className="min-h-screen bg-neutral-50 p-6">
      <div className="mx-auto max-w-7xl space-y-8">
        <header className="space-y-1">
          <p className="text-xs uppercase tracking-widest text-neutral-500">r1487 · Growth</p>
          <h1 className="text-2xl font-semibold text-neutral-900">Competitor pricing intel ladder</h1>
          <p className="text-sm text-neutral-600">
            Observed competitor quotes per equipment-category and hospital-tier. Spread vs market drives under-priced
            and over-priced segment calls.
          </p>
        </header>

        <section>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {kpis.map((kpi: Kpi) => (
              <div
                key={kpi.label}
                className="rounded-lg border border-neutral-200 bg-white p-4 shadow-sm"
              >
                <div className="text-xs uppercase tracking-wide text-neutral-500">{kpi.label}</div>
                <div className="mt-1 text-lg font-semibold text-neutral-900">{kpi.value}</div>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Segment ladder · category × tier</h2>
          <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
            <DataTable columns={ladderColumns} rows={ladder} rowKey={(r: any) => r.id} />
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Under-priced segments (raise floor)</h2>
          <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
            <DataTable columns={underColumns} rows={underPriced} rowKey={(r: any) => r.id} />
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Over-priced segments (close win-rate gap)</h2>
          <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
            <DataTable columns={overColumns} rows={overPriced} rowKey={(r: any) => r.id} />
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Top competitors observed</h2>
          <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
            <DataTable columns={competitorColumns} rows={competitors} rowKey={(r: any) => r.competitor_name} />
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Recent observations (last 50)</h2>
          <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
            <DataTable columns={recentColumns} rows={recent} rowKey={(r: any) => r.id} />
          </div>
        </section>
      </div>
    </div>
  );
}
