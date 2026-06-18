import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "KYC pending detail — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { user_id: string; display_name: string; state: string; city: string; verification_status: string; signup_at: string; days_pending: number };

export default async function KycPendingDetailPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_kyc_pending_detail");
  if (error) throw new Error(`founder_kyc_pending_detail: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "d", header: "Days pending",
      render: (r) => {
        const tone = r.days_pending > 7 ? "text-[var(--color-danger)]"
          : r.days_pending > 3 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.days_pending}</span>;
      }
    },
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "v", header: "Status",
      render: (r) => {
        const tone = r.verification_status === "rejected" ? "text-[var(--color-danger)]"
          : r.verification_status === "in_review" ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.verification_status}</span>;
      }
    },
    { key: "a", header: "Signed up", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.signup_at).toLocaleString()}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">KYC pending detail</h1>
        <span className="text-xs text-[var(--color-muted)]">{rows.length} engineers awaiting verification · oldest first</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.user_id} emptyMessage="No KYC backlog." />
    </div>
  );
}
