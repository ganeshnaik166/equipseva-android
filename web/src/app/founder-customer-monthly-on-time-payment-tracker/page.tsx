import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtRupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return v.toFixed(2) + '%';
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [payments, actions, focus, grades, funnel, trend, summary] = await Promise.all([
    supabase.rpc('list_payments_r2640'),
    supabase.rpc('list_collection_actions_r2640'),
    supabase.rpc('top_late_focus_r2640'),
    supabase.rpc('grade_distribution_r2640'),
    supabase.rpc('status_funnel_r2640'),
    supabase.rpc('monthly_payment_trend_r2640'),
    supabase.rpc('total_unpaid_summary_r2640'),
  ]);

  const paymentRows: any[] = payments.data ?? [];
  const actionRows: any[] = actions.data ?? [];
  const focusRows: any[] = focus.data ?? [];
  const gradeRows: any[] = grades.data ?? [];
  const funnelRows: any[] = funnel.data ?? [];
  const trendRows: any[] = trend.data ?? [];
  const sum: any = (summary.data ?? [])[0] ?? {};

  const paymentCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'invoiced_rupees', header: 'Invoiced', render: (r: any) => fmtRupees(r.invoiced_rupees) },
    { key: 'paid_on_time_rupees', header: 'On-time', render: (r: any) => fmtRupees(r.paid_on_time_rupees) },
    { key: 'paid_late_rupees', header: 'Late', render: (r: any) => fmtRupees(r.paid_late_rupees) },
    { key: 'unpaid_rupees', header: 'Unpaid', render: (r: any) => fmtRupees(r.unpaid_rupees) },
    { key: 'on_time_pct', header: 'On-time %', render: (r: any) => fmtPct(r.on_time_pct) },
    { key: 'days_to_pay_avg', header: 'Avg days', render: (r: any) => Number(r.days_to_pay_avg ?? 0).toFixed(1) },
    { key: 'payment_grade', header: 'Grade', render: (r: any) => r.payment_grade },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '-' },
    { key: 'action_at', header: 'When', render: (r: any) => fmtDate(r.action_at) },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'unpaid_rupees', header: 'Unpaid', render: (r: any) => fmtRupees(r.unpaid_rupees) },
    { key: 'on_time_pct', header: 'On-time %', render: (r: any) => fmtPct(r.on_time_pct) },
    { key: 'payment_grade', header: 'Grade', render: (r: any) => r.payment_grade },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'payment_grade', header: 'Grade', render: (r: any) => r.payment_grade },
    { key: 'cnt', header: 'Customers', render: (r: any) => String(r.cnt) },
    { key: 'invoiced_rupees', header: 'Invoiced', render: (r: any) => fmtRupees(r.invoiced_rupees) },
    { key: 'unpaid_rupees', header: 'Unpaid', render: (r: any) => fmtRupees(r.unpaid_rupees) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'invoiced_rupees', header: 'Invoiced', render: (r: any) => fmtRupees(r.invoiced_rupees) },
    { key: 'paid_on_time_rupees', header: 'On-time', render: (r: any) => fmtRupees(r.paid_on_time_rupees) },
    { key: 'unpaid_rupees', header: 'Unpaid', render: (r: any) => fmtRupees(r.unpaid_rupees) },
    { key: 'on_time_pct_avg', header: 'Avg on-time %', render: (r: any) => fmtPct(r.on_time_pct_avg) },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Customer Monthly On-Time Payment Tracker</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Round 2640 — track who pays on time, who slips, and where collections must act.</p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total invoiced</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(sum.total_invoiced_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Paid on time</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(sum.total_paid_on_time_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Paid late</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(sum.total_paid_late_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Unpaid outstanding</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtRupees(sum.total_unpaid_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Overall on-time %</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{fmtPct(sum.overall_on_time_pct)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Escalated cases</div>
          <div style={{ fontSize: 20, fontWeight: 600 }}>{String(sum.escalated_count ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top late-payment focus (top 10)</h2>
        <DataTable
          rows={focusRows}
          columns={focusCols}
          emptyMessage="No active focus accounts."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All customer-month rows</h2>
        <DataTable
          rows={paymentRows}
          columns={paymentCols}
          emptyMessage="No payment rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Collection actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No collection actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Grade distribution</h2>
          <DataTable
            rows={gradeRows}
            columns={gradeCols}
            emptyMessage="No grade data."
            rowKey={(r: any, i: number) => String(r.payment_grade ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
          <DataTable
            rows={funnelRows}
            columns={funnelCols}
            emptyMessage="No status data."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly trend</h2>
          <DataTable
            rows={trendRows}
            columns={trendCols}
            emptyMessage="No monthly data."
            rowKey={(r: any, i: number) => String(r.month_label ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
