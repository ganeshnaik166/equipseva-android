import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Tier graduations recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { user_id: string; display_name: string; old_tier: string; new_tier: string; direction: string; changed_at: string };

export default async function TierGraduationsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_graduations_recent");
  if (error) throw new Error(`founder_tier_graduations_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.changed_at).toLocaleString()}</span> },
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "o", header: "From", render: (r) => <span className="text-xs">{r.old_tier}</span> },
    { key: "x", header: "To", render: (r) => <span className="text-xs font-semibold">{r.new_tier}</span> },
    { key: "d", header: "Direction",
      render: (r) => {
        const tone = r.direction === "promotion" ? "text-[var(--color-ok)]"
          : r.direction === "demotion" ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.direction}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier graduations (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 engineer cert tier transitions</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.user_id + r.changed_at} emptyMessage="No tier events." />
    </div>
  );
}
