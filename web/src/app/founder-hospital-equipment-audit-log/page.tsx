import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type AuditRow = {
  id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  audit_date: string;
  auditor_email: string;
  total_units: number;
  working_units: number;
  non_working_units: number;
  missing_units: number;
  summary_md: string | null;
  created_at: string;
};

type SummaryRow = {
  hospital_user_id: string;
  hospital_email: string | null;
  total_audits: number;
  last_audit_date: string | null;
  avg_working_pct: number | null;
  total_open_findings: number;
  total_p0_findings: number;
};

type FindingRow = {
  id: string;
  audit_id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  audit_date: string;
  finding_text: string;
  severity: string;
  action_required: string | null;
  action_owner_email: string | null;
  status: string;
  age_days: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, summaryRes, findingsRes] = await Promise.all([
    sb.rpc("list_audits_r1667"),
    sb.rpc("audit_summary_by_hospital_r1667"),
    sb.rpc("high_severity_open_findings_r1667"),
  ]);

  const audits: AuditRow[] = (auditsRes.data as AuditRow[]) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[]) ?? [];
  const findings: FindingRow[] = (findingsRes.data as FindingRow[]) ?? [];

  const totalAudits = audits.length;
  const totalUnits = audits.reduce((s, a) => s + (a.total_units ?? 0), 0);
  const totalWorking = audits.reduce((s, a) => s + (a.working_units ?? 0), 0);
  const totalMissing = audits.reduce((s, a) => s + (a.missing_units ?? 0), 0);
  const workingPct = totalUnits > 0 ? Math.round((totalWorking / totalUnits) * 1000) / 10 : 0;
  const openP0 = findings.filter((f) => f.severity === "p0").length;
  const openP1 = findings.filter((f) => f.severity === "p1").length;

  const auditCols: Column<AuditRow>[] = [
    { key: "audit_date", header: "Date", render: (r) => <span>{r.audit_date}</span> },
    { key: "hospital_email", header: "Hospital", render: (r) => <span>{r.hospital_email ?? "—"}</span> },
    { key: "auditor_email", header: "Auditor", render: (r) => <span>{r.auditor_email}</span> },
    { key: "total_units", header: "Total", render: (r) => <span>{r.total_units}</span> },
    {
      key: "working_units",
      header: "Working",
      render: (r) => (
        <span style={{ color: "#0a7d3b", fontWeight: 600 }}>{r.working_units}</span>
      ),
    },
    {
      key: "non_working_units",
      header: "Non-working",
      render: (r) => (
        <span style={{ color: "#b45309" }}>{r.non_working_units}</span>
      ),
    },
    {
      key: "missing_units",
      header: "Missing",
      render: (r) => (
        <span style={{ color: r.missing_units > 0 ? "#b91c1c" : "#6b7280" }}>{r.missing_units}</span>
      ),
    },
    {
      key: "working_pct",
      header: "Working %",
      render: (r) => {
        const pct = r.total_units > 0 ? Math.round((r.working_units / r.total_units) * 1000) / 10 : 0;
        return <span>{pct}%</span>;
      },
    },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r) => <span>{r.hospital_email ?? "—"}</span> },
    { key: "total_audits", header: "Audits", render: (r) => <span>{r.total_audits}</span> },
    { key: "last_audit_date", header: "Last Audit", render: (r) => <span>{r.last_audit_date ?? "—"}</span> },
    {
      key: "avg_working_pct",
      header: "Avg Working %",
      render: (r) => <span>{r.avg_working_pct ?? 0}%</span>,
    },
    {
      key: "total_open_findings",
      header: "Open Findings",
      render: (r) => (
        <span style={{ fontWeight: r.total_open_findings > 0 ? 600 : 400 }}>
          {r.total_open_findings}
        </span>
      ),
    },
    {
      key: "total_p0_findings",
      header: "P0 Open",
      render: (r) => (
        <span style={{ color: r.total_p0_findings > 0 ? "#b91c1c" : "#6b7280", fontWeight: 700 }}>
          {r.total_p0_findings}
        </span>
      ),
    },
  ];

  const findingCols: Column<FindingRow>[] = [
    {
      key: "severity",
      header: "Sev",
      render: (r) => {
        const color = r.severity === "p0" ? "#b91c1c" : "#b45309";
        return (
          <span
            style={{
              background: color,
              color: "white",
              padding: "2px 8px",
              borderRadius: 4,
              fontWeight: 700,
              fontSize: 12,
            }}
          >
            {r.severity.toUpperCase()}
          </span>
        );
      },
    },
    { key: "hospital_email", header: "Hospital", render: (r) => <span>{r.hospital_email ?? "—"}</span> },
    { key: "audit_date", header: "Audit Date", render: (r) => <span>{r.audit_date}</span> },
    { key: "finding_text", header: "Finding", render: (r) => <span>{r.finding_text}</span> },
    {
      key: "action_required",
      header: "Action Required",
      render: (r) => <span>{r.action_required ?? "—"}</span>,
    },
    {
      key: "action_owner_email",
      header: "Owner",
      render: (r) => <span>{r.action_owner_email ?? "—"}</span>,
    },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span
          style={{
            background: r.status === "open" ? "#fee2e2" : "#fef3c7",
            color: r.status === "open" ? "#991b1b" : "#92400e",
            padding: "2px 8px",
            borderRadius: 4,
            fontWeight: 600,
            fontSize: 12,
          }}
        >
          {r.status}
        </span>
      ),
    },
    {
      key: "age_days",
      header: "Age (d)",
      render: (r) => (
        <span style={{ color: r.age_days > 14 ? "#b91c1c" : "#374151", fontWeight: r.age_days > 14 ? 700 : 400 }}>
          {r.age_days}
        </span>
      ),
    },
  ];

  return (
    <div style={{ padding: 24, fontFamily: "system-ui, -apple-system, sans-serif", maxWidth: 1400 }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Hospital Equipment Audit Log
      </h1>
      <p style={{ color: "#6b7280", marginBottom: 24 }}>
        Per-hospital periodic equipment audit results, findings, and remediation tracking.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary KPIs</h2>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
            gap: 12,
          }}
        >
          <Kpi label="Total Audits" value={totalAudits.toString()} />
          <Kpi label="Total Units Audited" value={totalUnits.toString()} />
          <Kpi label="Working %" value={`${workingPct}%`} accent="#0a7d3b" />
          <Kpi label="Missing Units" value={totalMissing.toString()} accent={totalMissing > 0 ? "#b91c1c" : "#6b7280"} />
          <Kpi label="P0 Open Findings" value={openP0.toString()} accent={openP0 > 0 ? "#b91c1c" : "#6b7280"} />
          <Kpi label="P1 Open Findings" value={openP1.toString()} accent={openP1 > 0 ? "#b45309" : "#6b7280"} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Per-Hospital Summary ({summary.length})
        </h2>
        <DataTable<SummaryRow>
          rows={summary}
          columns={summaryCols}
          rowKey={(r, i) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          High-Severity Open Findings ({findings.length})
        </h2>
        <DataTable<FindingRow>
          rows={findings}
          columns={findingCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Audits ({audits.length})
        </h2>
        <DataTable<AuditRow>
          rows={audits}
          columns={auditCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value, accent }: { label: string; value: string; accent?: string }) {
  return (
    <div
      style={{
        background: "#fff",
        border: "1px solid #e5e7eb",
        borderRadius: 8,
        padding: 16,
      }}
    >
      <div style={{ fontSize: 12, color: "#6b7280", textTransform: "uppercase", letterSpacing: 0.5 }}>
        {label}
      </div>
      <div style={{ fontSize: 24, fontWeight: 700, color: accent ?? "#111827", marginTop: 4 }}>
        {value}
      </div>
    </div>
  );
}
