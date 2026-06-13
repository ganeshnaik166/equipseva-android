import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct, formatRelativeTime, formatRupees } from "@/lib/format";

export const metadata = { title: "Engineers — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type LtvRow = {
  engineer_user_id: string;
  engineer_email: string | null;
  first_active_at: string | null;
  total_jobs_completed: number | null;
  total_gross_rupees: number | null;
  total_net_paid_rupees: number | null;
  total_tds_rupees: number | null;
  avg_rating: number | null;
  dispute_count: number | null;
  current_risk_score: number | null;
  risk_band: string | null;
};

export default async function EngineersPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_ltv_ranked", { p_limit: 100 });
  if (error) throw new Error(`founder_engineer_ltv_ranked: ${error.message}`);
  const rows = (data ?? []) as LtvRow[];

  const cols: Column<LtvRow>[] = [
    {
      key: "rank",
      header: "#",
      render: (_r, i) => <span className="text-xs text-[var(--color-muted)]">{i + 1}</span>,
      width: "40px",
    },
    {
      key: "email",
      header: "Engineer",
      render: (r) => (
        <Link
          href={`/engineers/${r.engineer_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {r.engineer_email ?? r.engineer_user_id.slice(0, 8)}
        </Link>
      ),
    },
    {
      key: "first",
      header: "First active",
      render: (r) => formatRelativeTime(r.first_active_at),
    },
    { key: "jobs", header: "Jobs done", render: (r) => formatNumber(r.total_jobs_completed) },
    { key: "gross", header: "Gross", render: (r) => formatRupees(r.total_gross_rupees) },
    { key: "net", header: "Net paid", render: (r) => formatRupees(r.total_net_paid_rupees) },
    { key: "tds", header: "TDS", render: (r) => formatRupees(r.total_tds_rupees) },
    {
      key: "rating",
      header: "Rating",
      render: (r) => (r.avg_rating != null ? `${r.avg_rating.toFixed(2)}★` : "—"),
    },
    {
      key: "disputes",
      header: "Disputes",
      render: (r) => (
        <span className={(r.dispute_count ?? 0) > 0 ? "font-medium text-[var(--color-warn)]" : ""}>
          {formatNumber(r.dispute_count)}
        </span>
      ),
    },
    {
      key: "risk",
      header: "Risk",
      render: (r) => {
        const band = (r.risk_band ?? "").toLowerCase();
        const cls =
          band === "red"
            ? "bg-red-100 text-[var(--color-danger)]"
            : band === "amber" || band === "yellow"
              ? "bg-yellow-100 text-[var(--color-warn)]"
              : "bg-green-100 text-[var(--color-ok)]";
        return (
          <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>
            {r.current_risk_score ?? 0}/{r.risk_band ?? "green"}
          </span>
        );
      },
    },
  ];

  return (
    <div className="space-y-4">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer LTV (ranked)</h1>
        <span className="text-xs text-[var(--color-muted)]">{rows.length} engineers</span>
      </header>
      <p className="text-sm text-[var(--color-muted)]">
        Ranked by total gross earned. Risk score from r498 collusion + reliability signals.
      </p>
      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.engineer_user_id}
        emptyMessage="No engineer LTV rows yet — needs at least one completed job."
      />
    </div>
  );
}
