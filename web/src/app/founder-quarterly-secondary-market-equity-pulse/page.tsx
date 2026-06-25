import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_requests: number;
  approved_requests: number;
  open_requests: number;
  closed_requests: number;
  total_shares_offered: number;
  weighted_avg_price: number;
  latest_valuation_crores: number;
  approval_rate_pct: number;
};

type QuarterRow = {
  quarter_label: string;
  request_count: number;
  shares_total: number;
  avg_implied_valuation: number;
  approved_count: number;
};

type SellerMixRow = {
  seller_type: string;
  request_count: number;
  shares_total: number;
  avg_ask_price: number;
};

type ValuationRow = {
  recorded_at: string;
  quarter_label: string;
  signal_source: string;
  signal_valuation_crores: number;
  confidence_pct: number;
  market_regime: string;
  founder_call: string;
};

type OpenTenderRow = {
  id: number;
  quarter_label: string;
  seller_party: string;
  seller_type: string;
  shares_offered: number;
  ask_price_per_share_rupees: number;
  implied_valuation_crores: number;
  signal_strength: string;
  founder_decision: string;
  days_open: number;
};

type DecisionRow = {
  founder_decision: string;
  request_count: number;
  shares_total: number;
  share_of_total_pct: number;
};

type SourceRow = {
  source_channel: string;
  request_count: number;
  approved_count: number;
  shares_total: number;
  approval_rate_pct: number;
};

