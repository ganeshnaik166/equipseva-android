import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { PayoutActions } from "./PayoutActions";

export const metadata = { title: "Engineer payouts — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type PayoutRow = {
  id: string;
  repair_job_id: string | null;
  job_number: string | null;
  engineer_user_id: string;
  engineer_name: string | null;
  engineer_phone: string | null;
  amount_paise: number | null;
  status: string;
  mode: string | null;
  utr: string | null;
  failure_reason: string | null;
  destination_label: string | null;
  attempts: number | null;
  queued_at: string | null;
  processed_at: string | null;
};

type DeadLetterRow = {
  category: string;
  count_rows: number | null;
  total_paise: number | null;
};

export default async function PayoutsPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const status = params.status ?? "queued";

  const supabase = await getSupabaseServerClient();
  const [listRes, deadRes] = await Promise.all([
    supabase.rpc("admin_list_engineer_payouts", { p_status: status, p_limit: 200 }),
    supabase.rpc("founder_payouts_dead_letter_summary"),
  ]);
  if (listRes.error) throw new Error(`admin_list_engineer_payouts: ${listRes.error.message}`);
  // dead letter is best-effort — empty if RPC absent or empty
  const rows = (listRes.data ?? []) as PayoutRow[];
  const dead = (deadRes.error ? [] : (deadRes.data ?? [])) as DeadLetterRow[];

  const cols: Column<PayoutRow>[] = [
    {
      key: "queued",
      header: "Queued",
      render: (r) => (
        <Link
          href={`/payouts/${r.id}`}
          title={r.queued_at ?? ""}
          className="text-[var(--color-accent)] hover:underline"
        >
          {formatRelativeTime(r.queued_at)}
        </Link>
      ),
    },
    {
      key: "engineer",
      header: "Engineer",
      render: (r) => (
        <span>
          {r.engineer_name ?? shortId(r.engineer_user_id)}{" "}
          {r.engineer_phone && (
            <span className="text-xs text-[var(--color-muted)]">{r.engineer_phone}</span>
          )}
        </span>
      ),
    },
    {
      key: "job",
      header: "Job",
      render: (r) =>
        r.repair_job_id ? (
          <Link
            href={`/jobs/${r.repair_job_id}`}
            className="font-mono text-xs text-[var(--color-accent)] hover:underline"
          >
            {r.job_number ?? shortId(r.repair_job_id)}
          </Link>
        ) : (
          <span className="text-xs">—</span>
        ),
    },
    {
      key: "amount",
      header: "Amount",
      render: (r) => formatRupees(r.amount_paise != null ? r.amount_paise / 100 : null),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const s = r.status.toLowerCase();
        const cls =
          s === "paid" || s === "processed" || s === "completed"
            ? "bg-green-100 text-[var(--color-ok)]"
            : s === "failed" || s === "cancelled"
              ? "bg-red-100 text-[var(--color-danger)]"
              : s === "queued" || s === "pending"
                ? "bg-yellow-100 text-[var(--color-warn)]"
                : "bg-gray-100";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status}</span>;
      },
    },
    {
      key: "dest",
      header: "Destination",
      render: (r) => <span className="text-xs">{r.destination_label ?? "—"}</span>,
    },
    {
      key: "attempts",
      header: "Attempts",
      render: (r) => formatNumber(r.attempts),
    },
    {
      key: "failure",
      header: "Last failure",
      render: (r) => (
        <span className="text-xs text-[var(--color-danger)]">{r.failure_reason ?? ""}</span>
      ),
    },
    {
      key: "act",
      header: "Action",
      render: (r) => <PayoutActions payoutId={r.id} status={r.status} />,
    },
  ];

  const STATUSES = ["queued", "failed", "paid", "cancelled"];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Engineer payouts</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Cashfree-backed engineer payout queue from r428. Status tabs filter; founder actions
          write to founder_action_log + payout_admin_events ledger.
        </p>
      </header>

      <nav className="flex gap-2 text-sm">
        {STATUSES.map((s) => (
          <a
            key={s}
            href={`/payouts?status=${s}`}
            className={`rounded border px-2 py-1 ${
              s === status
                ? "border-[var(--color-fg)] bg-[var(--color-fg)] text-white"
                : "border-[var(--color-border)] hover:bg-gray-50"
            }`}
          >
            {s}
          </a>
        ))}
      </nav>

      {dead.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">Dead-letter summary</h2>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {dead.map((d) => (
              <div
                key={d.category}
                className="rounded border border-[var(--color-border)] bg-white p-3"
              >
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
                  {d.category}
                </div>
                <div className="mt-1 text-lg font-semibold tabular-nums">
                  {formatNumber(d.count_rows)}{" "}
                  <span className="text-xs font-normal text-[var(--color-muted)]">
                    · {formatRupees(d.total_paise != null ? d.total_paise / 100 : null)}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        emptyMessage={`No payouts with status="${status}".`}
      />
    </div>
  );
}
