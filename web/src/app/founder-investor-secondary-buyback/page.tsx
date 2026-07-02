import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string | number };

export const dynamic = 'force-dynamic';

export default async function FounderInvestorSecondaryBuybackPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let rounds: any[] = [];
  let offers: any[] = [];
  let pending: any[] = [];
  let breakdown: any[] = [];

  try {
    const r = await sb.rpc('founder_buyback_kpis');
    kpis = r.data ?? {};
  } catch {
    kpis = {};
  }
  try {
    const r = await sb.rpc('founder_buyback_rounds_list');
    rounds = (r.data as any[]) ?? [];
  } catch {
    rounds = [];
  }
  try {
    const r = await sb.rpc('founder_buyback_offers_recent');
    offers = (r.data as any[]) ?? [];
  } catch {
    offers = [];
  }
  try {
    const r = await sb.rpc('founder_buyback_pending_responses');
    pending = (r.data as any[]) ?? [];
  } catch {
    pending = [];
  }
  try {
    const r = await sb.rpc('founder_buyback_round_breakdown');
    breakdown = (r.data as any[]) ?? [];
  } catch {
    breakdown = [];
  }

  const cards: Kpi[] = [
    { label: 'Rounds total', value: kpis.rounds_total ?? 0 },
    { label: 'Rounds open', value: kpis.rounds_open ?? 0 },
    { label: 'Rounds consolidating', value: kpis.rounds_consolidating ?? 0 },
    { label: 'Rounds approved', value: kpis.rounds_approved ?? 0 },
    { label: 'Rounds closed', value: kpis.rounds_closed ?? 0 },
    { label: 'Offers total', value: kpis.offers_total ?? 0 },
    { label: 'Offers sent', value: kpis.offers_sent ?? 0 },
    { label: 'Offers accepted', value: kpis.offers_accepted ?? 0 },
    { label: 'Offers declined', value: kpis.offers_declined ?? 0 },
    { label: 'Offers countered', value: kpis.offers_countered ?? 0 },
    { label: 'Offers expired', value: kpis.offers_expired ?? 0 },
    { label: 'Offers consolidated', value: kpis.offers_consolidated ?? 0 },
    { label: 'Shares accepted', value: kpis.shares_accepted ?? 0 },
    { label: 'Rupees committed', value: kpis.rupees_committed ?? 0 },
    { label: 'Avg offer price', value: kpis.avg_offer_price ?? 0 },
    { label: 'Budget envelope', value: kpis.budget_total ?? 0 },
  ];

  const roundCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'target_consolidation_pct', header: 'Target %', render: (r: any) => r.target_consolidation_pct ?? '—' },
    { key: 'ceiling_price_per_share_rupees', header: 'Ceiling/share', render: (r: any) => r.ceiling_price_per_share_rupees ?? '—' },
    { key: 'budget_envelope_rupees', header: 'Budget', render: (r: any) => r.budget_envelope_rupees ?? '—' },
    { key: 'offers_count', header: 'Offers', render: (r: any) => r.offers_count ?? 0 },
    { key: 'accepted_count', header: 'Accepted', render: (r: any) => r.accepted_count ?? 0 },
    { key: 'committed_rupees', header: 'Committed', render: (r: any) => r.committed_rupees ?? 0 },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ?? '—' },
  ];

  const offerCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label ?? '—' },
    { key: 'shareholder_name', header: 'Shareholder', render: (r: any) => r.shareholder_name ?? '—' },
    { key: 'shareholder_email', header: 'Email', render: (r: any) => r.shareholder_email ?? '—' },
    { key: 'shares_offered', header: 'Shares', render: (r: any) => r.shares_offered ?? 0 },
    { key: 'offered_price_per_share_rupees', header: 'Price/share', render: (r: any) => r.offered_price_per_share_rupees ?? '—' },
    { key: 'total_offer_rupees', header: 'Total', render: (r: any) => r.total_offer_rupees ?? 0 },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ?? '—' },
    { key: 'responded_at', header: 'Responded', render: (r: any) => r.responded_at ?? '—' },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label ?? '—' },
    { key: 'shareholder_name', header: 'Shareholder', render: (r: any) => r.shareholder_name ?? '—' },
    { key: 'shareholder_email', header: 'Email', render: (r: any) => r.shareholder_email ?? '—' },
    { key: 'shares_offered', header: 'Shares', render: (r: any) => r.shares_offered ?? 0 },
    { key: 'offered_price_per_share_rupees', header: 'Price/share', render: (r: any) => r.offered_price_per_share_rupees ?? '—' },
    { key: 'total_offer_rupees', header: 'Total', render: (r: any) => r.total_offer_rupees ?? 0 },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ?? '—' },
    { key: 'days_outstanding', header: 'Days out', render: (r: any) => r.days_outstanding ?? 0 },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'sent_count', header: 'Sent', render: (r: any) => r.sent_count ?? 0 },
    { key: 'accepted_count', header: 'Accepted', render: (r: any) => r.accepted_count ?? 0 },
    { key: 'declined_count', header: 'Declined', render: (r: any) => r.declined_count ?? 0 },
    { key: 'countered_count', header: 'Countered', render: (r: any) => r.countered_count ?? 0 },
    { key: 'total_committed_rupees', header: 'Committed', render: (r: any) => r.total_committed_rupees ?? 0 },
    { key: 'budget_envelope_rupees', header: 'Budget', render: (r: any) => r.budget_envelope_rupees ?? '—' },
    { key: 'headroom_rupees', header: 'Headroom', render: (r: any) => r.headroom_rupees ?? 0 },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Investor Secondary Buyback Offers</h1>
        <p className="text-sm text-gray-600">
          Outbound offers to existing shareholders. Per-offer price and status. Founder approves consolidation.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((k) => (
          <div key={k.label} className="border rounded p-3 bg-white">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-xl font-semibold">{String(k.value)}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Buyback rounds</h2>
        <DataTable columns={roundCols} rows={rounds} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent offers</h2>
        <DataTable columns={offerCols} rows={offers} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending responses</h2>
        <DataTable columns={pendingCols} rows={pending} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Round breakdown</h2>
        <DataTable columns={breakdownCols} rows={breakdown} rowKey={(r: any) => r.round_label} />
      </section>
    </div>
  );
}
