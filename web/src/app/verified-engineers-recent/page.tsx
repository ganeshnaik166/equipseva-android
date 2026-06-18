import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Verified engineers recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { user_id: string; display_name: string; state: string; city: string; verified_at: string; signup_to_verified_days: number };

export default async function VerifiedEngineersRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_verified_engineers_recent");
  if (error) throw new Error(`founder_verified_engineers_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Verified at", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.verified_at).toLocaleString()}</span> },
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "d", header: "Signup → verified (days)",
      render: (r) => {
        const tone = r.signup_to_verified_days > 14 ? "text-[var(--color-warn)]"
          : r.signup_to_verified_days > 7 ? "text-[var(--color-fg)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.signup_to_verified_days}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Verified engineers recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 with signup → verified latency</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.user_id} emptyMessage="No new verifications." />
    </div>
  );
}
