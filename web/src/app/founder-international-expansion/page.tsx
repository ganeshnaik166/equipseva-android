import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';

type Summary = {
  total_countries: number;
  researching: number;
  market_validation: number;
  partner_signed: number;
  pilot: number;
  active: number;
  paused: number;
  exited: number;
  total_tam_inr: number;
  total_addressable_hospitals: number;
  active_currencies: number;
  milestones_30d: number;
  milestones_all: number;
  revenue_milestones_value_inr: number;
};

type CountryRow = {
  id: string;
  country_code: string;
  country_name: string;
  currency_code: string;
  expansion_status: string;
  regulatory_burden_band: string | null;
  estimated_market_size_rupees: number | null;
  estimated_total_addressable_hospitals: number | null;
  entered_at: string | null;
  activated_at: string | null;
  created_at: string;
};

type MilestoneRow = {
  id: string;
  country_id: string | null;
  country_code: string | null;
  country_name: string | null;
  milestone_kind: string;
  description: string | null;
  value_rupees: number | null;
  achieved_at: string;
};

type CurrencyRow = {
  currency_code: string;
  currency_label: string | null;
  exchange_rate_inr: number;
  exchange_rate_source: string;
  last_updated_at: string;
  is_active: boolean;
};

function statusBadge(status: string) {
  const map: Record<string, string> = {
    researching: 'bg-slate-100 text-slate-800',
    market_validation: 'bg-amber-100 text-amber-800',
    partner_signed: 'bg-indigo-100 text-indigo-800',
    pilot: 'bg-blue-100 text-blue-800',
    active: 'bg-emerald-100 text-emerald-800',
    paused: 'bg-yellow-100 text-yellow-800',
    exited: 'bg-rose-100 text-rose-800',
  };
  return map[status] ?? 'bg-slate-100 text-slate-800';
}

