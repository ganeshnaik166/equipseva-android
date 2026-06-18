import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referrals ROI — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; bounties_paid_rupees: number; referee_gross_rupees: number; roi_multiple: number };

export default async function ReferralsRoiPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referrals_roi");
  if (error) throw new Error(`founder_referrals_roi: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "b", header: "Bounties paid (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.bounties_paid_rupees)}</span> },
    { key: "g", header: "Referee gross (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.referee_gross_rupees)}</span> },
    { key: "r", header: "ROI ×",
      render: (r) => {
        const tone = r.roi_multiple >= 10 ? "text-[var(--color-ok)]"
          : r.roi_multiple >= 3 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.roi_multiple}×</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referrals ROI</h1>
        <span className="text-xs text-[var(--color-muted)]">Referee completed-job gross / bounty paid · cohorts by referral date</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No referral activity." />
    </div>
  );
}
