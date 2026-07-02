import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TermRow = {
  id: string;
  investor_id: string;
  term_sheet_label: string;
  raise_amount_rupees: number;
  valuation_pre_money_rupees: number;
  valuation_post_money_rupees: number;
  liquidation_preference: string;
  anti_dilution: string;
  status: string;
  received_at: string;
};

type TopTermRow = {
  id: string;
  term_sheet_label: string;
  raise_amount_rupees: number;
  valuation_pre_money_rupees: number;
  status: string;
};

type FlaggedClauseRow = {
  id: string;
  ts_id: string;
  term_sheet_label: string;
  clause_type: string;
  clause_md: string;
  recorded_at: string;
};

function rupeesToCrore(n: number): string {
  if (!n) return '0';
  const cr = n / 10000000;
  return cr.toFixed(2) + ' Cr';
}

const termColumns: Column<TermRow>[] = [
  { key: 'term_sheet_label', header: 'Label', render: (r: any) => r.term_sheet_label },
  { key: 'raise_amount_rupees', header: 'Raise', render: (r: any) => rupeesToCrore(r.raise_amount_rupees) },
  { key: 'valuation_pre_money_rupees', header: 'Pre Money', render: (r: any) => rupeesToCrore(r.valuation_pre_money_rupees) },
  { key: 'valuation_post_money_rupees', header: 'Post Money', render: (r: any) => rupeesToCrore(r.valuation_post_money_rupees) },
  { key: 'liquidation_preference', header: 'Liq Pref', render: (r: any) => r.liquidation_preference },
  { key: 'anti_dilution', header: 'Anti Dilution', render: (r: any) => r.anti_dilution },
  { key: 'status', header: 'Status', render: (r: any) => r.status },
  { key: 'received_at', header: 'Received', render: (r: any) => new Date(r.received_at).toLocaleDateString() },
];

const topColumns: Column<TopTermRow>[] = [
  { key: 'term_sheet_label', header: 'Label', render: (r: any) => r.term_sheet_label },
  { key: 'raise_amount_rupees', header: 'Raise', render: (r: any) => rupeesToCrore(r.raise_amount_rupees) },
  { key: 'valuation_pre_money_rupees', header: 'Pre Money Valuation', render: (r: any) => rupeesToCrore(r.valuation_pre_money_rupees) },
  { key: 'status', header: 'Status', render: (r: any) => r.status },
];

const flaggedColumns: Column<FlaggedClauseRow>[] = [
  { key: 'term_sheet_label', header: 'Term Sheet', render: (r: any) => r.term_sheet_label },
  { key: 'clause_type', header: 'Clause Type', render: (r: any) => r.clause_type },
  { key: 'clause_md', header: 'Clause', render: (r: any) => r.clause_md },
  { key: 'recorded_at', header: 'Recorded', render: (r: any) => new Date(r.recorded_at).toLocaleDateString() },
];

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [termsRes, topRes, flaggedRes] = await Promise.all([
    sb.rpc('list_terms_r1925'),
    sb.rpc('top_terms_r1925'),
    sb.rpc('flagged_clauses_r1925'),
  ]);

  const terms: TermRow[] = (termsRes.data as TermRow[]) ?? [];
  const top: TopTermRow[] = (topRes.data as TopTermRow[]) ?? [];
  const flagged: FlaggedClauseRow[] = (flaggedRes.data as FlaggedClauseRow[]) ?? [];

  const accepted = terms.filter((t) => t.status === 'accepted').length;
  const underReview = terms.filter((t) => t.status === 'under_review').length;
  const totalRaise = terms.reduce((a, t) => a + (t.raise_amount_rupees || 0), 0);

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Investor Term Sheet Comparison</h1>
        <p className="text-sm text-gray-600">Compare term sheets across investors. Founder view only.</p>
      </div>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Term Sheets</div>
          <div className="text-2xl font-semibold">{terms.length}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Accepted</div>
          <div className="text-2xl font-semibold">{accepted}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Under Review</div>
          <div className="text-2xl font-semibold">{underReview}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Raise Tracked</div>
          <div className="text-2xl font-semibold">{rupeesToCrore(totalRaise)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Term Sheets</h2>
        <DataTable
          rows={terms}
          columns={termColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Term Sheets by Valuation</h2>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Flagged Clauses</h2>
        <p className="text-sm text-gray-600 mb-2">Clauses marked as flagged for founder attention.</p>
        <DataTable
          rows={flagged}
          columns={flaggedColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
