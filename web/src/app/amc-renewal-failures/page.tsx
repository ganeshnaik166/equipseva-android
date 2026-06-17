import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC renewal failures — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  amc_contract_id: string;
  hospital_user_id: string;
  display_name: string;
  city: string;
  monthly_fee_rupees: number;
  end_date: string;
  days_since_end: number;
  last_attempt_at: string | null;
  last_error: string | null;
};

export default async function AmcRenewalFailuresPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_failures_list");
  if (error) throw new Error(`founder_amc_renewal_failures_list: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.city}</span> },
    { key: "m", header: "MRR (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.monthly_fee_rupees)}</span> },
    { key: "e", header: "End date", render: (r) => <span className="text-xs tabular-nums">{r.end_date}</span> },
    { key: "d", header: "Days since end",
      render: (r) => {
        const tone = r.days_since_end > 60 ? "text-[var(--color-danger)]"
          : r.days_since_end > 30 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.days_since_end}</span>;
      }
    },
    { key: "x", header: "Last error", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.last_error?.slice(0,60) ?? "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal failures</h1>
        <span className="text-xs text-[var(--color-muted)]">renewal_failed contracts · outreach queue</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.amc_contract_id} emptyMessage="No renewal failures." />
    </div>
  );
}
