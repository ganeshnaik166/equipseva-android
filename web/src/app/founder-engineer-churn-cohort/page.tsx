import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type Kpi = { label: string; value: string | number };

function fmt(v: any): string {
  if (v === null || v === undefined) return "—";
  if (typeof v === "number") return Number.isFinite(v) ? v.toLocaleString() : "—";
  return String(v);
}

function pct(v: any): string {
  if (v === null || v === undefined) return "—";
  const n = Number(v);
  return Number.isFinite(n) ? n.toFixed(2) + "%" : "—";
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let cohorts: any[] = [];
  let atRisk: any[] = [];
  let tierCorr: any[] = [];
  let payoutSignal: any[] = [];
  let snapshots: any[] = [];

  try {
    const r = await sb.rpc("founder_engineer_churn_kpis");
    kpis = (r.data as any[])?.[0] ?? null;
  } catch {
    kpis = null;
  }

  try {
    const r = await sb.rpc("founder_engineer_churn_cohort_grid");
    cohorts = (r.data as any[]) ?? [];
  } catch {
    cohorts = [];
  }

  try {
    const r = await sb.rpc("founder_engineer_churn_at_risk_list");
    atRisk = (r.data as any[]) ?? [];
  } catch {
    atRisk = [];
  }

  try {
    const r = await sb.rpc("founder_engineer_churn_tier_correlation");
    tierCorr = (r.data as any[]) ?? [];
  } catch {
    tierCorr = [];
  }

  try {
    const r = await sb.rpc("founder_engineer_churn_payout_signal");
    payoutSignal = (r.data as any[]) ?? [];
  } catch {
    payoutSignal = [];
  }

  try {
    const r = await sb.rpc("founder_engineer_churn_recent_snapshots");
    snapshots = (r.data as any[]) ?? [];
  } catch {
    snapshots = [];
  }

  try {
    await sb.rpc("log_founder_churn_cohort_view", {
      p_filter: { source: "page_load" },
    });
  } catch {}

  const kpiCards: Kpi[] = [
    { label: "Total engineers", value: fmt(kpis?.total_engineers) },
    { label: "Active engineers", value: fmt(kpis?.active_engineers) },
    { label: "Churned engineers", value: fmt(kpis?.churned_engineers) },
    { label: "At-risk engineers", value: fmt(kpis?.at_risk_engineers) },
    { label: "Overall churn rate", value: pct(kpis?.churn_rate_pct) },
    { label: "Avg days since last job", value: fmt(kpis?.avg_days_since_last_job) },
    { label: "Avg NPS", value: fmt(kpis?.avg_nps) },
    { label: "Avg payout delay (d)", value: fmt(kpis?.avg_payout_delay_days) },
    { label: "High risk", value: fmt(kpis?.high_risk_count) },
    { label: "Med risk", value: fmt(kpis?.med_risk_count) },
    { label: "Low risk", value: fmt(kpis?.low_risk_count) },
    { label: "Cohorts tracked", value: fmt(kpis?.total_cohorts) },
    { label: "Worst cohort", value: fmt(kpis?.worst_cohort_label) },
    { label: "Worst cohort churn", value: pct(kpis?.worst_cohort_churn_pct) },
    { label: "Best cohort", value: fmt(kpis?.best_cohort_label) },
    { label: "Best cohort churn", value: pct(kpis?.best_cohort_churn_pct) },
  ];

  const cohortCols: Column<any>[] = [
    { key: "signup_month", header: "Signup month", render: (r: any) => fmt(r.signup_month) },
    { key: "tier", header: "Tier", render: (r: any) => fmt(r.tier) },
    { key: "city", header: "City", render: (r: any) => fmt(r.city) },
    { key: "cohort_size", header: "Size", render: (r: any) => fmt(r.cohort_size) },
    { key: "churned_count", header: "Churned", render: (r: any) => fmt(r.churned_count) },
    { key: "active_count", header: "Active", render: (r: any) => fmt(r.active_count) },
    { key: "churn_rate_pct", header: "Churn %", render: (r: any) => pct(r.churn_rate_pct) },
    { key: "avg_days_since_last_job", header: "Avg days since job", render: (r: any) => fmt(r.avg_days_since_last_job) },
  ];

  const atRiskCols: Column<any>[] = [
    { key: "engineer_name", header: "Engineer", render: (r: any) => fmt(r.engineer_name) },
    { key: "tier", header: "Tier", render: (r: any) => fmt(r.tier) },
    { key: "city", header: "City", render: (r: any) => fmt(r.city) },
    { key: "days_since_last_job", header: "Days since job", render: (r: any) => fmt(r.days_since_last_job) },
    { key: "payout_delay_days", header: "Payout delay (d)", render: (r: any) => fmt(r.payout_delay_days) },
    { key: "risk_band", header: "Risk band", render: (r: any) => fmt(r.risk_band) },
    { key: "risk_score", header: "Risk score", render: (r: any) => fmt(r.risk_score) },
  ];

  const tierCols: Column<any>[] = [
    { key: "tier", header: "Tier", render: (r: any) => fmt(r.tier) },
    { key: "cohort_size", header: "Engineers", render: (r: any) => fmt(r.cohort_size) },
    { key: "churned_count", header: "Churned", render: (r: any) => fmt(r.churned_count) },
    { key: "churn_rate_pct", header: "Churn %", render: (r: any) => pct(r.churn_rate_pct) },
    { key: "avg_days_since_last_job", header: "Avg days since job", render: (r: any) => fmt(r.avg_days_since_last_job) },
  ];

  const payoutCols: Column<any>[] = [
    { key: "delay_bucket", header: "Payout delay bucket", render: (r: any) => fmt(r.delay_bucket) },
    { key: "engineer_count", header: "Engineers", render: (r: any) => fmt(r.engineer_count) },
    { key: "churned_count", header: "Churned", render: (r: any) => fmt(r.churned_count) },
    { key: "churn_rate_pct", header: "Churn %", render: (r: any) => pct(r.churn_rate_pct) },
  ];

  const snapshotCols: Column<any>[] = [
    { key: "snapshot_at", header: "Snapshot at", render: (r: any) => fmt(r.snapshot_at) },
    { key: "signup_month", header: "Signup month", render: (r: any) => fmt(r.signup_month) },
    { key: "tier", header: "Tier", render: (r: any) => fmt(r.tier) },
    { key: "city", header: "City", render: (r: any) => fmt(r.city) },
    { key: "cohort_size", header: "Size", render: (r: any) => fmt(r.cohort_size) },
    { key: "churned_count", header: "Churned", render: (r: any) => fmt(r.churned_count) },
    { key: "churn_rate_pct", header: "Churn %", render: (r: any) => pct(r.churn_rate_pct) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Engineer churn cohort analysis</h1>
        <p className="text-sm text-gray-600">
          Engineers with no jobs in {">"}=60 days are flagged as churned. Cohorts grouped by signup-month {"×"} tier {"×"} city.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpiCards.map((k, i) => (
          <div key={i} className="rounded border bg-white p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value ?? "—"}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cohort grid (signup-month {"×"} tier {"×"} city)</h2>
        <DataTable columns={cohortCols} rows={cohorts} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-risk engineers (idle {">"}=30d)</h2>
        <DataTable columns={atRiskCols} rows={atRisk} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Churn by tier</h2>
        <DataTable columns={tierCols} rows={tierCorr} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Payout-delay {"→"} churn signal</h2>
        <DataTable columns={payoutCols} rows={payoutSignal} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent snapshots</h2>
        <DataTable columns={snapshotCols} rows={snapshots} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
