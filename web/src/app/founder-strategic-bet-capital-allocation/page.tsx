import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import { redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

const FOUNDER_EMAIL = 'marketingtools@getphyllo.com';

function rupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user || user.email !== FOUNDER_EMAIL) redirect('/login');

  const [bets, summary, byCategory, topBets, redeploy, events, efficiency] = await Promise.all([
    supabase.rpc('fsbca_r2369_list_bets'),
    supabase.rpc('fsbca_r2369_summary'),
    supabase.rpc('fsbca_r2369_by_category'),
    supabase.rpc('fsbca_r2369_top_bets', { p_limit: 10 }),
    supabase.rpc('fsbca_r2369_redeployment_candidates'),
    supabase.rpc('fsbca_r2369_recent_events', { p_limit: 50 }),
    supabase.rpc('fsbca_r2369_capital_efficiency'),
  ]);

  const s = (summary.data && summary.data[0]) || {};

  const betCols: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r) => r.bet_name },
    { key: 'bet_category', header: 'Category', render: (r) => r.bet_category },
    { key: 'bet_status', header: 'Status', render: (r) => r.bet_status },
    { key: 'capital_deployed_rupees', header: 'Deployed', render: (r) => rupees(r.capital_deployed_rupees) },
    { key: 'revenue_generated_rupees', header: 'Revenue', render: (r) => rupees(r.revenue_generated_rupees) },
    { key: 'gross_margin_rupees', header: 'Margin', render: (r) => rupees(r.gross_margin_rupees) },
    { key: 'roi_percent', header: 'ROI', render: (r) => pct(r.roi_percent) },
    { key: 'payback_months', header: 'Payback (mo)', render: (r) => r.payback_months ?? '-' },
  ];

  const catCols: Column<any>[] = [
    { key: 'bet_category', header: 'Category', render: (r) => r.bet_category },
    { key: 'bet_count', header: 'Bets', render: (r) => r.bet_count },
    { key: 'total_deployed', header: 'Deployed', render: (r) => rupees(r.total_deployed) },
    { key: 'total_revenue', header: 'Revenue', render: (r) => rupees(r.total_revenue) },
    { key: 'avg_roi', header: 'Avg ROI', render: (r) => pct(r.avg_roi) },
  ];

  const evCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r) => new Date(r.recorded_at).toLocaleString() },
    { key: 'bet_name', header: 'Bet', render: (r) => r.bet_name },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'amount_rupees', header: 'Amount', render: (r) => rupees(r.amount_rupees) },
    { key: 'event_note', header: 'Note', render: (r) => r.event_note ?? '-' },
  ];

  const effCols: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r) => r.bet_name },
    { key: 'capital_deployed_rupees', header: 'Deployed', render: (r) => rupees(r.capital_deployed_rupees) },
    { key: 'revenue_generated_rupees', header: 'Revenue', render: (r) => rupees(r.revenue_generated_rupees) },
    { key: 'efficiency_ratio', header: 'Rev/Capital', render: (r) => Number(r.efficiency_ratio ?? 0).toFixed(2) + 'x' },
    { key: 'payback_months', header: 'Payback (mo)', render: (r) => r.payback_months ?? '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, marginBottom: 8 }}>Strategic-Bet Capital Allocation</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Capital flowing into each strategic bet, return on capital & redeployment decisions.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Total Bets</div>
          <div style={{ fontSize: 24, fontWeight: 600 }}>{s.total_bets ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Active</div>
          <div style={{ fontSize: 24, fontWeight: 600 }}>{s.active_bets ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Capital Deployed</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{rupees(s.total_deployed)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Revenue Generated</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{rupees(s.total_revenue)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Margin</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{rupees(s.total_margin)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Avg ROI</div>
          <div style={{ fontSize: 24, fontWeight: 600 }}>{pct(s.avg_roi)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Best ROI</div>
          <div style={{ fontSize: 24, fontWeight: 600, color: '#16a34a' }}>{pct(s.best_roi)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Worst ROI</div>
          <div style={{ fontSize: 24, fontWeight: 600, color: '#dc2626' }}>{pct(s.worst_roi)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>All Bets (sorted by ROI)</h2>
        <DataTable
          rows={bets.data ?? []}
          columns={betCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No bets recorded yet"
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>By Category</h2>
        <DataTable
          rows={byCategory.data ?? []}
          columns={catCols}
          rowKey={(r: any) => r.bet_category}
          emptyMessage="No category data"
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Top 10 Bets</h2>
        <DataTable
          rows={topBets.data ?? []}
          columns={betCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No top bets"
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Redeployment Candidates</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Bets pausing, killing, or with ROI &lt; 0 — candidates for capital redeployment.
        </p>
        <DataTable
          rows={redeploy.data ?? []}
          columns={betCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No redeployment candidates"
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Capital Efficiency</h2>
        <DataTable
          rows={efficiency.data ?? []}
          columns={effCols}
          rowKey={(r: any) => r.bet_id}
          emptyMessage="No efficiency data"
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Recent Capital Events</h2>
        <DataTable
          rows={events.data ?? []}
          columns={evCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No events recorded"
        />
      </section>
    </main>
  );
}
