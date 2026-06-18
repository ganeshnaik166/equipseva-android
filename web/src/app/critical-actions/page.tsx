import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Critical actions — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  surface: string;
  item_id: string;
  item_label: string;
  amount_inr: number | null;
  created_at: string;
  age_days: number;
  severity: "critical" | "warn";
};

const SURFACE_BADGES: Record<string, { bg: string; fg: string; label: string }> = {
  payout:      { bg: "bg-[var(--color-warn-bg)]",    fg: "text-[var(--color-warn)]",    label: "PAYOUT"   },
  code_red:    { bg: "bg-[var(--color-danger-bg)]",  fg: "text-[var(--color-danger)]",  label: "CODE RED" },
  spare_part:  { bg: "bg-[var(--color-info-bg)]",    fg: "text-[var(--color-info)]",    label: "PART"     },
  escrow:      { bg: "bg-[var(--color-muted-bg)]",   fg: "text-[var(--color-muted)]",   label: "ESCROW"   },
};

export default async function CriticalActionsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_critical_actions");
  if (error) throw new Error(`founder_critical_actions: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const critCount = rows.filter(r => r.severity === "critical").length;
  const cols: Column<Row>[] = [
    {
      key: "s", header: "Type",
      render: (r) => {
        const b = SURFACE_BADGES[r.surface] ?? { bg: "", fg: "", label: r.surface };
        return <span className={`rounded px-2 py-0.5 text-xs font-medium ${b.bg} ${b.fg}`}>{b.label}</span>;
      },
    },
    { key: "l", header: "Item", render: (r) => <span className="text-xs">{r.item_label}</span> },
    { key: "a", header: "Amount", render: (r) => <span className="text-xs tabular-nums">{r.amount_inr != null ? formatRupees(Number(r.amount_inr)) : "—"}</span> },
    { key: "g", header: "Age", render: (r) => <span className={`text-xs tabular-nums ${r.severity === "critical" ? "text-[var(--color-danger)] font-medium" : "text-[var(--color-warn)]"}`}>{formatNumber(r.age_days)}d</span> },
    { key: "c", header: "Created", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatRelativeTime(r.created_at)}</span> },
    { key: "i", header: "ID", render: (r) => <span className="text-xs font-mono text-[var(--color-muted)]">{r.item_id.slice(0, 8)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Critical actions queue</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top items across payouts / Code Red / spare parts / escrow · <span className="text-[var(--color-danger)]">{formatNumber(critCount)} critical</span> · {formatNumber(rows.length)} total
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.surface}-${r.item_id}`} emptyMessage="No critical action items." />
    </div>
  );
}
