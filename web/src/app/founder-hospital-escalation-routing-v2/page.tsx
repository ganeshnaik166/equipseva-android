import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type Kpi = { label: string; value: string };

function fmtNum(n: any, digits = 0): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return "0";
  return v.toFixed(digits);
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let openRows: any[] = [];
  let breachedRows: any[] = [];
  let byRoute: any[] = [];
  let topHosp: any[] = [];
  let audit: any[] = [];

  try {
    const r = await sb.rpc("founder_hosp_esc_v2_kpis");
    kpis = (r.data as any) ?? {};
  } catch {}
  try {
    const r = await sb.rpc("founder_hosp_esc_v2_open");
    openRows = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc("founder_hosp_esc_v2_breached");
    breachedRows = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc("founder_hosp_esc_v2_by_route");
    byRoute = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc("founder_hosp_esc_v2_top_hospitals");
    topHosp = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc("founder_hosp_esc_v2_recent_audit");
    audit = (r.data as any[]) ?? [];
  } catch {}

  const cards: Kpi[] = [
    { label: "Open total",         value: fmtNum(kpis.open_total) },
    { label: "Open P0",            value: fmtNum(kpis.open_p0) },
    { label: "Open P1",            value: fmtNum(kpis.open_p1) },
    { label: "Open P2",            value: fmtNum(kpis.open_p2) },
    { label: "Open P3",            value: fmtNum(kpis.open_p3) },
    { label: "Route founder",      value: fmtNum(kpis.route_founder) },
    { label: "Route CTO",          value: fmtNum(kpis.route_cto) },
    { label: "Route sales",        value: fmtNum(kpis.route_sales) },
    { label: "Route ops",          value: fmtNum(kpis.route_ops) },
    { label: "Breached open",      value: fmtNum(kpis.breached_open) },
    { label: "Auto-escalated",     value: fmtNum(kpis.auto_escalated_open) },
    { label: "Opened 7d",          value: fmtNum(kpis.opened_7d) },
    { label: "Resolved 7d",        value: fmtNum(kpis.resolved_7d) },
    { label: "Avg ack min 7d",     value: fmtNum(kpis.avg_ack_minutes_7d, 1) },
    { label: "Avg resolve hr 7d",  value: fmtNum(kpis.avg_resolve_hours_7d, 1) },
    { label: "Breach rate 7d %",   value: fmtNum(kpis.breach_rate_7d, 1) },
  ];

  const openCols: Column<any>[] = [
    { key: "hospital_name",            header: "Hospital",   render: (r: any) => r.hospital_name ?? "—" },
    { key: "severity",                 header: "Sev",        render: (r: any) => r.severity ?? "—" },
    { key: "route_to",                 header: "Route",      render: (r: any) => r.route_to ?? "—" },
    { key: "amc_tier_at_open",         header: "AMC tier",   render: (r: any) => r.amc_tier_at_open ?? "—" },
    { key: "prior_escalations_count",  header: "Prior",      render: (r: any) => fmtNum(r.prior_escalations_count) },
    { key: "sla_minutes",              header: "SLA min",    render: (r: any) => fmtNum(r.sla_minutes) },
    { key: "age_minutes",              header: "Age min",    render: (r: any) => fmtNum(r.age_minutes, 1) },
    { key: "breached",                 header: "Breached",   render: (r: any) => (r.breached ? "yes" : "no") },
  ];

  const breachedCols: Column<any>[] = [
    { key: "hospital_name",     header: "Hospital",       render: (r: any) => r.hospital_name ?? "—" },
    { key: "severity",          header: "Sev",            render: (r: any) => r.severity ?? "—" },
    { key: "route_to",          header: "Route",          render: (r: any) => r.route_to ?? "—" },
    { key: "sla_minutes",       header: "SLA min",        render: (r: any) => fmtNum(r.sla_minutes) },
    { key: "minutes_over_sla",  header: "Over SLA min",   render: (r: any) => fmtNum(r.minutes_over_sla, 1) },
    { key: "auto_escalated_to", header: "Auto to",        render: (r: any) => r.auto_escalated_to ?? "—" },
    { key: "breached_at",       header: "Breached at",    render: (r: any) => r.breached_at ?? "—" },
  ];

  const byRouteCols: Column<any>[] = [
    { key: "route_to",          header: "Route",           render: (r: any) => r.route_to ?? "—" },
    { key: "open_count",        header: "Open",            render: (r: any) => fmtNum(r.open_count) },
    { key: "breached_count",    header: "Breached",        render: (r: any) => fmtNum(r.breached_count) },
    { key: "avg_ack_minutes",   header: "Avg ack min",     render: (r: any) => fmtNum(r.avg_ack_minutes, 1) },
    { key: "avg_resolve_hours", header: "Avg resolve hr",  render: (r: any) => fmtNum(r.avg_resolve_hours, 1) },
  ];

  const topHospCols: Column<any>[] = [
    { key: "hospital_name",     header: "Hospital",        render: (r: any) => r.hospital_name ?? "—" },
    { key: "escalations_30d",   header: "Escalations 30d", render: (r: any) => fmtNum(r.escalations_30d) },
    { key: "breach_count",      header: "Breaches",        render: (r: any) => fmtNum(r.breach_count) },
    { key: "last_opened_at",    header: "Last opened",     render: (r: any) => r.last_opened_at ?? "—" },
  ];

  const auditCols: Column<any>[] = [
    { key: "created_at",   header: "When",   render: (r: any) => r.created_at ?? "—" },
    { key: "action",       header: "Action", render: (r: any) => r.action ?? "—" },
    { key: "actor_email",  header: "Actor",  render: (r: any) => r.actor_email ?? "—" },
    { key: "route_id",     header: "Route",  render: (r: any) => r.route_id ?? "—" },
  ];

  return (
    <main style={{ padding: 24, fontFamily: "system-ui, sans-serif" }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital escalation routing v2
      </h1>
      <p style={{ color: "#555", marginBottom: 16 }}>
        Severity + AMC tier + history-based routing. Per-route SLA. Auto-escalates on breach.
      </p>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(4, minmax(0, 1fr))",
          gap: 12,
          marginBottom: 24,
        }}
      >
        {cards.map((k) => (
          <div
            key={k.label}
            style={{
              border: "1px solid #e5e7eb",
              borderRadius: 8,
              padding: 12,
              background: "#fff",
            }}
          >
            <div style={{ fontSize: 11, color: "#666", textTransform: "uppercase" }}>
              {k.label}
            </div>
            <div style={{ fontSize: 22, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: "12px 0 8px" }}>Open routes</h2>
      <DataTable rowKey={(r: any) => r.id} rows={openRows} columns={openCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: "24px 0 8px" }}>Breached</h2>
      <DataTable rowKey={(r: any) => r.id} rows={breachedRows} columns={breachedCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: "24px 0 8px" }}>By route</h2>
      <DataTable rowKey={(r: any) => r.route_to} rows={byRoute} columns={byRouteCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: "24px 0 8px" }}>Top hospitals 30d</h2>
      <DataTable rowKey={(r: any) => r.hospital_org_id} rows={topHosp} columns={topHospCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: "24px 0 8px" }}>Recent audit</h2>
      <DataTable rowKey={(r: any) => r.id} rows={audit} columns={auditCols} />
    </main>
  );
}