type SignalRow = {
  signal_strength: string;
  request_count: number;
  avg_implied_valuation: number;
  approved_count: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    quarterRes,
    sellerRes,
    valuationRes,
    openRes,
    decisionRes,
    sourceRes,
    signalRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2761_quarterly_kpis'),
    supabase.rpc('founder_r2761_requests_by_quarter'),
    supabase.rpc('founder_r2761_seller_type_mix'),
    supabase.rpc('founder_r2761_valuation_timeline'),
    supabase.rpc('founder_r2761_open_tenders'),
    supabase.rpc('founder_r2761_decision_distribution'),
    supabase.rpc('founder_r2761_source_channel_breakdown'),
    supabase.rpc('founder_r2761_signal_strength_heatmap'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const quarters: QuarterRow[] = (quarterRes.data as QuarterRow[]) ?? [];
  const sellers: SellerMixRow[] = (sellerRes.data as SellerMixRow[]) ?? [];
  const valuations: ValuationRow[] = (valuationRes.data as ValuationRow[]) ?? [];
  const openTenders: OpenTenderRow[] = (openRes.data as OpenTenderRow[]) ?? [];
  const decisions: DecisionRow[] = (decisionRes.data as DecisionRow[]) ?? [];
  const sources: SourceRow[] = (sourceRes.data as SourceRow[]) ?? [];
  const signals: SignalRow[] = (signalRes.data as SignalRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Quarterly Secondary Market Equity Pulse</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track secondary market share-sale requests, tenders, valuations, sources, closes, signals & founder decisions across quarters.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Total Requests</div>
          <div className="text-2xl font-bold mt-1">{kpi?.total_requests ?? 0}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Approved</div>
          <div className="text-2xl font-bold mt-1 text-green-700">{kpi?.approved_requests ?? 0}</div>
          <div className="text-xs text-gray-500 mt-1">{kpi?.approval_rate_pct ?? 0}% approval rate</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Open Tenders</div>
          <div className="text-2xl font-bold mt-1 text-amber-700">{kpi?.open_requests ?? 0}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Closed</div>
          <div className="text-2xl font-bold mt-1">{kpi?.closed_requests ?? 0}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Total Shares Offered</div>
          <div className="text-2xl font-bold mt-1">{(kpi?.total_shares_offered ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Weighted Avg Price</div>
          <div className="text-2xl font-bold mt-1">₹{(kpi?.weighted_avg_price ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Latest Valuation</div>
          <div className="text-2xl font-bold mt-1">₹{kpi?.latest_valuation_crores ?? 0} Cr</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase">Signals Tracked</div>
          <div className="text-2xl font-bold mt-1">{valuations.length}</div>
        </div>
      </div>

      <section className="bg-white border rounded-lg p-4">
        <h2 className="text-lg font-semibold mb-3">Open Tenders Awaiting Action</h2>
        <DataTable
          rows={openTenders}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: OpenTenderRow) => r.quarter_label },
            { key: 'seller_party', header: 'Seller', render: (r: OpenTenderRow) => r.seller_party },
            { key: 'seller_type', header: 'Type', render: (r: OpenTenderRow) => r.seller_type },
            { key: 'shares_offered', header: 'Shares', render: (r: OpenTenderRow) => r.shares_offered.toLocaleString('en-IN') },
            { key: 'ask_price_per_share_rupees', header: 'Ask ₹/sh', render: (r: OpenTenderRow) => `₹${r.ask_price_per_share_rupees}` },
            { key: 'implied_valuation_crores', header: 'Implied Cr', render: (r: OpenTenderRow) => `₹${r.implied_valuation_crores} Cr` },
            { key: 'signal_strength', header: 'Signal', render: (r: OpenTenderRow) => r.signal_strength },
            { key: 'founder_decision', header: 'Decision', render: (r: OpenTenderRow) => r.founder_decision },
            { key: 'days_open', header: 'Days Open', render: (r: OpenTenderRow) => r.days_open },
          ]}
          emptyMessage="No open tenders"
          rowKey={(r: OpenTenderRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="bg-white border rounded-lg p-4">
        <h2 className="text-lg font-semibold mb-3">Requests by Quarter</h2>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: QuarterRow) => r.quarter_label },
            { key: 'request_count', header: 'Requests', render: (r: QuarterRow) => r.request_count },
            { key: 'shares_total', header: 'Shares', render: (r: QuarterRow) => r.shares_total.toLocaleString('en-IN') },
            { key: 'avg_implied_valuation', header: 'Avg Val Cr', render: (r: QuarterRow) => `₹${r.avg_implied_valuation} Cr` },
            { key: 'approved_count', header: 'Approved', render: (r: QuarterRow) => r.approved_count },
          ]}
          emptyMessage="No quarterly data"
          rowKey={(r: QuarterRow, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section className="bg-white border rounded-lg p-4">
        <h2 className="text-lg font-semibold mb-3">Seller Type Mix</h2>
        <DataTable
          rows={sellers}
          columns={[
            { key: 'seller_type', header: 'Seller Type', render: (r: SellerMixRow) => r.seller_type },
            { key: 'request_count', header: 'Requests', render: (r: SellerMixRow) => r.request_count },
            { key: 'shares_total', header: 'Shares', render: (r: SellerMixRow) => r.shares_total.toLocaleString('en-IN') },
            { key: 'avg_ask_price', header: 'Avg Ask ₹/sh', render: (r: SellerMixRow) => `₹${r.avg_ask_price}` },
          ]}
          emptyMessage="No seller data"
          rowKey={(r: SellerMixRow, i: number) => String(r.seller_type ?? i)}
        />
      </section>

      <section className="bg-white border rounded-lg p-4">
        <h2 className="text-lg font-semibold mb-3">Valuation Signal Timeline</h2>
        <DataTable
          rows={valuations}
          columns={[
            { key: 'recorded_at', header: 'Recorded', render: (r: ValuationRow) => r.recorded_at },
            { key: 'quarter_label', header: 'Quarter', render: (r: ValuationRow) => r.quarter_label },
            { key: 'signal_source', header: 'Source', render: (r: ValuationRow) => r.signal_source },
            { key: 'signal_valuation_crores', header: 'Valuation Cr', render: (r: ValuationRow) => `₹${r.signal_valuation_crores} Cr` },
            { key: 'confidence_pct', header: 'Confidence %', render: (r: ValuationRow) => `${r.confidence_pct}%` },
            { key: 'market_regime', header: 'Regime', render: (r: ValuationRow) => r.market_regime },
            { key: 'founder_call', header: 'Founder Call', render: (r: ValuationRow) => r.founder_call },
          ]}
          emptyMessage="No valuation signals"
          rowKey={(r: ValuationRow, i: number) => String(`${r.recorded_at}-${r.signal_source}` ?? i)}
        />
      </section>

      <section className="bg-white border rounded-lg p-4">
        <h2 className="text-lg font-semibold mb-3">Founder Decision Distribution</h2>
        <DataTable
          rows={decisions}
          columns={[
            { key: 'founder_decision', header: 'Decision', render: (r: DecisionRow) => r.founder_decision },
            { key: 'request_count', header: 'Requests', render: (r: DecisionRow) => r.request_count },
            { key: 'shares_total', header: 'Shares', render: (r: DecisionRow) => r.shares_total.toLocaleString('en-IN') },
            { key: 'share_of_total_pct', header: 'Share %', render: (r: DecisionRow) => `${r.share_of_total_pct}%` },
          ]}
          emptyMessage="No decision data"
          rowKey={(r: DecisionRow, i: number) => String(r.founder_decision ?? i)}
        />
      </section>

      <section className="bg-white border rounded-lg p-4">
        <h2 className="text-lg font-semibold mb-3">Source Channel Breakdown</h2>
        <DataTable
          rows={sources}
          columns={[
            { key: 'source_channel', header: 'Channel', render: (r: SourceRow) => r.source_channel },
            { key: 'request_count', header: 'Requests', render: (r: SourceRow) => r.request_count },
            { key: 'approved_count', header: 'Approved', render: (r: SourceRow) => r.approved_count },
            { key: 'shares_total', header: 'Shares', render: (r: SourceRow) => r.shares_total.toLocaleString('en-IN') },
            { key: 'approval_rate_pct', header: 'Approval %', render: (r: SourceRow) => `${r.approval_rate_pct}%` },
          ]}
          emptyMessage="No channel data"
          rowKey={(r: SourceRow, i: number) => String(r.source_channel ?? i)}
        />
      </section>

      <section className="bg-white border rounded-lg p-4">
        <h2 className="text-lg font-semibold mb-3">Signal Strength Heatmap</h2>
        <DataTable
          rows={signals}
          columns={[
            { key: 'signal_strength', header: 'Signal', render: (r: SignalRow) => r.signal_strength },
            { key: 'request_count', header: 'Requests', render: (r: SignalRow) => r.request_count },
            { key: 'avg_implied_valuation', header: 'Avg Val Cr', render: (r: SignalRow) => `₹${r.avg_implied_valuation} Cr` },
            { key: 'approved_count', header: 'Approved', render: (r: SignalRow) => r.approved_count },
          ]}
          emptyMessage="No signal data"
          rowKey={(r: SignalRow, i: number) => String(r.signal_strength ?? i)}
        />
      </section>
    </div>
  );
}
