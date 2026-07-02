import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer service-cost-per-job analysis — r2368" };
export const dynamic = "force-dynamic";

type JobRow = {
  id: string;
  repair_job_id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  engineer_user_id: string | null;
  engineer_email: string | null;
  equipment_class: string;
  closed_at: string;
  engineer_minutes: number;
  engineer_cost_rupees: number;
  parts_cost_rupees: number;
  travel_km: number;
  travel_cost_rupees: number;
  total_cost_rupees: number;
  invoice_amount_rupees: number;
  margin_rupees: number;
};

type HospitalRow = {
  hospital_user_id: string;
  hospital_email: string | null;
  jobs_closed: number;
  total_cost_rupees: number;
  total_invoice_rupees: number;
  total_margin_rupees: number;
  avg_cost_per_job_rupees: number;
  margin_pct: number;
};

type EquipmentClassRow = {
  equipment_class: string;
  jobs_closed: number;
  total_cost_rupees: number;
  total_invoice_rupees: number;
  total_margin_rupees: number;
  avg_cost_per_job_rupees: number;
  avg_engineer_minutes: number;
};

type BreakdownRow = {
  jobs_closed: number;
  total_engineer_cost_rupees: number;
  total_parts_cost_rupees: number;
  total_travel_cost_rupees: number;
  total_cost_rupees: number;
  total_invoice_rupees: number;
  total_margin_rupees: number;
  engineer_pct: number;
  parts_pct: number;
  travel_pct: number;
};

type LossRow = {
  id: string;
  repair_job_id: string;
  hospital_email: string | null;
  equipment_class: string;
  total_cost_rupees: number;
  invoice_amount_rupees: number;
  margin_rupees: number;
  closed_at: string;
};

type MonthRow = {
  period_month: string;
  jobs_closed: number;
  total_cost_rupees: number;
  total_invoice_rupees: number;
  total_margin_rupees: number;
  avg_cost_per_job_rupees: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "₹" + n.toLocaleString("en-IN");
}

function marginClass(n: number): string {
  if (n > 0) return "text-emerald-700";
  if (n < 0) return "text-rose-700";
  return "text-gray-600";
}

