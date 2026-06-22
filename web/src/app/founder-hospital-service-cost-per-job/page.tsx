import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type CostRow = {
  id: string;
  repair_job_id: string;
  engineer_minutes: number;
  travel_cost_rupees: number;
  parts_cost_rupees: number;
  overhead_allocation_rupees: number;
  total_cost_rupees: number;
  billed_amount_rupees: number;
  margin_pct: number;
  recorded_at: string;
};

type AnomalyRow = {
  id: string;
  cost_id: string;
  anomaly_type: string;
  anomaly_text: string;
  founder_note: string | null;
  created_at: string;
};

type MonthlyRow = {
  month_start: string;
  jobs_count: number;
  total_cost_rupees: number;
  total_billed_rupees: number;
  avg_margin_pct: number;
};

type LossRow = {
  id: string;
  repair_job_id: string;
  total_cost_rupees: number;
  billed_amount_rupees: number;
  loss_rupees: number;
  margin_pct: number;
  recorded_at: string;
};

type ProfitRow = {
  id: string;
  repair_job_id: string;
  total_cost_rupees: number;
  billed_amount_rupees: number;
  profit_rupees: number;
  margin_pct: number;
  recorded_at: string;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

function fmtMonth(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short' });
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [costsRes, anomaliesRes, monthlyRes, lossRes, profitRes] = await Promise.all([
    sb.rpc('list_costs_r1879', { p_limit: 200 }),
    sb.rpc('list_anomalies_r1879', { p_limit: 200 }),
    sb.rpc('monthly_margin_summary_r1879'),
    sb.rpc('top_loss_jobs_r1879', { p_limit: 20 }),
    sb.rpc('top_profit_jobs_r1879', { p_limit: 20 }),
  ]);

  const costs: CostRow[] = (costsRes.data as CostRow[] | null) ?? [];
  const anomalies: AnomalyRow[] = (anomaliesRes.data as AnomalyRow[] | null) ?? [];
  const monthly: MonthlyRow[] = (monthlyRes.data as MonthlyRow[] | null) ?? [];
  const losses: LossRow[] = (lossRes.data as LossRow[] | null) ?? [];
  const profits: ProfitRow[] = (profitRes.data as ProfitRow[] | null) ?? [];

  const totalJobs = costs.length;
  const totalCost = costs.reduce((acc, r) => acc + Number(r.total_cost_rupees || 0), 0);
  const totalBilled = costs.reduce((acc, r) => acc + Number(r.billed_amount_rupees || 0), 0);
  const netMargin = totalBilled - totalCost;
  const marginPct = totalBilled > 0 ? Math.round(((netMargin / totalBilled) * 100) * 100) / 100 : 0;
  const anomalyCount = anomalies.length;

  const costCols: Column<CostRow>[] = [
    { key: 'repair_job_id', header: 'Job', render: (r: any) => <code className="text-xs">{String(r.repair_job_id).slice(0, 8)}</code> },
    { key: 'engineer_minutes', header: 'Eng Min', render: (r: any) => <span>{r.engineer_minutes}</span> },
    { key: 'travel_cost_rupees', header: 'Travel', render: (r: any) => <span>{fmtRupees(r.travel_cost_rupees)}</span> },
    { key: 'parts_cost_rupees', header: 'Parts', render: (r: any) => <span>{fmtRupees(r.parts_cost_rupees)}</span> },
    { key: 'overhead_allocation_rupees', header: 'Overhead', render: (r: any) => <span>{fmtRupees(r.overhead_allocation_rupees)}</span> },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => <span className="font-medium">{fmtRupees(r.total_cost_rupees)}</span> },
    { key: 'billed_amount_rupees', header: 'Billed', render: (r: any) => <span>{fmtRupees(r.billed_amount_rupees)}</span> },
    { key: 'margin_pct', header: 'Margin %', render: (r: any) => <span className={Number(r.margin_pct) < 0 ? 'text-red-600' : 'text-green-700'}>{Number(r.margin_pct).toFixed(2)}%</span> },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => <span className="text-xs text-gray-600">{fmtDate(r.recorded_at)}</span> },
  ];

  const anomalyCols: Column<AnomalyRow>[] = [
    { key: 'anomaly_type', header: 'Type', render: (r: any) => <span className="rounded bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-900">{r.anomaly_type}</span> },
    { key: 'cost_id', header: 'Cost', render: (r: any) => <code className="text-xs">{String(r.cost_id).slice(0, 8)}</code> },
    { key: 'anomaly_text', header: 'Detail', render: (r: any) => <span className="text-sm">{r.anomaly_text}</span> },
    { key: 'founder_note', header: 'Founder Note', render: (r: any) => <span className="text-sm text-gray-700">{r.founder_note ?? '-'}</span> },
    { key: 'created_at', header: 'When', render: (r: any) => <span className="text-xs text-gray-600">{fmtDate(r.created_at)}</span> },
  ];

  const monthlyCols: Column<MonthlyRow>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => <span className="font-medium">{fmtMonth(r.month_start)}</span> },
    { key: 'jobs_count', header: 'Jobs', render: (r: any) => <span>{r.jobs_count}</span> },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => <span>{fmtRupees(r.total_cost_rupees)}</span> },
    { key: 'total_billed_rupees', header: 'Total Billed', render: (r: any) => <span>{fmtRupees(r.total_billed_rupees)}</span> },
    { key: 'avg_margin_pct', header: 'Avg Margin %', render: (r: any) => <span className={Number(r.avg_margin_pct) < 0 ? 'text-red-600' : 'text-green-700'}>{Number(r.avg_margin_pct).toFixed(2)}%</span> },
  ];

  const lossCols: Column<LossRow>[] = [
    { key: 'repair_job_id', header: 'Job', render: (r: any) => <code className="text-xs">{String(r.repair_job_id).slice(0, 8)}</code> },
    { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => <span>{fmtRupees(r.total_cost_rupees)}</span> },
    { key: 'billed_amount_rupees', header: 'Billed', render: (r: any) => <span>{fmtRupees(r.billed_amount_rupees)}</span> },
    { key: 'loss_rupees', header: 'Loss', render: (r: any) => <span className="font-medium text-red-700">{fmtRupees(r.loss_rupees)}</span> },
    { key: 'margin_pct', header: 'Margin %', render: (r: any) => <span className="text-red-600">{Number(r.margin_pct).toFixed(2)}%</span> },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => <span className="text-xs text-gray-600">{fmtDate(r.recorded_at)}</span> },
  ];

  const profitCols: Column<ProfitRow>[] = [
    { key: 'repair_job_id', header: 'Job', render: (r: any) => <code className="text-xs">{String(r.repair_job_id).slice(0, 8)}</code> },
    { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => <span>{fmtRupees(r.total_cost_rupees)}</span> },
    { key: 'billed_amount_rupees', header: 'Billed', render: (r: any) => <span>{fmtRupees(r.billed_amount_rupees)}</span> },
    { key: 'profit_rupees', header: 'Profit', render: (r: any) => <span className="font-medium text-green-700">{fmtRupees(r.profit_rupees)}</span> },
    { key: 'margin_pct', header: 'Margin %', render: (r: any) => <span className="text-green-700">{Number(r.margin_pct).toFixed(2)}%</span> },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => <span className="text-xs text-gray-600">{fmtDate(r.recorded_at)}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Service Cost Per Job</h1>
        <p className="text-sm text-gray-600">
          True per-job economics — engineer time, travel, parts & overhead vs. billed amount. Track margin and spot loss-makers.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-5">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Jobs Costed</div>
          <div className="mt-1 text-2xl font-semibold">{totalJobs}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total Cost</div>
          <div className="mt-1 text-2xl font-semibold">{fmtRupees(totalCost)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total Billed</div>
          <div className="mt-1 text-2xl font-semibold">{fmtRupees(totalBilled)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Net Margin</div>
          <div className={'mt-1 text-2xl font-semibold ' + (netMargin < 0 ? 'text-red-600' : 'text-green-700')}>
            {fmtRupees(netMargin)} ({marginPct}%)
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Anomalies</div>
          <div className="mt-1 text-2xl font-semibold">{anomalyCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Monthly Margin Summary</h2>
        <p className="text-sm text-gray-600">Aggregated jobs costed per month — total cost vs. billed, avg margin %.</p>
        <DataTable rows={monthly} columns={monthlyCols} rowKey={(r: any, i: number) => String(r.month_start ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Cost Records</h2>
        <p className="text-sm text-gray-600">Latest 200 per-job cost breakdowns. Margin &lt; 0% = loss-making job.</p>
        <DataTable rows={costs} columns={costCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Loss-Making Jobs</h2>
        <p className="text-sm text-gray-600">Jobs where cost &gt; billed amount. Sorted by loss magnitude.</p>
        <DataTable rows={losses} columns={lossCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Profit Jobs</h2>
        <p className="text-sm text-gray-600">Jobs where billed &gt; cost. Sorted by profit magnitude.</p>
        <DataTable rows={profits} columns={profitCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Cost Breakdown Anomalies</h2>
        <p className="text-sm text-gray-600">Flags: unusual_travel, parts_overrun, time_overrun, missing_billing.</p>
        <DataTable rows={anomalies} columns={anomalyCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
