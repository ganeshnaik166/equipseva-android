import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct, formatRupees } from "@/lib/format";

export const metadata = { title: "Verticals — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type VerticalRow = {
  equipment_type: string;
  job_count: number | null;
  gmv_rupees: number | null;
  avg_ticket_rupees: number | null;
  dispute_count: number | null;
  dispute_rate_pct: number | null;
};

export default async function VerticalsPage({
  searchParams,
}: {
  searchParams?: Promise<{ days?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const days = Math.max(7, Math.min(180, Number.parseInt(params.days ?? "30", 10) || 30));

  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_gmv_by_equipment_type", {
    p_days: days,
  });
  if (error) throw new Error(`founder_gmv_by_equipment_type: ${error.message}`);
  const rows = (data ?? []) as VerticalRow[];

  const totalGmv = rows.reduce((s, r) => s + (r.gmv_rupees ?? 0), 0);
  const totalJobs = rows.reduce((s, r) => s + (r.job_count ?? 0), 0);

  const cols: Column<VerticalRow>[] = [
    { key: "type", header: "Equipment", render: (r) => r.equipment_type },
    { key: "jobs", header: "Jobs", render: (r) => formatNumber(r.job_count) },
    { key: "gmv", header: "GMV", render: (r) => formatRupees(r.gmv_rupees) },
    {
      key: "share",
      header: "% of total GMV",
      render: (r) =>
        formatPct(totalGmv > 0 ? ((r.gmv_rupees ?? 0) / totalGmv) * 100 : 0),
    },
    {
      key: "avg",
      header: "Avg ticket",
      render: (r) => formatRupees(r.avg_ticket_rupees),
    },
    {
      key: "disp",
      header: "Disputes",
      render: (r) => (
        <span>
          {formatNumber(r.dispute_count)}{" "}
          <span
            className={
              (r.dispute_rate_pct ?? 0) > 10
                ? "text-[var(--color-danger)]"
                : (r.dispute_rate_pct ?? 0) > 5
                  ? "text-[var(--color-warn)]"
                  : "text-[var(--color-muted)]"
            }
          >
            ({formatPct(r.dispute_rate_pct)})
          </span>
        </span>
      ),
    },
  ];

  const WINDOWS = [7, 30, 90];

  return (
    <div className="space-y-4">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Verticals — equipment-type breakdown</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {formatRupees(totalGmv)} GMV · {formatNumber(totalJobs)} jobs · last {days}d
        </span>
      </header>

      <nav className="flex gap-2 text-sm">
        {WINDOWS.map((d) => (
          <a
            key={d}
            href={`/verticals?days=${d}`}
            className={`rounded border px-2 py-1 ${
              d === days
                ? "border-[var(--color-fg)] bg-[var(--color-fg)] text-white"
                : "border-[var(--color-border)] hover:bg-gray-50"
            }`}
          >
            {d}d
          </a>
        ))}
      </nav>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.equipment_type}
        emptyMessage={`No completed jobs in the last ${days} days.`}
      />
    </div>
  );
}
