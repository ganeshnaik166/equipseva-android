import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (!Number.isFinite(v)) return '-';
  if (Math.abs(v) >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
  if (Math.abs(v) >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined, digits = 2): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  return Number.isFinite(v) ? v.toFixed(digits) : '-';
}

export default async function FounderInvestorCapitalEfficiencyPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let perInvestor: any[] = [];
  let perCohort: any[] = [];
  let monthly: any[] = [];
  let benchmark: any[] = [];
  let rounds: any[] = [];
  let byType: any[] = [];

  try {
    const r = await sb.rpc('founder_capital_efficiency_kpis');
    kpis = Array.isArray(r.data) ? r.data[0] : r.data;
  } catch {}
  try {
    const r = await sb.rpc('founder_capital_per_investor');
    perInvestor = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_capital_per_cohort');
    perCohort = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_capital_monthly_series');
    monthly = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_capital_benchmark_saas');
    benchmark = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_capital_raise_rounds_list');
    rounds = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_capital_by_investor_type');
    byType = (r.data as any[]) ?? [];
  } catch {}
  try {
    await sb.rpc('log_founder_capital_efficiency_viewed', { p_view: 'main' });
  } catch {}

  const k = kpis ?? {};
  const cards: Kpi[] = [
    { label: 'Total Raised', value: fmtRupees(k.total_raised_rupees) },
    { label: 'Total Revenue', value: fmtRupees(k.total_revenue_rupees) },
    { label: 'Revenue / ₹ Raised', value: fmtNum(k.revenue_per_rupee_raised, 3) },
    { label: 'Cash Balance', value: fmtRupees(k.cash_balance_rupees) },
    { label: 'LTM Burn', value: fmtRupees(k.ltm_burn_rupees) },
    { label: 'LTM Net-New Revenue', value: fmtRupees(k.ltm_net_new_revenue_rupees) },
    { label: 'Burn Multiple', value: fmtNum(k.burn_multiple) },
    { label: 'Runway (mo)', value: fmtNum(k.runway_months, 1) },
    { label: 'LTM Marketing', value: fmtRupees(k.ltm_marketing_spend_rupees) },
    { label: 'LTM Sales', value: fmtRupees(k.ltm_sales_spend_rupees) },
    { label: 'LTM New Customers', value: String(k.ltm_new_customers ?? '-') },
    { label: 'CAC', value: fmtRupees(k.cac_rupees) },
    { label: 'Revenue / Customer', value: fmtRupees(k.ltm_revenue_per_customer) },
    { label: 'LTV', value: fmtRupees(k.ltv_rupees) },
    { label: 'LTV : CAC', value: fmtNum(k.ltv_to_cac) },
    { label: 'Payback (mo)', value: fmtNum(k.payback_months, 1) },
  ];

  const investorCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '-' },
    { key: 'investor_type', header: 'Type', render: (r: any) => r.investor_type ?? '-' },
    { key: 'total_invested_rupees', header: 'Invested', render: (r: any) => fmtRupees(r.total_invested_rupees) },
    { key: 'rounds_participated', header: 'Rounds', render: (r: any) => String(r.rounds_participated ?? '-') },
    { key: 'first_check_date', header: 'First Check', render: (r: any) => r.first_check_date ?? '-' },
    { key: 'latest_check_date', header: 'Latest', render: (r: any) => r.latest_check_date ?? '-' },
    { key: 'share_of_total_raise_pct', header: 'Share %', render: (r: any) => fmtNum(r.share_of_total_raise_pct) },
  ];

  const cohortCols: Column<any>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => r.cohort_label ?? '-' },
    { key: 'raised_rupees', header: 'Raised', render: (r: any) => fmtRupees(r.raised_rupees) },
    { key: 'investor_count', header: 'Investors', render: (r: any) => String(r.investor_count ?? '-') },
    { key: 'first_close_date', header: 'First Close', render: (r: any) => r.first_close_date ?? '-' },
    { key: 'last_close_date', header: 'Last Close', render: (r: any) => r.last_close_date ?? '-' },
    { key: 'pre_money_avg_rupees', header: 'Pre-money Avg', render: (r: any) => fmtRupees(r.pre_money_avg_rupees) },
    { key: 'post_money_avg_rupees', header: 'Post-money Avg', render: (r: any) => fmtRupees(r.post_money_avg_rupees) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'period_month', header: 'Month', render: (r: any) => r.period_month ?? '-' },
    { key: 'net_burn_rupees', header: 'Burn', render: (r: any) => fmtRupees(r.net_burn_rupees) },
    { key: 'net_new_revenue_rupees', header: 'NNR', render: (r: any) => fmtRupees(r.net_new_revenue_rupees) },
    { key: 'burn_multiple', header: 'Burn Mult', render: (r: any) => fmtNum(r.burn_multiple) },
    { key: 'total_revenue_rupees', header: 'Total Rev', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'new_customers', header: 'New Cust', render: (r: any) => String(r.new_customers ?? '-') },
    { key: 'cash_balance_rupees', header: 'Cash', render: (r: any) => fmtRupees(r.cash_balance_rupees) },
    { key: 'runway_months', header: 'Runway', render: (r: any) => fmtNum(r.runway_months, 1) },
  ];

  const benchmarkCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric ?? '-' },
    { key: 'our_value', header: 'Our Value', render: (r: any) => fmtNum(r.our_value, 3) },
    { key: 'saas_good', header: 'SaaS Good', render: (r: any) => fmtNum(r.saas_good, 2) },
    { key: 'saas_great', header: 'SaaS Great', render: (r: any) => fmtNum(r.saas_great, 2) },
    { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict ?? '-' },
  ];

  const roundsCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label ?? '-' },
    { key: 'raised_at', header: 'Closed', render: (r: any) => r.raised_at ?? '-' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '-' },
    { key: 'investor_type', header: 'Type', render: (r: any) => r.investor_type ?? '-' },
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => r.cohort_label ?? '-' },
    { key: 'pre_money_valuation_rupees', header: 'Pre-money', render: (r: any) => fmtRupees(r.pre_money_valuation_rupees) },
    { key: 'post_money_valuation_rupees', header: 'Post-money', render: (r: any) => fmtRupees(r.post_money_valuation_rupees) },
    { key: 'days_since_close', header: 'Days', render: (r: any) => String(r.days_since_close ?? '-') },
  ];

  const byTypeCols: Column<any>[] = [
    { key: 'investor_type', header: 'Type', render: (r: any) => r.investor_type ?? '-' },
    { key: 'total_invested_rupees', header: 'Invested', render: (r: any) => fmtRupees(r.total_invested_rupees) },
    { key: 'investor_count', header: 'Investors', render: (r: any) => String(r.investor_count ?? '-') },
    { key: 'round_count', header: 'Rounds', render: (r: any) => String(r.round_count ?? '-') },
    { key: 'avg_check_rupees', header: 'Avg Check', render: (r: any) => fmtRupees(r.avg_check_rupees) },
    { key: 'share_of_raise_pct', header: 'Share %', render: (r: any) => fmtNum(r.share_of_raise_pct) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Investor Capital Efficiency Tracker</h1>
        <p className="text-sm text-gray-600">CAC, LTV, payback, burn multiple, revenue per rupee raised — benchmarked vs SaaS norms (r1544).</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Headline KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {cards.map((c) => (
            <div key={c.label} className="rounded-xl border border-gray-200 bg-white p-3">
              <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
              <div className="text-lg font-semibold mt-1">{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">SaaS Benchmark Verdict</h2>
        <DataTable<any> rows={benchmark} columns={benchmarkCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Monthly Burn / Revenue Series</h2>
        <DataTable<any> rows={monthly} columns={monthlyCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Per Investor</h2>
        <DataTable<any> rows={perInvestor} columns={investorCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Per Cohort</h2>
        <DataTable<any> rows={perCohort} columns={cohortCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">By Investor Type</h2>
        <DataTable<any> rows={byType} columns={byTypeCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Raise Rounds</h2>
        <DataTable<any> rows={rounds} columns={roundsCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
