import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups by hour 7d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  hour_ist: number;
  engineer_signups: number;
  hospital_signups: number;
  other_signups: number;
  total: number;
};

export default async function SignupsByHour7dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_by_hour_7d");
  if (error) throw new Error(`founder_signups_by_hour_7d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour IST", render: (r) => <span className="text-xs tabular-nums font-medium">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "e", header: "Engineer", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.engineer_signups)}</span> },
    { key: "ho", header: "Hospital", render: (r) => <span className="text-xs tabular-nums text-[var(--color-info)]">{formatNumber(r.hospital_signups)}</span> },
    { key: "o", header: "Other", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.other_signups)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups by hour (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          24-hour IST distribution · 7d signups split engineer/hospital/other · onboarding temporal pattern
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No signups in last 7 days." />
    </div>
  );
}
