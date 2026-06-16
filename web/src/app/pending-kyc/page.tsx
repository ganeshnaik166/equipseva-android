import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Pending KYC — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { engineer_id: string; user_id: string; display_name: string; city: string | null; created_at: string; days_waiting: number; status: string };

export default async function PendingKycPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_pending_kyc_list");
  if (error) throw new Error(`founder_pending_kyc_list: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.city ?? "—"}</span> },
    { key: "t", header: "Signed up", render: (r) => <span className="text-xs">{new Date(r.created_at).toLocaleDateString("en-IN")}</span> },
    { key: "d", header: "Waiting",
      render: (r) => {
        const tone = r.days_waiting > 14 ? "text-[var(--color-danger)]"
          : r.days_waiting > 7 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.days_waiting)}d</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Pending KYC</h1>
        <span className="text-xs text-[var(--color-muted)]">verification queue · oldest-first</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Pending count" value={formatNumber(rows.length)} tone={rows.length > 0 ? "warn" : "ok"} />
          <StatCard label="Aged >7d" value={formatNumber(rows.filter((r) => r.days_waiting > 7).length)} tone="warn" />
          <StatCard label="Aged >14d" value={formatNumber(rows.filter((r) => r.days_waiting > 14).length)} tone="danger" />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_id} emptyMessage="No pending KYC." />
    </div>
  );
}
