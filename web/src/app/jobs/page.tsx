import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Jobs — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type JobRow = {
  id: string;
  job_number?: string | null;
  hospital_user_id: string;
  status: string;
  urgency?: string | null;
  equipment_type?: string | null;
  brand?: string | null;
  model?: string | null;
  estimated_cost_rupees?: number | null;
  contracted_amount_rupees?: number | null;
  created_at: string;
  completed_at?: string | null;
};

const STATUS_TONE: Record<string, string> = {
  open: "bg-yellow-100 text-[var(--color-warn)]",
  bidding: "bg-yellow-100 text-[var(--color-warn)]",
  accepted: "bg-blue-100",
  in_progress: "bg-blue-100",
  completed: "bg-green-100 text-[var(--color-ok)]",
  cancelled: "bg-gray-100",
  withdrawn: "bg-gray-100",
};

const STATUSES = [
  "all",
  "open",
  "bidding",
  "accepted",
  "in_progress",
  "completed",
  "cancelled",
  "withdrawn",
];

export default async function JobsPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string; q?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const statusFilter = params.status ?? "all";
  const search = (params.q ?? "").trim();

  const supabase = await getSupabaseServerClient();

  // Generous SELECT — different migration generations have added
  // different columns. Project a wide set and let unknown columns
  // surface as null.
  let query = supabase
    .from("repair_jobs")
    .select(
      "id, job_number, hospital_user_id, status, urgency, equipment_type, brand, model, estimated_cost_rupees, contracted_amount_rupees, created_at, completed_at",
    )
    .order("created_at", { ascending: false })
    .limit(200);

  if (statusFilter !== "all") {
    query = query.eq("status", statusFilter);
  }
  if (search.length > 0) {
    // Founder may paste a job_number (free text), a UUID prefix, or
    // a partial brand/model string. Use a single .or() across the
    // text columns.
    const safe = search.replace(/[%_]/g, "");
    const ilike = `%${safe}%`;
    query = query.or(
      `job_number.ilike.${ilike},equipment_type.ilike.${ilike},brand.ilike.${ilike},model.ilike.${ilike}`,
    );
  }

  const { data, error } = await query;
  if (error) throw new Error(`repair_jobs: ${error.message}`);
  const rows = (data ?? []) as JobRow[];

  // Status-class totals shown above the filter tabs.
  const totalCount = rows.length;
  const openCount = rows.filter(
    (r) => !["completed", "cancelled", "withdrawn"].includes(r.status),
  ).length;
  const completedCount = rows.filter((r) => r.status === "completed").length;
  const recentGmv = rows
    .filter((r) => r.status === "completed")
    .reduce((s, r) => s + (r.contracted_amount_rupees ?? r.estimated_cost_rupees ?? 0), 0);

  const cols: Column<JobRow>[] = [
    {
      key: "id",
      header: "Job",
      render: (r) => (
        <Link
          href={`/jobs/${r.id}`}
          className="font-mono text-xs text-[var(--color-accent)] hover:underline"
        >
          {r.job_number ?? shortId(r.id)}
        </Link>
      ),
    },
    {
      key: "when",
      header: "Created",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    {
      key: "hospital",
      header: "Hospital",
      render: (r) => (
        <Link
          href={`/hospitals/${r.hospital_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {shortId(r.hospital_user_id)}
        </Link>
      ),
    },
    {
      key: "equipment",
      header: "Equipment",
      render: (r) => (
        <span className="text-xs">
          {r.equipment_type ?? "—"}{" "}
          {(r.brand || r.model) && (
            <span className="text-[var(--color-muted)]">
              · {[r.brand, r.model].filter(Boolean).join(" ")}
            </span>
          )}
        </span>
      ),
    },
    {
      key: "amount",
      header: "Amount",
      render: (r) =>
        formatRupees(r.contracted_amount_rupees ?? r.estimated_cost_rupees ?? null),
    },
    {
      key: "urgency",
      header: "Urgency",
      render: (r) => (
        <span className="text-xs text-[var(--color-muted)]">{r.urgency ?? "—"}</span>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${STATUS_TONE[r.status] ?? "bg-gray-100"}`}
        >
          {r.status}
        </span>
      ),
    },
    {
      key: "completed",
      header: "Completed",
      render: (r) => formatRelativeTime(r.completed_at ?? null),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs</h1>
        <span className="text-xs text-[var(--color-muted)]">
          showing {totalCount} of last 200 ·{" "}
          {search ? <span>search &ldquo;{search}&rdquo;</span> : <span>{statusFilter}</span>}
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="In view" value={formatNumber(totalCount)} />
          <StatCard
            label="Open / active"
            value={formatNumber(openCount)}
            tone={openCount > 0 ? "warn" : "ok"}
          />
          <StatCard label="Completed (in view)" value={formatNumber(completedCount)} />
          <StatCard
            label="GMV (completed in view)"
            value={formatRupees(recentGmv)}
          />
        </div>
      </section>

      <form className="flex flex-wrap items-end gap-3 rounded border border-[var(--color-border)] bg-white p-3 text-sm">
        <label className="block">
          <span className="text-xs text-[var(--color-muted)]">Search</span>
          <input
            type="text"
            name="q"
            defaultValue={search}
            placeholder="job_number / equipment / brand / model"
            className="mt-1 w-72 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          />
        </label>
        <input type="hidden" name="status" value={statusFilter} />
        <button
          type="submit"
          className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm font-medium text-white"
        >
          Filter
        </button>
        {(search || statusFilter !== "all") && (
          <a
            href="/jobs"
            className="rounded border border-[var(--color-border)] px-3 py-1 text-sm hover:bg-gray-50"
          >
            Clear
          </a>
        )}
      </form>

      <nav className="flex flex-wrap gap-2 text-sm">
        {STATUSES.map((s) => (
          <a
            key={s}
            href={`/jobs?status=${s}${search ? `&q=${encodeURIComponent(search)}` : ""}`}
            className={`rounded border px-2 py-1 ${
              s === statusFilter
                ? "border-[var(--color-fg)] bg-[var(--color-fg)] text-white"
                : "border-[var(--color-border)] hover:bg-gray-50"
            }`}
          >
            {s}
          </a>
        ))}
      </nav>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        emptyMessage={
          search
            ? `No jobs matching "${search}".`
            : statusFilter === "all"
              ? "No jobs in the last 200 rows."
              : `No jobs with status="${statusFilter}".`
        }
      />
    </div>
  );
}
