import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Webhook success rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { source: string; window_label: string; events: number; applied: number; success_pct: number };

export default async function WebhookSuccessRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_webhook_success_rate");
  if (error) throw new Error(`founder_webhook_success_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Source", render: (r) => <span className="text-xs font-semibold">{r.source}</span> },
    { key: "w", header: "Window", render: (r) => <span className="text-xs">{r.window_label}</span> },
    { key: "e", header: "Events", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.events)}</span> },
    { key: "a", header: "Applied", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.applied)}</span> },
    { key: "p", header: "Success %",
      render: (r) => {
        const tone = r.success_pct < 95 ? "text-[var(--color-danger)]"
          : r.success_pct < 99 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.success_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Webhook success rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% of webhook events that successfully applied · razorpay + payouts</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.source}-${r.window_label}`} emptyMessage="No webhook events." />
    </div>
  );
}
