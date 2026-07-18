import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer product adoption tracker — r2484" };
export const dynamic = "force-dynamic";

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "₹" + Number(n).toLocaleString("en-IN");
}

function statusBadge(status: string): string {
  if (status === "active") return "text-emerald-700 font-medium";
  if (status === "adopting") return "text-blue-700";
  if (status === "not_adopted") return "text-gray-500";
  if (status === "lapsed") return "text-amber-700";
  if (status === "dropped") return "text-rose-700 font-medium";
  return "";
}

function outcomeBadge(o: string): string {
  if (o === "positive") return "text-emerald-700";
  if (o === "negative") return "text-rose-700";
  if (o === "neutral") return "text-gray-600";
  if (o === "pending") return "text-amber-700";
  return "";
}

export default async function FounderCustomerProductAdoptionTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [adoptionRes, helpRes, stuckRes, topValueRes, funnelRes, ownerLoadRes, weeklyRes] =
    await Promise.all([
      sb.rpc("list_adoption_r2484"),
      sb.rpc("list_help_requests_r2484"),
      sb.rpc("stuck_users_focus_r2484"),
      sb.rpc("top_value_features_r2484"),
      sb.rpc("feature_adoption_funnel_r2484"),
      sb.rpc("owner_load_r2484"),
      sb.rpc("weekly_adoption_trend_r2484"),
    ]);

  if (adoptionRes.error) throw new Error(`list_adoption_r2484: ${adoptionRes.error.message}`);
  if (helpRes.error) throw new Error(`list_help_requests_r2484: ${helpRes.error.message}`);
  if (stuckRes.error) throw new Error(`stuck_users_focus_r2484: ${stuckRes.error.message}`);
  if (topValueRes.error) throw new Error(`top_value_features_r2484: ${topValueRes.error.message}`);
  if (funnelRes.error) throw new Error(`feature_adoption_funnel_r2484: ${funnelRes.error.message}`);
  if (ownerLoadRes.error) throw new Error(`owner_load_r2484: ${ownerLoadRes.error.message}`);
  if (weeklyRes.error) throw new Error(`weekly_adoption_trend_r2484: ${weeklyRes.error.message}`);

  const adoption = (adoptionRes.data ?? []) as any[];
  const helpRequests = (helpRes.data ?? []) as any[];
  const stuck = (stuckRes.data ?? []) as any[];
  const topValue = (topValueRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];
  const weekly = (weeklyRes.data ?? []) as any[];

  const totalAdoptions = adoption.length;
  const totalAdopted = adoption.filter((a) => a.adopted).length;
  const totalValue = adoption.reduce((s, a) => s + Number(a.value_derived_rupees || 0), 0);
  const totalStuck = adoption.reduce((s, a) => s + Number(a.stuck_user_count || 0), 0);
  const helpNeededCount = adoption.filter((a) => a.help_needed).length;

  const adoptionCols: Column<any>[] = [
    { key: "feature_name", header: "Feature", render: (r: any) => <span className="font-mono text-xs">{r.feature_name}</span> },
    { key: "hospital_user_id", header: "Hospital", render: (r: any) => <span className="font-mono text-xs">{String(r.hospital_user_id).slice(0, 8)}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "adopted", header: "Adopted", render: (r: any) => (r.adopted ? "yes" : "no") },
    { key: "adopted_at", header: "Adopted at", render: (r: any) => fmtDate(r.adopted_at) },
    { key: "usage_frequency_per_week", header: "Usage/wk", render: (r: any) => r.usage_frequency_per_week },
    { key: "value_derived_rupees", header: "Value", render: (r: any) => fmtRupees(r.value_derived_rupees) },
    { key: "stuck_user_count", header: "Stuck", render: (r: any) => r.stuck_user_count > 0 ? <span className="text-rose-700">{r.stuck_user_count}</span> : 0 },
    { key: "help_needed", header: "Help?", render: (r: any) => r.help_needed ? <span className="text-amber-700">yes</span> : "—" },
    { key: "help_request_count", header: "# help", render: (r: any) => r.help_request_count },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const helpCols: Column<any>[] = [
    { key: "feature_name", header: "Feature", render: (r: any) => <span className="font-mono text-xs">{r.feature_name}</span> },
    { key: "request_kind", header: "Kind", render: (r: any) => r.request_kind },
    { key: "request_at", header: "Requested", render: (r: any) => fmtDate(r.request_at) },
    { key: "resolved_at", header: "Resolved", render: (r: any) => fmtDate(r.resolved_at) },
    { key: "outcome", header: "Outcome", render: (r: any) => <span className={outcomeBadge(r.outcome)}>{r.outcome}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const stuckCols: Column<any>[] = [
    { key: "feature_name", header: "Feature", render: (r: any) => <span className="font-mono text-xs">{r.feature_name}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "stuck_user_count", header: "Stuck users", render: (r: any) => <span className="text-rose-700 font-medium">{r.stuck_user_count}</span> },
    { key: "help_request_count", header: "# help", render: (r: any) => r.help_request_count },
    { key: "unresolved_help_count", header: "Unresolved", render: (r: any) => r.unresolved_help_count },
    { key: "help_needed", header: "Help?", render: (r: any) => r.help_needed ? "yes" : "no" },
    { key: "focus_score", header: "Focus score", render: (r: any) => <span className="font-medium">{r.focus_score}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const topValueCols: Column<any>[] = [
    { key: "feature_name", header: "Feature", render: (r: any) => <span className="font-mono text-xs">{r.feature_name}</span> },
    { key: "hospital_count", header: "Hospitals", render: (r: any) => r.hospital_count },
    { key: "adopted_count", header: "Adopted", render: (r: any) => r.adopted_count },
    { key: "active_count", header: "Active", render: (r: any) => r.active_count },
    { key: "avg_usage_per_week", header: "Avg usage/wk", render: (r: any) => r.avg_usage_per_week },
    { key: "total_value_rupees", header: "Total value", render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  const funnelCols: Column<any>[] = [
    { key: "status", header: "Stage", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "cohort_count", header: "Count", render: (r: any) => r.cohort_count },
    { key: "pct_of_total", header: "% total", render: (r: any) => `${r.pct_of_total}%` },
    { key: "total_value_rupees", header: "Value", render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  const ownerCols: Column<any>[] = [
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email },
    { key: "adoption_count", header: "Adoptions", render: (r: any) => r.adoption_count },
    { key: "active_count", header: "Active", render: (r: any) => r.active_count },
    { key: "help_needed_count", header: "Help-needed", render: (r: any) => r.help_needed_count > 0 ? <span className="text-amber-700">{r.help_needed_count}</span> : 0 },
    { key: "open_help_requests", header: "Open help", render: (r: any) => r.open_help_requests },
    { key: "total_value_rupees", header: "Value", render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  const weeklyCols: Column<any>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "adopted_count", header: "Adopted", render: (r: any) => r.adopted_count },
    { key: "help_request_count", header: "Help requests", render: (r: any) => r.help_request_count },
    { key: "resolved_count", header: "Resolved", render: (r: any) => r.resolved_count },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Customer product adoption tracker</h1>
        <p className="text-sm text-gray-600">
          Feature × hospital × adopted × usage frequency × value derived × stuck users × help-needed. Round r2484.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Total adoptions</div>
          <div className="text-2xl font-semibold">{totalAdoptions}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Adopted</div>
          <div className="text-2xl font-semibold text-emerald-700">{totalAdopted}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Value derived</div>
          <div className="text-2xl font-semibold">{fmtRupees(totalValue)}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Stuck users</div>
          <div className="text-2xl font-semibold text-rose-700">{totalStuck}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Help-needed</div>
          <div className="text-2xl font-semibold text-amber-700">{helpNeededCount}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Adoption funnel by stage</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No adoption records yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top value features</h2>
        <DataTable
          rows={topValue}
          columns={topValueCols}
          emptyMessage="No features tracked."
          rowKey={(r: any, i: number) => String(r.feature_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stuck users & help focus</h2>
        <p className="text-xs text-gray-500 mb-2">
          Rows where stuck_users &gt; 0 OR help_needed=true OR status in (lapsed, dropped). Sorted by focus_score desc.
        </p>
        <DataTable
          rows={stuck}
          columns={stuckCols}
          emptyMessage="No stuck cohorts — healthy adoption."
          rowKey={(r: any, i: number) => String(r.adoption_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">CS owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly trend (last 12 weeks)</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All adoption records</h2>
        <DataTable
          rows={adoption}
          columns={adoptionCols}
          emptyMessage="No adoption records seeded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Help request log</h2>
        <DataTable
          rows={helpRequests}
          columns={helpCols}
          emptyMessage="No help requests."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
