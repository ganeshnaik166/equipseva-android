import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups by role 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  engineer_signups: number;
  hospital_signups: number;
  buyer_signups: number;
  other_signups: number;
  total: number;
};

export default async function SignupsByRole30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_by_role_30d");
  if (error) throw new Error(`founder_signups_by_role_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalEng = rows.reduce((a, r) => a + (r.engineer_signups ?? 0), 0);
  const totalHosp = rows.reduce((a, r) => a + (r.hospital_signups ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "e", header: "Engineer", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.engineer_signups)}</span> },
    { key: "h", header: "Hospital", render: (r) => <span className="text-xs tabular-nums text-[var(--color-info)]">{formatNumber(r.hospital_signups)}</span> },
    { key: "b", header: "Buyer", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.buyer_signups)}</span> },
    { key: "o", header: "Other", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.other_signups)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups by role (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          30d: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalEng)}</span> engineers · <span className="font-mono tabular-nums text-[var(--color-info)]">{formatNumber(totalHosp)}</span> hospitals
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No signups in last 30 days." />
    </div>
  );
}
