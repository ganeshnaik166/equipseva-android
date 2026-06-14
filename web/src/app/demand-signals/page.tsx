import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime } from "@/lib/format";
import { ResolveButton } from "./ResolveButton";
import { PriorityPicker } from "./PriorityPicker";
import { ManualEntryForm } from "./ManualEntryForm";

type SnapshotRow = {
  metric: string;
  current_week_value: number | null;
  prior_week_value: number | null;
  delta_pct: number | null;
};

type BrandRow = {
  brand: string | null;
  signal_count: number | null;
  unique_part_numbers: number | null;
  unique_reporters: number | null;
  last_seen: string | null;
  has_critical: boolean | null;
};

const METRIC_LABELS: Record<string, string> = {
  new_signals: "New signals",
  resolved_signals: "Resolved",
  unique_part_numbers: "Unique parts",
  critical_signals: "Critical-urgency",
};

export const metadata = { title: "Demand signals — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type DashRow = {
  group_key: string;
  equipment_brand: string | null;
  equipment_model: string | null;
  part_number: string | null;
  signal_count: number | null;
  unique_reporters: number | null;
  last_seen: string | null;
  max_urgency: string | null;
  has_critical: boolean | null;
  founder_priority: string | null;
  any_unresolved_id: string;
};

export default async function DemandSignalsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [dashRes, snapRes, brandRes] = await Promise.all([
    supabase.rpc("founder_demand_signal_dashboard"),
    supabase.rpc("founder_demand_signal_weekly_snapshot"),
    supabase.rpc("founder_demand_signal_brand_rollup"),
  ]);
  if (dashRes.error)
    throw new Error(`founder_demand_signal_dashboard: ${dashRes.error.message}`);

  const rows = (dashRes.data ?? []) as DashRow[];
  const snapshot = (snapRes.error ? [] : (snapRes.data ?? [])) as SnapshotRow[];
  const brands = (brandRes.error ? [] : (brandRes.data ?? [])) as BrandRow[];
  const totalSignals = rows.reduce((s, r) => s + (r.signal_count ?? 0), 0);
  const critGroups = rows.filter((r) => r.has_critical).length;
  const highPriority = rows.filter((r) => r.founder_priority === "high").length;
  const uniqueReporters = rows.reduce(
    (s, r) => s + (r.unique_reporters ?? 0),
    0,
  );

  const cols: Column<DashRow>[] = [
    {
      key: "subject",
      header: "Subject",
      render: (r) => (
        <div className="flex flex-col">
          <span className="text-xs font-medium">
            {r.equipment_brand || "?"}{" "}
            <span className="text-[var(--color-muted)]">{r.equipment_model ?? ""}</span>
          </span>
          {r.part_number && (
            <span className="font-mono text-xs text-[var(--color-muted)]">
              part #{r.part_number}
            </span>
          )}
        </div>
      ),
    },
    {
      key: "count",
      header: "Signals",
      render: (r) => (
        <span className="font-semibold tabular-nums">{formatNumber(r.signal_count)}</span>
      ),
    },
    {
      key: "reporters",
      header: "Distinct reporters",
      render: (r) => formatNumber(r.unique_reporters),
    },
    {
      key: "lastSeen",
      header: "Last seen",
      render: (r) => <span title={r.last_seen ?? ""}>{formatRelativeTime(r.last_seen)}</span>,
    },
    {
      key: "urgency",
      header: "Max urgency",
      render: (r) => {
        const tone =
          r.max_urgency === "critical"
            ? "bg-red-100 text-[var(--color-danger)]"
            : r.max_urgency === "urgent"
              ? "bg-yellow-100 text-[var(--color-warn)]"
              : "bg-gray-100";
        return (
          <span className={`rounded px-1.5 py-0.5 text-xs ${tone}`}>
            {r.max_urgency ?? "standard"}
          </span>
        );
      },
    },
    {
      key: "priority",
      header: "Priority",
      render: (r) => (
        <PriorityPicker signalId={r.any_unresolved_id} current={r.founder_priority} />
      ),
    },
    {
      key: "act",
      header: "Action",
      render: (r) => <ResolveButton signalId={r.any_unresolved_id} />,
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare-part demand signals</h1>
        <span className="text-xs text-[var(--color-muted)]">
          top {rows.length} unresolved groups · {totalSignals.toLocaleString("en-IN")} signals
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Unresolved groups" value={formatNumber(rows.length)} />
          <StatCard
            label="Total signals"
            value={formatNumber(totalSignals)}
            tone={totalSignals > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Critical-urgency groups"
            value={formatNumber(critGroups)}
            tone={critGroups > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="High-priority groups"
            value={formatNumber(highPriority)}
            tone={highPriority > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      {snapshot.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">Week-over-week (7d vs prior 7d)</h2>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {snapshot.map((s) => {
              const delta = s.delta_pct;
              const tone =
                delta == null
                  ? "text-[var(--color-muted)]"
                  : delta > 0
                    ? "text-[var(--color-warn)]"
                    : delta < 0
                      ? "text-[var(--color-ok)]"
                      : "text-[var(--color-muted)]";
              const sign = delta != null && delta > 0 ? "+" : "";
              return (
                <div
                  key={s.metric}
                  className="rounded border border-[var(--color-border)] bg-white p-3"
                >
                  <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
                    {METRIC_LABELS[s.metric] ?? s.metric}
                  </div>
                  <div className="mt-1 text-lg font-semibold tabular-nums">
                    {formatNumber(s.current_week_value)}{" "}
                    <span className="text-xs font-normal text-[var(--color-muted)]">
                      vs {formatNumber(s.prior_week_value)}
                    </span>
                  </div>
                  <div className={`text-xs ${tone}`}>
                    {delta == null ? "— no prior data" : `${sign}${delta}% WoW`}
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      )}

      {brands.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">Unresolved demand by brand (top {brands.length})</h2>
          <div className="overflow-hidden rounded border border-[var(--color-border)] bg-white">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-left text-xs text-[var(--color-muted)]">
                <tr>
                  <th className="px-3 py-2">Brand</th>
                  <th className="px-3 py-2">Signals</th>
                  <th className="px-3 py-2">Unique parts</th>
                  <th className="px-3 py-2">Reporters</th>
                  <th className="px-3 py-2">Last seen</th>
                  <th className="px-3 py-2">Critical</th>
                </tr>
              </thead>
              <tbody>
                {brands.map((b, idx) => (
                  <tr
                    key={`${b.brand ?? "_null"}-${idx}`}
                    className="border-t border-[var(--color-border)]"
                  >
                    <td className="px-3 py-2 font-medium">{b.brand ?? <span className="text-[var(--color-muted)]">(unknown)</span>}</td>
                    <td className="px-3 py-2 tabular-nums">{formatNumber(b.signal_count)}</td>
                    <td className="px-3 py-2 tabular-nums">{formatNumber(b.unique_part_numbers)}</td>
                    <td className="px-3 py-2 tabular-nums">{formatNumber(b.unique_reporters)}</td>
                    <td className="px-3 py-2 text-xs">{formatRelativeTime(b.last_seen)}</td>
                    <td className="px-3 py-2">
                      {b.has_critical ? (
                        <span className="rounded bg-red-100 px-1.5 py-0.5 text-xs text-[var(--color-danger)]">
                          yes
                        </span>
                      ) : (
                        <span className="text-xs text-[var(--color-muted)]">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <ManualEntryForm />

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.group_key}
        emptyMessage="No unresolved demand signals — either every search succeeded or no callers wired record_spare_part_demand_signal yet."
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r571 — v0.5 P3 #2 marketplace seed.</strong>{" "}
        Each row aggregates every &quot;search → 0 results&quot; or &quot;RFQ → no supplier&quot;
        emit for a given (brand, model, part_number). Distinct reporters
        column matters more than raw count — five hospitals searching the
        same part beats one hospital searching five times. Founder
        priority is bulk-applied to every unresolved signal in the group.
        Resolving with{" "}
        <code>supplier_onboarded</code> or <code>bonded_intake</code> closes
        the loop into r500&apos;s bonded-parts provenance ledger. Pending
        signals reflect ~{uniqueReporters} distinct hospital/engineer
        reporters across all groups in view.
      </section>
    </div>
  );
}
