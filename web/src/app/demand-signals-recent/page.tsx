import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Demand signals recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  source: string;
  reporter_role: string | null;
  part_number: string | null;
  equipment_model: string | null;
  founder_priority: string | null;
  resolved_at: string | null;
  created_at: string;
};

export default async function DemandSignalsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_signals_recent");
  if (error) throw new Error(`founder_demand_signals_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "s", header: "Source", render: (r) => <span className="text-xs">{r.source}</span> },
    { key: "rl", header: "Role", render: (r) => <span className="text-xs">{r.reporter_role ?? "—"}</span> },
    { key: "p", header: "Part #", render: (r) => <span className="text-xs font-mono">{r.part_number ?? "—"}</span> },
    { key: "e", header: "Equipment model", render: (r) => <span className="text-xs">{r.equipment_model ?? "—"}</span> },
    { key: "x", header: "Priority",
      render: (r) => {
        const tone = r.founder_priority === "high" ? "text-[var(--color-danger)]"
          : r.founder_priority === "med" ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.founder_priority ?? "—"}</span>;
      }
    },
    { key: "rv", header: "Resolved",
      render: (r) => r.resolved_at
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : <span className="text-xs text-[var(--color-muted)]">open</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand signals recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 spare-part demand signals</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No demand signals." />
    </div>
  );
}
