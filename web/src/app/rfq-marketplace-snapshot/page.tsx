import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "RFQ marketplace snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_rfqs_all_time: number;
  distinct_requester_orgs: number;
  total_rfq_bids: number;
  accepted_rfq_bids: number;
  bid_acceptance_rate_pct: number;
  rfqs_with_bids: number;
  rfqs_with_zero_bids: number;
  avg_bids_per_rfq: number;
  distinct_bidding_manufacturers: number;
  total_bid_value_rupees: number;
  rental_listings_total: number;
  rental_owner_orgs: number;
  marketplace_listings_total: number;
  financing_applications_total: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function RfqMarketplaceSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_rfq_marketplace_snapshot_summary");
  if (error) throw new Error(`founder_rfq_marketplace_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">RFQ marketplace snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI marketplace pulse · RFQs + bids + rentals + financing + listings · TAM expansion visibility</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total RFQs all-time" val={formatNumber(r.total_rfqs_all_time)} />
          <Card title="Distinct requester orgs" val={formatNumber(r.distinct_requester_orgs)} sub="hospital demand breadth" />
          <Card title="Total RFQ bids" val={formatNumber(r.total_rfq_bids)} />
          <Card title="Accepted bids" val={formatNumber(r.accepted_rfq_bids)} ok sub="conversion signal" />
          <Card title="Bid acceptance rate" val={`${Number(r.bid_acceptance_rate_pct).toFixed(1)}%`} sub="accepted / total bids" />
          <Card title="RFQs with bids" val={formatNumber(r.rfqs_with_bids)} ok sub="engagement" />
          <Card title="RFQs zero bids" val={formatNumber(r.rfqs_with_zero_bids)} danger={r.rfqs_with_zero_bids > 0} sub="dead listings" />
          <Card title="Avg bids per RFQ" val={Number(r.avg_bids_per_rfq).toFixed(2)} />
          <Card title="Bidding manufacturers" val={formatNumber(r.distinct_bidding_manufacturers)} sub="supply breadth" />
          <Card title="Total bid value" val={inr(r.total_bid_value_rupees)} sub="cumulative GMV pipeline" />
          <Card title="Rental listings" val={formatNumber(r.rental_listings_total)} />
          <Card title="Rental owner orgs" val={formatNumber(r.rental_owner_orgs)} sub="rental supply" />
          <Card title="Marketplace listings" val={formatNumber(r.marketplace_listings_total)} />
          <Card title="Financing applications" val={formatNumber(r.financing_applications_total)} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
