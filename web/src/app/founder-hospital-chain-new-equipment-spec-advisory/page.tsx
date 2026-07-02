import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital chain new-equipment spec advisory — r2391" };
export const dynamic = "force-dynamic";

type AdvisoryRow = {
  id: string;
  chain_admin_user_id: string;
  chain_name: string;
  equipment_category: string;
  budget_rupees: number | null;
  hospitals_count: number;
  ask_summary: string;
  our_recommendation: string | null;
  recommended_brand: string | null;
  recommended_model: string | null;
  recommended_price_rupees: number | null;
  status: string;
  asked_at: string;
  recommended_at: string | null;
  decided_at: string | null;
  created_at: string;
};

type WinRateRow = {
  equipment_category: string;
  advisory_count: number;
  installed_count: number;
  lost_count: number;
  win_rate_pct: number;
  total_units_installed: number;
  total_revenue_assist_rupees: number;
};

type TopChainRow = {
  chain_name: string;
  advisory_count: number;
  installed_count: number;
  win_rate_pct: number;
  last_asked_at: string | null;
};

type PipelineRow = {
  open_count: number;
  recommended_count: number;
  installed_count: number;
  lost_count: number;
  withdrawn_count: number;
  total_pipeline_budget_rupees: number;
  avg_decision_days: number;
};

type StalledRow = {
  id: string;
  chain_name: string;
  equipment_category: string;
  status: string;
  asked_at: string;
  days_open: number;
  budget_rupees: number | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null): string {
  if (n === null || n === undefined) return "—";
  return "Rs " + n.toLocaleString("en-IN");
}

function statusClass(status: string): string {
  if (status === "installed") return "text-emerald-700 font-medium";
  if (status === "recommended") return "text-blue-700";
  if (status === "open") return "text-amber-700";
  if (status === "lost") return "text-rose-700";
  if (status === "withdrawn") return "text-gray-500";
  return "";
}

function winRateClass(pct: number): string {
  if (pct >= 70) return "text-emerald-700 font-medium";
  if (pct >= 40) return "text-amber-700";
  return "text-rose-700";
}

