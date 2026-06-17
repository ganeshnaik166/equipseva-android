import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer recency — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number; share_pct: number };

export default async function EngineerRecencyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_recency");
  if (error) throw new Error(`founder_engineer_recency: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "b", header: "Last bid recency", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "s", header: "Share %",
      render: (r) => {
        const tone = r.bucket.includes("Dormant") ? "text-[var(--color-danger)]"
          : r.bucket.includes("Active") ? "text-[var(--color-ok)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.share_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer recency</h1>
        <span className="text-xs text-[var(--color-muted)]">Verified engineers by days since last placed bid</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No verified engineers." />
    </div>
  );
}
