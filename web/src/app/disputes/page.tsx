import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRelativeTime, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Disputes — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type DisputeRow = {
  id?: string;
  dispute_id?: string;
  hospital_email?: string | null;
  engineer_email?: string | null;
  escrow_amount_rupees?: number | null;
  amount_rupees?: number | null;
  status?: string | null;
  created_at?: string | null;
  repair_job_id?: string | null;
};

export default async function DisputesPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dispute_queue", { p_limit: 50 });
  if (error) {
    throw new Error(`founder_dispute_queue failed: ${error.message}`);
  }
  const rows = (data ?? []) as DisputeRow[];

  const columns: Column<DisputeRow>[] = [
    {
      key: "created",
      header: "Filed",
      render: (r) => (
        <span title={r.created_at ?? ""}>{formatRelativeTime(r.created_at)}</span>
      ),
    },
    {
      key: "hospital",
      header: "Hospital",
      render: (r) => r.hospital_email ?? "—",
    },
    {
      key: "engineer",
      header: "Engineer",
      render: (r) => r.engineer_email ?? "—",
    },
    {
      key: "amount",
      header: "Escrow",
      render: (r) =>
        formatRupees(r.escrow_amount_rupees ?? r.amount_rupees ?? null),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs">
          {r.status ?? "open"}
        </span>
      ),
    },
    {
      key: "job",
      header: "Job",
      render: (r) => (
        <code className="text-xs text-[var(--color-muted)]">
          {shortId(r.repair_job_id ?? r.id ?? r.dispute_id)}
        </code>
      ),
    },
  ];

  return (
    <div className="space-y-4">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dispute queue</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {rows.length} open · founder mediation
        </span>
      </header>
      <p className="text-sm text-[var(--color-muted)]">
        Oldest first. v0 is read-only — decision UI ships in v0.1. For now use
        the Android app to call <code>founder_decide_dispute_pack</code>.
      </p>
      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(r) => (r.id ?? r.dispute_id ?? r.repair_job_id ?? Math.random().toString())}
        emptyMessage="No open disputes."
      />
    </div>
  );
}
