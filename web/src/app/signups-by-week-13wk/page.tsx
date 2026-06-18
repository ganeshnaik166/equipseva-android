import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  engineer_signups: number;
  hospital_signups: number;
  other_signups: number;
  total: number;
};

export default async function SignupsByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_by_week_13wk");
  if (error) throw new Error(`founder_signups_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const tEng = rows.reduce((a, r) => a + (r.engineer_signups ?? 0), 0);
  const tHosp = rows.reduce((a, r) => a + (r.hospital_signups ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "e", header: "Engineer", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.engineer_signups)}</span> },
    { key: "h", header: "Hospital", render: (r) => <span className="text-xs tabular-nums text-[var(--color-info)]">{formatNumber(r.hospital_signups)}</span> },
    { key: "o", header: "Other", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.other_signups)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(tEng)}</span> engineers · <span className="font-mono tabular-nums text-[var(--color-info)]">{formatNumber(tHosp)}</span> hospitals
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No signups in last 13 weeks." />
    </div>
  );
}
