import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Signups recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { user_id: string; display_name: string; role: string; state: string; city: string; created_at: string };

export default async function SignupsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_recent");
  if (error) throw new Error(`founder_signups_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Joined", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "n", header: "Name", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "r", header: "Role", render: (r) => <span className="text-xs">{r.role}</span> },
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups recent (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 new profiles</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.user_id} emptyMessage="No new signups." />
    </div>
  );
}
