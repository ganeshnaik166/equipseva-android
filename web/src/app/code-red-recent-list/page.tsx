import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Code Red recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  hospital_name: string;
  equipment_type: string;
  status: string;
  accepted_at: string | null;
  resolved_at: string | null;
  created_at: string;
};

export default async function CodeRedRecentListPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_recent_v2");
  if (error) throw new Error(`founder_code_red_recent_v2: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Created", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.hospital_name}</span> },
    { key: "e", header: "Equipment", render: (r) => <span className="text-xs">{r.equipment_type}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "resolved" ? "text-[var(--color-ok)]"
          : r.status === "timed_out" ? "text-[var(--color-danger)]"
          : "text-[var(--color-warn)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.accepted_at ? new Date(r.accepted_at).toLocaleString() : "—"}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.resolved_at ? new Date(r.resolved_at).toLocaleString() : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 emergency requests with status + timestamps</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No code red." />
    </div>
  );
}
