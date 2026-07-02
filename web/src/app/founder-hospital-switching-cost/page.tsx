import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type SignalRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string;
  city: string | null;
  integration_count: number;
  custom_contract_clauses: number;
  staff_trained_count: number;
  lockin_score: number;
  assessed_at: string;
  note: string | null;
};

type ActionRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string;
  action_type: string;
  completed_at: string;
  weight: number;
  note: string | null;
};

type TopRow = {
  hospital_user_id: string;
  hospital_name: string;
  city: string | null;
  latest_lockin_score: number;
  latest_assessed_at: string;
  total_actions: number;
  total_action_weight: number;
};

type AtRiskRow = {
  hospital_user_id: string;
  hospital_name: string;
  city: string | null;
  latest_lockin_score: number;
  latest_assessed_at: string;
  days_since_assessment: number;
  risk_band: string;
};

type Summary = {
  hospitals_assessed: number;
  avg_lockin_score: number | null;
  high_lockin_count: number;
  medium_lockin_count: number;
  low_lockin_count: number;
  total_actions: number;
  total_weight: number;
  signals_last_30d: number;
};

function fmtDateTime(iso: string | null): string {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

function scoreBadge(score: number): string {
  if (score >= 70) return "#16a34a";
  if (score >= 40) return "#f59e0b";
  return "#ef4444";
}

function riskBadge(band: string): string {
  switch (band) {
    case "critical":
      return "#b91c1c";
    case "high":
      return "#ef4444";
    case "medium":
      return "#f59e0b";
    default:
      return "#64748b";
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, topRes, signalsRes, actionsRes, atRiskRes] = await Promise.all([
    sb.rpc("switching_cost_summary_r1679"),
    sb.rpc("top_locked_in_hospitals_r1679", { p_limit: 25 }),
    sb.rpc("list_signals_r1679", { p_limit: 100 }),
    sb.rpc("list_actions_r1679", { p_limit: 100 }),
    sb.rpc("low_lockin_at_risk_r1679", { p_threshold: 40, p_limit: 25 }),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] as Summary | undefined) ?? null;
  const topRows: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const signalRows: SignalRow[] = (signalsRes.data as SignalRow[] | null) ?? [];
  const actionRows: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const atRiskRows: AtRiskRow[] = (atRiskRes.data as AtRiskRow[] | null) ?? [];

  const rpcError =
    summaryRes.error?.message ||
    topRes.error?.message ||
    signalsRes.error?.message ||
    actionsRes.error?.message ||
    atRiskRes.error?.message ||
    null;

  const topCols: Column<TopRow>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "—" },
    {
      key: 'lockin',
      header: "Lock-in",
      render: (r: any) => (
        <span
          style={{
            background: scoreBadge(r.latest_lockin_score),
            color: "white",
            padding: "2px 8px",
            borderRadius: 4,
            fontWeight: 600,
          }}
        >
          {r.latest_lockin_score}
        </span>
      ),
    },
    { key: 'actions', header: 'Actions', render: (r: any) => r.total_actions },
    { key: 'weight', header: 'Weight', render: (r: any) => r.total_action_weight },
    { key: 'last_assessed', header: 'Last Assessed', render: (r: any) => fmtDateTime(r.latest_assessed_at) },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "—" },
    {
      key: 'score',
      header: "Score",
      render: (r: any) => (
        <span style={{ color: scoreBadge(r.latest_lockin_score), fontWeight: 600 }}>
          {r.latest_lockin_score}
        </span>
      ),
    },
    {
      key: 'risk',
      header: "Risk",
      render: (r: any) => (
        <span
          style={{
            background: riskBadge(r.risk_band),
            color: "white",
            padding: "2px 8px",
            borderRadius: 4,
            fontSize: 11,
            textTransform: "uppercase",
          }}
        >
          {r.risk_band}
        </span>
      ),
    },
    { key: 'days_since_check', header: 'Days Since Check', render: (r: any) => r.days_since_assessment },
    { key: 'last_assessed', header: 'Last Assessed', render: (r: any) => fmtDateTime(r.latest_assessed_at) },
  ];

  const signalCols: Column<SignalRow>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "—" },
    { key: 'integrations', header: 'Integrations', render: (r: any) => r.integration_count },
    { key: 'clauses', header: 'Clauses', render: (r: any) => r.custom_contract_clauses },
    { key: 'staff_trained', header: 'Staff Trained', render: (r: any) => r.staff_trained_count },
    {
      key: 'score',
      header: "Score",
      render: (r: any) => (
        <span style={{ color: scoreBadge(r.lockin_score), fontWeight: 600 }}>
          {r.lockin_score}
        </span>
      ),
    },
    { key: 'assessed', header: 'Assessed', render: (r: any) => fmtDateTime(r.assessed_at) },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? "—" },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'action', header: 'Action', render: (r: any) => r.action_type },
    { key: 'weight', header: 'Weight', render: (r: any) => r.weight },
    { key: 'completed', header: 'Completed', render: (r: any) => fmtDateTime(r.completed_at) },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? "—" },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: "0 auto" }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
          Hospital Switching Cost Tracker
        </h1>
        <p style={{ color: "#64748b", fontSize: 14 }}>
          Per-hospital lock-in score: integrations, contract clauses, staff training depth.
          High score = sticky customer; low score = at flight risk.
        </p>
      </header>

      {rpcError && (
        <div
          style={{
            background: "#fef2f2",
            border: "1px solid #fecaca",
            color: "#b91c1c",
            padding: 12,
            borderRadius: 6,
            marginBottom: 16,
          }}
        >
          RPC error: {rpcError}
        </div>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: "#475569" }}>
          KPIs
        </h2>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))",
            gap: 12,
          }}
        >
          <KpiCard label="Hospitals Assessed" value={summary?.hospitals_assessed ?? 0} />
          <KpiCard
            label="Avg Lock-in"
            value={summary?.avg_lockin_score != null ? `${summary.avg_lockin_score}` : "—"}
          />
          <KpiCard
            label="High Lock-in (≥70)"
            value={summary?.high_lockin_count ?? 0}
            color="#16a34a"
          />
          <KpiCard
            label="Medium (40–69)"
            value={summary?.medium_lockin_count ?? 0}
            color="#f59e0b"
          />
          <KpiCard
            label="Low (<40)"
            value={summary?.low_lockin_count ?? 0}
            color="#ef4444"
          />
          <KpiCard label="Total Actions" value={summary?.total_actions ?? 0} />
          <KpiCard label="Total Weight" value={summary?.total_weight ?? 0} />
          <KpiCard label="Signals (30d)" value={summary?.signals_last_30d ?? 0} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: "#475569" }}>
          Top Locked-In Hospitals
        </h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          rowKey={(r, i) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: "#475569" }}>
          At-Risk Hospitals (Low Lock-in)
        </h2>
        <DataTable
          rows={atRiskRows}
          columns={atRiskCols}
          rowKey={(r, i) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: "#475569" }}>
          Latest Signals
        </h2>
        <DataTable
          rows={signalRows}
          columns={signalCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: "#475569" }}>
          Recent Lock-in Actions
        </h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ fontSize: 12, color: "#94a3b8", marginTop: 24 }}>
        r1679 · founder-only · scoring: 0–100 lock-in; weight: 1–20 per action
      </footer>
    </main>
  );
}

function KpiCard({
  label,
  value,
  color,
}: {
  label: string;
  value: number | string;
  color?: string;
}) {
  return (
    <div
      style={{
        background: "white",
        border: "1px solid #e2e8f0",
        borderRadius: 8,
        padding: 12,
      }}
    >
      <div style={{ fontSize: 11, color: "#64748b", textTransform: "uppercase", letterSpacing: 0.5 }}>
        {label}
      </div>
      <div style={{ fontSize: 22, fontWeight: 700, color: color ?? "#0f172a", marginTop: 4 }}>
        {value}
      </div>
    </div>
  );
}
