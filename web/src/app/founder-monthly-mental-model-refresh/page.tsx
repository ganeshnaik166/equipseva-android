import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder monthly mental model refresh — r2489" };
export const dynamic = "force-dynamic";

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function staleColor(s: string): string {
  if (s === "fresh") return "text-emerald-700";
  if (s === "aging") return "text-amber-700";
  if (s === "stale") return "text-red-700";
  if (s === "archived") return "text-gray-500";
  return "";
}

function outcomeColor(s: string): string {
  if (s === "positive") return "text-emerald-700";
  if (s === "neutral") return "text-gray-600";
  if (s === "negative") return "text-red-700";
  if (s === "pending") return "text-amber-700";
  return "";
}

export default async function FounderMonthlyMentalModelRefreshPage() {
  const sb = await getSupabaseServerClient();
  const [modelsRes, logRes, staleRes, topRes, breakdownRes, trendRes, revisitRes] = await Promise.all([
    sb.rpc("list_models_r2489"),
    sb.rpc("list_application_log_r2489"),
    sb.rpc("stale_models_focus_r2489"),
    sb.rpc("top_applied_models_r2489"),
    sb.rpc("source_kind_breakdown_r2489"),
    sb.rpc("monthly_application_trend_r2489"),
    sb.rpc("revisit_pipeline_r2489"),
  ]);

  if (modelsRes.error) throw new Error(`list_models_r2489: ${modelsRes.error.message}`);
  if (logRes.error) throw new Error(`list_application_log_r2489: ${logRes.error.message}`);
  if (staleRes.error) throw new Error(`stale_models_focus_r2489: ${staleRes.error.message}`);
  if (topRes.error) throw new Error(`top_applied_models_r2489: ${topRes.error.message}`);
  if (breakdownRes.error) throw new Error(`source_kind_breakdown_r2489: ${breakdownRes.error.message}`);
  if (trendRes.error) throw new Error(`monthly_application_trend_r2489: ${trendRes.error.message}`);
  if (revisitRes.error) throw new Error(`revisit_pipeline_r2489: ${revisitRes.error.message}`);

  const models = (modelsRes.data ?? []) as any[];
  const log = (logRes.data ?? []) as any[];
  const stale = (staleRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const breakdown = (breakdownRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const revisit = (revisitRes.data ?? []) as any[];

  const totalModels = models.length;
  const freshCount = models.filter((m: any) => m.stale_status === "fresh").length;
  const agingCount = models.filter((m: any) => m.stale_status === "aging").length;
  const staleCount = models.filter((m: any) => m.stale_status === "stale").length;
  const archivedCount = models.filter((m: any) => m.stale_status === "archived").length;
  const totalApplications = log.length;
  const positiveApplications = log.filter((l: any) => l.outcome === "positive").length;

  const modelColumns: Column<any>[] = [
    { key: "model_name", header: "Model", render: (r: any) => <span className="font-medium">{r.model_name}</span> },
    { key: "source_kind", header: "Source kind", render: (r: any) => r.source_kind },
    { key: "source_label", header: "Source", render: (r: any) => r.source_label ?? "—" },
    { key: "stale_status", header: "Status", render: (r: any) => <span className={staleColor(r.stale_status)}>{r.stale_status}</span> },
    { key: "last_used_at", header: "Last used", render: (r: any) => fmtDate(r.last_used_at) },
    { key: "stale_threshold_days", header: "Threshold (d)", render: (r: any) => r.stale_threshold_days },
    { key: "revisit_due_at", header: "Revisit due", render: (r: any) => fmtDate(r.revisit_due_at) },
    { key: "applicability_md", header: "Applicability", render: (r: any) => <span className="text-sm">{r.applicability_md ?? "—"}</span> },
  ];

  const logColumns: Column<any>[] = [
    { key: "applied_at", header: "Applied", render: (r: any) => fmtDate(r.applied_at) },
    { key: "model_name", header: "Model", render: (r: any) => <span className="font-medium">{r.model_name}</span> },
    { key: "situation_md", header: "Situation", render: (r: any) => <span className="text-sm">{r.situation_md ?? "—"}</span> },
    { key: "insight_md", header: "Insight", render: (r: any) => <span className="text-sm">{r.insight_md ?? "—"}</span> },
    { key: "outcome", header: "Outcome", render: (r: any) => <span className={outcomeColor(r.outcome)}>{r.outcome}</span> },
    { key: "revisit_required", header: "Revisit", render: (r: any) => (r.revisit_required ? "yes" : "no") },
  ];

  const staleColumns: Column<any>[] = [
    { key: "model_name", header: "Model", render: (r: any) => <span className="font-medium">{r.model_name}</span> },
    { key: "source_kind", header: "Source kind", render: (r: any) => r.source_kind },
    { key: "stale_status", header: "Status", render: (r: any) => <span className={staleColor(r.stale_status)}>{r.stale_status}</span> },
    { key: "last_used_at", header: "Last used", render: (r: any) => fmtDate(r.last_used_at) },
    { key: "days_since_use", header: "Days since", render: (r: any) => r.days_since_use ?? "—" },
    { key: "revisit_due_at", header: "Revisit due", render: (r: any) => fmtDate(r.revisit_due_at) },
  ];

  const topColumns: Column<any>[] = [
    { key: "model_name", header: "Model", render: (r: any) => <span className="font-medium">{r.model_name}</span> },
    { key: "source_kind", header: "Source kind", render: (r: any) => r.source_kind },
    { key: "application_count", header: "Applications", render: (r: any) => r.application_count },
    { key: "positive_count", header: "Positive", render: (r: any) => <span className="text-emerald-700">{r.positive_count}</span> },
    { key: "last_applied_at", header: "Last applied", render: (r: any) => fmtDate(r.last_applied_at) },
  ];

  const breakdownColumns: Column<any>[] = [
    { key: "source_kind", header: "Source kind", render: (r: any) => <span className="font-medium">{r.source_kind}</span> },
    { key: "model_count", header: "Models", render: (r: any) => r.model_count },
    { key: "fresh_count", header: "Fresh", render: (r: any) => <span className="text-emerald-700">{r.fresh_count}</span> },
    { key: "aging_count", header: "Aging", render: (r: any) => <span className="text-amber-700">{r.aging_count}</span> },
    { key: "stale_count", header: "Stale", render: (r: any) => <span className="text-red-700">{r.stale_count}</span> },
    { key: "archived_count", header: "Archived", render: (r: any) => <span className="text-gray-500">{r.archived_count}</span> },
  ];

  const trendColumns: Column<any>[] = [
    { key: "month_label", header: "Month", render: (r: any) => <span className="font-mono text-sm">{r.month_label}</span> },
    { key: "application_count", header: "Applications", render: (r: any) => r.application_count },
    { key: "positive_count", header: "Positive", render: (r: any) => <span className="text-emerald-700">{r.positive_count}</span> },
    { key: "negative_count", header: "Negative", render: (r: any) => <span className="text-red-700">{r.negative_count}</span> },
    { key: "pending_count", header: "Pending", render: (r: any) => <span className="text-amber-700">{r.pending_count}</span> },
  ];

  const revisitColumns: Column<any>[] = [
    { key: "model_name", header: "Model", render: (r: any) => <span className="font-medium">{r.model_name}</span> },
    { key: "source_kind", header: "Source kind", render: (r: any) => r.source_kind },
    { key: "stale_status", header: "Status", render: (r: any) => <span className={staleColor(r.stale_status)}>{r.stale_status}</span> },
    { key: "revisit_due_at", header: "Due", render: (r: any) => fmtDate(r.revisit_due_at) },
    { key: "days_until_due", header: "Days until", render: (r: any) => r.days_until_due ?? "—" },
    { key: "revisit_required_logs", header: "Flagged logs", render: (r: any) => r.revisit_required_logs },
  ];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Monthly mental model refresh</h1>
        <p className="text-gray-600 text-sm mt-1">
          Round r2489 — founder mental models library, application log, staleness detection, and revisit pipeline.
          First-principles re-derivation each month keeps frameworks sharp.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Models</div>
          <div className="text-2xl font-semibold">{totalModels}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Fresh</div>
          <div className="text-2xl font-semibold text-emerald-700">{freshCount}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Aging</div>
          <div className="text-2xl font-semibold text-amber-700">{agingCount}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Stale</div>
          <div className="text-2xl font-semibold text-red-700">{staleCount}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Archived</div>
          <div className="text-2xl font-semibold text-gray-500">{archivedCount}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Applications (+pos)</div>
          <div className="text-2xl font-semibold">{totalApplications}<span className="text-base text-emerald-700"> / {positiveApplications}</span></div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Mental models</h2>
        <DataTable
          rows={models}
          columns={modelColumns}
          emptyMessage="No mental models yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale & aging focus</h2>
        <DataTable
          rows={stale}
          columns={staleColumns}
          emptyMessage="No stale models — all fresh"
          rowKey={(r: any, i: number) => String(r.model_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top applied models</h2>
        <DataTable
          rows={top}
          columns={topColumns}
          emptyMessage="No applications recorded"
          rowKey={(r: any, i: number) => String(r.model_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Source kind breakdown</h2>
        <DataTable
          rows={breakdown}
          columns={breakdownColumns}
          emptyMessage="No source kinds"
          rowKey={(r: any, i: number) => String(r.source_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly application trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Revisit pipeline</h2>
        <DataTable
          rows={revisit}
          columns={revisitColumns}
          emptyMessage="Nothing to revisit"
          rowKey={(r: any, i: number) => String(r.model_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Application log</h2>
        <DataTable
          rows={log}
          columns={logColumns}
          emptyMessage="No applications logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
