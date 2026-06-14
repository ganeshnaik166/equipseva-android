import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime } from "@/lib/format";
import { ResolveButton } from "./ResolveButton";
import { PriorityPicker } from "./PriorityPicker";

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
  const { data, error } = await supabase.rpc("founder_demand_signal_dashboard");
  if (error) throw new Error(`founder_demand_signal_dashboard: ${error.message}`);

  const rows = (data ?? []) as DashRow[];
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