export default async function FounderHospitalChainNewEquipmentSpecAdvisoryPage() {
  const sb = await getSupabaseServerClient();
  const [advisoriesRes, winRateRes, topChainsRes, pipelineRes, stalledRes] = await Promise.all([
    sb.rpc("list_chain_spec_advisories_r2391"),
    sb.rpc("win_rate_by_category_r2391"),
    sb.rpc("top_chains_by_advisory_r2391"),
    sb.rpc("pipeline_summary_r2391"),
    sb.rpc("stalled_advisories_r2391"),
  ]);

  const advisories: AdvisoryRow[] = (advisoriesRes.data as AdvisoryRow[] | null) ?? [];
  const winRates: WinRateRow[] = (winRateRes.data as WinRateRow[] | null) ?? [];
  const topChains: TopChainRow[] = (topChainsRes.data as TopChainRow[] | null) ?? [];
  const pipelineArr: PipelineRow[] = (pipelineRes.data as PipelineRow[] | null) ?? [];
  const pipeline = pipelineArr[0] ?? {
    open_count: 0,
    recommended_count: 0,
    installed_count: 0,
    lost_count: 0,
    withdrawn_count: 0,
    total_pipeline_budget_rupees: 0,
    avg_decision_days: 0,
  };
  const stalled: StalledRow[] = (stalledRes.data as StalledRow[] | null) ?? [];

  const errs = [advisoriesRes.error, winRateRes.error, topChainsRes.error, pipelineRes.error, stalledRes.error]
    .filter((e) => e)
    .map((e: any) => e.message);

  const advisoryCols: Column<any>[] = [
    { key: "chain_name", header: "Chain", render: (r: AdvisoryRow) => r.chain_name },
    { key: "equipment_category", header: "Category", render: (r: AdvisoryRow) => r.equipment_category },
    { key: "hospitals_count", header: "Hospitals", render: (r: AdvisoryRow) => String(r.hospitals_count) },
    { key: "budget_rupees", header: "Budget", render: (r: AdvisoryRow) => fmtRupees(r.budget_rupees) },
    {
      key: "recommended",
      header: "Our rec",
      render: (r: AdvisoryRow) =>
        r.recommended_brand
          ? `${r.recommended_brand} ${r.recommended_model ?? ""} (${fmtRupees(r.recommended_price_rupees)})`
          : "—",
    },
    {
      key: "status",
      header: "Status",
      render: (r: AdvisoryRow) => <span className={statusClass(r.status)}>{r.status}</span>,
    },
    { key: "asked_at", header: "Asked", render: (r: AdvisoryRow) => fmtDate(r.asked_at) },
    { key: "decided_at", header: "Decided", render: (r: AdvisoryRow) => fmtDate(r.decided_at) },
  ];

  const winRateCols: Column<any>[] = [
    { key: "equipment_category", header: "Category", render: (r: WinRateRow) => r.equipment_category },
    { key: "advisory_count", header: "Advisories", render: (r: WinRateRow) => String(r.advisory_count) },
    { key: "installed_count", header: "Installed", render: (r: WinRateRow) => String(r.installed_count) },
    { key: "lost_count", header: "Lost", render: (r: WinRateRow) => String(r.lost_count) },
    {
      key: "win_rate_pct",
      header: "Win %",
      render: (r: WinRateRow) => <span className={winRateClass(r.win_rate_pct)}>{r.win_rate_pct}%</span>,
    },
    { key: "total_units_installed", header: "Units", render: (r: WinRateRow) => String(r.total_units_installed) },
    {
      key: "total_revenue_assist_rupees",
      header: "Revenue assist",
      render: (r: WinRateRow) => fmtRupees(r.total_revenue_assist_rupees),
    },
  ];

  const topChainCols: Column<any>[] = [
    { key: "chain_name", header: "Chain", render: (r: TopChainRow) => r.chain_name },
    { key: "advisory_count", header: "Asks", render: (r: TopChainRow) => String(r.advisory_count) },
    { key: "installed_count", header: "Installed", render: (r: TopChainRow) => String(r.installed_count) },
    {
      key: "win_rate_pct",
      header: "Win %",
      render: (r: TopChainRow) => <span className={winRateClass(r.win_rate_pct)}>{r.win_rate_pct}%</span>,
    },
    { key: "last_asked_at", header: "Last asked", render: (r: TopChainRow) => fmtDate(r.last_asked_at) },
  ];

  const stalledCols: Column<any>[] = [
    { key: "chain_name", header: "Chain", render: (r: StalledRow) => r.chain_name },
    { key: "equipment_category", header: "Category", render: (r: StalledRow) => r.equipment_category },
    {
      key: "status",
      header: "Status",
      render: (r: StalledRow) => <span className={statusClass(r.status)}>{r.status}</span>,
    },
    { key: "asked_at", header: "Asked", render: (r: StalledRow) => fmtDate(r.asked_at) },
    {
      key: "days_open",
      header: "Days open",
      render: (r: StalledRow) => <span className="text-rose-700 font-medium">{r.days_open}</span>,
    },
    { key: "budget_rupees", header: "Budget", render: (r: StalledRow) => fmtRupees(r.budget_rupees) },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Hospital chain new-equipment spec advisory</h1>
        <p className="text-sm text-gray-600 mt-1">
          When a chain asks us to advise on new equipment purchase, our recommendation & win-rate to install.
          Founder-only. r2391 ★★★★
        </p>
      </div>

      {errs.length > 0 && (
        <div className="rounded border border-rose-300 bg-rose-50 p-3 text-sm text-rose-800">
          <div className="font-medium">RPC errors</div>
          <ul className="list-disc ml-5 mt-1">
            {errs.map((m, i) => (
              <li key={i}>{m}</li>
            ))}
          </ul>
        </div>
      )}

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Open</div>
          <div className="text-xl font-semibold text-amber-700">{pipeline.open_count}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Recommended</div>
          <div className="text-xl font-semibold text-blue-700">{pipeline.recommended_count}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Installed</div>
          <div className="text-xl font-semibold text-emerald-700">{pipeline.installed_count}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Lost</div>
          <div className="text-xl font-semibold text-rose-700">{pipeline.lost_count}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Withdrawn</div>
          <div className="text-xl font-semibold text-gray-600">{pipeline.withdrawn_count}</div>
        </div>
        <div className="rounded border p-3 col-span-2">
          <div className="text-xs text-gray-500">Pipeline budget (open+rec)</div>
          <div className="text-xl font-semibold">{fmtRupees(pipeline.total_pipeline_budget_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg decision days</div>
          <div className="text-xl font-semibold">{pipeline.avg_decision_days}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Win-rate by category</h2>
        <DataTable
          rows={winRates}
          columns={winRateCols}
          emptyMessage="No category outcomes yet"
          rowKey={(r: WinRateRow) => r.equipment_category}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top chains by advisory volume</h2>
        <DataTable
          rows={topChains}
          columns={topChainCols}
          emptyMessage="No chain advisories yet"
          rowKey={(r: TopChainRow) => r.chain_name}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Stalled advisories (&gt; 14 days open)</h2>
        <DataTable
          rows={stalled}
          columns={stalledCols}
          emptyMessage="No stalled advisories"
          rowKey={(r: StalledRow) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">All advisories</h2>
        <DataTable
          rows={advisories}
          columns={advisoryCols}
          emptyMessage="No advisories logged"
          rowKey={(r: AdvisoryRow) => r.id}
        />
      </section>
    </div>
  );
}
