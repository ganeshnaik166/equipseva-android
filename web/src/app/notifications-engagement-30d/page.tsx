import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Notifications engagement 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  sent: number;
  read: number;
  unread_ratio_pct: number;
};

export default async function NotificationsEngagement30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_notifications_engagement_30d");
  if (error) throw new Error(`founder_notifications_engagement_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalSent = rows.reduce((a, r) => a + (r.sent ?? 0), 0);
  const totalRead = rows.reduce((a, r) => a + (r.read ?? 0), 0);
  const avgUnread = totalSent === 0 ? 0 : 100 - (100 * totalRead / totalSent);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "s", header: "Sent", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.sent)}</span> },
    { key: "r", header: "Read", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.read)}</span> },
    { key: "u", header: "Unread %", render: (r) => {
        const v = Number(r.unread_ratio_pct);
        const tone = v >= 70 ? "text-[var(--color-danger)]" : v >= 40 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Notifications engagement (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Sent: <span className="font-mono tabular-nums">{formatNumber(totalSent)}</span> · Read: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalRead)}</span> · Avg unread: <span className="font-mono tabular-nums">{formatPct(avgUnread / 100)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No notifications sent." />
    </div>
  );
}
