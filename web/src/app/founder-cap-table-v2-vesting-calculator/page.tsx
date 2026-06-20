import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type SummaryRow = {
  total_vesting_schedules: number;
  time_based_schedules: number;
  milestone_based_schedules: number;
  cliff_only_schedules: number;
  total_shares_under_vesting: number;
  total_shares_vested_to_date: number;
  total_shares_unvested: number;
  cliffs_in_next_90d: number;
  cliffs_in_next_30d: number;
  fully_vested_count: number;
  total_dilution_scenarios: number;
  seed_scenarios: number;
  seriesA_scenarios: number;
  avg_projected_dilution_pct: number;
  max_projected_dilution_pct: number;
  total_raise_modeled_rupees: number;
  avg_pre_money_rupees: number;
};

type VestingStatusRow = {
  schedule_id: string;
  shareholder_id: string;
  shareholder_name: string;
  shareholder_kind: string;
  vesting_kind: string;
  total_shares: number;
  vested_shares: number;
  unvested_shares: number;
  vested_pct: number;
  cliff_passed: boolean;
  vesting_start_date: string;
  vesting_end_date: string;
  months_remaining: number;
};

type CliffRow = {
  schedule_id: string;
  shareholder_name: string;
  shareholder_kind: string;
  cliff_date: string;
  days_until_cliff: number;
  shares_at_cliff: number;
  vesting_kind: string;
};

type ScenarioRow = {
  id: string;
  scenario_label: string;
  scenario_kind: string;
  raise_amount_rupees: number;
  pre_money_valuation_rupees: number;
  new_esop_pct_added: number;
  projected_dilution_pct: number;
  founder_dilution_pct: number | null;
  employee_dilution_pct: number | null;
  notes: string | null;
  created_at: string;
};

