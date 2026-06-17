import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Webhook failures recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { source: string; event_kind: string; ref_id: string; failure_reason: string; received_at: string };

export default async function WebhookFailuresRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_webhook_failures_recent");
  if (error) throw new Error(`founder_webhook_failures_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.received_at).toLocaleString()}</span> },
    { key: "s", header: "Source", render: (r) => <span className="text-xs font-semibold">{r.source}</span> },
    { key: "e", header: "Event", render: (r) => <span className="text-xs">{r.event_kind}</span> },
    { key: "i", header: "Ref id", render: (r) => <span className="text-xs font-mono text-[var(--color-muted)]">{r.ref_id?.slice(0, 32)}</span> },
    { key: "r", header: "Reason", render: (r) => <span className="text-xs text-[var(--color-danger)]">{r.failure_reason?.slice(0, 80)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Webhook failures recent (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">RazorpayX payout + Razorpay incoming events that failed to apply</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.source}-${r.ref_id}-${r.received_at}`} emptyMessage="No webhook failures — healthy." />
    </div>
  );
}
