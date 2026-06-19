import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Promo redemptions summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  promo_code: string;
  total_redemptions: number;
  redeemed_count: number;
  reserved_count: number;
  revoked_count: number;
  expired_count: number;
  unique_hospitals: number;
  total_subsidy_rupees: number;
  avg_subsidy_rupees: number;
  max_subsidy_rupees: number;
  redemptions_last_7d: number;
  redemptions_last_30d: number;
  subsidy_last_30d_rupees: number;
  first_redeemed_at: string | null;
  last_redeemed_at: string | null;
  pct_revoked: number;
};

function fmtDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toISOString().slice(0, 10);
}

export default async function PromoRedemptionsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_promo_redemptions_summary");
  if (error) throw new Error(`founder_promo_redemptions_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];

  const grandSubsidy = rows.reduce((a, r) => a + Number(r.total_subsidy_rupees ?? 0), 0);
  const grandRedemptions = rows.reduce((a, r) => a + Number(r.total_redemptions ?? 0), 0);
  const grandHospitals = rows.reduce((a, r) => a + Number(r.unique_hospitals ?? 0), 0);
  const grandLast30dSubsidy = rows.reduce((a, r) => a + Number(r.subsidy_last_30d_rupees ?? 0), 0);

  const cols: Column<Row>[] = [
    { key: "code", header: "Promo code", render: (r) => <span className="text-xs font-mono font-medium">{r.promo_code}</span> },
    { key: "total", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_redemptions)}</span> },
    { key: "redeemed", header: "Redeemed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.redeemed_count)}</span> },
    { key: "revoked", header: "Revoked", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.revoked_count)}</span> },
    { key: "pctrev", header: "% revoked", render: (r) => <span className="text-xs tabular-nums">{Number(r.pct_revoked).toFixed(2)}%</span> },
    { key: "hosp", header: "Unique hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.unique_hospitals)}</span> },
    { key: "subs", header: "Subsidy ₹", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_subsidy_rupees))}</span> },
    { key: "avg", header: "Avg ₹", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.avg_subsidy_rupees))}</span> },
    { key: "max", header: "Max ₹", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.max_subsidy_rupees))}</span> },
    { key: "d7", header: "Last 7d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.redemptions_last_7d)}</span> },
    { key: "d30", header: "Last 30d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.redemptions_last_30d)}</span> },
    { key: "subs30", header: "₹ last 30d", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.subsidy_last_30d_rupees))}</span> },
    { key: "first", header: "First", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{fmtDate(r.first_redeemed_at)}</span> },
    { key: "last", header: "Last", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{fmtDate(r.last_redeemed_at)}</span> },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Promo redemptions summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {formatNumber(grandRedemptions)} redemptions · {formatNumber(grandHospitals)} hospitals · subsidy: <span className="font-mono tabular-nums">{formatRupees(grandSubsidy)}</span> · 30d: <span className="font-mono tabular-nums">{formatRupees(grandLast30dSubsidy)}</span> · CAC lever
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.promo_code} emptyMessage="No promo redemptions yet." />
    </div>
  );
}
