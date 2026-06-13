import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime, formatRupees } from "@/lib/format";

export const metadata = { title: "System health — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type ReconRow = {
  run_date: string;
  status: string;
  anomaly_count: number | null;
  ran_at: string | null;
};

type DeadLetter = {
  category: string;
  count_rows: number | null;
  total_paise: number | null;
};

type RzpHealth = {
  table_name: string;
  duplicate_count: number | null;
  null_binding_count: number | null;
  oldest_null_at: string | null;
};

type KycRenewal = {
  status?: string | null;
};

type TopEvent = {
  event_key: string;
  event_count: number | null;
  unique_users: number | null;
};

export default async function HealthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [reconRes, deadRes, rzpRes, kycRes, topRes] = await Promise.all([
    supabase.rpc("founder_reconciliation_recent", { p_days: 3 }),
    supabase.rpc("founder_payouts_dead_letter_summary"),
    supabase.rpc("founder_razorpay_binding_health"),
    supabase.rpc("founder_kyc_renewal_queue", { p_days: 30, p_limit: 500 }),
    supabase.rpc("founder_top_events", { p_days: 1, p_limit: 10 }),
  ]);

  // Treat any individual RPC failure as an UNKNOWN signal in the health
  // panel; don't blow the whole page up.
  const recon = (reconRes.error ? [] : (reconRes.data ?? [])) as ReconRow[];
  const dead = (deadRes.error ? [] : (deadRes.data ?? [])) as DeadLetter[];
  const rzp = (rzpRes.error ? [] : (rzpRes.data ?? [])) as RzpHealth[];
  const kyc = (kycRes.error ? [] : (kycRes.data ?? [])) as KycRenewal[];
  const top = (topRes.error ? [] : (topRes.data ?? [])) as TopEvent[];

  const reconLatest = recon[0];
  const reconFresh =
    reconLatest?.ran_at != null &&
    Date.now() - new Date(reconLatest.ran_at).getTime() < 36 * 3600 * 1000;
  const reconAnomalies = recon.reduce((s, r) => s + (r.anomaly_count ?? 0), 0);
  const totalDeadLetter = dead.reduce((s, r) => s + (r.count_rows ?? 0), 0);
  const totalDeadPaise = dead.reduce((s, r) => s + (r.total_paise ?? 0), 0);
  const rzpDupes = rzp.reduce((s, r) => s + (r.duplicate_count ?? 0), 0);
  const rzpNullBindings = rzp.reduce((s, r) => s + (r.null_binding_count ?? 0), 0);
  const kycExpired = kyc.filter((r) => (r.status ?? "").toLowerCase() === "expired").length;
  const eventsLast24h = top.reduce((s, r) => s + (r.event_count ?? 0), 0);

  const signals: {
    label: string;
    state: "ok" | "warn" | "danger";
    value: string;
    href?: string;
  }[] = [
    {
      label: "Recon cron (last run)",
      state: reconFresh ? "ok" : "warn",
      value: reconLatest?.ran_at
        ? formatRelativeTime(reconLatest.ran_at)
        : "no runs",
      href: "/reconciliation",
    },
    {
      label: "Recon anomalies (3d)",
      state: reconAnomalies === 0 ? "ok" : reconAnomalies < 5 ? "warn" : "danger",
      value: formatNumber(reconAnomalies),
      href: "/reconciliation",
    },
    {
      label: "Payout dead-letter",
      state: totalDeadLetter === 0 ? "ok" : "danger",
      value: `${formatNumber(totalDeadLetter)} / ${formatRupees(totalDeadPaise / 100)}`,
      href: "/payouts?status=failed",
    },
    {
      label: "RZP binding dupes",
      state: rzpDupes === 0 ? "ok" : "danger",
      value: formatNumber(rzpDupes),
    },
    {
      label: "RZP null bindings",
      state: rzpNullBindings === 0 ? "ok" : "warn",
      value: formatNumber(rzpNullBindings),
    },
    {
      label: "KYC expired",
      state: kycExpired === 0 ? "ok" : kycExpired < 5 ? "warn" : "danger",
      value: formatNumber(kycExpired),
      href: "/kyc",
    },
    {
      label: "Analytics events (24h)",
      state: eventsLast24h > 0 ? "ok" : "warn",
      value: formatNumber(eventsLast24h),
      href: "/funnel",
    },
  ];

  const okCount = signals.filter((s) => s.state === "ok").length;

  const reconCols: Column<ReconRow>[] = [
    { key: "date", header: "Run date", render: (r) => r.run_date },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${
            r.status === "clean"
              ? "bg-green-100 text-[var(--color-ok)]"
              : r.status === "anomaly"
                ? "bg-yellow-100 text-[var(--color-warn)]"
                : "bg-red-100 text-[var(--color-danger)]"
          }`}
        >
          {r.status}
        </span>
      ),
    },
    { key: "anom", header: "Anomalies", render: (r) => formatNumber(r.anomaly_count) },
    { key: "ran", header: "Ran at", render: (r) => formatRelativeTime(r.ran_at) },
  ];

  const rzpCols: Column<RzpHealth>[] = [
    { key: "table", header: "Table", render: (r) => <code className="text-xs">{r.table_name}</code> },
    {
      key: "dupes",
      header: "Duplicates",
      render: (r) => (
        <span className={(r.duplicate_count ?? 0) > 0 ? "font-semibold text-[var(--color-danger)]" : ""}>
          {formatNumber(r.duplicate_count)}
        </span>
      ),
    },
    {
      key: "nulls",
      header: "Null bindings",
      render: (r) => (
        <span className={(r.null_binding_count ?? 0) > 0 ? "font-semibold text-[var(--color-warn)]" : ""}>
          {formatNumber(r.null_binding_count)}
        </span>
      ),
    },
    {
      key: "oldest",
      header: "Oldest null",
      render: (r) => formatRelativeTime(r.oldest_null_at),
    },
  ];

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">System health</h1>
        <span
          className={`rounded px-2 py-0.5 text-xs ${
            okCount === signals.length
              ? "bg-green-100 text-[var(--color-ok)]"
              : signals.some((s) => s.state === "danger")
                ? "bg-red-100 text-[var(--color-danger)]"
                : "bg-yellow-100 text-[var(--color-warn)]"
          }`}
        >
          {okCount}/{signals.length} signals green
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {signals.map((s) => (
            <StatCard
              key={s.label}
              label={s.label}
              value={s.value}
              href={s.href}
              tone={s.state === "ok" ? "ok" : s.state === "danger" ? "danger" : "warn"}
            />
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Reconciliation (last 3 days)</h2>
        <DataTable
          columns={reconCols}
          rows={recon}
          rowKey={(r) => r.run_date}
          emptyMessage="No reconciliation runs in the last 3 days — cron may be unhealthy."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Razorpay binding health (r469 + r481)</h2>
        <DataTable
          columns={rzpCols}
          rows={rzp}
          rowKey={(r) => r.table_name}
          emptyMessage="No tables reporting issues."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Top analytics events (24h)</h2>
        <DataTable
          columns={[
            { key: "ev", header: "Event", render: (r: TopEvent) => <code className="text-xs">{r.event_key}</code> },
            { key: "c", header: "Count", render: (r) => formatNumber(r.event_count) },
            { key: "u", header: "Unique users", render: (r) => formatNumber(r.unique_users) },
          ]}
          rows={top}
          rowKey={(r) => r.event_key}
          emptyMessage="No analytics events in the last 24h — clients may not be calling log_analytics_event."
        />
      </section>
    </div>
  );
}
