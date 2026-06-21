import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CalcRow = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  calculation_label: string;
  total_invested_rupees: number;
  total_distributions_rupees: number;
  current_value_rupees: number;
  holding_period_years: number;
  irr_pct: number;
  dpi: number;
  tvpi: number;
  status: string;
  calculated_at: string;
};

type LeaderRow = {
  investor_id: string;
  investor_email: string | null;
  best_irr_pct: number;
  best_tvpi: number;
  best_dpi: number;
  calc_count: number;
};

type RecentRow = {
  id: string;
  investor_email: string | null;
  calculation_label: string;
  irr_pct: number;
  tvpi: number;
  dpi: number;
  status: string;
  calculated_at: string;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined) {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

function fmtNum(n: number | null | undefined, digits = 2) {
  if (n == null) return '-';
  return Number(n).toFixed(digits);
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

export default async function FounderInvestorIrrCalculatorPage() {
  const sb = await getSupabaseServerClient();

  const [calcsRes, leaderRes, recentRes] = await Promise.all([
    sb.rpc('list_calculations_r1829'),
    sb.rpc('irr_leaderboard_r1829'),
    sb.rpc('recent_calculations_r1829'),
  ]);

  const calcs: CalcRow[] = (calcsRes.data as CalcRow[] | null) ?? [];
  const leaders: LeaderRow[] = (leaderRes.data as LeaderRow[] | null) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[] | null) ?? [];

  const calcsCurrent = calcs.filter((c) => c.status === 'current');
  const totalInvested = calcsCurrent.reduce((s, c) => s + Number(c.total_invested_rupees || 0), 0);
  const totalDistribs = calcsCurrent.reduce((s, c) => s + Number(c.total_distributions_rupees || 0), 0);
  const totalNAV = calcsCurrent.reduce((s, c) => s + Number(c.current_value_rupees || 0), 0);
  const avgIrr = calcsCurrent.length > 0
    ? calcsCurrent.reduce((s, c) => s + Number(c.irr_pct || 0), 0) / calcsCurrent.length
    : 0;

  const calcCols: Column<CalcRow>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{r.investor_email ?? r.investor_id?.slice(0, 8)}</span> },
    { key: 'label', header: 'Label', render: (r: any) => <span>{r.calculation_label}</span> },
    { key: 'invested', header: 'Invested', render: (r: any) => <span>{fmtRupees(r.total_invested_rupees)}</span> },
    { key: 'distribs', header: 'Distributions', render: (r: any) => <span>{fmtRupees(r.total_distributions_rupees)}</span> },
    { key: 'nav', header: 'Current NAV', render: (r: any) => <span>{fmtRupees(r.current_value_rupees)}</span> },
    { key: 'years', header: 'Years', render: (r: any) => <span>{fmtNum(r.holding_period_years)}</span> },
    { key: 'irr', header: 'IRR', render: (r: any) => <span className="font-medium">{fmtPct(r.irr_pct)}</span> },
    { key: 'dpi', header: 'DPI', render: (r: any) => <span>{fmtNum(r.dpi, 4)}x</span> },
    { key: 'tvpi', header: 'TVPI', render: (r: any) => <span>{fmtNum(r.tvpi, 4)}x</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span> },
    { key: 'when', header: 'Calculated', render: (r: any) => <span className="text-xs">{fmtDate(r.calculated_at)}</span> },
  ];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{r.investor_email ?? r.investor_id?.slice(0, 8)}</span> },
    { key: 'irr', header: 'Best IRR', render: (r: any) => <span className="font-medium">{fmtPct(r.best_irr_pct)}</span> },
    { key: 'tvpi', header: 'Best TVPI', render: (r: any) => <span>{fmtNum(r.best_tvpi, 4)}x</span> },
    { key: 'dpi', header: 'Best DPI', render: (r: any) => <span>{fmtNum(r.best_dpi, 4)}x</span> },
    { key: 'count', header: 'Active Calcs', render: (r: any) => <span>{r.calc_count}</span> },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{r.investor_email ?? '-'}</span> },
    { key: 'label', header: 'Label', render: (r: any) => <span>{r.calculation_label}</span> },
    { key: 'irr', header: 'IRR', render: (r: any) => <span>{fmtPct(r.irr_pct)}</span> },
    { key: 'tvpi', header: 'TVPI', render: (r: any) => <span>{fmtNum(r.tvpi, 4)}x</span> },
    { key: 'dpi', header: 'DPI', render: (r: any) => <span>{fmtNum(r.dpi, 4)}x</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span> },
    { key: 'when', header: 'When', render: (r: any) => <span className="text-xs">{fmtDate(r.calculated_at)}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Investor IRR Calculator</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Per-investor IRR, DPI &amp; TVPI tracking. Distributions &gt; current value &gt; cash flows. Disputed marks flagged for review.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Total Invested (current)</div>
          <div className="mt-1 text-xl font-semibold">{fmtRupees(totalInvested)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Total Distributions</div>
          <div className="mt-1 text-xl font-semibold">{fmtRupees(totalDistribs)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Current NAV</div>
          <div className="mt-1 text-xl font-semibold">{fmtRupees(totalNAV)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Avg IRR (current)</div>
          <div className="mt-1 text-xl font-semibold">{fmtPct(avgIrr)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Calculations</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Newest first — superseded rows kept for audit trail.
        </p>
        <DataTable<CalcRow>
          rows={calcs}
          columns={calcCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No IRR calculations yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">IRR Leaderboard</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Best IRR per investor — top 50 ordered IRR desc.
        </p>
        <DataTable<LeaderRow>
          rows={leaders}
          columns={leaderCols}
          rowKey={(r: any, i: number) => String(r.investor_id ?? i)}
          emptyMessage="No leaderboard entries."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent (last 30d)</h2>
        <DataTable<RecentRow>
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No recent calculations."
        />
      </section>
    </main>
  );
}
