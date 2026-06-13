import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { FunnelBars, type FunnelDatum } from "@/components/charts/FunnelBars";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Funnel — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type FunnelRow = {
  ordinal: number;
  event_key: string;
  step_label: string;
  unique_users: number | null;
  conversion_pct: number | null;
};

type TopEventRow = {
  event_key: string;
  event_count: number | null;
  unique_users: number | null;
};

const FUNNELS: { key: string; label: string }[] = [
  { key: "hospital_first_repair", label: "Hospital — first repair" },
  { key: "engineer_first_bid", label: "Engineer — first bid" },
  { key: "amc_signup", label: "AMC signup" },
];

export default async function FunnelPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [funnelResults, topRes] = await Promise.all([
    Promise.all(
      FUNNELS.map((f) =>
        supabase
          .rpc("founder_funnel_conversion", { p_funnel_key: f.key, p_days: 30 })
          .then((res) => ({ key: f.key, label: f.label, ...res })),
      ),
    ),
    supabase.rpc("founder_top_events", { p_days: 7, p_limit: 30 }),
  ]);

  if (topRes.error) throw new Error(`founder_top_events: ${topRes.error.message}`);
  const topEvents = (topRes.data ?? []) as TopEventRow[];

  const funnelCols: Column<FunnelRow>[] = [
    { key: "step", header: "#", render: (r) => `Step ${r.ordinal}`, width: "70px" },
    { key: "label", header: "Step", render: (r) => r.step_label },
    {
      key: "event",
      header: "Event key",
      render: (r) => <code className="text-xs text-[var(--color-muted)]">{r.event_key}</code>,
    },
    {
      key: "users",
      header: "Unique users (30d)",
      render: (r) => formatNumber(r.unique_users),
    },
    {
      key: "pct",
      header: "Conversion from step 1",
      render: (r) => (
        <span className="font-medium tabular-nums">{formatPct(r.conversion_pct)}</span>
      ),
    },
  ];

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-xl font-semibold">Funnel conversion (last 30 days)</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          From the self-hosted analytics ledger (r510). Step-1 is the denominator; later steps show
          % retained.
        </p>
      </header>

      {funnelResults.map((f) => {
        const rows = (f.error ? [] : (f.data ?? [])) as FunnelRow[];
        return (
          <section key={f.key}>
            <h2 className="mb-2 text-sm font-semibold">{f.label}</h2>
            {f.error ? (
              <div className="rounded border border-[var(--color-danger)] bg-red-50 p-3 text-sm text-[var(--color-danger)]">
                {f.error.message}
              </div>
            ) : (
              <div className="grid gap-4 lg:grid-cols-[1fr_1fr]">
                <div className="rounded border border-[var(--color-border)] bg-white p-3">
                  <FunnelBars data={rows as FunnelDatum[]} />
                </div>
                <DataTable
                  columns={funnelCols}
                  rows={rows}
                  rowKey={(r) => `${f.key}-${r.ordinal}`}
                  emptyMessage="No events recorded yet — funnel will fill in as r513/r516 events fire from clients."
                />
              </div>
            )}
          </section>
        );
      })}

      <section>
        <h2 className="mb-2 text-sm font-semibold">Top events — last 7 days</h2>
        <DataTable
          columns={[
            {
              key: "event",
              header: "Event key",
              render: (r: TopEventRow) => (
                <code className="text-xs">{r.event_key}</code>
              ),
            },
            { key: "count", header: "Events", render: (r) => formatNumber(r.event_count) },
            { key: "users", header: "Unique users", render: (r) => formatNumber(r.unique_users) },
          ]}
          rows={topEvents}
          rowKey={(r) => r.event_key}
          emptyMessage="No events in last 7 days."
        />
      </section>
    </div>
  );
}
