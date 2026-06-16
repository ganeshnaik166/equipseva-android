import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups by day — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; signups: number; engineers: number };

export default async function SignupsByDayTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_by_day_trend");
  if (error) throw new Error(`founder_signups_by_day_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total14d = rows.reduce((s, r) => s + r.signups, 0);
  const eng14d = rows.reduce((s, r) => s + r.engineers, 0);
  const today = rows[0];
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "s", header: "Signups", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.signups)}</span> },
    { key: "e", header: "of which engineers", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.engineers)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups by day</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · IST</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="14d total" value={formatNumber(total14d)} />
          <StatCard label="14d engineers" value={formatNumber(eng14d)} />
          <StatCard label="Today" value={formatNumber(today?.signups ?? 0)} subtext={`${today?.engineers ?? 0} engineers`} />
          <StatCard label="Daily avg" value={(total14d / 14).toFixed(1)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No signups." />
    </div>
  );
}
