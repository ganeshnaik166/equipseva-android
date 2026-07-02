import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Bid = {
  id: string;
  tender_name: string;
  hospital_org_id: string | null;
  hospital_name: string | null;
  submission_date: string | null;
  bid_amount_rupees: number;
  deadline_date: string | null;
  status: string;
  win_probability_pct: number | null;
  lead_owner_email: string | null;
  created_at: string;
};

type Summary = {
  total_bids: number;
  submitted_bids: number;
  awarded_bids: number;
  lost_bids: number;
  win_rate_pct: number;
  total_award_value_rupees: number;
  avg_bid_rupees: number;
};

type Deadline = {
  id: string;
  tender_name: string;
  hospital_name: string | null;
  deadline_date: string | null;
  days_remaining: number | null;
  bid_amount_rupees: number;
  status: string;
  lead_owner_email: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [bidsRes, summaryRes, deadlinesRes] = await Promise.all([
    sb.rpc('list_tender_bids_r1715'),
    sb.rpc('tender_win_rate_summary_r1715'),
    sb.rpc('tender_upcoming_deadlines_r1715'),
  ]);

  const bids: Bid[] = (bidsRes.data as Bid[]) || [];
  const summaryRow: Summary | null = Array.isArray(summaryRes.data) && summaryRes.data.length > 0
    ? (summaryRes.data[0] as Summary)
    : null;
  const deadlines: Deadline[] = (deadlinesRes.data as Deadline[]) || [];

  const bidColumns: Column<Bid>[] = [
    { key: 'tender_name', header: 'Tender', render: (r: any) => r.tender_name },
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name || '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'bid_amount', header: 'Bid', render: (r: any) => fmtRupees(r.bid_amount_rupees) },
    { key: 'win_prob', header: 'Win %', render: (r: any) => (r.win_probability_pct != null ? r.win_probability_pct + '%' : '-') },
    { key: 'deadline', header: 'Deadline', render: (r: any) => r.deadline_date || '-' },
    { key: 'submission', header: 'Submitted', render: (r: any) => r.submission_date || '-' },
    { key: 'owner', header: 'Owner', render: (r: any) => r.lead_owner_email || '-' },
  ];

  const deadlineColumns: Column<Deadline>[] = [
    { key: 'tender_name', header: 'Tender', render: (r: any) => r.tender_name },
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name || '-' },
    { key: 'deadline', header: 'Deadline', render: (r: any) => r.deadline_date || '-' },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => (r.days_remaining != null ? r.days_remaining : '-') },
    { key: 'amount', header: 'Bid', render: (r: any) => fmtRupees(r.bid_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.lead_owner_email || '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Tender Submissions</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track government and institutional tender bids. Pipeline view, win-rate analytics, and upcoming deadlines &lt;= 30 days.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Win-Rate Summary</h2>
        {summaryRow ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total Bids</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summaryRow.total_bids}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Submitted</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summaryRow.submitted_bids}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Awarded</div>
              <div style={{ fontSize: 22, fontWeight: 700, color: '#059669' }}>{summaryRow.awarded_bids}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Lost</div>
              <div style={{ fontSize: 22, fontWeight: 700, color: '#dc2626' }}>{summaryRow.lost_bids}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Win Rate</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{summaryRow.win_rate_pct}%</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total Award Value</div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(summaryRow.total_award_value_rupees)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Avg Bid</div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtRupees(summaryRow.avg_bid_rupees)}</div>
            </div>
          </div>
        ) : (
          <p style={{ color: '#888' }}>No bids tracked yet.</p>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Upcoming Deadlines</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Active tenders (drafting / submitted / shortlisted) with deadlines &gt;= today.
        </p>
        <DataTable
          rows={deadlines}
          columns={deadlineColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Tender Bids</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Most-recent 200 bids across all hospital orgs. Statuses: drafting &gt; submitted &gt; shortlisted &gt; awarded / lost / withdrawn.
        </p>
        <DataTable
          rows={bids}
          columns={bidColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}