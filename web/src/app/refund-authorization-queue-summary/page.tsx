import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Refund-authorization queue summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  pending_count: number;
  pending_value_inr: number;
  oldest_pending_age_hours: number;
  expiring_24h_count: number;
  approved_30d: number;
  rejected_30d: number;
  expired_30d: number;
  executed_30d: number;
  auto_approved_30d: number;
  manual_approved_30d: number;
  auto_share_pct_30d: number;
  median_approval_hours_30d: number;
};

export default async function RefundAuthorizationQueueSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_refund_authorization_queue_summary");
  if (error) throw new Error(`founder_refund_authorization_queue_summary: ${error.message}`);
  const row = ((data ?? [])[0] ?? {
    pending_count: 0,
    pending_value_inr: 0,
    oldest_pending_age_hours: 0,
    expiring_24h_count: 0,
    approved_30d: 0,
    rejected_30d: 0,
    expired_30d: 0,
    executed_30d: 0,
    auto_approved_30d: 0,
    manual_approved_30d: 0,
    auto_share_pct_30d: 0,
    median_approval_hours_30d: 0,
  }) as Row;

  const pendingCount = Number(row.pending_count ?? 0);
  const pendingValue = Number(row.pending_value_inr ?? 0);
  const oldestHours = Number(row.oldest_pending_age_hours ?? 0);
  const expiringSoon = Number(row.expiring_24h_count ?? 0);
  const approved30d = Number(row.approved_30d ?? 0);
  const rejected30d = Number(row.rejected_30d ?? 0);
  const expired30d = Number(row.expired_30d ?? 0);
  const executed30d = Number(row.executed_30d ?? 0);
  const auto30d = Number(row.auto_approved_30d ?? 0);
  const manual30d = Number(row.manual_approved_30d ?? 0);
  const autoSharePct = Number(row.auto_share_pct_30d ?? 0);
  const medianHours = Number(row.median_approval_hours_30d ?? 0);

  const oldestLabel = oldestHours <= 0
    ? "—"
    : oldestHours < 48
      ? `${oldestHours.toFixed(1)} h`
      : `${(oldestHours / 24).toFixed(1)} d`;

  const pendingTone = pendingCount === 0
    ? "var(--color-ok)"
    : pendingCount >= 10
      ? "var(--color-danger)"
      : "var(--color-warn)";

  const expiringTone = expiringSoon === 0
    ? "var(--color-ok)"
    : expiringSoon >= 3
      ? "var(--color-danger)"
      : "var(--color-warn)";

  const tiles: Array<{
    label: string;
    value: string;
    sub?: string;
    tone?: string;
  }> = [
    {
      label: "Pending (live)",
      value: formatNumber(pendingCount),
      sub: `value ${formatRupees(pendingValue)}`,
      tone: pendingTone,
    },
    {
      label: "Oldest pending",
      value: oldestLabel,
      sub: "age of head-of-queue",
    },
    {
      label: `Expiring ${"<="} 24 h`,
      value: formatNumber(expiringSoon),
      sub: "auto-expires if untouched",
      tone: expiringTone,
    },
    {
      label: "Approved · 30 d",
      value: formatNumber(approved30d),
      sub: "incl. auto + manual",
      tone: "var(--color-ok)",
    },
    {
      label: "Rejected · 30 d",
      value: formatNumber(rejected30d),
      sub: "founder declined",
      tone: rejected30d > 0 ? "var(--color-warn)" : undefined,
    },
    {
      label: "Expired · 30 d",
      value: formatNumber(expired30d),
      sub: "reaper auto-closed",
      tone: expired30d > 0 ? "var(--color-warn)" : undefined,
    },
    {
      label: "Executed · 30 d",
      value: formatNumber(executed30d),
      sub: "refund pushed downstream",
    },
    {
      label: "Auto-approved · 30 d",
      value: formatNumber(auto30d),
      sub: `${"<="} ${"₹"}10,000 fast-path`,
    },
    {
      label: "Manual-approved · 30 d",
      value: formatNumber(manual30d),
      sub: "founder-touched",
    },
    {
      label: "Auto-share · 30 d",
      value: `${autoSharePct.toFixed(1)}%`,
      sub: "auto / (auto+manual+rejected)",
    },
    {
      label: "Median approval latency",
      value: medianHours > 0 ? `${medianHours.toFixed(2)} h` : "—",
      sub: "manual-only · 30 d",
    },
    {
      label: "Backlog ratio",
      value: approved30d + rejected30d + expired30d === 0
        ? "—"
        : `${(pendingCount / (approved30d + rejected30d + expired30d)).toFixed(2)}x`,
      sub: "pending vs 30-d decided",
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Refund-authorization queue summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {`Founder approval pipeline · threshold `}
          <span className="font-mono">{"₹"}10,000</span>
          {` · auto-expire 7 d · pending=${formatNumber(pendingCount)}`}
        </span>
      </header>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {tiles.map((t) => (
          <div
            key={t.label}
            className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface)] p-3"
          >
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">
              {t.label}
            </div>
            <div
              className="mt-1 text-lg font-semibold tabular-nums"
              style={t.tone ? { color: t.tone } : undefined}
            >
              {t.value}
            </div>
            {t.sub ? (
              <div className="text-[11px] text-[var(--color-muted)] mt-0.5">{t.sub}</div>
            ) : null}
          </div>
        ))}
      </div>

      <p className="text-[11px] text-[var(--color-muted)]">
        {`Pending = status='pending' AND expires_at > now(). Auto-approved = approver_reason tagged 'auto-approved (below threshold)'. `}
        {`Median latency excludes auto-path. 30-d windows are rolling from now(). Source: public.refund_authorization_requests (r488).`}
      </p>
    </div>
  );
}