export default async function FounderCustomerServiceCostPerJobAnalysisPage() {
  const sb = await getSupabaseServerClient();

  const [jobsRes, byHospitalRes, byEqRes, breakdownRes, lossRes, trendRes] = await Promise.all([
    sb.rpc("list_service_cost_jobs_r2368", { p_limit: 200 }),
    sb.rpc("cost_by_hospital_r2368"),
    sb.rpc("cost_by_equipment_class_r2368"),
    sb.rpc("cost_breakdown_summary_r2368"),
    sb.rpc("top_loss_jobs_r2368", { p_limit: 20 }),
    sb.rpc("cost_monthly_trend_r2368", { p_months: 12 }),
  ]);

  if (jobsRes.error) throw new Error(`list_service_cost_jobs_r2368: ${jobsRes.error.message}`);
  if (byHospitalRes.error) throw new Error(`cost_by_hospital_r2368: ${byHospitalRes.error.message}`);
  if (byEqRes.error) throw new Error(`cost_by_equipment_class_r2368: ${byEqRes.error.message}`);
  if (breakdownRes.error) throw new Error(`cost_breakdown_summary_r2368: ${breakdownRes.error.message}`);
  if (lossRes.error) throw new Error(`top_loss_jobs_r2368: ${lossRes.error.message}`);
  if (trendRes.error) throw new Error(`cost_monthly_trend_r2368: ${trendRes.error.message}`);

  const jobs = (jobsRes.data ?? []) as JobRow[];
  const byHospital = (byHospitalRes.data ?? []) as HospitalRow[];
  const byEq = (byEqRes.data ?? []) as EquipmentClassRow[];
  const breakdownRows = (breakdownRes.data ?? []) as BreakdownRow[];
  const lossJobs = (lossRes.data ?? []) as LossRow[];
  const trend = (trendRes.data ?? []) as MonthRow[];

  const breakdown: BreakdownRow = breakdownRows[0] ?? {
    jobs_closed: 0,
    total_engineer_cost_rupees: 0,
    total_parts_cost_rupees: 0,
    total_travel_cost_rupees: 0,
    total_cost_rupees: 0,
    total_invoice_rupees: 0,
    total_margin_rupees: 0,
    engineer_pct: 0,
    parts_pct: 0,
    travel_pct: 0,
  };

  const lossJobCount = jobs.filter((j) => j.margin_rupees < 0).length;
  const avgCostPerJob = breakdown.jobs_closed > 0 ? Math.round(breakdown.total_cost_rupees / breakdown.jobs_closed) : 0;

  const jobColumns: Column<JobRow>[] = [
    { key: "closed_at", header: "Closed", render: (r: any) => fmtDate(r.closed_at) },
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? "—"}</span> },
    { key: "equipment_class", header: "Equipment", render: (r: any) => r.equipment_class },
    { key: "engineer_minutes", header: "Eng min", render: (r: any) => String(r.engineer_minutes) },
    { key: "engineer_cost_rupees", header: "Eng cost", render: (r: any) => rupees(r.engineer_cost_rupees) },
    { key: "parts_cost_rupees", header: "Parts", render: (r: any) => rupees(r.parts_cost_rupees) },
    { key: "travel_cost_rupees", header: "Travel", render: (r: any) => rupees(r.travel_cost_rupees) },
    { key: "total_cost_rupees", header: "Total cost", render: (r: any) => <span className="font-medium">{rupees(r.total_cost_rupees)}</span> },
    { key: "invoice_amount_rupees", header: "Invoice", render: (r: any) => rupees(r.invoice_amount_rupees) },
    { key: "margin_rupees", header: "Margin", render: (r: any) => <span className={marginClass(r.margin_rupees)}>{rupees(r.margin_rupees)}</span> },
  ];

  const hospitalColumns: Column<HospitalRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? "—"}</span> },
    { key: "jobs_closed", header: "Jobs", render: (r: any) => String(r.jobs_closed) },
    { key: "total_cost_rupees", header: "Total cost", render: (r: any) => rupees(r.total_cost_rupees) },
    { key: "total_invoice_rupees", header: "Total invoice", render: (r: any) => rupees(r.total_invoice_rupees) },
    { key: "total_margin_rupees", header: "Margin", render: (r: any) => <span className={marginClass(r.total_margin_rupees)}>{rupees(r.total_margin_rupees)}</span> },
    { key: "avg_cost_per_job_rupees", header: "Avg cost/job", render: (r: any) => rupees(r.avg_cost_per_job_rupees) },
    { key: "margin_pct", header: "Margin %", render: (r: any) => `${r.margin_pct}%` },
  ];

  const eqColumns: Column<EquipmentClassRow>[] = [
    { key: "equipment_class", header: "Equipment class", render: (r: any) => <span className="font-medium">{r.equipment_class}</span> },
    { key: "jobs_closed", header: "Jobs", render: (r: any) => String(r.jobs_closed) },
    { key: "total_cost_rupees", header: "Total cost", render: (r: any) => rupees(r.total_cost_rupees) },
    { key: "total_invoice_rupees", header: "Total invoice", render: (r: any) => rupees(r.total_invoice_rupees) },
    { key: "total_margin_rupees", header: "Margin", render: (r: any) => <span className={marginClass(r.total_margin_rupees)}>{rupees(r.total_margin_rupees)}</span> },
    { key: "avg_cost_per_job_rupees", header: "Avg cost/job", render: (r: any) => rupees(r.avg_cost_per_job_rupees) },
    { key: "avg_engineer_minutes", header: "Avg eng min", render: (r: any) => String(r.avg_engineer_minutes) },
  ];

  const lossColumns: Column<LossRow>[] = [
    { key: "closed_at", header: "Closed", render: (r: any) => fmtDate(r.closed_at) },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? "—" },
    { key: "equipment_class", header: "Equipment", render: (r: any) => r.equipment_class },
    { key: "total_cost_rupees", header: "Cost", render: (r: any) => rupees(r.total_cost_rupees) },
    { key: "invoice_amount_rupees", header: "Invoice", render: (r: any) => rupees(r.invoice_amount_rupees) },
    { key: "margin_rupees", header: "Loss", render: (r: any) => <span className="text-rose-700 font-medium">{rupees(r.margin_rupees)}</span> },
  ];

  const trendColumns: Column<MonthRow>[] = [
    { key: "period_month", header: "Month", render: (r: any) => fmtDate(r.period_month) },
    { key: "jobs_closed", header: "Jobs", render: (r: any) => String(r.jobs_closed) },
    { key: "total_cost_rupees", header: "Cost", render: (r: any) => rupees(r.total_cost_rupees) },
    { key: "total_invoice_rupees", header: "Invoice", render: (r: any) => rupees(r.total_invoice_rupees) },
    { key: "total_margin_rupees", header: "Margin", render: (r: any) => <span className={marginClass(r.total_margin_rupees)}>{rupees(r.total_margin_rupees)}</span> },
    { key: "avg_cost_per_job_rupees", header: "Avg cost/job", render: (r: any) => rupees(r.avg_cost_per_job_rupees) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer service-cost-per-job analysis — r2368</h1>
        <p className="mt-1 text-xs text-gray-500">
          True service cost per closed job =&gt; engineer time + parts + travel. Sliced by hospital &amp; equipment
          class so we can spot loss-makers and reprice AMC tiers.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Jobs closed</div>
          <div className="mt-1 text-lg font-semibold">{breakdown.jobs_closed}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total cost</div>
          <div className="mt-1 text-lg font-semibold">{rupees(breakdown.total_cost_rupees)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total invoice</div>
          <div className="mt-1 text-lg font-semibold">{rupees(breakdown.total_invoice_rupees)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total margin</div>
          <div className={`mt-1 text-lg font-semibold ${marginClass(breakdown.total_margin_rupees)}`}>{rupees(breakdown.total_margin_rupees)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg cost/job</div>
          <div className="mt-1 text-lg font-semibold">{rupees(avgCostPerJob)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Loss-making jobs</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{lossJobCount}</div>
        </div>
      </section>

      <section className="grid grid-cols-1 gap-3 md:grid-cols-3">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Engineer share of cost</div>
          <div className="mt-1 text-lg font-semibold">{breakdown.engineer_pct}%</div>
          <div className="text-xs text-gray-500">{rupees(breakdown.total_engineer_cost_rupees)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Parts share of cost</div>
          <div className="mt-1 text-lg font-semibold">{breakdown.parts_pct}%</div>
          <div className="text-xs text-gray-500">{rupees(breakdown.total_parts_cost_rupees)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Travel share of cost</div>
          <div className="mt-1 text-lg font-semibold">{breakdown.travel_pct}%</div>
          <div className="text-xs text-gray-500">{rupees(breakdown.total_travel_cost_rupees)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Cost by hospital</h2>
        <p className="text-xs text-gray-500">
          Sorted by total cost desc. Margin % &lt;= 0 =&gt; hospital is a loss-maker; renegotiate AMC or drop.
        </p>
        <DataTable
          rows={byHospital}
          columns={hospitalColumns}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
          emptyMessage="No closed jobs recorded yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Cost by equipment class</h2>
        <p className="text-xs text-gray-500">
          Equipment classes with high avg cost &amp; low margin are repricing candidates; classes with low cost &amp;
          high invoice =&gt; scale aggressively.
        </p>
        <DataTable
          rows={byEq}
          columns={eqColumns}
          rowKey={(r: any, i: number) => String(r.equipment_class ?? i)}
          emptyMessage="No equipment-class data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top loss-making jobs</h2>
        <p className="text-xs text-gray-500">
          Jobs where total cost &gt; invoice amount =&gt; we burned money. Investigate root cause: wrong tier? bad
          part? wrong engineer?
        </p>
        <DataTable
          rows={lossJobs}
          columns={lossColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No loss-making jobs — every closed job is profitable."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly trend (last 12 months)</h2>
        <p className="text-xs text-gray-500">
          Watch avg cost/job =&gt; if rising faster than invoice, margin is compressing.
        </p>
        <DataTable
          rows={trend}
          columns={trendColumns}
          rowKey={(r: any, i: number) => String(r.period_month ?? i)}
          emptyMessage="No monthly data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Recent closed jobs (last 200)</h2>
        <p className="text-xs text-gray-500">
          Raw per-job cost ledger. Use to audit suspicious rows or feed into AMC re-pricing models.
        </p>
        <DataTable
          rows={jobs}
          columns={jobColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No closed jobs in the cost ledger yet."
        />
      </section>
    </div>
  );
}
