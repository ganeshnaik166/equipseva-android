import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Trend = { week_label: string; ccc_days: number; dso_days: number; dpo_days: number; dio_days: number; net_cash_rupees: number };
type Kpi = { metric: string; value: string; delta_4w: string; trend: string };
type Leak = { invoice_ref: string; segment: string; delay_days: number; amount_rupees: number; root_cause: string; owner: string; status: string };
type Recovery = { week_label: string; at_risk_rupees: number; recovered_rupees: number; recovery_rate_pct: number; write_off_rupees: number };
type Segment = { segment: string; leak_count: number; total_at_risk: number; avg_delay: number; recovery_pct: number };
type Root = { root_cause: string; occurrences: number; total_amount: number; avg_delay_days: number };
type Forecast = { week_label: string; projected_ccc: number; projected_net_cash: number; cumulative_cash: number; milestone: string };
type Owner = { owner: string; open_count: number; open_amount: number; escalated_count: number; oldest_delay: number };

const inr = (n: number) => `₹${(n / 100000).toFixed(2)}L`;

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [trend, kpis, leaks, recovery, segments, roots, forecast, owners] = await Promise.all([
    sb.rpc('founder_ccc_weekly_trend_r2897'),
    sb.rpc('founder_ccc_current_week_kpis_r2897'),
    sb.rpc('founder_ccc_open_leaks_r2897'),
    sb.rpc('founder_ccc_recovery_scorecard_r2897'),
    sb.rpc('founder_ccc_leak_by_segment_r2897'),
    sb.rpc('founder_ccc_root_cause_breakdown_r2897'),
    sb.rpc('founder_ccc_forecast_runway_r2897'),
    sb.rpc('founder_ccc_owner_load_r2897'),
  ]);

  const trendRows = (trend.data ?? []) as Trend[];
  const kpiRows = (kpis.data ?? []) as Kpi[];
  const leakRows = (leaks.data ?? []) as Leak[];
  const recoveryRows = (recovery.data ?? []) as Recovery[];
  const segmentRows = (segments.data ?? []) as Segment[];
  const rootRows = (roots.data ?? []) as Root[];
  const forecastRows = (forecast.data ?? []) as Forecast[];
  const ownerRows = (owners.data ?? []) as Owner[];

  const trendCols: Column<Trend>[] = [
    { key: 'week_label', header: 'Week', render: (r) => r.week_label },
    { key: 'ccc_days', header: 'CCC days', render: (r) => r.ccc_days.toFixed(1) },
    { key: 'dso_days', header: 'DSO', render: (r) => r.dso_days.toFixed(1) },
    { key: 'dpo_days', header: 'DPO', render: (r) => r.dpo_days.toFixed(1) },
    { key: 'dio_days', header: 'DIO', render: (r) => r.dio_days.toFixed(1) },
    { key: 'net_cash_rupees', header: 'Net Cash', render: (r) => inr(r.net_cash_rupees) },
  ];

  const leakCols: Column<Leak>[] = [
    { key: 'invoice_ref', header: 'Invoice', render: (r) => r.invoice_ref },
    { key: 'segment', header: 'Segment', render: (r) => r.segment },
    { key: 'delay_days', header: 'Delay (d)', render: (r) => String(r.delay_days) },
    { key: 'amount_rupees', header: 'At risk', render: (r) => inr(r.amount_rupees) },
    { key: 'root_cause', header: 'Root cause', render: (r) => r.root_cause },
    { key: 'owner', header: 'Owner', render: (r) => r.owner },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const recoveryCols: Column<Recovery>[] = [
    { key: 'week_label', header: 'Week', render: (r) => r.week_label },
    { key: 'at_risk_rupees', header: 'At risk', render: (r) => inr(r.at_risk_rupees) },
    { key: 'recovered_rupees', header: 'Recovered', render: (r) => inr(r.recovered_rupees) },
    { key: 'recovery_rate_pct', header: 'Recovery %', render: (r) => `${r.recovery_rate_pct ?? 0}%` },
    { key: 'write_off_rupees', header: 'Write-off', render: (r) => inr(r.write_off_rupees) },
  ];

  const segmentCols: Column<Segment>[] = [
    { key: 'segment', header: 'Segment', render: (r) => r.segment },
    { key: 'leak_count', header: 'Leaks', render: (r) => String(r.leak_count) },
    { key: 'total_at_risk', header: 'Total at risk', render: (r) => inr(r.total_at_risk) },
    { key: 'avg_delay', header: 'Avg delay', render: (r) => `${r.avg_delay}d` },
    { key: 'recovery_pct', header: 'Recovery %', render: (r) => `${r.recovery_pct ?? 0}%` },
  ];

  const rootCols: Column<Root>[] = [
    { key: 'root_cause', header: 'Root cause', render: (r) => r.root_cause },
    { key: 'occurrences', header: 'Count', render: (r) => String(r.occurrences) },
    { key: 'total_amount', header: 'Total ₹', render: (r) => inr(r.total_amount) },
    { key: 'avg_delay_days', header: 'Avg delay', render: (r) => `${r.avg_delay_days}d` },
  ];

  const forecastCols: Column<Forecast>[] = [
    { key: 'week_label', header: 'Week', render: (r) => r.week_label },
    { key: 'projected_ccc', header: 'Projected CCC', render: (r) => r.projected_ccc.toFixed(1) },
    { key: 'projected_net_cash', header: 'Net cash', render: (r) => inr(r.projected_net_cash) },
    { key: 'cumulative_cash', header: 'Cumulative', render: (r) => inr(r.cumulative_cash) },
    { key: 'milestone', header: 'Milestone', render: (r) => r.milestone },
  ];

  const ownerCols: Column<Owner>[] = [
    { key: 'owner', header: 'Owner', render: (r) => r.owner },
    { key: 'open_count', header: 'Open', render: (r) => String(r.open_count) },
    { key: 'open_amount', header: 'Open ₹', render: (r) => inr(r.open_amount) },
    { key: 'escalated_count', header: 'Escalated', render: (r) => String(r.escalated_count) },
    { key: 'oldest_delay', header: 'Oldest (d)', render: (r) => String(r.oldest_delay) },
  ];

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-semibold">Founder Weekly Cash Conversion Cycle Drilldown</h1>
        <p className="text-sm text-gray-600 mt-1">
          CEO-grade weekly readout — DSO &amp; DPO &amp; DIO movements, leak events, recovery scorecard, root-cause &amp; forecast runway. CCC trending down 24 days over 12 weeks =&gt; Series A trigger zone in sight.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {kpiRows.map((k, i) => (
          <div key={i} className="rounded-lg border bg-white p-4">
            <div className="text-xs uppercase text-gray-500">{k.metric}</div>
            <div className="text-2xl font-semibold mt-1">{k.value}</div>
            <div className="text-xs text-gray-500 mt-1">Δ 4w: {k.delta_4w} · {k.trend}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Weekly CCC trend (16 weeks)</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open cash leaks (founder action queue)</h2>
        <DataTable rows={leakRows} columns={leakCols} emptyMessage="No open leaks => clean week" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recovery scorecard by week</h2>
        <DataTable rows={recoveryRows} columns={recoveryCols} emptyMessage="No data" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Leak concentration by segment</h2>
        <DataTable rows={segmentRows} columns={segmentCols} emptyMessage="No data" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Root cause breakdown</h2>
        <DataTable rows={rootRows} columns={rootCols} emptyMessage="No data" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Forecast & runway milestones</h2>
        <DataTable rows={forecastRows} columns={forecastCols} emptyMessage="No forecast data" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Remediation owner load</h2>
        <DataTable rows={ownerRows} columns={ownerCols} emptyMessage="No owner load" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}