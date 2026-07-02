import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Forecast = {
  id: string;
  model_label: string;
  assumed_next_round_date: string | null;
  assumed_next_valuation_rupees: number | null;
  total_safes_count: number | null;
  total_safe_amount_rupees: number | null;
  expected_conversion_shares: number | null;
  founder_ownership_after_pct: number | null;
  status: string;
  created_at: string;
};

type Curve = {
  status: string;
  model_count: number;
  avg_ownership_after_pct: number;
  total_amount_rupees: number;
  total_shares: number;
};

type Scenario = {
  model_label: string;
  status: string;
  total_safe_amount_rupees: number | null;
  expected_conversion_shares: number | null;
  founder_ownership_after_pct: number | null;
  delta_vs_baseline_pct: number | null;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined) {
  if (n == null) return '-';
  return Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined) {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [forecastsRes, curveRes, scenariosRes] = await Promise.all([
    sb.rpc('list_safe_maturity_forecasts_r1825'),
    sb.rpc('safe_maturity_dilution_curve_r1825'),
    sb.rpc('safe_maturity_scenario_comparison_r1825'),
  ]);

  const forecasts: Forecast[] = (forecastsRes.data as Forecast[] | null) ?? [];
  const curve: Curve[] = (curveRes.data as Curve[] | null) ?? [];
  const scenarios: Scenario[] = (scenariosRes.data as Scenario[] | null) ?? [];

  const forecastCols: Column<Forecast>[] = [
    { key: 'model_label', header: 'Model', render: (r: any) => <span className="font-medium">{r.model_label}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'assumed_next_round_date', header: 'Next Round', render: (r: any) => r.assumed_next_round_date ?? '-' },
    { key: 'assumed_next_valuation_rupees', header: 'Assumed Valuation', render: (r: any) => fmtRupees(r.assumed_next_valuation_rupees) },
    { key: 'total_safes_count', header: 'SAFEs', render: (r: any) => fmtNum(r.total_safes_count) },
    { key: 'total_safe_amount_rupees', header: 'SAFE Amount', render: (r: any) => fmtRupees(r.total_safe_amount_rupees) },
    { key: 'expected_conversion_shares', header: 'Conv Shares', render: (r: any) => fmtNum(r.expected_conversion_shares) },
    { key: 'founder_ownership_after_pct', header: 'Founder After', render: (r: any) => fmtPct(r.founder_ownership_after_pct) },
    { key: 'created_at', header: 'Created', render: (r: any) => new Date(r.created_at).toLocaleDateString('en-IN') },
  ];

  const curveCols: Column<Curve>[] = [
    { key: 'status', header: 'Status Bucket', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'model_count', header: 'Models', render: (r: any) => fmtNum(r.model_count) },
    { key: 'avg_ownership_after_pct', header: 'Avg Founder After', render: (r: any) => fmtPct(r.avg_ownership_after_pct) },
    { key: 'total_amount_rupees', header: 'Total SAFE Amount', render: (r: any) => fmtRupees(r.total_amount_rupees) },
    { key: 'total_shares', header: 'Total Shares', render: (r: any) => fmtNum(r.total_shares) },
  ];

  const scenarioCols: Column<Scenario>[] = [
    { key: 'model_label', header: 'Scenario', render: (r: any) => <span className="font-medium">{r.model_label}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'total_safe_amount_rupees', header: 'SAFE Amount', render: (r: any) => fmtRupees(r.total_safe_amount_rupees) },
    { key: 'expected_conversion_shares', header: 'Conv Shares', render: (r: any) => fmtNum(r.expected_conversion_shares) },
    { key: 'founder_ownership_after_pct', header: 'Founder After', render: (r: any) => fmtPct(r.founder_ownership_after_pct) },
    { key: 'delta_vs_baseline_pct', header: 'Delta vs Baseline', render: (r: any) => {
        const v = r.delta_vs_baseline_pct;
        if (v == null) return '-';
        const sign = Number(v) >= 0 ? '+' : '';
        return sign + Number(v).toFixed(2) + ' pp';
      } },
  ];

  return (
    <main className="mx-auto max-w-6xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Investor SAFE Maturity Forecast</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Forecast when SAFEs convert & how founder ownership shifts across baseline & scenario models.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Forecast Models</h2>
        <p className="text-sm text-[var(--color-muted)]">
          All saved forecasts — baseline, draft & scenarios.
        </p>
        <DataTable<Forecast>
          rows={forecasts}
          columns={forecastCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No forecast models saved yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Dilution Curve</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Aggregate ownership impact grouped by status.
        </p>
        <DataTable<Curve>
          rows={curve}
          columns={curveCols}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
          emptyMessage="No curve data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Scenario Comparison</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Each scenario vs the active baseline — delta is founder-ownership percentage points.
        </p>
        <DataTable<Scenario>
          rows={scenarios}
          columns={scenarioCols}
          rowKey={(r: any, i: number) => String(r.model_label + '-' + i)}
          emptyMessage="No scenarios to compare."
        />
      </section>
    </main>
  );
}