function burdenBadge(band: string | null) {
  if (!band) return 'bg-slate-100 text-slate-600';
  const map: Record<string, string> = {
    low: 'bg-emerald-50 text-emerald-700',
    medium: 'bg-amber-50 text-amber-700',
    high: 'bg-orange-50 text-orange-700',
    very_high: 'bg-rose-50 text-rose-700',
  };
  return map[band] ?? 'bg-slate-100 text-slate-600';
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, countriesRes, milestonesRes, currenciesRes] = await Promise.all([
    supabase.rpc('founder_international_expansion_summary'),
    supabase.rpc('founder_international_countries_recent', { p_status: null, p_limit: 10 }),
    supabase.rpc('founder_international_milestones_recent', { p_country_id: null, p_limit: 25 }),
    supabase.rpc('founder_international_currency_table'),
  ]);

  const s: Summary = (summaryRes.data as Summary) ?? {
    total_countries: 0, researching: 0, market_validation: 0, partner_signed: 0,
    pilot: 0, active: 0, paused: 0, exited: 0, total_tam_inr: 0,
    total_addressable_hospitals: 0, active_currencies: 0, milestones_30d: 0,
    milestones_all: 0, revenue_milestones_value_inr: 0,
  };
  const countries: CountryRow[] = (countriesRes.data as CountryRow[]) ?? [];
  const milestones: MilestoneRow[] = (milestonesRes.data as MilestoneRow[]) ?? [];
  const currencies: CurrencyRow[] = (currenciesRes.data as CurrencyRow[]) ?? [];

  const cards = [
    { label: 'Total Countries', value: formatNumber(s.total_countries) },
    { label: 'Researching', value: formatNumber(s.researching) },
    { label: 'Market Validation', value: formatNumber(s.market_validation) },
    { label: 'Partner Signed', value: formatNumber(s.partner_signed) },
    { label: 'Pilot', value: formatNumber(s.pilot) },
    { label: 'Active', value: formatNumber(s.active) },
    { label: 'Paused', value: formatNumber(s.paused) },
    { label: 'Exited', value: formatNumber(s.exited) },
    { label: 'Total TAM (₹)', value: formatNumber(Math.round(s.total_tam_inr ?? 0)) },
    { label: 'Addressable Hospitals', value: formatNumber(s.total_addressable_hospitals) },
    { label: 'Active Currencies', value: formatNumber(s.active_currencies) },
    { label: 'Milestones (30d)', value: formatNumber(s.milestones_30d) },
    { label: 'Milestones (All)', value: formatNumber(s.milestones_all) },
    { label: 'Revenue Milestones (₹)', value: formatNumber(Math.round(s.revenue_milestones_value_inr ?? 0)) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold text-slate-900">International Expansion</h1>
        <p className="mt-1 text-sm text-slate-600">
          Cross-border expansion infrastructure {'<'} country pipeline {'>'} milestone tracking {'>'} FX rates.
        </p>
      </header>

      <section className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-slate-200 bg-white p-3">
            <div className="text-[11px] uppercase tracking-wide text-slate-500">{c.label}</div>
            <div className="mt-1 text-lg font-semibold text-slate-900 tabular-nums">{c.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-3">Country Pipeline</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-xs uppercase text-slate-600">
              <tr>
                <th className="px-3 py-2 text-left">Code</th>
                <th className="px-3 py-2 text-left">Country</th>
                <th className="px-3 py-2 text-left">Ccy</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-left">Burden</th>
                <th className="px-3 py-2 text-right">TAM (₹)</th>
                <th className="px-3 py-2 text-right">Hospitals</th>
                <th className="px-3 py-2 text-left">Activated</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {countries.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-6 text-center text-slate-500">No countries registered yet.</td></tr>
              ) : countries.map((c) => (
                <tr key={c.id} className="hover:bg-slate-50">
                  <td className="px-3 py-2 font-mono text-xs text-slate-700">{c.country_code}</td>
                  <td className="px-3 py-2 text-slate-900">{c.country_name}</td>
                  <td className="px-3 py-2 font-mono text-xs text-slate-700">{c.currency_code}</td>
                  <td className="px-3 py-2">
                    <span className={`inline-flex rounded px-2 py-0.5 text-xs font-medium ${statusBadge(c.expansion_status)}`}>
                      {c.expansion_status}
                    </span>
                  </td>
                  <td className="px-3 py-2">
                    <span className={`inline-flex rounded px-2 py-0.5 text-xs ${burdenBadge(c.regulatory_burden_band)}`}>
                      {c.regulatory_burden_band ?? '—'}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-900">
                    {formatNumber(Math.round(Number(c.estimated_market_size_rupees ?? 0)))}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-700">
                    {formatNumber(c.estimated_total_addressable_hospitals ?? 0)}
                  </td>
                  <td className="px-3 py-2 text-xs text-slate-600">
                    {c.activated_at ? new Date(c.activated_at).toLocaleDateString() : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-3">Milestone Feed</h2>
        <div className="rounded-lg border border-slate-200 bg-white divide-y divide-slate-100">
          {milestones.length === 0 ? (
            <div className="px-4 py-6 text-center text-sm text-slate-500">No milestones logged yet.</div>
          ) : milestones.map((m) => (
            <div key={m.id} className="px-4 py-3 flex items-start gap-3">
              <span className="inline-flex shrink-0 rounded bg-indigo-50 px-2 py-0.5 text-xs font-medium text-indigo-700">
                {m.milestone_kind}
              </span>
              <div className="flex-1 min-w-0">
                <div className="text-sm text-slate-900">
                  <span className="font-medium">{m.country_code ?? '??'}</span>
                  <span className="text-slate-500"> · {m.country_name ?? 'unknown'}</span>
                </div>
                {m.description ? (
                  <div className="mt-0.5 text-xs text-slate-600 truncate">{m.description}</div>
                ) : null}
              </div>
              <div className="text-right shrink-0">
                {Number(m.value_rupees ?? 0) > 0 ? (
                  <div className="text-sm font-semibold text-slate-900 tabular-nums">
                    {'₹'}{formatNumber(Math.round(Number(m.value_rupees)))}
                  </div>
                ) : null}
                <div className="text-[11px] text-slate-500">
                  {new Date(m.achieved_at).toLocaleDateString()}
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-3">Currency Rates (1 unit foreign = X INR)</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-xs uppercase text-slate-600">
              <tr>
                <th className="px-3 py-2 text-left">Code</th>
                <th className="px-3 py-2 text-left">Label</th>
                <th className="px-3 py-2 text-right">Rate (INR)</th>
                <th className="px-3 py-2 text-left">Source</th>
                <th className="px-3 py-2 text-left">Last Updated</th>
                <th className="px-3 py-2 text-left">Active</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {currencies.length === 0 ? (
                <tr><td colSpan={6} className="px-3 py-6 text-center text-slate-500">No currencies configured.</td></tr>
              ) : currencies.map((cu) => (
                <tr key={cu.currency_code} className="hover:bg-slate-50">
                  <td className="px-3 py-2 font-mono text-xs text-slate-700">{cu.currency_code}</td>
                  <td className="px-3 py-2 text-slate-900">{cu.currency_label ?? '—'}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-900">
                    {Number(cu.exchange_rate_inr).toFixed(4)}
                  </td>
                  <td className="px-3 py-2 text-xs text-slate-600">{cu.exchange_rate_source}</td>
                  <td className="px-3 py-2 text-xs text-slate-600">
                    {new Date(cu.last_updated_at).toLocaleString()}
                  </td>
                  <td className="px-3 py-2">
                    {cu.is_active ? (
                      <span className="inline-flex rounded bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-800">active</span>
                    ) : (
                      <span className="inline-flex rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-700">inactive</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="pt-4 text-xs text-slate-500">
        Source: founder_international_countries / _milestones / _currencies — RLS founder-only.
      </footer>
    </main>
  );
}
