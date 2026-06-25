import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyPayYourselfCheckPage() {
  const supabase = await getSupabaseServerClient();

  const [checksRes, decisionsRes, focusRes, distRes, funnelRes, trendRes, pulseRes] = await Promise.all([
    supabase.rpc('list_pay_check_r2665'),
    supabase.rpc('list_decisions_r2665'),
    supabase.rpc('top_comfort_focus_r2665'),
    supabase.rpc('status_distribution_r2665'),
    supabase.rpc('status_funnel_r2665'),
    supabase.rpc('quarterly_pay_trend_r2665'),
    supabase.rpc('founder_pulse_summary_r2665'),
  ]);

  const checks = (checksRes.data ?? []) as any[];
  const decisions = (decisionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const distribution = (distRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const pulse = ((pulseRes.data ?? [])[0] ?? {}) as any;

  const fmtMoney = (n: number | null | undefined) =>
    n == null ? '—' : `₹${Number(n).toLocaleString('en-IN')}`;

  const checkColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'salary_drawn_rupees', header: 'Salary Drawn', render: (r: any) => fmtMoney(r.salary_drawn_rupees) },
    { key: 'market_benchmark_rupees', header: 'Market Benchmark', render: (r: any) => fmtMoney(r.market_benchmark_rupees) },
    { key: 'sweat_equity_value_rupees', header: 'Sweat Equity', render: (r: any) => fmtMoney(r.sweat_equity_value_rupees) },
    { key: 'comfort_score', header: 'Comfort 0-10', render: (r: any) => r.comfort_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const decisionColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'decided_at', header: 'Decided', render: (r: any) => new Date(r.decided_at).toLocaleDateString() },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'summary_md', header: 'Summary', render: (r: any) => r.summary_md ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const focusColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'salary_drawn_rupees', header: 'Salary', render: (r: any) => fmtMoney(r.salary_drawn_rupees) },
    { key: 'market_benchmark_rupees', header: 'Benchmark', render: (r: any) => fmtMoney(r.market_benchmark_rupees) },
    { key: 'comfort_score', header: 'Comfort', render: (r: any) => r.comfort_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const distributionColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'check_count', header: 'Checks', render: (r: any) => r.check_count },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Decision Status', render: (r: any) => r.status },
    { key: 'decision_count', header: 'Decisions', render: (r: any) => r.decision_count },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'total_checks', header: 'Checks', render: (r: any) => r.total_checks },
    { key: 'avg_salary_rupees', header: 'Avg Salary', render: (r: any) => fmtMoney(r.avg_salary_rupees) },
    { key: 'avg_benchmark_rupees', header: 'Avg Benchmark', render: (r: any) => fmtMoney(r.avg_benchmark_rupees) },
    { key: 'avg_comfort', header: 'Avg Comfort', render: (r: any) => r.avg_comfort },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Quarterly Pay Yourself Check</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track founder salary vs market benchmark, sweat equity, and comfort score per quarter.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Total Checks</div>
          <div className="text-2xl font-bold">{pulse.total_checks ?? 0}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Below Market</div>
          <div className="text-2xl font-bold">{pulse.below_market_checks ?? 0}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Above Market</div>
          <div className="text-2xl font-bold">{pulse.above_market_checks ?? 0}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Avg Comfort</div>
          <div className="text-2xl font-bold">{pulse.avg_comfort ?? 0}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Decisions</div>
          <div className="text-2xl font-bold">{pulse.total_decisions ?? 0}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Open Decisions</div>
          <div className="text-2xl font-bold">{pulse.open_decisions ?? 0}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pay-Yourself Checks</h2>
        <DataTable
          rows={checks}
          columns={checkColumns}
          emptyMessage="No checks recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Low-Comfort Focus (score <= 5)</h2>
        <DataTable
          rows={focus}
          columns={focusColumns}
          emptyMessage="No low-comfort quarters."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decisions Log</h2>
        <DataTable
          rows={decisions}
          columns={decisionColumns}
          emptyMessage="No decisions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <div className="grid md:grid-cols-2 gap-6">
        <section>
          <h2 className="text-lg font-semibold mb-2">Status Distribution</h2>
          <DataTable
            rows={distribution}
            columns={distributionColumns}
            emptyMessage="No data."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </section>

        <section>
          <h2 className="text-lg font-semibold mb-2">Decision Status Funnel</h2>
          <DataTable
            rows={funnel}
            columns={funnelColumns}
            emptyMessage="No decisions."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </section>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No quarter data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>
    </div>
  );
}
