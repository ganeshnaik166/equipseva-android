import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Outstanding = {
  id: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  hospital_org: string | null;
  invoice_number: string;
  invoice_date: string;
  due_date: string;
  amount_rupees: number;
  paid_amount_rupees: number;
  outstanding_rupees: number;
  days_overdue: number;
  status: string;
  created_at: string;
};

type Ageing = {
  bucket: string;
  invoice_count: number;
  total_outstanding_rupees: number;
};

type TopOverdue = {
  hospital_user_id: string | null;
  hospital_email: string | null;
  hospital_org: string | null;
  invoice_count: number;
  total_outstanding_rupees: number;
  max_days_overdue: number;
};

type Action = {
  id: string;
  invoice_id: string | null;
  invoice_number: string | null;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  outcome: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleDateString('en-IN');
  } catch {
    return s;
  }
}

function fmtDateTime(s: string | null | undefined): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [outstandingRes, ageingRes, topRes, actionsRes] = await Promise.all([
    sb.rpc('list_outstanding_r1747', { p_status: null }),
    sb.rpc('ageing_summary_r1747'),
    sb.rpc('top_overdue_hospitals_r1747'),
    sb.rpc('list_collection_actions_r1747', { p_invoice_id: null }),
  ]);

  const outstanding: Outstanding[] = (outstandingRes.data as Outstanding[]) ?? [];
  const ageing: Ageing[] = (ageingRes.data as Ageing[]) ?? [];
  const top: TopOverdue[] = (topRes.data as TopOverdue[]) ?? [];
  const actions: Action[] = (actionsRes.data as Action[]) ?? [];

  const totalOutstanding = outstanding.reduce(
    (acc, r) => acc + Number(r.outstanding_rupees || 0),
    0,
  );
  const totalInvoices = outstanding.length;
  const overdueCount = outstanding.filter((r) =>
    ['overdue_30', 'overdue_60', 'overdue_90_plus'].includes(r.status),
  ).length;

  const outstandingCols: Column<Outstanding>[] = [
    { key: 'invoice_number', header: 'Invoice #', render: (r: any) => r.invoice_number ?? '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_org ?? '—' },
    { key: 'hospital_org', header: 'Org', render: (r: any) => r.hospital_org ?? '—' },
    { key: 'invoice_date', header: 'Invoice Date', render: (r: any) => fmtDate(r.invoice_date) },
    { key: 'due_date', header: 'Due Date', render: (r: any) => fmtDate(r.due_date) },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'paid_amount_rupees', header: 'Paid', render: (r: any) => fmtRupees(r.paid_amount_rupees) },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r: any) => fmtRupees(r.outstanding_rupees) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const ageingCols: Column<Ageing>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket ?? '—' },
    { key: 'invoice_count', header: 'Invoices', render: (r: any) => String(r.invoice_count ?? 0) },
    { key: 'total_outstanding_rupees', header: 'Total Outstanding', render: (r: any) => fmtRupees(r.total_outstanding_rupees) },
  ];

  const topCols: Column<TopOverdue>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'hospital_org', header: 'Org', render: (r: any) => r.hospital_org ?? '—' },
    { key: 'invoice_count', header: 'Invoices', render: (r: any) => String(r.invoice_count ?? 0) },
    { key: 'total_outstanding_rupees', header: 'Outstanding', render: (r: any) => fmtRupees(r.total_outstanding_rupees) },
    { key: 'max_days_overdue', header: 'Max Days Overdue', render: (r: any) => String(r.max_days_overdue ?? 0) },
  ];

  const actionsCols: Column<Action>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => fmtDateTime(r.taken_at) },
    { key: 'invoice_number', header: 'Invoice #', render: (r: any) => r.invoice_number ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Cash Collection Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track outstanding hospital invoices and collection ageing. Founder-only console.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px' }}>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>Total Outstanding</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{fmtRupees(totalOutstanding)}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>Invoices Tracked</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalInvoices}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>Overdue Count</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{overdueCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Ageing Summary</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          Outstanding amount grouped by ageing bucket. Excludes written-off invoices.
        </p>
        <DataTable
          rows={ageing}
          columns={ageingCols}
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Overdue Hospitals</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          Hospitals with the largest outstanding balances across overdue buckets.
        </p>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Outstanding Invoices</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          All tracked invoices sorted by due date ascending. Capped at 200 rows.
        </p>
        <DataTable
          rows={outstanding}
          columns={outstandingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent Collection Actions</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          Audit trail of reminders, calls, visits, legal notices, and escalations.
        </p>
        <DataTable
          rows={actions}
          columns={actionsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
