import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Admin actions trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; actions: number; distinct_actors: number; distinct_ops: number };

export default async function AdminActionsTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_admin_actions_trend");
  if (error) throw new Error(`founder_admin_actions_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + r.actions, 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "a", header: "Actions", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.actions)}</span> },
    { key: "u", header: "Distinct actors", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_actors)}</span> },
    { key: "o", header: "Distinct ops", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.distinct_ops)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Admin actions trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · founder_action_log activity</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="14d actions" value={formatNumber(total)} />
          <StatCard label="Daily avg" value={(total / 14).toFixed(1)} />
          <StatCard label="Today" value={formatNumber(rows[0]?.actions ?? 0)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No admin actions." />
    </div>
  );
}
