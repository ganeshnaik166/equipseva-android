import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Notifications by kind 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  kind: string;
  sent: number;
  read: number;
  read_pct: number;
};

export default async function NotificationsByKind30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_notifications_by_kind_30d");
  if (error) throw new Error(`founder_notifications_by_kind_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalSent = rows.reduce((a, r) => a + (r.sent ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "k", header: "Kind", render: (r) => <span className="text-xs font-medium">{r.kind}</span> },
    { key: "s", header: "Sent", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.sent)}</span> },
    { key: "r", header: "Read", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.read)}</span> },
    { key: "p", header: "Read %", render: (r) => {
        const v = Number(r.read_pct);
        const tone = v >= 60 ? "text-[var(--color-ok)]" : v >= 30 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Notifications by kind (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total sent: <span className="font-mono tabular-nums">{formatNumber(totalSent)}</span> · top 50 kinds by volume · low read % = candidate to drop or rework
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.kind} emptyMessage="No notifications sent in last 30d." />
    </div>
  );
}
