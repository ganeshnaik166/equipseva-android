import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital repeat rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number };

export default async function HospitalRepeatRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_repeat_rate");
  if (error) throw new Error(`founder_hospital_repeat_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + r.cnt, 0);
  const oneShot = rows.find((r) => r.bucket.includes("one-shot"))?.cnt ?? 0;
  const repeatShare = total === 0 ? 0 : Math.round(((total - oneShot) / total) * 1000) / 10;
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share",
      render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{total === 0 ? "—" : `${((r.cnt / total) * 100).toFixed(1)}%`}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital repeat rate</h1>
        <span className="text-xs text-[var(--color-muted)]">distribution by all-time job count</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Total hospitals" value={formatNumber(total)} />
          <StatCard label="Repeat customers" value={formatNumber(total - oneShot)} subtext={`${repeatShare}% of total`} tone="ok" />
          <StatCard label="One-shot" value={formatNumber(oneShot)} subtext={`${total === 0 ? 0 : ((oneShot / total) * 100).toFixed(1)}%`} tone={oneShot / Math.max(total, 1) > 0.5 ? "warn" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No data." />
    </div>
  );
}
