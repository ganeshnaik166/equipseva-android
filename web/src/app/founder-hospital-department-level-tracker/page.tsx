import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital department-level tracker — r1759" };
export const dynamic = "force-dynamic";

type DepartmentRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string;
  hospital_city: string | null;
  department_name: string;
  department_type: string;
  equipment_count: number;
  monthly_service_revenue_rupees: number;
  status: string;
  last_audited_at: string | null;
  open_action_count: number;
  created_at: string;
};

type ActionRow = {
  id: string;
  department_id: string;
  department_name: string;
  hospital_name: string;
  action_text: string;
  owner_email: string | null;
  due_date: string | null;
  status: string;
  days_until_due: number | null;
  created_at: string;
};

type RevenueSummaryRow = {
  department_type: string;
  dept_count: number;
  total_equipment: number;
  total_monthly_revenue_rupees: number;
  avg_monthly_revenue_rupees: number;
  active_count: number;
  inactive_count: number;
};

type AuditNeededRow = {
  id: string;
  hospital_name: string;
  department_name: string;
  department_type: string;
  last_audited_at: string | null;
  days_since_audit: number | null;
  equipment_count: number;
  monthly_service_revenue_rupees: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "Rs. " + n.toLocaleString("en-IN");
}

function typeLabel(t: string): string {
  const map: Record<string, string> = {
    opd: "OPD",
    icu: "ICU",
    ed: "ED",
    ot: "OT",
    lab: "Lab",
    radiology: "Radiology",
    dialysis: "Dialysis",
  };
  return map[t] ?? t;
}

function statusColor(status: string): string {
  if (status === "active" || status === "done") return "text-emerald-700";
  if (status === "open") return "text-amber-700";
  if (status === "inactive" || status === "dropped") return "text-gray-500";
  return "";
}

export default async function FounderHospitalDepartmentLevelTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [deptRes, actionsRes, summaryRes, auditRes] = await Promise.all([
    sb.rpc("list_departments_r1759"),
    sb.rpc("list_actions_r1759"),
    sb.rpc("dept_revenue_summary_r1759"),
    sb.rpc("departments_needing_audit_r1759"),
  ]);

  if (deptRes.error) throw new Error(`list_departments_r1759: ${deptRes.error.message}`);
  if (actionsRes.error) throw new Error(`list_actions_r1759: ${actionsRes.error.message}`);
  if (summaryRes.error) throw new Error(`dept_revenue_summary_r1759: ${summaryRes.error.message}`);
  if (auditRes.error) throw new Error(`departments_needing_audit_r1759: ${auditRes.error.message}`);

  const departments = (deptRes.data ?? []) as DepartmentRow[];
  const actions = (actionsRes.data ?? []) as ActionRow[];
  const revenueSummary = (summaryRes.data ?? []) as RevenueSummaryRow[];
  const auditNeeded = (auditRes.data ?? []) as AuditNeededRow[];

  const totalDepartments = departments.length;
  const activeDepartments = departments.filter((d) => d.status === "active").length;
  const totalEquipment = departments.reduce((sum, d) => sum + (d.equipment_count ?? 0), 0);
  const totalMonthlyRevenue = departments.reduce(
    (sum, d) => sum + (d.monthly_service_revenue_rupees ?? 0),
    0,
  );
  const openActionsCount = actions.filter((a) => a.status === "open").length;
  const overdueActions = actions.filter(
    (a) => a.status === "open" && a.days_until_due !== null && a.days_until_due < 0,
  ).length;
  const auditNeededCount = auditNeeded.length;

  const departmentColumns: Column<DepartmentRow>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_name}</span> },
    { key: "hospital_city", header: "City", render: (r: any) => r.hospital_city ?? "—" },
    { key: "department_name", header: "Department", render: (r: any) => r.department_name },
    { key: "department_type", header: "Type", render: (r: any) => typeLabel(r.department_type) },
    { key: "equipment_count", header: "Equipment", render: (r: any) => String(r.equipment_count ?? 0) },
    { key: "monthly_service_revenue_rupees", header: "Monthly revenue", render: (r: any) => fmtRupees(r.monthly_service_revenue_rupees) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusColor(r.status)}>{r.status}</span> },
    { key: "open_action_count", header: "Open actions", render: (r: any) => String(r.open_action_count ?? 0) },
    { key: "last_audited_at", header: "Last audited", render: (r: any) => fmtDate(r.last_audited_at) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name },
    { key: "department_name", header: "Department", render: (r: any) => r.department_name },
    { key: "action_text", header: "Action", render: (r: any) => <span className="font-medium">{r.action_text}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "due_date", header: "Due", render: (r: any) => fmtDate(r.due_date) },
    {
      key: "days_until_due",
      header: "Days until due",
      render: (r: any) => {
        if (r.days_until_due === null || r.days_until_due === undefined) return "—";
        const d = r.days_until_due as number;
        if (d < 0) return <span className="text-red-700">overdue {Math.abs(d)}d</span>;
        if (d === 0) return <span className="text-amber-700">due today</span>;
        return `${d}d`;
      },
    },
    { key: "status", header: "Status", render: (r: any) => <span className={statusColor(r.status)}>{r.status}</span> },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const revenueColumns: Column<RevenueSummaryRow>[] = [
    { key: "department_type", header: "Type", render: (r: any) => <span className="font-medium">{typeLabel(r.department_type)}</span> },
    { key: "dept_count", header: "Departments", render: (r: any) => String(r.dept_count ?? 0) },
    { key: "active_count", header: "Active", render: (r: any) => String(r.active_count ?? 0) },
    { key: "inactive_count", header: "Inactive", render: (r: any) => String(r.inactive_count ?? 0) },
    { key: "total_equipment", header: "Equipment", render: (r: any) => String(r.total_equipment ?? 0) },
    { key: "total_monthly_revenue_rupees", header: "Total monthly revenue", render: (r: any) => fmtRupees(r.total_monthly_revenue_rupees) },
    { key: "avg_monthly_revenue_rupees", header: "Avg monthly revenue", render: (r: any) => fmtRupees(r.avg_monthly_revenue_rupees) },
  ];

  const auditColumns: Column<AuditNeededRow>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_name}</span> },
    { key: "department_name", header: "Department", render: (r: any) => r.department_name },
    { key: "department_type", header: "Type", render: (r: any) => typeLabel(r.department_type) },
    {
      key: "last_audited_at",
      header: "Last audited",
      render: (r: any) => (r.last_audited_at ? fmtDate(r.last_audited_at) : <span className="text-red-700">never</span>),
    },
    {
      key: "days_since_audit",
      header: "Days since audit",
      render: (r: any) => {
        if (r.days_since_audit === null || r.days_since_audit === undefined) {
          return <span className="text-red-700">never audited</span>;
        }
        const d = r.days_since_audit as number;
        if (d >= 180) return <span className="text-red-700">{d}d</span>;
        if (d >= 120) return <span className="text-amber-700">{d}d</span>;
        return `${d}d`;
      },
    },
    { key: "equipment_count", header: "Equipment", render: (r: any) => String(r.equipment_count ?? 0) },
    { key: "monthly_service_revenue_rupees", header: "Monthly revenue", render: (r: any) => fmtRupees(r.monthly_service_revenue_rupees) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10">
      <header className="mb-8">
        <h1 className="text-3xl font-semibold tracking-tight">Hospital department-level tracker</h1>
        <p className="mt-2 text-sm text-gray-600">
          Per-hospital breakdown of departments (OPD, ICU, ED, OT, lab, radiology, dialysis) with equipment counts,
          monthly service revenue, action items, and audit cadence. Departments not audited in &gt;=90 days surface in
          the audit queue.
        </p>
      </header>

      <section className="mb-10">
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
          <div className="rounded-lg border border-gray-200 p-4">
            <div className="text-xs uppercase tracking-wide text-gray-500">Total departments</div>
            <div className="mt-1 text-2xl font-semibold">{totalDepartments}</div>
            <div className="mt-1 text-xs text-gray-500">{activeDepartments} active</div>
          </div>
          <div className="rounded-lg border border-gray-200 p-4">
            <div className="text-xs uppercase tracking-wide text-gray-500">Total equipment</div>
            <div className="mt-1 text-2xl font-semibold">{totalEquipment}</div>
            <div className="mt-1 text-xs text-gray-500">across all departments</div>
          </div>
          <div className="rounded-lg border border-gray-200 p-4">
            <div className="text-xs uppercase tracking-wide text-gray-500">Monthly revenue</div>
            <div className="mt-1 text-2xl font-semibold">{fmtRupees(totalMonthlyRevenue)}</div>
            <div className="mt-1 text-xs text-gray-500">sum of all departments</div>
          </div>
          <div className="rounded-lg border border-gray-200 p-4">
            <div className="text-xs uppercase tracking-wide text-gray-500">Open actions</div>
            <div className="mt-1 text-2xl font-semibold">{openActionsCount}</div>
            <div className="mt-1 text-xs text-gray-500">
              {overdueActions > 0 ? (
                <span className="text-red-700">{overdueActions} overdue</span>
              ) : (
                <span>none overdue</span>
              )}
              {" "}· {auditNeededCount} need audit
            </div>
          </div>
        </div>
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Revenue summary by department type</h2>
        <p className="mb-3 text-sm text-gray-600">
          Aggregate equipment and monthly service revenue grouped by department type. Ordered by total monthly revenue
          descending so the highest-value categories surface first.
        </p>
        <DataTable
          rows={revenueSummary}
          columns={revenueColumns}
          rowKey={(r: any, i: number) => String(r?.department_type ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">All departments ({departments.length})</h2>
        <p className="mb-3 text-sm text-gray-600">
          Every hospital department on file, newest first. Open-action count and last-audit date flag departments
          that need attention before they slip.
        </p>
        <DataTable
          rows={departments}
          columns={departmentColumns}
          rowKey={(r: any, i: number) => String(r?.id ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Action items ({actions.length})</h2>
        <p className="mb-3 text-sm text-gray-600">
          Per-department action items sorted open-first then by due date. Items overdue by &gt;=1 day render in red so
          the founder can chase the assigned owner.
        </p>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r?.id ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Departments needing audit ({auditNeeded.length})</h2>
        <p className="mb-3 text-sm text-gray-600">
          Active departments not audited in the last 90 days. Rows aged &gt;=180 days render in red; &gt;=120 days in
          amber. Never-audited departments sort to the top.
        </p>
        <DataTable
          rows={auditNeeded}
          columns={auditColumns}
          rowKey={(r: any, i: number) => String(r?.id ?? i)}
        />
      </section>
    </main>
  );
}
