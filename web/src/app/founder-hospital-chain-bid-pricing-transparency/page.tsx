import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type BidRow = {
  id: string;
  chain_user_id: string;
  chain_email: string | null;
  tender_ref: string;
  tender_title: string;
  tender_region: string | null;
  category: string;
  closed_at: string;
  won: boolean;
  our_bid_rupees: number;
  winning_competitor_bid_rupees: number | null;
  competitor_name: string | null;
  our_estimated_cost_rupees: number;
  margin_pct: number | null;
  delta_to_competitor_rupees: number | null;
  delta_to_competitor_pct: number | null;
  bid_source: string | null;
  intel_confidence: string | null;
  recorded_by_email: string | null;
  recorded_at: string;
  note_count: number;
};

type ThinRow = {
  id: string;
  chain_email: string | null;
  tender_ref: string;
  tender_title: string;
  category: string;
  our_bid_rupees: number;
  our_estimated_cost_rupees: number;
  margin_pct: number | null;
  closed_at: string;
};

type DeltaRow = {
  id: string;
  tender_ref: string;
  tender_title: string;
  competitor_name: string | null;
  our_bid_rupees: number;
  winning_competitor_bid_rupees: number;
  delta_rupees: number;
  delta_pct: number | null;
  intel_confidence: string | null;
  closed_at: string;
};

type RollupRow = {
  category: string;
  bid_count: number;
  total_value_rupees: number;
  avg_margin_pct: number | null;
  min_margin_pct: number | null;
  max_margin_pct: number | null;
};

function fmtRupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [bidsRes, thinRes, deltaRes, rollupRes] = await Promise.all([
    supabase.rpc('list_chain_tender_bids_r2359'),
    supabase.rpc('thinnest_margin_chain_bids_r2359'),
    supabase.rpc('closest_competitor_deltas_r2359'),
    supabase.rpc('category_margin_rollup_r2359'),
  ]);

  const bids: BidRow[] = (bidsRes.data as BidRow[] | null) ?? [];
  const thin: ThinRow[] = (thinRes.data as ThinRow[] | null) ?? [];
  const deltas: DeltaRow[] = (deltaRes.data as DeltaRow[] | null) ?? [];
  const rollup: RollupRow[] = (rollupRes.data as RollupRow[] | null) ?? [];

  const bidCols: Column<any>[] = [
    { key: 'closed_at', header: 'Closed', render: (r: BidRow) => new Date(r.closed_at).toLocaleDateString() },
    { key: 'tender_ref', header: 'Tender Ref', render: (r: BidRow) => r.tender_ref },
    { key: 'tender_title', header: 'Title', render: (r: BidRow) => r.tender_title },
    { key: 'chain_email', header: 'Chain', render: (r: BidRow) => r.chain_email ?? '—' },
    { key: 'category', header: 'Category', render: (r: BidRow) => r.category },
    { key: 'tender_region', header: 'Region', render: (r: BidRow) => r.tender_region ?? '—' },
    { key: 'our_bid_rupees', header: 'Our Bid', render: (r: BidRow) => fmtRupees(r.our_bid_rupees) },
    { key: 'winning_competitor_bid_rupees', header: 'Competitor Bid', render: (r: BidRow) => fmtRupees(r.winning_competitor_bid_rupees) },
    { key: 'competitor_name', header: 'Competitor', render: (r: BidRow) => r.competitor_name ?? '—' },
    { key: 'delta_to_competitor_pct', header: 'Delta %', render: (r: BidRow) => fmtPct(r.delta_to_competitor_pct) },
    { key: 'margin_pct', header: 'Margin %', render: (r: BidRow) => fmtPct(r.margin_pct) },
    { key: 'intel_confidence', header: 'Intel', render: (r: BidRow) => r.intel_confidence ?? '—' },
    { key: 'bid_source', header: 'Source', render: (r: BidRow) => r.bid_source ?? '—' },
    { key: 'note_count', header: 'Notes', render: (r: BidRow) => String(r.note_count) },
  ];

  const thinCols: Column<any>[] = [
    { key: 'closed_at', header: 'Closed', render: (r: ThinRow) => new Date(r.closed_at).toLocaleDateString() },
    { key: 'tender_ref', header: 'Tender', render: (r: ThinRow) => r.tender_ref },
    { key: 'tender_title', header: 'Title', render: (r: ThinRow) => r.tender_title },
    { key: 'chain_email', header: 'Chain', render: (r: ThinRow) => r.chain_email ?? '—' },
    { key: 'category', header: 'Category', render: (r: ThinRow) => r.category },
    { key: 'our_bid_rupees', header: 'Our Bid', render: (r: ThinRow) => fmtRupees(r.our_bid_rupees) },
    { key: 'our_estimated_cost_rupees', header: 'Est Cost', render: (r: ThinRow) => fmtRupees(r.our_estimated_cost_rupees) },
    { key: 'margin_pct', header: 'Margin %', render: (r: ThinRow) => fmtPct(r.margin_pct) },
  ];

  const deltaCols: Column<any>[] = [
    { key: 'closed_at', header: 'Closed', render: (r: DeltaRow) => new Date(r.closed_at).toLocaleDateString() },
    { key: 'tender_ref', header: 'Tender', render: (r: DeltaRow) => r.tender_ref },
    { key: 'tender_title', header: 'Title', render: (r: DeltaRow) => r.tender_title },
    { key: 'competitor_name', header: 'Competitor', render: (r: DeltaRow) => r.competitor_name ?? '—' },
    { key: 'our_bid_rupees', header: 'Our Bid', render: (r: DeltaRow) => fmtRupees(r.our_bid_rupees) },
    { key: 'winning_competitor_bid_rupees', header: 'Competitor Bid', render: (r: DeltaRow) => fmtRupees(r.winning_competitor_bid_rupees) },
    { key: 'delta_rupees', header: 'Delta', render: (r: DeltaRow) => fmtRupees(r.delta_rupees) },
    { key: 'delta_pct', header: 'Delta %', render: (r: DeltaRow) => fmtPct(r.delta_pct) },
    { key: 'intel_confidence', header: 'Intel', render: (r: DeltaRow) => r.intel_confidence ?? '—' },
  ];

  const rollupCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: RollupRow) => r.category },
    { key: 'bid_count', header: 'Bids Won', render: (r: RollupRow) => String(r.bid_count) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: RollupRow) => fmtRupees(r.total_value_rupees) },
    { key: 'avg_margin_pct', header: 'Avg Margin', render: (r: RollupRow) => fmtPct(r.avg_margin_pct) },
    { key: 'min_margin_pct', header: 'Min Margin', render: (r: RollupRow) => fmtPct(r.min_margin_pct) },
    { key: 'max_margin_pct', header: 'Max Margin', render: (r: RollupRow) => fmtPct(r.max_margin_pct) },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 600 }}>Hospital Chain Bid-Pricing Transparency</h1>
      <p style={{ color: '#666', marginTop: 4 }}>
        For tenders we won &gt;&gt; our bid vs winning competitor bid (where known) &amp; margin notes.
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Category margin rollup</h2>
        <DataTable
          rows={rollup}
          emptyMessage="No won bids on file yet."
          rowKey={(r: RollupRow) => r.category}
          columns={rollupCols}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Thinnest-margin won bids (top 25)</h2>
        <DataTable
          rows={thin}
          emptyMessage="No thin-margin wins."
          rowKey={(r: ThinRow) => r.id}
          columns={thinCols}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Closest competitor deltas (we barely won)</h2>
        <DataTable
          rows={deltas}
          emptyMessage="No competitor-disclosed deltas yet."
          rowKey={(r: DeltaRow) => r.id}
          columns={deltaCols}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All bids on record</h2>
        <DataTable
          rows={bids}
          emptyMessage="No bids recorded yet."
          rowKey={(r: BidRow) => r.id}
          columns={bidCols}
        />
      </section>
    </main>
  );
}
