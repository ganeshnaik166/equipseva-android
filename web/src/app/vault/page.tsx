import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { PackActions } from "./PackActions";

export const metadata = { title: "Dispute vault — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type PackRow = {
  id: string;
  repair_job_escrow_id: string;
  repair_job_id: string;
  filed_by_user_id: string;
  filer_role: string;
  position_statement: string;
  evidence_ledger_ids: string[] | null;
  dsr_id: string | null;
  pved_id: string | null;
  evidence_count: number | null;
  total_money_at_stake_rupees: number | null;
  status: string;
  submitted_at: string | null;
  mediator_user_id: string | null;
  mediator_decision_at: string | null;
  mediator_note: string | null;
  created_at: string;
};

export default async function VaultPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const statusFilter = params.status ?? "submitted";

  const supabase = await getSupabaseServerClient();
  let query = supabase
    .from("dispute_evidence_packs")
    .select(
      "id, repair_job_escrow_id, repair_job_id, filed_by_user_id, filer_role, position_statement, evidence_ledger_ids, dsr_id, pved_id, evidence_count, total_money_at_stake_rupees, status, submitted_at, mediator_user_id, mediator_decision_at, mediator_note, created_at",
    )
    .order("submitted_at", { ascending: false, nullsFirst: false })
    .limit(100);
  if (statusFilter !== "all") {
    query = query.eq("status", statusFilter);
  }

  const { data, error } = await query;
  if (error) throw new Error(`dispute_evidence_packs: ${error.message}`);
  const rows = (data ?? []) as PackRow[];

  const totalAtStake = rows
    .filter((r) => r.status === "submitted")
    .reduce((s, r) => s + Number(r.total_money_at_stake_rupees ?? 0), 0);
  const oldestSubmitted = rows
    .filter((r) => r.status === "submitted" && r.submitted_at != null)
    .reduce<string | null>((oldest, r) => {
      if (!r.submitted_at) return oldest;
      if (!oldest || r.submitted_at < oldest) return r.submitted_at;
      return oldest;
    }, null);

  const STATUSES = ["submitted", "accepted", "rejected", "withdrawn", "draft", "all"];

  const cols: Column<PackRow>[] = [
    {
      key: "submitted",
      header: "Submitted",
      render: (r) => (
        <span title={r.submitted_at ?? r.created_at}>
          {formatRelativeTime(r.submitted_at ?? r.created_at)}
        </span>
      ),
    },
    {
      key: "role",
      header: "Filer",
      render: (r) => (
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${
            r.filer_role === "engineer"
              ? "bg-blue-100"
              : "bg-purple-100"
          }`}
        >
          {r.filer_role}
        </span>
      ),
    },
    {
      key: "job",
      header: "Job",
      render: (r) => (
        <code className="text-xs">{shortId(r.repair_job_id)}</code>
      ),
    },
    {
      key: "escrow",
      header: "Escrow",
      render: (r) => (
        <code className="text-xs text-[var(--color-muted)]">
          {shortId(r.repair_job_escrow_id)}
        </code>
      ),
    },
    {
      key: "stake",
      header: "Money at stake",
      render: (r) => formatRupees(r.total_money_at_stake_rupees),
    },
    {
      key: "evidence",
      header: "Evidence",
      render: (r) => (
        <span>
          {formatNumber(r.evidence_count)}{" "}
          {r.dsr_id && (
            <span className="rounded bg-gray-100 px-1 text-[10px]" title={r.dsr_id}>
              DSR
            </span>
          )}{" "}
          {r.pved_id && (
            <span className="rounded bg-gray-100 px-1 text-[10px]" title={r.pved_id}>
              PVED
            </span>
          )}
        </span>
      ),
    },
    {
      key: "position",
      header: "Position",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">
            read
          </summary>
          <p className="mt-1 max-w-md whitespace-pre-wrap text-xs">
            {r.position_statement}
          </p>
        </details>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const cls =
          r.status === "submitted"
            ? "bg-yellow-100 text-[var(--color-warn)]"
            : r.status === "accepted"
              ? "bg-green-100 text-[var(--color-ok)]"
              : r.status === "rejected"
                ? "bg-red-100 text-[var(--color-danger)]"
                : "bg-gray-100";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status}</span>;
      },
    },
    {
      key: "act",
      header: "Action",
      render: (r) =>
        r.status === "submitted" ? (
          <PackActions packId={r.id} />
        ) : (
          <span className="text-xs text-[var(--color-muted)]">
            {r.mediator_note ? "decided" : "—"}
          </span>
        ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dispute evidence vault</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {rows.length} pack{rows.length === 1 ? "" : "s"} ({statusFilter})
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Submitted packs"
            value={formatNumber(
              rows.filter((r) => r.status === "submitted").length,
            )}
            tone={rows.some((r) => r.status === "submitted") ? "warn" : "ok"}
          />
          <StatCard
            label="Money at stake"
            value={formatRupees(totalAtStake)}
          />
          <StatCard
            label="Oldest submitted"
            value={formatRelativeTime(oldestSubmitted)}
            tone={
              oldestSubmitted != null &&
              Date.now() - new Date(oldestSubmitted).getTime() > 7 * 86400 * 1000
                ? "danger"
                : "warn"
            }
          />
          <StatCard
            label="View"
            value={statusFilter}
            subtext="status filter"
          />
        </div>
      </section>

      <nav className="flex flex-wrap gap-2 text-sm">
        {STATUSES.map((s) => (
          <a
            key={s}
            href={`/vault?status=${s}`}
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
          statusFilter === "submitted"
            ? "No packs awaiting mediation. Good."
            : `No packs with status="${statusFilter}".`
        }
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Mediator decision writes <code>founder_decide_dispute_pack</code> which appends
        an audit-log row + sets <code>mediator_user_id</code> +{" "}
        <code>mediator_decision_at</code>. Accepted packs feed the escrow split
        downstream (the actual money move uses the existing escrow release path).
      </section>
    </div>
  );
}
