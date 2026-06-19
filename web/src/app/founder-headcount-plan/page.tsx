import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder headcount plan — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  latest_quarter: string | null;
  total_planned_roles: number | null;
  total_recruiting: number | null;
  total_offer_out: number | null;
  total_hired: number | null;
  total_filled_pct: number | null;
  total_planned_monthly_budget_rupees: number | null;
  total_actual_monthly_budget_rupees: number | null;
  deferred_count: number | null;
  cancelled_count: number | null;
  overdue_target_filled_count: number | null;
  top_role_kind: string | null;
  top_role_kind_count: number | null;
  days_until_quarter_end: number | null;
};

type RoleRow = {
  id: string;
  quarter_label: string;
  role_title: string;
  role_kind: string | null;
  target_count: number | null;
  target_filled_by: string | null;
  budget_monthly_rupees: number | null;
  status: string;
  priority: string;
  justification: string | null;
  days_to_target: number | null;
  is_overdue: boolean | null;
  created_at: string;
};

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return formatNumber(Number(n));
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(1) + "%";
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "₹" + formatNumber(Math.round(Number(n)));
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  return new Date(s).toISOString().slice(0, 10);
}

function statusBadge(status: string): { label: string; bg: string; fg: string } {
  switch (status) {
    case "planned":    return { label: "PLANNED",    bg: "#e0e7ff", fg: "#3730a3" };
    case "recruiting": return { label: "RECRUITING", bg: "#fef3c7", fg: "#92400e" };
    case "offer_out":  return { label: "OFFER OUT",  bg: "#dbeafe", fg: "#1e40af" };
    case "hired":      return { label: "HIRED",      bg: "#d1fae5", fg: "#065f46" };
    case "deferred":   return { label: "DEFERRED",   bg: "#f3e8ff", fg: "#6b21a8" };
    case "cancelled":  return { label: "CANCELLED",  bg: "#fee2e2", fg: "#991b1b" };
    default:           return { label: status.toUpperCase(), bg: "#f1f5f9", fg: "#475569" };
  }
}

function priorityBadge(priority: string): { label: string; bg: string; fg: string } {
  switch (priority) {
    case "p0": return { label: "P0", bg: "#fecaca", fg: "#7f1d1d" };
    case "p1": return { label: "P1", bg: "#fed7aa", fg: "#9a3412" };
    case "p2": return { label: "P2", bg: "#fef08a", fg: "#854d0e" };
    case "p3": return { label: "P3", bg: "#e0f2fe", fg: "#075985" };
    default:   return { label: priority.toUpperCase(), bg: "#f1f5f9", fg: "#475569" };
  }
}

