import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Notifications snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  sent_today: number;
  read_today: number;
  sent_30d: number;
  read_30d: number;
  read_pct_30d: number;
  unread_over_7d: number;
  distinct_users_30d: number;
  distinct_kinds_30d: number;
  push_channel_30d: number;
  top_kind_30d: string;
  avg_read_latency_minutes: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function NotificationsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_notifications_snapshot_summary");
  if (error) throw new Error(`founder_notifications_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Notifications snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI push/notification dashboard · today/30d/all-time mix · pair with /notifications-engagement-30d + /notifications-by-kind-30d</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total notifications all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Sent today" val={formatNumber(r.sent_today)} sub="IST day" />
          <Card title="Read today" val={formatNumber(r.read_today)} ok sub="IST day" />
          <Card title="Sent 30d" val={formatNumber(r.sent_30d)} />
          <Card title="Read 30d" val={formatNumber(r.read_30d)} ok />
          <Card title="Read rate 30d" val={`${Number(r.read_pct_30d).toFixed(1)}%`} sub="engagement health" />
          <Card title="Stuck unread >7d" val={formatNumber(r.unread_over_7d)} danger={r.unread_over_7d > 0} sub="last 60d sent, never read" />
          <Card title="Distinct users 30d" val={formatNumber(r.distinct_users_30d)} sub="reach" />
          <Card title="Distinct kinds 30d" val={formatNumber(r.distinct_kinds_30d)} />
          <Card title="Push-channel 30d" val={formatNumber(r.push_channel_30d)} sub="channel='push'" />
          <Card title="Top kind 30d" val={String(r.top_kind_30d ?? "(none)")} />
          <Card title="Avg read latency (min, 30d)" val={Number(r.avg_read_latency_minutes).toFixed(1)} sub="sent → read" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