export default async function FounderCapTableV2VestingCalculatorPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, vestingRes, cliffRes, scenariosRes] = await Promise.all([
    supabase.rpc('founder_cap_table_v2_summary'),
    supabase.rpc('founder_cap_table_v2_vesting_status'),
    supabase.rpc('founder_cap_table_v2_upcoming_cliffs', { p_days: 90 }),
    supabase.rpc('founder_cap_table_v2_scenarios_recent', { p_limit: 25 }),
  ]);

  const summary = (summaryRes.data ?? {}) as Partial<SummaryRow>;
  const vesting = (vestingRes.data ?? []) as VestingStatusRow[];
  const cliffs = (cliffRes.data ?? []) as CliffRow[];
  const scenarios = (scenariosRes.data ?? []) as ScenarioRow[];

  const kpis: Array<[string, string | number]> = [
    ['Vesting schedules', formatNumber(summary.total_vesting_schedules ?? 0)],
    ['Time-based', formatNumber(summary.time_based_schedules ?? 0)],
    ['Milestone-based', formatNumber(summary.milestone_based_schedules ?? 0)],
    ['Cliff-only', formatNumber(summary.cliff_only_schedules ?? 0)],
    ['Shares under vesting', formatNumber(summary.total_shares_under_vesting ?? 0)],
    ['Shares vested', formatNumber(summary.total_shares_vested_to_date ?? 0)],
    ['Shares unvested', formatNumber(summary.total_shares_unvested ?? 0)],
    ['Cliffs <30d', formatNumber(summary.cliffs_in_next_30d ?? 0)],
    ['Cliffs <90d', formatNumber(summary.cliffs_in_next_90d ?? 0)],
    ['Fully vested', formatNumber(summary.fully_vested_count ?? 0)],
    ['Scenarios', formatNumber(summary.total_dilution_scenarios ?? 0)],
    ['Seed scenarios', formatNumber(summary.seed_scenarios ?? 0)],
    ['Series A scenarios', formatNumber(summary.seriesA_scenarios ?? 0)],
    ['Avg dilution %', `${summary.avg_projected_dilution_pct ?? 0}%`],
    ['Max dilution %', `${summary.max_projected_dilution_pct ?? 0}%`],
    ['Total modeled raise', `Rs. ${formatNumber(summary.total_raise_modeled_rupees ?? 0)}`],
  ];

  const cliffBannerCount = cliffs.length;

  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <header className="mb-6">
        <h1 className="text-3xl font-bold text-slate-900">Cap Table v2 · Vesting + Dilution</h1>
        <p className="text-slate-600 mt-1">
          r1401 · vesting schedules, cliff tracking, and dilution scenario modeling.
        </p>
      </header>

      {cliffBannerCount > 0 && (
        <div className="mb-6 rounded-lg border border-amber-300 bg-amber-50 p-4">
          <div className="text-sm font-semibold text-amber-900">
            {cliffBannerCount} cliff{cliffBannerCount === 1 ? '' : 's'} hit in the next 90 days
          </div>
          <div className="text-xs text-amber-800 mt-1">
            Earliest: {cliffs[0]?.shareholder_name} on {cliffs[0]?.cliff_date} ({cliffs[0]?.days_until_cliff}d)
          </div>
        </div>
      )}

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3 mb-8">
        {kpis.map(([label, value]) => (
          <div key={label} className="rounded-lg border border-slate-200 bg-white p-3 shadow-sm">
            <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
            <div className="text-lg font-semibold text-slate-900 mt-1">{value}</div>
          </div>
        ))}
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold text-slate-900 mb-3">Vesting schedules — per shareholder</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-100">
              <tr className="text-left text-slate-700">
                <th className="px-3 py-2">Shareholder</th>
                <th className="px-3 py-2">Kind</th>
                <th className="px-3 py-2">Vesting kind</th>
                <th className="px-3 py-2 text-right">Total</th>
                <th className="px-3 py-2 text-right">Vested</th>
                <th className="px-3 py-2 text-right">Unvested</th>
                <th className="px-3 py-2 text-right">Vested %</th>
                <th className="px-3 py-2">Cliff</th>
                <th className="px-3 py-2">Start</th>
                <th className="px-3 py-2">End</th>
                <th className="px-3 py-2 text-right">Months left</th>
              </tr>
            </thead>
            <tbody>
              {vesting.length === 0 && (
                <tr><td colSpan={11} className="px-3 py-6 text-center text-slate-500">No vesting schedules yet.</td></tr>
              )}
              {vesting.map((r) => (
                <tr key={r.schedule_id} className="border-t border-slate-100">
                  <td className="px-3 py-2 font-medium text-slate-800">{r.shareholder_name}</td>
                  <td className="px-3 py-2 text-slate-600">{r.shareholder_kind}</td>
                  <td className="px-3 py-2 text-slate-600">{r.vesting_kind}</td>
                  <td className="px-3 py-2 text-right">{formatNumber(r.total_shares)}</td>
                  <td className="px-3 py-2 text-right text-emerald-700">{formatNumber(r.vested_shares)}</td>
                  <td className="px-3 py-2 text-right text-slate-500">{formatNumber(r.unvested_shares)}</td>
                  <td className="px-3 py-2 text-right font-medium">{r.vested_pct}%</td>
                  <td className="px-3 py-2">
                    <span className={r.cliff_passed ? 'text-emerald-700' : 'text-amber-700'}>
                      {r.cliff_passed ? 'passed' : 'pending'}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-slate-600">{r.vesting_start_date}</td>
                  <td className="px-3 py-2 text-slate-600">{r.vesting_end_date}</td>
                  <td className="px-3 py-2 text-right">{r.months_remaining}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold text-slate-900 mb-3">Upcoming cliffs (next 90 days)</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-100">
              <tr className="text-left text-slate-700">
                <th className="px-3 py-2">Shareholder</th>
                <th className="px-3 py-2">Kind</th>
                <th className="px-3 py-2">Vesting kind</th>
                <th className="px-3 py-2">Cliff date</th>
                <th className="px-3 py-2 text-right">Days</th>
                <th className="px-3 py-2 text-right">Shares released</th>
              </tr>
            </thead>
            <tbody>
              {cliffs.length === 0 && (
                <tr><td colSpan={6} className="px-3 py-6 text-center text-slate-500">No cliffs hit in the next 90 days.</td></tr>
              )}
              {cliffs.map((c) => (
                <tr key={c.schedule_id} className="border-t border-slate-100">
                  <td className="px-3 py-2 font-medium text-slate-800">{c.shareholder_name}</td>
                  <td className="px-3 py-2 text-slate-600">{c.shareholder_kind}</td>
                  <td className="px-3 py-2 text-slate-600">{c.vesting_kind}</td>
                  <td className="px-3 py-2 text-slate-600">{c.cliff_date}</td>
                  <td className="px-3 py-2 text-right">{c.days_until_cliff}</td>
                  <td className="px-3 py-2 text-right">{formatNumber(c.shares_at_cliff)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold text-slate-900 mb-3">Dilution scenarios</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-100">
              <tr className="text-left text-slate-700">
                <th className="px-3 py-2">Scenario</th>
                <th className="px-3 py-2">Kind</th>
                <th className="px-3 py-2 text-right">Raise (Rs.)</th>
                <th className="px-3 py-2 text-right">Pre-money (Rs.)</th>
                <th className="px-3 py-2 text-right">New ESOP %</th>
                <th className="px-3 py-2 text-right">Dilution %</th>
                <th className="px-3 py-2 text-right">Founder dilution %</th>
                <th className="px-3 py-2 text-right">Employee dilution %</th>
                <th className="px-3 py-2">Created</th>
              </tr>
            </thead>
            <tbody>
              {scenarios.length === 0 && (
                <tr><td colSpan={9} className="px-3 py-6 text-center text-slate-500">No dilution scenarios modeled yet.</td></tr>
              )}
              {scenarios.map((s) => (
                <tr key={s.id} className="border-t border-slate-100">
                  <td className="px-3 py-2 font-medium text-slate-800">{s.scenario_label}</td>
                  <td className="px-3 py-2 text-slate-600">{s.scenario_kind}</td>
                  <td className="px-3 py-2 text-right">{formatNumber(s.raise_amount_rupees)}</td>
                  <td className="px-3 py-2 text-right">{formatNumber(s.pre_money_valuation_rupees)}</td>
                  <td className="px-3 py-2 text-right">{s.new_esop_pct_added}%</td>
                  <td className="px-3 py-2 text-right font-semibold text-rose-700">{Number(s.projected_dilution_pct).toFixed(2)}%</td>
                  <td className="px-3 py-2 text-right">{s.founder_dilution_pct != null ? `${Number(s.founder_dilution_pct).toFixed(2)}%` : '—'}</td>
                  <td className="px-3 py-2 text-right">{s.employee_dilution_pct != null ? `${Number(s.employee_dilution_pct).toFixed(2)}%` : '—'}</td>
                  <td className="px-3 py-2 text-slate-600">{new Date(s.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="text-xs text-slate-500 mt-8">
        Founder-only. RPCs gated by is_founder(). Extends r1335 cap-table tables.
      </footer>
    </div>
  );
}
