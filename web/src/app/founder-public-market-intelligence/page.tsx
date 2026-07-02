import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';

type Summary = {
  total_competitors: number;
  direct_amc_competitor_count: number;
  critical_threat_count: number;
  high_threat_count: number;
  medium_threat_count: number;
  low_threat_count: number;
  total_market_pricing_snapshots: number;
  pricing_snapshots_30d: number;
  avg_competitor_monthly_fee_rupees: number;
  our_avg_monthly_fee_rupees: number;
  pricing_advantage_pct: number | null;
  top_funded_competitor: string;
  top_funded_amount_rupees: number;
  generated_at: string;
};

type Competitor = {
  id: string;
  competitor_name: string;
  competitor_kind: string | null;
  primary_segment: string | null;
  founded_year: number | null;
  headquarters_city: string | null;
  headquarters_state: string | null;
  employee_count_band: string | null;
  funding_status: string | null;
  total_funding_rupees: number | null;
  market_share_estimate_pct: number | null;
  competitive_threat_band: string;
  primary_source_url: string | null;
  last_intel_at: string | null;
  created_at: string;
};

type PricingSnapshot = {
  id: string;
  competitor_id: string | null;
  competitor_name: string | null;
  tier_label: string;
  monthly_fee_rupees: number | null;
  annual_fee_rupees: number | null;
  observed_at: string;
  source_url: string | null;
};

const THREAT_BADGE: Record<string, string> = {
  critical: 'bg-red-100 text-red-900 border-red-300',
  high: 'bg-orange-100 text-orange-900 border-orange-300',
  medium: 'bg-amber-100 text-amber-900 border-amber-300',
  low: 'bg-green-100 text-green-900 border-green-300',
  negligible: 'bg-slate-100 text-slate-700 border-slate-300',
};

export default async function FounderPublicMarketIntelligencePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, competitorsRes, snapshotsRes] = await Promise.all([
    supabase.rpc('founder_public_market_intelligence_summary'),
    supabase.rpc('founder_market_competitors_recent', { p_threat_band: null, p_limit: 50 }),
    supabase.rpc('founder_market_pricing_snapshots_recent', { p_competitor_id: null, p_limit: 100 }),
  ]);

  const summary = (summaryRes.data ?? {}) as Summary;
  const competitors = (competitorsRes.data ?? []) as Competitor[];
  const snapshots = (snapshotsRes.data ?? []) as PricingSnapshot[];

  const advantage = summary.pricing_advantage_pct;
  const advantageGood = advantage !== null && advantage !== undefined && advantage > 0;

  const cards: Array<{ label: string; value: string; tone?: string }> = [
    { label: 'Total Competitors', value: formatNumber(summary.total_competitors ?? 0) },
    { label: 'Direct AMC Competitors', value: formatNumber(summary.direct_amc_competitor_count ?? 0) },
    { label: 'Critical Threats', value: formatNumber(summary.critical_threat_count ?? 0), tone: 'red' },
    { label: 'High Threats', value: formatNumber(summary.high_threat_count ?? 0), tone: 'orange' },
    { label: 'Medium Threats', value: formatNumber(summary.medium_threat_count ?? 0), tone: 'amber' },
    { label: 'Low Threats', value: formatNumber(summary.low_threat_count ?? 0), tone: 'green' },
    { label: 'Pricing Snapshots (all)', value: formatNumber(summary.total_market_pricing_snapshots ?? 0) },
    { label: 'Pricing Snapshots (30d)', value: formatNumber(summary.pricing_snapshots_30d ?? 0) },
    { label: 'Avg Competitor Monthly Fee', value: `₹${formatNumber(Math.round(summary.avg_competitor_monthly_fee_rupees ?? 0))}` },
    { label: 'Our Avg Monthly Fee', value: `₹${formatNumber(Math.round(summary.our_avg_monthly_fee_rupees ?? 0))}` },
    { label: 'Pricing Advantage %', value: advantage === null || advantage === undefined ? 'n/a' : `${advantage}%`, tone: advantageGood ? 'green' : 'red' },
    { label: 'Top Funded Competitor', value: summary.top_funded_competitor ?? 'none' },
    { label: 'Top Funded Amount', value: `₹${formatNumber(Math.round(summary.top_funded_amount_rupees ?? 0))}` },
    { label: 'Generated At', value: summary.generated_at ? new Date(summary.generated_at).toLocaleString('en-IN') : 'n/a' },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold text-slate-900">Public Market Intelligence</h1>
        <p className="text-sm text-slate-600">
          Competitor + market intel tracker. Threat band, funding, pricing snapshots, and our pricing position.
        </p>
      </header>

      <section
        className={`rounded-lg border p-4 ${advantageGood ? 'border-green-300 bg-green-50' : 'border-red-300 bg-red-50'}`}
      >
        <div className="flex flex-col gap-1 md:flex-row md:items-center md:justify-between">
          <div>
            <div className="text-xs uppercase tracking-wide text-slate-600">Pricing Position vs Market</div>
            <div className="text-lg font-semibold text-slate-900">
              {advantage === null || advantage === undefined
                ? 'No competitor pricing data yet'
                : advantageGood
                  ? `We are ${advantage}% cheaper than the avg competitor`
                  : `We are ${Math.abs(advantage)}% more expensive than the avg competitor`}
            </div>
          </div>
          <div className="text-sm text-slate-700">
            Us: ₹{formatNumber(Math.round(summary.our_avg_monthly_fee_rupees ?? 0))} /mo
            {' '}vs Competitors: ₹{formatNumber(Math.round(summary.avg_competitor_monthly_fee_rupees ?? 0))} /mo
          </div>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-slate-200 bg-white p-3 shadow-sm">
            <div className="text-xs uppercase tracking-wide text-slate-500">{c.label}</div>
            <div className={`mt-1 text-lg font-semibold ${c.tone === 'red' ? 'text-red-700' : c.tone === 'orange' ? 'text-orange-700' : c.tone === 'amber' ? 'text-amber-700' : c.tone === 'green' ? 'text-green-700' : 'text-slate-900'}`}>
              {c.value}
            </div>
          </div>
        ))}
      </section>

      <section className="rounded-lg border border-slate-200 bg-white shadow-sm">
        <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-base font-semibold text-slate-900">Competitor Ledger (top 50 by threat)</h2>
          <span className="text-xs text-slate-500">{formatNumber(competitors.length)} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Threat</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Competitor</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Kind</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Segment</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">HQ</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Founded</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Employees</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Funding</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Funding ₹</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Share %</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Last Intel</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {competitors.length === 0 ? (
                <tr>
                  <td colSpan={11} className="px-3 py-6 text-center text-slate-500">
                    No competitors registered yet.
                  </td>
                </tr>
              ) : (
                competitors.map((c) => (
                  <tr key={c.id} className="hover:bg-slate-50">
                    <td className="px-3 py-2">
                      <span className={`inline-flex rounded-full border px-2 py-0.5 text-xs font-medium ${THREAT_BADGE[c.competitive_threat_band] ?? 'bg-slate-100 text-slate-700 border-slate-300'}`}>
                        {c.competitive_threat_band}
                      </span>
                    </td>
                    <td className="px-3 py-2 font-medium text-slate-900">{c.competitor_name}</td>
                    <td className="px-3 py-2 text-slate-700">{c.competitor_kind ?? '—'}</td>
                    <td className="px-3 py-2 text-slate-700">{c.primary_segment ?? '—'}</td>
                    <td className="px-3 py-2 text-slate-700">
                      {[c.headquarters_city, c.headquarters_state].filter(Boolean).join(', ') || '—'}
                    </td>
                    <td className="px-3 py-2 text-slate-700">{c.founded_year ?? '—'}</td>
                    <td className="px-3 py-2 text-slate-700">{c.employee_count_band ?? '—'}</td>
                    <td className="px-3 py-2 text-slate-700">{c.funding_status ?? '—'}</td>
                    <td className="px-3 py-2 text-right text-slate-900">
                      {c.total_funding_rupees ? `₹${formatNumber(Math.round(c.total_funding_rupees))}` : '—'}
                    </td>
                    <td className="px-3 py-2 text-right text-slate-700">
                      {c.market_share_estimate_pct !== null ? `${c.market_share_estimate_pct}%` : '—'}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {c.last_intel_at ? new Date(c.last_intel_at).toLocaleDateString('en-IN') : '—'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-slate-200 bg-white shadow-sm">
        <div className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-base font-semibold text-slate-900">Pricing Snapshots (latest 100)</h2>
          <span className="text-xs text-slate-500">{formatNumber(snapshots.length)} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Observed</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Competitor</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Tier</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Monthly ₹</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Annual ₹</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Source</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {snapshots.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-3 py-6 text-center text-slate-500">
                    No pricing snapshots recorded yet.
                  </td>
                </tr>
              ) : (
                snapshots.map((s) => (
                  <tr key={s.id} className="hover:bg-slate-50">
                    <td className="px-3 py-2 text-slate-700">
                      {new Date(s.observed_at).toLocaleDateString('en-IN')}
                    </td>
                    <td className="px-3 py-2 font-medium text-slate-900">{s.competitor_name ?? '—'}</td>
                    <td className="px-3 py-2 text-slate-700">{s.tier_label}</td>
                    <td className="px-3 py-2 text-right text-slate-900">
                      {s.monthly_fee_rupees ? `₹${formatNumber(Math.round(s.monthly_fee_rupees))}` : '—'}
                    </td>
                    <td className="px-3 py-2 text-right text-slate-900">
                      {s.annual_fee_rupees ? `₹${formatNumber(Math.round(s.annual_fee_rupees))}` : '—'}
                    </td>
                    <td className="px-3 py-2 text-slate-500">
                      {s.source_url ? (
                        <a href={s.source_url} target="_blank" rel="noreferrer" className="text-blue-600 hover:underline">
                          link
                        </a>
                      ) : (
                        '—'
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="text-xs text-slate-500">
        Founder-only. Public market intel signals — competitor watch + pricing position.
      </footer>
    </div>
  );
}
