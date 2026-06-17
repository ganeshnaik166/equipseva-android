import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups by hour — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hour_ist: number; signups: number };

export default async function SignupsByHourPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_by_hour");
  if (error) throw new Error(`founder_signups_by_hour: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const max = Math.max(1, ...rows.map((r) => r.signups));
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour (IST)", render: (r) => <span className="text-xs font-mono">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "s", header: "Signups (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.signups)}</span> },
    { key: "b", header: "",
      render: (r) => (
        <div className="h-2 w-32 rounded bg-[var(--color-bg-subtle)]">
          <div className="h-2 rounded bg-[var(--color-fg)]" style={{ width: `${(r.signups / max) * 100}%` }} />
        </div>
      )
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups by hour</h1>
        <span className="text-xs text-[var(--color-muted)]">90d distribution · IST</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No signups." />
    </div>
  );
}
