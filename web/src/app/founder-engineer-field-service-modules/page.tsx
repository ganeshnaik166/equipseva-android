import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  modules_total: number;
  modules_active: number;
  modules_inactive: number;
  module_kinds_distinct: number;
  runs_total: number;
  runs_started: number;
  runs_in_progress: number;
  runs_completed: number;
  runs_aborted: number;
  runs_synced: number;
  runs_24h: number;
  runs_7d: number;
  engineers_active_30d: number;
  completion_rate_pct: number;
};

type ModuleRow = {
  id: string;
  module_label: string;
  module_kind: string;
  required_steps_count: number;
  is_active: boolean;
  mobile_min_version: string | null;
  runs_total: number;
  runs_completed: number;
  created_at: string;
};

type RunRow = {
  id: string;
  engineer_user_id: string;
  module_label: string;
  module_kind: string;
  status: string;
  steps_completed: number;
  required_steps_count: number;
  repair_job_id: string | null;
  started_at: string;
  completed_at: string | null;
  created_at: string;
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [summaryRes, modulesRes, runsRes] = await Promise.all([
    sb.rpc("founder_field_service_modules_summary"),
    sb.rpc("founder_field_service_modules_recent", { p_limit: 60 }),
    sb.rpc("founder_field_service_runs_recent", { p_limit: 80 }),
  ]);

  const s = (summaryRes.data ?? {}) as Partial<Summary>;
  const modules = (modulesRes.data ?? []) as ModuleRow[];
  const runs = (runsRes.data ?? []) as RunRow[];

  const cards: Array<{ label: string; value: string; tone?: string }> = [
    { label: "Modules total", value: formatNumber(s.modules_total ?? 0) },
    { label: "Active", value: formatNumber(s.modules_active ?? 0), tone: "good" },
    { label: "Inactive", value: formatNumber(s.modules_inactive ?? 0), tone: "muted" },
    { label: "Distinct kinds", value: formatNumber(s.module_kinds_distinct ?? 0) },
    { label: "Runs total", value: formatNumber(s.runs_total ?? 0) },
    { label: "Started", value: formatNumber(s.runs_started ?? 0) },
    { label: "In progress", value: formatNumber(s.runs_in_progress ?? 0), tone: "warn" },
    { label: "Completed", value: formatNumber(s.runs_completed ?? 0), tone: "good" },
    { label: "Aborted", value: formatNumber(s.runs_aborted ?? 0), tone: "bad" },
    { label: "Synced", value: formatNumber(s.runs_synced ?? 0) },
    { label: "Runs 24h", value: formatNumber(s.runs_24h ?? 0) },
    { label: "Runs 7d", value: formatNumber(s.runs_7d ?? 0) },
    { label: "Engineers 30d", value: formatNumber(s.engineers_active_30d ?? 0) },
    { label: "Completion %", value: `${formatNumber(s.completion_rate_pct ?? 0)}%`, tone: "good" },
  ];

  return (
    <main style={{ padding: 24, fontFamily: "ui-sans-serif, system-ui, sans-serif", maxWidth: 1280, margin: "0 auto" }}>
      <header style={{ marginBottom: 24 }}>
        <div style={{ fontSize: 12, color: "#64748b", textTransform: "uppercase", letterSpacing: 1 }}>r1412 - founder</div>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: "4px 0" }}>Engineer Field Service Modules</h1>
        <p style={{ color: "#475569", margin: 0 }}>
          Mobile App v0.6 module registry: catalog, run telemetry, completion rates.
        </p>
      </header>

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", gap: 12, marginBottom: 28 }}>
        {cards.map((c) => (
          <div
            key={c.label}
            style={{
              border: "1px solid #e2e8f0",
              borderRadius: 10,
              padding: 14,
              background: "#fff",
              borderLeft: `4px solid ${
                c.tone === "good" ? "#10b981"
                : c.tone === "warn" ? "#f59e0b"
                : c.tone === "bad" ? "#ef4444"
                : c.tone === "muted" ? "#94a3b8"
                : "#6366f1"
              }`,
            }}
          >
            <div style={{ fontSize: 11, color: "#64748b", textTransform: "uppercase", letterSpacing: 0.5 }}>{c.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4, color: "#0f172a" }}>{c.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Module catalog ({modules.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e2e8f0", borderRadius: 10, background: "#fff" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f8fafc" }}>
              <tr>
                <th style={th}>Label</th>
                <th style={th}>Kind</th>
                <th style={thNum}>Steps</th>
                <th style={th}>Active</th>
                <th style={th}>Min ver</th>
                <th style={thNum}>Runs</th>
                <th style={thNum}>Done</th>
                <th style={th}>Created</th>
              </tr>
            </thead>
            <tbody>
              {modules.length === 0 ? (
                <tr><td colSpan={8} style={{ padding: 16, textAlign: "center", color: "#94a3b8" }}>No modules registered yet.</td></tr>
              ) : modules.map((m) => (
                <tr key={m.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={td}><span style={{ fontWeight: 600 }}>{m.module_label}</span></td>
                  <td style={td}><code style={kindBadge}>{m.module_kind}</code></td>
                  <td style={tdNum}>{m.required_steps_count}</td>
                  <td style={td}>{m.is_active ? <span style={{ color: "#10b981" }}>active</span> : <span style={{ color: "#94a3b8" }}>inactive</span>}</td>
                  <td style={td}>{m.mobile_min_version ?? <span style={{ color: "#cbd5e1" }}>-</span>}</td>
                  <td style={tdNum}>{formatNumber(m.runs_total)}</td>
                  <td style={tdNum}>{formatNumber(m.runs_completed)}</td>
                  <td style={{ ...td, color: "#64748b", fontSize: 12 }}>{new Date(m.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent runs ({runs.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e2e8f0", borderRadius: 10, background: "#fff" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f8fafc" }}>
              <tr>
                <th style={th}>Module</th>
                <th style={th}>Kind</th>
                <th style={th}>Status</th>
                <th style={thNum}>Steps</th>
                <th style={th}>Started</th>
                <th style={th}>Completed</th>
                <th style={th}>Job</th>
              </tr>
            </thead>
            <tbody>
              {runs.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, textAlign: "center", color: "#94a3b8" }}>No runs logged yet.</td></tr>
              ) : runs.map((r) => (
                <tr key={r.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={td}><span style={{ fontWeight: 600 }}>{r.module_label}</span></td>
                  <td style={td}><code style={kindBadge}>{r.module_kind}</code></td>
                  <td style={td}>
                    <span style={statusBadge(r.status)}>{r.status}</span>
                  </td>
                  <td style={tdNum}>{r.steps_completed}/{r.required_steps_count}</td>
                  <td style={{ ...td, color: "#64748b", fontSize: 12 }}>{new Date(r.started_at).toLocaleString()}</td>
                  <td style={{ ...td, color: "#64748b", fontSize: 12 }}>{r.completed_at ? new Date(r.completed_at).toLocaleString() : <span style={{ color: "#cbd5e1" }}>-</span>}</td>
                  <td style={{ ...td, fontSize: 11, fontFamily: "ui-monospace, monospace", color: "#64748b" }}>{r.repair_job_id ? r.repair_job_id.slice(0, 8) : <span style={{ color: "#cbd5e1" }}>-</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}

const th: React.CSSProperties = { textAlign: "left", padding: "8px 12px", fontSize: 11, color: "#64748b", textTransform: "uppercase", letterSpacing: 0.5, fontWeight: 600 };
const thNum: React.CSSProperties = { ...th, textAlign: "right" };
const td: React.CSSProperties = { padding: "8px 12px", color: "#0f172a", verticalAlign: "top" };
const tdNum: React.CSSProperties = { ...td, textAlign: "right", fontVariantNumeric: "tabular-nums" };
const kindBadge: React.CSSProperties = { fontSize: 11, padding: "2px 6px", borderRadius: 4, background: "#eef2ff", color: "#4338ca" };

function statusBadge(status: string): React.CSSProperties {
  const map: Record<string, { bg: string; fg: string }> = {
    started: { bg: "#fef3c7", fg: "#92400e" },
    in_progress: { bg: "#dbeafe", fg: "#1e40af" },
    completed: { bg: "#d1fae5", fg: "#065f46" },
    aborted: { bg: "#fee2e2", fg: "#991b1b" },
    synced: { bg: "#e0e7ff", fg: "#3730a3" },
  };
  const c = map[status] ?? { bg: "#f1f5f9", fg: "#475569" };
  return { fontSize: 11, padding: "2px 8px", borderRadius: 12, background: c.bg, color: c.fg, fontWeight: 600 };
}
