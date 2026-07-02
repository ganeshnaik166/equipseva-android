import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Opportunity = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  current_state: string;
  suggested_offer: string;
  expected_arr_lift_rupees: number;
  owner_email: string | null;
  status: string;
  last_outreach_at: string | null;
  outreach_count: number;
  created_at: string;
};

type PipelineRow = {
  status: string;
  opp_count: number;
  total_arr_lift_rupees: number;
};

type ConversionRow = {
  suggested_offer: string;
  total_opps: number;
  won_count: number;
  lost_count: number;
  open_count: number;
  pitched_count: number;
  win_rate_pct: number | null;
  total_arr_won_rupees: number;
};

function formatRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function formatDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [oppsRes, pipelineRes, conversionRes] = await Promise.all([
    sb.rpc('list_cross_sell_opportunities_r1695'),
    sb.rpc('total_cross_sell_arr_lift_pipeline_r1695'),
    sb.rpc('cross_sell_conversion_by_offer_r1695'),
  ]);

  const opps: Opportunity[] = (oppsRes.data as Opportunity[] | null) ?? [];
  const pipeline: PipelineRow[] = (pipelineRes.data as PipelineRow[] | null) ?? [];
  const conversion: ConversionRow[] = (conversionRes.data as ConversionRow[] | null) ?? [];

  const totalOpenArrLift = pipeline
    .filter((p) => p.status === 'open' || p.status === 'pitched')
    .reduce((s, p) => s + Number(p.total_arr_lift_rupees || 0), 0);
  const totalWonArr = pipeline
    .filter((p) => p.status === 'won')
    .reduce((s, p) => s + Number(p.total_arr_lift_rupees || 0), 0);

  const oppColumns: Column<Opportunity>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id.slice(0, 8) },
    { key: 'current_state', header: 'Current State', render: (r: any) => r.current_state },
    { key: 'suggested_offer', header: 'Suggested Offer', render: (r: any) => r.suggested_offer },
    { key: 'expected_arr_lift_rupees', header: 'ARR Lift', render: (r: any) => formatRupees(r.expected_arr_lift_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outreach_count', header: 'Outreach', render: (r: any) => String(r.outreach_count ?? 0) },
    { key: 'last_outreach_at', header: 'Last Outreach', render: (r: any) => formatDate(r.last_outreach_at) },
    { key: 'created_at', header: 'Created', render: (r: any) => formatDate(r.created_at) },
  ];

  const pipelineColumns: Column<PipelineRow>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'opp_count', header: 'Count', render: (r: any) => String(r.opp_count) },
    { key: 'total_arr_lift_rupees', header: 'Total ARR Lift', render: (r: any) => formatRupees(r.total_arr_lift_rupees) },
  ];

  const conversionColumns: Column<ConversionRow>[] = [
    { key: 'suggested_offer', header: 'Offer', render: (r: any) => r.suggested_offer },
    { key: 'total_opps', header: 'Total', render: (r: any) => String(r.total_opps) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
    { key: 'pitched_count', header: 'Pitched', render: (r: any) => String(r.pitched_count) },
    { key: 'won_count', header: 'Won', render: (r: any) => String(r.won_count) },
    { key: 'lost_count', header: 'Lost', render: (r: any) => String(r.lost_count) },
    { key: 'win_rate_pct', header: 'Win Rate %', render: (r: any) => r.win_rate_pct == null ? '-' : String(r.win_rate_pct) + '%' },
    { key: 'total_arr_won_rupees', header: 'ARR Won', render: (r: any) => formatRupees(r.total_arr_won_rupees) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Cross-Sell Opportunities</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Repair-only hospitals to AMC. Single-equipment to multi. Track outreach, conversion, ARR lift.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pipeline Summary</h2>
        <div style={{ display: 'flex', gap: 16, marginBottom: 16, flexWrap: 'wrap' }}>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, minWidth: 200 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Open + Pitched ARR Lift</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{formatRupees(totalOpenArrLift)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, minWidth: 200 }}>
            <div style={{ fontSize: 12, color: '#666' }}>ARR Won</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{formatRupees(totalWonArr)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, minWidth: 200 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Opportunities</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{opps.length}</div>
          </div>
        </div>
        <DataTable rows={pipeline} columns={pipelineColumns} rowKey={(r, i) => String((r as any).status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Conversion by Offer</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Win rate = won / (won + lost). Higher win rate &gt;= 50% means offer resonates.
        </p>
        <DataTable rows={conversion} columns={conversionColumns} rowKey={(r, i) => String((r as any).suggested_offer ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Opportunities</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Ordered by status (open first), then expected ARR lift &gt; recent.
        </p>
        <DataTable rows={opps} columns={oppColumns} rowKey={(r, i) => String((r as any).id ?? i)} />
      </section>
    </main>
  );
}
