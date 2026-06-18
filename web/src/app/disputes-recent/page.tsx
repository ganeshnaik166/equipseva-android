import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Disputes recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  repair_job_id: string;
  submitter_name: string;
  status: string;
  submitted_at: string | null;
  mediator_decision_at: string | null;
};

export default async function DisputesRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_disputes_recent");
  if (error) throw new Error(`founder_disputes_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Submitted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.submitted_at ? new Date(r.submitted_at).toLocaleString() : "—"}</span> },
    { key: "n", header: "Submitter", render: (r) => <span className="text-xs font-semibold">{r.submitter_name}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "accepted" ? "text-[var(--color-ok)]"
          : r.status === "rejected" ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "d", header: "Decided", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.mediator_decision_at ? new Date(r.mediator_decision_at).toLocaleString() : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Disputes recent (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 dispute evidence packs</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No disputes." />
    </div>
  );
}
