import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { RefundActions } from "./RefundActions";

export const metadata = { title: "Refund authorizations — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type RefundRow = {
  id: string;
  source_kind: string | null;
  source_id: string | null;
  amount_rupees: number | null;
  reason: string | null;
  requested_by: string | null;
  requester_email: string | null;
  expires_at: string | null;
  created_at: string;
};

export default async function RefundsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_pending_refund_authorizations", {
    p_limit: 50,
  });
  if (error) throw new Error(`founder_pending_refund_authorizations: ${error.message}`);
  const rows = (data ?? []) as RefundRow[];

  const cols: Column<RefundRow>[] = [
    {
      key: "created",
      header: "Requested",
      render: (r) => (
        <Link
          href={`/refunds/${r.id}`}
          title={r.created_at}
          className="text-[var(--color-accent)] hover:underline"
        >
          {formatRelativeTime(r.created_at)}
        </Link>
      ),
    },
    {
      key: "expires",
      header: "Expires",
      render: (r) => {
        const txt = formatRelativeTime(r.expires_at);
        const expired = r.expires_at != null && new Date(r.expires_at).getTime() < Date.now();
        return (
          <span className={expired ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]"}>
            {txt}
          </span>
        );
      },
    },
    { key: "amount", header: "Amount", render: (r) => formatRupees(r.amount_rupees) },
    { key: "source", header: "Source", render: (r) => `${r.source_kind ?? "—"} · ${shortId(r.source_id)}` },
    { key: "reason", header: "Reason", render: (r) => <span className="text-xs">{r.reason ?? "—"}</span> },
    { key: "by", header: "Requested by", render: (r) => r.requester_email ?? shortId(r.requested_by) },
    {
      key: "act",
      header: "Action",
      render: (r) => <RefundActions requestId={r.id} />,
    },
  ];

  return (
    <div className="space-y-4">
      <header>
        <h1 className="text-xl font-semibold">
          Pending refund authorizations{" "}
          <span className="text-[var(--color-muted)]">({rows.length})</span>
        </h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Threshold-gated refunds from r488. Auto-expire 7 days after creation. Approve writes to
          founder_action_log for forensic trail.
        </p>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No pending refunds." />
    </div>
  );
}
