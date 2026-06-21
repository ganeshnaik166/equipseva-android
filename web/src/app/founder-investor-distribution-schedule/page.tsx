import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Distribution = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  scheduled_date: string;
  distribution_type: string;
  scheduled_amount_rupees: number;
  actual_amount_rupees: number | null;
  status: string;
  paid_at: string | null;
  notes: string | null;
  created_at: string;
};

type Comm = {
  id: string;
  distribution_id: string;
  comm_type: string;
  sent_at: string;
  by_email: string | null;
  message_summary: string;
};

type Summary = {
  total_scheduled: number;
  total_paid: number;
  total_deferred: number;
  total_cancelled: number;
  scheduled_amount_rupees: number;
  paid_amount_rupees: number;
};

type Upcoming = {
  id: string;
  investor_id: string;
  investor_email: string | null;
  scheduled_date: string;
  distribution_type: string;
  scheduled_amount_rupees: number;
  status: string;
  days_until: number;
};

function fmtRupees(v: number | null | undefined): string {
  if (v == null) return '—';
  return '₹' + (v / 100).toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

function fmtDate(v: string | null | undefined): string {
  if (!v) return '—';
  return new Date(v).toLocaleDateString('en-IN');
}

function fmtDateTime(v: string | null | undefined): string {
  if (!v) return '—';
  return new Date(v).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [distRes, commRes, sumRes, upcomingRes] = await Promise.all([
    sb.rpc('list_distributions_r1745', { p_limit: 100 }),
    sb.rpc('list_comms_r1745', { p_limit: 100 }),
    sb.rpc('distribution_summary_r1745'),
    sb.rpc('upcoming_distributions_r1745', { p_days: 90 }),
  ]);

  const distributions: Distribution[] = (distRes.data as Distribution[]) || [];
  const comms: Comm[] = (commRes.data as Comm[]) || [];
  const summary: Summary = ((sumRes.data as Summary[]) || [])[0] || {
    total_scheduled: 0,
    total_paid: 0,
    total_deferred: 0,
    total_cancelled: 0,
    scheduled_amount_rupees: 0,
    paid_amount_rupees: 0,
  };
  const upcoming: Upcoming[] = (upcomingRes.data as Upcoming[]) || [];

  const distColumns: Column<Distribution>[] = [
    { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_date) },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email || r.investor_id?.slice(0, 8) },
    { key: 'distribution_type', header: 'Type', render: (r: any) => r.distribution_type },
    { key: 'scheduled_amount_rupees', header: 'Scheduled', render: (r: any) => fmtRupees(r.scheduled_amount_rupees) },
    { key: 'actual_amount_rupees', header: 'Actual', render: (r: any) => fmtRupees(r.actual_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'paid_at', header: 'Paid', render: (r: any) => fmtDateTime(r.paid_at) },
  ];

  const commColumns: Column<Comm>[] = [
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDateTime(r.sent_at) },
    { key: 'comm_type', header: 'Type', render: (r: any) => r.comm_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
    { key: 'distribution_id', header: 'Distribution', render: (r: any) => String(r.distribution_id).slice(0, 8) },
    { key: 'message_summary', header: 'Summary', render: (r: any) => r.message_summary },
  ];

  const upcomingColumns: Column<Upcoming>[] = [
    { key: 'scheduled_date', header: 'Date', render: (r: any) => fmtDate(r.scheduled_date) },
    { key: 'days_until', header: 'Days Out', render: (r: any) => String(r.days_until) },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email || r.investor_id?.slice(0, 8) },
    { key: 'distribution_type', header: 'Type', render: (r: any) => r.distribution_type },
    { key: 'scheduled_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.scheduled_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Investor Distribution Schedule</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track promised and actual cash distributions across all investors.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Scheduled</div>
            <div style={{ fontSize: '22px', fontWeight: 700 }}>{summary.total_scheduled}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Paid</div>
            <div style={{ fontSize: '22px', fontWeight: 700, color: '#10b981' }}>{summary.total_paid}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Deferred</div>
            <div style={{ fontSize: '22px', fontWeight: 700, color: '#f59e0b' }}>{summary.total_deferred}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Cancelled</div>
            <div style={{ fontSize: '22px', fontWeight: 700, color: '#ef4444' }}>{summary.total_cancelled}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Scheduled Amount</div>
            <div style={{ fontSize: '18px', fontWeight: 700 }}>{fmtRupees(summary.scheduled_amount_rupees)}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Paid Amount</div>
            <div style={{ fontSize: '18px', fontWeight: 700, color: '#10b981' }}>{fmtRupees(summary.paid_amount_rupees)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Upcoming Distributions (next 90 days)
        </h2>
        <DataTable
          rows={upcoming}
          columns={upcomingColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Distributions</h2>
        <DataTable
          rows={distributions}
          columns={distColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Communications</h2>
        <DataTable
          rows={comms}
          columns={commColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
