import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';

type Summary = {
  total_positions: number;
  total_currencies: number;
  total_countries: number;
  total_balance_inr_equivalent: number;
  bank_account_count: number;
  cash_in_hand_count: number;
  escrow_count: number;
  holding_account_count: number;
  forex_card_count: number;
  other_count: number;
  top_currency_by_inr: string;
  top_currency_inr_value: number;
  top_country_by_inr: string;
  top_country_inr_value: number;
  stale_positions_14d: number;
  positions_missing_inr: number;
};

type PositionRow = {
  id: string;
  currency_code: string;
  country_id: string | null;
  country_code: string | null;
  country_name: string | null;
  position_label: string;
  position_kind: string;
  balance_amount: number;
  balance_inr_equivalent: number | null;
  last_synced_at: string | null;
  bank_name: string | null;
  account_label_masked: string | null;
  notes: string | null;
  created_at: string;
};

type ByCurrencyRow = {
  currency_code: string;
  currency_label: string | null;
  exchange_rate_inr: number;
  position_count: number;
  total_balance_amount: number;
  total_balance_inr_equivalent: number;
  last_synced_at: string | null;
};

type ByCountryRow = {
  country_id: string;
  country_code: string;
  country_name: string;
  expansion_status: string;
  position_count: number;
  total_balance_inr_equivalent: number;
};

