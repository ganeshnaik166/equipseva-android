import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Notifications throughput 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_sent: number;
  total_read: number;
  read_pct: number;
  distinct_users: number;
  distinct_kinds: number;
};

function Card({ title, val, sub }: { title: string; val: string; sub?: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function NotificationsThroughput30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_notifications_throughput_30d");
  if (error) throw new Error(`founder_notifications_throughput_30d: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Notifications throughput (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">5 KPIs · pair with /notifications-engagement-30d (daily) and /notifications-by-kind-30d</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <Card title="Total sent" val={formatNumber(r.total_sent)} />
          <Card title="Total read" val={formatNumber(r.total_read)} />
          <Card title="Read %" val={formatPct(Number(r.read_pct) / 100)} />
          <Card title="Distinct users" val={formatNumber(r.distinct_users)} />
          <Card title="Distinct kinds" val={formatNumber(r.distinct_kinds)} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
