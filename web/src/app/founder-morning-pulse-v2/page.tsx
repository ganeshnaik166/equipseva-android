import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder morning pulse v2 — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric: string;
  metric_order: number;
  today_val: number;
  yesterday_val: number;
  delta: number;
  category: string;
};

const CAT_TONE: Record<string, string> = {
  Growth:      "text-[var(--color-info)]",
  Marketplace: "text-[var(--color-info)]",
  Revenue:     "text-[var(--color-ok)]",
  Trust:       "text-[var(--color-danger)]",
};

export default async function FounderMorningPulseV2Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_morning_pulse_v2");
  if (error) throw new Error(`founder_morning_pulse_v2: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "Cat", render: (r) => <span className={`text-[10px] font-medium uppercase tracking-wider ${CAT_TONE[r.category] ?? ""}`}>{r.category}</span> },
    { key: "m", header: "Metric", render: (r) => <span className="text-xs font-medium">{r.metric}</span> },
    { key: "t", header: "Today", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.today_val)}</span> },
    { key: "y", header: "Yesterday", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.yesterday_val)}</span> },
    { key: "d", header: "Δ", render: (r) => {
        const d = r.delta;
        if (d === 0) return <span className="text-xs tabular-nums text-[var(--color-muted)]">0</span>;
        const tone = d > 0 ? (r.category === "Trust" ? "text-[var(--color-danger)]" : "text-[var(--color-ok)]") : (r.category === "Trust" ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]");
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{d > 0 ? "+" : ""}{formatNumber(d)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Founder morning pulse v2</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12 actionable numbers · today vs yesterday · 4 categories (Growth/Marketplace/Revenue/Trust)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.metric_order)} emptyMessage="No data." />
    </div>
  );
}
