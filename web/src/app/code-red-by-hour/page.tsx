import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red by hour — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hour_ist: number; opened: number; timed_out: number };

export default async function CodeRedByHourPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_by_hour");
  if (error) throw new Error(`founder_code_red_by_hour: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const max = Math.max(1, ...rows.map((r) => r.opened));
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour (IST)", render: (r) => <span className="text-xs font-mono">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "o", header: "Opened (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.opened)}</span> },
    { key: "t", header: "Timed-out",
      render: (r) => <span className={`text-xs tabular-nums ${r.timed_out > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{formatNumber(r.timed_out)}</span>
    },
    { key: "b", header: "",
      render: (r) => (
        <div className="h-2 w-32 rounded bg-[var(--color-bg-subtle)]">
          <div className="h-2 rounded bg-[var(--color-fg)]" style={{ width: `${(r.opened / max) * 100}%` }} />
        </div>
      )
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red by hour</h1>
        <span className="text-xs text-[var(--color-muted)]">90d distribution by request-creation hour (IST)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No Code Red requests." />
    </div>
  );
}
