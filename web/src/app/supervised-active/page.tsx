import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervised active — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { assignment_id: string; trainee_user_id: string; trainee_name: string; supervisor_user_id: string; supervisor_name: string; status: string; days_open: number; signoff_outcome: string | null };

export default async function SupervisedActivePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_active");
  if (error) throw new Error(`founder_supervised_active: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const pending = rows.filter((r) => r.status === "pending_supervisor_accept").length;
  const active = rows.filter((r) => r.status === "active").length;
  const cols: Column<Row>[] = [
    { key: "tr", header: "Trainee", render: (r) => <span className="text-xs">{r.trainee_name}</span> },
    { key: "sv", header: "Supervisor", render: (r) => <span className="text-xs">{r.supervisor_name}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "pending_supervisor_accept" ? "text-[var(--color-warn)]"
          : r.status === "active" ? "text-[var(--color-ok)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "d", header: "Age", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.days_open)}d</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised active</h1>
        <span className="text-xs text-[var(--color-muted)]">pending + active supervised assignments</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Pending accept" value={formatNumber(pending)} tone={pending > 0 ? "warn" : "ok"} />
          <StatCard label="Active" value={formatNumber(active)} />
          <StatCard label="Oldest" value={`${formatNumber(Math.max(0, ...rows.map((r) => r.days_open)))}d`} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.assignment_id} emptyMessage="No active supervisions." />
    </div>
  );
}