function kindBadge(kind: string) {
  const map: Record<string, string> = {
    bank_account: 'bg-blue-100 text-blue-800',
    cash_in_hand: 'bg-amber-100 text-amber-800',
    escrow: 'bg-violet-100 text-violet-800',
    holding_account: 'bg-indigo-100 text-indigo-800',
    forex_card: 'bg-emerald-100 text-emerald-800',
    other: 'bg-slate-100 text-slate-700',
  };
  return map[kind] ?? 'bg-slate-100 text-slate-700';
}

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

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, positionsRes, byCurrencyRes, byCountryRes] = await Promise.all([
    supabase.rpc('founder_multi_currency_treasury_summary'),
    supabase.rpc('founder_multi_currency_treasury_positions_recent', { p_limit: 50 }),
    supabase.rpc('founder_multi_currency_treasury_by_currency'),
    supabase.rpc('founder_multi_currency_treasury_by_country'),
  ]);

  const s: Summary = (summaryRes.data as Summary) ?? {
    total_positions: 0, total_currencies: 0, total_countries: 0,
    total_balance_inr_equivalent: 0,
    bank_account_count: 0, cash_in_hand_count: 0, escrow_count: 0,
    holding_account_count: 0, forex_card_count: 0, other_count: 0,
    top_currency_by_inr: '—', top_currency_inr_value: 0,
    top_country_by_inr: '—', top_country_inr_value: 0,
    stale_positions_14d: 0, positions_missing_inr: 0,
  };
  const positions: PositionRow[] = (positionsRes.data as PositionRow[]) ?? [];
  const byCurrency: ByCurrencyRow[] = (byCurrencyRes.data as ByCurrencyRow[]) ?? [];
  const byCountry: ByCountryRow[] = (byCountryRes.data as ByCountryRow[]) ?? [];

  const cards = [
    { label: 'Total Positions', value: formatNumber(s.total_positions) },
    { label: 'Currencies', value: formatNumber(s.total_currencies) },
    { label: 'Countries', value: formatNumber(s.total_countries) },
    { label: 'Total Balance (₹)', value: formatNumber(Math.round(s.total_balance_inr_equivalent ?? 0)) },
    { label: 'Bank Accounts', value: formatNumber(s.bank_account_count) },
    { label: 'Cash In Hand', value: formatNumber(s.cash_in_hand_count) },
    { label: 'Escrow', value: formatNumber(s.escrow_count) },
    { label: 'Holding', value: formatNumber(s.holding_account_count) },
    { label: 'Forex Card', value: formatNumber(s.forex_card_count) },
    { label: 'Other', value: formatNumber(s.other_count) },
    { label: 'Top Currency', value: s.top_currency_by_inr ?? '—' },
    { label: 'Top Ccy (₹)', value: formatNumber(Math.round(s.top_currency_inr_value ?? 0)) },
    { label: 'Top Country', value: s.top_country_by_inr ?? '—' },
    { label: 'Top Country (₹)', value: formatNumber(Math.round(s.top_country_inr_value ?? 0)) },
    { label: 'Stale (14d)', value: formatNumber(s.stale_positions_14d) },
    { label: 'Missing INR', value: formatNumber(s.positions_missing_inr) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold text-slate-900">Multi-Currency Treasury</h1>
        <p className="mt-1 text-sm text-slate-600">
          Cash positions across countries {'<'} currencies {'>'} INR-equivalent rollup. Extends r1398 international expansion infra.
        </p>
      </header>

      <section className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-8 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-slate-200 bg-white p-3">
            <div className="text-[11px] uppercase tracking-wide text-slate-500">{c.label}</div>
            <div className="mt-1 text-lg font-semibold text-slate-900 tabular-nums truncate">{c.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-3">By Currency</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-xs uppercase text-slate-600">
              <tr>
                <th className="px-3 py-2 text-left">Code</th>
                <th className="px-3 py-2 text-left">Label</th>
                <th className="px-3 py-2 text-right">FX (INR)</th>
                <th className="px-3 py-2 text-right">Positions</th>
                <th className="px-3 py-2 text-right">Native Bal</th>
                <th className="px-3 py-2 text-right">Bal (₹)</th>
                <th className="px-3 py-2 text-left">Last Synced</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {byCurrency.length === 0 ? (
                <tr><td colSpan={7} className="px-3 py-6 text-center text-slate-500">No currencies registered.</td></tr>
              ) : byCurrency.map((r) => (
                <tr key={r.currency_code} className="hover:bg-slate-50">
                  <td className="px-3 py-2 font-mono text-xs text-slate-700">{r.currency_code}</td>
                  <td className="px-3 py-2 text-slate-900">{r.currency_label ?? '—'}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-700">{Number(r.exchange_rate_inr).toFixed(4)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-700">{formatNumber(r.position_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-900">{formatNumber(Math.round(Number(r.total_balance_amount ?? 0)))}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-900">{formatNumber(Math.round(Number(r.total_balance_inr_equivalent ?? 0)))}</td>
                  <td className="px-3 py-2 text-xs text-slate-600">
                    {r.last_synced_at ? new Date(r.last_synced_at).toLocaleDateString() : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-3">By Country</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-xs uppercase text-slate-600">
              <tr>
                <th className="px-3 py-2 text-left">Code</th>
                <th className="px-3 py-2 text-left">Country</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-right">Positions</th>
                <th className="px-3 py-2 text-right">Bal (₹)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {byCountry.length === 0 ? (
                <tr><td colSpan={5} className="px-3 py-6 text-center text-slate-500">No countries registered.</td></tr>
              ) : byCountry.map((r) => (
                <tr key={r.country_id} className="hover:bg-slate-50">
                  <td className="px-3 py-2 font-mono text-xs text-slate-700">{r.country_code}</td>
                  <td className="px-3 py-2 text-slate-900">{r.country_name}</td>
                  <td className="px-3 py-2">
                    <span className={`inline-flex rounded px-2 py-0.5 text-xs font-medium ${statusBadge(r.expansion_status)}`}>
                      {r.expansion_status}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-700">{formatNumber(r.position_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-900">{formatNumber(Math.round(Number(r.total_balance_inr_equivalent ?? 0)))}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold text-slate-900 mb-3">Positions Ledger</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-xs uppercase text-slate-600">
              <tr>
                <th className="px-3 py-2 text-left">Ccy</th>
                <th className="px-3 py-2 text-left">Country</th>
                <th className="px-3 py-2 text-left">Label</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-left">Bank</th>
                <th className="px-3 py-2 text-right">Native Bal</th>
                <th className="px-3 py-2 text-right">Bal (₹)</th>
                <th className="px-3 py-2 text-left">Synced</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {positions.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-6 text-center text-slate-500">No treasury positions registered yet.</td></tr>
              ) : positions.map((p) => (
                <tr key={p.id} className="hover:bg-slate-50">
                  <td className="px-3 py-2 font-mono text-xs text-slate-700">{p.currency_code}</td>
                  <td className="px-3 py-2 text-xs text-slate-700">
                    {p.country_code ? `${p.country_code} · ${p.country_name ?? ''}` : '—'}
                  </td>
                  <td className="px-3 py-2 text-slate-900">{p.position_label}</td>
                  <td className="px-3 py-2">
                    <span className={`inline-flex rounded px-2 py-0.5 text-xs font-medium ${kindBadge(p.position_kind)}`}>
                      {p.position_kind}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-xs text-slate-600">
                    {p.bank_name ?? '—'}{p.account_label_masked ? ` · ${p.account_label_masked}` : ''}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-900">
                    {formatNumber(Math.round(Number(p.balance_amount ?? 0)))}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-900">
                    {p.balance_inr_equivalent == null ? '—' : formatNumber(Math.round(Number(p.balance_inr_equivalent)))}
                  </td>
                  <td className="px-3 py-2 text-xs text-slate-600">
                    {p.last_synced_at ? new Date(p.last_synced_at).toLocaleDateString() : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="pt-4 text-xs text-slate-500">
        Source: founder_multi_currency_treasury_positions × founder_international_currencies × founder_international_countries — RLS founder-only · cron-callable INR recompute.
      </footer>
    </main>
  );
}
