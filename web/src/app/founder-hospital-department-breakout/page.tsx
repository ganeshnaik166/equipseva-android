import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Hospital department breakout — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_departments: number;
  top_dept_kind: string | null;
  top_dept_kind_count: number;
  hospitals_with_departments: number;
  avg_departments_per_hospital: number;
  total_equipment_across_depts: number;
  total_visits_30d: number;
  top_dept_by_visits: string | null;
  top_dept_by_visits_count: number;
  depts_with_no_visits_30d: number;
  depts_idle_over_60d: number;
  unique_engineers_assigned: number;
  max_equipment_in_one_dept: number;
  avg_equipment_per_dept: number;
  generated_at: string;
};

type RecentRow = {
  id: string;
  hospital_user_id: string;
  department_label: string;
  department_kind: string;
  total_equipment_count: number;
  total_visits_30d: number;
  last_visit_at: string | null;
  department_lead_name: string | null;
  primary_engineer_id: string | null;
  created_at: string;
  updated_at: string;
};

type ByKindRow = {
  department_kind: string;
  dept_count: number;
  hospitals_count: number;
  total_equipment: number;
  total_visits_30d: number;
  avg_equipment_per_dept: number;
  avg_visits_per_dept: number;
  idle_over_60d_count: number;
};

type TopRevenueRow = {
  rank_pos: number;
  id: string;
  department_label: string;
  department_kind: string;
  hospital_user_id: string;
  total_equipment_count: number;
  total_visits_30d: number;
  load_score: number;
  last_visit_at: string | null;
};

function Card({ title, val, sub, danger, ok, warn }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; warn?: boolean }) {
  const color = danger ? "text-[var(--color-danger)]" : warn ? "text-[var(--color-warn)]" : ok ? "text-[var(--color-ok)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${color}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function KindBadge({ k }: { k: string }) {
  const v = (k ?? "").toLowerCase();
  const cls =
    v === "icu" || v === "emergency"
      ? "bg-red-100 text-[var(--color-danger)]"
      : v === "ot" || v === "radiology"
        ? "bg-yellow-100 text-[var(--color-warn)]"
        : v === "outpatient" || v === "pharmacy" || v === "admin"
          ? "bg-gray-100 text-[var(--color-muted)]"
          : "bg-green-100 text-[var(--color-ok)]";
  return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{k ?? "—"}</span>;
}

