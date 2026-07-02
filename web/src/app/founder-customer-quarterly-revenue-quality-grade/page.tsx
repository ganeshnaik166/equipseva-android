import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer quarterly revenue quality grade — r2636" };
export const dynamic = "force-dynamic";

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return "—";
  return "₹" + Number(n).toLocaleString("en-IN");
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return "—";
  return `${Number(n).toFixed(2)}%`;
}

function gradeTone(g: string): string {
  if (g === "A") return "text-emerald-700 font-semibold";
  if (g === "B") return "text-emerald-600";
  if (g === "C") return "text-amber-700";
  if (g === "D") return "text-orange-700";
  if (g === "F") return "text-rose-700 font-semibold";
  return "";
}

function statusTone(s: string): string {
  if (s === "improving") return "text-emerald-700";
  if (s === "stable") return "text-sky-700";
  if (s === "declining") return "text-rose-700";
  if (s === "monitoring") return "text-gray-700";
  if (s === "open") return "text-amber-700";
  if (s === "done") return "text-emerald-700";
  if (s === "dropped") return "text-gray-500";
  return "";
}

export default async function FounderCustomerQuarterlyRevenueQualityGradePage() {
  const sb = await getSupabaseServerClient();
  const [
    qualityRes,
    actionsRes,
    atRiskRes,
    gradeDistRes,
    statusFunnelRes,
    trendRes,
    summaryRes,
  ] = await Promise.all([
    sb.rpc("list_quality_r2636"),
    sb.rpc("list_improvement_actions_r2636"),
    sb.rpc("top_at_risk_focus_r2636"),
    sb.rpc("grade_distribution_r2636"),
    sb.rpc("status_funnel_r2636"),
    sb.rpc("quarterly_quality_trend_r2636"),
    sb.rpc("total_revenue_summary_r2636"),
  ]);

  if (qualityRes.error) throw new Error(`list_quality_r2636: ${qualityRes.error.message}`);
  if (actionsRes.error) throw new Error(`list_improvement_actions_r2636: ${actionsRes.error.message}`);
  if (atRiskRes.error) throw new Error(`top_at_risk_focus_r2636: ${atRiskRes.error.message}`);
  if (gradeDistRes.error) throw new Error(`grade_distribution_r2636: ${gradeDistRes.error.message}`);
  if (statusFunnelRes.error) throw new Error(`status_funnel_r2636: ${statusFunnelRes.error.message}`);
  if (trendRes.error) throw new Error(`quarterly_quality_trend_r2636: ${trendRes.error.message}`);
  if (summaryRes.error) throw new Error(`total_revenue_summary_r2636: ${summaryRes.error.message}`);

  const quality = (qualityRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const atRisk = (atRiskRes.data ?? []) as any[];
  const gradeDist = (gradeDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? []) as any[])[0] ?? null;

  const qualityCols: Column<any>[] = [
    { key: "quarter_label", header: "Quarter", render: (r: any) => r.quarter_label },
    { key: "hospital", header: "Hospital", render: (r: any) => String(r.hospital_user_id).slice(0, 8) },
    { key: "revenue", header: "Revenue", render: (r: any) => fmtRupees(r.revenue_rupees) },
    { key: "recurring", header: "Recurring %", render: (r: any) => fmtPct(r.recurring_pct) },
    { key: "paid_on_time", header: "Paid on time %", render: (r: any) => fmtPct(r.paid_on_time_pct) },
    { key: "churn_risk", header: "Churn risk %", render: (r: any) => fmtPct(r.churn_risk_pct) },
    { key: "grade", header: "Grade", render: (r: any) => <span className={gradeTone(r.quality_grade)}>{r.quality_grade}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusTone(r.status)}>{r.status}</span> },
    { key: "owner", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "created", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const actionsCols: Column<any>[] = [
    { key: "action_at", header: "When", render: (r: any) => fmtDate(r.action_at) },
    { key: "quality_id", header: "Cohort", render: (r: any) => String(r.quality_id).slice(0, 8) },
    { key: "kind", header: "Action", render: (r: any) => r.action_kind },
    { key: "outcome", header: "Outcome", render: (r: any) => r.outcome },
    { key: "status", header: "Status", render: (r: any) => <span className={statusTone(r.status)}>{r.status}</span> },
    { key: "owner", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const atRiskCols: Column<any>[] = [
    { key: "quarter_label", header: "Quarter", render: (r: any) => r.quarter_label },
    { key: "hospital", header: "Hospital", render: (r: any) => String(r.hospital_user_id).slice(0, 8) },
    { key: "revenue", header: "Revenue", render: (r: any) => fmtRupees(r.revenue_rupees) },
    { key: "churn_risk", header: "Churn risk %", render: (r: any) => fmtPct(r.churn_risk_pct) },
    { key: "grade", header: "Grade", render: (r: any) => <span className={gradeTone(r.quality_grade)}>{r.quality_grade}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusTone(r.status)}>{r.status}</span> },
    { key: "owner", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const gradeDistCols: Column<any>[] = [
    { key: "grade", header: "Grade", render: (r: any) => <span className={gradeTone(r.quality_grade)}>{r.quality_grade}</span> },
    { key: "cohort_count", header: "Cohorts", render: (r: any) => r.cohort_count },
    { key: "total_revenue", header: "Total revenue", render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: "avg_churn", header: "Avg churn risk %", render: (r: any) => fmtPct(r.avg_churn_risk_pct) },
  ];

  const statusFunnelCols: Column<any>[] = [
    { key: "status", header: "Status", render: (r: any) => <span className={statusTone(r.status)}>{r.status}</span> },
    { key: "cohort_count", header: "Cohorts", render: (r: any) => r.cohort_count },
    { key: "total_revenue", header: "Total revenue", render: (r: any) => fmtRupees(r.total_revenue_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: "quarter_label", header: "Quarter", render: (r: any) => r.quarter_label },
    { key: "cohort_count", header: "Cohorts", render: (r: any) => r.cohort_count },
    { key: "total_revenue", header: "Total revenue", render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: "avg_recurring", header: "Avg recurring %", render: (r: any) => fmtPct(r.avg_recurring_pct) },
    { key: "avg_pot", header: "Avg paid on time %", render: (r: any) => fmtPct(r.avg_paid_on_time_pct) },
    { key: "avg_churn", header: "Avg churn risk %", render: (r: any) => fmtPct(r.avg_churn_risk_pct) },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer quarterly revenue quality grade</h1>
        <p className="text-sm text-gray-600 mt-1">
          Grade every paying hospital A–F by recurring %, paid-on-time %, and churn risk —
          then track improvement actions until the at-risk cohort shrinks.
        </p>
      </header>

      {summary ? (
        <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="rounded-lg border p-3">
            <div className="text-xs uppercase text-gray-500">Cohorts</div>
            <div className="text-xl font-semibold">{summary.total_cohorts ?? 0}</div>
          </div>
          <div className="rounded-lg border p-3">
            <div className="text-xs uppercase text-gray-500">Total revenue</div>
            <div className="text-xl font-semibold">{fmtRupees(summary.total_revenue_rupees)}</div>
          </div>
          <div className="rounded-lg border p-3">
            <div className="text-xs uppercase text-gray-500">A&B revenue</div>
            <div className="text-xl font-semibold text-emerald-700">{fmtRupees(summary.high_grade_revenue_rupees)}</div>
          </div>
          <div className="rounded-lg border p-3">
            <div className="text-xs uppercase text-gray-500">At-risk revenue</div>
            <div className="text-xl font-semibold text-rose-700">{fmtRupees(summary.at_risk_revenue_rupees)}</div>
          </div>
          <div className="rounded-lg border p-3">
            <div className="text-xs uppercase text-gray-500">Avg churn risk</div>
            <div className="text-xl font-semibold">{fmtPct(summary.avg_churn_risk_pct)}</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-lg font-semibold mb-2">Top at-risk focus</h2>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          emptyMessage="No at-risk cohorts — nice."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grade distribution</h2>
        <DataTable
          rows={gradeDist}
          columns={gradeDistCols}
          emptyMessage="No graded cohorts yet."
          rowKey={(r: any, i: number) => String(r.quality_grade ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusFunnelCols}
          emptyMessage="No status rollup yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All quality grades</h2>
        <DataTable
          rows={quality}
          columns={qualityCols}
          emptyMessage="No quality cohorts yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Improvement actions</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          emptyMessage="No improvement actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
