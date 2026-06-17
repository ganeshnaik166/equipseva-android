import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audit by engineer — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { engineer_user_id: string; display_name: string; responses_180d: number; avg_rating: number; low_2less: number; high_4plus: number };

export default async function SpotAuditByEngineerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audit_by_engineer");
  if (error) throw new Error(`founder_spot_audit_by_engineer: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "r", header: "Responses", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.responses_180d)}</span> },
    { key: "a", header: "Avg rating",
      render: (r) => {
        const tone = r.avg_rating < 3 ? "text-[var(--color-danger)]"
          : r.avg_rating < 4 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.avg_rating}</span>;
      }
    },
    { key: "l", header: "≤2★", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.low_2less)}</span> },
    { key: "h", header: "4★+", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.high_4plus)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audit by engineer (180d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Engineers with ≥3 spot audit responses · sorted by avg rating (lowest first)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No spot audit responses." />
    </div>
  );
}