export default async function FounderHospitalDepartmentBreakoutPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, recRes, kindRes, topRes] = await Promise.all([
    supabase.rpc("founder_hospital_department_breakout_summary"),
    supabase.rpc("founder_hospital_department_breakout_recent", { p_limit: 40 }),
    supabase.rpc("founder_hospital_department_breakout_by_kind"),
    supabase.rpc("founder_hospital_department_top_revenue", { p_limit: 20 }),
  ]);
  if (sumRes.error)  throw new Error(`breakout_summary: ${sumRes.error.message}`);
  if (recRes.error)  throw new Error(`breakout_recent: ${recRes.error.message}`);
  if (kindRes.error) throw new Error(`breakout_by_kind: ${kindRes.error.message}`);
  if (topRes.error)  throw new Error(`top_revenue: ${topRes.error.message}`);

  const s    = (sumRes.data?.[0] ?? null) as SummaryRow | null;
  const recs = (recRes.data ?? []) as RecentRow[];
  const kinds = (kindRes.data ?? []) as ByKindRow[];
  const tops = (topRes.data ?? []) as TopRevenueRow[];

  const loadMax = Math.max(1, ...tops.map((t) => Number(t.load_score) || 0));

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between gap-4">
        <h1 className="text-xl font-semibold">Hospital department breakout</h1>
        <span className="text-xs text-[var(--color-muted)]">
          14 KPIs · departments table · by-kind breakdown · top-load · 10 dept kinds · pure read aggregator
        </span>
      </header>

      {s ? (
        <section>
          <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Department portfolio summary</h2>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
            <Card title="Total departments"           val={formatNumber(s.total_departments)} />
            <Card title="Top dept kind"               val={s.top_dept_kind ?? "—"} sub={`${formatNumber(s.top_dept_kind_count)} depts`} />
            <Card title="Hospitals w/ depts"          val={formatNumber(s.hospitals_with_departments)} />
            <Card title="Avg depts / hospital"        val={Number(s.avg_departments_per_hospital).toFixed(2)} />
            <Card title="Total equipment"             val={formatNumber(s.total_equipment_across_depts)} sub="across depts" />
            <Card title="Visits (30d)"                val={formatNumber(s.total_visits_30d)} ok={s.total_visits_30d > 0} />
            <Card title="Top dept by visits"          val={s.top_dept_by_visits ?? "—"} sub={`${formatNumber(s.top_dept_by_visits_count)} visits`} />
            <Card title="Depts w/ 0 visits (30d)"     val={formatNumber(s.depts_with_no_visits_30d)} warn={s.depts_with_no_visits_30d > 0} />
            <Card title="Depts idle >60d"             val={formatNumber(s.depts_idle_over_60d)} danger={s.depts_idle_over_60d > 0} />
            <Card title="Engineers assigned"          val={formatNumber(s.unique_engineers_assigned)} sub="distinct" />
            <Card title="Max equipment / dept"        val={formatNumber(s.max_equipment_in_one_dept)} />
            <Card title="Avg equipment / dept"        val={Number(s.avg_equipment_per_dept).toFixed(2)} />
            <Card title="Total dept kinds"            val={formatNumber(kinds.length)} sub="of 10 allowed" />
            <Card title="Generated"                   val={formatRelativeTime(s.generated_at)} sub={s.generated_at} />
          </div>
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No summary data.</p>}

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Departments (most recent 40 by updated_at)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Department</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-left">Hospital</th>
                <th className="px-3 py-2 text-right">Equipment</th>
                <th className="px-3 py-2 text-right">Visits (30d)</th>
                <th className="px-3 py-2 text-left">Last visit</th>
                <th className="px-3 py-2 text-left">Lead</th>
                <th className="px-3 py-2 text-left">Engineer</th>
                <th className="px-3 py-2 text-left">Updated</th>
              </tr>
            </thead>
            <tbody>
              {recs.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={9}>No departments registered yet.</td></tr>
              ) : recs.map((d) => (
                <tr key={d.id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{d.department_label}</td>
                  <td className="px-3 py-2"><KindBadge k={d.department_kind} /></td>
                  <td className="px-3 py-2 tabular-nums text-xs">{shortId(d.hospital_user_id)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(d.total_equipment_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(d.total_visits_30d)}</td>
                  <td className="px-3 py-2">{d.last_visit_at ? formatRelativeTime(d.last_visit_at) : "—"}</td>
                  <td className="px-3 py-2">{d.department_lead_name ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums text-xs">{d.primary_engineer_id ? shortId(d.primary_engineer_id) : "—"}</td>
                  <td className="px-3 py-2">{formatRelativeTime(d.updated_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Breakdown by department kind</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-right">Depts</th>
                <th className="px-3 py-2 text-right">Hospitals</th>
                <th className="px-3 py-2 text-right">Equipment</th>
                <th className="px-3 py-2 text-right">Visits (30d)</th>
                <th className="px-3 py-2 text-right">Avg eq/dept</th>
                <th className="px-3 py-2 text-right">Avg visits/dept</th>
                <th className="px-3 py-2 text-right">Idle {">"}60d</th>
              </tr>
            </thead>
            <tbody>
              {kinds.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={8}>No data.</td></tr>
              ) : kinds.map((k) => (
                <tr key={k.department_kind} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2"><KindBadge k={k.department_kind} /></td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(k.dept_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(k.hospitals_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(k.total_equipment)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(k.total_visits_30d)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{Number(k.avg_equipment_per_dept).toFixed(2)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{Number(k.avg_visits_per_dept).toFixed(2)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(k.idle_over_60d_count)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Top departments by load score (equipment x visits)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
          <table className="min-w-full text-sm">
            <thead className="text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-right">#</th>
                <th className="px-3 py-2 text-left">Department</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-right">Equipment</th>
                <th className="px-3 py-2 text-right">Visits</th>
                <th className="px-3 py-2 text-right">Load score</th>
                <th className="px-3 py-2 text-left">Load bar</th>
                <th className="px-3 py-2 text-left">Last visit</th>
              </tr>
            </thead>
            <tbody>
              {tops.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={8}>No load data yet.</td></tr>
              ) : tops.map((t) => {
                const pct = Math.max(2, Math.round((Number(t.load_score) / loadMax) * 100));
                return (
                  <tr key={t.id} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2 text-right tabular-nums">{t.rank_pos}</td>
                    <td className="px-3 py-2">{t.department_label}</td>
                    <td className="px-3 py-2"><KindBadge k={t.department_kind} /></td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(t.total_equipment_count)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(t.total_visits_30d)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(Number(t.load_score))}</td>
                    <td className="px-3 py-2">
                      <div className="h-2 w-full rounded bg-[var(--color-border)]">
                        <div className="h-2 rounded bg-[var(--color-ok)]" style={{ width: `${pct}%` }} />
                      </div>
                    </td>
                    <td className="px-3 py-2">{t.last_visit_at ? formatRelativeTime(t.last_visit_at) : "—"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