export default async function FounderHeadcountPlanPage({
  searchParams,
}: {
  searchParams?: Promise<{ q?: string }>;
}) {
  await requireFounder();
  const sp = (await searchParams) ?? {};
  const quarter = sp.q && sp.q.trim().length > 0 ? sp.q.trim() : null;

  const supabase = await getSupabaseServerClient();
  const [summaryRes, rolesRes] = await Promise.all([
    supabase.rpc("founder_headcount_plan_summary", { p_quarter: quarter }),
    supabase.rpc("founder_headcount_plan_roles_recent", { p_quarter: quarter, p_limit: 50 }),
  ]);

  const summary: Summary = (summaryRes.data?.[0] ?? {}) as Summary;
  const roles: RoleRow[] = (rolesRes.data ?? []) as RoleRow[];

  const totalBudget = summary.total_planned_monthly_budget_rupees ?? 0;
  const actualBudget = summary.total_actual_monthly_budget_rupees ?? 0;
  const utilizationPct = totalBudget > 0
    ? ((Number(actualBudget) / Number(totalBudget)) * 100).toFixed(1)
    : "0.0";

  return (
    <main style={{ padding: "32px 24px", maxWidth: 1400, margin: "0 auto", fontFamily: "system-ui, sans-serif", color: "#0f172a" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Founder headcount plan</h1>
      <p style={{ color: "#475569", marginTop: 6 }}>
        Quarterly hiring plan · budget tracker · status pipeline planned {"→"} recruiting {"→"} offer_out {"→"} hired · founder-only
      </p>

      <form method="GET" style={{ marginTop: 16, display: "flex", gap: 8, alignItems: "center" }}>
        <label htmlFor="q" style={{ fontSize: 13, color: "#334155", fontWeight: 600 }}>Quarter</label>
        <input
          id="q"
          name="q"
          defaultValue={quarter ?? ""}
          placeholder="e.g. 2026Q3 (blank = latest)"
          style={{ padding: "6px 10px", border: "1px solid #cbd5e1", borderRadius: 6, fontSize: 13, minWidth: 180 }}
        />
        <button type="submit" style={{ padding: "6px 14px", background: "#0f172a", color: "#fff", border: "none", borderRadius: 6, fontSize: 13, fontWeight: 600, cursor: "pointer" }}>Apply</button>
        <span style={{ marginLeft: 12, fontSize: 12, color: "#64748b" }}>
          Showing: <strong style={{ color: "#0f172a" }}>{summary.latest_quarter ?? "—"}</strong>
        </span>
      </form>

      <section style={{ marginTop: 20, padding: "18px 22px", background: "linear-gradient(135deg, #1e293b 0%, #0f172a 100%)", borderRadius: 10, color: "#f1f5f9" }}>
        <div style={{ fontSize: 12, opacity: 0.75, textTransform: "uppercase", letterSpacing: 0.6 }}>Planned monthly burn ({summary.latest_quarter ?? "n/a"})</div>
        <div style={{ fontSize: 32, fontWeight: 700, marginTop: 4 }}>{fmtRupees(totalBudget)}</div>
        <div style={{ fontSize: 13, opacity: 0.8, marginTop: 4 }}>
          Actual hired-burn: <strong style={{ color: "#86efac" }}>{fmtRupees(actualBudget)}</strong> ({utilizationPct}% utilization) · {fmtNum(summary.days_until_quarter_end)} days until quarter end
        </div>
      </section>

      <section style={{ marginTop: 20, display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 12 }}>
        <Card label="Latest quarter"          value={summary.latest_quarter ?? "—"} />
        <Card label="Total planned roles"     value={fmtNum(summary.total_planned_roles)} />
        <Card label="Recruiting"              value={fmtNum(summary.total_recruiting)} />
        <Card label="Offer out"               value={fmtNum(summary.total_offer_out)} />
        <Card label="Hired"                   value={fmtNum(summary.total_hired)} />
        <Card label="Filled %"                value={fmtPct(summary.total_filled_pct)} />
        <Card label="Planned monthly ₹"       value={fmtRupees(summary.total_planned_monthly_budget_rupees)} />
        <Card label="Actual monthly ₹"        value={fmtRupees(summary.total_actual_monthly_budget_rupees)} />
        <Card label="Deferred"                value={fmtNum(summary.deferred_count)} />
        <Card label="Cancelled"               value={fmtNum(summary.cancelled_count)} />
        <Card label="Overdue (past target)"   value={fmtNum(summary.overdue_target_filled_count)} alert />
        <Card label="Top role kind"           value={summary.top_role_kind ?? "—"} />
        <Card label="Top kind count"          value={fmtNum(summary.top_role_kind_count)} />
        <Card label="Days to quarter end"     value={fmtNum(summary.days_until_quarter_end)} />
      </section>

      <section style={{ marginTop: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, margin: 0 }}>Role ledger</h2>
        <p style={{ color: "#64748b", fontSize: 13, marginTop: 4 }}>Top 50 · sorted by priority {"→"} status {"→"} target date</p>
        <div style={{ marginTop: 12, overflowX: "auto", border: "1px solid #e2e8f0", borderRadius: 8 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13, minWidth: 1200 }}>
            <thead>
              <tr style={{ background: "#f8fafc", textAlign: "left" }}>
                <Th>Quarter</Th>
                <Th>Role</Th>
                <Th>Kind</Th>
                <Th>#</Th>
                <Th>Target by</Th>
                <Th>Monthly ₹</Th>
                <Th>Status</Th>
                <Th>Priority</Th>
                <Th>Days to target</Th>
                <Th>Justification</Th>
              </tr>
            </thead>
            <tbody>
              {roles.length === 0 ? (
                <tr><td colSpan={10} style={{ padding: 20, textAlign: "center", color: "#94a3b8" }}>No roles in plan yet.</td></tr>
              ) : roles.map((r) => {
                const sb = statusBadge(r.status);
                const pb = priorityBadge(r.priority);
                return (
                  <tr key={r.id} style={{ borderTop: "1px solid #e2e8f0", background: r.is_overdue ? "#fef2f2" : "transparent" }}>
                    <Td>{r.quarter_label}</Td>
                    <Td><strong>{r.role_title}</strong></Td>
                    <Td>{r.role_kind ?? "—"}</Td>
                    <Td>{fmtNum(r.target_count)}</Td>
                    <Td>{fmtDate(r.target_filled_by)}</Td>
                    <Td>{fmtRupees(r.budget_monthly_rupees)}</Td>
                    <Td><Badge bg={sb.bg} fg={sb.fg} label={sb.label} /></Td>
                    <Td><Badge bg={pb.bg} fg={pb.fg} label={pb.label} /></Td>
                    <Td style={r.is_overdue ? { color: "#b91c1c", fontWeight: 600 } : undefined}>
                      {r.days_to_target === null ? "—" : r.days_to_target + "d"}
                    </Td>
                    <Td style={{ maxWidth: 280, color: "#475569" }}>{r.justification ?? "—"}</Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <p style={{ marginTop: 30, fontSize: 11, color: "#94a3b8" }}>
        r1351 · founder-only · live RPC: founder_headcount_plan_summary + founder_headcount_plan_roles_recent · writes: log_founder_headcount_register_role · log_founder_headcount_status
      </p>
    </main>
  );
}

function Card({ label, value, alert }: { label: string; value: string; alert?: boolean }) {
  return (
    <div style={{ padding: "14px 16px", background: alert ? "#fef2f2" : "#fff", border: "1px solid " + (alert ? "#fecaca" : "#e2e8f0"), borderRadius: 8 }}>
      <div style={{ fontSize: 11, color: alert ? "#b91c1c" : "#64748b", textTransform: "uppercase", letterSpacing: 0.5, fontWeight: 600 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4, color: alert ? "#7f1d1d" : "#0f172a" }}>{value}</div>
    </div>
  );
}

function Th({ children }: { children: React.ReactNode }) {
  return <th style={{ padding: "10px 12px", fontWeight: 600, color: "#475569", fontSize: 12, textTransform: "uppercase", letterSpacing: 0.4 }}>{children}</th>;
}

function Td({ children, style }: { children: React.ReactNode; style?: React.CSSProperties }) {
  return <td style={{ padding: "10px 12px", verticalAlign: "top", ...style }}>{children}</td>;
}

function Badge({ bg, fg, label }: { bg: string; fg: string; label: string }) {
  return (
    <span style={{ display: "inline-block", padding: "2px 8px", borderRadius: 999, background: bg, color: fg, fontSize: 11, fontWeight: 700, letterSpacing: 0.3 }}>
      {label}
    </span>
  );
}
