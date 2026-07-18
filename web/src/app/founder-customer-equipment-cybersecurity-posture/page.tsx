import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Customer equipment cybersecurity posture — r2540" };
export const dynamic = "force-dynamic";

type PostureRow = {
  id: string;
  hospital_user_id: string | null;
  equipment_label: string;
  equipment_kind: string;
  os_kind: string;
  os_patch_level: string | null;
  vulnerability_count: number;
  air_gapped: boolean;
  nabh_compliant: boolean;
  remediation_due_at: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type PlanRow = {
  id: string;
  posture_id: string;
  equipment_label: string | null;
  plan_kind: string;
  planned_at: string | null;
  owner_email: string | null;
  status: string;
  outcome: string;
  notes: string | null;
};

type CriticalRow = {
  id: string;
  equipment_label: string;
  equipment_kind: string;
  os_kind: string;
  vulnerability_count: number;
  air_gapped: boolean;
  nabh_compliant: boolean;
  status: string;
  remediation_due_at: string | null;
  owner_email: string | null;
};

type OsBreakdownRow = {
  os_kind: string;
  equipment_count: number;
  total_vulns: number;
  air_gapped_count: number;
  nabh_compliant_count: number;
  critical_count: number;
};

type TopHospitalRow = {
  hospital_user_id: string | null;
  owner_email: string | null;
  equipment_count: number;
  total_vulns: number;
  critical_count: number;
  nabh_compliant_count: number;
};

type ComplianceSummaryRow = {
  total_equipment: number;
  nabh_compliant: number;
  nabh_noncompliant: number;
  air_gapped_total: number;
  critical_total: number;
  quarantined_total: number;
  total_vulns: number;
  avg_vulns: number;
};

type MonthlyTrendRow = {
  month_label: string;
  plans_count: number;
  done_count: number;
  positive_count: number;
  negative_count: number;
  pending_count: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function statusBadge(status: string): string {
  if (status === "secure") return "text-emerald-700";
  if (status === "at_risk") return "text-amber-700";
  if (status === "critical") return "text-rose-700";
  if (status === "quarantined") return "text-indigo-700";
  return "";
}

function planStatusBadge(status: string): string {
  if (status === "done") return "text-emerald-700";
  if (status === "in_progress") return "text-amber-700";
  if (status === "open") return "text-indigo-700";
  if (status === "dropped") return "text-gray-500";
  return "";
}

function outcomeBadge(outcome: string): string {
  if (outcome === "positive") return "text-emerald-700";
  if (outcome === "negative") return "text-rose-700";
  if (outcome === "neutral") return "text-gray-600";
  if (outcome === "pending") return "text-amber-700";
  return "";
}

export default async function CustomerEquipmentCybersecurityPosturePage() {
  const sb = await getSupabaseServerClient();
  const [
    posturesRes,
    plansRes,
    criticalRes,
    osRes,
    hospitalsRes,
    complianceRes,
    monthlyRes,
  ] = await Promise.all([
    sb.rpc("list_postures_r2540"),
    sb.rpc("list_remediation_plans_r2540"),
    sb.rpc("critical_focus_r2540"),
    sb.rpc("os_kind_breakdown_r2540"),
    sb.rpc("top_vulnerable_hospitals_r2540"),
    sb.rpc("nabh_compliance_summary_r2540"),
    sb.rpc("monthly_remediation_trend_r2540"),
  ]);

  if (posturesRes.error) throw new Error(`list_postures_r2540: ${posturesRes.error.message}`);
  if (plansRes.error) throw new Error(`list_remediation_plans_r2540: ${plansRes.error.message}`);
  if (criticalRes.error) throw new Error(`critical_focus_r2540: ${criticalRes.error.message}`);
  if (osRes.error) throw new Error(`os_kind_breakdown_r2540: ${osRes.error.message}`);
  if (hospitalsRes.error) throw new Error(`top_vulnerable_hospitals_r2540: ${hospitalsRes.error.message}`);
  if (complianceRes.error) throw new Error(`nabh_compliance_summary_r2540: ${complianceRes.error.message}`);
  if (monthlyRes.error) throw new Error(`monthly_remediation_trend_r2540: ${monthlyRes.error.message}`);

  const postures = (posturesRes.data ?? []) as PostureRow[];
  const plans = (plansRes.data ?? []) as PlanRow[];
  const critical = (criticalRes.data ?? []) as CriticalRow[];
  const osBreakdown = (osRes.data ?? []) as OsBreakdownRow[];
  const hospitals = (hospitalsRes.data ?? []) as TopHospitalRow[];
  const compliance = ((complianceRes.data ?? []) as ComplianceSummaryRow[])[0] ?? {
    total_equipment: 0,
    nabh_compliant: 0,
    nabh_noncompliant: 0,
    air_gapped_total: 0,
    critical_total: 0,
    quarantined_total: 0,
    total_vulns: 0,
    avg_vulns: 0,
  };
  const monthly = (monthlyRes.data ?? []) as MonthlyTrendRow[];

  const totalEquip = postures.length;
  const secureCount = postures.filter((p) => p.status === "secure").length;
  const atRiskCount = postures.filter((p) => p.status === "at_risk").length;
  const criticalCount = postures.filter((p) => p.status === "critical").length;
  const quarantinedCount = postures.filter((p) => p.status === "quarantined").length;
  const totalVulns = postures.reduce((acc, p) => acc + Number(p.vulnerability_count ?? 0), 0);

  const postureColumns: Column<PostureRow>[] = [
    { key: "equipment_label", header: "Equipment", render: (r: any) => <span className="font-medium">{r.equipment_label}</span> },
    { key: "equipment_kind", header: "Kind", render: (r: any) => r.equipment_kind },
    { key: "os_kind", header: "OS", render: (r: any) => r.os_kind },
    { key: "os_patch_level", header: "Patch", render: (r: any) => r.os_patch_level ?? "—" },
    { key: "vulnerability_count", header: "Vulns", render: (r: any) => String(r.vulnerability_count) },
    { key: "air_gapped", header: "Air-gap", render: (r: any) => (r.air_gapped ? "yes" : "no") },
    { key: "nabh_compliant", header: "NABH", render: (r: any) => (r.nabh_compliant ? "yes" : "no") },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "remediation_due_at", header: "Due", render: (r: any) => fmtDate(r.remediation_due_at) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const planColumns: Column<PlanRow>[] = [
    { key: "equipment_label", header: "Equipment", render: (r: any) => <span className="font-medium">{r.equipment_label ?? "—"}</span> },
    { key: "plan_kind", header: "Plan", render: (r: any) => r.plan_kind },
    { key: "planned_at", header: "Planned", render: (r: any) => fmtDate(r.planned_at) },
    { key: "status", header: "Status", render: (r: any) => <span className={planStatusBadge(r.status)}>{r.status}</span> },
    { key: "outcome", header: "Outcome", render: (r: any) => <span className={outcomeBadge(r.outcome)}>{r.outcome}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const criticalColumns: Column<CriticalRow>[] = [
    { key: "equipment_label", header: "Equipment", render: (r: any) => <span className="font-medium">{r.equipment_label}</span> },
    { key: "equipment_kind", header: "Kind", render: (r: any) => r.equipment_kind },
    { key: "os_kind", header: "OS", render: (r: any) => r.os_kind },
    { key: "vulnerability_count", header: "Vulns", render: (r: any) => <span className="font-semibold text-rose-700">{String(r.vulnerability_count)}</span> },
    { key: "air_gapped", header: "Air-gap", render: (r: any) => (r.air_gapped ? "yes" : "no") },
    { key: "nabh_compliant", header: "NABH", render: (r: any) => (r.nabh_compliant ? "yes" : "no") },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "remediation_due_at", header: "Due", render: (r: any) => fmtDate(r.remediation_due_at) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const osColumns: Column<OsBreakdownRow>[] = [
    { key: "os_kind", header: "OS", render: (r: any) => <span className="font-medium">{r.os_kind}</span> },
    { key: "equipment_count", header: "Equip", render: (r: any) => String(r.equipment_count) },
    { key: "total_vulns", header: "Vulns", render: (r: any) => String(r.total_vulns) },
    { key: "air_gapped_count", header: "Air-gap", render: (r: any) => String(r.air_gapped_count) },
    { key: "nabh_compliant_count", header: "NABH ok", render: (r: any) => String(r.nabh_compliant_count) },
    { key: "critical_count", header: "Critical", render: (r: any) => <span className="text-rose-700">{String(r.critical_count)}</span> },
  ];

  const hospitalColumns: Column<TopHospitalRow>[] = [
    { key: "owner_email", header: "Owner", render: (r: any) => <span className="font-medium">{r.owner_email ?? "—"}</span> },
    { key: "equipment_count", header: "Equip", render: (r: any) => String(r.equipment_count) },
    { key: "total_vulns", header: "Vulns", render: (r: any) => <span className="font-semibold">{String(r.total_vulns)}</span> },
    { key: "critical_count", header: "Critical", render: (r: any) => <span className="text-rose-700">{String(r.critical_count)}</span> },
    { key: "nabh_compliant_count", header: "NABH ok", render: (r: any) => String(r.nabh_compliant_count) },
  ];

  const monthlyColumns: Column<MonthlyTrendRow>[] = [
    { key: "month_label", header: "Month", render: (r: any) => <span className="font-medium">{r.month_label}</span> },
    { key: "plans_count", header: "Plans", render: (r: any) => String(r.plans_count) },
    { key: "done_count", header: "Done", render: (r: any) => String(r.done_count) },
    { key: "positive_count", header: "Positive", render: (r: any) => <span className="text-emerald-700">{String(r.positive_count)}</span> },
    { key: "negative_count", header: "Negative", render: (r: any) => <span className="text-rose-700">{String(r.negative_count)}</span> },
    { key: "pending_count", header: "Pending", render: (r: any) => <span className="text-amber-700">{String(r.pending_count)}</span> },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Customer equipment cybersecurity posture — r2540</h1>
        <p className="mt-1 text-xs text-gray-500">
          Every customer machine: OS & patch level & vuln count & air-gapped & NABH & remediation plan.
          XP boxes on hospital LAN =&gt; ransomware vector =&gt; patient safety risk. Show the gap, drive remediation.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total equipment</div>
          <div className="mt-1 text-lg font-semibold">{totalEquip}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Secure</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{secureCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">At risk</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{atRiskCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Critical</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{criticalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Quarantined</div>
          <div className="mt-1 text-lg font-semibold text-indigo-700">{quarantinedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total vulns</div>
          <div className="mt-1 text-lg font-semibold">{totalVulns}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">NABH compliant</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{compliance.nabh_compliant}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">NABH non-compliant</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{compliance.nabh_noncompliant}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Air-gapped</div>
          <div className="mt-1 text-lg font-semibold">{compliance.air_gapped_total}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg vulns/unit</div>
          <div className="mt-1 text-lg font-semibold">{Number(compliance.avg_vulns ?? 0).toFixed(2)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total CVEs</div>
          <div className="mt-1 text-lg font-semibold">{compliance.total_vulns}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All equipment cybersecurity posture</h2>
        <p className="text-xs text-gray-500">
          Sorted by status severity then vuln count. Windows XP on hospital LAN =&gt; immediate critical.
        </p>
        <DataTable
          rows={postures}
          columns={postureColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No equipment posture entries yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Critical focus</h2>
        <p className="text-xs text-gray-500">
          Critical & quarantined & vuln-count &gt;= 10 & XP boxes. Top of remediation queue.
        </p>
        <DataTable
          rows={critical}
          columns={criticalColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No critical posture entries."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Remediation plans</h2>
        <p className="text-xs text-gray-500">
          Patch & isolate & firmware & replace & document_only. Track outcome to learn what actually moves posture.
        </p>
        <DataTable
          rows={plans}
          columns={planColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No remediation plans yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">OS-kind breakdown</h2>
        <p className="text-xs text-gray-500">
          Where the vuln mass sits. XP/proprietary cluster =&gt; either air-gap or replace path.
        </p>
        <DataTable
          rows={osBreakdown}
          columns={osColumns}
          rowKey={(r: any, i: number) => `${r.os_kind}-${i}`}
          emptyMessage="No OS breakdown."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top vulnerable hospitals</h2>
        <p className="text-xs text-gray-500">
          Ranked by aggregate vuln count. Founder conversation targets =&gt; AMC upsell on cyber hygiene.
        </p>
        <DataTable
          rows={hospitals}
          columns={hospitalColumns}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
          emptyMessage="No hospital aggregates."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly remediation trend</h2>
        <p className="text-xs text-gray-500">
          Plans booked & done & outcome distribution per month. Watch positive-outcome rate climb.
        </p>
        <DataTable
          rows={monthly}
          columns={monthlyColumns}
          rowKey={(r: any, i: number) => `${r.month_label}-${i}`}
          emptyMessage="No remediation history yet."
        />
      </section>
    </div>
  );
}
