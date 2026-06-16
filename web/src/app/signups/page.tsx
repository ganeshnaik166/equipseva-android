import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  signups: number;
  hospitals: number;
  engineers: number;
};

type ActiveRow = {
  window_label: string;
  total_users: number;
  hospitals: number;
  engineers: number;
  ratio_pct: number;
};

export default async function SignupsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [signupsRes, activeRes] = await Promise.all([
    supabase.rpc("founder_signups_by_day", { p_days: 30 }),
    supabase.rpc("founder_active_users"),
  ]);
  if (signupsRes.error) throw new Error(`founder_signups_by_day: ${signupsRes.error.message}`);

  const rows = (signupsRes.data ?? []) as Row[];
  const activeRows = (activeRes.error ? [] : (activeRes.data ?? [])) as ActiveRow[];
  const total30d = rows.reduce((s, r) => s + (r.signups ?? 0), 0);
  const hospitals30d = rows.reduce((s, r) => s + (r.hospitals ?? 0), 0);
  const engineers30d = rows.reduce((s, r) => s + (r.engineers ?? 0), 0);
  const peakDay = rows.reduce<Row | null>(
    (acc, r) => (acc == null || (r.signups ?? 0) > (acc.signups ?? 0) ? r : acc),
    null,
  );

  // Reverse for table display so newest is on top.
  const tableRows = [...rows].reverse();

  // Simple inline bar chart — proportional to peak.
  const peakValue = Math.max(peakDay?.signups ?? 1, 1);

  const cols: Column<Row>[] = [
    {
      key: "day",
      header: "Day (IST)",
      render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span>,
    },
    {
      key: "bar",
      header: "Bar",
      render: (r) => {
        const pct = ((r.signups ?? 0) / peakValue) * 100;
        return (
          <div className="flex items-center gap-2">
            <div className="h-2 w-24 rounded-full bg-gray-100">
              <div
                className="h-2 rounded-full bg-[var(--color-accent)]"
                style={{ width: `${pct}%` }}
              />
            </div>
            <span className="text-xs tabular-nums">{r.signups}</span>
          </div>
        );
      },
    },
    {
      key: "hospitals",
      header: "Hospitals",
      render: (r) => (
        <span className="text-xs tabular-nums">{formatNumber(r.hospitals)}</span>
      ),
    },
    {
      key: "engineers",
      header: "Engineers",
      render: (r) => (
        <span className="text-xs tabular-nums">{formatNumber(r.engineers)}</span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups by day</h1>
        <span className="text-xs text-[var(--color-muted)]">
          last 30 days · IST day boundaries
        </span>
      </header>

      {activeRows.length > 0 && (
        <section>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Active users (r609)
          </h2>
          <div className="grid grid-cols-3 gap-3">
            {activeRows.map((a) => (
              <div
                key={a.window_label}
                className="rounded border border-[var(--color-border)] bg-white p-3"
              >
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
                  {a.window_label}
                </div>
                <div className="mt-1 text-lg font-semibold tabular-nums">
                  {formatNumber(a.total_users)}
                </div>
                <div className="text-xs text-[var(--color-muted)]">
                  {a.hospitals}H · {a.engineers}E · {a.ratio_pct}% of total
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Total signups (30d)" value={formatNumber(total30d)} />
          <StatCard label="Hospitals (30d)" value={formatNumber(hospitals30d)} />
          <StatCard label="Engineers (30d)" value={formatNumber(engineers30d)} />
          <StatCard
            label="Peak day"
            value={peakDay?.day_ist ?? "—"}
            subtext={peakDay ? `${formatNumber(peakDay.signups)} signups` : undefined}
          />
        </div>
      </section>

      <DataTable
        columns={cols}
        rows={tableRows}
        rowKey={(r) => r.day_ist}
        emptyMessage="No signups in the last 30 days."
      />
    </div>
  );
}
