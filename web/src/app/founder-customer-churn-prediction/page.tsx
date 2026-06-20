import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type SummaryRow = {
  total_models: number | null;
  active_models: number | null;
  shadow_models: number | null;
  active_threshold_pct: number | null;
  total_feature_snapshots: number | null;
  snapshots_last_7d: number | null;
  snapshots_last_30d: number | null;
  hospitals_scored: number | null;
  hospitals_at_risk: number | null;
  avg_churn_score: number | null;
  max_churn_score: number | null;
  total_outcomes: number | null;
  correct_predictions: number | null;
  false_positives: number | null;
  false_negatives: number | null;
  precision_observed_pct: number | null;
};

type ActiveModel = {
  id: string;
  model_label: string | null;
  model_family: string | null;
  trained_through: string | null;
  accuracy_pct: number | null;
  precision_pct: number | null;
  recall_pct: number | null;
  auc_roc: number | null;
  churn_threshold_pct: number | null;
  shadow_mode: boolean | null;
  activated_at: string | null;
};

type AtRiskRow = {
  hospital_org_id: string;
  hospital_name: string | null;
  latest_score: number | null;
  latest_snapshot_at: string | null;
  days_since_last_visit: number | null;
  sla_breach_count_90d: number | null;
  open_dispute_count: number | null;
  monthly_fee_rupees: number | null;
  threshold_pct: number | null;
  exceeds_threshold_by: number | null;
};

type FeatureRow = {
  id: string;
  hospital_name: string | null;
  feature_snapshot_at: string | null;
  days_since_last_visit: number | null;
  sla_breach_count_90d: number | null;
  code_red_count_180d: number | null;
  payment_overdue_days: number | null;
  open_dispute_count: number | null;
  nps_score: number | null;
  monthly_fee_rupees: number | null;
  computed_churn_score: number | null;
  model_label: string | null;
};

function fmtPct(v: number | null | undefined) {
  if (v == null) return "—";
  return `${Number(v).toFixed(1)}%`;
}

function fmtDate(v: string | null | undefined) {
  if (!v) return "—";
  return new Date(v).toLocaleString();
}

export default async function FounderCustomerChurnPredictionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, modelsRes, atRiskRes, featuresRes] = await Promise.all([
    supabase.rpc("founder_churn_prediction_summary"),
    supabase.rpc("founder_churn_prediction_active_model"),
    supabase.rpc("founder_churn_prediction_at_risk_hospitals", { p_limit: 50 }),
    supabase.rpc("founder_churn_prediction_features_recent", { p_limit: 50 }),
  ]);

  const summary: SummaryRow = (summaryRes.data?.[0] ?? {}) as SummaryRow;
  const models: ActiveModel[] = (modelsRes.data ?? []) as ActiveModel[];
  const atRisk: AtRiskRow[] = (atRiskRes.data ?? []) as AtRiskRow[];
  const features: FeatureRow[] = (featuresRes.data ?? []) as FeatureRow[];
  const activeModel = models[0];

  const cards: { label: string; value: string; tone?: "good" | "warn" | "bad" }[] = [
    { label: "Total models", value: formatNumber(summary.total_models ?? 0) },
    { label: "Active (prod)", value: formatNumber(summary.active_models ?? 0), tone: "good" },
    { label: "Shadow mode", value: formatNumber(summary.shadow_models ?? 0) },
    { label: "Active threshold", value: fmtPct(summary.active_threshold_pct) },
    { label: "Feature snapshots", value: formatNumber(summary.total_feature_snapshots ?? 0) },
    { label: "Snapshots 7d", value: formatNumber(summary.snapshots_last_7d ?? 0) },
    { label: "Snapshots 30d", value: formatNumber(summary.snapshots_last_30d ?? 0) },
    { label: "Hospitals scored", value: formatNumber(summary.hospitals_scored ?? 0) },
    { label: "At-risk hospitals", value: formatNumber(summary.hospitals_at_risk ?? 0), tone: "warn" },
    { label: "Avg churn score", value: fmtPct(summary.avg_churn_score) },
    { label: "Max churn score", value: fmtPct(summary.max_churn_score) },
    { label: "Outcomes logged", value: formatNumber(summary.total_outcomes ?? 0) },
    { label: "Correct predictions", value: formatNumber(summary.correct_predictions ?? 0), tone: "good" },
    { label: "False positives", value: formatNumber(summary.false_positives ?? 0), tone: "warn" },
    { label: "False negatives", value: formatNumber(summary.false_negatives ?? 0), tone: "bad" },
    { label: "Observed precision", value: fmtPct(summary.precision_observed_pct), tone: "good" },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-8 space-y-8">
      <header className="space-y-1">
        <p className="text-xs uppercase tracking-wider text-zinc-500">r1407 Founder ops</p>
        <h1 className="text-2xl font-semibold">Customer churn prediction</h1>
        <p className="text-sm text-zinc-600">
          Model registry, feature snapshot store, and outcome ledger powering churn risk scoring across hospital accounts.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-sm font-medium text-zinc-700">Pipeline KPIs</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {cards.map((c) => (
            <div
              key={c.label}
              className={
                "rounded-lg border p-4 " +
                (c.tone === "good"
                  ? "border-emerald-200 bg-emerald-50"
                  : c.tone === "warn"
                  ? "border-amber-200 bg-amber-50"
                  : c.tone === "bad"
                  ? "border-rose-200 bg-rose-50"
                  : "border-zinc-200 bg-white")
              }
            >
              <div className="text-xs uppercase tracking-wider text-zinc-500">{c.label}</div>
              <div className="mt-1 text-xl font-semibold text-zinc-900">{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      {activeModel && (
        <section className="rounded-lg border border-zinc-200 bg-white p-4">
          <h2 className="mb-3 text-sm font-medium text-zinc-700">Active model</h2>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div>
              <div className="text-xs text-zinc-500">Label</div>
              <div className="font-medium">{activeModel.model_label ?? "—"}</div>
            </div>
            <div>
              <div className="text-xs text-zinc-500">Family</div>
              <div className="font-medium">{activeModel.model_family ?? "—"}</div>
            </div>
            <div>
              <div className="text-xs text-zinc-500">Trained through</div>
              <div className="font-medium">{activeModel.trained_through ?? "—"}</div>
            </div>
            <div>
              <div className="text-xs text-zinc-500">Mode</div>
              <div className="font-medium">{activeModel.shadow_mode ? "Shadow" : "Production"}</div>
            </div>
            <div>
              <div className="text-xs text-zinc-500">Accuracy</div>
              <div className="font-medium">{fmtPct(activeModel.accuracy_pct)}</div>
            </div>
            <div>
              <div className="text-xs text-zinc-500">Precision</div>
              <div className="font-medium">{fmtPct(activeModel.precision_pct)}</div>
            </div>
            <div>
              <div className="text-xs text-zinc-500">Recall</div>
              <div className="font-medium">{fmtPct(activeModel.recall_pct)}</div>
            </div>
            <div>
              <div className="text-xs text-zinc-500">AUC-ROC</div>
              <div className="font-medium">{activeModel.auc_roc != null ? Number(activeModel.auc_roc).toFixed(3) : "—"}</div>
            </div>
          </div>
        </section>
      )}

      <section>
        <h2 className="mb-3 text-sm font-medium text-zinc-700">
          At-risk hospitals (score {">"} threshold)
        </h2>
        <div className="overflow-x-auto rounded-lg border border-zinc-200">
          <table className="min-w-full text-sm">
            <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <th className="px-3 py-2 text-left">Hospital</th>
                <th className="px-3 py-2 text-right">Score</th>
                <th className="px-3 py-2 text-right">Over threshold</th>
                <th className="px-3 py-2 text-right">Days since visit</th>
                <th className="px-3 py-2 text-right">SLA breaches 90d</th>
                <th className="px-3 py-2 text-right">Open disputes</th>
                <th className="px-3 py-2 text-right">MRR (₹)</th>
                <th className="px-3 py-2 text-left">Snapshot</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {atRisk.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-6 text-center text-zinc-500">No hospitals currently above threshold.</td></tr>
              ) : (
                atRisk.map((r) => (
                  <tr key={r.hospital_org_id} className="hover:bg-zinc-50">
                    <td className="px-3 py-2">{r.hospital_name ?? r.hospital_org_id}</td>
                    <td className="px-3 py-2 text-right font-medium">{fmtPct(r.latest_score)}</td>
                    <td className="px-3 py-2 text-right text-rose-600">+{fmtPct(r.exceeds_threshold_by)}</td>
                    <td className="px-3 py-2 text-right">{r.days_since_last_visit ?? "—"}</td>
                    <td className="px-3 py-2 text-right">{r.sla_breach_count_90d ?? 0}</td>
                    <td className="px-3 py-2 text-right">{r.open_dispute_count ?? 0}</td>
                    <td className="px-3 py-2 text-right">{formatNumber(r.monthly_fee_rupees ?? 0)}</td>
                    <td className="px-3 py-2 text-zinc-500">{fmtDate(r.latest_snapshot_at)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-medium text-zinc-700">Recent feature snapshots</h2>
        <div className="overflow-x-auto rounded-lg border border-zinc-200">
          <table className="min-w-full text-sm">
            <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <th className="px-3 py-2 text-left">Hospital</th>
                <th className="px-3 py-2 text-left">When</th>
                <th className="px-3 py-2 text-right">Score</th>
                <th className="px-3 py-2 text-right">Days idle</th>
                <th className="px-3 py-2 text-right">SLA 90d</th>
                <th className="px-3 py-2 text-right">Code red 180d</th>
                <th className="px-3 py-2 text-right">Overdue d</th>
                <th className="px-3 py-2 text-right">Disputes</th>
                <th className="px-3 py-2 text-right">NPS</th>
                <th className="px-3 py-2 text-left">Model</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {features.length === 0 ? (
                <tr><td colSpan={10} className="px-3 py-6 text-center text-zinc-500">No feature snapshots recorded yet.</td></tr>
              ) : (
                features.map((f) => (
                  <tr key={f.id} className="hover:bg-zinc-50">
                    <td className="px-3 py-2">{f.hospital_name ?? "—"}</td>
                    <td className="px-3 py-2 text-zinc-500">{fmtDate(f.feature_snapshot_at)}</td>
                    <td className="px-3 py-2 text-right font-medium">{fmtPct(f.computed_churn_score)}</td>
                    <td className="px-3 py-2 text-right">{f.days_since_last_visit ?? "—"}</td>
                    <td className="px-3 py-2 text-right">{f.sla_breach_count_90d ?? 0}</td>
                    <td className="px-3 py-2 text-right">{f.code_red_count_180d ?? 0}</td>
                    <td className="px-3 py-2 text-right">{f.payment_overdue_days ?? 0}</td>
                    <td className="px-3 py-2 text-right">{f.open_dispute_count ?? 0}</td>
                    <td className="px-3 py-2 text-right">{f.nps_score ?? "—"}</td>
                    <td className="px-3 py-2 text-zinc-500">{f.model_label ?? "—"}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="text-xs text-zinc-500">
        Backed by 3 tables + 8 RPCs. Threshold + shadow-mode flags are model-version-scoped; outcomes ledger drives observed precision back-testing.
      </footer>
    </main>
  );
}
